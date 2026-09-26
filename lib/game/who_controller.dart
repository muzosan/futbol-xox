import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'engine/who_engine.dart';

export 'engine/who_engine.dart' show WhoEngine, WhoQuestion, WhoResult;

/// Zorluğa göre Kim Bu? soruları seçer (farklı oyunculardan).
List<WhoQuestion> pickWhoQuestions(Repository repo, String difficulty,
    {int count = 5, Random? random}) {
  final rnd = random ?? Random();
  // (en düşük popülerlik, en yüksek popülerlik)
  final (lo, hi) = switch (difficulty) {
    'kolay' => (35, 1 << 30),
    'orta' => (15, 50),
    _ => (8, 25),
  };
  final pool = repo.careers.where((c) {
    final p = repo.playerById(c.playerId);
    return p != null && p.popularity >= lo && p.popularity <= hi;
  }).toList()
    ..shuffle(rnd);
  final source = pool.length >= count ? pool : (repo.careers.toList()..shuffle(rnd));
  return source.take(count).map((c) {
    final p = repo.playerById(c.playerId);
    return WhoQuestion(
        playerId: c.playerId, steps: c.steps, birthYear: p?.birthYear);
  }).toList();
}

/// Yerel Kim Bu? oyunu (tek kişilik, süresiz).
class WhoController extends ChangeNotifier {
  WhoController({required this.repo, required this.engine});

  final Repository repo;
  final WhoEngine engine;

  Player answerPlayer() => repo.playerById(engine.current.playerId)!;

  void reveal() {
    engine.reveal();
    notifyListeners();
  }

  bool guess(Player player) {
    final correct = engine.guess(player.id);
    notifyListeners();
    return correct;
  }

  void giveUp() {
    engine.giveUp();
    notifyListeners();
  }

  void nextQuestion() {
    engine.nextQuestion();
    notifyListeners();
  }
}
