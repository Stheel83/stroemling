# Strömling Design – Claude Code Einstiegspunkt

**Projekt:** Strömling Design · Open-Source E-CAD für Elektrotechnik  
**Stack:** Qt 6.5+ · QML · C++17 · SQLite  
**Normen:** DIN EN 81346 · DIN 6771 · IEC 60617

---

## Fehlerreport-Vorlage (für den Nutzer)

Wenn etwas nicht funktioniert, diese 4 Punkte mitgeben:

```
Rebuild:   ja / nein  (wurde nach der letzten Änderung neu gebaut?)
Aktion:    [was genau getan wurde, z.B. "Kabellinie auswählen → Aderzuordnung öffnen → Ader 2 wählen → Übernehmen"]
Erwartet:  [was passieren sollte]
Passiert:  [was stattdessen passiert ist]
```

Danach den relevanten Log-Ausschnitt einfügen (journalctl-Output).

---

## Schnellreferenz

```
Build:            cd build && make -j$(nproc)
Schema-Version:   wird über schema_migration-Tabelle verwaltet (SCHEMA_VERSION-Konstante entfällt)
                  Neue Migration → alleMigrationen() in src/database/Database.cpp ergänzen
DB-Pfad:          ~/.local/share/Strömling Design/stroemling.db
DB zurücksetzen:  Datei löschen → App neu starten (alle Migrationen laufen erneut)
Neue QML-Datei:   1) CMakeLists.txt unter QML_FILES eintragen
                  2) cmake .. im build-Ordner ausführen
                  3) make -j$(nproc)
Aktueller Stand:  konzept/AKTUELL.md  ← hier immer zuerst lesen
```

---

## Konzeptdokumentation

Lies zu Sitzungsbeginn immer `konzept/AKTUELL.md` (max. 30 Zeilen).
Danach nur die Konzeptdateien die zum aktuellen Thema passen.

| Datei | Inhalt |
|---|---|
| `konzept/AKTUELL.md` | **Einstieg:** Was zuletzt fertig, was als nächstes, bekannte Bugs |
| **`konzept/architektur/`** | **Wie ist die App gebaut?** |
| `konzept/architektur/01_vision_architektur.md` | Projektziele, Stack, Schichtenmodell, Abgrenzung |
| `konzept/architektur/02_datenbankschema.md` | Alle Tabellen, Views, Relationen, Schema-Strategie |
| `konzept/architektur/03_canvas_zeichenfläche.md` | Canvas-Modi, Zoom/Pan, Raster, Hintergrundfarbe |
| `konzept/architektur/10_ui_terminologie.md` | Verbindliche Bezeichnungen für alle Fenster, Panels und Bereiche |
| `konzept/architektur/17_qml_struktur.md` | QML-Dateistruktur aller Unterordner (ep/canvas/ba/la/…), Architektur-Konventionen, EP-Auslöserbedingungen |
| `konzept/architektur/19_farben_theming.md` | UI-Theme-System (3 Themes, theme-Objekt-Struktur, Weitergabe), Canvas-Hintergrund |
| `konzept/architektur/20_qml_initialisierung.md` | QML-Initialisierungsreihenfolge: C++-Phase, Singleton, Objektbaum-Aufbau, Component.onCompleted |
| `konzept/architektur/21_canvas_elemente_model.md` | ElementeModel: Canvas-Datenschicht; API-Design, Element-Struct |
| `konzept/architektur/23_technische_ablaeufe.md` | Systemabläufe: EP↔Canvas-Datenfluss, Netzberechnung, Koordinatensystem, Laden/Speichern, Kabel |
| `konzept/architektur/26_release_migration.md` | Release-Vorbereitung: DB-Trennung, Migrations-System, Export/Import, App-Datenverzeichnis |
| **`konzept/features/`** | **Was kann die App?** |
| `konzept/features/04_symbolsystem.md` | Haupt-/Nebenfunktion, Erweiterungen, Pinkatalog, Rotation; Domain-Symbole Arduino (§9) |
| `konzept/features/05_leitungen_kabel.md` | Einzelader, Kabelbaum, Verbindungslogik im Canvas |
| `konzept/features/06_bauteilbibliothek.md` | Bibliotheksstruktur, Varianten, Kabeldefinitionen |
| `konzept/features/07_normkennzeichnung.md` | BMK nach DIN EN 81346, Seitenkennzeichnung DIN 6771 |
| `konzept/features/09_klemmen.md` | Klemmen: 3-Ebenen-Modell, Bauteil-Editor, Klemmenreihen-Editor, Canvas-Platzierung |
| `konzept/features/11_symboleditor.md` | Symbole visuell erstellen und bearbeiten |
| `konzept/features/12_Kabelberechnung.md` | Kabelquerschnitt-Rechner: Formeln, UI-Layout, Normen-Referenztabellen (IP/IK/VDE/IEC) |
| `konzept/features/14_Inbetriebnahme.md` | IBN-Modus: Betriebsmittel prüfen, Messwerte erfassen, Prüfprotokoll |
| `konzept/features/15_makros.md` | Makros / Schaltplan-Vorlagen: Makrokasten, DB-Schema v31 (`makro`, `makro_element`), UX-Ablauf, C++-API |
| `konzept/features/24_normblatt_phase2.md` | Normblatt-Vorlagen-Editor Phase 2: Schema v38, `normblatt_feld`, C++ API, Canvas-Renderer |
| `konzept/features/25_wiki.md` | Erfahrungs-Wiki (W1–W4 ✅) + Inhalts-Bundles (TB-1–TB-7 ✅): Schema v40/WIKI_SCHEMA v10, `WikiModel`, Bundle-JSON, `bundle_erstellen.py` |
| `konzept/features/27_sps.md` | SPS-Integration: DB-Schema, SPS-Ansicht, EP-Adresszuweisung, I/O-Liste, CSV-Export |
| `konzept/features/29_pdf_export.md` | PDF-Export: Vektor-PDF, alle Element-Typen, Kreuzungslücken, Aderbeschriftung |
| `konzept/features/30_fun_modus.md` | Fun-Modus (Easter Egg): 8 Szenarien, Sprite-System |
| `konzept/features/35_drc.md` | Design Rule Check: 8 Checks (D-01 bis D-08) |
| `konzept/features/38_nutzbarkeit.md` | Nutzbarkeit & Nutzerführung: Tooltip-Audit (Phase 1 ✅ / Phase 2 📋), Leere-Zustände, Onboarding |
| **`konzept/technik/`** | **Wie entwickle ich daran?** |
| `konzept/technik/18_debugging.md` | Debugging-Workflow, visuelle Indikatoren, Log-Muster, Qt 6-Fallstricke, Build-Merkhilfen |
| `konzept/technik/22_manuelle_tests.md` | Manuelle Testszenarien und Checklisten |
| `konzept/technik/31_optimierungen.md` | Optimierungspotenziale (C-01/C-02/D-02 langfristig offen) |
| `konzept/technik/33_rotation_multi_debug.md` | Debugging-Protokoll: ROTATION-MULTI-01 (Mehrfachauswahl-EP, offen) |
| **`konzept/projekt/`** | **Wer ist das Projekt?** |
| `konzept/projekt/08_roadmap.md` | Implementierungsstand, nächste Schritte, offene Punkte |
| `konzept/projekt/32_mitwirkende.md` | Mitwirkende, Danksagungen, Entstehungsgeschichte |
| `konzept/projekt/34_stromlinge.md` | Strömlinge-Charakter-System: 13+ Figuren, Verwendung in App; Quellmaterial in `konzept/Strömlinge/` |
| **`konzept/archiv/`** | **Abgeschlossenes Werk (Referenz)** |
| `konzept/archiv/erledigt.md` | Alle erledigten Meilensteine, Optimierungen und Sprint-Changelog; nicht mehr aktiv gepflegt |

---

## Arbeitsregeln für Claude

### Vor jeder Änderung
1. `konzept/AKTUELL.md` lesen – gibt den Kontext in 30 Sekunden
2. Die zum Thema passende Konzeptdatei lesen
3. Abweichungen zwischen Code und Konzept **melden bevor** angefangen wird
4. Nicht eigenmächtig das Konzept vereinfachen um Implementierung zu erleichtern

### Nach jeder Änderung (Standardverfahren)
Nach dem Abschließen jeder Code-Änderung – auch kleiner Fixes – die betroffenen
Konzeptdateien auf Aktualität prüfen und **sofort** anpassen:

1. Welche Konzeptdatei(en) sind betroffen? (Schema, Canvas, Symbole, Klemmen…)
2. Stimmen Status-Marker (✅ / 📋 / 🔄), Schema-Versionen und
   Implementierungsstand-Tabellen noch?
3. Neue Designentscheidungen oder Abweichungen vom Konzept kurz begründen
4. Offene Punkte und TODOs in `konzept/projekt/08_roadmap.md` eintragen oder aktualisieren
5. **`konzept/AKTUELL.md` auf aktuellen Stand bringen** – was wurde fertig, was kommt als nächstes
6. **Memory-Datei** `~/.claude/projects/.../memory/project_stroemling_stand.md` aktualisieren

Dieses Verfahren gilt auch für reine QML-Fixes, Refactorings und
UI-Konsistenz-Korrekturen – nicht nur für neue Features.

### Architektur – unveränderliche Grundsätze
- **QML hat keinen direkten Datenbankzugriff** – ausschließlich über C++-Modelle
- **Kein direkter SQL in QML** – alle DB-Operationen in C++ Backend-Klassen
- **Schichtenmodell einhalten:** QML → C++ Modelle → SQLite
- **Foreign Keys bleiben aktiviert** (`PRAGMA foreign_keys = ON`)

### Migrations-System (ab R4 aktiv)
- Datenbankschema wird **nicht** mehr bei jedem Start neu aufgebaut
- Schemaänderungen kommen als inkrementelle Migration in `alleMigrationen()` in `Database.cpp`
- Jede Migration bekommt eine aufsteigende Versionsnummer und eine `QStringList` mit SQL-Statements
- **Vollständiger Rebuild** nur noch durch manuelles Löschen der DB-Datei (`~/.local/share/Strömling Design/stroemling.db`)
- Datenbankdatei liegt in `~/.local/share/Strömling Design/stroemling.db` (R3 erledigt)
- `SCHEMA_VERSION`-Konstante entfällt – Versionierung über `schema_migration`-Tabelle

### QML-Dateien: Pflichtregistrierung in CMakeLists.txt
Jede neue `.qml`-Datei – egal ob in `qml/`, `qml/components/` oder `qml/ep/` – **muss sofort**
in `CMakeLists.txt` unter `QML_FILES` eingetragen werden. Fehlt der Eintrag, kann
die App zwar kompilieren, startet aber nicht (der QML-Loader findet die Komponente
zur Laufzeit nicht). Nach jedem neuen Eintrag `cmake ..` im Build-Ordner ausführen.

### Was Claude NICHT eigenständig ändern darf
- Das Datenbankschema ohne explizite Anweisung umstrukturieren
- Den Canvas-Rendering-Ansatz (Qt Quick Canvas / 2D Context) ersetzen
- Die Koordinatensystematik des Pinkatalogs (`0..1` normiert) ändern
- Neue Abhängigkeiten (Libraries) hinzufügen ohne Rückfrage

### Bekannte QML-Fallstricke in diesem Projekt

Vollständige Liste mit Ursachen und Fixes: → `konzept/technik/18_debugging.md` §5

### Konzeptpflege
- Wenn eine Konzeptentscheidung sich im Gespräch ändert: **Konzeptdatei sofort
  aktualisieren**, bevor Code geändert wird
- Offene Punkte und TODOs in `konzept/projekt/08_roadmap.md` eintragen
- Bei Designentscheidungen kurz begründen warum – analog zum Stil in
  `konzept/architektur/01_vision_architektur.md` Abschnitt „Designentscheidungen"

### Abgleich Konzept ↔ Code (bei Unklarheit)
Wenn der Überblick fehlt oder Konzept und Code auseinanderdriften:
> „Lies alle Dateien in `konzept/` und vergleiche sie mit dem tatsächlichen
>  Code. Erstelle einen Abweichungsbericht: Was stimmt überein, was weicht ab,
>  was fehlt noch?"

---

## Projektstruktur
Aktuelle Struktur immer per `tree stroemling/` prüfen.
Übersicht: `konzept/architektur/01_vision_architektur.md`
