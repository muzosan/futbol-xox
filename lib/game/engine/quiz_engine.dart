/// "X futbolcusu Y kulübünde oynadı mı?" sorusu.
class QuizQuestion {
  const QuizQuestion(this.playerId, this.clubId, this.isTrue);

  final String playerId;
  final String clubId;
  final bool isTrue;

  Map<String, dynamic> toJson() => {'p': playerId, 'c': clubId, 't': isTrue};

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        json['p'] as String,
        json['c'] as String,
        json['t'] as bool,
      );
}

/// Doğru mu Yanlış mı? kuralları:
/// - Toplam [durationSeconds] saniye var; her doğru cevap +1 puan.
/// - Yanlış cevap süreden [penaltySeconds] saniye götürür ve seriyi bozar.
/// Soruları dışarıdan gelen üretici belirler (uygulamada veya sunucuda).
class QuizEngine {
  QuizEngine({this.durationSeconds = 60, this.penaltySeconds = 5})
      : timeLeft = durationSeconds;

  final int durationSeconds;
  final int penaltySeconds;

  QuizQuestion? current;
  int timeLeft;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int answered = 0;

  bool get isOver => timeLeft <= 0;

  /// [saysPlayed]: oyuncunun cevabı ("Oynadı" = true). Doğruysa true döner.
  bool answer(bool saysPlayed) {
    final q = current;
    if (isOver || q == null) return false;
    answered++;
    final correct = saysPlayed == q.isTrue;
    if (correct) {
      score++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
      timeLeft = timeLeft > penaltySeconds ? timeLeft - penaltySeconds : 0;
    }
    return correct;
  }

  void tick() {
    if (timeLeft > 0) timeLeft--;
  }
}
