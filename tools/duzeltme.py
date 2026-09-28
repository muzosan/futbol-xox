"""
Futbol XOX - Veri düzeltmeleri (tm_birlestir.py, denetle.py ve hazirla.py kullanır)

İki kaynak:
    duzeltmeler.json                -> senin elle yazdığın düzeltmeler (tools klasöründe)
    data/duzeltmeler_otomatik.json  -> denetle.py --uygula ile bulunan düzeltmeler

Veri her yeniden üretildiğinde (tm_birlestir.py) ikisi de otomatik uygulanır,
yani düzeltmeler kaybolmaz.

duzeltmeler.json biçimi:
{
  "kulup_ekle":  [{"oyuncu": "David Luiz", "kulup": "Benfica"}],
  "kulup_cikar": [{"oyuncu": "Oyuncu Adı", "dogum": 1990, "kulup": "Kulüp"}]
}
"dogum" isteğe bağlıdır; aynı isimli birden fazla oyuncu varsa ayırt etmek için yazılır.
"""

import json
import os
from collections import defaultdict

from seviye import GORUNEN_AD, anahtar  # noqa: F401 (hazirla.py da buradan alabilir)

ELLE = "duzeltmeler.json"
OTOMATIK = os.path.join("data", "duzeltmeler_otomatik.json")

def _oku(yol):
    if not os.path.exists(yol):
        return {}
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def uygula(oyuncular, kulupler):
    """Düzeltmeleri oyuncu listesine uygular.
    Dönüş: (uygulanan düzeltme sayısı, çözülemeyen elle düzeltmeler)"""
    oyuncu_id = {o["id"]: o for o in oyuncular}
    gecerli_kulup = {k["id"] for k in kulupler}
    uygulanan = 0

    for d in _oku(OTOMATIK).get("kulup_ekle", []):
        o = oyuncu_id.get(d["id"])
        if o and d["kulup"] in gecerli_kulup and d["kulup"] not in o["kulupler"]:
            o["kulupler"].append(d["kulup"])
            uygulanan += 1

    elle = _oku(ELLE)
    if not elle:
        return uygulanan, []

    kulup_ad = {}
    for k in kulupler:
        for ad in (k["ad"], k.get("tam_ad", ""), GORUNEN_AD.get(k["ad"], "")):
            if ad:
                kulup_ad.setdefault(anahtar(ad), k["id"])
    oyuncu_ad = defaultdict(list)
    for o in oyuncular:
        for ad in {o["ad"], o.get("en", "")}:
            if ad:
                oyuncu_ad[anahtar(ad)].append(o)

    cozulemeyen = []
    for islem in ("kulup_ekle", "kulup_cikar"):
        for d in elle.get(islem, []):
            adaylar = oyuncu_ad.get(anahtar(d.get("oyuncu", "")), [])
            if "dogum" in d:
                adaylar = [o for o in adaylar if o.get("dogum_yili") == d["dogum"]]
            kulup = kulup_ad.get(anahtar(d.get("kulup", "")))
            if len(adaylar) != 1 or not kulup:
                sebep = ("kulüp bulunamadı" if not kulup else
                         "oyuncu bulunamadı" if not adaylar else
                         "aynı isimli birden çok oyuncu var, 'dogum' ekle")
                cozulemeyen.append((islem, d, sebep))
                continue
            o = adaylar[0]
            if islem == "kulup_ekle" and kulup not in o["kulupler"]:
                o["kulupler"].append(kulup)
                uygulanan += 1
            elif islem == "kulup_cikar" and kulup in o["kulupler"]:
                o["kulupler"].remove(kulup)
                uygulanan += 1
    return uygulanan, cozulemeyen
