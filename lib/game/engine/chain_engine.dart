import 'common.dart';

/// Zincirin bir halkası.
class ChainLink {
  const ChainLink({
    required this.playerId,
    required this.viaClub,
    required this.mark,
  });

  final String playerId;

  /// Bir önceki oyuncuyla bağlantıyı kuran kulüp (başlangıç oyuncusunda null)
  final String? viaClub;

  /// Halkayı ekleyen oyuncu (başlangıç oyuncusunda null)
  final Mark? mark;

  Map<String, dynamic> toJson() =>
      {'p': playerId, 'v': viaClub, 'm': mark?.name};

  factory ChainLink.fromJson(Map<String, dynamic> json) => ChainLink(
        playerId: json['p'] as String,
        viaClub: json['v'] as String?,
        mark: json['m'] == null ? null : markFromName(json['m'] as String),
      );
}

enum ChainFail { none, noSharedClub, clubLimit }

class ChainResult {
  const ChainResult(this.outcome, {this.link, this.fail = ChainFail.none});
  final GuessResult outcome;
  final ChainLink? link;
  final ChainFail fail;
}

/// Kariyer Zinciri kuralları:
/// - Bir başlangıç futbolcusu var. Sıradaki oyuncu, zincirdeki son futbolcuyla
///   aynı kulüpte oynamış başka bir futbolcu yazmalı.
/// - Aynı futbolcu tekrar kullanılamaz; bir kulüp üzerinden en fazla
///   [maxClubUses] bağlantı kurulabilir.
/// - Yanlış cevap, pas veya süre dolması bir can götürür; canı biten kaybeder.
class ChainEngine {
  ChainEngine({
    required this.startPlayerId,
    required this.clubsOf,
    this.lives = 3,
    this.maxClubUses = 2,
  }) {
    chain.add(ChainLink(playerId: startPlayerId, viaClub: null, mark: null));
    usedPlayerIds.add(startPlayerId);
    livesLeft[Mark.x] = lives;
    livesLeft[Mark.o] = lives;
  }

  final String startPlayerId;
  final ClubsOf clubsOf;
  final int lives;
  final int maxClubUses;

  final List<ChainLink> chain = [];
  final Set<String> usedPlayerIds = {};
  final Map<String, int> clubUses = {};
  final Map<Mark, int> livesLeft = {};

  Mark current = Mark.x;
  int turnNumber = 0;
  Mark? winner;

  bool get isOver => winner != null;
  String get lastPlayerId => chain.last.playerId;

  /// Başlangıç oyuncusu hariç zincir uzunluğu
  int get length => chain.length - 1;

  int usesOf(String clubId) => clubUses[clubId] ?? 0;
  bool clubAvailable(String clubId) => usesOf(clubId) < maxClubUses;

  /// Son oyuncunun, hâlâ bağlantı kurulabilecek kulüpleri
  List<String> openClubs() =>
      clubsOf(lastPlayerId).where(clubAvailable).toList();

  ChainResult answer(String playerId) {
    if (isOver) return const ChainResult(GuessResult.invalid);
    if (usedPlayerIds.contains(playerId)) {
      return const ChainResult(GuessResult.alreadyUsed);
    }

    final shared = clubsOf(lastPlayerId).intersection(clubsOf(playerId));
    if (shared.isEmpty) {
      _loseLife();
      return const ChainResult(GuessResult.wrong, fail: ChainFail.noSharedClub);
    }
    final open = shared.where(clubAvailable).toList();
    if (open.isEmpty) {
      _loseLife();
      return const ChainResult(GuessResult.wrong, fail: ChainFail.clubLimit);
    }

    // En az kullanılmış ortak kulüp üzerinden bağla
    open.sort((a, b) => usesOf(a).compareTo(usesOf(b)));
    final via = open.first;
    clubUses[via] = usesOf(via) + 1;
    final link = ChainLink(playerId: playerId, viaClub: via, mark: current);
    chain.add(link);
    usedPlayerIds.add(playerId);
    _nextTurn();
    return ChainResult(GuessResult.correct, link: link);
  }

  /// Pas geçme veya süre dolması: bir can gider.
  void pass() {
    if (isOver) return;
    _loseLife();
  }

  void _loseLife() {
    livesLeft[current] = livesLeft[current]! - 1;
    if (livesLeft[current]! <= 0) {
      winner = current.other;
      turnNumber++;
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    current = current.other;
    turnNumber++;
  }

  Map<String, dynamic> toJson() => {
        'mode': 'chain',
        'start': startPlayerId,
        'lives': lives,
        'maxClubUses': maxClubUses,
        'chain': [for (final l in chain) l.toJson()],
        'used': usedPlayerIds.toList(),
        'clubUses': clubUses,
        'livesLeft': {for (final e in livesLeft.entries) e.key.name: e.value},
        'current': current.name,
        'turn': turnNumber,
        'winner': winner?.name,
      };

  factory ChainEngine.fromJson(Map<String, dynamic> json, ClubsOf clubsOf) {
    final e = ChainEngine(
      startPlayerId: json['start'] as String,
      clubsOf: clubsOf,
      lives: json['lives'] as int,
      maxClubUses: json['maxClubUses'] as int,
    );
    e.chain
      ..clear()
      ..addAll((json['chain'] as List)
          .map((l) => ChainLink.fromJson(l as Map<String, dynamic>)));
    e.usedPlayerIds
      ..clear()
      ..addAll((json['used'] as List).cast<String>());
    e.clubUses.addAll((json['clubUses'] as Map<String, dynamic>).cast<String, int>());
    final lives = json['livesLeft'] as Map<String, dynamic>;
    e.livesLeft[Mark.x] = lives['x'] as int;
    e.livesLeft[Mark.o] = lives['o'] as int;
    e.current = markFromName(json['current'] as String);
    e.turnNumber = json['turn'] as int;
    e.winner =
        json['winner'] == null ? null : markFromName(json['winner'] as String);
    return e;
  }
}
