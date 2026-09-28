import 'dart:math';

import '../data/models.dart';
import '../data/repository.dart';

/// Gizli futbolcu: herkesin ipucu verebileceği kadar tanınmış olmalı.
/// kolay: en az 2 büyük kulüpte oynamış yıldızlar · orta: tanınmışlar · zor: daha az bilinenler
Player pickImposterSecret(Repository repo, String difficulty,
    {Set<String> exclude = const {}, Random? random}) {
  final rnd = random ?? Random();
  final (minPop, maxPop, maxTier, minBig) = switch (difficulty) {
    'kolay' => (45, 1 << 30, 1, 2),
    'orta' => (22, 1 << 30, 2, 1),
    _ => (10, 40, 3, 0),
  };
  var pool = repo.players
      .where((p) =>
          p.popularity >= minPop &&
          p.popularity <= maxPop &&
          repo.bigClubCount(p, maxTier) >= minBig &&
          !exclude.contains(p.id))
      .toList();
  if (pool.length < 10) {
    pool = repo.players.where((p) => p.popularity >= 20).toList();
  }
  return pool[rnd.nextInt(pool.length)];
}

/// Sahtekâra verilecek küçük ipucu: mevki ve en tanınmış kulübün ligi
String imposterHint(Repository repo, Player p) {
  final parts = <String>[
    if (p.positions.isNotEmpty) 'Mevki: ${p.positions.first}',
    if (repo.mainClub(p) != null) 'Lig: ${repo.mainClub(p)!.league}',
  ];
  return parts.isEmpty ? 'İpucu yok, dikkatle dinle!' : parts.join(' · ');
}
