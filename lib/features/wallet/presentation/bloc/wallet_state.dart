import 'package:equatable/equatable.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/domain/entities/transactions.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';

/// States that WalletBloc can emit
/// States represent the current condition of the wallet feature
abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no wallet operations have occurred
class WalletInitial extends WalletState {
  const WalletInitial();
}

/// Loading state - wallet operation is in progress
class WalletLoading extends WalletState {
  const WalletLoading();
}

/// Wallet created successfully
class WalletCreated extends WalletState {
  final Wallet wallet;
  final bool isImported;

  const WalletCreated(this.wallet, this.isImported);

  @override
  List<Object?> get props => [wallet, isImported];
}

/// Wallet saved successfully
class WalletSaved extends WalletState {
  const WalletSaved();
}

/// Wallet exists check completed
class WalletExistsChecked extends WalletState {
  final bool exists;

  const WalletExistsChecked(this.exists);

  @override
  List<Object?> get props => [exists];
}

/// Balance fetched successfully
class BalanceFetched extends WalletState {
  final int balance; // Balance in lamports
  final String address;

  const BalanceFetched({
    required this.balance,
    required this.address,
  });

  @override
  List<Object?> get props => [balance, address];

  /// Convert lamports to SOL
  double get balanceInSol => balance / 1000000000;
}

/// Airdrop requested successfully
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

/// Wallet cleared successfully
class WalletCleared extends WalletState {
  const WalletCleared();
}

/// SOL price fetched successfully
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

/// NFTs fetched successfully
class NftsFetched extends WalletState {
  final List<Nft> nfts;
  const NftsFetched(this.nfts);
  @override
  List<Object?> get props => [nfts];
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

/// SOL is being sent (in-flight)
class SendingSol extends WalletState {
  const SendingSol();
}

/// SOL sent successfully
class SolSent extends WalletState {
  final String signature;
  final double amountInSol;
  final String recipientAddress;

  const SolSent({
    required this.signature,
    required this.amountInSol,
    required this.recipientAddress,
  });

  @override
  List<Object?> get props => [signature, amountInSol, recipientAddress];
}