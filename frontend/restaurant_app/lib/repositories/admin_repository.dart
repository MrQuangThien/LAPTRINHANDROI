import '../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> areas() async {
    final r = await _api.dio.get('/api/areas');
    return (r.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> tables() async {
    final r = await _api.dio.get(
      '/api/tables',
      queryParameters: {'pageNumber': 1, 'pageSize': 100},
    );
    final d = Map<String, dynamic>.from(r.data as Map);
    return (d['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveArea({
    int? id,
    required String name,
    String? description,
  }) async {
    final data = {'name': name, 'description': description};
    if (id == null) {
      await _api.dio.post('/api/areas', data: data);
    } else {
      await _api.dio.put('/api/areas/$id', data: data);
    }
  }

  Future<void> deleteArea(int id) =>
      _api.dio.delete('/api/areas/$id').then((_) {});
  Future<void> saveTable({
    int? id,
    required int areaId,
    required String name,
    required int capacity,
    required String status,
  }) async {
    final data = {
      'areaId': areaId,
      'tableName': name,
      'capacity': capacity,
      'status': status,
    };
    if (id == null) {
      await _api.dio.post('/api/tables', data: data);
    } else {
      await _api.dio.put('/api/tables/$id', data: data);
    }
  }

  Future<void> deleteTable(int id) =>
      _api.dio.delete('/api/tables/$id').then((_) {});

  Future<List<Map<String, dynamic>>> members({
    String search = '',
    String? role,
  }) async {
    final r = await _api.dio.get(
      '/api/members',
      queryParameters: {
        'pageNumber': 1,
        'pageSize': 100,
        if (search.isNotEmpty) 'search': search,
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );
    final d = Map<String, dynamic>.from(r.data as Map);
    return (d['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<String>> roles() async {
    final r = await _api.dio.get('/api/roles');
    return (r.data as List)
        .map((e) => (e as Map)['name'] as String)
        .where((e) => e != 'Admin')
        .toList();
  }

  Future<List<Map<String, dynamic>>> roleDetails() async {
    final r = await _api.dio.get('/api/roles');
    return (r.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> createMember(Map<String, dynamic> data) =>
      _api.dio.post('/api/members', data: data).then((_) {});
  Future<void> updateMember(int id, Map<String, dynamic> data) =>
      _api.dio.put('/api/members/$id', data: data).then((_) {});
  Future<void> setMemberActive(int id, bool active) => _api.dio
      .patch('/api/members/$id/active', queryParameters: {'active': active})
      .then((_) {});
}
