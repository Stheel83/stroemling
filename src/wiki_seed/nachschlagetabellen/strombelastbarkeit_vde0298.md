# Strombelastbarkeit von Leitungen und Einzeladern – VDE 0298-4

Wie viel Strom ein Leiter dauerhaft führen darf, hängt vom Querschnitt, dem
Material, der Verlegeart und der Umgebungstemperatur ab. Überschreitung
führt zu unzulässiger Erwärmung und Isolationsschädigung. Das gilt sowohl
für mehradrige **Leitungen/Kabel** (NYM, LiYCY …) als auch für einzelne
**Aderleitungen** in der Schaltschrankverdrahtung (H07V-K, H05V-K).

> **Normen:** DIN VDE 0298-4:2013-06 · DIN VDE 0100-430 (Schutz bei Überlast) · DIN EN 60204-1 (Schaltschrankverdrahtung)

---

## Korrekturfaktor: Umgebungstemperatur

Standardwert der Tabellen unten: 30 °C. Bei abweichender Temperatur:

| Umgebungstemperatur | Faktor Cu-Leitung |
|:--------------------:|:------------------:|
| 10 °C                | 1,22               |
| 15 °C                | 1,17               |
| 20 °C                | 1,12               |
| 25 °C                | 1,06               |
| **30 °C**            | **1,00**           |
| 35 °C                | 0,94                |
| 40 °C                | 0,87                |
| 45 °C                | 0,79                |
| 50 °C                | 0,71                |
| 55 °C                | 0,61                |
| 60 °C                | 0,50                |

> **Schaltschrank-Hinweis:** Schaltschränke werden innen oft wärmer als die
> Standardannahme von 30 °C (Eigenerwärmung durch Netzteile, Motoren, dichte
> Packung). Bei Schränken ohne aktive Kühlung im Dauerbetrieb sind 35–40 °C
> Innentemperatur ein realistischer Planungswert.

---

## Mehradrige Leitungen und Kabel

### Basiswerte: Kupfer-Leitungen nach Verlegeart

Strombelastbarkeit I_z in Ampere (Dauerbelastung, 30 °C Umgebung):

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

### Häufungsfaktor bei Bündelung (Verlegeart B–F)

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

### Aluminium-Leitungen

Alu-Leitungen haben ca. 79 % der Kupfer-Belastbarkeit bei gleichem Querschnitt.
Faktor: **× 0,79** auf Cu-Wert. Für den gleichen Strom benötigt Alu
typischerweise den nächsthöheren Querschnitt.

| Querschnitt Alu | Äquivalent Cu |
|:---------------:|:-------------:|
| 16 mm²          | 10 mm²        |
| 25 mm²          | 16 mm²        |
| 35 mm²          | 25 mm²        |
| 50 mm²          | 35 mm²        |

### Berechnungsbeispiel

**Aufgabe:** 3-adrige NYM-Leitung (Cu), Verlegeart B2, 35 °C Umgebung,
3 Leitungen im Rohr zusammen. Welchen Querschnitt für 16 A?

1. Korrekturfaktor Temperatur: 0,94
2. Häufungsfaktor (3 Leitungen): 0,70
3. Gesamtfaktor: 0,94 × 0,70 = 0,658
4. Erforderliche Basisbelastbarkeit: 16 A / 0,658 = **24,3 A**
5. Tabelle B2: 4 mm² = 25 A → **4 mm² ausreichend**

---

## Einzeladern in der Schaltschrankverdrahtung

Einzeladern wie **H07V-K** oder **H05V-K** sind feindrähtige Aderleitungen
für die Innenverdrahtung von Schaltschränken und Geräten (Klemme zu Klemme,
Schütz zu Klemmenleiste usw.) — keine Mantelleitung und kein Kabel im
Außenbereich. Die Verlegearten und Basiswerte unterscheiden sich von der
Leitungstabelle oben; die Korrekturfaktoren für Umgebungstemperatur gelten
unverändert.

### Basiswerte: Einzeladern Kupfer, feindrähtig (H05V-K/H07V-K)

Strombelastbarkeit I_z in Ampere bei 30 °C Umgebungstemperatur:

| Querschnitt | Frei in Luft / lose gebündelt¹ | Eng gebündelt im Kanal² |
|:-----------:|:-------------------------------:|:------------------------:|
| 0,5 mm²     | 11                               | 8                        |
| 0,75 mm²    | 15                               | 10                       |
| 1,0 mm²     | 17,5                             | 12                       |
| 1,5 mm²     | 22                               | 15                       |
| 2,5 mm²     | 30                               | 20                       |
| 4,0 mm²     | 40                               | 27                       |
| 6,0 mm²     | 51                               | 34                       |
| 10 mm²      | 70                               | 47                       |

¹ Verlegeart E/F nach VDE 0298-4 (Verlegeart „frei in Luft"), lose Adern oder
kleines Bündel mit Abstand.  
² Verlegeart B2 sinngemäß angewandt, mehrere Adern eng gebündelt im
geschlossenen Kabelkanal — praxisüblicher Ansatz für dichte
Schaltschrankverdrahtung, wenn keine Herstellerangabe vorliegt.

> **Praxis-Hinweis:** Für konkrete Aderleitungen (z. B. Lapp Ölflex®, Helukabel)
> immer zuerst das Datenblatt des Herstellers prüfen — die Werte oben sind
> ein VDE-basierter Richtwert, kein Ersatz für die Herstellerangabe.

### Absicherung nach DIN VDE 0100-430

Eine Ader/Leitung ist korrekt geschützt, wenn **beide** Bedingungen erfüllt sind:

```
Bedingung 1:  I_B ≤ I_N ≤ I_Z
Bedingung 2:  I_2 ≤ 1,45 × I_Z
```

- `I_B` = Betriebsstrom des Verbrauchers
- `I_N` = Nennstrom des Schutzorgans (Sicherung/LS-Schalter)
- `I_Z` = zulässige Dauerstrombelastbarkeit (aus Tabelle, mit Korrekturfaktoren)
- `I_2` = Strom, bei dem das Schutzorgan sicher innerhalb der Prüfzeit auslöst

**Für Leitungsschutzschalter (LS, Charakteristik B/C/D nach DIN EN 60898-1)**
ist `I_2 = 1,45 × I_N` bereits durch die Bauart festgelegt — Bedingung 2 ist
dann automatisch erfüllt, sobald `I_N ≤ I_Z` gilt. Es genügt also die
einfache Regel **I_N ≤ I_Z**.

**Für gG-Sicherungen (NH/D-System)** gilt herstellerbedingt `I_2 ≈ 1,6 × I_N`.
Damit Bedingung 2 erfüllt ist, muss:

```
I_Z ≥ (1,6 / 1,45) × I_N ≈ 1,10 × I_N
```

Bei gG-Sicherungen reicht `I_N ≤ I_Z` allein **nicht** sicher aus — die Ader
sollte gut 10 % Reserve gegenüber dem Sicherungsnennstrom haben.

### Richtwerttabelle: Querschnitt → maximale Absicherung (Einzeladern)

Bei 30 °C, frei verlegt/lose gebündelt (erste Spalte der Basiswerte-Tabelle oben):

| Querschnitt | I_z (A) | Max. LS-Schalter (I_N ≤ I_z) | Max. gG-Sicherung (I_z ≥ 1,10 × I_N) |
|:-----------:|:-------:|:-----------------------------:|:--------------------------------------:|
| 0,5 mm²     | 11      | 10 A                           | –¹                                     |
| 0,75 mm²    | 15      | 13 A / 16 A²                   | –¹                                     |
| 1,0 mm²     | 17,5    | 16 A                           | –¹                                     |
| 1,5 mm²     | 22      | 20 A                           | 16 A                                   |
| 2,5 mm²     | 30      | 25 A                           | 25 A                                   |
| 4,0 mm²     | 40      | 32 A                           | 35 A                                   |
| 6,0 mm²     | 51      | 50 A                           | 40 A                                   |
| 10 mm²      | 70      | 63 A                           | 63 A                                   |

¹ Für Querschnitte unter 1,5 mm² sind gG-Sicherungen unüblich – hier werden
üblicherweise Elektronik-Sicherungen (Feinsicherungen, flink/träge nach
DIN 41571) oder LS-Schalter eingesetzt.  
² 16 A nur bei kurzer Leitungslänge und wenn die Ader tatsächlich für 16 A
freigegeben ist (Herstellerangabe prüfen) — 13 A ist die konservative Wahl.

### Rechenbeispiel

**Aufgabe:** H07V-K 1,5 mm² verdrahtet im Schaltschrank, eng gebündelt im
Kanal, Innentemperatur 40 °C. Zulässiger LS-Schalter?

1. Basiswert eng gebündelt: 15 A
2. Korrekturfaktor 40 °C: 0,87
3. I_z = 15 A × 0,87 = **13,1 A**
4. Nächstkleinerer LS-Normnennstrom: **13 A** (oder 10 A für Reserve)

Ohne Berücksichtigung der Bündelung und Innentemperatur hätte man fälschlich
einen 16-A- oder sogar 20-A-Automaten gewählt — die Ader wäre thermisch
überlastet, ohne dass der LS-Schalter auslöst.

---

## Quellen

- DKE Normendatenbank: [DIN VDE 0298-4 (VDE 0298-4):2023-06](https://www.dke.de/de/normen-standards/dokument?id=7161768&type=dke%7Cdokument)
- elektro.net: [Empfohlene Werte für die Strombelastbarkeit von Kabeln und Leitungen](https://www.elektro.net/123986/empfohlene-werte-fuer-die-strombelastbarkeit-von-kabeln-und-leitungen/)
- ElekRechner: [DIN VDE 0298-4 erklärt: Strombelastbarkeit, Verlegearten & Korrekturfaktoren](https://www.elekrechner.com/ratgeber/vde-normen/din-vde-0298)

*Hinweis: Die Einzeladern-Tabelle (H05V-K/H07V-K) wendet die
VDE-0298-4-Verlegearten sinngemäß auf die Schaltschrank-Praxis an
(„eng gebündelt im Kanal" ≈ Verlegeart B2) — bei konkreten
Aderleitungs-Fabrikaten immer zuerst das Hersteller-Datenblatt prüfen,
das kann von diesem Richtwert abweichen.*
