import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../config/pocketbase_config.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/promo_banner.dart';
import '../models/coupon.dart';
import '../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
// ==========================================
// 1. PRODUCTS PROVIDER (CRUD STATE)
// ==========================================
class ProductListNotifier extends StateNotifier<List<Product>> {
  final Ref ref;
  ProductListNotifier(this.ref) : super([]) {
    fetchProducts();
  }

  final pb = PocketBaseConfig.pb;

  Future<void> fetchProducts() async {
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      final records = await pb.collection('products').getFullList(
        sort: '-created',
      );
      
      final List<Product> loaded = records.map((record) {
        final imagesList = record.getListValue<String>('images');
        String primaryImageUrl = 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=400&q=80'; // fallback
        
        if (imagesList.isNotEmpty) {
          final filename = imagesList.first;
          primaryImageUrl = '${PocketBaseConfig.baseUrl}/api/files/products/${record.id}/$filename';
        } else {
          final fallbackUrl = record.getStringValue('imageUrl');
          if (fallbackUrl.isNotEmpty) {
            primaryImageUrl = fallbackUrl;
          }
        }

        // Map category code back to full readable text
        String displayCategory = 'Udang';
        final catVal = record.getStringValue('category');
        if (catVal == 'Ikan') {
          displayCategory = 'Ikan';
        } else if (catVal == 'Cumi') {
          displayCategory = 'Cumi';
        } else if (catVal == 'Pedas') {
          displayCategory = 'Pedas';
        }

        return Product(
          id: record.id,
          name: record.getStringValue('name'),
          sellerName: record.getStringValue('sellerName'),
          price: record.getDoubleValue('price'),
          imageUrl: primaryImageUrl,
          images: imagesList.map((f) => '${PocketBaseConfig.baseUrl}/api/files/products/${record.id}/$f').toList(),
          category: displayCategory,
          rating: record.getDoubleValue('rating', 4.8),
          reviewsCount: record.getIntValue('reviewsCount', 1),
          weight: record.getIntValue('weight', 250),
          description: record.getStringValue('description'),
          characteristics: (() {
            final raw = record.data['characteristics'];
            if (raw is List) {
              return raw.map((e) => e.toString()).toList();
            }
            if (raw is String && raw.isNotEmpty) {
              try {
                final parsed = jsonDecode(raw);
                if (parsed is List) {
                  return parsed.map((e) => e.toString()).toList();
                }
              } catch (_) {}
            }
            return <String>[];
          })(),
          stock: record.getIntValue('stock', 0),
          isActive: record.getBoolValue('isActive', true),
          originalPrice: record.getDoubleValue('originalPrice', 0.0),
        );
      }).toList();

      state = loaded;
    } catch (e) {
      debugPrint('Error fetching products from PocketBase: $e');
      if (e is ClientException) {
        debugPrint('PocketBase 403/Forbidden details: ${e.response}');
      }
    }
  }

  Future<void> addProduct(
    Product product, {
    Uint8List? webImageBytes,
    String? webImageName,
    String? mobileImagePath,
  }) async {
    // Blazing-fast optimistic update
    state = [...state, product];

    if (!PocketBaseConfig.enablePocketBase) return;

    try {
      // ONLY send fields that are guaranteed to exist in the database schema
      final body = {
        'name': product.name,
        'sellerName': product.sellerName,
        'price': product.price,
        'originalPrice': product.originalPrice,
        'category': product.category,
        'weight': product.weight,
        'description': product.description,
        'stock': product.stock,
        'isActive': product.isActive,
        'characteristics': product.characteristics,
      };

      final List<http.MultipartFile> files = [];
      if (kIsWeb && webImageBytes != null && webImageName != null) {
        files.add(http.MultipartFile.fromBytes(
          'images',
          webImageBytes,
          filename: webImageName,
        ));
      } else if (!kIsWeb && mobileImagePath != null && mobileImagePath.isNotEmpty) {
        if (!mobileImagePath.startsWith('http://') && 
            !mobileImagePath.startsWith('https://') && 
            !mobileImagePath.startsWith('blob:')) {
          files.add(await http.MultipartFile.fromPath(
            'images',
            mobileImagePath,
          ));
        }
      }

      await pb.collection('products').create(
        body: body,
        files: files,
      );

      final adminName = ref.read(authProvider).currentUser?.name ?? 'Admin Kartara';
      await PocketBaseConfig.logActivity(
        title: 'Menambahkan produk baru "${product.name}"',
        icon: 'add',
        admin: adminName,
      );

      // Re-fetch to sync real PocketBase record IDs and file paths
      await fetchProducts();
    } catch (e) {
      debugPrint('Error adding product to PocketBase: $e');
      if (e is ClientException) {
        debugPrint('PocketBase 400/Validation details: ${e.response}');
      }
    }
  }

  Future<void> updateProduct(
    Product updatedProduct, {
    Uint8List? webImageBytes,
    String? webImageName,
    String? mobileImagePath,
  }) async {
    // Blazing-fast optimistic update
    final oldProduct = state.firstWhere((p) => p.id == updatedProduct.id, orElse: () => updatedProduct);
    state = [
      for (final p in state)
        if (p.id == updatedProduct.id) updatedProduct else p
    ];

    if (!PocketBaseConfig.enablePocketBase) return;

    try {
      // ONLY send fields that are guaranteed to exist in the database schema
      final body = {
        'name': updatedProduct.name,
        'sellerName': updatedProduct.sellerName,
        'price': updatedProduct.price,
        'originalPrice': updatedProduct.originalPrice,
        'category': updatedProduct.category,
        'weight': updatedProduct.weight,
        'description': updatedProduct.description,
        'stock': updatedProduct.stock,
        'isActive': updatedProduct.isActive,
        'characteristics': updatedProduct.characteristics,
      };

      final List<http.MultipartFile> files = [];
      if (kIsWeb && webImageBytes != null && webImageName != null) {
        files.add(http.MultipartFile.fromBytes(
          'images',
          webImageBytes,
          filename: webImageName,
        ));
      } else if (!kIsWeb && mobileImagePath != null && mobileImagePath.isNotEmpty) {
        if (!mobileImagePath.startsWith('http://') && 
            !mobileImagePath.startsWith('https://') && 
            !mobileImagePath.startsWith('blob:')) {
          files.add(await http.MultipartFile.fromPath(
            'images',
            mobileImagePath,
          ));
        }
      }

      await pb.collection('products').update(
        updatedProduct.id,
        body: body,
        files: files,
      );

      final adminName = ref.read(authProvider).currentUser?.name ?? 'Admin Kartara';
      String logTitle = 'Mengubah detail produk "${updatedProduct.name}"';
      if (oldProduct.price != updatedProduct.price || oldProduct.originalPrice != updatedProduct.originalPrice) {
        if (updatedProduct.originalPrice == 0.0) {
          logTitle = 'Menghapus diskon produk "${updatedProduct.name}"';
        } else {
          logTitle = 'Mengubah diskon produk "${updatedProduct.name}"';
        }
      }
      await PocketBaseConfig.logActivity(
        title: logTitle,
        icon: 'edit',
        admin: adminName,
      );

      await fetchProducts();
    } catch (e) {
      debugPrint('Error updating product in PocketBase: $e');
      if (e is ClientException) {
        debugPrint('PocketBase 400/Validation details: ${e.response}');
      }
    }
  }

  Future<void> deleteProduct(String id) async {
    final product = state.firstWhere(
      (p) => p.id == id,
      orElse: () => Product(
        id: id,
        name: 'Produk Tidak Dikenal',
        sellerName: '',
        price: 0.0,
        originalPrice: 0.0,
        imageUrl: '',
        category: '',
        rating: 0.0,
        reviewsCount: 0,
        weight: 0,
        description: '',
        characteristics: const [],
        stock: 0,
      ),
    );
    // Blazing-fast optimistic update
    state = state.where((p) => p.id != id).toList();

    if (!PocketBaseConfig.enablePocketBase) return;

    try {
      await pb.collection('products').delete(id);
      final adminName = ref.read(authProvider).currentUser?.name ?? 'Admin Kartara';
      await PocketBaseConfig.logActivity(
        title: 'Menghapus produk "${product.name}"',
        icon: 'edit',
        admin: adminName,
      );
      // Automatically refresh in the background without full page reload/splash screen!
      await fetchProducts();
    } catch (e) {
      debugPrint('Error deleting product from PocketBase: $e');
    }
  }

  Future<void> submitProductReview(String productId, double userRating) async {
    if (!PocketBaseConfig.enablePocketBase) return;

    try {
      final record = await pb.collection('products').getOne(productId);
      final double currentRating = record.getDoubleValue('rating', 4.8);
      final int currentReviewsCount = record.getIntValue('reviewsCount', 1);

      final int newReviewsCount = currentReviewsCount + 1;
      final double newRating = ((currentRating * currentReviewsCount) + userRating) / newReviewsCount;

      // Update di PocketBase
      await pb.collection('products').update(
        productId,
        body: {
          'rating': double.parse(newRating.toStringAsFixed(1)),
          'reviewsCount': newReviewsCount,
        },
      );

      // Refresh status produk lokal
      await fetchProducts();
    } catch (e) {
      debugPrint('Error submitting product review: $e');
    }
  }
}


final productsProvider = StateNotifierProvider<ProductListNotifier, List<Product>>((ref) {
  return ProductListNotifier(ref);
});

// ==========================================
// 2. CART PROVIDER
// ==========================================
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    loadCart();
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('shopping_cart');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        state = decoded.map((item) => CartItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cart from SharedPreferences: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(state.map((item) => item.toJson()).toList());
      await prefs.setString('shopping_cart', jsonStr);
    } catch (e) {
      debugPrint('Error saving cart to SharedPreferences: $e');
    }
  }

  void addToCart(Product product, {int qty = 1}) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final currentItem = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        currentItem.copyWith(quantity: currentItem.quantity + qty),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, CartItem(product: product, quantity: qty)];
    }
    _saveToPrefs();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.product.id == productId) item.copyWith(quantity: quantity) else item
    ];
    _saveToPrefs();
  }

  void removeFromCart(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _saveToPrefs();
  }

  void clearCart() {
    state = [];
    _saveToPrefs();
  }

  void clearSelectedItems() {
    state = state.where((item) => !item.isSelected).toList();
    _saveToPrefs();
  }

  void toggleSelection(String productId) {
    state = [
      for (final item in state)
        if (item.product.id == productId) item.copyWith(isSelected: !item.isSelected) else item
    ];
    _saveToPrefs();
  }

  Coupon? _activeCoupon;
  Coupon? get activeCoupon => _activeCoupon;

  Future<String?> applyCoupon(String code) async {
    if (code.trim().isEmpty) {
      _activeCoupon = null;
      state = [...state];
      return null;
    }

    if (!PocketBaseConfig.enablePocketBase) {
      if (code.trim().toUpperCase() == 'KARTARACERIA') {
        _activeCoupon = Coupon(id: 'mock', code: 'KARTARACERIA', discountAmount: 10000, minPurchase: 50000);
        state = [...state];
        return null;
      }
      return "Kupon tidak valid.";
    }

    try {
      final pb = PocketBase(PocketBaseConfig.baseUrl);
      final records = await pb.collection('coupons').getFullList(
        filter: 'code = "${code.trim().toUpperCase()}" && isActive = true',
      );
      if (records.isEmpty) {
        return "Kupon tidak valid atau sudah kedaluwarsa.";
      }
      final coupon = Coupon.fromJson({
        'id': records.first.id,
        ...records.first.data,
      });

      if (subtotal < coupon.minPurchase) {
        return "Minimal pembelian Rp ${coupon.minPurchase.toStringAsFixed(0)} untuk kupon ini.";
      }

      _activeCoupon = coupon;
      state = [...state];
      return null;
    } catch (e) {
      debugPrint('Error applying coupon: $e');
      return "Gagal memverifikasi kupon.";
    }
  }

  void selectCoupon(Coupon coupon) {
    if (subtotal < coupon.minPurchase) return;
    _activeCoupon = coupon;
    state = [...state];
  }

  void removeCoupon() {
    _activeCoupon = null;
    state = [...state];
  }

  bool get hasSelectedItems => state.any((item) => item.isSelected);
  double get subtotal => state.where((item) => item.isSelected).fold(0, (sum, item) => sum + item.totalPrice);
  double get shippingFee => 0.0;
  double get discount => _activeCoupon == null ? 0.0 : _activeCoupon!.discountAmount;
  double get totalInvoice => subtotal + shippingFee - discount;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

// ==========================================
// 3. ORDERS PROVIDER
// ==========================================
class OrderListNotifier extends StateNotifier<List<OrderModel>> {
  final Ref ref;
  OrderListNotifier(this.ref) : super([]) {
    loadOrders();
    _subscribeToPocketBase();
  }

  void _subscribeToPocketBase() {
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      pb.collection('orders').subscribe('*', (e) {
        if (mounted) {
          loadOrders();
        }
      });
    } catch (err) {
      debugPrint('Error subscribing to orders real-time SSE: $err');
    }
  }

  final pb = PocketBaseConfig.pb;

  Future<void> loadOrders() async {
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      final authState = ref.read(authProvider);
      final currentUser = authState.currentUser;
      if (currentUser == null) {
        state = [];
        return;
      }

      String? filter;
      if (currentUser.role == 'buyer') {
        // Filter by buyerId (UID) for precise per-user isolation.
        // Falls back to buyerPhone for legacy orders that don't have buyerId set.
        final uid = currentUser.uid;
        if (uid.isEmpty) {
          state = [];
          return;
        }
        filter = 'buyerId = "$uid" || (buyerId = "" && buyerPhone = "${currentUser.phone}")';
      }

      final records = await pb.collection('orders').getFullList(
        sort: '-created',
        filter: filter,
      );
      if (!mounted) return;
      state = records.map((record) {
        return OrderModel.fromJson({
          'id': record.id,
          'items': record.data['items'],
          'status': record.data['status'].toString().toLowerCase(),
          'orderDate': record.created,
          'recipientName': record.data['buyerName'] ?? '',
          'recipientPhone': record.data['buyerPhone'] ?? '',
          'shippingAddress': record.data['shippingAddress'] ?? '',
          'paymentMethod': record.data['paymentMethod'] ?? 'E-Wallet',
          'subtotal': (record.data['totalAmount'] as num?)?.toDouble() ?? 0.0,
          'shippingFee': (record.data['shippingFee'] as num?)?.toDouble() ?? 0.0,
          'discount': (record.data['discount'] as num?)?.toDouble() ?? 0.0,
          'totalInvoice': (record.data['totalAmount'] as num?)?.toDouble() ?? 0.0,
          // New shipping fields
          'courierName': record.data['courierName'] ?? 'Kartara Instant',
          'courierService': record.data['courierService'] ?? 'Reguler',
          'courierEta': record.data['courierEta'] ?? '',
          'trackingNumber': record.data['trackingNumber'] ?? '',
          'postalCode': record.data['postalCode'] ?? '',
          'destinationCity': record.data['destinationCity'] ?? '',
          'courierProgress': (record.data['courierProgress'] as num?)?.toDouble() ?? 0.3,
        });
      }).toList();
    } catch (e) {
      debugPrint('Error loading orders from database: $e');
      if (mounted) {
        state = []; // Set state to empty list as a safety fallback
      }
    }
  }

  @override
  void dispose() {
    if (PocketBaseConfig.enablePocketBase) {
      try {
        pb.collection('orders').unsubscribe('*');
      } catch (err) {
        debugPrint('Error unsubscribing from orders real-time SSE: $err');
      }
    }
    super.dispose();
  }

  Future<void> cancelOrder(String orderId) async {
    state = state.where((o) => o.id != orderId).toList();
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      await pb.collection('orders').delete(orderId);
      final adminName = ref.read(authProvider).currentUser?.name ?? 'Pembeli';
      await PocketBaseConfig.logActivity(
        title: 'Membatalkan pesanan #$orderId',
        icon: 'cancel',
        admin: adminName,
      );
    } catch (e) {
      debugPrint('Error deleting/cancelling order in PocketBase: $e');
    }
  }

  Future<void> addOrder(OrderModel order) async {
    state = [order, ...state];

    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      await pb.collection('orders').create(
        body: {
          'id': order.id,
          'items': order.items.map((item) => item.toJson()).toList(),
          'status': 'Pending',
          'buyerName': order.recipientName,
          'buyerPhone': order.recipientPhone,
          'shippingAddress': order.shippingAddress,
          'paymentMethod': order.paymentMethod.contains('E-Wallet') || order.paymentMethod.contains('QRIS')
              ? 'E-Wallet'
              : 'Transfer Bank',
          'totalAmount': order.totalInvoice.toInt(),
          'discount': order.discount.toInt(),
          // New shipping fields
          'shippingFee': order.shippingFee.toInt(),
          'courierName': order.courierName,
          'courierService': order.courierService,
          'courierEta': order.courierEta,
          'trackingNumber': order.trackingNumber,
          'postalCode': order.postalCode,
          'destinationCity': order.destinationCity,
          'courierProgress': order.courierProgress,
        },
      );

      // Decrease product stock in PocketBase for each order item
      for (final item in order.items) {
        try {
          final prodRecord = await pb.collection('products').getOne(item.product.id);
          final int currentStock = prodRecord.getIntValue('stock', 0);
          final int newStock = (currentStock - item.quantity).clamp(0, 999999);
          await pb.collection('products').update(
            item.product.id,
            body: {
              'stock': newStock,
            },
          );
        } catch (stockErr) {
          debugPrint('Error updating product stock in PB: $stockErr');
        }
      }

      // Synchronize local products list state
      ref.read(productsProvider.notifier).fetchProducts();

    } catch (e) {
      debugPrint('Error saving order to database: $e');
    }
  }

  // Create order in PocketBase and return the auto-generated ID
  Future<String?> createOrderInPocketBase({
    required List<CartItem> items,
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
    required double subtotal,
    required double shippingFee,
    required double discount,
    required double totalInvoice,
  }) async {
    if (!PocketBaseConfig.enablePocketBase) return null;
    
    try {
      // Read the current user UID to link order ownership securely
      final authState = ref.read(authProvider);
      final buyerId = authState.currentUser?.uid ?? '';

      final record = await pb.collection('orders').create(
        body: {
          'items': items.map((item) => item.toJson()).toList(),
          'status': 'Pending',
          'buyerName': recipientName,
          'buyerPhone': recipientPhone,
          'buyerId': buyerId,
          'shippingAddress': shippingAddress,
          'paymentMethod': 'E-Wallet',
          'totalAmount': totalInvoice.toInt(),
          'discount': discount.toInt(),
          'shippingFee': shippingFee.toInt(),
          'payment_status': 'pending_payment',
        },
      );

      // Decrease product stock in PocketBase for each order item
      for (final item in items) {
        try {
          final prodRecord = await pb.collection('products').getOne(item.product.id);
          final int currentStock = prodRecord.getIntValue('stock', 0);
          final int newStock = (currentStock - item.quantity).clamp(0, 999999);
          await pb.collection('products').update(
            item.product.id,
            body: {
              'stock': newStock,
            },
          );
        } catch (stockErr) {
          debugPrint('Error updating product stock in PB: $stockErr');
        }
      }

      // Synchronize local products list state
      ref.read(productsProvider.notifier).fetchProducts();

      return record.id; // Return PocketBase auto-generated ID
    } catch (e) {
      debugPrint('Error creating order in PocketBase: $e');
      return null;
    }
  }

  // Add order to local state only (without saving to PocketBase)
  void addOrderToState(OrderModel order) {
    state = [order, ...state];
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, {String? paymentMethod, String? paymentStatus}) async {
    state = [
      for (final order in state)
        if (order.id == orderId)
          order.copyWith(
            status: newStatus,
            paymentMethod: paymentMethod ?? order.paymentMethod,
          )
        else
          order
    ];

    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      String pbStatus = 'Pending';
      if (newStatus == 'diproses') {
        pbStatus = 'Diproses';
      } else if (newStatus == 'dikirim') {
        pbStatus = 'Dikirim';
      } else if (newStatus == 'selesai') {
        pbStatus = 'Selesai';
      }

      final Map<String, dynamic> body = {
        'status': pbStatus,
      };

      if (paymentStatus != null) {
        body['payment_status'] = paymentStatus;
        if (paymentStatus == 'paid') {
          body['paid_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }

      if (paymentMethod != null) {
        body['paymentMethod'] = paymentMethod.toLowerCase().contains('wallet') || 
                                paymentMethod.toLowerCase().contains('qris') ||
                                paymentMethod.toLowerCase().contains('gopay') ||
                                paymentMethod.toLowerCase().contains('ovo') ||
                                paymentMethod.toLowerCase().contains('dana') ||
                                paymentMethod.toLowerCase().contains('shopee')
            ? 'E-Wallet'
            : 'Transfer Bank'; // Map to validated PocketBase select options
      }

      await pb.collection('orders').update(
        orderId,
        body: body,
      );

      final adminName = ref.read(authProvider).currentUser?.name ?? 'System';
      final order = state.firstWhere(
        (o) => o.id == orderId,
        orElse: () => OrderModel(
          id: orderId,
          items: const [],
          status: newStatus,
          orderDate: DateTime.now(),
          recipientName: 'Pembeli Kartara',
          recipientPhone: '',
          shippingAddress: '',
          paymentMethod: paymentMethod ?? 'COD',
          subtotal: 0.0,
          shippingFee: 0.0,
          discount: 0.0,
          totalInvoice: 0.0,
        ),
      );
      
      final cleanOrderNumber = order.id.replaceAll('ORD-', '').replaceAll('#', '');
      final displayNum = cleanOrderNumber.length > 6 ? cleanOrderNumber.substring(cleanOrderNumber.length - 6) : cleanOrderNumber;
      final formattedTotal = 'Rp ${order.totalInvoice.toStringAsFixed(0)}';

      String activityTitle = 'Memproses pesanan #KT-$displayNum senilai $formattedTotal';
      if (newStatus == 'selesai') {
        activityTitle = 'Menyelesaikan pesanan #KT-$displayNum senilai $formattedTotal';
      } else if (newStatus == 'dikirim') {
        activityTitle = 'Mengirimkan pesanan #KT-$displayNum senilai $formattedTotal';
      }

      await PocketBaseConfig.logActivity(
        title: activityTitle,
        icon: 'check_circle',
        admin: adminName,
      );
    } catch (e) {
      debugPrint('Error updating order status in database: $e');
    }
  }
}

final ordersProvider = StateNotifierProvider<OrderListNotifier, List<OrderModel>>((ref) {
  // Watch authProvider so this provider is rebuilt when auth state changes (login, logout, account switch)
  ref.watch(authProvider);
  return OrderListNotifier(ref);
});

// ==========================================
// ==========================================
// 5. NAVIGATION PROVIDER (ROUTER STATE)
// ==========================================
class AppNavigationState {
  final String role; // 'buyer' or 'admin'
  final String buyerScreen; // 'home', 'detail', 'cart', 'checkout', 'success', 'tracking', 'history', 'assistant'
  final String adminScreen; // 'dashboard', 'products', 'product_form', 'transactions'
  final int buyerTab; // 0: Beranda, 1: Pesanan, 2: Asisten, 3: Akun
  final Product? selectedProduct;
  final OrderModel? selectedOrder;
  final List<String> screenHistory; // Simple stack for back navigation

  AppNavigationState({
    required this.role,
    required this.buyerScreen,
    required this.adminScreen,
    required this.buyerTab,
    this.selectedProduct,
    this.selectedOrder,
    required this.screenHistory,
  });

  AppNavigationState copyWith({
    String? role,
    String? buyerScreen,
    String? adminScreen,
    int? buyerTab,
    Product? selectedProduct,
    OrderModel? selectedOrder,
    List<String>? screenHistory,
  }) {
    return AppNavigationState(
      role: role ?? this.role,
      buyerScreen: buyerScreen ?? this.buyerScreen,
      adminScreen: adminScreen ?? this.adminScreen,
      buyerTab: buyerTab ?? this.buyerTab,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      selectedOrder: selectedOrder ?? this.selectedOrder,
      screenHistory: screenHistory ?? this.screenHistory,
    );
  }
}

class AppNavigationNotifier extends StateNotifier<AppNavigationState> {
  AppNavigationNotifier() : super(AppNavigationState(
    role: 'buyer',
    buyerScreen: 'home',
    adminScreen: 'dashboard',
    buyerTab: 0,
    screenHistory: ['home'],
  ));

  void switchRole(String newRole) {
    state = AppNavigationState(
      role: newRole,
      buyerScreen: 'home',
      adminScreen: 'dashboard',
      buyerTab: 0,
      selectedProduct: null,
      selectedOrder: null,
      screenHistory: newRole == 'buyer' ? ['home'] : ['dashboard'],
    );
  }

  void reset() {
    state = AppNavigationState(
      role: 'buyer',
      buyerScreen: 'home',
      adminScreen: 'dashboard',
      buyerTab: 0,
      selectedProduct: null,
      selectedOrder: null,
      screenHistory: ['home'],
    );
  }

  void navigateToBuyer(String screen, {Product? product, OrderModel? order}) {
    final newHistory = List<String>.from(state.screenHistory)..add(screen);
    
    // Manage buyer tabs correlation
    int tab = state.buyerTab;
    if (screen == 'home') tab = 0;
    if (screen == 'history') tab = 1;
    if (screen == 'assistant') tab = 2;
    if (screen == 'profile') tab = 3;

    state = AppNavigationState(
      role: state.role,
      buyerScreen: screen,
      adminScreen: state.adminScreen,
      buyerTab: tab,
      selectedProduct: product,
      selectedOrder: order,
      screenHistory: newHistory,
    );
  }

  void changeBuyerTab(int index) {
    String screen = 'home';
    if (index == 0) screen = 'home';
    if (index == 1) screen = 'history';
    if (index == 2) screen = 'assistant';
    if (index == 3) screen = 'profile';

    state = AppNavigationState(
      role: state.role,
      buyerScreen: screen,
      adminScreen: state.adminScreen,
      buyerTab: index,
      selectedProduct: null,
      selectedOrder: null,
      screenHistory: [screen],
    );
  }

  void navigateToAdmin(String screen, {Product? product, OrderModel? order}) {
    final newHistory = List<String>.from(state.screenHistory)..add(screen);
    state = AppNavigationState(
      role: state.role,
      buyerScreen: state.buyerScreen,
      adminScreen: screen,
      buyerTab: state.buyerTab,
      selectedProduct: product,
      selectedOrder: order,
      screenHistory: newHistory,
    );
  }

  void goBack() {
    final currentState = state;
    if (currentState.screenHistory.length <= 1) return;
    
    final newHistory = List<String>.from(currentState.screenHistory)..removeLast();
    final prevScreen = newHistory.last;

    if (currentState.role == 'buyer') {
      int tab = currentState.buyerTab;
      if (prevScreen == 'home') tab = 0;
      if (prevScreen == 'history') tab = 1;
      if (prevScreen == 'assistant') tab = 2;

      state = AppNavigationState(
        role: currentState.role,
        buyerScreen: prevScreen,
        adminScreen: currentState.adminScreen,
        buyerTab: tab,
        selectedProduct: null, // Reset selected product when popping
        selectedOrder: null,
        screenHistory: newHistory,
      );
    } else {
      state = AppNavigationState(
        role: currentState.role,
        buyerScreen: currentState.buyerScreen,
        adminScreen: prevScreen,
        buyerTab: currentState.buyerTab,
        selectedProduct: null, // Reset selected product when popping
        selectedOrder: null,
        screenHistory: newHistory,
      );
    }
  }
}

final navigationProvider = StateNotifierProvider<AppNavigationNotifier, AppNavigationState>((ref) {
  return AppNavigationNotifier();
});

typedef NavigationState = AppNavigationState;
typedef NavigationNotifier = AppNavigationNotifier;

// ==========================================
// FAVORITES PROVIDER
// ==========================================
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorites') ?? [];
    state = favoriteIds.toSet();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', state.toList());
  }

  void toggleFavorite(String productId) {
    if (state.contains(productId)) {
      state = {...state}..remove(productId);
    } else {
      state = {...state, productId};
    }
    _saveFavorites();
  }

  bool isFavorite(String productId) {
    return state.contains(productId);
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

// ==========================================
// 5. BANNERS PROVIDER
// ==========================================
class BannerListNotifier extends StateNotifier<List<PromoBanner>> {
  BannerListNotifier() : super([]) {
    fetchBanners();
  }

  Future<void> fetchBanners() async {
    if (!PocketBaseConfig.enablePocketBase) {
      final mockBanners = [
        PromoBanner(
          id: 'mock1',
          title: 'Diskon 20%',
          subtitle: 'Spesial Krupuk Tengiri Asli!',
          image: 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=800&q=80',
          isActive: true,
        ),
      ];
      state = mockBanners;
      return;
    }

    try {
      final pb = PocketBase(PocketBaseConfig.baseUrl);
      final records = await pb.collection('banners').getFullList();
      state = records.map((r) => PromoBanner.fromJson({
        'id': r.id,
        ...r.data,
      })).toList();
    } catch (e) {
      debugPrint('Error fetching banners from PocketBase: $e');
      state = [];
    }
  }
}

final bannersProvider = StateNotifierProvider<BannerListNotifier, List<PromoBanner>>((ref) {
  return BannerListNotifier();
});

class CouponListNotifier extends StateNotifier<List<Coupon>> {
  CouponListNotifier() : super([]) {
    fetchCoupons();
  }

  Future<void> fetchCoupons() async {
    if (!PocketBaseConfig.enablePocketBase) {
      final mockCoupons = [
        Coupon(id: 'mock1', code: 'KARTARACERIA', discountAmount: 10000, minPurchase: 50000, isActive: true),
        Coupon(id: 'mock2', code: 'DISKON20K', discountAmount: 20000, minPurchase: 100000, isActive: true),
      ];
      state = mockCoupons;
      return;
    }

    try {
      final pb = PocketBase(PocketBaseConfig.baseUrl);
      final records = await pb.collection('coupons').getFullList();
      state = records.map((r) => Coupon.fromJson({
        'id': r.id,
        ...r.data,
      })).toList();
    } catch (e) {
      debugPrint('Error fetching coupons from PocketBase: $e');
      state = [];
    }
  }
}

final couponsProvider = StateNotifierProvider<CouponListNotifier, List<Coupon>>((ref) {
  return CouponListNotifier();
});

// ==========================================
// 6. REGISTERED CUSTOMERS PROVIDER
// ==========================================
class RegisteredCustomersNotifier extends StateNotifier<List<UserModel>> {
  RegisteredCustomersNotifier() : super([]) {
    fetchCustomers();
  }

  final pb = PocketBaseConfig.pb;

  Future<void> fetchCustomers() async {
    if (!PocketBaseConfig.enablePocketBase) return;
    try {
      final records = await pb.collection('users').getFullList(
        filter: 'role = "pembeli"',
      );
      state = records.map((record) => UserModel(
        uid: record.id,
        name: record.getStringValue('name'),
        email: record.getStringValue('email'),
        phone: record.getStringValue('phone'),
        role: 'buyer',
        address: record.getStringValue('address'),
        avatar: record.getStringValue('avatar'),
      )).toList();
    } catch (e) {
      debugPrint('Error fetching registered customers: $e');
    }
  }
}

final registeredCustomersProvider = StateNotifierProvider<RegisteredCustomersNotifier, List<UserModel>>((ref) {
  return RegisteredCustomersNotifier();
});

