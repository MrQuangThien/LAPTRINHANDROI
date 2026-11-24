import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _database;

  /// sqflite's native Android plugin is unavailable on Windows desktop.
  /// Switch its database factory to SQLite FFI before opening the local cache.
  static void initializeForCurrentPlatform() {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async => openDatabase(
    path.join(await getDatabasesPath(), 'restaurant_offline.db'),
    version: 1,
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE cache (bucket TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(bucket,id))',
      );
      await db.execute(
        'CREATE TABLE drafts (client_request_id TEXT PRIMARY KEY, table_id INTEGER NOT NULL, table_name TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE sync_queue (client_request_id TEXT PRIMARY KEY, payload TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT, created_at TEXT NOT NULL)',
      );
    },
  );

  Future<List<Map<String, dynamic>>> readCache(String bucket) async {
    final rows = await (await database).query(
      'cache',
      where: 'bucket = ?',
      whereArgs: [bucket],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((r) => jsonDecode(r['payload']! as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> replaceCache(
    String bucket,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cache', where: 'bucket = ?', whereArgs: [bucket]);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in items) {
      batch.insert('cache', {
        'bucket': bucket,
        'id': '${item['id']}',
        'payload': jsonEncode(item),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveDraft(
    String id,
    int tableId,
    String tableName,
    Map<String, dynamic> payload,
  ) async => (await database).insert('drafts', {
    'client_request_id': id,
    'table_id': tableId,
    'table_name': tableName,
    'payload': jsonEncode(payload),
    'created_at': DateTime.now().toUtc().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteDraft(String id) async => (await database).delete(
    'drafts',
    where: 'client_request_id = ?',
    whereArgs: [id],
  );
  Future<Map<String, dynamic>?> findEditableDraft(int tableId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT d.client_request_id, d.payload FROM drafts d
      LEFT JOIN sync_queue q ON q.client_request_id = d.client_request_id
      WHERE d.table_id = ? AND q.client_request_id IS NULL
      ORDER BY d.created_at DESC LIMIT 1
    ''',
      [tableId],
    );
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['client_request_id'],
      'payload':
          jsonDecode(rows.first['payload']! as String) as Map<String, dynamic>,
    };
  }

  Future<void> queueOrder(String id, Map<String, dynamic> payload) async =>
      (await database).insert('sync_queue', {
        'client_request_id': id,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Map<String, dynamic>>> queuedOrders() async {
    final rows = await (await database).query(
      'sync_queue',
      orderBy: 'created_at',
    );
    return rows
        .map(
          (r) => {
            'client_request_id': r['client_request_id'],
            'payload':
                jsonDecode(r['payload']! as String) as Map<String, dynamic>,
          },
        )
        .toList();
  }

  Future<Set<int>> queuedTableIds() async {
    return (await queuedOrders())
        .map((entry) => (entry['payload'] as Map<String, dynamic>?)?['tableId'])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
  }

  Future<void> markSynced(String id) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'client_request_id = ?',
      whereArgs: [id],
    );
    await db.delete('drafts', where: 'client_request_id = ?', whereArgs: [id]);
  }

  Future<void> markSyncFailed(String id, String error) async =>
      (await database).rawUpdate(
        'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE client_request_id = ?',
        [error, id],
      );
  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(
        await (await database).rawQuery('SELECT COUNT(*) FROM sync_queue'),
      ) ??
      0;
}
