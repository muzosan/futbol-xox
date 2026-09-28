import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'engine/who_engine.dart';

export 'engine/who_engine.dart' show WhoEngine, WhoQuestion, WhoResult;

/// Zorluğa göre açık başlayan ipucu sayısı: kolayda ilk iki kulüp açık.
int whoStartRevealed(String difficulty) => difficulty == 'kolay' ? 2 : 1;

/// Zorluğa göre Kim Bu? soruları seçer (farklı oyunculardan).
/// kolay: en az 2 büyük kulüpte oynamış yıldızlar
/// orta : en az 1 büyük/tanınmış kulüpte oynamış tanınmış oyuncular
/// zor  : daha az bilinen oyuncular
List<WhoQuestion> pickWhoQuestions(Repository repo, String difficulty,
    {int count = 5, Random? random}) {
  final rnd = random ?? Random();
  final (lo, hi, maxTier, minBigClubs) = switch (difficulty) {
    'kolay' => (50, 1 << 30, 1, 2),
    'orta' => (25, 1 << 30, 2, 1),
    _ => (8, 30, 3, 0),
  };
  bool fits(Player p) =>
      p.popularity >= lo &&
      p.popularity <= hi &&
      repo.bigClubCount(p, maxTier) >= minBigClubs;

  var pool = repo.careers.where((c) {
    final p = repo.playerById(c.playerId);
    return p != null && fits(p);
  }).toList();
  if (pool.length < count) pool = repo.careers.toList(); // yedek
  pool.shuffle(rnd);
  return pool.take(count).map((c) {
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
