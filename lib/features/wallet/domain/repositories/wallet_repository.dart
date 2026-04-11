import 'package:solfare/features/wallet/domain/entities/wallet.dart';

/// Abstract wallet repository — defines WHAT the app can do with wallets.
/// The data layer decides HOW.
abstract class WalletRepository {
  /// Generate a new wallet (mnemonic → seed → keypair → address).
  Future<Wallet> createWallet();

  /// Import an existing wallet from a mnemonic phrase.
  Future<Wallet> importWallet(String mnemonic);

  /// Persist the wallet credentials securely on device.
  Future<void> saveWallet(Wallet wallet);

  /// Check if a wallet already exists on this device.
  Future<bool> hasWallet();

  /// Retrieve the stored wallet address.
  Future<String?> getSavedAddress();

  /// Clear all wallet data from secure storage.
  Future<void> clearWallet();

  /// Get the stored mnemonic phrase (needed for signing transactions).
  Future<String?> getStoredMnemonic();
}
