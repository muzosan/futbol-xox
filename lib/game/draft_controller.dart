import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'ai_player.dart' show BotLevel;
import 'engine/common.dart';
import 'engine/draft_engine.dart';
import 'engine/duel_engine.dart' show CardStat, cardStat;
import 'turn_timer.dart';
import '../l10n/l10n.dart';

export 'engine/draft_engine.dart';

/// Kadro Kur ölçütleri (veride milli maç varsa o da)
List<CardStat> draftCriteria(Repository repo) {
  final hasCaps = repo.players.any((p) => p.stat('mm') > 0);
  return [
    for (final k in ['g', 'a', 'm', 'y', 'r', 'pv', if (hasCaps) 'mm']) cardStat(k),
  ];
}

/// Ölçütün ekrandaki başlığı: "EN ÇOK GOL", "EN YÜKSEK PİYASA DEĞERİ"...
String criterionTitle(CardStat s) => t('crit.${s.key}');

/// Maç kurulumu: rastgele ölçüt + zorluğa uygun, yeterince aday oyuncusu olan 5 kulüp
({String criterion, List<String> clubs}) draftSetup(Repository repo, String difficulty,
    {int rounds = 5, Random? random}) {
  final rnd = random ?? Random();
  final criteria = draftCriteria(repo);
  final (maxTier, minKnown) = switch (difficulty) {
    'kolay' => (1, 6),
    'orta' => (2, 5),
    _ => (3, 4),
  };

  for (var attempt = 0; attempt < 20; attempt++) {
    final criterion = criteria[rnd.nextInt(criteria.length)].key;
    // Kulübün bu ölçütte değeri olan tanınmış oyuncuları yeterli mi?
    bool fits(Club c) =>
        repo
            .playersOf(c.id)
            .where((p) => p.popularity >= 10 && p.stat(criterion) > 0)
            .length >=
        minKnown;
    var pool = repo.clubs.values.where((c) => c.tier <= maxTier && fits(c)).toList();
    if (pool.length < rounds) {
      pool = repo.clubs.values.where(fits).toList();
    }
    if (pool.length < rounds) continue;
    pool.shuffle(rnd);
    return (criterion: criterion, clubs: pool.take(rounds).map((c) => c.id).toList());
  }
  // Son çare: istatistik olmasa da bir kurulum döndür
  final clubs = repo.clubs.keys.toList()..shuffle(rnd);
  return (criterion: criteria.first.key, clubs: clubs.take(rounds).toList());
}

/// Bir kulüpte ölçüte göre en iyi seçenekler (maç sonu "kaçırdıkların" için)
List<Player> bestOptions(Repository repo, String clubId, String criterion,
        {Set<String> exclude = const {}, int limit = 3}) =>
    (repo
            .playersOf(clubId)
            .where((p) => p.stat(criterion) > 0 && !exclude.contains(p.id))
            .toList()
          ..sort((a, b) => b.stat(criterion).compareTo(a.stat(criterion))))
        .take(limit)
        .toList();

/// Kadro Kur botu: tanıdığı oyuncular arasından seçer; seviye arttıkça
/// ölçüte göre en iyi oyuncuyu bulma olasılığı artar. Her zaman geçerli seçim yapar.
class DraftBot {
  DraftBot(this.level, this.repo, {Random? random}) : _random = random ?? Random();

  final BotLevel level;
  final Repository repo;
  final Random _random;

  int get _knowledge => switch (level) {
        BotLevel.easy => 25,
        BotLevel.medium => 12,
        BotLevel.hard => 4,
      };

  String? pick(DraftEngine e) {
    final known = repo
        .playersOf(e.currentClub)
        .where((p) => p.popularity >= _knowledge && !e.usedPlayerIds.contains(p.id))
        .toList()
      ..sort((a, b) => b.stat(e.criterion).compareTo(a.stat(e.criterion)));
    if (known.isEmpty) return null;
    final range = switch (level) {
      BotLevel.easy => known.length,
      BotLevel.medium => min(6, known.length),
      BotLevel.hard => min(2, known.length),
    };
    return known[_random.nextInt(range)].id;
  }

  Duration thinkingTime() => Duration(milliseconds: 2000 + _random.nextInt(3000));
}

/// Yerel Kadro Kur: kurallar [DraftEngine]'de, üstüne seçim süresi.
class DraftController extends ChangeNotifier with TurnTimer {
  DraftController({
    required this.repo,
    required this.engine,
    this.turnSeconds = 30,
    this.onTimeout,
    this.names = const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
  }) {
    startTurnTimer();
  }

  final Repository repo;
  final DraftEngine engine;
  @override
  final int turnSeconds;
  final void Function(Mark who)? onTimeout;
  final Map<Mark, String> names;

  String nameOf(Mark m) => names[m] ?? m.symbol;
  CardStat get criterion => cardStat(engine.criterion);
  Club get currentClub => repo.club(engine.currentClub);
  Mark get current => engine.current;
  bool get isOver => engine.isOver;
  int get turnNumber => engine.turnNumber;

  DraftResult pick(Player p) {
    final r = engine.pick(p.id);
    if (r.outcome == GuessResult.correct) _afterMove();
    return r;
  }

  void skip() {
    if (isOver) return;
    engine.skip();
    _afterMove();
  }

  void _afterMove() {
    if (engine.isOver) {
      stopTurnTimer();
    } else {
      startTurnTimer();
    }
    notifyListeners();
  }

  @override
  void onTurnExpired() {
    final who = engine.current;
    engine.skip();
    _afterMove();
    onTimeout?.call(who);
  }

  @override
  void dispose() {
    stopTurnTimer();
    super.dispose();
  }
}
