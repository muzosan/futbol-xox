"""
Futbol XOX - Veri toplama scripti
Wikidata'dan seçili kulüplerde oynamış futbolcuları çeker ve JSON olarak kaydeder.

Kullanım:
    pip install requests
    python veri_topla.py

Çıktılar (data/ klasörü):
    clubs.json   -> kulüpler (Wikidata ID, ad, lig, oyuncu sayısı)
    players.json -> oyuncular (ID, ad, doğum yılı, popülerlik, oynadığı kulüpler)
    pairs.json   -> her kulüp çiftinin ortak oyuncu sayısı (tablo üretici için)

Not: clubs.json varsa kulüp eşleştirmesi tekrar yapılmaz. Yanlış eşleşen bir
kulüp olursa clubs.json içinden ID'sini elle düzeltip scripti tekrar çalıştır.
"""

import itertools
import json
import os
import re
import sys
import time

import requests

sys.stdout.reconfigure(encoding="utf-8")

SPARQL_URL = "https://query.wikidata.org/sparql"
API_URL = "https://www.wikidata.org/w/api.php"
# Wikidata, isteği kimin attığını belirten bir User-Agent ister. Kendi mailini yaz.
HEADERS = {"User-Agent": "FutbolXOX-VeriScripti/0.1 (iletisim: muazonurluer2312@gmail.com)"}

FUTBOLCU = "Q937857"   # Wikidata: "association football player"
CIKTI = "data"
BEKLEME = 1.0          # sorgular arası bekleme (sn) - Wikidata'yı yormamak için
TANINMIS_ESIK = 15     # en az bu kadar dilde Wikipedia sayfası olan oyuncu "tanınmış" sayılır

KULUPLER = {
    "Süper Lig": [
        "Galatasaray", "Fenerbahçe", "Beşiktaş", "Trabzonspor", "İstanbul Başakşehir",
        "Bursaspor", "Sivasspor", "Göztepe", "Kasımpaşa", "Antalyaspor",
    ],
    "Premier League": [
        "Manchester United F.C.", "Liverpool F.C.", "Arsenal F.C.", "Chelsea F.C.",
        "Manchester City F.C.", "Tottenham Hotspur F.C.", "Everton F.C.",
        "Newcastle United F.C.", "Aston Villa F.C.", "West Ham United F.C.",
    ],
    "La Liga": [
        "Real Madrid CF", "FC Barcelona", "Atlético Madrid", "Sevilla FC", "Valencia CF",
        "Villarreal CF", "Real Betis", "Athletic Bilbao", "Real Sociedad",
    ],
    "Serie A": [
        "Juventus FC", "AC Milan", "Inter Milan", "AS Roma", "SS Lazio", "SSC Napoli",
        "ACF Fiorentina", "Atalanta BC",
    ],
    "Bundesliga": [
        "FC Bayern Munich", "Borussia Dortmund", "Bayer 04 Leverkusen", "FC Schalke 04",
        "VfB Stuttgart", "Hamburger SV", "SV Werder Bremen", "Borussia Mönchengladbach",
        "Eintracht Frankfurt",
    ],
    "Ligue 1": [
        "Paris Saint-Germain F.C.", "Olympique de Marseille", "Olympique Lyonnais",
        "AS Monaco FC", "Lille OSC", "OGC Nice", "Stade Rennais F.C.",
    ],
}


# İlk aramada bulunamayan kulüpler için denenecek alternatif isimler
ALTERNATIF_ISIMLER = {
    "Göztepe": ["Göztepe S.K.", "Göztepe SK", "Göztepe Spor Kulübü"],
}


def istek(url, params, deneme=8):
    for i in range(1, deneme + 1):
        bekle = min(10 * i, 60)
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=150)
        except requests.RequestException as e:
            print(f"   ! Bağlantı hatası ({i}/{deneme}): {str(e)[:80]} - {bekle} sn sonra tekrar")
            time.sleep(bekle)
            continue
        if r.status_code == 200:
            try:
                return r.json()
            except ValueError:
                # Wikidata bazen yanıtı yarıda kesiyor; tekrar dene
                print(f"   ! Yanıt yarım geldi ({i}/{deneme}) - {bekle} sn sonra tekrar")
                time.sleep(bekle)
                continue
        if r.status_code in (429, 500, 502, 503, 504):
            bekle = int(r.headers.get("Retry-After", bekle))
            print(f"   ! Sunucu meşgul ({r.status_code}), {bekle} sn bekleniyor")
            time.sleep(bekle)
            continue
        r.raise_for_status()
    raise RuntimeError("İstek birkaç denemeye rağmen başarısız oldu. Scripti tekrar çalıştır, kaldığı yerden devam eder.")


def sparql(sorgu):
    veri = istek(SPARQL_URL, {"query": sorgu, "format": "json"})
    time.sleep(BEKLEME)
    return veri["results"]["bindings"]


def qid(uri):
    return uri.rsplit("/", 1)[-1]


def kaydet(yol, veri, kompakt=False):
    with open(yol, "w", encoding="utf-8") as f:
        if kompakt:
            json.dump(veri, f, ensure_ascii=False, separators=(",", ":"))
        else:
            json.dump(veri, f, ensure_ascii=False, indent=2)


def kulup_bul(ad, lig):
    """İsimle arar; adaylar arasından en çok futbolcusu olanı seçer.
    (Örn. 'Galatasaray' araması semt, spor kulübü, futbol takımı döndürebilir.)"""
    arama = istek(API_URL, {
        "action": "wbsearchentities", "search": ad, "language": "en",
        "uselang": "tr", "type": "item", "limit": 10, "format": "json",
    })
    adaylar = [s["id"] for s in arama.get("search", [])]
    if not adaylar:
        print(f"   ! '{ad}' için arama sonucu yok")
        return None

    values = " ".join(f"wd:{a}" for a in adaylar)
    sonuc = sparql(f"""
      SELECT ?kulup ?kulupLabel (COUNT(DISTINCT ?o) AS ?n) WHERE {{
        VALUES ?kulup {{ {values} }}
        ?o wdt:P54 ?kulup ; wdt:P106 wd:{FUTBOLCU} .
        SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
      }}
      GROUP BY ?kulup ?kulupLabel
      ORDER BY DESC(?n)
      LIMIT 1""")
    if not sonuc:
        print(f"   ! '{ad}' için futbolcusu olan kulüp bulunamadı")
        return None

    s = sonuc[0]
    return {
        "id": qid(s["kulup"]["value"]),
        "ad": s["kulupLabel"]["value"],
        "arama": ad,
        "lig": lig,
        "oyuncu_sayisi": int(s["n"]["value"]),
    }


def oyunculari_cek(kulup_id):
    return sparql(f"""
      SELECT ?o ?oLabel ?sl ?dogum WHERE {{
        ?o wdt:P54 wd:{kulup_id} ; wdt:P106 wd:{FUTBOLCU} ; wikibase:sitelinks ?sl .
        OPTIONAL {{ ?o wdt:P569 ?dogum . }}
        SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en,mul,es,it,de,fr,pt". }}
      }}""")


def main():
    os.makedirs(CIKTI, exist_ok=True)
    kulup_dosyasi = os.path.join(CIKTI, "clubs.json")

    # 1) Kulüpleri eşleştir (clubs.json varsa sadece eksik olanları dener)
    kulupler = []
    if os.path.exists(kulup_dosyasi):
        with open(kulup_dosyasi, encoding="utf-8") as f:
            kulupler = json.load(f)
        print(f"clubs.json bulundu, {len(kulupler)} kulüp yüklendi.")

    bulunanlar = {k["arama"] for k in kulupler}
    eksikler = [(lig, ad) for lig, adlar in KULUPLER.items() for ad in adlar if ad not in bulunanlar]
    if eksikler:
        print("1) Kulüpler Wikidata'da eşleştiriliyor...")
        for lig, ad in eksikler:
            k = None
            for aranan in [ad] + ALTERNATIF_ISIMLER.get(ad, []):
                k = kulup_bul(aranan, lig)
                if k:
                    k["arama"] = ad
                    break
            if k:
                kulupler.append(k)
                uyari = "  <-- AZ, KONTROL ET" if k["oyuncu_sayisi"] < 150 else ""
                print(f"   {ad:28} -> {k['id']:10} {k['ad']} ({k['oyuncu_sayisi']} oyuncu){uyari}")
            kaydet(kulup_dosyasi, kulupler)  # her kulüpten sonra kaydet
    print()

    # 2) Oyuncuları çek (her kulüp data/cache içine kaydedilir; hata olursa
    #    script tekrar çalıştırıldığında biten kulüpleri atlar)
    onbellek = os.path.join(CIKTI, "cache")
    os.makedirs(onbellek, exist_ok=True)
    print("2) Oyuncular çekiliyor (birkaç dakika sürebilir)...")
    oyuncular = {}
    for i, k in enumerate(kulupler, 1):
        cache_yolu = os.path.join(onbellek, f"{k['id']}.json")
        if os.path.exists(cache_yolu):
            with open(cache_yolu, encoding="utf-8") as f:
                satirlar = json.load(f)
            kaynak = "önbellek"
        else:
            satirlar = oyunculari_cek(k["id"])
            kaydet(cache_yolu, satirlar, kompakt=True)
            kaynak = "indirildi"
        for s in satirlar:
            oid = qid(s["o"]["value"])
            ad = s["oLabel"]["value"]
            if re.fullmatch(r"Q\d+", ad):
                continue  # hiçbir dilde adı olmayan kayıt
            o = oyuncular.setdefault(oid, {
                "id": oid, "ad": ad, "dogum_yili": None,
                "populerlik": int(s["sl"]["value"]), "kulupler": [],
            })
            if o["dogum_yili"] is None and "dogum" in s:
                m = re.match(r"^(\d{4})-", s["dogum"]["value"])
                if m:
                    o["dogum_yili"] = int(m.group(1))
            if k["id"] not in o["kulupler"]:
                o["kulupler"].append(k["id"])
        tekil = len({qid(s["o"]["value"]) for s in satirlar})
        print(f"   [{i}/{len(kulupler)}] {k['ad']}: {tekil} oyuncu ({kaynak})")

    liste = sorted(oyuncular.values(), key=lambda o: -o["populerlik"])
    kaydet(os.path.join(CIKTI, "players.json"), liste, kompakt=True)

    # 3) Kulüp çiftleri: tablo üreticinin temeli
    kulup_oyuncu = {k["id"]: set() for k in kulupler}
    for o in liste:
        for kid in o["kulupler"]:
            kulup_oyuncu.setdefault(kid, set()).add(o["id"])

    ciftler = []
    for a, b in itertools.combinations(kulup_oyuncu, 2):
        ortak = kulup_oyuncu[a] & kulup_oyuncu[b]
        if ortak:
            taninmis = sum(1 for oid in ortak if oyuncular[oid]["populerlik"] >= TANINMIS_ESIK)
            ciftler.append({"a": a, "b": b, "ortak": len(ortak), "taninmis": taninmis})
    ciftler.sort(key=lambda c: -c["ortak"])
    kaydet(os.path.join(CIKTI, "pairs.json"), ciftler)

    # 4) Özet
    adlar = {k["id"]: k["ad"] for k in kulupler}
    olasi = len(kulupler) * (len(kulupler) - 1) // 2
    print("\n=== ÖZET ===")
    print(f"Kulüp sayısı            : {len(kulupler)}")
    print(f"Toplam oyuncu           : {len(liste)}")
    print(f"2+ kulüpte oynamış      : {sum(1 for o in liste if len(o['kulupler']) >= 2)}")
    print(f"Olası kulüp çifti       : {olasi}")
    print(f"En az 3 ortak oyunculu  : {sum(1 for c in ciftler if c['ortak'] >= 3)}")
    print(f"En az 3 TANINMIŞ ortak  : {sum(1 for c in ciftler if c['taninmis'] >= 3)}")
    print("\nEn çok ortak oyuncusu olan 10 çift:")
    for c in ciftler[:10]:
        print(f"   {adlar[c['a']]} - {adlar[c['b']]}: {c['ortak']} ({c['taninmis']} tanınmış)")
    print(f"\nDosyalar '{CIKTI}' klasörüne kaydedildi.")


if __name__ == "__main__":
    main()
