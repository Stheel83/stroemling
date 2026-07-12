# Bordnetz-Grundlagen: Starterbatterie vs. Aufbaubatterie

Der wichtigste konzeptionelle Unterschied zwischen einem normalen PKW und
einem Wohnmobil/Camper: Es gibt **zwei getrennte Batteriekreise** mit
unterschiedlicher Aufgabe – und wer diese Trennung nicht versteht, riskiert
im schlimmsten Fall, mit leerer Starterbatterie liegenzubleiben.

---

## 1. Warum zwei Batterien?

Die **Starterbatterie** ist für den Motorstart und das Fahrzeugbordnetz
zuständig (Zündung, Steuergeräte, Fahrlicht) – exakt dieselbe Funktion wie
in jedem normalen PKW (→ Kategorie „KFZ-Elektrik im Wandel der Zeit").

Die **Aufbaubatterie** (auch Versorgerbatterie oder Bordbatterie genannt)
versorgt ausschließlich die Wohnraum-Verbraucher: Beleuchtung im
Innenraum, Kühlbox/Kompressorkühlschrank, Wasserpumpe, USB-Lader, ggf.
Standheizung-Steuerung. Sie ist bewusst **elektrisch getrennt** von der
Starterbatterie.

## 2. Warum die Trennung zwingend nötig ist

Ohne Trennung würde ein Abend mit eingeschalteter Innenbeleuchtung und
laufendem Kühlschrank die Starterbatterie mit entladen – am nächsten
Morgen bleibt das Fahrzeug liegen. Die Trennung stellt sicher, dass die
Wohnraum-Verbraucher die Starterbatterie **niemals** entladen können,
selbst wenn die Aufbaubatterie komplett leer gefahren wird.

## 3. Wie die Trennung technisch umgesetzt wird

Zwei grundsätzliche Ansätze, im Detail → Artikel „Trennrelais und
Ladebooster":

- **Trennrelais** – schaltet die Verbindung zwischen beiden Batterien nur
  bei laufendem Motor (Lichtmaschine liefert Ladespannung), trennt bei
  stehendem Motor automatisch
- **Ladebooster** – ein aktiver DC/DC-Wandler, der die Aufbaubatterie mit
  einer eigenen, batterietypgerechten Ladekennlinie versorgt, unabhängig
  von der genauen Lichtmaschinenspannung

## 4. Dimensionierung der Aufbaubatterie

Die passende Kapazität hängt vom Nutzungsprofil ab:

- **Wochenendcamper mit Campingplatz-Landstrom** – kleinere Kapazität
  ausreichend, da regelmäßig nachgeladen wird
  (Landstrom-Details → Artikel „230V an Bord")
- **Autarkes Reisen ohne Landstrom** (Stellplatz, wilde Übernachtung) –
  deutlich größere Kapazität nötig, meist kombiniert mit Solaranlage
  (→ eigener Artikel)
- **Kompressorkühlschrank statt Absorberkühlschrank** – deutlich höherer
  Dauerverbrauch als ein klassischer Gas-/230V-Absorberkühlschrank,
  beeinflusst die nötige Batteriekapazität erheblich

## 5. Praxishinweis

Eine häufige Fehlerquelle bei Selbstumbauten: Die Aufbaubatterie wird zwar
korrekt getrennt verbaut, aber **ohne eigene, batterienahe Sicherung**
angeschlossen – ein direkter Kurzschluss in der Verbraucherverkabelung
kann dann ungebremst die volle Batterieleistung freisetzen (→ Kategorie
„KFZ-Elektrik im Wandel der Zeit", Artikel „Sicherungstechnik im KFZ" für
das Grundprinzip, hier vertieft im Artikel „Sicherungstechnik im
Wohnmobil").

---

## Quellen

- AMUMOT: [Ladebooster vs. Trennrelais im Wohnmobil](https://www.amumot-shop.de/ratgeber/ladebooster-trennrelais-wohnmobil)
- BärenSquad: [Ladebooster im Wohnmobil einbauen](https://www.baerensquad.de/ladebooster-einbauanleitung-camper/)

*Hinweis: Dieser Artikel beschreibt das Grundprinzip herstellerunabhängig
– konkrete Kapazitäts- und Verkabelungsempfehlungen hängen stark vom
individuellen Nutzungsprofil ab.*
