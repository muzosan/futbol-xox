// Bütün oyun modlarının ortak tipleri.
//
// "engine" klasöründeki dosyalar Flutter'a, zamanlayıcıya veya veri yüklemeye
// bağlı değildir: sadece "durum + hamle = yeni durum" mantığını içerir ve JSON'a
// çevrilebilir. Online modda aynı kurallar sunucudaki hakeme taşınacak.

enum Mark { x, o }

extension MarkInfo on Mark {
  Mark get other => this == Mark.x ? Mark.o : Mark.x;
  String get symbol => this == Mark.x ? 'X' : 'O';
}

Mark markFromName(String name) => Mark.values.byName(name);

enum GuessResult { correct, wrong, alreadyUsed, invalid }

/// Bir oyuncunun oynadığı kulüplerin ID'lerini verir.
/// Uygulamada Repository, sunucuda sunucunun kendi veri kopyası sağlar.
typedef ClubsOf = Set<String> Function(String playerId);
