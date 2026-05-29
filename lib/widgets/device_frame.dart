import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';

class DeviceFrameWrapper extends ConsumerWidget {
  final Widget child;
  final bool showControls;

  const DeviceFrameWrapper({
    super.key,
    required this.child,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    // Responsive check: if screen width is narrow, show raw mobile app full-screen.
    // Otherwise, render the gorgeous desktop simulation environment with info sidebar and device frame!
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Scaffold(
            body: child,
          );
        }

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5EFE8), // Warm parchment
                  Color(0xFFEDE4D8), // Earthy clay cream
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, innerConstraints) {
                // Calculate if we have enough space for side panel
                final hasSpaceForPanel = innerConstraints.maxWidth >= 800;
                final deviceScale = innerConstraints.maxWidth < 900 ? 0.8 : 1.0;
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: innerConstraints.maxWidth,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Info & Control Panel on Left
                        if (showControls && hasSpaceForPanel) ...[
                          _buildInfoPanel(context, navState.role, navNotifier),
                          const SizedBox(width: 50),
                        ],
                        
                        // Smartphone Bezel Simulator
                        Center(
                          child: Transform.scale(
                            scale: deviceScale,
                            child: Container(
                              width: 390,
                              height: 820,
                              margin: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(48),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFC0430E).withOpacity(0.12),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF1A1A1A),
                                  width: 10,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(38),
                                child: Stack(
                                  children: [
                                    // App Contents
                                    Positioned.fill(
                                      child: Container(
                                        color: const Color(0xFFFAF7F2), // Cream background
                                        padding: const EdgeInsets.only(top: 40, bottom: 20), // Compensate for notch & home bar
                                        child: child,
                                      ),
                                    ),
                                    
                                    // Top Status Bar Area
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: 40,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        color: Colors.transparent,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              '15:55',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            // Notch / Dynamic Island representation
                                            Container(
                                              width: 110,
                                              height: 25,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius: BorderRadius.circular(15),
                                              ),
                                            ),
                                            // Status bar icons (Wifi, Network, Battery)
                                            const Row(
                                              children: [
                                                Icon(Icons.signal_cellular_4_bar, size: 13, color: Colors.black),
                                                SizedBox(width: 4),
                                                Icon(Icons.wifi, size: 13, color: Colors.black),
                                                SizedBox(width: 4),
                                                Icon(Icons.battery_5_bar, size: 13, color: Colors.black),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Bottom Home Indicator Bar
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      height: 20,
                                      child: Center(
                                        child: Container(
                                          width: 120,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(2.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Info sidebar showing Kartara branding and state changes
  Widget _buildInfoPanel(BuildContext context, String role, NavigationNotifier navNotifier) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC0430E).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.waves_rounded,
                  color: Color(0xFFC0430E),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KARTARA',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFC0430E),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Anyaman & Kerajinan Jepara',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B6B6B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            ],
          ),
          const Divider(height: 40, thickness: 1.2),
          const Text(
            'Mode Uji Coba UI/UX',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih peran di bawah ini untuk mensimulasikan alur Pembeli dan Admin. Data keranjang, produk, dan status pesanan akan saling tersinkronisasi secara real-time!',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7C7C7C),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          // Role Selection Buttons
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEADDD5)),
            ),
            child: Column(
              children: [
                _buildRoleButton(
                  title: 'Pembeli (Buyer)',
                  subtitle: 'Belanja, AI Chat, Lacak Kiriman',
                  isActive: role == 'buyer',
                  activeColor: const Color(0xFFC0430E),
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => navNotifier.switchRole('buyer'),
                ),
                const SizedBox(height: 6),
                _buildRoleButton(
                  title: 'Pengelola (Admin)',
                  subtitle: 'Dashboard, CRUD Stok, Transaksi',
                  isActive: role == 'admin',
                  activeColor: const Color(0xFF1A1A1A),
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: () => navNotifier.switchRole('admin'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          
          // Highlight Features list
          const Text(
            'Fitur Unggulan:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C7C7C),
            ),
          ),
          const SizedBox(height: 10),
          _buildFeatureDot('13 Halaman Terpadu Khas Jepara'),
          _buildFeatureDot('Warna Oranye Hangat & Creamy'),
          _buildFeatureDot('AI Assistant Asisten Kartara'),
          _buildFeatureDot('Sinkronisasi CRUD Produk Live'),
          _buildFeatureDot('Live Tracking Perjalanan Kurir'),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required String title,
    required String subtitle,
    required bool isActive,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF7C7C7C),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? Colors.white.withOpacity(0.8) : const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDot(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFFC0430E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
