import 'package:flutter/material.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

// ignore_for_file: curly_braces_in_flow_control_structures

class AreaManagementScreen extends StatefulWidget {
  const AreaManagementScreen({super.key});
  @override
  State<AreaManagementScreen> createState() => _AreaManagementScreenState();
}

class _AreaManagementScreenState extends State<AreaManagementScreen> {
  List<Map<String, dynamic>> _areas = [], _tables = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        adminRepository.areas(),
        adminRepository.tables(),
      ]);
      if (mounted) {
        setState(() {
          _areas = result[0];
          _tables = result[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object e) => apiError(e);
  Future<void> _areaDialog([Map<String, dynamic>? area]) async {
    final name = TextEditingController(text: area?['name']?.toString() ?? ''),
        desc = TextEditingController(
          text: area?['description']?.toString() ?? '',
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(area == null ? 'Thêm khu vực' : 'Sửa khu vực'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên khu vực'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    final areaName = name.text.trim();
    final areaDesc = desc.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    desc.dispose();
    if (ok != true) return;
    try {
      await adminRepository.saveArea(
        id: area?['id'] as int?,
        name: areaName,
        description: areaDesc,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<void> _tableDialog([Map<String, dynamic>? table]) async {
    if (_areas.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hãy tạo khu vực trước.')));
      return;
    }
    final name = TextEditingController(
          text: table?['tableName']?.toString() ?? '',
        ),
        capacity = TextEditingController(
          text: table?['capacity']?.toString() ?? '4',
        );
    int areaId = (table?['areaId'] as int?) ?? (_areas.first['id'] as int);
    String status = table?['status']?.toString() ?? 'Available';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(table == null ? 'Thêm bàn' : 'Sửa bàn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: areaId,
                decoration: const InputDecoration(labelText: 'Khu vực'),
                items: _areas
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as int,
                        child: Text(a['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setD(() => areaId = v);
                },
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên bàn'),
              ),
              TextField(
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sức chứa'),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: [
                  'Available',
                  if (table?['status'] == 'Occupied') 'Occupied',
                  'Reserved',
                  'Cleaning',
                ]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(statusStyle(s).$3),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setD(() => status = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    final tableName = name.text.trim();
    final tableCapacity = int.tryParse(capacity.text) ?? 4;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    capacity.dispose();
    if (ok != true) return;
    try {
      await adminRepository.saveTable(
        id: table?['id'] as int?,
        areaId: areaId,
        name: tableName,
        capacity: tableCapacity,
        status: status,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: const Text('Bạn có chắc muốn xóa dữ liệu này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: buildAppBar(
        context,
        title: 'Khu vực và bàn',
        subtitle: 'Thiết lập khu vực phục vụ và sức chứa bàn',
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Khu vực'),
            Tab(text: 'Bàn'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final isAreaTab = controller.index == 0;
              return FloatingActionButton.extended(
                onPressed: () => isAreaTab ? _areaDialog() : _tableDialog(),
                icon: const Icon(Icons.add),
                label: Text(isAreaTab ? 'Thêm khu vực' : 'Thêm bàn'),
              );
            },
          );
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : TabBarView(children: [_areaList(), _tableList()]),
    ),
  );
  Widget _areaList() => _areas.isEmpty
      ? const Center(child: Text('Chưa có khu vực.'))
      : ListView(
          children: [
            for (final a in _areas)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(a['name'] as String),
                  subtitle: Text(
                    '${a['tableCount']} bàn${a['description'] == null ? '' : ' · ${a['description']}'}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: () => _areaDialog(a),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (await _confirm('Xóa khu vực?')) {
                            try {
                              await adminRepository.deleteArea(a['id'] as int);
                              await _load();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_message(e))),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
  Widget _tableList() => _tables.isEmpty
      ? const Center(child: Text('Chưa có bàn.'))
      : ListView(
          children: [
            for (final t in _tables)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.table_restaurant),
                  title: Text(t['tableName'] as String),
                  subtitle: Text(
                    '${t['area']} · ${t['capacity']} chỗ · ${statusStyle(t['status'].toString()).$3}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: () => _tableDialog(t),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (await _confirm('Xóa bàn?')) {
                            try {
                              await adminRepository.deleteTable(t['id'] as int);
                              await _load();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_message(e))),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
}
