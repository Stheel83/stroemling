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
| Kanäle / Adressen | Flache Liste aller Kanäle mit Filter (Eingang/Ausgang/Merker/PLS-Typen) |
| Import / Export | Umschalter **Export** / **Import**: I/O-Liste als CSV oder PDF ausgeben, Bestandslisten als CSV einlesen |

---

## Kanal einem Schaltplan-Element zuweisen

Im Eigenschaftenpanel eines Elements erscheint der Abschnitt
**„SPS/PLS-Kanal"**. Über **„Ändern"** öffnest du eine Liste aller freien
Kanäle – oder legst direkt einen neuen an. Zugewiesene Kanäle zeigen
Adresse, Variablenname/Tag und Kommentar (bei PLS zusätzlich Einheit,
Messbereich, Alarmgrenzen).

---

## I/O-Liste exportieren

Tab **„Import / Export"** mit dem Umschalter auf **Export**. Links stellst
du die Liste zusammen, rechts siehst du eine **Vorschau** der ersten Zeilen
(und die Gesamtzahl nach Filter).

| Bereich | Möglichkeiten |
|---|---|
| **Vorlage** | **(Standard)** oder eigene Vorlagen; **Speichern unter …** legt eine Vorlage an (gleicher Name überschreibt), **Löschen** entfernt sie. Vorlagen gelten für alle Projekte |
| **Spalten** | Haken = exportieren, **▲ ▼** = Reihenfolge, Spaltentitel frei änderbar, dazu **＋ Feste Textspalte** (immer gleicher Inhalt, z. B. ein Stationsname – praktisch für Import-Vorlagen des Zielsystems) |
| **Format** (nur CSV) | Trennzeichen (Semikolon, Komma, Tabulator, Senkrechter Strich), Dezimalzeichen, Anführungszeichen (immer / nur bei Bedarf), Kopfzeile ja/nein, UTF-8-BOM für Excel |
| **Filter** | System (SPS/PLS), Rack, Signal, Belegung (alle / nur mit Element / nur ohne Element) |

Ausgegeben wird mit **Als CSV exportieren …** oder **Als PDF exportieren …**.
Das PDF nutzt dieselben Spalten und Filter; Format-Einstellungen gelten nur
für die CSV. Bei vielen Spalten wird es auf A4 quer eng – dann erscheint ein
Hinweis, besser eine Vorlage mit wenigen Spalten zu verwenden.

Die I/O-Liste lässt sich auch als **Abschnitt im Dokumentations-PDF** ausgeben
(Sidebar → PDF-Export): dort wählst du eine dieser Vorlagen aus.

---

## Bestandsliste importieren

Tab **„Import / Export"** mit dem Umschalter auf **Import** übernimmt eine
vorhandene Adressliste (CSV) in das Projekt:

1. **CSV-Datei** wählen (**Durchsuchen …**) und **Laden** – Trennzeichen und
   Kodierung werden erkannt, Spaltentitel nach Möglichkeit automatisch
   zugeordnet.
2. Die **Spaltenzuordnung** prüfen: Jede CSV-Spalte bekommt ein Zielfeld oder
   „— ignorieren —".
3. **Optionen** festlegen: System, wenn es nicht erkennbar ist (PLS oder SPS),
   Umgang mit **vorhandenen Kanälen** (nur leere Felder auffüllen /
   überspringen / aus der CSV überschreiben), Dezimalzeichen, und ob
   **fehlende Racks/Baugruppen angelegt** werden.
4. Der **Trockenlauf** zeigt, was passieren würde (neue, aktualisierte und
   unveränderte Kanäle, neu angelegte Racks/Baugruppen) und listet fehlerhafte
   Zeilen. Fehlerhafte Zeilen werden **nicht** importiert.
5. **Importieren** schreibt alles in einem Zug in das Projekt.

> **Tipp:** Ein Export aus Strömling mit „Feste Textspalte" lässt sich im
> Zielsystem als Importvorlage weiterverwenden – und umgekehrt bekommst du
> Bestandsanlagen per CSV-Import ins Projekt.
