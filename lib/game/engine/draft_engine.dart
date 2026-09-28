import 'common.dart';

/// Kadroya yapılan bir seçim (oyuncu null ise süre doldu / pas geçildi)
class DraftPick {
  const DraftPick(this.playerId, this.value);
  final String? playerId;
  final num value;

  Map<String, dynamic> toJson() => {'p': playerId, 'v': value};
}

class DraftResult {
  const DraftResult(this.outcome, [this.value = 0]);
  final GuessResult outcome;
  final num value;
}

/// Kadro Kur kuralları:
/// - Bir ölçüt (ör. gol) ve [clubs.length] tur var; her tur bir kulüp gelir.
/// - İki oyuncu da her turda o kulüpte oynamış bir futbolcu seçer; futbolcunun
///   ölçütteki değeri kadroya eklenir. Toplamı yüksek olan kazanır.
/// - Her turda ilk seçen oyuncu değişir; seçilen futbolcuyu rakip seçemez.
/// - Yanlış seçim (kulüpte oynamamış) puan getirmez ama sıra geçmez;
///   süre dolunca o tur 0 puanla geçilir ([skip]).
class DraftEngine {
  DraftEngine({
    required this.criterion,
    required this.clubs,
    required this.clubsOf,
    required this.statOf,
  })  : picks = {
          Mark.x: List<DraftPick?>.filled(clubs.length, null),
          Mark.o: List<DraftPick?>.filled(clubs.length, null),
        },
        current = Mark.x;

  final String criterion;
  final List<String> clubs;
  final ClubsOf clubsOf;
  final num Function(String playerId, String stat) statOf;

  final Map<Mark, List<DraftPick?>> picks;
  final Set<String> usedPlayerIds = {};
  int round = 0;
  Mark current;
  int turnNumber = 0;

  int get rounds => clubs.length;
  bool get isOver => round >= rounds;
  String get currentClub => clubs[round];

  /// Turda ilk seçen: çift turlarda X, tek turlarda O
  Mark firstOf(int r) => r.isEven ? Mark.x : Mark.o;

  num total(Mark m) =>
      picks[m]!.fold<num>(0, (sum, p) => sum + (p?.value ?? 0));

  Mark? get winner {
    if (!isOver) return null;
    final x = total(Mark.x), o = total(Mark.o);
    if (x == o) return null;
    return x > o ? Mark.x : Mark.o;
  }

  bool get isDraw => isOver && total(Mark.x) == total(Mark.o);

  DraftResult pick(String playerId) {
    if (isOver) return const DraftResult(GuessResult.invalid);
    if (usedPlayerIds.contains(playerId)) {
      return const DraftResult(GuessResult.alreadyUsed);
    }
    if (!clubsOf(playerId).contains(currentClub)) {
      return const DraftResult(GuessResult.wrong);
    }
    final value = statOf(playerId, criterion);
    picks[current]![round] = DraftPick(playerId, value);
    usedPlayerIds.add(playerId);
    _advance();
    return DraftResult(GuessResult.correct, value);
  }

  /// Süre doldu / pas: bu tur 0 puan
  void skip() {
    if (isOver) return;
    picks[current]![round] = const DraftPick(null, 0);
    _advance();
  }

  void _advance() {
    turnNumber++;
    if (current == firstOf(round)) {
      current = current.other; // aynı turda rakibin seçimi
    } else {
      round++;
      if (!isOver) current = firstOf(round);
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': 'draft',
        'criterion': criterion,
        'clubs': clubs,
        'round': round,
        'current': current.name,
        'picks': {
          for (final e in picks.entries)
            e.key.name: [for (final p in e.value) p?.toJson()],
        },
      };
}
