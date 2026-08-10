import 'package:solfare/core/solana/lamports.dart';
import 'package:equatable/equatable.dart';
import 'package:solfare/core/solana/pay/pay_request.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/core/solana/tx_outcome.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/domain/entities/transactions.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

/// States that WalletBloc can emit States represent the current condition of
/// the wallet feature
abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no wallet operations have occurred
class WalletInitial extends WalletState {
  const WalletInitial();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletCreated extends WalletState {
  final Wallet wallet;
  final bool isImported;

  const WalletCreated(this.wallet, this.isImported);

  @override
  List<Object?> get props => [wallet, isImported];
}

class WalletSaved extends WalletState {
  const WalletSaved();
}

class WalletExistsChecked extends WalletState {
  final bool exists;

  const WalletExistsChecked(this.exists);

  @override
  List<Object?> get props => [exists];
}

/// The check could not be completed — storage is present but unreadable.
class WalletStoreUnreadable extends WalletState {
  final String message;

  const WalletStoreUnreadable(this.message);

  @override
  List<Object?> get props => [message];
}

class BalanceFetched extends WalletState {
  final int balance; // Balance in lamports
  final String address;

  const BalanceFetched({
    required this.balance,
    required this.address,
  });

  @override
  List<Object?> get props => [balance, address];

  double get balanceInSol => Lamports.toSol(balance);
}

class AirdropRequested extends WalletState {
  final String transactionSignature;
  final String address;

  const AirdropRequested({
    required this.transactionSignature,
    required this.address,
  });

  @override
  List<Object?> get props => [transactionSignature, address];
}

class WalletCleared extends WalletState {
  const WalletCleared();
}

class SolPriceFetched extends WalletState {
  final double priceUsd;
  final double priceChange24h;

  const SolPriceFetched({
    required this.priceUsd,
    required this.priceChange24h,
  });

  @override
  List<Object?> get props => [priceUsd, priceChange24h];
}

/// Error state - something went wrong
class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}
 class WalletAddressLoaded extends WalletState {
  final String address;

  const WalletAddressLoaded(this.address);

  @override
  List<Object?> get props => [address];
}

/// Transaction history fetched successfully
class TransactionsFetched extends WalletState {
  final List<Transaction> transactions;

  const TransactionsFetched(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class NftsFetched extends WalletState {
  final List<Nft> nfts;
  const NftsFetched(this.nfts);
  @override
  List<Object?> get props => [nfts];
}

/// SPL tokens fetched successfully
class TokensFetched extends WalletState {
  final List<SplToken> tokens;
  const TokensFetched(this.tokens);
  @override
  List<Object?> get props => [tokens];
}

/// Emitted whenever the list of wallets changes (add, remove, rename, card).
class WalletsLoaded extends WalletState {
  final List<WalletAccount> wallets;
  final String? activeId;
  const WalletsLoaded({required this.wallets, required this.activeId});
  @override
  List<Object?> get props => [wallets, activeId];
}

/// Wallet customization loaded (name + card background)
class WalletCustomizationLoaded extends WalletState {
  final String walletName;
  final String cardBackground;

  const WalletCustomizationLoaded({
    required this.walletName,
    required this.cardBackground,
  });

  @override
  List<Object?> get props => [walletName, cardBackground];
}

/// A scanned payment is being resolved: parsed, fetched from the merchant where
/// applicable, and simulated.
class PayResolving extends WalletState {
  const PayResolving();
}

/// A payment is ready to approve.
class PayReady extends WalletState {
  final PayRequest request;
  final PayMerchant? merchant;
  final TxPreview preview;

  const PayReady({required this.request, required this.preview, this.merchant});

  @override
  List<Object?> get props => [request, merchant, preview];
}

/// The payment could not be prepared at all — bad URL, merchant down, or a
/// payload we refuse to sign.
class PayFailed extends WalletState {
  final String message;

  const PayFailed(this.message);

  @override
  List<Object?> get props => [message];
}

/// The pending send is being simulated.
class SendPreviewLoading extends WalletState {
  const SendPreviewLoading();
}

/// Simulation finished.
class SendPreviewReady extends WalletState {
  final TxPreview preview;

  const SendPreviewReady(this.preview);

  @override
  List<Object?> get props => [preview];
}

/// SOL is being sent.
class SendingSol extends WalletState {
  final TxPhase phase;

  const SendingSol({this.phase = TxPhase.preparing});

  @override
  List<Object?> get props => [phase];
}

/// Broadcast but never confirmed.
class SolSendFailed extends WalletState {
  final String message;
  final String signature;
  final bool expired;

  const SolSendFailed({
    required this.message,
    required this.signature,
    required this.expired,
  });

  @override
  List<Object?> get props => [message, signature, expired];
}

/// A transfer confirmed on chain.
class SolSent extends WalletState {
  final String signature;
  final double amountInSol;
  final String recipientAddress;
  final String symbol;

  const SolSent({
    required this.signature,
    required this.amountInSol,
    required this.recipientAddress,
    this.symbol = 'SOL',
  });

  @override
  List<Object?> get props => [signature, amountInSol, recipientAddress, symbol];
}