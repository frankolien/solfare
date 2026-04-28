/// A single wallet entry in the multi-wallet store.
///
/// `id` is a stable random identifier that outlives name/card changes — used
/// as the key for per-wallet caches and for selecting the active wallet
/// without relying on mnemonic equality.
class WalletAccount {
  final String id;
  final String address;
  final String mnemonic;
  final String name;
  final String cardBackground;
  final DateTime createdAt;

  const WalletAccount({
    required this.id,
    required this.address,
    required this.mnemonic,
    required this.name,
    required this.cardBackground,
    required this.createdAt,
  });

  WalletAccount copyWith({
    String? name,
    String? cardBackground,
  }) {
    return WalletAccount(
      id: id,
      address: address,
      mnemonic: mnemonic,
      name: name ?? this.name,
      cardBackground: cardBackground ?? this.cardBackground,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'address': address,
        'mnemonic': mnemonic,
        'name': name,
        'cardBackground': cardBackground,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory WalletAccount.fromJson(Map<String, dynamic> json) => WalletAccount(
        id: json['id'] as String,
        address: json['address'] as String,
        mnemonic: json['mnemonic'] as String,
        name: json['name'] as String? ?? 'Main Wallet',
        cardBackground: json['cardBackground'] as String? ?? 'card_1.png',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? 0,
        ),
      );
}
