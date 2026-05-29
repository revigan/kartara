import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_state.dart';
import '../../models/order.dart';
import '../../models/product.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  int _selectedTab = 0; // 0 for Berjalan, 1 for Selesai
  Set<String> _reviewedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadReviewedOrders();
  }

  Future<void> _loadReviewedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? list = prefs.getStringList('reviewed_order_ids');
      if (list != null) {
        setState(() {
          _reviewedOrderIds = list.toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading reviewed orders: $e');
    }
  }

  Future<void> _markOrderAsReviewed(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _reviewedOrderIds.add(orderId);
      });
      await prefs.setStringList('reviewed_order_ids', _reviewedOrderIds.toList());
    } catch (e) {
      debugPrint('Error saving reviewed order: $e');
    }
  }

  void _showRatingDialog(BuildContext context, Product product, String orderId) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0E6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: Colors.orange, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Beri Ulasan Produk',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C2C2C)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bagaimana kualitas produk "${product.name}"?',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Star Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1.0;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedRating = starVal;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starVal <= selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 38,
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 20),
              
              // Comment Input Box
              TextField(
                controller: commentController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tulis tanggapan Anda mengenai produk ini...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC0430E)),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0D5C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal', style: TextStyle(color: Color(0xFF6B5E52), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0430E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        
                        // Submit review ke PocketBase
                        await ref.read(productsProvider.notifier).submitProductReview(product.id, selectedRating);
                        
                        // Tandai order telah diulas
                        await _markOrderAsReviewed(orderId);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Terima kasih! Ulasan ${selectedRating.toInt()} bintang berhasil dikirim.'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: const Text('Kirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final products = ref.watch(productsProvider);

    // Default products for thumbnails fallback
    final Product p1 = products.isNotEmpty ? products[0] : Product(id: '1', name: 'Krupuk Tengiri Asli', sellerName: 'UMKM Berkah Laut', price: 25000, imageUrl: '', category: 'Udang', rating: 4.9, reviewsCount: 120, weight: 250, description: '', characteristics: [], stock: 45);

    final displayOrders = orders;

    // Filter based on selected tab
    final filteredOrders = _selectedTab == 0
        ? displayOrders.where((o) => o.status != 'selesai').toList()
        : displayOrders.where((o) => o.status == 'selesai').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Header Swiper
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => navNotifier.changeBuyerTab(0), // back to home
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                      child: Row(
                        children: [
                          // Tab 1: Berjalan
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 ? const Color(0xFFC0430E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Berjalan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 0 ? Colors.white : const Color(0xFF6B5E52),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Tab 2: Selesai
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1 ? const Color(0xFFC0430E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Selesai',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 1 ? Colors.white : const Color(0xFF6B5E52),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Orders List
            Expanded(
              child: filteredOrders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final Product p = order.items.isNotEmpty 
                            ? order.items.first.product 
                            : (products.isNotEmpty ? products.first : p1);
                            
                        int totalItems = 0;
                        if (order.items.isNotEmpty) {
                          for (final item in order.items) {
                            totalItems += item.quantity;
                          }
                        }
                        final quantityLabel = totalItems > 0 ? '$totalItems item' : '1 item';
                        
                        // Map status labels and colors to premium styles
                        String statusLabel = 'Dipesan';
                        Color statusBg = const Color(0xFFFFF0E6);
                        Color statusTextColor = const Color(0xFFC0430E);
                        
                        final String orderStatus = order.status.trim().toLowerCase();
                        if (orderStatus == 'pending') {
                          statusLabel = 'Menunggu Pembayaran';
                          statusBg = const Color(0xFFFFF3CD);
                          statusTextColor = const Color(0xFF856404);
                        } else if (orderStatus == 'diproses') {
                          statusLabel = 'Diproses';
                          statusBg = const Color(0xFFE0F2F1);
                          statusTextColor = const Color(0xFF004D40);
                        } else if (orderStatus == 'dikirim' || orderStatus == 'dalam perjalanan') {
                          statusLabel = 'Dalam Perjalanan';
                          statusBg = const Color(0xFFE3F2FD);
                          statusTextColor = const Color(0xFF0D47A1);
                        } else if (orderStatus == 'selesai') {
                          statusLabel = 'Selesai';
                          statusBg = const Color(0xFFE8F5E9);
                          statusTextColor = const Color(0xFF1B5E20);
                        }

                        final bool isReviewed = _reviewedOrderIds.contains(order.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEFEBE7)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Info (ID & Badge)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order.id,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C2C2C),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Middle Section (Thumbnail & Name)
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Image.network(
                                        p.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: const Color(0xFFFFF0E6),
                                          child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C2C2C),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          quantityLabel,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B5E52),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFFEFEBE7), height: 1),
                              const SizedBox(height: 12),
                              
                              // Bottom Section (Price & CTA Button)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Pembayaran',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rp ${order.totalInvoice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFC0430E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (orderStatus == 'selesai') ...[
                                        // Button Ulasan
                                        GestureDetector(
                                          onTap: isReviewed
                                              ? null
                                              : () => _showRatingDialog(context, p, order.id),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isReviewed ? const Color(0xFFE8F5E9) : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isReviewed ? Colors.transparent : const Color(0xFFC0430E),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                if (isReviewed) ...[
                                                  const Icon(Icons.check, size: 14, color: Color(0xFF1B5E20)),
                                                  const SizedBox(width: 4),
                                                ],
                                                Text(
                                                  isReviewed ? 'Diulas' : 'Beri Ulasan',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isReviewed ? const Color(0xFF1B5E20) : const Color(0xFFC0430E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        // Button Lacak / Bayar
                                        GestureDetector(
                                          onTap: () {
                                            if (orderStatus == 'pending') {
                                              navNotifier.navigateToBuyer('payment', order: order);
                                            } else {
                                              navNotifier.navigateToBuyer('tracking', order: order);
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFC0430E),
                                              ),
                                            ),
                                            child: Text(
                                              orderStatus == 'pending' ? 'Bayar' : 'Lacak',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFC0430E),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      // Beli Lagi Button
                                      GestureDetector(
                                        onTap: () {
                                          cartNotifier.addToCart(p, qty: order.items.isNotEmpty ? order.items.first.quantity : 1);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${p.name} ditambahkan kembali ke keranjang!'),
                                              backgroundColor: const Color(0xFFC0430E),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          );
                                          navNotifier.navigateToBuyer('cart');
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFC0430E),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Beli Lagi',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            // Bottom CTA "Beri Ulasan untuk Pesanan Selesai" only shows on running tab
            if (_selectedTab == 0)
              Container(
                width: double.infinity,
                height: 48,
                margin: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _selectedTab = 1); // Switch to completed/selesai tab
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC0430E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Beri Ulasan untuk Pesanan Selesai',
                    style: TextStyle(
                      color: Color(0xFFC0430E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0E6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFFC0430E)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada transaksi di tab ini.',
            style: TextStyle(color: Color(0xFF6B5E52), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
