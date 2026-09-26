import 'text_utils.dart';

class Club {
  const Club({
    required this.id,
    required this.name,
    required this.fullName,
    required this.league,
  });

  final String id;
  final String name;
  final String fullName;
  final String league;

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id'] as String,
        name: json['ad'] as String,
        fullName: json['tam_ad'] as String,
        league: json['lig'] as String,
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
  }) : searchKey = ' ${normalize('$name ${trName ?? ''}')}';

  final String id;
  final String name;
  final String? trName;
  final int popularity;
  final int? birthYear;
  final Set<String> clubs;

  /// Başında boşluk olan sadeleştirilmiş isim; kelime başı eşleşmesi için kullanılır.
  final String searchKey;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['ad'] as String,
        trName: json['tr'] as String?,
        popularity: json['p'] as int,
        birthYear: json['y'] as int?,
        clubs: (json['k'] as List).cast<String>().toSet(),
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
