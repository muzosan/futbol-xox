import 'common.dart';

/// Kartlarda karşılaştırılan istatistikler
class CardStat {
  const CardStat(this.key, this.label, this.short, {this.money = false, this.since2012 = false});

  final String key;
  final String label;
  final String short;
  final bool money;

  /// Sadece 2012 sonrası Avrupa verisini kapsıyor mu (ekranda belirtilir)
  final bool since2012;

  String format(num v) {
    if (!money) return '${v.round()}';
    if (v >= 10) return '€${v.round()}M';
    return '€${v.toStringAsFixed(1)}M';
  }
}

const List<CardStat> kCardStats = [
  CardStat('g', 'Gol', 'GOL', since2012: true),
  CardStat('a', 'Asist', 'AST', since2012: true),
  CardStat('m', 'Maç', 'MAÇ', since2012: true),
  CardStat('r', 'Kırmızı Kart', 'KRM', since2012: true),
  CardStat('y', 'Sarı Kart', 'SARI', since2012: true),
  CardStat('mm', 'Milli Maç', 'MİLLİ'),
  CardStat('pv', 'Piyasa Değeri', 'DEĞER', money: true),
];

CardStat cardStat(String key) => kCardStats.firstWhere((s) => s.key == key);

class DuelRound {
  const DuelRound({
    required this.chooser,
    required this.stat,
    required this.x,
    required this.o,
    required this.winner,
  });

  final Mark chooser;
  final String stat;
  final num x;
  final num o;
  final Mark? winner; // null = berabere

  Map<String, dynamic> toJson() =>
      {'c': chooser.name, 's': stat, 'x': x, 'o': o, 'w': winner?.name};
}

/// Kart Düellosu kuralları:
/// - İki oyuncunun da [rounds] kartlık destesi var; her tur sıradaki kartlar karşılaşır.
/// - Sırası gelen (turlar sırayla değişir) kendi kartına bakıp bir istatistik seçer.
/// - Değeri yüksek olan turu kazanır; eşitlikte kimse puan almaz.
class DuelEngine {
  DuelEngine({required this.decks, required this.statOf, this.rounds = 7});

  final Map<Mark, List<String>> decks;
  final num Function(String playerId, String stat) statOf;
  final int rounds;

  int index = 0;
  int turnNumber = 0;

  /// Bu turun kartları açıldı mı
  bool revealed = false;
  final Map<Mark, int> points = {Mark.x: 0, Mark.o: 0};
  final List<DuelRound> history = [];

  Mark get chooser => index.isEven ? Mark.x : Mark.o;
  String cardOf(Mark mark) => decks[mark]![index];
  DuelRound? get currentRound => revealed ? history.last : null;
  bool get isOver => revealed && index >= rounds - 1;

  Mark? get winner {
    if (!isOver) return null;
    final x = points[Mark.x]!, o = points[Mark.o]!;
    if (x == o) return null;
    return x > o ? Mark.x : Mark.o;
  }

  bool get isDraw => isOver && points[Mark.x] == points[Mark.o];

  DuelRound? pick(String stat) {
    if (revealed) return null;
    final x = statOf(cardOf(Mark.x), stat);
    final o = statOf(cardOf(Mark.o), stat);
    final w = x > o ? Mark.x : (o > x ? Mark.o : null);
    if (w != null) points[w] = points[w]! + 1;
    final round = DuelRound(chooser: chooser, stat: stat, x: x, o: o, winner: w);
    history.add(round);
    revealed = true;
    turnNumber++;
    return round;
  }

  void next() {
    if (!revealed || isOver) return;
    index++;
    revealed = false;
    turnNumber++;
  }

  Map<String, dynamic> toJson() => {
        'mode': 'duel',
        'decks': {for (final e in decks.entries) e.key.name: e.value},
        'rounds': rounds,
        'index': index,
        'revealed': revealed,
        'history': [for (final r in history) r.toJson()],
      };
}
