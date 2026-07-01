# Stern-Dreieck-Anlasser

Der Stern-Dreieck-Anlasser (Y-Δ-Anlasser) reduziert den Einschaltstrom
beim Anlaufen großer Drehstrommotoren auf ein Drittel des direkten
Anlaufstroms — auf Kosten des Anlaufdrehmoments.

> **Norm:** DIN EN 60947-4-1

---

## Warum Stern-Dreieck?

Beim **Direktanlauf** (Schütz allein) zieht ein Drehstrommotor den
**5–8-fachen Nennstrom** als Anlaufstrom. Bei großen Motoren belastet
das das Netz spürbar (Spannungseinbruch) und kann andere Verbraucher stören.

**Lösung:** Motor startet in **Sternschaltung** (Y) mit reduzierter Spannung
je Wicklung, schaltet nach dem Anlaufen in **Dreieckschaltung** (Δ) um.

| | Direktanlauf | Stern-Anlauf | Dreieck-Betrieb |
|---|:---:|:---:|:---:|
| Spannung je Wicklung | 400 V | 231 V (= 400/√3) | 400 V |
| Anlaufstrom | 5–8 × I_N | **1,5–2,7 × I_N** | — |
| Anlaufdrehmoment | 100% | **33%** | 100% |

---

## Schaltungsaufbau

Drei Schütze:
- **K1** — Netzschütz (Hauptschütz, immer geschlossen im Betrieb)
- **KY** — Sternschütz (verbindet W2, U2, V2 zu Sternpunkt)
- **KΔ** — Dreieckschütz (verbindet W2-U1, U2-V1, V2-W1)

```
Netz ── K1 ──┬── U1, V1, W1 (Motor-Wicklungsanfänge)
             │
             └── KΔ ──── W2-U1, U2-V1, V2-W1 (Dreieck-Querverdrahtung)

             KY ──── U2, V2, W2 (Sternpunkt, im Y-Betrieb verbunden)
```

**Verriegelung:** KY und KΔ müssen **elektrisch und mechanisch** gegeneinander
verriegelt sein — gleichzeitiger Betrieb ergibt Kurzschluss!

---

## Ablaufsequenz

```
EIN-Taster:
  1. K1 (Netzschütz) anzieht
  2. KY (Sternschütz) anzieht → Motor läuft in Y an
  3. Zeitrelais KT startet (typisch: 3–10 Sekunden)
  4. Zeitrelais KT löst aus:
     a. KY fällt ab (Stern öffnet)
     b. kurze Pause (5–50 ms, Lichtbogenlöschung)
     c. KΔ zieht an (Dreieck schließt)
  5. Motor läuft in Δ weiter
```

---

## Umschaltzeitpunkt richtig wählen

| Zeitpunkt | Folge |
|-----------|-------|
| Zu früh (Motor noch nicht beschleunigt) | Hoher Stromspitzen beim Δ-Einschalten, mechanischer Ruck |
| Richtig (Motor hat ca. 80% Nenndrehzahl) | Sanfter Übergang, geringer Stromstoß |
| Zu spät | Kein Nachteil, aber unnötig lange Anlaufzeit |

Faustregel: **3–8 Sekunden** für normale Lasten. Für Schwungmassen
oder Pumpen ggf. 10–15 Sekunden testen.

---

## Wann Y-Δ sinnvoll — wann nicht?

**Geeignet:**
- Motoren ≥ 7,5 kW (kleinere lohnen selten)
- Anlagen die beim Anlauf **unbelastet** starten können (Pumpen, Lüfter, Kompressoren im Leerlauf)
- Netz mit Anlaufstrom-Begrenzung durch EVU

**Nicht geeignet:**
- Anlagen die **belastet** anlaufen müssen (Förderbänder, Heber, Krananlagen)
- Antriebe mit hohem Massenträgheitsmoment ohne Reduziermöglichkeit
- Wenn 33% Anlaufdrehmoment nicht ausreicht zum Losreißen

**Moderne Alternative:** Frequenzumrichter (sanfter Anlauf, einstellbares
Drehmoment, Energiesparbetrieb — aber höhere Anschaffungskosten).

---

## Thermorelay-Einstellung bei Y-Δ

Das Thermorelay schützt im **Δ-Betrieb** (Dauerbetrieb). Einstellung:

- Thermorelay im Hauptstromkreis (nach K1, vor Motor): I_Einstell = **I_N**
- Thermorelay nach KΔ (nur Dreieck-Zweig): I_Einstell = **I_N × 0,58**

Üblich: Thermorelay im Hauptstromkreis, Einstellung auf Motor-Nennstrom.
