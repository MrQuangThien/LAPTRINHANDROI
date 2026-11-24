import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class ReservationManagementScreen extends StatefulWidget {
  const ReservationManagementScreen({super.key});
  @override
  State<ReservationManagementScreen> createState() =>
      _ReservationManagementScreenState();
}

class _ReservationManagementScreenState
    extends State<ReservationManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await apiClient.dio.get('/api/customer/reservations');
    return (response.data as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  Future<void> _setStatus(int id, String status) async {
    setState(() => _busy = true);
    try {
      await apiClient.dio.patch(
        '/api/customer/reservations/$id/status',
        data: {'status': status},
      );
      if (mounted) setState(() => _future = _load());
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
      title: 'Đặt bàn của khách',
      subtitle: 'Danh sách lịch hẹn giữ chỗ trong 30 ngày tới',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => setState(() => _future = _load()),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline_rounded,
            title: 'Không tải được lịch đặt bàn',
            subtitle: apiError(snapshot.error!),
            action: OutlinedButton(
              onPressed: () => setState(() => _future = _load()),
              child: const Text('Thử lại'),
            ),
          );
        }
        final reservations = snapshot.data ?? [];
        if (reservations.isEmpty) {
          return const EmptyStateView(
            icon: Icons.event_seat_outlined,
            title: 'Không có lượt đặt bàn trong 30 ngày tới',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final next = _load();
            setState(() => _future = next);
            await next;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final row = reservations[index];
              final status = row['status'] as String;
              final start = DateTime.parse(row['startsAtUtc'].toString())
                  .toLocal();
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE4DA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_seat_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    '${row['customerName']} • ${row['table']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${row['customerPhone']} • ${row['partySize']} khách\n${DateFormat('dd/MM/yyyy • HH:mm').format(start)}${(row['note'] as String? ?? '').isEmpty ? '' : '\nGhi chú: ${row['note']}'}',
                  ),
                  isThreeLine: true,
                  trailing:
                      (status == 'Confirmed' || status == 'Seated') && !_busy
                      ? PopupMenuButton<String>(
                          tooltip: 'Cập nhật trạng thái',
                          onSelected: (value) =>
                              _setStatus(row['id'] as int, value),
                          child: StatusPill(
                            status: status,
                            compact: true,
                          ),
                          itemBuilder: (_) => [
                            if (status == 'Confirmed')
                              const PopupMenuItem(
                                value: 'Seated',
                                child: Text('Khách đã đến'),
                              ),
                            const PopupMenuItem(
                              value: 'Cancelled',
                              child: Text('Hủy đặt bàn'),
                            ),
                            if (status == 'Confirmed')
                              const PopupMenuItem(
                                value: 'NoShow',
                                child: Text('Khách không đến'),
                              ),
                          ],
                        )
                      : StatusPill(status: status, compact: true),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
