# Diagnose im Wandel: OBD → OBD-II/EOBD-Pflicht → Gateway-Steuergeräte

Fehlersuche im Auto bedeutete früher: Multimeter, Prüflampe, Schaltplan und
Erfahrung. Mit der On-Board-Diagnose kam ein völlig neues Werkzeug dazu –
und mit ihm eine gesetzliche Pflicht, die bis heute jedes neu zugelassene
Fahrzeug betrifft.

---

## 1. OBD-I: herstellerspezifische Anfänge

Erste On-Board-Diagnosesysteme (ab den 1980er-Jahren) waren rein
herstellerspezifisch: eigene Steckverbinder, eigene Protokolle, eigene
Fehlercodes. Ohne das passende (oft sehr teure) Herstellerdiagnosegerät war
eine elektronische Fehlerauslese praktisch unmöglich.

## 2. OBD-II / EOBD: die gesetzliche Vereinheitlichung

Der entscheidende Fortschritt war die **Standardisierung**: In den USA
wurde OBD-II verpflichtend, in Europa folgte das weitgehend baugleiche
**EOBD** (European On-Board Diagnostics), eingeführt über die
EU-Richtlinie 98/69/EG:

| Fahrzeugkategorie | EOBD-Pflicht ab |
|---|---|
| Benzin-PKW, neue Typen | 1. Januar 2000 |
| Benzin-PKW, alle Neuzulassungen | 1. Januar 2001 |
| Diesel-PKW, neue Typen | 1. Januar 2003 |
| Diesel-PKW, alle Neuzulassungen | 1. Januar 2004 |

(Gilt für Pkw der Kategorie M1 bis 2.500 kg Gesamtgewicht und max. 8
Fahrgastplätze.)

**Was EOBD konkret vorschreibt:**

- Einheitlicher **16-poliger OBD-Stecker** (SAE J1962), meist im
  Fußraum unter dem Lenkrad erreichbar
- Standardisierte **Fehlercodes** (z.B. P0301 = Zündaussetzer Zylinder 1) –
  herstellerübergreifend lesbar mit jedem generischen OBD-Diagnosegerät
- Kontinuierliche Überwachung abgasrelevanter Bauteile (u.a. Lambdasonde,
  Katalysator, Kraftstoffsystem) – bei Grenzwertüberschreitung leuchtet die
  Motorkontrollleuchte

## 3. Was OBD-II/EOBD *nicht* abdeckt

Wichtige Einschränkung für Hobbyisten: Die gesetzliche EOBD-Pflicht
beschränkt sich auf **abgasrelevante** Fehler. Komfort- und
Assistenzsysteme (Airbag, ABS, Klimaautomatik, Infotainment) sind zwar bei
den meisten Fahrzeugen ebenfalls über denselben OBD-Stecker erreichbar,
folgen dabei aber **herstellerspezifischen, nicht gesetzlich
standardisierten Protokollen** – ein generisches OBD-Lesegerät zeigt hier
oft nichts oder nur eingeschränkte Informationen an, während ein
Herstellertester (oder ein entsprechend lizenziertes Diagnosetool) den
vollen Funktionsumfang erschließt.

## 4. Gateway-Steuergeräte: der zentrale Vermittler

Mit zunehmender Bus-Vernetzung (→ Artikel „Bordnetz-Architektur")
kommunizieren Diagnosetester heute nicht mehr direkt mit jedem einzelnen
Steuergerät, sondern über ein **zentrales Gateway-Steuergerät**, das
zwischen den verschiedenen Bussegmenten (Motor-CAN, Komfort-CAN,
Infotainment-Bus) vermittelt und die Diagnoseanfrage an das richtige
Zielsteuergerät weiterleitet. Das Gateway ist damit auch ein zentraler
Sicherheitsknoten – moderne Fahrzeuge beschränken den Diagnosezugriff
zunehmend über Zugriffsschutz und Verschlüsselung, um unautorisierte
Manipulation über die OBD-Schnittstelle zu erschweren.

## 5. Praxis: was ein einfaches OBD-Lesegerät heute leistet

Für Hobbyisten gilt: Ein günstiges generisches OBD-II-Lesegerät reicht für
abgasrelevante Fehlercodes und die Basis-Motordiagnose (Live-Daten wie
Drehzahl, Kühlmitteltemperatur, Lambdawerte). Für Komfort-/
Assistenzsysteme, Codierungen oder tiefere Systemzugriffe ist meist ein
markenspezifisches oder professionelles Mehrmarken-Diagnosetool nötig.

---

## Quellen

- kfztech.de: [EOBD – Europäische On Board Diagnose / OBD](https://www.kfztech.de/kfztechnik/motor/abgas/eobd/eobd.htm)
- Wikipedia: [On-board diagnostics](https://en.wikipedia.org/wiki/On-board_diagnostics)
- OBD-2.net: [Ist mein Fahrzeug OBD-2 kompatibel?](https://www.obd-2.de/support/faqs/obd-2/51-ist-mein-fahrzeug-obd-2-kompatibel.html)

*Hinweis: Die genannten Stichtage gelten für die EU-Typzulassung/
-Neuzulassung von Pkw der Klasse M1 – für andere Fahrzeugklassen (Motorrad,
Nutzfahrzeug) und Länder außerhalb der EU gelten teils abweichende
Regelungen.*
