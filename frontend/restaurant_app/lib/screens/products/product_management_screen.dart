import 'package:dio/dio.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});
  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _categories = [];
  String _search = '';
  int _page = 1;
  static const int _pageSize = 10;
  int _totalCount = 0;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final values = await Future.wait([
      apiClient.dio.get(
        '/api/categories',
        queryParameters: {'pageNumber': 1, 'pageSize': 100},
      ),
      apiClient.dio.get(
        '/api/products',
        queryParameters: {
          'pageNumber': _page,
          'pageSize': _pageSize,
          'search': _search,
        },
      ),
    ]);
    _categories = (values[0].data['items'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    _totalCount = (values[1].data['totalCount'] as num?)?.toInt() ?? 0;
    return (values[1].data['items'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<Uint8List> _prepareUploadImage(XFile file) async {
    final source = await file.readAsBytes();
    if (source.length > 25_000_000) {
      throw StateError('Ảnh gốc quá lớn (tối đa 25 MB).');
    }
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('Không đọc được ảnh. Hãy chọn ảnh JPG, PNG hoặc WebP.');
    }
    final oriented = img.bakeOrientation(decoded);
    final longestSide = math.max(oriented.width, oriented.height);
    final scale = longestSide > 1600 ? 1600 / longestSide : 1.0;
    final resized = scale < 1
        ? img.copyResize(
            oriented,
            width: (oriented.width * scale).round(),
            height: (oriented.height * scale).round(),
          )
        : oriented;
    // Flatten transparent images onto white before encoding as JPEG.
    final background = img.Image(
      width: resized.width,
      height: resized.height,
      numChannels: 3,
    );
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(background, resized);
    for (final quality in [85, 75, 65, 55]) {
      final jpeg = img.encodeJpg(background, quality: quality);
      if (jpeg.length <= 5_000_000) return Uint8List.fromList(jpeg);
    }
    throw StateError('Không thể nén ảnh xuống dưới 5 MB.');
  }

  Future<void> _edit([Map<String, dynamic>? product]) async {
    final activeCategories = _categories
        .where((c) => c['isActive'] == true)
        .toList();
    if (_categories.isEmpty || (product == null && activeCategories.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy tạo hoặc bật hoạt động ít nhất một danh mục trước.'),
        ),
      );
      return;
    }
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: product?['name'] as String? ?? '');
    final description = TextEditingController(
      text: product?['description'] as String? ?? '',
    );
    final price = TextEditingController(
      text: product == null ? '' : (product['price'] as num).toString(),
    );
    int? categoryId =
        product?['categoryId'] as int? ??
        (activeCategories.first['id'] as num).toInt();
    bool available = product?['isAvailable'] as bool? ?? true;
    XFile? image;
    Future<Uint8List>? imagePreview;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(product == null ? 'Thêm món' : 'Sửa món'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Tên món'),
                    validator: (v) => v == null || v.trim().length < 2
                        ? 'Nhập tên món'
                        : null,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: _categories
                        .where(
                          (c) =>
                              c['isActive'] == true ||
                              (c['id'] as num).toInt() == categoryId,
                        )
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: (c['id'] as num).toInt(),
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => categoryId = v),
                  ),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Giá bán (₫)'),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                        ? 'Giá chưa hợp lệ'
                        : null,
                  ),
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  if (imagePreview != null) ...[
                    const SizedBox(height: 12),
                    FutureBuilder<Uint8List>(
                      future: imagePreview,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Không đọc được ảnh đã chọn.');
                        }
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            snapshot.data!,
                            height: 130,
                            width: 180,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ] else if ((product?['imageUrl'] as String?) != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        '${AppConfig.apiBaseUrl}${product!['imageUrl']}',
                        height: 130,
                        width: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              height: 100,
                              child: Center(
                                child: Text('Không tải được ảnh cũ'),
                              ),
                            ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    value: available,
                    title: const Text('Đang bán'),
                    onChanged: (v) => setDialog(() => available = v),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          image = picked;
                          imagePreview = picked.readAsBytes();
                        }
                        setDialog(() {});
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Không mở được trình chọn ảnh.'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      image?.name ??
                          ((product?['imageUrl'] as String?) == null
                              ? 'Chọn ảnh món'
                              : 'Đổi ảnh món'),
                    ),
                  ),
                  const Text(
                    'Ảnh sẽ được tự động thu nhỏ và nén trước khi tải lên',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
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
                    'price': double.parse(price.text.replaceAll(',', '.')),
                    'categoryId': categoryId,
                    'isAvailable': available,
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
    // showDialog completes as soon as the route is popped; let its reverse
    // transition detach the TextFormFields before disposing their controllers.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    description.dispose();
    price.dispose();
    if (data == null) return;
    try {
      final file = data['image'] as XFile?;
      final compressedImage = file == null
          ? null
          : await _prepareUploadImage(file);
      final body = {
        'name': data['name'],
        'description': data['description'],
        'price': data['price'],
        'categoryId': data['categoryId'],
        'isAvailable': data['isAvailable'],
      };
      final int id;
      if (product == null) {
        final r = await apiClient.dio.post('/api/products', data: body);
        id = (r.data['id'] as num).toInt();
      } else {
        id = (product['id'] as num).toInt();
        await apiClient.dio.put('/api/products/$id', data: body);
      }
      if (file != null) {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            compressedImage!,
            filename: 'product-$id.jpg',
          ),
        });
        await apiClient.dio.post('/api/products/$id/image', data: form);
      }
      _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngừng bán món?'),
        content: Text(
          'Xóa “${p['name']}”? Món có lịch sử order sẽ được ẩn bán để giữ hóa đơn.',
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
      final r = await apiClient.dio.delete('/api/products/${p['id']}');
      _reload();
      final msg = r.data is Map ? (r.data['message'] as String?) : null;
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
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
      title: 'Quản lý món',
      subtitle: 'Thêm món mới, cập nhật giá và hình ảnh',
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
      label: const Text('Thêm món'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm món',
            ),
            onChanged: (v) {
              _search = v;
              _page = 1;
              _reload();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text(apiError(snap.error!)));
              }
              final products = snap.data ?? [];
              if (products.isEmpty) {
                return const Center(child: Text('Chưa có món.'));
              }
              final totalPages = (_totalCount / _pageSize).ceil().clamp(1, 9999);
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: products.length,
                      itemBuilder: (context, i) {
                        final p = products[i];
                        final image = p['imageUrl'] as String?;
                        return Card(
                          child: ListTile(
                            leading: image == null
                                ? const CircleAvatar(
                                    child: Icon(Icons.restaurant),
                                  )
                                : CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      '${AppConfig.apiBaseUrl}$image',
                                    ),
                                  ),
                            title: Text(p['name'] as String),
                            subtitle: Text(
                              '${p['category']} • ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(p['price'])}${p['isAvailable'] == true ? '' : ' • Ngừng bán'}',
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  onPressed: () => _edit(p),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: () => _delete(p),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 88, 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Trang $_page / $totalPages • $_totalCount món',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _page > 1
                                ? () {
                                    _page--;
                                    _reload();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: const Text('Trước'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _page < totalPages
                                ? () {
                                    _page++;
                                    _reload();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: const Text('Sau'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
