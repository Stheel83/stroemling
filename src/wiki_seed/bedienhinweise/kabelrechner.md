# Kabelrechner

Der Kabelrechner berechnet den **empfohlenen Mindestquerschnitt** einer Leitung
angelehnt an VDE 0298-4. Das Ergebnis ist eine Orientierungshilfe, kein zertifizierter Normwert.

## Schnellstart mit Anwendungsfall-Vorlagen

Das Dropdown **Anwendung** oben im Eingabebereich füllt die Felder mit
praxisüblichen Werten vor. „Eigene Eingabe" bedeutet: nichts vorbelegt.
Nach der Auswahl auf **Berechnen** klicken – der Rechner prüft die
Vorlage immer vollständig nach Spannungsfall, Thermik und Abschaltbedingung.

| Gruppe | Vorlagen |
|---|---|
| Haushalt / Gebäude | Lichtkreis 10 A · Steckdosenkreis 16 A · Waschmaschine/Trockner 16 A · Herd/Backofen 3~ 16 A · Durchlauferhitzer 3~ 32 A · Wallbox 11 kW · Unterverteilung 3~ 32 A |
| Werkstatt | CEE-Steckdose 16 A (3~) · CEE-Steckdose 32 A (3~) |
| Motoren | Drehstrommotor 0,75 / 2,2 / 5,5 / 11 / 22 kW |
| Gleichspannung | Bordnetz 12 V (10 A) · Kühlbox/Pumpe 12 V (5 A) · Steuerstromkreis 24 V (5 A) |

> **Wichtig:** Leitungslänge, Strom und Verlegeart in den Vorlagen sind
> **typische Annahmen**. Passen sie nicht zu deiner Anlage, einfach das Feld
> ändern (die Auswahl springt dann auf „Eigene Eingabe"). Bei Motoren die
> Werte vom **Typenschild** eintragen (Nennstrom, cos φ).

## Eingaben

| Feld | Bedeutung |
|------|-----------|
| Betriebsart | AC einphasig (230 V), Drehstrom (400 V) oder DC |
| Strom (A) | Betriebsstrom der Leitung |
| Spannung (V) | Nennspannung |
| cos φ | Leistungsfaktor (1,0 für ohmsche Last) – nicht bei DC |
| ΔU max (%) | maximal zulässiger Spannungsfall, siehe unten |
| Länge (m) | einfache Leitungslänge |
| Material | Kupfer oder Aluminium |
| Verlegeart | A1 – G nach DIN VDE 0298-4, siehe unten |
| Temperatur / Häufung | Umgebungstemperatur, Anzahl gebündelter Leitungen |
| Schutzorgan Typ / I_n | LS-Charakteristik (B, C, D) und Nennstrom, für die Abschaltbedingung |
| R_netz (Ω) | Netzimpedanz am Einspeisepunkt, Standard 0,30 Ω (Annahme, siehe unten) |

### Verlegearten

| Kürzel | Verlegung |
|---|---|
| A1 / A2 | Aderleitung bzw. mehradriges Kabel im Rohr in wärmegedämmter Wand |
| B1 / B2 | Aderleitung bzw. mehradriges Kabel im Rohr auf einer Wand |
| C | Ein- oder mehradriges Kabel direkt auf einer Wand |
| D | Mehradriges Kabel im Rohr oder Kabelschacht im Erdboden |
| E | Mehradriges Kabel frei in Luft (Wandabstand ≥ 0,3 · d) |
| F | Einadrige Kabel mit Berührung frei in Luft – erst ab 25 mm² |
| G | Einadrige Kabel mit Abstand d frei in Luft – erst ab 25 mm² |

## Ergebnis

Der Rechner gibt den **empfohlenen Querschnitt** in mm² aus. Darunter
zeigen die **Berechnungsdetails**, welches Kriterium den Querschnitt bestimmt:

- **Spannungsfall** – ΔU in % beim Normquerschnitt
- **Thermik** – Strombelastbarkeit I_z nach Verlegeart, Temperatur und Häufung
- **Kurzschluss** (Abschaltbedingung, nur AC/Drehstrom) – erreichbarer
  Kurzschlussstrom I_k gegen den Auslösestrom des Schutzorgans

Der größte der drei Mindestquerschnitte gewinnt.

### Wenn kein Normquerschnitt reicht

Verlangt eines der Kriterien mehr als 50 mm² (der Rechner kennt Querschnitte bis
50 mm², Kupfer), steht dort **„Kein Normquerschnitt ausreichend"** mit dem
tatsächlichen Bedarf. Typische Auswege: Leitung kürzen, höhere Spannung,
ΔU-Grenze prüfen (nur wenn zulässig) oder Parallelverlegung. Bei Aluminium mit
Verlegeart F/G sind keine Belastbarkeitswerte hinterlegt – dort kommt
„Keine Empfehlung möglich".

### Abschaltbedingung und Netzimpedanz

Der Kurzschlussstrom am Leitungsende hängt auch vom Netz davor ab. Der Rechner
nimmt dafür standardmäßig **0,30 Ω** an – das ist eine **Annahme, kein Normwert**.
Näher am Transformator ist die Impedanz kleiner, und große Schutzorgane
(z. B. D-Charakteristik, hohe Nennströme) lassen sich eher abschalten.
Wer die Schleifenimpedanz am Einspeisepunkt gemessen hat, trägt den Messwert
unter **R_netz** ein. Bei Drehstrom wird mit der Leiter-Erde-Spannung
(400 V / √3 ≈ 231 V) gerechnet.

## Leistungsfaktor cos φ – Richtwerte

`cos φ` beschreibt, wie stark Strom und Spannung zeitlich gegeneinander
verschoben sind. Für die Querschnittsermittlung zählt nur der **Betrag**
`|cos φ|` – ob die Last induktiv (Strom eilt nach) oder kapazitiv (Strom
eilt vor) ist, ändert am Ergebnis nichts, weil die Formel nur den ohmschen
Spannungsfall-Anteil (Wirkwiderstand) berücksichtigt, nicht den
Blindanteil (Reaktanz). Bei sehr langen Leitungen mit stark induktiver
Last (z. B. Motoranlauf) kann der reale Spannungsfall dadurch etwas höher
liegen als berechnet.

| Verbraucher | cos φ | Charakter |
|---|---|---|
| Ohmsche Last (Heizung, Glühlampe, Kochplatte) | 1,0 | – |
| Asynchronmotor, Volllast | 0,80–0,85 | induktiv (nacheilend) |
| Asynchronmotor, Teillast/Leerlauf | 0,5–0,7 | induktiv (nacheilend) |
| Schweißtransformator | 0,5–0,6 | induktiv (nacheilend) |
| Leuchtstofflampe, unkompensiert (KVG) | ~0,5 | induktiv (nacheilend) |
| Leuchtstofflampe, kompensiert | ~0,9 | leicht kapazitiv (voreilend) |
| LED-/Schaltnetzteil ohne aktive PFC | 0,5–0,7 | kapazitiv verzerrt (voreilend, oberwellenbehaftet) |
| LED-/Schaltnetzteil mit aktiver PFC | > 0,95 | nahezu ohmsch |
| Kondensator / Blindleistungskompensation | – | rein kapazitiv (voreilend) |

> **Praxis-Hinweis:** Ohne Herstellerangabe (Typenschild, Datenblatt) sind
> obige Werte grobe Richtwerte. Bei Motoren steht der genaue cos φ meist
> auf dem Typenschild (siehe auch Wiki-Artikel „Drehstrommotor").

## Zulässiger Spannungsfall ΔU max

Der Grenzwert für den Spannungsfall ist einstellbar
(Standard: 3 %). Er stammt nicht aus einer starren Gesetzesvorgabe, sondern
aus dem **informativen Anhang von DIN VDE 0100-520** (angelehnt an
IEC 60364-5-52, Anhang B) – einer **Empfehlung**, kein zwingender Normwert:

| Anwendung | empfohlenes ΔU max |
|---|---|
| Beleuchtung | 3 % |
| sonstige Verbraucher (Steckdosen, Heizung, Motoren) | 5 % |

gemessen vom Anlagenübergabepunkt (Hausanschluss/Hauptverteilung) bis zum
Verbraucher. Der Rechner setzt standardmäßig den strengeren Wert (3 %) an;
für weniger spannungsempfindliche Stromkreise kann auf 5 % erhöht werden,
für besonders empfindliche Lasten (langer Motoranlauf, Elektronik) sind
auch kleinere Werte sinnvoll.

> **Hinweis:** Das Ergebnis ersetzt keine normgerechte Planung nach
> DIN VDE 0100. Bei sicherheitsrelevanten Anlagen immer einen
> Fachplaner hinzuziehen.
