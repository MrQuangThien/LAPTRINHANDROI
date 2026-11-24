import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/app_chrome.dart';
import '../../models/product.dart';
import '../../services/app_services.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Product>> _products;
  late Future<List<Map<String, dynamic>>> _categories;
  final _search = TextEditingController();
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _categories = catalogRepository.categories();
    _products = catalogRepository.products(
      categoryId: _categoryId,
      search: _search.text,
    );
  }

  void _filter({int? categoryId, String? search}) {
    setState(() {
      if (categoryId != null || (categoryId == null && _categoryId != null)) {
        _categoryId = categoryId;
      }
      _products = catalogRepository.products(
        categoryId: _categoryId,
        search: search ?? _search.text,
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Thực đơn',
      subtitle: 'Danh sách món đang phục vụ',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => setState(_refresh),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Tìm món ăn hoặc thức uống...',
            ),
            onChanged: (v) => _filter(search: v),
          ),
        ),
        SizedBox(
          height: 52,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _categories,
            builder: (context, snap) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _categoryId == null,
                    onSelected: (_) => _filter(categoryId: null),
                  ),
                ),
                for (final c in (snap.data ?? []).where(
                  (x) => x['isActive'] != false,
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c['name'] as String? ?? ''),
                      selected: _categoryId == c['id'],
                      onSelected: (_) => _filter(categoryId: c['id'] as int),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _products,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const EmptyStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Không tải được thực đơn',
                );
              }
              final list = (snap.data ?? []).where((p) => p.available).toList();
              if (list.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Chưa có món phù hợp',
                );
              }
              final money = NumberFormat.currency(
                locale: 'vi_VN',
                symbol: '₫',
                decimalDigits: 0,
              );
              return LayoutBuilder(
                builder: (context, box) => GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: box.maxWidth > 900
                        ? 4
                        : box.maxWidth > 580
                        ? 3
                        : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .80,
                  ),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                p.imageUrl == null
                                    ? Container(
                                        color: const Color(0xFFF3E7DC),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.local_cafe_outlined,
                                          size: 44,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : Image.network(
                                        '${AppConfig.apiBaseUrl}${p.imageUrl}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: const Color(0xFFF3E7DC),
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      ),
                                if (p.category.isNotEmpty)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        p.category,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if ((p.description ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    p.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  money.format(p.price),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
