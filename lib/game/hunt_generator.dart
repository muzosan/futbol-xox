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

  // (en az 2 kulüplü ünlü oyuncu, en az 3 kulüplü, "ünlü" eşiği, en yüksek kulüp seviyesi)
  // kolay: sadece büyük kulüpler ve çok ünlü oyuncular
  final (min2, min3, known, maxTier) = switch (difficulty) {
    'kolay' => (12, 3, 30, 1),
    'orta' => (10, 2, 20, 2),
    _ => (8, 1, 5, 3),
  };

  // En çok tanınmış oyuncusu olan kulüpler (seviye bilgisi yoksa yedek olarak da)
  List<String> mostFamous(int count) {
    final fame = <String, int>{
      for (final id in repo.clubs.keys)
        id: repo.playersOf(id).where((p) => p.popularity >= 15).length,
    };
    return (repo.clubs.keys.where((id) => fame[id]! > 0).toList()
          ..sort((a, b) => fame[b]!.compareTo(fame[a]!)))
        .take(count)
        .toList();
  }

  // Kolay/orta: seviyeye göre havuz. Zor: en çok tanınmış oyuncusu olan 300 kulüp.
  var pool = maxTier < 3
      ? repo.clubs.values
          .where((c) => c.tier <= maxTier)
          .map((c) => c.id)
          .toList()
      : mostFamous(300);
  if (pool.length < 15) pool = mostFamous(maxTier == 1 ? 40 : 120);

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
        final lig = repo.club(c).leagueRaw;
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
