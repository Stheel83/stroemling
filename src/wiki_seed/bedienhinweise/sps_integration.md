# SPS/PLS-Integration

Strömling Design bildet Automatisierungs-Hardware (SPS/PLC ebenso wie
PLS/DCS-Prozessleitsysteme) über ein gemeinsames Modell **Rack → Baugruppe
→ Kanal** ab und verbindet Kanäle mit Elementen im Schaltplan.

> **Testphase-Hinweis:** Die SPS/PLS-Ansicht zeigt einen 🚧-Streifen –
> die Funktion ist implementiert, aber noch nicht an einem echten Projekt
> durchgetestet. Rückmeldungen zu Problemen sind willkommen.

---

## Zwei Systemtypen, ein Modell

| System | Typische Hersteller | Adressformat |
|---|---|---|
| **SPS/PLC** | Siemens S7, CODESYS, Allen-Bradley | `E0.0`, `A1.3`, `EW64` |
| **PLS/DCS** | Siemens PCS7, ABB 800xA, Honeywell | `R1 S3 K12` (Rack/Slot/Kanal) |

Beim Anlegen eines **Racks** legst du fest, ob es ein SPS- oder
PLS-System ist – das steuert automatisch Adressformat und sichtbare
Zusatzfelder (PLS zeigt z. B. Einheit, Messbereich und Alarmgrenzen).

---

## Ansicht öffnen

Sidebar → **🖥 SPS/PLS**. Drei Tabs:

| Tab | Inhalt |
|---|---|
| Hardware | Racks links, Baugruppen (Slots) rechts je Rack |
| Kanäle/Adressen | Flache Liste aller Kanäle mit Filter (Eingang/Ausgang/Merker/PLS-Typen) |
| Export | I/O-Liste als CSV |

---

## Kanal einem Schaltplan-Element zuweisen

Im Eigenschaftenpanel eines Elements erscheint der Abschnitt
**„SPS/PLS-Kanal"**. Über **„Ändern"** öffnest du eine Liste aller freien
Kanäle – oder legst direkt einen neuen an. Zugewiesene Kanäle zeigen
Adresse, Variablenname/Tag und Kommentar (bei PLS zusätzlich Einheit,
Messbereich, Alarmgrenzen).

---

## I/O-Liste exportieren

Tab **„Export"** schreibt eine CSV mit Adresse, Tag, Beschreibung sowie
(bei PLS-Kanälen) Einheit, Messbereich und Alarmgrenzen – eine Datei für
SPS- und PLS-Kanäle gemeinsam.
