# Trennrelais und Ladebooster

Wie die Aufbaubatterie beim Fahren geladen wird, hat sich in den letzten
Jahren spürbar gewandelt – ausgelöst durch eine technische Entwicklung im
Fahrzeugbereich, die mit dem Wohnmobilausbau selbst gar nichts zu tun hat:
die intelligente Lichtmaschine.

---

## 1. Klassisches Trennrelais

Das klassische **Trennrelais** ist die einfachste Lösung: Sobald die
Lichtmaschine bei laufendem Motor eine Ladespannung liefert, schaltet das
Relais eine Verbindung zwischen Starter- und Aufbaubatterie durch – die
Aufbaubatterie wird direkt mit der Lichtmaschinenspannung geladen. Bei
stehendem Motor öffnet das Relais wieder, die Trennung ist wiederhergestellt.

**Voraussetzung, damit das funktioniert:** Die Lichtmaschine muss
durchgehend eine feste, ausreichend hohe Ladespannung liefern (klassisch
ca. 14,0–14,4 V) – bei älteren Fahrzeugen mit klassischem
Spannungsregler (→ Kategorie „KFZ-Elektrik im Wandel der Zeit", Artikel
„Vom Dynamo zur Lichtmaschine") der Normalfall.

## 2. Das Euro-6-Problem: intelligente Lichtmaschinen

Moderne Fahrzeuge (verbreitet seit Euro-6-Abgasnorm) nutzen aus
Kraftstoffeffizienzgründen **bedarfsgesteuerte Ladung (Smart Charging)**:
Die Lichtmaschine liefert nur noch so viel Ladestrom, wie die
Starterbatterie gerade tatsächlich braucht – ist diese voll, produziert
die Lichtmaschine bewusst **keinen unnötigen Ladestrom mehr** (weniger
Schleppmoment am Motor, geringerer Verbrauch). Für ein klassisches
Trennrelais bedeutet das: Es liegt oft gar keine ausreichende
Ladespannung mehr an, um die Aufbaubatterie über das Relais wirksam zu
laden – zusätzlich schwankt die Spannung ständig, was für die
Batterielebensdauer ungünstig ist.

## 3. Die Lösung: Ladebooster

Ein **Ladebooster** ist ein aktiver DC/DC-Wandler zwischen Starter- und
Aufbaubatterie: Er nimmt die (ggf. schwankende) Lichtmaschinenspannung auf
und erzeugt daraus eine **stabile, batterietypgerechte Ladekennlinie**
für die Aufbaubatterie (unterschiedliche Kennlinien für Blei-Gel, AGM oder
Lithium/LiFePO4 – → Artikel „Batterietechnik für Camper"). Bei Fahrzeugen
mit intelligenter Lichtmaschine muss der Ladebooster meist explizit auf
„Euro-6-Modus"/automatische Motorerkennung eingestellt werden, damit er
die schwankende Eingangsspannung korrekt erkennt und trotzdem zuverlässig
lädt.

## 4. Übersicht

| Merkmal | Trennrelais | Ladebooster |
|---|---|---|
| Funktionsprinzip | reine Schaltverbindung | aktiver DC/DC-Wandler mit eigener Ladekennlinie |
| Bei klassischer Lichtmaschine | funktioniert zuverlässig | funktioniert, aber meist unnötiger Mehraufwand |
| Bei intelligenter Lichtmaschine (Euro 6) | oft unzureichende Ladung | empfohlene Lösung |
| Kosten | günstig | deutlich teurer |
| Zusatzfunktion | keine | oft kombinierbar mit Solar-Eingang für Nachladung im Stand |

## 5. Praxisrelevanz

Vor dem Kauf/Einbau lohnt sich ein Blick ins Fahrzeug-Datenblatt oder
Herstellerforum: Ob ein einfaches Trennrelais ausreicht oder ein
Ladebooster nötig ist, hängt direkt davon ab, ob das Basisfahrzeug eine
klassische oder eine intelligente Lichtmaschine hat – ein häufiger
Fehlkauf bei Selbstausbauten ist ein zu einfaches Trennrelais an einem
modernen Euro-6-Fahrzeug, das die Aufbaubatterie dann dauerhaft nur
unzureichend lädt.

---

## Quellen

- womobox.de: [Ladebooster nachrüsten: Warum Euro-6-Fahrzeuge die Bordbatterie nicht voll laden](https://womobox.de/article/82-ladebooster-nachr%C3%BCsten-warum-euro-6-fahrzeuge-die-bordbatterie-nicht-voll-laden/)
- campofant: [Ladebooster oder Trennrelais im Wohnmobil?](https://campofant.com/ratgeber/ladebooster-trennrelais-wohnmobil/)
- Das Bordbuch: [Batterieladung trifft EURO 6](https://das-bordbuch.de/batterieladung-trifft-euro-6/)

*Hinweis: Ob ein Fahrzeug tatsächlich eine „intelligente" Lichtmaschine
hat, lässt sich nicht pauschal an der Euro-6-Norm allein festmachen –
im Zweifel beim Basisfahrzeughersteller oder im Wohnmobil-Fachforum für
das konkrete Modell nachfragen.*
