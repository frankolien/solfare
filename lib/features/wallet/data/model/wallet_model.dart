import 'dart:typed_data';

import 'package:solfare/features/wallet/domain/entities/wallet.dart';

class WalletModel extends Wallet {
  const WalletModel({
    required super.address,
    required super.publicKey,
    required super.mnemonic,
  });

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

  // Excludes the mnemonic — that lives in WalletAccountsStore only.
  Map<String, String> toStorageMap() => {'address': address};
}
