import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_state.dart';
import '../../services/app_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = await authRepository.restore();
    if (!mounted) return;
    if (user != null) {
      sessionState.signIn(user);
      if (user.role == 'Customer') {
        context.go('/customer');
      } else {
        syncService.start();
        context.go('/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
