import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  bool _biometricsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Iconsax.document_code,
                      title: 'Manage apps',
                      subtitle: 'Apps you connected to previously',
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Iconsax.link,
                      title: 'Spending approvals',
                      subtitle: 'Control who can spend your assets',
                      onTap: () {},
                    ),
                    _buildToggleItem(
                      icon: Iconsax.magic_star,
                      title: 'Magic AI',
                      subtitle: 'Show Magic assistant in the app',
                      value: false,
                      onChanged: (_) {},
                    ),
                    _buildToggleItem(
                      icon: Iconsax.finger_scan,
                      title: 'Biometrics',
                      subtitle: 'Unlock the app quickly and securely',
                      value: _biometricsEnabled,
                      onChanged: (val) => setState(() => _biometricsEnabled = val),
                    ),
                    _buildMenuItem(
                      icon: Iconsax.lock,
                      title: 'Change passcode',
                      subtitle: 'Update your account security',
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Iconsax.timer_1,
                      title: 'Request authentication',
                      subtitle: '24 hours',
                      onTap: () {},
                    ),
                    _buildExternalItem(
                      icon: Iconsax.document_text,
                      title: 'Terms of Service',
                      subtitle: 'Review rules and policies',
                      onTap: () {},
                    ),
                    _buildExternalItem(
                      icon: Iconsax.shield_tick,
                      title: 'Privacy Policy',
                      subtitle: 'Learn how we use and protect data',
                      onTap: () {},
                    ),

                    const SizedBox(height: 20),

                    // Log out
                    _buildLogoutItem(context),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Security & Privacy',
                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 9, fontFamily: 'FKGrotesk')),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 9, fontFamily: 'FKGrotesk')),
              ],
            ),
          ),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.black,
              activeTrackColor: Colors.yellow,
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 9, fontFamily: 'FKGrotesk')),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Colors.grey[600], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            const Icon(Iconsax.logout, color: Color(0xFFFF5252), size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Log out', style: TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Remove all wallets and clear all data', style: TextStyle(color: Colors.grey[500], fontSize: 9, fontFamily: 'FKGrotesk')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
        content: Text(
          'This will remove all wallet data from this device. Make sure you have your recovery phrase backed up.',
          style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk', height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WalletBloc>().add(const ClearWalletEvent());
            },
            child: const Text('Log out', style: TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
