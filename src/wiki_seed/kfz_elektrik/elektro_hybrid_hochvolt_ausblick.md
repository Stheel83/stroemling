# Elektro-/Hybridfahrzeuge: Hochvolt als Abgrenzung zum 12V-Bordnetz

Dieser Artikel ist bewusst kurz gehalten – er soll das klassische
12V-Bordnetz, um das es in dieser Kategorie sonst geht, von den
Hochvolt-Systemen moderner Elektro- und Hybridfahrzeuge abgrenzen. **Er ist
keine Anleitung für Arbeiten an Hochvolt-Systemen.**

---

## 1. Zwei getrennte elektrische Welten in einem Fahrzeug

Elektro- und Hybridfahrzeuge haben typischerweise **zwei unabhängige
Bordnetze**:

- Ein klassisches **12V-Bordnetz** für Beleuchtung, Steuergeräte, Infotainment
  usw. – technisch im Kern dasselbe System, das in den anderen Artikeln
  dieser Kategorie beschrieben wird
- Ein **Hochvolt-System** (typisch 400–800 V) für Antriebsmotor,
  Traktionsbatterie und Ladetechnik – ein komplett eigener, galvanisch
  getrennter Stromkreis mit eigenen Sicherheitsanforderungen

Zwischen beiden Systemen sitzt üblicherweise ein DC/DC-Wandler, der das
12V-Bordnetz aus der Hochvoltbatterie versorgt (die klassische
12V-Lichtmaschine gibt es in reinen Elektrofahrzeugen nicht mehr).

## 2. Warum Hochvolt-Systeme grundlegend anders sind

Ab einer Spannung von 60 V DC (bzw. 30 V AC) gelten Stromkreise als
**Hochvolt** im Sinne der Kfz-Sicherheitsvorschriften – deutlich unterhalb
der 400–800 V, die in Antriebssträngen tatsächlich anliegen. Zentrale
Unterschiede zum 12V-Bordnetz:

- **Lebensgefahr statt Sachschaden-Risiko:** Ein Kurzschluss oder direkter
  Kontakt kann bei Hochvolt tödlich sein – bei 12V praktisch ausgeschlossen
- **Kondensator-Restspannung:** Hochvolt-Komponenten (Wechselrichter,
  Zwischenkreiskondensatoren) können auch nach dem Abschalten und
  Trennen der Batterie noch für Minuten gefährliche Restspannung führen
- **Orange Kennzeichnung:** Hochvolt-Leitungen sind durchgängig orange
  isoliert – eine eigene, verbindliche Farbkonvention nur für diesen
  Spannungsbereich
- **Service-Trennstecker (Service Disconnect):** Ein spezieller
  Trennstecker unterbricht den Hochvolt-Kreis mechanisch, bevor überhaupt
  an der Batterie gearbeitet werden darf

## 3. Gesetzlich geregelte Qualifikationsstufen

Arbeiten an Hochvolt-Fahrzeugen sind in Deutschland über die
DGUV-Information (aktuell 209-093, vormals 200-005) in drei
Qualifikationsstufen geregelt:

| Stufe | Bezeichnung | Erlaubte Tätigkeiten |
|---|---|---|
| 1S | Unterwiesene Person | Arbeiten **ohne** Berührung des HV-Systems (Karosserie, Reifen, konventionelle Bremse/12V-Netz) |
| 2S | Fachkundige Person (spannungsfrei) | Arbeiten am **freigeschalteten** HV-System nach Trennung |
| 3S | Fachkundige Person (unter Spannung) | Arbeiten am **spannungsführenden** HV-System |

Diese Qualifikationspflicht ist bewusst so streng geregelt, dass sie **kein
Hobbyisten-Bereich** ist – anders als klassische 12V-Kfz-Elektrik, die mit
Grundkenntnissen und Vorsicht auch privat bearbeitet werden kann.

## 4. Was das für dieses Wiki bedeutet

Die übrigen Artikel dieser Kategorie (Batterietechnik, Sicherungen,
Bordnetz-Architektur usw.) beziehen sich ausschließlich auf das klassische
**12V-Bordnetz**, das in Elektro-/Hybridfahrzeugen unverändert vorhanden
und für Hobbyisten genauso zugänglich ist wie in einem Verbrenner. Das
Hochvolt-System selbst bleibt bewusst außerhalb des Umfangs dieses Wikis.

---

## Quellen

- DGUV Information 209-093: [Qualifizierung für Arbeiten an Fahrzeugen mit Hochvoltsystemen](https://publikationen.dguv.de/widgets/pdf/download/article/3982)
- KFZ Dietrich: [HV-Qualifikation und Hochvolt-Schein erklärt](https://kfz-dietrich.com/blog/hv-qualifikation-werkstatt-hybrid)

**Sicherheitshinweis:** Arbeiten an Hochvolt-Komponenten dürfen ausschließlich
von entsprechend qualifizierten Personen (mindestens Stufe 2S/3S nach
DGUV-Information) durchgeführt werden. Dieser Artikel dient ausschließlich
der allgemeinen Einordnung, nicht als Handlungsanleitung.
