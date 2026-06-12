# Strömling Design

Open-Source E-CAD für Elektrotechnik — Schaltpläne, Klemmenplan, Kabelliste. Strömling Design orientiert sich an den Normen DIN EN 81346 und DIN 6771, erhebt aber keinen Anspruch auf zertifizierte Normkonformität.

**Stack:** Qt 6.5+ · QML · C++17 · SQLite  
**Schema:** v65 · **Stand:** Juni 2026 · **Version:** v0.5

## Download

| Plattform | Link |
|-----------|------|
| Linux x64 | [AppImage herunterladen](https://stheelke.de/downloads/Stroemling-Design-0.5-x86_64.AppImage) |
| Windows x64 | [ZIP herunterladen](https://stheelke.de/downloads/Stroemling-Design-0.5-windows-x64.zip) |

Keine Installation nötig. Linux: `chmod +x` und starten. Windows: ZIP entpacken, `stroemling_app.exe` starten.

---

## Entstehung

Das Projekt entstand aus einem konkreten Bedürfnis: Im Beruf arbeite ich täglich mit EPLAN P8 Electric — einem professionellen E-CAD-Tool, das keine Linux-Version hat und für den Privatgebrauch nicht in Frage kommt. Privat nutze ich ausschließlich Linux (openSUSE mit KDE), und ich wollte ein E-CAD-Tool, das meinen persönlichen Anforderungen entspricht. QElectroTech kannte ich, aber auch das war nicht das, was ich mir vorgestellt hatte. Also habe ich angefangen, selbst etwas zu bauen — mit KI-Unterstützung, obwohl ich kein Programmierer bin.

Open Source deshalb, damit andere das Projekt leicht aufgreifen, forken oder weiterführen können — ohne auf mich angewiesen zu sein. Ob es für E-Techniker fachlich taugt, wird sich im Test mit Kollegen zeigen.

---

## Zielgruppe

Hobbyisten und Fachleute, die ein einfaches Werkzeug für Hausinstallation und Maschinenverdrahtung suchen — ohne den Konfigurationsaufwand professioneller Tools wie EPLAN.

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

Beim ersten Start wird das App-Datenverzeichnis automatisch angelegt:

```
~/.local/share/Stroemling_Design/
  stroemling.db   ← Launcher-DB (zuletzt geöffnete Projekte)
  wiki.db         ← projektübergreifendes Wiki
  makros.db       ← Makro-Bibliothek
```

Projekte werden als eigenständige Ordner gespeichert:

```
~/[beliebiger Ort]/MeinProjekt/
  projekt.strl    ← Projektdatenbank (SQLite, alle Schaltplandaten)
```

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
| Automatische Listen (Stückliste, Klemmenplan, Kabelliste, Klemmlistenauszug, CSV-Export) | ✅ |
| PDF-Export (Vektor-PDF, alle Elementtypen, Kreuzungslücken) | ✅ |
| Design Rule Check (doppelte BMK, offene Pins, fehlende Verbindungen u.a.) | ✅ |
| Geräte (Schütz/Relais: BMK-Vererbung, Kontaktspiegel, Bauteil-first-Workflow) | ✅ |
| SPS/PLS-Integration (I/O-Liste, Kanal-Zuweisung, CSV-Export) | ✅ |
| Normblatt DIN 6771 (Rahmen + visueller Vorlagen-Editor) | ✅ |
| Makros / Schaltplan-Vorlagen | ✅ |
| Inbetriebnahme-Modus (Prüflisten, Messwerte, PDF-Protokoll) | ✅ |
| Erfahrungs-Wiki (projektübergreifend, Bundle-Import) | ✅ |
| Kabelquerschnitt-Rechner (VDE 0298-4) | ✅ |
| Git-Integration (Snapshots, Projekt-History) | ✅ |
| 3 Farbthemes (Dunkel / Hell / Blueprint) | ✅ |

---

## Architektur

```
QML (Oberfläche)
  │  Q_PROPERTY / Q_INVOKABLE / Signals
C++ Backend (Database, ElementeModel, ProjektModel, SeitenModel, …)
  │  QSqlQuery / QtSql
SQLite  ┬─ ~/.local/share/Stroemling_Design/stroemling.db  (Launcher-DB)
        └─ [Projektordner]/projekt.strl                   (Projektdaten)
```

QML hat keinen direkten Datenbankzugriff — ausschließlich über C++-Klassen.

---

## Konzeptdateien

Das Verzeichnis `konzept/` enthält die persönlichen Arbeitsunterlagen des Projektinhabers (Designentscheidungen, Roadmap, Debugging-Notizen). Diese Dateien sind **nicht** Teil des Open-Source-Releases und werden nicht veröffentlicht.

---

## Bewusste Abgrenzung

Strömling Design ist kein EPLAN-Klon. Nicht geplant: ERP-Anbindung, Multiuser-Betrieb, 3D-Integration, Simulation.
