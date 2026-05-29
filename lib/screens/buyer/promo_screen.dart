import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../models/coupon.dart';

class PromoScreen extends ConsumerStatefulWidget {
  const PromoScreen({super.key});

  @override
  ConsumerState<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends ConsumerState<PromoScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh coupons list when entering screen
    Future.microtask(() {
      ref.read(couponsProvider.notifier).fetchCoupons();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch dynamic coupons loaded from database/provider
    final allCoupons = ref.watch(couponsProvider);
    final activeCoupons = allCoupons.where((c) => c.isActive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kupon & Promo',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC0430E)),
            onPressed: () {
              ref.read(couponsProvider.notifier).fetchCoupons();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memperbarui daftar kupon...'),
                  backgroundColor: Color(0xFFC0430E),
                  duration: Duration(milliseconds: 700),
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Promo Header Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC0430E), Color(0xFFD4601A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC0430E).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Daftar Kupon Aktif 🎫',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Makin Hemat Belanja Anyaman Asli!',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gunakan kupon belanja resmi yang dirilis admin di bawah ini untuk mendapatkan potongan harga spesial.',
                    style: TextStyle(color: Color(0xFFFFEDE0), fontSize: 10.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Active Coupons List
          Expanded(
            child: activeCoupons.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: activeCoupons.length,
                    itemBuilder: (context, index) {
                      final coupon = activeCoupons[index];
                      return _buildVoucherCard(context, coupon);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(BuildContext context, Coupon coupon) {
    const Color mainColor = Color(0xFFC0430E);

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F1F1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Left side colorful border strip
                  Container(
                    width: 8,
                    color: mainColor,
                  ),
                  
                  // Main voucher content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: mainColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'BELANJA',
                                  style: TextStyle(color: mainColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Text(
                                'Kupon Aktif 🎫',
                                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            coupon.displayCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1A1A1A)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dapatkan potongan harga langsung sebesar Rp ${coupon.discountAmount.toStringAsFixed(0)} dengan minimal pembelanjaan senilai Rp ${coupon.minPurchase.toStringAsFixed(0)}.',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C), height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          
                          // Code box and Copy button
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF1F1F1)),
                                  ),
                                  child: Text(
                                    coupon.code,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: mainColor,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: coupon.code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Kode Kupon "${coupon.code}" berhasil disalin!'),
                                      backgroundColor: mainColor,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text(
                                  'Salin',
                                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Ticket cutouts
        Positioned(
          left: -1,
          top: 0,
          bottom: 16,
          child: Center(
            child: Container(
              width: 12,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F2),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -1,
          top: 0,
          bottom: 16,
          child: Center(
            child: Container(
              width: 12,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard_rounded, color: Colors.grey.withOpacity(0.4), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Kupon Aktif',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nantikan rilis kupon diskon terbaru dari Admin Kartara.',
            style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
          ),
        ],
      ),
    );
  }
}
