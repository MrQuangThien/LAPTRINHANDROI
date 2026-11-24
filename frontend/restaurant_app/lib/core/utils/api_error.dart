import 'package:dio/dio.dart';

String apiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      if (data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return data['message'] as String;
      }
      if (data['errors'] is Map) {
        final errors = data['errors'] as Map;
        final messages = <String>[];
        for (final value in errors.values) {
          if (value is List) {
            messages.addAll(value.map((e) => e.toString()));
          } else if (value != null) {
            messages.add(value.toString());
          }
        }
        if (messages.isNotEmpty) {
          return messages.join(' ');
        }
      }
      if (data['title'] is String &&
          (data['title'] as String).trim().isNotEmpty) {
        return data['title'] as String;
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ API.';
    }
    return 'Yêu cầu thất bại (${error.response?.statusCode ?? 'mạng'}).';
  }
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}
