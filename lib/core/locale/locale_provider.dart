import 'package:flutter/material.dart';
import 'package:solfare/core/security/secure_store.dart';

class LocaleProvider extends ChangeNotifier {
  static const _storageKey = 'app_language';
  final _storage = SecureStore.instance;

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  static const Map<String, String> _codeToLocale = {
    'EN': 'en',
    'FR': 'fr',
    'ES': 'es',
    'DE': 'de',
    // Others fall back to English until ARB files are added
  };

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
