# Notheizstab – Auslegung, Absicherung, Redundanzkonzept

Der elektrische Heizstab ist die häufigste Zusatzheizquelle bei
Wärmepumpen – nicht nur als Redundanz für den Störfall, sondern auch als
regulärer Baustein monoenergetischer Betriebskonzepte
(→ Artikel „Kennzahlen: COP, JAZ und Bivalenzpunkt").

---

## 1. Einsatzzwecke

Ein Elektroheizstab im Pufferspeicher/Warmwasserspeicher der Wärmepumpe
übernimmt typischerweise vier Aufgaben:

1. **Spitzenlastabdeckung** bei sehr niedrigen Außentemperaturen, unterhalb
   des Bivalenzpunkts
2. **Gebäudetrocknung** im Neubau (hoher, kurzfristiger Wärmebedarf, für
   den die Wärmepumpe allein nicht ausgelegt ist)
3. **Thermische Desinfektion** des Trinkwarmwasserspeichers (Legionellen­
   schutz, periodisches Aufheizen über 60 °C – ein Temperaturniveau, das
   die Wärmepumpe allein oft nicht wirtschaftlich erreicht)
4. **Notbetrieb** bei Störung/Ausfall des Verdichters – Übergangslösung bis
   zur Reparatur

## 2. Typische Leistungsauslegung

Die Heizstab-Leistung liegt üblicherweise bei etwa **50–60 % der
Nennheizleistung** der Wärmepumpe. Für Einfamilienhäuser sind
Heizstab-Leistungen von **2–10 kW** üblich:

| Heizstab-Leistung | Anschlussspannung |
|---|---|
| bis ca. 3 kW | 230 V (einphasig) |
| über ca. 3 kW | 400 V (dreiphasig) |

Bei Sole-/Wasser-Wärmepumpen (deutlich seltener im Bivalenzbetrieb, da
Erdreich-/Grundwassertemperatur ganzjährig ausreichend konstant ist)
dient der Heizstab meist ausschließlich als Störungs-Redundanz, nicht als
regulärer Spitzenlastdecker.

## 3. Absicherung und Verdrahtung

- Der Heizstab wird häufig als **eigener Stromkreis** mit eigener
  Absicherung ausgeführt, unabhängig von der Verdichter-Zuleitung – das
  ermöglicht Wartung/Austausch eines Teilsystems ohne kompletten Ausfall
  der Notheizfunktion
- Bei mehrstufigen Heizstäben (z. B. 3 × 3 kW schaltbar) übernimmt die
  interne Wärmepumpenregelung meist die stufenweise Zuschaltung – die
  Elektroplanung muss dennoch die volle Anschlussleistung aller Stufen
  gleichzeitig berücksichtigen (worst case: alle Stufen aktiv)
- Als steuerbare Zusatzheizeinrichtung fällt der Heizstab ebenfalls unter
  die §14a-EnWG-Regelung (→ Artikel „§14a EnWG"), da er im selben
  Netzanschlusspunkt hängt

## 4. Redundanzkonzept in der Praxis

Ein sauberes Redundanzkonzept sieht vor, dass der Heizstab **automatisch**
und ohne Nutzereingriff einspringt, sobald die Wärmepumpensteuerung einen
Verdichterfehler erkennt (Notbetrieb/Störmeldung) – dieser Automatismus
ist Teil der Wärmepumpen-eigenen Regelungslogik, nicht der Elektroplanung
selbst, muss aber bei der Dimensionierung der Zuleitung berücksichtigt
werden (voller Notheizstab-Betrieb kann parallel zu anderen Haushalts­
lasten auftreten).

---

## Quellen

- energie-experten.org: [Heizstab der Wärmepumpe: Technik, Einsatz & Kosten](https://www.energie-experten.org/heizung/waermepumpe/technik/heizstab)
- thermondo: [Heizstab der Wärmepumpe: Wie funktioniert die elektrische Heizungsunterstützung?](https://www.thermondo.de/info/rat/waermepumpe/heizstab/)
- Green Planet Energy: [Was bewirkt der Heizstab einer Wärmepumpe?](https://green-planet-energy.de/blog/waerme/waermepumpen-blogserie-was-bewirken-heizstaebe)
- Tecalor: [Notbetrieb Wärmepumpe: Elektrische Überbrückung bei Störungen](https://waermepumpe.tecalor.de/de/blog/waermepumpe-lexikon/notbetrieb.html)

*Hinweis: Exakte Heizstab-Leistung, Stufenlogik und Absicherungswerte sind
gerätespezifisch – maßgeblich ist stets das Elektroschema des jeweiligen
Herstellers.*
