import 'package:equatable/equatable.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

enum BuyStatus {
  /// Typing an amount.
  editing,

  /// Building and simulating the route.
  preparing,

  /// The preview is on screen, waiting on the user.
  review,
  sending,
  done,
  failed,
}

class BuyState extends Equatable {
  final BuyStatus status;
  final MarketToken? asset;
  final String walletAddress;

  /// What is being spent. SOL or USDC — the two things a wallet is likely to
  /// already hold.
  final SwapToken payWith;
  final String amountText;

  /// Null until the balance lookup answers. Zero is a balance; null is not.
  final double? balance;

  /// Base units of [asset] the current amount would buy.
  final int? quotedOutRaw;
  final bool isQuoting;

  final TxPreview? preview;
  final String? signature;
  final String? error;

  const BuyState({
    this.status = BuyStatus.editing,
    this.asset,
    this.walletAddress = '',
    this.payWith = SwapToken.sol,
    this.amountText = '',
    this.balance,
    this.quotedOutRaw,
    this.isQuoting = false,
    this.preview,
    this.signature,
    this.error,
  });

  double? get amount {
    final parsed = double.tryParse(amountText);
    return (parsed == null || parsed <= 0) ? null : parsed;
  }

  /// Native SOL keeps a reserve behind: the fee, and the rent for the token
  /// account this purchase may have to open. Spending to the last lamport is
  /// how a swap fails after the user has already approved it.
  static const double solReserve = 0.01;

  double get spendable {
    final held = balance ?? 0;
    if (payWith.mint != SwapToken.sol.mint) return held;
    final left = held - solReserve;
    return left > 0 ? left : 0;
  }

  bool get hasEnough {
    final wanted = amount;
    // Unknown balance is not a reason to block the button — the simulation
    // is the thing that actually knows, and it runs before anything is sent.
    if (wanted == null || balance == null) return true;
    return wanted <= spendable;
  }

  double? get receiveAmount {
    final raw = quotedOutRaw;
    final decimals = asset?.decimals;
    if (raw == null || decimals == null) return null;
    var divisor = 1.0;
    for (var i = 0; i < decimals; i++) {
      divisor *= 10;
    }
    return raw / divisor;
  }

  bool get canReview =>
      status == BuyStatus.editing && amount != null && hasEnough && asset != null;

  BuyState copyWith({
    BuyStatus? status,
    MarketToken? asset,
    String? walletAddress,
    SwapToken? payWith,
    String? amountText,
    double? balance,
    int? quotedOutRaw,
    bool? isQuoting,
    TxPreview? preview,
    String? signature,
    String? error,
    bool clearQuote = false,
    bool clearError = false,
    bool clearPreview = false,
    bool clearBalance = false,
  }) {
    return BuyState(
      status: status ?? this.status,
      asset: asset ?? this.asset,
      walletAddress: walletAddress ?? this.walletAddress,
      payWith: payWith ?? this.payWith,
      amountText: amountText ?? this.amountText,
      balance: clearBalance ? null : (balance ?? this.balance),
      quotedOutRaw: clearQuote ? null : (quotedOutRaw ?? this.quotedOutRaw),
      isQuoting: isQuoting ?? this.isQuoting,
      preview: clearPreview ? null : (preview ?? this.preview),
      signature: signature ?? this.signature,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        asset?.id,
        walletAddress,
        payWith.mint,
        amountText,
        balance,
        quotedOutRaw,
        isQuoting,
        preview,
        signature,
        error,
      ];
}
