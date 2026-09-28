"""
Futbol XOX - Veri denetimi

Kaynak verilerdeki tutarsızlıkları bulur ve rapor yazar.

Kontroller:
    1) Kariyer - kulüp tutarsızlığı: oyuncunun kariyerinde bir kulüp var ama oyunda
       o kulübün oyuncusu sayılmıyor (ör. "David Luiz kariyerinde Benfica var").
       Bu durumda oyuncu doğru cevabı verse bile oyun "yanlış" der.
    2) Büyük kulüplerde şüpheli derecede az oyuncu (eksik veri belirtisi).

Kullanım (tools klasöründe, bütün veri hattı çalıştırıldıktan sonra):
    py denetle.py            -> sadece rapor (data/denetim_raporu.txt)
    py denetle.py --uygula   -> güvenli düzeltmeleri de uygular; sonra:
                                py tablo_uret.py  ve  py hazirla.py

Otomatik düzeltmeler data/duzeltmeler_otomatik.json'a yazılır ve veri her yeniden
üretildiğinde tm_birlestir.py tarafından tekrar uygulanır.
"""

import os
import re
import sys
from collections import defaultdict

from duzeltme import OTOMATIK, uygula
from seviye import GENEL_ADLAR, anahtar, kulup_anahtarlari
from tm_birlestir import kaydet, yukle

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
ASSETS = os.path.join("..", "assets", "data")
RAPOR = os.path.join(VERI, "denetim_raporu.txt")

MIN_POP = 10  # bu popülerliğin altındaki oyuncular rapora alınmaz


# Kariyerlerinden emin olunan oyuncular: veride bu kulüplerin hepsi olmalı.
# (Sadece oyundaki liglerde yer alan kulüpler yazıldı; listede olmayan kulüp atlanır.)
BILINEN = {
    "David Luiz": ["Benfica", "Chelsea", "PSG", "Arsenal", "Flamengo"],
    "Mauro Icardi": ["Sampdoria", "Inter", "PSG", "Galatasaray"],
    "Arda Turan": ["Galatasaray", "Atlético Madrid", "Barcelona", "Başakşehir"],
    "Mesut Özil": ["Schalke 04", "Werder Bremen", "Real Madrid", "Arsenal", "Fenerbahçe", "Başakşehir"],
    "Zlatan Ibrahimović": ["Ajax", "Juventus", "Inter", "Barcelona", "Milan", "PSG", "Manchester United"],
    "Cristiano Ronaldo": ["Sporting CP", "Manchester United", "Real Madrid", "Juventus", "Al-Nassr"],
    "Lionel Messi": ["Barcelona", "PSG"],
    "Neymar": ["Santos", "Barcelona", "PSG", "Al-Hilal"],
    "Karim Benzema": ["Lyon", "Real Madrid", "Al-Ittihad"],
    "Robin van Persie": ["Feyenoord", "Arsenal", "Manchester United", "Fenerbahçe"],
    "Wesley Sneijder": ["Ajax", "Real Madrid", "Inter", "Galatasaray"],
    "Didier Drogba": ["Marsilya", "Chelsea", "Galatasaray"],
    "Edin Džeko": ["Wolfsburg", "Manchester City", "Roma", "Inter", "Fenerbahçe"],
    "Ángel Di María": ["Rosario Central", "Benfica", "Real Madrid", "Manchester United", "PSG", "Juventus"],
    "Radamel Falcao": ["River Plate", "Porto", "Atlético Madrid", "Monaco", "Manchester United",
                       "Chelsea", "Galatasaray"],
    "Ricardo Quaresma": ["Sporting CP", "Barcelona", "Porto", "Inter", "Chelsea", "Beşiktaş"],
    "Pepe": ["Porto", "Real Madrid", "Beşiktaş"],
    "Gheorghe Hagi": ["Real Madrid", "Barcelona", "Galatasaray"],
    "Alex de Souza": ["Coritiba", "Palmeiras", "Flamengo", "Cruzeiro", "Fenerbahçe"],
    "Emre Belözoğlu": ["Galatasaray", "Inter", "Newcastle", "Fenerbahçe", "Atlético Madrid", "Başakşehir"],
    "Nihat Kahveci": ["Beşiktaş", "Real Sociedad", "Villarreal"],
    "Hamit Altıntop": ["Schalke 04", "Bayern Münih", "Real Madrid", "Galatasaray"],
    "Nuri Şahin": ["Dortmund", "Real Madrid", "Liverpool", "Werder Bremen"],
    "Arjen Robben": ["PSV", "Chelsea", "Real Madrid", "Bayern Münih"],
    "Luis Suárez": ["Ajax", "Liverpool", "Barcelona", "Atlético Madrid"],
    "Gonzalo Higuaín": ["River Plate", "Real Madrid", "Napoli", "Juventus", "Milan", "Chelsea"],
    "Samuel Eto'o": ["Real Madrid", "Barcelona", "Inter", "Chelsea", "Everton", "Antalyaspor", "Konyaspor"],
    "Roberto Carlos": ["Palmeiras", "Inter", "Real Madrid", "Fenerbahçe", "Corinthians"],
    "Kaká": ["São Paulo", "Milan", "Real Madrid"],
    "Ronaldinho": ["PSG", "Barcelona", "Milan", "Flamengo"],
    "Thierry Henry": ["Monaco", "Juventus", "Arsenal", "Barcelona"],
    "Fernando Torres": ["Atlético Madrid", "Liverpool", "Chelsea", "Milan"],
    "Sergio Ramos": ["Sevilla", "Real Madrid", "PSG"],
    "Mario Balotelli": ["Inter", "Manchester City", "Milan", "Liverpool", "Nice", "Marsilya"],
    "Fernando Muslera": ["Lazio", "Galatasaray"],
    "Burak Yılmaz": ["Beşiktaş", "Trabzonspor", "Fenerbahçe", "Galatasaray", "Lille"],
    "Hakan Çalhanoğlu": ["Leverkusen", "Milan", "Inter"],
    "Arda Güler": ["Fenerbahçe", "Real Madrid"],
    "Kerem Aktürkoğlu": ["Galatasaray", "Benfica"],
    "Victor Osimhen": ["Wolfsburg", "Lille", "Napoli", "Galatasaray"],
    "Mohamed Salah": ["Chelsea", "Fiorentina", "Roma", "Liverpool"],
    "Harry Kane": ["Tottenham", "Bayern Münih"],
    "Marco Asensio": ["Real Madrid", "PSG", "Aston Villa", "Fenerbahçe"],
    "Berke Özer": ["Fenerbahçe", "Lille"],
    "Hakan Şükür": ["Bursaspor", "Galatasaray", "Inter", "Parma"],
}


def bilinen_kariyer_testi(oyuncular, kulupler, kulup_adi):
    """BILINEN listesindeki her oyuncu-kulüp bilgisinin veride olup olmadığına bakar.
    Dönüş: (doğru sayısı, toplam, hatalar, atlananlar)"""
    kulup_bul = {}
    for k in kulupler:
        for a in kulup_anahtarlari(k):
            kulup_bul.setdefault(a, k["id"])
    isim_cache = os.path.join(VERI, "cache", "isimler.json")
    ingilizce = yukle(isim_cache) if os.path.exists(isim_cache) else {}
    oyuncu_bul = defaultdict(list)
    for o in oyuncular:
        for ad in {o["ad"], o.get("en", ""), ingilizce.get(o["id"], "")}:
            if ad:
                oyuncu_bul[anahtar(ad)].append(o)

    def en_uygun(adaylar, beklenen):
        """Aynı isimli oyunculardan beklenen kulüplere en çok uyan (eşitse en ünlü)."""
        ids = {kulup_bul.get(anahtar(k)) for k in beklenen}
        return max(adaylar, key=lambda o: (len(ids & set(o["kulupler"])), o["populerlik"]))

    dogru, toplam, hatalar, atlanan = 0, 0, [], []
    for isim, beklenen in BILINEN.items():
        adaylar = oyuncu_bul.get(anahtar(isim), [])
        o = en_uygun(adaylar, beklenen) if adaylar else None
        if not o:
            hatalar.append(f"{isim}: oyuncu veride bulunamadı")
            toplam += len(beklenen)
            continue
        eksik = []
        for kulup in beklenen:
            kid = kulup_bul.get(anahtar(kulup))
            if not kid:
                atlanan.append(f"{isim} - {kulup} (kulüp oyunda yok)")
                continue
            toplam += 1
            if kid in o["kulupler"]:
                dogru += 1
            else:
                eksik.append(kulup_adi.get(kid, kulup))
        if eksik:
            hatalar.append(f"{isim}: eksik kulüp -> {', '.join(eksik)}")
    return dogru, toplam, hatalar, atlanan


def main():
    uygula_modu = "--uygula" in sys.argv
    oyuncular = yukle(os.path.join(VERI, "players.json"))
    kulupler = yukle(os.path.join(VERI, "clubs.json"))
    app_kulupler = yukle(os.path.join(ASSETS, "clubs.json"))
    kariyerler = yukle(os.path.join(ASSETS, "careers.json"))

    oyuncu = {o["id"]: o for o in oyuncular}
    kulup_adi = {k["id"]: k["ad"] for k in app_kulupler}
    seviye = {k["id"]: k.get("t", 3) for k in app_kulupler}

    # Kariyerde görünen ad -> kulüp (sadece tek kulübe karşılık gelen adlar)
    ad_kulup = defaultdict(set)
    for k in app_kulupler:
        for ad in (k["ad"], k.get("tam_ad", ""), re.sub(r"\s*\(.*\)$", "", k["ad"])):
            if ad:
                ad_kulup[anahtar(ad)].add(k["id"])

    # 1) Kariyer - kulüp tutarsızlıkları
    eksikler = []
    for c in kariyerler:
        o = oyuncu.get(c["id"])
        if not o or o["populerlik"] < MIN_POP:
            continue
        for ad, yil in c["c"]:
            if ad.endswith("(Altyapı)"):
                continue
            key = anahtar(ad)
            kulupler_bu_adla = ad_kulup.get(key, set())
            if len(kulupler_bu_adla) != 1:
                continue
            kid = next(iter(kulupler_bu_adla))
            if kid not in o["kulupler"]:
                guvenli = (ad == kulup_adi.get(kid) and len(key) >= 5
                           and key not in GENEL_ADLAR)
                eksikler.append((o, kid, ad, yil, guvenli))

    # Aynı oyuncu + kulüp birden fazla stint olabilir: tekilleştir
    tekil = {}
    for e in eksikler:
        tekil.setdefault((e[0]["id"], e[1]), e)
    eksikler = sorted(tekil.values(), key=lambda e: -e[0]["populerlik"])

    # 2) Büyük kulüplerde az oyuncu
    dusuk = sorted((k for k in kulupler
                    if seviye.get(k["id"]) == 1 and k.get("oyuncu_sayisi", 0) < 300),
                   key=lambda k: k.get("oyuncu_sayisi", 0))

    # Rapor
    satirlar = ["FUTBOL XOX VERİ DENETİM RAPORU", "=" * 40, ""]
    satirlar.append(f"1) KARİYER - KULÜP TUTARSIZLIĞI: {len(eksikler)} kayıt")
    satirlar.append("   (Oyuncunun kariyerinde kulüp var ama oyunda o kulübün oyuncusu sayılmıyor)")
    satirlar.append("   [+] = --uygula ile otomatik düzeltilir, [?] = genel isim, elle kontrol et")
    for o, kid, ad, yil, guvenli in eksikler:
        isim = o.get("en") or o["ad"]
        satirlar.append(f"   {'[+]' if guvenli else '[?]'} {isim} ({o.get('dogum_yili') or '?'}) "
                        f"· kariyerde: {ad}{f' ({yil})' if yil else ''} · pop {o['populerlik']}")
    satirlar.append("")
    satirlar.append(f"2) AZ OYUNCULU BÜYÜK KULÜPLER: {len(dusuk)}")
    for k in dusuk:
        satirlar.append(f"   {kulup_adi.get(k['id'], k['ad'])}: {k.get('oyuncu_sayisi', 0)} oyuncu")
    with open(RAPOR, "w", encoding="utf-8") as f:
        f.write("\n".join(satirlar))

    # 3) Bilinen kariyerler testi
    dogru, toplam, hatalar, atlanan = bilinen_kariyer_testi(oyuncular, kulupler, kulup_adi)
    satirlar.append("")
    satirlar.append(f"3) BİLİNEN KARİYERLER TESTİ: {dogru}/{toplam} doğru")
    satirlar.extend(f"   ✗ {h}" for h in hatalar)
    satirlar.extend(f"   - atlandı: {a}" for a in atlanan)
    with open(RAPOR, "w", encoding="utf-8") as f:
        f.write("\n".join(satirlar))

    guvenli_sayi = sum(1 for e in eksikler if e[4])
    print("=== DENETİM ÖZETİ ===")
    print(f"Bilinen kariyerler testi   : {dogru}/{toplam} doğru "
          f"(%{100 * dogru // max(toplam, 1)})")
    for h in hatalar:
        print(f"   ✗ {h}")
    print(f"Kariyer-kulüp tutarsızlığı : {len(eksikler)} "
          f"({guvenli_sayi} otomatik düzeltilebilir, {len(eksikler) - guvenli_sayi} elle kontrol)")
    print(f"Az oyunculu büyük kulüp    : {len(dusuk)}")
    print("\nEn tanınmış 20 tutarsızlık:")
    for o, kid, ad, yil, guvenli in eksikler[:20]:
        print(f"   {'[+]' if guvenli else '[?]'} {o.get('en') or o['ad']}: kariyerinde "
              f"{ad}{f' ({yil})' if yil else ''} var, oyunda {kulup_adi[kid]} oyuncusu sayılmıyor")
    print(f"\nTam rapor: {RAPOR}")

    if uygula_modu:
        mevcut = yukle(OTOMATIK) if os.path.exists(OTOMATIK) else {"kulup_ekle": []}
        var_olan = {(d["id"], d["kulup"]) for d in mevcut["kulup_ekle"]}
        for o, kid, _, _, guvenli in eksikler:
            if guvenli and (o["id"], kid) not in var_olan:
                mevcut["kulup_ekle"].append({"id": o["id"], "kulup": kid})
        kaydet(OTOMATIK, mevcut)
        n, cozulemeyen = uygula(oyuncular, kulupler)
        kaydet(os.path.join(VERI, "players.json"), oyuncular, kompakt=True)
        dogru2, toplam2, hatalar2, _ = bilinen_kariyer_testi(oyuncular, kulupler, kulup_adi)
        print(f"\n{n} düzeltme uygulandı. Bilinen kariyerler testi şimdi: {dogru2}/{toplam2}")
        for h in hatalar2:
            print(f"   ✗ {h}")
        print("Şimdi: py tablo_uret.py  ve  py hazirla.py")
        for islem, d, sebep in cozulemeyen:
            print(f"   ! duzeltmeler.json: {d} -> {sebep}")
    elif guvenli_sayi:
        print("\nOtomatik düzeltmek için: py denetle.py --uygula")


if __name__ == "__main__":
    main()
