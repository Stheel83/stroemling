# RCD-Typen – Welcher FI-Schutzschalter wofür?

FI-Schutzschalter (RCD – Residual Current Device) schützen vor
Fehlerströmen. Nicht jeder RCD erkennt jeden Fehlerstrom —
die richtige Typauswahl ist entscheidend.

> **Norm:** DIN EN 61008-1 / DIN EN 61009-1 (VDE 0664)

---

## Typenübersicht

| Typ | Erkannte Fehlerströme | Kurzbeschreibung |
|:---:|----------------------|------------------|
| **AC** | Wechselfehlerstrom (50 Hz) | Ältester Typ, nur noch Altbestand |
| **A**  | Wechsel + pulsierender Gleichstrom | Standard für Wohngebäude |
| **F**  | Wie A + gemischte Frequenzen (13–100 Hz) | Waschmaschinen, Frequenzumrichter klein |
| **B**  | Wie A + glatter Gleichfehlerstrom | E-Mobilität, Wechselrichter, VFD |
| **B+** | Wie B + hochfrequente Fehlerströme | Erweiterte B-Anwendungen |

---

## Typ AC — veraltet, nur Bestandsschutz

Erkennt nur **sinusförmige Wechselfehlerstrom** bei 50 Hz.
Nicht mehr für Neuinstallationen empfohlen (DIN VDE 0100-530).

> Geräte mit Schaltnetzteilen, Dimmern oder Frequenzumrichtern können
> Typ AC „blind" machen — er löst dann nicht mehr sicher aus.

---

## Typ A — Standard für Wohngebäude

Erkennt:
- Sinusförmiger Wechselfehlerstrom (50 Hz)
- Pulsierender Gleichfehlerstrom (gleichgerichteter Halbwellen)

**Anwendung:** Standardmäßig in allen Wohngebäuden und Gewerbebauten.
Pflicht laut DIN VDE 0100-410 für Steckdosen bis 32 A (seit 2018).

**Nicht geeignet für:**
- Frequenzumrichter mit aktiver Eingangskorrektur
- EV-Ladestationen
- Wechselrichter (Photovoltaik, USV)

---

## Typ F — Waschmaschinen und kleine Umrichter

Erkennt zusätzlich zu Typ A:
- Gemischte Fehlerströme aus Überlagerung von 50 Hz und anderen Frequenzen (13–100 Hz)

**Anwendung:**
- Waschmaschinen mit Frequenzumrichter-Antrieb
- Kleine Frequenzumrichter (Pumpen, Lüfter)
- Haushaltsgeräte mit variablen Drehzahlen

---

## Typ B — E-Mobilität und Wechselrichter

Erkennt zusätzlich zu Typ A:
- Glattgerichtete Gleichfehlerströme (0 Hz / DC)
- Frequenzen bis 1000 Hz (je nach Hersteller)

**Anwendung:**
- **EV-Ladestationen / Wallboxen** (Pflicht bei Mode 3 Ladung)
- Wechselrichter (Photovoltaik-Anlagen, USV)
- Frequenzumrichter mit glatter DC-Zwischenkreis-Ableitung
- 3-Phasen-Frequenzumrichter > 2 kW

> Typ B ist deutlich teurer als Typ A. Manche Wallbox-Hersteller
> integrieren einen gleichwertigen DC-Fehlerstrom-Sensor intern —
> dann reicht extern ein Typ A.

---

## Auswahltabelle nach Anwendung

| Anwendung | Mindest-Typ |
|-----------|:-----------:|
| Steckdosen Wohngebäude | A |
| Beleuchtung | A |
| Waschmaschine mit Inverter | F oder B |
| E-Herd, Backofen | A |
| EV-Ladestation / Wallbox | B (oder A wenn intern) |
| Photovoltaik-Wechselrichter | B |
| Frequenzumrichter Industrie | B |
| USV-Anlage | B |
| Altbestand-Erweiterung | mindestens A |

---

## Nennfehlerströme (I_Δn)

| I_Δn | Anwendung |
|:----:|-----------|
| 10 mA | Nassräume, erhöhte Gefährdung (selten) |
| 30 mA | Personenschutz (Standard Steckdosen) |
| 100 mA | Selektive RCD (vorgelagert) |
| 300 mA | Brandschutz (nachgelagerte 30mA-RCD) |
| 500 mA | Brandschutz Altbau |

> Personenschutz erfordert **≤ 30 mA**. Höhere Stufen dienen der
> Selektivität oder dem Brandschutz, nicht dem direkten Personenschutz.
