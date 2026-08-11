import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/security/biometric_lock.dart';
import 'package:solfare/core/security/wallet_key.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  String? _label;
  bool _checking = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final available = await BiometricLock.isAvailable();
    final label = available ? await BiometricLock.label() : null;
    if (!mounted) return;
    setState(() {
      _label = label;
      _checking = false;
    });
  }

  Future<void> _enable() async {
    // Reached straight after the passcode was set, so the key it derived is
    // still held. Without it there is nothing to store and the toggle would be
    // a lie.
    final key = WalletKey.value;
    if (key == null) {
      _continue();
      return;
    }

    setState(() => _saving = true);
    final ok = await BiometricLock.enable(key);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not turn on $_label. Your passcode still works.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      return;
    }
    _continue();
  }

  void _continue() => context.push(AppRoutes.setupComplete);

  @override
  Widget build(BuildContext context) {
    final available = _label != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: _continue,
                ),
              ),

              const Spacer(flex: 2),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[900]?.withValues(alpha: 0.5),
                ),
                child: Icon(
                  available ? Icons.fingerprint : Icons.lock_open,
                  color: Colors.white,
                  size: 64,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'Unlock Quicker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                available
                    ? 'Use $_label instead of typing your passcode. Your passcode '
                        'still works, and is still what protects your recovery phrase.'
                    : 'No biometrics are set up on this device. You can keep '
                        'using your passcode.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _checking || _saving
                      ? null
                      : (available ? _enable : _continue),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          available ? 'Enable $_label' : 'Continue',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              if (available)
                TextButton(
                  onPressed: _saving ? null : _continue,
                  child: Text(
                    'Not now',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
