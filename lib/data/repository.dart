import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';
import 'text_utils.dart';

/// assets/data içindeki JSON dosyalarını yükler ve arama yapar.
class Repository {
  Repository._(this.clubs, this.players, this.grids);

  final Map<String, Club> clubs;
  final List<Player> players; // popülerliğe göre sıralı (en bilinen başta)
  final List<PuzzleGrid> grids;

  final Random _random = Random();
  String? _lastGridId;

  static Future<Repository> load() async {
    final files = await Future.wait([
      rootBundle.loadString('assets/data/clubs.json'),
      rootBundle.loadString('assets/data/players.json'),
      rootBundle.loadString('assets/data/grids.json'),
    ]);

    final clubList = (jsonDecode(files[0]) as List)
        .map((e) => Club.fromJson(e as Map<String, dynamic>));
    final playerList = (jsonDecode(files[1]) as List)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    final gridList = (jsonDecode(files[2]) as List)
        .map((e) => PuzzleGrid.fromJson(e as Map<String, dynamic>))
        .toList();

    return Repository._(
      {for (final c in clubList) c.id: c},
      playerList,
      gridList,
    );
  }

  Club club(String id) => clubs[id]!;

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

  /// Oyun sonunda boş kalan hücreler için örnek cevap (en bilinen oyuncu).
  Player? exampleAnswer(String clubA, String clubB) {
    for (final p in players) {
      if (p.clubs.contains(clubA) && p.clubs.contains(clubB)) return p;
    }
    return null;
  }
}
