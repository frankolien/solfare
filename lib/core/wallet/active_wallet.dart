import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';

/// Shortcut for the handful of screens that need to read the active wallet
/// without taking a dependency on the full bloc/repository graph. All
/// operations go through [WalletAccountsStore] so they respect migrations
/// and the active-id pointer.
class ActiveWallet {
  ActiveWallet._();
  static final _store = WalletAccountsStore();

  /// Returns the active wallet's mnemonic, or null if none installed.
  static Future<String?> mnemonic() async {
    final active = await _store.getActive();
    return active?.mnemonic;
  }

  /// Returns the active wallet's address, or null if none installed.
  static Future<String?> address() async {
    final active = await _store.getActive();
    return active?.address;
  }
}
