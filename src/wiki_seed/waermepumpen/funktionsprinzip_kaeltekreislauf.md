# Funktionsprinzip – Der Kompressions-Kältekreislauf

Eine Wärmepumpe "erzeugt" keine Wärme, sie **verschiebt** sie – von einem
kälteren zu einem wärmeren Ort, unter Einsatz von elektrischer Antriebsenergie
für einen Verdichter. Das physikalische Prinzip ist ein knapp 200 Jahre altes
Erbe der Kältetechnik (Kühlschrank und Klimaanlage arbeiten nach demselben
Kreisprozess, nur mit vertauschter Nutzrichtung) und heute die Grundlage fast
aller marktüblichen Heizwärmepumpen.

---

## 1. Die vier Grundkomponenten

```
        Wärmequelle (Luft/Sole/Wasser)
              │
              ▼
      ┌───────────────┐
      │   Verdampfer   │  Kältemittel verdampft bei niedrigem Druck,
      └───────┬───────┘  nimmt Wärme aus der Quelle auf
              │ (kalt, gasförmig, Niederdruck)
              ▼
      ┌───────────────┐
      │   Verdichter   │  Kältemittel wird komprimiert →
      │  (Kompressor)  │  Druck UND Temperatur steigen stark an
      └───────┬───────┘  (elektrische Antriebsenergie wird hier zugeführt)
              │ (heiß, gasförmig, Hochdruck)
              ▼
      ┌───────────────┐
      │  Verflüssiger  │  Kältemittel kondensiert, gibt Wärme an
      │  (Kondensator) │  Heizwasser/Raumluft ab
      └───────┬───────┘
              │ (warm, flüssig, Hochdruck)
              ▼
      ┌───────────────┐
      │ Expansionsventil│ Druck fällt schlagartig ab →
      └───────┬───────┘  Kältemittel kühlt stark ab
              │ (kalt, flüssig, Niederdruck)
              └──────────► zurück zum Verdampfer
```

- **Verdampfer** – nimmt Umweltwärme auf, auch bei niedrigen Außentemperaturen
  (das Kältemittel siedet bereits bei sehr tiefen Temperaturen)
- **Verdichter** – einzige Komponente mit nennenswertem Strombedarf; verdichtet
  das gasförmige Kältemittel, wodurch Druck und Temperatur steigen
  (physikalisch: adiabatische Kompression)
- **Verflüssiger** – gibt die im Kältemittel gespeicherte Wärme an das
  Heizsystem ab, das Kältemittel wird dabei wieder flüssig
- **Expansionsventil** – entspannt das flüssige Kältemittel wieder auf
  Niederdruck, schließt den Kreislauf

## 2. Warum das effizient ist

Ein Verdichter mit 1 kW elektrischer Aufnahmeleistung kann typischerweise
3–5 kW Wärmeleistung liefern – die Differenz stammt nicht "aus dem Nichts",
sondern aus der kostenlos verfügbaren Umweltwärme (Luft, Erdreich,
Grundwasser), die dem Kältemittel im Verdampfer entzogen wird. Das
Verhältnis aus abgegebener Wärmeleistung zu aufgenommener elektrischer
Leistung wird als **COP** bezeichnet (→ Artikel „Kennzahlen: COP, JAZ und
Bivalenzpunkt").

## 3. Reversibilität

Der komplette Kreisprozess lässt sich mit einem **Umkehrventil (4-Wege-Ventil)**
in seiner Fließrichtung umdrehen: Aus dem Verflüssiger wird der Verdampfer und
umgekehrt. Genau dieses Prinzip macht aus einer Klimaanlage im Sommer ein
Heizgerät im Winter – die Bauteile bleiben identisch, nur der Kältemittelfluss
wird umgekehrt gesteuert. Diese Reversibilität ist die technische Grundlage
für Luft-Luft-Wärmepumpen und für den weltweiten Siegeszug reversibler
Klimasplitgeräte (→ Artikel „Wärmepumpen weltweit im Vergleich").

## 4. Verdichterarten

| Verdichtertyp | Typischer Einsatz | Besonderheit |
|---|---|---|
| Scroll-Verdichter | Standard bei Luft-Wasser-WP im EFH-Bereich | robust, leise, wartungsarm |
| Rotationskolbenverdichter | kompakte Split-/Multisplit-Geräte | sehr kompakte Bauform |
| Inverter-Verdichter (drehzahlgeregelt) | praktisch alle modernen Geräte | passt Leistung stufenlos an Bedarf an, vermeidet Takten |

Inverter-Technik (drehzahlgeregelter Verdichter statt reinem Ein/Aus-Betrieb)
ist heute Serienstandard und war ursprünglich eine japanische Entwicklung
(Mitsubishi Electric brachte 1959 den ersten Mini-Split auf den Markt) –
Details zur historischen Entwicklung → Artikel „Wärmepumpen weltweit im
Vergleich".

---

## Quellen

- Mitsubishi Electric HVAC US: [Explainer – What's the History of All-Climate Heat Pumps?](https://www.mitsubishicomfort.com/articles/history-variable-capacity-heat-pumps)
- Bundesverband Wärmepumpe (BWP) e.V.: [waermepumpe.de – Funktionsweise](https://www.waermepumpe.de/)
- THPE: [The history of heat pumps, air conditioning, and refrigeration](https://www.thpe.co.uk/history-of-heat-pumps)

*Hinweis: Das Grundprinzip ist herstellerunabhängig; Detailausführungen
(Verdichtertyp, Kältemittel, Regelungstechnik) unterscheiden sich je nach
Fabrikat und Baujahr.*
