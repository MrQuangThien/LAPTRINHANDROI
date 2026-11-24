import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});
  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await apiClient.dio.get(
      '/api/categories',
      queryParameters: {'pageNumber': 1, 'pageSize': 100},
    );
    return (r.data['items'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _edit([Map<String, dynamic>? category]) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(
      text: category?['name'] as String? ?? '',
    );
    final description = TextEditingController(
      text: category?['description'] as String? ?? '',
    );
    bool isActive = category?['isActive'] as bool? ?? true;
    XFile? image;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên danh mục'),
                  validator: (v) => v == null || v.trim().length < 2
                      ? 'Nhập tên danh mục'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: const Text('Đang hoạt động'),
                  onChanged: (v) => setDialog(() => isActive = v),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    setDialog(() {});
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(image?.name ?? 'Chọn ảnh đại diện'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, {
                    'name': name.text.trim(),
                    'description': description.text.trim(),
                    'isActive': isActive,
                    'image': image,
                  });
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    description.dispose();
    if (data == null) return;
    try {
      final body = {
        'name': data['name'],
        'description': data['description'],
        'isActive': data['isActive'],
      };
      final int id;
      if (category == null) {
        final r = await apiClient.dio.post('/api/categories', data: body);
        id = (r.data['id'] as num).toInt();
      } else {
        id = (category['id'] as num).toInt();
        await apiClient.dio.put('/api/categories/$id', data: body);
      }
      final file = data['image'] as XFile?;
      if (file != null) {
        final bytes = await file.readAsBytes();
        final upload = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: file.name),
        });
        await apiClient.dio.post('/api/categories/$id/image', data: upload);
      }
      _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text(
          'Xóa “${category['name']}”? Danh mục đang có món sẽ không thể xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiClient.dio.delete('/api/categories/${category['id']}');
      _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Quản lý danh mục',
      subtitle: 'Thêm, sửa và xóa nhóm món ăn',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm danh mục'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline_rounded,
            title: 'Không tải được danh mục',
            subtitle: apiError(snap.error!),
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return const EmptyStateView(
            icon: Icons.category_outlined,
            title: 'Chưa có danh mục',
            subtitle: 'Nhấn nút Thêm danh mục để bắt đầu.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final c = rows[i];
            final image = c['imageUrl'] as String?;
            return Card(
              child: ListTile(
                leading: image == null
                    ? Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE4DA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.category_outlined,
                          color: AppColors.primary,
                        ),
                      )
                    : CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(
                          '${AppConfig.apiBaseUrl}$image',
                        ),
                      ),
                title: Text(
                  c['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${(c['description'] as String? ?? '').isEmpty ? 'Không có mô tả' : c['description']}${c['isActive'] == false ? ' • Tạm ẩn' : ''}',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Sửa',
                      onPressed: () => _edit(c),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Xóa',
                      onPressed: () => _delete(c),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
