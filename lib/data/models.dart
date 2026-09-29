import '../l10n/lang_state.dart';
import 'text_utils.dart';

class Club {
  const Club({
    required this.id,
    required String name,
    this.nameEn,
    required this.fullName,
    required String league,
    this.tier = 3,
    this.kitPattern = 'solid',
    this.kitColors = const [],
  })  : nameTr = name,
        leagueRaw = league;

  final String id;

  /// Veriden gelen Türkçe ad (ör. "Bayern Münih") ve İngilizce ad (ör. "Bayern Munich")
  final String nameTr;
  final String? nameEn;
  final String fullName;

  /// Veriden gelen lig adı (Türkçe, ör. "Arjantin Ligi")
  final String leagueRaw;

  /// Ekranda gösterilen kulüp adı: Türkçede Türkçe ad, diğer dillerde İngilizce ad
  String get name => currentLang == 'tr' || nameEn == null ? nameTr : nameEn!;

  /// Ekranda gösterilen lig adı (geçerli dilde)
  String get league => leagueName(leagueRaw);

  /// Ün seviyesi: 1 = herkesin bildiği büyük kulüp, 2 = tanınmış, 3 = diğer
  final int tier;

  /// Forma deseni: solid, stripes, hoops, halves, sleeves, center, band, sash, diagonal
  final String kitPattern;

  /// Forma renkleri (0xAARRGGBB). Boşsa varsayılan renk kullanılır.
  final List<int> kitColors;

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id'] as String,
        name: json['ad'] as String,
        nameEn: json['en'] as String?,
        fullName: json['tam_ad'] as String,
        league: json['lig'] as String,
        tier: json['t'] as int? ?? 3,
        kitPattern: (json['f'] as Map<String, dynamic>?)?['p'] as String? ?? 'solid',
        kitColors: ((json['f'] as Map<String, dynamic>?)?['c'] as List?)
                ?.map((h) => int.parse('FF${(h as String).substring(1)}', radix: 16))
                .toList() ??
            const [],
      );

  /// Rozet içinde yazacak kısaltma: "Real Madrid" -> "RM", "Galatasaray" -> "GAL"
  String get initials {
    final parts =
        name.split(RegExp(r"[\s'\-]+")).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 3 ? 3 : word.length).toUpperCase();
    }
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }
}

class Player {
  Player({
    required this.id,
    required this.name,
    this.trName,
    required this.popularity,
    this.birthYear,
    required this.clubs,
    this.positions = const [],
    this.nationality,
    this.stats = const {},
  }) : searchKey = ' ${normalize('$name ${trName ?? ''}')}';

  final String id;
  final String name;
  final String? trName;
  final int popularity;
  final int? birthYear;
  final Set<String> clubs;

  /// Mevki kısaltmaları, ör. ["CB"] veya ["CM", "DM"]
  final List<String> positions;

  /// Ülke kodu, ör. "TR", "BR", "GB-ENG" (bilinmiyorsa null)
  final String? nationality;

  /// İstatistikler: g gol, a asist, m maç, y sarı, r kırmızı (2012+ Avrupa),
  /// mm milli maç, mg milli gol, pv en yüksek piyasa değeri (milyon €)
  final Map<String, num> stats;

  num stat(String key) => stats[key] ?? 0;

  /// Başında boşluk olan sadeleştirilmiş isim; kelime başı eşleşmesi için kullanılır.
  final String searchKey;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['ad'] as String,
        trName: json['tr'] as String?,
        popularity: json['p'] as int,
        birthYear: json['y'] as int?,
        clubs: (json['k'] as List).cast<String>().toSet(),
        positions: (json['m'] as List?)?.cast<String>() ?? const [],
        nationality: json['u'] as String?,
        stats: (json['s'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as num)) ??
            const {},
      );
}

class PuzzleGrid {
  const PuzzleGrid({
    required this.id,
    required this.difficulty,
    required this.rows,
    required this.cols,
    required this.answerCounts,
  });

  final String id;
  final String difficulty;
  final List<String> rows; // 3 kulüp ID'si
  final List<String> cols; // 3 kulüp ID'si
  final List<List<int>> answerCounts; // [satır][sütun] doğru cevap sayısı

  factory PuzzleGrid.fromJson(Map<String, dynamic> json) => PuzzleGrid(
        id: json['id'] as String,
        difficulty: json['z'] as String,
        rows: (json['s'] as List).cast<String>(),
        cols: (json['c'] as List).cast<String>(),
        answerCounts: (json['n'] as List)
            .map((row) => (row as List).cast<int>().toList())
            .toList(),
      );
}

/// Kariyerde bir durak: kulüp adı ve katıldığı yıl (bilinmiyorsa null).
class CareerStep {
  const CareerStep(this.club, this.year);
  final String club;
  final int? year;
}

class Career {
  const Career(this.playerId, this.steps);

  final String playerId;
  final List<CareerStep> steps; // kronolojik sırayla

  factory Career.fromJson(Map<String, dynamic> json) => Career(
        json['id'] as String,
        (json['c'] as List)
            .map((s) => CareerStep((s as List)[0] as String, s[1] as int?))
            .toList(),
      );
}
