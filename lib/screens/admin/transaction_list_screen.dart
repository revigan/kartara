import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../models/order.dart';

class AdminTransactionListScreen extends ConsumerStatefulWidget {
  const AdminTransactionListScreen({super.key});

  @override
  ConsumerState<AdminTransactionListScreen> createState() => _AdminTransactionListScreenState();
}

class _AdminTransactionListScreenState extends ConsumerState<AdminTransactionListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'Semua';

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final navState = ref.watch(navigationProvider);
    final ordersNotifier = ref.read(ordersProvider.notifier);

    // Apply filtering matching visual search
    final filtered = orders.where((o) {
      final matchesSearch = o.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.recipientName.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _selectedStatus == 'Semua' || 
          o.status.toLowerCase() == _selectedStatus.toLowerCase();
      
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (centered "Kelola Pesanan" without back arrow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: const Text(
                  'Kelola Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),

            // 2. Search & Category Filters (matches Image 2 perfectly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildStatusFilters(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Transactions Cards List
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, idx) {
                        final order = filtered[idx];
                        return _buildTransactionCard(context, order, ordersNotifier);
                      },
                    ),
            ),

            // 4. Admin Navigation bottom bar
            _buildAdminBottomNavBar(navState.adminScreen, navNotifier),
          ],
        ),
      ),
    );
  }

  // Search input matching visual screen design
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDDCC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari ID pesanan atau nama...',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF7C7C7C)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF7C7C7C)),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
      ),
    );
  }

  // Premium Dropdown Status Filter
  Widget _buildStatusFilters() {
    final Map<String, String> dropdownItems = {
      'Semua': 'Semua Status Pesanan',
      'Pending': 'Pesanan Pending',
      'Diproses': 'Pesanan Diproses',
      'Dikirim': 'Pesanan Dikirim',
      'Selesai': 'Pesanan Selesai',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFDDCC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFC0430E)),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
          items: dropdownItems.entries.map((entry) {
            IconData icon;
            if (entry.key == 'Semua') {
              icon = Icons.all_inbox_rounded;
            } else if (entry.key == 'Pending') {
              icon = Icons.hourglass_empty_rounded;
            } else if (entry.key == 'Diproses') {
              icon = Icons.sync_rounded;
            } else if (entry.key == 'Dikirim') {
              icon = Icons.local_shipping_outlined;
            } else {
              icon = Icons.check_circle_outline_rounded;
            }
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFC0430E), size: 16),
                  const SizedBox(width: 8),
                  Text(entry.value),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedStatus = val;
              });
            }
          },
        ),
      ),
    );
  }

  // Styled Cracker Transaction item card
  Widget _buildTransactionCard(
    BuildContext context,
    OrderModel order,
    OrderListNotifier ordersNotifier,
  ) {
    final status = order.status.toLowerCase();
    final itemsCount = order.items.fold(0, (sum, i) => sum + i.quantity);
    
    // Status colors configurations matching Image 2 perfectly
    Color bgPillColor = const Color(0xFFFFDDCC);
    Color textPillColor = const Color(0xFFC0430E);
    String statusLabel = 'Diproses';

    if (status == 'pending') {
      bgPillColor = const Color(0xFFFFF9E6);
      textPillColor = const Color(0xFFB38F00);
      statusLabel = 'Pending';
    } else if (status == 'dikirim') {
      bgPillColor = const Color(0xFFE8F5E9);
      textPillColor = const Color(0xFF2E7D32);
      statusLabel = 'Dikirim';
    } else if (status == 'selesai') {
      bgPillColor = const Color(0xFFE8F5E9);
      textPillColor = const Color(0xFF2E7D32);
      statusLabel = 'Selesai';
    }

    // Default visual cracker thumbnail
    String thumbnail = 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=100&q=80';
    if (order.items.isNotEmpty) {
      thumbnail = order.items.first.product.imageUrl;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFDDCC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showStatusUpdateBottomSheet(context, order, ordersNotifier),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            // Cracker image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: const Color(0xFFFFF0E6)),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content details column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.id,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.recipientName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7C7C7C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemsCount item • Rp ${order.totalInvoice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),

            // Status label and arrow
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: bgPillColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: textPillColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF7C7C7C),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Update Status modal options
  void _showStatusUpdateBottomSheet(
    BuildContext context,
    OrderModel order,
    OrderListNotifier ordersNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perbarui Status Pesanan ${order.id}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mengubah status pesanan akan langsung ter-update di live tracking pembeli.',
                style: TextStyle(fontSize: 10, color: Color(0xFF7C7C7C)),
              ),
              const SizedBox(height: 20),
              
              _buildStatusOptionCard(context, order, 'pending', 'Pending (Menunggu Pembayaran)', 'Menunggu konfirmasi pembayaran', const Color(0xFFB38F00), ordersNotifier),
              _buildStatusOptionCard(context, order, 'diproses', 'Diproses UMKM', 'Sedang disiapkan oleh penjual', const Color(0xFFC0430E), ordersNotifier),
              _buildStatusOptionCard(context, order, 'dikirim', 'Dalam Pengiriman (On the way)', 'Kurir sedang mengantarkan kerupuk', const Color(0xFF2E7D32), ordersNotifier),
              _buildStatusOptionCard(context, order, 'selesai', 'Selesai', 'Kerupuk telah sampai ke tangan pembeli', const Color(0xFF2E7D32), ordersNotifier),
              
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOptionCard(
    BuildContext context,
    OrderModel order,
    String statusKey,
    String title,
    String subtitle,
    Color activeColor,
    OrderListNotifier ordersNotifier,
  ) {
    final isSelected = order.status.toLowerCase() == statusKey.toLowerCase();
    
    return GestureDetector(
      onTap: () {
        ordersNotifier.updateOrderStatus(order.id, statusKey);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pesanan ${order.id} diubah ke $title!'),
            backgroundColor: const Color(0xFFC0430E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFFFDDCC),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? activeColor : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF7C7C7C)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: activeColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Tidak ada transaksi yang sesuai filter.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  // Standard Admin Bottom Navigation Bar (active tab Pesanan selected)
  Widget _buildAdminBottomNavBar(String activeScreen, NavigationNotifier navNotifier) {
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
                icon: Icons.home_outlined,
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
}
