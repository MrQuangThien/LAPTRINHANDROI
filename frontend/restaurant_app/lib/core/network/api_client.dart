import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../providers/session_state.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Accept': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
            ),
          ),
      _storage = storage ?? AppConfig.secureStorage {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/api/auth/login')) {
            await _storage.delete(key: 'jwt');
            await _storage.delete(key: 'session_user');
            if (sessionState.user != null) {
              sessionState.signOut();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;
  Dio get dio => _dio;
}
