class Nft {
  final String mint;
  final String name;
  final String? imageUrl;
  final String? collection;
  final String? description;

  const Nft({
    required this.mint,
    required this.name,
    this.imageUrl,
    this.collection,
    this.description,
  });
}
