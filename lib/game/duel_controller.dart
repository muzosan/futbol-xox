import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'ai_player.dart' show BotLevel;
import 'engine/common.dart';
import 'engine/duel_engine.dart';
import 'turn_timer.dart';

export 'engine/duel_engine.dart';

/// Kartlarda gösterilecek 6 istatistik. Veride milli maç bilgisi yoksa
/// (bazı Transfermarkt veri seti sürümlerinde bulunmuyor) yerine sarı kart.
List<CardStat> cardStatsFor(Repository repo) {
  final hasCaps = repo.players.any((p) => p.stat('mm') > 0);
  return [
    for (final k in ['g', 'a', 'm', 'r', hasCaps ? 'mm' : 'y', 'pv']) cardStat(k),
  ];
}

/// Zorluğa göre kart havuzu: kolayda yıldızlar, zorda herkes.
/// Sadece yeterince maç istatistiği olan oyuncular (kartlar boş kalmasın).
List<Player> duelPool(Repository repo, String difficulty) {
  final (minPop, minApps) = switch (difficulty) {
    'kolay' => (35, 80),
    'orta' => (15, 60),
    _ => (5, 40),
  };
  var pool = repo.players
      .where((p) => p.popularity >= minPop && p.stat('m') >= minApps)
      .toList();
  if (pool.length < 40) {
    pool = repo.players.where((p) => p.stat('m') > 0).toList();
  }
  return pool;
}

Map<Mark, List<String>> dealDecks(List<Player> pool, {int size = 7, Random? random}) {
  final rnd = random ?? Random();
  final shuffled = pool.toList()..shuffle(rnd);
  final cards = shuffled.take(size * 2).map((p) => p.id).toList();
  return {Mark.x: cards.sublist(0, size), Mark.o: cards.sublist(size)};
}

/// Kart Düellosu botu: kendi kartında hangi istatistiğin havuza göre en güçlü
/// olduğuna bakar (yüzdelik dilim). Seviye arttıkça en iyi seçimi daha sık yapar.
class DuelBot {
  DuelBot(this.level, List<Player> pool, this.stats, {Random? random})
      : _random = random ?? Random() {
    for (final s in stats) {
      _sorted[s.key] = pool.map((p) => p.stat(s.key)).toList()..sort();
    }
  }

  final BotLevel level;
  final List<CardStat> stats;
  final Random _random;
  final Map<String, List<num>> _sorted = {};

  double _percentile(String stat, num value) {
    final list = _sorted[stat]!;
    if (list.isEmpty) return 0;
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo / list.length;
  }

  String pickStat(Player card) {
    final smart = switch (level) {
      BotLevel.easy => 0.45,
      BotLevel.medium => 0.8,
      BotLevel.hard => 1.0,
    };
    if (_random.nextDouble() > smart) {
      return stats[_random.nextInt(stats.length)].key;
    }
    return stats
        .map((s) => (key: s.key, p: _percentile(s.key, card.stat(s.key))))
        .reduce((a, b) => a.p >= b.p ? a : b)
        .key;
  }

  Duration thinkingTime() => Duration(milliseconds: 1400 + _random.nextInt(1600));
}

/// Yerel Kart Düellosu: kurallar [DuelEngine]'de, üstüne seçim süresi.
class DuelController extends ChangeNotifier with TurnTimer {
  DuelController({
    required this.repo,
    required this.engine,
    this.turnSeconds = 20,
    this.names = const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
    required this.stats,
    Random? random,
  }) : _random = random ?? Random() {
    startTurnTimer();
  }

  final Repository repo;
  final DuelEngine engine;
  @override
  final int turnSeconds;
  final Map<Mark, String> names;
  final List<CardStat> stats;
  final Random _random;

  String nameOf(Mark m) => names[m] ?? m.symbol;
  Player cardOf(Mark m) => repo.playerById(engine.cardOf(m))!;
  Mark get chooser => engine.chooser;
  bool get revealed => engine.revealed;
  bool get isOver => engine.isOver;
  int points(Mark m) => engine.points[m]!;
  int get turnNumber => engine.turnNumber;

  void pick(String stat) {
    if (engine.pick(stat) == null) return;
    stopTurnTimer();
    notifyListeners();
  }

  void next() {
    if (!engine.revealed || engine.isOver) return;
    engine.next();
    startTurnTimer();
    notifyListeners();
  }

  /// Süre dolarsa rastgele bir istatistik seçilir
  @override
  void onTurnExpired() {
    if (engine.revealed) return;
    pick(stats[_random.nextInt(stats.length)].key);
  }

  @override
  void dispose() {
    stopTurnTimer();
    super.dispose();
  }
}
