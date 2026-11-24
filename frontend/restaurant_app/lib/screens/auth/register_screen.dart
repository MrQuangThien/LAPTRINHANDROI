import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../providers/session_state.dart';
import '../../services/app_services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final user = await authRepository.register(
        fullName: _name.text.trim(),
        email: email,
        phone: _phone.text.trim(),
        password: _password.text,
        role: 'Customer',
      );
      sessionState.signIn(user);
      if (!mounted) return;
      String? demoCode;
      try {
        final res = await authRepository.sendVerification(email);
        demoCode = (res['devOtpCode'] ?? res['demoCode'])?.toString();
      } catch (_) {}
      if (mounted) {
        await _showVerifyEmailDialog(email, demoCode);
      }
      if (mounted) context.go('/customer');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showVerifyEmailDialog(String email, String? initialCode) async {
    final codeCtrl = TextEditingController(text: initialCode ?? '');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var submitting = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Xác thực Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã OTP xác thực đã được gửi tới $email.',
                  style: const TextStyle(fontSize: 13),
                ),
                if (initialCode != null && initialCode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Mã demo: $initialCode',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Mã OTP (6 số)',
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim();
                        if (code.isEmpty) {
                          setDialogState(() => errorText = 'Vui lòng nhập mã OTP.');
                          return;
                        }
                        setDialogState(() {
                          submitting = true;
                          errorText = null;
                        });
                        try {
                          await authRepository.verifyEmail(email, code);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Xác thực Email thành công!')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            submitting = false;
                            errorText = apiError(e);
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Xác nhận'),
              ),
            ],
          ),
        );
      },
    );
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Đăng ký tài khoản Khách hàng',
      subtitle: 'Dành cho khách hàng đặt bàn, gọi món & xem Blog nhà hàng',
      fallbackRoute: '/login',
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'Nhập họ tên'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Email chưa hợp lệ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => v == null || v.trim().length < 7
                          ? 'Số điện thoại chưa hợp lệ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu (tối thiểu 10 ký tự)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v == null || v.length < 10
                          ? 'Mật khẩu cần ít nhất 10 ký tự'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loading ? null : _register,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Đăng ký tài khoản khách hàng'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
