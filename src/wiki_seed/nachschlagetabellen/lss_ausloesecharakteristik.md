# Leitungsschutzschalter – Auslösecharakteristiken B, C, D

Leitungsschutzschalter (LSS, auch LS-Schalter oder MCB) schützen Leitungen
vor Überlast und Kurzschluss. Die Charakteristik bestimmt, bei welchem
Vielfachen des Nennstroms der magnetische Schnellauslöser anspricht.

> **Norm:** DIN EN 60898-1 (VDE 0641-11)

---

## Auslösebereiche im Überblick

| Charakteristik | Magnetischer Schnellauslöser | Typische Anwendung |
|:--------------:|:---------------------------:|---------------------|
| **B**          | 3–5 × I_n                   | Wohngebäude, lange Leitungen, ohmsche Lasten |
| **C**          | 5–10 × I_n                  | Allgemeine Installation, kleine Motoren, Leuchtstofflampen |
| **D**          | 10–20 × I_n                 | Transformatoren, große Motoren, Schweißgeräte, Kondensatoren |

Der **thermische Bimetallauslöser** (Überlastauslösung) ist bei allen
Charakteristiken gleich: Auslösung zwischen 1,13 × I_n (kein Auslösen)
und 1,45 × I_n (Auslösen innerhalb 1 Stunde).

---

## Charakteristik B — für Wohngebäude und ohmsche Lasten

**Schnellauslösung:** 3–5 × I_n  
**Auslösezeit:** < 0,1 s (bei ≥ 5 × I_n)

**Typische Anwendungsfälle:**
- Steckdosenstromkreise in Wohngebäuden
- Beleuchtungskreise
- Lange Leitungen mit hoher Impedanz (Kabellänge begrenzt den Kurzschlussstrom)
- Elektroheizung, Durchlauferhitzer (ohmsche Last, kein Einschaltstromstoß)

> Wichtig: Bei Typ B muss auch am Ende einer langen Leitung noch mindestens
> 5 × I_n Kurzschlussstrom fließen können — sonst löst der magnetische
> Auslöser nicht sicher aus. Bei langen Leitungen Schleifenimpedanz prüfen!

---

## Charakteristik C — Allgemeine Installation und kleine Motoren

**Schnellauslösung:** 5–10 × I_n  
**Auslösezeit:** < 0,1 s (bei ≥ 10 × I_n)

**Typische Anwendungsfälle:**
- Gewerbliche und industrielle Allgemeininstallation
- Kleine Elektromotoren (geringer Anlaufstromstoß)
- Leuchtstofflampen mit Vorschaltgerät
- Steckdosen im Gewerbebereich
- Pumpen, Lüfter mit geringer Massenträgheit

---

## Charakteristik D — Hohe Einschaltströme

**Schnellauslösung:** 10–20 × I_n  
**Auslösezeit:** < 0,1 s (bei ≥ 20 × I_n)

**Typische Anwendungsfälle:**
- Transformatoren (Einschaltstromstoß bis 20 × I_n)
- Großmotoren mit schwerem Anlauf
- Schweißgeräte, Röntgenanlagen
- Kondensatorbatterien
- USV-Anlagen

---

## Auslösezeiten nach DIN EN 60898-1

| Vielfaches I_n | Typ B         | Typ C         | Typ D         |
|:--------------:|:-------------:|:-------------:|:-------------:|
| 1,13 × I_n     | kein Auslösen | kein Auslösen | kein Auslösen |
| 1,45 × I_n     | < 1 h         | < 1 h         | < 1 h         |
| 2,55 × I_n     | < 60 s (heiß) | —             | —             |
| 3 × I_n        | < 0,1 s       | kein Auslösen | kein Auslösen |
| 5 × I_n        | < 0,1 s       | < 0,1 s       | kein Auslösen |
| 10 × I_n       | < 0,1 s       | < 0,1 s       | < 0,1 s       |
| 20 × I_n       | < 0,1 s       | < 0,1 s       | < 0,1 s       |

---

## Selektivität zwischen LSS

Für Selektivität (vorgelagerte Sicherung löst nicht aus, nur der fehlernahe LSS):
- Nennstromverhältnis vorgelagerter zu nachgelagertem LSS mindestens **1 : 1,6**
- Oder: vorgelagerter LSS ist Typ NH-Sicherung (immer selektiv zu MCB)
- Selektivitätsnachweis über Hersteller-Selektivitätstabellen

---

## Häufige Fehler bei der Auswahl

| Fehler | Folge |
|--------|-------|
| Typ B bei Motoranlauf | Ungewolltes Auslösen beim Einschalten |
| Typ D in Wohngebäude | Zu träge — mangelnder Personenschutz |
| Zu hoher Nennstrom | Leitung unzureichend geschützt |
| Leitungsimpedanz ignoriert | Typ B löst am Leitungsende nicht sicher aus |

---

## Quellen

- ABB: [Auslöse-Charakteristiken für Sicherungsautomaten im Vergleich](https://library.e.abb.com/public/a273e99608575e0ec125761100343ab8/2CDC400002D0103.pdf)
- ElekRechner: [LS-Schalter Auslösekennlinien](https://www.elekrechner.com/tabellen/leitungsschutz-kennlinien)
- tgb-automation.de: [Leitungsschutzschalter im Überblick — Charakteristik B/C/D](https://tgb-automation.de/komponenten/leitungsschutzschalter/)

*Hinweis: Die Selektivitätsregel „1 : 1,6" ist eine Faustregel — echte
Selektivität zwischen zwei LSS ist nur über die
Hersteller-Selektivitätstabellen (Strombegrenzungsklasse, Kennlinien)
nachweisbar, nicht allein über das Nennstromverhältnis.*
