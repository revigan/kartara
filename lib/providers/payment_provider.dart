import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/order.dart';

// Payment state
class PaymentState {
  final bool isLoading;
  final String? snapToken;
  final String? redirectUrl;
  final String? orderId;
  final String? error;
  final String paymentStatus; // pending_payment, paid, failed, expired
  final String transactionStatus; // settlement, pending, deny, cancel, expire

  PaymentState({
    this.isLoading = false,
    this.snapToken,
    this.redirectUrl,
    this.orderId,
    this.error,
    this.paymentStatus = 'pending_payment',
    this.transactionStatus = 'pending',
  });

  PaymentState copyWith({
    bool? isLoading,
    String? snapToken,
    String? redirectUrl,
    String? orderId,
    String? error,
    String? paymentStatus,
    String? transactionStatus,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      snapToken: snapToken ?? this.snapToken,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      orderId: orderId ?? this.orderId,
      error: error ?? this.error,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionStatus: transactionStatus ?? this.transactionStatus,
    );
  }
}

// Payment provider
class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier() : super(PaymentState());

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: AppConfig.defaultHeaders,
  ));

  // Create Midtrans transaction
  Future<bool> createTransaction({
    required String orderId,
    required double totalAmount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? paymentType,
    List<Map<String, dynamic>>? items,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/create-transaction', data: {
        'orderId': orderId,
        'totalAmount': totalAmount,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'paymentType': paymentType,
        'items': items ?? [
          {
            'id': 'item-1',
            'price': totalAmount.round(),
            'quantity': 1,
            'name': 'Pesanan Kartara'
          }
        ],
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          snapToken: response.data['snap_token'],
          redirectUrl: response.data['redirect_url'],
          orderId: response.data['order_id'],
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Gagal membuat transaksi pembayaran',
        );
        return false;
      }
    } on DioException catch (e) {
      debugPrint('Create transaction error: $e');
      String errorMsg = 'Gagal menghubungi server pembayaran';
      if (e.response?.statusCode == 401) {
        errorMsg = 'Konfigurasi Midtrans tidak valid. Hubungi admin.';
      } else if (e.response?.statusCode == 400) {
        errorMsg = 'Data pesanan tidak lengkap. Coba lagi.';
      } else if (e.response?.statusCode == 500) {
        final msg = e.response?.data['message']?.toString() ?? '';
        if (msg.contains('Access denied') || msg.contains('unauthorized')) {
          errorMsg = 'Kunci Midtrans tidak valid. Hubungi admin untuk konfigurasi ulang.';
        } else {
          errorMsg = 'Server pembayaran error. Coba metode COD atau Transfer Bank.';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMsg = 'Koneksi timeout. Periksa koneksi internet Anda.';
      } else if (e.type == DioExceptionType.unknown) {
        errorMsg = 'Tidak dapat menghubungi server. Gunakan COD atau Transfer Bank.';
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    } catch (e) {
      debugPrint('Create transaction error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Terjadi kesalahan. Coba metode COD atau Transfer Bank.',
      );
      return false;
    }
  }

  // Check payment status
  Future<void> checkPaymentStatus(String orderId) async {
    try {
      final response = await _dio.get('/payment-status/$orderId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final transactionStatus = response.data['transaction_status'] ?? 'pending';
        final order = response.data['order'];
        
        String paymentStatus = 'pending_payment';
        if (order != null) {
          paymentStatus = order['payment_status'] ?? 'pending_payment';
        }

        state = state.copyWith(
          paymentStatus: paymentStatus,
          transactionStatus: transactionStatus,
        );
      }
    } catch (e) {
      debugPrint('Check payment status error: $e');
    }
  }

  // Reset state
  void reset() {
    state = PaymentState();
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier();
});
