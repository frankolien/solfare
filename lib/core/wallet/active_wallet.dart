import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';

// Read-only shortcut for screens that don't want the full bloc/repository
// graph just to look up "who am I right now."
class ActiveWallet {
  ActiveWallet._();
  static final _store = WalletAccountsStore();

  static Future<String?> mnemonic() async => (await _store.getActive())?.mnemonic;
  static Future<String?> address() async => (await _store.getActive())?.address;
}
