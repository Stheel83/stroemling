# TN-, TT- und IT-Netze – Netzformen im Überblick

Die Netzform beschreibt, wie der Neutralpunkt der Spannungsquelle und
die Gehäuse der Betriebsmittel mit Erde verbunden sind.

> **Norm:** DIN VDE 0100-410 (IEC 60364-4-41)  
> **Nomenklatur:** 1. Buchstabe = Neutralpunkt der Quelle, 2. Buchstabe = Gehäuse/PE

---

## Buchstaben-Erklärung

| Buchstabe | Position | Bedeutung |
|:---------:|:--------:|-----------|
| T         | 1.       | Transformator-Sternpunkt direkt geerdet (Terra) |
| I         | 1.       | Isolierter Sternpunkt (keine direkte Erdung) |
| T         | 2.       | Gehäuse direkt zur Erde (eigene Erdelektrode) |
| N         | 2.       | Gehäuse über Neutralleiter zum Transformator-Sternpunkt |
| C         | 3.       | Neutral- und Schutzleiter kombiniert (PEN) |
| S         | 3.       | Neutral- und Schutzleiter getrennt (Separate) |

---

## TN-Netz – Standard in Deutschland

Transformator-Sternpunkt direkt geerdet, Gehäuse über N-Leiter verbunden.

### TN-C (Klassische Nullung)

```
Trafo ─── L1 ─────────────────── Last
          L2 ─────────────────── Last
          L3 ─────────────────── Last
          PEN ─────────────────── N + Gehäuse
          (N und PE kombiniert)
```

- PEN-Leiter vereint N und PE
- **Verboten für Neuanlagen seit 1973 (BRD)**
- FI/RCD **nicht einsetzbar**
- Risiko: Spannung auf Gehäuse bei PEN-Unterbrechung
- (→ Artikel: Klassische Nullung – Grundlagen)

### TN-S (modernes System)

```
Trafo ─── L1 ─────────────────── Last
          L2 ─────────────────── Last
          L3 ─────────────────── Last
          N ───────────────────── Neutralleiter
          PE ──────────────────── Gehäuse (getrennt!)
```

- PE und N vollständig getrennt
- FI/RCD problemlos einsetzbar
- Höchste Sicherheit im TN-System

### TN-C-S (Hybrid, Standard in DE)

```
Trafo ─── PEN (bis HAK) ─── PE + N (ab HAK getrennt) ─── Last
```

- Im öffentlichen Netz: TN-C mit PEN-Leiter
- Im Gebäude ab Hausanschlusskasten (HAK): PE und N getrennt
- De-facto-Standard in deutschen Wohngebäuden
- FI/RCD im Gebäude einsetzbar (nach der Auftrennung)

---

## TT-Netz – Eigene Erdelektrode beim Kunden

```
Trafo ─── L1 ─────────────────── Last
          N ───────────────────── Neutralleiter (geerdet beim Trafo)
          PE ────────── [eigene Erdelektrode beim Kunden] ─── Gehäuse
```

- Schutzleiter (PE) verbunden mit **eigener Erdelektrode beim Gebäude**
- Gebräuchlich in Frankreich, Italien, ländlichen Gebieten (Freileitungen)
- In Deutschland selten — aber in manchen ländlichen Bestandsanlagen
- **FI/RCD Pflicht** (Abschaltbedingung ohne RCD schwer erfüllbar)
- Vorteil: Fehler in einem Gebäude beeinflusst andere Gebäude nicht

### Besonderheit: N-Leiter-Unterbrechung im TT-Netz

Bei Unterbrechung des N-Leiters im TT-Netz können gefährliche
Überspannungen entstehen: Andere Verbraucher (z. B. L2, L3) „heben"
den Neutralpunkt an — Geräte auf anderen Phasen erhalten mehr als 230 V.

---

## IT-Netz – Isolierter Sternpunkt

```
Trafo ─── L1 ─────────────────── Last
          L2 ─────────────────── Last
          L3 ─────────────────── Last
          (kein N-Leiter; Sternpunkt hochohmig oder nicht geerdet)
```

- Kein direkter Erdanschluss des Transformator-Sternpunkts
- Erster Erdschluss führt **nicht** zum Abschalten
- Isolationsüberwachungsgerät (IMD) erkennt ersten Fehler
- Zweiter Fehler → Kurzschluss → Abschaltung

**Typische Anwendung:**
- Krankenhäuser (OP-Säle: erster Fehler darf nicht zum Stromausfall führen)
- Bergwerke (Schlagwetterschutz)
- Rechenzentren (Ausfallsicherheit)

---

## Vergleich auf einen Blick

| Merkmal | TN-C | TN-S | TN-C-S | TT | IT |
|---------|:----:|:----:|:------:|:--:|:--:|
| PE und N getrennt | nein | ja | ab HAK | ja | ja |
| FI/RCD einsetzbar | nein | ja | ja | Pflicht | ja |
| Standard DE Neubau | nein | — | ja | nein | nein |
| Erdeelektrode Kunde | nein | nein | nein | ja | nein |
| 1. Fehler sicher | nein | ja | ja | ja | ja |
| Betrieb bei 1. Fehler | nein | nein | nein | nein | **ja** |
