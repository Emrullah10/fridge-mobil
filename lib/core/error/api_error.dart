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

/// Backend {error:{code,...}} gövdesindeki makine-okunur kodu döner —
/// paywall/kilit UI'ı bunu ayırt etmek için kullanır (SIGNUP_REQUIRED,
/// PLAN_LIMIT_REACHED, PLAN_FEATURE_LOCKED, RATE_LIMITED, AI_DISABLED vb.).
/// describeApiError sadece kullanıcıya gösterilecek METNİ okuyordu, kodu
/// hiç okumuyordu — paywall_controller.dart bu ayrımı yapamıyordu.
String? apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final code = data['error']['code'];
      if (code is String && code.isNotEmpty) return code;
    }
  }
  return null;
}

/// 402 gövdesindeki plan/kota bilgisini taşır — paywall sheet'i "hangi
/// özellik, ne zaman sıfırlanır, hangi plana geçmen lazım" gösterebilsin.
class PlanLimitInfo {
  const PlanLimitInfo({
    required this.code,
    required this.message,
    this.plan,
    this.feature,
    this.limit,
    this.used,
    this.resetsAt,
    this.upgradeAvailable = true,
  });

  final String code;
  final String message;
  final String? plan;
  final String? feature;
  final int? limit;
  final int? used;
  final DateTime? resetsAt;
  final bool upgradeAvailable;

  /// error 402 bir DioException'sa PlanLimitInfo'yu ayrıştırır, değilse null
  /// döner — çağıran (api_client.dart interceptor'ı, paywall tetikleyicileri)
  /// bunu `if (info != null)` ile kapı olarak kullanır.
  static PlanLimitInfo? tryParse(Object error) {
    if (error is! DioException) return null;
    if (error.response?.statusCode != 402) return null;
    final data = error.response?.data;
    if (data is! Map || data['error'] is! Map) return null;
    final errorMap = data['error'] as Map;
    final code = errorMap['code'];
    if (code is! String) return null;
    return PlanLimitInfo(
      code: code,
      message: errorMap['message'] as String? ?? 'Bu işlem için plan sınırına ulaşıldı.',
      plan: data['plan'] as String?,
      feature: data['feature'] as String?,
      limit: (data['limit'] as num?)?.toInt(),
      used: (data['used'] as num?)?.toInt(),
      resetsAt: data['resetsAt'] is String ? DateTime.tryParse(data['resetsAt'] as String) : null,
      upgradeAvailable: data['upgradeAvailable'] as bool? ?? true,
    );
  }
}
