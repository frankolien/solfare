import 'package:solfare/core/security/mnemonic_envelope.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';

// Read-only shortcut for screens that don't want the full bloc/repository
// graph just to look up "who am I right now."
class ActiveWallet {
  ActiveWallet._();
  static final _store = WalletAccountsStore();

  // Unwrapped here rather than by each caller, so there is one place that
  // can throw MnemonicLockedException and one place to get it right.
  static Future<String?> mnemonic() async {
    final active = await _store.getActive();
    if (active == null) return null;
    return MnemonicEnvelope.unwrap(active.mnemonic, WalletKey.value);
  }
  static Future<String?> address() async => (await _store.getActive())?.address;
}
