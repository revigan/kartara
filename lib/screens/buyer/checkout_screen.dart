import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../models/order.dart';
import '../../models/cart_item.dart';
import '../../models/coupon.dart';
import '../../widgets/shipping_cost_card.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isProcessing = false;
  Coupon? _selectedCoupon;
  String _selectedCourier = 'Kartara Instant';
  double _shippingFee = 0.0;
  String _selectedCourierEta = '1-3 hari';
  String _selectedCourierService = 'Reguler';

  final _postalCodeController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _postalCodeFocusNode = FocusNode();

  List<ShippingCourier> _courierOptions = [];
  ShippingCourier? _selectedCourierOption;
  bool _isLoadingShipping = false;
  String? _destinationInfo;
  int? _distanceKm;
  String _shippingSource = 'idle';
  String? _shippingError;

  @override
  void initState() {
    super.initState();
    _addressFocusNode.addListener(_onFocusChange);
    _postalCodeFocusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.currentUser != null) {
        _nameController.text = authState.currentUser!.name;
        _phoneController.text = authState.currentUser!.phone;
        _addressController.text = authState.currentUser!.address;
        _postalCodeController.text = authState.currentUser!.postalCode.isNotEmpty
            ? authState.currentUser!.postalCode
            : '59411';
        _calculateShipping();
      }
    });
  }

  void _onFocusChange() {
    if (!_addressFocusNode.hasFocus && !_postalCodeFocusNode.hasFocus) {
      _calculateShipping();
    }
  }

  Future<void> _calculateShipping() async {
    final address = _addressController.text.trim();
    final postalCode = _postalCodeController.text.trim();

    if (address.isEmpty || postalCode.isEmpty) return;

    setState(() {
      _isLoadingShipping = true;
      _courierOptions = [];
      _selectedCourierOption = null;
      _destinationInfo = null;
      _distanceKm = null;
      _shippingSource = 'loading';
    });

    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: AppConfig.defaultHeaders,
      ));

      final response = await dio.post('/shipping/calculate', data: {
        'destinationAddress': address,
        'postalCode': postalCode,
        'totalWeight': 1000,
      });

      if (response.data != null && response.data['success'] == true) {
        final List rawCouriers = response.data['couriers'] ?? [];
        final parsedCouriers = rawCouriers.map((json) => ShippingCourier.fromJson(json)).toList();
        final String? destination = response.data['destination'];
        final int? distance = response.data['distanceKm'];
        final String src = response.data['source'] ?? 'smart_calculation';

        setState(() {
          _courierOptions = parsedCouriers;
          _destinationInfo = destination;
          _distanceKm = distance;
          _shippingSource = src;
          if (_courierOptions.isNotEmpty) {
            _selectedCourierOption = _courierOptions.first;
            _selectedCourier = _selectedCourierOption!.name;
            _shippingFee = _selectedCourierOption!.fee;
            _selectedCourierEta = _selectedCourierOption!.eta;
            _selectedCourierService = _selectedCourierOption!.desc.contains('Ekspres') ? 'Ekspres' : 'Reguler';
          }
          _isLoadingShipping = false;
          _shippingError = null;
        });
      } else {
        setState(() {
          _isLoadingShipping = false;
          _shippingError = 'Server tidak dapat menghitung ongkir.';
        });
      }
    } catch (e) {
      debugPrint('Error calculating shipping costs: $e');
      setState(() {
        _isLoadingShipping = false;
        _shippingError = 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _postalCodeController.dispose();
    _addressFocusNode.dispose();
    _postalCodeFocusNode.dispose();
    super.dispose();
  }

  String _formatRupiah(double amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  double get _subtotal {
    final cart = ref.read(cartProvider);
    return cart.where((i) => i.isSelected).fold(0, (s, i) => s + i.totalPrice);
  }

  double get _couponDiscount => _selectedCoupon?.discountAmount ?? 0.0;
  double get _totalInvoice => _subtotal + _shippingFee - _couponDiscount;

  Future<void> _processCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);

    final cartNotifier = ref.read(cartProvider.notifier);
    final ordersNotifier = ref.read(ordersProvider.notifier);
    final navNotifier = ref.read(navigationProvider.notifier);

    final selectedItems = ref.read(cartProvider).where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada produk yang dipilih')),
      );
      setState(() => _isProcessing = false);
      return;
    }

    final subtotal = _subtotal;
    final shippingFee = _shippingFee;
    final discount = _couponDiscount;
    final totalInvoice = _totalInvoice;

    final pocketbaseOrderId = await ordersNotifier.createOrderInPocketBase(
      items: selectedItems,
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      shippingAddress: _addressController.text.trim(),
      subtotal: subtotal,
      shippingFee: shippingFee,
      discount: discount,
      totalInvoice: totalInvoice,
    );

    if (pocketbaseOrderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat pesanan. Silakan coba lagi.')),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    // Sync user profile details in PocketBase and locally if they differ or are empty.
    // NOTE: updateProfile/updateAddress mutate authState which causes ordersProvider to
    // be torn down and recreated by Riverpod. We must re-read ordersProvider.notifier
    // AFTER the sync so we never call addOrderToState on a disposed notifier.
    final authState = ref.read(authProvider);
    if (authState.currentUser != null) {
      final curUser = authState.currentUser!;
      final newPhone = _phoneController.text.trim();
      final newAddress = _addressController.text.trim();
      final newPostalCode = _postalCodeController.text.trim();
      final newName = _nameController.text.trim();

      if (curUser.phone != newPhone || curUser.name != newName) {
        try {
          await ref.read(authProvider.notifier).updateProfile(
            name: newName,
            phone: newPhone,
          );
        } catch (e) {
          debugPrint('Error syncing profile name/phone: $e');
        }
      }

      if (curUser.address != newAddress || curUser.postalCode != newPostalCode) {
        try {
          await ref.read(authProvider.notifier).updateAddress(
            newAddress,
            newPostalCode,
          );
        } catch (e) {
          debugPrint('Error syncing profile address/postalCode: $e');
        }
      }
    }

    // Generate tracking number
    final trackingNumber = 'KTR-${pocketbaseOrderId.substring(0, 8).toUpperCase()}';

    // Determine courier vehicle from courier name
    String courierVehicle = 'Honda Supra • K 4812 JT';
    int etaMinutes = 25;

    if (_selectedCourier.contains('JNE')) {
      courierVehicle = 'Yamaha Mio • K 9283 JN';
      etaMinutes = 20;
    } else if (_selectedCourier.contains('Instant')) {
      courierVehicle = 'Honda Vario • K 1234 XY';
      etaMinutes = 15;
    }

    final order = OrderModel(
      id: pocketbaseOrderId,
      items: selectedItems,
      status: 'pending',
      orderDate: DateTime.now(),
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      shippingAddress: _addressController.text.trim(),
      paymentMethod: 'Midtrans',
      subtotal: subtotal,
      shippingFee: shippingFee,
      discount: discount,
      totalInvoice: totalInvoice,
      courierName: _selectedCourier,
      courierVehicle: courierVehicle,
      etaMinutes: etaMinutes,
      courierService: _selectedCourierService,
      courierEta: _selectedCourierEta,
      trackingNumber: trackingNumber,
      postalCode: _postalCodeController.text.trim(),
      destinationCity: _destinationInfo ?? '',
      courierProgress: 0.3,
    );

    // After profile sync, ordersProvider may have already been rebuilt by Riverpod
    // and loadOrders() re-fetched the new order from PocketBase.
    // Calling addOrderToState would duplicate the order in state.
    // Instead, call loadOrders() to ensure state is fresh without duplicates.
    if (!mounted) return;
    await ref.read(ordersProvider.notifier).loadOrders();
    ref.read(cartProvider.notifier).clearSelectedItems();

    if (mounted) {
      setState(() => _isProcessing = false);
      ref.read(navigationProvider.notifier).navigateToBuyer('payment', order: order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final coupons = ref.watch(couponsProvider);
    final selectedItems = cartState.where((i) => i.isSelected).toList();
    final subtotal = selectedItems.fold<double>(0, (s, i) => s + i.totalPrice);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => ref.read(navigationProvider.notifier).navigateToBuyer('cart'),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary
                  _buildSectionTitle('Ringkasan Pesanan'),
                  const SizedBox(height: 12),
                  _buildOrderSummary(selectedItems),
                  const SizedBox(height: 24),

                  // Shipping Information
                  _buildSectionTitle('Informasi Pengiriman'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nama Penerima',
                    icon: Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama penerima harus diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Nomor HP',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nomor HP harus diisi';
                      if (v.trim().length < 10) return 'Nomor HP tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Alamat Lengkap',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                    focusNode: _addressFocusNode,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat harus diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _postalCodeController,
                    label: 'Kode Pos',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                    focusNode: _postalCodeFocusNode,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Kode pos harus diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Catatan Pesanan (Opsional)',
                    icon: Icons.note_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Pilihan Pengiriman'),
                  const SizedBox(height: 12),
                  ShippingCostCard(
                      couriers: _courierOptions,
                      selectedCourier: _selectedCourierOption,
                      destinationInfo: _destinationInfo,
                      distanceKm: _distanceKm,
                      isLoading: _isLoadingShipping,
                      errorMessage: _shippingError,
                      source: _shippingSource,
                      onRetry: _calculateShipping,
                      onCourierSelected: (courier) {
                        setState(() {
                          _selectedCourierOption = courier;
                          _selectedCourier = courier.name;
                          _shippingFee = courier.fee;
                          _selectedCourierEta = courier.eta;
                          _selectedCourierService = courier.desc.contains('Ekspres') ? 'Ekspres' : 'Reguler';
                        });
                      },
                    ),
                  const SizedBox(height: 24),

                  // Kupon Section
                  _buildSectionTitle('Kupon & Promo'),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih kupon yang tersedia untuk mendapatkan diskon',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  _buildCouponSection(coupons, subtotal),
                  const SizedBox(height: 24),

                  // Price Summary
                  _buildSectionTitle('Rincian Pembayaran'),
                  const SizedBox(height: 12),
                  _buildPriceSummary(subtotal),
                ],
              ),
            ),
          ),
          _buildStickyCheckoutButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
    );
  }

  Widget _buildOrderSummary(List<CartItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Color(0xFFC0430E), size: 20),
              const SizedBox(width: 8),
              Text(
                '${items.length} Produk',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.product.imageUrl,
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50, height: 50,
                      color: const Color(0xFFF5F1ED),
                      child: const Icon(Icons.image, color: Color(0xFFC0430E)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity}x Rp ${_formatRupiah(item.product.price)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E52)),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rp ${_formatRupiah(item.totalPrice)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCouponSection(List<Coupon> coupons, double subtotal) {
    final activeCoupons = coupons.where((c) => c.isActive).toList();

    if (activeCoupons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined, color: Colors.grey[400], size: 24),
            const SizedBox(width: 12),
            Text('Tidak ada kupon tersedia', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: activeCoupons.map((coupon) {
        final isUnlocked = subtotal >= coupon.minPurchase;
        final isSelected = _selectedCoupon?.id == coupon.id;

        return GestureDetector(
          onTap: isUnlocked
              ? () {
                  setState(() {
                    _selectedCoupon = isSelected ? null : coupon;
                  });
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC0430E)
                    : isUnlocked
                        ? const Color(0xFFE0D5C7)
                        : const Color(0xFFEEEEEE),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFC0430E).withOpacity(0.1)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Left color strip & icon
                    Container(
                      width: 72,
                      color: isUnlocked
                          ? (isSelected ? const Color(0xFFC0430E) : const Color(0xFFFFF0E6))
                          : const Color(0xFFF5F5F5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isUnlocked ? Icons.local_offer : Icons.lock_outline,
                            color: isUnlocked
                                ? (isSelected ? Colors.white : const Color(0xFFC0430E))
                                : Colors.grey[400],
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'KUPON',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked
                                  ? (isSelected ? Colors.white70 : const Color(0xFFC0430E))
                                  : Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dashed divider
                    _buildDashedDivider(isUnlocked, isSelected),

                    // Right: coupon details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Coupon name + selected badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    coupon.displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isUnlocked ? const Color(0xFF2C2C2C) : Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC0430E),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Dipakai',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Discount amount
                            Text(
                              'Hemat Rp ${_formatRupiah(coupon.discountAmount)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isUnlocked ? const Color(0xFFC0430E) : Colors.grey[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Description / min purchase
                            if (coupon.description.isNotEmpty) ...[
                              Text(
                                coupon.description,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Min purchase info
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: isUnlocked ? Colors.grey[500] : Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  coupon.minPurchase > 0
                                      ? 'Min. belanja Rp ${_formatRupiah(coupon.minPurchase)}'
                                      : 'Tanpa minimum pembelian',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isUnlocked ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),

                            // Locked message
                            if (!isUnlocked) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_outline, size: 11, color: Color(0xFFAAAAAA)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tambah Rp ${_formatRupiah(coupon.minPurchase - subtotal)} lagi',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Right action
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: isUnlocked
                          ? (isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFFC0430E), size: 24)
                              : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCCCCCC), size: 24))
                          : const Icon(Icons.lock, color: Color(0xFFCCCCCC), size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashedDivider(bool isUnlocked, bool isSelected) {
    final color = isSelected
        ? const Color(0xFFC0430E).withOpacity(0.4)
        : isUnlocked
            ? const Color(0xFFE0D5C7)
            : const Color(0xFFEEEEEE);
    return SizedBox(
      width: 16,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    FocusNode? focusNode,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      focusNode: focusNode,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFC0430E)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C7))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C7))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC0430E), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  Widget _buildPriceSummary(double subtotal) {
    final discount = _couponDiscount;
    final total = subtotal + _shippingFee - discount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', subtotal),
          const SizedBox(height: 8),
          _buildPriceRow('Ongkir', _shippingFee),
          if (_selectedCoupon != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer, size: 14, color: Color(0xFFC0430E)),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCoupon!.displayName,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E52)),
                    ),
                  ],
                ),
                Text(
                  '- Rp ${_formatRupiah(discount)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE0D5C7)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
              Text(
                'Rp ${_formatRupiah(total)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B5E52))),
        Text(
          'Rp ${_formatRupiah(amount)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C)),
        ),
      ],
    );
  }



  Widget _buildStickyCheckoutButton() {
    final total = _totalInvoice;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0430E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Bayar Rp ${_formatRupiah(total)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double startY = 0;
    final x = size.width / 2;
    while (startY < size.height) {
      canvas.drawLine(Offset(x, startY), Offset(x, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
