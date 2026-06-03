import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class AddressManagementScreen extends ConsumerStatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  ConsumerState<AddressManagementScreen> createState() => _AddressManagementScreenState();
}

class _AddressManagementScreenState extends ConsumerState<AddressManagementScreen> {
  bool _isSaving = false;

  void _showEditAddressBottomSheet(BuildContext context) {
    final user = ref.read(authProvider).currentUser;
    final addressController = TextEditingController(text: user?.address ?? '');
    final postalCodeController = TextEditingController(text: user?.postalCode ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Ubah Alamat Pengiriman',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Masukkan alamat lengkap pengiriman untuk pengiriman pesanan yang akurat.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF7C7C7C)),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: addressController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A1A1A)),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Alamat tidak boleh kosong';
                          }
                          if (val.trim().length < 10) {
                            return 'Harap masukkan alamat lengkap (min. 10 karakter)';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Tulis nama jalan, RT/RW, nomor rumah, kelurahan, kecamatan, dan kota...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: postalCodeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A1A1A)),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kode pos tidak boleh kosong';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Kode Pos',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => _isSaving = true);
                                  
                                  final success = await ref.read(authProvider.notifier).updateAddress(
                                        addressController.text,
                                        postalCodeController.text,
                                      );
                                      
                                  setModalState(() => _isSaving = false);
                                  
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Alamat utama berhasil diperbarui!'),
                                          backgroundColor: Color(0xFF4CAF50),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      final error = ref.read(authProvider).errorMessage ?? 'Gagal memperbarui alamat.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(error),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC0430E),
                            disabledBackgroundColor: const Color(0xFFFFD1B3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Perbarui Alamat',
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
              ),
            );
          },
        );
      },
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
          'Alamat Saya',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alamat Pengiriman Utama',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),

              // 1. Premium Address Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: user != null && user.address.isNotEmpty
                        ? const Color(0xFFFFD1B3)
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC0430E).withOpacity(0.02),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          user?.name ?? 'Budi Santoso',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (user != null && user.address.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0E6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Utama',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFC0430E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.phone ?? '+62 812-3456-7890',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C7C7C),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Color(0xFFF1F1F1)),
                    ),
                    Text(
                      user != null && user.address.isNotEmpty
                          ? user.address
                          : 'Alamat utama pengiriman belum diatur. Silakan ketuk tombol di bawah untuk menambah alamat pengiriman Anda.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: user != null && user.address.isNotEmpty
                            ? const Color(0xFF1A1A1A)
                            : Colors.grey.shade500,
                        fontWeight: user != null && user.address.isNotEmpty
                            ? FontWeight.normal
                            : FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (user != null && user.address.isNotEmpty && user.postalCode.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Kode Pos: ${user.postalCode}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),

              // 2. Edit Action CTA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _showEditAddressBottomSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0430E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        user != null && user.address.isNotEmpty
                            ? Icons.edit_location_alt_outlined
                            : Icons.add_location_alt_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user != null && user.address.isNotEmpty
                            ? 'Ubah Alamat Utama'
                            : 'Atur Alamat Utama',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
}
