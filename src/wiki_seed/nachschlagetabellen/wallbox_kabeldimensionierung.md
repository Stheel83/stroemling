# Wallbox / E-Auto-Ladepunkt – Kabel richtig dimensionieren

Ein Ladepunkt für Elektrofahrzeuge (Wallbox) verhält sich elektrisch anders
als die meisten Verbraucher, für die die üblichen Faustregeln gedacht sind.
Drei Besonderheiten, die man beim Kabelrechner berücksichtigen sollte:

> **Norm:** DIN VDE 0100-722 (Zusatzanforderungen für Ladeeinrichtungen von
> Elektrofahrzeugen, entspricht IEC 60364-7-722)

---

## 1. Kein Gleichzeitigkeitsfaktor – volle Dauerlast

Ein Ladevorgang läuft stundenlang mit vollem Nennstrom, nicht nur kurzzeitig
wie bei den meisten Haushaltsgeräten. DIN VDE 0100-722 verlangt deshalb, die
Zuleitung auf den **vollen Bemessungsstrom des Ladepunkts als Dauerlast**
auszulegen – ohne die sonst oft übliche Abminderung durch Gleichzeitigkeit.

| Ladeleistung | Strom I (Drehstrom, 400 V) |
|---|---|
| 11 kW | 16 A |
| 22 kW | 32 A |

→ Im Kabelrechner: **Strom I** = genau dieser Wert, nicht abgemindert.

---

## 2. cos φ ≈ 1,0 – kein Motorverhalten

Das Ladegerät im Fahrzeug hat eine aktive PFC-Vorstufe
(Leistungsfaktorkorrektur). Dadurch verhält sich die Last netzseitig
praktisch ohmsch – **cos φ ≈ 0,95–1,0**, nicht die 0,7–0,85 eines
Asynchronmotors (siehe auch Kabelrechner-Hinweistext zu cos-φ-Richtwerten).
Für die Berechnung reicht `cos φ = 1,0` als sichere Näherung.

---

## 3. ΔU max eher konservativ ansetzen

Da es sich um Dauervolllast über Stunden handelt, ist der strengere Wert
**3 %** (statt der für „sonstige Verbraucher" erlaubten 5 %) die
vorsichtigere Wahl – besonders bei längeren Kabelwegen zu freistehenden
Garagen oder Stellplätzen, wo ein zu hoher Spannungsfall die tatsächliche
Ladeleistung über die gesamte Ladedauer spürbar reduziert.

---

## Rechenbeispiele

Beide Beispiele: Drehstrom, 400 V, cos φ = 1,0, Kupfer, Verlegeart B2
(Mantelleitung auf/in Wand – typisch für Kabelkanal von Zählerschrank zur
Garage), 20 m Länge, 30 °C, keine Häufung (1 Leitung), LS-Schalter
Charakteristik C mit I_n = Ladepunkt-Nennstrom, ΔU max = 3 %.

### 11 kW / 16 A

| Kriterium | Ergebnis |
|---|---|
| Spannungsfall | 1,5 mm² ausreichend (ΔU ≈ 1,65 %) |
| Thermik | **2,5 mm²** nötig (I_z = 21 A bei B2, 1,5 mm² reicht mit 15,5 A nicht) |
| Abschaltbedingung (C16) | 1,5 mm² ausreichend |
| **Empfohlener Querschnitt** | **2,5 mm²** (Thermik entscheidet) |
| Praxisrichtwert I/6 | 16/6 ≈ 2,7 → 4 mm² (hier großzügiger als die exakte Berechnung) |

### 22 kW / 32 A

| Kriterium | Ergebnis |
|---|---|
| Spannungsfall | 2,5 mm² ausreichend (ΔU ≈ 1,98 %) |
| Thermik | **6 mm²** nötig (I_z = 36 A bei B2, 4 mm² reicht mit 28 A nicht) |
| Abschaltbedingung (C32) | 1,5 mm² ausreichend |
| **Empfohlener Querschnitt** | **6 mm²** (Thermik entscheidet) |
| Praxisrichtwert I/6 | 32/6 ≈ 5,3 → 6 mm² (stimmt hier mit der exakten Berechnung überein) |

Beide Ergebnisse (2,5 mm² für 16 A, 6 mm² für 32 A) decken sich mit gängiger
Installationspraxis. Bei größerer Distanz zum Zählerschrank (lange
Erdkabelstrecke zu einem entfernten Stellplatz) kann der Spannungsfall statt
der Thermik zum limitierenden Kriterium werden – dann lohnt sich die
Genauberechnung mit der tatsächlichen Leitungslänge.

---

## Wallboxen lassen sich drosseln – Kabel muss nicht immer größer werden

Reicht die vorhandene Zuleitung oder Absicherung nicht für den vollen
Ladestrom aus, muss nicht zwingend das Kabel vergrößert werden: Viele
Wallboxen – insbesondere mobile Ladeboxen – lassen sich am Gerät selbst auf
einen niedrigeren Ladestrom einstellen (DIP-Schalter, App, oder Aushandlung
über das Fahrzeug-Pilotsignal). Das Fahrzeug zieht dann einfach
entsprechend weniger Leistung. Für die Kabeldimensionierung zählt in dem
Fall der **eingestellte, gedrosselte** Strom als Bemessungsstrom – nicht der
theoretische Maximalwert des Ladegeräts.

---

## Schutzorgan (RCD)

Zusätzlich zur reinen Querschnittsberechnung verlangt DIN VDE 0100-722 einen
RCD mit Erkennung glatter Gleichfehlerströme (Typ B, oder Typ A mit
zusätzlichem, mindestens 6 mA erkennendem DC-Fehlerstromsensor). Details:
Wiki-Artikel „RCD-Typen – Welcher FI-Schutzschalter wofür?".

> **Hinweis:** Diese Werte sind eine Orientierungshilfe, kein zertifizierter
> Normwert. Bei sicherheitsrelevanten Anlagen immer einen Fachplaner
> hinzuziehen.
