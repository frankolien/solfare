import 'package:bip39/bip39.dart' as bip39;
import 'package:bloc/bloc.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/rpc/dto/account_data/stake_program/authorized.dart';
import 'package:solana/src/rpc/dto/latest_blockhash.dart';
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/features/staking/domain/entities/stake_account.dart';
import 'package:solfare/features/staking/domain/entities/validator_info.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_event.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_local_datasource.dart';

class StakingBloc extends Bloc<StakingEvent, StakingState> {
  final SolanaRpcDataSource _rpcDataSource;
  final WalletRepositoryImpl _repository;

  StakingBloc({
    SolanaRpcDataSource? rpcDataSource,
    WalletRepositoryImpl? repository,
  })  : _rpcDataSource = rpcDataSource ?? SolanaRpcDataSourceImpl(),
        _repository = repository ??
            WalletRepositoryImpl(
              localDataSource: WalletLocalDataSourceImpl(),
            ),
        super(const StakingInitial()) {
    on<FetchStakeAccountsEvent>(_onFetchStakeAccounts);
    on<FetchValidatorsEvent>(_onFetchValidators);
    on<DelegateStakeEvent>(_onDelegateStake);
    on<DeactivateStakeEvent>(_onDeactivateStake);
    on<WithdrawStakeEvent>(_onWithdrawStake);
  }

  Future<void> _onFetchStakeAccounts(
    FetchStakeAccountsEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakingLoading());
    try {
      final raw = await _rpcDataSource.getStakeAccounts(event.walletAddress);
      final accounts = raw.map((a) => StakeAccount(
            pubkey: a['pubkey'] as String,
            lamports: a['lamports'] as int,
            voterPubkey: a['voterPubkey'] as String?,
            state: _determineState(
              a['activationEpoch'] as int,
              a['deactivationEpoch'] as int,
            ),
            activationEpoch: a['activationEpoch'] as int,
            deactivationEpoch: a['deactivationEpoch'] as int,
          )).toList();
      emit(StakeAccountsFetched(accounts));
    } catch (e) {
      emit(StakingError(e.toString()));
    }
  }

  String _determineState(int activationEpoch, int deactivationEpoch) {
    // Max u64 means "not set"
    const maxEpoch = 9223372036854775807;
    if (deactivationEpoch != maxEpoch && deactivationEpoch != 0) {
      return 'deactivating';
    }
    if (activationEpoch == 0) return 'inactive';
    return 'activating';
  }

  Future<void> _onFetchValidators(
    FetchValidatorsEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakingLoading());
    try {
      final raw = await _rpcDataSource.getVoteAccounts();
      final validators = raw.map((v) => ValidatorInfo(
            votePubkey: v['votePubkey'] as String,
            name: _validatorName(v['votePubkey'] as String),
            activatedStake: v['activatedStake'] as int,
            commission: (v['commission'] as int).toDouble(),
          )).toList();
      // Sort by stake descending
      validators.sort((a, b) => b.activatedStake.compareTo(a.activatedStake));
      emit(ValidatorsFetched(validators));
    } catch (e) {
      emit(StakingError(e.toString()));
    }
  }

  /// Well-known devnet/mainnet validators get friendly names
  String _validatorName(String votePubkey) {
    const knownValidators = {
      'CertusDeBmqN8ZawdkxK5kFGMwBXdudvWHYwtNgNhvLu': 'Certus One',
      'vgcDar2pryHvMgPkKaZfh8pQy4BJxv7SpwUG7zinWjG': 'Devnet Validator 1',
      '5ZWgXcyqrrNpQHCme5SdC5hCeYb2o3fEJhF7Gok3bTVN': 'Devnet Validator 2',
      'i7NyKBMJCA9bLM2nsGyAGCKHECuR2L5eh4GqFciuwNT': 'Devnet Validator 3',
      '23AoPQc3EPkfLWb14cKiWNahh1H9rtb3UBk8gWseohjF': 'Devnet Validator 4',
    };
    return knownValidators[votePubkey] ?? 'Validator ${votePubkey.substring(0, 4)}...${votePubkey.substring(votePubkey.length - 4)}';
  }

  Future<void> _onDelegateStake(
    DelegateStakeEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakeDelegating());
    try {
      // 1. Get mnemonic and derive keypair
      final mnemonic = await _repository.getStoredMnemonic();
      if (mnemonic == null) {
        throw Exception('No wallet found. Please create or import a wallet first.');
      }

      final seed = bip39.mnemonicToSeed(mnemonic);
      final keyData = await ED25519_HD_KEY.derivePath(
        SolanaPath.defaultPath,
        seed,
      );
      final senderKeyPair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: keyData.key,
      );

      // 2. Generate a new keypair for the stake account
      final stakeAccountKeyPair = await solana.Ed25519HDKeyPair.random();

      // 3. Calculate lamports
      final lamports = (event.amountInSol * 1000000000).toInt();

      // 4. Get rent exemption for stake account (200 bytes)
      final rentExemption = await _rpcDataSource.getMinimumBalanceForRentExemption(200);

      print('[StakingBloc] lamports=$lamports, rentExemption=$rentExemption, total=${lamports + rentExemption}');
      print('[StakingBloc] sender=${senderKeyPair.address}');
      print('[StakingBloc] stakeAccount=${stakeAccountKeyPair.address}');
      print('[StakingBloc] validator=${event.validatorVoteAccount}');

      // 5. Get recent blockhash
      final blockhashData = await _rpcDataSource.getLatestBlockhash();
      final latestBlockhash = LatestBlockhash(
        blockhash: blockhashData['blockhash'] as String,
        lastValidBlockHeight: blockhashData['lastValidBlockHeight'] as int,
      );

      // 6. Build all instructions: createAccount + initialize + delegateStake
      final createAndInitInstructions = solana.StakeInstruction.createAndInitializeAccount(
        fundingAccount: senderKeyPair.publicKey,
        newAccount: stakeAccountKeyPair.publicKey,
        authorized: Authorized(
          staker: senderKeyPair.address,
          withdrawer: senderKeyPair.address,
        ),
        lamports: lamports + rentExemption,
      );

      final delegateInstruction = solana.StakeInstruction.delegateStake(
        stake: stakeAccountKeyPair.publicKey,
        vote: solana.Ed25519HDPublicKey.fromBase58(event.validatorVoteAccount),
        config: solana.Ed25519HDPublicKey.fromBase58('StakeConfig11111111111111111111111111111111'),
        authority: senderKeyPair.publicKey,
      );

      // 7. Single transaction with all instructions
      final message = solana.Message(
        instructions: [...createAndInitInstructions, delegateInstruction],
      );

      // 8. Sign with both keys
      final signedTx = await solana.signTransaction(
        latestBlockhash,
        message,
        [senderKeyPair, stakeAccountKeyPair],
      );

      // 9. Send
      final signature = await _rpcDataSource.sendTransaction(signedTx.encode());

      print('[StakingBloc] DelegateStake SUCCESS: $signature');
      emit(StakeDelegated(
        signature: signature,
        amountInSol: event.amountInSol,
      ));
    } catch (e, stackTrace) {
      print('[StakingBloc] DelegateStake FAILED: $e');
      print('[StakingBloc] StackTrace: $stackTrace');
      emit(StakingError(e.toString()));
    }
  }

  /// Derive the wallet keypair from stored mnemonic
  Future<solana.Ed25519HDKeyPair> _deriveKeyPair() async {
    final mnemonic = await _repository.getStoredMnemonic();
    if (mnemonic == null) {
      throw Exception('No wallet found.');
    }
    final seed = bip39.mnemonicToSeed(mnemonic);
    final keyData = await ED25519_HD_KEY.derivePath(SolanaPath.defaultPath, seed);
    return solana.Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: keyData.key);
  }

  Future<void> _onDeactivateStake(
    DeactivateStakeEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakeDeactivating());
    try {
      final keyPair = await _deriveKeyPair();

      final blockhashData = await _rpcDataSource.getLatestBlockhash();
      final latestBlockhash = LatestBlockhash(
        blockhash: blockhashData['blockhash'] as String,
        lastValidBlockHeight: blockhashData['lastValidBlockHeight'] as int,
      );

      final instruction = solana.StakeInstruction.deactivate(
        stake: solana.Ed25519HDPublicKey.fromBase58(event.stakeAccountPubkey),
        authority: keyPair.publicKey,
      );

      final signedTx = await solana.signTransaction(
        latestBlockhash,
        solana.Message(instructions: [instruction]),
        [keyPair],
      );

      final signature = await _rpcDataSource.sendTransaction(signedTx.encode());
      emit(StakeDeactivated(signature: signature));
    } catch (e) {
      emit(StakingError(e.toString()));
    }
  }

  Future<void> _onWithdrawStake(
    WithdrawStakeEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakeWithdrawing());
    try {
      final keyPair = await _deriveKeyPair();

      final blockhashData = await _rpcDataSource.getLatestBlockhash();
      final latestBlockhash = LatestBlockhash(
        blockhash: blockhashData['blockhash'] as String,
        lastValidBlockHeight: blockhashData['lastValidBlockHeight'] as int,
      );

      final instruction = solana.StakeInstruction.withdraw(
        stake: solana.Ed25519HDPublicKey.fromBase58(event.stakeAccountPubkey),
        recipient: keyPair.publicKey,
        authority: keyPair.publicKey,
        lamports: event.lamports,
      );

      final signedTx = await solana.signTransaction(
        latestBlockhash,
        solana.Message(instructions: [instruction]),
        [keyPair],
      );

      final signature = await _rpcDataSource.sendTransaction(signedTx.encode());
      emit(StakeWithdrawn(signature: signature));
    } catch (e) {
      emit(StakingError(e.toString()));
    }
  }
}
