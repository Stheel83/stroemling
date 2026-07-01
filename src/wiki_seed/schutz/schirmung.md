# Schirmung – Konzepte, Feldtypen und Praxis

Schirmung ist eine der wichtigsten Maßnahmen zur elektromagnetischen
Verträglichkeit (EMV). Der entscheidende Fehler in der Praxis ist
nicht das Fehlen eines Schirms — sondern seine falsche Verlegung
und Erdung. Ein falsch geerdeteter Schirm kann mehr schaden als nützen.

> **Normen:** DIN EN 61000-5-2 (EMV Erdung und Schirmung),
> DIN VDE 0100-444 (EMV in Gebäudeinstallationen),
> DIN EN 50174-2 (Verkabelung, Installationsplanung)

---

## 1. Die drei Feldtypen — was koppelt sich wie ein?

Störungen koppeln sich auf drei physikalisch unterschiedliche Arten ein.
Die Art der Kopplung bestimmt, welche Gegenmaßnahme wirkt.

### Elektrisches Feld (E-Feld) — kapazitive Kopplung

```
Störquelle (hohes Potential)
        │
        │  kapazitiv (wie Kondensator)
        │
  Störung in Nachbarleitung
```

- Entsteht durch **Spannungsunterschiede** zwischen benachbarten Leitern
- Koppelt sich über die **Kapazität** zwischen Leitern ein
- Frequenzunabhängig bei gleicher Geometrie — aber höhere Frequenz = mehr Strom
- Typische Quellen: Netzleitungen, Schaltspannungen, IGBT-Flanken

**Abschirmen:** Metallischer Schirm leitet E-Feld zur Erde ab.
**Einseitige Erdung reicht** — der Schirm zieht das Feld auf sich und
leitet es zur Erde. Kein Strom muss fließen.

### Magnetisches Feld (H-Feld) — induktive Kopplung

```
Störquelle (Strom fließt)
     ↕ (Magnetfeld ringförmig um Leiter)
  induzierte Spannung in Schleife (U = dΦ/dt)
```

- Entsteht durch **fließende Ströme** in der Störquelle
- Induziert Spannung proportional zur **eingeschlossenen Leiterschleife**
  (Faradaysches Induktionsgesetz)
- Je größer die Schleifenfläche der Signalleitung — desto mehr Störspannung
- Typische Quellen: Trafos, Motoren, Leitungen mit hohem Wechselstrom,
  Schütze beim Schalten

**Abschirmen:** Schwierig! Metallischer Schirm allein hilft bei
Niederfrequenz kaum. Wirksame Maßnahmen:
- **Verdrillte Leiter (Twisted Pair):** aufeinanderfolgende Schleifenhälften
  kompensieren sich (Feld hebt sich auf)
- **Ferromagnetischer Schirm** (Stahl, µ-Metall): leitet Feldlinien um —
  aufwendig und schwer
- **Minimale Leiterschleife:** Hin- und Rückleiter dicht nebeneinander,
  kurze Leitungslängen

### Elektromagnetisches Feld (EM-Feld) — Welleneinkopplung

```
Störwelle (HF, > ~1 MHz)
     ↓↓↓↓↓↓↓
  Leitung als Antenne
```

- Bei **hohen Frequenzen** (ab ca. 1 MHz) wird Strahlung dominant
- Leitungen wirken als Empfangsantennen
- Typische Quellen: Mobilfunk, WLAN, Radar, Leistungselektronik
  (IGBT-Schaltflanken mit Oberwellen bis in den MHz-Bereich)

**Abschirmen:** Metallischer Schirm, **beidseitig geerdet** — erzeugt
Gegenstrom im Schirm, der das eindringende Feld kompensiert (Faradayscher
Käfig). Nur beidseitige Erdung schließt den Stromkreis für den Gegenstrom!

---

## 2. Einseitige Erdung — wann und warum

```
Signal-    ┌────────────────────────────────┐ Signal-
quelle     │ ≈≈≈≈≈≈≈≈≈≈≈ Schirm ≈≈≈≈≈≈≈≈≈ │ empfänger
           └────────────────────────────────┘
                │                    (offen)
               GND (nur eine Seite)
```

**Wirkung:** Schirm liegt auf definiertem Potential → E-Feld wird
abgeleitet. Kein Schirmstrom kann fließen → keine Brummschleife.

**Geeignet für:**
- Analoge Niederfrequenz-Signale (0–10 V, 4–20 mA, Thermoelement, PT100)
- Audiokabel, Messleitungen
- Überall, wo Potenzialunterschiede zwischen Quelle und Empfänger
  auftreten können (Ausgleichsströme müssten vermieden werden)
- Leitungslängen < 10–20 m

**Nicht geeignet für:**
- Hochfrequente Störer (FU, IGBT) — kein Schirmstrom möglich, kein HF-Schutz
- Lange Leitungen in stark gestörter Umgebung

**Praxis:** Schirm einseitig an der **Quelle** (niederohmiger Ausgang)
erden, am Empfänger auflegen aber isolieren (nicht direkt erden).
Bei 4–20-mA-Schleifen: Schirm nur an der Geberseite.

---

## 3. Beidseitige Erdung — wann und warum

```
Signal-    ┌────────────────────────────────┐ Signal-
quelle     │ ≈≈≈≈≈≈≈≈≈≈≈ Schirm ≈≈≈≈≈≈≈≈≈ │ empfänger
           └────────────────────────────────┘
                │                        │
               GND                      GND
```

**Wirkung:** Schirm ist an beiden Enden geerdet → bei HF-Störung
fließt Gegenstrom durch Schirm → Kompensation. Niedriger
Schirm-Impedanzpfad auch für hochfrequente Ströme geschlossen.

**Geeignet für:**
- Frequenzumrichter-Motorleitungen (Pflicht!)
- Digitale Feldbus-Leitungen (PROFIBUS, EtherNet/IP, PROFINET)
- Leitungen in HF-reicher Umgebung (Schaltschränke mit FU)
- Leitungslängen > 20–30 m in gestörter Umgebung
- Encoder-Leitungen

**Problem: Brummschleife (50-Hz-Ausgleichsstrom)**

Wenn zwischen den beiden Erdungspunkten ein **Potenzialunterschied**
besteht (erdschleifengebundener Strom bei 50 Hz), fließt ein Strom
durch den Schirm. Dieser induziert eine Störspannung im Inneren:

```
GND-Punkt A ─── Schirm ─── GND-Punkt B
     │                           │
  Potenzial-Differenz ΔU (50 Hz)
  → Schirmstrom → Brummen (50 Hz) im Signal
```

**Lösung bei Brummschleifen:**
- Trenntrafo oder Trennverstärker (galvanische Trennung)
- Potenzialausgleich zwischen Anlagenteilen verbessern (dicker PE-Leiter)
- HF-Durchgangskapazität: Schirm an einer Seite über Kondensator
  (100 nF) zur Erde — lässt NF-Brummstrom nicht, aber HF-Strom durch

---

## 4. Schirmtypen und ihre Eigenschaften

### Geflechtschirm

```
Innenleiter ══════════════════════════
            ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱
            ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲
```

- **Deckungsgrad:** 85–98 % (je nach Flechtdichte)
- Sehr gute **HF-Abschirmung** durch niedrige Transferimpedanz
- Mechanisch robust, biegefähig
- Gute Schirmkontaktierung (360°-Auflage mit Kabelverschraubung)
- Standard für Motorleitungen, Busleitungen

### Folienschirm (Aluminiumfolie + Drainwire)

```
Innenleiter ══════════════════════════
            ██████████████████████████  ← Alu-Folie
            ─────────────────────────   ← Drainwire
```

- **Deckungsgrad:** 100 % (lückenlos)
- Sehr gute E-Feld-Abschirmung
- Schlechter bei mechanischer Beanspruchung (Folie reißt)
- Kontaktierung nur über Drainwire → höhere Impedanz
- Standard bei analogen Messleitungen, Audioleitungen

### Kombischirm (Folie + Geflecht)

- Deckungsgrad 100 % + niedrige HF-Impedanz
- Beste Gesamtabschirmung
- Teurer und steifer
- Für anspruchsvolle Anwendungen: Servoantriebe, Messkabel in EMV-Zonen

### Paarschirm vs. Gesamtschirm

| Schirmkonzept | Aufbau | Anwendung |
|---------------|--------|-----------|
| **Gesamtschirm** | Ein Schirm um alle Adern | Einfache Trennung vom Außen |
| **Paarschirm** | Jedes Aderpaar einzeln abgeschirmt | Übersprechen zwischen Paaren unterdrücken |
| **Kombination** | Paarschirm + Gesamtschirm | Maximale Entkopplung (z. B. PROFIBUS PA) |

---

## 5. Schirmwirkung — die wichtigsten Kenngrößen

### Schirmdämpfung a_s (dB)

Verhältnis von Störspannung ohne zu mit Schirm. Je höher, desto besser.

| Schirmtyp | Schirmdämpfung (typisch) |
|-----------|:------------------------:|
| Folienschirm, einseitig geerdet | 30–50 dB |
| Geflechtschirm (85%) beidseitig | 60–80 dB |
| Kombischirm beidseitig | 80–100 dB |

### Transferimpedanz Z_T (mΩ/m)

Beschreibt, wie gut der Schirm HF-Ströme ohne Spannungsabfall leitet.
Niedriger Z_T = besser.

| Schirmtyp | Z_T bei 10 MHz |
|-----------|:--------------:|
| Drainwire (Folie) | 50–200 mΩ/m |
| Geflecht 85% | 5–20 mΩ/m |
| Geflecht 95% | 1–5 mΩ/m |
| Kombischirm | < 1 mΩ/m |

---

## 6. Wann welche Schirmung?

| Situation | Empfohlene Schirmung | Erdung |
|-----------|---------------------|--------|
| Analoges 4–20-mA-Signal, kurze Leitung | Geflechtschirm | einseitig |
| Analoges Signal, lange Leitung, viel Störer | Kombischirm + Trennverstärker | einseitig oder galv. Trennung |
| PT100 / Thermoelement | Folienschirm oder Geflecht | einseitig |
| PROFIBUS DP | Geflecht oder Kombischirm | beidseitig |
| PROFINET, EtherNet/IP | Kategorie-Kabel mit Gesamtschirm | beidseitig |
| Encoder-Leitung am FU | Kombischirm | beidseitig, 360°-Auflage |
| Motorleitung am FU | Geflecht-Schirm, 4-adrig (3×L + PE) | **beidseitig, 360°-Auflage am FU und Motor** |
| Steuerkabel in Schaltschrank ohne FU | Geflecht oder ungeschirmt | je nach Störumgebung |
| Leitung neben Frequenzumrichter-Ausgang | Geflecht | beidseitig und räumlich trennen |

---

## 7. Schirmkontaktierung — der häufigste Fehler

Die Schirmwirkung ist nur so gut wie die Kontaktstelle. Ein Schirm,
der mit einem langen „Zopf" (Pigtail) angeschlossen ist, verliert
seine HF-Wirkung fast vollständig.

### Falsch: Zopf-Anschluss

```
Kabel ──── Schirmgeflecht aufgedröselt ──── langer Draht ──── Klemme
```

Der Draht hat Induktivität → bei hohen Frequenzen hohe Impedanz →
kein Schirmstrom kann fließen → keine HF-Abschirmung.

Schon **5 cm Zopflänge** können die Schirmdämpfung bei 10 MHz
um 20–30 dB verschlechtern.

### Richtig: 360°-Schirmauflage

```
Kabel ──── Kabelverschraubung mit Schirmkontaktring ──── Gehäuse
               (Schirm allseitig kontaktiert, kein Zopf)
```

Oder im Schaltschrank:
```
Kabel ──── Schirmklemme (WAGO 790, Phoenix SACB, o.ä.) ──── PE-Schiene
               (Schirm aufgeschnitten, flächig aufgelegt)
```

**Regel:** Schirm so kurz wie möglich freilegen, **360°-Kontakt** herstellen,
kein freier Zopf im HF-relevanten Bereich.

---

## 8. Leitungsführung und Trennabstände

Auch ohne Schirm lassen sich Störungen durch sinnvolle Verlegung reduzieren:

| Leitungsgruppe | Mindestabstand zu Starkstromleitungen |
|----------------|:------------------------------------:|
| Analoge Signalleitungen (< 50 V) | 30 cm |
| Digitale Steuerleitungen | 20 cm |
| Geschirmte Bus-Leitungen | 10 cm |
| Motorleitungen an FU (geschirmt) | 20–30 cm zu Signalleitungen |

**Kreuzungen:** Wenn Starkstrom- und Signalleitung sich kreuzen müssen,
immer **im rechten Winkel** (90°) — minimiert die induktive Fläche.

**Niemals parallel verlegen:** FU-Motorleitung und Signalleitung im
gleichen Kabelkanal → massive Störeinkopplung durch HF-Ableitströme.

---

## 9. Zusammenfassung: Welche Maßnahme gegen welches Feld?

| Feldtyp | Frequenz | Kopplung | Wirksame Maßnahme |
|---------|:--------:|:--------:|-------------------|
| E-Feld | alle | kapazitiv | Metallschirm, **einseitig** geerdet |
| H-Feld (NF) | < 100 kHz | induktiv | **Verdrillte Leiter** (Twisted Pair), ferromagnet. Schirm |
| H-Feld (HF) | > 100 kHz | induktiv | Geflechtschirm **beidseitig** geerdet |
| EM-Wellen | > 1 MHz | Strahlung | Geflechtschirm **beidseitig**, 360°-Auflage |
| Leitungsgebunden | alle | galvanisch | Galvanische Trennung (Trenntrafo, Optokoppler) |

> **Faustregel:** Analoge Niederfrequenz → einseitig. Digitale Signale,
> Feldbus, FU-Motorkabel → beidseitig mit 360°-Auflage. Verdrillte Leiter
> immer verwenden wenn H-Feld die Hauptstörquelle ist.
