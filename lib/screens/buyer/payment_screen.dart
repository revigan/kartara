import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import '../../providers/app_state.dart';
import '../../providers/payment_provider.dart';
import '../../models/order.dart';
import '../../widgets/success_notification.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'QRIS'; // 'QRIS', 'COD', 'Transfer Bank'
  bool _isProcessing = false;
  bool _showQrisScreen = false;
  bool _isSavingQr = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Proses pembayaran ─────────────────────────────────────────────────────
  Future<void> _processPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    setState(() => _isProcessing = true);
    if (_selectedMethod == 'QRIS') {
      await _processQrisPayment(order, ordersNotifier, navNotifier);
    } else {
      await _processManualPayment(order, ordersNotifier, navNotifier);
    }
  }

  Future<void> _processManualPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final newStatus = _selectedMethod == 'COD' ? 'diproses' : 'pending';
    await ordersNotifier.updateOrderStatus(order.id, newStatus, paymentMethod: _selectedMethod);
    if (mounted) {
      setState(() => _isProcessing = false);
      showSuccessNotification(
        context,
        _selectedMethod == 'COD'
            ? 'Pesanan Berhasil! Bayar saat barang tiba.'
            : 'Pesanan Berhasil! Silakan transfer ke rekening kami.',
      );
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) navNotifier.navigateToBuyer('history');
    }
  }

  Future<void> _processQrisPayment(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) async {
    final paymentNotifier = ref.read(paymentProvider.notifier);
    final success = await paymentNotifier.createTransaction(
      orderId: order.id,
      totalAmount: order.totalInvoice,
      customerName: order.recipientName,
      keterangan: 'Pembayaran Pesanan Kartara #${order.id}',
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        setState(() => _showQrisScreen = true);
        _startPolling(order, ordersNotifier, navNotifier);
      } else {
        final err = ref.read(paymentProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Gagal membuat QRIS'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startPolling(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final isPaid = await ref.read(paymentProvider.notifier).checkPaymentStatus(order.id);
      if (isPaid && mounted) {
        timer.cancel();
        setState(() => _showQrisScreen = false);
        await ordersNotifier.loadOrders();
        navNotifier.navigateToBuyer('history');
        if (mounted) {
          showSuccessNotification(context, 'Pembayaran Berhasil! Pesanan sedang diproses.');
        }
      }
    });
  }

  Future<void> _downloadQrCode(String? qrisB64, String? qrisUrl) async {
    if ((qrisB64 == null || qrisB64.isEmpty) && (qrisUrl == null || qrisUrl.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gambar QR tidak tersedia'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSavingQr = true);

    try {
      late Uint8List bytes;
      if (qrisB64 != null && qrisB64.isNotEmpty) {
        final raw = qrisB64.contains(',') ? qrisB64.split(',').last : qrisB64;
        bytes = base64Decode(raw);
      } else if (qrisUrl != null && qrisUrl.isNotEmpty) {
        final response = await Dio().get<List<int>>(
          qrisUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null) {
          bytes = Uint8List.fromList(response.data!);
        } else {
          throw Exception('Gagal mendownload data gambar');
        }
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final request = await Gal.requestAccess();
        if (!request) {
          throw Exception('Izin akses galeri ditolak');
        }
      }

      await Gal.putImageBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code berhasil disimpan ke galeri!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan QR: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  // ── Layar QR Code native ──────────────────────────────────────────────────
  Widget _buildQrisScreen(OrderModel order) {
    final payState = ref.watch(paymentProvider);
    final qrisB64 = payState.qrisImage;
    final totalAmt = payState.totalAmount ?? order.totalInvoice.toStringAsFixed(0);
    final expired = payState.expiredMenit ?? '60';

    ImageProvider? qrImage;
    if (qrisB64 != null && qrisB64.isNotEmpty) {
      try {
        final raw = qrisB64.contains(',') ? qrisB64.split(',').last : qrisB64;
        qrImage = MemoryImage(base64Decode(raw));
      } catch (_) {}
    }
    if (qrImage == null && payState.qrisUrl != null) {
      qrImage = NetworkImage(payState.qrisUrl!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2C2C2C)),
          onPressed: () {
            _pollTimer?.cancel();
            setState(() => _showQrisScreen = false);
          },
        ),
        title: const Text(
          'Scan & Bayar QRIS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Info total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFC0430E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('TOTAL PEMBAYARAN', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${double.tryParse(totalAmt)?.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.') ?? totalAmt}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Berlaku $expired menit • Scan sebelum kedaluwarsa',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: qrImage != null
                  ? Image(image: qrImage, width: 260, height: 260, fit: BoxFit.contain)
                  : const SizedBox(
                      width: 260, height: 260,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFC0430E))),
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSavingQr
                  ? null
                  : () => _downloadQrCode(qrisB64, payState.qrisUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0430E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: _isSavingQr
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 20),
              label: Text(_isSavingQr ? 'Menyimpan...' : 'Simpan QR ke Galeri'),
            ),
            const SizedBox(height: 20),
            // Instruksi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD8C2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cara Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2C2C2C))),
                  SizedBox(height: 8),
                  Text('1. Buka aplikasi GoPay, OVO, DANA, ShopeePay, atau Mobile Banking.', style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52))),
                  SizedBox(height: 4),
                  Text('2. Pilih menu Scan/Pay QR.', style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52))),
                  SizedBox(height: 4),
                  Text('3. Arahkan kamera ke kode QR di atas.', style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52))),
                  SizedBox(height: 4),
                  Text('4. Konfirmasi jumlah dan selesaikan pembayaran.', style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52))),
                  SizedBox(height: 4),
                  Text('5. Halaman ini akan otomatis berpindah ke riwayat pesanan setelah pembayaran dikonfirmasi.', style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Status cek manual
            Row(
              children: [
                const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC0430E))),
                const SizedBox(width: 10),
                const Text('Menunggu konfirmasi pembayaran...', style: TextStyle(fontSize: 13, color: Color(0xFF6B5E52))),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Build utama ───────────────────────────────────────────────────────────
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0430E)),
                child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_showQrisScreen) return _buildQrisScreen(order);

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
        title: const Text('Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInvoiceCard(order),
                const SizedBox(height: 24),
                const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
                const SizedBox(height: 16),
                _buildPaymentOption('QRIS', 'Bayar dengan QRIS', 'GoPay, OVO, DANA, ShopeePay, Mobile Banking', Icons.qr_code_2),
                const SizedBox(height: 120),
              ],
            ),
          ),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
                  const Text('TOTAL PEMBAYARAN', style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${order.totalInvoice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFF0E6), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, size: 14, color: Color(0xFFC0430E)),
                    SizedBox(width: 4),
                    Text('Belum Dibayar', style: TextStyle(fontSize: 11, color: Color(0xFFC0430E), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFE0D5C7))),
          const Text('ID PESANAN', style: TextStyle(fontSize: 10, color: Color(0xFF6B5E52))),
          const SizedBox(height: 4),
          Text(order.id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String method, String title, String desc, IconData icon) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5EE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFE0D5C7), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFF5F1ED), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFFC0430E), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF2C2C2C) : const Color(0xFF6B5E52))),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E52))),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFFC0430E), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF5EE), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD8C2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.info_outline, color: Color(0xFFC0430E), size: 20), SizedBox(width: 8), Text('Informasi Transfer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)))]),
          const SizedBox(height: 12),
          _buildBankDetail('Bank BCA', '1234567890', 'PT Kartara Indonesia'),
          const SizedBox(height: 8),
          _buildBankDetail('Bank Mandiri', '0987654321', 'PT Kartara Indonesia'),
          const SizedBox(height: 12),
          const Text('⚠️ Setelah transfer, kirim bukti transfer ke WhatsApp kami untuk konfirmasi.', style: TextStyle(fontSize: 11, color: Color(0xFF6B5E52), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildBankDetail(String bank, String account, String name) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bank, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
          const SizedBox(height: 4),
          Text(account, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC0430E))),
          const SizedBox(height: 2),
          Text('a.n. $name', style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52))),
        ],
      ),
    );
  }

  Widget _buildStickyPayButton(OrderModel order, dynamic ordersNotifier, dynamic navNotifier) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _processPayment(order, ordersNotifier, navNotifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0430E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _selectedMethod == 'QRIS' ? 'Tampilkan QR Code' : _selectedMethod == 'COD' ? 'Konfirmasi Pesanan (COD)' : 'Konfirmasi Pesanan',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
