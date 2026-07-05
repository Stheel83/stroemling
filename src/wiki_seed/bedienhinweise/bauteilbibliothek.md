# Bauteilbibliothek – Kategorien und Verwaltung

Die Bauteile-Ansicht verwaltet alle wiederverwendbaren Bauteiltypen
(Klemmen, Kabel, Steckverbinder, konfektionierte Kabel, Kontakte) sowie
die projektbezogenen Klemmenreihen und Gerätekästen – alles über eine
gemeinsame Sidebar links.

---

## Sidebar-Kategorien

**BIBLIOTHEK** (projektübergreifend, liegt in `bibliothek.db`):

| Kategorie | Inhalt |
|---|---|
| Bauteile | Alle Einträge ungefiltert |
| Klemmen | Klemmentypen – eigener Vollbild-Editor, → „Klemmen-Typ anlegen und bearbeiten" |
| Kabel | Kabeltypen – eigener Vollbild-Editor, → „Kabel-Typ anlegen und bearbeiten" |
| Steckverbinder / Konf. Kabel / Kontakte | → „Steckverbinder und konfektionierte Kabel anlegen" |
| Makros | Schaltplan-Vorlagen (eigenes Konzept, Makrokasten) |
| Geräte | reserviert, noch nicht implementiert |

Darunter **eigene Kategorien**: „+ Neu" legt eine frei benennbare Unter-
kategorie an (z. B. „Sicherungsautomaten", „Relais") – rein organisatorisch,
ohne Einfluss auf den Bauteiltyp.

**PROJEKT** (nur im aktuell offenen Projekt):

| Kategorie | Inhalt |
|---|---|
| Klemmenreihen | Verwaltung platzierter Klemmenleisten – Zusammensetzung, Stegbrücken, Reihenfolge |
| Gerätekästen | → „Gerätekasten und Geräte mit Kontaktspiegel" |

---

## Bauteil anlegen

`[+]`-Button in der jeweiligen Kategorie legt sofort einen neuen Eintrag mit
Standardwerten an und öffnet – bei Klemme/Kabel/Steckverbinder/Konf. Kabel/
Kontakt – direkt den passenden Vollbild-Editor. Kein Vor-Dialog, du benennst
den Eintrag im Editor selbst.

## Bauteil duplizieren

Der ❐-Button (beim Überfahren einer Zeile sichtbar) kopiert den kompletten
Eintrag inkl. aller Detail-Tabellen (bei Klemmen z. B. Querschnitte und
Brückenebenen, bei Kabeln alle Adern) unter dem Namen „… (Kopie)". Bei
Klemme und Kabel öffnet sich anschließend direkt der Editor.

## Aus CSV importieren

Beim Überfahren der Zeile „Bauteile" erscheint ein ⇩-Button, der einen
Import-Dialog öffnet: CSV-Datei wählen → Spalten den Bauteilfeldern zuordnen
(Bezeichnung, Hersteller, Artikelnummer, Preis, Spannung, Strom, Leistung,
Bemerkung …) → Zielkategorie wählen → importieren. Nur für einfache Bauteile
ohne Detail-Tabellen gedacht (keine Klemmen-/Kabel-Adern über CSV).
