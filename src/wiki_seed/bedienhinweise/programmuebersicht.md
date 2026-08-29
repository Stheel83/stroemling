# Programmübersicht

Strömling Design ist in mehrere Arbeitsbereiche aufgeteilt, zwischen denen
du über die **Seitenleiste links** wechselst. Einen eigenen „Schaltplan"-
Eintrag gibt es dabei nicht – der Einstieg ins Zeichnen läuft über
**Seiten** (den Seitenbaum mit den Projektseiten).

## Bevor du zeichnest: Bauteil-Grundstock anlegen

Strömling arbeitet hardwarenah – ein Symbol im Schaltplan verweist meist auf
ein echtes Bauteil aus dem Bereich **🔧 Bauteile**, nicht umgekehrt. Manches
lässt sich im Canvas erst verknüpfen, wenn das passende Bauteil vorher dort
angelegt wurde:

- Eine **Klemme** muss zuerst in einer **Klemmenleiste** stecken, bevor du
  sie als „Verknüpft" platzieren kannst.
- Ein **Kabel-Typ** (mit seinen Adern) sollte angelegt sein, sonst
  funktioniert die automatische Ader-Einfärbung an Kreuzungen nicht.
- Ein **Steckverbinder-Typ** braucht zuerst passende **Kontakt-Typen**,
  bevor du ihn mit einem Gerätekasten verknüpfen und Kontakte platzieren
  kannst.
- Für **SPS/PLS** gilt dieselbe Reihenfolge: erst Rack, dann Baugruppe,
  dann Kanal – erst danach lässt sich der Kanal einem Symbol zuweisen.

Ein neues Projekt startet nicht bei null – ein kleiner Grundstock an
Standardklemmen, Kabeltypen und Grundgeräten ist bereits vorhanden. Reicht
das nicht, leg im Bereich „Bauteile" gezielt nach, **bevor** du im
Schaltplan danach suchst.

## Arbeitsbereiche

| Symbol | Bereich | Funktion |
|--------|---------|----------|
| 📁 | Projekte | Projekt anlegen, öffnen, Versionshistorie |
| 📄 | Seiten | Seitenbaum: Seiten, Anlagen und Orte – Einstieg zur Zeichenfläche |
| 📋 | Listen | Stückliste, Kabel-, Klemmen- und weitere Listen |
| 🖥 | SPS/PLS | SPS/PLS-Konfiguration: Hardware, Baugruppen, I/O-Kanäle |
| 🔧 | Bauteile | Bauteilkatalog: Klemmen, Kabel, Steckverbinder, Geräte |
| ✔ | IBN | Inbetriebnahme: Betriebsmittel prüfen, Messwerte erfassen |
| 🔍 | Fehlersuche | Strompfad durch den Schaltplan nachverfolgen |
| ⚡ | Kabelrechner | Leitungsquerschnitt nach VDE/IEC berechnen |
| 🖨 | PDF-Export | Alle Seiten des Projekts als PDF exportieren |
| 📐 | Normblatt | Schriftfeld nach DIN 6771 gestalten und Vorlage wählen |
| ✏ | Symbole | Eigene Schaltsymbole erstellen und bearbeiten |
| 📚 | Wiki | Erfahrungs-Wiki: Fachwissen nachschlagen und eigene Artikel |
| 🏆 | Errungenschaften | Freigeschaltete Achievements |
| 🔔 | Meldungen | Zuletzt angezeigte Meldungen dieser Session |
| ⚙ | Einstellungen | Theme, Darstellung und App-Einstellungen |

## Grundprinzip

- **Links:** Seitenleiste (Arbeitsbereiche) sowie – im Bereich „Seiten" –
  zusätzlich der Seitenbaum
- **Mitte:** Arbeitsbereich / Zeichenfläche
- **Rechts:** Eigenschaftenpanel – zeigt die Eigenschaften des gewählten Elements
