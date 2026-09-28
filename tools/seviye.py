"""
Futbol XOX - Kulüp ün seviyeleri (tablo_uret.py ve hazirla.py kullanır)

Seviye 1: Herkesin bildiği büyük kulüpler (aşağıdaki ELIT listesi, elle seçildi)
Seviye 2: En çok tanınmış oyuncu çıkarmış sonraki IKINCI_SEVIYE_SAYI kulüp (otomatik)
Seviye 3: Geri kalanlar

Zorluklar bu seviyelere göre kurulur: kolay = sadece 1. seviye, orta = 1 ve 2,
zor = hepsi. Listeye kulüp eklemek/çıkarmak için ELIT'i düzenleyip
tablo_uret.py ve hazirla.py'yi tekrar çalıştırman yeterli.
"""

import re
import unicodedata
from collections import Counter

TANINMIS = 15
IKINCI_SEVIYE_SAYI = 70

# Her satır bir kulüp; aynı kulübün farklı yazımları aynı satırda
ELIT = [
    ["Real Madrid"], ["Barcelona"], ["Atlético Madrid", "Atletico Madrid"],
    ["Sevilla"], ["Valencia"],
    ["Manchester United"], ["Manchester City"], ["Liverpool"], ["Arsenal"],
    ["Chelsea"], ["Tottenham", "Tottenham Hotspur"], ["Newcastle", "Newcastle United"],
    ["Aston Villa"], ["Everton"], ["West Ham", "West Ham United"],
    ["Juventus"], ["Milan", "AC Milan", "A.C. Milan"], ["Inter", "Internazionale"],
    ["Roma"], ["Napoli"], ["Lazio"], ["Fiorentina"], ["Atalanta"],
    ["Bayern Münih", "Bayern Munich", "Bayern München"], ["Dortmund", "Borussia Dortmund"],
    ["Leverkusen", "Bayer Leverkusen"], ["Schalke 04"],
    ["PSG", "Paris Saint-Germain"], ["Marsilya", "Marseille", "Olympique de Marseille"],
    ["Lyon", "Olympique Lyonnais"], ["Monaco"],
    ["Galatasaray"], ["Fenerbahçe"], ["Beşiktaş"], ["Trabzonspor"], ["Başakşehir"],
    ["Ajax"], ["PSV", "PSV Eindhoven"], ["Feyenoord"],
    ["Porto"], ["Benfica"], ["Sporting CP", "Sporting de Portugal", "Sporting"],
    ["Al-Nassr", "Al Nassr", "Al-Nasr", "El Nasr", "El-Nasr", "El Nassr", "An-Nassr",
     "En-Nasr", "En Nasr"],
    ["Al-Hilal", "Al Hilal", "El Hilal", "El-Hilal"],
    ["Al-Ittihad", "Al Ittihad", "El İttihad", "El-İttihad", "El Ittihad",
     "Ittihad", "Al-Ittihad Jeddah"],
    ["Flamengo"], ["Boca Juniors"], ["River Plate"],
]


# Wikidata'daki alışılmadık Türkçe yazımlar yerine oyunda yaygın kullanılan adlar
GORUNEN_AD = {
    "En-Nasr": "Al-Nassr", "El-Hilâl": "Al-Hilal", "Ittihad": "Al-Ittihad",
    "Ettifaq": "Al-Ettifaq", "Eş-Şebab": "Al-Shabab", "El-Kadisiye": "Al-Qadsiah",
    "El-Faysalî": "Al-Faisaly", "Et-Teâvün": "Al-Taawoun", "El-Feth": "Al-Fateh",
    "el-Feyha": "Al-Fayha", "do Recife": "Sport Recife", "Avellino 12 SSD": "Avellino",
}


# Birden fazla ülkede kullanılan genel kulüp adları: bunlarla isimden eşleştirme yapılmaz
GENEL_ADLAR = {
    "nacional", "racing", "sporting", "independiente", "olimpia", "universitario",
    "union", "deportivo", "atletico", "national", "real", "city", "united", "rangers",
    "wanderers", "athletic", "dinamo", "dynamo", "spartak", "lokomotiv", "hapoel",
    "maccabi", "alianza", "cerro", "liga", "america", "santos", "internacional",
    # Körfez ülkelerinde birden çok kulüp aynı adı taşıyor (Suudi, Katar, BAE, Mısır...)
    "alahli", "ahli", "alhilal", "hilal", "alnassr", "alnasr", "nasr", "nassr",
    "alittihad", "ittihad", "alshabab", "shabab", "alwahda", "alwehda", "alarabi",
    "alfaisaly", "altaawoun", "alqadsiah", "alfateh", "alettifaq", "alkhaleej",
}


def kulup_anahtarlari(kulup):
    """Bir kulübün bilinen bütün yazımlarının anahtarları (isimle eşleştirme için):
    kısa ad, tam ad, oyunda görünen ad ve ELIT listesindeki alternatif yazımlar."""
    lig_eksiz = re.sub(r"\s*\(.*\)$", "", kulup["ad"])  # "Nacional (Liga Portugal)" -> "Nacional"
    adlar = {kulup["ad"], lig_eksiz, kulup.get("tam_ad", ""), GORUNEN_AD.get(kulup["ad"], "")}
    anahtarlar = {anahtar(a) for a in adlar if a}
    for yazimlar in ELIT:
        if any(anahtar(y) in anahtarlar for y in yazimlar):
            anahtarlar.update(anahtar(y) for y in yazimlar)
    anahtarlar.discard("")
    return anahtarlar


def anahtar(ad):
    """'Beşiktaş J.K.' ve 'Besiktas' aynı anahtara düşsün: 'besiktas'"""
    ad = (ad or "").replace("ı", "i").replace("İ", "I")
    ad = unicodedata.normalize("NFKD", ad)
    return "".join(c for c in ad.lower() if c.isascii() and c.isalnum())


def kulup_seviyeleri(kulupler, oyuncular):
    """Dönüş: ({kulüp ID: seviye}, [listede bulunamayan ELIT kulüpleri])"""
    un = Counter()
    for o in oyuncular:
        if o["populerlik"] >= TANINMIS:
            un.update(o["kulupler"])

    ad_index = {}
    for k in kulupler:
        for ad in (k["ad"], k.get("tam_ad", "")):
            ad_index.setdefault(anahtar(ad), []).append(k)

    seviye = {}
    bulunamayan = []
    for yazimlar in ELIT:
        adaylar = [k for y in yazimlar for k in ad_index.get(anahtar(y), [])]
        if not adaylar:
            bulunamayan.append(yazimlar[0])
            continue
        # Aynı ada sahip birden çok kayıt varsa en çok tanınmış oyuncusu olan
        en_iyi = max(adaylar, key=lambda k: un[k["id"]])
        seviye[en_iyi["id"]] = 1

    kalan = sorted((k for k in kulupler if k["id"] not in seviye),
                   key=lambda k: -un[k["id"]])
    for k in kalan[:IKINCI_SEVIYE_SAYI]:
        seviye[k["id"]] = 2
    for k in kulupler:
        seviye.setdefault(k["id"], 3)
    return seviye, bulunamayan
