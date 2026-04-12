import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:solfare/features/settings/presentation/screens/address_book_screen.dart';
import 'package:solfare/features/settings/presentation/screens/general_screen.dart';
import 'package:solfare/features/settings/presentation/screens/security_privacy_screen.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Menu items
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Iconsax.setting_4,
                      title: 'General',
                      subtitle: 'Edit language and currency',
                      onTap: () => _push(context, const GeneralScreen()),
                    ),
                    _buildMenuItem(
                      icon: Iconsax.book,
                      title: 'Address book',
                      subtitle: 'Manage your contacts',
                      onTap: () => _push(context, const AddressBookScreen()),
                    ),
                    _buildMenuItem(
                      icon: Iconsax.notification,
                      title: 'Notifications',
                      subtitle: 'Get important updates',
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Iconsax.shield_tick,
                      title: 'Security & privacy',
                      subtitle: 'Manage apps and more',
                      onTap: () => _push(context, const SecurityPrivacyScreen()),
                    ),
                    _buildMenuItem(
                      icon: Iconsax.message_question,
                      title: 'Support',
                      subtitle: 'Contact our customer support',
                      onTap: () {},
                    ),

                    const SizedBox(height: 40),

                    // Reset wallet (danger)
                    _buildResetButton(context),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Version
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Version 0.1.0 (1)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w400,
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
          // MW avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'MW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 32),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _showResetDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'Reset Wallet',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 11,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Wallet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will remove all wallet data from this device. Make sure you have your recovery phrase backed up.',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
            fontFamily: 'FKGrotesk',
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WalletBloc>().add(const ClearWalletEvent());
            },
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 13,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
