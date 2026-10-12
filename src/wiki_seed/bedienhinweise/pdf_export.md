# PDF-Export

Aus dem Projekt wird **ein** PDF-Dokument zusammengesetzt: Deckblatt,
Inhaltsverzeichnis, Schaltplan, SPS/PLS-I/O-Liste und beliebige Listen –
in der Reihenfolge, die du bestimmst. Der Schaltplan ist dabei ein
**echtes Vektor-PDF** (kein Screenshot): gezeichnete Linien und Texte,
beliebig skalierbar und druckfertig.

---

## Export starten

- Sidebar → **🖨 PDF-Export**, oder
- Tastenkürzel **Strg+Umschalt+P**

Es öffnet sich eine eigene Ansicht (kein Dialog) mit zwei Spalten:

| Bereich | Inhalt |
|---|---|
| Links | **Zusammenstellung** (gespeicherte Vorlagen) und die **Abschnitte** des PDFs |
| Rechts | **Schaltplan-Seiten** zum Ankreuzen sowie die Schaltplan-Optionen |
| Fußleiste | Zustand („3 Abschnitte, 12 Schaltplan-Seiten") bzw. der Grund, warum der Export gesperrt ist, und **Exportieren …** |

Ein Klick auf **Exportieren …** öffnet die Pfadwahl. Existiert die
Zieldatei bereits, fragt ein Bestätigungsdialog vor dem Überschreiben nach –
bewusst ein Dialog statt eines Toasts, da ein versehentliches
Überschreiben Konsequenzen hat. Nach dem Export bleibst du in der Ansicht
und kannst die Zusammenstellung anpassen und erneut exportieren.

---

## Die Abschnitte

Jeder Abschnitt hat ein Häkchen und die Pfeile **▲ ▼**. Die Reihenfolge
der Liste ist die Reihenfolge im PDF.

| Abschnitt | Was er enthält |
|---|---|
| **Deckblatt** | Aus einer Blattvorlage (Auswahl „Vorlage“). Die mitgelieferte „Standard-Deckblatt“-Vorlage zeigt Projektname, optionalen Titelzusatz, Logo, Projektnummer, Auftraggeber, Auftragnehmer, Bearbeiter, Werk, Abteilung, Norm, Anlagedatum und Ausgabedatum |
| **Inhaltsverzeichnis** | Alle übrigen Abschnitte mit Seitenzahl; beim Schaltplan nach Anlage und Ort gegliedert, mit jedem Blatt |
| **Schaltplan** | Die ausgewählten Seiten (siehe unten) |
| **SPS/PLS – I/O-Liste** | Die I/O-Liste mit den Spalten und Filtern einer SPS-Export-Vorlage |
| **Listen** | Stückliste, Bestellliste, Kabelliste, Aderliste, Adersummenliste, Klemmenplan, Klemmlistenauszug, Steckverbinder, Belegungsplan, Pinbelegung, Querverweise – je Liste ein Abschnitt, standardmäßig ausgeschaltet |

Das Inhaltsverzeichnis erscheint nur, wenn es mindestens einen
Schaltplan-, SPS- oder Listen-Abschnitt gibt, den es auflisten kann. Die
**Seitenzahlen im Verzeichnis sind PDF-Seiten**, stimmen also mit der
Anzeige im PDF-Programm überein – nicht mit den Blattnummern im Schriftfeld.

---

## Welche Schaltplan-Seiten?

Rechts siehst du alle Seiten des Projekts mit Anlage, Ort, Blatt und
Bezeichnung.

| Schaltfläche | Wirkung |
|---|---|
| **Alle** / **Keine** | Alle Seiten an- bzw. abwählen |
| **Nur aktuelle** | Nur die Seite, die du zuletzt geöffnet hattest |
| **Auswahl als Voreinstellung der Seiten speichern** | Schreibt die Auswahl dauerhaft in die Seiten |

Die **Voreinstellung** pro Seite ist die Option **„In Dokumentations-PDF
aufnehmen"** im „Seite bearbeiten"-Dialog des Seitenbaums (direkt unter
„Normblatt anzeigen"). Neue Seiten sind standardmäßig enthalten. Beim Öffnen
der Ansicht ist die Auswahl mit dieser Voreinstellung vorbelegt; Änderungen
in der Ansicht gelten nur für den aktuellen Export, solange du sie nicht
ausdrücklich als Voreinstellung speicherst.

### Schaltplan-Optionen

| Option | Wirkung |
|---|---|
| **Normblatt einschließen** | Zeichnet Rahmen und Schriftfeld der Seite mit |
| **Infostreifen für Seiten ohne Schriftfeld** | Seiten ohne Normblatt bekommen unten einen schmalen Streifen: links Projektname und Auftraggeber, in der Mitte Blattnummer und Bezeichnung, rechts Datum und Bearbeiter |
| **Ganzes Canvas (ohne Normblatt)** | Exportiert den gesamten belegten Bereich der Seite statt des Blattformats; das Normblatt entfällt dabei |

---

## SPS/PLS-I/O-Liste im PDF

Bei **SPS/PLS – I/O-Liste** wählst du, **welche Spalten und Filter** gelten:

- **(Standard)** – die Standardspalten ohne Filter,
- **(Zuletzt im Export-Tab)** – der Stand, den du zuletzt im Tab
  „Import / Export" der SPS/PLS-Ansicht bearbeitet hast,
- jede dort gespeicherte **Vorlage**.

Der Abschnitt ist gesperrt, solange das Projekt keine SPS/PLS-Daten hat.
Mit sehr vielen Spalten wird es auf A4 quer eng – für das PDF lohnt sich
eine Vorlage mit wenigen Spalten.

---

## Listen im PDF

Im Dokumentations-PDF erscheinen die Listen in der **Standardansicht**:
vollständig, ungefiltert und in der Reihenfolge der Datenbank. Jede Zeile in
der Abschnittsliste nennt die Zeilenzahl. **Listen ohne Einträge** sind
gesperrt („keine Einträge") und tauchen weder im PDF noch im
Inhaltsverzeichnis auf.

Die **Adersummenliste** hat die Option **„je Anlage/Ort gruppieren"** – wie
der Umschalter in der Listen-Ansicht.

> **Möchtest du eine gefilterte oder sortierte Liste?** Dann exportiere sie
> direkt im Tab der Listen-Ansicht über **PDF exportieren**: Dort gilt, was
> am Bildschirm zu sehen ist (Filter und Sortierung). Das
> Dokumentations-PDF gibt die vollständige Liste aus.

---

## Zusammenstellungen speichern

Oben links wählst du eine gespeicherte **Zusammenstellung** oder legst mit
**Speichern unter …** eine neue an (ein vorhandener Name wird
überschrieben). Eine Vorlage merkt sich:

- welche Abschnitte aktiv sind und in welcher Reihenfolge,
- Titelzusatz und Logo-Einstellung,
- die Schaltplan-Optionen,
- die gewählte SPS-Vorlage und die Adersummenlisten-Option,
- die **Seitenauswahl**.

Vorlagen gelten für alle Projekte. Die Seiten werden dabei über
**Anlage | Ort | Blatt** erkannt: Passt keine Seite der Vorlage zu einem
anderen Projekt, bleibt die Voreinstellung der Seiten bestehen und ein
Hinweis erscheint.

**(zuletzt benutzt)** stellt Abschnitte und Optionen des letzten Exports
wieder her, lässt die Seitenauswahl aber bewusst bei der Voreinstellung der
Seiten – so überstimmt eine alte Auswahl nie spätere Änderungen daran.

---

## Seitenzahlen im PDF

Verzeichnis-, Tabellen- und Listenseiten tragen unten rechts
**„Seite x von y"** (durchlaufend über das ganze Dokument). Schaltplan-Seiten
behalten ihr Schriftfeld mit der Blattzählung – dort wird keine zusätzliche
PDF-Seitenzahl eingeblendet. Das Deckblatt trägt keine Seitenzahl.

---

## Was im Schaltplan mit exportiert wird

- Alle Symbole, Leitungen, Texte, Bilder und Kästen (Geräte-, Struktur-,
  Makrokasten) der jeweiligen Seite
- Kreuzungslücken bei sich kreuzenden Leitungen aus unterschiedlichen
  Netzen
- Aderbeschriftungen (Bezeichnung, Aderfarbe, Querschnitt, Länge)
- Das Normblatt inkl. Schriftfeld, Logo und Revisionsstand
- Ist ein Revisionsstatus gesetzt (Entwurf/Freigegeben/Veraltet), erscheint
  automatisch ein diagonales Wasserzeichen auf der exportierten Seite

> **Bekannte Einschränkung:** Seiten, die im aktuellen Programmlauf noch
> nie geöffnet wurden, können im PDF ohne Leitungen erscheinen – die
> Verbindungsdaten werden erst beim Öffnen einer Seite synchronisiert.
> Einmal kurz jede Seite öffnen behebt das.
