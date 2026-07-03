# Steckverbinder und konfektionierte Kabel anlegen

Steckverbinder (Stecker/Buchse-Paare) und konfektionierte Kabel (Kabel mit
fest angeschlagenen Steckern) werden – wie Klemmen und Kabeltypen – einmal
in der **Bauteil-Bibliothek** angelegt und stehen danach in jedem Projekt
zur Verfügung.

---

## Steckverbinder anlegen

1. Sidebar **🔧 Bauteile** öffnen.
2. Im Kategoriebaum links mit der Maus über **Steckverbinder** fahren →
   **„+"** klicken.
3. Der Steckverbinder-Editor öffnet sich automatisch als eigene Ansicht
   (Breadcrumb „← Bauteile / … / Steckverbinder-Editor").

### Stammdaten

Bezeichnung, Hersteller, Artikel-Nr., Lieferant, Preis, Spannung, Strom,
Leistung, Bemerkung und Links (Hersteller-Website, Datenblatt) – wie bei
jedem anderen Bauteil.

### Ausführung: Stecker/Buchse × Frei/Einbau

Ein Steckverbinder hat zwei unabhängige Eigenschaften:

| | **Stecker** (Stifte) | **Buchse** (Buchsenkontakte) |
|---|---|---|
| **Frei** (hängt am Kabel) | freier Stecker | freie Buchse |
| **Einbau** (Flansch/Panel) | Einbaustecker | Einbaubuchse |

Beide werden im Editor als zwei Umschalter-Gruppen gesetzt (Ausführung:
Stecker/Buchse, Montage: Frei/Einbau). Üblich: Geräteanschluss =
Einbaubuchse, Kabelende = freier Stecker.

### Gehäuse-Eigenschaften

Polzahl, Kodierung, IP getrennt/gesteckt, Verriegelung, Geschirmt,
Schirmkontakt – jeweils direkt im Editor.

### Kabeleinführungen

Mit **„+"** eine Zeile hinzufügen: Nummer, zulässiger Außendurchmesser
(min/max), Einführungstyp, Zugentlastung. Nur relevant für freie
Steckverbinder (die ein Kabel aufnehmen).

### Kontakttypen

Mit **„+"** pro Kontaktposition eine Zeile anlegen: Kontaktgröße,
Querschnittsbereich, Nennstrom/-spannung, Verbindungstechnik (Crimp,
Löten, Schraube …), sowie optional Litze-Farbe, Litze-Querschnitt und
Litze-Bezeichnung für konfektionierte Enden. Ein Schirmkontakt-Schalter
markiert Positionen, die den Kabelschirm kontaktieren.

> Alle Änderungen werden sofort gespeichert – es gibt keinen separaten
> „Speichern"-Button für einzelne Zeilen, nur für die Stammdaten oben.

---

## Konfektioniertes Kabel anlegen

Ein konfektioniertes Kabel verbindet einen Kabeltyp aus der Bibliothek mit
einem Steckverbinder an einem oder beiden Enden – z. B. ein fertig
konfektioniertes Sensorkabel mit M8-Stecker.

1. Sidebar **🔧 Bauteile** → im Kategoriebaum über **Konf. Kabel** fahren
   → **„+"**.
2. Der Konfkabel-Editor öffnet sich automatisch.
3. Auswahl treffen:
   - **Kabeltyp** aus der Bibliothek (oder „— kein Kabeltyp —")
   - **Länge** in Metern
   - **Stecker/Buchse – Ende A** und **Ende B** – Auswahl aus allen
     angelegten Steckverbindern (zeigt Polzahl und Stecker/Buchse als
     Hinweis), oder **„— freies Ende —"** wenn ein Ende offen bleibt.

---

## Wo diese Bauteile später auftauchen

- **Gerätekasten** (→ eigener Artikel „Gerätekasten und Geräte mit
  Kontaktspiegel") kann mit einem Steckverbinder-Bauteil verknüpft werden.
- **Listen-Ansicht:** Tab „Steckverbinder" (alle platzierten
  Steckverbinder-Gehäuse) und Tab „Belegungsplan" (Kontaktbelegung je
  Gerätekasten mit Sprung-Funktion).
