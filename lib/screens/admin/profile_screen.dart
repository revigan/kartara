import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navNotifier = ref.read(navigationProvider.notifier);
    final navState = ref.watch(navigationProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (centered bold "Akun Admin")
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  'Akun Admin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),

            // 2. Profile Avatar Info block matching Image 5
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Circular vector avatar of administrator
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFDDCC), width: 2),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Detail columns
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Admin Kartara',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Administrator',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'admin@kartara.id',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C7C7C),
                          ),
                        ),
                        const SizedBox(height: 2),
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

            // 3. Admin list tiles with dividers (All Active!)
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildAdminOption(
                    context: context,
                    icon: Icons.person_outline,
                    label: 'Profil Admin',
                    onTap: () {
                      _showBottomSheet(context, const EditProfileSheet());
                    },
                  ),
                  _buildAdminOption(
                    context: context,
                    icon: Icons.lock_outline,
                    label: 'Ubah Password',
                    onTap: () {
                      _showBottomSheet(context, const ChangePasswordSheet());
                    },
                  ),
                  _buildAdminOption(
                    context: context,
                    icon: Icons.storefront_outlined,
                    label: 'Pengaturan Toko',
                    onTap: () {
                      _showBottomSheet(context, const ShopSettingsSheet());
                    },
                  ),
                  _buildAdminOption(
                    context: context,
                    icon: Icons.group_outlined,
                    label: 'Manajemen Pengguna',
                    onTap: () {
                      _showBottomSheet(context, const UserManagementSheet());
                    },
                  ),
                  _buildAdminOption(
                    context: context,
                    icon: Icons.history_outlined,
                    label: 'Log Aktivitas',
                    onTap: () {
                      _showBottomSheet(context, const ActivityLogSheet());
                    },
                  ),
                  _buildAdminOption(
                    context: context,
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

            // 4. Admin bottom navigation bar with active Akun icon selected
            _buildAdminBottomNavBar(navState.adminScreen, navNotifier, context, ref),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context, Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => child,
    );
  }

  Widget _buildAdminOption({
    required BuildContext context,
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
        title: const Text('Keluar dari Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun administrator?', style: TextStyle(fontSize: 12, height: 1.4)),
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

// ============================================================================
// PREMIUM BOTTOM SHEETS FOR FULL INTERACTION
// ============================================================================

// 1. EDIT PROFILE BOTTOM SHEET
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).currentUser;
    _nameController = TextEditingController(text: user?.name ?? 'Admin Kartara');
    _emailController = TextEditingController(text: user?.email ?? 'admin@kartara.id');
    _phoneController = TextEditingController(text: user?.phone ?? '081215413573');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Edit Profil Admin',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Perbarui informasi kontak administrator Kartara di bawah ini.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                  ),
                  const SizedBox(height: 24),

                  // Avatar picker preview
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFDDCC), width: 3),
                            image: const DecorationImage(
                              image: NetworkImage(
                                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFFC0430E),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Mengubah foto profil admin...'),
                                    backgroundColor: Color(0xFFC0430E),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.person, color: Color(0xFFC0430E)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.email, color: Color(0xFFC0430E)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Email tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Nomor Telepon',
                      labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFFC0430E)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Nomor telepon tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          final success = await ref.read(authProvider.notifier).updateProfile(
                            name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                          );
                          if (mounted) {
                            setState(() => _isLoading = false);
                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profil admin berhasil disimpan!'),
                                  backgroundColor: Color(0xFFC0430E),
                                ),
                              );
                            } else {
                              final errorMsg = ref.read(authProvider).errorMessage ?? 'Gagal menyimpan perubahan';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: Colors.red[800],
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0430E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2. CHANGE PASSWORD BOTTOM SHEET
class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ubah Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gunakan kombinasi karakter yang kuat agar keamanan akun admin tetap terjaga.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                  ),
                  const SizedBox(height: 24),

                  // Old Password
                  TextFormField(
                    controller: _oldPasswordController,
                    obscureText: _obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Password Lama',
                      labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.lock_open, color: Color(0xFFC0430E)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOld ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF7C7C7C)),
                        onPressed: () => setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Password lama wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFC0430E)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF7C7C7C)),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? 'Password baru minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 16),

                  // Confirm New Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password Baru',
                      labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.verified_user_outlined, color: Color(0xFFC0430E)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF7C7C7C)),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Wajib diisi untuk konfirmasi' : null,
                  ),
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          if (_newPasswordController.text != _confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Konfirmasi password tidak cocok!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() => _isLoading = true);
                          final success = await ref.read(authProvider.notifier).updatePassword(
                            oldPassword: _oldPasswordController.text.trim(),
                            newPassword: _newPasswordController.text.trim(),
                          );
                          if (mounted) {
                            setState(() => _isLoading = false);
                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password berhasil diperbarui!'),
                                  backgroundColor: Color(0xFFC0430E),
                                ),
                              );
                            } else {
                              final errorMsg = ref.read(authProvider).errorMessage ?? 'Gagal memperbarui password';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: Colors.red[800],
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0430E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan Password Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 3. SHOP SETTINGS BOTTOM SHEET
class ShopSettingsSheet extends StatefulWidget {
  const ShopSettingsSheet({super.key});

  @override
  State<ShopSettingsSheet> createState() => _ShopSettingsSheetState();
}

class _ShopSettingsSheetState extends State<ShopSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isShopOpen = true;
  bool _isLoading = false;
  late TextEditingController _nameController;
  late TextEditingController _addressController;

  final Map<String, bool> _shippingCouriers = {
    'JNE Express': true,
    'J&T Express': true,
    'Sicepat': true,
    'POS Indonesia': false,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Kartara Jepara');
    _addressController = TextEditingController(text: 'Kec. Tahunan, Kabupaten Jepara, Indonesia');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isShopOpen = prefs.getBool('saved_shop_is_open') ?? true;
      _nameController.text = prefs.getString('saved_shop_name') ?? 'Kartara Jepara';
      _addressController.text = prefs.getString('saved_shop_address') ?? 'Kec. Tahunan, Kabupaten Jepara, Indonesia';
      _shippingCouriers['JNE Express'] = prefs.getBool('saved_shop_jne') ?? true;
      _shippingCouriers['J&T Express'] = prefs.getBool('saved_shop_jnt') ?? true;
      _shippingCouriers['Sicepat'] = prefs.getBool('saved_shop_sicepat') ?? true;
      _shippingCouriers['POS Indonesia'] = prefs.getBool('saved_shop_pos') ?? false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Toko',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kelola operasional, informasi lokasi, dan pilihan kurir logistik.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shop Status Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFDDCC)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isShopOpen ? 'Status Toko: Buka 🏪' : 'Status Toko: Tutup 🚪',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Pelanggan bisa melakukan order sekarang.',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF7C7C7C)),
                                  )
                                ],
                              ),
                              Switch(
                                value: _isShopOpen,
                                activeColor: const Color(0xFFC0430E),
                                onChanged: (val) => setState(() => _isShopOpen = val),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Shop Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Toko',
                            labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                            ),
                          ),
                          validator: (v) => v!.isEmpty ? 'Nama toko wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),

                        // Shop Address
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Alamat Toko / Pengiriman',
                            labelStyle: const TextStyle(color: Color(0xFF7C7C7C), fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                            ),
                          ),
                          validator: (v) => v!.isEmpty ? 'Alamat wajib diisi' : null,
                        ),
                        const SizedBox(height: 20),

                        // Courier Logistics Selection
                        const Text(
                          'Pilihan Kurir Pengiriman',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 8),
                        ..._shippingCouriers.keys.map((key) {
                          return CheckboxListTile(
                            value: _shippingCouriers[key],
                            title: Text(key, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A))),
                            activeColor: const Color(0xFFC0430E),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setState(() {
                                _shippingCouriers[key] = val ?? false;
                              });
                            },
                          );
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Save Changes Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('saved_shop_is_open', _isShopOpen);
                        await prefs.setString('saved_shop_name', _nameController.text.trim());
                        await prefs.setString('saved_shop_address', _addressController.text.trim());
                        await prefs.setBool('saved_shop_jne', _shippingCouriers['JNE Express'] ?? true);
                        await prefs.setBool('saved_shop_jnt', _shippingCouriers['J&T Express'] ?? true);
                        await prefs.setBool('saved_shop_sicepat', _shippingCouriers['Sicepat'] ?? true);
                        await prefs.setBool('saved_shop_pos', _shippingCouriers['POS Indonesia'] ?? false);
                        if (mounted) {
                          setState(() => _isLoading = false);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pengaturan toko berhasil diperbarui!'),
                              backgroundColor: Color(0xFFC0430E),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC0430E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Pengaturan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. USER MANAGEMENT BOTTOM SHEET
class UserManagementSheet extends ConsumerStatefulWidget {
  const UserManagementSheet({super.key});

  @override
  ConsumerState<UserManagementSheet> createState() => _UserManagementSheetState();
}

class _UserManagementSheetState extends ConsumerState<UserManagementSheet> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Refresh user list on launch
    Future.microtask(() {
      ref.read(registeredCustomersProvider.notifier).fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(registeredCustomersProvider);

    // Filter by search query
    final filteredCustomers = customers.where((c) {
      final name = c.name.toLowerCase();
      final email = c.email.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manajemen Pengguna',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Melihat data ${customers.length} pembeli terdaftar di Kartara.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFFC0430E)),
                      onPressed: () {
                        ref.read(registeredCustomersProvider.notifier).fetchCustomers();
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama atau email...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFC0430E), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F1F1))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Customers List
              Expanded(
                child: filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_outlined, color: Colors.grey.withOpacity(0.3), size: 48),
                            const SizedBox(height: 12),
                            const Text('Pengguna Tidak Ditemukan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final c = filteredCustomers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFFFDDCC)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFFFDDCC),
                                    child: Text(
                                      c.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Color(0xFFC0430E), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              c.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('PEMBELI', style: TextStyle(color: Color(0xFF2563EB), fontSize: 8, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(c.email, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C))),
                                        if (c.phone.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text('Telp: ${c.phone}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C))),
                                        ],
                                        if (c.address.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text('Alamat: ${c.address}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// 5. ACTIVITY LOG BOTTOM SHEET
class ActivityLogSheet extends StatelessWidget {
  const ActivityLogSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> logs = [
      {
        'time': 'Hari ini, 09:42',
        'title': 'Mengubah diskon produk "Kursi Kayu Jati Minimalis"',
        'admin': 'Admin Kartara',
        'icon': 'edit',
      },
      {
        'time': 'Hari ini, 08:15',
        'title': 'Memperbarui kupon belanja KARTARACERIA',
        'admin': 'Admin Kartara',
        'icon': 'card_giftcard',
      },
      {
        'time': 'Kemarin, 14:20',
        'title': 'Menambahkan produk baru "Meja Makan Solid Wood"',
        'admin': 'Admin Kartara',
        'icon': 'add',
      },
      {
        'time': 'Kemarin, 11:05',
        'title': 'Memproses pesanan #KT-8902 senilai Rp 1.500.000',
        'admin': 'System',
        'icon': 'check_circle',
      },
      {
        'time': '2 hari lalu',
        'title': 'Mengubah banner promo "Gratis Ongkir Akhir Pekan"',
        'admin': 'Admin Kartara',
        'icon': 'image',
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Aktivitas Admin',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Jejak audit seluruh perubahan produk, promo, kupon, dan transaksi toko.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7C7C7C)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    IconData iconData = Icons.info_outline;
                    Color iconBg = const Color(0xFFEFF6FF);
                    Color iconColor = const Color(0xFF2563EB);

                    if (log['icon'] == 'edit') {
                      iconData = Icons.edit_outlined;
                      iconBg = const Color(0xFFFEF3C7);
                      iconColor = const Color(0xFFD97706);
                    } else if (log['icon'] == 'add') {
                      iconData = Icons.add_circle_outline;
                      iconBg = const Color(0xFFECFDF5);
                      iconColor = const Color(0xFF059669);
                    } else if (log['icon'] == 'card_giftcard') {
                      iconData = Icons.card_giftcard_outlined;
                      iconBg = const Color(0xFFFDF2F8);
                      iconColor = const Color(0xFFDB2777);
                    } else if (log['icon'] == 'check_circle') {
                      iconData = Icons.check_circle_outline;
                      iconBg = const Color(0xFFECFDF5);
                      iconColor = const Color(0xFF059669);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline Dot with Icon
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 18),
                          ),
                          const SizedBox(width: 14),

                          // Timeline text details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['title']!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1A1A1A), height: 1.3),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      log['time']!,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('•', style: TextStyle(color: Color(0xFF9E9E9E))),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Oleh: ${log['admin']!}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF7C7C7C), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
