# Kuriosum: 3-adrig verdrahtet, aber klassisch genullt

Ein Phänomen an einzelnen Steckdosen im DDR-Altbestand, das auf den
ersten Blick wie eine korrekte TN-S-Installation aussieht: **drei
Adern liegen an der Dose an, aber die blaue (N-)Ader wird gar nicht
genutzt.** Stattdessen wird die grün-gelbe PE-Ader auf besondere
Weise verdrahtet: sie wird **länger als üblich abisoliert**, mit dem
einen Ende in den PE-Kontakt und mit dem restlichen, langen Ende in
die N-Klemme geklemmt — ein und dieselbe Ader steckt durchgehend in
beiden Klemmen. Eine separate Drahtbrücke wird dafür nicht benötigt.
Klassische Nullung, lokal an der Steckdose nachgebaut, obwohl das
Kabel eigentlich dreiadrig ist.

> **Quellen:** Wikipedia [Nullung](https://de.wikipedia.org/wiki/Nullung),
> [TN-Netz](https://de.wikipedia.org/wiki/TN-Netz) — für den
> allgemeinen Hintergrund zu klassischer Nullung. **Die hier
> beschriebene Verdrahtungsvariante selbst ist Praxis-/Felderfahrung
> und in keiner der beiden Quellen dokumentiert** — es handelt sich
> um eine im Feld beobachtete Verdrahtungsgewohnheit, keine belegte
> Norm oder Fachliteratur-Aussage.

---

## Was wird vorgefunden?

```
Kabel mit 3 Adern läuft bis zur Steckdose:
  schwarz     (L)   ──────────────► L-Klemme
  hellblau    (N)   ── unbenutzt, nicht angeklemmt
  grün-gelb   (PE)  ──► lang abisoliert, ein Ende in PE-Kontakt,
                        das andere (lange) Ende in N-Klemme
```

Die blaue Ader liegt zwar physisch im Kabel bzw. Rohr vor, wird aber
**weder am Verteiler noch an der Dose angeklemmt** — sie ist eine
tote Reserveader. Funktionell trägt die grün-gelbe Ader gleichzeitig
PE **und** N: Sie wird ungewöhnlich lang abisoliert, sodass ein Ende
in den Schutzkontakt und das andere Ende der blanken Ader direkt in
die N-Klemme reicht — **ohne separate Drahtbrücke**, es ist die
gleiche durchgehende Ader in beiden Klemmen. Damit liegen
Schutzkontakt und Neutralkontakt der Steckdose auf demselben
Potenzial — klassische Nullung, aber nicht am Unterverteiler zentral
hergestellt, sondern **lokal an jeder einzelnen Dose per
überlanger Aderabisolierung nachgebildet.**

---

## Warum wurde so gebaut?

Die naheliegendste Erklärung: die vorgelagerte Installation
(Unterverteiler, Zuleitung) war selbst noch klassisch genullt — es
gab dort **keinen eigenen, getrennten N-Leiter**, sondern nur eine
gemeinsame PEN-Schiene. Ein Elektriker, der ein neueres 3-adriges
Kabel verlegte (weil das zu der Zeit bereits vorgeschrieben oder im
Lager verfügbar war), hatte am anderen Ende schlicht keinen echten N
zum Anklemmen der blauen Ader. Statt die Zuleitung selbst zu
modernisieren, wurde die dritte Ader einfach nicht genutzt und an der
Dose die altbekannte Nullungs-Verbindung nachgebaut — mit dem
Ergebnis, dass die Anlage *äußerlich* (3 Adern im Kabel) modern
wirkt, *funktionell* aber unverändert klassisch genullt ist.

**Wichtiger Unterschied zur Unterverteiler-Variante:** Hier liegt das
Problem nicht in einer fehlenden PE-Schiene am Verteiler, sondern in
einer bewussten oder gewohnheitsmäßigen Entscheidung **direkt an der
Dose**, die dritte Ader zu ignorieren und stattdessen die alte
Verdrahtungsgewohnheit (eine Ader für beides) beizubehalten.

---

## Die Gefahr

Elektrisch ist das Ergebnis identisch zur klassischen Nullung: Bricht
die grün-gelbe Ader irgendwo zwischen Verteiler und Dose, liegt die
volle Netzspannung gleichzeitig auf Schutzkontakt **und**
Neutralkontakt der Steckdose — an jedem angeschlossenen Gerätegehäuse.

**Die Tarnung macht es gefährlicher als die klassische Variante am
offenen Verteiler:** Wer nur die Dose öffnet und zwei getrennt
aussehende Klemmen (PE, N) mit jeweils eigener Ader sieht, hält die
Installation leicht für eine echte TN-S-Verdrahtung — dass es sich
um ein und dieselbe, nur ungewöhnlich lang abisolierte Ader handelt,
fällt erst beim genauen Verfolgen der Aderführung auf, es gibt ja
keine separate, auffällige Drahtbrücke zum Entdecken. Ein
oberflächlicher Check (nur Aderanzahl im Kabel zählen) täuscht
Sicherheit vor, die nicht besteht.

**Fehlerhafte Reparatur-Falle:** Wer die Ader einfach umklemmt (z. B.
nur noch in PE) und stattdessen die vorhandene blaue Ader auf die
N-Klemme klemmt, ohne vorher zu prüfen, ob diese Ader am Verteiler
tatsächlich mit einem echten, getrennten N verbunden ist, riskiert
eine Steckdose **ganz ohne** funktionierenden Neutralleiter oder
Schutzkontakt — je nachdem, was am anderen Ende der blauen Ader
tatsächlich anliegt (oft: nichts).

---

## Erkennungsmerkmale im Feld

| Merkmal | Hinweis auf diese Variante |
|---------|----------------------------|
| Grün-gelbe Ader ungewöhnlich lang abisoliert, steckt gleichzeitig in PE-Kontakt und N-Klemme | Eindeutiger Beleg |
| Blaue Ader in der Dose vorhanden, aber lose/abisoliert ungenutzt zurückgeschoben | Reserveader ohne Funktion |
| Messung PE gegen N an der Steckdose: praktisch 0 Ω (Kurzschluss) | Bestätigt die gemeinsame Ader |
| Blaue Ader auch am Verteiler nicht angeklemmt | Bestätigt: nie als N vorgesehen |
| Schutzleiterfarbe einfarbig grün statt grün-gelb (ältere DDR-Bestände) | Zusatzhinweis auf DDR-Altinstallation |

---

## Was tun?

1. **Messen statt vertrauen:** PE gegen N an der Dose prüfen (Kurzschluss
   bestätigt die gemeinsame Ader) und **zusätzlich** am Verteiler
   nachsehen, ob dort ein echter, getrennter N vorhanden ist.
2. **Blaue Ader nicht blind nutzen:** Erst die durchgängige Verbindung
   der blauen Ader bis zu einem echten N-Punkt nachweisen (Durchgangs-
   prüfung), bevor die grün-gelbe Ader aus der N-Klemme entfernt und
   die blaue Ader stattdessen angeklemmt wird.
3. **Wenn kein echter N am Verteiler existiert:** Lokales „Reparieren"
   an der einzelnen Dose bringt nichts — die Zuleitung/der
   Unterverteiler muss auf echtes TN-S umgerüstet werden (separate
   PE-Schiene, echter N-Sammelpunkt), bevor einzelne Dosen korrekt
   verdrahtet werden können.
4. **RCD-Nachrüstung erst nach Prüfung:** Ein RCD löst bei dieser
   Fehlerart (PEN-Bruch) nicht zuverlässig aus, solange PE und N
   irgendwo im Stromkreis noch verbunden sind — Schleifenimpedanz und
   Verdrahtung vorher prüfen.
5. **Jede vorgefundene Dose einzeln prüfen:** Da diese Verdrahtung pro
   Dose individuell gesetzt wurde, sagt der Befund an einer Steckdose
   nichts über die Nachbardose aus — anders als bei der zentralen
   PEN-Schienen-Variante am Verteiler.
