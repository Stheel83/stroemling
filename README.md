# ⚡ Strömling Design – Technische Dokumentation

**Version:** Schema v7  
**Stand:** April 2026  
**Stack:** Qt 6.5+ · QML · C++17 · SQLite  
**Normen:** DIN EN 81346 · DIN 6771 · IEC 60617

---

## Inhaltsverzeichnis

1. [Projektübersicht](#1-projektübersicht)
2. [Architektur](#2-architektur)
3. [Entwicklungsumgebung](#3-entwicklungsumgebung)
4. [Projektstruktur](#4-projektstruktur)
5. [Datenbankschema](#5-datenbankschema)
6. [C++ Backend](#6-c-backend)
7. [QML Frontend](#7-qml-frontend)
8. [Normenkonformität](#8-normenkonformität)
9. [Automatische Listen (Views)](#9-automatische-listen-views)
10. [Roadmap](#10-roadmap)
11. [Designentscheidungen](#11-designentscheidungen)

---

## 1. Projektübersicht

Strömling Design ist ein Open-Source E-CAD Tool für Elektrotechnik. Zielgruppe sind ambitionierte Hobbyisten und Fachleute die ein einfaches, zuverlässiges Werkzeug für Hausinstallation und Maschinenverdrahtung suchen – ohne den Konfigurationsaufwand professioneller Tools wie EPLAN Electric P8.

### Kernziele

- Solide Grundlagen statt Featurefülle
- Daten einmal erfassen – automatisch überall verfügbar (Stückliste, Klemmenplan, Kabelplan)
- Normgerechte Kennzeichnung nach DIN EN 81346 und DIN 6771
- SQLite als einzige Datei – einfach zu sichern, zu versionieren, weiterzugeben
- Qt6 + QML für eine moderne, native Desktop-Oberfläche unter Linux

### Abgrenzung

Strömling Design ist kein EPLAN-Klon. Folgende Funktionen sind bewusst nicht geplant:

- ERP-Anbindung
- Multiuser-Betrieb
- 3D-Integration
- Simulation oder Berechnung

---

## 2. Architektur

```
┌─────────────────────────────────────────┐
│           QML (Oberfläche)              │
│   ListView, TreeView, Dialog, Canvas    │
└──────────────────┬──────────────────────┘
                   │ Q_PROPERTY / Q_INVOKABLE
                   │ Signals & Slots
┌──────────────────▼──────────────────────┐
│         C++ Backend                     │
│   QAbstractListModel, QAbstractItemModel│
│   Database, ProjektModel, SeitenModel,  │
│   BauteilKategorieModel, BauteilListModel│
└──────────────────┬──────────────────────┘
                   │ QSqlQuery / QtSql
┌──────────────────▼──────────────────────┐
│         SQLite Datenbank                │
│   ~/.local/share/Strömling Design/      │
│   stroemling.db                         │
└─────────────────────────────────────────┘
```

QML hat keinen direkten Datenbankzugriff. Es kommuniziert ausschließlich über C++-Modelle die als Kontext-Properties in der QML Engine registriert sind.

### Schichtenmodell

| Schicht | Technologie | Verantwortung |
|---|---|---|
| Oberfläche | QML / Qt Quick | Darstellung, Navigation, Benutzereingaben |
| Modelle | C++ QAbstractListModel / QAbstractItemModel | Daten für QML aufbereiten, Änderungen zurückschreiben |
| Datenbank | C++ / QtSql | Verbindung, Schema, SQL-Abfragen |
| Persistenz | SQLite | Datenhaltung, Views, Foreign Keys |

---

## 3. Entwicklungsumgebung

### Abhängigkeiten (openSUSE Tumbleweed)

```bash
sudo zypper install cmake qt6-base-devel qt6-declarative-devel \
                   qt6-sql-devel libqt6-sqldrivers-sqlite
```

### Bauen und starten

```bash
cd stroemling
cmake -B build
cmake --build build
./build/stroemling_app
```

### Datenbankpfad

```
Linux:   ~/.local/share/Strömling Design/stroemling.db
```


Die Datei wird beim ersten Start automatisch angelegt. Schema-Migrationen werden inkrementell durchgeführt (`ALTER TABLE ADD COLUMN`) – bestehende Daten bleiben erhalten.

Idee: ich fände es gut wenn für den Entwicklungsstand die Datenbank im gleichen Pfad liegt, wie das Programm. Also im Build Ordner. 
Den Build Ordner kopiere ich mir dann per Hand nach größeren Änderungen. Dann habe ich  Dann habe ich immer mal ne neue Programmversion.
Die Datenbank kann dann auch immer neu aufgebaut werden, also wenn im Datenbankschema neue Tabellen oder Spalten hinzugkommen, alte Programm Versionen brauchen nicht berücksichtigt werden. 
Das ist ja noch eine Entwicklungsversion.
Nach der Entwicklungsphase sollte um eine Versionierung kümmern.

---

## 4. Projektstruktur

```
stroemling/
├── CMakeLists.txt                         ← Build-Konfiguration (Qt6, C++17)
├── README.md                              ← Technische Dokumentation
├── src/
│   ├── main.cpp                           ← Einstiegspunkt, DB + Models registrieren
│   ├── database/
│   │   ├── Database.h                     ← Interface: open, close, isOpen, lastError
│   │   └── Database.cpp                   ← SQLite-Verbindung + Schema v7 + inkrementelle Migrationen
│   └── models/
│       ├── ProjektModel.h / .cpp          ← Projektliste (QAbstractListModel)
│       ├── SeitenModel.h / .cpp           ← Seitenbaum (QAbstractItemModel, Baum)
│       └── BauteilModel.h / .cpp          ← Kategoriebaum + Bauteilliste
└── qml/
    ├── Main.qml                           ← Hauptfenster (Sidebar + Inhaltsbereiche)
    ├── ProjectTree.qml                    ← Projektliste mit Neu/Löschen Dialog
    ├── SeitenBaum.qml                     ← Seitenbaum mit CRUD + Verschieben
    ├── BauteilAnsicht.qml                 ← Bauteil-Datenbank (Kategorien + Liste)
    ├── SchaltplanCanvas.qml               ← Schaltplan-Zeichenfläche (Canvas, Symbole, Leitungen)
    ├── SymbolPalette.qml                  ← Symbolpalette (IEC/ANSI, Favoriten)
    ├── EigenschaftenPanel.qml             ← Eigenschaftenpanel (noch in Entwicklung)
    ├── symbole.js                         ← SVG-Pfaddaten aller Schaltzeichen
    ├── pinkatalog.js                      ← Normierte Pin-Positionen (0..1) pro Symbol
    └── components/
        └── SidebarButton.qml              ← Wiederverwendbarer Sidebar-Button
```

### CMakeLists.txt

Alle Quelldateien werden explizit gelistet. QML-Dateien sind Teil des QML-Moduls `stroemling` (URI `stroemling`, Version 1.0). Das Modul wird über `qt_add_qml_module` registriert, damit QML-Importe und der AOT-Compiler funktionieren.

```cmake
qt_add_executable(stroemling_app
    src/main.cpp
    src/database/Database.cpp  src/database/Database.h
    src/models/ProjektModel.cpp  src/models/ProjektModel.h
    src/models/SeitenModel.cpp   src/models/SeitenModel.h
    src/models/BauteilModel.cpp  src/models/BauteilModel.h
)

qt_add_qml_module(stroemling_app
    URI stroemling  VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/ProjectTree.qml
        qml/SeitenBaum.qml
        qml/BauteilAnsicht.qml
        qml/SchaltplanCanvas.qml
        qml/EigenschaftenPanel.qml
        qml/SymbolPalette.qml
        qml/symbole.js
        qml/pinkatalog.js
        qml/components/SidebarButton.qml
)
```

---

## 5. Datenbankschema

Schema-Version: **v7**  
Tabellen: **16** (+ `grafik_element` erweitert)  
Views: **2** (aktiv genutzt)  
Foreign Keys: aktiviert (`PRAGMA foreign_keys = ON`)  
WAL-Modus: aktiviert (`PRAGMA journal_mode = WAL`)  
Busy-Timeout: 5 Sekunden (`PRAGMA busy_timeout = 5000`)

### 5.0 Migrationshistorie

| Version | Änderung |
|---|---|
| v1–v4 | Initiale Schemata (Projekt, Seitenbaum, Bauteile, Symbole) |
| v5 | Symbolpalette, Norm-Feld in `projekt` |
| v6 | `grafik_element.punkte TEXT` – Polylinien-Punkte für Leitungen (JSON-Array) |
| v7 | `projekt.canvas_hintergrund TEXT` – projektweise Canvas-Hintergrundfarbe |

Eine Migrationshistorie wäre dann nach der Entwicklungsphase relevant, nicht schon jetzt.

### 5.1 Übersicht aller Tabellen

| Abschnitt | Tabelle | Beschreibung |
|---|---|---|
| Normblatt | `normblatt_vorlage` | Titelblatt-Vorlagen (projektübergreifend) |
| Normblatt | `normblatt_feld` | Einzelne Felder im Titelblatt (frei positionierbar) |
| Projekt | `projekt` | Projektdaten inkl. DIN 6771 Felder, Norm, Canvas-Hintergrundfarbe |
| Changelog | `changelog` | Änderungshistorie pro Projekt |
| Seitenbaum | `anlage` | Funktionskennzeichen `=` (z.B. Erdgeschoss) |
| Seitenbaum | `ort` | Ortskennzeichen `+` (z.B. Schaltschrank A1) |
| Seitenbaum | `seite` | Einzelne Seiten mit DIN 6771 Kennzeichnung |
| Symbole | `symbol` | Schaltzeichen als SVG |
| Symbole | `symbol_anschluss` | Anschlusspunkte eines Symbols |
| Bauteile | `bauteil_kategorie` | Hierarchische Kategorien |
| Bauteile | `bauteil` | Bauteil-Datenbank (projektübergreifend) |
| Betriebsmittel | `betriebsmittel` | Platzierte Bauteile mit BMK |
| Betriebsmittel | `betriebsmittel_platzierung` | Position auf einer Seite |
| Betriebsmittel | `betriebsmittel_anschluss` | Anschlüsse einer Platzierung |
| Verbindungen | `verbindung` | Elektrisches Potenzial (Konzept) |
| Verbindungen | `verbindung_segment` | Geometrie einer Verbindung auf einer Seite |
| Verbindungen | `querverweis` | Seitenübergang einer Verbindung |
| Kabel | `kabel` | Kabelmantel mit Typ, Länge, Verlegeweg |
| Kabel | `kabel_ader` | Einzelne Adern eines Kabels |
| Leiter | `leiter` | Einzeladern ohne Kabelmantel (Schaltschrank) |
| Klemmen | `klemmenleiste` | Klemmenleiste (z.B. X1) |
| Klemmen | `klemme` | Einzelne Klemme mit Typ und Ebene |
| Klemmen | `klemme_anschluss` | Anschlusspunkte einer Klemme (je eine Zeile) |



### 5.2 Hierarchie Seitenbaum

```
projekt
  └── anlage          (Funktionskennzeichen "=", z.B. "=EG")
        └── ort        (Ortskennzeichen "+", z.B. "+A1")
              └── seite  (Blattnummer, z.B. "001")
                    └── seite (parent_id, Unterseiten möglich)
```

Berechnetes Vollkennzeichen nach DIN 6771:

```
=EG+A1/001
 ^   ^   ^
 |   |   Blattnummer
 |   Ort (Schaltschrank A1)
 Anlage (Erdgeschoss)
```

### 5.3 BMK nach DIN EN 81346

Das Betriebsmittelkennzeichen wird aus bis zu fünf Ebenen zusammengesetzt:

```
==WERK1  ++HALLE2  =EG  +A1  -K1
  ^^        ^^      ^    ^    ^
  ||        ||      |    |    Betriebsmittel (Pflicht)
  ||        ||      |    Einbauort
  ||        ||      Funktion / Anlage
  ||        Übergeordneter Standort
  Übergeordnete Anlage
```

Die View `betriebsmittel_bmk` berechnet zwei Varianten:

- `bmk_vollstaendig` – alle Ebenen, für Dokumentation
- `bmk_kurz` – ohne `==` und `++`, für Planbeschriftung

### 5.4 Verbindung vs. Leiter vs. Kabelader

| Begriff | Was es ist | Beispiel |
|---|---|---|
| `verbindung` | Elektrisches Potenzial im Schaltplan | „L1, 230VAC" |
| `leiter` | Physischer Draht im Schrank (ohne Mantel) | „1.5mm² BK von X1:1.1 → -K1:A1" |
| `kabel_ader` | Physischer Draht als Teil eines Kabelmantels | „Ader 1, BN, in Kabel W1" |

### 5.5 Klemmenanschlüsse

Eine Klemme hat explizite Anschlusspunkte – je eine Zeile in `klemme_anschluss`:

```
Klemmenleiste X1, Klemme Nr. 1:
  klemme_anschluss (bezeichnung="1.1", seite="innen")  → verbindung "L1" → leiter "1.5sw"
  klemme_anschluss (bezeichnung="1.2", seite="aussen") → verbindung "L1" → leiter "W1/1"
```

### 5.6 Normblatt / Titelblatt

Jedes Feld im Titelblatt ist eine eigene Zeile in `normblatt_feld` mit frei konfigurierbarer Position, Größe und Datenquelle:

| `feldtyp` | Datenquelle |
|---|---|
| `fest` | Fixer Text (z.B. Firmenname) |
| `projekt` | Feld aus `projekt` (z.B. `projekt.name`) |
| `seite` | Feld aus `seite` (z.B. `seite.blattnummer`) |
| `datum` | Aktuelles Datum oder Freigabedatum |
| `changelog` | Letzte Version / Änderung aus `changelog` |
| `benutzer` | Angemeldeter Benutzer |

---

## 6. C++ Backend

### 6.1 Database

**Datei:** `src/database/Database.h / .cpp`

Die Klasse `Database` erbt von `QObject` und verwaltet die SQLite-Verbindung.

**Methoden:**

| Methode | Beschreibung |
|---|---|
| `open(path)` | Datenbankdatei öffnen / anlegen, Schema-Migration prüfen |
| `close()` | Verbindung schließen |
| `isOpen()` | Verbindungsstatus |
| `lastError()` | Letzter Fehlertext für Debugging |
| `grafikLaden(seiteId)` | Alle Grafik-Elemente einer Seite als `QVariantList` |
| `grafikSpeichern(seiteId, elemente)` | Alle Grafik-Elemente einer Seite ersetzen (Transaktion) |
| `symboleNachNorm(norm)` | Symbol-Katalog für „IEC" oder „ANSI" |
| `symbolFavoritSetzen(id, favorit)` | Favoritenstatus eines Symbols setzen |
| `projektNormLaden(id)` | Aktive Norm des Projekts lesen |
| `projektNormSpeichern(id, norm)` | Aktive Norm des Projekts schreiben |
| `projektHintergrundLaden(id)` | Canvas-Hintergrundfarbe des Projekts lesen |
| `projektHintergrundSpeichern(id, farbe)` | Canvas-Hintergrundfarbe des Projekts schreiben |

`checkAndApplySchema()` wird von `open()` intern aufgerufen. Es führt inkrementelle Migrationen durch (`ALTER TABLE ADD COLUMN`) wenn die gespeicherte Version kleiner als `SCHEMA_VERSION` ist. Bei unbekannten Versionen wird das Schema komplett neu aufgebaut. Foreign Keys, WAL-Modus und Busy-Timeout werden nach dem Öffnen per PRAGMA gesetzt.

**Wichtig – Reihenfolge der Tabellenerstellung:**  
`leiter` muss vor `klemme_anschluss` angelegt werden, da `klemme_anschluss.leiter_id` auf `leiter` verweist.

### 6.2 ProjektModel

**Datei:** `src/models/ProjektModel.h / .cpp`

Erbt von `QAbstractListModel`. Macht die Projektliste für QML verfügbar.

**Roles (QML-Feldnamen):**

| Role | QML-Name | Typ |
|---|---|---|
| `IdRole` | `projektId` | int |
| `NameRole` | `name` | QString |
| `ProjektnummerRole` | `projektnummer` | QString |
| `StatusRole` | `status` | QString |
| `ErstelltAmRole` | `erstelltAm` | QString |
| `BemerkungRole` | `bemerkung` | QString |

**Invokable Methoden:**

| Methode | Beschreibung |
|---|---|
| `laden()` | Projektliste neu aus DB laden |
| `anlegen(name, nr, bemerkung)` | Neues Projekt anlegen, gibt ID zurück |
| `loeschen(id)` | Projekt löschen |

### 6.3 SeitenModel

**Datei:** `src/models/SeitenModel.h / .cpp`

Erbt von `QAbstractItemModel`. Bildet den Seitenbaum als Baumstruktur ab: Anlage → Ort → Seite.

**Interne Datenstrukturen:**

```cpp
struct AnlageEintrag { int id, projektId; QString kuerzel, bezeichnung; int sortierung;
                       QList<OrtEintrag> orte; };
struct OrtEintrag    { int id, anlageId;  QString kuerzel, bezeichnung; int sortierung;
                       QList<SeiteEintrag> seiten; };
struct SeiteEintrag  { int id, parentId, ortId; QString blattnummer, bezeichnung, seitentyp;
                       int sortierung; };

struct BaumKnoten {
    enum Typ { Anlage = 0, Ort = 1, Seite = 2 };
    Typ typ; int index; BaumKnoten *eltern;
    AnlageEintrag *anlage; OrtEintrag *ort; SeiteEintrag *seite;
    QList<BaumKnoten *> kinder;
};
```

Der unsichtbare Wurzelknoten `m_wurzel` hält alle Anlage-Knoten. `baumAufbauen()` liest Anlage, Ort und Seite in drei verschachtelten SQL-Abfragen und baut den Baum auf. `baumLeeren()` löscht alle Knoten und leert `m_anlagen`.

**Roles (QML-Feldnamen):**

| Role | QML-Name | Beschreibung |
|---|---|---|
| `BezeichnungRole` | `bezeichnung` | Formatierter Anzeigetext (z.B. `=EG  Erdgeschoss`) |
| `KuerzelRole` | `kuerzel` | Rohes Kürzel (nur Anlage / Ort) |
| `BlattnummerRole` | `blattnummer` | Blattnummer (nur Seite) |
| `SeitentypRole` | `seitentyp` | `schaltplan`, `klemmenplan` etc. (nur Seite) |
| `KnotenTypRole` | `knotenTyp` | `0` = Anlage, `1` = Ort, `2` = Seite |
| `ItemIdRole` | `itemId` | Datenbank-ID des Eintrags |
| `RohBezeichnungRole` | `rohBezeichnung` | Bezeichnung ohne Formatierung (für Vorbelegen in Dialogen) |

**Invokable Methoden:**

| Methode | Beschreibung |
|---|---|
| `laden(projektId)` | Baum für Projekt neu laden (`beginResetModel` / `endResetModel`) |
| `anlageAnlegen(projektId, kuerzel, bezeichnung)` | Neue Anlage, gibt neue ID zurück |
| `ortAnlegen(anlageId, kuerzel, bezeichnung)` | Neuen Ort unter Anlage, gibt neue ID zurück |
| `seiteAnlegen(ortId, blattnummer, bezeichnung, seitentyp)` | Neue Seite unter Ort, gibt neue ID zurück |
| `loeschen(knotenTyp, id)` | Eintrag löschen (Typ 0/1/2 = Anlage/Ort/Seite) |
| `anlageBearbeiten(id, kuerzel, bezeichnung)` | Anlage aktualisieren |
| `ortBearbeiten(id, kuerzel, bezeichnung)` | Ort aktualisieren |
| `seiteBearbeiten(id, blattnummer, bezeichnung, seitentyp)` | Seite aktualisieren |
| `seiteVerschieben(seiteId, neuerOrtId)` | Seite einem anderen Ort zuordnen |
| `ortVerschieben(ortId, neueAnlageId)` | Ort einer anderen Anlage zuordnen |
| `anlagenListe()` | `QVariantList` aller Anlagen mit `{itemId, label}` für ComboBox |
| `orteListe(anlageId)` | `QVariantList` der Orte einer Anlage mit `{itemId, label}` für ComboBox |

**Wichtig:** Alle Mutationsmethoden rufen intern `laden(m_projektId)` auf, was `beginResetModel()` / `endResetModel()` auslöst. In QML wird per `Qt.callLater(treeView.expandRecursively)` sichergestellt, dass der Baum erst nach dem vollständigen Model-Reset wieder aufgeklappt wird.

### 6.4 BauteilModel

**Datei:** `src/models/BauteilModel.h / .cpp`

Zwei separate Modelle für die Bauteil-Datenbank.

#### BauteilKategorieModel

Erbt von `QAbstractListModel`. Stellt den Kategoriebaum als **flache Liste mit Tiefeninformation** dar – kein echtes Baummodell, da QML ListView ausreicht wenn Einrückung per `tiefe`-Rolle gesteuert wird.

**Struct:**
```cpp
struct KategorieEintrag { int id, parentId; QString name; int sortierung, tiefe; };
```

Das Feld `tiefe` wird beim Laden per DFS-Durchlauf (`traversieren()`) berechnet. Wurzelkategorien haben `tiefe = 0`, deren Kinder `tiefe = 1` usw.

**Roles:**

| Role | QML-Name | Beschreibung |
|---|---|---|
| `KategorieIdRole` | `kategorieId` | Datenbank-ID |
| `NameRole` | `name` | Bezeichnung |
| `ParentIdRole` | `parentId` | ID der übergeordneten Kategorie (-1 = Wurzel) |
| `TiefeRole` | `tiefe` | Einrücktiefe (0 = Wurzel) |
| `HatKinderRole` | `hatKinder` | `true` wenn Unterkategorien vorhanden |

**Invokable Methoden:** `laden()`, `anlegen(parentId, name)`, `bearbeiten(id, name)`, `loeschen(id)`

#### BauteilListModel

Erbt von `QAbstractListModel`. Zeigt Bauteile einer Kategorie (oder alle bei `kategorieId = -1`).

**Struct:**
```cpp
struct BauteilEintrag {
    int id, kategorieId;
    QString bezeichnung, hersteller, artikelnummer, lieferant, bemerkung;
    double preisEur, spannungV, stromA, leistungW;
};
```

**Roles:** `bauteilId`, `kategorieId`, `bezeichnung`, `hersteller`, `artikelnummer`, `lieferant`, `preisEur`, `spannungV`, `stromA`, `leistungW`, `bemerkung`

**Q_PROPERTY:** `aktiveKategorieId` – wird von QML gelesen um den aktiven Kategorieeintrag zu markieren.

**Invokable Methoden:** `laden(kategorieId)`, `anlegen(...)`, `bearbeiten(...)`, `loeschen(id)`

### 6.5 main.cpp

Einstiegspunkt der Anwendung. Registriert alle fünf Models als QML-Kontext-Properties:

```cpp
engine.rootContext()->setContextProperty("projektModel",   &projektModel);
engine.rootContext()->setContextProperty("seitenModel",    &seitenModel);
engine.rootContext()->setContextProperty("kategorieModel", &kategorieModel);
engine.rootContext()->setContextProperty("bauteilModel",   &bauteilModel);
engine.rootContext()->setContextProperty("db",             &db);
```

---

## 7. QML Frontend

### 7.1 Main.qml

Hauptfenster der Anwendung (1200×800px, dunkles Blaugrau-Farbschema).

**Layout:**

```
┌──────────────┬──────────────────────────────┐
│   Sidebar    │   Hauptbereich               │
│   (200px)    │   (flex)                     │
│              │                              │
│  ⚡ Strömling│   aktive Ansicht             │
│              │   (Projekte / Seiten /       │
│  📁 Projekte │    Bauteile / Stückliste)    │
│  📄 Seiten   │                              │
│  🔧 Bauteile │                              │
│  📋 Stückl.  │                              │
│              │                              │
│  [Aktives    │                              │
│   Projekt]   │                              │
└──────────────┴──────────────────────────────┘
```

**State-Variablen:**

| Property | Typ | Beschreibung |
|---|---|---|
| `aktivProjektId` | int | ID des gewählten Projekts (-1 = keins) |
| `aktivProjektName` | string | Name des gewählten Projekts |
| `aktiveAnsicht` | string | Aktive Ansicht: `projekte`, `seiten`, `bauteile`, `stueckliste` |
| `aktivSeiteId` | int | ID der gewählten Seite (-1 = keine) |
| `aktivSeiteName` | string | Anzeigename der Seite (Bezeichnung + Blattnummer) |
| `aktivProjektNorm` | string | Aktive Norm: `IEC` oder `ANSI` |
| `aktivProjektHintergrund` | string | Canvas-Hintergrundfarbe (CSS-Hex, z.B. `#080f1c`) |

Navigation-Buttons für Seiten und Stückliste sind deaktiviert (`opacity: 0.4`, `enabled: false`) solange kein Projekt ausgewählt ist.

Wenn ein Projekt gewählt wird, werden `projektNormLaden()`, `projektHintergrundLaden()` und `seitenModel.laden(id)` sofort aufgerufen.

### 7.2 ProjectTree.qml

Projektliste mit vollständiger CRUD-Funktionalität.

**Funktionen:**
- Alle Projekte aus `projektModel` als scrollbare Liste
- Projekt auswählen → Signal `projektGewaehlt(id, name)` nach oben
- Hover-Effekt mit Löschen-Button (×)
- Dialog zum Anlegen neuer Projekte (Name, Projektnummer)
- Leerzustand wenn keine Projekte vorhanden

**Signal:**
```qml
signal projektGewaehlt(int id, string name)
```

### 7.3 SeitenBaum.qml

Seitenbaum für das aktive Projekt. Zeigt Anlage → Ort → Seite in einem `TreeView`.

**Hauptfunktionen:**
- Automatisches Aufklappen nach jedem Model-Reset via `Qt.callLater(treeView.expandRecursively)`
- Hover-Aktionen pro Knoten: `+` (Kind anlegen), `✎` (bearbeiten), `→` (verschieben), `×` (löschen)
- Seitentyp-Badge (kleines Label rechts) bei Seiten-Knoten
- Farbkodierung nach Knotentyp: Anlage = hell (weiß), Ort = mittel (hellblau), Seite = gedämpft

**Dialoge (8 insgesamt):**

| Dialog | Felder | Zielaktion |
|---|---|---|
| `dlgAnlage` | Kürzel, Bezeichnung | `seitenModel.anlageAnlegen()` |
| `dlgOrt` | Kürzel, Bezeichnung | `seitenModel.ortAnlegen()` |
| `dlgSeite` | Blattnummer, Bezeichnung, Seitentyp (ComboBox) | `seitenModel.seiteAnlegen()` |
| `dlgAnlageBearbeiten` | Kürzel, Bezeichnung (vorbelegt via `rohBezeichnung`) | `seitenModel.anlageBearbeiten()` |
| `dlgOrtBearbeiten` | Kürzel, Bezeichnung (vorbelegt) | `seitenModel.ortBearbeiten()` |
| `dlgSeiteBearbeiten` | Blattnummer, Bezeichnung, Seitentyp (vorbelegt) | `seitenModel.seiteBearbeiten()` |
| `dlgSeiteVerschieben` | Anlage (ComboBox) → Ort (ComboBox, kaskadierend) | `seitenModel.seiteVerschieben()` |
| `dlgOrtVerschieben` | Anlage (ComboBox) | `seitenModel.ortVerschieben()` |

**Verschieben-Dialoge im Detail:**

`dlgSeiteVerschieben` öffnet mit einem kaskadierenden ComboBox-Paar:
1. Anlage-ComboBox wird mit `seitenModel.anlagenListe()` befüllt (`QVariantList` → `ListModel`)
2. Bei Änderung der Anlage-Auswahl wird die Ort-ComboBox mit `seitenModel.orteListe(anlageId)` aktualisiert
3. Speichern ruft `seitenModel.seiteVerschieben(seiteId, neuerOrtId)` auf

`dlgOrtVerschieben` öffnet mit einer einzelnen Anlage-ComboBox. Speichern ruft `seitenModel.ortVerschieben(ortId, neueAnlageId)` auf.

Beide Dialoge verwenden `ListModel` als ComboBox-Model mit `textRole: "label"`. Der Verschieben-Button `→` erscheint im Hover-Bereich nur bei Ort- und Seiten-Knoten (Anlagen sind nicht verschiebbar).

**Dialog-Pattern (einheitlich für alle Dialoge):**

Alle Dialoge verzichten auf die `footer:` Property von `Dialog`. Stattdessen sind Buttons das letzte Element im `contentItem: ColumnLayout`, getrennt durch eine `Rectangle`-Trennlinie. Dies verhindert das Überlappen der Footer-Fläche mit dem Content-Bereich in Qt Quick Controls 2.

```qml
contentItem: ColumnLayout {
    spacing: 10
    // ... Eingabefelder ...
    Rectangle { Layout.fillWidth: true; height: 1; color: "#1e3a5f" }
    RowLayout {
        Item { Layout.fillWidth: true }   // rechtsbündig ausrichten
        Button { text: "Abbrechen" ... }
        Button { text: "Speichern" ... }
    }
}
```

### 7.4 SchaltplanCanvas.qml

Schaltplan-Zeichenfläche. Verwendet Qt Quick `Canvas` (2D Context) für alle Zeichenoperationen.

**Layout (von hinten nach vorne):**

```
Rectangle (Hintergrund, hintergrundFarbe)
  Canvas gridCanvas  ← Raster + Achsen
  Canvas drawCanvas  ← Elemente + Vorschau + Verbindungsknoten
  Rectangle headerBar  ← Seitenname + Undo/Redo + Zoom
  Rectangle footerBar  ← Raster + Rastend-Toggle + Canvas-Farbpresets
  Rectangle werkzeugLeiste  ← Werkzeugbuttons (links)
```

**Öffentliche Properties:**

| Property | Typ | Beschreibung |
|---|---|---|
| `seiteId` | int | Aktive Seite (-1 = keine) |
| `seiteName` | string | Anzeigename der Seite |
| `hintergrundFarbe` | string | Canvas-Hintergrundfarbe (CSS-Hex) |
| `aktivesWerkzeug` | string | `zeiger`, `leitung`, `linie`, `rechteck`, `kreis`, `symbol` |
| `paletteSymbolId` | string | Code des aus der Palette gewählten Symbols |

**Signal:** `hintergrundGeaendert(farbe)` – wird bei Klick auf einen Farbpreset ausgelöst; `Main.qml` speichert den Wert projektweise in der DB.

**Werkzeuge:**

| Taste | Werkzeug | Beschreibung |
|---|---|---|
| `V` | Zeiger | Auswählen, Verschieben, Resize-Handles |
| `W` | Leitung | Einzelnes orthogonales Segment zeichnen | das kann entfallen, es werden nur noch autoconnectoren gesetzt, Leitungen entstehen automatisch, wenn sich Autokonnektoren gegenüberliegen
| `/` | – | H ↔ V Modus umschalten beim Leitungszeichnen | Daher sollte dieser Modus auch nicht mehr notwendig sein, aber besser nochmal prüfen.
| `L` | Linie | Freie Linie |
| `R` | Rechteck | Rechteck |
| `K` | Kreis | Kreis/Ellipse |
| `S` | Symbol | Aktives Symbol aus Palette platzieren |
| `Esc` | – | Aktuellen Vorgang abbrechen |
| `Ctrl+Z` | – | Rückgängig |
| `Ctrl+Y` | – | Wiederholen |

**Leitungswerkzeug (EPLAN-Stil):**

Zeichnet exakt ein horizontales oder vertikales Segment pro Klickpaar. `/` schaltet zwischen H-Modus (fester Y) und V-Modus (feste X) um. Pin-Snap rastet den Cursor in 18px-Radius an Symbolanschlüssen ein. Beim Verschieben eines Symbols werden Wire-Endpunkte die innerhalb von 2 Welteinheiten eines alten Pin-Punkts liegen automatisch mitgezogen. / nach prüfung auch entfallen

**Verbindungsknoten (T-Knoten):**

`drawCanvas.maleVerbindungsknoten()` zeichnet automatisch gefüllte Kreise an T-Kreuzungen (Endpunkt liegt auf einem Segment) und an Punkten wo ≥3 Leitungsendpunkte zusammentreffen. Radius skaliert mit Zoom (min 3.5 px, max 6.5 px).

**Canvas-Hintergrundfarbe:**

Drei Presets in der Fußzeile: Dunkel (`#080f1c`), Hell (`#e8edf2`), Papier (`#fdf8e8`). Das Raster passt Farbe und Kontrast automatisch an (dunkle Linien auf hellem Hintergrund, helle Linien auf dunklem).

### 7.5 BauteilAnsicht.qml

Bauteil-Datenbank mit zweigeteiltem Layout: Kategoriebaum links (240px), Bauteilliste rechts.

**Kategoriebaum (links):**
- `ListView` auf `kategorieModel`
- Einrückung per `leftMargin: 16 + model.tiefe * 14`
- Hover-Aktionen: `+` (Unterkategorie), `✎` (umbenennen), `×` (löschen)
- „Alle Bauteile" als fester Eintrag oben (lädt `bauteilModel.laden(-1)`)
- Klick auf Kategorie lädt `bauteilModel.laden(kategorieId)`

**Bauteilliste (rechts):**
- `ListView` auf `bauteilModel`
- Spalten: Bezeichnung (200px), Hersteller (140px), Artikel-Nr. (120px), Preis € (80px), U/V (60px), I/A (60px)
- Numerische Spalten haben `horizontalAlignment: Text.AlignRight` sowohl im Header als auch in den Daten
- Hover-Aktionen: `✎` (bearbeiten), `×` (löschen)
- Leerzustand-Text wenn keine Bauteile vorhanden

**Inline-Komponente `BauteilFormContent`:**

Wird sowohl in `dlgBauteilNeu` als auch `dlgBauteilBearbeiten` verwendet. Enthält:
- Bezeichnung (Pflichtfeld, `*` markiert)
- Hersteller / Artikelnummer (2-spaltig, `GridLayout`)
- Lieferant / Preis (2-spaltig)
- Spannung / Strom (2-spaltig)
- Leistung (einzeilig)
- Bemerkung als `TextArea` mit `height: 72`, `wrapMode: TextArea.Wrap` (verhindert Überlappen bei langen Texten)

Die Dialoge für Bauteil Neu/Bearbeiten nutzen `ScrollView` um das Formular bei kleinen Fenstern scrollbar zu machen.

### 7.6 SidebarButton.qml

Wiederverwendbarer Button für die Sidebar-Navigation.

**Properties:**

| Property | Typ | Default | Beschreibung |
|---|---|---|---|
| `icon` | string | `"●"` | Emoji-Icon links |
| `label` | string | `"Button"` | Beschriftung |
| `active` | bool | `false` | Aktiv-Zustand (blauer Akzentbalken links) |

**Signal:** `clicked()`

### 7.7 Farbschema

```
Hintergrund:     #0a1628   (sehr dunkles Blaugrau)
Sidebar:         #0d1b2a   (etwas heller)
Ausgewählt:      #0f2540   (mittleres Blau)
Trennlinien:     #1e3a5f   (dezentes Blau)
Akzentfarbe:     #4a9eff   (helles Blau)
Text primär:     #e8f0fe   (fast weiß)
Text sekundär:   #8899aa   (gedämpftes Blaugrau)
Text Labels:     #4a6080   (sehr gedämpft, für Spaltenköpfe)
Verschieben:     #44aa66   (grün, für → Button)
Löschen:         #aa4444   (rot, für × Button)
```

---

## 8. Normenkonformität

### DIN EN 81346 – Betriebsmittelkennzeichen

Alle fünf Kennzeichenebenen werden unterstützt:

| Präfix | Ebene | Beispiel | Feld in DB |
|---|---|---|---|
| `==` | Übergeordnete Anlage | `==WERK1` | `anlage_uebergeordnet` |
| `++` | Übergeordneter Standort | `++HALLE2` | `standort_uebergeordnet` |
| `=` | Funktion / Anlage | `=EG` | `funktion` |
| `+` | Einbauort | `+A1` | `einbauort` |
| `-` | Betriebsmittel | `-K1` | `betriebsmittel_kz` |

Die View `betriebsmittel_bmk` berechnet das vollständige Kennzeichen automatisch per SQL `COALESCE`.

### DIN 6771 – Seitenkennzeichnung

Vollkennzeichen wird aus drei Teilen zusammengesetzt:

```
= {anlage_kuerzel} + {ort_kuerzel} / {blattnummer}
```

Die View `seite_kennzeichen` berechnet das Vollkennzeichen automatisch.

Unterstützte Seitentypen: `schaltplan`, `klemmenplan`, `kabelplan`, `titelblatt`, `inhaltsverzeichnis`, `layout`.

### IEC 60617 – Schaltzeichen

Symbole werden als SVG gespeichert (`symbol.svg_data`). Die Norm-Zuordnung erfolgt über `symbol.norm`. Aktuell noch kein Symbol-Bestand enthalten – wird mit dem Canvas-Feature ergänzt.

---

## 9. Automatische Listen (Views)

Alle Listen werden automatisch aus den Projektdaten generiert. Keine manuelle Pflege nötig.

### stueckliste

```
Projekt | BMK | Bauteil | Hersteller | Art.-Nr. | Lieferant | Preis | Menge | Gesamt
```

### klemmenbelegung

```
Ort | Klemmenleiste | Klemme | Ebene | Typ | Anschluss | Seite | Potenzial | Spannung | Leiter | Farbe | mm²
```

### kabelliste

```
Kabel | Typ | Adern | mm² | Länge m | Von | Nach | Belegte Adern | Bemerkung
```

### verdrahtungsliste

```
Projekt | Leiter | Farbe | mm² | Potenzial | Spannung | Von | Nach | Typ
```

Von/Nach werden automatisch aus BMK + Anschlussbezeichnung berechnet: `-K1:A1`.

### querverweisliste

```
Leiter | Potenzial | Von Seite | Von Bezeichnung | Nach Seite | Nach Bezeichnung
```

### changelog_ansicht

```
Projekt | Projektnummer | Version | Datum | Autor | Typ | Änderung
```

---

## 10. Roadmap

### ✅ Abgeschlossen

**Schritt 1 – Projektliste**  
`ProjektModel` als `QAbstractListModel`. `ProjectTree.qml` mit Anlegen / Löschen Dialog. Aktives Projekt wird in `Main.qml` gehalten und in der Statuszeile der Sidebar angezeigt.

**Schritt 2 – Seitenbaum**  
`SeitenModel` als `QAbstractItemModel` für die Baumhierarchie Anlage → Ort → Seite. `SeitenBaum.qml` mit `TreeView` und vollständiger CRUD-Funktionalität:
- Anlegen: Anlage, Ort, Seite (mit Seitentyp-Auswahl)
- Bearbeiten: Kürzel, Bezeichnung, Seitentyp – vorbelegt aus `rohBezeichnung`-Rolle
- Verschieben: Seite → anderer Ort (kaskadierendes ComboBox-Paar); Ort → andere Anlage
- Löschen
- Automatisches Aufklappen nach Model-Reset via `Qt.callLater`

**Schritt 3 – Bauteil-Datenbank**  
`BauteilKategorieModel` (flache Liste mit DFS-Tiefe) und `BauteilListModel`. `BauteilAnsicht.qml` mit zweigeteiltem Layout, hierarchischem Kategoriebaum und Bauteiltabelle mit allen Feldern (Bezeichnung, Hersteller, Artikelnummer, Lieferant, Preis, Spannung, Strom, Leistung, Bemerkung als mehrzeiliges TextArea).

**Schritt 4 – Canvas (Schaltplan-Zeichenfläche)** ✅  
Qt Quick `Canvas` mit 2D Context. Raster (2/4/6/8/10 mm), Zoom (Ctrl+Scroll), Pan (mittlere Maustaste). Undo/Redo-Stack. Koordinatenanzeige. Header- und Fußzeile mit Werkzeugstatus. Hintergrundfarbe projektweise speicherbar (3 Presets: Dunkel / Hell / Papier).

**Schritt 5 – Symbole platzieren** ✅  
`SymbolPalette.qml` mit IEC/ANSI-Umschaltung und Favoritenstern. Symbole aus `symbole.js` und `pinkatalog.js`. Platzierung mit Rotation (90°-Schritten, R-Taste) und Spiegelung (X/Y-Taste). Pin-Punkte werden als blaue Markierungen visualisiert. Speicherung in `grafik_element` mit JSON-Serialisierung.

**Schritt 6 – Verbindungen zeichnen** ✅  
Leitungswerkzeug (W-Taste) im EPLAN-Stil: ein orthogonales Segment pro Klickpaar (H oder V, umschaltbar mit `/`). Pin-Snap rastet in 18px-Radius ein. Verbindungsknoten (T-Punkte, 3+ Endpunkte) werden automatisch gezeichnet. Segmentverschiebung per Drag. Wire-follows-Symbol beim Verschieben (2 Welteinheiten Toleranz). Speicherung in `grafik_element.punkte` als JSON-Array `[{x,y}, …]`.

---

### Nächste Schritte

**Schritt 7 – Querverweise**  
Unterbrechungspfeile bei Seitenwechsel. `querverweis`-Tabelle automatisch füllen. Klick auf Pfeil springt zur Gegenseite.

**Schritt 8 – Automatische Listen anzeigen**  
`TableView` in QML auf Views wie `stueckliste`, `klemmenbelegung`, `kabelliste`. Export als CSV oder PDF.

**Schritt 9 – Normblatt-Editor & Canvas-Seitenmodus**  
Visueller Editor für Titelblatt-Vorlagen. Felder per Drag & Drop positionieren. Logo-Import.

Beide Canvas-Modi werden unterstützt und sind pro Seite wählbar:

| Modus | Beschreibung |
|---|---|
| **Unbegrenzt** | Canvas in Weltkoordinaten ohne feste Seitengrenze. Normblattrahmen ist ein optionales, ein-/ausblendbares visuelles Element auf der Zeichenfläche. |
| **Papiergebunden** | Feste Seitengröße (A4/A3 oder benutzerdefiniert) aus `seite.breite_mm` / `seite.hoehe_mm`. Normblattrahmen füllt das Blatt automatisch aus. |

Beim PDF-Export wird je nach Modus gewählt:
- **Fit to content** – Canvas-Inhalt bestimmt die Ausgabegröße (unbegrenzter Modus)
- **Auf Blattformat zuschneiden** – A4/A3 wie im Papierformat definiert

Der Normblattrahmen selbst ist ein eigenes Canvas-Element (`NormblattItem`) das auf jeder Seite unabhängig ein- oder ausgeblendet werden kann. Felder (Projektnummer, Revision, Datum, Firmenlogo) werden aus der `normblatt_vorlage`-Tabelle geladen und zur Laufzeit befüllt.

**Spätere Erweiterungen**

- `klemme_bruecke` Tabelle für verbundene Klemmenebenen
- Validierung (Kurzschlusspfade, unverbundene Anschlüsse)
- Konfigurierbare Tastenkürzel
- Versionsverwaltung / Git-Integration

---

## 11. Designentscheidungen

### Warum SQLite und nicht XML?

QElectroTech speichert Bilder als Base64 im XML – das führt bei mehreren Bildern zu spürbaren Hängern beim Speichern. SQLite speichert Binärdaten nativ als BLOB, ist transaktionssicher und ermöglicht SQL-Abfragen die automatische Listen wie Stücklisten trivial machen. / Hier ist an anderer Stelle was falsch implementiert worden, es werden schon Bilder in der Datenbank gespeichert, aber als Base64 und nicht als Blob. Das muss man noch anpassen, in der Datenbank und ggf. im Aufrufen im QML

### Warum Qt Quick / QML statt Qt Widgets?

QML ist deklarativer, moderner und einfacher zu iterieren. Animationen und Übergänge sind mit Widgets deutlich aufwändiger. Der Einstieg mit QML ist niederschwelliger als mit dem klassischen Widgets-System.
Einmal klären ab wann QML nicht mehr ausreichen würde für die Arbeit am PC. Ich denke aktuelle komme ich super mit QML klar.

### Warum kein `footer:` in Dialogen?

Qt Quick Controls 2 berechnet die Dialog-Höhe aus `contentItem` + `header`. Ein benutzerdefinierter `footer` wird **zusätzlich** angehängt ohne die `contentItem`-Höhe zu reduzieren – bei kleinen Dialogen überlappt er die untersten Eingabefelder. Die Lösung: Keine `footer:` Property. Buttons werden als letztes Element in `contentItem: ColumnLayout` platziert, getrennt durch eine `Rectangle`-Linie.

### Warum flaches ListModel für Kategorien statt TreeModel?

`QAbstractItemModel` als Baummodell (wie für `SeitenModel`) ist für den Kategoriebaum überdimensioniert, da Kategorien nur zur Filterung dienen und keine komplexen Baumoperationen benötigen. Ein flaches `QAbstractListModel` mit DFS-berechneter `tiefe`-Rolle reicht aus – QML übernimmt die Einrückung per `leftMargin: 16 + model.tiefe * 14`.

### Warum `QVariantList` für Verschieben-Dialoge?

Die ComboBoxen in den Verschieben-Dialogen brauchen nur ID + Anzeigetext. Ein eigenes Modell dafür anzulegen wäre Overengineering. `Q_INVOKABLE QVariantList` gibt eine Liste von `QVariantMap({itemId, label})` zurück – QML befüllt daraus per `for`-Schleife ein `ListModel`. Einfach, direkt und für diesen Anwendungsfall ausreichend.

### Warum zwei Canvas-Modi (unbegrenzt + papiergebunden)?

Schaltpläne für Hausinstallation sind oft breiter als ein A4-Blatt und werden primär digital betrachtet – eine harte Papierbindung wäre hinderlich. Gleichzeitig brauchen professionelle Dokumentationen einen Normblattrahmen mit Schriftfeld für den Ausdruck. Beide Anwendungsfälle werden unterstützt: der Modus ist pro Seite wählbar, der Normblattrahmen ist ein optionales Canvas-Element, und der PDF-Export passt sich je nach Modus an.

### Warum `klemme_anschluss` als separate Tabelle?

Eine Durchgangsklemme hat 2 Anschlüsse, eine Dreietagenklemme 6. Feste Felder `anschluss_1`, `anschluss_2` wären inflexibel. Mit einer separaten Tabelle ist die Struktur für alle Klemmentypen identisch und die Verdrahtungsliste kann präzise `X1:1.1 → -K1:A1` ausgeben.

### Warum `verbindung` und `leiter` getrennt?

`verbindung` ist ein elektrisches Konzept (das Potenzial L1 fließt hier). `leiter` ist die physische Realität (dieser Draht liegt von hier nach dort). Die Trennung ermöglicht es, dass ein Potenzial durch mehrere physische Leiter fließt – was bei Abzweigungen und Kabelübergängen immer der Fall ist.

### Warum einzelne Segmente statt automatischem L-Routing?

EPLAN Electric P8 verwendet kein automatisches L-Routing: Der Nutzer zieht explizit Ecken, Kreuzungen und Abzweigungen. Das erzwingt bewusstes Leitungsführen und vermeidet unerwartete Routingpfade die beim Verschieben von Symbolen aufbrechen. Ein einzelnes Segment pro Klickpaar (H oder V) ist das kleinste sinnvolle Primitiv – komplexe Wege entstehen durch mehrfaches Zeichnen. Segmente können nachträglich verschoben werden; fehlerhafte Strecken werden einfach gelöscht und neu gezeichnet.

Achtung: im EigenschaftenPanel gibt es eine Umschaltung für horizontal und vertikal, das ist super für Grafiken und Symbole nach dem Platzieren. Diese funktion möchte ich beibehalten. Ein Leitungen zeichnen an sich gibt es ja nicht. Vielleicht verstehe ich diesen Punkt aktuell nicht, hier muss ich dann prüfen was wirklich gemeint ist.

### Warum projektweise Canvas-Hintergrundfarbe?

Schaltpläne werden in unterschiedlichen Kontexten genutzt: auf dem Monitor bei gedimmter Umgebung (Dunkel), auf hellem Display oder bei Bildschirmteilung (Hell), und bei Vorbereitung für Druck oder PDF-Export (Papier/Creme). Die Farbe ist projektgebunden weil verschiedene Projekte unterschiedliche Verwendungszwecke haben können. Drei Presets reichen für die meisten Fälle; ein freier Farbwähler wäre Overengineering.
