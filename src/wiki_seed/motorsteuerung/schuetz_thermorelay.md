# Schütz + Thermorelay – Grundschaltung Motorsteuerung

Die Kombination aus Schütz und Thermorelay ist die klassische
Direktanlauf-Schaltung für Drehstrommotoren — einfach, robust,
zuverlässig und nach wie vor weit verbreitet.

> **Normen:** DIN EN 60947-4-1 (Schütze), DIN EN 60947-4-1 (Überlastrelais)

---

## Schaltungsprinzip

```
L1 ──┬── Q1 (LSS) ── K1 (Schütz, Hauptkontakt 1/2) ─── U1 (Motor)
L2 ──┼── Q1         ── K1 (Hauptkontakt 3/4)        ─── V1
L3 ──┴── Q1         ── K1 (Hauptkontakt 5/6)        ─── W1
                        └── F1 (Thermorelay)             PE
                             └── Motor
```

**Steuerstromkreis:**

```
L1 ── S0 (NOT-HALT, Öffner) ── F1:95/96 (Öffner) ── S1 (EIN, Schließer)
   ─── K1:13/14 (Selbsthaltekontakt, parallel zu S1)
   ─── K1:A1 (Spule)
N  ── K1:A2
```

---

## Bauelemente im Einzelnen

### Leistungsschalter Q1 (LSS / Motorschutzschalter)

Schützt die Zuleitung und das Schütz vor Kurzschlüssen.
- Typ C oder D (Motoranlaufstrom)
- Nennstrom: nach Motorleistung und Verlegeart

### Schütz K1

Schaltet den Hauptstromkreis ein und aus.
- **Spulenspannung** wählen: 230 V AC (L–N) oder 24 V DC (Steuerung)
- Hauptkontakte: 1/2, 3/4, 5/6 (Schließer)
- Hilfskontakt 13/14 für Selbsthaltung

**Schützauswahl nach Motorleistung (AC-3, 230/400 V):**

| Motorleistung | Schützgröße (Siemens) | I_e bei 400 V |
|:-------------:|:---------------------:|:-------------:|
| bis 4 kW      | 3RT2015 (S00)         | 7 A           |
| bis 7,5 kW    | 3RT2023 (S0)          | 9 A           |
| bis 11 kW     | 3RT2026 (S0)          | 25 A          |
| bis 22 kW     | 3RT2035 (S2)          | 40 A          |
| bis 37 kW     | 3RT2044 (S3)          | 65 A          |

### Thermorelay F1 (Überlastrelais)

Schützt den Motor vor thermischer Überlastung.
- Einstellbereich: auf Motornennstrom I_N einstellen
- Kontakte: **95/96** (Öffner) in Steuerstromkreis, **97/98** (Schließer) für Meldung

**Einstellung:** I_Einstell = I_N (Motor-Nennstrom lt. Typenschild)

Bei Δ-Schaltung des Motors: I_Einstell = I_N × 0,58 (Strangstrom statt Leiterstrom)

---

## NOT-HALT-Kreis (S0)

Der NOT-HALT-Taster (S0) ist ein **Öffner** in Reihe im Steuerstromkreis.
Betätigung öffnet den Kreis → Schütz fällt ab → Motor stoppt sofort.

**Wichtig:** NOT-HALT muss auch bei Spannungsausfall in der Ausgangsstellung
bleiben (Rastfunktion). Rückstellen nur manuell möglich.

---

## Selbsthaltung

Der Hilfskontakt 13/14 (Schließer) liegt **parallel zum EIN-Taster S1**.
Nach Loslassen von S1 hält K1 sich selbst gehalten — bis S0 oder S_AUS
(Öffner in Reihe) den Kreis unterbricht.

```
S1 ─┬─ K1:A1 (Spule EIN)
    └─ K1:13/14 (Selbsthaltung, parallel zu S1)
```

---

## Thermorelay: Rückstellen nach Auslösung

Nach Auslösung des Thermorelays (Überlastfall):
1. **Motor abkühlen lassen** (mindestens 5–10 Minuten)
2. Ursache der Überlast beheben
3. Rückstellknopf am Thermorelay drücken (Hand-Reset)
4. Steuerstromkreis schließt wieder — Motor bereit

**Automatisches Rückstellen** (Auto-Reset) vermeiden bei unbeaufsichtigten
Anlagen: Motor würde nach Abkühlung automatisch wiederanlaufen → Unfallgefahr.
