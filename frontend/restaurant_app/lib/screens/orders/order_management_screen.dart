import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});
  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _searchCtrl = TextEditingController();
  String? _status;
  String _search = '';
  bool _busy = false;

  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await apiClient.dio.get(
      '/api/orders',
      queryParameters: {
        'pageNumber': 1,
        'pageSize': 100,
        if (_status != null) 'status': _status,
        if (_search.trim().isNotEmpty) 'search': _search.trim(),
      },
    );
    return (r.data['items'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _action(Map<String, dynamic> order, String action) async {
    if (action == 'cancel') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hủy order?'),
          content: Text('Bạn có chắc muốn hủy order ${order['orderCode']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Không'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hủy order'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      final route = switch (action) {
        'served' => '/api/orders/${order['id']}/served',
        'cancel' => '/api/orders/${order['id']}/cancel',
        _ => '/api/orders/${order['id']}/confirm',
      };
      await apiClient.dio.post(route);
      _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details(Map<String, dynamic> order) async {
    try {
      final data = Map<String, dynamic>.from(
        (await apiClient.dio.get('/api/orders/${order['id']}')).data as Map,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${data['orderCode']} • ${data['tableName']}',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    StatusPill(status: data['status'] as String),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Phụ trách / Khách: ${data['memberName']}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if ((data['note'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ghi chú: ${data['note']}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Divider(height: 22),
                for (final raw in data['items'] as List)
                  Builder(
                    builder: (context) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${item['quantity']} × ${item['productName']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${statusStyle(item['status'] as String).$3}${(item['note'] as String? ?? '').isEmpty ? '' : ' • ${item['note']}'}',
                        ),
                        trailing: Text(
                          _money.format(item['totalPrice']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                  ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tổng cộng',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: Text(
                    _money.format(data['totalAmount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (data['status'] == 'Completed')
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        this.context.push('/invoices/order/${data['id']}');
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Xem hóa đơn'),
                    ),
                  )
                else if (data['status'] != 'Cancelled')
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await this.context.push(
                                  '/orders/new/${data['tableId']}?name=${Uri.encodeComponent('${data['tableName']}')}&orderId=${data['id']}',
                                );
                                _reload();
                              },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Gọi thêm món'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () {
                                Navigator.pop(context);
                                _action(order, 'cancel');
                              },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Hủy order'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        ),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = <(String?, String)>[
      (null, 'Tất cả'),
      ('Pending', 'Chờ xác nhận'),
      ('Confirmed', 'Đã xác nhận'),
      ('Preparing', 'Đang chế biến'),
      ('Ready', 'Món sẵn sàng'),
      ('Served', 'Đã phục vụ'),
      ('Completed', 'Đã thanh toán'),
      ('Cancelled', 'Đã hủy'),
    ];
    return Scaffold(
      appBar: buildAppBar(
        context,
        title: 'Đơn hàng',
        subtitle: 'Theo dõi và xử lý đơn phục vụ',
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Tìm theo mã đơn, tên bàn hoặc tên khách...',
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _search = '';
                            _future = _load();
                          });
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
              onChanged: (v) {
                setState(() {
                  _search = v;
                  _future = _load();
                });
              },
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: filters
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s.$2),
                        selected: _status == s.$1,
                        onSelected: (_) => setState(() {
                          _status = s.$1;
                          _future = _load();
                        }),
                      ),
                    ),
                  )
                  .toList(),
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
                  return EmptyStateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Không tải được đơn hàng',
                    subtitle: apiError(snap.error!),
                  );
                }
                final orders = snap.data ?? [];
                if (orders.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Không có order phù hợp',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, i) {
                      final o = orders[i];
                      final status = o['status'] as String;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _details(o),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${o['orderCode']} • Bàn ${o['tableName']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                    ),
                                    StatusPill(status: status, compact: true),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${o['memberName']} • ${formatDateTime(o['orderDate'])}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      _money.format(o['totalAmount']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _details(o),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 17,
                                      ),
                                      label: const Text('Chi tiết'),
                                    ),
                                    if (status == 'Pending')
                                      FilledButton.tonal(
                                        onPressed: _busy
                                            ? null
                                            : () => _action(o, 'confirm'),
                                        child: const Text('Xác nhận'),
                                      ),
                                    if (status == 'Ready')
                                      FilledButton.tonal(
                                        onPressed: _busy
                                            ? null
                                            : () => _action(o, 'served'),
                                        child: const Text('Đã phục vụ'),
                                      ),
                                    if (status == 'Completed')
                                      FilledButton.tonalIcon(
                                        onPressed: () => context.push(
                                          '/invoices/order/${o['id']}',
                                        ),
                                        icon: const Icon(
                                          Icons.receipt_outlined,
                                          size: 16,
                                        ),
                                        label: const Text('Hóa đơn'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
}
