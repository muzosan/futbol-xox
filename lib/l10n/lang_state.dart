/// Geçerli dil (saf Dart: modeller ve kural motorları da kullanabilir).
/// Değiştirmek için [L10n.setLang] kullan; bu değişken oradan güncellenir.
String currentLang = 'tr';

/// Oyundaki liglerin 8 dildeki adları (veride Türkçe tutulur)
const Map<String, Map<String, String>> kLeagueNames = {
  'Süper Lig': {'en': 'Süper Lig', 'ar': 'الدوري التركي الممتاز'},
  'TFF 1. Lig': {'en': 'TFF First League', 'es': 'TFF Primera Liga', 'pt': 'TFF Primeira Liga', 'de': 'TFF 1. Lig', 'fr': 'TFF 1re Ligue', 'it': 'TFF 1. Lig', 'ar': 'الدرجة الأولى التركية'},
  'TFF 2. Lig': {'en': 'TFF Second League', 'es': 'TFF Segunda Liga', 'pt': 'TFF Segunda Liga', 'de': 'TFF 2. Lig', 'fr': 'TFF 2e Ligue', 'it': 'TFF 2. Lig', 'ar': 'الدرجة الثانية التركية'},
  'TFF 3. Lig': {'en': 'TFF Third League', 'es': 'TFF Tercera Liga', 'pt': 'TFF Terceira Liga', 'de': 'TFF 3. Lig', 'fr': 'TFF 3e Ligue', 'it': 'TFF 3. Lig', 'ar': 'الدرجة الثالثة التركية'},
  'Premier League': {'ar': 'الدوري الإنجليزي الممتاز'},
  'Championship': {'ar': 'دوري البطولة الإنجليزية'},
  'La Liga': {'ar': 'الدوري الإسباني'},
  'La Liga 2': {'ar': 'الدوري الإسباني الدرجة الثانية'},
  'Serie A': {'ar': 'الدوري الإيطالي'},
  'Serie B': {'ar': 'الدوري الإيطالي الدرجة الثانية'},
  'Bundesliga': {'ar': 'الدوري الألماني'},
  '2. Bundesliga': {'ar': 'الدوري الألماني الدرجة الثانية'},
  'Ligue 1': {'ar': 'الدوري الفرنسي'},
  'Ligue 2': {'ar': 'الدوري الفرنسي الدرجة الثانية'},
  'Eredivisie': {'ar': 'الدوري الهولندي'},
  'Eerste Divisie': {'ar': 'الدوري الهولندي الدرجة الثانية'},
  'Liga Portugal': {'ar': 'الدوري البرتغالي'},
  'Liga Portugal 2': {'ar': 'الدوري البرتغالي الدرجة الثانية'},
  'Brasileirão': {'ar': 'الدوري البرازيلي'},
  'Arjantin Ligi': {'en': 'Argentine League', 'es': 'Liga Argentina', 'pt': 'Liga Argentina', 'de': 'Argentinische Liga', 'fr': 'Championnat argentin', 'it': 'Campionato argentino', 'ar': 'الدوري الأرجنتيني'},
  'Suudi Pro Lig': {'en': 'Saudi Pro League', 'es': 'Liga Profesional Saudí', 'pt': 'Liga Profissional Saudita', 'de': 'Saudi Pro League', 'fr': 'Saudi Pro League', 'it': 'Saudi Pro League', 'ar': 'دوري روشن السعودي'},
};

/// Lig adını geçerli dilde döndürür (çeviri yoksa İngilizce, o da yoksa aslı)
String leagueName(String raw) {
  if (currentLang == 'tr') return raw;
  final m = kLeagueNames[raw];
  return m?[currentLang] ?? m?['en'] ?? raw;
}
