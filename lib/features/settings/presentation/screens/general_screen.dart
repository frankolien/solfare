import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:solfare/features/settings/presentation/screens/language_screen.dart';

class GeneralScreen extends StatefulWidget {
  const GeneralScreen({super.key});

  @override
  State<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends State<GeneralScreen> {
  final _storage = const FlutterSecureStorage();
  String _languageLabel = 'English (EN)';

  // Map code → display name (same list as LanguageScreen)
  static const Map<String, String> _languageNames = {
    'EN': 'English (EN)',
    'ID': 'Bahasa Indonesia (ID)',
    'MY': 'Bahasa Melayu (MY)',
    'DK': 'Dansk (DK)',
    'DE': 'Deutsch (DE)',
    'ES': 'Español (ES)',
    'PH': 'Filipino (PH)',
    'FR': 'Français (FR)',
    'CA': 'Français (Canada) (CA)',
    'IN': 'हिंदी (IN)',
    'IT': 'Italiano (IT)',
    'JP': '日本語 (JP)',
    'KR': '한국어 (KR)',
    'NL': 'Nederlands (NL)',
    'PL': 'Polski (PL)',
    'BR': 'Português (Brasil) (BR)',
    'PT': 'Português (Portugal) (PT)',
    'RU': 'Русский (RU)',
    'SI': 'Slovenščina (SI)',
    'RS': 'Srpski (RS)',
    'SE': 'Svenska (SE)',
    'VN': 'Tiếng Việt (VN)',
    'TR': 'Türkçe (TR)',
    'TH': 'ภาษาไทย (TH)',
    'UA': 'Українська (UA)',
    'CN': '中文 (简体) (CN)',
    'TW': '中文 (繁體) (TW)',
  };

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final code = await _storage.read(key: 'app_language');
    if (code != null && mounted) {
      setState(() => _languageLabel = _languageNames[code] ?? 'English (EN)');
    }
  }

  Future<void> _openLanguage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LanguageScreen()),
    );
    // Reload when coming back
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Iconsax.global,
              title: 'Language',
              subtitle: _languageLabel,
              onTap: _openLanguage,
            ),
            _buildMenuItem(
              icon: Iconsax.dollar_circle,
              title: 'Currency',
              subtitle: 'US Dollar',
              onTap: () {},
            ),
            _buildMenuItem(
              icon: Iconsax.hierarchy_square_2,
              title: 'Network',
              subtitle: 'Devnet',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                'General',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 14),
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
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );
  }
}
