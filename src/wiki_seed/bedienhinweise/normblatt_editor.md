# Normblatt-Vorlagen selbst gestalten

Unter **Blattvorlagen** in der Seitenleiste gestaltest du eigene **Schriftfelder** (Titelblatt einer
Zeichnungsseite) und **Deckblätter** (für das Dokumentations-PDF) visuell – Felder frei positionieren,
Größe anpassen, mit einer Datenquelle verknüpfen. Neben den drei mitgelieferten Schriftfeldvorlagen
(`din6771`, `kompakt`, `rahmen`) sind eigene Vorlagen frei gestaltbar.

---

## Einstieg

Seitenleiste → **Blattvorlagen** öffnet den Vollbild-Editor. Eine Schriftfeld-Vorlage weist du einer Seite im
„Seite bearbeiten“-Dialog (Seitenbaum) unter „Schriftfeld-Vorlage“ → „Benutzerdefiniert“ zu; ein Deckblatt wählst
du im PDF-Export beim Abschnitt Deckblatt.

## Layout des Editors

Drei Spalten:

| Spalte | Inhalt |
|---|---|
| Palette (links) | Feldtypen zum Anklicken: Fest, Projekt, Seite, Datum, Vollkennzeichen, Format, Logo, Kunden-Logo, Textblock, Linie |
| Vorschau (Mitte) | Skalierte Darstellung der Seite mit allen bereits platzierten Feldern |
| Eigenschaften (rechts) | Feldtyp, Label, Quelle, Breite/Höhe, X/Y – für das gerade ausgewählte Feld |

## Bedienung

| Aktion | Effekt |
|---|---|
| Feldtyp aus der Palette anklicken | Neues Feld erscheint in der Mitte der Vorschau |
| Feld in der Vorschau ziehen | Neu positionieren (Snap-Raster 1 mm) |
| Feld anklicken | Auswahl – Eigenschaften erscheinen rechts |
| Eckgriff ziehen | Größe ändern (Snap-Raster 1 mm) |
| Entf | Ausgewähltes Feld löschen |
| Speichern | Alle Felder werden übernommen |
| Abbrechen | Änderungen verwerfen, Dialog schließen |

## Feldtypen und Datenquellen

| Feldtyp | Datenquelle |
|---|---|
| Fest | Frei eingetippter Text |
| Projekt | Projektfelder wie Name, Projektnummer, Auftraggeber, Bearbeiter, Norm |
| Seite | Blattnummer, Bezeichnung, Anlagen-/Ortkürzel der aktuellen Seite |
| Datum | Erstellungsdatum des Projekts (TT.MM.JJJJ) |
| Vollkennzeichen | berechnet: `=Anlage+Ort/Blatt` |
| Format | berechnet: Papierformat, z. B. „A4 QF" |
| Logo | Projekt-Logo als Bild |

## Vorlagen verwalten

Über die Kopfzeile: „+ Neu" legt eine leere, sofort bearbeitbare Vorlage
an. „Löschen" entfernt eine Vorlage nur, solange keine Seite sie verwendet
– sonst erscheint ein Hinweis.

Eine so erstellte Vorlage wählst du danach in jeder Seite über
„Benutzerdefiniert" plus Vorlagenname aus.

---

## Schrift, Platzhalter und Deckblatt

- **Schriftgröße und Fett:** Im Eigenschaften-Panel stellst du die Schriftgröße (in mm) und „Fett“ je Feld ein. Das gilt
  für die Anzeige im Schaltplan und im PDF. Lange Texte werden an Wortgrenzen umgebrochen.
- **Platzhalter in festen Texten:** `{projekt.name}`, `{projekt.projektnummer}`, `{projekt.auftraggeber}`,
  `{projekt.auftragnehmer}`, `{projekt.bearbeiter}`, `{projekt.norm}`, `{projekt.werk}`, `{projekt.abteilung}`,
  `{datum}` (Projekt angelegt), `{heute}` (Ausgabedatum) und `{titelzusatz}` (Eingabe beim PDF-Export).
- **Deckblatt:** Das Deckblatt des Dokumentations-PDFs ist eine Blattvorlage der Art „Deckblatt“ (A4 hoch).
  Mitgeliefert ist „Standard-Deckblatt“; per „Kopieren“ legst du eine eigene Variante an und wählst sie im
  PDF-Export beim Abschnitt Deckblatt unter „Vorlage“.

---

## Neue Feldtypen und Logos

| Feldtyp | Zweck |
|---|---|
| **Kunden-Logo** | Zeigt das Kunden-Logo des Projekts (Projektseite → Projektdaten → „Kunden-Logo“). Ohne Logo bleibt die Fläche leer. |
| **Textblock** | Mehrzeiliger fester Text mit Platzhaltern; Zeilenumbrüche bleiben erhalten. |
| **Linie** | Trennlinie entlang der längeren Seite des Feldes; „Fett“ macht sie dicker. Für eine senkrechte Linie das Feld schmal und hoch ziehen. |

- **Logo der Vorlage:** Oben in der Kopfzeile „Logo …“ wählt ein eigenes Logo für die Vorlage (Feldtyp „Logo“) –
  gedacht für dein Firmenlogo, das in jedem Projekt gleich bleibt. Das Kunden-Logo des Projekts gehört dagegen zum Feldtyp „Kunden-Logo“.
- **Neue Deckblatt-Vorlage:** Beim Anlegen (＋) die Art „Deckblatt (A4 hoch)“ wählen. Sie erscheint im PDF-Export beim
  Abschnitt Deckblatt unter „Vorlage“ und nicht in der Schriftfeld-Auswahl einer Seite.

---

## Vorlagenbibliothek

Mit **Bibliothek …** in der Kopfzeile öffnest du die Vorlagenbibliothek. Sie gilt für alle Projekte auf diesem Rechner –
so gestaltest du dein Firmen-Deckblatt oder dein Schriftfeld einmal und nutzt es in jedem Projekt.

- **In Bibliothek speichern:** legt die gewählte Vorlage (mit Feldern und Logo) in der Bibliothek ab. Ist sie schon verknüpft,
  wird die Bibliotheksvorlage aktualisiert.
- **Übernehmen:** kopiert eine Bibliotheksvorlage in das aktuelle Projekt. Das Projekt behält diese Kopie – es ist also auch
  ohne Bibliothek vollständig.
- **Abgleich:** Eine übernommene Vorlage merkt sich ihren Stand. Das Fenster zeigt, ob die Bibliothek eine neuere Version hat
  oder du lokal etwas geändert hast. Aktualisieren ist immer eine ausdrückliche Aktion; sind beide Seiten geändert, fragt das
  Programm nach, bevor lokale Änderungen überschrieben werden. Der Name der Vorlage bleibt dabei lokal.
- **Löschen** entfernt nur den Bibliothekseintrag; Kopien in Projekten bleiben bestehen.
