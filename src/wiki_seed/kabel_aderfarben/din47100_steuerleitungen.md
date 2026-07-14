# Aderfarben nach DIN 47100 – Mehradrige Steuerleitungen

**DIN 47100** regelt die Aderfarben mehradriger Steuer- und Datenleitungen
(z. B. **LiYCY**, **LiYY**, **ÖLFLEX®**) – anders als die Aderfarben für feste
Elektroinstallation (siehe [Aderfarben im Wandel der Normen](aderfarben_normen_geschichte.md)),
bei denen L1/L2/L3/N/PE farblich festgelegt sind. Bei Steuerleitungen mit
vielen Adern (2 bis über 60) macht das keinen Sinn – hier bekommt **jede
einzelne Ader eine eigene, eindeutige Farbe oder Farbkombination**, damit sie
sich am offenen Kabelende und an beiden Enden zuverlässig zuordnen lässt.

> **Status:** DIN 47100 wurde als offizielle Norm zurückgezogen, ohne
> direkten 1:1-Nachfolger im gleichen Umfang. In der Praxis ist sie aber
> weiterhin **de-facto-Industriestandard** – nahezu alle Hersteller
> (Lapp/ÖLFLEX, Helukabel, Faber) drucken ihre mehradrigen Steuerleitungen
> weiterhin exakt nach diesem Farbcode.

**Abgrenzung zu IEC 60757:** Die aktuell gültige **DIN EN IEC 60757
(VDE 0197-757)** – zuletzt 2023-10 nach 37 Jahren grundlegend neu gefasst –
regelt nur die **Kurzzeichen einzelner Farben** (z. B. BN, BU, GNYE für
grün-gelb) für die allgemeine Leiterkennzeichnung nach
[DIN VDE 0293-308](aderfarben_normen_geschichte.md). Sie liefert **keinen**
eigenen Ring-Farbcode für mehradrige Steuerleitungen – für die
durchnummerierte Adernfolge 1–61 bleibt der DIN-47100-Farbcode die
einschlägige (wenn auch zurückgezogene) Referenz.

---

## Die 18 Grundfarben (Adern 1–18)

| Ader-Nr. | Farbe          |
|:--------:|----------------|
| 1        | weiß           |
| 2        | braun          |
| 3        | grün           |
| 4        | gelb           |
| 5        | grau           |
| 6        | rosa           |
| 7        | blau           |
| 8        | rot            |
| 9        | schwarz        |
| 10       | violett        |
| 11       | grau-rosa      |
| 12       | rot-blau       |
| 13       | weiß-grün      |
| 14       | braun-grün     |
| 15       | weiß-gelb      |
| 16       | gelb-braun     |
| 17       | weiß-grau      |
| 18       | weiß-rosa      |

**Ader 1 ist immer weiß** – das ist der zuverlässigste erste
Orientierungspunkt beim Auflegen einer unbekannten Steuerleitung.

---

## Mehr als 18 Adern: Ringmarkierung

Ab 19 Adern wiederholt sich die 18er-Farbfolge, jede Wiederholung bekommt
zur Unterscheidung einen **schwarzen Ring** auf der Ader:

| Adern-Bereich | Kennzeichnung |
|:--------------:|---------------|
| 1–18            | Grundfarbe, kein Ring |
| 19–36           | Grundfarbe + **1 schwarzer Ring** |
| 37–54           | Grundfarbe + **2 schwarze Ringe** |
| 55–61 (üblicher Max.)| Grundfarbe + **3 schwarze Ringe** |

**Beispiel:** Ader 22 = Grundfarbe von Ader 4 (gelb, da 22 − 18 = 4) mit
einem schwarzen Ring.

---

## Typische Anwendung

DIN-47100-Farbcode findet sich bei:

- **LiYCY** – geschirmte PVC-Steuerleitung
- **LiYY** – ungeschirmte PVC-Steuerleitung
- Vorkonfektionierte SPS-Anschlusskabel, Sensor-/Aktor-Sammelleitungen
- Klemmen-zu-Klemmen-Verdrahtung bei vielen parallelen Steuersignalen

**Praxis-Hinweis:** Bei Leitungen mit **Schirm** zählt der Schirm nicht als
nummerierte Ader – er wird separat behandelt
(siehe [Schirmung – Konzepte, Feldtypen und Praxis](../schutz/schirmung.md)).

---

## Rechenbeispiel

**Aufgabe:** LiYCY 12×0,25 mm² – welche Farbe hat Ader 9, welche Ader 11?

1. Ader 9 ≤ 18 → direkt aus der Tabelle: **schwarz**
2. Ader 11 ≤ 18 → direkt aus der Tabelle: **grau-rosa**

**Aufgabe 2:** Ein 30-adriges Kabel – welche Kennzeichnung hat Ader 25?

1. 25 − 18 = 7 → Grundfarbe von Ader 7 = **blau**
2. Ader liegt im Bereich 19–36 → **+ 1 schwarzer Ring**
3. Ergebnis: **blau mit einem schwarzen Ring**

---

## Quellen

- DIN 47100 – zurückgezogen im November 1998, ohne direkten
  Nachfolger im gleichen Umfang; Farbcode bleibt de-facto-Standard
  der Kabelhersteller
- DIN EN IEC 60757 (VDE 0197-757) – Kurzzeichen für Farben, Neufassung
  2023-10 (kein Ring-Farbcode, siehe Abgrenzung oben)
- [Kabeltronik – Farbcode nach DIN 47100](https://www.kabeltronik.de/de/kabeltronik/info-download/technical/color-code-din)
- [Lapp – Farbcode DIN 47100 (PDF)](https://www.lapp.ch/file/73/CMS/Downloads/farbcode-din-47100-de.pdf)
- [SAB Kabel – Farbcode Aderkennzeichnung nach DIN 47100](https://www.sab-kabel.de/kabel-konfektion-temperaturmesstechnik/technische-daten/farbcode-kabel-und-leitungen.html)
- [medikabel – Ader-Farbcode nach DIN 47100](https://www.medikabel.de/en/technical-information/colorcodes/colorcodes-din47100)
- [letronic – Kennzeichnung der Verseilelemente nach DIN 47100 (PDF)](https://www.letronic.de/themes/letronic/assets/pdf/DIN%2047100%20Farbcode.pdf)
