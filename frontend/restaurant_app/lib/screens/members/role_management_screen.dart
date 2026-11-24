import 'package:flutter/material.dart';

import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});
  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  late Future<List<Map<String, dynamic>>> _roles;
  @override
  void initState() {
    super.initState();
    _roles = adminRepository.roleDetails();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Vai trò và quyền hạn',
      subtitle: 'Danh sách phân quyền trong hệ thống',
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _roles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.lock_outline_rounded,
            title: 'Không tải được vai trò',
            subtitle: 'Hãy đăng nhập bằng tài khoản Admin.',
            action: OutlinedButton(
              onPressed: () => setState(() {
                _roles = adminRepository.roleDetails();
              }),
              child: const Text('Thử lại'),
            ),
          );
        }
        final roles = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: Color(0xFFFFF8F2),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vai trò được cấu hình cố định để bảo vệ quyền quản trị. Gán vai trò nhân viên tại màn hình Quản lý nhân viên.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final role in roles)
              Card(
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE4DA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(switch (role['name']) {
                      'Admin' => Icons.admin_panel_settings_outlined,
                      'Cashier' => Icons.point_of_sale_outlined,
                      'Kitchen' => Icons.soup_kitchen_outlined,
                      'Customer' => Icons.person_outline_rounded,
                      _ => Icons.restaurant_outlined,
                    }, color: AppColors.primary),
                  ),
                  title: Text(
                    switch (role['name']) {
                      'Admin' => 'Quản trị viên (Admin)',
                      'Staff' => 'Nhân viên phục vụ (Staff)',
                      'Cashier' => 'Thu ngân (Cashier)',
                      'Kitchen' => 'Nhân viên bếp (Kitchen)',
                      'Customer' => 'Khách hàng (Customer)',
                      _ => '${role['name']}',
                    },
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    switch (role['name']) {
                      'Admin' => 'Quản trị hệ thống và phân quyền nhân viên',
                      'Staff' => 'Nhân viên phục vụ bàn và tiếp nhận gọi món',
                      'Cashier' => 'Thu ngân, xuất hóa đơn và xác nhận thanh toán',
                      'Kitchen' => 'Nhân viên bếp / pha chế xử lý món',
                      'Customer' => 'Tài khoản khách hàng đặt bàn và gọi món',
                      _ => role['description'] as String? ?? '',
                    },
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
