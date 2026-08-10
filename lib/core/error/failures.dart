/// Base failure class for the app.
/// All domain-level errors extend this.
///
/// `implements Exception` because these are thrown. Without it they are
/// neither an Exception nor an Error, so any `on Exception catch` upstream
/// would miss every storage and wallet-creation failure in the app — and the
/// only reason nothing broke was that every call site used a bare `catch (e)`
/// and relied on toString() happening to return the message.
abstract class Failure implements Exception {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Failure during wallet creation (mnemonic generation, key derivation, etc.)
class WalletCreationFailure extends Failure {
  const WalletCreationFailure(super.message);
}

/// Failure when reading/writing to secure storage.
class StorageFailure extends Failure {
  const StorageFailure(super.message);
}
