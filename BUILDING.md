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

Der offizielle Release-Build läuft **nicht** auf Tumbleweed, sondern nativ
auf einem separaten openSUSE-Leap-16-Rechner (GLIBC-Kompatibilität, s.
`konzept/technik/`-Debug-Historie bzw. Plan `glittery-prancing-yao.md`).
Tumbleweeds eigenes GLIBC ist neuer als das, was ältere Distros mitbringen —
ein dort gebautes AppImage würde auf vielen Zielsystemen nicht laufen.

**Auf dem Leap-16-Rechner** (Code kommt per `git clone`/`git pull` von
Codeberg, kein Push von dort vorgesehen):

```bash
git clone https://codeberg.org/Stheel/stroemling.git   # einmalig, sonst: git pull
cd stroemling

mkdir -p build-release && cd build-release
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . -j$(nproc)
ctest --output-on-failure
cd ..

cd appimage
rm -rf AppDir
VERSION=$(grep -oP 'APP_VERSION="\K[^"]+' ../CMakeLists.txt)
export APPIMAGE_EXTRACT_AND_RUN=1
export QMAKE=/usr/bin/qmake6
~/tools/linuxdeploy-x86_64.AppImage \
    --appdir AppDir \
    --executable ../build-release/stroemling_app \
    --desktop-file stroemling-design.desktop \
    --icon-file stroemling-design.png \
    --plugin qt
```

`linuxdeploy-plugin-qt` deployt die QML-Module nicht zuverlässig — deshalb
zwei manuelle Nachzieh-Schritte, bevor gepackt wird:

```bash
# 1) QML-Module selbst (QML-DEPLOY-01)
QT_QML=$(qmake6 -query QT_INSTALL_QML)
mkdir -p AppDir/usr/qml
cp -r "$QT_QML"/. AppDir/usr/qml/

# 2) Native Bibliotheken, die NUR von QML-Plugins gebraucht werden,
#    z.B. libQt6QuickControls2.so.6 (QML-DEPLOY-02) — transitiv, bis
#    sich nichts mehr ändert
QT_LIBS=$(qmake6 -query QT_INSTALL_LIBS)
while :; do
    added=0
    while IFS= read -r -d '' so; do
        for needed in $(readelf -d "$so" 2>/dev/null | grep NEEDED | grep -oP '\[\K[^\]]+'); do
            if [[ "$needed" == libQt6* ]] && [ ! -e "AppDir/usr/lib/$needed" ]; then
                src="$QT_LIBS/$needed"
                if [ -e "$src" ]; then
                    cp -L "$src" "AppDir/usr/lib/$needed"
                    echo "  nachgezogen: $needed"
                    added=1
                fi
            fi
        done
    done < <(find AppDir/usr \( -name '*.so' -o -name '*.so.*' \) -print0)
    [ "$added" -eq 0 ] && break
done

~/tools/appimagetool-x86_64.AppImage AppDir "Stroemling-Design-${VERSION}-x86_64.AppImage"
```

Fertige Datei danach auf den Tumbleweed-Rechner übertragen (z. B. `scp`) und
nach `Website/downloads/Stroemling-Design-<VERSION>-x86_64.AppImage`
kopieren.

### QML-DEPLOY-02 — Hintergrund

Symptom beim Start des AppImage ohne den zweiten Nachzieh-Schritt oben:

```
Cannot load library .../usr/qml/QtQuick/Controls/libqtquickcontrols2plugin.so:
/lib64/libQt6QuickControls2.so.6: version `Qt_6.x.x_PRIVATE_API' not found
```

**Ursache:** Der QML-Copy-Schritt (Workaround für QML-DEPLOY-01) kopiert die
QML-Plugin-`.so`-Dateien roh rein — `linuxdeploy` selbst lief vorher und hat
nur die Abhängigkeiten der Haupt-Executable aufgelöst. Native Bibliotheken,
die *ausschließlich* von QML-Plugins gebraucht werden (z. B.
`libQt6QuickControls2.so.6`, transitiv auch `libQt6QuickTemplates2.so.6`),
landen dadurch nie in `AppDir/usr/lib/`. Der Loader fällt dann auf die
System-Bibliothek zurück (`/lib64/...`) — läuft nur zufällig, wenn das
System-Qt exakt zur AppImage-Qt-Version passt, und bricht sonst mit obigem
Versionsfehler. Zum Testen: AppImage auf einem System ohne exakt passendes
System-Qt starten, oder `ldd` der gepackten `libqtquickcontrols2plugin.so`
gegen `AppDir/usr/lib/` abgleichen.

**Nachtrag (Aug 2026, beim GitHub-Actions-Testaufbau gefunden):** Der
Nachzieh-Loop selbst hatte einen zweiten, subtileren Bug — `find AppDir/usr
-name '*.so'` matcht nur Dateien, die **exakt** auf `.so` endet (z. B.
QML-Plugins wie `libqtquickdialogsplugin.so`). Die eigentlichen
versionierten Qt-Bibliotheken tragen aber Namen wie `libQt6QuickDialogs2.so.6`
— die enden auf `.6`, nicht auf `.so`, und wurden vom `find` nie erfasst.
Ergebnis: eine bereits nachgezogene Bibliothek wurde selbst nie auf *ihre
eigenen* transitiven Abhängigkeiten hin durchsucht, die Kette brach eine
Ebene zu früh ab (konkret: `libQt6QuickDialogs2.so.6` wurde kopiert, aber
deren eigene Abhängigkeit `libQt6QuickDialogs2Utils.so.6` nie entdeckt).
Fix: `find AppDir/usr \( -name '*.so' -o -name '*.so.*' \) -print0` erfasst
beide Namensformen. Auf der lokalen Leap-16-Maschine ist der Fehler
offenbar nie aufgefallen (vermutlich andere Abhängigkeitskette bei dortiger
Qt-Version/-Konfiguration) — der Fix schadet dort aber nicht und macht den
Loop grundsätzlich korrekter.

---

## Hinweise (Linux)

- Das AppImage enthält alle Qt-Abhängigkeiten und läuft ohne installiertes Qt auf anderen Linux-Systemen.
- Das AppImage (`appimage/Stroemling-Design-x86_64.AppImage`) ist nicht im Git-Repository enthalten.

---

## Linux-Build via GitHub Actions (Test, Aug 2026)

`.github/workflows/linux-build.yml` baut das AppImage automatisiert auf
einem `ubuntu-latest`-Runner — als Alternative/Ergänzung zum lokalen
Leap-16-Build oben. Bewusst **kein** Docker-Container mit openSUSE Leap 16
(würde die lokale Build-Maschine 1:1 spiegeln, ist aber aufwendiger
aufzusetzen, da Qt6 dort kein offizielles Zypper-Paket hat), sondern Qt6
über `jurplel/install-qt-action` (offizielle Qt-Binärpakete, dieselbe
Action wie beim Windows-Workflow) — einfacher, aber die GLIBC-Kompatibilität
des Ergebnisses ist damit **noch nicht verifiziert**, nur der lokale
Leap-16-Build ist bisher als Kompatibilitäts-Baseline geprüft.

- **Auslösen:** manuell über „Run workflow" (Tab „Actions") oder
  automatisch bei jedem Tag-Push (`v*`).
- **Ergebnis:** AppImage als Workflow-Artefakt zum Download
  (`Stroemling-Design-<version>-x86_64.AppImage`), 30 Tage aufbewahrt.
- Übernimmt die beiden QML-Nachzieh-Schritte (QML-DEPLOY-01/02) 1:1 aus
  dem oben dokumentierten manuellen Ablauf als eigene Workflow-Steps.
- **Status:** ✅ läuft grün durch (Aug 2026). Bis dahin behobene Stolpersteine:
  - `qttools` ist unter Linux (anders als Windows) kein separates
    Zusatzmodul, sondern Teil der Basis-Installation — `modules`-Angabe
    beim Qt-Install-Schritt entfernt.
  - `Qt6PrintSupport` braucht CUPS-Entwicklungsheader
    (`apt-get install libcups2-dev`), die der Runner nicht mitbringt.
  - Der Bauen-Schritt war auf `--target stroemling_app` beschränkt,
    wodurch `stroemling_test` fehlte und `ctest` es nicht fand — ohne
    Target-Einschränkung gebaut (baut alles, wie lokal `make -j$(nproc)`).
  - `linuxdeploy-plugin-qt` versucht automatisch alle gefundenen
    `sqldrivers`-Plugins zu bündeln (MySQL, Mimer, ODBC, …) und scheitert,
    wenn deren native Client-Libs fehlen (`libmimerapi.so`) — die App
    nutzt ausschließlich `QSQLITE`, alle anderen Treiber-Plugins vor dem
    Deploy-Schritt aus der Qt-Installation entfernt.
  - **GLIBC-Kompatibilität des Ergebnis-AppImage weiterhin nicht
    verifiziert** — nur „baut erfolgreich", noch nicht auf einem älteren
    Zielsystem getestet. Der lokale Leap-16-Build bleibt bis dahin die
    geprüfte Release-Quelle.

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
