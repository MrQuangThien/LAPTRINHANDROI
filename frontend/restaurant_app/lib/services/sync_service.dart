import 'dart:async';

import 'package:dio/dio.dart';

import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';

class SyncService {
  SyncService(this._api, this._database);
  final ApiClient _api;
  final DatabaseHelper _database;
  Timer? _timer;
  bool _running = false;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
    unawaited(flush());
  }

  void dispose() => _timer?.cancel();

  Future<int> flush() async {
    if (_running) return 0;
    _running = true;
    var synced = 0;
    try {
      final queue = await _database.queuedOrders();
      for (final item in queue) {
        final id = item['client_request_id'] as String;
        try {
          final created = await _api.dio.post(
            '/api/orders',
            data: item['payload'],
          );
          final orderId = (created.data as Map)['id'];
          await _api.dio.post('/api/orders/$orderId/confirm');
          await _database.markSynced(id);
          synced++;
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (status != null &&
              status >= 400 &&
              status < 500 &&
              status != 401 &&
              status != 408 &&
              status != 429) {
            await _database.markSynced(id);
            continue;
          }
          await _database.markSyncFailed(id, e.message ?? e.type.name);
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              status == 401) {
            break;
          }
        }
      }
    } finally {
      _running = false;
    }
    return synced;
  }
}
