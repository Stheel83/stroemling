# Strömling Design – Bauanleitung

## Voraussetzungen

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

## Hinweise

- Das AppImage enthält alle Qt-Abhängigkeiten und läuft ohne installiertes Qt auf anderen Linux-Systemen.
- Die Tools in `~/tools/` müssen nur einmalig heruntergeladen werden.
- Das AppImage (`appimage/Stroemling-Design-x86_64.AppImage`) ist nicht im Git-Repository enthalten.
