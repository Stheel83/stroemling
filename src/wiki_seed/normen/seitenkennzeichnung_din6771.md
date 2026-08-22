# Seitenkennzeichnung nach DIN 6771

DIN 6771 regelte den Aufbau von technischen Zeichnungen und Dokumenten —
insbesondere das Schriftfeld (Stempelfeld) und die Blattkennzeichnung.
„DIN 6771" ist in der Elektropraxis nach wie vor der geläufige Name für
diesen klassischen Schriftfeld-Stil, auch wenn die Norm selbst formal
zurückgezogen ist (Details unten).

> **Norm (historisch):** DIN 6771-1 bis DIN 6771-6 — Teil 1 (Schriftfeld)
> seit 2004 ersetzt durch **EN ISO 7200**, Teil 6 (Zeichnungsformate)
> bereits seit 1999 durch **EN ISO 5457**, Teile 2/5 ersatzlos gestrichen.

---

## DIN 6771 vs. EN ISO 7200 — was hat sich geändert?

Bei den **Blattformaten** (Abschnitt „Blattformate" unten) hat sich
inhaltlich nichts geändert — EN ISO 5457 übernimmt exakt dieselben
A0–A4-Maße, nur die Norm-Nummer ist neu.

Beim **Schriftfeld** gibt es einen echten Unterschied: DIN 6771-1 schrieb
ein **starres Pflichtraster** vor (feste Maße 182,88 × 54,99 mm, festes
Feld-Layout unten rechts). EN ISO 7200 schreibt nur noch vor, **welche
Datenfelder** vorkommen sollen (Zeichnungsnummer, Benennung, Maßstab,
Datum, Erstellt/Geprüft/Freigegeben, Änderungsindex — inhaltlich fast
identisch zu DIN 6771-1), stellt das konkrete Layout aber frei — nur die
Breite (180 mm) ist noch vorgegeben, die Höhe nicht mehr.

**In Strömling Design stehen beide Stile zur Wahl:** Die eingebaute
Titelblatt-Vorlage „DIN 6771" liefert das klassische starre
Drei-Zeilen-Schriftfeld. Wer stattdessen ein frei gestaltetes Schriftfeld
im heutigen EN-ISO-7200-Sinn möchte, wählt „Benutzerdefiniert" und baut
es im visuellen Normblatt-Editor selbst zusammen — mit denselben
Datenfeldern, aber frei platzierbarem Layout.

---

## Schriftfeld (Stempelfeld)

Das Schriftfeld befindet sich immer **unten rechts** auf dem Blatt
(bei Hochformat: rechts unten; bei Querformat: unten rechts).

Pflichtelemente nach DIN 6771-1:

| Feld | Inhalt | Beispiel |
|------|--------|---------|
| Firma / Auftraggeber | Name des Unternehmens | Musterfirma GmbH |
| Zeichnungsnummer | Eindeutige Dokumentnummer | 2024-001-ST-001 |
| Benennung | Bezeichnung des Dokuments | Hauptverteiler HV-01 |
| Blatt / Blätter | Seitenzahl | Bl. 3 / 12 |
| Maßstab | bei Lageplaenen | 1:50 |
| Datum | Erstellungsdatum | 2024-01-15 |
| Erstellt | Name oder Kürzel | MMS |
| Geprüft | Name oder Kürzel | STH |
| Freigegeben | Name oder Kürzel | KL |
| Änderungsindex | Revisionsbuchstabe | A, B, C … |

---

## Blattformate

| Format | Maße (mm) | Verwendung |
|:------:|:---------:|-----------|
| A0     | 841 × 1189 | Großanlagen, Übersichtsschaltpläne |
| A1     | 594 × 841  | Stromlaufpläne, Anlagenübersichten |
| A2     | 420 × 594  | Standard Stromlaufplan |
| A3     | 297 × 420  | Klemmenplan, Geräteschema |
| A4     | 210 × 297  | Einzelseiten, Listen, Berichte |

---

## Zeichnungsnummer

Eine einheitliche Nummerierung erleichtert die Dokumentenverwaltung.
Verbreitetes Schema:

```
[Projektnummer] - [Anlagenkennzeichen] - [Dokumenttyp] - [Blattnummer]

Beispiel: 2024-001 - ST - SLP - 003
          │          │   │      │
          │          │   │      └─ Blatt 003
          │          │   └──────── SLP = Stromlaufplan
          │          └──────────── ST  = Schaltanlage (Anlagenkürzel)
          └─────────────────────── 2024-001 = Projektnummer
```

Gebräuchliche Dokumenttyp-Kürzel:

| Kürzel | Bedeutung |
|:------:|-----------|
| SLP    | Stromlaufplan |
| KLP    | Klemmenplan |
| KBP    | Kabelplan / Kabelverzeichnis |
| GER    | Geräteliste / Stückliste |
| ANS    | Anschlussplan |
| INS    | Installationsplan |
| LAG    | Lageplan |
| ÜBS    | Übersichtsschaltplan |

---

## Änderungsindex

Jede Revision erhält einen Buchstaben (A, B, C …) oder eine Ziffer.
Änderungsvermerke werden im Schriftfeld und idealerweise in einer
**Änderungstabelle** (links neben dem Schriftfeld) eingetragen:

| Index | Datum | Inhalt | Bearbeiter |
|:-----:|-------|--------|-----------|
| A     | 2024-01-15 | Erstausgabe | MMS |
| B     | 2024-03-20 | Motorschutz geändert | STH |
| C     | 2024-06-01 | Klemmenplan ergänzt | MMS |

---

## Zonen-Koordinaten

Auf größeren Formaten (A1/A0) werden die Blattränder in Zonen unterteilt,
damit Querverweise punktgenau auf Seite und Zone verweisen können:

- Waagerecht: Ziffern 1, 2, 3 … (von links nach rechts)
- Senkrecht: Buchstaben A, B, C … (von oben nach unten)
- Referenz: z. B. „Seite 5 / Zone C4"

---

## Quellen

- Wikipedia: [DIN 6771](https://de.wikipedia.org/wiki/DIN_6771)
- Wikipedia: [ISO 7200](https://de.wikipedia.org/wiki/EN_ISO_7200)
- DIN Media: [DIN EN ISO 7200 – 2004-05](https://www.dinmedia.de/en/standard/din-en-iso-7200/69093619)
- DIN Media: [DIN EN ISO 5457 – 2017-10](https://www.dinmedia.de/en/standard/din-en-iso-5457/278410251)

*Hinweis: Die Blattformat-Tabelle (A0–A4) gilt unverändert nach EN ISO
5457 — hier ist DIN 6771 nur der historische Name derselben Werte. Die
Schriftfeld-Pflichtelemente-Tabelle oben orientiert sich am alten,
starren DIN-6771-1-Raster; wer ein frei gestaltbares Schriftfeld nach
heutigem EN-ISO-7200-Verständnis braucht, nutzt in Strömling Design die
Vorlage „Benutzerdefiniert" mit dem visuellen Normblatt-Editor.*
