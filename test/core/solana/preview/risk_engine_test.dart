import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/preview/instruction_decoder.dart';
import 'package:solfare/core/solana/preview/risk_engine.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';

void main() {
  const risk = RiskEngine();
  const me = '8xTf7ZLvBqCzHZWmnGL7CxHRWZqL3qYzTNy1MEwSc2Ke';

  DecodedInstruction ix(
    String kind, {
    Map<String, String> fields = const {},
    String? programName = 'Token Program',
    String programId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
  }) =>
      DecodedInstruction(
        index: 0, programId: programId, programName: programName,
        kind: kind, summary: kind, fields: fields,
      );

  BalanceDelta sol(int delta, {int? post, bool own = true}) => BalanceDelta(
        mint: null, owner: own ? me : 'other', rawDelta: delta,
        decimals: 9, symbol: 'SOL', isOwnAccount: own, postRaw: post,
      );

  BalanceDelta token(int delta, {String mint = 'MintAAA', bool own = true}) => BalanceDelta(
        mint: mint, owner: own ? me : 'other', rawDelta: delta,
        decimals: 6, symbol: 'USDC', isOwnAccount: own,
      );

  bool has(List<RiskFlag> flags, RiskSeverity s, String titlePart) =>
      flags.any((f) => f.severity == s && f.title.toLowerCase().contains(titlePart.toLowerCase()));

  group('approvals', () {
    test('an unlimited approval is danger', () {
      final flags = risk.evaluate(
        instructions: [ix('approve', fields: {'amount': InstructionDecoder.unlimitedAmount})],
        deltas: const [],
      );
      expect(has(flags, RiskSeverity.danger, 'unlimited'), isTrue);
    });

    test('a bounded approval is caution, not danger', () {
      final flags = risk.evaluate(
        instructions: [ix('approve', fields: {'amount': '1000'})],
        deltas: const [],
      );
      expect(has(flags, RiskSeverity.caution, 'spending approval'), isTrue);
      expect(flags.any((f) => f.severity == RiskSeverity.danger), isFalse);
    });
  });

  group('authority', () {
    test('setAuthority is danger', () {
      final flags = risk.evaluate(instructions: [ix('setAuthority')], deltas: const []);
      expect(has(flags, RiskSeverity.danger, 'ownership'), isTrue);
    });

    test('assign is danger', () {
      final flags = risk.evaluate(
        instructions: [ix('assign', programName: 'System Program')],
        deltas: const [],
      );
      expect(has(flags, RiskSeverity.danger, 'another program'), isTrue);
    });
  });

  group('native balance', () {
    test('spending below the rent-exempt floor is danger', () {
      final flags = risk.evaluate(
        instructions: const [],
        deltas: [sol(-2000000000, post: 1000)],
      );
      expect(has(flags, RiskSeverity.danger, 'empties your SOL'), isTrue);
    });

    test('a normal send that leaves a balance raises nothing', () {
      final flags = risk.evaluate(
        instructions: const [],
        deltas: [sol(-500000000, post: 1500000000)],
      );
      expect(flags, isEmpty);
    });

    test('another wallet being emptied is not our problem', () {
      final flags = risk.evaluate(
        instructions: const [],
        deltas: [sol(-2000000000, post: 0, own: false)],
      );
      expect(flags, isEmpty);
    });
  });

  group('one-way transfers', () {
    test('a send the user composed is not flagged', () {
      // They typed the amount and the recipient. "Nothing comes back"
      // describes what they asked for, and firing on every send is how
      // warnings get ignored.
      final flags = risk.evaluate(instructions: const [], deltas: [token(-5000000)]);
      expect(has(flags, RiskSeverity.caution, 'nothing comes back'), isFalse);
    });

    test('the same shape from a dapp is a caution', () {
      final flags = risk.evaluate(
        instructions: const [],
        deltas: [token(-5000000)],
        userInitiated: false,
      );
      expect(has(flags, RiskSeverity.caution, 'nothing comes back'), isTrue);
    });

    test('a swap, where something comes back, is not flagged', () {
      final flags = risk.evaluate(
        instructions: const [],
        deltas: [token(-5000000), token(2000000, mint: 'MintBBB')],
        userInitiated: false,
      );
      expect(has(flags, RiskSeverity.caution, 'nothing comes back'), isFalse);
    });
  });

  group('unknown programs', () {
    test('an unrecognised program is flagged once per program', () {
      final unknown = ix('unknown', programName: null, programId: 'SomeUnknownProgram11111');
      final flags = risk.evaluate(instructions: [unknown, unknown], deltas: const []);
      final unknownFlags = flags.where((f) => f.title.contains('program')).toList();
      expect(unknownFlags.length, 1);
    });

    test('a program used before reads differently to a brand new one', () {
      const id = 'SomeUnknownProgram11111';
      final first = risk.evaluate(
        instructions: [ix('unknown', programName: null, programId: id)],
        deltas: const [],
      );
      final again = risk.evaluate(
        instructions: [ix('unknown', programName: null, programId: id)],
        deltas: const [],
        previouslyUsedPrograms: const {id},
      );
      expect(first.first.title, contains('First time'));
      expect(again.first.title, contains('Unrecognised'));
    });

    test('compute budget instructions never count as unknown', () {
      final flags = risk.evaluate(
        instructions: [
          ix('setComputeUnitLimit',
              programName: null, programId: 'ComputeBudget111111111111111111111111111111'),
        ],
        deltas: const [],
      );
      expect(flags, isEmpty);
    });
  });

  group('presentation', () {
    test('flags come back worst-first', () {
      final flags = risk.evaluate(
        instructions: [
          ix('closeAccount'),
          ix('setAuthority'),
        ],
        deltas: const [],
        willFail: true,
      );
      expect(flags.first.severity, RiskSeverity.danger);
    });

    test('a failing simulation says the fee is still charged', () {
      final flags = risk.evaluate(instructions: const [], deltas: const [], willFail: true);
      expect(has(flags, RiskSeverity.caution, 'would fail'), isTrue);
      expect(flags.first.detail, contains('fee'));
    });

    test('undecodable instructions are admitted, not hidden', () {
      final flags = risk.evaluate(
        instructions: const [], deltas: const [], instructionsUnavailable: true,
      );
      expect(has(flags, RiskSeverity.caution, 'could not be read'), isTrue);
    });

    test('a plain send raises nothing at all', () {
      final flags = risk.evaluate(
        instructions: [ix('transfer', programName: 'System Program', fields: {'lamports': '500'})],
        deltas: [sol(-500, post: 1000000000), sol(500, own: false)],
      );
      expect(flags, isEmpty, reason: 'warning on every send trains people to ignore warnings');
    });
  });
}
