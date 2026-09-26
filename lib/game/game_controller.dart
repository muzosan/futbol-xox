import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models.dart';

enum Mark { x, o }

extension MarkInfo on Mark {
  Mark get other => this == Mark.x ? Mark.o : Mark.x;
  String get symbol => this == Mark.x ? 'X' : 'O';
  String get playerName => this == Mark.x ? 'Oyuncu 1' : 'Oyuncu 2';
}

enum GuessResult { correct, wrong, alreadyUsed, invalid }

enum EndReason { line, boardFull, stalemate }

class FilledCell {
  const FilledCell(this.player, this.owner);
  final Player player;
  final Mark owner;
}

/// Oyunun bütün kuralları burada. Ekran sadece bu sınıfı dinler ve çizer.
/// Online moda geçince aynı kurallar sunucu tarafında da kullanılacak.
class GameController extends ChangeNotifier {
  GameController({
    required this.grid,
    this.turnSeconds = 30,
    this.onTimeout,
  }) : secondsLeft = turnSeconds {
    _startTimer();
  }

  final PuzzleGrid grid;
  final int turnSeconds;

  /// Süre dolunca çağrılır (sırası geçen oyuncu parametre olarak gelir).
  final void Function(Mark who)? onTimeout;

  /// Üst üste bu kadar tur kimse doğru cevap veremezse oyun berabere biter.
  static const int maxTurnsWithoutProgress = 6;

  static const List<List<int>> _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // yatay
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // dikey
    [0, 4, 8], [2, 4, 6], // çapraz
  ];

  final List<FilledCell?> cells = List<FilledCell?>.filled(9, null);
  final Set<String> usedPlayerIds = {};

  Mark current = Mark.x;
  int turnNumber = 0;
  int secondsLeft;

  Mark? winner;
  bool isDraw = false;
  List<int>? winningLine;
  EndReason? endReason;

  int _turnsWithoutProgress = 0;
  Timer? _timer;

  bool get isOver => winner != null || isDraw;

  String rowClubId(int cell) => grid.rows[cell ~/ 3];
  String colClubId(int cell) => grid.cols[cell % 3];

  int cellCount(Mark mark) => cells.where((c) => c?.owner == mark).length;

  bool isCorrect(Player player, int cell) =>
      player.clubs.contains(rowClubId(cell)) &&
      player.clubs.contains(colClubId(cell));

  GuessResult guess(int cell, Player player) {
    if (isOver || cells[cell] != null) return GuessResult.invalid;
    if (usedPlayerIds.contains(player.id)) return GuessResult.alreadyUsed;

    if (!isCorrect(player, cell)) {
      _endTurn(progress: false);
      return GuessResult.wrong;
    }

    cells[cell] = FilledCell(player, current);
    usedPlayerIds.add(player.id);
    _endTurn(progress: true);
    return GuessResult.correct;
  }

  void pass() {
    if (isOver) return;
    _endTurn(progress: false);
  }

  void _endTurn({required bool progress}) {
    _turnsWithoutProgress = progress ? 0 : _turnsWithoutProgress + 1;
    _checkGameOver();

    if (isOver) {
      _timer?.cancel();
    } else {
      current = current.other;
      turnNumber++;
      secondsLeft = turnSeconds;
      _startTimer();
    }
    notifyListeners();
  }

  void _checkGameOver() {
    for (final line in _lines) {
      final first = cells[line[0]];
      if (first != null &&
          cells[line[1]]?.owner == first.owner &&
          cells[line[2]]?.owner == first.owner) {
        winner = first.owner;
        winningLine = line;
        endReason = EndReason.line;
        return;
      }
    }
    if (cells.every((c) => c != null)) {
      isDraw = true;
      endReason = EndReason.boardFull;
    } else if (_turnsWithoutProgress >= maxTurnsWithoutProgress) {
      isDraw = true;
      endReason = EndReason.stalemate;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        final who = current;
        _endTurn(progress: false);
        onTimeout?.call(who);
      } else {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
