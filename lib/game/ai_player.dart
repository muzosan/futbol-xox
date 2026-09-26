import 'dart:math';

import '../data/models.dart';
import '../data/repository.dart';
import 'chain_controller.dart';
import 'game_controller.dart';
import 'hunt_controller.dart';

enum BotLevel { easy, medium, hard }

/// Bütün botların ortak "kişiliği": ne kadar oyuncu bildiği, ne sıklıkla
/// hatırlayabildiği ve ne kadar düşündüğü.
abstract class BotBase {
  BotBase(this.level, this.repo, {Random? random})
      : random = random ?? Random();

  final BotLevel level;
  final Repository repo;
  final Random random;

  /// Botun tanıdığı en düşük popülerlik (düşük = daha çok oyuncu bilir)
  int get knowledge => switch (level) {
        BotLevel.easy => 25,
        BotLevel.medium => 12,
        BotLevel.hard => 4,
      };

  /// Bildiği bir cevabı gerçekten hatırlama olasılığı
  double get successRate => switch (level) {
        BotLevel.easy => 0.6,
        BotLevel.medium => 0.8,
        BotLevel.hard => 0.93,
      };

  /// İnsan gibi görünsün diye düşünme süresi
  Duration thinkingTime() {
    final extra = level == BotLevel.hard ? 2000 : 3500;
    return Duration(milliseconds: 1800 + random.nextInt(extra));
  }
}

// ======================================================================
// XOX botu
// ======================================================================

class BotMove {
  const BotMove(this.cell, this.player);
  const BotMove.pass()
      : cell = null,
        player = null;

  final int? cell;
  final Player? player;
  bool get isPass => cell == null;
}

class Bot extends BotBase {
  Bot(super.level, super.repo, {super.random});

  /// Kazanma/bloklama hamlelerini görme olasılığı
  double get _strategyRate => switch (level) {
        BotLevel.easy => 0.35,
        BotLevel.medium => 0.8,
        BotLevel.hard => 1.0,
      };

  BotMove decide(GameController game) {
    final cells = game.cells;
    final empty = [for (var i = 0; i < 9; i++) if (cells[i] == null) i];
    if (empty.isEmpty) return const BotMove.pass();

    final known = <int, List<Player>>{};
    for (final cell in empty) {
      final list = repo
          .answers(game.rowClubId(cell), game.colClubId(cell))
          .where((p) =>
              p.popularity >= knowledge && !game.usedPlayerIds.contains(p.id))
          .toList();
      if (list.isNotEmpty) known[cell] = list;
    }

    final cell = _chooseCell(game, cells, empty, known);

    if (known.containsKey(cell) && random.nextDouble() < successRate) {
      final options = known[cell]!;
      return BotMove(cell, options[random.nextInt(min(options.length, 5))]);
    }
    if (random.nextDouble() < 0.6) {
      final wrong = _wrongGuess(game, cell);
      if (wrong != null) return BotMove(cell, wrong);
    }
    return const BotMove.pass();
  }

  int _chooseCell(GameController game, List<FilledCell?> cells,
      List<int> empty, Map<int, List<Player>> known) {
    final me = game.current;
    final candidates = known.isEmpty ? empty : known.keys.toList();

    if (random.nextDouble() < _strategyRate) {
      final win = _lineFinisher(cells, me, candidates);
      if (win != null) return win;
      final block = _lineFinisher(cells, me.other, candidates);
      if (block != null) return block;
    }

    int score(int c) {
      final base = c == 4 ? 3 : (c.isEven ? 2 : 1);
      return base * 10 + random.nextInt(15);
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    return candidates.first;
  }

  int? _lineFinisher(
      List<FilledCell?> cells, Mark mark, List<int> candidates) {
    for (final line in GameController.lines) {
      final owned = line.where((c) => cells[c]?.owner == mark).length;
      final open = line.where((c) => cells[c] == null).toList();
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
      if (p.popularity < knowledge) break; // liste popülerliğe göre sıralı
      if (p.clubs.contains(a) != p.clubs.contains(b) &&
          !game.usedPlayerIds.contains(p.id)) {
        pool.add(p);
        if (pool.length >= 10) break;
      }
    }
    return pool.isEmpty ? null : pool[random.nextInt(pool.length)];
  }
}

// ======================================================================
// Kulüp Avı botu
// ======================================================================

class HuntBot extends BotBase {
  HuntBot(super.level, super.repo, {super.random});

  /// Botun cevabı; null ise pas geçer.
  Player? decide(HuntController game) {
    final clubs = game.engine.currentClubs;
    final known = repo
        .multiClubPlayers(clubs)
        .where((e) =>
            e.player.popularity >= knowledge &&
            !game.usedPlayerIds.contains(e.player.id))
        .toList(); // çok kulüplüden aza sıralı

    if (known.isNotEmpty && random.nextDouble() < successRate) {
      // Uzman bot en iyi cevaplardan birini, acemi bot rastgele birini seçer
      final range = switch (level) {
        BotLevel.easy => known.length,
        BotLevel.medium => min(8, known.length),
        BotLevel.hard => min(3, known.length),
      };
      return known[random.nextInt(range)].player;
    }
    if (random.nextDouble() < 0.6) return _wrongGuess(game, clubs);
    return null;
  }

  /// Gerçekçi bir yanlış: bu kulüplerden sadece birinde oynamış bilinen biri.
  Player? _wrongGuess(HuntController game, List<String> clubs) {
    final pool = <Player>[];
    for (final p in repo.players) {
      if (p.popularity < knowledge) break;
      if (clubs.where(p.clubs.contains).length == 1 &&
          !game.usedPlayerIds.contains(p.id)) {
        pool.add(p);
        if (pool.length >= 10) break;
      }
    }
    return pool.isEmpty ? null : pool[random.nextInt(pool.length)];
  }
}

// ======================================================================
// Kariyer Zinciri botu
// ======================================================================

class ChainBot extends BotBase {
  ChainBot(super.level, super.repo, {super.random});

  /// Botun cevabı; null ise pas geçer (bir can kaybeder).
  Player? decide(ChainController game) {
    final lastId = game.engine.lastPlayerId;
    final seen = <String>{};
    final known = <Player>[];
    for (final club in game.engine.openClubs()) {
      for (final p in repo.playersOf(club)) {
        if (p.popularity < knowledge) break; // liste popülerliğe göre sıralı
        if (p.id != lastId &&
            !game.usedPlayerIds.contains(p.id) &&
            seen.add(p.id)) {
          known.add(p);
        }
      }
    }
    if (known.isNotEmpty && random.nextDouble() < successRate) {
      known.sort((a, b) => b.popularity.compareTo(a.popularity));
      final range = switch (level) {
        BotLevel.easy => min(5, known.length),
        BotLevel.medium => min(12, known.length),
        BotLevel.hard => min(25, known.length),
      };
      return known[random.nextInt(range)];
    }
    if (random.nextDouble() < 0.6) {
      // Gerçekçi bir yanlış: son oyuncuyla ortak kulübü olmayan ünlü biri
      final lastClubs = game.lastPlayer.clubs;
      final pool = repo.players
          .take(300)
          .where((p) =>
              p.id != lastId &&
              !game.usedPlayerIds.contains(p.id) &&
              p.clubs.intersection(lastClubs).isEmpty)
          .toList();
      if (pool.isNotEmpty) return pool[random.nextInt(pool.length)];
    }
    return null;
  }
}
