/// A Token-2022 transfer fee, withheld from the recipient on every transfer.
class TransferFee {
  final int basisPoints;

  /// Cap in base units. A large transfer pays this rather than the full rate.
  final int maximumFee;

  const TransferFee({required this.basisPoints, required this.maximumFee});

  /// Fee charged on [amount], rounded up as the program does.
  int feeOn(int amount) {
    if (basisPoints == 0) return 0;
    final raw = (amount * basisPoints + 9999) ~/ 10000;
    return raw > maximumFee ? maximumFee : raw;
  }

  /// What actually lands in the recipient's account.
  int netOf(int amount) => amount - feeOn(amount);

  double get percent => basisPoints / 100;
}

/// What a mint is and what its extensions will do to a transfer.
///
/// Token-2022 mints can carry behaviour that plain SPL mints cannot: fees
/// that shrink the amount in flight, transfers that are forbidden outright,
/// a delegate that can move balances without the owner. A wallet that treats
/// them as ordinary tokens tells the user things that are not true.
class MintInfo {
  final String mint;

  /// Owning program — plain Token or Token-2022.
  final String programId;
  final int decimals;

  final bool isToken2022;
  final bool nonTransferable;
  final TransferFee? transferFee;
  final bool hasTransferHook;
  final bool hasPermanentDelegate;
  final bool defaultFrozen;
  final bool interestBearing;

  const MintInfo({
    required this.mint,
    required this.programId,
    required this.decimals,
    this.isToken2022 = false,
    this.nonTransferable = false,
    this.transferFee,
    this.hasTransferHook = false,
    this.hasPermanentDelegate = false,
    this.defaultFrozen = false,
    this.interestBearing = false,
  });

  static const tokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const token2022ProgramId = 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';

  /// Build from a jsonParsed `getAccountInfo` result.
  ///
  /// [currentEpoch] picks between the two transfer fee schedules; without it
  /// the newer one is assumed, which is the common case since most mints
  /// never schedule a change.
  static MintInfo parse(String mint, Map<String, dynamic> account, {int? currentEpoch}) {
    final programId = account['owner'] as String? ?? tokenProgramId;
    final info = account['data']?['parsed']?['info'] as Map<String, dynamic>?;
    if (info == null) {
      throw const FormatException('That account is not a token mint.');
    }

    final extensions = (info['extensions'] as List?) ?? const [];
    Map<String, dynamic>? state(String name) {
      for (final e in extensions) {
        if ((e as Map)['extension'] == name) {
          return (e['state'] as Map?)?.cast<String, dynamic>() ?? const {};
        }
      }
      return null;
    }

    final hook = state('transferHook');
    return MintInfo(
      mint: mint,
      programId: programId,
      decimals: (info['decimals'] as int?) ?? 0,
      isToken2022: programId == token2022ProgramId,
      nonTransferable: state('nonTransferable') != null,
      transferFee: _feeFrom(state('transferFeeConfig'), currentEpoch),
      // The extension can be present with no program set — PYUSD ships like
      // that. Present-but-unset means nothing runs on transfer, so warning
      // about it would be a warning about nothing.
      hasTransferHook: hook != null && hook['programId'] != null,
      hasPermanentDelegate: state('permanentDelegate')?['delegate'] != null,
      defaultFrozen: state('defaultAccountState')?['accountState'] == 'frozen',
      interestBearing: state('interestBearingConfig') != null,
    );
  }

  /// The schedule in force, or null when there is no fee to speak of.
  ///
  /// A config with a zero rate is not a fee. Reporting one would tell the
  /// user the recipient gets less than they send, which is false.
  static TransferFee? _feeFrom(Map<String, dynamic>? config, int? currentEpoch) {
    if (config == null) return null;

    final newer = (config['newerTransferFee'] as Map?)?.cast<String, dynamic>();
    final older = (config['olderTransferFee'] as Map?)?.cast<String, dynamic>();

    var chosen = newer ?? older;
    if (newer != null && older != null && currentEpoch != null) {
      final activation = int.tryParse('${newer['epoch']}') ?? 0;
      chosen = currentEpoch < activation ? older : newer;
    }
    if (chosen == null) return null;

    final basisPoints = int.tryParse('${chosen['transferFeeBasisPoints']}') ?? 0;
    if (basisPoints == 0) return null;

    return TransferFee(
      basisPoints: basisPoints,
      maximumFee: int.tryParse('${chosen['maximumFee']}') ?? 0,
    );
  }

  /// True when this mint schedules a fee change, which is the only case where
  /// the epoch has to be known to answer correctly.
  static bool needsEpoch(Map<String, dynamic> account) {
    final extensions =
        (account['data']?['parsed']?['info']?['extensions'] as List?) ?? const [];
    for (final e in extensions) {
      if ((e as Map)['extension'] != 'transferFeeConfig') continue;
      final state = e['state'] as Map?;
      final newer = state?['newerTransferFee'] as Map?;
      final older = state?['olderTransferFee'] as Map?;
      if (newer == null || older == null) return false;
      // Identical schedules mean no change is pending and the epoch cannot
      // change the answer.
      return newer['transferFeeBasisPoints'] != older['transferFeeBasisPoints'] ||
          newer['maximumFee'] != older['maximumFee'];
    }
    return false;
  }

  /// True when anything about this mint changes how a send behaves.
  bool get hasNotableExtensions =>
      nonTransferable ||
      transferFee != null ||
      hasTransferHook ||
      hasPermanentDelegate ||
      defaultFrozen ||
      interestBearing;

  @override
  String toString() => 'MintInfo($mint, decimals=$decimals, '
      'token2022=$isToken2022, fee=${transferFee?.basisPoints}bps, '
      'nonTransferable=$nonTransferable)';
}
