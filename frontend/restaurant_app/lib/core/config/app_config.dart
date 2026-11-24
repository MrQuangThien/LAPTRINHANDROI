import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return Uri.base.origin;
    return defaultTargetPlatform == TargetPlatform.windows
        ? 'http://localhost:5000'
        : 'http://10.0.2.2:5000';
  }

  static const secureStorage = FlutterSecureStorage();
}
