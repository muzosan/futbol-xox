"""
Futbol XOX - Kariyer verisi (Kim Bu? modu için)

Her oyuncunun kariyerindeki BÜTÜN kulüpleri (sadece bizim 53 kulüp değil),
kronolojik sırayla ve katıldığı yılla çıkarır.

Kaynaklar:
    - Transfermarkt transferleri (transfers.csv): tarihli transfer geçmişi.
      Modern ve güncel oyuncular için.
    - Wikidata kulüp kayıtları (başlangıç yılıyla): Transfermarkt'ta kariyeri
      eksik kalan tanınmış oyuncular (eski dönem efsaneleri) için.

Kullanım (tools klasöründe, tm_birlestir.py çalıştırıldıktan sonra):
    py kariyer_hazirla.py

Çıktı:
    ../assets/data/careers.json -> [{"id": oyuncu, "c": [[kulüp, yıl], ...]}]
"""

import json
import os
import re
import sys
from collections import defaultdict

from tm_birlestir import csv_oku, isim_anahtar, kaydet, tm_kulup_haritasi, yukle
from veri_topla import kisalt, qid, sparql, tm_kulup_idleri

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
CIKTI = os.path.join("..", "assets", "data")
WD_CACHE = os.path.join(VERI, "cache", "wd_kariyer.json")

MIN_ADIM = 4       # Kim Bu? için en az bu kadar kulüp (ipucu) olmalı
MIN_POP = 8        # sadece bu popülerliğin üstündeki oyuncular
WD_MIN_POP = 15    # Wikidata'dan tamamlanacak oyuncular için eşik

# Kariyere yazılmayacak kayıtlar: altyapı/B takımları, milli takımlar, "Emekli" vb.
GENC = re.compile(
    r"(\bU-?\d{2}\b|\bunder[- ]?\d{2}\b|\byouth\b|\byth\b|\bjgd\b|\bjugend|"
    r"\bjuvenil|\bprimavera\b|\breserves?\b|\bres\.|\bacademy\b|\bakademi|"
    r"\bcastilla\b|\byou\b\.?|\byth\b\.?|\bjug\b\.?|\bjuv\b\.?|\bsub-?\d{2}\b|(?:^|\s)(b|ii|c)$)",
    re.I,
)
MILLI = re.compile(r"national|milli|olympic|olimpik", re.I)
BOS = {"retired", "without club", "career break", "unknown", "ban",
       "verein unbekannt", "vereinslos", "pause"}

KONTROL = ["Mauro Icardi", "Arda Turan", "Mesut Özil", "Gheorghe Hagi",
           "Zlatan Ibrahimović", "Edin Džeko"]


ALTYAPI = " (Altyapı)"


def altyapi_adi(ad):
    """'FC Barcelona U19' -> 'Barcelona (Altyapı)', 'Vecindario You.' -> 'Vecindario (Altyapı)'"""
    temiz = GENC.sub(" ", ad)
    temiz = re.sub(r"\s+[A-Z]$", " ", temiz.strip())      # 'Juvenil A' -> ''
    temiz = kisalt(" ".join(temiz.split()).strip(" .-"))
    return temiz + ALTYAPI if temiz else None


def adim_ekle(adimlar, ad, yil):
    """Kariyere bir kulüp ekler; kayıt kaynaklı tekrarları ayıklar.
    Altyapı kayıtları sadece profesyonel kariyer başlamadan önceyse eklenir."""
    ad = (ad or "").strip()
    if not ad or ad.lower() in BOS or MILLI.search(ad):
        return
    if GENC.search(ad):
        if any(not a[0].endswith(ALTYAPI) for a in adimlar):
            return  # profesyonel kariyer başlamış; B takımı / U21 kaydı atlanır
        ad = altyapi_adi(ad)
        if not ad:
            return
    # Aynı kulüp art arda gelirse (ör. kiralıktan dönüş kaydı) tekrar ekleme
    if adimlar and adimlar[-1][0] == ad:
        return
    # A -> B -> A aynı yıl içinde (kiralık bitti, aynı yaz kesin transfer oldu):
    # B'deki sıfır süreli "dönüşü" sil, A'da kalmaya devam et
    if (len(adimlar) >= 2 and adimlar[-2][0] == ad
            and yil is not None and adimlar[-1][1] == yil):
        adimlar.pop()
        return
    adimlar.append([ad, yil])


def tm_kariyerler(tm_kulup_ad):
    print("Transfermarkt transferleri okunuyor...")
    f, okuyucu = csv_oku("transfers.csv", [
        "player_id", "transfer_date", "from_club_id", "to_club_id",
        "from_club_name", "to_club_name",
    ])
    oyuncu_transfer = defaultdict(list)
    for r in okuyucu:
        oyuncu_transfer[r["player_id"]].append(r)
    f.close()

    sonuc = {}
    for tm_id, satirlar in oyuncu_transfer.items():
        satirlar.sort(key=lambda r: r["transfer_date"])
        adimlar = []
        ilk = satirlar[0]
        adim_ekle(adimlar, tm_kulup_ad.get(ilk["from_club_id"], kisalt(ilk["from_club_name"])), None)
        for r in satirlar:
            yil = r["transfer_date"][:4]
            adim_ekle(adimlar, tm_kulup_ad.get(r["to_club_id"], kisalt(r["to_club_name"])),
                      int(yil) if yil.isdigit() else None)
        sonuc[tm_id] = adimlar
    print(f"   {len(sonuc)} oyuncunun transfer geçmişi işlendi")
    return sonuc


def wd_kariyerler(wd_idler, wd_kulup_ad):
    """Wikidata'dan kulüp kayıtları + başlangıç yılları (40'arlı gruplar, önbellekli)."""
    cache = yukle(WD_CACHE) if os.path.exists(WD_CACHE) else {}
    eksik = [i for i in wd_idler if i not in cache]
    print(f"Wikidata kariyerleri: {len(wd_idler) - len(eksik)} hazır, {len(eksik)} indirilecek")

    for bas in range(0, len(eksik), 40):
        grup = eksik[bas:bas + 40]
        values = " ".join(f"wd:{i}" for i in grup)
        satirlar = sparql(f"""
          SELECT ?o ?club ?clubLabel ?start WHERE {{
            VALUES ?o {{ {values} }}
            ?o p:P54 ?st . ?st ps:P54 ?club .
            OPTIONAL {{ ?st pq:P580 ?start . }}
            SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en,tr". }}
          }}""")
        kayit = defaultdict(list)
        for s in satirlar:
            yil = s.get("start", {}).get("value", "")[:4]
            if not yil.isdigit():
                continue  # yılı olmayan kaydı sıralayamayız
            kulup = qid(s["club"]["value"])
            ad = wd_kulup_ad.get(kulup, kisalt(s.get("clubLabel", {}).get("value", "")))
            if re.fullmatch(r"Q\d+", ad):
                continue
            kayit[qid(s["o"]["value"])].append((int(yil), ad))
        for i in grup:
            adimlar = []
            for yil, ad in sorted(kayit.get(i, [])):
                adim_ekle(adimlar, ad, yil)
            cache[i] = adimlar
        kaydet(WD_CACHE, cache, kompakt=True)
        biten = min(bas + 40, len(eksik))
        if biten % 400 == 0 or biten == len(eksik):
            print(f"   {biten}/{len(eksik)}")
    return cache


def main():
    oyuncular = yukle(os.path.join(VERI, "players.json"))
    if not oyuncular or "kaynak" not in oyuncular[0]:
        sys.exit("HATA: Önce 'py tm_birlestir.py' çalıştırılmalı.")
    if not any("tm" in o for o in oyuncular):
        sys.exit("HATA: players.json'da Transfermarkt ID'leri yok. Güncel "
                 "tm_birlestir.py ile birleştirmeyi tekrar çalıştır.")

    # Bizim kulüplerin kısa adları (uygulamadaki gibi görünsün)
    app_kulupler = yukle(os.path.join(CIKTI, "clubs.json"))
    wd_kulup_ad = {k["id"]: k["ad"] for k in app_kulupler}
    # Kulübün ek Wikidata kayıtları da aynı adla görünsün
    for k in yukle(os.path.join(VERI, "clubs.json")):
        for e in k.get("es", []):
            if k["id"] in wd_kulup_ad:
                wd_kulup_ad[e] = wd_kulup_ad[k["id"]]
    tm_kulup_ad = {tm: wd_kulup_ad[kid]
                   for tm, kid in tm_kulup_haritasi(
                       yukle(os.path.join(VERI, "clubs.json")), rapor=False).items()
                   if kid in wd_kulup_ad}

    tm = tm_kariyerler(tm_kulup_ad)

    adaylar = [o for o in oyuncular if o["populerlik"] >= MIN_POP]
    kariyer = {}
    wd_gerekli = []
    for o in adaylar:
        tm_id = o.get("tm") or (o["id"][2:] if o["id"].startswith("TM") else None)
        adimlar = tm.get(tm_id, []) if tm_id else []
        kariyer[o["id"]] = ("tm", adimlar)
        if len(adimlar) < MIN_ADIM and o["id"].startswith("Q") \
                and o["populerlik"] >= WD_MIN_POP:
            wd_gerekli.append(o["id"])

    wd = wd_kariyerler(wd_gerekli, wd_kulup_ad)
    for i in wd_gerekli:
        if len(wd.get(i, [])) > len(kariyer[i][1]):
            kariyer[i] = ("wd", wd[i])

    cikti = []
    kaynak_sayisi = defaultdict(int)
    for o in adaylar:  # popülerliğe göre sıralı
        kaynak, adimlar = kariyer[o["id"]]
        if len(adimlar) >= MIN_ADIM:
            cikti.append({"id": o["id"], "c": adimlar})
            kaynak_sayisi[kaynak] += 1

    os.makedirs(CIKTI, exist_ok=True)
    yol = os.path.join(CIKTI, "careers.json")
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(cikti, f, ensure_ascii=False, separators=(",", ":"))

    print("\n=== KARİYER ÖZETİ ===")
    print(f"Kariyeri çıkarılan oyuncu : {len(cikti)}")
    print(f"   Transfermarkt'tan      : {kaynak_sayisi['tm']}")
    print(f"   Wikidata'dan           : {kaynak_sayisi['wd']}")
    print(f"Dosya boyutu              : {os.path.getsize(yol) / 1024:.0f} KB")

    print("\nKontrol:")
    ada_gore = {isim_anahtar(o["ad"]): o["id"] for o in adaylar}
    for aranan in KONTROL:
        oid = ada_gore.get(isim_anahtar(aranan))
        adimlar = kariyer.get(oid, (None, []))[1] if oid else []
        if not adimlar:
            print(f"   {aranan}: bulunamadı")
            continue
        yazi = " → ".join(f"{ad} ({yil})" if yil else ad for ad, yil in adimlar)
        print(f"   {aranan}: {yazi}")


if __name__ == "__main__":
    main()
