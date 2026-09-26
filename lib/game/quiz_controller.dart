import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'engine/quiz_engine.dart';

export 'engine/quiz_engine.dart' show QuizEngine, QuizQuestion;

/// Son cevabın özeti (ekrandaki geri bildirim satırı için).
class QuizFeedback {
  const QuizFeedback(this.correct, this.question);
  final bool correct;
  final QuizQuestion question;
}

/// Yerel Doğru mu Yanlış mı? oyunu: soru üretir ve toplam süreyi sayar.
class QuizController extends ChangeNotifier {
  QuizController({required this.repo, required this.difficulty, Random? random})
      : engine = QuizEngine(),
        _random = random ?? Random() {
    final minPopularity = switch (difficulty) {
      'kolay' => 30,
      'orta' => 15,
      _ => 6,
    };
    _pool = repo.players.where((p) => p.popularity >= minPopularity).toList();
    engine.current = _generate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      engine.tick();
      if (engine.isOver) _timer?.cancel();
      notifyListeners();
    });
  }

  final Repository repo;
  final String difficulty;
  final QuizEngine engine;
  final Random _random;
  late final List<Player> _pool;
  Timer? _timer;
  QuizFeedback? lastFeedback;

  QuizQuestion get question => engine.current!;
  Player get questionPlayer => repo.playerById(question.playerId)!;
  Club get questionClub => repo.club(question.clubId);
  bool get isOver => engine.isOver;

  void answer(bool saysPlayed) {
    if (isOver) return;
    final q = question;
    final correct = engine.answer(saysPlayed);
    lastFeedback = QuizFeedback(correct, q);
    if (engine.isOver) {
      _timer?.cancel();
    } else {
      engine.current = _generate(previous: q.playerId);
    }
    notifyListeners();
  }

  /// Yarı yarıya doğru/yanlış soru. Yanlış sorular inandırıcı olsun diye,
  /// oyuncunun oynadığı liglerden, oynamadığı bir kulüp seçilir.
  QuizQuestion _generate({String? previous}) {
    while (true) {
      final p = _pool[_random.nextInt(_pool.length)];
      if (p.id == previous) continue;
      if (_random.nextBool()) {
        final clubs = p.clubs.toList();
        return QuizQuestion(p.id, clubs[_random.nextInt(clubs.length)], true);
      }
      final leagues = p.clubs.map((c) => repo.club(c).league).toSet();
      final options = repo.clubs.values
          .where((c) => leagues.contains(c.league) && !p.clubs.contains(c.id))
          .toList();
      if (options.isEmpty) continue;
      return QuizQuestion(
          p.id, options[_random.nextInt(options.length)].id, false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
