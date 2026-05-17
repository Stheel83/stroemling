# Strömling Design

Open-Source E-CAD für Elektrotechnik — Schaltpläne, Klemmenplan, Kabelliste nach DIN EN 81346 / DIN 6771 / IEC 60617.

**Stack:** Qt 6.5+ · QML · C++17 · SQLite  
**Schema:** v38 · **Stand:** Mai 2026

---

## Zielgruppe

Ambitionierte Hobbyisten und Fachleute, die ein einfaches, zuverlässiges Werkzeug für Hausinstallation und Maschinenverdrahtung suchen — ohne den Konfigurationsaufwand professioneller Tools wie EPLAN.

---

## Bauen & Starten

```bash
# Abhängigkeiten (openSUSE Tumbleweed)
sudo zypper install cmake qt6-base-devel qt6-declarative-devel \
                   qt6-sql-devel libqt6-sqldrivers-sqlite

# Bauen
cmake -B build
cmake --build build -j$(nproc)

# Starten
./build/stroemling_app
```

Die Datenbankdatei (`stroemling.db`) liegt im Build-Ordner und wird beim ersten Start automatisch angelegt. Das Schema wird bei jedem Start neu aufgebaut (Entwicklungsphase — kein Migrationsbedarf).

---

## Kernfunktionen

| Bereich | Stand |
|---|---|
| Projektstruktur (Anlage / Ort / Seite) | ✅ |
| Canvas (Zoom, Pan, Raster, Undo/Redo, Split-Ansicht) | ✅ |
| Symbole (Platzieren, Rotation, Spiegelung, Modifier, Symboleditor) | ✅ |
| Verbindungen (Potenziale, Querverweise, Signaltyp-Propagation) | ✅ |
| Bauteilbibliothek (Kabel, Klemmen, Bauteile) | ✅ |
| Klemmen-System (Klemmenreihen, Stegbrücken, Ebenenansicht) | ✅ |
| Kabel (Kabellinie, Aderzuordnung 4 Modi, Verdrahtungsweg cross-page) | ✅ |
| Automatische Listen (Stückliste, Klemmenplan, Kabelliste, CSV-Export) | ✅ |
| Normblatt DIN 6771 (Rahmen + visueller Vorlagen-Editor) | ✅ |
| Makros / Schaltplan-Vorlagen | ✅ |
| Inbetriebnahme-Modus (Prüflisten, Messwerte, PDF-Protokoll) | ✅ |
| Kabelquerschnitt-Rechner (VDE 0298-4) | ✅ |
| 3 Farbthemes (Dunkel / Hell / Blueprint) | ✅ |

---

## Architektur

```
QML (Oberfläche)
  │  Q_PROPERTY / Q_INVOKABLE / Signals
C++ Backend (Database, ElementeModel, ProjektModel, SeitenModel, …)
  │  QSqlQuery / QtSql
SQLite (stroemling.db im Build-Ordner)
```

QML hat keinen direkten Datenbankzugriff — ausschließlich über C++-Klassen.

---

## Dokumentation

Alle Konzept- und Designentscheidungen liegen in `konzept/`:

| Datei | Inhalt |
|---|---|
| `konzept/AKTUELL.md` | Aktueller Stand, offene Punkte, Konventionen |
| `konzept/08_roadmap.md` | Feature-Übersicht und Backlog |
| `konzept/01_vision_architektur.md` | Projektziele, Stack, Schichtenmodell |
| `konzept/02_datenbankschema.md` | Alle Tabellen, Schema-Versionen |
| `konzept/17_qml_struktur.md` | QML-Dateistruktur und Konventionen |
| `konzept/18_debugging.md` | Qt 6-Fallstricke, Build-Workflow |
| `konzept/24_normblatt_phase2.md` | Normblatt-Vorlagen-Editor (Phase 2) |

---

## Bewusste Abgrenzung

Strömling Design ist kein EPLAN-Klon. Nicht geplant: ERP-Anbindung, Multiuser-Betrieb, 3D-Integration, Simulation.
