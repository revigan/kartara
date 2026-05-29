import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';
import '../../models/promo_banner.dart';
import '../../widgets/success_notification.dart';
import 'promo_screen.dart';

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua'; // 'Semua' selected by default
  bool _isDrawerOpen = false;
  bool _showCatalog = false; // false = dashboard, true = catalog
  String _sortBy = 'Terbaru';
  bool _filterDiscountOnly = false;
  bool _filterInStockOnly = false;

  late final PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  // Categories data
  final List<Map<String, dynamic>> categoriesData = [
    {'name': 'Semua', 'icon': Icons.grid_view},
    {'name': 'Ikan', 'icon': Icons.set_meal},
    {'name': 'Udang', 'icon': Icons.water},
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll(int bannersCount) {
    _bannerTimer?.cancel();
    if (bannersCount <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      _currentBannerPage = (_currentBannerPage + 1) % bannersCount;
      if (_bannerController.hasClients) {
        _bannerController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final banners = ref.watch(bannersProvider);
    final orders = ref.watch(ordersProvider);
    final activeBanners = banners.where((b) => b.isActive).toList();
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);

    // Auto-scroll logic trigger
    if (activeBanners.length > 1 && _bannerTimer == null) {
      _startBannerAutoScroll(activeBanners.length);
    } else if (activeBanners.length <= 1 && _bannerTimer != null) {
      _bannerTimer?.cancel();
      _bannerTimer = null;
    }

    // Filter products based on search query, category, and checkboxes
    final filteredProducts = products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sellerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Semua' || p.category == _selectedCategory;
      final matchesDiscount = !_filterDiscountOnly || p.hasDiscount;
      final matchesStock = !_filterInStockOnly || p.stock > 0;
      return p.isActive && matchesSearch && matchesCategory && matchesDiscount && matchesStock;
    }).toList();

    // Sort products
    if (_sortBy == 'Harga Tertinggi') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'Harga Terendah') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'Rating Tertinggi') {
      filteredProducts.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'Terbaru') {
      filteredProducts.sort((a, b) => b.id.compareTo(a.id));
    }

    return Scaffold(
      backgroundColor: _showCatalog ? Colors.white : const Color(0xFFFAF7F2),
      body: _showCatalog ? _buildCatalogView(filteredProducts, cart, navNotifier, cartNotifier, navState) : _buildDashboardView(activeBanners, cart, navNotifier, navState, orders, products, cartNotifier),
      
      bottomNavigationBar: _buildBottomNav(
        navState.buyerTab,
        navNotifier,
        cart.length,
        orders.where((o) => o.status.toLowerCase() != 'selesai').length,
      ),
      
      // Floating Action Button untuk Asisten Kartara (hanya di dashboard)
      floatingActionButton: !_showCatalog ? FloatingActionButton(
        onPressed: () => navNotifier.navigateToBuyer('assistant'),
        backgroundColor: const Color(0xFFC0430E),
        elevation: 6,
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 28,
        ),
      ) : null,
    );
  }

  // Dashboard View
  Widget _buildDashboardView(
    List<PromoBanner> activeBanners, 
    List cart, 
    NavigationNotifier navNotifier, 
    AppNavigationState navState, 
    List orders,
    List<Product> products,
    CartNotifier cartNotifier,
  ) {
    // Take the active products from PocketBase filtered by selected category on the dashboard
    final activeProducts = products.where((p) {
      final matchesCategory = _selectedCategory == 'Semua' || p.category.toLowerCase() == _selectedCategory.toLowerCase();
      return p.isActive && matchesCategory;
    }).toList();
    final displayProducts = activeProducts.take(4).toList();

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              // Dashboard Header
              _buildDashboardHeader(cart.length),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      _buildSearchBar(),
                      const SizedBox(height: 20),

                      // Promo Banner
                      _buildPromoBanner(activeBanners),
                      const SizedBox(height: 24),

                      // Kategori Pilihan
                      _buildKategoriPilihan(),
                      const SizedBox(height: 24),

                      // Today's Recommendations Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rekomendasi Hari Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'Semua';
                                _showCatalog = true;
                              });
                            },
                            child: const Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC0430E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Product Grid or Empty State
                      displayProducts.isEmpty
                          ? _buildEmptyState()
                          : _buildProductGrid(displayProducts, cartNotifier, navNotifier),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Drawer Sidebar Overlay
        if (_isDrawerOpen) _buildSidebarDrawer(context, navNotifier),
      ],
    );
  }

  Widget _buildPromoBanner(List<PromoBanner> activeBanners) {
    if (activeBanners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: activeBanners.length,
            onPageChanged: (index) {
              setState(() {
                _currentBannerPage = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = activeBanners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(banner.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC0430E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Promo Spesial',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        banner.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (activeBanners.length > 1)
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                activeBanners.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentBannerPage == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentBannerPage == index
                        ? const Color(0xFFC0430E)
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKategoriPilihan() {
    final categories = [
      {'name': 'Semua', 'icon': Icons.category},
      {'name': 'Ikan', 'icon': Icons.set_meal},
      {'name': 'Udang', 'icon': Icons.water},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori Pilihan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
            color: Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.builder(
            itemCount: categories.length,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final catName = cat['name'] as String;
              final catIcon = cat['icon'] as IconData;
              final isSelected = catName == _selectedCategory;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = catName;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFC0430E) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFC0430E),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        catIcon,
                        color: isSelected ? Colors.white : const Color(0xFFC0430E),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        catName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF5D4037),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Catalog View
  Widget _buildCatalogView(List<Product> filteredProducts, List cart, NavigationNotifier navNotifier, cartNotifier, AppNavigationState navState) {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              // Catalog Header
              _buildHeader(context, cart.length),
                
                // Content Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // Search Bar
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        
                        // Filter Section (Kategori, Urutkan, Filter)
                        _buildFilterSection(),
                        const SizedBox(height: 20),
                        
                        // Product Grid (all products, no "Rekomendasi" header)
                        (() {
                          return filteredProducts.isEmpty
                              ? _buildEmptyState()
                              : _buildProductGrid(filteredProducts, cartNotifier, navNotifier);
                        })(),
                        const SizedBox(height: 80), // Padding to prevent bottom nav overlap
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Drawer Sidebar Overlay
        if (_isDrawerOpen) _buildSidebarDrawer(context, navNotifier),
      ],
    );
  }

  // Dashboard Header
  Widget _buildDashboardHeader(int cartCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu Button
          GestureDetector(
            onTap: () => setState(() => _isDrawerOpen = true),
            child: Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.menu, color: Color(0xFFC0430E), size: 28),
            ),
          ),
          
          // Brand Logo
          const Text(
            'Kartara',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC0430E),
              letterSpacing: 0.3,
            ),
          ),
          
          // Cart Button
          GestureDetector(
            onTap: () => ref.read(navigationProvider.notifier).navigateToBuyer('cart'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Color(0xFF424242), size: 26),
                if (cartCount > 0)
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
                        '$cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Header (Back button for catalog, Logo, Cart badge)
  Widget _buildHeader(BuildContext context, int cartCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button (kembali ke dashboard)
          GestureDetector(
            onTap: () => setState(() => _showCatalog = false),
            child: Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.arrow_back, color: Color(0xFFC0430E), size: 28),
            ),
          ),
          
          // Title "Katalog Produk"
          const Text(
            'Katalog Produk',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          
          // Cart Button with badge
          GestureDetector(
            onTap: () => ref.read(navigationProvider.notifier).navigateToBuyer('cart'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Color(0xFF424242), size: 26),
                if (cartCount > 0)
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
                        '$cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Search Bar Widget
  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFC0430E), width: 1.5),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: const InputDecoration(
          hintText: 'Cari krupuk favoritmu...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF9E9E9E),
          ),
          prefixIcon: Icon(Icons.search, color: Color(0xFF9E9E9E), size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  // 3. Filter Section (Kategori, Urutkan, Filter)
  Widget _buildFilterSection() {
    return Row(
      children: [
        // Kategori Dropdown
        Expanded(
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Kategori',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...categoriesData.map((cat) {
                        final catName = cat['name'] as String;
                        final isSelected = catName == _selectedCategory;
                        return ListTile(
                          leading: Icon(
                            cat['icon'] as IconData,
                            color: isSelected ? const Color(0xFFC0430E) : const Color(0xFF757575),
                          ),
                          title: Text(
                            catName,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFC0430E) : const Color(0xFF424242),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Color(0xFFC0430E))
                              : null,
                          onTap: () {
                            setState(() => _selectedCategory = catName);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory == 'Semua' ? 'Kategori' : _selectedCategory,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF424242),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF757575)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // Urutkan Dropdown
        Expanded(
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => StatefulBuilder(
                  builder: (context, setModalState) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Urutkan Berdasarkan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSortTile(setModalState, 'Harga Tertinggi', Icons.trending_up),
                        _buildSortTile(setModalState, 'Harga Terendah', Icons.trending_down),
                        _buildSortTile(setModalState, 'Rating Tertinggi', Icons.star),
                        _buildSortTile(setModalState, 'Terbaru', Icons.new_releases),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _sortBy == 'Terbaru' ? 'Urutkan' : _sortBy,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF424242),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF757575)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // Filter Button
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => StatefulBuilder(
                builder: (context, setModalState) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Produk',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        activeColor: const Color(0xFFC0430E),
                        title: const Text('Produk Diskon'),
                        value: _filterDiscountOnly,
                        onChanged: (val) {
                          setState(() {
                            _filterDiscountOnly = val ?? false;
                          });
                          setModalState(() {});
                        },
                      ),
                      CheckboxListTile(
                        activeColor: const Color(0xFFC0430E),
                        title: const Text('Stok Tersedia'),
                        value: _filterInStockOnly,
                        onChanged: (val) {
                          setState(() {
                            _filterInStockOnly = val ?? false;
                          });
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC0430E),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Terapkan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_filterDiscountOnly || _filterInStockOnly)
                    ? const Color(0xFFC0430E)
                    : const Color(0xFFE0E0E0),
                width: (_filterDiscountOnly || _filterInStockOnly) ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: Color(0xFFC0430E)),
                const SizedBox(width: 4),
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFFC0430E),
                    fontWeight: (_filterDiscountOnly || _filterInStockOnly)
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortTile(StateSetter setModalState, String sortOption, IconData icon) {
    final isSelected = _sortBy == sortOption;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFFC0430E) : const Color(0xFF757575),
      ),
      title: Text(
        sortOption,
        style: TextStyle(
          color: isSelected ? const Color(0xFFC0430E) : const Color(0xFF424242),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFFC0430E))
          : null,
      onTap: () {
        setState(() {
          _sortBy = sortOption;
        });
        setModalState(() {});
        Navigator.pop(context);
      },
    );
  }

  // 4. Promo Banners Carousel (REMOVED - not in new design)
  Widget _buildPromoBanners(List<PromoBanner> banners) {
    return const SizedBox.shrink(); // Hidden in catalog view
  }

  // Quick Actions for Dashboard
  Widget _buildQuickActions(NavigationNotifier navNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Akses Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.shopping_bag,
                label: 'Katalog Produk',
                color: const Color(0xFFC0430E),
                onTap: () => setState(() => _showCatalog = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.history,
                label: 'Riwayat',
                color: const Color(0xFF2196F3),
                onTap: () => navNotifier.changeBuyerTab(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.chat_bubble_outline,
                label: 'Asisten',
                color: const Color(0xFF4CAF50),
                onTap: () => navNotifier.changeBuyerTab(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.person_outline,
                label: 'Akun',
                color: const Color(0xFFFF9800),
                onTap: () => navNotifier.changeBuyerTab(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dashboard Categories
  Widget _buildDashboardCategories() {
    return Row(
      children: [
        Expanded(
          child: _buildCategoryCard(
            icon: Icons.set_meal,
            label: 'Ikan',
            onTap: () {
              setState(() {
                _selectedCategory = 'Ikan';
                _showCatalog = true;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCategoryCard(
            icon: Icons.water,
            label: 'Udang',
            onTap: () {
              setState(() {
                _selectedCategory = 'Udang';
                _showCatalog = true;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFC0430E), size: 48),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OLD BANNER CODE BELOW (keeping for reference but not used)
  Widget _buildPromoBannersOld(List<PromoBanner> banners) {
    if (banners.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      child: PageView.builder(
        itemCount: banners.length,
        controller: _bannerController,
        onPageChanged: (index) {
          _currentBannerPage = index;
        },
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(banner.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC0430E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Promo Spesial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. Horizontal Categories filter
  Widget _buildCategories() {
    final categoriesData = [
      {'name': 'Semua', 'icon': Icons.apps_rounded},
      {'name': 'Ikan', 'icon': Icons.phishing_outlined},
      {'name': 'Udang', 'icon': Icons.set_meal},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori Pilihan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ListView.builder(
            itemCount: categoriesData.length,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, idx) {
              final catName = categoriesData[idx]['name'] as String;
              final catIcon = categoriesData[idx]['icon'] as IconData;
              final isSelected = catName == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = catName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFC0430E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFFC0430E).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        catIcon,
                        color: isSelected ? Colors.white : const Color(0xFF757575),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        catName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 5. Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: const Color(0xFFC0430E).withOpacity(0.5)),
            const SizedBox(height: 14),
            const Text(
              'Kerupuk tidak ditemukan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cobalah mencari jenis kerupuk atau UMKM lainnya.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Recommendation Product Grid
  Widget _buildProductGrid(
    List<Product> products,
    CartNotifier cartNotifier,
    NavigationNotifier navNotifier,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, idx) {
        final p = products[idx];
        return GestureDetector(
          onTap: () => navNotifier.navigateToBuyer('detail', product: p),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image with badges
                Expanded(
                  child: Stack(
                    children: [
                      // Image clip
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF5F5F5),
                              child: const Icon(Icons.image_outlined, color: Color(0xFFBDBDBD), size: 40),
                            ),
                          ),
                        ),
                      ),
                      // Top Right Green "Asli" badge
                      if (p.id == 'p1')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Asli',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Top Right Discount badge
                      if (p.hasDiscount)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '-${p.discountPercentage}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      // Top Right Red "Pedas" badge (only if no discount)
                      else if (p.id == 'p4')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Pedas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Stock Out indicator
                      if (p.stock <= 0)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32F2F),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'HABIS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Product Info Text Section
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seller Name (UMKM)
                      Text(
                        p.sellerName,
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Product Name
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Bottom Row: Price & Add to Cart button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rp ${p.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFFC0430E),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (p.hasDiscount)
                                  Text(
                                    'Rp ${p.originalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF9E9E9E),
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Plus Action button
                          GestureDetector(
                            onTap: p.stock <= 0
                                ? null
                                : () {
                                    cartNotifier.addToCart(p);
                                    showSuccessNotification(context, 'Berhasil Ditambahkan');
                                  },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: p.stock <= 0
                                    ? const Color(0xFFF5F5F5)
                                    : const Color(0xFFF5EBE1), // Light peach background
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                color: p.stock <= 0 ? const Color(0xFFBDBDBD) : const Color(0xFF5D4037), // Dark brown icon
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 7. Dynamic Sidebar Drawer
  Widget _buildSidebarDrawer(BuildContext context, NavigationNotifier navNotifier) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Black screen background overlay
          GestureDetector(
            onTap: () => setState(() => _isDrawerOpen = false),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          
          // Drawer body (slides from left)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 280,
            child: Material(
              color: const Color(0xFFFAF7F2),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand Info Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC0430E).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.waves_rounded, color: Color(0xFFC0430E), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KARTARA',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                'Versi 1.0.0',
                                style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                              )
                            ],
                          )
                        ],
                      ),
                      const Divider(height: 32, thickness: 1),
                      
                      // Sidebar Navigation Links
                      _buildSidebarLink(Icons.storefront_outlined, 'Beranda Utama', () {
                        setState(() => _isDrawerOpen = false);
                        navNotifier.changeBuyerTab(0);
                      }),
                      _buildSidebarLink(Icons.history_outlined, 'Riwayat Pembelian', () {
                        setState(() => _isDrawerOpen = false);
                        navNotifier.navigateToBuyer('history');
                      }),
                      _buildSidebarLink(Icons.chat_outlined, 'Asisten AI Kartara', () {
                        setState(() => _isDrawerOpen = false);
                        navNotifier.navigateToBuyer('assistant');
                      }),
                      _buildSidebarLink(Icons.card_giftcard_outlined, 'Kupon & Promo', () {
                        setState(() => _isDrawerOpen = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PromoScreen(),
                          ),
                        );
                      }),
                      const Spacer(),
                      
                      // Bottom Signout/Close indicator
                      const Divider(height: 24),
                      const Text(
                        'Pusat Bantuan Kartara Jepara',
                        style: TextStyle(fontSize: 10, color: Color(0xFF7C7C7C), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kec. Tahunan, Kabupaten Jepara\nIndonesia',
                        style: TextStyle(fontSize: 9, color: Colors.grey, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarLink(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFC0430E), size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
      onTap: onTap,
    );
  }

  // 8. Custom Bottom Navigation Bar - styled vertically (icon on top, label on bottom)
  Widget _buildBottomNav(int selectedTab, NavigationNotifier navNotifier, int cartCount, int uncompletedCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Beranda',
                isActive: selectedTab == 0,
                onTap: () => navNotifier.changeBuyerTab(0),
              ),
              _buildBottomNavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment,
                label: 'Pesanan',
                isActive: selectedTab == 1,
                onTap: () => navNotifier.changeBuyerTab(1),
                badgeCount: uncompletedCount,
              ),
              _buildBottomNavItem(
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum,
                label: 'Asisten',
                isActive: selectedTab == 2,
                onTap: () => navNotifier.changeBuyerTab(2),
              ),
              _buildBottomNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Akun',
                isActive: selectedTab == 3,
                onTap: () => navNotifier.changeBuyerTab(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? const Color(0xFFC0430E) : const Color(0xFF7C7C7C),
                size: 24,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC0430E),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFC0430E) : const Color(0xFF7C7C7C),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
