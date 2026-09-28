import 'dart:math';

enum ImposterPhase { reveal, clues, voting, impostorGuess, result }

/// Sahtekâr kuralları (tek telefonda elden ele, 3-8 kişi):
/// - Herkes gizli futbolcuyu görür, sahtekâr görmez.
/// - [clueRounds] tur boyunca sırayla herkes tek kelimelik ipucu söyler.
/// - Gizli oylama: en çok oyu alan suçlanır (eşitlikte kimse suçlanmaz).
/// - Sahtekâr yakalanırsa futbolcuyu tahmin ederek kurtulabilir.
/// Puanlar:
///   yakalandı ve tahmin tutmadı -> masumlar +1, sahtekârı oylayanlar +1 daha
///   yakalanmadı                 -> sahtekâr +3
///   yakalandı ama doğru tahmin  -> sahtekâr +2
class ImposterEngine {
  ImposterEngine({required this.names, this.clueRounds = 3, Random? random})
      : _random = random ?? Random(),
        scores = List<int>.filled(names.length, 0);

  final List<String> names;
  final int clueRounds;
  final Random _random;
  final List<int> scores;

  late String secretPlayerId;
  late int impostor;
  late List<int> order; // ipucu sırası
  ImposterPhase phase = ImposterPhase.reveal;
  int roundNumber = 0;

  int revealIndex = 0;
  int clueRound = 0;
  int clueIndex = 0;
  int voterIndex = 0;
  final Map<int, int> votes = {}; // oy veren -> oylanan
  int? accused;
  bool? impostorGuessedRight;

  int get playerCount => names.length;
  int get currentSpeaker => order[clueIndex];

  /// Yeni tur: yeni futbolcu, yeni sahtekâr, karışık ipucu sırası
  void startRound(String secretId) {
    roundNumber++;
    secretPlayerId = secretId;
    impostor = _random.nextInt(playerCount);
    order = List.generate(playerCount, (i) => i)..shuffle(_random);
    // Sahtekâr ilk konuşan olmasın (ilk ipucunu uydurmak çok zor)
    if (order.first == impostor && playerCount > 1) {
      order
        ..removeAt(0)
        ..insert(1 + _random.nextInt(playerCount - 1), impostor);
    }
    phase = ImposterPhase.reveal;
    revealIndex = 0;
    clueRound = 0;
    clueIndex = 0;
    voterIndex = 0;
    votes.clear();
    accused = null;
    impostorGuessedRight = null;
  }

  void nextReveal() {
    if (phase != ImposterPhase.reveal) return;
    revealIndex++;
    if (revealIndex >= playerCount) phase = ImposterPhase.clues;
  }

  void nextClue() {
    if (phase != ImposterPhase.clues) return;
    clueIndex++;
    if (clueIndex >= playerCount) {
      clueIndex = 0;
      clueRound++;
      if (clueRound >= clueRounds) phase = ImposterPhase.voting;
    }
  }

  void vote(int target) {
    if (phase != ImposterPhase.voting || target == voterIndex) return;
    votes[voterIndex] = target;
    voterIndex++;
    if (voterIndex >= playerCount) _finishVoting();
  }

  Map<int, int> get tally {
    final t = <int, int>{};
    for (final v in votes.values) {
      t[v] = (t[v] ?? 0) + 1;
    }
    return t;
  }

  void _finishVoting() {
    final t = tally;
    final maxVotes = t.values.fold<int>(0, max);
    final top = t.entries.where((e) => e.value == maxVotes).map((e) => e.key).toList();
    accused = top.length == 1 ? top.first : null; // eşitlik: kimse suçlanmaz
    if (accused == impostor) {
      phase = ImposterPhase.impostorGuess;
    } else {
      scores[impostor] += 3;
      phase = ImposterPhase.result;
    }
  }

  /// Yakalanan sahtekârın futbolcu tahmini
  void impostorGuess(String playerId) {
    if (phase != ImposterPhase.impostorGuess) return;
    impostorGuessedRight = playerId == secretPlayerId;
    if (impostorGuessedRight!) {
      scores[impostor] += 2;
    } else {
      for (var i = 0; i < playerCount; i++) {
        if (i == impostor) continue;
        scores[i] += 1;
        if (votes[i] == impostor) scores[i] += 1;
      }
    }
    phase = ImposterPhase.result;
  }

  /// Sonuç: masumlar mı kazandı?
  bool get innocentsWon =>
      accused == impostor && impostorGuessedRight == false;
}
