import 'lang_state.dart';
import 'strings.dart';

/// Dil kodlarının sırası (strings.dart'taki çeviri sırasıyla aynı)
const List<String> kLangCodes = ['tr', 'en', 'es', 'pt', 'de', 'fr', 'it', 'ar'];

/// Çeviri: t('home.tagline') veya t('xox.wrong', {'player': 'Messi'})
/// Saf Dart: kural motorları ve modeller de kullanabilir.
String t(String key, [Map<String, Object?> args = const {}]) {
  final entry = kStrings[key];
  if (entry == null) return key; // eksik anahtar: ekranda anahtarın kendisi görünür
  final i = kLangCodes.indexOf(currentLang);
  var s = (i >= 0 && i < entry.length && entry[i].isNotEmpty) ? entry[i] : entry[1];
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Dile duyarlı büyük harf: Türkçede "i" -> "İ" (Dart'ın toUpperCase'i "I" yapar)
String upper(String s) =>
    currentLang == 'tr' ? s.replaceAll('i', 'İ').toUpperCase() : s.toUpperCase();
