# Wärmepumpe im Bestandsgebäude mit Heizkörpern

Die häufigste Sorge bei der Umrüstung eines Altbaus: "Reichen die
vorhandenen Heizkörper überhaupt für eine Wärmepumpe?" Die kurze Antwort:
oft ja — aber nicht automatisch, und die Regelungstechnik funktioniert
anders, als viele es von der alten Öl-/Gasheizung gewohnt sind.

---

## 1. Grundproblem: Auslegungstemperatur

Als Faustregel gilt: Eine Wärmepumpe arbeitet wirtschaftlich sinnvoll, wenn
die Vorlauftemperatur ganzjährig **unter 55 °C** bleibt. Klassische
Rippenheizkörper aus den 1960er–1980er-Jahren wurden meist für
70–90 °C Vorlauf ausgelegt und liefern bei niedrigeren Temperaturen nur
einen Bruchteil ihrer Nennleistung:

| Vorlauftemperatur | Leistung klassischer Rippenheizkörper (ca.) |
|:---:|:---:|
| 35 °C | 30–40 % der Nennleistung |
| 45 °C | 50–60 % der Nennleistung |
| 55 °C | deutlich näher an Nennleistung |

Gleichzeitig gilt für die Effizienz der Wärmepumpe selbst: **jede
Absenkung der Vorlauftemperatur um 5 °C verbessert die JAZ um etwa
10 %** (→ Artikel „Kennzahlen: COP, JAZ und Bivalenzpunkt"). Eine
Wärmepumpe mit JAZ 4 bei 35 °C Vorlauf käme bei 55 °C rechnerisch nur
noch auf etwa JAZ 2,5 — der Zielkonflikt zwischen "Heizkörper brauchen
Temperatur" und "Wärmepumpe will möglichst wenig Temperatur" ist der Kern
jeder Bestandsplanung.

## 2. Praxis-Check: reichen die vorhandenen Heizkörper?

Ein gängiger Praxistest vor größeren Umbaumaßnahmen: An einem kalten
Wintertag die Vorlauftemperatur testweise auf 50–55 °C absenken und alle
Thermostatventile voll aufdrehen. Bleibt die Raumtemperatur komfortabel,
funktionieren die bestehenden Heizkörper auch mit der Wärmepumpe. Kühlt
der Raum spürbar aus, ist ein Heizkörpertausch oder eine Ergänzung der
Heizfläche in genau diesem Raum nötig — meist reicht ein Austausch der
kritischen Einzelräume, selten das ganze Gebäude.

## 3. Braucht man eine Temperaturmessung in jedem Raum? — Nein

Eine Wärmepumpe regelt im Regelfall **witterungsgeführt**: Ein
Außentemperaturfühler plus die eingestellte Heizkurve
(→ Artikel „Wärmepumpe richtig einstellen") bestimmen die
Vorlauftemperatur zentral, unabhängig vom Zustand einzelner Räume. Eine
raumweise Temperaturmessung ist dafür **nicht erforderlich**.

Optional lässt sich ein einzelner **Referenzraum-Fühler** einbinden, der
die zentrale Heizkurve fein nachkorrigiert (raumtemperaturgeführte
Zusatzkorrektur, kein Ersatz der Heizkurve). Wichtig bei der Auswahl:
der Referenzraum muss **möglichst repräsentativ und störungsfrei** sein.
Wohnzimmer mit Kaminofen oder Küche mit Herdabwärme gelten in der
Fachpraxis als denkbar schlechteste Wahl, da Fremdwärmequellen die
Regelung verfälschen — ein Flur oder ein wenig genutzter Raum ohne
zusätzliche Wärmequellen eignet sich deutlich besser.

## 4. Heizkreise und Mischer

Bei einem einzigen Heizkörper-Kreis (keine parallele Fußbodenheizung)
ist in der Regel **kein Mischer** nötig — die Wärmepumpe liefert die
benötigte Vorlauftemperatur direkt modulierend nach Heizkurve. Ein
Mischer wird erst notwendig, wenn **zwei Kreise mit unterschiedlichem
Temperaturniveau** gleichzeitig versorgt werden (z. B. Heizkörper im
Altbauteil + Fußbodenheizung im Anbau): Der Niedertemperatur-Kreis
bekommt dann einen eigenen Mischer mit eigener Pumpe, während die
Wärmepumpe die höhere Temperatur für die Heizkörperseite bereitstellt.

## 5. Müssen die Thermostatventile abgenommen werden? — Nein, nicht pauschal

Das eigentliche technische Problem heißt **Mindestvolumenstrom**
(→ Artikel „Hydraulik-Grundlagen"), nicht "die Regelung verträgt keine
Thermostate". Schließen viele Thermostatventile gleichzeitig (mildes
Wetter, mehrere Räume bereits warm genug), kann der Volumenstrom durch
die Wärmepumpe unter den technisch nötigen Mindestwert fallen. Drei
gängige Lösungsansätze, oft kombiniert:

1. **Pumpe im Δp-v-Modus** (differenzdruck-variabel/proportional) — die
   Heizungspumpe passt ihre Förderleistung automatisch an, wie viele
   Ventile gerade geöffnet sind
2. **Überströmventil am Verteiler** — öffnet, sobald viele
   Thermostatventile schließen, und leitet überschüssigen Vorlauf in den
   Rücklauf zurück. **Vorsicht bei der Platzierung:** sitzt das Ventil zu
   nah am Wärmeerzeuger bzw. öffnet zu früh, entsteht ein thermischer
   Kurzschluss — warmes Wasser läuft direkt in den Rücklauf, ohne über
   die Heizflächen abzukühlen. Das erhöht die Rücklauftemperatur der
   Wärmepumpe unnötig und verschlechtert die Effizienz. Empfehlung aus
   der Fachpraxis: Ventil möglichst am Ende der längsten Heizkreis-
   Strangleitung platzieren, nicht direkt am Wärmeerzeuger
3. **Pufferspeicher/hydraulische Weiche** — vollständig entkoppelte
   Lösung, unabhängig von der Ventilstellung im Heizkreis

Eine ältere, in Foren verbreitete "Notlösung" ist, an **ein bis zwei
Leit-Heizkörpern** (häufig Flur oder Bad) das Thermostatventil zu
entfernen oder dauerhaft voll zu öffnen, damit dieser Kreis nie
vollständig schließt und so ein Mindestdurchfluss garantiert bleibt. Das
ist ein möglicher Kompromiss, **kein zwingender Standard** — mit
korrekt ausgelegtem Überströmventil oder Δp-v-Pumpe ist ein komplettes
Abnehmen aller Thermostatventile nicht nötig und würde zudem die
raumweise Komfortregelung zunichtemachen, die Thermostatventile gerade
leisten sollen.

## 6. Was stattdessen wirklich gemacht werden muss

Statt Temperaturmessung je Raum braucht es eine **einmalige, raumweise
Heizlastberechnung** (hydraulischer Abgleich Verfahren B, → Artikel
„Wärmepumpe richtig einstellen"): Der Installateur berechnet den
Wärmebedarf jedes Raums und stellt die **voreinstellbaren
Thermostatventile** entsprechend ein. Das ist eine einmalige Berechnung
und Einstellung — keine laufende Raummessung —, aber Grundvoraussetzung
dafür, dass eine niedrige, effiziente Vorlauftemperatur überall im
Gebäude ausreicht.

## 7. Zusammenfassung

| Frage | Antwort |
|---|---|
| Temperaturmessung in jedem Raum nötig? | Nein — witterungsgeführt über einen zentralen Außenfühler, optional ein Referenzraum-Fühler |
| Mischer für jeden Heizkreis nötig? | Nur bei mehreren Kreisen mit unterschiedlichem Temperaturniveau |
| Alle Thermostatventile abnehmen? | Nein — Mindestvolumenstrom über Δp-v-Pumpe/Überströmventil/Puffer lösen, Thermostate bleiben aktiv |
| Heizkörpertausch immer nötig? | Nein — Praxistest (50–55 °C, Ventile voll auf) zeigt, ob einzelne Räume nachgerüstet werden müssen |

---

## Quellen

- Selbst.de: [Wärmepumpe im Altbau: Heizkörpertausch und Vorlauftemperaturen](https://www.selbst.de/waermepumpe-im-altbau-heizkoerpertausch-und-vorlauftemperaturen-79107.html)
- 42watt: [Heizkörper für Wärmepumpen: Niedertemperatur-Systeme für maximale Effizienz im Altbau](https://42watt.de/magazin/heizkorper-fur-warmepumpen)
- energie-experten.org: [Wärmepumpe mit Heizkörper betreiben: So geht's!](https://www.energie-experten.org/heizung/waermepumpe/waermepumpenheizung/heizkoerper)
- Umweltbundesamt: [Lösungsoptionen für Wärmepumpen in Bestandsgebäuden](https://www.umweltbundesamt.de/sites/default/files/medien/11740/publikationen/2023-05-25_factsheet_loesungsoptionen_waermepumpen_gebaeudebestand.pdf)
- bautipps24.de: [Wärmepumpe nachträglich an bestehende Heizkreise anbinden und optimal nutzen](https://www.bautipps24.de/waermepumpe-nachtraeglich-an-bestehende-heizkreise-anbinden/)
- bautipps24.de: [Überströmventil in der Heizungsanlage – Probleme bei Wärmepumpen](https://www.bautipps24.de/ueberstroemventil-waermepumpen-probleme/)
- Klimeo: [Überströmventil der Wärmepumpe einstellen und Druckprobleme vermeiden](https://www.klimeo.de/waermepumpe/wissen/funktionen-und-anwendung/ueberstroemventil-der-waermepumpe-einstellen-und-druckprobleme-vermeiden)
- xpora.de: [Mischer Heizkreisverteiler Wärmepumpe – Praxis](https://xpora.de/ratgeber/hydraulik/mischer-und-verteiler)

*Hinweis: Alle Faustregeln (55 °C-Grenze, JAZ-Verbesserung je 5 °C,
Leistungswerte klassischer Rippenheizkörper) sind Orientierungswerte aus
der Fachpraxis — die tatsächliche Eignung eines konkreten Gebäudes
ergibt sich immer aus der individuellen Heizlastberechnung.*
