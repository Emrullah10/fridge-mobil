import 'package:dio/dio.dart';

/// Backend {error:{code,message}} gövdesini okuyup kullanıcıya gösterilebilir
/// bir mesaja çevirir. Bu olmadan kullanıcı ham "DioException [bad response]:
/// 422" gibi teknik metinler görüyordu.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = data['error']['message'];
      if (message is String && message.isNotEmpty) return message;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Sunucuya ulaşılamadı, bağlantını kontrol et.';
      case DioExceptionType.connectionError:
        return 'İnternet bağlantısı yok veya sunucuya erişilemiyor.';
      default:
        return 'Bir şeyler ters gitti (${error.response?.statusCode ?? 'bağlantı hatası'}).';
    }
  }
  return error.toString();
}
