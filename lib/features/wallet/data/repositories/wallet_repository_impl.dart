import 'package:solfare/core/error/exception.dart';
import 'package:solfare/core/error/failures.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_local_datasource.dart';
import 'package:solfare/features/wallet/data/model/wallet_model.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';
import 'package:solfare/features/wallet/domain/repositories/wallet_repository.dart';

/// Concrete implementation of [WalletRepository].
/// Bridges the domain layer with the local data source.
class WalletRepositoryImpl implements WalletRepository {
  final WalletLocalDataSource _localDataSource;

  WalletRepositoryImpl({required WalletLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  @override
  Future<Wallet> createWallet() async {
    try {
      return await _localDataSource.createWallet();
    } on KeyDerivationException catch (e) {
      throw WalletCreationFailure(e.message);
    }
  }

  @override
  Future<Wallet> importWallet(String mnemonic) async {
    try {
      return await _localDataSource.deriveWallet(mnemonic);
    } on KeyDerivationException catch (e) {
      throw WalletCreationFailure(e.message);
    }
  }

  @override
  Future<void> saveWallet(Wallet wallet) async {
    try {
      final model = WalletModel(
        address: wallet.address,
        publicKey: wallet.publicKey,
        mnemonic: wallet.mnemonic,
      );
      await _localDataSource.saveWallet(model);
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<bool> hasWallet() async {
    try {
      return await _localDataSource.hasWallet();
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<String?> getSavedAddress() async {
    try {
      return await _localDataSource.getSavedAddress();
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<void> clearWallet() async {
    try {
      await _localDataSource.clearWallet();
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }
  
  @override
  Future<String?> getStoredMnemonic() async {
    try {
      return await _localDataSource.getStoredMnemonic();
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<List<WalletAccount>> getAllWallets() async {
    try {
      return await _localDataSource.getAllWallets();
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<WalletAccount?> getActiveWallet() async {
    try {
      return await _localDataSource.getActiveWallet();
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<void> setActiveWalletId(String id) async {
    try {
      await _localDataSource.setActiveWalletId(id);
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<WalletAccount> addWallet(String mnemonic, {String? name}) async {
    try {
      return await _localDataSource.addWallet(mnemonic, name: name);
    } on KeyDerivationException catch (e) {
      throw WalletCreationFailure(e.message);
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<void> removeWallet(String id) async {
    try {
      await _localDataSource.removeWallet(id);
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<void> renameWallet(String id, String name) async {
    try {
      await _localDataSource.renameWallet(id, name);
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }

  @override
  Future<void> setWalletCardBackground(String id, String cardBackground) async {
    try {
      await _localDataSource.setWalletCardBackground(id, cardBackground);
    } on LocalStorageException catch (e) {
      throw StorageFailure(e.message);
    }
  }
}
