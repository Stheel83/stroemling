# Die 5 Sicherheitsregeln

Die 5 Sicherheitsregeln sind das Fundament der elektrotechnischen
Arbeitssicherheit. Vor jeder Arbeit an elektrischen Anlagen müssen
**alle fünf Regeln in der richtigen Reihenfolge** angewendet werden.

> **Norm:** DIN VDE 0105-100 (Betrieb von elektrischen Anlagen)  
> **Gilt für:** Alle Arbeiten an oder in der Nähe aktiver Betriebsmittel

---

## Die 5 Regeln in Reihenfolge

### 1. Freischalten

Die Anlage oder der betroffene Anlagenteil wird **allpolig** von der
Spannungsquelle getrennt. Das bedeutet:
- Alle Außenleiter (L1, L2, L3) unterbrechen
- Auch den Neutralleiter (N) bei TN-C-Anlagen (PEN-Leiter)
- Transformatoren auf beiden Seiten freischalten

Geeignete Trennmittel: Hauptschalter, Sicherungslasttrenner (NH-Sicherung
herausziehen), Leistungsschalter, Trennschalter.

> Steckdose herausziehen zählt nur bei Sichtkontakt zur Steckdose
> und wenn Stecker/Dose nicht überbrückt werden kann.

### 2. Gegen Wiedereinschalten sichern

Verhindern, dass die Anlage unbeabsichtigt oder unbefugt wieder eingeschaltet
wird, während gearbeitet wird.

Maßnahmen:
- **Schloss an Hauptschalter** (Schloss-Set / Lockout-Tagout)
- **Sicherungen entnehmen** und in eigene Tasche stecken
- **Warnschild** anbringen: „Nicht einschalten! Es wird gearbeitet!"
- Bei mehreren Personen: **Jede Person eigenes Schloss**

### 3. Spannungsfreiheit feststellen

Mit einem **geeigneten Spannungsprüfer** (zweipolig, VDE-geprüft) prüfen,
ob die Anlage tatsächlich spannungsfrei ist.

- **Zweipolig messen** (nicht einpolig / Phasenprüfer!)
- **Prüfer vorher und nachher an bekannter Spannung testen**
- Alle Pole gegen alle anderen Pole messen:
  - L1–L2, L1–L3, L2–L3 (Leiterspannung)
  - L1–N, L2–N, L3–N (Strangspannung)
  - L1–PE, L2–PE, L3–PE (Erdschluss)

### 4. Erden und Kurzschließen (ab 1 kV Pflicht)

Bei Hochspannungsanlagen (≥ 1 kV) und bei Gefahr durch induktiv oder
kapazitiv eingekoppelte Spannungen (z. B. lange Leitungen neben anderen
aktiven Leitungen) muss geerdet und kurzgeschlossen werden.

Bei Niederspannungsanlagen (< 1 kV) empfohlen, aber nur Pflicht wenn:
- Rückspeisung möglich (Generatoren, PV-Anlagen)
- Induktive Einkopplung aus benachbarten Anlagen
- Kapazitive Aufladung von langen Kabeln

Erdungs- und Kurzschlusskabel möglichst nah am Arbeitsort anlegen —
**zuerst erden, dann phasenweise kurzschließen**.

### 5. Benachbarte unter Spannung stehende Teile abdecken oder abschranken

Teile, die **nicht freigeschaltet** werden konnten und in der Nähe des
Arbeitsbereichs liegen, müssen mechanisch gesichert werden:

- **Isolierende Abdeckungen** (Plastikschutzplatten, Isoliermatten)
- **Abschrankungen** mit Warnzeichen
- **Mindestabstände** einhalten (bei Hochspannung nach DIN VDE 0105)

---

## Reihenfolge beim Wiedereinschalten

Nach Abschluss der Arbeiten werden die Sicherheitsmaßnahmen in
**umgekehrter Reihenfolge** aufgehoben:

5. Abdeckungen entfernen  
4. Erdung und Kurzschluss entfernen  
3. (keine Umkehraktion)  
2. Sicherungen einsetzen, Schlosssicherungen entfernen  
1. Einschalten

---

## Häufige Fehler

| Fehler | Risiko |
|--------|--------|
| Nur einpolig freischalten (z. B. Sicherung L1) | L2/L3 noch aktiv |
| Spannungsfreiheit nur mit Phasenprüfer testen | Phasenprüfer zeigt keinen N-PE-Fehler |
| Wiedereinschaltsicherung vergessen | Kollege schaltet ein |
| Erdung/Kurzschluss nicht am Arbeitsort | Schutz nicht gegeben |
| Nachbarfelder vergessen | Rückspeisung über Sammelschiene |
