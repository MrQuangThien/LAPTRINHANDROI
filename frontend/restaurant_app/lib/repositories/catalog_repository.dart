import 'package:dio/dio.dart';

import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';
import '../models/product.dart';

class CatalogRepository {
  CatalogRepository(this._api, this._database);
  final ApiClient _api;
  final DatabaseHelper _database;

  Future<List<Product>> products({int? categoryId, String? search}) async {
    try {
      final response = await _api.dio.get(
        '/api/products',
        queryParameters: {
          'pageNumber': 1,
          'pageSize': 100,
          'categoryId': ?categoryId,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final items = (data['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (categoryId == null && (search == null || search.isEmpty)) {
        await _database.replaceCache('products', items);
      }
      return items.map(Product.fromJson).toList();
    } on DioException {
      final cached = await _database.readCache('products');
      return cached
          .map(Product.fromJson)
          .where(
            (p) =>
                (categoryId == null || p.categoryId == categoryId) &&
                (search == null ||
                    p.name.toLowerCase().contains(search.toLowerCase())),
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> categories() async {
    try {
      final response = await _api.dio.get(
        '/api/categories',
        queryParameters: {'pageNumber': 1, 'pageSize': 100},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final items = (data['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      await _database.replaceCache('categories', items);
      return items;
    } on DioException {
      return _database.readCache('categories');
    }
  }
}
