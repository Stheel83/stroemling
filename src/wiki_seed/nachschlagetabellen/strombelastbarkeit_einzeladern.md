# Strombelastbarkeit von Einzeladern – Schaltschrankverdrahtung & Absicherung

Einzeladern wie **H07V-K** oder **H05V-K** sind feindrähtige Aderleitungen
für die Innenverdrahtung von Schaltschränken und Geräten (Klemme zu Klemme,
Schütz zu Klemmenleiste usw.) — keine Mantelleitung und kein Kabel im
Außenbereich. Die Belastbarkeit richtet sich nach denselben Grundlagen wie
bei Leitungen ([Strombelastbarkeit von Leitungen – VDE 0298-4](strombelastbarkeit_vde0298.md)),
aber mit eigenen Verlegearten und meist höherer Innentemperatur.

> **Normen:** DIN VDE 0298-4:2013-06 · DIN VDE 0100-430 (Schutz bei Überlast) · DIN EN 60204-1 (Schaltschrankverdrahtung)

---

## Basiswerte: Einzeladern Kupfer, feindrähtig (H05V-K/H07V-K)

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

---

## Korrekturfaktor: Schaltschrank-Innentemperatur

Schaltschränke werden innen oft wärmer als die VDE-Standardannahme von 30 °C
(Eigenerwärmung durch Netzteile, Motoren, dichte Packung). Die
Korrekturfaktoren der Leitungstabelle gelten unverändert
(siehe [Strombelastbarkeit von Leitungen](strombelastbarkeit_vde0298.md)):

| Innentemperatur Schrank | Faktor |
|:------------------------:|:------:|
| 30 °C                    | 1,00   |
| 35 °C                    | 0,94   |
| 40 °C                    | 0,87   |
| 45 °C                    | 0,79   |
| 50 °C                    | 0,71   |

Bei Schaltschränken ohne aktive Kühlung im Dauerbetrieb sind 35–40 °C
Innentemperatur ein realistischer Planungswert, nicht 30 °C.

---

## Absicherung nach DIN VDE 0100-430

Eine Leitung ist korrekt geschützt, wenn **beide** Bedingungen erfüllt sind:

```
Bedingung 1:  I_B ≤ I_N ≤ I_Z
Bedingung 2:  I_2 ≤ 1,45 × I_Z
```

- `I_B` = Betriebsstrom des Verbrauchers
- `I_N` = Nennstrom des Schutzorgans (Sicherung/LS-Schalter)
- `I_Z` = zulässige Dauerstrombelastbarkeit der Ader (aus Tabelle oben, mit Korrekturfaktoren)
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

---

## Richtwerttabelle: Querschnitt → maximale Absicherung

Bei 30 °C, frei verlegt/lose gebündelt (Spalte 1 der Tabelle oben):

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

---

## Rechenbeispiel

**Aufgabe:** H07V-K 1,5 mm² verdrahtet im Schaltschrank, eng gebündelt im
Kanal, Innentemperatur 40 °C. Zulässiger LS-Schalter?

1. Basiswert eng gebündelt: 15 A
2. Korrekturfaktor 40 °C: 0,87
3. I_z = 15 A × 0,87 = **13,1 A**
4. Nächstkleinerer LS-Normnennstrom: **13 A** (oder 10 A für Reserve)

Ohne Berücksichtigung der Bündelung und Innentemperatur hätte man fälschlich
einen 16-A- oder sogar 20-A-Automaten gewählt — die Ader wäre thermisch
überlastet, ohne dass der LS-Schalter auslöst.
