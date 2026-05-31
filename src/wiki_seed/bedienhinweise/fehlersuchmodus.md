# Fehlersuchmodus

Der Fehlersuchmodus ist ein eigenständiger dritter Betriebsmodus neben
dem Schaltplan-Modus und der Inbetriebnahme. Er dient der interaktiven
Analyse: Klick auf ein beliebiges Element markiert den Strompfad bis zur
nächsten Unterbrechung.

---

## Aktivieren

Sidebar-Button **Fehlersuche** (🔍) anklicken. Die Ansicht teilt sich in
ein Info-Panel links und den schreibgeschützten Canvas rechts.

Zurück zum Schaltplan: **✕** oben im Info-Panel oder erneut auf
**Seiten** in der Sidebar klicken.

---

## Pfad markieren

Beliebiges Element oder Leitung im Canvas **anklicken** →
der Strompfad von diesem Punkt bis zur nächsten elektrischen
Unterbrechung wird markiert:

- **Leitungen im Pfad** erscheinen in der Akzentfarbe mit etwas
  dickerer Linie.
- **Elemente im Pfad** bleiben voll sichtbar.
- **Alles andere** wird auf ca. 12 % Deckkraft abgedunkelt.
- **Startpunkt** wird zusätzlich mit einem kleinen Kreis markiert.

Das Info-Panel links zeigt die Anzahl der gefundenen Elemente.

**Leere Stelle klicken** → Markierung aufheben.

---

## Was ist eine Unterbrechung?

Die Traversierung folgt dem Pfad durch alle Elemente, die Strom
„durchleiten" – und stoppt, sobald sie auf ein Element trifft, das
den Pfad elektrisch beendet:

| Elementtyp | Verhalten |
|---|---|
| Leitung, Polygonzug | Pfad läuft weiter |
| Schließer, Brücke, Trennstelle (Rolle: *durchleiter*) | Pfad läuft weiter |
| Quelle, Trafo-Ausgang (Rolle: *quelle*) | Pfad läuft weiter |
| Geräteanschluss (Rolle: *variabel*) | Pfad läuft weiter |
| Motor, Spule, Lampe (Rolle: *verbraucher*) | Pfad endet hier |
| Öffner, Sicherung, Schutzschalter (Rolle: *trenner*) | Pfad endet hier |

Die Rolle jedes Symbols ist im Symboleditor hinterlegt und wird beim
Zeichnen automatisch ausgewertet – kein manuelles Eingreifen nötig.

---

## Querverweise – seitenübergreifende Pfade

Führt der Pfad über einen **Querverweis** auf eine andere Seite,
erscheint im Info-Panel ein Eintrag mit dem Signalnamen und einem
**„Springen →"**-Button.

Klick auf den Button:
1. Lädt die Zielseite in den Canvas.
2. Springt automatisch zur Position des korrespondierenden
   Querverweis-Elements auf der Zielseite.
3. Der Pfad wird zurückgesetzt – auf der neuen Seite kann nun
   weitergeklickt werden.

> **Hinweis:** Der Querverweis-Sprung funktioniert nur, wenn die
> Verbindungstabelle aktuell ist. Falls „Zielseite nicht gefunden"
> erscheint, den Schaltplan einmal öffnen und speichern
> (löst die Netz-Synchronisierung aus).

---

## Abgrenzung zur Inbetriebnahme

| | Fehlersuchmodus | Inbetriebnahme |
|---|---|---|
| **Zweck** | Strompfad nachvollziehen | Betriebsmittel prüfen, Werte erfassen |
| **Aktivierung** | Sidebar „Fehlersuche" | Sidebar „IBN" |
| **Klick im Canvas** | Startet Pfad-Traversierung | Navigiert zu Betriebsmittel in der Liste |
| **Schreibschutz** | Ja | Ja |

Beide Modi können unabhängig voneinander genutzt werden.
