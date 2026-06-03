import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navNotifier = ref.read(navigationProvider.notifier);
    final navState = ref.watch(navigationProvider);
    final authState = ref.watch(authProvider);
    final products = ref.watch(productsProvider);
    final orders = ref.watch(ordersProvider);
    final customers = ref.watch(registeredCustomersProvider);

    final adminName = authState.currentUser?.name ?? 'Admin Kartara';

    // Kalkulasi nilai statistik dinamis
    final totalPenjualan = orders.fold(0.0, (sum, o) => sum + o.totalInvoice);
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final formattedSales = formatter.format(totalPenjualan);

    final totalOrders = orders.length;
    final totalProducts = products.length;
    final totalCustomers = customers.length;

    // Tentukan ucapan selamat berdasarkan waktu local
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 11) {
      greeting = 'Selamat pagi,';
    } else if (hour >= 11 && hour < 15) {
      greeting = 'Selamat siang,';
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat sore,';
    } else {
      greeting = 'Selamat malam,';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Row (as shown in Screenshot 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36),
                  const Text(
                    'Kartara Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC0430E),
                    ),
                  ),
                  // Admin avatar profile circle
                  GestureDetector(
                    onTap: () => _showAdminProfileDialog(context, ref, navNotifier),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF0E6),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Icon(Icons.person, color: const Color(0xFFC0430E).withOpacity(0.8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. Main content area (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Greeting text
                    Text(
                      greeting,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7C7C7C)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adminName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card Total Penjualan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC0430E),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC0430E).withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Penjualan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formattedSales,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '↗ Terhubung Live',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Wallet icon background element on the right
                          Positioned(
                            right: 0,
                            top: 8,
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.white.withOpacity(0.15),
                              size: 54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Divided Stats Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFDDCC)),
                      ),
                      child: Row(
                        children: [
                          _buildStatItem('Pesanan', totalOrders.toString()),
                          Container(width: 1, height: 32, color: const Color(0xFFFFDDCC)),
                          _buildStatItem('Produk', totalProducts.toString()),
                          Container(width: 1, height: 32, color: const Color(0xFFFFDDCC)),
                          _buildStatItem('Pelanggan', totalCustomers.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Promo & Banners Management Card
                    GestureDetector(
                      onTap: () => navNotifier.navigateToAdmin('promo_management'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF0E6), Color(0xFFFFD5B8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFD1B3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC0430E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.confirmation_number_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kelola Kupon & Banner Promo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tambah, aktifkan, atau hapus kupon & banner live di aplikasi pembeli.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFF1A1A1A).withOpacity(0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFFC0430E),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Transaksi Terbaru Header with link "Lihat semua"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transaksi Terbaru',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => navNotifier.navigateToAdmin('transactions'),
                          child: const Text(
                            'Lihat semua',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC0430E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tampilan transaksi dinamis / empty state
                    if (orders.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFDDCC)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF0E6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xFFC0430E),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum Ada Transaksi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Semua transaksi baru pelanggan akan muncul di sini secara real-time!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7C7C7C),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...orders.take(3).map((order) {
                        final isSuccess = order.status == 'selesai' || order.status == 'dikirim';
                        final formattedOrderDate = DateFormat('dd MMM, HH:mm').format(order.orderDate);
                        final displayStatus = order.status.isEmpty 
                            ? 'Pending' 
                            : order.status[0].toUpperCase() + order.status.substring(1);
                        return _buildTransactionItem(
                          id: order.id,
                          time: formattedOrderDate,
                          price: formatter.format(order.totalInvoice),
                          status: displayStatus,
                          isSuccess: isSuccess,
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // 3. Admin-Specific Bottom Navigation Bar
            _buildAdminBottomNavBar(navState.adminScreen, navNotifier, context, ref),
          ],
        ),
      ),
    );
  }

  // Stats Column helper
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  // Transaction card item helper
  Widget _buildTransactionItem({
    required String id,
    required String time,
    required String price,
    required String status,
    required bool isSuccess,
  }) {
    final statusBg = isSuccess ? const Color(0xFFE2F0D9) : const Color(0xFFFFF0E6);
    final statusColor = isSuccess ? const Color(0xFF388E3C) : const Color(0xFFC0430E);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDDCC)),
      ),
      child: Row(
        children: [
          // Shopping bag icon inside peach background square
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF6B2A0C), size: 20),
          ),
          const SizedBox(width: 12),
          
          // Transaction Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                ),
              ],
            ),
          ),
          
          // Price & Status Badge Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC0430E),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Admin Bottom Navigation Bar Builder
  Widget _buildAdminBottomNavBar(String activeScreen, NavigationNotifier navNotifier, BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Beranda',
                isActive: activeScreen == 'dashboard',
                onTap: () => navNotifier.navigateToAdmin('dashboard'),
              ),
              _buildNavItem(
                icon: Icons.shopping_bag_outlined,
                label: 'Produk',
                isActive: activeScreen == 'products' || activeScreen == 'product_form',
                onTap: () => navNotifier.navigateToAdmin('products'),
              ),
              _buildNavItem(
                icon: Icons.star_border,
                label: 'Pesanan',
                isActive: activeScreen == 'transactions',
                onTap: () => navNotifier.navigateToAdmin('transactions'),
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                label: 'Akun',
                isActive: activeScreen == 'profile',
                onTap: () => navNotifier.navigateToAdmin('profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? const Color(0xFFC0430E) : const Color(0xFF7C7C7C);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Account dialog
  void _showAdminProfileDialog(BuildContext context, WidgetRef ref, NavigationNotifier navNotifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Profil Admin Kartara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFFFF0E6),
              child: Icon(Icons.person, color: Color(0xFFC0430E), size: 32),
            ),
            const SizedBox(height: 12),
            const Text('Admin Kartara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('admin@kartara.com', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showConfirmLogoutDialog(context, ref);
              },
              icon: const Icon(Icons.logout, color: Colors.red, size: 16),
              label: const Text('Keluar (Logout)', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: const Text('Apakah Anda yakin ingin keluar (logout) dari akun Anda?', style: TextStyle(fontSize: 11, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
