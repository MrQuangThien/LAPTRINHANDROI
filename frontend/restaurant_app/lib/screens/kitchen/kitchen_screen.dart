import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});
  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await apiClient.dio.get('/api/kitchen/orders');
    return (response.data as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  Future<void> _action(int id, String action) async {
    setState(() => _busy = true);
    try {
      await apiClient.dio.post('/api/kitchen/orders/$id/$action');
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Màn hình bếp',
      subtitle: 'Hàng đợi chế biến món ăn & thức uống',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => setState(() {
            _future = _load();
          }),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
            title: 'Không tải được hàng đợi bếp',
            subtitle: apiError(snap.error!),
          );
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return const EmptyStateView(
            icon: Icons.soup_kitchen_outlined,
            title: 'Bếp chưa có order mới',
            subtitle: 'Các order đã xác nhận sẽ xuất hiện tại đây.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final future = _load();
            setState(() {
              _future = future;
            });
            await future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final order = orders[i];
              final status = order['status'] as String;
              final items = order['items'] as List;
              final hasPendingItems = items.any(
                (raw) => (raw as Map)['status'] == 'Pending',
              );
              final isNewOrder = status == 'Pending' || status == 'Confirmed';
              final action = isNewOrder || hasPendingItems
                  ? 'start'
                  : status == 'Preparing'
                  ? 'ready'
                  : 'served';
              final label = isNewOrder
                  ? 'Nhận chế biến'
                  : hasPendingItems
                  ? 'Nhận món gọi thêm'
                  : status == 'Preparing'
                  ? 'Báo món sẵn sàng'
                  : 'Đã phục vụ';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Bàn ${order['tableName']} • ${order['orderCode']}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(status: status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if ((order['customerName'] as String? ?? '')
                              .isNotEmpty)
                            'Khách: ${order['customerName']}',
                          formatDateTime(order['orderDate']),
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((order['note'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4DE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Ghi chú đơn: ${order['note']}',
                            style: const TextStyle(
                              color: Color(0xFFB26B00),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 20),
                      for (final raw in items)
                        Builder(
                          builder: (context) {
                            final item = Map<String, dynamic>.from(raw as Map);
                            final itemStatus =
                                item['status'] as String? ?? status;
                            final isServedItem = itemStatus == 'Served';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isServedItem
                                          ? Colors.grey.shade200
                                          : const Color(0xFFEDE4DA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item['quantity']}×',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isServedItem
                                            ? AppColors.textSecondary
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item['productName'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isServedItem
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                        decoration: isServedItem
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if ((item['note'] as String? ?? '')
                                      .isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEFE5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['note'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFFC85A17),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  StatusPill(status: itemStatus, compact: true),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _action(order['id'] as int, action),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: Text(label),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
