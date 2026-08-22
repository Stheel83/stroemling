# Sanftanlasser – Funktionsweise und Einsatz

Der Sanftanlasser (auch Softstarter) ermöglicht einen strom- und
drehmomentbegrenzten Anlauf von Drehstrommotoren ohne die
mechanischen Stöße und Netzbelastungen des Direktanlaufs — und
ohne die Nachteile des Stern-Dreieck-Anlassers.

> **Normen:** DIN EN 60947-4-2 (Halbleiter-Motorstarter), DIN EN 60034-1

---

## Funktionsprinzip

Der Sanftanlasser sitzt zwischen Netz und Motor und besteht aus
**antiparallelen Thyristorpaaren** (je zwei pro Phase):

```
Netz L1 ──── [Thyristorpaar] ──── Motor U1
Netz L2 ──── [Thyristorpaar] ──── Motor V1
Netz L3 ──── [Thyristorpaar] ──── Motor W1
```

Durch **Phasenanschnittsteuerung** (Zündwinkelsteuerung) steuern die
Thyristoren, welcher Teil jeder Halbwelle an den Motor weitergegeben wird:

- **Kleiner Zündwinkel** → wenig Spannung → geringes Drehmoment und Strom
- **Großer Zündwinkel** → volle Spannung → voller Betrieb

Beim Anlauf wird der Zündwinkel von groß nach klein gerampt → Spannung
steigt von einem einstellbaren Startwert auf 100 % → Motor beschleunigt
sanft und kontrolliert.

---

## Vergleich Anlaufverfahren

| Merkmal | Direktanlauf | Stern-Dreieck | Sanftanlasser | Frequenzumrichter |
|---------|:---:|:---:|:---:|:---:|
| Anlaufstrom | 5–8 × I_N | 1,5–2,7 × I_N | **1,5–4 × I_N** einstellbar | **< 1,5 × I_N** einstellbar |
| Anlaufdrehmoment | 100 % | 33 % | 30–80 % einstellbar | 0–150 % einstellbar |
| Spannungssprung bei Umschaltung | — | ja (Stromstoß) | kein | kein |
| Drehzahlregelung im Betrieb | nein | nein | nein | **ja** |
| Sanftes Abbremsen | nein | nein | **ja** (optional) | **ja** |
| Kosten | gering | mittel | mittel | hoch |

---

## Einstellparameter

### Anlaufspannung (U_start)

Die **Anfangsspannung** beim Einschalten — bestimmt das Losbrechmoment.

- Zu niedrig → Motor läuft nicht los (Last überwiegt Losbrechmoment)
- Zu hoch → Anlaufstromstoß zu groß
- Typisch: **30–50 % U_N** (je nach Lastwiderstand)

### Anlaufzeit (t_start / Ramp-Up-Time)

Zeit, in der die Spannung von U_start auf 100 % ansteigt.

- Zu kurz → kaum Unterschied zum Direktanlauf
- Zu lang → Motor wird warm (Schlupfverluste während langer Anlaufphase)
- Typisch: **3–30 Sekunden** (bei pumpen/lüfter eher 5–15 s)

### Strombegrenzung (I_max)

Viele Sanftanlasser können den Strom auf einen Maximalwert begrenzen
(z. B. 3 × I_N). Die Spannungsrampe wird dann automatisch verlangsamt,
wenn der Grenzstrom erreicht wird.

Vorteil: Reproduzierbarer Anlauf unabhängig von Lastschwankungen.

### Auslaufzeit (t_stop / Ramp-Down-Time)

Optionale **Sanftabbremsrampe**: Spannung wird beim Ausschalten
kontrolliert von 100 % auf 0 % gerampt.

Nützlich bei:
- Kreiselpumpen (verhindert Druckstoß / Wasserhammer)
- Förderbänder (keine Erschütterung)
- Lüfter (kein Massenträgheits-Ruck)

---

## Schaltungsaufbau in der Praxis

### Ohne Bypass-Schütz (einfach)

```
L1–L3 ── Q1 (MSS) ── Sanftanlasser ── Motor
```

Nachteil: Sanftanlasser bleibt im Strompfad, erzeugt im Dauerbetrieb
Verluste (Thyristor-Durchlassspannung ~1–2 V × I_N = Wärme).

### Mit Bypass-Schütz (Standard in der Praxis)

```
L1–L3 ── Q1 ── Sanftanlasser ──┬── Motor
                     └──── K_Bypass ─── Motor
```

Nach abgeschlossenem Anlauf:
1. Sanftanlasser meldet „Anlauf fertig"
2. Bypass-Schütz K_Bypass schließt (Motor direkt ans Netz)
3. Sanftanlasser schaltet intern ab (kein Verlust mehr)

Die meisten modernen Sanftanlasser haben den Bypass **intern integriert**.

### Typischer Steuerstromkreis

```
L ── S0 (NOT-HALT, Öffner) ── S1 (EIN) ──┬── Sanftanlasser [IN+]
                                          └── K1 (Bypass, intern)
N ── Sanftanlasser [IN–]
```

Sanftanlasser übernimmt Steuerung von K_Bypass und Thermorelay-Funktion selbst.

---

## Integrierter Motorschutz

Moderne Sanftanlasser ersetzen das externe Thermorelay:

| Schutzfunktion | Beschreibung |
|----------------|-------------|
| Thermischer Motorschutz | I²t-Modell, parametrierbar mit Motor-I_N und Klasse |
| Phasenausfallschutz | Erkennt fehlende Phase |
| Phasenfolge-Überwachung | Falscher Drehsinn → kein Anlauf |
| Unterspannungsschutz | Abschaltung bei zu niedriger Netzspannung |
| Überstromschutz | Sofortabschaltung bei Kurzschluss-Strom |
| Motorblockierung | Erkennt blockierten Motor (Strom hoch, kein Anlauf) |

---

## Wann Sanftanlasser, wann Frequenzumrichter?

**Sanftanlasser ist die bessere Wahl wenn:**
- Nur Anlauf und ggf. Auslauf geregelt werden sollen
- Die Betriebsdrehzahl konstant bleiben soll
- Kosten wichtig sind (Sanftanlasser günstiger als FU)
- Kreiselpumpen, Lüfter, Kompressoren (Anlaufstrom-Problem)

**Frequenzumrichter ist die bessere Wahl wenn:**
- Drehzahlregelung im Betrieb benötigt wird
- Energie gespart werden soll (Drehzahlabsenkung)
- Sehr sanfter Anlauf mit konstantem Drehmoment nötig ist
- Regeneratives Bremsen benötigt wird

---

## Häufige Fehler bei der Inbetriebnahme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| Motor läuft nicht an | U_start zu niedrig | Startwert erhöhen |
| Anlaufstrom zu hoch | Rampe zu kurz / U_start zu hoch | Rampe verlängern |
| Motor wird im Anlauf heiß | Anlaufzeit zu lang | Rampe verkürzen oder Motor für häufige Anlaufzyklen prüfen |
| Abschaltung bei Anlauf | I_max-Grenze zu niedrig | Strombegrenzung erhöhen |
| Druckstoß bei Pumpe | Auslaufzeit nicht parametriert | t_stop einstellen |

---

## Quellen

- Wikipedia: [Sanftanlauf](https://de.wikipedia.org/wiki/Sanftanlauf)
- e-hack.de: [Sanftanlaufgerät – Definition, Prinzip und Funktionsweise](https://www.e-hack.de/sanftanlaufgeraet-definition-und-funktionsweise/)
- Eaton: [Handbuch DS7 Softstarter](https://www.eaton.com/content/dam/eaton/technicaldocumentation/mn/MN03901001Z_DE.pdf)

*Hinweis: Einstellwerte (Anlaufspannung, Rampenzeiten, Strombegrenzung)
sind Praxis-Richtwerte — die konkreten Parametergrenzen und
Werkseinstellungen unterscheiden sich je Sanftanlasser-Hersteller/-Baureihe,
Herstellerhandbuch vor der Inbetriebnahme prüfen.*
