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
