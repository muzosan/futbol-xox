import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../l10n/lang_state.dart';
import '../l10n/translate.dart';
import 'models.dart';
import 'text_utils.dart';

/// assets/data içindeki JSON dosyalarını yükler ve arama yapar.
class Repository {
  Repository._(
      this.clubs, this.players, this.grids, this.careers, this.countries);

  final Map<String, Club> clubs;
  final List<Player> players; // popülerliğe göre sıralı (en bilinen başta)
  final List<PuzzleGrid> grids;

  /// Kim Bu? modu için kronolojik kariyerler (dosya yoksa boş)
  final List<Career> careers;

  /// Ülke kodu -> {dil: ülke adı} (dosya yoksa boş)
  final Map<String, Map<String, String>> countries;

  /// Ülke adı geçerli dilde (yoksa İngilizce, o da yoksa Türkçe)
  String countryName(String code) {
    final m = countries[code];
    return m?[currentLang] ?? m?['en'] ?? m?['tr'] ?? code;
  }

  late final Map<String, Club> _clubByTrName = {
    for (final c in clubs.values) c.nameTr: c,
  };

  /// Kariyer verisindeki kulüp adını (Türkçe kaydedilmiş) geçerli dile çevirir
  String localClubName(String name) {
    // Kariyer verisinde altyapı dönemleri "Barcelona (Altyapı)" şeklinde tutulur
    const youth = ' (Altyapı)';
    if (name.endsWith(youth)) {
      final base = name.substring(0, name.length - youth.length);
      return '${_clubByTrName[base]?.name ?? base} (${t('who.youth')})';
    }
    return _clubByTrName[name]?.name ?? name;
  }

  /// Arama listesindeki alt satır için: "CB · 🇹🇷 Türkiye"
  String playerInfo(Player p) {
    final nat = p.nationality;
    return [
      if (p.positions.isNotEmpty) p.positions.join('/'),
      if (nat != null) '${flagEmoji(nat)} ${countryName(nat)}'.trim(),
    ].join(' · ');
  }

  final Random _random = Random();
  String? _lastGridId;
  final Map<String, List<Player>> _answerCache = {};

  static Future<Repository>? _cache;

  /// Veri bir kez yüklenir; sonraki çağrılar (ör. dil değişince) aynı sonucu döndürür
  static Future<Repository> load() => _cache ??= _load();

  static Future<Repository> _load() async {
    final files = await Future.wait([
      rootBundle.loadString('assets/data/clubs.json'),
      rootBundle.loadString('assets/data/players.json'),
      rootBundle.loadString('assets/data/grids.json'),
      rootBundle
          .loadString('assets/data/careers.json')
          .catchError((_) => '[]'), // kariyer dosyası henüz yoksa
      rootBundle
          .loadString('assets/data/countries.json')
          .catchError((_) => '{}'), // ülke dosyası henüz yoksa
    ]);
    // JSON çözme ve 32.000 oyuncunun arama anahtarlarını hazırlama işi ayrı bir
    // iş parçacığında (isolate) yapılır; böylece açılışta arayüz donmaz.
    // (Web'de isolate olmadığı için aynı iş normal şekilde çalışır.)
    final parsed = await compute(_parseAll, files);
    return Repository._(parsed.clubs, parsed.players, parsed.grids,
        parsed.careers, parsed.countries);
  }

  Club club(String id) => clubs[id]!;

  int tierOf(String clubId) => clubs[clubId]?.tier ?? 3;

  /// Oyuncunun en tanınmış kulübü (kartta forması gösterilir)
  Club? mainClub(Player p) {
    if (p.clubs.isEmpty) return null;
    final list = p.clubs.map(club).toList()
      ..sort((a, b) {
        final t = a.tier.compareTo(b.tier);
        return t != 0 ? t : playersOf(b.id).length.compareTo(playersOf(a.id).length);
      });
    return list.first;
  }

  /// Kartlardaki "Yıldız Puanı" (45-99): şöhret ve en yüksek piyasa değerinden.
  /// Gerçek bir performans puanı değil; oyuncunun ününü ve değerini yansıtır.
  int starRating(Player p) {
    final r = 45 + 8 * log(1 + p.popularity) + 3 * log(1 + p.stat('pv'));
    return r.round().clamp(45, 99).toInt();
  }

  /// Oyuncunun, seviyesi en fazla [maxTier] olan kaç kulüpte oynadığı
  int bigClubCount(Player p, int maxTier) =>
      p.clubs.where((c) => tierOf(c) <= maxTier).length;

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
  const _ParsedData(
      this.clubs, this.players, this.grids, this.careers, this.countries);
  final Map<String, Club> clubs;
  final List<Player> players;
  final List<PuzzleGrid> grids;
  final List<Career> careers;
  final Map<String, Map<String, String>> countries;
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
  // Eski biçim {kod: ad} veya yeni biçim {kod: {dil: ad}}
  final countryMap = (jsonDecode(files[4]) as Map<String, dynamic>).map(
    (k, v) => MapEntry(
      k,
      v is String ? {'tr': v} : (v as Map<String, dynamic>).cast<String, String>(),
    ),
  );
  return _ParsedData({for (final c in clubList) c.id: c}, playerList,
      gridList, careerList, countryMap);
}
