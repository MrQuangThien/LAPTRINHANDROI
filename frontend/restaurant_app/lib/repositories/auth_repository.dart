import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/session_user.dart';

class AuthRepository {
  AuthRepository(this._api, {FlutterSecureStorage? storage})
    : _storage = storage ?? AppConfig.secureStorage;
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<SessionUser> login(String identifier, String password) async {
    final response = await _api.dio.post(
      '/api/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    return _saveSession(Map<String, dynamic>.from(response.data as Map));
  }

  Future<SessionUser> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'Customer',
  }) async {
    final response = await _api.dio.post(
      '/api/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      },
    );
    return _saveSession(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> sendVerification(String email) async {
    final response = await _api.dio.post(
      '/api/auth/send-verification',
      data: {'email': email},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final response = await _api.dio.post(
      '/api/auth/verify-email',
      data: {'email': email, 'code': code},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _api.dio.post(
      '/api/auth/forgot-password',
      data: {'email': email},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _api.dio.post(
      '/api/auth/reset-password',
      data: {'email': email, 'code': code, 'newPassword': newPassword},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<SessionUser> socialLogin({
    required String provider,
    required String email,
    required String fullName,
    String? phone,
  }) async {
    final response = await _api.dio.post(
      '/api/auth/social-login',
      data: {
        'provider': provider,
        'email': email,
        'fullName': fullName,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return _saveSession(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, bool>> oauthProviders() async {
    final response = await _api.dio.get('/api/auth/oauth/providers');
    final map = Map<String, dynamic>.from(response.data as Map);
    return {
      'google': map['google'] == true,
      'facebook': map['facebook'] == true,
      'zalo': map['zalo'] == true,
    };
  }

  Future<SessionUser> exchangeOAuthCode(String exchangeCode) async {
    final response = await _api.dio.post(
      '/api/auth/oauth/exchange',
      data: {'exchangeCode': exchangeCode},
    );
    return _saveSession(Map<String, dynamic>.from(response.data as Map));
  }

  Future<SessionUser?> pollDesktopOAuth(String sessionId) async {
    final response = await _api.dio.get(
      '/api/auth/oauth/desktop-poll/$sessionId',
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['completed'] == true && data['auth'] is Map) {
      return _saveSession(Map<String, dynamic>.from(data['auth'] as Map));
    }
    return null;
  }

  Future<SessionUser> _saveSession(Map<String, dynamic> json) async {
    await _storage.write(key: 'jwt', value: json['token'] as String);
    final user = SessionUser.fromJson(json);
    await _storage.write(
      key: 'session_user',
      value: jsonEncode({
        'id': user.id,
        'fullName': user.fullName,
        'email': user.email,
        'role': user.role,
      }),
    );
    return user;
  }

  Future<SessionUser?> restore() async {
    if (await _storage.read(key: 'jwt') == null) return null;
    try {
      final response = await _api.dio.get('/api/auth/me');
      final data = Map<String, dynamic>.from(response.data as Map);
      await _storage.write(key: 'session_user', value: jsonEncode(data));
      return SessionUser.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _clearSession();
        return null;
      }
      final cached = await _storage.read(key: 'session_user');
      if (cached != null) {
        return SessionUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/api/auth/logout');
    } on DioException {
      /* Clear local session even when offline. */
    }
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'session_user');
  }
}
