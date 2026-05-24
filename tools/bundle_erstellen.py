#!/usr/bin/env python3
"""
bundle_erstellen.py – Strömling Wiki-Bundle aus Ordnerstruktur erzeugen

Verwendung:
    python3 tools/bundle_erstellen.py <bundle-ordner> [--out <ausgabe.json>]

Ordnerstruktur (Beispiel):
    bundles/meine_tutorials/
        bundle.toml              ← Metadaten (kennung, version, titel)
        Erste Schritte/
            01_projekt_anlegen.md
            02_symbol_platzieren.md
            images/
                neues_projekt_dialog.png
                symbol_palette.png
        Altbestand – West/
            klassische_nullung.md
            images/
                tn_c_schema.png

Markdown-Bilder:
    Schreibe  ![Alt-Text](images/datei.png)  im Markdown.
    Das Skript weist lokale Bundle-IDs zu und ersetzt den Verweis
    auf  ![Alt-Text](wiki://bild/1)  – das Format das der App-Renderer versteht.
    Beim Bundle-Import in die App werden die lokalen IDs auf DB-IDs remappt.
"""

import argparse
import base64
import json
import mimetypes
import os
import re
import sys

try:
    import tomllib          # Python 3.11+
except ImportError:
    try:
        import tomli as tomllib   # pip install tomli
    except ImportError:
        tomllib = None


def lade_bundle_toml(bundle_dir: str) -> dict:
    """Liest bundle.toml; fällt auf bundle.json zurück falls vorhanden."""
    toml_pfad = os.path.join(bundle_dir, "bundle.toml")
    json_pfad = os.path.join(bundle_dir, "bundle.json")

    if os.path.exists(toml_pfad):
        if tomllib is None:
            sys.exit(
                "Fehler: bundle.toml gefunden, aber kein TOML-Parser verfügbar.\n"
                "Entweder Python 3.11+ verwenden oder: pip install tomli\n"
                "Alternativ: bundle.json statt bundle.toml anlegen."
            )
        with open(toml_pfad, "rb") as f:
            return tomllib.load(f)

    if os.path.exists(json_pfad):
        with open(json_pfad, encoding="utf-8") as f:
            return json.load(f)

    sys.exit(
        f"Fehler: Weder bundle.toml noch bundle.json in {bundle_dir!r} gefunden.\n\n"
        "Erstelle eine bundle.toml mit folgendem Inhalt:\n\n"
        "  kennung  = \"meine_tutorials\"\n"
        "  version  = 1\n"
        "  titel    = \"Meine Tutorials\"\n"
    )


def entdecke_kategorien(bundle_dir: str) -> list[str]:
    """Gibt alle Unterordner zurück (alphabetisch), die kein 'images'-Ordner sind."""
    return sorted(
        d for d in os.listdir(bundle_dir)
        if os.path.isdir(os.path.join(bundle_dir, d)) and d.lower() != "images"
    )


def entdecke_artikel(kat_dir: str) -> list[str]:
    """Gibt alle .md-Dateien im Ordner zurück (sortiert nach Dateiname)."""
    return sorted(
        f for f in os.listdir(kat_dir)
        if f.endswith(".md") and os.path.isfile(os.path.join(kat_dir, f))
    )


def verarbeite_bilder(inhalt: str, kat_dir: str,
                      bilder_liste: list, naechste_bild_id: list) -> str:
    """
    Ersetzt  ![Alt](images/datei.png)  im Markdown durch  ![Alt](wiki://bild/N).
    Fügt das Bild als base64 zur bilder_liste hinzu.
    naechste_bild_id ist eine einelementige Liste [int] – Workaround für veränderlichen
    Zähler in nested function (Python 3 kennt kein 'nonlocal' bei Closures in re.sub).
    """
    def ersatz(match):
        alt  = match.group(1)
        pfad = match.group(2)

        if not pfad.startswith("images/"):
            return match.group(0)   # externe URLs unverändert lassen

        bild_dateiname = pfad[len("images/"):]
        bild_pfad      = os.path.join(kat_dir, "images", bild_dateiname)

        if not os.path.exists(bild_pfad):
            print(f"  Warnung: Bild nicht gefunden: {bild_pfad}", file=sys.stderr)
            return match.group(0)

        mime, _ = mimetypes.guess_type(bild_pfad)
        if mime is None:
            mime = "image/png"

        with open(bild_pfad, "rb") as bf:
            daten_b64 = base64.b64encode(bf.read()).decode("ascii")

        bild_id = naechste_bild_id[0]
        naechste_bild_id[0] += 1

        bilder_liste.append({
            "id":           bild_id,
            "artikel_id":   -1,      # wird nach dem Artikel-INSERT befüllt
            "dateiname":    bild_dateiname,
            "mime_typ":     mime,
            "daten_base64": daten_b64,
            "beschreibung": alt,
            "sortierung":   bild_id,
        })

        return f"![{alt}](wiki://bild/{bild_id})"

    return re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", ersatz, inhalt)


def erstelle_bundle(bundle_dir: str, ausgabe_pfad: str | None = None):
    meta     = lade_bundle_toml(bundle_dir)
    kennung  = meta.get("kennung", "")
    version  = int(meta.get("version", 1))
    titel    = meta.get("titel", kennung)

    if not kennung:
        sys.exit("Fehler: 'kennung' in bundle.toml/bundle.json darf nicht leer sein.")

    kategorien_namen = entdecke_kategorien(bundle_dir)
    if not kategorien_namen:
        sys.exit(f"Fehler: Keine Kategorien-Unterordner in {bundle_dir!r} gefunden.")

    kategorien_arr = []
    artikel_arr    = []
    bilder_arr     = []

    naechste_bild_id = [1]   # globaler Zähler über alle Artikel
    naechste_art_id  = [1]

    for sort_idx, kat_name in enumerate(kategorien_namen):
        kat_dir = os.path.join(bundle_dir, kat_name)
        kat_id  = sort_idx + 1

        kategorien_arr.append({
            "id":           kat_id,
            "name":         kat_name,
            "beschreibung": "",
            "sortierung":   sort_idx * 10,
        })

        md_dateien = entdecke_artikel(kat_dir)
        if not md_dateien:
            print(f"  Hinweis: Keine .md-Dateien in {kat_dir!r}")

        for md_datei in md_dateien:
            art_id       = naechste_art_id[0]
            naechste_art_id[0] += 1
            md_pfad      = os.path.join(kat_dir, md_datei)
            titel_artikel = os.path.splitext(md_datei)[0]
            # Nummern-Präfix (z.B. "01_") aus Dateinamen entfernen
            titel_artikel = re.sub(r"^\d+[_\-\s]+", "", titel_artikel)

            with open(md_pfad, encoding="utf-8") as f:
                rohinhalt = f.read()

            # Ersten H1-Titel als Artikel-Titel verwenden, falls vorhanden
            h1_match = re.match(r"^#\s+(.+)", rohinhalt.lstrip())
            if h1_match:
                titel_artikel = h1_match.group(1).strip()

            # Tags aus YAML-Frontmatter extrahieren (optional)
            tags = ""
            fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", rohinhalt, re.DOTALL)
            if fm_match:
                fm_inhalt = fm_match.group(1)
                rohinhalt = rohinhalt[fm_match.end():]   # Frontmatter entfernen
                tag_match = re.search(r"^tags\s*:\s*(.+)$", fm_inhalt, re.MULTILINE)
                if tag_match:
                    tags = tag_match.group(1).strip().strip('"').strip("'")

            # Bilder-Referenzen ersetzen
            artikel_bilder: list = []
            bild_id_vor = naechste_bild_id[0]
            inhalt_remap = verarbeite_bilder(rohinhalt, kat_dir, artikel_bilder, naechste_bild_id)

            # artikel_id in den Bild-Einträgen setzen
            for b in artikel_bilder:
                b["artikel_id"] = art_id
            bilder_arr.extend(artikel_bilder)

            artikel_arr.append({
                "id":             art_id,
                "kategorie_id":   kat_id,
                "kategorie_name": kat_name,
                "titel":          titel_artikel,
                "inhalt":         inhalt_remap,
                "tags":           tags,
            })

            bild_anz = naechste_bild_id[0] - bild_id_vor
            print(f"  [{kat_name}] {titel_artikel}  ({bild_anz} Bild{'er' if bild_anz != 1 else ''})")

    bundle = {
        "wiki_export_version": 1,
        "bundle_kennung":      kennung,
        "bundle_version":      version,
        "bundle_titel":        titel,
        "kategorien":          kategorien_arr,
        "artikel":             artikel_arr,
        "bilder":              bilder_arr,
    }

    if ausgabe_pfad is None:
        ausgabe_pfad = os.path.join(
            os.path.dirname(bundle_dir.rstrip("/\\")),
            f"{kennung}.json"
        )

    with open(ausgabe_pfad, "w", encoding="utf-8") as f:
        json.dump(bundle, f, ensure_ascii=False, indent=2)

    print(f"\nBundle erstellt: {ausgabe_pfad}")
    print(f"  Kennung:   {kennung}")
    print(f"  Version:   {version}")
    print(f"  Kategorien:{len(kategorien_arr)}")
    print(f"  Artikel:   {len(artikel_arr)}")
    print(f"  Bilder:    {len(bilder_arr)}")


def main():
    parser = argparse.ArgumentParser(
        description="Strömling Wiki-Bundle aus Ordnerstruktur erzeugen"
    )
    parser.add_argument("bundle_ordner", help="Pfad zum Bundle-Ordner (enthält bundle.toml)")
    parser.add_argument("--out", "-o", metavar="AUSGABE.json",
                        help="Ausgabepfad (Standard: <bundle_ordner>/../<kennung>.json)")
    args = parser.parse_args()

    bundle_dir = os.path.realpath(args.bundle_ordner)
    if not os.path.isdir(bundle_dir):
        sys.exit(f"Fehler: Ordner nicht gefunden: {bundle_dir!r}")

    print(f"Verarbeite Bundle: {bundle_dir}")
    erstelle_bundle(bundle_dir, args.out)


if __name__ == "__main__":
    main()
