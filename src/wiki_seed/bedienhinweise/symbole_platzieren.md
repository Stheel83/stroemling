# Symbole platzieren und bearbeiten

## Symbol aus der Bibliothek platzieren

1. Im **Schaltplan-Werkzeugbereich** das Symbol-Werkzeug wählen.
2. Aus der Symbol-Palette das gewünschte Symbol anklicken.
3. Auf die Zeichenfläche klicken → Symbol wird platziert.
4. Im **Eigenschaftenpanel** kannst du Betriebsmittelkennzeichen (BMK),
   Beschriftung und weitere Eigenschaften setzen.

## Symbol drehen

- Platziertes Symbol anklicken → im Eigenschaftenpanel die **Rotation** ändern
  (0°, 90°, 180°, 270°).

## Eigene Symbole erstellen

1. Seitenleiste → **Symbole** (✏), dann **+ Neu**.
2. Name, Kategorie und Größe (Breite/Höhe in mm) festlegen. Pin-Abstände
   sollten Vielfache von 4mm sein (das größer hervorgehobene Raster zeigt
   das an), sonst rasten Leitungen später nicht sauber ein.
   Ändern Sie Breite oder Höhe nachträglich, bleibt der vorhandene Inhalt
   in seinen mm-Maßen unverändert: das Symbol wächst nach rechts bzw. nach
   unten (und schrumpft von dort), es wird nichts verzerrt. Pins am unteren
   oder rechten Rand bleiben dabei an ihrer alten Position und müssen bei
   Bedarf selbst an die neue Kante verschoben werden.
3. Mit den Zeichenwerkzeugen (Linie, Rechteck, Kreis, Bogen, Punkt, Text)
   die Geometrie zeichnen. Strichart und „Gefüllt"-Schalter in der
   Werkzeugleiste wirken auf das **nächste neu gezeichnete** Objekt, nicht
   rückwirkend – ein bereits vorhandenes Element änderst du über das
   Eigenschaften-Panel rechts (dort ausgewähltes Objekt anklicken).
4. **Pins** setzen: Pin-Werkzeug wählen, auf die gewünschte Position
   klicken. Für jeden Pin lassen sich Name, Signaltyp, Richtung (welche
   Seite „offen" ist, also wohin die Leitung zeigt) sowie Rolle und
   Knoten-Gruppe festlegen – die beiden letzten erklären die nächsten zwei
   Abschnitte.
5. **Speichern** – das Symbol steht sofort in der Palette unter „Eigene
   Symbole" zur Verfügung, der Editor bleibt offen für weitere
   Anpassungen.

---

## Rolle – wie sich ein Symbol im Netz verhält

Bestimmt, wie sich eine Ader-/Leitungsfarbe beim automatischen Verbinden
durch das Symbol hindurch ausbreitet:

- **Durchleiter** (Standard) – lässt die Farbe unverändert durch, wie ein
  Draht. Für Schalter, Kontakte, Klemmen.
- **Verbraucher** – nimmt eine Farbe entgegen, gibt aber keine eigene
  weiter (Endpunkt). Für Lampen, Motoren, Widerstände & Co.
- **Quelle** – speist selbst eine Farbe ins Netz ein, z.B. ein
  Netzteil-Ausgang oder ein SPS-Ausgangskanal.
- **Trenner** – blockiert die Ausbreitung komplett, z.B. eine bewusste
  Leitungsunterbrechung.
- **Variabel** – die tatsächliche Rolle wird erst beim Platzieren im
  Schaltplan festgelegt (z.B. ein Sensor, der je nach Einsatz Quelle oder
  Ziel ist).

Bei Symbolen mit gemischten Anschlüssen (z.B. ein Netzteil mit
Eingangs-**und** Ausgangspins) lässt sich die Rolle zusätzlich **pro Pin**
überschreiben – Spalte „Rolle" in der Pin-Liste.

## Knoten-Gruppe – welche Pins intern verbunden sind

Legt fest, ob zwei Pins **desselben** Symbols in der Netzberechnung als ein
einziger elektrischer Punkt gelten oder als zwei getrennte:

- **Gleiche Zahl** (Standard: alle Pins auf 0) = intern verbunden, wie bei
  einem geschlossenen Schalter oder einer Klemme.
- **Unterschiedliche Zahl** = getrennte Anschlüsse. Notwendig bei jedem
  echten Verbraucher (Lampe, Motor, Widerstand, Spule, Relais …) – sonst
  würden beide Anschlusspunkte fälschlich als kurzgeschlossen behandelt.

Faustregel: hat ein Symbol die **Rolle „Verbraucher"**, sollten alle Pins
unterschiedliche Knoten-Gruppen bekommen. Der Editor schlägt das für neu
angelegte Pins automatisch vor (nächste freie Zahl statt 0), du kannst den
Wert danach jederzeit von Hand anpassen.

---

## Weitere Einstellungen im Überblick

- **BMK-Seite** – wo das Betriebsmittelkennzeichen bei 0°/180° gezeichnet
  wird (oben oder seitlich, bzw. umgekehrt für Symbole, die schon bei 0°
  vertikal ausgerichtet sind, wie eine Spule).
- **Kennbuchstaben** – ein oder mehrere DIN-EN-81346-Kennbuchstaben
  (z.B. „K" für ein Schütz), einer davon als Standard markierbar – wird
  beim Platzieren automatisch als BMK-Vorschlag verwendet.
- **Pin-Schrift** – Schriftgröße der Pin-Beschriftungen; bei eng stehenden
  Pins (Arduino-Boards, SPS-Baugruppen) kleiner wählen.
- **Primitiv-Rotation** – einzelne Rechtecke und Texte lassen sich beliebig
  drehen (Zahlenfeld oder 0°/45°/90°/135°-Schnellauswahl im
  Eigenschaften-Panel), unabhängig von der 90°-Rotation des gesamten
  platzierten Symbols.
- **„Lesbar halten"** (nur bei Text) – der Textinhalt bleibt beim Drehen
  oder Spiegeln des platzierten Symbols immer aufrecht lesbar, statt auf
  dem Kopf zu stehen.
- **Vorschau-Drehung** (oben links über der Zeichenfläche) – rein visuelle
  Kontrolle, ob die Geometrie bei allen vier Rotationen und Spiegelungen
  noch in die Symbolbox passt. Ändert nichts an den gespeicherten Daten.

## Bestehendes Symbol als Vorlage nutzen

In der Symbolliste über das ❐-Icon „Als Vorlage kopieren" – öffnet eine
neue Kopie mit vollständiger Geometrie und allen Pins, das Original bleibt
unverändert. Eingebaute Symbole lassen sich nur auf diesem Weg anpassen,
nie direkt überschreiben.

## Zeichenfläche: Zoom, Pan, Undo

- **Zoom:** Mausrad/Touchpad (zoomt auf die Cursor-Position) oder die
  `+`/`−`-Buttons oben rechts; Klick auf die Prozentzahl setzt zurück.
- **Pan:** mittlere Maustaste ziehen.
- **Strg+Z:** macht die letzte Aktion rückgängig.
