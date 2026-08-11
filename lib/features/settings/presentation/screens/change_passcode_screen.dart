import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solfare/core/security/passcode_change.dart';
import 'package:solfare/core/security/passcode_gate.dart';

enum _Stage { current, next, confirm }

class ChangePasscodeScreen extends StatefulWidget {
  const ChangePasscodeScreen({super.key});

  @override
  State<ChangePasscodeScreen> createState() => _ChangePasscodeScreenState();
}

class _ChangePasscodeScreenState extends State<ChangePasscodeScreen> {
  static const _length = 6;

  _Stage _stage = _Stage.current;
  String _entered = '';
  String _current = '';
  String _next = '';
  bool _busy = false;
  bool _wrong = false;

  String get _title => switch (_stage) {
        _Stage.current => 'Enter your current passcode',
        _Stage.next => 'Choose a new passcode',
        _Stage.confirm => 'Confirm your new passcode',
      };

  void _reset(_Stage to) => setState(() {
        _stage = to;
        _entered = '';
        _wrong = false;
      });

  Future<void> _onComplete() async {
    switch (_stage) {
      case _Stage.current:
        // Not verified here — that would be a second guessing surface outside
        // the rate limit. It is checked once, by the gate, on submission.
        _current = _entered;
        _reset(_Stage.next);

      case _Stage.next:
        if (_entered == _current) {
          _fail('That is your current passcode. Choose a different one.');
          _reset(_Stage.next);
          return;
        }
        _next = _entered;
        _reset(_Stage.confirm);

      case _Stage.confirm:
        if (_entered != _next) {
          _fail('Those did not match. Try again.');
          _reset(_Stage.next);
          return;
        }
        await _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result =
        await PasscodeChange.apply(current: _current, next: _next);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case PasscodeChanged():
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Passcode changed.'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ));

      case PasscodeChangeWrong(:final remaining):
        _fail(remaining == 1
            ? 'Wrong passcode. 1 try left.'
            : 'Wrong passcode. $remaining tries left.');
        _current = '';
        _reset(_Stage.current);

      case PasscodeChangeLocked(:final remaining):
        _fail(PasscodeGate.describe(remaining));
        _current = '';
        _reset(_Stage.current);

      case PasscodeChangeFailed(:final message):
        _fail(message);
        _current = '';
        _reset(_Stage.current);
    }
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() => _wrong = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ));
  }

  void _press(String digit) {
    if (_busy || _entered.length >= _length) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entered += digit;
      _wrong = false;
    });
    if (_entered.length == _length) _onComplete();
  }

  void _delete() {
    if (_busy || _entered.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Change Passcode',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              _title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontFamily: 'FKGrotesk',
              ),
            ),
            const SizedBox(height: 32),
            _dots(),
            const Spacer(),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.yellow),
                ),
              ),
            _keypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_length, (i) {
        final filled = i < _entered.length;
        final colour = _wrong ? Colors.red : Colors.white;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colour : Colors.transparent,
            border: Border.all(
                color: filled ? colour : Colors.white38, width: 2),
          ),
        );
      }),
    );
  }

  Widget _keypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int col = 0; col < 3; col++)
                    _key('${row * 3 + col + 1}'),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 80),
              _key('0'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: GestureDetector(
                  onTap: _delete,
                  child: const Icon(Icons.backspace_outlined,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(String digit) {
    return GestureDetector(
      onTap: () => _press(digit),
      child: Container(
        width: 80,
        height: 80,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: Colors.grey[900]),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
        ),
      ),
    );
  }
}
