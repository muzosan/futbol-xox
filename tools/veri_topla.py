"""
Futbol XOX - Veri toplama (lig tabanlı)

Kulüpleri LİGLER listesinden otomatik bulur, sonra bu kulüplerde oynamış bütün
futbolcuları Wikidata'dan çeker.

Kullanım:
    pip install requests
    py veri_topla.py

Çıktılar (data/ klasörü):
    clubs.json   -> kulüpler (Wikidata ID, kısa ad, tam ad, lig, oyuncu sayısı)
    players.json -> oyuncular (ID, ad, İngilizce ad, doğum yılı, popülerlik, kulüpler)

Her şey data/cache içinde önbelleğe alınır: script yarıda kalırsa tekrar
çalıştırman yeterli, kaldığı yerden devam eder.
Bir lig yanlış eşleşirse (özet ekranında kontrol et) LIG_DUZELTME'ye doğru
Wikidata ID'sini yazıp data/cache/ligler.json'u silerek tekrar çalıştır.
"""

import json
import os
import re
import sys
import time

import requests

from seviye import ELIT, anahtar

sys.stdout.reconfigure(encoding="utf-8")

SPARQL_URL = "https://query.wikidata.org/sparql"
API_URL = "https://www.wikidata.org/w/api.php"
# Wikidata, isteği kimin attığını belirten bir User-Agent ister. Kendi mailini yaz.
HEADERS = {"User-Agent": "FutbolXOX-VeriScripti/0.2 (iletisim: muazonurluer2312@gmail.com)"}

FUTBOLCU = "Q937857"   # Wikidata: "association football player"
FUTBOL_KULUBU = "Q476028"  # Wikidata: "association football club"
CIKTI = "data"
ONBELLEK = os.path.join(CIKTI, "cache")
LIG_CACHE = os.path.join(ONBELLEK, "ligler_v3.json")
BEKLEME = 2.0          # sorgular arası en az bekleme (sn)
MAX_BEKLEME = 30.0     # sunucu çok zorlanırsa bekleme en fazla bu kadar uzar
MIN_OYUNCU = 30        # Wikidata'da bundan az oyuncusu olan kulüpler alınmaz

# Ülkelerin Wikidata ID'leri (aynı adlı başka ülke ligleriyle karışmasın diye)
ING = ["Q21", "Q145"]   # İngiltere / Birleşik Krallık
ISP, ITA, ALM, FRA = ["Q29"], ["Q38"], ["Q183"], ["Q142"]
TUR, HOL, POR = ["Q43"], ["Q55"], ["Q45"]
BRE, ARJ, SUU = ["Q155"], ["Q414"], ["Q851"]

# (Wikidata'da aranacak isim, oyunda görünecek lig adı, ülke)
LIGLER = [
    ("Premier League", "Premier League", ING),
    ("EFL Championship", "Championship", ING),
    ("La Liga", "La Liga", ISP),
    ("Segunda División", "La Liga 2", ISP),
    ("Serie A", "Serie A", ITA),
    ("Serie B", "Serie B", ITA),
    ("Bundesliga", "Bundesliga", ALM),
    ("2. Bundesliga", "2. Bundesliga", ALM),
    ("Ligue 1", "Ligue 1", FRA),
    ("Ligue 2", "Ligue 2", FRA),
    ("Süper Lig", "Süper Lig", TUR),
    ("TFF First League", "TFF 1. Lig", TUR),
    ("TFF Second League", "TFF 2. Lig", TUR),
    ("TFF Third League", "TFF 3. Lig", TUR),
    ("Eredivisie", "Eredivisie", HOL),
    ("Eerste Divisie", "Eerste Divisie", HOL),
    ("Primeira Liga", "Liga Portugal", POR),
    ("Liga Portugal 2", "Liga Portugal 2", POR),
    ("Campeonato Brasileiro Série A", "Brasileirão", BRE),
    ("Argentine Primera División", "Arjantin Ligi", ARJ),
    ("Saudi Pro League", "Suudi Pro Lig", SUU),
]

# Yanlış eşleşen lig olursa: {"Serie A": "Q15804"} gibi (arama adı -> Wikidata ID)
LIG_DUZELTME = {
    "La Liga": "Q324867",           # yoksa LaLiga 2 ile karışıyor
    "Segunda División": "Q35615",   # LaLiga 2 (yoksa eski Segunda B ile karışıyor)
    "Serie A": "Q15804",            # yoksa İtalya rugby ligi ile karışıyor
}

# Kulüp adı kısaltmaları (otomatik kısaltma yetmediğinde)
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

KISA_AD.update({
    "Paris Saint-Germain F.C.": "PSG", "Olympique de Marseille": "Marsilya",
    "Galatasaray S.K.": "Galatasaray", "Fenerbahçe S.K.": "Fenerbahçe",
    "Beşiktaş J.K.": "Beşiktaş", "Sporting Clube de Portugal": "Sporting CP",
})

# B takımları, altyapı takımları
YEDEK = re.compile(r"(\bJong\b|\bU-?\d{2}\b|\bII$|\bB$|Castilla|Reserves?\b|\bSub-?\d{2}\b|"
                   r"Atl[eè]tic\b|Juvenil|Primavera|Youth|Academy|Akademi|\bB\s*\()")
# Aynı kulübün kadın takımı ve başka spor branşları (birleştirmeye asla girmez)
BASKA_TAKIM = re.compile(
    r"(wom[ae]n|femen|femin|frauen|kadın|ladies|damen|dames|basket|bàsquet|basquete|"
    r"handbol|handball|hentbol|volley|voleybol|hockey|hokey|rugby|futsal|esports|"
    r"e-sports|beach|plaj|water ?polo|sutopu|athletics|atletizm|cycling|bisiklet)", re.I)
KARDES_CACHE = os.path.join(ONBELLEK, "kardesler.json")

# Otomatik kısaltmada atılan ekler (FC, SK, Spor Kulübü...)
EKLER = re.compile(
    r"\b(Clube de Regatas do|Clube de Regatas|Club de Regatas|Club Atlético|"
    r"Clube Atlético|Sociedade Esportiva|Sportif Faaliyetler|SFC|SL|"
    r"F\.?C\.?|C\.?F\.?|A\.?F\.?C\.?|S\.?C\.?|S\.?K\.?|F\.?K\.?|J\.?K\.?|"
    r"A\.?Ş\.?|SSC|SS|AS|AC|ACF|UC|US|CFC|SE|EC|FR|SAD|CD|SD|UD|RCD|RC|CA|SV|VfL|TSG|Calcio|"
    r"Spor Kulübü|Kulübü|Futebol Clube|Esporte Clube|Futbol Club|Club|Clube|"
    r"de Futebol|Associação|Sport Club|Football Club)\b\.?",
)


def kisalt(ad):
    """'FC Internazionale Milano' -> KISA_AD'dan 'Inter';
    'VfL Wolfsburg' -> 'Wolfsburg'; '1. FC Köln' -> 'Köln'."""
    if ad in KISA_AD:
        return KISA_AD[ad]
    kisa = EKLER.sub(" ", ad)
    kisa = re.sub(r"(^|\s)1\.(\s|$)", " ", kisa)          # "1. FC Köln"
    kisa = re.sub(r"\b(18|19|20)\d{2}\b", " ", kisa)       # "TSG 1899 Hoffenheim"
    kisa = " ".join(kisa.replace(" .", " ").split()).strip(" -.,")
    return kisa or ad


_bekleme = BEKLEME  # sunucunun durumuna göre otomatik ayarlanır


def _yavasla():
    global _bekleme
    _bekleme = min(_bekleme * 2, MAX_BEKLEME)


def _hizlan():
    global _bekleme
    _bekleme = max(BEKLEME, _bekleme * 0.85)


def istek(url, params, deneme=12):
    for i in range(1, deneme + 1):
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=150)
        except requests.RequestException as e:
            _yavasla()
            bekle = min(15 * i, 120)
            print(f"   ! Bağlantı sorunu ({i}/{deneme}): {str(e)[:60]} - {bekle} sn bekleniyor")
            time.sleep(bekle)
            continue
        if r.status_code == 200:
            try:
                veri = r.json()
            except ValueError:
                _yavasla()
                print(f"   ! Yanıt yarım geldi ({i}/{deneme}) - {10 * i} sn bekleniyor")
                time.sleep(10 * i)
                continue
            _hizlan()
            return veri
        if r.status_code in (429, 500, 502, 503, 504):
            _yavasla()
            bekle = int(r.headers.get("Retry-After", 0)) or min(15 * i, 120)
            print(f"   ! Sunucu meşgul ({r.status_code}, {i}/{deneme}) - {bekle} sn bekleniyor, "
                  f"sorgular arası bekleme {_bekleme:.0f} sn'ye çıktı")
            time.sleep(bekle)
            continue
        r.raise_for_status()
    raise RuntimeError("Sunucu uzun süre cevap vermedi. Biraz bekleyip scripti tekrar "
                       "çalıştır, kaldığı yerden devam eder.")


def sparql(sorgu):
    veri = istek(SPARQL_URL, {"query": sorgu, "format": "json"})
    time.sleep(_bekleme)
    return veri["results"]["bindings"]


def qid(uri):
    return uri.rsplit("/", 1)[-1]


def yukle(yol):
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def kaydet(yol, veri, kompakt=False):
    with open(yol, "w", encoding="utf-8") as f:
        if kompakt:
            json.dump(veri, f, ensure_ascii=False, separators=(",", ":"))
        else:
            json.dump(veri, f, ensure_ascii=False, indent=2)


def tm_kulup_idleri(kulup_idleri):
    """Kulüplerin Transfermarkt ID'leri (Wikidata P7223), 100'erli gruplar halinde.
    Dönüş: {TM kulüp ID: Wikidata kulüp ID}"""
    sonuc = {}
    idler = list(kulup_idleri)
    for bas in range(0, len(idler), 100):
        values = " ".join(f"wd:{k}" for k in idler[bas:bas + 100])
        for s in sparql(f"SELECT ?kulup ?tm WHERE {{ VALUES ?kulup {{ {values} }} "
                        f"?kulup wdt:P7223 ?tm . }}"):
            sonuc[s["tm"]["value"]] = qid(s["kulup"]["value"])
    return sonuc


def lig_bul(aranan, ulkeler):
    """İsimle arar; verilen ülkeye ait adaylar arasından en çok kulübü olanı seçer."""
    if aranan in LIG_DUZELTME:
        return {"id": LIG_DUZELTME[aranan], "etiket": aranan, "aciklama": "elle sabitlendi"}
    arama = istek(API_URL, {
        "action": "wbsearchentities", "search": aranan, "language": "en",
        "uselang": "en", "type": "item", "limit": 10, "format": "json",
    })
    adaylar = {s["id"]: s for s in arama.get("search", [])}
    if not adaylar:
        return None
    values = " ".join(f"wd:{a}" for a in adaylar)
    ulke_values = " ".join(f"wd:{u}" for u in ulkeler)
    sonuc = []
    for spor in ("?lig wdt:P641 wd:Q2736 .", ""):  # önce sadece futbol ligleri
        sonuc = sparql(f"""
          SELECT ?lig (COUNT(DISTINCT ?k) AS ?n) WHERE {{
            VALUES ?lig {{ {values} }}
            VALUES ?ulke {{ {ulke_values} }}
            ?lig wdt:P17 ?ulke .
            {spor}
            ?k wdt:P118 ?lig .
            FILTER NOT EXISTS {{ ?k wdt:P31 wd:Q5 . }}
          }} GROUP BY ?lig ORDER BY DESC(?n) LIMIT 1""")
        if sonuc:
            break
    if not sonuc:
        return None
    lig_id = qid(sonuc[0]["lig"]["value"])
    a = adaylar.get(lig_id, {})
    return {"id": lig_id, "etiket": a.get("label", ""), "aciklama": a.get("description", "")}


def lig_kulupleri(lig_id):
    """Ligin (bitiş tarihi girilmemiş) üyesi olan futbol kulüpleri."""
    satirlar = sparql(f"""
      SELECT DISTINCT ?k ?kLabel WHERE {{
        ?k p:P118 ?st . ?st ps:P118 wd:{lig_id} .
        FILTER NOT EXISTS {{ ?st pq:P582 ?bitis . }}
        FILTER NOT EXISTS {{ ?k wdt:P31 wd:Q5 . }}   # futbolcuları dışarıda bırak
        SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
      }}""")
    return [{"id": qid(s["k"]["value"]), "tam_ad": s["kLabel"]["value"]} for s in satirlar]


def oyunculari_cek(kulup_id):
    # Etiket servisi (SERVICE wikibase:label) sunucuyu çok yorduğu için
    # Türkçe / İngilizce / çok dilli adları doğrudan istiyoruz.
    return sparql(f"""
      SELECT ?o ?tr ?en ?mul ?sl ?dogum WHERE {{
        ?o wdt:P54 wd:{kulup_id} ; wdt:P106 wd:{FUTBOLCU} ; wikibase:sitelinks ?sl .
        OPTIONAL {{ ?o wdt:P569 ?dogum . }}
        OPTIONAL {{ ?o rdfs:label ?tr . FILTER(LANG(?tr) = "tr") }}
        OPTIONAL {{ ?o rdfs:label ?en . FILTER(LANG(?en) = "en") }}
        OPTIONAL {{ ?o rdfs:label ?mul . FILTER(LANG(?mul) = "mul") }}
      }}""")


def satir_adi(s):
    """Önbellekteki eski (oLabel) ve yeni (tr/en/mul) satır biçimlerini birlikte okur."""
    for alan in ("oLabel", "tr", "en", "mul"):
        if alan in s:
            return s[alan]["value"]
    return ""


def ad_anahtari(ad):
    """'SL Benfica', 'S.L. Benfica', 'Benfica (football)' -> 'benfica'"""
    ad = re.sub(r"\(.*?\)", " ", ad or "")
    ad = re.sub(r"\b([A-Za-z])\.(?=[A-Za-z]\.)", r"\1", ad)   # "S.L." -> "SL."
    ad = re.sub(r"\b([A-Z]{1,4})\.", r"\1", ad)               # "SL." -> "SL"
    return anahtar(kisalt(ad))


def kardes_kayitlar(kulup_idleri):
    """Aynı kulübün başka Wikidata kayıtları: bağlı olduğu spor kulübü, futbol şubesi
    veya aynı Transfermarkt ID'sine sahip kayıt. (Önbellekli)"""
    cache = yukle(KARDES_CACHE) if os.path.exists(KARDES_CACHE) else {}
    eksik = [k for k in kulup_idleri if k not in cache]
    for bas in range(0, len(eksik), 60):
        grup = eksik[bas:bas + 60]
        values = " ".join(f"wd:{k}" for k in grup)
        satirlar = sparql(f"""
          SELECT DISTINCT ?k ?s ?sLabel ?ayniTm WHERE {{
            VALUES ?k {{ {values} }}
            {{ ?s wdt:P361 ?k }} UNION {{ ?k wdt:P361 ?s }} UNION
            {{ ?k wdt:P527 ?s }} UNION {{ ?s wdt:P527 ?k }} UNION
            {{ ?s wdt:P749 ?k }} UNION {{ ?k wdt:P749 ?s }} UNION
            {{ ?k wdt:P355 ?s }} UNION {{ ?s wdt:P355 ?k }} UNION
            {{ ?k wdt:P7223 ?tm . ?s wdt:P7223 ?tm . BIND(true AS ?ayniTm) }}
            FILTER(?s != ?k)
            FILTER NOT EXISTS {{ ?s wdt:P31 wd:Q5 . }}
            SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en,tr". }}
          }}""")
        for k in grup:
            cache[k] = []
        for r in satirlar:
            cache[qid(r["k"]["value"])].append({
                "id": qid(r["s"]["value"]),
                "ad": r.get("sLabel", {}).get("value", ""),
                "tm": "ayniTm" in r,
            })
        kaydet(KARDES_CACHE, cache, kompakt=True)
    return cache


def satirlari_al(kulup_id):
    yol = os.path.join(ONBELLEK, f"{kulup_id}.json")
    if os.path.exists(yol):
        return yukle(yol)
    satirlar = oyunculari_cek(kulup_id)
    kaydet(yol, satirlar, kompakt=True)
    return satirlar


def eski_kulupler():
    """İlk sürümde isimle bulunmuş 53 kulübü koru (ID'leri oyuncu verisiyle uyumlu)."""
    yol = os.path.join(CIKTI, "clubs.json")
    if not os.path.exists(yol):
        return []
    eski = yukle(yol)
    return [k for k in eski if "arama" in k or k.get("sabit")]


def main():
    os.makedirs(ONBELLEK, exist_ok=True)

    # 1) Ligler ve kulüpleri (önbellekli)
    lig_cache = yukle(LIG_CACHE) if os.path.exists(LIG_CACHE) else {}
    print("1) Ligler ve kulüpleri bulunuyor...")
    kulupler = {}
    for aranan, lig_adi, ulkeler in LIGLER:
        if aranan not in lig_cache:
            lig = lig_bul(aranan, ulkeler)
            if not lig:
                print(f"   ! '{aranan}' bulunamadı")
                continue
            lig["kulupler"] = lig_kulupleri(lig["id"])
            lig_cache[aranan] = lig
            kaydet(LIG_CACHE, lig_cache)
        lig = lig_cache[aranan]
        eklenen = 0
        for k in lig["kulupler"]:
            if YEDEK.search(k["tam_ad"]) or re.fullmatch(r"Q\d+", k["tam_ad"]):
                continue
            if k["id"] not in kulupler:
                kulupler[k["id"]] = {"id": k["id"], "tam_ad": k["tam_ad"],
                                     "ad": kisalt(k["tam_ad"]), "lig": lig_adi}
                eklenen += 1
        uyari = "   <-- ÇOK FAZLA, KONTROL ET" if eklenen > 150 else ""
        print(f"   {lig_adi:16} -> {lig['id']:10} {lig['etiket']} ({lig['aciklama'][:40]}) · {eklenen} kulüp{uyari}")

    for k in eski_kulupler():
        kulupler.setdefault(k["id"], {"id": k["id"], "tam_ad": k.get("tam_ad", k["ad"]),
                                      "ad": kisalt(k.get("tam_ad", k["ad"])),
                                      "lig": k["lig"], "sabit": True})
    print(f"   Toplam aday kulüp: {len(kulupler)}\n")

    # 2) Aynı kulübün başka Wikidata kayıtları (ör. "spor kulübü" + "futbol takımı").
    #    Oyuncuların bir kısmı bir kayda, bir kısmı diğerine bağlı olabiliyor.
    #    Sadece aynı Transfermarkt ID'si ya da birebir aynı ad varsa birleştirilir;
    #    B takımları, altyapı, kadın takımları ve başka branşlar asla birleştirilmez.
    print("2) Kulüplerin diğer Wikidata kayıtları kontrol ediliyor...")
    kardes = kardes_kayitlar(list(kulupler))
    esler = {kid: [] for kid in kulupler}
    for kid, k in kulupler.items():
        hedef = {ad_anahtari(k["ad"]), ad_anahtari(k["tam_ad"])}
        for sb in kardes.get(kid, []):
            if sb["id"] in kulupler or sb["id"] in esler[kid]:
                continue
            if not sb["ad"] or BASKA_TAKIM.search(sb["ad"]) or YEDEK.search(sb["ad"]):
                continue
            sb_anahtar = ad_anahtari(sb["ad"])
            ayni_ad = sb_anahtar in hedef or any(
                len(h) >= 5 and h in sb_anahtar for h in hedef)  # "Sport Lisboa e Benfica"
            if sb["tm"] or ayni_ad:
                esler[kid].append(sb["id"])
    print(f"   {sum(1 for e in esler.values() if e)} kulübün ek kaydı bulundu\n")

    # 3) Oyuncular (her kulüp + ek kayıtları, önbellekli)
    print("3) Oyuncular çekiliyor (ilk seferde uzun sürer, yarıda kalırsa tekrar çalıştır)...")
    liste = list(kulupler.values())
    kulup_satirlari = {}
    kulup_oyuncu_sayisi = {}
    for i, k in enumerate(liste, 1):
        satirlar = []
        for kayit in [k["id"]] + esler[k["id"]]:
            satirlar.extend(satirlari_al(kayit))
        kulup_satirlari[k["id"]] = satirlar
        kulup_oyuncu_sayisi[k["id"]] = len({r["o"]["value"] for r in satirlar})
        if i % 5 == 0 or i == len(liste):
            print(f"   {i}/{len(liste)} kulüp · son: {k['ad']} ({kulup_oyuncu_sayisi[k['id']]} oyuncu)")

    # 4) Az oyunculu kulüpleri at. Aynı ligde aynı adlı kayıtlar tek kulüp olarak
    #    birleştirilir; farklı liglerde aynı ad varsa lig adı eklenir.
    gruplar = {}
    for k in liste:
        n = kulup_oyuncu_sayisi[k["id"]]
        if n < MIN_OYUNCU and not k.get("sabit"):
            continue
        gruplar.setdefault((k["ad"], k["lig"]), []).append(k)
    # Farklı liglerde aynı adlı kayıtlar: gerçekten farklı kulüp mü, yoksa aynı
    # kulübün hatalı bir kopyası mı? (ör. Wikidata'da Arjantin ligine yanlışlıkla
    # eklenmiş bir "Real Madrid" kaydı)
    #   - Oyuncularının %30'undan fazlası ortaksa: aynı kulüp -> birleştir
    #   - Büyük kulüp adıysa (seviye 1): sadece en çok oyunculu kayıt kalır
    #   - Diğer durumlarda gerçekten farklı kulüplerdir (ör. Nacional) -> lig adı eklenir
    elit_anahtar = {anahtar(y) for yazimlar in ELIT for y in yazimlar}

    def oyuncu_kumesi(grup):
        return {r["o"]["value"] for k in grup for r in kulup_satirlari[k["id"]]}

    ada_gore = {}
    for (ad, lig), grup in gruplar.items():
        ada_gore.setdefault(ad, []).append(grup)
    birlesik_gruplar = []
    atilan_kopyalar = []
    for ad, grup_listesi in ada_gore.items():
        grup_listesi.sort(key=lambda g: -len(oyuncu_kumesi(g)))
        buyuk = grup_listesi[0]
        buyuk_kume = oyuncu_kumesi(buyuk)
        kalanlar = [buyuk]
        for g in grup_listesi[1:]:
            kume = oyuncu_kumesi(g)
            ortak = len(kume & buyuk_kume) / max(len(kume), 1)
            if ortak >= 0.3:
                buyuk.extend(g)                      # aynı kulübün kopyası
            elif anahtar(ad) in elit_anahtar:
                atilan_kopyalar.append(f"{ad} ({g[0]['lig']})")  # büyük kulüp adını taşıyan yanlış kayıt
            else:
                kalanlar.append(g)                   # gerçekten farklı kulüp
        birlesik_gruplar.extend(kalanlar)
    if atilan_kopyalar:
        print("   Büyük kulüp adını taşıyan hatalı kayıtlar atıldı: " + ", ".join(atilan_kopyalar))

    ana_kulup = {}  # herhangi bir kayıt -> ana kulüp ID
    kulup_listesi = []
    ad_sayaci = {}
    for grup in birlesik_gruplar:
        grup.sort(key=lambda k: -kulup_oyuncu_sayisi[k["id"]])
        ana = grup[0]
        ana["es"] = sorted({e for k in grup for e in [k["id"]] + esler[k["id"]]} - {ana["id"]})
        for k in grup:
            ana_kulup[k["id"]] = ana["id"]
        kulup_listesi.append(ana)
        ad_sayaci[ana["ad"]] = ad_sayaci.get(ana["ad"], 0) + 1
    for k in kulup_listesi:
        if ad_sayaci[k["ad"]] > 1:
            k["ad"] = f"{k['ad']} ({k['lig']})"
            print(f"   Aynı adlı farklı kulüp: {k['ad']}")

    oyuncular = {}
    for k in liste:
        if k["id"] not in ana_kulup:
            continue
        hedef_kulup = ana_kulup[k["id"]]
        for r in kulup_satirlari[k["id"]]:
            oid = qid(r["o"]["value"])
            ad = satir_adi(r)
            if not ad or re.fullmatch(r"Q\d+", ad):
                continue
            o = oyuncular.setdefault(oid, {
                "id": oid, "ad": ad, "dogum_yili": None,
                "populerlik": int(r["sl"]["value"]), "kulupler": [],
            })
            if "en" in r and "en" not in o:
                o["en"] = r["en"]["value"]
            if o["dogum_yili"] is None and "dogum" in r:
                m = re.match(r"^(\d{4})-", r["dogum"]["value"])
                if m:
                    o["dogum_yili"] = int(m.group(1))
            if hedef_kulup not in o["kulupler"]:
                o["kulupler"].append(hedef_kulup)

    for k in kulup_listesi:
        k["oyuncu_sayisi"] = sum(1 for o in oyuncular.values() if k["id"] in o["kulupler"])
    kulup_listesi.sort(key=lambda k: -k["oyuncu_sayisi"])
    oyuncu_listesi = sorted(oyuncular.values(), key=lambda o: -o["populerlik"])

    kaydet(os.path.join(CIKTI, "clubs.json"), kulup_listesi)
    kaydet(os.path.join(CIKTI, "players.json"), oyuncu_listesi, kompakt=True)

    lig_sayisi = {}
    for k in kulup_listesi:
        lig_sayisi[k["lig"]] = lig_sayisi.get(k["lig"], 0) + 1
    print("\n=== ÖZET ===")
    for lig_adi, n in sorted(lig_sayisi.items(), key=lambda x: -x[1]):
        print(f"   {lig_adi:16} {n} kulüp")
    print(f"Kulüp sayısı       : {len(kulup_listesi)}")
    print(f"Toplam oyuncu      : {len(oyuncu_listesi)}")
    print(f"2+ kulüpte oynamış : {sum(1 for o in oyuncu_listesi if len(o['kulupler']) >= 2)}")
    print(f"\nDosyalar '{CIKTI}' klasörüne kaydedildi. Sırada: py tm_birlestir.py")


if __name__ == "__main__":
    main()
