import 'package:flutter/material.dart';
import '../models/tracking_info.dart';

class OrderTimelineStep {
  final String title;
  final String description;
  final String time;
  final bool isCompleted;
  final bool isActive;

  OrderTimelineStep({
    required this.title,
    required this.description,
    required this.time,
    required this.isCompleted,
    required this.isActive,
  });
}

class OrderTimelineWidget extends StatelessWidget {
  final String currentStatus;
  final String createdTime;
  final String paidTime;
  final String shippedTime;
  final String completedTime;

  /// Dynamic timeline dari backend (prioritas utama)
  final List<TrackingTimelineEvent>? dynamicTimeline;

  const OrderTimelineWidget({
    super.key,
    required this.currentStatus,
    required this.createdTime,
    this.paidTime = '',
    this.shippedTime = '',
    this.completedTime = '',
    this.dynamicTimeline,
  });

  List<OrderTimelineStep> _buildSteps() {
    // Gunakan dynamic timeline dari backend jika tersedia
    if (dynamicTimeline != null && dynamicTimeline!.isNotEmpty) {
      return dynamicTimeline!
          .map((e) => OrderTimelineStep(
                title: e.title,
                description: e.description,
                time: e.timestamp,
                isCompleted: e.isCompleted,
                isActive: e.isActive,
              ))
          .toList();
    }

    // Fallback ke logika lokal
    final status = currentStatus.toLowerCase();
    final isCancelled = status == 'cancelled' || status == 'dibatalkan';

    if (isCancelled) {
      return [
        OrderTimelineStep(
          title: 'Pesanan Dibatalkan',
          description: 'Pesanan ini telah dibatalkan.',
          time: completedTime.isNotEmpty ? completedTime : createdTime,
          isCompleted: true,
          isActive: true,
        ),
        OrderTimelineStep(
          title: 'Pesanan Dibuat',
          description: 'Menunggu pembayaran awal.',
          time: createdTime,
          isCompleted: true,
          isActive: false,
        ),
      ];
    }

    final isPending = status == 'pending' || status == 'belum dibayar';
    final isPaid = status == 'paid' || status == 'sudah dibayar';
    final isProcessing = status == 'processing' || status == 'diproses';
    final isShipped = status == 'shipped' || status == 'dikirim' || status == 'dalam perjalanan';
    final isCompleted = status == 'completed' || status == 'selesai';

    return [
      OrderTimelineStep(
        title: 'Pesanan Selesai',
        description: 'Paket telah diterima dengan baik. Terima kasih!',
        time: completedTime,
        isCompleted: isCompleted,
        isActive: isCompleted,
      ),
      OrderTimelineStep(
        title: 'Pesanan Dikirim',
        description: 'Kurir sedang mengantarkan paket Anda ke tujuan.',
        time: shippedTime.isNotEmpty ? shippedTime : (isShipped ? 'Sedang berjalan' : ''),
        isCompleted: isCompleted || isShipped,
        isActive: isShipped,
      ),
      OrderTimelineStep(
        title: 'Pesanan Diproses',
        description: 'Penjual sedang menyiapkan & mengemas kerupuk Anda.',
        time: paidTime.isNotEmpty ? paidTime : (isProcessing ? 'Sedang disiapkan' : ''),
        isCompleted: isCompleted || isShipped || isProcessing,
        isActive: isProcessing,
      ),
      OrderTimelineStep(
        title: 'Pembayaran Sukses',
        description: 'Pembayaran dikonfirmasi. Menunggu proses penjual.',
        time: paidTime,
        isCompleted: isCompleted || isShipped || isProcessing || isPaid,
        isActive: isPaid,
      ),
      OrderTimelineStep(
        title: 'Pesanan Dibuat',
        description: 'Invoice berhasil dibuat. Menunggu pembayaran.',
        time: createdTime,
        isCompleted: true,
        isActive: isPending,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: dot + connector line
            Column(
              children: [
                _buildDot(step),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 52,
                    color: step.isCompleted
                        ? const Color(0xFFC0430E)
                        : const Color(0xFFE0D5C7),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Right: text details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: step.isActive
                                  ? const Color(0xFFC0430E)
                                  : (step.isCompleted
                                      ? const Color(0xFF2C2C2C)
                                      : const Color(0xFFA89A8C)),
                            ),
                          ),
                        ),
                        if (step.time.isNotEmpty)
                          Text(
                            step.time,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF8C7E70)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: step.isCompleted
                            ? const Color(0xFF6B5E52)
                            : const Color(0xFFA89A8C),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDot(OrderTimelineStep step) {
    if (step.isActive) {
      // Pulse animation indicator untuk step aktif
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFC0430E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC0430E).withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
        curve: Curves.easeInOut,
      );
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: step.isCompleted ? const Color(0xFFFFEAE0) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: step.isCompleted ? const Color(0xFFC0430E) : const Color(0xFFE0D5C7),
          width: step.isCompleted ? 2.5 : 1.5,
        ),
      ),
    );
  }
}
