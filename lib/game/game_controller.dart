import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'engine/common.dart';
import 'engine/xox_engine.dart';
import 'turn_timer.dart';

export 'engine/common.dart';
export 'engine/xox_engine.dart' show EndReason;

class FilledCell {
  const FilledCell(this.player, this.owner);
  final Player player;
  final Mark owner;
}

/// Yerel XOX oyunu: kuralları [XoxEngine]'e bırakır, üstüne zamanlayıcı ekler
/// ve ekranın ihtiyaç duyduğu bilgileri (oyuncu isimleri vb.) sağlar.
class GameController extends ChangeNotifier with TurnTimer {
  GameController({
    required this.repo,
    required this.grid,
    this.turnSeconds = 30,
    this.onTimeout,
    this.names = const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
  }) : engine = XoxEngine(
          gridId: grid.id,
          rows: grid.rows,
          cols: grid.cols,
          clubsOf: repo.clubsOf,
        ) {
    startTurnTimer();
  }

  static const List<List<int>> lines = XoxEngine.lines;
  static const int maxTurnsWithoutProgress = XoxEngine.maxTurnsWithoutProgress;

  final Repository repo;
  final PuzzleGrid grid;
  @override
  final int turnSeconds;
  final void Function(Mark who)? onTimeout;
  final Map<Mark, String> names;
  final XoxEngine engine;

  String nameOf(Mark mark) => names[mark] ?? mark.symbol;

  List<FilledCell?> get cells => [
        for (final c in engine.cells)
          c == null ? null : FilledCell(repo.playerById(c.playerId)!, c.owner),
      ];

  Set<String> get usedPlayerIds => engine.usedPlayerIds;
  Mark get current => engine.current;
  int get turnNumber => engine.turnNumber;
  Mark? get winner => engine.winner;
  bool get isDraw => engine.isDraw;
  bool get isOver => engine.isOver;
  List<int>? get winningLine => engine.winningLine;
  EndReason? get endReason => engine.endReason;

  String rowClubId(int cell) => engine.rowClubId(cell);
  String colClubId(int cell) => engine.colClubId(cell);

  int cellCount(Mark mark) =>
      engine.cells.where((c) => c?.owner == mark).length;

  GuessResult guess(int cell, Player player) {
    final result = engine.guess(cell, player.id);
    if (result == GuessResult.correct || result == GuessResult.wrong) {
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
