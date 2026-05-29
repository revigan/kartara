import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => navNotifier.navigateToBuyer('home'),
        ),
        title: const Text(
          'Kartara',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFC0430E),
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFFC0430E)),
            onPressed: () {},
          ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmptyCartState(navNotifier)
          : Column(
              children: [
                // Header dengan judul dan jumlah produk
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFFF5F1ED),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Keranjang Anda',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cart.length} produk ditambahkan',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B5E52),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Cart Items List
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.length,
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, idx) {
                      final item = cart[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: Image.network(
                                  item.product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFFFF0E6),
                                    child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 24),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Product Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C2C2C),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Indikator stok
                                  Row(
                                    children: [
                                      Icon(
                                        item.quantity >= item.product.stock
                                            ? Icons.warning_amber_rounded
                                            : Icons.inventory_2_outlined,
                                        size: 12,
                                        color: item.quantity >= item.product.stock
                                            ? Colors.orange
                                            : const Color(0xFF6B5E52),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.quantity >= item.product.stock
                                            ? 'Stok habis (max ${item.product.stock})'
                                            : 'Stok: ${item.product.stock}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.quantity >= item.product.stock
                                              ? Colors.orange
                                              : const Color(0xFF6B5E52),
                                          fontWeight: item.quantity >= item.product.stock
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rp ${item.product.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                    style: const TextStyle(
                                      color: Color(0xFFC0430E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Delete and Quantity Controls
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Delete Icon
                                GestureDetector(
                                  onTap: () {
                                    // Show confirmation dialog
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        title: const Text(
                                          'Hapus Produk?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Color(0xFF2C2C2C),
                                          ),
                                        ),
                                        content: Text(
                                          'Apakah Anda yakin ingin menghapus "${item.product.name}" dari keranjang?',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B5E52),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text(
                                              'Batal',
                                              style: TextStyle(
                                                color: Color(0xFF6B5E52),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              cartNotifier.removeFromCart(item.product.id);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${item.product.name} dihapus dari keranjang'),
                                                  backgroundColor: const Color(0xFF6B5E52),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFC0430E),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Hapus',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Color(0xFFC0430E),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Quantity Controls
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE0D5C7)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (item.quantity > 1) {
                                            cartNotifier.updateQuantity(item.product.id, item.quantity - 1);
                                          } else {
                                            // Show confirmation dialog when quantity is 1
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                title: const Text(
                                                  'Hapus Produk?',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Color(0xFF2C2C2C),
                                                  ),
                                                ),
                                                content: Text(
                                                  'Apakah Anda yakin ingin menghapus "${item.product.name}" dari keranjang?',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF6B5E52),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text(
                                                      'Batal',
                                                      style: TextStyle(
                                                        color: Color(0xFF6B5E52),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      cartNotifier.removeFromCart(item.product.id);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('${item.product.name} dihapus dari keranjang'),
                                                          backgroundColor: const Color(0xFF6B5E52),
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFC0430E),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Hapus',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: const Text(
                                            '-',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C2C2C),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (item.quantity >= item.product.stock) {
                                            // Stok habis - tampilkan peringatan
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Stok ${item.product.name} hanya ${item.product.stock} unit',
                                                        style: const TextStyle(fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.orange[700],
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          } else {
                                            cartNotifier.updateQuantity(item.product.id, item.quantity + 1);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Text(
                                            '+',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              // Abu-abu jika stok habis
                                              color: item.quantity >= item.product.stock
                                                  ? Colors.grey[400]
                                                  : const Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Bottom Summary and Checkout
                _buildBillingPanel(context, cartNotifier, navNotifier, ref),
              ],
            ),
    );
  }

  // Illustrated empty cart page
  Widget _buildEmptyCartState(NavigationNotifier navNotifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Color(0xFFC0430E),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keranjang Belanja Kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Anda belum menambahkan kerupuk khas Jepara pilihan Anda ke keranjang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B5E52),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => navNotifier.navigateToBuyer('home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0430E),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Mulai Belanja',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cost summary breakdown panel
  Widget _buildBillingPanel(
    BuildContext context,
    CartNotifier cartNotifier,
    NavigationNotifier navNotifier,
    WidgetRef ref,
  ) {
    final cart = ref.watch(cartProvider);
    final subtotal = cart.fold(0.0, (sum, item) => sum + item.totalPrice);
    final total = subtotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Belanja',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 16),
            
            // Total Harga Line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Harga (${cart.fold(0, (sum, item) => sum + item.quantity)} barang)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B5E52),
                  ),
                ),
                Text(
                  'Rp ${subtotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                height: 1,
                color: Color(0xFFE0D5C7),
              ),
            ),
            
            // Total Tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tagihan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                Text(
                  'Rp ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC0430E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Checkout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => navNotifier.navigateToBuyer('checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC0430E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lanjut ke Checkout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
