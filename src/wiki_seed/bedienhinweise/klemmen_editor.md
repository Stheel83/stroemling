# Klemmen-Typ anlegen und bearbeiten

Im Klemmen-Editor legst du die **physikalische Beschaffenheit** einer
Klemme fest – alles Projektspezifische (BMK, Position, Ausrichtung auf der
Hutschiene) gehört nicht hierher, sondern zur platzierten Klemmenreihe im
Schaltplan.

---

## Aufbau des Editors

Zwei Spalten: links die Stammdaten, rechts eine schematische Vorschau plus
die Anschlusstabelle.

**Links – Stammdaten:**
- Allgemeine Bauteilfelder: Bezeichnung, Hersteller, Artikel-Nr., Lieferant,
  Preis, Spannung, Strom, Leistung, Bemerkung, Links (Hersteller-Website /
  Datenblatt)
- Anschlusstyp (Schraube, Feder, Push-In, Schneidklemme)
- Ebenen (1–10) sowie Anschlusspunkte Seite A und Seite B (je 0–10, aber
  nie beide gleichzeitig 0)
- PE-Fußkontakt (Häkchen) – erzeugt automatisch einen zusätzlichen
  `PE`-Anschluss, verbunden mit der untersten Ebene
- Stegbrücken-fähig (Häkchen)
- Breite (mm), Gehäusefarbe, Normbezeichnung, Bemerkung
- Querschnitte je Adertyp und interne Brückungen zwischen Ebenen
- Ein einziger **„Speichern"**-Button ganz unten sichert alles zusammen

**Rechts – Vorschau:** schematische Draufsicht (keine maßstäbliche
Zeichnung). Ebene 1 unten, weitere Ebenen wachsen nach oben; Seite A links,
Seite B rechts. Brücken zwischen Ebenen erscheinen als grüne senkrechte
Linie, ein Steg-Kontakt als gefüllter Punkt, der PE-Fußkontakt als grünes
Erdungssymbol unterhalb von Ebene 1. Darunter eine Tabelle mit jedem
Anschluss (Bezeichnung, Seite, Ebene) – aktualisiert sich live beim Ändern
der Werte links.

---

## Seite A und Seite B

Beschreiben die beiden Anschlussseiten rein physikalisch, unabhängig von
Einbaurichtung oder Schaltplan-Darstellung – typisch Seite A für
Einspeisung/Schrankinnen, Seite B für Abgang/Verbraucher außen. Die Anzahl
Anschlüsse je Seite kann unterschiedlich sein (z. B. 2× A, 1× B).

---

## Klemme im Schaltplan platzieren

Die hier definierte Klemme wird im Schaltplan nicht direkt platziert –
dafür legst du im Projekt eine **Klemmenreihe** an (Sidebar → Klemmenreihen)
und setzt darin diesen Klemmentyp ein. Von dort aus geht es weiter zur
verknüpften oder freien Canvas-Platzierung der einzelnen Anschlüsse.
