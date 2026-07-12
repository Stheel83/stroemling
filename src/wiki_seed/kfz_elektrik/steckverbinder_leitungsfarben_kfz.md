# Steckverbinder & Leitungsfarben in der KFZ-Technik

Wer aus der Hausinstallation kommt und zum ersten Mal in einem
Kfz-Kabelbaum arbeitet, stößt auf ein komplett anderes Normensystem: Andere
Klemmenbezeichnungen, andere Leitungsnormen, andere Steckverbinder-Welt.
Das ist kein Zufall – Fahrzeugelektrik und Hausinstallation haben sich aus
unterschiedlichen historischen Wurzeln und unter unterschiedlichen
Randbedingungen (Vibration, Temperaturschwankungen, Platzmangel,
Massenfertigung) entwickelt.

---

## 1. DIN 72552 – Klemmenbezeichnung statt Aderfarbe

In der Hausinstallation identifiziert man Leiter primär über die
**Aderfarbe** nach IEC 60446 (Braun/Schwarz/Grau = Außenleiter, Blau = N,
Grün-Gelb = PE). Im Kfz-Bereich ist die **Klemmenbezeichnung nach DIN 72552**
das zentrale Ordnungsprinzip – eine Nummer, die die *Funktion* eines
Anschlusses beschreibt, unabhängig von der Leitungsfarbe:

| Klemme | Bedeutung |
|---|---|
| 30 | Dauerplus, direkt von der Batterie (Pluspol) |
| 31 | Masse/Rückleiter zur Batterie (Minuspol) |
| 15 | Geschaltetes Plus nach Zündschloss ("Zündungsplus") |
| 50 | Anlassersteuerung (Startsignal) |
| 58 | Beleuchtung (Standlicht) |

Ein Elektriker im Kfz-Bereich fragt also „Wo ist Klemme 15?", nicht „Wo ist
die schwarze Ader?" – ein grundlegend anderes Denkmodell als in der
Hausinstallation, wo die Funktion (Außenleiter/Neutralleiter/Schutzleiter)
gerade über die Farbe kodiert wird.

## 2. Leitungsfarben im KFZ: uneinheitlicher als im Haus

Anders als in der Hausinstallation gibt es im Kfz-Bereich **keine
verbindliche internationale Farbnorm** für die Funktion eines Leiters.
Jeder Hersteller pflegt eigene Kabelbaum-Farbschlüssel (oft dokumentiert in
herstellereigenen Schaltplänen), die sich zwischen Marken und sogar
zwischen Modellreihen desselben Herstellers unterscheiden können. Farbe
dient im Kfz also primär der **Wiedererkennung innerhalb eines konkreten
Schaltplans**, nicht der herstellerübergreifenden Funktionszuordnung wie
im Haus.

## 3. ISO 6722 – die Leitungsnorm

Während IEC 60446 (Hausinstallation) primär die Farbkennzeichnung regelt,
legt **ISO 6722** die technischen Eigenschaften von Fahrzeugleitungen fest:
Kupferlitzenaufbau (z.B. 7, 12, 16, 19, 24 oder 32 Einzeldrähte je nach
Querschnitt), Isolationsmaterial (häufig PVC oder das temperaturbeständigere
XLPE), Nenntemperaturbereich (typisch −40 °C bis 105 °C, für
motornahe Anwendungen auch höher) und Prüfverfahren u.a. für Brennbarkeit.
Bekannte Bezeichnung im Handel: **FLRY** (Fahrzeugleitung, PVC-isoliert,
105 °C) – die Leitungstype, die in nahezu jedem Kfz-Kabelbaum steckt.

**Wichtiger Unterschied zur Hausinstallation:** Kfz-Leitungen sind für
deutlich höhere Vibrationsbelastung und größere Temperaturschwankungen
ausgelegt, dafür meist mit dünneren Litzendrähten und geringerer
Isolationsdicke – ein Kfz-Kabel ist nicht 1:1 durch eine Hausinstallations-
leitung ersetzbar und umgekehrt.

## 4. Steckverbindersysteme

Anders als in der Hausinstallation mit ihren genormten Steckdosen/Klemmen
dominiert im Kfz eine Vielzahl herstellerspezifischer Steckverbindersysteme
(z.B. AMP/TE Connectivity, Bosch, Yazaki, Delphi) mit unterschiedlichen
Kontaktgrößen, Verrastungen und Dichtungskonzepten. Gemeinsame Merkmale:

- **Crimpkontakte** statt Schraubklemmen – vibrationsfest, für die
  Serienmontage mit Crimpzangen/-automaten ausgelegt
- **Sekundärverriegelung** (zusätzlicher Rasthaken/Clip) verhindert, dass
  sich ein einzelner Kontakt aus dem Gehäuse löst
- **Dichtungen** (Einzeladerdichtungen oder Gesamtdichtung) bei
  Steckern in feuchtigkeitsexponierten Bereichen (Motorraum, Unterboden)

## 5. Praxisrelevanz für Hobbyisten

Wer im Kfz-Bereich schraubt und aus der Hausinstallation kommt, sollte zwei
Denkfehler vermeiden:

- **Nicht die Aderfarbe als Funktionsindikator verwenden** wie in der
  Hausinstallation – ohne den herstellerspezifischen Schaltplan ist die
  Farbe im Kfz weitgehend bedeutungslos
- **Keine Hausinstallationsleitung im Kfz verwenden** (und umgekehrt) –
  unterschiedliche Vibrations-, Temperatur- und Isolationsanforderungen

---

## Quellen

- hoelzle.ch: [Ein kleiner (Ein-)Blick in die große, weite Welt der Fahrzeugleitungen](https://www.hoelzle.ch/posts/ein-kleiner-ein-blick-in-die-grosse-weite-welt-der-fahrzeugleitungen)
- Wikipedia: [Klemmenbezeichnung](https://de.wikipedia.org/wiki/Klemmenbezeichnung)
- kktt.de: [Klemmenbezeichnung nach DIN 72552 (PDF)](http://kktt.de/pdf/DIN%2072552.pdf)

*Hinweis: Herstellerspezifische Leitungsfarbschlüssel sind hier bewusst
nicht tabellarisch aufgeführt, da sie zwischen Marken/Modellreihen
divergieren – im Zweifel gilt immer der fahrzeugspezifische Schaltplan.*
