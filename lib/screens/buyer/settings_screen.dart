import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationEnabled = true;
  bool _darkModeEnabled = false;
  bool _biometricEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // Section 1: Akun & Keamanan
          _buildSectionHeader('Akun & Keamanan'),
          _buildMenuTile(
            icon: Icons.lock_outline_rounded,
            title: 'Ubah Kata Sandi',
            subtitle: 'Perbarui kata sandi secara berkala agar tetap aman',
            onTap: () => _showStubNotification('Ubah Kata Sandi'),
          ),
          _buildMenuTile(
            icon: Icons.security_rounded,
            title: 'PIN Transaksi KartaraPay',
            subtitle: 'Ubah atau atur PIN pengamanan transaksi Anda',
            onTap: () => _showStubNotification('PIN Transaksi'),
          ),
          _buildSwitchTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometrik Sidik Jari',
            subtitle: 'Gunakan FaceID / Fingerprint saat login cepat',
            value: _biometricEnabled,
            onChanged: (val) {
              setState(() => _biometricEnabled = val);
            },
          ),
          const SizedBox(height: 24),

          // Section 2: Preferensi Aplikasi
          _buildSectionHeader('Preferensi Aplikasi'),
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi Push',
            subtitle: 'Dapatkan pemberitahuan promo, update pesanan, dll.',
            value: _notificationEnabled,
            onChanged: (val) {
              setState(() => _notificationEnabled = val);
            },
          ),
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: 'Mode Gelap (Dark Mode)',
            subtitle: 'Ubah tema aplikasi menjadi gelap agar mata rileks',
            value: _darkModeEnabled,
            onChanged: (val) {
              setState(() => _darkModeEnabled = val);
            },
          ),
          _buildMenuTile(
            icon: Icons.language_rounded,
            title: 'Bahasa Utama',
            subtitle: 'Bahasa Indonesia',
            onTap: () => _showStubNotification('Pengaturan Bahasa'),
          ),
          const SizedBox(height: 24),

          // Section 3: Info & Hukum
          _buildSectionHeader('Informasi Tambahan'),
          _buildMenuTile(
            icon: Icons.info_outline_rounded,
            title: 'Tentang Aplikasi Kartara',
            subtitle: 'Versi Aplikasi 1.0.4 Premium',
            onTap: () => _showAboutDialog(context),
          ),
          _buildMenuTile(
            icon: Icons.gavel_outlined,
            title: 'Syarat & Ketentuan Penggunaan',
            subtitle: 'Kebijakan Privasi & Ketentuan Pengguna',
            onTap: () => _showStubNotification('Kebijakan Privasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC0430E),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF1F1F1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: const Color(0xFF1A1A1A)),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C))),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF7C7C7C)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF1F1F1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: const Color(0xFF1A1A1A)),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C))),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFC0430E),
        ),
      ),
    );
  }

  void _showStubNotification(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menu "$title" akan segera dapat diakses pada rilis pembaruan berikutnya!'),
        backgroundColor: const Color(0xFFC0430E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tentang Kartara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: const Text(
          'Kartara adalah aplikasi belanja produk anyaman & kerajinan tangan khas lokal terlengkap di Indonesia.\n\nVersi: 1.0.4 (Stable)\n© 2026 Developer Kartara Inc.',
          style: TextStyle(fontSize: 11.5, height: 1.5, color: Color(0xFF1A1A1A)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0430E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Selesai', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
