"""
Futbol XOX - Mevki ve uyruk bilgisi

Her oyuncunun mevkisini (GK, CB, RW...) ve uyruğunu (ülke kodu) çıkarır.

Kaynaklar (öncelik sırasıyla):
    Mevki : Transfermarkt alt mevkisi (detaylı) -> Wikidata P413
    Uyruk : Wikidata P1532 (temsil ettiği ülke) -> Transfermarkt vatandaşlığı
            -> Wikidata P27 (vatandaşlık)

Kullanım (tools klasöründe, tm_birlestir.py ve tablo_uret.py'den sonra):
    py detay_topla.py
    py hazirla.py          <- mevki/uyruğu uygulama verisine ekler

Çıktılar:
    data/details.json            -> {oyuncu: {"m": ["CB"], "u": "TR"}}
    ../assets/data/countries.json -> {ülke kodu: Türkçe ülke adı}
"""

import os
import re
import sys
from collections import Counter

from tm_birlestir import csv_oku, isim_anahtar, kaydet, yukle
from veri_topla import API_URL, istek, qid, sparql

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
CIKTI = os.path.join("..", "assets", "data")
WD_CACHE = os.path.join(VERI, "cache", "wd_detay.json")
POZ_CACHE = os.path.join(VERI, "cache", "pozisyon_etiket.json")
GRUP = 250

# Transfermarkt alt mevkileri -> kısaltma
TM_ALT_MEVKI = {
    "Goalkeeper": "GK", "Centre-Back": "CB", "Left-Back": "LB", "Right-Back": "RB",
    "Defensive Midfield": "DM", "Central Midfield": "CM", "Attacking Midfield": "AM",
    "Left Midfield": "LM", "Right Midfield": "RM", "Left Winger": "LW",
    "Right Winger": "RW", "Second Striker": "SS", "Centre-Forward": "ST",
}
TM_MEVKI = {"Goalkeeper": "GK", "Defender": "DF", "Midfield": "MF", "Attack": "FW"}

# Wikidata mevki adları (İngilizce) -> kısaltma. Sıra önemli: özelden genele.
WD_MEVKI = [
    (r"goalkeeper|goalie", "GK"),
    (r"centre[- ]?back|center[- ]?back|central defender|stopper", "CB"),
    (r"sweeper|libero", "SW"),
    (r"left[- ]?back|left full[- ]?back", "LB"),
    (r"right[- ]?back|right full[- ]?back", "RB"),
    (r"wing[- ]?back", "WB"),
    (r"full[- ]?back", "FB"),
    (r"defensive midfield|holding midfield", "DM"),
    (r"attacking midfield|playmaker|trequartista", "AM"),
    (r"central midfield|centre midfield|box[- ]to[- ]box", "CM"),
    (r"left midfield", "LM"),
    (r"right midfield", "RM"),
    (r"left wing", "LW"),
    (r"right wing", "RW"),
    (r"winger", "W"),
    (r"second striker|inside forward|shadow striker", "SS"),
    (r"striker|centre[- ]?forward|center[- ]?forward", "ST"),
    (r"forward|attacker", "FW"),
    (r"midfielder|half[- ]?back|wing half", "MF"),
    (r"defender", "DF"),
]

# Birleşik Krallık'ın futbol ülkeleri (ISO kodu yok, bayrak için özel kod)
UK = {"Q21": "GB-ENG", "Q22": "GB-SCT", "Q25": "GB-WLS", "Q26": "GB-NIR"}

# Transfermarkt'ın farklı yazdığı ülke adları
TM_ULKE = {
    "Türkiye": "TR", "Korea, South": "KR", "Korea, North": "KP",
    "Cote d'Ivoire": "CI", "DR Congo": "CD", "Congo": "CG",
    "Bosnia-Herzegovina": "BA", "Czech Republic": "CZ", "United States": "US",
    "Curacao": "CW", "Cape Verde": "CV", "Kosovo": "XK", "Chinese Taipei": "TW",
    "North Macedonia": "MK", "Macedonia": "MK", "Russia": "RU", "Iran": "IR",
    "Syria": "SY", "Vietnam": "VN", "The Gambia": "GM", "Gambia": "GM",
    "Ireland": "IE", "Netherlands": "NL", "England": "GB-ENG",
    "Scotland": "GB-SCT", "Wales": "GB-WLS", "Northern Ireland": "GB-NIR",
    "St. Kitts & Nevis": "KN", "Moldova": "MD", "Palestine": "PS",
}

KONTROL = ["Arda Turan", "Mesut Özil", "Gheorghe Hagi", "Virgil van Dijk",
           "Mohamed Salah", "Harry Kane", "Mauro Icardi", "Berke Özer"]


def ulkeleri_al():
    """ISO kodu olan bütün ülkeler + İngiltere/İskoçya/Galler/K.İrlanda."""
    print("Ülke listesi alınıyor...")
    uk_values = " ".join(f'(wd:{q} "{k}")' for q, k in UK.items())
    satirlar = sparql(f"""
      SELECT ?c ?kod ?tr ?en WHERE {{
        {{ ?c wdt:P297 ?kod . }} UNION {{ VALUES (?c ?kod) {{ {uk_values} }} }}
        OPTIONAL {{ ?c rdfs:label ?tr . FILTER(LANG(?tr) = "tr") }}
        OPTIONAL {{ ?c rdfs:label ?en . FILTER(LANG(?en) = "en") }}
      }}""")
    ulke = {}  # Wikidata ID -> {"kod", "tr", "en"}
    for s in satirlar:
        c = qid(s["c"]["value"])
        ulke[c] = {
            "kod": s["kod"]["value"].upper(),
            "tr": s.get("tr", s.get("en", {})).get("value", ""),
            "en": s.get("en", {}).get("value", ""),
        }
    return ulke


def etiketleri_al(idler, diller):
    """wbgetentities ile etiketler (50'şerli)."""
    sonuc = {}
    idler = list(idler)
    for bas in range(0, len(idler), 50):
        cevap = istek(API_URL, {
            "action": "wbgetentities", "ids": "|".join(idler[bas:bas + 50]),
            "props": "labels", "languages": "|".join(diller), "format": "json",
        })
        for i, e in cevap.get("entities", {}).items():
            etiketler = e.get("labels", {})
            sonuc[i] = {d: etiketler[d]["value"] for d in diller if d in etiketler}
    return sonuc


def wd_detaylari(wd_idler):
    """Oyuncuların Wikidata mevki (P413), temsil ülkesi (P1532), vatandaşlık (P27)."""
    cache = yukle(WD_CACHE) if os.path.exists(WD_CACHE) else {}
    eksik = [i for i in wd_idler if i not in cache]
    print(f"Wikidata detayları: {len(wd_idler) - len(eksik)} hazır, {len(eksik)} indirilecek")
    for bas in range(0, len(eksik), GRUP):
        grup = eksik[bas:bas + GRUP]
        values = " ".join(f"wd:{i}" for i in grup)
        satirlar = sparql(f"""
          SELECT ?o ?poz ?spor ?vat WHERE {{
            VALUES ?o {{ {values} }}
            OPTIONAL {{ ?o wdt:P413 ?poz . }}
            OPTIONAL {{ ?o wdt:P1532 ?spor . }}
            OPTIONAL {{ ?o wdt:P27 ?vat . }}
          }}""")
        for i in grup:
            cache[i] = {"p": [], "s": [], "v": []}
        for s in satirlar:
            d = cache[qid(s["o"]["value"])]
            for alan, anahtar in (("poz", "p"), ("spor", "s"), ("vat", "v")):
                if alan in s:
                    deger = qid(s[alan]["value"])
                    if deger not in d[anahtar]:
                        d[anahtar].append(deger)
        kaydet(WD_CACHE, cache, kompakt=True)
        biten = min(bas + GRUP, len(eksik))
        if biten % (GRUP * 20) == 0 or biten == len(eksik):
            print(f"   {biten}/{len(eksik)}")
    return cache


def wd_mevki_kisalt(etiket):
    etiket = etiket.lower()
    for desen, kisa in WD_MEVKI:
        if re.search(desen, etiket):
            return kisa
    return None


def main():
    oyuncular = yukle(os.path.join(VERI, "players.json"))
    if not oyuncular or "kaynak" not in oyuncular[0]:
        sys.exit("HATA: Önce 'py tm_birlestir.py' çalıştırılmalı.")

    # 1) Transfermarkt: alt mevki + vatandaşlık
    print("Transfermarkt oyuncu bilgileri okunuyor...")
    f, okuyucu = csv_oku("players.csv", ["player_id", "position", "sub_position",
                                         "country_of_citizenship"])
    tm = {}
    for r in okuyucu:
        mevki = TM_ALT_MEVKI.get(r["sub_position"]) or TM_MEVKI.get(r["position"])
        tm[r["player_id"]] = (mevki, (r["country_of_citizenship"] or "").strip())
    f.close()

    # 2) Ülkeler
    ulke = ulkeleri_al()
    ad_kod = {u["en"]: u["kod"] for u in ulke.values() if u["en"]}
    ad_kod.update(TM_ULKE)

    # 3) Wikidata detayları
    wd_idler = [o["id"] for o in oyuncular if o["id"].startswith("Q")]
    wd = wd_detaylari(wd_idler)

    # Mevki etiketleri (birkaç yüz farklı mevki öğesi)
    poz_cache = yukle(POZ_CACHE) if os.path.exists(POZ_CACHE) else {}
    tum_poz = {p for d in wd.values() for p in d["p"]} - set(poz_cache)
    if tum_poz:
        print(f"{len(tum_poz)} mevki etiketi alınıyor...")
        for i, e in etiketleri_al(tum_poz, ["en"]).items():
            poz_cache[i] = e.get("en", "")
        kaydet(POZ_CACHE, poz_cache)

    # ISO kodu olmayan (tarihi) ülkeler: Yugoslavya, SSCB gibi
    tum_ulke = {u for d in wd.values() for u in d["s"] + d["v"]} - set(ulke)
    if tum_ulke:
        print(f"{len(tum_ulke)} tarihi/ek ülke etiketi alınıyor...")
        for i, e in etiketleri_al(tum_ulke, ["tr", "en"]).items():
            ulke[i] = {"kod": i, "tr": e.get("tr") or e.get("en", ""), "en": e.get("en", "")}

    # 4) Birleştir
    detaylar = {}
    ulke_adlari = {}
    kaynak = Counter()
    for o in oyuncular:
        tm_id = o.get("tm") or (o["id"][2:] if o["id"].startswith("TM") else None)
        tm_mevki, tm_ulke = tm.get(tm_id, (None, "")) if tm_id else (None, "")
        d = wd.get(o["id"], {"p": [], "s": [], "v": []})

        # Mevki
        mevkiler = []
        if tm_mevki:
            mevkiler = [tm_mevki]
            kaynak["mevki_tm"] += 1
        else:
            for p in d["p"]:
                kisa = wd_mevki_kisalt(poz_cache.get(p, ""))
                if kisa and kisa not in mevkiler:
                    mevkiler.append(kisa)
            mevkiler = mevkiler[:2]
            if mevkiler:
                kaynak["mevki_wd"] += 1

        # Uyruk
        kod = None
        spor = [u for u in d["s"] if u in ulke]
        if spor:
            kod = ulke[spor[0]]["kod"]
            kaynak["uyruk_wd_milli"] += 1
        elif tm_ulke and tm_ulke in ad_kod:
            kod = ad_kod[tm_ulke]
            kaynak["uyruk_tm"] += 1
        else:
            vat = sorted((u for u in d["v"] if u in ulke),
                         key=lambda u: (not re.fullmatch(r"[A-Z]{2}", ulke[u]["kod"]), u))
            if vat:
                kod = ulke[vat[0]]["kod"]
                kaynak["uyruk_wd_vatandas"] += 1

        if mevkiler or kod:
            detaylar[o["id"]] = {"m": mevkiler, "u": kod}
        if kod and kod not in ulke_adlari:
            eslesen = next((u for u in ulke.values() if u["kod"] == kod), None)
            if eslesen:
                ulke_adlari[kod] = eslesen["tr"] or eslesen["en"]

    kaydet(os.path.join(VERI, "details.json"), detaylar, kompakt=True)
    os.makedirs(CIKTI, exist_ok=True)
    kaydet(os.path.join(CIKTI, "countries.json"), ulke_adlari, kompakt=True)

    n = len(oyuncular)
    mevkili = sum(1 for d in detaylar.values() if d["m"])
    uyruklu = sum(1 for d in detaylar.values() if d["u"])
    print("\n=== DETAY ÖZETİ ===")
    print(f"Oyuncu            : {n}")
    print(f"Mevkisi bilinen   : {mevkili} (%{100 * mevkili // max(n, 1)}) "
          f"· TM {kaynak['mevki_tm']}, Wikidata {kaynak['mevki_wd']}")
    print(f"Uyruğu bilinen    : {uyruklu} (%{100 * uyruklu // max(n, 1)}) "
          f"· milli takım {kaynak['uyruk_wd_milli']}, TM {kaynak['uyruk_tm']}, "
          f"vatandaşlık {kaynak['uyruk_wd_vatandas']}")
    print(f"Farklı ülke       : {len(ulke_adlari)}")
    print(f"Mevki dağılımı    : " + ", ".join(
        f"{m} {c}" for m, c in Counter(m for d in detaylar.values() for m in d["m"][:1]).most_common()))

    print("\nKontrol:")
    ada_gore = {isim_anahtar(o["ad"]): o["id"] for o in oyuncular}
    for aranan in KONTROL:
        oid = ada_gore.get(isim_anahtar(aranan))
        d = detaylar.get(oid) if oid else None
        if not d:
            print(f"   {aranan}: bulunamadı")
            continue
        print(f"   {aranan}: {'/'.join(d['m']) or '?'} · {ulke_adlari.get(d['u'], d['u'] or '?')}")
    print("\nŞimdi: py hazirla.py")


if __name__ == "__main__":
    main()
