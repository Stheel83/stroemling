# Sicherungstechnik im KFZ: Glassicherung → Flachsicherung → elektronische Sicherung

Auch die unscheinbare Kfz-Sicherung hat einen deutlichen technischen Wandel
durchlaufen – von der zerbrechlichen Glasröhre über die heute allgegenwärtige
Flachsicherung bis zur softwaregesteuerten elektronischen Sicherung in
modernen Fahrzeugen.

---

## 1. Glassicherung (bis in die 1970er)

Frühe Fahrzeuge nutzten **Glasrohrsicherungen** (ähnlich den klassischen
Feinsicherungen aus der Elektronik) oder **Torpedosicherungen** – zylindrische
Keramik-/Glaskörper mit Metallkappen an beiden Enden. Nachteile: empfindlich
gegen Vibration und Stoß (typisches Kfz-Umfeld), Kontaktkorrosion an den
Metallkappen, umständlicher Wechsel.

## 2. Flachsicherung – die ATO-Revolution (ab 1976/1979)

1976 entwickelte der Hersteller Littelfuse die **Flachstecksicherung (ATO)**
– ein flacher Kunststoffkörper mit zwei Steckkontakten und sichtbarem
Schmelzleiter. Erstmals in größerer Serie eingesetzt 1979 im Opel Kadett D,
setzte sie sich in den 1980er-Jahren als neuer Standard durch und verdrängte
die Torpedosicherung nahezu vollständig.

**Vorteile gegenüber der Glassicherung:**

- Robuster gegenüber Vibration (kein zerbrechliches Glas)
- Steckkontakt statt Schraub-/Klemmverbindung → einfacherer, schnellerer
  Wechsel
- Sichtbarer Schmelzleiter erlaubt schnelle Sichtprüfung, ob die Sicherung
  ausgelöst hat

## 3. Baugrößen: Standard, Mini, Maxi

Mit zunehmender Anzahl elektrischer Stromkreise im Fahrzeug wurden kompaktere
Bauformen nötig:

| Baugröße | Bezeichnung | Typischer Einsatz |
|---|---|---|
| Standard (ATO/ATC) | Ursprüngliche Baugröße | ältere und einfachere Fahrzeuge, LKW |
| Mini (ATM/APM) | Kleiner, mehr Sicherungen auf gleichem Platz | moderne PKW-Sicherungskästen |
| Maxi | Größer, für hohe Ströme | Hauptstromkreise, oft im Motorraum nah an der Batterie |

Die Farbcodierung nach **ISO 8820-3** ist international einheitlich und gilt
für alle drei Baugrößen gleichermaßen (Detailtabelle → Nachschlagetabelle
„Sicherungsfarben/-werte + DIN-72552-Klemmenbezeichnungen").

## 4. Sicherungsplatzierung: Sicherungskasten vs. batterienahe Hauptsicherung

Moderne Fahrzeuge haben typischerweise zwei Ebenen:

- **Zentraler Sicherungskasten** (meist im Innenraum oder Motorraum) für die
  einzelnen Verbraucherstromkreise
- **Batterienahe Hauptsicherung(en)** direkt am Pluspol oder in unmittelbarer
  Batterienähe – schützt die dicke Hauptleitung selbst, oft als
  Schmelzsicherung mit hohem Ampere-Wert (50–150A) ausgeführt. Fehlt diese
  Absicherung bei nachträglich verlegten Zusatzleitungen (z.B. bei
  Wohnmobil-Umbauten), drohen im Fehlerfall Kabelbrände – eine der
  häufigsten Ursachen für Elektrik-Brände bei Selbstumbauten (→ Kategorie
  „Wohnmobil-/Camper-Elektrik").

## 5. Elektronische Sicherungen (moderne Fahrzeuge)

In aktuellen Fahrzeugen übernehmen zunehmend **elektronische
Sicherungselemente (Smart-Fuses/eFuse)** im Zentralsteuergerät die klassische
Schmelzsicherungsfunktion: Ein Halbleiterschalter überwacht den Strom
software-gesteuert und trennt den Stromkreis bei Überlast ab – ohne
mechanisches Bauteil, das gewechselt werden müsste, und mit der Möglichkeit,
den Stromkreis nach Fehlerbehebung per Software wieder zu aktivieren statt
eine neue Sicherung einzusetzen. Diese Entwicklung hängt eng mit der
zunehmenden Bordnetz-Vernetzung zusammen (→ Artikel „Bordnetz-Architektur").

---

## Quellen

- Tonful Electric: [Kfz-Flachsicherung vs. Glassicherung](https://tonful.com/de/blade-fuse-vs-glass-fuse-comparison-guide/)
- elektronik-zeit.de: [KFZ-Sicherungen Farbcode: Farben, Ampere, Bauformen](https://elektronik-zeit.de/batterietechnik/kfz-sicherungen-farbcode/)
- camper.help: [Übersicht Farbcodes der Mini-, Standard- und Maxi-Sicherungen](https://camper.help/farbcodes-sicherungen/)

*Hinweis: Elektronische Sicherungen (eFuse) sind aktuell primär in
Oberklasse- und Neufahrzeugen mit zentraler Bordnetzsteuerung verbreitet,
klassische Schmelzsicherungen bleiben im Bestand und bei einfacheren
Modellen weiterhin Standard.*
