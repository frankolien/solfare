/// Base failure class for the app.
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
