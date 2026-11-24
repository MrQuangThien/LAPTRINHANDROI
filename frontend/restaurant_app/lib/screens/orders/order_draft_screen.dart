import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../models/product.dart';
import '../../services/app_services.dart';

class OrderDraftScreen extends StatefulWidget {
  const OrderDraftScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    this.activeOrderId,
  });
  final int tableId;
  final String tableName;
  final int? activeOrderId;
  @override
  State<OrderDraftScreen> createState() => _OrderDraftScreenState();
}

class _OrderDraftScreenState extends State<OrderDraftScreen> {
  String _requestId = const Uuid().v4();
  final _note = TextEditingController();
  final _search = TextEditingController();
  late Future<List<Product>> _products;
  late Future<Map<String, dynamic>?> _activeOrder;
  final Map<int, int> _quantities = {};
  String _query = '';
  bool _sending = false;

  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _products = catalogRepository.products();
    _activeOrder = _loadActiveOrder();
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    if (widget.activeOrderId != null) return;
    final draft = await localDatabase.findEditableDraft(widget.tableId);
    if (draft == null) return;
    final payload = draft['payload'] as Map<String, dynamic>;
    final products = await _products;
    if (!mounted) return;
    setState(() {
      _productsValue = products;
      _requestId = draft['id'] as String;
      _note.text = payload['note'] as String? ?? '';
      for (final item in (payload['items'] as List? ?? [])) {
        final row = item as Map<String, dynamic>;
        _quantities[(row['productId'] as num).toInt()] =
            (row['quantity'] as num).toInt();
      }
    });
  }

  Future<Map<String, dynamic>?> _loadActiveOrder() async {
    final id = widget.activeOrderId;
    if (id == null) return null;
    final response = await apiClient.dio.get('/api/orders/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  void dispose() {
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  int get _count => _quantities.values.fold(0, (a, b) => a + b);
  double get _total => _productsValue.fold(
    0,
    (sum, p) => sum + p.price * (_quantities[p.id] ?? 0),
  );
  List<Product> _productsValue = const [];

  Map<String, dynamic> _payload() => {
    'tableId': widget.tableId,
    'clientRequestId': _requestId,
    'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    'items': _productsValue
        .where((p) => (_quantities[p.id] ?? 0) > 0)
        .map(
          (p) => {
            'productId': p.id,
            'quantity': _quantities[p.id],
            'note': null,
          },
        )
        .toList(),
  };

  Future<void> _persist() async {
    if (widget.activeOrderId != null) return;
    if (_count == 0) {
      await localDatabase.deleteDraft(_requestId);
      return;
    }
    await localDatabase.saveDraft(
      _requestId,
      widget.tableId,
      widget.tableName,
      _payload(),
    );
  }

  void _change(Product p, int delta) {
    setState(() {
      final next = (_quantities[p.id] ?? 0) + delta;
      if (next <= 0) {
        _quantities.remove(p.id);
      } else if (next <= 99) {
        _quantities[p.id] = next;
      }
    });
    _persist();
  }

  Future<void> _send() async {
    if (_count == 0) return;
    setState(() => _sending = true);
    try {
      var sent = false;
      if (widget.activeOrderId != null) {
        final response = await apiClient.dio.post(
          '/api/orders/${widget.activeOrderId}/items',
          data: {
            'items': _payload()['items'],
            'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
          },
        );
        if (response.data['status'] == 'Pending') {
          await apiClient.dio.post(
            '/api/orders/${widget.activeOrderId}/confirm',
          );
        }
        sent = true;
      } else {
        await localDatabase.saveDraft(
          _requestId,
          widget.tableId,
          widget.tableName,
          _payload(),
        );
        try {
          final created = await apiClient.dio.post(
            '/api/orders',
            data: _payload(),
          );
          final orderId = (created.data as Map)['id'];
          await apiClient.dio.post('/api/orders/$orderId/confirm');
          await localDatabase.markSynced(_requestId);
          sent = true;
        } on DioException catch (e) {
          final isOffline =
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout;
          if (isOffline) {
            await localDatabase.queueOrder(_requestId, _payload());
            sent = false;
          } else {
            rethrow;
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? (widget.activeOrderId == null
                      ? 'Order đã gửi xuống bếp.'
                      : 'Đã thêm món vào order hiện tại.')
                : 'Đã lưu trên thiết bị, sẽ đồng bộ khi có mạng.',
          ),
        ),
      );
      if (sent) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/tables');
        }
      } else {
        setState(() => _sending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.activeOrderId == null
                  ? 'Đã lưu bản nháp. ${apiError(e)}'
                  : 'Chưa gửi được món gọi thêm. Món đang chọn vẫn còn trên màn hình. ${apiError(e)}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: widget.activeOrderId == null ? 'Tạo order mới' : 'Gọi thêm món',
      subtitle: 'Bàn: ${widget.tableName}',
      fallbackRoute: '/tables',
    ),
    body: FutureBuilder<List<Product>>(
      future: _products,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const EmptyStateView(
            icon: Icons.wifi_off_rounded,
            title: 'Chưa có thực đơn trên thiết bị',
            subtitle: 'Kết nối mạng để tải danh sách món ăn.',
          );
        }
        _productsValue = (snap.data ?? []).where((p) => p.available).toList();
        final filtered = _query.trim().isEmpty
            ? _productsValue
            : _productsValue
                  .where(
                    (p) =>
                        p.name.toLowerCase().contains(_query.toLowerCase()) ||
                        p.category.toLowerCase().contains(_query.toLowerCase()),
                  )
                  .toList();
        return Column(
          children: [
            if (widget.activeOrderId != null)
              FutureBuilder<Map<String, dynamic>?>(
                future: _activeOrder,
                builder: (context, orderSnap) {
                  if (orderSnap.hasError) {
                    return const ListTile(
                      leading: Icon(Icons.error_outline),
                      title: Text('Không tải được order đang phục vụ.'),
                    );
                  }
                  final order = orderSnap.data;
                  if (order == null) {
                    return const LinearProgressIndicator();
                  }
                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    color: const Color(0xFFFFF8F2),
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        '${order['orderCode']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Tạm tính hiện tại: ${_money.format(order['totalAmount'])}',
                      ),
                      trailing: StatusPill(
                        status: order['status'] as String,
                        compact: true,
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Tìm nhanh món theo tên hoặc danh mục...',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.restaurant_menu_outlined,
                      title: 'Không tìm thấy món phù hợp',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final qty = _quantities[p.id] ?? 0;
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: qty > 0
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: qty > 0 ? 1.6 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: p.imageUrl == null
                                    ? Container(
                                        color: const Color(0xFFF3E7DC),
                                        child: const Icon(
                                          Icons.local_cafe_outlined,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : Image.network(
                                        '${AppConfig.apiBaseUrl}${p.imageUrl}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: const Color(0xFFF3E7DC),
                                          child: const Icon(
                                            Icons.local_cafe_outlined,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${p.category.isEmpty ? 'Món' : p.category} • ${_money.format(p.price)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: qty == 0
                                      ? null
                                      : () => _change(p, -1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$qty',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: qty > 0
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _change(p, 1),
                                  icon: const Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.primary,
                                  ),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _note,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú cho bếp / phục vụ',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      onChanged: (_) => _persist(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE4DA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Đã chọn $_count món',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _money.format(_total),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sending || _count == 0 ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _sending ? 'Đang gửi...' : 'Xác nhận & gửi bếp',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
