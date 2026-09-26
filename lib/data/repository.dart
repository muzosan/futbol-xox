import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';
import 'text_utils.dart';

/// assets/data içindeki JSON dosyalarını yükler ve arama yapar.
class Repository {
  Repository._(this.clubs, this.players, this.grids, this.careers);

  final Map<String, Club> clubs;
  final List<Player> players; // popülerliğe göre sıralı (en bilinen başta)
  final List<PuzzleGrid> grids;

  /// Kim Bu? modu için kronolojik kariyerler (dosya yoksa boş)
  final List<Career> careers;

  final Random _random = Random();
  String? _lastGridId;
  final Map<String, List<Player>> _answerCache = {};

  static Future<Repository> load() async {
    final files = await Future.wait([
      rootBundle.loadString('assets/data/clubs.json'),
      rootBundle.loadString('assets/data/players.json'),
      rootBundle.loadString('assets/data/grids.json'),
      rootBundle
          .loadString('assets/data/careers.json')
          .catchError((_) => '[]'), // kariyer dosyası henüz yoksa
    ]);
    // JSON çözme ve 32.000 oyuncunun arama anahtarlarını hazırlama işi ayrı bir
    // iş parçacığında (isolate) yapılır; böylece açılışta arayüz donmaz.
    // (Web'de isolate olmadığı için aynı iş normal şekilde çalışır.)
    final parsed = await compute(_parseAll, files);
    return Repository._(
        parsed.clubs, parsed.players, parsed.grids, parsed.careers);
  }

  Club club(String id) => clubs[id]!;

  late final Map<String, Player> _byId = {for (final p in players) p.id: p};

  late final Map<String, List<Player>> _byClub = () {
    final map = <String, List<Player>>{};
    for (final p in players) {
      for (final c in p.clubs) {
        (map[c] ??= []).add(p);
      }
    }
    return map;
  }();

  Player? playerById(String id) => _byId[id];

  /// Oyun motorlarının kullandığı kulüp bilgisi.
  Set<String> clubsOf(String playerId) => _byId[playerId]?.clubs ?? const <String>{};

  /// Bir kulüpte oynamış bütün oyuncular (en bilinen başta).
  List<Player> playersOf(String clubId) => _byClub[clubId] ?? const <Player>[];

  /// Verilen kulüplerin en az ikisinde oynamış oyuncular ve kaçında oynadıkları.
  /// Sıralama: önce kulüp sayısı, sonra popülerlik.
  List<({Player player, int count})> multiClubPlayers(List<String> clubIds) {
    final counts = <Player, int>{};
    for (final c in clubIds) {
      for (final p in playersOf(c)) {
        counts[p] = (counts[p] ?? 0) + 1;
      }
    }
    final list = [
      for (final e in counts.entries)
        if (e.value >= 2) (player: e.key, count: e.value),
    ];
    list.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : b.player.popularity.compareTo(a.player.popularity);
    });
    return list;
  }

  /// Her kelime, oyuncu adındaki bir kelimenin başıyla eşleşmeli.
  /// "slim" -> Islam Slimani, "cr ron" -> Cristiano Ronaldo
  List<Player> search(String query, {int limit = 25}) {
    final tokens =
        normalize(query).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty || tokens.join().length < 2) return const [];

    final results = <Player>[];
    for (final p in players) {
      if (tokens.every((t) => p.searchKey.contains(' $t'))) {
        results.add(p);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  /// Seçilen zorlukta rastgele bir tablo (üst üste aynısı gelmez).
  PuzzleGrid randomGrid(String difficulty) {
    var pool = grids.where((g) => g.difficulty == difficulty).toList();
    if (pool.isEmpty) pool = grids;
    if (pool.length > 1) pool.removeWhere((g) => g.id == _lastGridId);
    final grid = pool[_random.nextInt(pool.length)];
    _lastGridId = grid.id;
    return grid;
  }

  /// İki kulüpte de oynamış bütün oyuncular (en bilinen başta). Sonuç önbelleğe alınır.
  List<Player> answers(String clubA, String clubB) {
    final key = clubA.compareTo(clubB) < 0 ? '$clubA|$clubB' : '$clubB|$clubA';
    return _answerCache.putIfAbsent(
      key,
      () => players
          .where((p) => p.clubs.contains(clubA) && p.clubs.contains(clubB))
          .toList(),
    );
  }

  /// Oyun sonunda boş kalan hücreler için örnek cevap (en bilinen oyuncu).
  Player? exampleAnswer(String clubA, String clubB) {
    final list = answers(clubA, clubB);
    return list.isEmpty ? null : list.first;
  }
}

class _ParsedData {
  const _ParsedData(this.clubs, this.players, this.grids, this.careers);
  final Map<String, Club> clubs;
  final List<Player> players;
  final List<PuzzleGrid> grids;
  final List<Career> careers;
}

/// compute() ile çağrılabilmesi için sınıf dışında (top-level) tanımlı.
_ParsedData _parseAll(List<String> files) {
  final clubList = (jsonDecode(files[0]) as List)
      .map((e) => Club.fromJson(e as Map<String, dynamic>));
  final playerList = (jsonDecode(files[1]) as List)
      .map((e) => Player.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.popularity.compareTo(a.popularity));
  final gridList = (jsonDecode(files[2]) as List)
      .map((e) => PuzzleGrid.fromJson(e as Map<String, dynamic>))
      .toList();
  final careerList = (jsonDecode(files[3]) as List)
      .map((e) => Career.fromJson(e as Map<String, dynamic>))
      .toList();
  return _ParsedData(
      {for (final c in clubList) c.id: c}, playerList, gridList, careerList);
}
