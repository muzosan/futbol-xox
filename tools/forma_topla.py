"""
Futbol XOX - Forma renkleri

Her kulüp için küçük forma ikonunun desenini ve renklerini belirler.

Kaynaklar:
    1) ELLE_FORMA: büyük kulüpler için elle tanımlanmış desen + renkler
    2) Wikidata "resmi renk" (P6364) kaydı: diğer bütün kulüpler (desensiz)

Kullanım (tools klasöründe, veri_topla.py'den sonra):
    py forma_topla.py
    py hazirla.py          <- forma bilgisini uygulama verisine ekler

Çıktı:
    data/kits.json -> {kulüp ID: {"p": desen, "c": ["#RRGGBB", ...]}}

Desenler:
    solid        tek renk (2. renk yaka/kol detayı)
    stripes      dikey çubuklar          hoops   yatay çizgiler
    halves       iki yarım (sol/sağ)      sleeves gövde + farklı renk kollar
    center       ortadan dikey şerit     band    göğüste yatay bant
    sash         çapraz şerit            diagonal çapraz ikiye bölünmüş
"""

import os
import sys

from seviye import anahtar
from veri_topla import API_URL, istek, kaydet, yukle

sys.stdout.reconfigure(encoding="utf-8")

VERI = "data"
CACHE = os.path.join(VERI, "cache", "forma_wikidata.json")

# (kulüp adı yazımları, desen, renkler) - renkler: ana renk önce
ELLE_FORMA = [
    # İspanya
    (["Real Madrid"], "solid", ["#FFFFFF", "#1B2A55"]),
    (["Barcelona"], "stripes", ["#A50044", "#004D98"]),
    (["Atlético Madrid", "Atletico Madrid"], "stripes", ["#CB3524", "#FFFFFF"]),
    (["Sevilla"], "solid", ["#FFFFFF", "#D8001A"]),
    (["Valencia"], "solid", ["#FFFFFF", "#111111"]),
    (["Villarreal"], "solid", ["#FFE667", "#005187"]),
    (["Real Betis", "Betis"], "stripes", ["#0BB363", "#FFFFFF"]),
    (["Athletic Bilbao", "Athletic Club"], "stripes", ["#EE2523", "#FFFFFF"]),
    (["Real Sociedad"], "stripes", ["#0067B1", "#FFFFFF"]),
    (["Rayo Vallecano"], "sash", ["#FFFFFF", "#E30613"]),
    (["Deportivo Alavés", "Alavés"], "stripes", ["#1D5FA8", "#FFFFFF"]),
    (["Granada"], "hoops", ["#D0021B", "#FFFFFF"]),
    (["Levante"], "stripes", ["#004D98", "#B4053F"]),
    (["Osasuna"], "solid", ["#D91A21", "#0A2240"]),
    (["Eibar"], "stripes", ["#004D98", "#B4053F"]),
    (["Celta de Vigo", "Celta"], "solid", ["#8AC3EE", "#FFFFFF"]),
    # İngiltere
    (["Manchester United"], "solid", ["#DA291C", "#FFFFFF"]),
    (["Manchester City"], "solid", ["#6CABDD", "#FFFFFF"]),
    (["Liverpool"], "solid", ["#C8102E", "#FFFFFF"]),
    (["Arsenal"], "sleeves", ["#EF0107", "#FFFFFF"]),
    (["Chelsea"], "solid", ["#034694", "#FFFFFF"]),
    (["Tottenham", "Tottenham Hotspur"], "solid", ["#FFFFFF", "#132257"]),
    (["Newcastle", "Newcastle United"], "stripes", ["#111111", "#FFFFFF"]),
    (["Aston Villa"], "sleeves", ["#670E36", "#95BFE5"]),
    (["Everton"], "solid", ["#003399", "#FFFFFF"]),
    (["West Ham", "West Ham United"], "sleeves", ["#7A263A", "#1BB1E7"]),
    (["Lincoln City"], "stripes", ["#E30613", "#FFFFFF"]),
    # İtalya
    (["Juventus"], "stripes", ["#111111", "#FFFFFF"]),
    (["Milan", "AC Milan"], "stripes", ["#E30613", "#111111"]),
    (["Inter", "Internazionale"], "stripes", ["#0068A8", "#111111"]),
    (["Roma"], "solid", ["#8E1F2F", "#F0BC42"]),
    (["Napoli"], "solid", ["#12A0D7", "#FFFFFF"]),
    (["Lazio"], "solid", ["#87D8F7", "#FFFFFF"]),
    (["Fiorentina"], "solid", ["#482E92", "#FFFFFF"]),
    (["Atalanta"], "stripes", ["#1E71B8", "#111111"]),
    (["Torino"], "solid", ["#7B1C1C", "#FFFFFF"]),
    (["Udinese", "Udinese Calcio"], "stripes", ["#111111", "#FFFFFF"]),
    (["Parma", "Parma Calcio"], "solid", ["#FFFFFF", "#111111"]),
    (["Como", "Como Calcio"], "solid", ["#0033A0", "#FFFFFF"]),
    (["Bari"], "solid", ["#FFFFFF", "#D0021B"]),
    (["Padova", "Calcio Padova"], "solid", ["#FFFFFF", "#D0021B"]),
    (["Modena"], "solid", ["#FFD200", "#1E3A8A"]),
    (["Perugia", "Perugia Calcio"], "solid", ["#D0021B", "#FFFFFF"]),
    (["Reggiana"], "solid", ["#7A1F3D", "#FFFFFF"]),
    (["Reggina"], "solid", ["#8B1C3D", "#FFFFFF"]),
    (["Cremonese", "US Cremonese"], "stripes", ["#D0021B", "#9AA0A6"]),
    (["Avellino", "Avellino 12 SSD"], "solid", ["#0B8A3E", "#FFFFFF"]),
    (["Ternana"], "stripes", ["#D0021B", "#0B8A3E"]),
    (["ChievoVerona", "Chievo"], "solid", ["#FFD200", "#1F4E9E"]),
    (["Pro Vercelli"], "solid", ["#FFFFFF", "#111111"]),
    (["Cosenza"], "stripes", ["#D0021B", "#1F4E9E"]),
    # Almanya
    (["Bayern Münih", "Bayern Munich", "Bayern München"], "solid", ["#DC052D", "#FFFFFF"]),
    (["Dortmund", "Borussia Dortmund"], "solid", ["#FDE100", "#111111"]),
    (["Leverkusen", "Bayer Leverkusen"], "solid", ["#E32221", "#111111"]),
    (["Schalke 04"], "solid", ["#004D9D", "#FFFFFF"]),
    (["Wolfsburg"], "solid", ["#65B32E", "#FFFFFF"]),
    (["Werder Bremen", "SV Werder Bremen"], "solid", ["#1D9053", "#FFFFFF"]),
    (["M'gladbach", "Borussia Mönchengladbach"], "solid", ["#FFFFFF", "#00A651"]),
    (["Hertha BSC", "Hertha"], "stripes", ["#005CA9", "#FFFFFF"]),
    (["Hannover 96"], "solid", ["#D0021B", "#111111"]),
    (["Karlsruher", "Karlsruher SC"], "solid", ["#0059A6", "#FFFFFF"]),
    (["MSV Duisburg"], "hoops", ["#1F4E9E", "#FFFFFF"]),
    (["SpVgg Greuther Fürth", "Greuther Fürth"], "solid", ["#009640", "#FFFFFF"]),
    (["Osnabrück", "VfL Osnabrück"], "solid", ["#5B2C83", "#FFFFFF"]),
    (["Dinamo Dresden", "Dynamo Dresden"], "solid", ["#FFD200", "#111111"]),
    (["Energie Cottbus"], "solid", ["#D0021B", "#FFFFFF"]),
    (["Eintracht Braunschweig"], "solid", ["#FFD200", "#1F4E9E"]),
    (["Stuttgart", "VfB Stuttgart"], "band", ["#FFFFFF", "#E32219"]),
    # Fransa
    (["PSG", "Paris Saint-Germain"], "center", ["#004170", "#DA291C", "#FFFFFF"]),
    (["Marsilya", "Marseille", "Olympique de Marseille"], "solid", ["#FFFFFF", "#2FAEE0"]),
    (["Lyon", "Olympique Lyonnais"], "solid", ["#FFFFFF", "#14387F"]),
    (["Monaco"], "diagonal", ["#E7212D", "#FFFFFF"]),
    (["Lille"], "solid", ["#E01E13", "#20325F"]),
    (["Nice"], "stripes", ["#C8102E", "#111111"]),
    (["Rennes", "Stade Rennais"], "solid", ["#E30613", "#111111"]),
    (["Strasbourg"], "solid", ["#0A4595", "#FFFFFF"]),
    (["Lens", "RC Lens"], "solid", ["#FFD700", "#D0021B"]),
    (["Sochaux-Montbéliard", "Sochaux"], "solid", ["#FFD200", "#1F4E9E"]),
    (["Stade Lavallois", "Laval"], "solid", ["#F47B20", "#111111"]),
    (["Red Star Saint-Ouen", "Red Star"], "solid", ["#0B8A3E", "#FFFFFF"]),
    (["Stade de Reims", "Reims"], "sleeves", ["#E30613", "#FFFFFF"]),
    (["Bastia", "SC Bastia"], "solid", ["#1F4E9E", "#FFFFFF"]),
    # Türkiye
    (["Galatasaray"], "halves", ["#FDB912", "#A90432"]),
    (["Fenerbahçe"], "stripes", ["#FFED00", "#0C2340"]),
    (["Beşiktaş"], "stripes", ["#111111", "#FFFFFF"]),
    (["Trabzonspor"], "sleeves", ["#800020", "#4FA8DD"]),
    (["Başakşehir"], "solid", ["#F26522", "#1C2D5A"]),
    (["Bursaspor"], "stripes", ["#00A650", "#FFFFFF"]),
    (["Göztepe"], "halves", ["#FFD200", "#E30A17"]),
    (["Sivasspor"], "stripes", ["#E30A17", "#FFFFFF"]),
    (["Antalyaspor"], "stripes", ["#E30A17", "#FFFFFF"]),
    (["Kasımpaşa"], "solid", ["#1B2A55", "#FFFFFF"]),
    (["Konyaspor"], "solid", ["#00843D", "#FFFFFF"]),
    (["Kayserispor"], "stripes", ["#FFD200", "#E30A17"]),
    (["Samsunspor"], "solid", ["#E30A17", "#FFFFFF"]),
    # Hollanda / Portekiz
    (["Ajax"], "center", ["#FFFFFF", "#D2122E"]),
    (["PSV", "PSV Eindhoven"], "stripes", ["#ED1C24", "#FFFFFF"]),
    (["Feyenoord"], "halves", ["#E4002B", "#FFFFFF"]),
    (["Sparta Rotterdam"], "stripes", ["#E30613", "#FFFFFF"]),
    (["Porto"], "stripes", ["#003893", "#FFFFFF"]),
    (["Benfica"], "solid", ["#E83030", "#FFFFFF"]),
    (["Sporting CP", "Sporting de Portugal", "Sporting"], "hoops", ["#008057", "#FFFFFF"]),
    # Suudi Arabistan
    (["Al-Nassr", "Al Nassr", "Al-Nasr", "El Nasr", "El-Nasr", "El Nassr", "An-Nassr",
      "En-Nasr", "En Nasr"],
     "solid", ["#FCD116", "#1B3A8F"]),
    (["Al-Hilal", "Al Hilal", "El Hilal", "El-Hilal"], "solid", ["#1D4F9C", "#FFFFFF"]),
    (["Al-Ahli", "Al Ahli"], "solid", ["#007A3D", "#FFFFFF"]),
    (["Al-Ittihad", "Al Ittihad", "El İttihad", "El-İttihad", "El Ittihad", "Ittihad",
      "Al-Ittihad Jeddah"], "stripes", ["#FFD700", "#111111"]),
    # Güney Amerika
    (["Flamengo"], "hoops", ["#C8102E", "#111111"]),
    (["Boca Juniors"], "band", ["#103F79", "#F3B229"]),
    (["River Plate"], "sash", ["#FFFFFF", "#E30613"]),
    (["Palmeiras", "SE Palmeiras"], "solid", ["#006437", "#FFFFFF"]),
    (["Corinthians", "Corinthians Paulista"], "solid", ["#FFFFFF", "#111111"]),
    (["Botafogo", "Botafogo FR"], "stripes", ["#111111", "#FFFFFF"]),
    (["Fluminense"], "stripes", ["#7A0F2E", "#006B3F"]),
    (["Santos"], "solid", ["#FFFFFF", "#111111"]),
    (["Cruzeiro", "Cruzeiro EC"], "solid", ["#1D3F8F", "#FFFFFF"]),
    (["Portuguesa", "Portuguesa de Desportos"], "solid", ["#D0021B", "#0B8A3E"]),
    (["Rosario Central"], "stripes", ["#003B8E", "#FFD100"]),
    (["Racing de Avellaneda", "Racing Club", "Racing"], "stripes", ["#6CB4EE", "#FFFFFF"]),
    (["San Lorenzo de Almagro", "San Lorenzo"], "stripes", ["#1F4E9E", "#D0021B"]),
    (["Argentinos Juniors"], "solid", ["#D0021B", "#FFFFFF"]),
    (["Gimnasia y Esgrima La Plata", "Gimnasia La Plata"], "band", ["#FFFFFF", "#13294B"]),
    (["Sport Recife", "do Recife"], "hoops", ["#D0021B", "#111111"]),
    (["Fortaleza"], "hoops", ["#D0021B", "#1F4E9E"]),
    (["Coritiba"], "solid", ["#FFFFFF", "#00544D"]),
    (["São Paulo"], "band", ["#FFFFFF", "#E30613"]),
]

# Wikidata'nın genel renk adlarını futbol formasına uygun tonlara çevir
# (saf #FF0000 kırmızı yerine formalarda kullanılan daha doğal tonlar)
RENK_TONU = {
    "white": "#FFFFFF", "black": "#111111", "red": "#D0021B",
    "blue": "#1F4E9E", "navy blue": "#13294B", "navy": "#13294B",
    "dark blue": "#13294B", "royal blue": "#1D4ED8", "sky blue": "#6CB4EE",
    "light blue": "#6CB4EE", "azure": "#3B8FD9", "yellow": "#FFD200",
    "gold": "#D4A017", "golden": "#D4A017", "green": "#0B8A3E",
    "dark green": "#0A5C36", "orange": "#F47B20", "purple": "#5B2C83",
    "violet": "#5B2C83", "claret": "#7A1F3D", "maroon": "#7A1F3D",
    "bordeaux": "#7A1F3D", "burgundy": "#7A1F3D", "garnet": "#A50044",
    "crimson": "#B0102D", "scarlet": "#E0201B", "grey": "#9AA0A6",
    "gray": "#9AA0A6", "silver": "#B8BEC4", "pink": "#F48FB1",
    "brown": "#6D4C41", "turquoise": "#20B2AA", "cyan": "#20B2AA",
    "amber": "#FFBF00", "cream": "#F3E9D2",
}


def wbgetentities(idler, props, diller=None):
    sonuc = {}
    idler = list(idler)
    for bas in range(0, len(idler), 50):
        params = {"action": "wbgetentities", "ids": "|".join(idler[bas:bas + 50]),
                  "props": props, "format": "json"}
        if diller:
            params["languages"] = "|".join(diller)
        sonuc.update(istek(API_URL, params).get("entities", {}))
    return sonuc


def iddia_degerleri(varlik, ozellik):
    """Bir özelliğin değerlerini, Wikidata'daki sırasıyla döndürür."""
    degerler = []
    for iddia in varlik.get("claims", {}).get(ozellik, []):
        deger = iddia.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(deger, dict) and "id" in deger:
            degerler.append(deger["id"])
        elif isinstance(deger, str):
            degerler.append(deger)
    return degerler


def main():
    kulupler = yukle(os.path.join(VERI, "clubs.json"))
    cache = yukle(CACHE) if os.path.exists(CACHE) else {"kulup": {}, "renk": {}}

    # 1) Kulüplerin resmi renkleri (P6364)
    tum_kayitlar = [e for k in kulupler for e in [k["id"]] + k.get("es", [])]
    eksik = [i for i in tum_kayitlar if i not in cache["kulup"]]
    if eksik:
        print(f"{len(eksik)} kulübün resmi renkleri alınıyor...")
        for i, v in wbgetentities(eksik, "claims").items():
            cache["kulup"][i] = iddia_degerleri(v, "P6364")
        for i in eksik:
            cache["kulup"].setdefault(i, [])
        kaydet(CACHE, cache)

    # 2) Renk öğelerinin adı ve hex kodu (P465)
    renkler = {r for liste in cache["kulup"].values() for r in liste} - set(cache["renk"])
    if renkler:
        print(f"{len(renkler)} renk öğesi alınıyor...")
        for i, v in wbgetentities(renkler, "labels|claims", ["en"]).items():
            hexler = iddia_degerleri(v, "P465")
            cache["renk"][i] = {
                "ad": v.get("labels", {}).get("en", {}).get("value", "").lower(),
                "hex": ("#" + hexler[0].upper().lstrip("#")) if hexler else None,
            }
        kaydet(CACHE, cache)

    def renk_hex(renk_id):
        r = cache["renk"].get(renk_id, {})
        return RENK_TONU.get(r.get("ad", "")) or r.get("hex")

    # 3) Her kulübün forması
    elle = {}
    for yazimlar, desen, renk in ELLE_FORMA:
        for y in yazimlar:
            elle[anahtar(y)] = {"p": desen, "c": renk}

    formalar = {}
    say = {"elle": 0, "wikidata": 0, "yok": 0}
    renksiz = []
    kullanilan_elle = set()
    for k in kulupler:
        forma = None
        for ad in (k["ad"], k.get("tam_ad", "")):
            if anahtar(ad) in elle:
                forma = elle[anahtar(ad)]
                kullanilan_elle.add(anahtar(ad))
                say["elle"] += 1
                break
        if forma is None:
            hexler = []
            renk_listesi = cache["kulup"].get(k["id"], [])
            for e in k.get("es", []):  # kendi kaydında yoksa ek kayıtlarından
                renk_listesi = renk_listesi or cache["kulup"].get(e, [])
            for r in renk_listesi:
                h = renk_hex(r)
                if h and h not in hexler:
                    hexler.append(h)
            if hexler:
                forma = {"p": "solid", "c": hexler[:3]}
                say["wikidata"] += 1
            else:
                say["yok"] += 1
                renksiz.append(k)
        if forma:
            formalar[k["id"]] = forma

    kaydet(os.path.join(VERI, "kits.json"), formalar, kompakt=True)

    print("\n=== FORMA ÖZETİ ===")
    print(f"Kulüp                 : {len(kulupler)}")
    print(f"Elle tanımlı (desenli): {say['elle']}")
    print(f"Wikidata renkleri     : {say['wikidata']}")
    print(f"Rengi bulunamayan     : {say['yok']} (uygulamada varsayılan renkte görünür)")
    eslesmeyen = [y[0] for y, _, _ in ELLE_FORMA
                  if not any(anahtar(a) in kullanilan_elle for a in y)]
    if eslesmeyen:
        print("Elle tanımlı ama verinde bulunamayan: " + ", ".join(eslesmeyen))
    if renksiz:
        en_onemli = sorted(renksiz, key=lambda k: -k.get("oyuncu_sayisi", 0))[:40]
        print("Rengi bulunamayan en büyük kulüpler (ELLE_FORMA'ya eklenebilir):")
        print("   " + ", ".join(f"{k['ad']} ({k['lig']})" for k in en_onemli))
    suudi = [k["ad"] for k in kulupler if k["lig"] == "Suudi Pro Lig"]
    print(f"\nVerideki Suudi kulüpleri ({len(suudi)}): " + ", ".join(suudi))
    print("\nŞimdi: py hazirla.py")


if __name__ == "__main__":
    main()
