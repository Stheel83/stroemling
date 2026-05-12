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
Schema-Version:   static const int SCHEMA_VERSION = X;  → src/database/Database.h
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
| `konzept/01_vision_architektur.md` | Projektziele, Stack, Schichtenmodell, Abgrenzung |
| `konzept/02_datenbankschema.md` | Alle Tabellen, Views, Relationen, Schema-Strategie |
| `konzept/03_canvas_zeichenfläche.md` | Canvas-Modi, Zoom/Pan, Raster, Hintergrundfarbe |
| `konzept/04_symbolsystem.md` | Haupt-/Nebenfunktion, Erweiterungen, Pinkatalog, Rotation |
| `konzept/05_leitungen_kabel.md` | Einzelader, Kabelbaum, Verbindungslogik im Canvas |
| `konzept/06_bauteilbibliothek.md` | Bibliotheksstruktur, Varianten, Kabeldefinitionen |
| `konzept/07_normkennzeichnung.md` | BMK nach DIN EN 81346, Seitenkennzeichnung DIN 6771 |
| `konzept/08_roadmap.md` | Implementierungsstand, nächste Schritte, offene Punkte |
| `konzept/09_klemmen.md` | Klemmen: 3-Ebenen-Modell, Bauteil-Editor, Klemmenreihen-Editor, Canvas-Platzierung, Schema v8 |
| `konzept/10_ui_terminologie.md` | verbindlichen Bezeichnungen für alle Fenster, Panels und Bereiche der Anwendung |
| `konzept/11_symboleditor.md` | Symbole visuell zu erstellen und bestehende Symbole zu bearbeiten |
| `konzept/12_Kabelberechnung.md` | Entwurfsphase: Entwicklung eines Programm-Zusatzes zur Berechnung des optimalen Kabelquerschnitts |
| `konzept/13_Normen.md` | Entwurfsphase: Elektrotechnische Normen sinnvoll in das Programm integrieren |
| `konzept/14_Inbetriebnahme.md` | IBN-Modus: Betriebsmittel prüfen, Messwerte erfassen, Prüfprotokoll; DB-Schema (`inbetriebnahme`, `ibn_feldvorlage`, `ibn_feldwert`) |
| `konzept/15_makros.md` | Makros / Schaltplan-Vorlagen: Makrokasten, DB-Schema v31 (`makro`, `makro_element`), UX-Ablauf, C++-API |
| `konzept/16_eigenschaftenpanel.md` | EigenschaftenPanel: alle Abschnitte, Auslöserbedingungen, interne Hilfskomponenten, Konventionen für neue Abschnitte |

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
4. Offene Punkte und TODOs in `konzept/08_roadmap.md` eintragen oder aktualisieren
5. **`konzept/AKTUELL.md` auf aktuellen Stand bringen** – was wurde fertig, was kommt als nächstes
6. **Memory-Datei** `~/.claude/projects/.../memory/project_stroemling_stand.md` aktualisieren

Dieses Verfahren gilt auch für reine QML-Fixes, Refactorings und
UI-Konsistenz-Korrekturen – nicht nur für neue Features.

### Architektur – unveränderliche Grundsätze
- **QML hat keinen direkten Datenbankzugriff** – ausschließlich über C++-Modelle
- **Kein direkter SQL in QML** – alle DB-Operationen in C++ Backend-Klassen
- **Schichtenmodell einhalten:** QML → C++ Modelle → SQLite
- **Foreign Keys bleiben aktiviert** (`PRAGMA foreign_keys = ON`)

### Entwicklungsphase-Regeln (aktuell gültig)
- Datenbankschema wird bei jedem Start **komplett neu aufgebaut** (DROP + CREATE)
- Keine Rücksicht auf Migrationen alter Versionen nötig
- Datenbankdatei liegt im **Build-Ordner** (nicht in `~/.local/share/`)
- Migrationshistorie und Versionierung kommen erst vor dem ersten stabilen Release

### QML-Dateien: Pflichtregistrierung in CMakeLists.txt
Jede neue `.qml`-Datei – egal ob in `qml/` oder `qml/components/` – **muss sofort**
in `CMakeLists.txt` unter `QML_FILES` eingetragen werden. Fehlt der Eintrag, kann
die App zwar kompilieren, startet aber nicht (der QML-Loader findet die Komponente
zur Laufzeit nicht). Nach jedem neuen Eintrag `cmake ..` im Build-Ordner ausführen.

### Was Claude NICHT eigenständig ändern darf
- Das Datenbankschema ohne explizite Anweisung umstrukturieren
- Den Canvas-Rendering-Ansatz (Qt Quick Canvas / 2D Context) ersetzen
- Die Koordinatensystematik des Pinkatalogs (`0..1` normiert) ändern
- Neue Abhängigkeiten (Libraries) hinzufügen ohne Rückfrage

### Bekannte QML-Fallstricke in diesem Projekt

**Layout-Anker:** Innerhalb von `RowLayout`/`ColumnLayout` niemals `anchors.*` verwenden –
das erzeugt Warnungen und falsche Positionen. Stattdessen `Layout.alignment`,
`Layout.fillWidth`, `Layout.preferredWidth` etc. nutzen.

**Shortcuts in modalen Dialogs:** `ApplicationShortcut` wird von Qt Quick Controls 2
Modal-Popups blockiert und kommt nicht an. Lösung: lokaler `Shortcut {}` direkt im
Dialog + separates `property bool _debugLokal: false`. Beim Schließen auf `false` zurücksetzen
(`onClosed: root._debugLokal = false`).

**DebugLabel in Dialog:** `anchors.top/left` des DebugLabel kollidiert mit dem
`ColumnLayout`-ContentItem. Fix: `parent: root.background` statt Standard-Parent.

**`_refresh`-Counter für EP-Bindings:** Wenn QML-Bindings einen DB-Wert neu auswerten
sollen (ohne Property-Change-Signal), einen `property int _refresh: 0` anlegen und
in der Binding-Expression referenzieren – Hochzählen erzwingt Neuauswertung.

**`property var` Array In-place-Mutation:** `root.arr[i] = x` modifiziert das Array,
aber QML erkennt die Änderung nicht (kein Property-Change-Signal). Stattdessen immer
`var tmp = root.arr.slice(); tmp[i] = x; root.arr = tmp` verwenden.

**ComboBox Custom-Popup mit `delegateModel`:** `model: aderCombo.delegateModel` in
einem benutzerdefinierten Popup-ListView funktioniert nicht zuverlässig (interne Qt-API).
Stattdessen das echte Modell direkt setzen: `model: root._aderOptionen()` und den
Delegate inline im Popup definieren. Selektion per `onClicked: { aderCombo.currentIndex = index; aderCombo.popup.close() }`.

**ComboBox `onCurrentIndexChanged` + `currentIndex`-Binding = Zyklus:** Wenn eine
ComboBox ein `currentIndex`-Binding hat (reagiert auf externe Property) UND gleichzeitig
`onCurrentIndexChanged` die Property zurückschreibt, entsteht ein Zyklus: Binding setzt
Index → Handler schreibt `model[0]` zurück → Binding re-evaluiert → … Fix: `onActivated`
statt `onCurrentIndexChanged` verwenden. `onActivated` feuert **nur** bei echter
Nutzer-Interaktion, nicht bei programmatischen Index-Änderungen.

### Konzeptpflege
- Wenn eine Konzeptentscheidung sich im Gespräch ändert: **Konzeptdatei sofort
  aktualisieren**, bevor Code geändert wird
- Offene Punkte und TODOs in `konzept/08_roadmap.md` eintragen
- Bei Designentscheidungen kurz begründen warum – analog zum Stil in
  `konzept/01_vision_architektur.md` Abschnitt „Designentscheidungen"

### Abgleich Konzept ↔ Code (bei Unklarheit)
Wenn der Überblick fehlt oder Konzept und Code auseinanderdriften:
> „Lies alle Dateien in `konzept/` und vergleiche sie mit dem tatsächlichen
>  Code. Erstelle einen Abweichungsbericht: Was stimmt überein, was weicht ab,
>  was fehlt noch?"

---

## Projektstruktur
Aktuelle Struktur immer per `tree stroemling/` prüfen.
Übersicht: `konzept/01_vision_architektur.md`
