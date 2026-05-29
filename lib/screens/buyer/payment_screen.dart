import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
  WebViewController? _webViewController;
  Timer? _pollTimer;

  Future<void> _processPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    setState(() => _isProcessing = true);

    if (_selectedMethod == 'Midtrans') {
      // Process Midtrans payment
      await _processMidtransPayment(order, ordersNotifier, navNotifier);
    } else {
      // Process COD or Transfer Bank
      await _processManualPayment(order, ordersNotifier, navNotifier);
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
            _showWaitingDialog(order, ordersNotifier, navNotifier);
            _startPolling(order, ordersNotifier, navNotifier);
          }
        } else {
          setState(() => _showWebView = true);
          _initializeWebView();
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

  void _startPolling(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // Reload orders dari PocketBase langsung
        await ordersNotifier.loadOrders();
        final orders = ref.read(ordersProvider);
        final updated = orders.cast<OrderModel?>().firstWhere(
          (o) => o?.id == order.id,
          orElse: () => null,
        );

        // Cek apakah status sudah berubah menjadi diproses (artinya sudah dibayar)
        if (updated != null && (updated.status == 'diproses' || updated.status == 'selesai')) {
          timer.cancel();
          if (mounted) {
            if (Navigator.canPop(context)) Navigator.pop(context);
            showSuccessNotification(context, 'Pembayaran Berhasil! Pesanan sedang diproses.');
            await Future.delayed(const Duration(milliseconds: 1600));
            if (mounted) navNotifier.navigateToBuyer('history');
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  void _showWaitingDialog(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: Color(0xFFC0430E), strokeWidth: 3),
            const SizedBox(height: 20),
            const Text(
              'Menunggu Konfirmasi Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Selesaikan pembayaran di tab Midtrans.\nStatus akan otomatis diperbarui.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC0430E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                 onPressed: () async {
                  Navigator.pop(ctx);
                  _pollTimer?.cancel();
                  // Reload dari PocketBase
                  await ordersNotifier.loadOrders();
                  final orders = ref.read(ordersProvider);
                  final updated = orders.cast<OrderModel?>().firstWhere(
                    (o) => o?.id == order.id,
                    orElse: () => null,
                  );
                  if (updated != null && (updated.status == 'diproses' || updated.status == 'selesai')) {
                    if (mounted) {
                      showSuccessNotification(context, 'Pembayaran Berhasil!');
                      await Future.delayed(const Duration(milliseconds: 1600));
                      if (mounted) navNotifier.navigateToBuyer('history');
                    }
                  } else {
                    await ordersNotifier.loadOrders();
                    navNotifier.navigateToBuyer('history');
                  }
                },
                child: const Text('Sudah Bayar? Cek Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () {
                _pollTimer?.cancel();
                Navigator.pop(ctx);
                navNotifier.navigateToBuyer('history');
              },
              child: Text('Ke History', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
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

  void _initializeWebView() {
    final paymentState = ref.read(paymentProvider);
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            
            // Check if payment is completed
            if (url.contains('kartara://payment/success')) {
              _handlePaymentSuccess();
            } else if (url.contains('kartara://payment/failed')) {
              _handlePaymentFailed();
            } else if (url.contains('kartara://payment/pending')) {
              _handlePaymentPending();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Navigation request: ${request.url}');
            
            // Handle deep links
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
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentState.redirectUrl!));
  }

  void _handlePaymentSuccess() {
    final navNotifier = ref.read(navigationProvider.notifier);
    
    setState(() => _showWebView = false);
    
    showSuccessNotification(
      context,
      'Pembayaran Berhasil! Pesanan Anda sedang diproses.',
    );
    
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        navNotifier.navigateToBuyer('history');
      }
    });
  }

  void _handlePaymentFailed() {
    setState(() => _showWebView = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran Gagal! Silakan coba lagi.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handlePaymentPending() {
    final navNotifier = ref.read(navigationProvider.notifier);
    
    setState(() => _showWebView = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran Pending. Silakan selesaikan pembayaran Anda.'),
        backgroundColor: Colors.orange,
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        navNotifier.navigateToBuyer('history');
      }
    });
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
