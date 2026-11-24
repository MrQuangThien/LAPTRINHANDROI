import 'package:flutter/material.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../services/app_services.dart';

// The concise widget callbacks below follow the repository's existing lint policy.
// ignore_for_file: curly_braces_in_flow_control_structures

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});
  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String _search = '';
  String _groupFilter = 'All'; // All | Customer | StaffGroup
  String? _staffRoleFilter; // null | Admin | Staff | Kitchen | Cashier
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String? apiRole;
      if (_groupFilter == 'Customer') {
        apiRole = 'Customer';
      } else if (_groupFilter == 'StaffGroup') {
        apiRole = _staffRoleFilter ?? 'StaffGroup';
      }
      final m = await adminRepository.members(search: _search, role: apiRole);
      if (mounted) setState(() => _members = m);
    } catch (e) {
      if (mounted) {
        setState(() => _error = apiError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _form([Map<String, dynamic>? member]) async {
    List<String> roles;
    try {
      roles = await adminRepository.roles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được danh sách vai trò.')),
        );
      }
      return;
    }
    if (roles.isEmpty || !mounted) {
      return;
    }
    final full = TextEditingController(
          text: member?['fullName']?.toString() ?? '',
        ),
        email = TextEditingController(text: member?['email']?.toString() ?? ''),
        phone = TextEditingController(text: member?['phone']?.toString() ?? ''),
        password = TextEditingController();
    final isEditingAdmin = member?['role'] == 'Admin';
    String role = roles.contains(member?['role']?.toString())
        ? member!['role'].toString()
        : (roles.contains('Staff') ? 'Staff' : roles.first);
    String roleLabel(String r) => switch (r) {
      'Staff' => 'Staff — Nhân viên phục vụ',
      'Kitchen' => 'Kitchen — Nhân viên bếp / pha chế',
      'Cashier' => 'Cashier — Thu ngân',
      'Customer' => 'Customer — Khách hàng',
      _ => r,
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(member == null ? 'Thêm nhân viên' : 'Sửa thông tin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: full,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: member == null
                        ? 'Mật khẩu (ít nhất 10 ký tự)'
                        : 'Mật khẩu mới (để trống nếu giữ nguyên)',
                  ),
                ),
                if (!isEditingAdmin) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                    items: roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(roleLabel(r)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => role = v);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    final fullNameText = full.text.trim();
    final emailText = email.text.trim();
    final phoneText = phone.text.trim();
    final passwordText = password.text;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    full.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    if (saved != true) return;
    try {
      if (member == null) {
        await adminRepository.createMember({
          'fullName': fullNameText,
          'email': emailText,
          'phone': phoneText,
          'password': passwordText,
          'role': role,
        });
      } else {
        await adminRepository.updateMember(member['id'] as int, {
          'fullName': fullNameText,
          'email': emailText,
          'phone': phoneText,
          if (!isEditingAdmin) 'role': role,
          if (passwordText.isNotEmpty) 'password': passwordText,
        });
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Quản lý nhân viên',
      subtitle: 'Tài khoản, vai trò và trạng thái hoạt động',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _form(),
      icon: const Icon(Icons.person_add),
      label: const Text('Thêm nhân viên'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm tên, email hoặc số điện thoại',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              _search = v.trim();
              _load();
            },
            onSubmitted: (v) {
              _search = v.trim();
              _load();
            },
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final item in const [
                ('All', 'Tất cả'),
                ('Customer', 'Khách hàng (Customer)'),
                ('StaffGroup', 'Nhân viên'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: _groupFilter == item.$1,
                    onSelected: (_) {
                      setState(() {
                        _groupFilter = item.$1;
                        if (_groupFilter != 'StaffGroup') {
                          _staffRoleFilter = null;
                        }
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_groupFilter == 'StaffGroup')
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final r in const [
                  (null, 'Tất cả vị trí'),
                  ('Admin', 'Admin'),
                  ('Staff', 'Phục vụ (Staff)'),
                  ('Kitchen', 'Bếp (Kitchen)'),
                  ('Cashier', 'Thu ngân (Cashier)'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(r.$2),
                      selected: _staffRoleFilter == r.$1,
                      onSelected: (_) {
                        setState(() => _staffRoleFilter = r.$1);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _members.isEmpty
              ? const Center(child: Text('Chưa có nhân viên.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: _members.length,
                    itemBuilder: (c, i) {
                      final m = _members[i];
                      final active = m['isActive'] == true;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (m['fullName'] as String).isEmpty
                                  ? '?'
                                  : (m['fullName'] as String)
                                        .substring(0, 1)
                                        .toUpperCase(),
                            ),
                          ),
                          title: Text(m['fullName'] as String),
                          subtitle: Text(
                            '${m['email']} · ${m['role']}\n${m['phone']} · ${active ? 'Đang hoạt động' : 'Đã khóa'}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              try {
                                if (v == 'edit') {
                                  await _form(m);
                                } else {
                                  await adminRepository.setMemberActive(
                                    m['id'] as int,
                                    !active,
                                  );
                                  await _load();
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(apiError(e)),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (c) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Sửa thông tin'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  active ? 'Khóa tài khoản' : 'Mở khóa',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}
