import 'common.dart';

enum EndReason { line, boardFull, stalemate }

class XoxCell {
  const XoxCell(this.playerId, this.owner);

  final String playerId;
  final Mark owner;

  Map<String, dynamic> toJson() => {'p': playerId, 'o': owner.name};

  factory XoxCell.fromJson(Map<String, dynamic> json) =>
      XoxCell(json['p'] as String, markFromName(json['o'] as String));
}

/// XOX kuralları: 3x3 tablo, satır ve sütundaki iki kulüpte de oynamış
/// oyuncuyu bulan hücreyi alır, üçlüyü yapan kazanır.
class XoxEngine {
  XoxEngine({
    required this.gridId,
    required this.rows,
    required this.cols,
    required this.clubsOf,
  });

  /// Üst üste bu kadar tur kimse doğru cevap veremezse oyun berabere biter.
  static const int maxTurnsWithoutProgress = 6;

  static const List<List<int>> lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // yatay
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // dikey
    [0, 4, 8], [2, 4, 6], // çapraz
  ];

  final String gridId;
  final List<String> rows;
  final List<String> cols;
  final ClubsOf clubsOf;

  final List<XoxCell?> cells = List<XoxCell?>.filled(9, null);
  final Set<String> usedPlayerIds = {};
  Mark current = Mark.x;
  int turnNumber = 0;
  Mark? winner;
  bool isDraw = false;
  List<int>? winningLine;
  EndReason? endReason;
  int turnsWithoutProgress = 0;

  bool get isOver => winner != null || isDraw;

  String rowClubId(int cell) => rows[cell ~/ 3];
  String colClubId(int cell) => cols[cell % 3];

  bool isCorrect(String playerId, int cell) {
    final clubs = clubsOf(playerId);
    return clubs.contains(rowClubId(cell)) && clubs.contains(colClubId(cell));
  }

  GuessResult guess(int cell, String playerId) {
    if (isOver || cells[cell] != null) return GuessResult.invalid;
    if (usedPlayerIds.contains(playerId)) return GuessResult.alreadyUsed;

    if (!isCorrect(playerId, cell)) {
      _endTurn(progress: false);
      return GuessResult.wrong;
    }
    cells[cell] = XoxCell(playerId, current);
    usedPlayerIds.add(playerId);
    _endTurn(progress: true);
    return GuessResult.correct;
  }

  /// Pas geçme veya süre dolması.
  void pass() {
    if (isOver) return;
    _endTurn(progress: false);
  }

  void _endTurn({required bool progress}) {
    turnsWithoutProgress = progress ? 0 : turnsWithoutProgress + 1;
    _checkGameOver();
    if (!isOver) {
      current = current.other;
      turnNumber++;
    }
  }

  void _checkGameOver() {
    for (final line in lines) {
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
    } else if (turnsWithoutProgress >= maxTurnsWithoutProgress) {
      isDraw = true;
      endReason = EndReason.stalemate;
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': 'xox',
        'gridId': gridId,
        'rows': rows,
        'cols': cols,
        'cells': [for (final c in cells) c?.toJson()],
        'used': usedPlayerIds.toList(),
        'current': current.name,
        'turn': turnNumber,
        'winner': winner?.name,
        'draw': isDraw,
        'line': winningLine,
        'end': endReason?.name,
        'noProgress': turnsWithoutProgress,
      };

  factory XoxEngine.fromJson(Map<String, dynamic> json, ClubsOf clubsOf) {
    final e = XoxEngine(
      gridId: json['gridId'] as String,
      rows: (json['rows'] as List).cast<String>(),
      cols: (json['cols'] as List).cast<String>(),
      clubsOf: clubsOf,
    );
    final cells = json['cells'] as List;
    for (var i = 0; i < 9; i++) {
      final c = cells[i];
      e.cells[i] = c == null ? null : XoxCell.fromJson(c as Map<String, dynamic>);
    }
    e.usedPlayerIds.addAll((json['used'] as List).cast<String>());
    e.current = markFromName(json['current'] as String);
    e.turnNumber = json['turn'] as int;
    e.winner = json['winner'] == null ? null : markFromName(json['winner'] as String);
    e.isDraw = json['draw'] as bool;
    e.winningLine = (json['line'] as List?)?.cast<int>();
    e.endReason = json['end'] == null
        ? null
        : EndReason.values.byName(json['end'] as String);
    e.turnsWithoutProgress = json['noProgress'] as int;
    return e;
  }
}
