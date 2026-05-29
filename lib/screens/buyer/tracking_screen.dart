import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../models/order.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final orders = ref.watch(ordersProvider);

    // Retrieve order reactively
    final OrderModel? selectedOrder = navState.selectedOrder;
    final OrderModel order = orders.firstWhere(
      (o) => o.id == selectedOrder?.id,
      orElse: () => selectedOrder ?? OrderModel(
        id: 'KRK-9928-XYZ',
        items: [],
        status: 'dikirim',
        orderDate: DateTime.now(),
        recipientName: 'Budi Santoso',
        recipientPhone: '+62 812-3456-7890',
        shippingAddress: 'Jl. Sudirman No. 123, RT 04/RW 05, Kebayoran Baru, Jakarta Selatan 12190',
        paymentMethod: 'Transfer Bank',
        subtotal: 75000,
        shippingFee: 0,
        discount: 0,
        totalInvoice: 75000,
        courierName: 'Ahmad',
        courierVehicle: 'Honda Vario • K 1234 XY',
        courierRating: 4.5,
        etaMinutes: 15,
      ),
    );

    // Map actual order status to the correct labels, description and positions
    String trackingBadgeText = 'Dalam Perjalanan';
    Color trackingBadgeColor = const Color(0xFF166534); // Green
    String trackingDescText = 'Kurir sedang dalam perjalanan mengantarkan pesanan Anda.';
    String trackingEtaText = 'Tiba dalam ${order.etaMinutes} menit';
    
    double? courierTop;
    double? courierBottom;
    double? courierLeft;
    double? courierRight;
    bool showCourier = true;

    final String orderStatus = order.status.trim().toLowerCase();
    if (orderStatus == 'pending') {
      trackingBadgeText = 'Menunggu Pembayaran';
      trackingBadgeColor = const Color(0xFFD97706); // Amber
      trackingDescText = 'Harap selesaikan pembayaran Anda terlebih dahulu.';
      trackingEtaText = 'Menunggu Pembayaran';
      showCourier = false;
    } else if (orderStatus == 'diproses') {
      trackingBadgeText = 'Sedang Dipersiapkan';
      trackingBadgeColor = const Color(0xFFC0430E); // Orange
      trackingDescText = 'Penjual sedang mempersiapkan produk Anda dengan penuh kasih sayang.';
      trackingEtaText = 'Mempersiapkan Pesanan';
      // Station courier at shop location (bottom: 120, left: 60)
      courierBottom = 120.0;
      courierLeft = 60.0;
    } else if (orderStatus == 'dikirim' || orderStatus == 'dalam perjalanan') {
      trackingBadgeText = 'Dalam Perjalanan';
      trackingBadgeColor = const Color(0xFF166534); // Green
      trackingDescText = 'Kurir sedang dalam perjalanan mengantarkan pesanan Anda.';
      trackingEtaText = 'Tiba dalam ${order.etaMinutes} menit';
      // Standard moving courier position (top: 140, left: 170)
      courierTop = 140.0;
      courierLeft = 170.0;
    } else if (orderStatus == 'selesai') {
      trackingBadgeText = 'Tiba di Tujuan';
      trackingBadgeColor = const Color(0xFF374151); // Charcoal
      trackingDescText = 'Pesanan Anda telah sukses sampai ke tempat tujuan. Terima kasih!';
      trackingEtaText = 'Sudah Tiba';
      // Station courier at recipient home (top: 120, right: 60)
      courierTop = 120.0;
      courierRight = 60.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A), size: 18),
          onPressed: () => navNotifier.goBack(),
        ),
        title: const Text(
          'Lacak Pengiriman',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Gorgeous Stylized Vector Map Section
          Expanded(
            child: Stack(
              children: [
                // Custom Map Painter
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFFAF6F0),
                    child: CustomPaint(
                      painter: MapPainter(),
                    ),
                  ),
                ),
                
                // Floating status badge
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: trackingBadgeColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        trackingBadgeText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Destination recipient marker
                Positioned(
                  top: 70,
                  right: 60,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.home, color: Color(0xFF1A1A1A), size: 20),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Rumah Penerima',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                      ),
                    ],
                  ),
                ),
                
                // Source merchant hub
                Positioned(
                  bottom: 70,
                  left: 60,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.storefront, color: Color(0xFFC0430E), size: 20),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'UMKM Hub Jepara',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
                      ),
                    ],
                  ),
                ),
                
                // Motorcycle courier marker on route pathway
                if (showCourier)
                  Positioned(
                    top: courierTop,
                    bottom: courierBottom,
                    left: courierLeft,
                    right: courierRight,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC0430E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFC0430E),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Icon(Icons.motorcycle, color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Kurir ${order.courierName}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // 2. Tracking details sheet
          _buildTrackingDetailsPanel(context, ref, order, trackingEtaText, trackingDescText),
        ],
      ),
    );
  }

  // Delivery details bottom sheet matching image 5 mockup
  Widget _buildTrackingDetailsPanel(
    BuildContext context, 
    WidgetRef ref,
    OrderModel order, 
    String trackingEtaText, 
    String trackingDescText,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time & ETA Header
            Text(
              trackingEtaText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trackingDescText,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C7C7C)),
            ),
            const SizedBox(height: 20),
            
            // Courier Profile & Action Button Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFDDCC)),
              ),
              child: Row(
                children: [
                  // Courier avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: const Color(0xFFFFF0E6),
                      child: const Icon(Icons.person, color: Color(0xFFC0430E)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Courier details text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.courierName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kurir Kartara',
                          style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.courierVehicle,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                        ),
                      ],
                    ),
                  ),
                  
                  // Solid Orange Circle action buttons
                  Row(
                    children: [
                      // Chat button
                      GestureDetector(
                        onTap: () => _showCourierChatPopup(context, order.courierName),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC0430E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_bubble, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Phone button
                      GestureDetector(
                        onTap: () => _showCourierPhonePopup(context, order.courierName),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC0430E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (order.status == 'dikirim' || order.status == 'dalam perjalanan') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Update status in ordersProvider to 'selesai'
                    await ref.read(ordersProvider.notifier).updateOrderStatus(order.id, 'selesai');
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terima kasih! Pesanan Anda telah ditandai selesai.'),
                          backgroundColor: Color(0xFFC0430E),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      ref.read(navigationProvider.notifier).goBack();
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'Barang Sudah Diterima',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF166534), // Premium green for successful completion
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Popups
  void _showCourierChatPopup(BuildContext context, String name) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.motorcycle, color: Color(0xFFC0430E)),
            const SizedBox(width: 10),
            Text('Kirim Pesan ke $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        content: TextField(
          controller: msgCtrl,
          decoration: const InputDecoration(
            hintText: 'Halo Ahmad, apakah kerupuknya aman?...',
            hintStyle: TextStyle(fontSize: 11),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pesan Anda terkirim ke Kurir!'), backgroundColor: Color(0xFFC0430E)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0430E)),
            child: const Text('Kirim', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showCourierPhonePopup(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hubungi Telepon Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Menghubungi nomor WhatsApp / Seluler $name (+62 812-7389-9831) untuk koordinasi pengiriman kerupuk.', style: const TextStyle(fontSize: 11, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0430E)),
            child: const Text('Telepon', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Map Grid & Orange Route Drawing Custom Painter
class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFEFE6DD)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final routeHighlightPaint = Paint()
      ..color = const Color(0xFFC0430E)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.015)
      ..strokeWidth = 1.0;

    // Draw grid lines
    const int gridSpacing = 40;
    for (double i = 0; i < size.width; i += gridSpacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += gridSpacing) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // Draw complex network of roads
    final path = Path();
    path.moveTo(60, size.height - 80); // Hub
    path.quadraticBezierTo(100, size.height - 180, 160, size.height - 180);
    path.lineTo(160, 160);
    path.quadraticBezierTo(200, 120, size.width - 60, 80); // Target

    canvas.drawPath(path, roadPaint);

    // Highlight routing path fully in warm orange
    final activePath = Path();
    activePath.moveTo(60, size.height - 80);
    activePath.quadraticBezierTo(100, size.height - 180, 160, size.height - 180);
    activePath.lineTo(160, 160);
    activePath.quadraticBezierTo(200, 120, size.width - 60, 80);
    canvas.drawPath(activePath, routeHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => false;
}
