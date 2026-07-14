import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

// ──────────────────────────────────────────────────────────────────────────────
// KlikQRIS Payment State
// ──────────────────────────────────────────────────────────────────────────────
class PaymentState {
  final bool isLoading;
  final String? orderId;
  final String? qrisImage;      // base64 PNG — ditampilkan langsung di Flutter
  final String? qrisUrl;        // URL gambar alternatif
  final String? totalAmount;    // Total final yang ditampilkan ke pembeli (sudah + MDR)
  final String? expiredAt;      // Waktu kedaluwarsa QRIS
  final String? expiredMenit;   // Durasi kedaluwarsa dalam menit
  final String? signature;
  final String? error;
  final String paymentStatus;   // pending_payment | paid | failed | expired
  final String transactionStatus; // settlement | pending | expired

  PaymentState({
    this.isLoading = false,
    this.orderId,
    this.qrisImage,
    this.qrisUrl,
    this.totalAmount,
    this.expiredAt,
    this.expiredMenit,
    this.signature,
    this.error,
    this.paymentStatus = 'pending_payment',
    this.transactionStatus = 'pending',
  });

  PaymentState copyWith({
    bool? isLoading,
    String? orderId,
    String? qrisImage,
    String? qrisUrl,
    String? totalAmount,
    String? expiredAt,
    String? expiredMenit,
    String? signature,
    String? error,
    String? paymentStatus,
    String? transactionStatus,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      orderId: orderId ?? this.orderId,
      qrisImage: qrisImage ?? this.qrisImage,
      qrisUrl: qrisUrl ?? this.qrisUrl,
      totalAmount: totalAmount ?? this.totalAmount,
      expiredAt: expiredAt ?? this.expiredAt,
      expiredMenit: expiredMenit ?? this.expiredMenit,
      signature: signature ?? this.signature,
      error: error ?? this.error,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionStatus: transactionStatus ?? this.transactionStatus,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// KlikQRIS Payment Notifier
// ──────────────────────────────────────────────────────────────────────────────
class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier() : super(PaymentState());

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: AppConfig.defaultHeaders,
  ));

  /// Buat transaksi QRIS baru via KlikQRIS.
  /// Mengembalikan true jika QRIS berhasil dibuat dan [qrisImage] tersedia.
  Future<bool> createTransaction({
    required String orderId,
    required double totalAmount,
    required String customerName,
    String? keterangan,
    // Parameter lama diterima tapi diabaikan agar kompatibel
    String? customerEmail,
    String? customerPhone,
    String? paymentType,
    List<Map<String, dynamic>>? items,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/create-transaction', data: {
        'orderId': orderId,
        'totalAmount': totalAmount,
        'customerName': customerName,
        'keterangan': keterangan ?? 'Pembayaran Pesanan #$orderId',
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        state = state.copyWith(
          isLoading: false,
          orderId: data['order_id'],
          qrisImage: data['qris_image'],
          qrisUrl: data['qris_url'],
          totalAmount: data['total_amount']?.toString(),
          expiredAt: data['expired_at'],
          expiredMenit: data['expired_menit']?.toString(),
          signature: data['signature'],
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['error'] ?? 'Gagal membuat transaksi QRIS',
        );
        return false;
      }
    } on DioException catch (e) {
      debugPrint('KlikQRIS createTransaction error: $e');
      if (e.response != null) {
        debugPrint('Response status: ${e.response?.statusCode}');
        debugPrint('Response data: ${e.response?.data}');
      }
      String errorMsg = 'Gagal menghubungi server pembayaran';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMsg = 'Koneksi timeout. Periksa koneksi internet Anda.';
      } else if (e.response?.data != null && e.response?.data is Map && e.response?.data['error'] != null) {
        errorMsg = e.response?.data['error'];
        if (e.response?.data['message'] != null) {
          errorMsg = '$errorMsg: ${e.response?.data['message']}';
        }
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    } catch (e) {
      debugPrint('KlikQRIS createTransaction unknown error: $e');
      state = state.copyWith(isLoading: false, error: 'Terjadi kesalahan.');
      return false;
    }
  }

  /// Cek status pembayaran via backend (PocketBase + KlikQRIS).
  Future<bool> checkPaymentStatus(String orderId) async {
    try {
      final response = await _dio.get('/payment-status/$orderId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final txStatus = response.data['transaction_status'] ?? 'pending';
        final order = response.data['order'];
        String payStatus = state.paymentStatus;
        if (order != null) {
          payStatus = order['payment_status'] ?? 'pending_payment';
        }
        state = state.copyWith(
          paymentStatus: payStatus,
          transactionStatus: txStatus,
        );
        return payStatus == 'paid' || txStatus == 'settlement';
      }
    } catch (e) {
      debugPrint('checkPaymentStatus error: $e');
    }
    return false;
  }

  void reset() {
    state = PaymentState();
  }
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier();
});
