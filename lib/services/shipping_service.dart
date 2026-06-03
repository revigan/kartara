import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../widgets/shipping_cost_card.dart';

/// Result dari kalkulasi ongkir backend
class ShippingCalculationResult {
  final bool success;
  final String source; // 'biteship_live', 'biteship_fallback', 'smart_calculation'
  final String? destination;
  final int? distanceKm;
  final String? zone;
  final String? zoneLabel;
  final List<ShippingCourier> couriers;
  final String? error;

  const ShippingCalculationResult({
    required this.success,
    required this.source,
    this.destination,
    this.distanceKm,
    this.zone,
    this.zoneLabel,
    required this.couriers,
    this.error,
  });

  bool get isBiteshipLive => source == 'biteship_api' || source == 'biteship_live';
  bool get isEmpty => couriers.isEmpty;
}

class PostalCodeInfo {
  final String postalCode;
  final String city;
  final String province;
  final int distanceKm;
  final String origin;

  const PostalCodeInfo({
    required this.postalCode,
    required this.city,
    required this.province,
    required this.distanceKm,
    required this.origin,
  });

  factory PostalCodeInfo.fromJson(Map<String, dynamic> json) {
    return PostalCodeInfo(
      postalCode: json['postalCode'] as String? ?? '',
      city: json['city'] as String? ?? '',
      province: json['province'] as String? ?? '',
      distanceKm: json['distanceKm'] as int? ?? 0,
      origin: json['origin'] as String? ?? 'Jepara',
    );
  }

  String get displayName => '$city, $province';
}

/// Service untuk komunikasi dengan backend shipping API
class ShippingService {
  static ShippingService? _instance;
  late final Dio _dio;

  ShippingService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: AppConfig.defaultHeaders,
    ));
  }

  factory ShippingService() {
    _instance ??= ShippingService._();
    return _instance!;
  }

  /// Hitung ongkir berdasarkan alamat dan kode pos
  Future<ShippingCalculationResult> calculateShipping({
    required String address,
    required String postalCode,
    int totalWeight = 1000,
  }) async {
    try {
      final response = await _dio.post('/shipping/calculate', data: {
        'destinationAddress': address,
        'postalCode': postalCode,
        'totalWeight': totalWeight,
      });

      if (response.data == null || response.data['success'] != true) {
        return ShippingCalculationResult(
          success: false,
          source: 'error',
          couriers: [],
          error: response.data?['error'] ?? 'Gagal menghitung ongkir',
        );
      }

      final List rawCouriers = response.data['couriers'] ?? [];
      final couriers = rawCouriers
          .map((json) => ShippingCourier.fromJson(json as Map<String, dynamic>))
          .toList();

      return ShippingCalculationResult(
        success: true,
        source: response.data['source'] as String? ?? 'smart_calculation',
        destination: response.data['destination'] as String?,
        distanceKm: response.data['distanceKm'] as int?,
        zone: response.data['zone'] as String?,
        zoneLabel: response.data['zoneLabel'] as String?,
        couriers: couriers,
      );
    } on DioException catch (e) {
      return ShippingCalculationResult(
        success: false,
        source: 'error',
        couriers: [],
        error: _formatDioError(e),
      );
    } catch (e) {
      return ShippingCalculationResult(
        success: false,
        source: 'error',
        couriers: [],
        error: e.toString(),
      );
    }
  }

  /// Ambil info wilayah dari kode pos
  Future<PostalCodeInfo?> getPostalInfo(String postalCode) async {
    try {
      final response = await _dio.get('/shipping/postal-info/$postalCode');
      if (response.data?['success'] == true) {
        return PostalCodeInfo.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi timeout. Periksa internet Anda.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server. Pastikan backend aktif.';
    }
    return e.message ?? 'Terjadi kesalahan jaringan';
  }
}
