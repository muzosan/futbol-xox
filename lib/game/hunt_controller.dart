import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'engine/common.dart';
import 'engine/hunt_engine.dart';
import 'turn_timer.dart';

export 'engine/hunt_engine.dart' show HuntMove, HuntResult, HuntEngine;

/// Yerel Kulüp Avı oyunu: kuralları [HuntEngine]'e bırakır, üstüne zamanlayıcı ekler.
class HuntController extends ChangeNotifier with TurnTimer {
  HuntController({
    required this.repo,
    required this.engine,
    this.turnSeconds = 30,
    this.onTimeout,
    this.names = const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
  }) {
    startTurnTimer();
  }

  final Repository repo;
  final HuntEngine engine;
  @override
  final int turnSeconds;
  final void Function(Mark who)? onTimeout;
  final Map<Mark, String> names;

  String nameOf(Mark mark) => names[mark] ?? mark.symbol;

  List<Club> get clubs => engine.currentClubs.map(repo.club).toList();
  int get round => engine.roundIndex;
  int get totalRounds => engine.totalRounds;
  Mark get current => engine.current;
  int get turnNumber => engine.turnNumber;
  int score(Mark mark) => engine.scores[mark]!;
  int movesLeft(Mark mark) => engine.movesLeft(mark);
  bool get awaitingNextRound => engine.awaitingNextRound;
  bool get isOver => engine.isOver;
  Mark? get winner => engine.winner;
  bool get isDraw => engine.isDraw;
  Set<String> get usedPlayerIds => engine.usedPlayerIds;
  List<HuntMove> get roundMoves => engine.roundMoves.toList();

  HuntResult answer(Player player) {
    final result = engine.answer(player.id);
    if (result.outcome == GuessResult.correct ||
        result.outcome == GuessResult.wrong) {
      _afterMove();
    }
    return result;
  }

  void pass() {
    if (awaitingNextRound || isOver) return;
    engine.pass();
    _afterMove();
  }

  void nextRound() {
    if (!awaitingNextRound || isOver) return;
    engine.startNextRound();
    startTurnTimer();
    notifyListeners();
  }

  /// Bu turda kullanılmamış en iyi cevaplar (tur sonu "kaçırdıkların" için).
  List<({Player player, int count})> missedAnswers({int limit = 5}) => repo
      .multiClubPlayers(engine.currentClubs)
      .where((e) => !usedPlayerIds.contains(e.player.id))
      .take(limit)
      .toList();

  void _afterMove() {
    if (engine.awaitingNextRound) {
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
