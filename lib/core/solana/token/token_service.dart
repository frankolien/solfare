import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/solana/token/mint_info.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Thrown when a transfer cannot be built at all, with a reason worth showing.
class TokenTransferException implements Exception {
  final String message;
  const TokenTransferException(this.message);

  @override
  String toString() => message;
}

/// Reads mints and builds token transfers, Token-2022 included.
class TokenService {
  final SolanaRpcDataSource _rpc;

  const TokenService(this._rpc);

  /// Rough rent for a token account, used to warn before the sender pays it.
  /// The real figure comes from the simulation; this is for the amount screen,
  /// which runs before there is a transaction to simulate.
  static const int approximateAtaRentLamports = 2039280;

  /// Read a mint and everything about it that changes a transfer.
  Future<MintInfo> mintInfo(String mint) async {
    final account = await _rpc.getAccountInfo(mint);
    if (account == null) {
      throw const TokenTransferException('That token does not exist on this network.');
    }

    final programId = account['owner'] as String? ?? MintInfo.tokenProgramId;
    final info = account['data']?['parsed']?['info'] as Map<String, dynamic>?;
    if (info == null) {
      throw const TokenTransferException('That account is not a token mint.');
    }

    final extensions = (info['extensions'] as List?) ?? const [];
    Map<String, dynamic>? extension(String name) {
      for (final e in extensions) {
        if ((e as Map)['extension'] == name) return Map<String, dynamic>.from(e);
      }
      return null;
    }

    final feeConfig = extension('transferFeeConfig');
    return MintInfo(
      mint: mint,
      programId: programId,
      decimals: (info['decimals'] as int?) ?? 0,
      isToken2022: programId == MintInfo.token2022ProgramId,
      nonTransferable: extension('nonTransferable') != null,
      transferFee: feeConfig == null ? null : await _transferFee(feeConfig),
      hasTransferHook: extension('transferHook') != null,
      hasPermanentDelegate: extension('permanentDelegate') != null,
      defaultFrozen: extension('defaultAccountState')?['state']?['accountState'] == 'frozen',
      interestBearing: extension('interestBearingConfig') != null,
    );
  }

  /// A fee config carries two schedules so a change can be announced ahead of
  /// time. Which one applies depends on the current epoch, so quoting the
  /// wrong one would misstate what the recipient receives.
  Future<TransferFee?> _transferFee(Map<String, dynamic> config) async {
    final state = config['state'] as Map<String, dynamic>?;
    if (state == null) return null;

    final newer = state['newerTransferFee'] as Map<String, dynamic>?;
    final older = state['olderTransferFee'] as Map<String, dynamic>?;

    var chosen = newer ?? older;
    if (newer != null && older != null) {
      final activationEpoch = int.tryParse('${newer['epoch']}') ?? 0;
      final epoch = await _currentEpoch();
      chosen = (epoch != null && epoch < activationEpoch) ? older : newer;
    }
    if (chosen == null) return null;

    return TransferFee(
      basisPoints: int.tryParse('${chosen['transferFeeBasisPoints']}') ?? 0,
      maximumFee: int.tryParse('${chosen['maximumFee']}') ?? 0,
    );
  }

  Future<int?> _currentEpoch() async {
    try {
      return await _rpc.getEpoch();
    } catch (e) {
      // Only reached for mints that actually carry a fee schedule, and the
      // newer schedule is the right guess when we cannot tell.
      debugLog('[Token] epoch lookup failed, assuming newer fee: $e');
      return null;
    }
  }

  Future<solana.Ed25519HDPublicKey> associatedTokenAddress({
    required String owner,
    required MintInfo mint,
  }) =>
      solana.findAssociatedTokenAddress(
        owner: solana.Ed25519HDPublicKey.fromBase58(owner),
        mint: solana.Ed25519HDPublicKey.fromBase58(mint.mint),
        // Token-2022 mints derive a different address; using the default here
        // would send to an account nobody controls.
        tokenProgramType: mint.isToken2022
            ? solana.TokenProgramType.token2022Program
            : solana.TokenProgramType.tokenProgram,
      );

  /// Instructions to move [amount] base units of [mint] from [owner] to
  /// [recipient], creating the destination account if it does not exist.
  Future<List<encoder.Instruction>> buildTransfer({
    required MintInfo mint,
    required String owner,
    required String recipient,
    required int amount,
  }) async {
    if (mint.nonTransferable) {
      throw const TokenTransferException(
          'This token cannot be transferred. Its mint is marked non-transferable.');
    }
    if (amount <= 0) {
      throw const TokenTransferException('Enter an amount greater than zero.');
    }

    final ownerKey = solana.Ed25519HDPublicKey.fromBase58(owner);
    final mintKey = solana.Ed25519HDPublicKey.fromBase58(mint.mint);
    final tokenProgram = mint.isToken2022
        ? solana.TokenProgramType.token2022Program
        : solana.TokenProgramType.tokenProgram;

    final source = await associatedTokenAddress(owner: owner, mint: mint);
    final destination = await associatedTokenAddress(owner: recipient, mint: mint);

    final instructions = <encoder.Instruction>[];

    if (!await _accountExists(destination.toBase58())) {
      // Idempotent so a race with another transfer creating the same account
      // does not fail the whole transaction.
      instructions.add(solana.AssociatedTokenAccountInstruction.createAccountIdempotent(
        funder: ownerKey,
        address: destination,
        owner: solana.Ed25519HDPublicKey.fromBase58(recipient),
        mint: mintKey,
        tokenProgramId: tokenProgram.id,
      ));
    }

    // transferChecked over transfer: it verifies decimals on chain, which
    // turns a decimals mistake into a rejected transaction rather than a
    // transfer off by a factor of a thousand.
    instructions.add(solana.TokenInstruction.transferChecked(
      amount: amount,
      decimals: mint.decimals,
      source: source,
      mint: mintKey,
      destination: destination,
      owner: ownerKey,
      tokenProgram: tokenProgram,
    ));

    return instructions;
  }

  /// True when the destination account has to be created, which the sender
  /// pays rent for.
  Future<bool> destinationNeedsCreating({
    required MintInfo mint,
    required String recipient,
  }) async {
    final ata = await associatedTokenAddress(owner: recipient, mint: mint);
    return !await _accountExists(ata.toBase58());
  }

  Future<bool> _accountExists(String address) async {
    try {
      return await _rpc.getAccountInfo(address) != null;
    } catch (e) {
      // Assuming it exists would skip creating it and fail on chain; assuming
      // it does not is idempotent and merely redundant.
      debugLog('[Token] account lookup failed for $address: $e');
      return false;
    }
  }
}
