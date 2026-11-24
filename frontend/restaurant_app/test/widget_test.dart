import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/screens/auth/login_screen.dart';

void main() {
  testWidgets('login screen shows username, password and submit controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Tên đăng nhập, email hoặc SĐT'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký tài khoản mới'), findsOneWidget);
  });
}
