/// Base exception for local data source operations.
class LocalStorageException implements Exception {
  final String message;
  const LocalStorageException(this.message);

  @override
  String toString() => 'LocalStorageException: $message';
}

/// The wallet blob is present but could not be read.
///
/// Distinct from "there are no wallets" on purpose. Collapsing the two sends
/// a user who owns a wallet to the create-a-wallet screen, and the first
/// thing that screen does is overwrite the blob nobody could read.
class CorruptWalletStoreException implements Exception {
  final String message;
  const CorruptWalletStoreException(this.message);

  @override
  String toString() => 'CorruptWalletStoreException: $message';
}

/// Exception thrown when wallet key derivation fails.
class KeyDerivationException implements Exception {
  final String message;
  const KeyDerivationException(this.message);

  @override
  String toString() => 'KeyDerivationException: $message';
}
