# Strömling Design – Bauanleitung

## Voraussetzungen (Linux)

- Qt 6.5 oder neuer (inkl. Qt Quick, Qt Quick Controls 2, Qt SQL)
- CMake 3.16+
- C++17-kompatibler Compiler (GCC / Clang)
- SQLite (meist systemseitig vorhanden)

Auf openSUSE / Fedora / Ubuntu typischerweise via Paketmanager installierbar.

---

## Debug-Build (Entwicklung)

```bash
mkdir -p build && cd build
cmake ..
make -j$(nproc)
./stroemling_app
```

---

## Release-Build

```bash
mkdir -p build-release && cd build-release
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

Das fertige Binary liegt unter `build-release/stroemling_app`.

---

## AppImage bauen

Der offizielle Release-Build läuft **nicht** mehr nativ auf Tumbleweed,
sondern in einem Leap-16-Container (GLIBC-Kompatibilität, s.
`konzept/technik/`-Debug-Historie bzw. Plan `glittery-prancing-yao.md`).

```bash
sudo bash /home/stephan/containers/build-release-appimage.sh
```

Das Skript baut `stroemling_app` sauber im Container (`build-leap16/`),
lässt `ctest` laufen und erzeugt anschließend
`appimage/Stroemling-Design-<VERSION>-x86_64.AppImage` im Hauptverzeichnis.
Die dafür nötigen `linuxdeploy`/`appimagetool`-Binaries liegen in
`~/tools/` und werden vom Skript in den Container gemountet.

---

## Hinweise (Linux)

- Das AppImage enthält alle Qt-Abhängigkeiten und läuft ohne installiertes Qt auf anderen Linux-Systemen.
- Das AppImage (`appimage/Stroemling-Design-x86_64.AppImage`) ist nicht im Git-Repository enthalten.

---

## Windows 11 Build

### Voraussetzungen

1. **Qt 6.5+** für Windows installieren: [qt.io/download](https://www.qt.io/download)
   - Komponenten wählen: `Qt 6.x.x` → `MSVC 2022 64-bit` **oder** `MinGW 13.1.0 64-bit`
   - Zusätzlich: `Qt Quick`, `Qt Quick Controls`, `Qt SQL`, `Qt Print Support`
2. **CMake 3.16+** – wird mit Qt mitgeliefert oder separat von [cmake.org](https://cmake.org)
3. **Compiler:**
   - MSVC: Visual Studio 2022 Community (kostenlos) mit „Desktop-Entwicklung mit C++"
   - **oder** MinGW: wird direkt im Qt-Installer angeboten (einfacher, kein VS nötig)
4. **Git für Windows** (optional, für die Git-Integration in der App): [git-scm.com](https://git-scm.com)

### Build (PowerShell / Eingabeaufforderung)

```powershell
# Im Projektverzeichnis (stroemling/)
mkdir build
cd build

# Pfad zu Qt anpassen – Beispiel MSVC:
cmake .. -DCMAKE_PREFIX_PATH="C:\Qt\6.9.0\msvc2022_64"

# Beispiel MinGW:
# cmake .. -DCMAKE_PREFIX_PATH="C:\Qt\6.9.0\mingw_64" -G "MinGW Makefiles"

cmake --build . --parallel
```

Das fertige Binary liegt unter `build\stroemling_app.exe` (Debug) bzw. nach einem Release-Build:

```powershell
cmake .. -DCMAKE_PREFIX_PATH="C:\Qt\6.9.0\msvc2022_64" -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel --config Release
```

### Deployment (windeployqt)

Das `.exe` allein startet nicht – Qt-DLLs und QML-Module müssen daneben liegen.
`windeployqt` erledigt das automatisch:

```powershell
# Qt-Pfad anpassen
$env:Path = "C:\Qt\6.9.0\msvc2022_64\bin;" + $env:Path

# Deploy-Ordner anlegen
mkdir deploy
copy build\Release\stroemling_app.exe deploy\

windeployqt --qmldir qml deploy\stroemling_app.exe
```

Danach ist `deploy\` ein eigenständiger Ordner, der auf jedem Windows-11-Rechner läuft.

### Datenpfad unter Windows

App-Datenbanken (Launcher, Wiki, Makros):
```
%LOCALAPPDATA%\Strömling Design\
  stroemling.db   ← Launcher-DB (zuletzt geöffnete Projekte)
  wiki.db
  makros.db
```
Typischerweise: `C:\Users\<Benutzername>\AppData\Local\Strömling Design\`

Projekte werden als Ordner gespeichert (frei wählbarer Ort):
```
[beliebiger Ort]\MeinProjekt\
  projekt.strl    ← Projektdatenbank (alle Schaltplandaten)
```

Die Log-Datei liegt neben der `stroemling_app.exe`.

---

## Windows-Paket für Nutzer erstellen

Nutzer brauchen kein Qt installiert. `windeployqt` bündelt alle nötigen DLLs
und QML-Module in einen eigenständigen Ordner, der sich einfach als ZIP verteilen lässt.

### Schritt 1: Release-Build erstellen

```powershell
# Im Projektverzeichnis (stroemling/)
mkdir build-release
cd build-release
cmake .. -DCMAKE_PREFIX_PATH="C:\Qt\6.9.0\mingw_64" -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel --config Release
cd ..
```

### Schritt 2: Deploy-Ordner befüllen

```powershell
# Qt-Tools in den PATH aufnehmen (Pfad anpassen)
$env:Path = "C:\Qt\6.9.0\mingw_64\bin;" + $env:Path

# Deploy-Ordner anlegen und EXE hineinkopieren
mkdir deploy
copy build-release\stroemling_app.exe deploy\

# windeployqt kopiert alle DLLs und QML-Module automatisch
windeployqt --qmldir qml --release deploy\stroemling_app.exe
```

### Schritt 3: ZIP erstellen

```powershell
Compress-Archive -Path deploy\* -DestinationPath Stroemling-Design-0.666-win64.zip
```

Der Nutzer entpackt das ZIP und startet `stroemling_app.exe` — fertig.

---

## Windows-Build via GitHub Actions (nativer Build ohne Wine/MXE)

Alternative zum lokalen Windows-Build: `.github/workflows/windows-build.yml`
baut auf einem echten `windows-latest`-Runner (kein Wine, kein
QML-Erkennungsrisiko bei `windeployqt`). Funktioniert auch bei einem
**privaten** GitHub-Repo — GitHub Actions ist nicht auf öffentliche Repos
beschränkt.

- **Kontingent (privat, kostenloser Account):** 2.000 Minuten/Monat,
  Windows-Runner zählen mit 2× dagegen → effektiv ~1.000 Min. echte
  Windows-Build-Zeit/Monat. Öffentliche Repos: unbegrenzt.
- **Auslösen:** manuell über „Run workflow" (Tab „Actions") oder automatisch
  bei jedem Tag-Push (`v*`, passend zum Codeberg-Release-Tag).
- **Ergebnis:** ZIP als Workflow-Artefakt zum Download (`Stroemling-Design-<version>-windows-x64.zip`),
  30 Tage aufbewahrt — von dort aus manuell ins Codeberg-Release hochladen.
- Nutzt `jurplel/install-qt-action` für den Qt-Download (MSVC 2019 64-bit),
  Ziel-Executable ist `stroemling_app` (siehe `CMakeLists.txt`).

---

## Release auf Codeberg veröffentlichen

Releases auf Codeberg funktionieren über Git-Tags. Sowohl Linux-AppImage als auch
Windows-ZIP können als Anhang an denselben Release gehängt werden.

### Schritt 1: Git-Tag setzen (auf Linux oder Windows)

```bash
git tag v0.666
git push origin v0.666
```

### Schritt 2: Release auf Codeberg anlegen

1. Codeberg-Projektseite öffnen → **Releases** → **Neuer Release**
2. Tag `v0.666` auswählen
3. Titel und Beschreibung eintragen (z.B. Changelog)
4. Dateien hochladen:
   - `Stroemling-Design-0.666-win64.zip` (Windows-Paket)
   - `Stroemling-Design-0.666-x86_64.AppImage` (Linux-AppImage)
5. **Release veröffentlichen**

Nutzer sehen auf der Projektseite unter „Releases" direkt die Download-Links.
