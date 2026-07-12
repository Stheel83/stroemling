# Anlasser-Technik: Schub-Schraubtrieb bis Start-Stopp

Der Anlasser ist einer der elektrisch am stärksten beanspruchten Verbraucher
im Fahrzeug – kurzzeitig fließen mehrere hundert Ampere, um den Motor aus
dem Stillstand auf Zünddrehzahl zu bringen. Diese Belastung hat die
Anlassertechnik über die Jahrzehnte stark geprägt.

---

## 1. Grundprinzip: Elektromotor + Einspurmechanismus

Ein Anlasser besteht im Kern aus einem leistungsstarken
Gleichstrom-Elektromotor und einem Mechanismus, der das Anlasserritzel nur
während des Startvorgangs in den Zahnkranz des Schwungrads einspuren lässt –
im Fahrbetrieb muss die Verbindung zwingend getrennt sein, sonst würde der
Motor den Anlasser mit weit überhöhter Drehzahl zerstören.

## 2. Schub-Schraubtrieb (klassisches Prinzip)

Beim **Schub-Schraubtrieb** (auch Bendix-Prinzip nach seinem Erfinder Vincent
Bendix) sitzt das Ritzel auf einem steilen Gewinde der Anlasserwelle: Beim
Einschalten dreht sich die Welle, das Ritzel „schraubt" sich dabei axial nach
vorn in den Zahnkranz und treibt den Motor an. Sobald der Motor anspringt
und schneller dreht als der Anlasser, schraubt sich das Ritzel durch die
Drehzahldifferenz automatisch wieder zurück – ein rein mechanisches
Sicherheitsprinzip ohne elektrische Steuerung.

**Weiterentwicklung – Schubschraubtrieb mit Freilauf:** Ein zusätzlicher
Freilauf (Rollenfreilauf) im Ritzel verhindert, dass der anspringende Motor
den Anlasser über das Ritzel auf gefährlich hohe Drehzahl mitreißt, bevor
die Auskupplung vollständig erfolgt ist.

## 3. Magnetschalter (Vorsteuerrelais)

Moderne Anlasser nutzen einen **Magnetschalter (Einrückrelais)**, der zwei
Aufgaben in einem Bauteil vereint: Er schiebt über einen Hebel das Ritzel
mechanisch in den Zahnkranz **und** schaltet gleichzeitig den
Hauptstromkreis des Anlassermotors. Das ermöglicht eine präzise Steuerung
über den Zündschlüssel bzw. Startknopf, ohne dass der volle Anlasserstrom
durch den Zündschalter selbst fließen muss (der schaltet nur den kleinen
Steuerstrom des Magnetschalters – ähnliches Prinzip wie bei
Relais-Schaltungen allgemein).

## 4. Motorbauarten

| Bauart | Prinzip | Einsatz |
|---|---|---|
| Reihenschlussmotor | Anker- und Feldwicklung in Reihe, hohes Anlaufdrehmoment | klassischer Standard-Anlasser |
| Permanentmagnet-Anlasser | Feldmagnete statt Feldwicklung | kompakter, leichter, heute überwiegend Standard |
| Planetengetriebe-Anlasser | Elektromotor treibt über Untersetzungsgetriebe das Ritzel | kleinerer, schneller drehender Motor bei gleichem Drehmoment am Ritzel – heute Standard bei den meisten PKW |

## 5. Start-Stopp-Systeme: neue Anforderungen

Mit der Einführung von **Start-Stopp-Automatik** änderten sich die
Anforderungen an den Anlasser grundlegend: Statt einiger tausend
Startvorgänge über die gesamte Fahrzeuglebensdauer muss ein
Start-Stopp-Anlasser mehrere **hunderttausend** Startzyklen aushalten, da
der Motor bei jedem Ampelstopp abgeschaltet und wieder gestartet wird.
Das erforderte verstärkte Bauteile (robustere Lager, verschleißfestere
Kontakte im Magnetschalter, verbessertes Einspurverhalten für den
„Komfort-Wiederstart" schon während des Motor-Auslaufens).

**Weiterentwicklung – riemengetriebener Startergenerator (48V-Mildhybrid):**
Bei modernen Mildhybrid-Fahrzeugen übernimmt zunehmend ein
**riemengetriebener Startergenerator (RSG)** im 48V-Zusatzbordnetz sowohl
die Anlasser- als auch die Lichtmaschinenfunktion in einem Bauteil – ein
Konzept, das die klassische Trennung zwischen Anlasser und Lichtmaschine
technisch aufweicht (Details zum 12V/48V-Doppelbordnetz sind ein
eigenständig komplexes Thema und hier bewusst nur angerissen).

---

## Quellen

- Wikipedia: [Anlasser](https://de.wikipedia.org/wiki/Anlasser)
- Bosch Mobility: allgemeine Fachinformationen zu Starter-Generator-Systemen

*Hinweis: Start-Stopp-Zyklenzahlen und 48V-Mildhybrid-Details variieren
stark je Hersteller und Modell – hier als allgemeiner Trend beschrieben,
nicht als herstellerspezifische Spezifikation.*
