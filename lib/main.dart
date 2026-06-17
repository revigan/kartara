import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

// Providers
import 'providers/app_state.dart';
import 'providers/auth_provider.dart';

// Widgets & Bezel Frame
import 'widgets/device_frame.dart';
import 'widgets/buyer_bottom_nav_bar.dart';

// Auth Screens
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

// Buyer Screens
import 'screens/buyer/home_screen.dart';
import 'screens/buyer/product_detail_screen.dart';
import 'screens/buyer/cart_screen.dart';
import 'screens/buyer/checkout_screen.dart';
import 'screens/buyer/order_success_screen.dart';
import 'screens/buyer/tracking_screen.dart';
import 'screens/buyer/order_history_screen.dart';
import 'screens/buyer/assistant_screen.dart';
import 'screens/buyer/profile_screen.dart';
import 'screens/buyer/all_products_screen.dart';
import 'screens/buyer/payment_screen.dart';

// Admin Screens
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/product_list_screen.dart';
import 'screens/admin/product_form_screen.dart';
import 'screens/admin/transaction_list_screen.dart';
import 'screens/admin/profile_screen.dart';
import 'screens/admin/promo_management_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Always disable GoogleFonts HTTP fetching — use locally bundled fonts
  // to prevent CanvasKit crash on Web when network is unavailable
  GoogleFonts.config.allowRuntimeFetching = false;

  // Catch any unhandled Flutter framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kartara - UMKM Kerupuk Jepara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0430E),
          primary: const Color(0xFFC0430E),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F2),
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Outfit',
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAF7F2),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      home: const AppEntryNavigator(),
    );
  }
}

class AppEntryNavigator extends ConsumerStatefulWidget {
  const AppEntryNavigator({super.key});

  @override
  ConsumerState<AppEntryNavigator> createState() => _AppEntryNavigatorState();
}

class _AppEntryNavigatorState extends ConsumerState<AppEntryNavigator> {
  bool _splashCompleted = false;
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashCompleted) {
      return SplashScreen(
        onComplete: () {
          setState(() {
            _splashCompleted = true;
          });
        },
      );
    }

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous != null && previous.isAuthenticated && !next.isAuthenticated) {
        setState(() {
          _showRegister = false;
        });
        ref.read(navigationProvider.notifier).reset();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      // Show auth screens inside smartphone bezel but hide side simulator controls
      return DeviceFrameWrapper(
        showControls: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey(_showRegister ? 'register' : 'login'),
            child: _showRegister
                ? RegisterScreen(
                    onNavigateToLogin: () => setState(() => _showRegister = false),
                  )
                : LoginScreen(
                    onNavigateToRegister: () => setState(() => _showRegister = true),
                  ),
          ),
        ),
      );
    }

    // Authenticated state: show standard application routing inside bezel frame
    return const MainNavigator();
  }
}

class MainNavigator extends ConsumerStatefulWidget {
  const MainNavigator({super.key});

  @override
  ConsumerState<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends ConsumerState<MainNavigator> {
  String? _lastUserRole;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated && authState.currentUser != null) {
        final userRole = authState.currentUser!.role;
        _lastUserRole = userRole;
        ref.read(navigationProvider.notifier).switchRole(userRole);
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Handle deep link when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle deep link when app is opened from terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    // Handle kartara://payment/success
    if (uri.scheme == 'kartara' && uri.host == 'payment') {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'success') {
        // Navigate to order history after successful payment
        final navNotifier = ref.read(navigationProvider.notifier);
        navNotifier.navigateToBuyer('history');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran berhasil! Silakan periksa status pesanan Anda.'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final authState = ref.watch(authProvider);

    // Sync context role automatically on first successful login
    if (authState.isAuthenticated && authState.currentUser != null) {
      final userRole = authState.currentUser!.role;
      if (_lastUserRole != userRole) {
        _lastUserRole = userRole;
        // Schedule microtask to avoid building phase state updates conflict
        Future.microtask(() {
          navNotifier.switchRole(userRole);
        });
      }
    }

    // Dynamic routing inside the mobile bezel frame
    Widget activeScreen = const BuyerHomeScreen();

    if (navState.role == 'buyer') {
      switch (navState.buyerScreen) {
        case 'home':
          activeScreen = const BuyerHomeScreen();
          break;
        case 'detail':
          activeScreen = const ProductDetailScreen();
          break;
        case 'cart':
          activeScreen = const CartScreen();
          break;
        case 'checkout':
          activeScreen = const CheckoutScreen();
          break;
        case 'payment':
          activeScreen = const PaymentScreen();
          break;
        case 'success':
          activeScreen = const OrderSuccessScreen();
          break;
        case 'tracking':
          activeScreen = const TrackingScreen();
          break;
        case 'history':
          activeScreen = const OrderHistoryScreen();
          break;
        case 'assistant':
          activeScreen = const AssistantScreen();
          break;
        case 'profile':
          activeScreen = const BuyerProfileScreen();
          break;
        case 'all_products':
          activeScreen = const AllProductsScreen();
          break;
        default:
          activeScreen = const BuyerHomeScreen();
      }
    } else {
      // Admin screen routing
      switch (navState.adminScreen) {
        case 'dashboard':
          activeScreen = const AdminDashboardScreen();
          break;
        case 'products':
          activeScreen = const AdminProductListScreen();
          break;
        case 'product_form':
          activeScreen = const AdminProductFormScreen();
          break;
        case 'transactions':
          activeScreen = const AdminTransactionListScreen();
          break;
        case 'profile':
          activeScreen = const AdminProfileScreen();
          break;
        case 'promo_management':
          activeScreen = const AdminPromoManagementScreen();
          break;
        default:
          activeScreen = const AdminDashboardScreen();
      }
    }

    // Wrap the screen inside the smartphone frame wrapper with role switchers enabled!
    final bool showBottomNav = navState.role == 'buyer' && 
        ['home', 'history', 'assistant', 'profile'].contains(navState.buyerScreen);

    Widget mainWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey('${navState.role}_${navState.role == 'buyer' ? navState.buyerScreen : navState.adminScreen}'),
        child: activeScreen,
      ),
    );

    if (showBottomNav) {
      mainWidget = Scaffold(
        body: mainWidget,
        bottomNavigationBar: const BuyerBottomNavBar(),
      );
    }

    return DeviceFrameWrapper(
      showControls: true,
      child: mainWidget,
    );
  }
}
