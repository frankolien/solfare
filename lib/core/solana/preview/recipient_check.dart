import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Asks what a destination address actually is before sending to it.
///
/// Solana accepts a transfer to any address. Most addresses that are not
/// wallets are one-way: a token mint is owned by the Token program, which has
/// no instruction to withdraw lamports, so SOL sent there is unrecoverable
/// unless the mint happens to carry a close authority. The chain will not stop
/// this and the transaction will not fail — the wallet is the only thing
/// standing between the user and a permanent loss.
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
      // A lookup that fails is not evidence of anything. Inventing a warning
      // from a network error would be as bad as missing a real one.
      debugLog('[Recipient] could not inspect $address: $e');
      return null;
    }

    // Never used, or emptied and closed. This is what most fresh wallets look
    // like, so it is the normal case rather than a suspicious one.
    if (account == null) return null;

    if (account['executable'] == true) {
      return const RiskFlag(
        severity: RiskSeverity.danger,
        title: 'This address is a program',
        detail: 'It is on-chain code, not a wallet. Anything sent here is lost.',
      );
    }

    final owner = account['owner'] as String?;
    if (owner == null || owner == _systemProgram) return null;

    if (owner == _tokenProgram || owner == _token2022Program) {
      final type = account['data']?['parsed']?['type'] as String?;
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
