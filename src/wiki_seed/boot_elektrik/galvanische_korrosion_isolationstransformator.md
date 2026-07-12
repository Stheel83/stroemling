# Galvanische Korrosion & Isolationstransformator

Dieses Thema hat keine Entsprechung in der Hausinstallation, im Kfz oder
im Wohnmobil – es ist eine Besonderheit, die sich erst ergibt, sobald ein
Boot mit metallischen Unterwasserteilen an einem geerdeten Landstromnetz
hängt. Wer diesen Mechanismus nicht versteht, riskiert erhebliche
Korrosionsschäden am eigenen (und im Zweifel auch am Nachbar-) Boot.

---

## 1. Das Grundproblem

Landstrom-Anschlüsse sind – wie jede Hausinstallation – über den
**Schutzleiter (PE)** geerdet. Wird ein Boot über sein Landstromkabel an
diese Erdung angeschlossen, entsteht eine elektrisch leitende Verbindung
zwischen der Bootsmasse und der Erdung der Marina. Da das Boot gleichzeitig
über seine Unterwassermetallteile (Propeller, Wellenanlage, Seeventile,
Rumpfdurchführungen) **im leitfähigen Wasser** steht, kann darüber ein
schwacher Gleichstrom fließen, der die Unterwassermetalle des Bootes –
und im schlimmsten Fall auch die benachbarter Boote am selben Steg –
elektrolytisch korrodieren lässt (**galvanische Korrosion**).

## 2. Warum man den Schutzleiter trotzdem nicht einfach weglassen darf

Ein naheliegender, aber gefährlicher Gedanke: den Schutzleiter beim
Landanschluss einfach nicht mitzuführen, um die galvanische Verbindung zu
vermeiden. Das ist **hochgefährlich** – ohne Schutzleiter würde im
Fehlerfall (z.B. Isolationsfehler eines 230V-Geräts an Bord) die
Schutzeinrichtung (FI/RCD) nicht mehr zuverlässig auslösen, ein
lebensgefährlicher Fehlerstrom könnte über den Bootsrumpf oder badende
Personen im Wasser abfließen. Der Schutzleiter ist also **sicherheitlich
zwingend nötig** – das eigentliche Problem muss anders gelöst werden.

## 3. Die Lösung: Isolationstransformator

Ein **Isolationstransformator (Trenntransformator)** trennt das Boot
galvanisch vollständig vom Landnetz, ohne den Personenschutz zu
beeinträchtigen: Der Landstrom wird auf die Primärseite des
Transformators gelegt, das Boot hängt an der **elektrisch isolierten**
Sekundärseite. Der Transformator überträgt die Energie magnetisch, nicht
über eine leitende Verbindung – die Schutzleiter-Funktion für die
230V-Installation an Bord bleibt dabei vollständig erhalten (bootsseitig
eigene Erdung über die Sekundärwicklung), aber die galvanische
Verbindung zum Landnetz und damit der Korrosionspfad über das Wasser
entfällt.

## 4. Alternative/Ergänzung: Galvanischer Isolator

Für Boote ohne vollständigen Isolationstransformator gibt es als
kostengünstigere Teillösung den **galvanischen Isolator**: Er unterbricht
niederfrequente Gleichstromanteile im Schutzleiterpfad (die für die
galvanische Korrosion verantwortlich sind), lässt aber im Fehlerfall den
für den Personenschutz nötigen Wechselstrom-Fehlerstrom ungehindert
passieren. Schwächerer Schutz als ein vollständiger Trenntransformator,
aber deutlich besser als gar keine Maßnahme.

## 5. Praxisrelevanz

Wer sein Boot dauerhaft am Landstrom liegen hat (Dauerlieger im Hafen),
sollte diesem Thema besondere Aufmerksamkeit widmen – die Korrosion
wirkt schleichend über Monate/Jahre und wird oft erst bemerkt, wenn
bereits sichtbare Schäden an Propeller oder Seeventilen entstanden sind.
**Opferanoden** (Zink- oder Magnesiumanoden am Rumpf) mildern das Problem
zusätzlich ab, ersetzen aber keinen wirksamen galvanischen Schutz am
Landanschluss selbst.

---

## Quellen

- Victron Energy: [8. Galvanische Korrosion – The Wiring Unlimited](https://www.victronenergy.com/media/pg/The_Wiring_Unlimited_book/de/galvanic-corrosion.html)
- Schiffsladen: [Galvanischer Isolator – Schutz vor Korrosion](https://www.schiffsladen.at/lexikon/galvanischer-isolator/)
