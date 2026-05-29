import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../config/pocketbase_config.dart';
import '../../models/user.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  
  bool _isSavingProfile = false;
  bool _isSavingPassword = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  List<int>? _selectedImageBytes;
  String? _selectedImageFilename;

  // Untuk mengetahui apakah user punya password atau belum
  bool get _hasPassword => ref.watch(authProvider).hasPassword;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFilename = picked.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveProfileInfo() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    final success = await ref.read(authProvider.notifier).updateProfile(
          name: _nameController.text,
          phone: _phoneController.text,
          imageBytes: _selectedImageBytes,
          imageFilename: _selectedImageFilename,
        );
    setState(() => _isSavingProfile = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil Anda berhasil diperbarui!'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(authProvider).errorMessage ?? 'Gagal memperbarui profil.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isSavingPassword = true);
    
    bool success;
    if (_hasPassword) {
      // User sudah punya password, gunakan updatePassword
      success = await ref.read(authProvider.notifier).updatePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );
    } else {
      // User belum punya password (login via Google), gunakan createPassword
      success = await ref.read(authProvider.notifier).createPassword(
            newPassword: _newPasswordController.text,
          );
    }
    
    setState(() => _isSavingPassword = false);

    if (mounted) {
      if (success) {
        // Clear password fields on success
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasPassword 
              ? 'Kata sandi Anda berhasil diperbarui!' 
              : 'Kata sandi Anda berhasil dibuat!'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(authProvider).errorMessage ?? 
          (_hasPassword ? 'Gagal memperbarui kata sandi.' : 'Gagal membuat kata sandi.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildAvatarWidget(UserModel? user) {
    if (_selectedImageBytes != null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFDDCC), width: 3),
          image: DecorationImage(
            image: MemoryImage(Uint8List.fromList(_selectedImageBytes!)),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (user != null && user.avatar.isNotEmpty) {
      final avatarUrl = "${PocketBaseConfig.baseUrl}/api/files/_pb_users_auth_/${user.uid}/${user.avatar}";
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFDDCC), width: 3),
          image: DecorationImage(
            image: NetworkImage(avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFDDCC), width: 3),
        gradient: const LinearGradient(
          colors: [Color(0xFFC0430E), Color(0xFFD4601A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(user?.name ?? ''),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 32,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil Saya',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Interactive Profile Avatar Section
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _buildAvatarWidget(user),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC0430E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ================= MODULE 1: PROFILE INFO FORM =================
              Form(
                key: _profileFormKey,
                child: Column(
                  children: [
                    _buildInputField(
                      label: 'Nama Lengkap',
                      controller: _nameController,
                      icon: Icons.person_outline,
                      hint: 'Masukkan nama lengkap Anda',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama lengkap tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildInputField(
                      label: 'Nomor Telepon',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      hint: 'Masukkan nomor telepon aktif',
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nomor telepon tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildInputField(
                      label: 'Alamat Email (Tidak Dapat Diubah)',
                      controller: TextEditingController(text: user?.email ?? ''),
                      icon: Icons.email_outlined,
                      readOnly: true,
                      hint: 'email@domain.com',
                    ),
                    const SizedBox(height: 24),

                    // Button: Simpan Perubahan Profil
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSavingProfile ? null : _saveProfileInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC0430E),
                          disabledBackgroundColor: const Color(0xFFFFD1B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSavingProfile
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Simpan Perubahan Profil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Divider(color: Color(0xFFFFDDCC), height: 1),
              const SizedBox(height: 24),

              // ================= MODULE 2: PASSWORD CHANGE FORM =================
              Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasPassword ? 'Ubah Kata Sandi Akun' : 'Buat Kata Sandi Akun',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC0430E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasPassword 
                        ? 'Perbarui kata sandi Anda untuk keamanan akun'
                        : 'Anda login menggunakan Google. Buat kata sandi untuk dapat login dengan email.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF7C7C7C),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tampilkan field "Kata Sandi Lama" hanya jika user sudah punya password
                    if (_hasPassword) ...[
                      _buildInputField(
                        label: 'Kata Sandi Lama',
                        controller: _oldPasswordController,
                        icon: Icons.lock_outline,
                        hint: 'Masukkan kata sandi saat ini',
                        obscureText: _obscureOldPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureOldPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
                        ),
                        validator: (val) {
                          // Hanya validasi jika user sudah punya password
                          if (_hasPassword && (val == null || val.isEmpty)) {
                            return 'Kata sandi saat ini diperlukan';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    _buildInputField(
                      label: _hasPassword ? 'Kata Sandi Baru' : 'Kata Sandi',
                      controller: _newPasswordController,
                      icon: Icons.lock_outline,
                      hint: 'Masukkan kata sandi baru (min. 6 karakter)',
                      obscureText: _obscureNewPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Kata sandi tidak boleh kosong';
                        }
                        if (val.length < 6) {
                          return 'Kata sandi minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildInputField(
                      label: _hasPassword ? 'Konfirmasi Kata Sandi Baru' : 'Konfirmasi Kata Sandi',
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      hint: 'Ulangi kata sandi baru Anda',
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Harap ulangi kata sandi';
                        }
                        if (val != _newPasswordController.text) {
                          return 'Konfirmasi kata sandi tidak cocok';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Button: Perbarui/Buat Kata Sandi
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSavingPassword ? null : _saveNewPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC0430E),
                          disabledBackgroundColor: const Color(0xFFFFD1B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSavingPassword
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _hasPassword ? 'Perbarui Kata Sandi' : 'Buat Kata Sandi',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool readOnly = false,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 13.5,
            color: readOnly ? Colors.grey.shade600 : const Color(0xFF1A1A1A),
            fontWeight: readOnly ? FontWeight.w500 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: readOnly ? Colors.grey : const Color(0xFFC0430E), size: 20),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFC0430E), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
