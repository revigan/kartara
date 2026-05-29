import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../widgets/order_timeline_widget.dart';
import 'tracking_map_screen.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order.status.toLowerCase();
    
    // Status can be: pending, paid, processing, shipped, completed, cancelled
    final isCancelled = status == 'cancelled' || status == 'dibatalkan';
    final isShippedOrCompleted = status == 'shipped' || status == 'dikirim' || status == 'dalam perjalanan' || status == 'completed' || status == 'selesai';

    Color statusColor = const Color(0xFFC0430E);
    String statusLabel = order.status.toUpperCase();

    if (status.contains('pending')) {
      statusColor = Colors.orange;
      statusLabel = 'MENUNGGU PEMBAYARAN';
    } else if (status.contains('paid') || status.contains('sudah')) {
      statusColor = Colors.blue;
      statusLabel = 'SUDAH DIBAYAR';
    } else if (status.contains('proces') || status.contains('proses')) {
      statusColor = Colors.purple;
      statusLabel = 'SEDANG DIPROSES';
    } else if (status.contains('ship') || status.contains('kirim') || status.contains('perjalanan')) {
      statusColor = Colors.indigo;
      statusLabel = 'DALAM PENGIRIMAN';
    } else if (status.contains('complet') || status.contains('selesai')) {
      statusColor = Colors.green;
      statusLabel = 'PESANAN SELESAI';
    } else if (isCancelled) {
      statusColor = Colors.red;
      statusLabel = 'DIBATALKAN';
    }

    // Courier display properties
    final courierName = order.courierName.isNotEmpty ? order.courierName : 'Kartara Instant';
    final courierResi = 'KTR-${order.id.substring(0, 8).toUpperCase()}';
    final eta = '${order.etaMinutes} Menit';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Pelacakan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Invoice & Status Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nomor Invoice',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${order.id}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Shipping Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Pengiriman',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFE0D5C7)),
                  ),
                  _buildDetailRow('Kurir Partner', courierName, Icons.local_shipping_outlined),
                  const SizedBox(height: 12),
                  _buildDetailRow('Nomor Resi', courierResi, Icons.receipt_long_outlined),
                  const SizedBox(height: 12),
                  _buildDetailRow('Estimasi Tiba', eta, Icons.timer_outlined),
                  
                  // Live tracking map button
                  if (isShippedOrCompleted) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrackingMapScreen(order: order),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC0430E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Lacak Posisi di Peta',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Status Timeline Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riwayat Perjalanan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFE0D5C7)),
                  ),
                  OrderTimelineWidget(
                    currentStatus: order.status,
                    createdTime: '29 Mei 2026, 10:00',
                    paidTime: status != 'pending' ? '29 Mei 2026, 10:05' : '',
                    shippedTime: isShippedOrCompleted ? '29 Mei 2026, 12:30' : '',
                    completedTime: status == 'completed' || status == 'selesai' ? '29 Mei 2026, 13:15' : '',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFC0430E), size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
            ),
          ],
        ),
      ],
    );
  }
}
