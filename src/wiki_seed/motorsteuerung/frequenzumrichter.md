# Frequenzumrichter – Funktionsweise und Einsatz

Der Frequenzumrichter (FU, auch VFD – Variable Frequency Drive, oder
Umrichter) ermöglicht stufenlose Drehzahlregelung von Drehstrommotoren
durch Variation von Frequenz und Spannung. Er ist das leistungsfähigste
und vielseitigste Antriebssystem für AsynchromMotoren.

> **Normen:** DIN EN 61800-5-1 (Leistungselektronik), DIN EN 61800-3 (EMV),
> DIN EN 60034-1 (Motorschutz)

---

## Funktionsprinzip: AC → DC → AC

Der Frequenzumrichter wandelt die Netzfrequenz (50 Hz) in eine
frei einstellbare Ausgangsfrequenz um — in drei Stufen:

```
Netz (50 Hz)
    │
    ▼
┌─────────────────────────────────────────────┐
│  1. GLEICHRICHTER (Rectifier)               │
│     3-Phasen-Brückengleichrichter           │
│     AC 400V → DC ~565V (Zwischenkreis)      │
├─────────────────────────────────────────────┤
│  2. ZWISCHENKREIS (DC-Bus)                  │
│     Kondensator-Puffer, Glättung            │
│     DC ~565V konstant                       │
├─────────────────────────────────────────────┤
│  3. WECHSELRICHTER (Inverter)               │
│     6 IGBTs (Insulated Gate Bipolar         │
│     Transistor) erzeugen PWM-Signal         │
│     → quasi-sinusförmige AC-Ausgangsspannung│
│     Frequenz: 0–200 Hz (oder mehr)          │
│     Spannung: 0–400V proportional zur Freq. │
└─────────────────────────────────────────────┘
    │
    ▼
Motor (0–n_max U/min)
```

### Pulsweitenmodulation (PWM)

Die IGBTs schalten mit hoher Frequenz (typisch 4–16 kHz) und erzeugen
durch unterschiedliche Einschaltzeiten eine **sinusähnliche Spannung**:

```
+400V ──┐  ┌──┐    ┌────┐  ┌─
        │  │  │    │    │  │     (PWM-Rechteckpulse)
 0V ────┘  └──┘────┘    └──┘──
        ↕  ↕  ↕    ↕   ...
        Mittlere Spannung = sinusförmig
```

---

## U/f-Kennlinie: Spannung folgt Frequenz

Um das **magnetische Flussniveau** im Motor konstant zu halten, wird
die Spannung proportional zur Frequenz angehoben:

| Frequenz | Spannung | Drehzahl (4-pol. Motor) |
|:--------:|:--------:|:------------------------:|
| 0 Hz     | 0 V      | 0 U/min                  |
| 25 Hz    | 200 V    | ~750 U/min               |
| 50 Hz    | 400 V    | ~1500 U/min              |
| 60 Hz    | 400 V*   | ~1800 U/min              |
| 100 Hz   | 400 V*   | ~3000 U/min              |

\* Oberhalb der Nennfrequenz (Feldschwächbereich): Spannung bleibt bei 400V,
Fluss nimmt ab, Drehmoment sinkt — Leistung bleibt konstant.

---

## Wichtige Parameter

### Rampenzeiten

| Parameter | Beschreibung | Typischer Wert |
|-----------|-------------|:--------------:|
| Hochlaufzeit (t_acc) | Zeit von 0 auf Maximalfrequenz | 5–30 s |
| Auslaufzeit (t_dec) | Zeit von Maximalfrequenz auf 0 | 5–30 s |
| S-Kurve | Weiche Übergänge am Anfang/Ende der Rampe (jerk-frei) | empfohlen |

### Frequenzgrenzen

| Parameter | Beschreibung |
|-----------|-------------|
| Minimale Frequenz (f_min) | Unterster Betriebspunkt (z. B. 5 Hz bei Pumpen) |
| Maximale Frequenz (f_max) | Oberster Betriebspunkt (z. B. 50 oder 60 Hz) |
| Nennfrequenz (f_N) | Motor-Nennfrequenz (Typenschild), meist 50 Hz |

### Motorparameter (Parametrierung)

Unbedingt vom Motortypenschild eingeben:
- Nennspannung U_N (V)
- Nennstrom I_N (A)
- Nennfrequenz f_N (Hz)
- Nennleistung P_N (kW)
- Nenndrehzahl n_N (U/min) — für Schlupfkompensation

### Taktfrequenz (Schaltfrequenz)

Die PWM-Taktfrequenz der IGBTs beeinflusst:

| Taktfrequenz | Motorgeräusch | Umrichter-Erwärmung | Leitungslänge max. |
|:------------:|:-------------:|:-------------------:|:-----------------:|
| 4 kHz        | laut (hörbar) | gering              | > 100 m           |
| 8 kHz        | mittel        | mittel              | ~50 m             |
| 16 kHz       | leise / unhörbar | hoch             | ~20 m             |

---

## Integrierter Motorschutz

Der Frequenzumrichter übernimmt alle Schutzfunktionen — **kein externes
Thermorelay notwendig** (und bei Umrichter-Betrieb auch nicht erlaubt,
da der nichtsinusförmige Strom das Bimetall-Thermorelay verfälscht):

| Schutzfunktion | Erklärung |
|----------------|-----------|
| Thermisches Motormodell (I²t) | Berechnet Motor-Erwärmung aus Strom und Zeit |
| PTC-Eingang | Direkter Anschluss von Motor-Kaltleiter (empfohlen!) |
| Phasenausfall (Eingang) | Erkennt fehlende Netzphase |
| Überstrom / Kurzschluss | Abschaltung innerhalb µs (IGBT-Schutzstufe) |
| Überspannung (DC-Bus) | Abschaltung bei zu hoher Zwischenkreisspannung |
| Übertemperatur (FU intern) | Kühlkörper-Temperatursensor |
| Motorblockierung | Erkennt blockierten Motor (hoher Strom, keine Drehzahl) |

---

## Bremsmethoden

### 1. Rampenauslauf (Standard)

Frequenz wird linear auf 0 gerampt. Motor bremst durch seine eigene
Reibung und Last-Trägheit. **Kein aktives Bremsmoment.**

Nachteil: Bei leichten Lasten (Lüfter) kann Motor die Sollfrequenz nicht
halten → Umrichter schaltet ab (Überspannung im Zwischenkreis).

### 2. DC-Bremse (Gleichstrombremsung)

Umrichter speist Gleichstrom in die Motorwicklungen → erzeugt
Bremsmoment durch Wirbelstromprinzip. **Kein Bremswiderstand nötig.**

Nachteil: Motor erwärmt sich stark bei langer Bremszeit.

### 3. Bremswiderstand (Chopperbremssung)

Beim Bremsen speist der Motor als Generator in den Zwischenkreis zurück.
Überschüssige Energie wird in einem **Bremswiderstand** (Brake Resistor,
BR) in Wärme umgesetzt.

```
Motor (generatorisch) → DC-Bus → Bremschopper → Bremswiderstand (Wärme)
```

Nötig bei: schnellen Bremsrampen, schweren Massen, häufigem Bremsen.

### 4. Rückspeisung ins Netz (Regenerativ)

Hochwertige FUs (Active Front End, AFE) können Bremsenergie in das
Netz zurückspeisen. Teuer, aber energieeffizient bei häufigem Bremsen
(Krane, Aufzüge, Prüfstände).

---

## EMV-Maßnahmen (sehr wichtig!)

Frequenzumrichter erzeugen durch PWM hochfrequente Störungen.
**EMV-Maßnahmen sind Pflicht** nach DIN EN 61800-3.

### Netzseite

| Maßnahme | Zweck |
|----------|-------|
| EMV-Filter (Netzfilter) | Unterdrückt HF-Rückwirkungen ins Netz |
| Netzdrossel (AC-Drossel) | Begrenzt Stromspitzen beim Laden der DC-Kondensatoren |
| RFI-Filter (integriert oder extern) | Entstörfilter nach Kategorie C2/C1 |

### Motorseite

| Maßnahme | Wann nötig |
|----------|-----------|
| **Geschirmtes Motorkabel** | Immer! Schirm beidseitig großflächig erden |
| Motordrossel (Ausgangsdrossel) | Leitungslänge > 50 m oder empfindlicher Motor |
| dU/dt-Filter | Leitungslänge > 100 m, Motor ohne VFD-Isolierung |
| Sinusfilter | Motor nicht VFD-geeignet oder sehr lange Leitungen |

### Erdung und Kabelverlegung

```
Frequenzumrichter
├── Netzanschluss: ungeschirmt (EMV-Filter nötig)
└── Motoranschluss: geschirmtes Kabel!
    ├── Schirm am FU: großflächig auf Metallgehäuse (PE-Schiene oder Schirmklemme)
    └── Schirm am Motor: großflächig auf Motorgehäuse (Kabelverschraubung mit Schirmkontakt)
```

> Schirm niemals nur an einem Ende anschließen — beidseitige
> Auflage ist Pflicht für kapazitive Ableitströme.

**Steuerleitungen** (Analogsignale, Encoder) räumlich getrennt von
Leistungsleitungen verlegen (≥ 30 cm Abstand, Kreuzung nur senkrecht).

---

## Verdrahtung: typischer Schaltungsaufbau

```
L1–L3 ──── Q1 (LSS Typ D oder Sicherung) ──── [EMV-Filter] ──── FU (Netzeingang)
                                                                      │
                                                              FU (Motorausgang)
                                                                      │
                                                              [Motordrossel]
                                                                      │
                                                    Geschirmtes Kabel (4-adrig L+PE)
                                                                      │
                                                                    Motor
                                                                (inkl. PTC → FU)
```

**Hinweis:** Kein Schütz zwischen Frequenzumrichter und Motor schalten
— ausschalten durch FU-Freigabe (Enable). Ein Schütz im Betrieb
aufzutrennen beschädigt die IGBTs.

---

## Energieersparnis: das Quadratgesetz

Bei Kreiselpumpen und Lüftern sinkt der Leistungsbedarf mit dem
**Kubus der Drehzahl** (Affinitätsgesetze):

```
P₂/P₁ = (n₂/n₁)³
```

| Drehzahl-Reduktion | Leistungsersparnis |
|:------------------:|:-----------------:|
| 100 % → 90 %       | ~27 %             |
| 100 % → 80 %       | ~49 %             |
| 100 % → 70 %       | ~66 %             |
| 100 % → 50 %       | ~87,5 %           |

> Eine Pumpe auf 80 % Drehzahl zu drosseln spart fast die Hälfte
> der Energie — deutlich mehr als ein Drosselventil.

---

## Lagerströme — das versteckte Problem

Hochfrequente Ableitströme können über die Motorwelle auf die Lager
fließen und **Lager-Pittings** verursachen (vorzeitiger Lagerausfall).

**Gegenmaßnahmen:**
- Isoliertes Lager (NDE-Seite, Nicht-Antriebsseite)
- Wellen-Erdungsring (z. B. AEGIS SGR) am Motor
- Geschirmtes Kabel mit beidseitiger Schirmauflage
- Gemeinsamer PE-Leiter (Motorgehäuse ↔ FU-Gehäuse)

Lagerstromproblem tritt auf ab ca. **30 kW** — bei kleinen Motoren
in der Regel vernachlässigbar.

---

## Häufige Fehler

| Fehler | Folge | Lösung |
|--------|-------|--------|
| Kein EMV-Filter | Netzrückwirkungen, RFI-Störungen | EMV-Filter einbauen |
| Motorleitung ungeschirmt | EMV-Störungen auf Signalleitungen | Geschirmtes Kabel verwenden |
| Schütz zwischen FU und Motor | IGBT-Schaden bei Betriebsschaltung | Schütz entfernen, FU-Enable nutzen |
| Bimetall-Thermorelay am Ausgang | Fehlauslösungen oder kein Schutz | FU-internen I²t-Schutz nutzen |
| Motorparameter nicht eingegeben | Schlechtes Anlaufverhalten, Überhitzung | Typenschild-Daten eingeben |
| Taktfrequenz zu hoch, Leitung zu lang | Überspannungsspitzen am Motor | Motordrossel oder dU/dt-Filter |
| Kein Bremswiderstand bei großer Masse | Überspannung-Abschaltung beim Bremsen | Bremswiderstand berechnen und einbauen |
