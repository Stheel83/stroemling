import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../Normwerte.js" as NW

Item {
    id: root

    required property var theme
    property bool debug: false

    // CE-04: Mehrfachauswahl
    property var _ausgewaehlt:    []
    property int _letzterKabelId: -1

    // Auswahl leeren wenn ein anderes Kabel geladen wird
    Connections {
        target: kabelModel
        function onGeladen() {
            var curId = kabelModel.hatKabel ? kabelModel.stammdaten.id : -1
            if (curId !== root._letzterKabelId) {
                root._ausgewaehlt   = []
                root._letzterKabelId = curId
            }
        }
    }

    function _toggleAuswahl(aderId) {
        var idx = root._ausgewaehlt.indexOf(aderId)
        var sel = root._ausgewaehlt.slice()
        if (idx >= 0) sel.splice(idx, 1)
        else          sel.push(aderId)
        root._ausgewaehlt = sel
    }

    function _alleToggle() {
        if (root._ausgewaehlt.length === kabelModel.adern.length)
            root._ausgewaehlt = []
        else
            root._ausgewaehlt = kabelModel.adern.map(function(a) { return a.id })
    }

    readonly property var _normFarben: ({
        "neu":      [{farbe:"GN",farbe2:"YE"},"BN","BK","GY","BU","RD","OG","YE","VT","WH","PK","CL"],
        "alt":      [{farbe:"GN",farbe2:"YE"},"BK","RD","BU","GY","OG","YE","VT","WH","PK","CL"],
        "din47100": ["WH","BN","GN","YE","GY","PK","BU","RD","BK","VT"],
        "iec60757": ["BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","CL"]
    })

    function vorausfuellenFarben(normTyp) {
        var seq = root._normFarben[normTyp]
        var adern = kabelModel.adern
        var eintraege = []
        for (var i = 0; i < adern.length; i++) {
            var a = adern[i]
            var eintrag = i < seq.length ? seq[i] : seq[1 + ((i - seq.length) % (seq.length - 1))]
            var farbe  = typeof eintrag === "string" ? eintrag : eintrag.farbe
            var farbe2 = typeof eintrag === "string" ? ""      : (eintrag.farbe2 || "")
            eintraege.push({ id: a.id, farbe: farbe, farbe2: farbe2 })
        }
        // Ein Bulk-Aufruf (eine Transaktion, ein Tabellen-Reload) statt N
        // einzelner aderAktualisieren()-Aufrufe – sonst baut sich die Tabelle
        // (2 ComboBoxen je Zeile) bei jeder einzelnen Ader komplett neu auf.
        kabelModel.adernFarbenVorausfuellen(eintraege)
    }

    DebugLabel { panelName: qsTr("Ader-Tabelle"); visible: root.debug }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tabellenkopf
        Rectangle {
            Layout.fillWidth: true; height: 30; color: root.theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                spacing: 0

                // Alles-auswählen-Checkbox
                Item {
                    width: 28; height: 30
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14; height: 14; radius: 2
                        color:        root.theme.inputBg
                        border.color: root.theme.border
                        Text {
                            anchors.centerIn: parent
                            text:  root._ausgewaehlt.length > 0
                                   && root._ausgewaehlt.length === kabelModel.adern.length ? "✓" : ""
                            color: root.theme.accent; font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: alleMa
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: root._alleToggle()
                        cursorShape: Qt.PointingHandCursor
                    }
                    ToolTip.visible: alleMa.containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: qsTr("Alle auswählen / abwählen")
                }

                Text { text: qsTr("Nr.");             color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 30 }
                Text { text: qsTr("Bezeichnung");     color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 100 }
                Text { text: qsTr("Farbe");           color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 82 }
                Text { text: qsTr("2. Farbe");        color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 82 }
                Text { text: qsTr("mm²");             color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.fillWidth: true }
                Item { width: 70 }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

        ListView {
            id: aderListe
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            model: kabelModel.adern

            Column {
                anchors.centerIn: parent
                visible: aderListe.count === 0
                spacing: 8

                Image {
                    visible:  kabelModel.hatKabel
                    source:   "qrc:/assets/kabeljau_uebersicht.png"
                    width:    640; height: 640
                    fillMode: Image.PreserveAspectFit
                    smooth:   true; mipmap: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: kabelModel.hatKabel
                          ? qsTr("Noch keine Adern – mit '+ Ader' hinzufügen.")
                          : qsTr("Kabel-Daten anlegen um Adern zu definieren.")
                    color: root.theme.borderDark; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            delegate: Rectangle {
                id: delegateRow
                width:  aderListe.width
                height: 34

                readonly property bool ausgewaehlt: root._ausgewaehlt.indexOf(modelData.id) >= 0

                color: ausgewaehlt ? root.theme.activeItemAlt
                                   : (index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd)

                RowLayout {
                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                    spacing: 4

                    // Zeilen-Checkbox
                    Item {
                        width: 24; height: 34
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14; height: 14; radius: 2
                            color:        delegateRow.ausgewaehlt ? root.theme.accent : root.theme.inputBg
                            border.color: delegateRow.ausgewaehlt ? root.theme.accent : root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text:  delegateRow.ausgewaehlt ? "✓" : ""
                                color: "#ffffff"; font.pixelSize: 10; font.weight: Font.Bold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root._toggleAuswahl(modelData.id)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Text {
                        text:  String(modelData.aderNr)
                        color: root.theme.textMuted; font.pixelSize: 11
                        Layout.preferredWidth: 30
                    }

                    NavTextField {
                        id: tfAderBez
                        tabTarget:     tfAderMm2
                        backtabTarget: tfAderMm2
                        Layout.preferredWidth: 96
                        text: modelData.bezeichnung
                        font.pixelSize: 11; implicitHeight: 26
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                        onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     text,
                            "farbe":           cbAderFarbe.currentIndex > 0 ? cbAderFarbe.model[cbAderFarbe.currentIndex] : "",
                            "farbe2":          cbAderFarbe2.currentIndex > 0 ? cbAderFarbe2.model[cbAderFarbe2.currentIndex] : "",
                            "querschnitt_mm2": tfAderMm2.currentIndex >= 0 ? tfAderMm2.model[tfAderMm2.currentIndex] : 0
                        })
                    }

                    ComboBox {
                        id: cbAderFarbe
                        Layout.preferredWidth: 78
                        implicitHeight: 26
                        model: ["", "BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","CL"]
                        currentIndex: {
                            var f = modelData.farbe || ""
                            var idx = model.indexOf(f)
                            return idx >= 0 ? idx : 0
                        }
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        contentItem: Row {
                            leftPadding: 4; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            AderfarbenSwatch {
                                aderCode: modelData.farbe || ""
                                width: 10; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: (modelData.farbe || "") !== "" ? modelData.farbe : "—"
                                color: root.theme.textPrimary; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        delegate: ItemDelegate {
                            width: cbAderFarbe.width; implicitHeight: 24
                            contentItem: Row {
                                leftPadding: 6; spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                AderfarbenSwatch {
                                    aderCode: modelData; width: 10; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData !== "" ? modelData : "—"; font.pixelSize: 11
                                    color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                            highlighted: cbAderFarbe.highlightedIndex === index
                            ToolTip.visible: hovered && modelData !== ""
                            ToolTip.delay: 400
                            ToolTip.text: ({"BK":"Schwarz","BN":"Braun","RD":"Rot","OG":"Orange",
                                "YE":"Gelb","GN":"Grün","BU":"Blau","VT":"Violett","GY":"Grau",
                                "WH":"Weiß","PK":"Rosa","CL":"Farblos"})[modelData] || ""
                        }
                        onActivated: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     tfAderBez.text,
                            "farbe":           currentIndex > 0 ? model[currentIndex] : "",
                            "farbe2":          cbAderFarbe2.currentIndex > 0 ? cbAderFarbe2.model[cbAderFarbe2.currentIndex] : "",
                            "querschnitt_mm2": tfAderMm2.currentIndex >= 0 ? tfAderMm2.model[tfAderMm2.currentIndex] : 0
                        })
                    }

                    ComboBox {
                        id: cbAderFarbe2
                        Layout.preferredWidth: 78
                        implicitHeight: 26
                        model: ["", "BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK"]
                        currentIndex: {
                            var f = modelData.farbe2 || ""
                            var idx = model.indexOf(f)
                            return idx >= 0 ? idx : 0
                        }
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        contentItem: Row {
                            leftPadding: 4; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            AderfarbenSwatch {
                                aderCode: modelData.farbe2 || ""
                                width: 10; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: (modelData.farbe2 || "") !== "" ? modelData.farbe2 : "—"
                                color: root.theme.textPrimary; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        delegate: ItemDelegate {
                            width: cbAderFarbe2.width; implicitHeight: 24
                            contentItem: Row {
                                leftPadding: 6; spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                AderfarbenSwatch {
                                    aderCode: modelData; width: 10; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData !== "" ? modelData : "—"; font.pixelSize: 11
                                    color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                            highlighted: cbAderFarbe2.highlightedIndex === index
                            ToolTip.visible: hovered && modelData !== ""
                            ToolTip.delay: 400
                            ToolTip.text: ({"BK":"Schwarz","BN":"Braun","RD":"Rot","OG":"Orange",
                                "YE":"Gelb","GN":"Grün","BU":"Blau","VT":"Violett","GY":"Grau",
                                "WH":"Weiß","PK":"Rosa"})[modelData] || ""
                        }
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: qsTr("Zweite Farbe für Bifarb-Adern (z.B. PE grün-gelb, DIN-47100-Bifarben)")
                        onActivated: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     tfAderBez.text,
                            "farbe":           cbAderFarbe.currentIndex > 0 ? cbAderFarbe.model[cbAderFarbe.currentIndex] : "",
                            "farbe2":          currentIndex > 0 ? model[currentIndex] : "",
                            "querschnitt_mm2": tfAderMm2.currentIndex >= 0 ? tfAderMm2.model[tfAderMm2.currentIndex] : 0
                        })
                    }

                    ComboBox {
                        id: tfAderMm2
                        Layout.fillWidth: true
                        implicitHeight: 26
                        model: NW.QUERSCHNITT_WERTE
                        currentIndex: {
                            var q = modelData.querschnittMm2 || 0
                            for (var i = 0; i < model.length; i++)
                                if (Math.abs(model[i] - q) < 0.001) return i
                            return -1
                        }
                        displayText: currentIndex >= 0 ? model[currentIndex] + "" : "—"
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        contentItem: Text {
                            leftPadding: 6
                            text: tfAderMm2.displayText
                            color: root.theme.textPrimary; font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        delegate: ItemDelegate {
                            width: tfAderMm2.width; implicitHeight: 24
                            contentItem: Text {
                                leftPadding: 6; text: modelData + ""; font.pixelSize: 11
                                color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                            highlighted: tfAderMm2.highlightedIndex === index
                            ToolTip.visible: hovered
                            ToolTip.delay: 400
                            ToolTip.text: qsTr("Ø %1 mm (Leiter, eindrähtig, rechnerisch – reale Außenmaße je nach Isolierung/Litzenzahl abweichend)")
                                .arg((2 * Math.sqrt(modelData / Math.PI)).toFixed(2).replace('.', ','))
                        }
                        onActivated: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     tfAderBez.text,
                            "farbe":           cbAderFarbe.currentIndex > 0 ? cbAderFarbe.model[cbAderFarbe.currentIndex] : "",
                            "farbe2":          cbAderFarbe2.currentIndex > 0 ? cbAderFarbe2.model[cbAderFarbe2.currentIndex] : "",
                            "querschnitt_mm2": currentIndex >= 0 ? model[currentIndex] : 0
                        })
                    }

                    Row {
                        spacing: 2
                        Button {
                            width: 22; height: 22; flat: true
                            contentItem: Text { text: "↑"; color: root.theme.accent; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: kabelModel.aderSchieben(modelData.id, -1)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Ader nach oben verschieben")
                        }
                        Button {
                            width: 22; height: 22; flat: true
                            contentItem: Text { text: "↓"; color: root.theme.accent; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: kabelModel.aderSchieben(modelData.id, 1)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Ader nach unten verschieben")
                        }
                        Button {
                            width: 22; height: 22; flat: true
                            contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 16;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: kabelModel.aderLoeschen(modelData.id)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Ader löschen")
                        }
                    }
                }
            }
        }

        // CE-04: Sammel-Editierleiste (nur sichtbar wenn Adern ausgewählt)
        Rectangle {
            Layout.fillWidth: true
            height:  root._ausgewaehlt.length > 0 ? 56 : 0
            visible: root._ausgewaehlt.length > 0
            color:   root.theme.surfaceDeep
            clip:    true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: root.theme.accent; opacity: 0.4
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 6

                Text {
                    text: qsTr("%1 ausgewählt:").arg(root._ausgewaehlt.length)
                    color: root.theme.textMuted; font.pixelSize: 11
                    Layout.preferredWidth: 80
                }

                // Farbe
                ColumnLayout {
                    spacing: 2
                    Text { text: qsTr("Farbe"); color: root.theme.textMuted; font.pixelSize: 10 }
                    ComboBox {
                        id: cbBulkFarbe
                        implicitWidth: 96; implicitHeight: 24
                        model: ["—", "BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","CL"]
                        currentIndex: 0
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        contentItem: Row {
                            leftPadding: 4; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            AderfarbenSwatch {
                                aderCode: cbBulkFarbe.currentIndex > 0 ? cbBulkFarbe.model[cbBulkFarbe.currentIndex] : ""
                                width: 10; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: cbBulkFarbe.currentIndex > 0 ? cbBulkFarbe.model[cbBulkFarbe.currentIndex] : "—"
                                color: root.theme.textPrimary; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        delegate: ItemDelegate {
                            width: cbBulkFarbe.width; implicitHeight: 24
                            contentItem: Row {
                                leftPadding: 6; spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                AderfarbenSwatch {
                                    aderCode: modelData !== "—" ? modelData : ""
                                    width: 10; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData; font.pixelSize: 11
                                    color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                            highlighted: cbBulkFarbe.highlightedIndex === index
                        }
                    }
                }

                // 2. Farbe
                ColumnLayout {
                    spacing: 2
                    Text { text: qsTr("2. Farbe"); color: root.theme.textMuted; font.pixelSize: 10 }
                    ComboBox {
                        id: cbBulkFarbe2
                        implicitWidth: 96; implicitHeight: 24
                        model: ["—", "BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK"]
                        currentIndex: 0
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        contentItem: Row {
                            leftPadding: 4; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            AderfarbenSwatch {
                                aderCode: cbBulkFarbe2.currentIndex > 0 ? cbBulkFarbe2.model[cbBulkFarbe2.currentIndex] : ""
                                width: 10; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: cbBulkFarbe2.currentIndex > 0 ? cbBulkFarbe2.model[cbBulkFarbe2.currentIndex] : "—"
                                color: root.theme.textPrimary; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        delegate: ItemDelegate {
                            width: cbBulkFarbe2.width; implicitHeight: 24
                            contentItem: Row {
                                leftPadding: 6; spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                AderfarbenSwatch {
                                    aderCode: modelData !== "—" ? modelData : ""
                                    width: 10; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData; font.pixelSize: 11
                                    color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                            highlighted: cbBulkFarbe2.highlightedIndex === index
                        }
                    }
                }

                // mm²
                ColumnLayout {
                    spacing: 2
                    Text { text: qsTr("mm²"); color: root.theme.textMuted; font.pixelSize: 10 }
                    ComboBox {
                        id: bulkMm2
                        implicitWidth: 90; implicitHeight: 24
                        model: ["—"].concat(NW.QUERSCHNITT_WERTE)
                        currentIndex: 0
                        font.pixelSize: 11
                        property real gewaehlterWert: currentIndex > 0 ? model[currentIndex] : 0
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        contentItem: Text {
                            leftPadding: 6; text: bulkMm2.displayText
                            color: root.theme.textPrimary; font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        delegate: ItemDelegate {
                            width: bulkMm2.width; implicitHeight: 24
                            contentItem: Text {
                                leftPadding: 6; text: modelData + ""; font.pixelSize: 11
                                color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                            highlighted: bulkMm2.highlightedIndex === index
                            ToolTip.visible: hovered && modelData !== "—"
                            ToolTip.delay: 400
                            ToolTip.text: modelData !== "—" ? qsTr("Ø %1 mm (Leiter, eindrähtig, rechnerisch – reale Außenmaße je nach Isolierung/Litzenzahl abweichend)")
                                .arg((2 * Math.sqrt(modelData / Math.PI)).toFixed(2).replace('.', ',')) : ""
                        }
                    }
                }

                // Bezeichnung
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 10 }
                    TextField {
                        id: bulkBez
                        Layout.fillWidth: true; implicitHeight: 24
                        font.pixelSize: 11
                        placeholderText: qsTr("leer = unveraendert")
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }
                }

                // Übernehmen
                Button {
                    text: qsTr("Uebernehmen"); implicitHeight: 28; implicitWidth: 90
                    contentItem: Text {
                        text: parent.text; color: root.theme.textPrimary
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: root.theme.accent
                    }
                    onClicked: {
                        var daten = {}
                        if (cbBulkFarbe.currentIndex  > 0) daten["farbe"]           = cbBulkFarbe.model[cbBulkFarbe.currentIndex]
                        if (cbBulkFarbe2.currentIndex > 0) daten["farbe2"]          = cbBulkFarbe2.model[cbBulkFarbe2.currentIndex]
                        if (bulkMm2.currentIndex      > 0) daten["querschnitt_mm2"] = bulkMm2.model[bulkMm2.currentIndex]
                        if (bulkBez.text.trim()     !== "") daten["bezeichnung"]   = bulkBez.text.trim()
                        kabelModel.aderMehrfachAktualisieren(root._ausgewaehlt, daten)
                        cbBulkFarbe.currentIndex = 0; cbBulkFarbe2.currentIndex = 0; bulkMm2.currentIndex = 0; bulkBez.text = ""
                    }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Ausgefüllte Felder auf alle markierten Adern anwenden")
                }

                // Auswahl aufheben
                Button {
                    text: "×"; implicitHeight: 28; implicitWidth: 28
                    contentItem: Text {
                        text: parent.text; color: root.theme.textMuted
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.activeItemAlt : "transparent"
                        radius: 4; border.color: root.theme.border
                    }
                    onClicked: root._ausgewaehlt = []
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Auswahl aufheben")
                }
            }
        }

        // Vorausfüllen-Zeile
        Rectangle {
            Layout.fillWidth: true
            height: kabelModel.hatKabel && kabelModel.adern.length > 0 ? 56 : 0
            visible: kabelModel.hatKabel && kabelModel.adern.length > 0
            color: root.theme.surfaceDeep; clip: true
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: root.theme.divider
            }
            ColumnLayout {
                anchors { fill: parent; topMargin: 6; bottomMargin: 6; leftMargin: 12; rightMargin: 12 }
                spacing: 4
                Text {
                    text: qsTr("Farben vorausfüllen:")
                    color: root.theme.textMuted; font.pixelSize: 10
                }
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [
                            { key: "neu",      label: "Neue Norm (IEC 60446)", akzent: true,  tip: "IEC 60446:2010 / HD 308 S2 — GN/YE, BN, BK, GY, BU, …" },
                            { key: "alt",      label: "Alte Norm (VDE 0293)",  akzent: false, tip: "VDE 0293 / alte deutsche Norm — GN/YE, BK, RD, BU, GY, …" },
                            { key: "din47100", label: "DIN 47100",             akzent: false, tip: "DIN 47100 — WH, BN, GN, YE, GY, PK, BU, RD, BK, VT, …" },
                            { key: "iec60757", label: "IEC 60757",             akzent: false, tip: "IEC 60757 Reihenfolge — BK, BN, RD, OG, YE, GN, BU, VT, GY, WH, PK, CL" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; implicitHeight: 24
                            contentItem: Text {
                                text: parent.text; color: root.theme.textPrimary; font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? root.theme.accent : root.theme.inputBg
                                radius: 3
                                border.color: modelData.akzent ? root.theme.accent : root.theme.border
                            }
                            onClicked: root.vorausfuellenFarben(modelData.key)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: modelData.tip
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // Fußzeile
        Rectangle {
            Layout.fillWidth: true; height: 44; color: root.theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text {
                    text: qsTr("%1 Ader(n)").arg(kabelModel.adern.length)
                    color: root.theme.textMuted; font.pixelSize: 12; Layout.fillWidth: true
                }
                Button {
                    text: qsTr("+ Ader"); implicitHeight: 30
                    enabled: kabelModel.hatKabel
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                    }
                    onClicked: kabelModel.aderAnlegen()
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: kabelModel.hatKabel
                                  ? qsTr("Neue Ader hinzufügen")
                                  : qsTr("Zuerst Kabel-Daten anlegen")
                }
            }
        }
    }
}
