import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import 'lang_state.dart';

export 'lang_state.dart' show currentLang, leagueName;
export 'translate.dart' show t, upper;

/// Desteklenen diller (sıra, strings.dart'taki çeviri sırasıyla aynı)
class AppLang {
  const AppLang(this.code, this.nativeName, this.flag);
  final String code;
  final String nativeName;
  final String flag;
}

const List<AppLang> kLangs = [
  AppLang('tr', 'Türkçe', '🇹🇷'),
  AppLang('en', 'English', '🇬🇧'),
  AppLang('es', 'Español', '🇪🇸'),
  AppLang('pt', 'Português', '🇵🇹'),
  AppLang('de', 'Deutsch', '🇩🇪'),
  AppLang('fr', 'Français', '🇫🇷'),
  AppLang('it', 'Italiano', '🇮🇹'),
  AppLang('ar', 'العربية', '🇸🇦'),
];

/// Dil ayarı: seçimi hatırlar, ilk açılışta telefonun dilini kullanır.
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n instance = L10n._();
  static const _prefKey = 'dil';

  AppLang get lang => kLangs.firstWhere((l) => l.code == currentLang);
  Locale get locale => Locale(currentLang);
  bool get isRtl => currentLang == 'ar';

  /// Uygulama açılırken çağrılır
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && kLangs.any((l) => l.code == saved)) {
      currentLang = saved;
    } else {
      final device = PlatformDispatcher.instance.locale.languageCode;
      currentLang = kLangs.any((l) => l.code == device) ? device : 'en';
    }
    notifyListeners();
  }

  Future<void> setLang(String code) async {
    if (!kLangs.any((l) => l.code == code) || code == currentLang) return;
    currentLang = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }
}
