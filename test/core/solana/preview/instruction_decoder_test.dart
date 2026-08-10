import 'package:flutter_test/flutter_test.dart';
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/solana/preview/instruction_decoder.dart';
import 'package:solfare/core/solana/preview/program_registry.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';

void main() {
  // Instructions are built with the solana package's own factories, so the
  // test asserts against the real wire layout rather than bytes we invented.
  const decoder = InstructionDecoder(network: SolanaNetwork.mainnet);

  final alice = solana.Ed25519HDPublicKey.fromBase58(
      '8xTf7ZLvBqCzHZWmnGL7CxHRWZqL3qYzTNy1MEwSc2Ke');
  final bob = solana.Ed25519HDPublicKey.fromBase58(
      'CRVideKGnbHTPWLWTJz8mrKGVn7oCVaFHPFhpqJT6Ah');
  final mint = solana.Ed25519HDPublicKey.fromBase58(
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');

  group('system program', () {
    test('decodes a lamport transfer with its amount', () {
      final ix = solana.SystemInstruction.transfer(
        fundingAccount: alice,
        recipientAccount: bob,
        lamports: 500000000,
      );

      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.kind, 'transfer');
      expect(d.programName, 'System Program');
      expect(d.fields['lamports'], '500000000');
      expect(d.fields['destination'], bob.toBase58());
      expect(d.summary, contains('0.5'));
    });
  });

  group('token program', () {
    test('decodes transferChecked with amount and decimals', () {
      final ix = solana.TokenInstruction.transferChecked(
        amount: 1500000,
        decimals: 6,
        source: alice,
        destination: bob,
        owner: alice,
        mint: mint,
      );

      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.kind, 'transferChecked');
      expect(d.fields['amount'], '1500000');
      expect(d.fields['decimals'], '6');
    });

    test('flags an unlimited approval by its amount', () {
      // u64 max is what "approve everything" looks like on the wire. Dart
      // ints are signed, so the literal has to be written as its bit pattern.
      final ix = solana.TokenInstruction.approve(
        amount: 0xFFFFFFFFFFFFFFFF,
        source: alice,
        delegate: bob,
        sourceOwner: alice,
      );

      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.kind, 'approve');
      expect(d.fields['amount'], InstructionDecoder.unlimitedAmount);
      expect(d.summary, contains('unlimited'));
    });

    test('a bounded approval does not read as unlimited', () {
      final ix = solana.TokenInstruction.approve(
        amount: 1000,
        source: alice,
        delegate: bob,
        sourceOwner: alice,
      );

      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.fields['amount'], '1000');
      expect(d.summary, isNot(contains('unlimited')));
    });

    test('decodes setAuthority', () {
      final ix = solana.TokenInstruction.setAuthority(
        authorityType: solana.AuthorityType.closeAccount,
        mintOrAccount: alice,
        currentAuthority: alice,
        newAuthority: bob,
      );

      expect(decoder.decode(RawInstruction.from(ix), 0).kind, 'setAuthority');
    });

    test('decodes closeAccount', () {
      final ix = solana.TokenInstruction.closeAccount(
        accountToClose: alice,
        destination: bob,
        owner: alice,
      );

      final d = decoder.decode(RawInstruction.from(ix), 0);
      expect(d.kind, 'closeAccount');
      expect(d.fields['destination'], bob.toBase58());
    });
  });

  group('compute budget', () {
    test('reads back the unit limit', () {
      final ix = solana.ComputeBudgetInstruction.setComputeUnitLimit(units: 200000);
      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.kind, 'setComputeUnitLimit');
      expect(d.fields['units'], '200000');
      expect(d.isNoise, isTrue, reason: 'budget instructions are ours, not user intent');
    });

    test('reads back the priority price', () {
      final ix = solana.ComputeBudgetInstruction.setComputeUnitPrice(microLamports: 12345);
      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.kind, 'setComputeUnitPrice');
      expect(d.fields['microLamports'], '12345');
    });
  });

  group('memo', () {
    test('keeps the text but does not present it as authority', () {
      final ix = solana.MemoInstruction(signers: [alice], memo: 'Order #1847');
      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.kind, 'memo');
      expect(d.fields['memo'], 'Order #1847');
      // The summary must not quote attacker-controlled text as a claim.
      expect(d.summary, 'Attaches a note');
    });
  });

  group('unknown programs', () {
    final unknownProgram = solana.Ed25519HDPublicKey.fromBase58(
        'Stake11111111111111111111111111111111111112');

    test('never invents a name', () {
      final ix = encoder.Instruction(
        programId: unknownProgram,
        accounts: const [],
        data: encoder.ByteArray(const [9, 9, 9]),
      );

      final d = decoder.decode(RawInstruction.from(ix), 0);

      expect(d.programName, isNull);
      expect(d.isKnownProgram, isFalse);
      expect(d.kind, DecodedInstruction.unknownKind);
      expect(d.summary, contains('unrecognised'));
      expect(d.fields['program'], unknownProgram.toBase58());
    });
  });

  group('program registry', () {
    test('runtime programs resolve on every cluster', () {
      for (final network in SolanaNetwork.values) {
        expect(
          ProgramRegistry.nameFor('11111111111111111111111111111111', network: network),
          'System Program',
        );
      }
    });

    test('a mainnet-only protocol is not named on devnet', () {
      const jupiter = 'JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4';

      expect(ProgramRegistry.nameFor(jupiter, network: SolanaNetwork.mainnet),
          'Jupiter Aggregator');
      expect(ProgramRegistry.nameFor(jupiter, network: SolanaNetwork.devnet), isNull);
    });

    test('registry has no duplicate addresses', () {
      final ids = ProgramRegistry.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('decodeAll', () {
    test('preserves order and indexes each instruction', () {
      final ixs = [
        solana.ComputeBudgetInstruction.setComputeUnitLimit(units: 1000),
        solana.SystemInstruction.transfer(
            fundingAccount: alice, recipientAccount: bob, lamports: 1),
      ];

      final decoded = decoder.decodeAll(ixs);

      expect(decoded.map((d) => d.index), [0, 1]);
      expect(decoded.map((d) => d.kind), ['setComputeUnitLimit', 'transfer']);
    });
  });
}
