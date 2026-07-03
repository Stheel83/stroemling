# IBN – Inbetriebnahme

Der IBN-Modus dient zur **strukturierten Prüfung und Dokumentation** von
Schaltanlagen vor der Inbetriebnahme. Er ist ein eigenständiger Modus
neben dem Schaltplan-Modus und dem Fehlersuchmodus.

---

## Ablauf

1. Sidebar → **IBN** (✅).
2. Die platzierten **Betriebsmittel** aus dem Schaltplan werden automatisch
   als Prüfpositionen aufgelistet.
3. Für jedes Betriebsmittel können **Messwerte** (Spannung, Strom,
   Widerstand usw.) eingetragen und ein Status gesetzt werden.
4. Felder mit **Soll-Werten** zeigen farblich an, ob der Messwert im
   zulässigen Bereich liegt.

Die Ansicht ist in drei Tabs gegliedert:

| Tab | Inhalt |
|---|---|
| Betriebsmittel | Prüfpositionen, Messwerte, Status je Gerät |
| Kabel | IBN-Status der Kabelverbindungen |
| Felder | Editor für Feldvorlagen (siehe unten) |

---

## Feldvorlagen bearbeiten

Über den Tab **„Felder"** legst du fest, welche Messwerte für welchen
Betriebsmitteltyp erfasst werden – z. B. hat ein Motor andere Prüffelder
als eine Leuchte.

- Links: Liste der Symbol-Kategorien.
- Rechts: Tabelle der Felder dieser Kategorie (Name, Typ, Einheit).
- **„+ Neues Feld"** legt ein Feld an.
- **✎** öffnet die Bearbeitung eines Felds inline.
- **Reihenfolge per Drag & Drop** – am `≡`-Griff eine Zeile greifen und
  verschieben, die Anzeigereihenfolge wird sofort gespeichert.
- Systemfelder sind schreibgeschützt (grau, kein Löschen-Button) –
  eigene Felder lassen sich frei anlegen, bearbeiten und löschen.

> **Hinweis:** Das Löschen eines Felds (`×`) geschieht sofort und lässt
> sich nicht rückgängig machen.

---

## IBN-Status im Eigenschaftenpanel

Auch ohne in den IBN-Modus zu wechseln: Ist für ein ausgewähltes
Betriebsmittel bereits ein IBN-Eintrag vorhanden, zeigt das
Eigenschaftenpanel im normalen Schaltplan-Modus einen zusätzlichen,
schreibgeschützten Abschnitt **INBETRIEBNAHME** mit Status-Badge
(grau = offen, gelb = in Arbeit, grün = abgeschlossen), Bauteil-ID,
Prüfer/-datum und den erfassten Messwerten. Der Abschnitt bleibt
unsichtbar, solange kein Eintrag existiert – Bearbeiten ist weiterhin
nur im IBN-Modus möglich.

---

## Prüfprotokoll

Das ausgefüllte IBN-Protokoll kann als Liste exportiert werden
(Listen-Ansicht → IBN-Tab).
