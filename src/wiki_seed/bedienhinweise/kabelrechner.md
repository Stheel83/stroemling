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
