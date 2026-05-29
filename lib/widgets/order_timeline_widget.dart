import 'package:flutter/material.dart';

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

  const OrderTimelineWidget({
    super.key,
    required this.currentStatus,
    required this.createdTime,
    this.paidTime = '',
    this.shippedTime = '',
    this.completedTime = '',
  });

  List<OrderTimelineStep> _buildSteps() {
    final status = currentStatus.toLowerCase();
    
    // Status list: pending, paid, processing, shipped, completed, cancelled
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
            // Left Line & Dot indicator
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: step.isActive
                        ? const Color(0xFFC0430E)
                        : (step.isCompleted ? const Color(0xFFFFEAE0) : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step.isCompleted ? const Color(0xFFC0430E) : const Color(0xFFE0D5C7),
                      width: step.isActive ? 4 : 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: step.isCompleted ? const Color(0xFFC0430E) : const Color(0xFFE0D5C7),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Right text details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: step.isActive
                                ? const Color(0xFFC0430E)
                                : (step.isCompleted ? const Color(0xFF2C2C2C) : const Color(0xFFA89A8C)),
                          ),
                        ),
                        if (step.time.isNotEmpty)
                          Text(
                            step.time,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8C7E70)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: step.isCompleted ? const Color(0xFF6B5E52) : const Color(0xFFA89A8C),
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
}
