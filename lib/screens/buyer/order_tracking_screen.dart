import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../models/tracking_info.dart';
import '../../providers/tracking_provider.dart';
import '../../widgets/order_timeline_widget.dart';
import 'tracking_map_screen.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(orderTrackingProvider(order.id));

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC0430E)),
            onPressed: () => ref.invalidate(orderTrackingProvider(order.id)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: trackingAsync.when(
        loading: () => _buildLoadingState(),
        error: (_, __) => _buildContentFromOrder(context, null, order),
        data: (trackingInfo) => RefreshIndicator(
          color: const Color(0xFFC0430E),
          onRefresh: () async {
            ref.invalidate(orderTrackingProvider(order.id));
          },
          child: _buildContentFromOrder(context, trackingInfo, order),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFC0430E)),
          SizedBox(height: 16),
          Text('Memuat informasi pengiriman...', style: TextStyle(color: Color(0xFF6B5E52))),
        ],
      ),
    );
  }

  Widget _buildContentFromOrder(
    BuildContext context,
    OrderTrackingInfo? trackingInfo,
    OrderModel order,
  ) {
    // Gunakan data dari backend jika ada, fallback ke order model
    final status = (trackingInfo?.status ?? order.status).toLowerCase();
    final courierName = trackingInfo?.courierName.isNotEmpty == true
        ? trackingInfo!.courierName
        : (order.courierName.isNotEmpty ? order.courierName : 'Kartara Instant');
    final trackingNumber = trackingInfo?.trackingNumber.isNotEmpty == true
        ? trackingInfo!.trackingNumber
        : order.generatedTrackingNumber;
    final eta = trackingInfo?.courierEta.isNotEmpty == true
        ? trackingInfo!.courierEta
        : order.displayEta;

    final isCancelled = status == 'cancelled' || status == 'dibatalkan';
    final isShippedOrCompleted = status == 'shipped' || status == 'dikirim' ||
        status == 'dalam perjalanan' || status == 'completed' || status == 'selesai';

    Color statusColor;
    String statusLabel;

    if (status.contains('pending')) {
      statusColor = Colors.orange;
      statusLabel = 'MENUNGGU PEMBAYARAN';
    } else if (status.contains('paid')) {
      statusColor = Colors.blue;
      statusLabel = 'SUDAH DIBAYAR';
    } else if (status.contains('proces') || status.contains('proses') || status.contains('diproses')) {
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
    } else {
      statusColor = const Color(0xFFC0430E);
      statusLabel = status.toUpperCase();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Invoice & Status Badge
          _buildInvoiceCard(order.id, statusColor, statusLabel),
          const SizedBox(height: 16),

          // 2. Shipping Details Card
          _buildShippingDetailsCard(
            context,
            courierName: courierName,
            trackingNumber: trackingNumber,
            eta: eta,
            isShippedOrCompleted: isShippedOrCompleted,
            order: order,
            trackingInfo: trackingInfo,
          ),
          const SizedBox(height: 16),

          // 3. Timeline Card
          _buildTimelineCard(status, trackingInfo),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(String orderId, Color statusColor, String statusLabel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D5C7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
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
                  color: statusColor.withValues(alpha: 0.1),
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
            '#$orderId',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingDetailsCard(
    BuildContext context, {
    required String courierName,
    required String trackingNumber,
    required String eta,
    required bool isShippedOrCompleted,
    required OrderModel order,
    required OrderTrackingInfo? trackingInfo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D5C7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
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
          _buildDetailRow('Nomor Resi', trackingNumber, Icons.receipt_long_outlined),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Estimasi Tiba',
            eta,
            Icons.timer_outlined,
          ),
          if (trackingInfo?.destinationCity.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              'Tujuan',
              trackingInfo!.destinationCity,
              Icons.location_on_outlined,
            ),
          ],

          // Map button
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
    );
  }

  Widget _buildTimelineCard(String status, OrderTrackingInfo? trackingInfo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D5C7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
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
            currentStatus: status,
            createdTime: trackingInfo?.created ?? '',
            paidTime: trackingInfo?.paidAt ?? '',
            shippedTime: '',
            completedTime: '',
            dynamicTimeline: trackingInfo?.timeline,
          ),
        ],
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
        Expanded(
          child: Column(
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
        ),
      ],
    );
  }
}
