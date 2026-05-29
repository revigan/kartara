import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../models/order.dart';

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    // Safety fallback
    final OrderModel order = navState.selectedOrder ??
        OrderModel(
          id: 'KRK-9928-XYZ',
          items: [],
          status: 'diproses',
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
        );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              
              // 1. 3D Cardboard Delivery Box Graphic with Confetti
              _buildConfettiBox(),
              const SizedBox(height: 24),
              
              // 2. Success message headers
              const Text(
                'Pesanan Berhasil!',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Terima kasih, pesanan Anda sedang kami proses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7C7C7C),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              
              // 3. Receipt Invoice Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFDDCC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID Pesanan with Copy Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ID Pesanan',
                              style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.id,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ID Pesanan disalin ke clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy, color: Color(0xFF7C7C7C), size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFF4EBE1)),
                    const SizedBox(height: 12),
                    
                    // Estimasi Tiba
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimasi Tiba',
                          style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hari ini, 14.30 - 15.00 WIB',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFF4EBE1)),
                    const SizedBox(height: 12),
                    
                    // Kurir Ahmad info row
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: const Color(0xFFFFF0E6),
                            child: const Icon(Icons.person, color: Color(0xFFC0430E)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kurir',
                              style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.courierName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.courierVehicle,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // 4. Navigation CTA Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => navNotifier.navigateToBuyer('tracking', order: order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0430E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.search, color: Colors.white, size: 20),
                  label: const Text(
                    'Lacak Pesanan',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    navNotifier.changeBuyerTab(0);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7ED),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFFDDCC)),
                    ),
                  ),
                  child: const Text(
                    'Kembali ke Beranda',
                    style: TextStyle(color: Color(0xFFC0430E), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Beautiful drawing of open orange box and green check badge
  Widget _buildConfettiBox() {
    return SizedBox(
      height: 160,
      width: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Colorful confetti dots around
          Positioned(top: 20, left: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
          Positioned(top: 40, right: 10, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle))),
          Positioned(bottom: 20, left: 20, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))),
          Positioned(bottom: 35, right: 20, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle))),
          
          // Outer cardboard box shape
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFC0430E),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC0430E).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 8,
                  child: Container(
                    width: 60,
                    height: 2,
                    color: Colors.white24,
                  ),
                ),
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white70,
                  size: 36,
                ),
              ],
            ),
          ),
          
          // Green check mark badge
          Positioned(
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
