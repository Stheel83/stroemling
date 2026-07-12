# Spannungsabfall bei langen 12V-Leitungswegen

Was im normalen PKW kaum eine Rolle spielt, wird im Camper-Ausbau schnell
zum zentralen Auslegungsproblem: der **Spannungsabfall** auf langen
12V-Leitungswegen. Der Grund liegt in der Physik selbst, nicht in einer
Camper-Besonderheit – aber die typischen Leitungslängen im Ausbau machen
den Effekt viel spürbarer als im Kfz.

---

## 1. Warum 12V empfindlicher reagiert als 230V

Bei gleicher übertragener Leistung fließt bei 12V ein rund 19-mal so
hoher Strom wie bei 230V (P = U × I). Da der Spannungsabfall auf einer
Leitung direkt proportional zum fließenden Strom ist (U_Abfall = I × R),
wirkt sich derselbe Leitungswiderstand bei 12V viel gravierender auf die
Spannung aus als bei 230V – ein Effekt, der bereits beim 6V→12V-Wechsel
in der Kfz-Geschichte eine Rolle spielte (→ Kategorie „KFZ-Elektrik im
Wandel der Zeit", Artikel „Von 6V auf 12V") und im Camper mit seinen
deutlich längeren Leitungswegen als im normalen PKW noch relevanter wird.

## 2. Konkrete Auswirkung

Ein zu dünn dimensionierter Leitungsquerschnitt über mehrere Meter Länge
kann dazu führen, dass am Verbraucher spürbar weniger als 12V ankommen –
mit direkten Folgen:

- **LED-Beleuchtung** wird sichtbar dunkler oder flackert
- **Kompressorkühlschränke** schalten bei zu niedriger Spannung in
  Schutzabschaltung oder laufen ineffizienter
- **Ladegeräte/Wechselrichter** melden Unterspannungsfehler, obwohl die
  Batterie selbst in Ordnung ist

## 3. Faustregel zur Querschnittsermittlung

Der nötige Leitungsquerschnitt hängt von drei Faktoren ab: Stromstärke,
Leitungslänge (hin **und** zurück zählen!) und zulässiger
Spannungsabfall (üblicher Richtwert im 12V-Bordnetz: max. 3 % der
Nennspannung, also ca. 0,36 V bei 12V). Grundformel:

```
A = (2 × L × I) / (κ × U_Abfall)

A = Leitungsquerschnitt in mm²
L = einfache Leitungslänge in m (Faktor 2 für Hin- und Rückleiter)
I = Stromstärke in A
κ = elektrische Leitfähigkeit (Kupfer ≈ 56 m/(Ω·mm²))
U_Abfall = zulässiger Spannungsabfall in V
```

**Praxisbeispiel:** Eine 10 m lange Leitung (Hin+Rück = 20 m) mit 15 A
Last und maximal 3 % zulässigem Spannungsabfall bei 12V (0,36 V) braucht
rechnerisch bereits einen Querschnitt von rund 15 mm² – deutlich mehr, als
viele beim ersten Überschlag erwarten.

## 4. Praxishinweise

- Bei längeren Leitungswegen (Solarmodul auf dem Dach → Laderegler im
  Innenraum, Aufbaubatterie → weit entfernter Sicherungsverteiler) den
  Querschnitt lieber großzügig statt knapp wählen – Kupfer ist die
  günstigste Stelle zum „Puffer einbauen"
- Bei bereits spürbarem Spannungsabfall an einem bestehenden Verbraucher:
  zuerst mit einem Multimeter die tatsächliche Spannung direkt am
  Verbraucher **unter Last** messen (nicht nur an der Batterie im
  Leerlauf) – das lokalisiert das Problem zuverlässiger als reines
  Schätzen
- Steckverbinder und Klemmstellen zählen zum Gesamtwiderstand dazu – viele
  Steckverbindungen auf kurzer Strecke können denselben Effekt haben wie
  ein zu dünner Querschnitt über eine lange Strecke

---

## Quellen

Physikalisches Grundprinzip (Ohmsches Gesetz, Leitfähigkeit Kupfer) –
allgemeines Elektrotechnik-Grundwissen, keine spezifische Camper-Quelle
nötig. Für die exakte Querschnittsermittlung im eigenen Projekt eignet
sich ein dedizierter Kabelquerschnitt-Rechner (in Strömling Design als
eigenständiges Werkzeug vorhanden, siehe Programmübersicht).
