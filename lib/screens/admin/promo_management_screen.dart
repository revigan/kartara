import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../config/pocketbase_config.dart';
import '../../providers/app_state.dart';
import '../../models/promo_banner.dart';
import '../../models/coupon.dart';
import '../../models/product.dart';

class AdminPromoManagementScreen extends ConsumerStatefulWidget {
  const AdminPromoManagementScreen({super.key});

  @override
  ConsumerState<AdminPromoManagementScreen> createState() => _AdminPromoManagementScreenState();
}

class _AdminPromoManagementScreenState extends ConsumerState<AdminPromoManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider);
    final coupons = ref.watch(couponsProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => navNotifier.navigateToAdmin('dashboard'),
        ),
        title: const Text(
          'Kelola Promo & Banner',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFC0430E),
          unselectedLabelColor: const Color(0xFF7C7C7C),
          indicatorColor: const Color(0xFFC0430E),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Banner Promo'),
            Tab(text: 'Kupon Diskon'),
            Tab(text: 'Diskon Produk'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBannersTab(banners),
          _buildCouponsTab(coupons),
          _buildProductDiscountsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddBannerSheet(context);
          } else if (_tabController.index == 1) {
            _showAddCouponSheet(context);
          } else {
            _showAddProductDiscountSheet(context);
          }
        },
        backgroundColor: const Color(0xFFC0430E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0
              ? 'Tambah Banner'
              : _tabController.index == 1
                  ? 'Tambah Kupon'
                  : 'Tambah Diskon',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==========================================
  // BANNERS TAB
  // ==========================================
  Widget _buildBannersTab(List<PromoBanner> banners) {
    if (banners.isEmpty) {
      return _buildEmptyState('Belum Ada Banner Promo', 'Tambahkan banner visual untuk memikat pembeli di halaman beranda.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: banners.length,
      itemBuilder: (context, index) {
        final banner = banners[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFDDCC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  banner.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: const Color(0xFFFFF0E6),
                    child: const Icon(Icons.broken_image, color: Color(0xFFC0430E), size: 36),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            banner.subtitle,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                          ),
                        ],
                      ),
                    ),
                    // Toggle Switch
                    Switch(
                      value: banner.isActive,
                      onChanged: (val) => _toggleBannerActive(banner, val),
                      activeColor: const Color(0xFFC0430E),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFFC0430E)),
                      onPressed: () => _showAddBannerSheet(context, banner: banner),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDeleteBanner(banner),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // COUPONS TAB
  // ==========================================
  Widget _buildCouponsTab(List<Coupon> coupons) {
    if (coupons.isEmpty) {
      return _buildEmptyState('Belum Ada Kupon Diskon', 'Buat kupon belanja spesial agar pembeli semakin bersemangat checkout!');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFDDCC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Visual Coupon Dashed Badge removed as requested to keep code invisible but saved in database
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potongan Rp ${coupon.discountAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Min. Blj: Rp ${coupon.minPurchase.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                    ),
                  ],
                ),
              ),
              // Toggle switch
              Switch(
                value: coupon.isActive,
                onChanged: (val) => _toggleCouponActive(coupon, val),
                activeColor: const Color(0xFFC0430E),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFFC0430E)),
                onPressed: () => _showAddCouponSheet(context, coupon: coupon),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteCoupon(coupon),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // EMPTY STATE HELPER
  // ==========================================
  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFC0430E), size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CONTROLLER ACTIONS (POCKETBASE LOGIC)
  // ==========================================
  Future<void> _toggleBannerActive(PromoBanner banner, bool val) async {
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      final pb = PocketBase(PocketBaseConfig.baseUrl);
      await pb.collection('banners').update(banner.id, body: {'isActive': val});
      ref.read(bannersProvider.notifier).fetchBanners();
    } catch (e) {
      debugPrint('Error toggling banner: $e');
    }
  }

  Future<void> _toggleCouponActive(Coupon coupon, bool val) async {
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      final pb = PocketBase(PocketBaseConfig.baseUrl);
      await pb.collection('coupons').update(coupon.id, body: {'isActive': val});
      ref.read(couponsProvider.notifier).fetchCoupons();
    } catch (e) {
      debugPrint('Error toggling coupon: $e');
    }
  }

  void _confirmDeleteBanner(PromoBanner banner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Apakah Anda yakin ingin menghapus banner "${banner.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (PocketBaseConfig.enablePocketBase) {
                final pb = PocketBase(PocketBaseConfig.baseUrl);
                await pb.collection('banners').delete(banner.id);
                ref.read(bannersProvider.notifier).fetchBanners();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _confirmDeleteCoupon(Coupon coupon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Kupon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Apakah Anda yakin ingin menghapus kupon "${coupon.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (PocketBaseConfig.enablePocketBase) {
                final pb = PocketBase(PocketBaseConfig.baseUrl);
                await pb.collection('coupons').delete(coupon.id);
                ref.read(couponsProvider.notifier).fetchCoupons();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // ==========================================
  // ADD BANNER BOTTOM SHEET
  // ==========================================
  void _showAddBannerSheet(BuildContext context, {PromoBanner? banner}) {
    final titleCtrl = TextEditingController(text: banner?.title ?? '');
    final subCtrl = TextEditingController(text: banner?.subtitle ?? '');
    XFile? selectedImage;
    bool isActive = banner?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7F2),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // Beautiful Header with Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      banner != null ? 'Edit Banner' : 'Tambah Banner Baru', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFFC0430E)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFFFDDCC), height: 1),
              
              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Judul Promo Banner',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subCtrl,
                        decoration: InputDecoration(
                          labelText: 'Deskripsi / Subtitle',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Visual premium image picker selector container
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (file != null) {
                            setSheetState(() {
                              selectedImage = file;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFD1B3), width: 1.5),
                          ),
                          child: selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: kIsWeb
                                      ? Image.network(
                                          selectedImage!.path,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : Image.file(
                                          File(selectedImage!.path),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                )
                              : (banner != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        banner.imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFC0430E), size: 36),
                                        SizedBox(height: 8),
                                        Text(
                                          'Pilih / Unggah Gambar Banner',
                                          style: TextStyle(
                                            color: Color(0xFFC0430E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Klik untuk memilih file gambar dari galeri Anda',
                                          style: TextStyle(color: Colors.grey, fontSize: 10),
                                        ),
                                      ],
                                    )),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Langsung Aktifkan Banner', style: TextStyle(fontSize: 13)),
                          Switch(
                            value: isActive,
                            onChanged: (val) => setSheetState(() => isActive = val),
                            activeColor: const Color(0xFFC0430E),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (titleCtrl.text.isEmpty || (selectedImage == null && banner == null)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Harap lengkapi judul dan pilih gambar banner!')),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            
                            if (PocketBaseConfig.enablePocketBase) {
                              try {
                                final pb = PocketBase(PocketBaseConfig.baseUrl);
                                if (banner != null) {
                                  if (selectedImage != null) {
                                    final bytes = await selectedImage!.readAsBytes();
                                    final multipartFile = http.MultipartFile.fromBytes(
                                      'image',
                                      bytes,
                                      filename: selectedImage!.name,
                                    );
                                    await pb.collection('banners').update(
                                      banner.id,
                                      body: {
                                        'title': titleCtrl.text.trim(),
                                        'subtitle': subCtrl.text.trim(),
                                        'isActive': isActive,
                                      },
                                      files: [multipartFile],
                                    );
                                  } else {
                                    await pb.collection('banners').update(
                                      banner.id,
                                      body: {
                                        'title': titleCtrl.text.trim(),
                                        'subtitle': subCtrl.text.trim(),
                                        'isActive': isActive,
                                      },
                                    );
                                  }
                                } else {
                                  final bytes = await selectedImage!.readAsBytes();
                                  final multipartFile = http.MultipartFile.fromBytes(
                                    'image',
                                    bytes,
                                    filename: selectedImage!.name,
                                  );
                                  
                                  await pb.collection('banners').create(
                                    body: {
                                      'title': titleCtrl.text.trim(),
                                      'subtitle': subCtrl.text.trim(),
                                      'isActive': isActive,
                                    },
                                    files: [multipartFile],
                                  );
                                }
                                ref.read(bannersProvider.notifier).fetchBanners();
                              } catch (e) {
                                debugPrint('Error saving banner: $e');
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC0430E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(banner != null ? 'Perbarui Banner' : 'Simpan Banner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ADD COUPON BOTTOM SHEET
  // ==========================================
  void _showAddCouponSheet(BuildContext context, {Coupon? coupon}) {
    final amountCtrl = TextEditingController(text: coupon != null ? coupon.discountAmount.toInt().toString() : '');
    final minCtrl = TextEditingController(text: coupon != null ? coupon.minPurchase.toInt().toString() : '');
    bool isActive = coupon?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7F2),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // Beautiful Header with Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      coupon != null ? 'Edit Kupon' : 'Tambah Kupon Baru', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFFC0430E)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFFFDDCC), height: 1),
              
              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nominal Potongan Harga (Rp)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Minimal Belanja Syarat Kupon (Rp)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Langsung Aktifkan Kupon', style: TextStyle(fontSize: 13)),
                          Switch(
                            value: isActive,
                            onChanged: (val) => setSheetState(() => isActive = val),
                            activeColor: const Color(0xFFC0430E),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (amountCtrl.text.isEmpty || minCtrl.text.isEmpty) return;
                            Navigator.pop(context);
                            if (PocketBaseConfig.enablePocketBase) {
                              final pb = PocketBase(PocketBaseConfig.baseUrl);
                              final discount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                              final minPurchase = double.tryParse(minCtrl.text.trim()) ?? 0;
                              if (coupon != null) {
                                await pb.collection('coupons').update(coupon.id, body: {
                                  'code': 'DISKON${discount.toInt()}',
                                  'discountAmount': discount,
                                  'minPurchase': minPurchase,
                                  'isActive': isActive,
                                });
                              } else {
                                await pb.collection('coupons').create(body: {
                                  'code': 'DISKON${discount.toInt()}',
                                  'discountAmount': discount,
                                  'minPurchase': minPurchase,
                                  'isActive': isActive,
                                });
                              }
                              ref.read(couponsProvider.notifier).fetchCoupons();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC0430E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(coupon != null ? 'Perbarui Kupon' : 'Simpan Kupon', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PRODUCT DIRECT DISCOUNTS TAB
  // ==========================================
  Widget _buildProductDiscountsTab() {
    final products = ref.watch(productsProvider);
    final discountedProducts = products.where((p) => p.hasDiscount).toList();

    if (discountedProducts.isEmpty) {
      return _buildEmptyState(
        'Belum Ada Diskon Produk',
        'Terapkan potongan harga langsung pada produk Anda untuk menarik perhatian pembeli.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: discountedProducts.length,
      itemBuilder: (context, index) {
        final p = discountedProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFDDCC)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                p.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 50,
                  height: 50,
                  color: const Color(0xFFFFF0E6),
                  child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 24),
                ),
              ),
            ),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Diskon ${p.discountPercentage}%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rp ${p.originalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Harga Sekarang: Rp ${p.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFC0430E)),
                  onPressed: () => _showAddProductDiscountSheet(context, product: p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  onPressed: () => _confirmRemoveDiscount(context, p),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveDiscount(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Diskon', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus diskon untuk "${product.name}" dan mengembalikan harga normal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF7C7C7C))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Restore price to originalPrice and set originalPrice to 0.0
              final restored = product.copyWith(
                price: product.originalPrice,
                originalPrice: 0.0,
              );
              await ref.read(productsProvider.notifier).updateProduct(restored);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Diskon "${product.name}" berhasil dihapus.'),
                    backgroundColor: const Color(0xFFC0430E),
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddProductDiscountSheet(BuildContext context, {Product? product}) {
    final products = ref.read(productsProvider);
    // Only products that do not have active discounts, PLUS the product we are currently editing (so it is selectable!)
    final availableProducts = products.where((p) => !p.hasDiscount || (product != null && p.id == product.id)).toList();
    
    if (availableProducts.isEmpty && product == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFAF7F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tidak Ada Produk', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Semua produk Anda saat ini sudah memiliki diskon aktif. Hapus diskon produk terlebih dahulu untuk menerapkan diskon baru.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFFC0430E))),
            ),
          ],
        ),
      );
      return;
    }

    Product? selectedProduct = product ?? (availableProducts.isNotEmpty ? availableProducts.first : null);
    final percentCtrl = TextEditingController(text: product != null ? product.discountPercentage.toInt().toString() : '');
    
    final double initialBasePrice = (selectedProduct != null && selectedProduct.originalPrice > 0)
        ? selectedProduct.originalPrice
        : (selectedProduct?.price ?? 0.0);
        
    final double initialPercent = product != null ? product.discountPercentage.toDouble() : 0.0;
    
    double liveCalculatedPrice = selectedProduct != null
        ? (selectedProduct.originalPrice > 0 ? selectedProduct.price : selectedProduct.price)
        : 0.0;
    double liveSavedAmount = (initialBasePrice * initialPercent) / 100;
    if (product != null) {
      liveCalculatedPrice = product.price;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Live calculation helper
          void recalculate() {
            final double basePrice = (selectedProduct != null && selectedProduct!.originalPrice > 0)
                ? selectedProduct!.originalPrice
                : (selectedProduct?.price ?? 0.0);
            final double percent = double.tryParse(percentCtrl.text.trim()) ?? 0.0;
            if (percent > 0 && percent < 100) {
              liveSavedAmount = basePrice * percent / 100;
              liveCalculatedPrice = basePrice - liveSavedAmount;
            } else {
              liveSavedAmount = 0.0;
              liveCalculatedPrice = basePrice;
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Beautiful Header with Close Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product != null ? 'Edit Diskon Produk' : 'Tambah Diskon Baru',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF0E6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 18, color: Color(0xFFC0430E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFFFDDCC), height: 1),
                
                // Scrollable Form
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 16,
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product dropdown selector
                        const Text('Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C7C7C))),
                        const SizedBox(height: 6),
                        product != null
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        selectedProduct!.imageUrl,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          width: 32,
                                          height: 32,
                                          color: const Color(0xFFFFF0E6),
                                          child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedProduct!.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Harga Awal: Rp ${initialBasePrice.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Product>(
                                    value: selectedProduct,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFC0430E)),
                                    items: availableProducts.map((p) {
                                      return DropdownMenuItem<Product>(
                                        value: p,
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                p.imageUrl,
                                                width: 30,
                                                height: 30,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) => Container(
                                                  width: 30,
                                                  height: 30,
                                                  color: const Color(0xFFFFF0E6),
                                                  child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 16),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${p.name} (Rp ${p.price.toStringAsFixed(0)})',
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setSheetState(() {
                                          selectedProduct = val;
                                          recalculate();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                        const SizedBox(height: 16),

                        // Discount Percentage Input
                        TextField(
                          controller: percentCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setSheetState(() {
                              recalculate();
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Persentase Diskon (%)',
                            hintText: 'Contoh: 10, 20, 50',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.percent, color: Color(0xFFC0430E)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Live Preview Area (Very premium details!)
                        if (selectedProduct != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFDDCC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kalkulasi Harga:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C2D12)),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Harga Awal:', style: TextStyle(fontSize: 12, color: Color(0xFF1A1A1A))),
                                    Text('Rp ${initialBasePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Potongan Diskon:', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                                    Text('-Rp ${liveSavedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                  ],
                                ),
                                const Divider(height: 12, color: Color(0xFFFFDDCC)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Harga Baru / Coret:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                                    Text(
                                      'Rp ${liveCalculatedPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFC0430E)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              final percent = double.tryParse(percentCtrl.text.trim()) ?? 0.0;
                              if (percent <= 0 || percent >= 100 || selectedProduct == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Masukkan persentase diskon yang valid (1-99%)'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(context);

                              // Calculate and apply
                              final double originalPrice = (selectedProduct!.originalPrice > 0)
                                  ? selectedProduct!.originalPrice
                                  : selectedProduct!.price;
                              final double newPrice = originalPrice - (originalPrice * percent / 100);

                              final discounted = selectedProduct!.copyWith(
                                price: newPrice,
                                originalPrice: originalPrice,
                              );

                              await ref.read(productsProvider.notifier).updateProduct(discounted);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Diskon ${percent.toInt()}% berhasil disimpan ke "${selectedProduct!.name}"!'),
                                    backgroundColor: const Color(0xFFC0430E),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC0430E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(product != null ? 'Perbarui Diskon' : 'Simpan Diskon', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
