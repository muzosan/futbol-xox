/// Arama için metni sadeleştirir:
/// "Mesut Özil" -> "mesut ozil", "N'Golo Kanté" -> "ngolo kante", "İlkay" -> "ilkay"
String normalize(String input) {
  final text = input.replaceAll('İ', 'i').toLowerCase();
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final mapped = _charMap[ch];
    if (mapped != null) {
      buffer.write(mapped);
    } else if ((rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57)) {
      buffer.write(ch); // a-z, 0-9
    } else if (ch == ' ' || ch == '-') {
      buffer.write(' ');
    }
    // Diğer her şey (nokta, kesme işareti, birleşik aksan işaretleri) atlanır
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

const Map<String, String> _charMap = {
  'ı': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c',
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ū': 'u', 'ű': 'u', 'ů': 'u',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ć': 'c', 'č': 'c',
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  'š': 's', 'ś': 's', 'ș': 's',
  'ț': 't', 'ť': 't',
  'ř': 'r', 'ý': 'y', 'ÿ': 'y', 'đ': 'd', 'ď': 'd', 'ł': 'l',
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
};
