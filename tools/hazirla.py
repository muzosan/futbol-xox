"""
Futbol XOX - Uygulama verisi hazırlama
tools/data içindeki verileri Flutter uygulamasının kullanacağı hale getirir.

Kullanım (tools klasöründe):
    py hazirla.py

Yaptıkları:
    1) Wikidata oyuncularının İngilizce isimlerini çeker
       -> arama kutusu hem "Mkhitaryan" hem "Mhitaryan" yazımını tanır
    2) Kulüp bilgilerini uygulamanın beklediği biçime getirir
    3) Dosyaları küçültüp ../assets/data/ klasörüne yazar

Çıktılar (futbol_xox/assets/data/):
    clubs.json, players.json, grids.json
"""

import json
import os
import sys
import time

from seviye import GORUNEN_AD, kulup_seviyeleri
from veri_topla import API_URL, KISA_AD, istek, kisalt  # aynı bağlantı ayarlarını (mailin dahil) kullanır

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
CIKTI = os.path.join("..", "assets", "data")
ISIM_CACHE = os.path.join(VERI, "cache", "isimler.json")



def yukle(yol):
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def yaz(yol, veri):
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False, separators=(",", ":"))


def ingilizce_isimleri_cek(idler):
    """50'şerli gruplar halinde İngilizce isimleri çeker; yarıda kalırsa kaldığı yerden devam eder."""
    isimler = yukle(ISIM_CACHE) if os.path.exists(ISIM_CACHE) else {}
    eksik = [i for i in idler if i not in isimler]
    print(f"İngilizce isimler: {len(idler) - len(eksik)} hazır, {len(eksik)} indirilecek")

    for bas in range(0, len(eksik), 50):
        grup = eksik[bas:bas + 50]
        cevap = istek(API_URL, {
            "action": "wbgetentities", "ids": "|".join(grup),
            "props": "labels", "languages": "en", "format": "json",
        })
        for qid in grup:
            etiket = cevap.get("entities", {}).get(qid, {}).get("labels", {}).get("en")
            isimler[qid] = etiket["value"] if etiket else ""
        yaz(ISIM_CACHE, isimler)
        biten = min(bas + 50, len(eksik))
        if biten % 500 == 0 or biten == len(eksik):
            print(f"   {biten}/{len(eksik)}")
        time.sleep(0.5)
    return isimler


KULUP_EN_CACHE = os.path.join(VERI, "cache", "kulup_en.json")

# KISA_AD'daki Türkçeye özgü kısaltmaların İngilizcesi
TR_OZEL_EN = {"Marsilya": "Marseille", "Bayern Münih": "Bayern Munich"}


def kulup_ingilizce_adlari(kulupler):
    """Kulüplerin İngilizce kısa adları (diğer dillerde gösterilir)."""
    cache = yukle(KULUP_EN_CACHE) if os.path.exists(KULUP_EN_CACHE) else {}
    eksik = [k["id"] for k in kulupler if k["id"] not in cache]
    for bas in range(0, len(eksik), 50):
        grup = eksik[bas:bas + 50]
        cevap = istek(API_URL, {"action": "wbgetentities", "ids": "|".join(grup),
                                "props": "labels", "languages": "en", "format": "json"})
        for q in grup:
            e = cevap.get("entities", {}).get(q, {}).get("labels", {}).get("en")
            cache[q] = e["value"] if e else ""
        yaz(KULUP_EN_CACHE, cache)
    adlar = {}
    for k in kulupler:
        etiket = cache.get(k["id"], "")
        if not etiket:
            continue
        kisa = KISA_AD.get(etiket) or kisalt(etiket)
        adlar[k["id"]] = TR_OZEL_EN.get(kisa, kisa)
    return adlar


def main():
    kulupler = yukle(os.path.join(VERI, "clubs.json"))
    oyuncular = yukle(os.path.join(VERI, "players.json"))
    tablolar = yukle(os.path.join(VERI, "grids.json"))

    # Arama kutusu herkesi bulsun: tek kulüplü oyuncular da yazılabilmeli,
    # yanlışsa oyun "yanlış" desin. (Transfermarkt'tan gelen "TM..." ID'lerin
    # isimleri zaten standart yazımda, onlar için Wikidata'ya sorulmaz.)
    adaylar = oyuncular
    # İngilizce isimlerin çoğu veri_topla.py'de alındı; eksik kalanlar burada çekilir
    isimler = ingilizce_isimleri_cek(
        [o["id"] for o in adaylar if o["id"].startswith("Q") and not o.get("en")])

    # İstatistikler (istatistik_topla.py çalıştırıldıysa)
    ist_yolu = os.path.join(VERI, "stats.json")
    istatistikler = yukle(ist_yolu) if os.path.exists(ist_yolu) else {}
    if not istatistikler:
        print("Not: data/stats.json yok; Kart Düellosu ve Kadro Kur için py istatistik_topla.py")

    # Mevki ve uyruk (detay_topla.py çalıştırıldıysa)
    detay_yolu = os.path.join(VERI, "details.json")
    detaylar = yukle(detay_yolu) if os.path.exists(detay_yolu) else {}
    if not detaylar:
        print("Not: data/details.json yok; mevki/uyruk eklenmeyecek (py detay_topla.py)")

    app_oyuncular = []
    for o in adaylar:
        tr = o["ad"]
        en = o.get("en") or isimler.get(o["id"]) or tr
        kayit = {
            "id": o["id"],
            "ad": en,                    # ekranda görünen ad (İngilizce yazım daha standart)
            "p": o["populerlik"],
            "k": o["kulupler"],
        }
        if tr != en:
            kayit["tr"] = tr             # aramada Türkçe yazım da bulunsun
        if o["id"] in istatistikler:
            kayit["s"] = istatistikler[o["id"]]  # gol, asist, maç, kart, milli, değer
        detay = detaylar.get(o["id"])
        if detay:
            if detay.get("m"):
                kayit["m"] = detay["m"]   # mevki kısaltmaları, ör. ["CB"]
            if detay.get("u"):
                kayit["u"] = detay["u"]   # ülke kodu, ör. "TR"
        if o["dogum_yili"]:
            kayit["y"] = o["dogum_yili"]  # aynı isimli oyuncuları ayırmak için
        app_oyuncular.append(kayit)

    seviye, bulunamayan = kulup_seviyeleri(kulupler, oyuncular)
    if bulunamayan:
        print("Not: şu büyük kulüpler verinizde bulunamadı: " + ", ".join(bulunamayan))

    # Forma desenleri ve renkleri (forma_topla.py çalıştırıldıysa)
    forma_yolu = os.path.join(VERI, "kits.json")
    formalar = yukle(forma_yolu) if os.path.exists(forma_yolu) else {}
    if not formalar:
        print("Not: data/kits.json yok; formalar varsayılan renkte görünecek (py forma_topla.py)")

    en_adlar = kulup_ingilizce_adlari(kulupler)
    app_kulupler = [{
        "id": k["id"],
        "ad": GORUNEN_AD.get(k["ad"], k["ad"]),
        **({"en": en_adlar[k["id"]]} if en_adlar.get(k["id"]) else {}),  # diğer diller için
        "tam_ad": k.get("tam_ad", k["ad"]),
        "t": seviye[k["id"]],   # 1 = büyük kulüp, 2 = tanınmış, 3 = diğer
        **({"f": formalar[k["id"]]} if k["id"] in formalar else {}),  # forma
        "lig": k["lig"],
    } for k in kulupler]

    app_tablolar = [{
        "id": t["id"], "z": t["zorluk"], "s": t["satirlar"], "c": t["sutunlar"],
        "n": t["cevap_sayilari"],
    } for t in tablolar]

    os.makedirs(CIKTI, exist_ok=True)
    yaz(os.path.join(CIKTI, "clubs.json"), app_kulupler)
    yaz(os.path.join(CIKTI, "players.json"), app_oyuncular)
    yaz(os.path.join(CIKTI, "grids.json"), app_tablolar)

    print("\n=== HAZIRLIK ÖZETİ ===")
    print(f"Kulüp   : {len(app_kulupler)}")
    print(f"Oyuncu  : {len(app_oyuncular)} ({sum(1 for o in app_oyuncular if 'tr' in o)} tanesinin ayrı Türkçe yazımı var)")
    print(f"Tablo   : {len(app_tablolar)}")
    print(f"Mevkili : {sum(1 for o in app_oyuncular if 'm' in o)} · "
          f"Uyruklu: {sum(1 for o in app_oyuncular if 'u' in o)}")
    for ad in ("clubs.json", "players.json", "grids.json"):
        boyut = os.path.getsize(os.path.join(CIKTI, ad)) / 1024
        print(f"   {ad:13} {boyut:7.0f} KB")
    print(f"\nDosyalar '{os.path.abspath(CIKTI)}' klasörüne yazıldı.")


if __name__ == "__main__":
    main()
