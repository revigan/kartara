import '../config/pocketbase_config.dart';

class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final String image; // Holds filename or URL
  final bool isActive;

  PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    this.isActive = true,
  });

  String get imageUrl {
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image; // Support mock / absolute fallback URLs
    }
    // PocketBase dynamic file URL resolution format
    return '${PocketBaseConfig.baseUrl}/api/files/banners/$id/$image';
  }

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    final String imageVal = (json['image'] as String? ?? json['imageUrl'] as String?) ?? '';
    return PromoBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      image: imageVal,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
