# Normblatt-Vorlagen selbst gestalten

Neben den drei mitgelieferten Schriftfeldvorlagen (`din6771`, `kompakt`,
`rahmen`) kannst du eigene Titelblattvorlagen visuell zusammenstellen –
Felder frei positionieren, Größe anpassen, mit einer Datenquelle
verknüpfen.

---

## Einstieg

Im „Seite bearbeiten"-Dialog (Seitenbaum) bei der Vorlage-Auswahl
„Benutzerdefiniert" wählen → Button „Vorlage bearbeiten …" öffnet den
Vollbild-Editor.

## Layout des Editors

Drei Spalten:

| Spalte | Inhalt |
|---|---|
| Palette (links) | Feldtypen zum Anklicken: Fest, Projekt, Seite, Datum, Vollkennzeichen, Format, Logo |
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
