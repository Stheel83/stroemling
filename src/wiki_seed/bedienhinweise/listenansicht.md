# Listen-Ansicht – Stückliste, Aderliste & Co.

Die Listen-Ansicht fasst alle tabellarischen Auswertungen des Projekts in
acht Tabs zusammen – von der Stückliste bis zum Belegungsplan.

---

## Die acht Tabs

| Tab | Inhalt |
|---|---|
| Stückliste | Alle Symbole und Gerätekästen mit BMK, Freitextfeldern, Struktur |
| Querverweise | Alle Querverweis-Paare mit Sprungziel zur Gegenstelle |
| Aderliste | Alle Aderdefinitions-Symbole mit Farbe, Querschnitt, Länge |
| Klemmenplan | Alle Klemmen mit Anschlusszuordnung |
| Klemmlistenauszug | Kompakter Auszug je Klemmenreihe |
| Kabelliste | Kabel aufklappbar zu Ader-Unterzeilen (Farbe, Netz, Von-/Nach-Gerät:Pin) |
| Steckverbinder | Alle Steckverbinder-Gehäuse mit Polzahl, IP, Kodierung |
| Belegungsplan | Pin-für-Pin-Belegung je Steckverbinder-Gehäuse |

Jeder Tab zeigt die Zeilenanzahl im Tab-Titel. Spaltenbreiten lassen sich
per Ziehen an der Trennlinie anpassen – die Breiten merkt sich die App.

---

## Zur passenden Canvas-Stelle springen

Nahezu jede Zeile hat einen `→`-Button: Klick wechselt zur richtigen Seite
und zentriert die Ansicht auf das Element. Bei der Kabelliste sitzt der
Button an der einzelnen **Ader-Zeile** (nicht am Kabel selbst), da ein
Kabel über mehrere Kabellinien verteilt sein kann, aber jede Ader immer
genau einer Kabellinie zugeordnet ist – so ist das Sprungziel immer
eindeutig.

## Als CSV exportieren

Jeder Tab hat oben rechts einen CSV-Export-Button – schreibt genau die
aktuell angezeigten Daten dieses Tabs in eine Datei (bei der Kabelliste:
eine Zeile pro Ader, flach statt aufklappbar).

## Verbindungen nummerieren

Der „N"-Button in der Titelleiste (unabhängig vom aktiven Tab) öffnet einen
Popup: Präfix, Startwert und Schrittweite festlegen, dann bekommen alle
noch unbeschrifteten Leitungen im Projekt automatisch fortlaufende Nummern
– praktisch, um ein Potenzialschema schnell durchzunummerieren, statt jede
Leitung einzeln zu benennen.
