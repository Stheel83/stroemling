# Klemmenbezeichnungen nach DIN EN 60445

Normgerechte Klemmenbezeichnungen machen Schaltpläne lesbar und
Verdrahtung eindeutig — unabhängig vom Hersteller.

> **Norm:** DIN EN 60445 (VDE 0197):2018-02  
> (integriert seit 2011 auch DIN EN 60446 / VDE 0198)

---

## Netz-Leiter (AC-Drehstrom)

| Bezeichnung | Bedeutung | Farbe (aktuell) |
|:-----------:|-----------|:---------------:|
| L1          | Außenleiter 1 | braun |
| L2          | Außenleiter 2 | schwarz |
| L3          | Außenleiter 3 | grau |
| N           | Neutralleiter | hellblau |
| PE          | Schutzleiter | grün-gelb |
| PEN         | kombiniert N+PE | grün-gelb, blaue Enden |

---

## Motoranschlussklemmen (3-Phasen-Motor)

| Klemme | Bedeutung |
|:------:|-----------|
| U1     | Wicklungsanfang Phase U |
| V1     | Wicklungsanfang Phase V |
| W1     | Wicklungsanfang Phase W |
| U2     | Wicklungsende Phase U |
| V2     | Wicklungsende Phase V |
| W2     | Wicklungsende Phase W |
| PE     | Schutzleiter (Gehäuse) |

**Stern-Schaltung:** U2, V2, W2 verbunden (Sternpunkt)  
**Dreieck-Schaltung:** U1–W2, V1–U2, W1–V2 verbunden

---

## Schütz-Klemmenbezeichnungen (Hauptstromkreis)

| Klemme | Bedeutung |
|:------:|-----------|
| 1      | Eingang L1 |
| 2      | Ausgang L1 |
| 3      | Eingang L2 |
| 4      | Ausgang L2 |
| 5      | Eingang L3 |
| 6      | Ausgang L3 |

Merkhilfe: **Ungerade** = Eingang (Netz), **Gerade** = Ausgang (Last).

---

## Schütz-Hilfskontakte

| Klemmen | Kontaktart | Zustand Spule AUS |
|:-------:|-----------|:----------------:|
| 13 / 14 | Schließer (NO) | offen |
| 21 / 22 | Öffner (NC) | geschlossen |
| 31 / 32 | Öffner (NC) | geschlossen |
| 43 / 44 | Schließer (NO) | offen |
| 53 / 54 | Schließer (NO) | offen |
| 61 / 62 | Öffner (NC) | geschlossen |

Merkhilfe: Erste Ziffer = Kontaktnummer; letzte Ziffer:
- **3 / 4** = Schließer (NO — Normally Open)
- **1 / 2** = Öffner (NC — Normally Closed)

---

## Schützklappe (Spule / Steuerstromkreis)

| Klemme | Bedeutung |
|:------:|-----------|
| A1     | Spule + (Steuerplus oder Phase) |
| A2     | Spule – (Steuernull oder Neutralleiter) |

---

## Thermorelay-Klemmen

| Klemme | Bedeutung |
|:------:|-----------|
| 1 / 3 / 5 | Eingang L1 / L2 / L3 vom Schütz |
| 2 / 4 / 6 | Ausgang zum Motor |
| 95 / 96    | Öffner (NC) — Abschaltkontakt |
| 97 / 98    | Schließer (NO) — Meldekontakt |

---

## Sicherungslasttrenner / NH-Sicherungen

| Klemme | Bedeutung |
|:------:|-----------|
| 1 / 3 / 5 | Eingang (Netz) |
| 2 / 4 / 6 | Ausgang (Last) |

---

## Klemmenleisten (Reihenklemmen)

Klemmen werden von links nach rechts nummeriert:
`:1`, `:2`, `:3` … oder mit Leistenkürzel: `X1:1`, `X1:2` …

Sonderklemmen nach Funktion:
| Bezeichnung | Funktion |
|:-----------:|----------|
| PE          | Schutzleiterklemme (grün-gelb) |
| N           | Neutralleiterklemme (blau) |
| L           | Phasenklemme / Sammelschiene |

---

## Quellen

- DKE Normendatenbank: [DIN EN 60445 (VDE 0197):2018-02](https://www.dke.de/de/normen-standards/dokument?id=7102116&type=dke%7Cdokument)
- Elektropraktiker: [Anschlusskennzeichnung bei Maschinen- und Anlagentechnik: DIN EN 60445 (VDE 0197) 2018-02](https://www.elektropraktiker.de/nachrichten/nachricht/anschlusskennzeichnung-bei-maschinen-und-anlagentechnik-din-en-60445-vde-0197-2018-02?p=all)
- elektro.net: [Kennzeichnung von Anschlüssen elektrischer Betriebsmittel](https://www.elektro.net/123351/kennzeichnung-von-anschluessen-elektrischer-betriebsmittel/)

*Hinweis: Seit Februar 2023 liegt mit DIN EN IEC 60445 (VDE 0197):2023-02 eine
neuere Ausgabe vor (u. a. verbindliche statt empfohlene Aderfarben, neuer
Abschnitt zu Schutzleiterklemmen bei mehreren Einspeisungen) — die hier
gezeigten Klemmenbezeichnungen selbst sind davon nicht betroffen. Schütz-,
Motor- und Thermorelay-Klemmenbezeichnungen sind Herstellerkonvention nach
DIN EN 60445, keine erschöpfende Normtabelle.*
