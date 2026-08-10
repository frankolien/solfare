import 'package:solfare/core/solana/lamports.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:solana/encoder.dart' as encoder;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/solana/preview/program_registry.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';

/// An instruction reduced to the three things the decoder reads.
///
/// Exists so instructions can be decoded straight out of a compiled message
/// with the account indices resolved against the simulation's key list. The
/// old path went through `decompileMessage()`, which needs the actual address
/// lookup table accounts and throws without them — so every v0 transaction
/// that used a table decoded to nothing at all.
class RawInstruction {
  final String programId;
  final Uint8List data;
  final List<String> accounts;

  const RawInstruction({
    required this.programId,
    required this.data,
    required this.accounts,
  });

  RawInstruction.from(encoder.Instruction ix)
      : programId = ix.programId.toBase58(),
        data = Uint8List.fromList(ix.data.toList()),
        accounts = [for (final a in ix.accounts) a.pubKey.toBase58()];
}

/// Turns raw instructions into readable summaries.
///
/// The one rule: never invent a name for something we do not recognise.
/// "Unknown program" is a fact the user can act on; a guessed label is a
/// lie a drainer can hide behind.
class InstructionDecoder {
  final SolanaNetwork? network;

  const InstructionDecoder({this.network});

  static const _systemProgram = '11111111111111111111111111111111';
  static const _tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const _token2022Program = 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';
  static const _ataProgram = 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';
  static const _computeBudgetProgram = 'ComputeBudget111111111111111111111111111111';
  static const _stakeProgram = 'Stake11111111111111111111111111111111111111';
  static const _memoProgram = 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr';
  static const _memoV1Program = 'Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo';

  /// u64 max — the amount an "unlimited" approval carries.
  static const String unlimitedAmount = '18446744073709551615';

  List<DecodedInstruction> decodeAll(List<encoder.Instruction> instructions) =>
      decodeRaw([for (final ix in instructions) RawInstruction.from(ix)]);

  List<DecodedInstruction> decodeRaw(List<RawInstruction> instructions) => [
        for (var i = 0; i < instructions.length; i++) decode(instructions[i], i),
      ];

  DecodedInstruction decode(RawInstruction ix, int index) {
    final programId = ix.programId;
    final name = ProgramRegistry.nameFor(programId, network: network);
    final data = ix.data;
    final accounts = ix.accounts;

    switch (programId) {
      case _systemProgram:
        return _system(index, programId, name, data, accounts);
      case _tokenProgram:
      case _token2022Program:
        return _token(index, programId, name, data, accounts,
            isToken2022: programId == _token2022Program);
      case _ataProgram:
        return _ata(index, programId, name, data, accounts);
      case _computeBudgetProgram:
        return _computeBudget(index, programId, name, data);
      case _stakeProgram:
        return _stake(index, programId, name, data, accounts);
      case _memoProgram:
      case _memoV1Program:
        return _memo(index, programId, name, data);
      default:
        return DecodedInstruction(
          index: index,
          programId: programId,
          programName: name,
          kind: DecodedInstruction.unknownKind,
          summary: name == null
              ? 'Calls an unrecognised program'
              : 'Calls $name',
          fields: {'program': programId},
        );
    }
  }

  // ── System ──

  DecodedInstruction _system(
      int index, String programId, String? name, Uint8List data, List<String> accounts) {
    // System instructions are tagged with a little-endian u32.
    final tag = _u32(data, 0);
    DecodedInstruction make(String kind, String summary, [Map<String, String> fields = const {}]) =>
        DecodedInstruction(
            index: index, programId: programId, programName: name,
            kind: kind, summary: summary, fields: fields);

    switch (tag) {
      case 0:
        final lamports = _u64(data, 4);
        return make('createAccount', 'Create an account funded with ${_sol(lamports)} SOL', {
          'lamports': '$lamports',
          if (accounts.length > 1) 'newAccount': accounts[1],
        });
      case 1:
        return make('assign', 'Hand this account to another program', {
          if (accounts.isNotEmpty) 'account': accounts[0],
        });
      case 2:
        final lamports = _u64(data, 4);
        return make('transfer', 'Send ${_sol(lamports)} SOL', {
          'lamports': '$lamports',
          if (accounts.length > 1) 'destination': accounts[1],
        });
      case 8:
        return make('allocate', 'Allocate account space');
      case 11:
        final lamports = _u64(data, 4);
        return make('transferWithSeed', 'Send ${_sol(lamports)} SOL', {'lamports': '$lamports'});
      default:
        return make(DecodedInstruction.unknownKind, 'System Program instruction #$tag');
    }
  }

  // ── Token / Token-2022 ──

  DecodedInstruction _token(
    int index,
    String programId,
    String? name,
    Uint8List data,
    List<String> accounts, {
    required bool isToken2022,
  }) {
    // Token instructions are tagged with a single byte.
    final tag = data.isEmpty ? -1 : data[0];
    DecodedInstruction make(String kind, String summary, [Map<String, String> fields = const {}]) =>
        DecodedInstruction(
            index: index, programId: programId, programName: name,
            kind: kind, summary: summary,
            fields: {...fields, if (isToken2022) 'tokenProgram': 'Token-2022'});

    switch (tag) {
      case 3:
        return make('transfer', 'Transfer tokens', {
          'amount': _u64Str(data, 1),
          if (accounts.length > 1) 'destination': accounts[1],
        });
      case 4:
        final amount = _u64Str(data, 1);
        return make('approve', _approveSummary(amount), {
          'amount': amount,
          if (accounts.length > 1) 'delegate': accounts[1],
        });
      case 5:
        return make('revoke', 'Remove a token delegate');
      case 6:
        // authorityType u8, then an optional COption<Pubkey>.
        final authorityType = data.length > 1 ? data[1] : -1;
        return make('setAuthority', 'Change who controls this token account', {
          'authorityType': '$authorityType',
        });
      case 7:
        return make('mintTo', 'Mint tokens', {'amount': _u64Str(data, 1)});
      case 8:
        return make('burn', 'Burn tokens', {'amount': _u64Str(data, 1)});
      case 9:
        return make('closeAccount', 'Close a token account and reclaim its rent', {
          if (accounts.length > 1) 'destination': accounts[1],
        });
      case 10:
        return make('freezeAccount', 'Freeze a token account');
      case 11:
        return make('thawAccount', 'Unfreeze a token account');
      case 12:
        return make('transferChecked', 'Transfer tokens', {
          'amount': _u64Str(data, 1),
          'decimals': '${data.length > 9 ? data[9] : 0}',
          if (accounts.length > 2) 'destination': accounts[2],
          if (accounts.isNotEmpty) 'mint': accounts[1 <= accounts.length - 1 ? 1 : 0],
        });
      case 13:
        final amount = _u64Str(data, 1);
        return make('approveChecked', _approveSummary(amount), {
          'amount': amount,
          if (accounts.length > 2) 'delegate': accounts[2],
        });
      case 14:
        return make('mintToChecked', 'Mint tokens', {'amount': _u64Str(data, 1)});
      case 15:
        return make('burnChecked', 'Burn tokens', {'amount': _u64Str(data, 1)});
      default:
        return make(DecodedInstruction.unknownKind, 'Token instruction #$tag');
    }
  }

  String _approveSummary(String amount) => isEffectivelyUnlimited(amount)
      ? 'Grant unlimited spending of a token'
      : 'Grant spending of a token';

  /// Whether an approval amount may as well be unlimited.
  ///
  /// Comparing against u64 max exactly is a check a drainer clears by
  /// subtracting one: `u64::MAX - 1` is still about 1.8e13 of any token with
  /// six decimals, and it used to render as an ordinary orange "Spending
  /// approval". The threshold is 2^63, which no honest approval reaches —
  /// the entire supply of every real SPL token is orders of magnitude below
  /// it — and which no amount of arithmetic can slip under while still
  /// draining anyone.
  static bool isEffectivelyUnlimited(String? amount) {
    if (amount == null) return false;
    final value = BigInt.tryParse(amount);
    if (value == null) return false;
    return value >= BigInt.two.pow(63);
  }

  // ── Associated Token Account ──

  DecodedInstruction _ata(
      int index, String programId, String? name, Uint8List data, List<String> accounts) {
    // Empty data is the original create; later versions tag with one byte.
    final tag = data.isEmpty ? 0 : data[0];
    final kind = switch (tag) {
      1 => 'createIdempotent',
      2 => 'recoverNested',
      _ => 'createAssociatedTokenAccount',
    };
    return DecodedInstruction(
      index: index, programId: programId, programName: name, kind: kind,
      summary: tag == 2
          ? 'Recover a nested token account'
          : 'Create a token account (costs rent)',
      fields: {if (accounts.length > 1) 'account': accounts[1]},
    );
  }

  // ── Compute budget ──

  DecodedInstruction _computeBudget(int index, String programId, String? name, Uint8List data) {
    final tag = data.isEmpty ? -1 : data[0];
    final (kind, summary, fields) = switch (tag) {
      2 => ('setComputeUnitLimit', 'Set compute unit limit',
          {'units': '${_u32(data, 1)}'}),
      3 => ('setComputeUnitPrice', 'Set priority fee',
          {'microLamports': _u64Str(data, 1)}),
      1 => ('requestHeapFrame', 'Request heap', <String, String>{}),
      4 => ('setLoadedAccountsDataSizeLimit', 'Set data size limit', <String, String>{}),
      _ => (DecodedInstruction.unknownKind, 'Compute budget instruction', <String, String>{}),
    };
    return DecodedInstruction(
      index: index, programId: programId, programName: name,
      kind: kind, summary: summary, fields: fields,
    );
  }

  // ── Stake ──

  DecodedInstruction _stake(
      int index, String programId, String? name, Uint8List data, List<String> accounts) {
    final tag = _u32(data, 0);
    final (kind, summary) = switch (tag) {
      0 => ('initializeStake', 'Initialise a stake account'),
      1 => ('authorizeStake', 'Change who controls a stake account'),
      2 => ('delegateStake', 'Delegate stake to a validator'),
      3 => ('splitStake', 'Split a stake account'),
      4 => ('withdrawStake', 'Withdraw ${_sol(_u64(data, 4))} SOL from staking'),
      5 => ('deactivateStake', 'Begin unstaking'),
      7 => ('mergeStake', 'Merge stake accounts'),
      _ => (DecodedInstruction.unknownKind, 'Stake instruction #$tag'),
    };
    return DecodedInstruction(
      index: index, programId: programId, programName: name,
      kind: kind, summary: summary,
      fields: {if (accounts.isNotEmpty) 'stakeAccount': accounts[0]},
    );
  }

  // ── Memo ──

  DecodedInstruction _memo(int index, String programId, String? name, Uint8List data) {
    String memo;
    try {
      memo = utf8.decode(data);
    } catch (_) {
      // Memos are arbitrary bytes; a program can write something undecodable.
      memo = '<${data.length} bytes>';
    }
    return DecodedInstruction(
      index: index, programId: programId, programName: name,
      kind: 'memo',
      // Shown verbatim and never trusted — this is attacker-controlled text.
      summary: 'Attaches a note',
      fields: {'memo': memo},
    );
  }

  // ── byte helpers ──

  int _u32(Uint8List data, int offset) {
    if (data.length < offset + 4) return -1;
    return ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.little);
  }

  int _u64(Uint8List data, int offset) {
    if (data.length < offset + 8) return 0;
    return ByteData.sublistView(data, offset, offset + 8).getUint64(0, Endian.little);
  }

  /// Dart ints are signed, so a u64 at or above 2^63 comes back negative —
  /// u64 max reads as -1. Token amounts reach exactly that range, and an
  /// unlimited approval is the case that matters most, so amounts are carried
  /// as their unsigned decimal string.
  String _u64Str(Uint8List data, int offset) =>
      BigInt.from(_u64(data, offset)).toUnsigned(64).toString();

  String _sol(int lamports) {
    final sol = Lamports.toSol(lamports);
    if (sol == 0) return '0';
    if (sol < 0.000001) return sol.toStringAsExponential(2);
    var s = sol.toStringAsFixed(9);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }
}
