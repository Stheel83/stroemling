# BMK nach DIN EN 81346 – Kurzreferenz

Das Betriebsmittelkennzeichen (BMK) identifiziert jedes Element in einer
Anlage eindeutig. Strömling Design verwendet DIN EN 81346 als Basis
für die automatische BMK-Vergabe.

> **Norm:** DIN EN 81346-1 und -2 (IEC 81346, ersetzt DIN EN 61346)

---

## Aufbau eines BMK

```
== ST + HB - Q1
│   │    │   │
│   │    │   └─ Betriebsmittel-Kennbuchstabe + lfd. Nr.
│   │    └───── Ort (++Ort → +Unterort)
│   └────────── Anlage (==Übergeordnete Anlage → =Anlage)
└────────────── Präfix-Zeichen
```

---

## Präfix-Zeichen

| Zeichen | Bedeutung | Beispiel |
|:-------:|-----------|---------|
| `==`    | Übergeordnete Anlage (Projekt, Gebäude) | `==FABRIK` |
| `=`     | Anlage | `=ST` (Schaltanlage) |
| `++`    | Übergeordneter Ort | `++EG` (Erdgeschoss) |
| `+`     | Ort / Einbauort | `+HB` (Hauptverteiler) |
| `-`     | Betriebsmittel | `-Q1` (Leistungsschalter 1) |

---

## Kennbuchstaben für Betriebsmittel (Auswahl)

### Elektrische Energie – Erzeugung und Wandlung

| Buchstabe | Betriebsmittel | Beispiele |
|:---------:|----------------|---------|
| G | Erzeuger, Energiequelle | Generator, Batterie, PV-Modul |
| M | Motor | Drehstrommotor, Servomotor |
| T | Transformator | Netztrafo, Stromwandler |
| U | Umrichter, Wandler | Frequenzumrichter, USV |

### Schalt- und Schutzgeräte

| Buchstabe | Betriebsmittel | Beispiele |
|:---------:|----------------|---------|
| F | Schutzeinrichtung | Sicherung, LSS, Überstromrelais |
| K | Kontaktgerät, Relais | Schütz, Hilfsschütz, Zeitrelais |
| Q | Leistungsschalter, Schaltgerät (Starkstrom) | Motorschutzschalter, Hauptschalter |
| S | Schaltgerät (Steuerung) | Taster, Grenzschalter, Schlüsselschalter |

### Sensoren und Messung

| Buchstabe | Betriebsmittel | Beispiele |
|:---------:|----------------|---------|
| B | Wandler (nichtelektr. → elektr.) | Temperatursensor, Druckgeber |
| P | Messgerät, Prüfgerät | Voltmeter, Amperemeter, Zähler |

### Passive Bauelemente und Verbinder

| Buchstabe | Betriebsmittel | Beispiele |
|:---------:|----------------|---------|
| C | Kondensator | Kompensationskondensator |
| R | Widerstand | Bremswiderstand, Heizwiderstand |
| X | Klemme, Stecker, Buchse | Klemmenleiste, Steckverbinder |
| W | Leitung, Kabel | Kabel, Steuerleitung |

### Anzeige und Signalisierung

| Buchstabe | Betriebsmittel | Beispiele |
|:---------:|----------------|---------|
| H | Signalanzeige | Meldeleuchte, Hupe, Summer |
| P | Messanzeige | (auch Zähler, Anzeigen) |

---

## Vollständiges BMK-Beispiel

```
==ANLAGE1 =ST +HB -Q1
```
Bedeutung: In Anlage `ANLAGE1`, Schaltanlage `ST`, Hauptverteiler `HB`
befindet sich der Leistungsschalter `Q1`.

Kurzform (wenn Anlage/Ort aus Kontext klar): `-Q1`

---

## Nummerierung

Laufende Nummern folgen direkt auf den Kennbuchstaben:
- `-Q1`, `-Q2`, `-Q3` … (Reihenfolge beliebig, aber konsistent)
- Doppelbuchstaben für Untergruppen: `-QF1` (Fehlerschutzschalter 1)

---

## Häufige Fehler

| Fehler | Korrekt |
|--------|---------|
| `-1Q1` (Zahl vor Buchstabe) | `-Q1` |
| `Q1` ohne Präfix im Schaltplan | `-Q1` mit Präfix |
| `=` und `+` vertauscht | `=` = Anlage, `+` = Ort |
| Kennbuchstabe erfunden | Nur normierte Buchstaben aus DIN EN 81346-2 |

---

## Quellen

- DIN Media (Beuth): [DIN EN IEC 81346-2:2020-10](https://www.dinmedia.de/en/standard/din-en-iec-81346-2/320735342)
- DKE Normendatenbank: [DIN EN IEC 81346-2:2020-10](https://www.dke.de/de/normen-standards/dokument?id=7140661&type=dke%7Cdokument)
- KSV Koblenz: [Wie funktioniert die Kennzeichnung von Betriebsmitteln nach DIN EN 81346?](https://www.ksv-koblenz.de/blog/wie-funktioniert-die-kennzeichnung-von-betriebsmitteln-nach-din-en-81346/)

*Hinweis: Die Kennbuchstaben-Tabellen oben sind ein Praxisauszug, nicht die
vollständige Klassenliste der Norm — bei seltenen oder ungewöhnlichen
Betriebsmitteln im Zweifel die Originalnorm (DIN EN IEC 81346-2)
konsultieren.*
