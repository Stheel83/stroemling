# AWG – Umrechnung American Wire Gauge zu mm²

**AWG** (American Wire Gauge) ist das in den USA übliche Maßsystem für
Drahtdurchmesser — vor allem in Elektronik-Datenblättern, US-Steckverbindern
und Mikrocontroller-Zubehör (z. B. Arduino, USB, JST-Stecker) anzutreffen.
Im deutschsprachigen Raum wird stattdessen der Leiterquerschnitt in **mm²**
angegeben. Wer Fremd-Datenblätter liest oder Fremdbauteile einplant, muss
zwischen beiden Systemen umrechnen.

---

## Funktionsprinzip

AWG zählt **umgekehrt** zum Querschnitt: je größer die AWG-Zahl, desto
**dünner** der Draht. Die Skala ist logarithmisch – von AWG 36 (0 AWG) bis
AWG 0000 (4/0) verdreifacht sich der Querschnitt etwa alle 3 Stufen.

**Durchmesser-Formel:**

```
d(AWG) = 0,127 mm × 92^((36 − AWG) / 39)
```

**Querschnitt:**

```
A(AWG) = π/4 × d(AWG)²
```

Für Querschnitte größer als 0 AWG wird die Zählung negativ fortgesetzt:
`00 AWG = −1`, `000 AWG = −2`, `0000 AWG = −3` in obiger Formel.

---

## Umrechnungstabelle (gängige Größen)

| AWG   | Durchmesser (mm) | Fläche exakt (mm²) | Nächster Normquerschnitt (aufgerundet) | Typische Anwendung |
|:-----:|:-----------------:|:-------------------:|:----------------------------------------:|---------------------|
| 36    | 0,127              | 0,0127               | 0,014 mm²                                | Wickeldraht, SMD-Litze |
| 34    | 0,160              | 0,0206               | 0,025 mm²                                | Feinstlitze |
| 32    | 0,202              | 0,0324               | 0,034 mm²                                | Sensorleitung |
| 30    | 0,255              | 0,0507               | 0,05 mm²                                 | Wire-Wrap, Jumper |
| 28    | 0,321              | 0,0804               | 0,1 mm²                                  | Steckbrücken, JST-PH |
| 26    | 0,405              | 0,128                | 0,14 mm²                                 | Arduino-Jumperkabel |
| 24    | 0,511              | 0,205                | 0,25 mm²                                 | USB-Datenleitung, Sensorkabel |
| 22    | 0,644              | 0,326                | 0,34 mm²                                 | Servo-/Steuerleitung |
| 20    | 0,812              | 0,518                | 0,5 mm²                                  | USB-Versorgungsleitung |
| 18    | 1,024              | 0,823                | 1,0 mm²                                  | Netzteil-Anschlussleitung, 12V-KFZ |
| 16    | 1,291              | 1,31                 | 1,5 mm²                                  | LED-Streifen-Versorgung |
| 14    | 1,628              | 2,08                 | 2,5 mm²                                  | US-Hausinstallation (leicht) |
| 12    | 2,053              | 3,31                 | 4,0 mm²                                  | US-Hausinstallation (Standard) |
| 10    | 2,588              | 5,26                 | 6,0 mm²                                  | US-Herd-/Trockneranschluss |
| 8     | 3,264              | 8,37                 | 10 mm²                                   | Batteriekabel |
| 6     | 4,115              | 13,3                 | 16 mm²                                   | Batteriekabel, kleine Zuleitung |
| 4     | 5,189              | 21,2                 | 25 mm²                                   | Hausanschluss (leicht) |
| 2     | 6,544              | 33,6                 | 35 mm²                                   | Hausanschluss |
| 1     | 7,348              | 42,4                 | 50 mm²                                   | Zählerzuleitung |
| 1/0 (0)  | 8,251           | 53,5              | 70 mm²                                   | Hauptleitung |
| 2/0 (00) | 9,266           | 67,4              | 70 mm²                                   | Hauptleitung |
| 3/0 (000)| 10,405          | 85,0              | 95 mm²                                   | Hauptleitung, Verteiler |
| 4/0 (0000)| 11,684         | 107,2            | 120 mm²                                  | Zuleitung, Trafoanschluss |

> Beim Ersatz einer AWG-Angabe durch einen mm²-Normquerschnitt **immer
> aufrunden**, nie abrunden — sonst sinkt die Strombelastbarkeit
> gegenüber dem Originalbauteil.

---

## Achtung bei der Strombelastbarkeit

Die AWG-Tabelle liefert nur die **Fläche**, keine direkt übertragbare
Stromtragfähigkeit. US-amerikanische Ampacity-Tabellen (NEC, UL) beruhen auf
anderen Isolationsklassen, Umgebungstemperaturen und Sicherheitsfaktoren als
die deutsche **DIN VDE 0298-4**. Eine "18 AWG = 10 A"-Angabe aus einem
US-Datenblatt darf **nicht** ungeprüft für eine deutsche Installation
übernommen werden — für die Absicherung gilt immer die Strombelastbarkeit
nach VDE 0298-4 des tatsächlich verbauten Querschnitts in mm², siehe
[Strombelastbarkeit von Leitungen und Einzeladern – VDE 0298-4](strombelastbarkeit_vde0298.md).

---

## Rechenbeispiel

**Aufgabe:** Ein US-Datenblatt gibt für ein Steckernetzteil-Kabel „18 AWG" an.
Welcher deutsche Normquerschnitt entspricht dem mindestens?

1. Fläche AWG 18 = 0,823 mm²
2. Nächster Normquerschnitt ≥ 0,823 mm² aus der Reihe
   `{0,5 / 0,75 / 1,0 / 1,5 / …}` → **1,0 mm²**
3. Für die tatsächliche Absicherung zusätzlich Verlegeart und
   Umgebungstemperatur nach VDE 0298-4 prüfen — die AWG-Angabe ersetzt
   diese Prüfung nicht.
