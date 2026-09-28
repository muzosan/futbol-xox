# ⚽ Volea: Futbol Bilgi Arenası

Futbol bilgini 8 farklı oyun moduyla sınayan, gerçek oyuncu verileriyle oynanan bir bilgi ve strateji oyunu. Bota karşı, arkadaşınla aynı telefonda ya da kalabalık bir grupla oynayabilirsin.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-F5C451)
![Durum](https://img.shields.io/badge/Durum-Kapal%C4%B1%20Test-2EE59D)

> Yakında **App Store** ve **Google Play**'de.

## Ekran Görüntüleri

| Ana Menü | Oyun | Oyuncu Arama |
|:---:|:---:|:---:|
| <img src="docs/screenshots/home.png" width="250"> | <img src="docs/screenshots/game.png" width="250"> | <img src="docs/screenshots/search.png" width="250"> |

## Oyun Modları

| Mod | Nasıl oynanır | Kiminle |
|---|---|---|
| **XOX** | 3×3 tablonun satır ve sütunundaki iki kulüpte de oynamış futbolcuyu bul, üçlüyü ilk yapan kazansın. | Bot · 2 kişi |
| **Kart Düellosu** | Futbolcu kartından bir istatistik seç (gol, asist, piyasa değeri…). Yüksek olan turu alır. | Bot · 2 kişi |
| **Kadro Kur** | Her maç bir ölçüt (ör. en çok kırmızı kart). 5 turda gelen takımlardan birer oyuncu seçip en güçlü kadroyu kur. | Bot · 2 kişi |
| **Sahtekâr** | Herkes gizli futbolcuyu görür, biri hariç. İpuçları ve gizli oylamayla sahtekârı yakala. | 3-8 kişi, tek telefon |
| **Kulüp Avı** | Gelen 5 kulübün en çoğunda oynamış futbolcuyu bul. Kulüp sayısı arttıkça puan katlanır. | Bot · 2 kişi |
| **Zincir** | Son futbolcuyla aynı kulüpte oynamış birini yaz, zinciri uzat. Canı biten kaybeder. | Bot · 2 kişi |
| **Doğru mu?** | 60 saniyede "Bu futbolcu bu kulüpte oynadı mı?" sorularını bil. | Tek kişilik, rekor |
| **Kim Bu?** | Kariyerdeki kulüpler sırayla açılır. Ne kadar az ipucuyla bilirsen o kadar çok puan. | Tek kişilik, rekor |

Her mod **Kolay / Orta / Zor** seviyelerinde oynanır. Kolay seviyede herkesin bildiği büyük kulüpler ve yıldız oyuncular, zor seviyede az bilinen eşleşmeler çıkar.

## Öne Çıkanlar

- **~100 bin futbolcu, 477 kulüp, 21 lig:** Premier League, La Liga, Serie A, Bundesliga, Ligue 1 ve ikinci ligleri; Süper Lig ve TFF 1-2-3. Lig; Hollanda, Portekiz, Brezilya, Arjantin ve Suudi Arabistan ligleri
- **Üç seviyeli yapay zekâ rakip:** Botlar insan gibi davranır; bazen unutur, bazen yanılır, seviyesine göre stratejik oynar
- **Premium arayüz:** Gece maçı temalı koyu tasarım, altın vurgular, FIFA tarzı futbolcu kartları, 3B kart çevirme animasyonları
- **Kulüp formaları:** Her kulüp, renkleri ve deseniyle (çubuklu, parçalı, şeritli…) kodla çizilmiş küçük bir formayla gösterilir
- **Akıllı arama:** Türkçe karakter ve aksanlardan bağımsız; oyuncunun mevkisi, uyruğu ve doğum yılı gösterilir
- **Maç içi emoji tepkileri:** Hazır emojilerle, taciz riski olmadan
- **Hatalı veri bildir:** Oyuncular gördükleri hatayı tek dokunuşla bildirir

## Proje Yapısı

```
lib/
├── data/          # Veri modelleri, yükleme (arka planda), arama
├── game/
│   ├── engine/    # Saf kural motorları (Flutter'dan bağımsız, JSON'a çevrilebilir)
│   └── ...        # Denetleyiciler, botlar, tur üreticileri
├── screens/       # Mod ekranları
├── widgets/       # Kartlar, formalar, tahta, arama paneli
├── reactions/     # Emoji tepkileri
├── report/        # Hatalı veri bildirimi
└── theme.dart     # Tema, renkler, yazı tipleri
assets/data/       # Uygulamanın kullandığı hazır veri (JSON)
tools/             # Veri hattı (Python)
```

Kural motorları bilerek arayüzden ayrı tutuldu. Online moda geçildiğinde aynı kurallar sunucu tarafında hakem olarak kullanılacak.

## Veri Hattı

Bütün veri `tools/` klasöründeki scriptlerle iki açık kaynaktan üretilir. Tek komutla çalışır:

```bash
pip install requests
python hepsi.py
```

| Adım | Script | Görevi |
|---|---|---|
| 1 | `veri_topla.py` | 21 ligin kulüplerini ve bu kulüplerde oynamış futbolcuları Wikidata'dan çeker; aynı kulübün kopya kayıtlarını birleştirir |
| 2 | `tm_birlestir.py` | Transfermarkt veri setiyle birleştirir (güncel transferler) |
| 3 | `detay_topla.py` | Mevki ve uyruk |
| 4 | `forma_topla.py` | Forma renkleri ve desenleri |
| 5 | `istatistik_topla.py` | Gol, asist, maç, kart ve piyasa değeri |
| 6 | `tablo_uret.py` | Zorluk seviyelerine ayrılmış XOX tabloları |
| 7 | `hazirla.py` | Uygulama verisini `assets/data/` klasörüne yazar |
| 8 | `kariyer_hazirla.py` | Kronolojik kariyerler (Kim Bu?) |
| 9 | `denetle.py` | Veri denetimi: tutarsızlıkları bulur, bilinen kariyerlerle doğruluk testi yapar |

Her adım önbellekli çalışır; yarıda kalırsa kaldığı yerden devam eder. Elle düzeltmeler `tools/duzeltmeler.json` dosyasına yazılır ve her yenilemede otomatik uygulanır.

## Çalıştırma

```bash
flutter pub get
flutter run
```

## Yol Haritası

- [x] 8 oyun modu
- [x] Üç seviyeli yapay zekâ rakip
- [x] Premium tema ve futbolcu kartları
- [x] Veri denetimi ve hatalı veri bildirimi
- [ ] 8 dil desteği
- [ ] Online mod (Firebase): eşleştirme, arkadaş odası, sunucu tarafı hakem
- [ ] Liderlik tablosu ve rütbeler
- [ ] Google Play ve App Store yayını

## Veri Kaynakları

- [Wikidata](https://www.wikidata.org/): CC0 lisanslı
- [Football Data from Transfermarkt](https://www.kaggle.com/datasets/davidcariboo/player-scores) ([transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets)): CC0 lisanslı

Gol, asist, maç ve kart istatistikleri 2012 sonrası Avrupa ligleri ve kupalarını kapsar.

Volea hiçbir kulüp, lig, oyuncu veya Transfermarkt ile bağlantılı değildir. Kulüp ve oyuncu isimleri yalnızca bilgi amaçlı kullanılır; resmi logo veya görsel kullanılmaz.

## Geliştirici

**MUON Studio** · Muaz Onurluer · [@muzosan](https://github.com/muzosan)

© 2026 MUON Studio. Tüm hakları saklıdır.
