"""
Futbol XOX - Transfermarkt verisiyle birleştirme

Wikidata (eski dönem + efsaneler) ile Transfermarkt veri setini (2012 sonrası,
güncel transferler) oyuncu ID'si üzerinden birleştirir.

Hazırlık:
    Kaggle'dan "Football Data from Transfermarkt" (davidcariboo/player-scores)
    veri setini indir, zip'i aç ve şu dosyaları tools/tm_data/ klasörüne koy:
        players.csv, transfers.csv, appearances.csv

Kullanım (tools klasöründe, sırayla):
    py tm_birlestir.py
    py tablo_uret.py
    py hazirla.py

Nasıl eşleştiriyor:
    - Kulüpler: Wikidata'daki "Transfermarkt kulüp ID" (P7223) bilgisiyle
    - Oyuncular: Wikidata'daki "Transfermarkt oyuncu ID" (P2446) bilgisiyle;
      bulunamazsa isim + doğum yılıyla
"""

import csv
import json
import os
import sys
import unicodedata
from collections import defaultdict

from veri_topla import qid, sparql

sys.stdout.reconfigure(encoding="utf-8")
csv.field_size_limit(10_000_000)

VERI = "data"
TM = "tm_data"
ONBELLEK = os.path.join(VERI, "cache")

# Wikidata'da Transfermarkt ID'si eksik/yanlış olan kulüp olursa buraya elle ekle:
# "Q495299": ["141"]  (Wikidata ID -> Transfermarkt kulüp ID listesi)
KULUP_TM_DUZELTME = {}

# Birleştirme sonrası kontrol için ekrana yazdırılacak örnek oyuncular
KONTROL = ["Marco Asensio", "Berke Özer", "Gheorghe Hagi", "Mauro Icardi", "Edin Džeko"]


def yukle(yol):
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def kaydet(yol, veri, kompakt=False):
    with open(yol, "w", encoding="utf-8") as f:
        if kompakt:
            json.dump(veri, f, ensure_ascii=False, separators=(",", ":"))
        else:
            json.dump(veri, f, ensure_ascii=False, indent=2)


def isim_anahtar(ad):
    """'Berke Özer' -> 'berke ozer' (isim eşleştirme için)"""
    ad = ad.replace("ı", "i").replace("İ", "I")
    ad = unicodedata.normalize("NFKD", ad)
    ad = "".join(c for c in ad if not unicodedata.combining(c)).lower()
    return " ".join("".join(c if c.isalnum() else " " for c in ad).split())


def tm_populerlik(deger):
    """Wikipedia sayfası sayısı olmayan oyuncular için en yüksek piyasa değerinden
    tahmini popülerlik (tablo_uret.py'deki 'tanınmış' eşiği 15)."""
    try:
        d = float(deger or 0)
    except ValueError:
        return 3
    if d >= 50_000_000:
        return 30
    if d >= 20_000_000:
        return 20
    if d >= 10_000_000:
        return 15
    if d >= 3_000_000:
        return 8
    return 3


def csv_oku(ad, gerekli):
    yol = os.path.join(TM, ad)
    if not os.path.exists(yol):
        sys.exit(f"HATA: {yol} bulunamadı. Kaggle'dan indirdiğin CSV'leri '{TM}' klasörüne koy.")
    f = open(yol, encoding="utf-8", newline="")
    okuyucu = csv.DictReader(f)
    eksik = [s for s in gerekli if s not in (okuyucu.fieldnames or [])]
    if eksik:
        sys.exit(f"HATA: {ad} içinde şu sütunlar yok: {eksik}\nMevcut sütunlar: {okuyucu.fieldnames}")
    return f, okuyucu


def wikidata_oyunculari():
    """Wikidata'dan gelen orijinal oyuncu listesini döndürür (birleştirmeyi tekrar
    çalıştırınca birleşmiş dosyayı değil, orijinali kullanmak için yedekler)."""
    ana = os.path.join(VERI, "players.json")
    yedek = os.path.join(VERI, "players_wikidata.json")
    oyuncular = yukle(ana)
    if oyuncular and "kaynak" in oyuncular[0]:
        return yukle(yedek)  # zaten birleştirilmiş; orijinali kullan
    kaydet(yedek, oyuncular, kompakt=True)
    return oyuncular


def main():
    os.makedirs(ONBELLEK, exist_ok=True)
    kulupler = yukle(os.path.join(VERI, "clubs.json"))
    kulup_ad = {k["id"]: k["ad"] for k in kulupler}
    wd_oyuncular = {o["id"]: dict(o) for o in wikidata_oyunculari()}
    print(f"Wikidata: {len(wd_oyuncular)} oyuncu, {len(kulupler)} kulüp\n")

    # 1) Kulüplerin Transfermarkt ID'leri
    print("1) Kulüplerin Transfermarkt ID'leri alınıyor...")
    values = " ".join(f"wd:{k['id']}" for k in kulupler)
    satirlar = sparql(f"SELECT ?kulup ?tm WHERE {{ VALUES ?kulup {{ {values} }} ?kulup wdt:P7223 ?tm . }}")
    tm_kulup = {}  # TM kulüp ID -> Wikidata kulüp ID
    for s in satirlar:
        tm_kulup[s["tm"]["value"]] = qid(s["kulup"]["value"])
    for wd_id, tm_idler in KULUP_TM_DUZELTME.items():
        for t in tm_idler:
            tm_kulup[t] = wd_id
    eslesen = set(tm_kulup.values())
    for k in kulupler:
        if k["id"] not in eslesen:
            print(f"   ! {k['ad']} için Transfermarkt ID bulunamadı (KULUP_TM_DUZELTME'ye ekleyebilirsin)")
    print(f"   {len(eslesen)}/{len(kulupler)} kulüp eşleşti\n")

    # 2) Transfermarkt oyuncu bilgileri
    print("2) Transfermarkt dosyaları okunuyor...")
    tm_oyuncu = {}
    f, okuyucu = csv_oku("players.csv", ["player_id", "name", "date_of_birth"])
    for r in okuyucu:
        dogum = (r.get("date_of_birth") or "")[:4]
        tm_oyuncu[r["player_id"]] = {
            "ad": r["name"],
            "yil": int(dogum) if dogum.isdigit() else None,
            "deger": r.get("highest_market_value_in_eur") or r.get("market_value_in_eur"),
        }
    f.close()

    tm_uyelik = defaultdict(set)  # TM oyuncu ID -> bizim kulüp ID'leri
    f, okuyucu = csv_oku("transfers.csv", ["player_id", "from_club_id", "to_club_id"])
    for r in okuyucu:
        for kulup in (r["from_club_id"], r["to_club_id"]):
            if kulup in tm_kulup:
                tm_uyelik[r["player_id"]].add(tm_kulup[kulup])
        if r["player_id"] not in tm_oyuncu and r.get("player_name"):
            tm_oyuncu[r["player_id"]] = {"ad": r["player_name"], "yil": None, "deger": None}
    f.close()

    f, okuyucu = csv_oku("appearances.csv", ["player_id", "player_club_id"])
    for i, r in enumerate(okuyucu, 1):
        if r["player_club_id"] in tm_kulup:
            tm_uyelik[r["player_id"]].add(tm_kulup[r["player_club_id"]])
        if i % 500_000 == 0:
            print(f"   appearances: {i:,} satır okundu")
    f.close()
    print(f"   Bizim kulüplerde oynamış {len(tm_uyelik)} Transfermarkt oyuncusu bulundu\n")

    # 3) Wikidata oyuncularının Transfermarkt ID'leri (kulüp kulüp, önbellekli)
    print("3) Wikidata oyuncularının Transfermarkt ID'leri alınıyor...")
    tm_wd = {}  # TM oyuncu ID -> Wikidata oyuncu ID
    for i, k in enumerate(kulupler, 1):
        yol = os.path.join(ONBELLEK, f"tm_oyuncu_{k['id']}.json")
        if os.path.exists(yol):
            satirlar = yukle(yol)
        else:
            satirlar = sparql(f"SELECT ?o ?tm WHERE {{ ?o wdt:P54 wd:{k['id']} ; wdt:P2446 ?tm . }}")
            kaydet(yol, satirlar, kompakt=True)
        for s in satirlar:
            tm_wd[s["tm"]["value"]] = qid(s["o"]["value"])
        if i % 10 == 0 or i == len(kulupler):
            print(f"   {i}/{len(kulupler)} kulüp")

    # İsim + doğum yılı yedek eşleştirmesi
    isim_index = {}
    for o in wd_oyuncular.values():
        isim_index.setdefault((isim_anahtar(o["ad"]), o["dogum_yili"]), o["id"])

    # 4) Birleştir
    print("\n4) Birleştiriliyor...")
    for o in wd_oyuncular.values():
        o["kaynak"] = "wd"
    yeni_baglanti = yeni_oyuncu = id_ile = isim_ile = 0

    for tm_id, kulup_set in tm_uyelik.items():
        bilgi = tm_oyuncu.get(tm_id, {"ad": f"TM {tm_id}", "yil": None, "deger": None})
        wd_id = tm_wd.get(tm_id)
        if wd_id in wd_oyuncular:
            id_ile += 1
        else:
            wd_id = isim_index.get((isim_anahtar(bilgi["ad"]), bilgi["yil"]))
            if wd_id:
                isim_ile += 1

        if wd_id in wd_oyuncular:
            o = wd_oyuncular[wd_id]
            eklenecek = kulup_set - set(o["kulupler"])
            o["kulupler"].extend(sorted(eklenecek))
            yeni_baglanti += len(eklenecek)
            o["populerlik"] = max(o["populerlik"], tm_populerlik(bilgi["deger"]))
            if o["dogum_yili"] is None:
                o["dogum_yili"] = bilgi["yil"]
            o["kaynak"] = "wd+tm"
            o["tm"] = tm_id  # kariyer_hazirla.py için
        else:
            yeni_oyuncu += 1
            wd_oyuncular[f"TM{tm_id}"] = {
                "id": f"TM{tm_id}",
                "ad": bilgi["ad"],
                "dogum_yili": bilgi["yil"],
                "populerlik": tm_populerlik(bilgi["deger"]),
                "kulupler": sorted(kulup_set),
                "kaynak": "tm",
            }

    liste = sorted(wd_oyuncular.values(), key=lambda o: -o["populerlik"])
    kaydet(os.path.join(VERI, "players.json"), liste, kompakt=True)

    print("\n=== BİRLEŞTİRME ÖZETİ ===")
    print(f"ID ile eşleşen oyuncu        : {id_ile}")
    print(f"İsim + doğum yılıyla eşleşen : {isim_ile}")
    print(f"Mevcut oyunculara eklenen kulüp bağlantısı: {yeni_baglanti}")
    print(f"Sadece Transfermarkt'ta olan yeni oyuncu  : {yeni_oyuncu}")
    print(f"Toplam oyuncu                : {len(liste)}")
    print(f"2+ kulüpte oynamış           : {sum(1 for o in liste if len(o['kulupler']) >= 2)}")

    print("\nKontrol:")
    for aranan in KONTROL:
        anahtar = isim_anahtar(aranan)
        bulunan = [o for o in liste if isim_anahtar(o["ad"]) == anahtar]
        if not bulunan:
            print(f"   {aranan}: bulunamadı")
        for o in bulunan[:1]:
            kulup_listesi = ", ".join(kulup_ad.get(k, k) for k in o["kulupler"])
            print(f"   {o['ad']}: {kulup_listesi}")

    print(f"\n'{VERI}/players.json' güncellendi. Şimdi sırayla: py tablo_uret.py  ->  py hazirla.py")


if __name__ == "__main__":
    main()
