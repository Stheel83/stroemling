# Listen-Ansicht – Stückliste, Aderliste & Co.

Die Listen-Ansicht fasst alle tabellarischen Auswertungen des Projekts in
elf Tabs zusammen – von der Stückliste bis zur Pinbelegung.

---

## Die elf Tabs

| Tab | Inhalt |
|---|---|
| Stückliste | Alle Symbole und Gerätekästen mit BMK, Freitextfeldern, Struktur |
| Bestellliste | Bauteile nach Artikel zusammengefasst mit Menge, Einzelpreis und Summe |
| Kabelliste | Kabel aufklappbar zu Ader-Unterzeilen (Farbe, Netz, Von-/Nach-Gerät:Pin) |
| Aderliste | Alle Aderdefinitions-Symbole mit Farbe, Querschnitt, Länge |
| Adersummenliste | Adern nach Aderfarbe und Querschnitt gruppiert, Längen aufsummiert |
| Klemmenplan | Alle Klemmen mit Anschlusszuordnung |
| Klemmlistenauszug | Kompakter Auszug je Klemmenreihe |
| Steckverbinder | Alle Steckverbinder-Gehäuse mit Polzahl, IP, Kodierung |
| Belegungsplan | Pin-für-Pin-Belegung je Steckverbinder-Gehäuse |
| Pinbelegung | Pins von Mikrokontroller-Boards (z. B. Arduino) mit dem angeschlossenen Bauteil |
| Querverweise | Alle Querverweis-Paare mit Sprungziel zur Gegenstelle |

Jeder Tab zeigt die Zeilenanzahl im Tab-Titel. Spaltenbreiten lassen sich
per Ziehen an der Trennlinie anpassen – die Breiten merkt sich die App.

---

## Filtern und sortieren

In den flachen Listen gibt es oben ein Feld **„Filtern…"**, das alle
Textspalten durchsucht. Ein Klick auf einen **Spaltenkopf** sortiert nach
dieser Spalte, ein weiterer Klick dreht die Richtung um.

Ausnahmen, bei denen die Gruppierung nicht zerrissen werden soll:
**Klemmenplan**, **Klemmlistenauszug** (gruppiert nach Klemmenleiste) und
**Belegungsplan** (gruppiert nach Gehäuse) haben weder Filter noch
Sortierung, die **Kabelliste** nur den Filter, und die **Adersummenliste**
sortiert nicht, solange „je Anlage/Ort aufschlüsseln" eingeschaltet ist.

Einige Listen haben eine Fußzeile mit der Summe: **Gesamtsumme in EUR**
(Bestellliste) bzw. **Gesamtlänge in m** (Kabelliste, Adersummenliste).

## Besonderheiten einzelner Tabs

- **Adersummenliste:** Der Schalter **„je Anlage/Ort aufschlüsseln"**
  gruppiert zusätzlich nach Anlage und Ort.
- **Pinbelegung:** **„Freie Pins ausblenden"** zeigt nur belegte Pins.
  **„#define-Code …"** erzeugt aus den Verbindungen Pin-Definitionen für den
  Sketch und kopiert sie in die Zwischenablage.

---

## Zur passenden Canvas-Stelle springen

Nahezu jede Zeile hat einen `→`-Button: Klick wechselt zur richtigen Seite
und zentriert die Ansicht auf das Element. Bei der Kabelliste sitzt der
Button an der einzelnen **Ader-Zeile** (nicht am Kabel selbst), da ein
Kabel über mehrere Kabellinien verteilt sein kann, aber jede Ader immer
genau einer Kabellinie zugeordnet ist – so ist das Sprungziel immer
eindeutig.

## Als PDF oder CSV exportieren

Jeder Tab hat oben rechts die Buttons **PDF exportieren** und **CSV
exportieren**.

- **PDF** gibt die Liste so aus, wie sie am Bildschirm steht – **mit
  aktivem Filter und aktueller Sortierung**. Das PDF ist A4 quer mit
  Titel, Projektname, wiederholter Kopfzeile und „Seite x von y".
- **CSV** schreibt die vollständigen Daten des Tabs (bei der Kabelliste:
  eine Zeile pro Ader, flach statt aufklappbar); Filter und Sortierung
  gelten dafür nicht.

Mehrere Listen zusammen mit Schaltplan, Deckblatt und Inhaltsverzeichnis in
**einem** PDF ausgeben: Sidebar → **🖨 PDF-Export** (siehe Artikel
„PDF-Export"). Dort erscheinen die Listen vollständig und ungefiltert.

## Verbindungen nummerieren

Der „N"-Button in der Titelleiste (unabhängig vom aktiven Tab) öffnet einen
Popup: Präfix, Startwert und Schrittweite festlegen, dann bekommen alle
noch unbeschrifteten Leitungen im Projekt automatisch fortlaufende Nummern
– praktisch, um ein Potenzialschema schnell durchzunummerieren, statt jede
Leitung einzeln zu benennen.
