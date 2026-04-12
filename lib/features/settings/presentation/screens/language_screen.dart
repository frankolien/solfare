import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/main.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  static const _storageKey = 'app_language';
  final _storage = const FlutterSecureStorage();
  String _selected = 'EN';

  static const List<_Language> _languages = [
    _Language(flag: '🇬🇧', name: 'English', code: 'EN'),
    _Language(flag: '🇮🇩', name: 'Bahasa Indonesia', code: 'ID'),
    _Language(flag: '🇲🇾', name: 'Bahasa Melayu', code: 'MY'),
    _Language(flag: '🇩🇰', name: 'Dansk', code: 'DK'),
    _Language(flag: '🇩🇪', name: 'Deutsch', code: 'DE'),
    _Language(flag: '🇪🇸', name: 'Español', code: 'ES'),
    _Language(flag: '🇵🇭', name: 'Filipino', code: 'PH'),
    _Language(flag: '🇫🇷', name: 'Français', code: 'FR'),
    _Language(flag: '🇨🇦', name: 'Français (Canada)', code: 'CA'),
    _Language(flag: '🇮🇳', name: 'हिंदी', code: 'IN'),
    _Language(flag: '🇮🇹', name: 'Italiano', code: 'IT'),
    _Language(flag: '🇯🇵', name: '日本語', code: 'JP'),
    _Language(flag: '🇰🇷', name: '한국어', code: 'KR'),
    _Language(flag: '🇳🇱', name: 'Nederlands', code: 'NL'),
    _Language(flag: '🇵🇱', name: 'Polski', code: 'PL'),
    _Language(flag: '🇧🇷', name: 'Português (Brasil)', code: 'BR'),
    _Language(flag: '🇵🇹', name: 'Português (Portugal)', code: 'PT'),
    _Language(flag: '🇷🇺', name: 'Русский', code: 'RU'),
    _Language(flag: '🇸🇮', name: 'Slovenščina', code: 'SI'),
    _Language(flag: '🇷🇸', name: 'Srpski', code: 'RS'),
    _Language(flag: '🇸🇪', name: 'Svenska', code: 'SE'),
    _Language(flag: '🇻🇳', name: 'Tiếng Việt', code: 'VN'),
    _Language(flag: '🇹🇷', name: 'Türkçe', code: 'TR'),
    _Language(flag: '🇹🇭', name: 'ภาษาไทย', code: 'TH'),
    _Language(flag: '🇺🇦', name: 'Українська', code: 'UA'),
    _Language(flag: '🇨🇳', name: '中文 (简体)', code: 'CN'),
    _Language(flag: '🇹🇼', name: '中文 (繁體)', code: 'TW'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.read(key: _storageKey);
    if (saved != null && mounted) {
      setState(() => _selected = saved);
    }
  }

  Future<void> _select(String code) async {
    setState(() => _selected = code);
    await _storage.write(key: _storageKey, value: code);
    if (mounted) {
      context.localeProvider.setLocale(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
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
                        'Language',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // Language list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selected == lang.code;

                  return GestureDetector(
                    onTap: () => _select(lang.code),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          // Flag
                          Text(lang.flag, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 14),

                          // Name + code
                          Expanded(
                            child: Text(
                              '${lang.name} (${lang.code})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'FKGrotesk',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          // Selection indicator
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.yellow,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.black, size: 14),
                            )
                          else
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[700]!, width: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Language {
  final String flag;
  final String name;
  final String code;

  const _Language({required this.flag, required this.name, required this.code});
}
