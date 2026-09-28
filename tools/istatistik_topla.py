"""
Futbol XOX - Oyuncu istatistikleri (Kart Düellosu ve Kadro Kur için)

Kaynaklar:
    - Transfermarkt veri seti, appearances.csv: her maçın gol, asist, sarı/kırmızı
      kart ve dakika kaydı. KAPSAM: 2012 sonrası, 14 Avrupa ligi + Avrupa kupaları.
      (Bu yüzden oyunda "2012 sonrası" olarak gösterilir; eski efsanelerde 0 olabilir.)
    - Transfermarkt players.csv: kariyerindeki en yüksek piyasa değeri
    - Transfermarkt players.csv'de varsa: milli maç ve gol (international_caps/goals)
      (Wikidata'daki milli maç bilgisi çok eksik olduğu için kullanılmıyor)

Kullanım (tools klasöründe, tm_birlestir.py'den sonra):
    py istatistik_topla.py
    py hazirla.py

Çıktı:
    data/stats.json -> {oyuncu: {"g": gol, "a": asist, "m": maç, "y": sarı, "r": kırmızı,
                                 "mm": milli maç, "mg": milli gol, "pv": en yüksek değer (milyon €)}}
"""

import os
import sys
from collections import defaultdict

from tm_birlestir import csv_oku, isim_anahtar, kaydet, yukle
from veri_topla import qid, sparql

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
WD_CACHE = os.path.join(VERI, "cache", "wd_milli.json")
WD_MIN_POP = 8      # milli maç bilgisi bu popülerliğin üstündekiler için çekilir
GRUP = 100
A_MILLI_TAKIM = "Q6979593"  # Wikidata: "national association football team" (A takımı)

KONTROL = ["Cristiano Ronaldo", "Lionel Messi", "Arda Turan", "Sergio Ramos",
           "Mauro Icardi", "Pepe", "Gheorghe Hagi", "Arda Güler"]


def sayi(deger):
    try:
        return int(float(deger or 0))
    except ValueError:
        return 0


def milli_istatistikler(wd_idler):
    """Oyuncuların A milli takım maç/gol sayıları (100'lük gruplar, önbellekli).
    "optimizer None" ipucu, sorgunun bizim oyuncu listemizden başlamasını sağlar;
    yoksa sunucu bütün milli takımları tarayıp zaman aşımına uğrar."""
    cache = yukle(WD_CACHE) if os.path.exists(WD_CACHE) else {}
    eksik = [i for i in wd_idler if i not in cache]
    print(f"Milli takım bilgileri: {len(wd_idler) - len(eksik)} hazır, {len(eksik)} indirilecek")
    for bas in range(0, len(eksik), GRUP):
        grup = eksik[bas:bas + GRUP]
        values = " ".join(f"wd:{i}" for i in grup)
        satirlar = sparql(f"""
          SELECT ?o ?takim ?mac ?gol WHERE {{
            hint:Query hint:optimizer "None" .
            VALUES ?o {{ {values} }}
            ?o p:P54 ?st . ?st ps:P54 ?takim .
            ?takim wdt:P31 wd:{A_MILLI_TAKIM} .
            OPTIONAL {{ ?st pq:P1350 ?mac . }}
            OPTIONAL {{ ?st pq:P1351 ?gol . }}
          }}""")
        # Aynı milli takım için birden fazla kayıt olabilir (farklı dönemler) -> topla;
        # birden fazla ülke varsa (ör. gençlikte başka ülke) en çok maç yapılanı al
        takim_toplam = defaultdict(lambda: defaultdict(lambda: [0, 0]))
        for s in satirlar:
            o = qid(s["o"]["value"])
            t = takim_toplam[o][qid(s["takim"]["value"])]
            t[0] += sayi(s.get("mac", {}).get("value"))
            t[1] += sayi(s.get("gol", {}).get("value"))
        for i in grup:
            takimlar = takim_toplam.get(i)
            cache[i] = max(takimlar.values(), key=lambda t: t[0]) if takimlar else [0, 0]
        kaydet(WD_CACHE, cache, kompakt=True)
        biten = min(bas + GRUP, len(eksik))
        if biten % (GRUP * 10) == 0 or biten == len(eksik):
            print(f"   {biten}/{len(eksik)}")
    return cache


def main():
    oyuncular = yukle(os.path.join(VERI, "players.json"))
    if not oyuncular or "kaynak" not in oyuncular[0]:
        sys.exit("HATA: Önce 'py tm_birlestir.py' çalıştırılmalı.")

    # Transfermarkt oyuncu ID -> bizim oyuncu ID
    tm_bizim = {}
    for o in oyuncular:
        tm = o.get("tm") or (o["id"][2:] if o["id"].startswith("TM") else None)
        if tm:
            tm_bizim[tm] = o["id"]

    # 1) Maç kayıtlarından toplamlar
    print("Maç kayıtları okunuyor (appearances.csv, birkaç dakika sürebilir)...")
    toplam = defaultdict(lambda: {"g": 0, "a": 0, "m": 0, "y": 0, "r": 0})
    f, okuyucu = csv_oku("appearances.csv", ["player_id", "goals", "assists",
                                             "yellow_cards", "red_cards"])
    for i, r in enumerate(okuyucu, 1):
        oid = tm_bizim.get(r["player_id"])
        if oid:
            t = toplam[oid]
            t["g"] += sayi(r["goals"])
            t["a"] += sayi(r["assists"])
            t["m"] += 1
            t["y"] += sayi(r["yellow_cards"])
            t["r"] += sayi(r["red_cards"])
        if i % 500_000 == 0:
            print(f"   {i:,} satır")
    f.close()

    # 2) En yüksek piyasa değeri + (varsa) milli maç/gol sütunları
    f, okuyucu = csv_oku("players.csv", ["player_id", "highest_market_value_in_eur"])
    milli_sutun = {"international_caps", "international_goals"} <= set(okuyucu.fieldnames or [])
    deger = {}
    milli = {}
    for r in okuyucu:
        oid = tm_bizim.get(r["player_id"])
        if not oid:
            continue
        v = sayi(r["highest_market_value_in_eur"])
        if v:
            deger[oid] = round(v / 1_000_000, 1)
        if milli_sutun:
            milli[oid] = [sayi(r["international_caps"]), sayi(r["international_goals"])]
    f.close()

    # 3) Milli takım: Wikidata'daki milli maç bilgisi çok eksik ve güvenilmez olduğu
    #    için (ör. Ronaldo 10 maç görünüyor) sadece Transfermarkt sütunları varsa kullanılır.
    if milli_sutun:
        print("Milli maç/gol: Transfermarkt players.csv sütunlarından alındı")
    else:
        print("Not: players.csv'de milli maç sütunları yok; milli maç istatistiği "
              "kullanılmayacak (kartlarda yerine Sarı Kart gösterilir)")

    # 4) Birleştir (sadece sıfırdan farklı değerler; dosya küçük kalsın)
    istatistik = {}
    for o in oyuncular:
        s = dict(toplam.get(o["id"], {}))
        if o["id"] in milli:
            s["mm"], s["mg"] = milli[o["id"]]
        if o["id"] in deger:
            s["pv"] = deger[o["id"]]
        s = {k: v for k, v in s.items() if v}
        if s:
            istatistik[o["id"]] = s
    kaydet(os.path.join(VERI, "stats.json"), istatistik, kompakt=True)

    n = len(oyuncular)
    def kac(k):
        return sum(1 for s in istatistik.values() if k in s)
    print("\n=== İSTATİSTİK ÖZETİ ===")
    print(f"Oyuncu                       : {n}")
    print(f"Maç istatistiği olan (2012+) : {kac('m')}")
    print(f"Milli maç bilgisi olan       : {kac('mm')}")
    print(f"Piyasa değeri olan           : {kac('pv')}")

    print("\nKontrol (2012+ Avrupa: gol/asist/maç/sarı/kırmızı · milli maç/gol · en yüksek değer):")
    ada_gore = {}
    for o in oyuncular:
        ada_gore.setdefault(isim_anahtar(o["ad"]), o["id"])
        if o.get("en"):
            ada_gore.setdefault(isim_anahtar(o["en"]), o["id"])
    for aranan in KONTROL:
        s = istatistik.get(ada_gore.get(isim_anahtar(aranan)), {})
        print(f"   {aranan:20} {s.get('g', 0)}g {s.get('a', 0)}a {s.get('m', 0)}m "
              f"{s.get('y', 0)}sk {s.get('r', 0)}kk · milli {s.get('mm', 0)}/{s.get('mg', 0)} "
              f"· €{s.get('pv', 0)}M")
    print("\nŞimdi: py hazirla.py")


if __name__ == "__main__":
    main()
