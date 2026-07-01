# Strombelastbarkeit von Leitungen – VDE 0298-4

Wie viel Strom eine Leitung dauerhaft führen darf, hängt vom
Querschnitt, dem Material und der Verlegeart ab. Überschreitung
führt zu unzulässiger Erwärmung und Isolationsschädigung.

> **Norm:** DIN VDE 0298-4:2013-06

---

## Basiswerte: Kupfer-Leitungen nach Verlegeart

Strombelastbarkeit I_z in Ampere (Dauerbelastung, 30°C Umgebung):

| Querschnitt | A1¹ | A2² | B1³ | B2⁴ | C⁵  | E/F⁶ |
|:-----------:|:---:|:---:|:---:|:---:|:---:|:----:|
| 1,5 mm²     | 13  | 13  | 15  | 15  | 17  | 19   |
| 2,5 mm²     | 17  | 17  | 20  | 20  | 23  | 26   |
| 4,0 mm²     | 23  | 23  | 27  | 25  | 30  | 35   |
| 6,0 mm²     | 29  | 29  | 34  | 32  | 38  | 44   |
| 10 mm²      | 39  | 38  | 46  | 43  | 52  | 60   |
| 16 mm²      | 52  | 51  | 61  | 57  | 69  | 79   |
| 25 mm²      | 68  | 66  | 80  | 75  | 90  | 101  |
| 35 mm²      | 84  | 83  | 99  | 92  | 111 | 126  |
| 50 mm²      | 100 | 99  | 118 | 110 | 133 | 152  |

¹ A1: Einader-Leitung in Rohr in Wärmedämmung  
² A2: Mehrader-Leitung in Rohr in Wärmedämmung  
³ B1: Einader-Leitung in Rohr auf/in Wand  
⁴ B2: Mehrader-Leitung in Rohr auf/in Wand  
⁵ C: Kabel direkt auf Wand (keine Wärmedämmung)  
⁶ E/F: Kabel frei in Luft, auf Kabelbahn, mehradrig  

---

## Korrekturfaktoren Umgebungstemperatur

Standardwert: 30°C. Bei abweichender Temperatur:

| Umgebungstemperatur | Faktor Cu-Leitung |
|:-------------------:|:-----------------:|
| 10°C                | 1,22              |
| 15°C                | 1,17              |
| 20°C                | 1,12              |
| 25°C                | 1,06              |
| **30°C**            | **1,00**          |
| 35°C                | 0,94              |
| 40°C                | 0,87              |
| 45°C                | 0,79              |
| 50°C                | 0,71              |
| 55°C                | 0,61              |
| 60°C                | 0,50              |

---

## Häufungsfaktor bei Bündelung (Verlegeart B–F)

Mehrere belastete Leitungen nebeneinander (in Rohr, Kanal, Bündel):

| Anzahl Leitungen | Faktor |
|:----------------:|:------:|
| 1                | 1,00   |
| 2                | 0,80   |
| 3                | 0,70   |
| 4                | 0,65   |
| 5                | 0,60   |
| 6                | 0,57   |
| 7–9              | 0,54   |
| 10–12            | 0,50   |
| 13–16            | 0,45   |
| 17–20            | 0,41   |

> Nicht belastete Adern (N bei symmetrischer Drehstromlast, PE) zählen
> nicht als belastete Leitung.

---

## Aluminium-Leitungen

Alu-Leitungen haben ca. 79 % der Kupfer-Belastbarkeit bei gleichem Querschnitt.
Faktor: **× 0,79** auf Cu-Wert. Für den gleichen Strom benötigt Alu
typischerweise den nächsthöheren Querschnitt.

| Querschnitt Alu | Äquivalent Cu |
|:---------------:|:-------------:|
| 16 mm²          | 10 mm²        |
| 25 mm²          | 16 mm²        |
| 35 mm²          | 25 mm²        |
| 50 mm²          | 35 mm²        |

---

## Berechnungsbeispiel

**Aufgabe:** 3-adrige NYM-Leitung (Cu), Verlegeart B2, 35°C Umgebung,
3 Leitungen im Rohr zusammen. Welchen Querschnitt für 16 A?

1. Korrekturfaktor Temperatur: 0,94
2. Häufungsfaktor (3 Leitungen): 0,70
3. Gesamtfaktor: 0,94 × 0,70 = 0,658
4. Erforderliche Basisbelastbarkeit: 16 A / 0,658 = **24,3 A**
5. Tabelle B2: 4 mm² = 25 A → **4 mm² ausreichend**
