class DappItem {
  final String name;
  final String description;
  final String iconUrl;
  final String url;
  final String category; // Featured, Earn, Ecosystem, Memes

  const DappItem({
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.url,
    required this.category,
  });
}
