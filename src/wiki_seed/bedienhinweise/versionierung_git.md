# Versionierung mit Git

Strömling-Projekte sind eigenständige **SQLite-Dateien** (`.strl`).
Da alle Daten in einer einzigen Datei stecken, funktioniert Git als
Versionsverwaltung ohne jede Konfiguration in der App.

## Einrichten (einmalig)

```bash
# Projektordner anlegen und als Git-Repo initialisieren
mkdir ~/Projekte/Schaltschrank-A
cd ~/Projekte/Schaltschrank-A
git init

# .gitignore anlegen (optional, aber empfohlen)
echo "*.db-wal" >  .gitignore
echo "*.db-shm" >> .gitignore
git add .gitignore
git commit -m "Repo initialisiert"
```

Danach das Projekt in diesem Ordner anlegen oder die `.strl`-Datei
dorthin kopieren (📂 → **Projekt öffnen**).

## Täglicher Workflow

```bash
# Nach einer Arbeitssitzung
git add schaltschrank_a.strl
git commit -m "Hauptstromkreis: Schütze K1–K3 verdrahtet"

# Verlauf anzeigen
git log --oneline

# Auf Stand vor 3 Commits zurückgehen (nur lesen, nicht überschreiben)
git show HEAD~3:schaltschrank_a.strl > alt.strl
```

## Was Git kann und was nicht

| ✅ Funktioniert | ❌ Funktioniert nicht |
|---|---|
| Vollständige Versionshistorie | Lesbares `git diff` (Binärdatei) |
| Wiederherstellung beliebiger Stände | Zeilenweises Mergen zweier Versionen |
| Branching (z. B. Varianten A/B) | Automatische Konfliktauflösung |
| Backup auf GitHub/Gitea/lokalem Server | |

## Tipps

- **Sinnvolle Commit-Nachrichten** helfen später: lieber
  *„Steuerstromkreis Schütz K2 korrigiert"* als *„Update"*.
- **Vor größeren Umstrukturierungen** einen Commit machen – so kann
  man jederzeit zum Ausgangszustand zurück.
- **Projekt exportieren** (⬆-Button in der Projektliste) erzeugt eine
  kompakte, saubere Kopie – ideal für Archivierung oder Weitergabe.
- Mehrere Varianten eines Projekts: einfach **Branches** nutzen:
  ```bash
  git checkout -b variante-drehstrom
  # ... Änderungen ...
  git checkout main   # zurück zur Hauptvariante
  ```
