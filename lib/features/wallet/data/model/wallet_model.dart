import 'dart:typed_data';

import 'package:solfare/features/wallet/domain/entities/wallet.dart';

/// Data-layer representation of a wallet.
/// Handles conversion between raw data and domain entity.
class WalletModel extends Wallet {
  const WalletModel({
    required super.address,
    required super.publicKey,
    required super.mnemonic,
  });

  /// Create a WalletModel from raw key derivation results.
  factory WalletModel.fromKeyData({
    required String address,
    required Uint8List publicKey,
    required String mnemonic,
  }) {
    return WalletModel(
      address: address,
      publicKey: publicKey,
      mnemonic: mnemonic,
    );
  }

  /// Serialize to a map for storage (excluding sensitive data like mnemonic).
  Map<String, String> toStorageMap() {
    return {
      'address': address,
    };
  }
}
