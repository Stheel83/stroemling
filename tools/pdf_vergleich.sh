#!/usr/bin/env bash
# Vergleicht zwei PDF-Ordner seitenweise (gerendert, Pixelvergleich) – Absicherung beim Umbau von
# src/database/Database_PDF.cpp. Die Eingaben enthalten ggf. echte Nutzerdaten: nie ins Repo legen.
#
# Ablauf:
#   1) Kopie eines Projekts + der Bibliothek anlegen (WAL-sicher, nie per cp):
#        sqlite3 ~/Stroemling_Projekte/<Name>/projekt.strl ".backup /pfad/arbeit/projekt.strl"
#        sqlite3 ~/.local/share/Stroemling_Design/bibliothek.db ".backup /pfad/arbeit/bibliothek.db"
#        cp -r ~/Stroemling_Projekte/<Name>/bilder /pfad/arbeit/bilder     # Bilddateien liegen neben der .strl
#   2) Referenz VOR dem Umbau erzeugen (aus dem build-Ordner):
#        QT_QPA_PLATFORM=offscreen STROEMLING_PDF_PROJEKT=/pfad/arbeit/projekt.strl \
#          STROEMLING_PDF_BIB=/pfad/arbeit/bibliothek.db STROEMLING_PDF_AUSGABE=/pfad/vorher \
#          ./stroemling_test pdf_referenzexport
#   3) Umbau, neu bauen, dasselbe mit STROEMLING_PDF_AUSGABE=/pfad/nachher
#   4) tools/pdf_vergleich.sh /pfad/vorher /pfad/nachher
# (Die Meldung "Function not found" der Klasse TstMigrationen im Lauf ist harmlos.)
set -euo pipefail
a="${1:?Ordner mit Referenz-PDFs}"; b="${2:?Ordner mit neuen PDFs}"; dpi="${3:-60}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rc=0
for fa in "$a"/*.pdf; do
    n="$(basename "$fa")"; fb="$b/$n"
    if [[ ! -f "$fb" ]]; then echo "FEHLT   $n"; rc=1; continue; fi
    pdftoppm -r "$dpi" -png "$fa" "$tmp/a"; pdftoppm -r "$dpi" -png "$fb" "$tmp/b"
    sa=$(ls "$tmp"/a-*.png | wc -l); sb=$(ls "$tmp"/b-*.png | wc -l)
    if [[ "$sa" != "$sb" ]]; then echo "SEITEN  $n: $sa vs $sb"; rc=1; rm -f "$tmp"/*.png; continue; fi
    bad=0
    for pa in "$tmp"/a-*.png; do
        pb="$tmp/b-$(basename "$pa" | sed 's/^a-//')"
        d=$(compare -metric AE "$pa" "$pb" null: 2>&1 || true); d="${d%% *}"
        if [[ "$d" != "0" ]]; then echo "DIFF    $n $(basename "$pa" .png): $d Pixel"; bad=1; fi
    done
    [[ $bad == 0 ]] && echo "OK      $n" || rc=1
    rm -f "$tmp"/*.png
done
exit $rc
