import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    (await apiClient.dio.get('/api/invoices/by-order/${widget.orderId}')).data
        as Map,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Hóa đơn thanh toán',
      subtitle: 'Chi tiết phiếu thu & món đã dùng',
      fallbackRoute: '/payments',
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline_rounded,
            title: 'Không tải được hóa đơn',
            subtitle: apiError(snap.error!),
          );
        }
        final invoice = snap.data!;
        final money = NumberFormat.currency(
          locale: 'vi_VN',
          symbol: '₫',
          decimalDigits: 0,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'BẾP NHÀ • PHIẾU THANH TOÁN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const StatusPill(
                              status: 'Completed',
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${invoice['invoiceCode']}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Order: ${invoice['orderCode']} • Bàn ${invoice['table']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Phụ trách: ${invoice['cashier']}${invoice['customerName'] != null ? ' • Khách: ${invoice['customerName']}' : ''} • ${formatDateTime(invoice['createdAt'])}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(height: 28),
                        const Text(
                          'CHI TIẾT MÓN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final raw in invoice['items'] as List)
                          Builder(
                            builder: (context) {
                              final item = Map<String, dynamic>.from(
                                raw as Map,
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  item['product'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item['quantity']} × ${money.format(item['unitPrice'])}',
                                ),
                                trailing: Text(
                                  money.format(item['totalPrice']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        const Divider(height: 24),
                        if (invoice['subTotal'] != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tạm tính',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                money.format(invoice['subTotal']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (((invoice['discount'] as num?) ?? 0) > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Giảm giá',
                                style: TextStyle(
                                  color: Color(0xFF1E7E48),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '-${money.format(invoice['discount'])}',
                                style: const TextStyle(
                                  color: Color(0xFF1E7E48),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (((invoice['tax'] as num?) ?? 0) > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Thuế VAT',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                money.format(invoice['tax']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tổng thanh toán',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              money.format(invoice['totalAmount']),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        PaymentQrCard(
                          orderCode: '${invoice['orderCode']}',
                          amount: (invoice['totalAmount'] as num?) ?? 0,
                          tableName: '${invoice['table'] ?? ''}',
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lịch sử giao dịch',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        for (final raw in invoice['payments'] as List)
                          Builder(
                            builder: (context) {
                              final p = Map<String, dynamic>.from(raw as Map);
                              final methodLabel = switch (p['paymentMethod']) {
                                'Cash' => 'Tiền mặt',
                                'BankTransfer' => 'Chuyển khoản',
                                'VietQR' => 'VietQR',
                                _ => '${p['paymentMethod']}',
                              };
                              final txCode =
                                  (p['transactionCode'] as String? ?? '')
                                      .trim();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF1E7E48),
                                ),
                                title: Text(
                                  methodLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  txCode.isEmpty
                                      ? formatDateTime(p['paymentDate'])
                                      : '${formatDateTime(p['paymentDate'])} • Mã GD: $txCode',
                                ),
                                trailing: Text(
                                  money.format(p['amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
