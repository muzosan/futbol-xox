import 'dart:math';

import '../data/repository.dart';

/// Kulüp Avı için tur tur 5'li kulüp setleri seçer.
/// Tamamen rastgele seçilirse bazen hiç ortak oyuncu çıkmayabilir; bu yüzden her
/// sette yeterince "tanınmış" 2 ve 3 kulüplü oyuncu olmasını şart koşar.
List<List<String>> generateHuntRounds(
  Repository repo,
  String difficulty, {
  int rounds = 3,
  Random? random,
}) {
  final rnd = random ?? Random();

  // (en az 2 kulüplü tanınmış oyuncu, en az 3 kulüplü, "tanınmış" eşiği)
  final (min2, min3, known) = switch (difficulty) {
    'kolay' => (25, 5, 15),
    'orta' => (15, 3, 10),
    _ => (8, 1, 5),
  };

  // Kolayda, çok sayıda tanınmış oyuncusu olan büyük kulüplerden seç
  var pool = repo.clubs.keys.toList();
  if (difficulty == 'kolay') {
    pool.sort((a, b) => repo
        .playersOf(b)
        .where((p) => p.popularity >= known)
        .length
        .compareTo(
            repo.playersOf(a).where((p) => p.popularity >= known).length));
    pool = pool.take(30).toList();
  }

  final result = <List<String>>[];
  final usedClubs = <String>{};

  for (var r = 0; r < rounds; r++) {
    List<String>? best;
    var bestScore = -1;

    for (var attempt = 0; attempt < 300; attempt++) {
      final candidates = pool.where((c) => !usedClubs.contains(c)).toList()
        ..shuffle(rnd);
      if (candidates.length < 5) break;
      final set = candidates.take(5).toList();

      // Aynı ligden en fazla 3 kulüp
      final leagues = <String, int>{};
      for (final c in set) {
        final lig = repo.club(c).league;
        leagues[lig] = (leagues[lig] ?? 0) + 1;
      }
      if (leagues.values.any((n) => n > 3)) continue;

      final list = repo
          .multiClubPlayers(set)
          .where((e) => e.player.popularity >= known)
          .toList();
      final two = list.length;
      final three = list.where((e) => e.count >= 3).length;

      if (two >= min2 && three >= min3) {
        best = set;
        break;
      }
      // Şart sağlanamazsa en iyi bulunanı yedek olarak tut
      final score = min(two, min2) + min(three, min3) * 5;
      if (score > bestScore) {
        bestScore = score;
        best = set;
      }
    }

    if (best == null) break;
    result.add(best);
    usedClubs.addAll(best);
  }
  return result;
}
