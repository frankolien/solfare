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
