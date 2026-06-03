import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../providers/app_state.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order.dart';
import '../../widgets/success_notification.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'Midtrans'; // 'Midtrans', 'COD' or 'Transfer Bank'
  bool _isProcessing = false;
  bool _showWebView = false;
  bool _waitingForPayment = false; // Full-screen waiting state for Web tab flow
  WebViewController? _webViewController;
  Timer? _pollTimer;

  // Simpan referensi agar bisa dipakai di WebView callback
  dynamic _ordersNotifier;
  dynamic _navNotifier;

  Future<void> _processPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    setState(() => _isProcessing = true);
    if (_selectedMethod == 'Midtrans') {
      await _processMidtransPayment(order, ordersNotifier, navNotifier);
    } else {
      await _processManualPayment(order, ordersNotifier, navNotifier);
    }
  }

  Future<void> _processManualPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Update order status based on payment method
    String newStatus = 'pending';
    if (_selectedMethod == 'COD') {
      newStatus = 'diproses'; // COD langsung diproses
    } else {
      newStatus = 'pending'; // Transfer menunggu konfirmasi
    }

    await ordersNotifier.updateOrderStatus(order.id, newStatus, paymentMethod: _selectedMethod);

    if (mounted) {
      setState(() => _isProcessing = false);
      
      showSuccessNotification(
        context, 
        _selectedMethod == 'COD' 
          ? 'Pesanan Berhasil! Bayar saat barang tiba.' 
          : 'Pesanan Berhasil! Silakan transfer ke rekening kami.'
      );
      
      await Future.delayed(const Duration(milliseconds: 1600));
      
      if (mounted) {
        navNotifier.navigateToBuyer('history');
      }
    }
  }

  Future<void> _processMidtransPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    final paymentNotifier = ref.read(paymentProvider.notifier);
    final authState = ref.read(authProvider);

    // Create Midtrans transaction
    final success = await paymentNotifier.createTransaction(
      orderId: order.id,
      totalAmount: order.totalInvoice,
      customerName: order.recipientName,
      customerEmail: authState.currentUser?.email ?? 'customer@kartara.com',
      customerPhone: order.recipientPhone,
      paymentType: _selectedMethod,
      items: order.items.map((item) => {
        'id': item.product.id,
        'price': item.product.price.round(),
        'quantity': item.quantity,
        'name': item.product.name,
      }).toList(),
    );

    if (mounted) {
      setState(() => _isProcessing = false);

      if (success) {
        final paymentState = ref.read(paymentProvider);
        if (kIsWeb) {
          await _openMidtransInNewTab(paymentState.redirectUrl!);
          if (mounted) {
            // Show full-screen waiting overlay (cannot be dismissed by accident)
            setState(() => _waitingForPayment = true);
            _startPolling(order, ordersNotifier, navNotifier);
          }
        } else {
          setState(() => _showWebView = true);
          _initializeWebView(ordersNotifier, navNotifier);
        }
      } else {
        final paymentState = ref.read(paymentProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentState.error ?? 'Gagal membuat transaksi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cek status pembayaran via backend API (hindari CORS issue di Flutter Web)
  Future<bool> _checkPaymentPaidViaApi(String orderId) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: AppConfig.defaultHeaders,
      ));
      final response = await dio.get('/payment-status/$orderId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final order = response.data['order'];
        final paymentStatus = order?['payment_status'] as String? ?? '';
        final txStatus = response.data['transaction_status'] as String? ?? '';
        debugPrint('💳 Payment poll: payment_status=$paymentStatus, tx=$txStatus');
        return paymentStatus == 'paid' ||
               txStatus == 'settlement' ||
               txStatus == 'capture';
      }
    } catch (e) {
      debugPrint('Payment status check error: $e');
    }
    return false;
  }

  void _startPolling(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final isPaid = await _checkPaymentPaidViaApi(order.id);
        if (isPaid) {
          timer.cancel();
          if (mounted) {
            // Clear waiting state, refresh orders, navigate to history
            setState(() => _waitingForPayment = false);
            await ref.read(ordersProvider.notifier).loadOrders();
            ref.read(navigationProvider.notifier).navigateToBuyer('history');
            showSuccessNotification(context, 'Pembayaran Berhasil! Pesanan sedang diproses.');
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  /// Full-screen waiting overlay, shown instead of a dismissible dialog.
  Widget _buildWaitingOverlay(OrderModel order) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payment, color: Color(0xFFC0430E), size: 40),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Menunggu Pembayaran',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF2C2C2C)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Selesaikan pembayaran di tab Midtrans.\nApp akan otomatis berpindah ke riwayat pesanan.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const CircularProgressIndicator(
                  color: Color(0xFFC0430E),
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC0430E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      final isPaid = await _checkPaymentPaidViaApi(order.id);
                      if (isPaid) {
                        _pollTimer?.cancel();
                        if (mounted) {
                          setState(() => _waitingForPayment = false);
                          await ref.read(ordersProvider.notifier).loadOrders();
                          ref.read(navigationProvider.notifier).navigateToBuyer('history');
                          showSuccessNotification(context, 'Pembayaran Berhasil!');
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pembayaran belum terkonfirmasi. Silakan tunggu...'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Sudah Bayar? Cek Status',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _pollTimer?.cancel();
                    setState(() => _waitingForPayment = false);
                    ref.read(navigationProvider.notifier).navigateToBuyer('history');
                  },
                  child: Text('Ke Riwayat Pesanan', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Open Midtrans in new tab for Flutter Web
  Future<void> _openMidtransInNewTab(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka halaman pembayaran'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initializeWebView(dynamic ordersNotifier, dynamic navNotifier) {
    final paymentState = ref.read(paymentProvider);

    // Simpan referensi untuk dipakai di callback
    _ordersNotifier = ordersNotifier;
    _navNotifier = navNotifier;

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 KartaraApp/1.0')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint('✅ WebView page finished: $url');

            // Deteksi URL callback dari backend (ngrok/server)
            if (url.contains('/success') || url.contains('order_id') && url.contains('finish')) {
              _handlePaymentSuccess();
            } else if (url.contains('/failed') || url.contains('order_id') && url.contains('error')) {
              _handlePaymentFailed();
            } else if (url.contains('/pending')) {
              _handlePaymentPending();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🔗 Navigation request: ${request.url}');

            // Handle deep links kartara://
            if (request.url.startsWith('kartara://')) {
              if (request.url.contains('/success')) {
                _handlePaymentSuccess();
              } else if (request.url.contains('/failed')) {
                _handlePaymentFailed();
              } else if (request.url.contains('/pending')) {
                _handlePaymentPending();
              }
              return NavigationDecision.prevent;
            }

            // Deteksi redirect ke URL backend /success, /failed, /pending
            final isCallbackUrl = request.url.contains('/success') ||
                request.url.contains('/failed') ||
                request.url.contains('/pending') ||
                request.url.contains('finish?') ||
                request.url.contains('error?');

            if (isCallbackUrl) {
              if (request.url.contains('success') || request.url.contains('finish')) {
                _handlePaymentSuccess();
              } else if (request.url.contains('failed') || request.url.contains('error')) {
                _handlePaymentFailed();
              } else if (request.url.contains('pending')) {
                _handlePaymentPending();
              }
              return NavigationDecision.prevent;
            }

            // Intercept navigations to ngrok URLs and reload with bypass header.
            // The loadRequest header is only applied to the first request;
            // subsequent redirects inside the WebView lose it.
            // By intercepting here and calling loadRequest again with the header,
            // we guarantee the ngrok warning page is never shown.
            final isNgrokUrl = request.url.contains('ngrok-free.app') ||
                request.url.contains('ngrok-free.dev') ||
                request.url.contains('ngrok.io') ||
                request.url.contains('ngrok.app');
            if (isNgrokUrl) {
              debugPrint('🔑 Injecting ngrok-skip-browser-warning for: ${request.url}');
              _webViewController?.loadRequest(
                Uri.parse(request.url),
                headers: const {
                  'ngrok-skip-browser-warning': 'true',
                  'User-Agent': 'Mozilla/5.0 KartaraApp/1.0',
                },
              );
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(paymentState.redirectUrl!),
        headers: const {'ngrok-skip-browser-warning': 'true'},
      );
  }

  void _handlePaymentSuccess() {
    if (!mounted) return;
    // Tutup WebView, kembali ke halaman pembayaran
    setState(() => _showWebView = false);

    // Refresh orders secara langsung
    _ordersNotifier?.loadOrders();

    // Navigasi langsung tanpa delay
    _navNotifier?.navigateToBuyer('history');

    showSuccessNotification(
      context,
      'Pembayaran Berhasil! Pesanan Anda sedang diproses.',
    );
  }

  void _handlePaymentFailed() {
    if (!mounted) return;
    // Tutup WebView, kembali ke halaman pembayaran (payment screen)
    setState(() => _showWebView = false);

    // Refresh orders secara langsung
    _ordersNotifier?.loadOrders();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran Gagal! Silakan coba lagi.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    // Tetap di halaman payment agar user bisa coba lagi
  }

  void _handlePaymentPending() {
    if (!mounted) return;
    // Tutup WebView, kembali ke halaman pembayaran
    setState(() => _showWebView = false);

    // Refresh orders secara langsung
    _ordersNotifier?.loadOrders();

    // Navigasi langsung ke history
    _navNotifier?.navigateToBuyer('history');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran Pending. Selesaikan pembayaran Anda.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final ordersNotifier = ref.read(ordersProvider.notifier);

    final OrderModel? order = navState.selectedOrder;

    if (order == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F1ED),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Pesanan tidak ditemukan', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => navNotifier.changeBuyerTab(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC0430E),
                ),
                child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Show full-screen waiting overlay for Flutter Web tab payment flow
    if (_waitingForPayment) {
      return _buildWaitingOverlay(order);
    }

    // Show WebView if payment is being processed
    if (_showWebView) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF2C2C2C)),
            onPressed: () {
              setState(() => _showWebView = false);
            },
          ),
          title: const Text(
            'Pembayaran Midtrans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2C),
            ),
          ),
        ),
        body: _webViewController != null
            ? WebViewWidget(controller: _webViewController!)
            : const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => navNotifier.changeBuyerTab(0),
        ),
        title: const Text(
          'Pembayaran',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice Card
                _buildInvoiceCard(order),
                const SizedBox(height: 24),

                // Payment Method Selection
                const Text(
                  'Pilih Metode Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 16),

                // Midtrans Option (QRIS, GoPay, DANA, VA)
                _buildPaymentOption(
                  'Midtrans',
                  'Pembayaran Digital',
                  'QRIS, GoPay, DANA, Virtual Account',
                  Icons.payment_outlined,
                ),
                const SizedBox(height: 12),

                // COD Option
                _buildPaymentOption(
                  'COD',
                  'Cash on Delivery',
                  'Bayar tunai saat barang tiba',
                  Icons.local_shipping_outlined,
                ),
                const SizedBox(height: 12),

                // Transfer Bank Option
                _buildPaymentOption(
                  'Transfer Bank',
                  'Transfer Bank Manual',
                  'Transfer ke rekening BCA/Mandiri',
                  Icons.account_balance_outlined,
                ),
                const SizedBox(height: 24),

                // Bank Account Info (if Transfer selected)
                if (_selectedMethod == 'Transfer Bank') _buildBankInfo(),

                const SizedBox(height: 120), // Space for button
              ],
            ),
          ),

          // Sticky Bottom Button
          _buildStickyPayButton(order, ordersNotifier, navNotifier),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL PEMBAYARAN',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B5E52),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${order.totalInvoice.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC0430E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, size: 14, color: Color(0xFFC0430E)),
                    SizedBox(width: 4),
                    Text(
                      'Belum Dibayar',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC0430E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFE0D5C7)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ID PESANAN',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B5E52)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.id,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String method, String title, String desc, IconData icon) {
    final bool isSelected = _selectedMethod == method;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5EE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFE0D5C7),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFF5F1ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFFC0430E),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF2C2C2C) : const Color(0xFF6B5E52),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B5E52),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFC0430E),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }



  Widget _buildBankInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD8C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFC0430E), size: 20),
              SizedBox(width: 8),
              Text(
                'Informasi Transfer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBankDetail('Bank BCA', '1234567890', 'PT Kartara Indonesia'),
          const SizedBox(height: 8),
          _buildBankDetail('Bank Mandiri', '0987654321', 'PT Kartara Indonesia'),
          const SizedBox(height: 12),
          const Text(
            '⚠️ Setelah transfer, mohon kirim bukti transfer ke WhatsApp kami untuk konfirmasi.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B5E52),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetail(String bank, String account, String name) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bank,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            account,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC0430E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'a.n. $name',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B5E52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyPayButton(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () => _processPayment(order, ordersNotifier, navNotifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0430E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _selectedMethod == 'Midtrans' 
                        ? 'Bayar Sekarang'
                        : _selectedMethod == 'COD' 
                          ? 'Konfirmasi Pesanan (COD)' 
                          : 'Konfirmasi Pesanan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
