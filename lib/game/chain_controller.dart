import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'engine/chain_engine.dart';
import 'engine/common.dart';
import 'turn_timer.dart';

export 'engine/chain_engine.dart' show ChainEngine, ChainFail, ChainLink, ChainResult;

/// Zorluğa göre başlangıç futbolcusu seçer: en az 3 kulübümüzde oynamış biri.
String pickChainStart(Repository repo, String difficulty, {Random? random}) {
  final rnd = random ?? Random();
  var minPopularity = switch (difficulty) {
    'kolay' => 40,
    'orta' => 20,
    _ => 8,
  };
  while (true) {
    final pool = repo.players
        .where((p) => p.popularity >= minPopularity && p.clubs.length >= 3)
        .toList();
    if (pool.length >= 10 || minPopularity <= 1) {
      return pool[rnd.nextInt(pool.length)].id;
    }
    minPopularity ~/= 2;
  }
}

/// Yerel Kariyer Zinciri oyunu: kuralları [ChainEngine]'e bırakır, üstüne
/// zamanlayıcı ekler.
class ChainController extends ChangeNotifier with TurnTimer {
  ChainController({
    required this.repo,
    required this.engine,
    this.turnSeconds = 30,
    this.onTimeout,
    this.names = const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
  }) {
    startTurnTimer();
  }

  final Repository repo;
  final ChainEngine engine;
  @override
  final int turnSeconds;
  final void Function(Mark who)? onTimeout;
  final Map<Mark, String> names;

  String nameOf(Mark mark) => names[mark] ?? mark.symbol;

  Player get lastPlayer => repo.playerById(engine.lastPlayerId)!;
  Mark get current => engine.current;
  int get turnNumber => engine.turnNumber;
  int livesOf(Mark mark) => engine.livesLeft[mark]!;
  int get length => engine.length;
  bool get isOver => engine.isOver;
  Mark? get winner => engine.winner;
  Set<String> get usedPlayerIds => engine.usedPlayerIds;
  List<ChainLink> get links => engine.chain;

  /// Son oyuncunun kulüpleri; müsait olanlar önce.
  List<({Club club, int uses})> get lastPlayerClubs {
    final list = [
      for (final id in lastPlayer.clubs)
        (club: repo.club(id), uses: engine.usesOf(id)),
    ];
    list.sort((a, b) => a.uses.compareTo(b.uses));
    return list;
  }

  ChainResult answer(Player player) {
    final result = engine.answer(player.id);
    if (result.outcome == GuessResult.correct ||
        result.outcome == GuessResult.wrong) {
      _afterMove();
    }
    return result;
  }

  void pass() {
    if (isOver) return;
    engine.pass();
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
    engine.pass();
    _afterMove();
    onTimeout?.call(who);
  }

  @override
  void dispose() {
    stopTurnTimer();
    super.dispose();
  }
}
