import 'package:equatable/equatable.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';

/// Events that can be dispatched to WalletBloc
/// Events represent user actions or system triggers
abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

/// Event to create a new wallet
class CreateWalletEvent extends WalletEvent {
  const CreateWalletEvent();
}

/// Internal event dispatched when the active Solana cluster changes.
/// The handler clears cluster-scoped caches (tokens, NFTs) so the UI
/// doesn't flash stale holdings from the previous network, then
/// triggers a refetch.
class NetworkChangedEvent extends WalletEvent {
  const NetworkChangedEvent();
}

/// Event to save a wallet to secure storage
class SaveWalletEvent extends WalletEvent {
  final Wallet wallet;

  const SaveWalletEvent(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

/// Event to check if a wallet exists
class CheckWalletExistsEvent extends WalletEvent {
  const CheckWalletExistsEvent();
}

/// Event to request airdrop (devnet/testnet only)
class RequestAirdropEvent extends WalletEvent {
  final String address;
  final int lamports; // Amount in lamports (default: 1 SOL = 1,000,000,000)

  const RequestAirdropEvent({
    required this.address,
    this.lamports = 1000000000, // 1 SOL
  });

  @override
  List<Object?> get props => [address, lamports];
}

/// Event to fetch wallet balance
class FetchBalanceEvent extends WalletEvent {
  final String address;

  const FetchBalanceEvent(this.address);

  @override
  List<Object?> get props => [address];
}

/// Event to reset wallet state
class ResetWalletEvent extends WalletEvent {
  const ResetWalletEvent();
}

/// Event to clear all wallet data from storage
class ClearWalletEvent extends WalletEvent {
  const ClearWalletEvent();
}

/// Event to fetch SOL price
class FetchSolPriceEvent extends WalletEvent {
  const FetchSolPriceEvent();
}

/// Live ticker push from BinancePriceWsService. Carries already-parsed
/// values so the bloc handler is pure state mutation.
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

/// Event to fetch transaction history
class FetchTransactionsEvent extends WalletEvent {
  final String address;

  const FetchTransactionsEvent(this.address);

  @override
  List<Object?> get props => [address];
}

/// Event to fetch NFTs for a wallet address
class FetchNftsEvent extends WalletEvent {
  final String address;
  const FetchNftsEvent(this.address);
  @override
  List<Object?> get props => [address];
}

/// Event to fetch SPL tokens for a wallet address
class FetchTokensEvent extends WalletEvent {
  final String address;
  const FetchTokensEvent(this.address);
  @override
  List<Object?> get props => [address];
}

// ── Multi-wallet events ────────────────────────────────────────────────────

/// Load every wallet stored on device — UI uses this to render the
/// swipeable card list.
class LoadAllWalletsEvent extends WalletEvent {
  const LoadAllWalletsEvent();
}

/// Switch the app's active wallet. Emits [WalletAddressLoaded] with the new
/// address so every subscriber refetches against it.
class SwitchWalletEvent extends WalletEvent {
  final String walletId;
  const SwitchWalletEvent(this.walletId);
  @override
  List<Object?> get props => [walletId];
}

/// Add a wallet from a mnemonic. Used by the Import flow and by creating a
/// second wallet from inside the app.
class AddWalletEvent extends WalletEvent {
  final String mnemonic;
  final String? name;
  const AddWalletEvent(this.mnemonic, {this.name});
  @override
  List<Object?> get props => [mnemonic, name];
}

/// Remove a wallet by id. Active selection automatically falls back to the
/// first remaining wallet.
class RemoveWalletEvent extends WalletEvent {
  final String walletId;
  const RemoveWalletEvent(this.walletId);
  @override
  List<Object?> get props => [walletId];
}

/// Event to update wallet display name
class UpdateWalletNameEvent extends WalletEvent {
  final String name;
  const UpdateWalletNameEvent(this.name);
  @override
  List<Object?> get props => [name];
}

/// Event to update wallet card background
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

/// Event to send SOL to another address
/// Simulate a pending SPL token send. [amount] is in display units; the
/// mint's decimals turn it into base units.
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
/// Read-only — nothing is signed or broadcast.
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
