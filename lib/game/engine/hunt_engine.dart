import 'common.dart';

/// Kulüp Avı'nda yapılan bir hamle.
class HuntMove {
  const HuntMove({
    required this.round,
    required this.mark,
    required this.playerId,
    required this.clubs,
    required this.points,
  });

  final int round;
  final Mark mark;

  /// null ise pas geçildi (veya süre doldu).
  final String? playerId;

  /// O turun 5 kulübünden oyuncunun oynadıkları.
  final List<String> clubs;
  final int points;

  bool get isPass => playerId == null;

  Map<String, dynamic> toJson() => {
        'r': round,
        'm': mark.name,
        'p': playerId,
        'c': clubs,
        'pt': points,
      };

  factory HuntMove.fromJson(Map<String, dynamic> json) => HuntMove(
        round: json['r'] as int,
        mark: markFromName(json['m'] as String),
        playerId: json['p'] as String?,
        clubs: (json['c'] as List).cast<String>(),
        points: json['pt'] as int,
      );
}

class HuntResult {
  const HuntResult(this.outcome, [this.move]);
  final GuessResult outcome;
  final HuntMove? move;
}

/// Kulüp Avı kuralları:
/// - Her turda 5 kulüp var; oyuncular sırayla futbolcu yazar.
/// - Futbolcu bu 5 kulüpten en az ikisinde oynamış olmalı; kaç kulüpte
///   oynadıysa puan o kadar artar.
/// - Her oyuncunun turda [movesPerRound] hamlesi var; sonra yeni tur başlar.
/// - Aynı futbolcu maç boyunca bir kez kullanılabilir.
class HuntEngine {
  HuntEngine({
    required this.rounds,
    required this.clubsOf,
    this.movesPerRound = 3,
  });

  static const Map<int, int> pointTable = {2: 1, 3: 3, 4: 6, 5: 10};
  static int pointsFor(int clubCount) => pointTable[clubCount] ?? 0;

  final List<List<String>> rounds;
  final ClubsOf clubsOf;
  final int movesPerRound;

  int roundIndex = 0;
  int movesInRound = 0;
  Mark current = Mark.x;
  int turnNumber = 0;

  /// Tur bitti, bir sonraki tur başlamadan önce özet gösteriliyor.
  bool awaitingNextRound = false;

  final Map<Mark, int> scores = {Mark.x: 0, Mark.o: 0};
  final Set<String> usedPlayerIds = {};
  final List<HuntMove> history = [];

  int get totalRounds => rounds.length;
  List<String> get currentClubs => rounds[roundIndex];

  bool get isOver => awaitingNextRound && roundIndex >= rounds.length - 1;

  Mark? get winner {
    if (!isOver) return null;
    final x = scores[Mark.x]!, o = scores[Mark.o]!;
    if (x == o) return null;
    return x > o ? Mark.x : Mark.o;
  }

  bool get isDraw => isOver && scores[Mark.x] == scores[Mark.o];

  /// Her turu sırayla farklı oyuncu başlatır (adil olsun diye).
  Mark get roundStarter => roundIndex.isEven ? Mark.x : Mark.o;

  Iterable<HuntMove> get roundMoves =>
      history.where((m) => m.round == roundIndex);

  int movesLeft(Mark mark) =>
      movesPerRound - roundMoves.where((m) => m.mark == mark).length;

  List<String> matchingClubs(String playerId) {
    final clubs = clubsOf(playerId);
    return currentClubs.where(clubs.contains).toList();
  }

  HuntResult answer(String playerId) {
    if (isOver || awaitingNextRound) return const HuntResult(GuessResult.invalid);
    if (usedPlayerIds.contains(playerId)) {
      return const HuntResult(GuessResult.alreadyUsed);
    }
    final matched = matchingClubs(playerId);
    final correct = matched.length >= 2;
    final move = HuntMove(
      round: roundIndex,
      mark: current,
      playerId: playerId,
      clubs: matched,
      points: correct ? pointsFor(matched.length) : 0,
    );
    if (correct) {
      usedPlayerIds.add(playerId);
      scores[current] = scores[current]! + move.points;
    }
    _record(move);
    return HuntResult(correct ? GuessResult.correct : GuessResult.wrong, move);
  }

  /// Pas geçme veya süre dolması.
  void pass() {
    if (isOver || awaitingNextRound) return;
    _record(HuntMove(
      round: roundIndex,
      mark: current,
      playerId: null,
      clubs: const [],
      points: 0,
    ));
  }

  void _record(HuntMove move) {
    history.add(move);
    movesInRound++;
    turnNumber++;
    if (movesInRound >= movesPerRound * 2) {
      awaitingNextRound = true;
    } else {
      current = current.other;
    }
  }

  void startNextRound() {
    if (!awaitingNextRound || isOver) return;
    roundIndex++;
    movesInRound = 0;
    awaitingNextRound = false;
    current = roundStarter;
    turnNumber++;
  }

  Map<String, dynamic> toJson() => {
        'mode': 'hunt',
        'rounds': rounds,
        'movesPerRound': movesPerRound,
        'roundIndex': roundIndex,
        'movesInRound': movesInRound,
        'current': current.name,
        'turn': turnNumber,
        'awaiting': awaitingNextRound,
        'scores': {for (final e in scores.entries) e.key.name: e.value},
        'used': usedPlayerIds.toList(),
        'history': [for (final m in history) m.toJson()],
      };

  factory HuntEngine.fromJson(Map<String, dynamic> json, ClubsOf clubsOf) {
    final e = HuntEngine(
      rounds: (json['rounds'] as List)
          .map((r) => (r as List).cast<String>().toList())
          .toList(),
      clubsOf: clubsOf,
      movesPerRound: json['movesPerRound'] as int,
    );
    e.roundIndex = json['roundIndex'] as int;
    e.movesInRound = json['movesInRound'] as int;
    e.current = markFromName(json['current'] as String);
    e.turnNumber = json['turn'] as int;
    e.awaitingNextRound = json['awaiting'] as bool;
    final scores = json['scores'] as Map<String, dynamic>;
    e.scores[Mark.x] = scores['x'] as int;
    e.scores[Mark.o] = scores['o'] as int;
    e.usedPlayerIds.addAll((json['used'] as List).cast<String>());
    e.history.addAll((json['history'] as List)
        .map((m) => HuntMove.fromJson(m as Map<String, dynamic>)));
    return e;
  }
}
