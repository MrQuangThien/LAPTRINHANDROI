import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../providers/session_state.dart';
import '../../services/app_services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pending = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final count = await localDatabase.pendingCount();
    if (mounted) setState(() => _pending = count);
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final count = await syncService.flush();
    await _loadQueue();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Đã đồng bộ $count đơn.'
                : 'Không có đơn nào được đồng bộ.',
          ),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới (tối thiểu 10 ký tự)',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
                validator: (v) => v == null || v.length < 10
                    ? 'Mật khẩu mới cần ít nhất 10 ký tự'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
    final currentPassword = currentCtrl.text;
    final newPassword = newCtrl.text;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    currentCtrl.dispose();
    newCtrl.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await apiClient.dio.post(
        '/api/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đổi mật khẩu thành công.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = sessionState.user!;
    final tiles = <(IconData, String, String, String, Color)>[];
    if (user.role != 'Kitchen') {
      tiles.addAll([
        (
          Icons.table_restaurant_rounded,
          'Bàn phục vụ',
          'Mở bàn, gọi món, chuyển/gộp bàn',
          '/tables',
          const Color(0xFF1E7E48),
        ),
        (
          Icons.restaurant_menu_rounded,
          'Thực đơn',
          'Tra cứu món ăn & thức uống',
          '/menu',
          const Color(0xFF8B4C2F),
        ),
        (
          Icons.receipt_long_outlined,
          'Đơn hàng',
          'Theo dõi & xác nhận trạng thái đơn',
          '/orders',
          const Color(0xFF1D5B9E),
        ),
      ]);
    }
    if (user.role == 'Admin' || user.role == 'Staff') {
      tiles.addAll([
        (
          Icons.event_available_outlined,
          'Đặt bàn khách',
          'Quản lý lịch hẹn giữ chỗ của khách',
          '/reservations',
          const Color(0xFF0E7490),
        ),
        (
          Icons.home_work_outlined,
          'Trang chủ Khách & Blog',
          'Trang chủ nhà hàng, bài viết blog & đặt món',
          '/customer',
          const Color(0xFF8B4C2F),
        ),
      ]);
    }
    if (user.role == 'Admin' || user.role == 'Kitchen') {
      tiles.add((
        Icons.soup_kitchen_rounded,
        'Màn hình bếp',
        'Nhận chế biến & báo món sẵn sàng',
        '/kitchen',
        const Color(0xFFC85A17),
      ));
    }
    if (user.role == 'Admin' || user.role == 'Cashier') {
      tiles.addAll([
        (
          Icons.point_of_sale_rounded,
          'Thanh toán',
          'Thu tiền, tính giảm giá & xuất hóa đơn',
          '/payments',
          const Color(0xFF6B3FA0),
        ),
        (
          Icons.insights_rounded,
          'Báo cáo',
          'Doanh thu ngày, tháng & món bán chạy',
          '/reports',
          const Color(0xFFB26B00),
        ),
      ]);
    }
    if (user.role == 'Admin') {
      tiles.addAll([
        (
          Icons.category_outlined,
          'Danh mục',
          'Thêm, sửa, xóa nhóm thực đơn',
          '/admin/categories',
          const Color(0xFF6F3E26),
        ),
        (
          Icons.inventory_2_outlined,
          'Quản lý món',
          'Cập nhật giá bán, hình ảnh & trạng thái',
          '/admin/products',
          const Color(0xFF6F3E26),
        ),
        (
          Icons.meeting_room_outlined,
          'Khu vực và bàn',
          'Thiết lập sơ đồ khu vực & sức chứa bàn',
          '/admin/areas',
          const Color(0xFF6F3E26),
        ),
        (
          Icons.groups_outlined,
          'Nhân viên',
          'Tài khoản & trạng thái làm việc',
          '/admin/members',
          const Color(0xFF6F3E26),
        ),
        (
          Icons.admin_panel_settings_outlined,
          'Vai trò',
          'Danh mục phân quyền hệ thống',
          '/admin/roles',
          const Color(0xFF6F3E26),
        ),
      ]);
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_cafe_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Trang chủ · Bếp Nhà'),
          ],
        ),
        actions: [
          if (sessionState.user?.role == 'Admin')
            const NotificationBellButton(),
          TextButton.icon(
            onPressed: () => context.push('/customer'),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Trang chủ Khách'),
          ),
          IconButton(
            tooltip: 'Đồng bộ đơn offline',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Badge(
                    isLabelVisible: _pending > 0,
                    label: Text('$_pending'),
                    child: const Icon(Icons.sync_rounded),
                  ),
          ),
          IconButton(
            tooltip: 'Đổi mật khẩu',
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_reset_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () async {
                syncService.dispose();
                await authRepository.logout();
                sessionState.signOut();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Đăng xuất'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, Color(0xFF8B5637)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1E472617),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'CA LÀM VIỆC • ${user.role.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Xin chào, ${user.fullName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.email,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
              if (_pending > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFFFF4DE),
                  child: ListTile(
                    leading: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Color(0xFFB26B00),
                    ),
                    title: Text(
                      '$_pending đơn offline đang chờ đồng bộ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Đơn sẽ tự gửi lại khi máy chủ kết nối được.',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _syncing ? null : _sync,
                      child: const Text('Đồng bộ ngay'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phân hệ nghiệp vụ',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Chạm vào từng chức năng để thao tác',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tiles.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 920
                      ? 4
                      : MediaQuery.sizeOf(context).width > 620
                      ? 3
                      : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 148,
                ),
                itemBuilder: (context, i) {
                  final tile = tiles[i];
                  final accent = tile.$5;
                  return Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await context.push(tile.$4);
                        _loadQueue();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(tile.$1, size: 24, color: accent),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 15,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tile.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tile.$3,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
