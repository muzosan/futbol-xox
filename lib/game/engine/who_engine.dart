import 'dart:math';

import '../../data/models.dart';

class WhoQuestion {
  const WhoQuestion({
    required this.playerId,
    required this.steps,
    this.birthYear,
  });

  final String playerId;
  final List<CareerStep> steps;

  /// Kariyer bitince açılabilecek son ipucu
  final int? birthYear;

  Map<String, dynamic> toJson() => {
        'p': playerId,
        'c': [for (final s in steps) [s.club, s.year]],
        'y': birthYear,
      };

  factory WhoQuestion.fromJson(Map<String, dynamic> json) => WhoQuestion(
        playerId: json['p'] as String,
        steps: (json['c'] as List)
            .map((s) => CareerStep((s as List)[0] as String, s[1] as int?))
            .toList(),
        birthYear: json['y'] as int?,
      );
}

class WhoResult {
  const WhoResult(this.playerId, this.solved, this.points);
  final String playerId;
  final bool solved;
  final int points;
}

/// Kim Bu? kuralları:
/// - Bir futbolcunun kariyerindeki kulüpler sırayla açılır; ilk kulüp açık başlar.
/// - Her soru [maxPoints] puandan başlar. Açılan her ek ipucu [clueCost],
///   her yanlış tahmin [wrongCost] puan götürür (en az 1 puan kalır).
/// - [maxWrong] yanlış tahminden sonra soru kaybedilir; pes etmek 0 puandır.
class WhoEngine {
  WhoEngine({
    required this.questions,
    this.maxWrong = 3,
    this.maxPoints = 10,
    this.clueCost = 2,
    this.wrongCost = 1,
  });

  final List<WhoQuestion> questions;
  final int maxWrong;
  final int maxPoints;
  final int clueCost;
  final int wrongCost;

  int index = 0;
  int revealed = 1;
  int wrongGuesses = 0;
  int score = 0;

  /// Mevcut soru bitti mi (bilindi, pes edildi veya haklar tükendi)
  bool resolved = false;
  final List<WhoResult> results = [];

  WhoQuestion get current => questions[index];
  int get totalQuestions => questions.length;
  bool get isLastQuestion => index >= questions.length - 1;
  bool get isOver => resolved && isLastQuestion;
  WhoResult? get lastResult => results.isEmpty ? null : results.last;

  /// Kariyer durakları + (varsa) doğum yılı
  int get totalClues =>
      current.steps.length + (current.birthYear != null ? 1 : 0);
  bool get canReveal => !resolved && revealed < totalClues;
  bool get birthYearRevealed =>
      current.birthYear != null && revealed > current.steps.length;

  /// Şu an bilinirse kazanılacak puan
  int get potentialPoints => max(
      1, maxPoints - (revealed - 1) * clueCost - wrongGuesses * wrongCost);

  void reveal() {
    if (canReveal) revealed++;
  }

  /// Tahmin doğruysa true döner.
  bool guess(String playerId) {
    if (resolved) return false;
    if (playerId == current.playerId) {
      final points = potentialPoints;
      score += points;
      _resolve(solved: true, points: points);
      return true;
    }
    wrongGuesses++;
    if (wrongGuesses >= maxWrong) _resolve(solved: false, points: 0);
    return false;
  }

  void giveUp() {
    if (!resolved) _resolve(solved: false, points: 0);
  }

  void _resolve({required bool solved, required int points}) {
    resolved = true;
    revealed = totalClues; // cevapla birlikte bütün kariyer görünsün
    results.add(WhoResult(current.playerId, solved, points));
  }

  void nextQuestion() {
    if (!resolved || isLastQuestion) return;
    index++;
    revealed = 1;
    wrongGuesses = 0;
    resolved = false;
  }
}
