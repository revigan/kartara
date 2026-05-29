class Coupon {
  final String id;
  final String code;
  final String name;
  final String description;
  final double discountAmount;
  final double minPurchase;
  final bool isActive;
  final DateTime? expiryDate;

  Coupon({
    required this.id,
    required this.code,
    this.name = '',
    this.description = '',
    required this.discountAmount,
    required this.minPurchase,
    this.isActive = true,
    this.expiryDate,
  });

  String get displayName {
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return 'Kupon Diskon';
  }

  String get displayDescription {
    if (description.isNotEmpty) return description;
    return 'Hemat Rp ${discountAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String get displayCode {
    if (code.isNotEmpty && !code.startsWith('DISKON')) {
      return code;
    }
    return 'Kupon Rp ${discountAmount.toStringAsFixed(0)}';
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    DateTime? expiry;
    final expiryRaw = json['expiryDate'] ?? json['expiry_date'];
    if (expiryRaw != null && expiryRaw.toString().isNotEmpty) {
      try {
        expiry = DateTime.parse(expiryRaw.toString());
      } catch (_) {}
    }
    return Coupon(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      minPurchase: (json['minPurchase'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? true,
      expiryDate: expiry,
    );
  }
}
