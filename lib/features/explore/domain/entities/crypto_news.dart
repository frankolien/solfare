class CryptoNews {
  final String id;
  final String title;
  final String? source;
  final String url;
  final String? imageUrl;
  final DateTime publishedAt;

  const CryptoNews({
    required this.id,
    required this.title,
    this.source,
    required this.url,
    this.imageUrl,
    required this.publishedAt,
  });
}
