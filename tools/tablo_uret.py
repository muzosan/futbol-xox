"""
Futbol XOX - Tablo üretici
data/ klasöründeki verilerden oynanabilir 3x3 tablolar üretir.

Kullanım:
    py tablo_uret.py

Zorluklar (kulüp seviyeleri için seviye.py'ye bak):
    kolay : sadece büyük kulüpler (seviye 1); her hücrede en az 3 ÇOK ÜNLÜ cevap
    orta  : büyükler + tanınmış kulüpler (seviye 1-2); her hücrede en az 2 ünlü cevap
    zor   : bütün kulüpler; her hücrede en az 1 tanınmış cevap, birkaç hücre zorlayıcı
Ortak kurallar:
    - 6 farklı kulüp, her hücrede en az MIN_CEVAP doğru cevap
    - Bir tabloda aynı ligden en fazla MAX_AYNI_LIG kulüp
    - Tabloların yaklaşık TURK_ORANI kadarında en az bir Türk kulübü
"""

import json
import os
import random
import sys
from collections import Counter, defaultdict
from itertools import combinations

from seviye import kulup_seviyeleri

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
MIN_CEVAP = 3
MAX_AYNI_LIG = 3
TURK_ORANI = 0.3
TURK_LIGLER = {"Süper Lig", "TFF 1. Lig", "TFF 2. Lig", "TFF 3. Lig"}
DENEME = 400_000
TOHUM = 42

# zorluk: (izinli kulüp seviyeleri, "ünlü" popülerlik eşiği, hücre başına en az ünlü cevap, hedef)
AYAR = {
    "kolay": ({1}, 30, 3, 400),
    "orta": ({1, 2}, 20, 2, 500),
    "zor": ({1, 2, 3}, 10, 1, 500),
}
# Bir zorlukta uzun süre tablo bulunamazsa sırayla denenecek daha gevşek şartlar
GEVSETME = {
    "kolay": [(25, 3), (25, 2), (20, 2)],
    "orta": [(15, 2), (15, 1)],
    "zor": [],
}


def yukle(ad):
    with open(os.path.join(VERI, ad), encoding="utf-8") as f:
        return json.load(f)


def main():
    random.seed(TOHUM)
    kulupler = yukle("clubs.json")
    oyuncular = yukle("players.json")
    kulup_ad = {k["id"]: k["ad"] for k in kulupler}
    kulup_lig = {k["id"]: k["lig"] for k in kulupler}
    seviye, bulunamayan = kulup_seviyeleri(kulupler, oyuncular)

    esikler = sorted({a[1] for a in AYAR.values()} |
                     {e for g in GEVSETME.values() for e, _ in g} | {20})
    toplam = Counter()
    unlu = {e: Counter() for e in esikler}   # eşik -> kulüp çifti -> ünlü ortak sayısı
    ornek = defaultdict(list)
    un = Counter()
    for o in oyuncular:
        pop = o["populerlik"]
        if pop >= 15:
            un.update(o["kulupler"])
        for a, b in combinations(sorted(o["kulupler"]), 2):
            toplam[(a, b)] += 1
            for e in esikler:
                if pop >= e:
                    unlu[e][(a, b)] += 1
            if len(ornek[(a, b)]) < 2:
                ornek[(a, b)].append(o["ad"])

    def anahtar(a, b):
        return (a, b) if a < b else (b, a)

    def komsuluk(izinli, esik, en_az):
        """kulüp -> birlikte geçerli hücre oluşturabileceği kulüpler"""
        k = defaultdict(set)
        for (a, b), n in toplam.items():
            if n >= MIN_CEVAP and a in izinli and b in izinli and unlu[esik][(a, b)] >= en_az:
                k[a].add(b)
                k[b].add(a)
        return k

    komsu = {}
    havuzlar = {}
    for z, (seviyeler, esik, en_az, _) in AYAR.items():
        izinli = {k for k in kulup_ad if seviye[k] in seviyeler and un[k] > 0}
        havuzlar[z] = sorted(izinli)
        komsu[z] = komsuluk(izinli, esik, en_az)
        print(f"{z:6}: {len(izinli)} kulüp havuzda")
    gevsetme_adimi = {z: 0 for z in AYAR}
    son_bulunan = {z: 0 for z in AYAR}
    if bulunamayan:
        print("Not: şu büyük kulüpler verinizde bulunamadı: " + ", ".join(bulunamayan))

    kullanim = Counter()

    def sec(adaylar, adet):
        adaylar = list(adaylar)
        secilen = []
        for _ in range(adet):
            if not adaylar:
                return None
            agirlik = [(un[c] ** 0.5 + 1) / (1 + kullanim[c]) for c in adaylar]
            c = random.choices(adaylar, weights=agirlik, k=1)[0]
            secilen.append(c)
            adaylar.remove(c)
        return secilen

    tablolar = {z: [] for z in AYAR}
    gorulen = set()
    son_ilerleme = 0
    print("Tablolar üretiliyor...")

    for deneme in range(1, DENEME + 1):
        eksik = [z for z in AYAR if len(tablolar[z]) < AYAR[z][3]]
        if not eksik:
            break
        if deneme - son_ilerleme > 60_000:
            print("   Uzun süredir yeni tablo bulunamadı, durduruluyor.")
            break
        if deneme % 50_000 == 0:
            print("   " + str(deneme) + " deneme -> " +
                  ", ".join(f"{z}: {len(tablolar[z])}" for z in AYAR))

        z = random.choice(eksik)
        # Bu zorlukta uzun süredir tablo çıkmıyorsa şartı bir kademe gevşet
        if deneme - son_bulunan[z] > 15_000 and gevsetme_adimi[z] < len(GEVSETME[z]):
            esik, en_az = GEVSETME[z][gevsetme_adimi[z]]
            gevsetme_adimi[z] += 1
            son_bulunan[z] = deneme
            son_ilerleme = deneme
            komsu[z] = komsuluk(set(havuzlar[z]), esik, en_az)
            print(f"   ! {z}: yeterli tablo bulunamıyor, şart gevşetildi "
                  f"(hücre başına en az {en_az} oyuncu, popülerlik {esik}+)")
        havuz = havuzlar[z]
        turk = [c for c in havuz if kulup_lig[c] in TURK_LIGLER]

        if turk and random.random() < TURK_ORANI:
            ilk = sec(turk, 1)
            kalan = sec([c for c in havuz if c not in ilk], 2)
            satirlar = ilk + kalan if kalan else None
        else:
            satirlar = sec(havuz, 3)
        if not satirlar:
            continue

        k = komsu[z]
        adaylar = (k[satirlar[0]] & k[satirlar[1]] & k[satirlar[2]]) - set(satirlar)
        sutunlar = sec(adaylar, 3)
        if not sutunlar:
            continue
        if max(Counter(kulup_lig[c] for c in satirlar + sutunlar).values()) > MAX_AYNI_LIG:
            continue
        imza = frozenset([frozenset(satirlar), frozenset(sutunlar)])
        if imza in gorulen:
            continue

        # Zor tablolar gerçekten zorlasın: en az 2 hücrede en fazla 1 ünlü (20+) cevap
        if z == "zor":
            zor_hucre = sum(1 for s in satirlar for c in sutunlar
                            if unlu[20][anahtar(s, c)] <= 1)
            if zor_hucre < 2:
                continue

        random.shuffle(satirlar)
        random.shuffle(sutunlar)
        if random.random() < 0.5:
            satirlar, sutunlar = sutunlar, satirlar

        gorulen.add(imza)
        son_ilerleme = deneme
        son_bulunan[z] = deneme
        kullanim.update(satirlar + sutunlar)
        tablolar[z].append({
            "id": f"{z[0]}{len(tablolar[z]) + 1:04d}",
            "zorluk": z,
            "satirlar": satirlar,
            "sutunlar": sutunlar,
            "cevap_sayilari": [[toplam[anahtar(s, c)] for c in sutunlar] for s in satirlar],
        })

    hepsi = [t for z in AYAR for t in tablolar[z]]
    with open(os.path.join(VERI, "grids.json"), "w", encoding="utf-8") as f:
        json.dump(hepsi, f, ensure_ascii=False, indent=1)

    print("\n=== TABLO ÜRETİCİ ÖZETİ ===")
    for z in AYAR:
        print(f"{z:6}: {len(tablolar[z])} / {AYAR[z][3]} tablo")
    turkler = sum(1 for t in hepsi
                  if any(kulup_lig[c] in TURK_LIGLER for c in t["satirlar"] + t["sutunlar"]))
    print(f"Türk kulübü içeren: {turkler} / {len(hepsi)}")
    print("Büyük kulüpler (seviye 1): " +
          ", ".join(sorted(kulup_ad[c] for c in kulup_ad if seviye[c] == 1)))

    for z in AYAR:
        if not tablolar[z]:
            continue
        t = random.choice(tablolar[z])
        print(f"\n--- Örnek {z.upper()} tablo ({t['id']}) ---")
        print("Sütunlar: " + " | ".join(kulup_ad[c] for c in t["sutunlar"]))
        for s in t["satirlar"]:
            print(f"{kulup_ad[s]}")
            for c in t["sutunlar"]:
                key = anahtar(s, c)
                print(f"   x {kulup_ad[c]:22} {toplam[key]:3} cevap  örn: {', '.join(ornek[key])}")

    print(f"\n{len(hepsi)} tablo '{VERI}/grids.json' dosyasına kaydedildi.")


if __name__ == "__main__":
    main()
