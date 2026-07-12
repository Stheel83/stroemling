# Motorrad-Bordnetz: Besonderheiten gegenüber PKW

Wer vom PKW zum Motorrad wechselt, findet oft ein deutlich einfacheres,
teils batterieunabhängiges Bordnetz vor – aus gutem Grund: Gewicht, Platz
und Kosten spielen bei Zweirädern eine noch größere Rolle als beim Auto.

---

## 1. Schwungmagnetzünder – Zündung ganz ohne Batterie

Bei einfachen Mopeds und älteren Kleinkrafträdern liefert eine
**Schwunglichtmaschine (Lichtmagnetzünder)** die komplette elektrische
Energie – für Zündung und Beleuchtung gleichermaßen, **ganz ohne
Batterie**. Ein Permanentmagnet-Rotor auf der Kurbelwelle induziert in
feststehenden Spulen die nötige Spannung direkt während der Motordrehung.
Vorteil: minimaler Aufwand, kein Ausfallrisiko durch leere Batterie.
Nachteil: keine Leistung ohne laufenden Motor (kein Anlasser möglich, meist
Kickstarter), Lichtleistung drehzahlabhängig (bei Standgas sehr schwaches
Licht).

## 2. CDI-Zündung: batterieunabhängig, aber mit eigener Elektronik

Die **CDI-Zündung (Kondensator-Entladungs-Zündung)** ist bei vielen
Motorrädern und praktisch allen klassischen Mopeds Standard – und
funktioniert unabhängig von Bordnetz und Batterie: Separate Ladespulen in
der Lichtmaschine laden einen Kondensator in der CDI-Einheit auf, eine
Impulsspule am Rotor löst zum Zündzeitpunkt einen Thyristor aus, der den
Kondensator schlagartig über die Zündspule entlädt. Das Ergebnis: ein sehr
kurzer, aber sehr energiereicher Zündfunke – Vorteil bei hohen Drehzahlen
und für Zweitaktmotoren mit ihrem großen Elektrodenabstand-Verschleiß.
Man unterscheidet **AC-CDI** (Zündenergie kommt direkt und unabhängig aus
der Lichtmaschinen-Ladespule, batterielos möglich) und **DC-CDI** (Energie
kommt aus dem batteriegepufferten Bordnetz, gleichmäßigerer Zündfunke auch
im Leerlauf).

## 3. Bordnetz mit Batterie (größere Motorräder)

Größere Motorräder mit E-Starter brauchen zwingend eine Batterie und ein
klassisches Lichtmaschine-Regler-System, ähnlich dem PKW-Prinzip, aber in
kompakterer, leichterer Bauform:

- Kleinere **Batteriekapazität** (oft nur 6–14 Ah statt 40–90 Ah beim PKW)
- **Lichtmaschine** meist als Wechselstromgenerator mit Gleichrichter/Regler
  im Motorgehäuse integriert statt als separates Anbauteil
- Deutlich **weniger elektrische Verbraucher** als im PKW – kein
  Fensterheber, keine Klimaanlage, oft nur Beleuchtung, Zündung,
  Instrumente, ggf. Heizgriffe

## 4. Praxisrelevanz für Hobbyisten

- Bei Standlicht-Problemen an einfachen Mopeds mit Schwunglichtmaschine
  zuerst die Drehzahlabhängigkeit bedenken – schwaches Licht im Leerlauf
  ist bei diesem System oft normal, kein Defekt
- CDI-Einheiten sind meist als Ganzes zu tauschen, nicht wie klassische
  Kontaktzündungen vor Ort zu warten – ein Fehlerbild „kein Zündfunke"
  erfordert oft Bauteiltausch statt Reparatur
- Batteriewechsel bei kleinen Motorrad-/Rollerbatterien: unbedingt die vom
  Hersteller vorgegebene Kapazität und den Batterietyp (klassisch
  Blei-Säure, wartungsfrei, oder zunehmend Lithium-Ionen-Kleinbatterien)
  einhalten – Unterdimensionierung führt schnell zu Startproblemen

---

## Quellen

- motelek.net: [Einführung in die HKZ bzw. CDI Thyristor Zündtechnik](https://www.motelek.net/zundanlagen/cdi/cdi_lektion1.html)
- MOTOR-TALK: [CDI am Motorrad, wie funktioniert das?](https://www.motor-talk.de/forum/cdi-am-motorrad-wie-funktioniert-das-funktionsweise-kondensatorzuendanlage-t4751210.html)
- Peter Rausch: [Motorradelektrik (K)ein Buch mit sieben Siegeln (PDF)](https://www.peterrausch.de/motorradelektrik.pdf)

*Hinweis: Die genaue Bordnetz-Architektur unterscheidet sich stark je
Hubraumklasse und Baujahr – dieser Artikel beschreibt die grundsätzlichen
Prinzipien, nicht ein konkretes Modell.*
