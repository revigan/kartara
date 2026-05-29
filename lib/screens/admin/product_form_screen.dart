import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/app_state.dart';
import '../../models/product.dart';

class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key});

  @override
  ConsumerState<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Input controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _sellerCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _imgCtrl;
  late TextEditingController _characteristicsCtrl;
  
  // Picked image upload properties
  Uint8List? _webImageBytes;
  String? _webImageName;
  String? _mobileImagePath;
  
  String _selectedCategory = 'Krupuk Udang';
  bool _isActive = true;
  String _imageUrl = 'https://images.unsplash.com/photo-1626132647523-66f5bf380027?auto=format&fit=crop&w=400&q=80';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedProd = ref.read(navigationProvider).selectedProduct;

    if (selectedProd != null) {
      _nameCtrl = TextEditingController(text: selectedProd.name);
      _sellerCtrl = TextEditingController(text: selectedProd.sellerName);
      _priceCtrl = TextEditingController(text: selectedProd.price.toStringAsFixed(0));
      _weightCtrl = TextEditingController(text: selectedProd.weight.toString());
      _stockCtrl = TextEditingController(text: selectedProd.stock.toString());
      _descCtrl = TextEditingController(text: selectedProd.description);
      _imageUrl = selectedProd.imageUrl;
      _imgCtrl = TextEditingController(text: selectedProd.imageUrl);
      _imgCtrl.addListener(() {
        if (mounted) setState(() {});
      });
      _isActive = selectedProd.isActive;
      _characteristicsCtrl = TextEditingController(text: selectedProd.characteristics.join(', '));
      
      // Map domain category code back to user dropdown
      if (selectedProd.category == 'Ikan') {
        _selectedCategory = 'Krupuk Ikan';
      } else {
        _selectedCategory = 'Krupuk Udang';
      }
    } else {
      // Clean and empty defaults for a premium blank slate when adding a new product
      _nameCtrl = TextEditingController(text: '');
      _sellerCtrl = TextEditingController(text: '');
      _priceCtrl = TextEditingController(text: '');
      _weightCtrl = TextEditingController(text: '');
      _stockCtrl = TextEditingController(text: '');
      _descCtrl = TextEditingController(text: '');
      _imageUrl = '';
      _imgCtrl = TextEditingController(text: '');
      _imgCtrl.addListener(() {
        if (mounted) setState(() {});
      });
      _characteristicsCtrl = TextEditingController(text: '');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sellerCtrl.dispose();
    _priceCtrl.dispose();
    _weightCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _imgCtrl.dispose();
    _characteristicsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final productsNotifier = ref.read(productsProvider.notifier);

    final bool isEditMode = navState.selectedProduct != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => navNotifier.goBack(),
        ),
        title: Text(
          isEditMode ? 'Edit Produk' : 'Tambah Produk',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Foto Produk Section
              const Text(
                'Foto Produk',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C7C7C)),
              ),
              const SizedBox(height: 10),
              _buildFotoProdukSection(),
              const SizedBox(height: 16),

              // 2. Nama Produk Input
              _buildLabel('Nama Produk'),
              _buildTextInput(_nameCtrl, 'Masukkan nama produk...', (val) {
                if (val == null || val.trim().isEmpty) return 'Nama produk wajib diisi';
                return null;
              }),

              // Nama Toko Input
              _buildLabel('Nama Toko / UMKM'),
              _buildTextInput(_sellerCtrl, 'Masukkan nama toko...', (val) {
                if (val == null || val.trim().isEmpty) return 'Nama toko wajib diisi';
                return null;
              }),

              // 3. Kategori Dropdown (as shown in Screenshot 5)
              _buildLabel('Kategori'),
              _buildKategoriDropdown(),

              // 4. Deskripsi Input
              _buildLabel('Deskripsi'),
              _buildTextInput(_descCtrl, 'Masukkan deskripsi...', (val) {
                if (val == null || val.trim().isEmpty) return 'Deskripsi wajib diisi';
                return null;
              }, maxLines: 3),

              // 5. Harga & Stok Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Harga (Rp)'),
                        _buildTextInput(_priceCtrl, '45000', (val) {
                          if (val == null || double.tryParse(val) == null) return 'Wajib angka';
                          return null;
                        }, isNumber: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Stok'),
                        _buildTextInput(_stockCtrl, '120', (val) {
                          if (val == null || int.tryParse(val) == null) return 'Wajib angka';
                          return null;
                        }, isNumber: true),
                      ],
                    ),
                  ),
                ],
              ),

              // 6. Berat (Gram) Input
              _buildLabel('Berat (Gram)'),
              _buildTextInput(_weightCtrl, '250', (val) {
                if (val == null || int.tryParse(val) == null) return 'Wajib angka';
                return null;
              }, isNumber: true),
              const SizedBox(height: 16),

              // Characteristics Input
              _buildLabel('Karakteristik (Pisahkan dengan koma)'),
              _buildTextInput(
                _characteristicsCtrl,
                'Contoh: Gurih, Renyah, Alami',
                (val) => null,
              ),
              const SizedBox(height: 16),

              // 7. Toggle switch Aktifkan Produk (as shown in Screenshot 5)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aktifkan Produk',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (val) => setState(() => _isActive = val),
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF4CAF50),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey[300],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 8. Action Buttons
              Row(
                children: [
                  // Batal button
                  OutlinedButton(
                    onPressed: () => navNotifier.goBack(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Color(0xFF6B2A0C)),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B2A0C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Simpan button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final double price = double.parse(_priceCtrl.text);
                          final int weight = int.parse(_weightCtrl.text);
                          final int stock = int.parse(_stockCtrl.text);
                          final List<String> parsedCharacteristics = _characteristicsCtrl.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                          // Map category dropdown value to model categories code
                          String domainCategory = 'Udang';
                          if (_selectedCategory == 'Krupuk Ikan') {
                            domainCategory = 'Ikan';
                          }

                          if (isEditMode && navState.selectedProduct != null) {
                            final updated = navState.selectedProduct!.copyWith(
                              name: _nameCtrl.text,
                              sellerName: _sellerCtrl.text,
                              category: domainCategory,
                              price: price,
                              // Preserve active discount if present
                              originalPrice: navState.selectedProduct!.originalPrice,
                              weight: weight,
                              stock: stock,
                              description: _descCtrl.text,
                              isActive: _isActive,
                              imageUrl: _imgCtrl.text,
                              characteristics: parsedCharacteristics,
                            );
                            productsNotifier.updateProduct(
                              updated,
                              webImageBytes: _webImageBytes,
                              webImageName: _webImageName,
                              mobileImagePath: _mobileImagePath,
                            );
                          } else {
                            final newProd = Product(
                              id: 'p${Random().nextInt(8999) + 1000}',
                              name: _nameCtrl.text,
                              sellerName: _sellerCtrl.text,
                              price: price,
                              originalPrice: 0.0,
                              imageUrl: _imgCtrl.text,
                              category: domainCategory,
                              weight: weight,
                              description: _descCtrl.text,
                              stock: stock,
                              isActive: _isActive,
                              rating: 4.8,
                              reviewsCount: 1,
                              characteristics: parsedCharacteristics,
                            );
                            productsNotifier.addProduct(
                              newProd,
                              webImageBytes: _webImageBytes,
                              webImageName: _webImageName,
                              mobileImagePath: _mobileImagePath,
                            );
                          }
                          final successMsg = isEditMode ? 'Berhasil Diperbarui' : 'Berhasil Ditambahkan';
                          _showSuccessDialog(context, successMsg);
                          Future.delayed(const Duration(milliseconds: 1500), () {
                            navNotifier.goBack();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0430E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Foto Produk section - Only contains the beautiful click-to-pick preview square
  Widget _buildFotoProdukSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFFDDCC), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC0430E).withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: _buildImageWidget(),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC0430E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Pick file method using image_picker
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _imgCtrl.text = picked.path; // Web blob URL
            _webImageBytes = bytes;
            _webImageName = picked.name;
          });
        } else {
          setState(() {
            _imgCtrl.text = picked.path; // Mobile local path
            _mobileImagePath = picked.path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // Safe rendering of network vs local files
  Widget _buildImageWidget() {
    final path = _imgCtrl.text.trim().isEmpty ? _imageUrl : _imgCtrl.text.trim();
    
    if (path.isEmpty) {
      return Container(
        color: const Color(0xFFFFF0E6),
        width: 90,
        height: 90,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: Color(0xFFC0430E), size: 24),
            SizedBox(height: 4),
            Text(
              'Pilih Foto',
              style: TextStyle(
                fontSize: 8,
                color: Color(0xFFC0430E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    if (kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: 90,
        height: 90,
        errorBuilder: (context, error, stackTrace) => _buildErrorImagePlaceholder(),
      );
    } else {
      // Mobile / Desktop local file vs dynamic URLs
      if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          width: 90,
          height: 90,
          errorBuilder: (context, error, stackTrace) => _buildErrorImagePlaceholder(),
        );
      } else {
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: 90,
          height: 90,
          errorBuilder: (context, error, stackTrace) => _buildErrorImagePlaceholder(),
        );
      }
    }
  }

  Widget _buildErrorImagePlaceholder() {
    return Container(
      color: const Color(0xFFFFF0E6),
      width: 90,
      height: 90,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Color(0xFFC0430E), size: 24),
          SizedBox(height: 4),
          Text('No Image', style: TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C7C7C)),
      ),
    );
  }

  Widget _buildTextInput(
    TextEditingController ctrl,
    String hint,
    String? Function(String?)? validator, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDDCC)),
      ),
      child: TextFormField(
        controller: ctrl,
        validator: validator,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Dropdown selector matching Screenshot 5 exactly
  Widget _buildKategoriDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDDCC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7C7C7C)),
          items: ['Krupuk Udang', 'Krupuk Ikan'].map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(
                val,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Auto-close the dialog after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF166534), // Deep premium green
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF166534),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
