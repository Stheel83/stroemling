# Nullleiter-Unterbrechung im TT-Netz

Eine Unterbrechung des Neutralleiters (N) im TT-Netz ist eine der
gefährlichsten Fehlersituationen im Altbestand — weil sie zunächst
unauffällig wirkt und dann alle angeschlossenen Geräte beschädigen kann.

> Betrifft vor allem: ländliche Regionen, Freileitungsanschlüsse,
> Österreich, Altbau-Gebäude in Außenbereichen.

---

## Was passiert bei N-Leiter-Unterbrechung?

Im TT-Netz ist der Neutralleiter (N) und der Schutzleiter (PE)
getrennt. Der N-Leiter läuft vom Transformator zum Verbraucher —
er ist der Rückleiter des Stroms.

### Normalbetrieb (N intakt)

```
Trafo ─── L1 (230 V gegen N) ─── Gerät A ─── N (0 V) ─── Trafo
          L2 (230 V gegen N) ─── Gerät B ─── N (0 V) ─── Trafo
          L3 (230 V gegen N) ─── Gerät C ─── N (0 V) ─── Trafo
```

### N-Leiter-Unterbrechung (z. B. Klemmbruch, korrodierter Freileitungsverbinder)

```
Trafo ─── L1 ─── Gerät A ─────────────────── ✂ (N unterbrochen)
          L2 ─── Gerät B ─── gemeinsamer Knoten ─── N (schwimmend)
          L3 ─── Gerät C ─────────────────── ✂
```

Der N-Leiter ist nun nicht mehr auf 0 V fixiert. Der **Neutralpunkt
verschiebt sich** in Abhängigkeit von den angeschlossenen Lasten.

---

## Neutralpunktverschiebung: Die Gefahr

Die angeschlossenen Geräte wirken als Spannungsteiler zwischen den
Außenleitern. Je nach Last kann die Spannung stark ansteigen:

**Beispiel:**
- L1: Leichtes Gerät (hoher Widerstand, z. B. LED-Leuchte)
- L2: Schweres Gerät (niedriger Widerstand, z. B. Heizung)

→ Der Neutralpunkt verschiebt sich in Richtung L2.
→ Die Spannung an L1-Geräten steigt auf 300–380 V!
→ Die Spannung an L2-Geräten sinkt auf 80–100 V.

Ergebnis:
- Geräte auf der „leichten" Phase: **Überspannung → sofortige Zerstörung**
- Geräte auf der „schweren" Phase: **Unterspannung → Fehlfunktion**

---

## Typische Ursachen

| Ursache | Häufig bei |
|---------|-----------|
| Korrodierter Freileitungsverbinder | Ländliche Gebiete, Freileitungen > 20 Jahre |
| Gelockerte Klemmverbindung im Zählerkasten | Altbau, Alu-Verbindungen |
| Beschädigter Erdkabelmuffe | Grabenarbeiten, Setzungen |
| Defekte Nullsicherung (ältere Systeme) | Sehr alte Anlagen |
| Übergangs-Klemme PEN → N ohne Schraubenprüfung | Nach Umbauarbeiten |

---

## Schutzmaßnahmen

### Unmittelbarer Schutz: RCD

Im TT-Netz ist der FI-Schutzschalter (RCD) **Pflicht**.
Er schützt allerdings **nicht** direkt vor Neutralleiter-Unterbrechung —
RCDs messen Differenzströme, keine Neutralleiter-Integrität.

### Überspannungsschutz (SPD)

SPD Typ 2 + Typ 3 schützen Geräte vor den Überspannungsspitzen bei
N-Unterbrechung (bis zu einem gewissen Grad).

### Neutralleiter-Überwachungsrelais

Spezielle Überwachungsrelais erkennen N-Unterbrechung und schalten die
Anlage ab, bevor Geräte zerstört werden. In TT-Netzen mit Freileitungen
sinnvolle Ergänzung.

### Regelmäßige Inspektion

- Freileitungsverbinder alle 5–10 Jahre prüfen lassen (EVU)
- Klemmen im Zählerkasten auf Festsitz prüfen (Elektriker)
- Alu-Klemmen: Nachziehen oder Bimetall-Klemmen einsetzen

---

## Abgrenzung zu TN-Netzen

Im TN-C(-S)-Netz ist der PEN-Leiter geerdet — bei Unterbrechung
entsteht eine andere, aber ebenfalls gefährliche Situation
(→ Artikel: Klassische Nullung – Grundlagen).

Im TT-Netz ist die N-Unterbrechung durch die fehlende Fixierung
des Neutralpunkts beim Kunden besonders gefährlich.
