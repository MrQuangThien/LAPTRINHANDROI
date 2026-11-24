import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/web_redirect.dart';
import '../../core/widgets/app_chrome.dart';
import '../../providers/session_state.dart';
import '../../services/app_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await authRepository.login(
        _identifier.text.trim(),
        _password.text,
      );
      sessionState.signIn(user);
      if (user.role == 'Customer') {
        if (mounted) context.go('/customer');
      } else {
        syncService.start();
        if (mounted) context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool step2 = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? infoMsg;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Quên mật khẩu'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: emailCtrl,
                    enabled: !step2,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email tài khoản',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  if (infoMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        infoMsg!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (step2) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mã OTP 6 số',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          tooltip: obscureNew ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setD(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Nhập lại mật khẩu mới',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip:
                              obscureConfirm ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setD(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (step2)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (!email.contains('@')) return;
                        setD(() => busy = true);
                        try {
                          final res = await authRepository.forgotPassword(email);
                          setD(() {
                            final otp = res['devOtpCode'];
                            infoMsg =
                                '${res['message']}${otp != null ? '\nMã OTP của bạn: $otp' : ''}';
                            if (otp != null) codeCtrl.text = '$otp';
                          });
                        } catch (e) {
                          setD(() => infoMsg = apiError(e));
                        } finally {
                          setD(() => busy = false);
                        }
                      },
                child: const Text('Gửi lại mã'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (!email.contains('@')) {
                        setD(() => infoMsg = 'Vui lòng nhập email hợp lệ.');
                        return;
                      }
                      setD(() => busy = true);
                      try {
                        if (!step2) {
                          final res = await authRepository.forgotPassword(email);
                          setD(() {
                            step2 = true;
                            final otp = res['devOtpCode'];
                            infoMsg =
                                '${res['message']}${otp != null ? '\nMã OTP của bạn: $otp' : ''}';
                            if (otp != null) codeCtrl.text = '$otp';
                          });
                        } else {
                          if (newPassCtrl.text.length < 6) {
                            setD(
                              () => infoMsg = 'Mật khẩu mới cần ít nhất 6 ký tự.',
                            );
                            return;
                          }
                          if (newPassCtrl.text != confirmPassCtrl.text) {
                            setD(
                              () => infoMsg = 'Mật khẩu nhập lại không khớp.',
                            );
                            return;
                          }
                          final res = await authRepository.resetPassword(
                            email: email,
                            code: codeCtrl.text.trim(),
                            newPassword: newPassCtrl.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('${res['message']}')),
                            );
                          }
                        }
                      } catch (e) {
                        setD(() => infoMsg = apiError(e));
                      } finally {
                        setD(() => busy = false);
                      }
                    },
              child: Text(step2 ? 'Đổi mật khẩu' : 'Gửi mã OTP'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    emailCtrl.dispose();
    codeCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  }

  Future<void> _openVerifyEmailDialog() async {
    final emailCtrl = TextEditingController(
      text: _identifier.text.contains('@') ? _identifier.text.trim() : '',
    );
    final codeCtrl = TextEditingController();
    bool codeSent = false;
    String? infoMsg;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Xác thực Email'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email cần xác thực',
                      prefixIcon: Icon(Icons.mark_email_read_outlined),
                    ),
                  ),
                  if (infoMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        infoMsg!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (codeSent) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mã xác thực 6 số',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (codeSent)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (!email.contains('@')) return;
                        setD(() => busy = true);
                        try {
                          final res = await authRepository.sendVerification(
                            email,
                          );
                          setD(() {
                            final otp = res['devOtpCode'];
                            infoMsg =
                                '${res['message']}${otp != null ? '\nMã xác thực: $otp' : ''}';
                            if (otp != null) codeCtrl.text = '$otp';
                          });
                        } catch (e) {
                          setD(() => infoMsg = apiError(e));
                        } finally {
                          setD(() => busy = false);
                        }
                      },
                child: const Text('Gửi lại mã'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (!email.contains('@')) {
                        setD(() => infoMsg = 'Nhập email hợp lệ.');
                        return;
                      }
                      setD(() => busy = true);
                      try {
                        if (!codeSent) {
                          final res = await authRepository.sendVerification(
                            email,
                          );
                          setD(() {
                            codeSent = true;
                            final otp = res['devOtpCode'];
                            infoMsg =
                                '${res['message']}${otp != null ? '\nMã xác thực: $otp' : ''}';
                            if (otp != null) codeCtrl.text = '$otp';
                          });
                        } else {
                          final res = await authRepository.verifyEmail(
                            email,
                            codeCtrl.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('${res['message']}')),
                            );
                          }
                        }
                      } catch (e) {
                        setD(() => infoMsg = apiError(e));
                      } finally {
                        setD(() => busy = false);
                      }
                    },
              child: Text(codeSent ? 'Xác nhận' : 'Gửi mã xác thực'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    emailCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _socialLogin(String provider) async {
    try {
      final providers = await authRepository.oauthProviders();
      final key = provider.toLowerCase();
      if (providers[key] == true) {
        if (kIsWeb) {
          final returnUrl = Uri.base.origin;
          redirectToUrl(
            '${AppConfig.apiBaseUrl}/api/auth/oauth/$key/start?returnUrl=${Uri.encodeComponent(returnUrl)}',
          );
          return;
        }
        final sessionId = const Uuid().v4();
        final url = Uri.parse(
          '${AppConfig.apiBaseUrl}/api/auth/oauth/$key/start?desktopSessionId=$sessionId',
        );
        final launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không thể mở trình duyệt cho $provider.')),
            );
          }
          return;
        }
        if (!mounted) return;
        Timer? timer;
        var cancelled = false;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            timer ??= Timer.periodic(const Duration(seconds: 2), (t) async {
              if (cancelled) {
                t.cancel();
                return;
              }
              try {
                final user = await authRepository.pollDesktopOAuth(sessionId);
                if (user != null) {
                  t.cancel();
                  sessionState.signIn(user);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                  if (mounted) {
                    context.go(
                      user.role == 'Customer' ? '/customer' : '/dashboard',
                    );
                  }
                }
              } catch (_) {}
            });
            return AlertDialog(
              title: Text('Đăng nhập bằng $provider'),
              content: const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Vui lòng hoàn tất đăng nhập trên trình duyệt vừa mở...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    timer?.cancel();
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Hủy'),
                ),
              ],
            );
          },
        );
        cancelled = true;
        timer?.cancel();
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    final sampleEmail = switch (provider) {
      'Google' => 'khach.gmail@gmail.com',
      'Facebook' => 'khach.fb@facebook.com',
      _ => 'khach.zalo@zalo.me',
    };
    final sampleName = switch (provider) {
      'Google' => 'Khách hàng Google',
      'Facebook' => 'Khách hàng Facebook',
      _ => 'Khách hàng Zalo',
    };
    final emailCtrl = TextEditingController(text: sampleEmail);
    final nameCtrl = TextEditingController(text: sampleName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Đăng nhập bằng $provider'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ tên hiển thị',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: provider == 'Google'
                      ? 'Địa chỉ Gmail'
                      : 'Email liên kết $provider',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Tiếp tục với $provider'),
          ),
        ],
      ),
    );
    final email = emailCtrl.text.trim();
    final name = nameCtrl.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    emailCtrl.dispose();
    nameCtrl.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final user = await authRepository.socialLogin(
        provider: provider,
        email: email,
        fullName: name.isEmpty ? sampleName : name,
      );
      sessionState.signIn(user);
      if (mounted) context.go('/customer');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 28,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Bếp Nhà',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hệ thống quản lý nhà hàng & quán cà phê',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Đăng nhập dành cho Khách hàng & Nhân viên quán',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _identifier,
                          decoration: const InputDecoration(
                            labelText: 'Tên đăng nhập, email hoặc SĐT',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nhập tên đăng nhập, email hoặc SĐT'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Đăng nhập'),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton(
                              onPressed: _openForgotPasswordDialog,
                              child: const Text('Quên mật khẩu?'),
                            ),
                            TextButton(
                              onPressed: _openVerifyEmailDialog,
                              child: const Text('Xác thực Email'),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: const Text('Đăng ký tài khoản mới'),
                        ),
                        const Divider(height: 22),
                        const Text(
                          'Hoặc đăng nhập nhanh qua mạng xã hội',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _socialLogin('Google'),
                                icon: const Icon(
                                  Icons.g_mobiledata_rounded,
                                  color: Color(0xFFDB4437),
                                ),
                                label: const Text('Gmail'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _socialLogin('Facebook'),
                                icon: const Icon(
                                  Icons.facebook_rounded,
                                  color: Color(0xFF1877F2),
                                ),
                                label: const Text('Facebook'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _socialLogin('Zalo'),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Color(0xFF0068FF),
                                  size: 18,
                                ),
                                label: const Text('Zalo'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/customer'),
                          icon: const Icon(Icons.home_rounded),
                          label: const Text(
                            'Vào Trang chủ Nhà hàng (Thực đơn, Blog & Đặt bàn)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
