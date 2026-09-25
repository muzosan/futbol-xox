"""
Futbol XOX - Uygulama verisi hazırlama
tools/data içindeki verileri Flutter uygulamasının kullanacağı hale getirir.

Kullanım (tools klasöründe):
    py hazirla.py

Yaptıkları:
    1) Doğru cevap olabilecek oyuncuların (2+ kulüp) İngilizce isimlerini Wikidata'dan çeker
       -> arama kutusu hem "Mkhitaryan" hem "Mhitaryan" yazımını tanır
    2) Kulüplere kısa, okunaklı isimler verir (FC Internazionale Milano -> Inter)
    3) Dosyaları küçültüp ../assets/data/ klasörüne yazar

Çıktılar (futbol_xox/assets/data/):
    clubs.json, players.json, grids.json
"""

import json
import os
import sys
import time

from veri_topla import istek, API_URL  # aynı bağlantı ayarlarını (mailin dahil) kullanır

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
CIKTI = os.path.join("..", "assets", "data")
ISIM_CACHE = os.path.join(VERI, "cache", "isimler.json")

# Oyunda görünecek kısa kulüp adları
KISA_AD = {
    "İstanbul Başakşehir FK": "Başakşehir", "Kasımpaşa SK": "Kasımpaşa", "Göztepe SK": "Göztepe",
    "Manchester United FC": "Manchester United", "Liverpool FC": "Liverpool",
    "Arsenal FC": "Arsenal", "Chelsea FC": "Chelsea", "Manchester City FC": "Manchester City",
    "Tottenham Hotspur FC": "Tottenham", "Everton FC": "Everton",
    "Newcastle United FC": "Newcastle", "Aston Villa FC": "Aston Villa",
    "West Ham United FC": "West Ham", "Real Madrid CF": "Real Madrid",
    "FC Barcelona": "Barcelona", "Sevilla FC": "Sevilla", "Valencia CF": "Valencia",
    "Villarreal CF": "Villarreal", "Juventus FC": "Juventus", "A.C. Milan": "Milan",
    "FC Internazionale Milano": "Inter", "AS Roma": "Roma", "SS Lazio": "Lazio",
    "SSC Napoli": "Napoli", "ACF Fiorentina": "Fiorentina", "Atalanta BC": "Atalanta",
    "FC Bayern Münih": "Bayern Münih", "Borussia Dortmund": "Dortmund",
    "Bayer 04 Leverkusen": "Leverkusen", "FC Schalke 04": "Schalke 04",
    "VfB Stuttgart": "Stuttgart", "SV Werder Bremen": "Werder Bremen",
    "Borussia Mönchengladbach": "M'gladbach", "Eintracht Frankfurt": "Frankfurt",
    "Paris Saint-Germain": "PSG", "Olympique de Marseille": "Marsilya",
    "Olympique Lyonnais": "Lyon", "AS Monaco FC": "Monaco", "Lille OSC": "Lille",
    "OGC Nice": "Nice", "Stade Rennais FC": "Rennes",
}


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


def main():
    kulupler = yukle(os.path.join(VERI, "clubs.json"))
    oyuncular = yukle(os.path.join(VERI, "players.json"))
    tablolar = yukle(os.path.join(VERI, "grids.json"))

    # Sadece en az 2 kulübümüzde oynamış oyuncular doğru cevap olabilir
    adaylar = [o for o in oyuncular if len(o["kulupler"]) >= 2]
    isimler = ingilizce_isimleri_cek([o["id"] for o in adaylar])

    app_oyuncular = []
    for o in adaylar:
        tr = o["ad"]
        en = isimler.get(o["id"]) or tr
        kayit = {
            "id": o["id"],
            "ad": en,                    # ekranda görünen ad (İngilizce yazım daha standart)
            "p": o["populerlik"],
            "k": o["kulupler"],
        }
        if tr != en:
            kayit["tr"] = tr             # aramada Türkçe yazım da bulunsun
        if o["dogum_yili"]:
            kayit["y"] = o["dogum_yili"]  # aynı isimli oyuncuları ayırmak için
        app_oyuncular.append(kayit)

    app_kulupler = [{
        "id": k["id"],
        "ad": KISA_AD.get(k["ad"], k["ad"]),
        "tam_ad": k["ad"],
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
    for ad in ("clubs.json", "players.json", "grids.json"):
        boyut = os.path.getsize(os.path.join(CIKTI, ad)) / 1024
        print(f"   {ad:13} {boyut:7.0f} KB")
    print(f"\nDosyalar '{os.path.abspath(CIKTI)}' klasörüne yazıldı.")


if __name__ == "__main__":
    main()
