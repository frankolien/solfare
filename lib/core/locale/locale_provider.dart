import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleProvider extends ChangeNotifier {
  static const _storageKey = 'app_language';
  final _storage = const FlutterSecureStorage();

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  // Map language codes from LanguageScreen to proper locale codes
  static const Map<String, String> _codeToLocale = {
    'EN': 'en',
    'FR': 'fr',
    'ES': 'es',
    'DE': 'de',
    // Others fall back to English until ARB files are added
  };

  // Supported locales — must match ARB files
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('es'),
    Locale('de'),
  ];

  LocaleProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final code = await _storage.read(key: _storageKey);
    if (code != null) {
      final localeCode = _codeToLocale[code] ?? 'en';
      _locale = Locale(localeCode);
      notifyListeners();
    }
  }

  Future<void> setLocale(String languageCode) async {
    final localeCode = _codeToLocale[languageCode] ?? 'en';
    _locale = Locale(localeCode);
    await _storage.write(key: _storageKey, value: languageCode);
    notifyListeners();
  }
}
