import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/session_state.dart';
import '../../services/app_services.dart';

String formatDateTime(Object? raw) {
  if (raw == null) return '';
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return raw.toString();
  return DateFormat('dd/MM/yyyy • HH:mm').format(parsed.toLocal());
}

class AppColors {
  static const primary = Color(0xFF6F3E26);
  static const primaryDark = Color(0xFF472617);
  static const accent = Color(0xFFC67C4E);
  static const background = Color(0xFFF6F2EC);
  static const surface = Color(0xFFFFFDF9);
  static const border = Color(0xFFE6DDD2);
  static const textPrimary = Color(0xFF2B1E16);
  static const textSecondary = Color(0xFF75675C);
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.fallbackRoute = '/dashboard',
    this.label = 'Trở lại',
  });

  final String fallbackRoute;
  final String label;

  void _handleTap(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 7, bottom: 7),
      child: Material(
        color: const Color(0xFFEDE4DA),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

PreferredSizeWidget buildAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  String fallbackRoute = '/dashboard',
  bool showBack = true,
  bool showNotifications = true,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: showBack ? 4 : 16,
    leadingWidth: showBack ? 104 : null,
    leading: showBack ? AppBackButton(fallbackRoute: fallbackRoute) : null,
    title: subtitle == null
        ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
    actions: [
      if (showNotifications && sessionState.user?.role == 'Admin')
        const NotificationBellButton(),
      ...?actions,
    ],
    bottom: bottom,
  );
}

(Color, Color, String, IconData) statusStyle(String status) {
  return switch (status) {
    'Available' => (
      const Color(0xFF1E7E48),
      const Color(0xFFE3F6EB),
      'Bàn trống',
      Icons.check_circle_outline_rounded,
    ),
    'Occupied' => (
      const Color(0xFFC85A17),
      const Color(0xFFFFEFE5),
      'Đang phục vụ',
      Icons.local_cafe_rounded,
    ),
    'Reserved' => (
      const Color(0xFF1D5B9E),
      const Color(0xFFE6F0FA),
      'Đã đặt trước',
      Icons.event_available_rounded,
    ),
    'Cleaning' => (
      const Color(0xFF5A6B7C),
      const Color(0xFFEBEEF2),
      'Đang dọn',
      Icons.cleaning_services_outlined,
    ),
    'Pending' => (
      const Color(0xFFB26B00),
      const Color(0xFFFFF4DE),
      'Chờ xác nhận',
      Icons.schedule_rounded,
    ),
    'Confirmed' => (
      const Color(0xFF1D5B9E),
      const Color(0xFFE6F0FA),
      'Đã xác nhận',
      Icons.thumb_up_alt_outlined,
    ),
    'Preparing' => (
      const Color(0xFFC85A17),
      const Color(0xFFFFEFE5),
      'Đang chế biến',
      Icons.soup_kitchen_outlined,
    ),
    'Ready' => (
      const Color(0xFF1E7E48),
      const Color(0xFFE3F6EB),
      'Món sẵn sàng',
      Icons.notifications_active_outlined,
    ),
    'Served' => (
      const Color(0xFF6B3FA0),
      const Color(0xFFF1EAFA),
      'Đã phục vụ',
      Icons.room_service_outlined,
    ),
    'Completed' => (
      const Color(0xFF1E7E48),
      const Color(0xFFE3F6EB),
      'Đã thanh toán',
      Icons.verified_outlined,
    ),
    'Cancelled' => (
      const Color(0xFFB42318),
      const Color(0xFFFEE4E2),
      'Đã hủy',
      Icons.cancel_outlined,
    ),
    'Seated' => (
      const Color(0xFF1E7E48),
      const Color(0xFFE3F6EB),
      'Khách đã nhận bàn',
      Icons.event_seat_rounded,
    ),
    'NoShow' => (
      const Color(0xFF7A271A),
      const Color(0xFFFEE4E2),
      'Không đến',
      Icons.person_off_outlined,
    ),
    'PendingConfirmation' => (
      const Color(0xFFB26B00),
      const Color(0xFFFFF4DE),
      'Chờ thu ngân xác nhận',
      Icons.hourglass_top_rounded,
    ),
    _ => (
      AppColors.primary,
      const Color(0xFFEDE4DA),
      status,
      Icons.info_outline_rounded,
    ),
  };
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.compact = false});
  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label, icon) = statusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE4DA),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

String defaultPaymentReference(Object? orderCode) {
  final raw = (orderCode?.toString() ?? 'ORDER').trim().replaceAll(' ', '');
  return raw.startsWith('BN-') ? raw : 'BN-$raw';
}

class PaymentQrCard extends StatelessWidget {
  const PaymentQrCard({
    super.key,
    required this.orderCode,
    required this.amount,
    this.tableName,
    this.compact = false,
  });

  final String orderCode;
  final num amount;
  final String? tableName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final refCode = defaultPaymentReference(orderCode);
    final qrSize = compact ? 156.0 : 188.0;
    final vietQrUrl =
        'https://img.vietqr.io/image/TCB-222277770005-qr_only.png'
        '?amount=${amount.round()}'
        '&addInfo=${Uri.encodeComponent(refCode)}'
        '&accountName=${Uri.encodeComponent('MAI QUANG THIEN')}';

    void copyText(String label, String value) {
      Clipboard.setData(ClipboardData(text: value));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã sao chép $label: $value')));
    }

    final fallbackQr = CustomPaint(
      size: Size.square(qrSize - 20),
      painter: _DeterministicQrPainter(
        data: 'VIETQR|TCB|222277770005|${amount.round()}|$refCode',
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'VIETQR • NAPAS 247',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    letterSpacing: 0.7,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          if (tableName != null && tableName!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Bàn $tableName • Đơn $orderCode',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: qrSize,
            height: qrSize,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D5C8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Image.network(
              vietQrUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallbackQr,
              errorBuilder: (context, error, stackTrace) => fallbackQr,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            money.format(amount),
            style: TextStyle(
              fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Techcombank (TCB) • MAI QUANG THIEN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.copy_rounded, size: 14),
                label: const Text(
                  'STK: 2222 7777 0005',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: () => copyText('số tài khoản', '222277770005'),
              ),
              ActionChip(
                avatar: const Icon(Icons.tag_rounded, size: 14),
                label: Text(
                  'Nội dung: $refCode',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => copyText('nội dung chuyển khoản', refCode),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showPaymentQrDialog(
  BuildContext context, {
  required String orderCode,
  required num amount,
  String? tableName,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Mã QR thanh toán • $orderCode'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: PaymentQrCard(
            orderCode: orderCode,
            amount: amount,
            tableName: tableName,
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

class _DeterministicQrPainter extends CustomPainter {
  const _DeterministicQrPainter({required this.data});

  final String data;

  bool _isFinder(int r, int c, int top, int left) {
    final dr = r - top;
    final dc = c - left;
    if (dr < 0 || dr > 6 || dc < 0 || dc > 6) return false;
    if (dr == 0 || dr == 6 || dc == 0 || dc == 6) return true;
    if (dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4) return true;
    return false;
  }

  bool _inFinderZone(int r, int c, int n) {
    return (r < 8 && c < 8) || (r < 8 && c >= n - 8) || (r >= n - 8 && c < 8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const n = 25;
    final cell = size.width / n;
    final dark = Paint()
      ..color = const Color(0xFF1F1610)
      ..style = PaintingStyle.fill;

    int hash = 2166136261;
    for (final codeUnit in data.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        bool on = false;
        if (_isFinder(r, c, 0, 0) ||
            _isFinder(r, c, 0, n - 7) ||
            _isFinder(r, c, n - 7, 0)) {
          on = true;
        } else if (!_inFinderZone(r, c, n)) {
          if (r == 6 || c == 6) {
            on = (r + c).isEven;
          } else if (r >= 16 && r <= 20 && c >= 16 && c <= 20) {
            final dr = r - 16;
            final dc = c - 16;
            on =
                dr == 0 ||
                dr == 4 ||
                dc == 0 ||
                dc == 4 ||
                (dr == 2 && dc == 2);
          } else {
            final idx = r * n + c;
            final v =
                ((hash >> (idx % 23)) ^
                    (data.codeUnitAt(idx % data.length) * (r + 3) * (c + 7))) &
                3;
            on = v == 0 || v == 2;
          }
        }
        if (on) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cell, r * cell, cell * 0.94, cell * 0.94),
              const Radius.circular(1.4),
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DeterministicQrPainter oldDelegate) =>
      oldDelegate.data != data;
}

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  static final Set<String> _seenEventKeys = <String>{};
  static final Set<String> _readEventKeys = <String>{};
  static int? _lastMemberId;
  static List<Map<String, dynamic>> _cachedItems = [];
  static Map<String, dynamic> _cachedSummary = const {};

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll(isInitial: _seenEventKeys.isEmpty);
    _timer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _poll(isInitial: false),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll({required bool isInitial}) async {
    final user = sessionState.user;
    if (user == null || user.role != 'Admin') return;
    if (_lastMemberId != user.id) {
      _lastMemberId = user.id;
      _seenEventKeys.clear();
      _readEventKeys.clear();
      _cachedItems = [];
      _cachedSummary = const {};
      isInitial = true;
    }
    try {
      final res = await apiClient.dio.get('/api/notifications');
      final data = Map<String, dynamic>.from(res.data as Map);
      final summary = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : const <String, dynamic>{};
      final items = (data['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      Map<String, dynamic>? newestUnseen;
      for (final item in items) {
        final key = '${item['eventKey']}';
        if (_seenEventKeys.add(key) && !isInitial) {
          newestUnseen ??= item;
        }
      }

      if (!mounted) return;
      setState(() {
        _cachedSummary = summary;
        _cachedItems = items;
      });

      if (newestUnseen != null && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        final title = '${newestUnseen['title']}';
        final msg = '${newestUnseen['message']}';
        final route = '${newestUnseen['route'] ?? ''}';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              backgroundColor: AppColors.primaryDark,
              content: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFFFD580),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          msg,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: route.isEmpty
                  ? null
                  : SnackBarAction(
                      label: 'Xem ngay',
                      textColor: const Color(0xFFFFD580),
                      onPressed: () {
                        if (mounted) context.push(route);
                      },
                    ),
            ),
          );
      }
    } catch (_) {
      // Ignore transient network errors during background polling.
    }
  }

  int get _badgeCount {
    final unread = _cachedItems
        .where((e) => !_readEventKeys.contains('${e['eventKey']}'))
        .length;
    final attention = (_cachedSummary['totalAttention'] as num?)?.toInt() ?? 0;
    return unread > 0 ? unread : attention;
  }

  Future<void> _openSheet() async {
    await _poll(isInitial: false);
    for (final item in _cachedItems) {
      _readEventKeys.add('${item['eventKey']}');
    }
    if (!mounted) return;
    setState(() {});

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final summary = _cachedSummary;
        final items = _cachedItems;
        final isStaff = sessionState.user?.role != 'Customer';
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE4DA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông báo hoạt động',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            isStaff
                                ? 'Cập nhật tức thì khi khách đặt bàn, gửi order, bếp báo món & thanh toán'
                                : 'Theo dõi trạng thái đơn hàng, bàn đặt và hóa đơn của bạn',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _openSheet();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              if (summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Color(0xFFB26B00),
                        ),
                        label: Text(
                          '${summary['pendingOrders'] ?? 0} order chờ xác nhận',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.event_available_rounded,
                          size: 16,
                          color: Color(0xFF1D5B9E),
                        ),
                        label: Text(
                          '${summary['pendingReservations'] ?? 0} lịch đặt bàn',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                          color: Color(0xFF1E7E48),
                        ),
                        label: Text(
                          '${summary['readyOrders'] ?? 0} đơn sẵn sàng',
                        ),
                      ),
                      if (isStaff)
                        Chip(
                          avatar: const Icon(
                            Icons.payments_outlined,
                            size: 16,
                            color: Color(0xFFC85A17),
                          ),
                          label: Text(
                            '${summary['pendingPayments'] ?? 0} chờ thu ngân',
                          ),
                        ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.notifications_none_rounded,
                        title: 'Chưa có thông báo nào',
                        subtitle:
                            'Khi có khách đặt bàn, gọi món hoặc yêu cầu thanh toán, thông báo sẽ xuất hiện tại đây.',
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(14),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final n = items[i];
                          final type = '${n['type']}';
                          final icon = switch (type) {
                            'Reservation' => Icons.event_seat_rounded,
                            'PaymentRequest' => Icons.qr_code_scanner_rounded,
                            _ => Icons.receipt_long_rounded,
                          };
                          final route = '${n['route'] ?? ''}';
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE4DA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: AppColors.primary),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${n['title']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  StatusPill(
                                    status: '${n['status']}',
                                    compact: true,
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${n['message']}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDateTime(n['createdAtUtc']),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: route.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      if (route == '/customer') {
                                        this.context.go('/customer');
                                      } else {
                                        this.context.push(route);
                                      }
                                    },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _badgeCount;
    return IconButton(
      tooltip: 'Thông báo hoạt động',
      onPressed: _openSheet,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
