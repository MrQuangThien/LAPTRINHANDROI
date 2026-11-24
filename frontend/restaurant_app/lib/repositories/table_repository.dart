import 'package:dio/dio.dart';

import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';
import '../models/restaurant_table.dart';

class TableRepository {
  TableRepository(this._api, this._database);
  final ApiClient _api;
  final DatabaseHelper _database;
  Future<List<RestaurantTable>> tables() async {
    try {
      final response = await _api.dio.get(
        '/api/tables',
        queryParameters: {'pageNumber': 1, 'pageSize': 100},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final items = (data['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      await _database.replaceCache('tables', items);
      return items.map(RestaurantTable.fromJson).toList();
    } on DioException {
      return (await _database.readCache('tables'))
          .map(RestaurantTable.fromJson)
          .toList();
    }
  }
}
