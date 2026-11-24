import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<Map<String, dynamic>> _future;
  String _groupBy = 'day';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      apiClient.dio.get('/api/reports/dashboard'),
      apiClient.dio.get(
        '/api/reports/revenue',
        queryParameters: {'groupBy': _groupBy},
      ),
      apiClient.dio.get('/api/reports/order-statuses'),
    ]);
    final dash = Map<String, dynamic>.from(results[0].data as Map);
    dash['revenueSeries'] = (results[1].data as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    dash['orderStatuses'] = (results[2].data as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    return dash;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Báo cáo & Thống kê',
      subtitle: 'Tổng hợp doanh thu và hiệu suất phục vụ hôm nay',
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
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline_rounded,
            title: 'Không tải được báo cáo',
            subtitle: apiError(snap.error!),
          );
        }
        final d = snap.data!;
        final money = NumberFormat.currency(
          locale: 'vi_VN',
          symbol: '₫',
          decimalDigits: 0,
        );
        final stats = <(String, String, IconData, Color)>[
          (
            'Doanh thu hôm nay',
            money.format(d['todayRevenue']),
            Icons.payments_outlined,
            const Color(0xFF1E7E48),
          ),
          (
            'Doanh thu tháng',
            money.format(d['monthRevenue']),
            Icons.calendar_month_outlined,
            const Color(0xFF1D5B9E),
          ),
          (
            'Order hôm nay',
            '${d['todayOrders']}',
            Icons.receipt_long_outlined,
            const Color(0xFF8B4C2F),
          ),
          (
            'Món đã bán',
            '${d['soldItemsToday']}',
            Icons.restaurant_outlined,
            const Color(0xFFC85A17),
          ),
          (
            'Bàn đang phục vụ',
            '${d['occupiedTables']}',
            Icons.table_restaurant_outlined,
            const Color(0xFF6B3FA0),
          ),
          (
            'Bàn còn trống',
            '${d['availableTables']}',
            Icons.event_seat_outlined,
            const Color(0xFF0E7490),
          ),
        ];
        final top = (d['topProducts'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        final revenueSeries = (d['revenueSeries'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        final orderStatuses = (d['orderStatuses'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 680
                        ? 3
                        : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 132,
                  ),
                  itemBuilder: (context, i) {
                    final s = stats[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: s.$4.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(s.$3, color: s.$4, size: 22),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.$1,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Thống kê doanh thu',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Theo ngày'),
                          selected: _groupBy == 'day',
                          onSelected: (_) => setState(() {
                            _groupBy = 'day';
                            _future = _load();
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Theo tháng'),
                          selected: _groupBy == 'month',
                          onSelected: (_) => setState(() {
                            _groupBy = 'month';
                            _future = _load();
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (revenueSeries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Chưa có giao dịch thanh toán trong kỳ thống kê.',
                      ),
                    ),
                  )
                else
                  for (final row in revenueSeries.reversed)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.stacked_line_chart_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          _groupBy == 'month'
                              ? DateFormat('MM/yyyy').format(
                                  DateTime.parse('${row['date']}'),
                                )
                              : DateFormat('dd/MM/yyyy').format(
                                  DateTime.parse('${row['date']}'),
                                ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${row['orders']} đơn thanh toán'),
                        trailing: Text(
                          money.format(row['revenue']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E7E48),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                if (orderStatuses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Trạng thái đơn hàng toàn hệ thống',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final st in orderStatuses)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusPill(
                                  status: '${st['status']}',
                                  compact: true,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${st['count']} đơn',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Top 5 món bán chạy nhất',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (top.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Chưa có dữ liệu bán hàng hoàn tất.'),
                    ),
                  ),
                for (var idx = 0; idx < top.length; idx++)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEDE4DA),
                        foregroundColor: AppColors.primaryDark,
                        child: Text(
                          '#${idx + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        top[idx]['productName'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('Đã bán: ${top[idx]['quantity']} phần'),
                      trailing: Text(
                        money.format(top[idx]['revenue']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontSize: 15,
                        ),
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
