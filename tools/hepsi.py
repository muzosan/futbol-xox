"""
Futbol XOX - Bütün veri hattını doğru sırayla çalıştırır.

Kullanım (tools klasöründe):
    py hepsi.py              -> baştan sona
    py hepsi.py 5            -> 5. adımdan devam et (bir adım hata verdiyse)

Her adım önbellekli çalışır; bir adım yarıda kalırsa aynı komutla tekrar
başlatabilir ya da kaldığın adım numarasıyla devam edebilirsin.
"""

import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")

ADIMLAR = [
    ("veri_topla.py", [], "Kulüpler ve oyuncular (Wikidata)"),
    ("tm_birlestir.py", [], "Transfermarkt ile birleştirme"),
    ("detay_topla.py", [], "Mevki ve uyruk"),
    ("forma_topla.py", [], "Forma renkleri"),
    ("istatistik_topla.py", [], "İstatistikler (gol, asist, kart, milli maç)"),
    ("tablo_uret.py", [], "XOX tabloları"),
    ("hazirla.py", [], "Uygulama verisi"),
    ("kariyer_hazirla.py", [], "Kariyerler (Kim Bu?)"),
    ("denetle.py", ["--uygula"], "Veri denetimi ve otomatik düzeltmeler"),
    ("tablo_uret.py", [], "XOX tabloları (düzeltmelerle)"),
    ("hazirla.py", [], "Uygulama verisi (düzeltmelerle)"),
]


def main():
    baslangic = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    toplam_sure = time.time()
    for i, (script, argumanlar, aciklama) in enumerate(ADIMLAR, 1):
        if i < baslangic:
            continue
        print(f"\n{'=' * 60}\n[{i}/{len(ADIMLAR)}] {aciklama}  ({script} {' '.join(argumanlar)})\n{'=' * 60}")
        sure = time.time()
        sonuc = subprocess.run([sys.executable, script, *argumanlar])
        if sonuc.returncode != 0:
            print(f"\n!!! {script} hata verdi. Sorunu giderip şu komutla kaldığın yerden devam et:")
            print(f"    py hepsi.py {i}")
            sys.exit(1)
        print(f"--- {script} bitti ({(time.time() - sure) / 60:.1f} dk)")
    print(f"\nHepsi tamamlandı ({(time.time() - toplam_sure) / 60:.1f} dk). "
          f"Uygulamayı yeniden başlatabilirsin.")
    print("Denetim raporunun tamamı: data/denetim_raporu.txt")


if __name__ == "__main__":
    main()
