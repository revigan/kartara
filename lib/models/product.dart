class Product {
  final String id;
  final String name;
  final String sellerName;
  final double price;
  final double originalPrice; // Harga asli coret
  final String imageUrl;
  final List<String> images; // Galeri banyak gambar
  final String category;
  final double rating;
  final int reviewsCount;
  final int weight; // in grams
  final String description;
  final List<String> characteristics;
  final int stock;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    required this.sellerName,
    required this.price,
    this.originalPrice = 0.0,
    required this.imageUrl,
    this.images = const [], // Default kosong untuk kompatibilitas ke belakang
    required this.category,
    required this.rating,
    required this.reviewsCount,
    required this.weight,
    required this.description,
    required this.characteristics,
    required this.stock,
    this.isActive = true,
  });

  bool get hasDiscount => originalPrice > price;

  int get discountPercentage {
    if (!hasDiscount || originalPrice <= 0) return 0;
    return (((originalPrice - price) / originalPrice) * 100).round();
  }

  Product copyWith({
    String? id,
    String? name,
    String? sellerName,
    double? price,
    double? originalPrice,
    String? imageUrl,
    List<String>? images,
    String? category,
    double? rating,
    int? reviewsCount,
    int? weight,
    String? description,
    List<String>? characteristics,
    int? stock,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sellerName: sellerName ?? this.sellerName,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      weight: weight ?? this.weight,
      description: description ?? this.description,
      characteristics: characteristics ?? this.characteristics,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sellerName': sellerName,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'images': images,
      'category': category,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'weight': weight,
      'description': description,
      'characteristics': characteristics,
      'stock': stock,
      'isActive': isActive,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sellerName: json['sellerName'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String? ?? '',
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      category: json['category'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      weight: json['weight'] as int? ?? 250,
      description: json['description'] as String? ?? '',
      characteristics: (json['characteristics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      stock: json['stock'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
