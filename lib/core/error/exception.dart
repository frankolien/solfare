/// Base exception for local data source operations.
class LocalStorageException implements Exception {
  final String message;
  const LocalStorageException(this.message);

  @override
  String toString() => 'LocalStorageException: $message';
}

/// Exception thrown when wallet key derivation fails.
class KeyDerivationException implements Exception {
  final String message;
  const KeyDerivationException(this.message);

  @override
  String toString() => 'KeyDerivationException: $message';
}
