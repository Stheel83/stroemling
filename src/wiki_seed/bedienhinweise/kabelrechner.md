# Kabelrechner

Der Kabelrechner berechnet den **empfohlenen Mindestquerschnitt** einer Leitung
angelehnt an VDE 0298-4. Das Ergebnis ist eine Orientierungshilfe, kein zertifizierter Normwert.

## Eingaben

| Feld | Bedeutung |
|------|-----------|
| Strom (A) | Betriebsstrom der Leitung |
| Länge (m) | einfache Leitungslänge |
| Spannung (V) | Nennspannung (typisch 230 V oder 400 V) |
| cos φ | Leistungsfaktor (1,0 für ohmsche Last) |
| ΔU max (%) | maximal zulässiger Spannungsfall, siehe unten |
| Verlegeart | Freie Luft, Rohr, Wand usw. |
| Häufung | Anzahl gebündelter Leitungen |

## Ergebnis

Der Rechner gibt den **empfohlenen Querschnitt** in mm² aus und zeigt
den berechneten Spannungsfall.

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

Der Grenzwert für den Spannungsfall ist im Genau-Modus einstellbar
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
