import 'dart:math';

import '../data/models.dart';
import '../data/repository.dart';
import 'game_controller.dart';

enum BotLevel { easy, medium, hard }

class BotMove {
  const BotMove(this.cell, this.player);
  const BotMove.pass()
      : cell = null,
        player = null;

  final int? cell;
  final Player? player;
  bool get isPass => cell == null;
}

/// Bilgisayar rakip. Gerçek bir insan gibi davranması için:
/// - sadece belli bir popülerliğin üstündeki oyuncuları "bilir"
/// - bildiği bir cevabı bazen hatırlayamaz
/// - bazen yanlış cevap verir, bazen pas geçer
/// - seviyesi arttıkça kazanan hamleyi daha iyi görür ve rakibi bloklar
class Bot {
  Bot(this.level, this.repo, {Random? random}) : _random = random ?? Random();

  final BotLevel level;
  final Repository repo;
  final Random _random;

  /// Botun tanıdığı en düşük popülerlik (düşük = daha çok oyuncu bilir)
  int get _knowledge => switch (level) {
        BotLevel.easy => 25,
        BotLevel.medium => 12,
        BotLevel.hard => 4,
      };

  /// Bildiği bir hücreye gerçekten doğru cevap verme olasılığı
  double get _successRate => switch (level) {
        BotLevel.easy => 0.6,
        BotLevel.medium => 0.8,
        BotLevel.hard => 0.93,
      };

  /// Kazanma/bloklama hamlelerini görme olasılığı
  double get _strategyRate => switch (level) {
        BotLevel.easy => 0.35,
        BotLevel.medium => 0.8,
        BotLevel.hard => 1.0,
      };

  /// İnsan gibi görünsün diye düşünme süresi
  Duration thinkingTime() {
    final extra = level == BotLevel.hard ? 2000 : 3500;
    return Duration(milliseconds: 1800 + _random.nextInt(extra));
  }

  BotMove decide(GameController game) {
    final empty = [for (var i = 0; i < 9; i++) if (game.cells[i] == null) i];
    if (empty.isEmpty) return const BotMove.pass();

    // Botun cevabını bildiği hücreler
    final known = <int, List<Player>>{};
    for (final cell in empty) {
      final list = repo
          .answers(game.rowClubId(cell), game.colClubId(cell))
          .where((p) =>
              p.popularity >= _knowledge && !game.usedPlayerIds.contains(p.id))
          .toList();
      if (list.isNotEmpty) known[cell] = list;
    }

    final cell = _chooseCell(game, empty, known);

    if (known.containsKey(cell) && _random.nextDouble() < _successRate) {
      final options = known[cell]!;
      return BotMove(cell, options[_random.nextInt(min(options.length, 5))]);
    }
    // Hatırlayamadı: çoğu zaman tahmin eder (yanlış), bazen pas geçer
    if (_random.nextDouble() < 0.6) {
      final wrong = _wrongGuess(game, cell);
      if (wrong != null) return BotMove(cell, wrong);
    }
    return const BotMove.pass();
  }

  int _chooseCell(
      GameController game, List<int> empty, Map<int, List<Player>> known) {
    final me = game.current;
    final candidates = known.isEmpty ? empty : known.keys.toList();

    if (_random.nextDouble() < _strategyRate) {
      final win = _lineFinisher(game, me, candidates);
      if (win != null) return win;
      final block = _lineFinisher(game, me.other, candidates);
      if (block != null) return block;
    }

    // Orta > köşeler > kenarlar, biraz rastgelelikle
    int score(int c) {
      final base = c == 4 ? 3 : (c.isEven ? 2 : 1);
      return base * 10 + _random.nextInt(15);
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    return candidates.first;
  }

  /// [mark] için iki hücresi dolu, üçüncüsü boş olan bir çizginin boş hücresi.
  int? _lineFinisher(GameController game, Mark mark, List<int> candidates) {
    for (final line in GameController.lines) {
      final owned = line.where((c) => game.cells[c]?.owner == mark).length;
      final open = line.where((c) => game.cells[c] == null).toList();
      if (owned == 2 && open.length == 1 && candidates.contains(open.first)) {
        return open.first;
      }
    }
    return null;
  }

  /// Gerçekçi bir yanlış: iki kulüpten sadece birinde oynamış bilinen bir oyuncu.
  Player? _wrongGuess(GameController game, int cell) {
    final a = game.rowClubId(cell);
    final b = game.colClubId(cell);
    final pool = <Player>[];
    for (final p in repo.players) {
      if (p.popularity < _knowledge) break; // liste popülerliğe göre sıralı
      if (p.clubs.contains(a) != p.clubs.contains(b) &&
          !game.usedPlayerIds.contains(p.id)) {
        pool.add(p);
        if (pool.length >= 10) break;
      }
    }
    return pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
  }
}
