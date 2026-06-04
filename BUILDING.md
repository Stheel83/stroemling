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

### Einmalig: Tools herunterladen

```bash
mkdir -p ~/tools

# linuxdeploy
wget "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" \
  -O ~/tools/linuxdeploy-x86_64.AppImage

# Qt-Plugin für linuxdeploy
wget "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" \
  -O ~/tools/linuxdeploy-plugin-qt-x86_64.AppImage

# appimagetool
wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" \
  -O ~/tools/appimagetool-x86_64.AppImage

# AppImage-Runtime (verhindert Download beim Build)
wget "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64" \
  -O ~/tools/runtime-x86_64

chmod +x ~/tools/linuxdeploy-x86_64.AppImage \
         ~/tools/linuxdeploy-plugin-qt-x86_64.AppImage \
         ~/tools/appimagetool-x86_64.AppImage
```

### Schritt 1: Release-Build erstellen

```bash
mkdir -p build-release && cd build-release
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ..
```

### Schritt 2: AppDir vorbereiten

Alle folgenden Befehle aus dem **Hauptverzeichnis** (`stroemling/`) ausführen:

```bash
rm -rf appimage/AppDir

QMAKE=$(which qmake6 || which qmake) \
~/tools/linuxdeploy-x86_64.AppImage \
  --appdir appimage/AppDir \
  --executable build-release/stroemling_app \
  --desktop-file appimage/stroemling-design.desktop \
  --icon-file appimage/stroemling-design.png \
  --plugin qt
```

### Schritt 3: Qt QML-Module einbinden

`linuxdeploy-plugin-qt` deployt die QML-Module nicht automatisch korrekt.
Manuell kopieren und an den von `qt.conf` erwarteten Ort verschieben:

```bash
QT_QML=$(qmake6 -query QT_INSTALL_QML 2>/dev/null || qmake -query QT_INSTALL_QML)
mkdir -p appimage/AppDir/usr/lib/qt6/qml
cp -r "$QT_QML"/. appimage/AppDir/usr/lib/qt6/qml/
mv appimage/AppDir/usr/lib/qt6/qml appimage/AppDir/usr/qml
```

### Schritt 4: AppImage erstellen

```bash
~/tools/appimagetool-x86_64.AppImage \
  --runtime-file ~/tools/runtime-x86_64 \
  appimage/AppDir \
  appimage/Stroemling-Design-x86_64.AppImage
```

### Testen

```bash
chmod +x appimage/Stroemling-Design-x86_64.AppImage
./appimage/Stroemling-Design-x86_64.AppImage
```

---

## Hinweise (Linux)

- Das AppImage enthält alle Qt-Abhängigkeiten und läuft ohne installiertes Qt auf anderen Linux-Systemen.
- Die Tools in `~/tools/` müssen nur einmalig heruntergeladen werden.
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
Compress-Archive -Path deploy\* -DestinationPath Stroemling-Design-0.5-win64.zip
```

Der Nutzer entpackt das ZIP und startet `stroemling_app.exe` — fertig.

---

## Cross-Kompilierung: Windows-Build unter Linux (openSUSE Tumbleweed)

Dieses Verfahren erzeugt eine `stroemling_app.exe` direkt auf dem Linux-Rechner,
ohne dass Windows benötigt wird.

**Werkzeug:** [MXE (M cross environment)](https://mxe.cc) baut einmalig den
MinGW-w64-Compiler und Qt6 für Windows aus dem Quellcode.

**Speicherbedarf:** ca. 15–20 GB für den MXE-Baum mit Qt6.  
**Ersteinrichtungszeit:** 1–3 Stunden (danach Strömling-Builds in ~5 Minuten).

---

### Schritt 1: Abhängigkeiten installieren

```bash
sudo zypper install -y \
  git autoconf automake bison bzip2 cmake flex \
  gcc gcc-c++ gettext-tools gperf intltool libtool make \
  nasm p7zip patch perl python3 ruby sed unzip wget xz \
  libffi-devel libjpeg8-devel libpng16-devel
```

---

### Schritt 2: MXE klonen und Qt6 bauen (einmalig)

```bash
git clone https://github.com/mxe/mxe.git ~/mxe
cd ~/mxe

# Qt6 für Windows (shared DLLs) + benötigte Module bauen
# Dauer: 1–3 Stunden je nach CPU
make -j$(nproc) MXE_TARGETS=x86_64-w64-mingw32.shared \
  qt6-qtbase \
  qt6-qtdeclarative \
  qt6-qttools \
  qt6-qtsvg
```

Danach MXE dauerhaft in den PATH aufnehmen:

```bash
echo 'export PATH="$HOME/mxe/usr/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

### Schritt 3: Strömling für Windows bauen

```bash
# Im Projektverzeichnis (stroemling/)
mkdir -p build-win && cd build-win

x86_64-w64-mingw32.shared-cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

Das fertige Binary liegt unter `build-win/stroemling_app.exe`.

---

### Schritt 4: Windows-Deploy-Paket erstellen

Die `.exe` allein startet nicht – Qt-DLLs und QML-Module müssen daneben liegen.
`windeployqt6.exe` (aus dem MXE-Build) übernimmt das automatisch, wenn Wine
installiert ist:

```bash
sudo zypper install -y wine

MXE_BIN="$HOME/mxe/usr/x86_64-w64-mingw32.shared/qt6/bin"

mkdir -p deploy-win
cp build-win/stroemling_app.exe deploy-win/

# windeployqt6 via Wine ausführen
WINEPREFIX=/tmp/wine-deploy WINEPATH="$MXE_BIN" \
  wine "$MXE_BIN/windeployqt6.exe" \
    --qmldir qml \
    --release \
    deploy-win/stroemling_app.exe
```

> **Hinweis:** Schlägt `windeployqt6` unter Wine fehl, kann die `.exe` alternativ
> auf einem Windows-Rechner mit dem nativen `windeployqt` deployed werden
> (Abschnitt „Windows-Paket für Nutzer erstellen" weiter unten).

---

### Schritt 5: ZIP für Nutzer erstellen

```bash
zip -r Stroemling-Design-win64.zip deploy-win/
```

---

### Tipps

- **Erneuter Strömling-Build** (nach Codeänderung): nur Schritt 3 wiederholen –
  MXE und Qt6 müssen nicht neu gebaut werden.
- **Build nach Absturz/Unterbrechung fortsetzen:** `make` ist inkrementell –
  einfach erneut `make -j$(nproc)` in `build-win/` ausführen. Bereits kompilierte
  Objektdateien werden übersprungen. Bei Linker-Fehlern (korrumpierte `.o`-Dateien)
  vorher `make clean` ausführen.
- **System friert beim Build ein:** `make -j$(nproc)` lastet alle Kerne voll aus.
  Alternativ `make -j4` verwenden – deutlich weniger Last, Build dauert etwas länger.
- **MXE aktualisieren:** `cd ~/mxe && git pull && make -j$(nproc) MXE_TARGETS=... qt6-qtbase ...`
- **Welche MXE-Version Qt6 hat:** `cat ~/mxe/src/qt6-qtbase.mk | grep PKG_VERSION`

---

## Release auf Codeberg veröffentlichen

Releases auf Codeberg funktionieren über Git-Tags. Sowohl Linux-AppImage als auch
Windows-ZIP können als Anhang an denselben Release gehängt werden.

### Schritt 1: Git-Tag setzen (auf Linux oder Windows)

```bash
git tag v0.5
git push origin v0.5
```

### Schritt 2: Release auf Codeberg anlegen

1. Codeberg-Projektseite öffnen → **Releases** → **Neuer Release**
2. Tag `v0.5` auswählen
3. Titel und Beschreibung eintragen (z.B. Changelog)
4. Dateien hochladen:
   - `Stroemling-Design-0.5-win64.zip` (Windows-Paket)
   - `Stroemling-Design-x86_64.AppImage` (Linux-AppImage)
5. **Release veröffentlichen**

Nutzer sehen auf der Projektseite unter „Releases" direkt die Download-Links.
