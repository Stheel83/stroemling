# Seitenkennzeichnung nach DIN 6771

DIN 6771 regelt den Aufbau von technischen Zeichnungen und Dokumenten —
insbesondere das Schriftfeld (Stempelfeld) und die Blattkennzeichnung.

> **Norm:** DIN 6771-1 bis DIN 6771-6

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
