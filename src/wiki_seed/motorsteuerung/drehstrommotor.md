# Drehstromotoren – Aufbau, Typenschild und Betrieb

Der Drehstromasynchronmotor (Käfigläufermotor) ist der meistverwendete
Elektromotor in der Industrie. Robust, wartungsarm und in nahezu allen
Leistungsklassen verfügbar — vom Watt bis zum Megawatt.

> **Normen:** DIN EN 60034-1 (Betriebsverhalten), DIN EN 60034-5 (Schutzarten),
> DIN EN 60034-7 (Bauformen), DIN EN 60034-30-1 (Wirkungsgradklassen IE)

---

## 1. Funktionsprinzip

### Drehendes Magnetfeld

Die drei Phasen (L1, L2, L3) des Drehstromnetzes erzeugen im **Stator**
(Ständer) ein **rotierendes Magnetfeld** — das Ständerdrehfeld. Seine
Drehzahl heißt **synchrone Drehzahl** n_s:

```
       120 × f
n_s = ─────────   [U/min]
          p

f = Netzfrequenz (50 Hz)
p = Polzahl (2, 4, 6, 8 ...)
```

| Polzahl (p) | Synchrone Drehzahl (50 Hz) |
|:-----------:|:--------------------------:|
| 2           | 3000 U/min                 |
| 4           | 1500 U/min                 |
| 6           | 1000 U/min                 |
| 8           | 750 U/min                  |
| 12          | 500 U/min                  |

### Induktion und Schlupf

Das Ständerdrehfeld **induziert** Ströme im kurzgeschlossenen **Rotor**
(Läufer). Diese Rotorströme erzeugen ein eigenes Magnetfeld, das mit dem
Ständerfeld wechselwirkt → **Drehmoment**.

Damit Induktion stattfindet, muss der Rotor **langsamer** drehen als das
Ständerdrehfeld — er läuft nach, daher **Asynchronmotor**.

Der **Schlupf** s beschreibt diese Differenz:

```
       n_s − n
s =  ───────────  × 100 %
          n_s

n_s = synchrone Drehzahl
n   = tatsächliche Rotordrehzahl
```

Im Nennbetrieb: s = 2–8 % (typisch ~4 % bei 4-poligem Standardmotor).

**Beispiel:** 4-poliger Motor, n_s = 1500 U/min, s = 4 %
→ n = 1500 × (1 − 0,04) = **1440 U/min** (steht so auf dem Typenschild)

---

## 2. Aufbau

### Stator (Ständer)

- **Blechpaket** aus gestanzten Siliziumstahlblechen (reduziert Wirbelstromverluste)
- **Wicklung** in Nuten eingelegt, üblicherweise Kupferlackdraht
- **3 Stränge** (U, V, W), elektrisch um 120° versetzt
- **Gehäuse** aus Grauguss oder Aluminium, mit Kühlrippen

### Rotor (Läufer) — Käfigläufer

- **Blechpaket** ähnlich Stator, mit schräggestellten Nuten (Schrägnuten)
  für ruhigen Lauf
- **Aluminiumkäfig** (Druckguss) oder **Kupferstäbe** in den Nuten,
  am Ende durch Kurzschlussringe verbunden
- **Welle** aus Stahl, in Wälzlagern geführt
- Kein Schleifring, kein Kollektor → wartungsarm

### Lüfter und Kühlung

Standardmotor (IC411): Eigenlüftung durch aufgesteckten Lüfter auf
der Wellenrückseite — Kühlluft strömt über Kühlrippen.

Bei sehr langsamen Drehzahlen (Frequenzumrichter-Betrieb) kühlt der
Eigenlüfter nicht mehr ausreichend → **Fremdlüfter** (IC416) oder
**Motordrossel** + reduzierter Dauerbetrieb.

---

## 3. Das Typenschild — alle Angaben erklärt

```
┌─────────────────────────────────────────────────────┐
│  Musterfirma Motorenwerk GmbH                       │
│  Typ: M2AA 132 S-4    S/N: 2024-001234              │
├────────────────┬────────────────────────────────────┤
│  kW    5,5     │  Hz    50                          │
│  U/min 1450    │  cos φ 0,84                        │
│  Δ/Y   230/400 │  A  Δ 22,0 / Y 12,7               │
│  IP 55         │  IC 411   IM B3                    │
│  Kl. F / B     │  kg  42                            │
└────────────────┴────────────────────────────────────┘
```

| Angabe | Bedeutung | Beispiel |
|--------|-----------|---------|
| **kW** | Nennleistung (Wellenleistung) | 5,5 kW |
| **U/min** | Nenndrehzahl (bei Nennlast) | 1450 U/min |
| **Hz** | Nennfrequenz | 50 Hz |
| **cos φ** | Leistungsfaktor bei Nennlast | 0,84 |
| **Δ/Y** | Nennspannung für Dreieck/Stern | 230/400 V |
| **A Δ/Y** | Nennstrom für Dreieck/Stern | 22,0/12,7 A |
| **IP** | Schutzart (→ Artikel IP-Schutzarten) | IP55 |
| **IC** | Kühlart | IC411 (Eigenlüftung) |
| **IM** | Bauform / Montageart | B3 (Fußmotor) |
| **Kl. F / B** | Isolationsklasse / Temperaturklasse | F/B |
| **kg** | Masse | 42 kg |

---

## 4. Stern- und Dreieckschaltung der Wicklung

### Wicklungsanschlüsse am Klemmenkasten

| Klemme | Bedeutung |
|:------:|-----------|
| U1, V1, W1 | Wicklungsanfänge |
| U2, V2, W2 | Wicklungsenden |

### Sternschaltung (Y)

```
       U1 ─── Wicklung U ─── U2 ─┐
       V1 ─── Wicklung V ─── V2 ──┤── Sternpunkt (verbunden)
       W1 ─── Wicklung W ─── W2 ─┘
```

Anschluss: U2–V2–W2 mit Brücken verbunden.
Spannung je Wicklung: **U_Netz / √3** (bei 400V-Netz → 231 V je Wicklung)

### Dreieckschaltung (Δ)

```
U1 ─── Wicklung U ─── U2 = W1 ─── Wicklung W ─── W2 = V1 ─── Wicklung V ─── V2 = U1
```

Anschluss: U1–W2, V1–U2, W1–V2 mit Brücken verbunden.
Spannung je Wicklung: **U_Netz** (bei 400V-Netz → 400 V je Wicklung)

### Welche Schaltung wann?

| Typenschild | 230/400 V | Netz 400 V | Schaltung |
|-------------|:---------:|:----------:|:---------:|
| **230/400 V** | — | 400 V | **Y** (Stern) |
| **400/690 V** | — | 400 V | **Δ** (Dreieck) |

> Faustregel: Linke Typenschildspannung (Δ) = Netzspannung → Dreieck.
> Rechte Typenschildspannung (Y) = Netzspannung → Stern.

---

## 5. Drehzahl-Drehmoment-Kennlinie

```
Drehmoment
    │
M_k ┤        ╭──────╮
    │       ╱        ╲
M_N ┤──────╱            ╲──────────────────
    │     ╱              ╲
M_A ┤────╱                ╲
    │   (Anlauf)     (Sattel)   (Nennpunkt)
    └────────────────────────────────────────→ Drehzahl
    0                          n_N    n_s
```

| Punkt | Bezeichnung | Typischer Wert |
|-------|------------|:--------------:|
| M_A   | Anzugsmoment (bei n=0) | 0,5–1,5 × M_N |
| M_S   | Sattelmoment (Minimum) | 0,3–1,0 × M_N |
| M_k   | Kippmoment (Maximum) | 2,0–3,5 × M_N |
| M_N   | Nennmoment (Betriebspunkt) | 1,0 × M_N |

**Nennmoment berechnen:**

```
        P_N × 9550
M_N = ──────────────   [N·m]
            n_N

P_N in kW, n_N in U/min
```

**Achtung:** Der Motor kann nur anlaufen, wenn das Anzugsmoment M_A
**größer** als das Lastmoment bei Stillstand ist!

---

## 6. Wirkungsgradklassen (IE-Klassen)

Seit 2011 (IE2), ab 2015/2017/2021 schrittweise verschärft:

| IE-Klasse | Bezeichnung | Pflicht ab (≤ 375 kW, 2-/4-/6-polig) |
|:---------:|-------------|:------------------------------------:|
| IE1       | Standard Efficiency | verboten für Neuinstallation (≥ 0,75 kW) |
| **IE2**   | High Efficiency | Mindestanforderung ohne FU |
| **IE3**   | Premium Efficiency | Pflicht ab 0,75 kW (seit 07/2021) |
| IE4       | Super Premium | freiwillig, Ziel für FU-Betrieb |
| IE5       | Ultra Premium | Dauermagneterregte Motoren |

> **Praxis:** Seit Juli 2021 müssen neue Motoren von 0,75–1000 kW
> mindestens **IE3** erfüllen. Ältere IE2-Motoren haben Bestandsschutz.

---

## 7. Thermische Isolationsklassen

Die Isolationsklasse bestimmt die **maximale Wicklungstemperatur**:

| Klasse | Max. Wicklungstemperatur | Umgebung + Übertemperatur |
|:------:|:------------------------:|:-------------------------:|
| A      | 105°C                    | 40°C + 60K + 5K Reserve   |
| E      | 120°C                    | 40°C + 75K + 5K Reserve   |
| **B**  | **130°C**                | 40°C + 80K + 10K Reserve  |
| **F**  | **155°C**                | 40°C + 105K + 10K Reserve |
| H      | 180°C                    | 40°C + 125K + 15K Reserve |

**Typenschild „Kl. F / B"** bedeutet:
- Wicklung ist mit **Klasse F**-Material isoliert
- Motor ist aber nur für **Klasse B**-Temperaturerhöhung ausgelegt
  → **Reserven vorhanden** (häufig bei modernen Motoren)

---

## 8. Kühlarten (IC-Code) — Auswahl

| IC-Code | Kühlung | Typische Anwendung |
|:-------:|---------|-------------------|
| IC411   | Eigenlüftung (Lüfter auf Welle) | Standard, alle Drehzahlen konstant |
| IC416   | Fremdlüftung (separater Motor) | FU-Betrieb mit niedriger Drehzahl |
| IC411/416 | Kombiniert | Wechselbetrieb |
| IC410   | Eigenlüftung ohne Lüfter | Sehr kleine Motoren |
| IC418   | Innenluft-Umwälzung mit Wärmetauscher | Schutzart IP54/65, keine Außenluft |

---

## 9. Bauformen (IM-Code) — Auswahl

| IM-Code | Bauform | Beschreibung |
|:-------:|---------|-------------|
| **B3**  | Fußmotor | Horizontale Welle, Fußmontage (Standard) |
| **B5**  | Flanschmotor | Horizontale Welle, Flansch an DE-Seite |
| **B14** | Klemmflansch | Kleiner Flansch, verschraubt |
| V1      | Vertikale Welle, DE unten | Tauchpumpen, Rührer |
| V3      | Vertikale Welle, DE oben | Krananwendungen |

---

## 10. Motortypen im Vergleich

| Typ | Prinzip | Stärken | Schwächen |
|-----|---------|---------|-----------|
| **Käfigläufer (ASM)** | Induktion, kurzgeschlossener Rotor | Robust, wartungsarm, günstig | Schlupf, keine Drehzahlregelung ohne FU |
| **Schleifringläufer** | Induktion, Rotor mit Schleifringen | Hohes Anzugsmoment, Anlasswiderstand | Schleifringe verschleißen, aufwendig |
| **Synchronmotor (PM)** | Permanentmagnete im Rotor | Hoher Wirkungsgrad (IE4/5), kein Schlupf | Braucht immer FU, teurer |
| **Reluktanzmotor** | Salienter Rotor ohne Magnete | IE4 ohne seltene Erden | Braucht FU, Schwingungen |

---

## 11. Anschlussklemmen – Standard-Belegung Klemmenkasten

6-polige Klemmenleiste für Y/Δ-Schaltung:

```
┌─────┬─────┬─────┐
│ W2  │ U2  │ V2  │  ← Wicklungsenden (oben)
├─────┼─────┼─────┤
│ U1  │ V1  │ W1  │  ← Wicklungsanfänge (unten)
└─────┴─────┴─────┘
  L1    L2    L3    ← Netzanschluss an U1/V1/W1

Sternschaltung (Y):       Dreieckschaltung (Δ):
W2–U2–V2 verbunden        U1–W2, V1–U2, W1–V2 verbunden
```

**PE-Anschluss:** Immer im Klemmenkasten vorhanden (Gehäuse-Erdung Pflicht!).
**PTC/Kaltleiter:** Wenn vorhanden, eigene 2-polige Klemmen (T1/T2 oder PTC).

---

## 12. Checkliste: Motor in Betrieb nehmen

1. **Typenschild prüfen:** Spannung, Schaltung (Y/Δ) und Frequenz stimmen mit Netz überein?
2. **Wicklungswiderstand messen:** Alle drei Stränge gleich? (Grober Wicklungstest)
3. **Isolationsmessung:** Wicklung gegen Gehäuse ≥ 1 MΩ (500 V DC Megger)
4. **Lagergeräusch prüfen:** Motor kurz von Hand drehen — läuft er leicht?
5. **Drehrichtung prüfen:** Kurz einschalten, Drehrichtung kontrollieren
   → falsch: zwei Phasen tauschen (L1↔L2 oder beliebige zwei)
6. **Leerlaufstrom messen:** ca. 30–60 % des Nennstroms (je nach Motor)
7. **Thermorelay / FU-Schutz einstellen:** I_N vom Typenschild eingeben
8. **Lagertemperatur nach 1h Betrieb prüfen:** max. 70–80°C (Handprüfung: kurz anfassbar)

---

## Quellen

- DKE Normendatenbank: [DIN EN 60034-30-1 (VDE 0530-30-1):2014-12](https://www.dke.de/de/normen-standards/dokument?id=7049254&type=dke%7Cdokument)
- elektro.net: [Wirkungsgrad-Klassifizierung](https://www.elektro.net/94709/wirkungsgrad-klassifizierung/)
- ElekRechner: [Elektromotoren-Grundlagen: Typenschild lesen, Anlaufarten & IE-Effizienzklassen](https://www.elekrechner.com/ratgeber/grundlagen/elektromotoren-grundlagen)

*Hinweis: Die IE3-Pflicht ab 0,75 kW seit Juli 2021 sowie Bestandsschutz für
ältere IE2-Motoren beziehen sich auf die EU-Ökodesign-Verordnung 2019/1781 in
Verbindung mit DIN EN 60034-30-1 — bei neuen Grenzwerten/Ausnahmen die
jeweils aktuelle Verordnungsfassung prüfen.*
