import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Future<List<Map<String, dynamic>>> _future;
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

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await apiClient.dio.get(
      '/api/payments/pending',
      queryParameters: {'pageNumber': 1, 'pageSize': 100},
    );
    return (r.data['items'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  Future<void> _checkout(Map<String, dynamic> order) async {
    final discount = TextEditingController(text: '0');
    final paymentRequest = order['paymentRequest'] is Map
        ? Map<String, dynamic>.from(order['paymentRequest'] as Map)
        : null;
    final isCustomerRequest =
        paymentRequest?['status'] == 'PendingConfirmation';
    final defaultRef = defaultPaymentReference(order['orderCode']);
    final transaction = TextEditingController(
      text: isCustomerRequest
          ? (paymentRequest?['transactionCode'] as String? ?? defaultRef)
          : defaultRef,
    );
    String method = isCustomerRequest
        ? (paymentRequest?['paymentMethod'] as String? ?? 'VietQR')
        : 'VietQR';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Thanh toán ${order['orderCode']}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              if (order['customerName'] != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Khách: ${order['customerName']} • ${order['customerPhone'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Tạm tính: ${_money.format(order['subTotal'] ?? order['totalAmount'])}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (isCustomerRequest)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Khách đã gửi yêu cầu thanh toán. Thu ngân cần xác minh tiền đã nhận.',
                    ),
                  ),
                ),
              TextField(
                controller: discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Giảm giá (₫)'),
                onChanged: (_) => setDialog(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Hình thức thanh toán',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'VietQR',
                    child: Text('Mã QR (VietQR)'),
                  ),
                  DropdownMenuItem(
                    value: 'BankTransfer',
                    child: Text('Chuyển khoản'),
                  ),
                  DropdownMenuItem(value: 'Cash', child: Text('Tiền mặt')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialog(() {
                      method = value;
                      if (method != 'Cash' && transaction.text.trim().isEmpty) {
                        transaction.text = defaultRef;
                      }
                    });
                  }
                },
              ),
              if (method != 'Cash') ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final sub =
                        ((order['subTotal'] ?? order['totalAmount']) as num)
                            .toDouble();
                    final disc =
                        (double.tryParse(discount.text.replaceAll(',', '.')) ??
                                0)
                            .clamp(0.0, sub);
                    final net = (sub - disc).clamp(0.0, sub);
                    final payable = net + (net * 0.08).roundToDouble();
                    return PaymentQrCard(
                      orderCode: '${order['orderCode']}',
                      amount: payable,
                      tableName: '${order['tableName'] ?? ''}',
                      compact: true,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: transaction,
                  decoration: const InputDecoration(
                    labelText: 'Mã giao dịch / Nội dung CK',
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Xác nhận tiền đã vào tài khoản trước khi hoàn tất thu ngân.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  discount.text.replaceAll(',', '.'),
                );
                final subTotal =
                    ((order['subTotal'] ?? order['totalAmount']) as num)
                        .toDouble();
                if (parsed == null || parsed < 0 || parsed > subTotal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Mức giảm giá không hợp lệ hoặc vượt quá tạm tính.',
                      ),
                    ),
                  );
                  return;
                }
                if (method != 'Cash' && transaction.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nhập mã tham chiếu giao dịch.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'discount': parsed,
                  'method': method,
                  'transactionCode': transaction.text.trim(),
                });
              },
              child: const Text('Xác nhận thu tiền'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    discount.dispose();
    transaction.dispose();
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await apiClient.dio.post(
        '/api/payments/orders/${order['id']}/checkout',
        data: {
          'paymentMethod': result['method'],
          'discount': result['discount'],
          'transactionCode': result['transactionCode'],
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã thanh toán'),
          content: const Text('Hóa đơn đã được tạo.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Xem hóa đơn'),
            ),
          ],
        ),
      );
      if (mounted) {
        await context.push('/invoices/order/${order['id']}');
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
      title: 'Thu ngân & Thanh toán',
      subtitle: 'Các order đã sẵn sàng hoặc đã phục vụ chờ xuất hóa đơn',
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
            title: 'Không tải được danh sách chờ thanh toán',
            subtitle: apiError(snap.error!),
          );
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return const EmptyStateView(
            icon: Icons.point_of_sale_outlined,
            title: 'Không có order cần thanh toán',
            subtitle:
                'Order sau khi báo "Món sẵn sàng" hoặc "Đã phục vụ" sẽ hiển thị tại đây.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final next = _load();
            setState(() {
              _future = next;
            });
            await next;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: orders.length,
            itemBuilder: (context, i) {
            final o = orders[i];
            final hasRequest =
                o['paymentRequest'] is Map &&
                (o['paymentRequest'] as Map)['status'] == 'PendingConfirmation';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE4DA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Bàn ${o['tableName']} • ${o['orderCode']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              if (o['status'] != null)
                                StatusPill(
                                  status: o['status'] as String,
                                  compact: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (o['customerName'] != null)
                                'Khách: ${o['customerName']}',
                              _money.format(o['totalAmount']),
                            ].join(' • '),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hasRequest) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Khách yêu cầu thanh toán${(o['paymentRequest'] as Map)['transactionCode'] == null ? '' : ' • Mã ${(o['paymentRequest'] as Map)['transactionCode']}'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFC85A17),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Mã QR thanh toán',
                      onPressed: () {
                        final sub =
                            ((o['subTotal'] ?? o['totalAmount']) as num)
                                .toDouble();
                        final totalWithVat = sub + (sub * 0.08).roundToDouble();
                        showPaymentQrDialog(
                          context,
                          orderCode: '${o['orderCode']}',
                          amount: totalWithVat,
                          tableName: '${o['tableName'] ?? ''}',
                        );
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _checkout(o),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: const Text('Thu tiền'),
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
