# Kuriositäten/häufige Fehler beim Selbstausbau

Camper-Selbstausbau boomt seit Jahren – und mit ihm eine ganze Reihe
wiederkehrender Elektrik-Fehler, die sich in Foren, Werkstätten und
Erfahrungsberichten immer wieder finden lassen.

---

## 1. Unterdimensionierte Kabel „weil noch in der Kiste"

Der Klassiker: Für die Hauptleitung von der Aufbaubatterie zum
Sicherungsverteiler wird eine Leitung verwendet, die zufällig noch
vorhanden war – oft deutlich zu dünn für die tatsächliche Strombelastung
und Leitungslänge (→ Artikel „Spannungsabfall bei langen
12V-Leitungswegen"). Symptome reichen von spürbarem Leistungsverlust bis
zu gefährlicher Erwärmung der Leitung unter Volllast.

## 2. Fehlende batterienahe Hauptsicherung

Wie im entsprechenden Artikel zur Sicherungstechnik beschrieben (→ Artikel
„Sicherungstechnik im Wohnmobil"): Die einzelnen Verbraucherstromkreise
sind sauber abgesichert, aber die dicke Hauptleitung zwischen Batterie
und Sicherungsverteiler selbst hat **keine eigene Sicherung in
Batterienähe** – im Fehlerfall auf diesem kurzen, aber hochstromfähigen
Leitungsstück greift dann keine der nachgelagerten Sicherungen.

## 3. Fehlende Massetrennung / gemeinsame Masseschiene für alles

Bei manchen Selbstausbauten werden 12V-Masse, 230V-Schutzleiter und
Fahrzeugkarosserie-Masse unsauber vermischt oder über denselben
Sammelpunkt geführt, ohne die eigentlich nötige galvanische Trennung
zwischen Fahrzeug-Bordnetz-Masse und der 230V-Schutzleiter-Systematik zu
berücksichtigen. Ergebnis können unerwartete Potenzialverschiebungen oder
im ungünstigsten Fall ein unwirksamer Personenschutz auf der 230V-Seite
sein.

## 4. Solarmodul-Anschluss ohne Sicherung/mit vertauschter Polarität

Da Solarleitungen meist vergleichsweise dünn wirken, wird ihre
Absicherung häufig vernachlässigt (→ Artikel „Solaranlage"). Ebenfalls
verbreitet: vertauschte Plus-/Minus-Anschlüsse am Laderegler bei der
Erstinbetriebnahme – bei den meisten modernen MPPT-Reglern zwar durch
interne Schutzschaltungen meist folgenlos, aber nicht bei jedem
Billigmodell garantiert.

## 5. Ladebooster/Trennrelais falsch für das Basisfahrzeug gewählt

Wie im entsprechenden Artikel beschrieben (→ Artikel „Trennrelais und
Ladebooster"): ein klassisches Trennrelais an einem modernen Euro-6-
Basisfahrzeug mit intelligenter Lichtmaschine gewählt – die
Aufbaubatterie wird dadurch dauerhaft nur unzureichend geladen, ohne dass
der eigentliche Fehler (falsche Komponentenwahl) sofort offensichtlich
ist.

## 6. Lithium-Batterie ohne Kälteschutz im unbeheizten Bereich verbaut

Eine LiFePO4-Aufbaubatterie wird im unbeheizten Unterflurbereich oder in
einer kalten Staubox verbaut, ohne dass BMS/Heizung die Kälteempfindlichkeit
beim Laden abfangen (→ Artikel „Batterietechnik für Camper") – bei
winterlicher Nutzung drohen Ladeausfälle oder im schlimmsten Fall
Zellschäden.

---

## Quellen

Dieser Artikel basiert auf allgemein bekannten, in Camper-Ausbau-Foren
und Fachratgebern breit dokumentierten Praxiserfahrungen, nicht auf einer
einzelnen Fachquelle – ähnlich den bereits im Wiki vorhandenen
Kuriositäten-Artikeln zu anderen Themenbereichen.
