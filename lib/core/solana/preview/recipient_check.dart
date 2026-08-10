import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/core/util/json.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Asks what a destination address actually is before sending to it.
class RecipientCheck {
  final SolanaRpcDataSource _rpc;

  const RecipientCheck(this._rpc);

  static const _systemProgram = '11111111111111111111111111111111';
  static const _tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const _token2022Program = 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';

  /// A flag when [address] is not an ordinary wallet, null when it is.
  Future<RiskFlag?> inspect(String address) async {
    final Map<String, dynamic>? account;
    try {
      account = await _rpc.getAccountInfo(address);
    } catch (e) {
      // A lookup that fails is not evidence of anything.
      debugLog('[Recipient] could not inspect $address: $e');
      return null;
    }

    // Never used, or emptied and closed.
    if (account == null) return null;

    if (account.boolAt('executable') == true) {
      return const RiskFlag(
        severity: RiskSeverity.danger,
        title: 'This address is a program',
        detail: 'It is on-chain code, not a wallet. Anything sent here is lost.',
      );
    }

    final owner = account.stringAt('owner');
    if (owner == null || owner == _systemProgram) return null;

    if (owner == _tokenProgram || owner == _token2022Program) {
      // pathAt, not a ?[] chain: getAccountInfo is asked for jsonParsed and
      // falls back to base64 for anything it cannot parse, which makes `data` a
      // two-element List.
      final type = account.pathAt(['data', 'parsed'])?.stringAt('type');
      return switch (type) {
        'mint' => const RiskFlag(
            severity: RiskSeverity.danger,
            title: 'This address is a token mint',
            detail: 'It is the token itself, not somebody\'s wallet. SOL sent '
                'to a mint cannot be withdrawn by anyone, including you.',
          ),
        'account' => const RiskFlag(
            severity: RiskSeverity.danger,
            title: 'This address is a token account',
            detail: 'It holds one kind of token for someone. Send to their '
                'wallet address instead — SOL sent here is stuck.',
          ),
        _ => const RiskFlag(
            severity: RiskSeverity.danger,
            title: 'This address belongs to the token program',
            detail: 'It is not a wallet, and what is sent here may not be '
                'recoverable.',
          ),
      };
    }

    return RiskFlag(
      severity: RiskSeverity.caution,
      title: 'This address is controlled by a program',
      detail: 'It is not an ordinary wallet. Only send here if the program is '
          'meant to receive it — ${_short(owner)}.',
    );
  }

  String _short(String address) => address.length <= 12
      ? address
      : '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
}
