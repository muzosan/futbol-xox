"""
Futbol XOX - Tablo üretici
data/ klasöründeki verilerden oynanabilir 3x3 tablolar üretir.

Kullanım:
    py tablo_uret.py

Çıktı:
    data/grids.json -> zorluk seviyelerine ayrılmış tablolar

Kurallar:
    - 6 kulüp birbirinden farklı (3 satır + 3 sütun)
    - Her hücrede en az MIN_CEVAP doğru cevap ve en az 1 tanınmış oyuncu var
    - Bir tabloda aynı ligden en fazla MAX_AYNI_LIG kulüp olur (hep İtalyan tablosu çıkmasın)
    - Az kullanılan kulüpler öncelikli seçilir (kulüpler dengeli dağılsın)
    - Tabloların yaklaşık TURK_ORANI kadarında en az bir Süper Lig kulübü olur
"""

import json
import os
import random
import sys
from collections import Counter, defaultdict
from functools import lru_cache
from itertools import combinations

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
TANINMIS_ESIK = 15      # veri_topla.py ile aynı olmalı
MIN_CEVAP = 3           # her hücrede en az bu kadar doğru cevap
MAX_AYNI_LIG = 3
TURK_ORANI = 0.3
HEDEF = {"kolay": 300, "orta": 300, "zor": 300}
DENEME = 300_000
TOHUM = 42              # aynı sonuçları tekrar almak için sabit; değiştirirsen farklı tablolar çıkar


# Hücre zorluğu (tanınmış cevap sayısına göre): 6+ kolay, 3-5 orta, 1-2 zor
def zorluk_hesapla(hucreler):
    """Tablonun zorluğu, zor ve kolay hücrelerin sayısına göre belirlenir."""
    taninmislar = [t for satir in hucreler for _, t in satir]
    if min(taninmislar) < 1:
        return None
    zor_hucre = sum(1 for t in taninmislar if t <= 2)
    kolay_hucre = sum(1 for t in taninmislar if t >= 6)
    if zor_hucre == 0 and kolay_hucre >= 6:
        return "kolay"
    if zor_hucre >= 3:
        return "zor"
    return "orta"


# Hedeflenen zorluğa göre sütun seçerken her hücrede istenen en az tanınmış cevap
HUCRE_ESIK = {"kolay": 3, "orta": 2, "zor": 1}


def yukle(ad):
    with open(os.path.join(VERI, ad), encoding="utf-8") as f:
        return json.load(f)


def main():
    random.seed(TOHUM)
    kulupler = yukle("clubs.json")
    oyuncular = yukle("players.json")

    kulup_ad = {k["id"]: k["ad"] for k in kulupler}
    kulup_lig = {k["id"]: k["lig"] for k in kulupler}
    tum_kulupler = list(kulup_ad)
    turk_kulupler = [k for k in tum_kulupler if kulup_lig[k] == "Süper Lig"]

    # Her kulüp çifti için ortak oyuncular (popülerliğe göre)
    ortak = defaultdict(list)
    for o in oyuncular:
        for a, b in combinations(sorted(o["kulupler"]), 2):
            ortak[(a, b)].append((o["populerlik"], o["ad"]))

    @lru_cache(maxsize=None)  # her çift bir kez hesaplanır, sonra hafızadan okunur
    def hucre(a, b):
        liste = ortak.get(tuple(sorted((a, b))), [])
        taninmis = sum(1 for p, _ in liste if p >= TANINMIS_ESIK)
        return len(liste), taninmis

    def uygun(a, b, esik):
        toplam, taninmis = hucre(a, b)
        return toplam >= MIN_CEVAP and taninmis >= esik

    # Kolay tablolar için: çok sayıda güçlü bağlantısı olan (büyük) kulüpler
    guc = {a: sum(1 for b in tum_kulupler if b != a and hucre(a, b)[1] >= 6) for a in tum_kulupler}
    buyuk_kulupler = [c for c in tum_kulupler if guc[c] >= 8]
    buyuk_turk = [c for c in turk_kulupler if c in buyuk_kulupler] or turk_kulupler

    kullanim = Counter()

    def agirlikli_sec(adaylar, adet):
        """Az kullanılmış kulüplere daha çok şans veren tekrarsız seçim."""
        adaylar = list(adaylar)
        secilen = []
        for _ in range(adet):
            if not adaylar:
                return None
            agirlik = [1 / (1 + kullanim[c]) for c in adaylar]
            c = random.choices(adaylar, weights=agirlik, k=1)[0]
            secilen.append(c)
            adaylar.remove(c)
        return secilen

    tablolar = {z: [] for z in HEDEF}
    gorulen = set()

    print("Tablolar üretiliyor...")
    son_ilerleme = 0
    for deneme in range(1, DENEME + 1):
        if all(len(tablolar[z]) >= HEDEF[z] for z in HEDEF):
            break
        if deneme - son_ilerleme > 50_000:
            print("   Uzun süredir yeni tablo bulunamadı, durduruluyor.")
            break
        if deneme % 25_000 == 0:
            durum = ", ".join(f"{z}: {len(tablolar[z])}" for z in HEDEF)
            print(f"   {deneme} deneme -> {durum}")

        # Henüz dolmamış bir zorluk seviyesini hedefle
        hedef_z = random.choice([z for z in HEDEF if len(tablolar[z]) < HEDEF[z]])
        esik = HUCRE_ESIK[hedef_z]

        # Satırları seç (yarısında ilk satır bir Türk kulübü)
        havuz = buyuk_kulupler if hedef_z == "kolay" else tum_kulupler
        turk_havuz = buyuk_turk if hedef_z == "kolay" else turk_kulupler
        if random.random() < TURK_ORANI:
            ilk = agirlikli_sec(turk_havuz, 1)
            kalan = agirlikli_sec([c for c in havuz if c not in ilk], 2)
            satirlar = ilk + kalan if kalan else None
        else:
            satirlar = agirlikli_sec(havuz, 3)
        if not satirlar:
            continue

        # Üç satırın hepsiyle uyumlu sütun adayları
        adaylar = [c for c in tum_kulupler
                   if c not in satirlar and all(uygun(s, c, esik) for s in satirlar)]
        sutunlar = agirlikli_sec(adaylar, 3)
        if not sutunlar:
            continue

        # Aynı ligden çok fazla kulüp olmasın
        lig_sayisi = Counter(kulup_lig[c] for c in satirlar + sutunlar)
        if max(lig_sayisi.values()) > MAX_AYNI_LIG:
            continue

        # Aynı tablo (veya satır/sütun yer değiştirmiş hali) tekrar etmesin
        imza = frozenset([frozenset(satirlar), frozenset(sutunlar)])
        if imza in gorulen:
            continue

        hucreler = [[hucre(s, c) for c in sutunlar] for s in satirlar]
        z = zorluk_hesapla(hucreler)
        if z is None or len(tablolar[z]) >= HEDEF[z]:
            continue

        # Satır/sütun sırasını karıştır ki Türk kulübü hep sol üstte olmasın
        random.shuffle(satirlar)
        random.shuffle(sutunlar)
        if random.random() < 0.5:
            satirlar, sutunlar = sutunlar, satirlar
        hucreler = [[hucre(s, c) for c in sutunlar] for s in satirlar]

        gorulen.add(imza)
        son_ilerleme = deneme
        kullanim.update(satirlar + sutunlar)
        tablolar[z].append({
            "id": f"{z[0]}{len(tablolar[z]) + 1:04d}",
            "zorluk": z,
            "satirlar": satirlar,
            "sutunlar": sutunlar,
            # İpucu için: "Bu hücrede X doğru cevap var"
            "cevap_sayilari": [[t for t, _ in satir] for satir in hucreler],
            "taninmis_sayilari": [[n for _, n in satir] for satir in hucreler],
        })

    hepsi = [t for z in HEDEF for t in tablolar[z]]
    with open(os.path.join(VERI, "grids.json"), "w", encoding="utf-8") as f:
        json.dump(hepsi, f, ensure_ascii=False, indent=1)

    # --- Özet ---
    print("=== TABLO ÜRETİCİ ÖZETİ ===")
    for z in HEDEF:
        print(f"{z:6}: {len(tablolar[z])} / {HEDEF[z]} tablo")
    turkler = sum(1 for t in hepsi if any(c in turk_kulupler for c in t["satirlar"] + t["sutunlar"]))
    print(f"Türk kulübü içeren: {turkler} / {len(hepsi)}")

    if kullanim:
        en_cok = kullanim.most_common(3)
        en_az = sorted(tum_kulupler, key=lambda c: kullanim[c])[:3]
        print("En çok kullanılan : " + ", ".join(f"{kulup_ad[c]} ({n})" for c, n in en_cok))
        print("En az kullanılan  : " + ", ".join(f"{kulup_ad[c]} ({kullanim[c]})" for c in en_az))

    # Her zorluktan bir örnek tablo, hücre başına en bilinen 2 cevapla
    for z in HEDEF:
        if not tablolar[z]:
            continue
        t = tablolar[z][0]
        print(f"\n--- Örnek {z.upper()} tablo ({t['id']}) ---")
        print("Sütunlar: " + " | ".join(kulup_ad[c] for c in t["sutunlar"]))
        for s in t["satirlar"]:
            print(f"\n{kulup_ad[s]}")
            for c in t["sutunlar"]:
                liste = sorted(ortak[tuple(sorted((s, c)))], reverse=True)
                ornek = ", ".join(ad for _, ad in liste[:2])
                print(f"   x {kulup_ad[c]:28} {len(liste):3} cevap  örn: {ornek}")

    print(f"\n{len(hepsi)} tablo '{VERI}/grids.json' dosyasına kaydedildi.")


if __name__ == "__main__":
    main()
