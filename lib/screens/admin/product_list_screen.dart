import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';

class AdminProductListScreen extends ConsumerStatefulWidget {
  const AdminProductListScreen({super.key});

  @override
  ConsumerState<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends ConsumerState<AdminProductListScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final navState = ref.watch(navigationProvider);
    final productsNotifier = ref.read(productsProvider.notifier);

    // List of real registered products from PocketBase / AppState
    final displayProducts = products;

    // Apply filtering
    final filtered = displayProducts.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Semua' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Paginate logic
    const int itemsPerPage = 10;
    final totalItems = filtered.length;
    final totalPages = (totalItems / itemsPerPage).ceil();

    // Clamp current page to valid range
    int activePage = _currentPage;
    if (activePage > totalPages && totalPages > 0) {
      activePage = totalPages;
    } else if (activePage < 1) {
      activePage = 1;
    }
    // Update state safely outside of building phase if it clamped
    if (activePage != _currentPage) {
      Future.microtask(() {
        if (mounted) setState(() => _currentPage = activePage);
      });
    }

    final startIndex = (activePage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    final paginatedItems = filtered.sublist(
      startIndex,
      endIndex > totalItems ? totalItems : endIndex,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (as shown in Screenshot 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: const Text(
                  'Kelola Produk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            
            // 2. Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFDDCC)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC0430E).withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'Cari produk...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 3. Horizontal Categories Filter
            _buildCategoriesFilter(),
            const SizedBox(height: 12),

            // 4. Products List
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: paginatedItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFF0E6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _searchQuery.isNotEmpty
                                            ? Icons.search_off
                                            : Icons.inventory_2_outlined,
                                        color: const Color(0xFFC0430E),
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Produk yang Anda Cari Tidak Ada'
                                          : 'Belum Ada Produk',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Coba gunakan kata kunci pencarian lain\natau bersihkan filter pencarian Anda!'
                                          : 'Ketuk tombol + di kanan bawah untuk\nmenambahkan produk pertama Anda!',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7C7C7C),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                                itemCount: paginatedItems.length + (totalPages > 1 ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index < paginatedItems.length) {
                                    final p = paginatedItems[index];
                                    return _buildProductRowCard(p, productsNotifier, navNotifier);
                                  } else {
                                    return _buildPaginationControls(totalPages);
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                  
                  // Floating orange plus action button
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: GestureDetector(
                      onTap: () {
                        navNotifier.navigateToAdmin('product_form', product: null);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC0430E),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 5. Admin Bottom Navigation
            _buildAdminBottomNavBar(navState.adminScreen, navNotifier, context, ref),
          ],
        ),
      ),
    );
  }

  // Categories Row Builder
  Widget _buildCategoriesFilter() {
    final Map<String, String> dropdownItems = {
      'Semua': 'Semua Produk',
      'Ikan': 'Krupuk Ikan',
      'Udang': 'Krupuk Udang',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFDDCC)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC0430E).withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC0430E)),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            dropdownColor: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(16),
            items: dropdownItems.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (String? newVal) {
              if (newVal != null) {
                setState(() {
                  _selectedCategory = newVal;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  // Inventory row item card
  Widget _buildProductRowCard(Product p, ProductListNotifier notifier, NavigationNotifier navNotifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFDDCC)),
      ),
      child: Row(
        children: [
          // Image slot
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
          
          // Info descriptions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 12, color: Color(0xFF7C7C7C)),
                    const SizedBox(width: 4),
                    Text(
                      p.sellerName.isNotEmpty ? p.sellerName : 'UMKM Jepara',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Stok: ${p.stock} pack',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${p.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC0430E),
                  ),
                ),
              ],
            ),
          ),
          
          // Edit & Delete Action icons in orange
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  navNotifier.navigateToAdmin('product_form', product: p);
                },
                child: const Icon(Icons.edit_outlined, color: Color(0xFFC0430E), size: 20),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _showConfirmDeleteDialog(context, p, notifier),
                child: const Icon(Icons.delete_outline, color: Color(0xFFC0430E), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConfirmDeleteDialog(BuildContext context, Product p, ProductListNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Apakah Anda yakin ingin menghapus "${p.name}" dari katalog Anda?', style: const TextStyle(fontSize: 11, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              notifier.deleteProduct(p.id);
              Navigator.pop(context);
              _showSuccessDialog(context, 'Berhasil Dihapus');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Auto-close the dialog after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF166534), // Deep premium green
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF166534),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFFFDDCC).withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous Button
          GestureDetector(
            onTap: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _currentPage > 1 ? const Color(0xFFFFF0E6) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_left,
                color: _currentPage > 1 ? const Color(0xFFC0430E) : const Color(0xFF7C7C7C).withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // Page Numbers / Indicators
          for (int i = 1; i <= totalPages; i++) ...[
            GestureDetector(
              onTap: () => setState(() => _currentPage = i),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == i ? const Color(0xFFC0430E) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _currentPage == i ? const Color(0xFFC0430E) : const Color(0xFFFFDDCC),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$i',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _currentPage == i ? Colors.white : const Color(0xFF7C7C7C),
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(width: 20),
          
          // Next Button
          GestureDetector(
            onTap: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _currentPage < totalPages ? const Color(0xFFFFF0E6) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right,
                color: _currentPage < totalPages ? const Color(0xFFC0430E) : const Color(0xFF7C7C7C).withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Consistent Admin Navigation Bar
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
                icon: Icons.home_outlined,
                label: 'Beranda',
                isActive: activeScreen == 'dashboard',
                onTap: () => navNotifier.navigateToAdmin('dashboard'),
              ),
              _buildNavItem(
                icon: Icons.shopping_bag,
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
