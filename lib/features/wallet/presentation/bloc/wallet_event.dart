import 'package:solfare/core/solana/lamports.dart';
import 'package:equatable/equatable.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class CreateWalletEvent extends WalletEvent {
  const CreateWalletEvent();
}

/// Internal event dispatched when the active Solana cluster changes.
class NetworkChangedEvent extends WalletEvent {
  const NetworkChangedEvent();
}

class SaveWalletEvent extends WalletEvent {
  final Wallet wallet;

  const SaveWalletEvent(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class CheckWalletExistsEvent extends WalletEvent {
  const CheckWalletExistsEvent();
}

/// Event to request airdrop (devnet/testnet only)
class RequestAirdropEvent extends WalletEvent {
  final String address;
  final int lamports; // Amount in lamports (default: 1 SOL = 1,000,000,000)

  const RequestAirdropEvent({
    required this.address,
    this.lamports = Lamports.perSol,
  });

  @override
  List<Object?> get props => [address, lamports];
}

class FetchBalanceEvent extends WalletEvent {
  final String address;

  const FetchBalanceEvent(this.address);

  @override
  List<Object?> get props => [address];
}

class ResetWalletEvent extends WalletEvent {
  const ResetWalletEvent();
}

/// Event to clear all wallet data from storage
class ClearWalletEvent extends WalletEvent {
  const ClearWalletEvent();
}

class FetchSolPriceEvent extends WalletEvent {
  const FetchSolPriceEvent();
}

/// Live ticker push from BinancePriceWsService.
class LivePriceTickEvent extends WalletEvent {
  final double priceUsd;
  final double percentChange24h;
  const LivePriceTickEvent(this.priceUsd, this.percentChange24h);

  @override
  List<Object?> get props => [priceUsd, percentChange24h];
}

class LoadWalletAddressEvent extends WalletEvent {
  const LoadWalletAddressEvent();

}

class ImportWalletEvent extends WalletEvent {
  final String mnemonic;
  const ImportWalletEvent(this.mnemonic);

  @override
  List<Object?> get props => [mnemonic];
}

class FetchTransactionsEvent extends WalletEvent {
  final String address;

  const FetchTransactionsEvent(this.address);

  @override
  List<Object?> get props => [address];
}

class FetchNftsEvent extends WalletEvent {
  final String address;
  const FetchNftsEvent(this.address);
  @override
  List<Object?> get props => [address];
}

class FetchTokensEvent extends WalletEvent {
  final String address;
  const FetchTokensEvent(this.address);
  @override
  List<Object?> get props => [address];
}

/// Load every wallet stored on device — UI uses this to render the swipeable
/// card list.
class LoadAllWalletsEvent extends WalletEvent {
  const LoadAllWalletsEvent();
}

/// Switch the app's active wallet.
class SwitchWalletEvent extends WalletEvent {
  final String walletId;
  const SwitchWalletEvent(this.walletId);
  @override
  List<Object?> get props => [walletId];
}

class AddWalletEvent extends WalletEvent {
  final String mnemonic;
  final String? name;
  const AddWalletEvent(this.mnemonic, {this.name});
  @override
  List<Object?> get props => [mnemonic, name];
}

class RemoveWalletEvent extends WalletEvent {
  final String walletId;
  const RemoveWalletEvent(this.walletId);
  @override
  List<Object?> get props => [walletId];
}

class UpdateWalletNameEvent extends WalletEvent {
  final String name;
  const UpdateWalletNameEvent(this.name);
  @override
  List<Object?> get props => [name];
}

class UpdateCardBackgroundEvent extends WalletEvent {
  final String cardFileName;
  const UpdateCardBackgroundEvent(this.cardFileName);
  @override
  List<Object?> get props => [cardFileName];
}

/// Event to load wallet customization (name + card) from storage
class LoadWalletCustomizationEvent extends WalletEvent {
  const LoadWalletCustomizationEvent();
}

/// Event to send SOL to another address A Solana Pay URL was scanned.
class ResolvePayEvent extends WalletEvent {
  final String url;

  const ResolvePayEvent(this.url);

  @override
  List<Object?> get props => [url];
}

/// Approve the payment that ResolvePayEvent prepared.
class ExecutePayEvent extends WalletEvent {
  const ExecutePayEvent();
}

/// Simulate a pending SPL token send.
class PreviewTokenSendEvent extends WalletEvent {
  final String mint;
  final String recipientAddress;
  final double amount;

  const PreviewTokenSendEvent({
    required this.mint,
    required this.recipientAddress,
    required this.amount,
  });

  @override
  List<Object?> get props => [mint, recipientAddress, amount];
}

class SendTokenEvent extends WalletEvent {
  final String mint;
  final String symbol;
  final String recipientAddress;
  final double amount;

  const SendTokenEvent({
    required this.mint,
    required this.symbol,
    required this.recipientAddress,
    required this.amount,
  });

  @override
  List<Object?> get props => [mint, symbol, recipientAddress, amount];
}

/// Simulate a pending send so the approval sheet can show what it does.
class PreviewSendEvent extends WalletEvent {
  final String recipientAddress;
  final double amountInSol;

  const PreviewSendEvent({
    required this.recipientAddress,
    required this.amountInSol,
  });

  @override
  List<Object?> get props => [recipientAddress, amountInSol];
}

class SendSolEvent extends WalletEvent {
  final String recipientAddress;
  final double amountInSol;

  const SendSolEvent({
    required this.recipientAddress,
    required this.amountInSol,
  });

  @override
  List<Object?> get props => [recipientAddress, amountInSol];
}
