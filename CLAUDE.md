# Strömling Design – Claude Code Einstiegspunkt

**Projekt:** Strömling Design · Open-Source E-CAD für Elektrotechnik  
**Stack:** Qt 6.5+ · QML · C++17 · SQLite  
**Normen:** DIN EN 81346 · DIN 6771

---

## Umgang mit langen Sessions

Wenn der Kontext voll wird: **`/compact`** eintippen – fasst die bisherige
Unterhaltung zusammen und gibt Context frei, ohne die aktuelle Arbeit zu
unterbrechen.

Kontinuität zwischen Sessions ist gesichert über:
- `konzept/AKTUELL.md` – immer zuerst lesen, gibt den Stand in 30 Sekunden
- Memory-Dateien in `~/.claude/projects/.../memory/` – Schema-Version, offene Bugs, Konventionen

**Session-Disziplin:** Ein Thema pro Session hält den Kontext schlank.
Bei Folge-Sessions einfach neu starten – `konzept/AKTUELL.md` + Memory
reichen für sofortigen Einstieg.

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
                  Neue Migration → alleMigrationen() in src/database/Database_Schema.cpp ergänzen
DB-Pfad:          ~/.local/share/Stroemling_Design/stroemling.db
DB zurücksetzen:  Datei löschen → App neu starten (alle Migrationen laufen erneut)
Neue QML-Datei:   1) CMakeLists.txt unter QML_FILES eintragen
                  2) cmake .. im build-Ordner ausführen
                  3) make -j$(nproc)
Aktueller Stand:  konzept/AKTUELL.md  ← hier immer zuerst lesen
```

---

## Konzeptdokumentation

> `konzept/` ist ein Symlink auf ein **separates, privates Repository** (`stroemling-konzept`).
> Die Konzeptdateien sind persönliche Arbeitsunterlagen des Projektinhabers und
> **nicht** Teil des Open-Source-Releases. Commits in `konzept/` müssen im
> Konzept-Repo durchgeführt werden, nicht im Hauptrepo.

Lies zu Sitzungsbeginn immer `konzept/AKTUELL.md` (max. 30 Zeilen).
Danach nur die Konzeptdateien die zum aktuellen Thema passen.

| Datei | Inhalt | Status |
|---|---|---|
| `konzept/AKTUELL.md` | **Einstieg:** Was zuletzt fertig, was als nächstes | — |
| **`konzept/architektur/`** | **Wie ist die App gebaut?** | |
| `konzept/architektur/01_vision_architektur.md` | Projektziele, Stack, Schichtenmodell, Abgrenzung | ✅ |
| `konzept/architektur/02_datenbankschema.md` | Alle Tabellen, Views, Relationen, Schema-Strategie | ✅ |
| `konzept/architektur/03_canvas_zeichenfläche.md` | Canvas-Modi, Zoom/Pan, Raster, Hintergrundfarbe, Mehrfachauswahl (Fenster/Schneiden) | ✅ |
| `konzept/architektur/10_ui_terminologie.md` | Verbindliche Bezeichnungen für alle Fenster, Panels und Bereiche | ✅ |
| `konzept/architektur/17_qml_struktur.md` | QML-Dateistruktur aller Unterordner, Architektur-Konventionen, EP-Auslöserbedingungen | ✅ |
| `konzept/architektur/19_farben_theming.md` | UI-Theme-System (3 Themes, theme-Objekt-Struktur, Weitergabe), Canvas-Hintergrund | ✅ |
| `konzept/architektur/20_qml_initialisierung.md` | QML-Initialisierungsreihenfolge: C++-Phase, Singleton, Objektbaum-Aufbau | ✅ |
| `konzept/architektur/21_canvas_elemente_model.md` | ElementeModel: Canvas-Datenschicht; API-Design, Element-Struct | ✅ |
| `konzept/architektur/23_technische_ablaeufe.md` | Systemabläufe: EP↔Canvas-Datenfluss, Netzberechnung, Koordinatensystem, Laden/Speichern | ✅ |
| `konzept/architektur/26_release_migration.md` | Release-Vorbereitung: DB-Trennung, Migrations-System, Export/Import, App-Datenverzeichnis | ✅ |
| `konzept/architektur/37_button_design_standard.md` | Button-Design-Standard für Dialoge: Primär/Abbrechen-Optik, hover-Logik, Referenz-Implementierungen | ✅ |
| **`konzept/features/`** | **Was kann die App?** | |
| `konzept/features/04_symbolsystem.md` | Haupt-/Nebenfunktion, Erweiterungen, Pinkatalog, Rotation; Domain-Symbole Arduino (§9) | ✅ |
| `konzept/features/05_leitungen_kabel.md` | Einzelader, Kabelbaum, Verbindungslogik im Canvas | ✅ |
| `konzept/features/06_bauteilbibliothek.md` | Bibliotheksstruktur, Varianten, Kabeldefinitionen | ✅ |
| `konzept/features/07_normkennzeichnung.md` | BMK nach DIN EN 81346, Seitenkennzeichnung DIN 6771, NKZ-04 Default-Anlage/Ort | 🔄 NKZ-01 offen (DIN EN 81346 alt vs. IEC 81346 neu) |
| `konzept/features/09_klemmen.md` | Klemmen: 3-Ebenen-Modell, Bauteil-Editor, Klemmenreihen-Editor, Canvas-Platzierung | ✅ |
| `konzept/features/11_symboleditor.md` | Symbole visuell erstellen und bearbeiten | ✅ |
| `konzept/features/12_Kabelberechnung.md` | Kabelquerschnitt-Rechner: Formeln, UI-Layout, Normen-Referenztabellen (IP/IK/VDE/IEC) | ✅ |
| `konzept/features/14_Inbetriebnahme.md` | IBN-Modus: Betriebsmittel prüfen, Messwerte erfassen, Prüfprotokoll | 🔄 offene Designfragen |
| `konzept/features/15_makros.md` | Makros / Schaltplan-Vorlagen: Makrokasten, DB-Schema, UX-Ablauf, C++-API | ✅ |
| `konzept/features/24_normblatt_phase2.md` | Normblatt-Vorlagen-Editor Phase 2: `normblatt_feld`, C++ API, Canvas-Renderer | ✅ |
| `konzept/features/25_wiki.md` | Erfahrungs-Wiki + Inhalts-Bundles: Schema v40/WIKI_SCHEMA v10, `WikiModel`, Bundle-JSON | ✅ |
| `konzept/features/27_sps.md` | SPS/PLS-Integration: DB-Schema, Ansicht, EP-Adresszuweisung, I/O-Liste, CSV-Export | ✅ |
| `konzept/features/29_pdf_export.md` | PDF-Export: Vektor-PDF, alle Element-Typen, Kreuzungslücken, Aderbeschriftung | ✅ |
| `konzept/features/30_fun_modus.md` | Fun-Modus (Easter Egg): 8 Szenarien, Sprite-System | ✅ |
| `konzept/features/35_drc.md` | Design Rule Check: 8 Checks (D-01 bis D-08) | ✅ |
| `konzept/features/36_minimap.md` | Canvas Minimap: Strg+M Übersichtsfenster, CanvasMinimap.qml | ✅ |
| `konzept/features/38_nutzbarkeit.md` | Nutzbarkeit & Nutzerführung: Tooltip-Audit, Leere-Zustände, Onboarding, F1-Kontexthilfe | 🔄 F1-Kontexthilfe Teilumfang (5 Ansichten ✅) |
| `konzept/features/39_fehlersuchmodus.md` | Fehlersuchmodus (L9): Strompfad-BFS, seitenübergreifend, Symbol-Rollen | ✅ |
| `konzept/features/40_geraete_kontaktspiegel.md` | Geräte (Schütz/Relais): BMK-Vererbung, Kontaktspiegel, Platzierungs-Workflow | ✅ |
| `konzept/features/41_git_integration.md` | Git-Integration: Auto-Commit, Remote-Push, Projekt-History | ✅ |
| `konzept/features/41_sprungfunktion.md` | Sprungfunktion: Navigation Referenz → Canvas-Position; 4 Phasen, Signal-Kette | 🔄 Phase 4 Teilumfang (Stückliste ✅, 7 Listen-Tabs offen) |
| `konzept/features/42_makro_palette.md` | Makro-Schnellpalette: Kategorie-Akzentstreifen, Overlay-Vorschau, Bibliotheks-Dialog | ✅ |
| `konzept/features/43_geraetekasten.md` | Gerätekasten: EP + BAUTEILE-Panel + Sprungfunktion Phase 3 | ✅ |
| `konzept/features/44_achievements.md` | Achievement-System: 47 Achievements, AchievementManager, Toast, Panel | ✅ |
| `konzept/features/45_steckverbinder.md` | Stecker und Buchsen: 4-Kombinations-Matrix, 3-Ebenen-Modell, Kontakteigenschaften, Steckpaar-Logik, BMK, DB-Schema-Entwurf | 🔄 Pin-2-Kopplung (§6.5) implementiert, Rest 📋 |
| `konzept/features/46_schirmung.md` | Schirm-Oval (Canvas-Element `schirm`), SH-Kennzeichnung, Schirmanschluss via Geräteanschluss | 🔄 SCH-02 (DRC-Warnung) offen |
| `konzept/features/47_meldungen_toast.md` | Meldungs-Toast: `MeldungManager` (C++, analog AchievementManager), `MeldungToast.qml`, Abgrenzung Toast vs. Dialog, migrierte Stellen | ✅ |
| `konzept/features/48_rosi_roehrenaal.md` | Rosi Röhrenaal: Maskottchen-Assistentin (Klippy-Hommage), `RosiManager`, Timing/Persistenz, Berlinerisch-Sprüche-Pools, Urlaub/Besuch | 🔄 Backend+QML implementiert, Bild-Asset offen |
| **`konzept/technik/`** | **Wie entwickle ich daran?** | |
| `konzept/technik/18_debugging.md` | Debugging-Workflow, visuelle Indikatoren, Log-Muster, Qt 6-Fallstricke, Build-Merkhilfen | ✅ |
| `konzept/technik/22_manuelle_tests.md` | Manuelle Testszenarien und Checklisten | ✅ |
| `konzept/technik/31_optimierungen.md` | Optimierungspotenziale (alle abgeschlossen) | ✅ |
| `konzept/technik/33_rotation_multi_debug.md` | Debugging-Protokoll: ROTATION-MULTI-01 (behoben) | ✅ |
| `konzept/technik/36_codeberg_repo_aufteilung.md` | Codeberg-Einrichtung & Repo-Aufteilung (Symlink-Lösung) | ✅ |
| `konzept/technik/40_listen_bg_debug.md` | Debugging-Protokoll: LISTEN-BG-01 (behoben) | ✅ |
| **`konzept/projekt/`** | **Wer ist das Projekt?** | |
| `konzept/projekt/08_roadmap.md` | Nächste Schritte, mittelfristige und langfristige Planung | — |
| `konzept/projekt/32_mitwirkende.md` | Mitwirkende, Danksagungen, Entstehungsgeschichte | ✅ |
| `konzept/projekt/34_stromlinge.md` | Strömlinge-Charakter-System: 13+ Figuren, Verwendung in App | 🔄 STR-09 Bilder offen |
| `konzept/projekt/49_vermarktung_lizenzierung.md` | Vermarktung: Duallizenzierung, Auftragsarbeit (Makros/Symbole) — einfaches Nutzungsrecht als Standard, exklusiv nur bei kundenspezifischen Vorlagen, Code/Website/Programm-Anpassungen, Arbeitgeber-Klärung, Gewerbe/Freiberufler-Anmeldung, Zeitrahmen | 📋 Konzept |

---

## Entwicklungsstatus

Das Projekt befindet sich in aktiver Entwicklung – **keine Produktivnutzer,
keine Altdaten, keine Migrationen notwendig.**

- Kompatibilitäts-Shims und One-Time-Migrations-Code dürfen entfernt werden
- „Unterstützung für altes Format XY" ist toter Code – löschen, nicht behalten
- Neue Features brauchen keine Rückwärtskompatibilität

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
- Schemaänderungen kommen als inkrementelle Migration in `alleMigrationen()` in `Database_Schema.cpp`
- Jede Migration bekommt eine aufsteigende Versionsnummer und eine `QStringList` mit SQL-Statements
- **Vollständiger Rebuild** nur noch durch manuelles Löschen der DB-Datei (`~/.local/share/Stroemling_Design/stroemling.db`)
- Datenbankdatei liegt in `~/.local/share/Stroemling_Design/stroemling.db` (R3 erledigt, PATH-01 normalisiert)
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
