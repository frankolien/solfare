import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

abstract class WalletRepository {
  Future<Wallet> createWallet();
  Future<Wallet> importWallet(String mnemonic);
  Future<void> saveWallet(Wallet wallet);
  Future<bool> hasWallet();
  Future<String?> getSavedAddress();
  Future<void> clearWallet();
  Future<String?> getStoredMnemonic();

  Future<List<WalletAccount>> getAllWallets();
  Future<WalletAccount?> getActiveWallet();
  Future<void> setActiveWalletId(String id);

  // No-op + returns the existing entry if the derived address is already
  // stored, so the import-wallet flow is idempotent.
  Future<WalletAccount> addWallet(String mnemonic, {String? name});

  // Active selection falls back to the first remaining wallet.
  Future<void> removeWallet(String id);

  Future<void> renameWallet(String id, String name);
  Future<void> setWalletCardBackground(String id, String cardBackground);
}
