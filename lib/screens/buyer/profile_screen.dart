import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'address_management_screen.dart';
import '../../config/pocketbase_config.dart';

import 'personal_wallet_screen.dart';
import 'settings_screen.dart';
import 'help_faq_screen.dart';

class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navNotifier = ref.read(navigationProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (drawer menu icon on the left, centered bold title "Akun Saya")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Center(
                child: Text(
                  'Akun Saya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),

            // 2. Avatar & Credentials Card (matches Image 1 exactly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Dynamic Profile Avatar (NetworkImage if uploaded, otherwise Initials)
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFDDCC), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC0430E).withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      gradient: user == null || user.avatar.isEmpty
                          ? const LinearGradient(
                              colors: [Color(0xFFC0430E), Color(0xFFD4601A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      image: user != null && user.avatar.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                "${PocketBaseConfig.baseUrl}/api/files/_pb_users_auth_/${user.uid}/${user.avatar}",
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user == null || user.avatar.isEmpty
                        ? Center(
                            child: Text(
                              _getInitials(user?.name ?? 'Budi Santoso'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 1.2,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  
                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Budi Santoso',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'budi.santoso@email.com',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C7C7C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.phone ?? '+62 812-3456-7890',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C7C7C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Navigation options lists with thin grey dividers
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildProfileOption(
                    icon: Icons.person_outline,
                    label: 'Profil Saya',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.location_on_outlined,
                    label: 'Alamat Saya',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddressManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Pesanan',
                    onTap: () => navNotifier.changeBuyerTab(1),
                  ),
                  _buildProfileOption(
                    icon: Icons.logout_outlined,
                    label: 'Keluar',
                    isDanger: true,
                    onTap: () {
                      _showConfirmLogoutDialog(context, authNotifier);
                    },
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? const Color(0xFF6B2A0C) : const Color(0xFF1A1A1A);
    
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDanger ? const Color(0xFF6B2A0C) : const Color(0xFF7C7C7C),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Color(0xFFF1F1F1), height: 1),
      ],
    );
  }

  void _showConfirmLogoutDialog(BuildContext context, AuthNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluar dari Kartara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?', style: TextStyle(fontSize: 12, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0430E)),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
