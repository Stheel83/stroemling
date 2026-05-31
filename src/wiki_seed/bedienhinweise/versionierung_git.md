# Versionierung mit Git

Strömling Design hat eine eingebaute Git-Integration. Wenn Git auf deinem System installiert ist, wird jedes neue Projekt automatisch als Git-Repository angelegt.

---

## Git ist installiert – so funktioniert es

### Neues Projekt anlegen

Beim Klick auf **+** (Projektliste) und Eingabe eines Namens passiert automatisch:

- Projektordner `~/Strömling-Projekte/Projektname/` wird angelegt
- `git init` initialisiert ein lokales Repository
- `.gitignore` wird erstellt (SQLite-Hilfsdateien ausgeschlossen)
- Erster Commit: „Projekt angelegt"

### Version anlegen

Klicke auf **„Version anlegen"** in der Canvas-Kopfzeile oder drücke `Ctrl+S`.

> **Wichtig:** Der Schaltplan wird *ständig automatisch* in SQLite gespeichert – nichts kann verloren gehen. Der „Version anlegen"-Knopf erstellt nur einen benannten Eintrag im Versionsverlauf, zu dem du später zurückkehren kannst.

Jede Version speichert außerdem eine `snapshot.json` – eine menschenlesbare Zusammenfassung mit Seitenliste, Elementanzahl und BMK-Liste. Diese dient als lesbarer Git-Diff, da SQLite-Dateien selbst Binärdateien sind.

### Versionshistorie und Wiederherstellen

Öffne die Projektliste (linke Sidebar → Projekt auswählen) und scrolle zum Bereich **„Versionshistorie"**. Dort siehst du alle gespeicherten Stände mit Datum und Uhrzeit.

Fahre mit der Maus über einen älteren Stand → Klick auf **„Wiederherstellen"** setzt das Projekt auf diesen Stand zurück.

### Remote-Backup (optional)

Im Bereich **„Versionsverwaltung"** in den Projektdetails kannst du eine Remote-URL eintragen:

```
git@codeberg.org:dein-nutzer/schaltschrank-a.git
```

Nach dem Eintragen pushst Strömling nach jeder Version automatisch. Fehler beim Push werden still geloggt – das lokale Speichern und die lokale Versionshistorie funktionieren immer, auch ohne Netzwerk.

Zugangsdaten (SSH-Key oder HTTPS-Credential-Helper) richtest du einmalig im System ein, nicht in der App.

---

## Git ist *nicht* installiert – was tun?

Ohne Git gibt es **keine automatische Versionierung**. Der Schaltplan wird weiterhin zuverlässig in der `.strl`-Datei gespeichert, aber es gibt keine Möglichkeit, zu einem früheren Stand zurückzukehren.

### Option 1: Git installieren (empfohlen)

| Betriebssystem | Befehl / Weg |
|---|---|
| Linux (Debian/Ubuntu) | `sudo apt install git` |
| Linux (Fedora/openSUSE) | `sudo dnf install git` / `sudo zypper install git` |
| Windows | https://git-scm.com/download/win |
| macOS | `xcode-select --install` oder `brew install git` |

Nach der Installation: App neu starten, neues Projekt anlegen – Git wird automatisch eingerichtet.

### Option 2: Manuelle Sicherungskopien

Exportiere regelmäßig eine Kopie über **„Kopie exportieren (.strl)"** in den Projektdetails. Benenne die Datei mit Datum und Stand:

```
Schaltschrank-A_2026-05-31_vor-Umverdrahtung.strl
```

Diese Datei kannst du jederzeit über **„Projekt öffnen"** wieder laden.

### Option 3: Vollständiges Backup

Über **Einstellungen → Datensicherung → Exportieren** sicherst du alle Daten auf einmal: Projekte, Makros und Wiki. Das ist sinnvoll vor größeren Arbeiten oder als regelmäßiges Offline-Backup auf einem USB-Stick.

---

## Technischer Hintergrund

Die `.strl`-Datei ist eine SQLite-Datenbank. Das ermöglicht transaktionssicheres Speichern (kein Datenverlust bei Programmabsturz) und erklärt, warum `git diff` keine lesbaren Änderungen zeigt – SQLite ist eine Binärdatei. Die mitgelieferte `snapshot.json` löst dieses Problem für die wichtigsten Übersichtsdaten.
