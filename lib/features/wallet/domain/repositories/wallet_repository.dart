import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

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

  /// Retrieve the ACTIVE wallet's address.
  Future<String?> getSavedAddress();

  /// Clear all wallet data from secure storage.
  Future<void> clearWallet();

  /// Get the ACTIVE wallet's mnemonic (needed for signing transactions).
  Future<String?> getStoredMnemonic();

  // ── Multi-wallet API ────────────────────────────────────────────────────

  /// Return every wallet stored on device, oldest first.
  Future<List<WalletAccount>> getAllWallets();

  /// Return the currently-selected wallet, or null if none installed.
  Future<WalletAccount?> getActiveWallet();

  /// Switch the active wallet by id.
  Future<void> setActiveWalletId(String id);

  /// Add a new wallet from a mnemonic. No-op if the derived address is
  /// already stored — returns the existing entry in that case.
  Future<WalletAccount> addWallet(String mnemonic, {String? name});

  /// Remove a specific wallet. Active selection falls back to the first
  /// remaining wallet automatically.
  Future<void> removeWallet(String id);

  /// Rename a wallet.
  Future<void> renameWallet(String id, String name);

  /// Update a wallet's card background.
  Future<void> setWalletCardBackground(String id, String cardBackground);
}
