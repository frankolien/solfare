import 'package:solfare/features/explore/domain/entities/crypto_news.dart';

class CryptoNewsModel extends CryptoNews {
  const CryptoNewsModel({
    required super.id,
    required super.title,
    super.source,
    required super.url,
    super.imageUrl,
    required super.publishedAt,
  });

  factory CryptoNewsModel.fromJson(Map<String, dynamic> json) {
    return CryptoNewsModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      source: (json['source'] as Map<String, dynamic>?)?['title'] as String?,
      url: json['url'] as String? ?? '',
      imageUrl: (json['metadata'] as Map<String, dynamic>?)?['image'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
