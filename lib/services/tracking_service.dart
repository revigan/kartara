import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/tracking_info.dart';

/// Service untuk komunikasi dengan backend tracking API
class TrackingService {
  static TrackingService? _instance;
  late final Dio _dio;

  TrackingService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: AppConfig.defaultHeaders,
    ));
  }

  factory TrackingService() {
    _instance ??= TrackingService._();
    return _instance!;
  }

  /// Ambil info tracking pesanan lengkap (status, kurir, timeline)
  Future<OrderTrackingInfo?> getOrderTracking(String orderId) async {
    try {
      final response = await _dio.get('/tracking/$orderId');
      if (response.data?['success'] == true) {
        return OrderTrackingInfo.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Ambil posisi kurir terkini (dipanggil setiap 5 detik)
  Future<CourierLocationData?> getCourierLocation(String orderId) async {
    try {
      final response = await _dio.get('/tracking/$orderId/courier-location');
      if (response.data?['success'] == true) {
        return CourierLocationData.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tandai pesanan selesai (diterima oleh pembeli)
  Future<bool> markOrderCompleted(String orderId) async {
    try {
      final response = await _dio.post('/tracking/$orderId/complete');
      return response.data?['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
