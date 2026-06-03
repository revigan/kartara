import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';

class BuyerBottomNavBar extends ConsumerWidget {
  const BuyerBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final orders = ref.watch(ordersProvider);
    
    // Count uncompleted orders to display as badge
    final uncompletedCount = orders.where((o) => o.status.toLowerCase() != 'selesai').length;

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
                isActive: navState.buyerTab == 0,
                onTap: () => navNotifier.changeBuyerTab(0),
              ),
              _buildBottomNavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment,
                label: 'Pesanan',
                isActive: navState.buyerTab == 1,
                onTap: () => navNotifier.changeBuyerTab(1),
                badgeCount: uncompletedCount,
              ),
              _buildBottomNavItem(
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum,
                label: 'Asisten',
                isActive: navState.buyerTab == 2,
                onTap: () => navNotifier.changeBuyerTab(2),
              ),
              _buildBottomNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Akun',
                isActive: navState.buyerTab == 3,
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
