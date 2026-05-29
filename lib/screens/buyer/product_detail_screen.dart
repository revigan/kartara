import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../models/product.dart';

import '../../widgets/success_notification.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);

    // Default fallback if no product is selected (safety)
    final Product product = navState.selectedProduct ??
        Product(
          id: 'temp',
          name: 'Kerupuk Pilihan',
          sellerName: 'UMKM Jepara',
          price: 25000,
          imageUrl: '',
          category: 'Udang',
          rating: 4.9,
          reviewsCount: 125,
          weight: 250,
          description: 'Deskripsi tidak tersedia.',
          characteristics: ['Gurih', 'Renyah', 'Alami'],
          stock: 10,
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Full-width Product Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Image.network(
              product.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFFFF0E6),
                child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 64),
              ),
            ),
          ),
          
          // 2. Content Card with rounded top corners
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Store name and stock
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 14, color: Color(0xFF7C7C7C)),
                            const SizedBox(width: 4),
                            Text(
                              product.sellerName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7C7C7C),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 12,
                              color: const Color(0xFFE0E0E0),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF7C7C7C)),
                            const SizedBox(width: 4),
                            Text(
                              'Stok: ${product.stock}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7C7C7C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Price in orange with discount info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Rp ${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC0430E),
                              ),
                            ),
                            if (product.hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Rp ${product.originalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '-${product.discountPercentage}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Badges: Rating, Weight, Origin
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Rating badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Color(0xFFFFA500), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.rating}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${product.reviewsCount})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7C7C7C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Weight badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.scale_outlined, color: Color(0xFFC0430E), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.weight}g',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Deskripsi Produk
                        const Text(
                          'Deskripsi Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7C7C7C),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Karakteristik
                        if (product.characteristics.isNotEmpty) ...[
                          const Text(
                            'Karakteristik',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: product.characteristics.map((char) {
                              IconData icon = Icons.check_circle;
                              if (char.toLowerCase().contains('renyah')) {
                                icon = Icons.cookie;
                              } else if (char.toLowerCase().contains('gurih')) {
                                icon = Icons.restaurant;
                              } else if (char.toLowerCase().contains('alami')) {
                                icon = Icons.eco;
                              }
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 18, color: const Color(0xFFC0430E)),
                                    const SizedBox(width: 8),
                                    Text(
                                      char,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 100), // Space for bottom bar
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 3. Back button (top left)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => navNotifier.goBack(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A), size: 20),
                  ),
                ),
              ),
            ),
          ),
          
          // Cart button (top right)
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => navNotifier.navigateToBuyer('cart'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF1A1A1A), size: 20),
                      ),
                      // Badge with cart count
                      if (ref.watch(cartProvider).isNotEmpty)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFC0430E),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${ref.watch(cartProvider).fold<int>(0, (sum, item) => sum + item.quantity)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),


          
          // 4. Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Chat button
                    GestureDetector(
                      onTap: () => navNotifier.navigateToBuyer('assistant'),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFFC0430E),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Masukkan Keranjang button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: product.stock <= 0
                            ? null
                            : () {
                                cartNotifier.addToCart(product);
                                showSuccessNotification(context, 'Berhasil Ditambahkan');
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC0430E),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          product.stock > 0 ? 'Masukkan Keranjang' : 'Stok Habis',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Merchant dialog pop-up simulated
  void _showMerchantChatDialog(BuildContext context, Product product) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.storefront, color: Color(0xFFC0430E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chat ${product.sellerName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tanyakan informasi ketersediaan atau detail produk ${product.name} langsung ke pengelola UMKM.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEFE6DD)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: textController,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan Anda di sini...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF7C7C7C))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Pesan Anda berhasil dikirim ke Penjual!'),
                  backgroundColor: const Color(0xFFC0430E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0430E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
