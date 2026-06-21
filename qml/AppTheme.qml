pragma Singleton
import QtQuick
import QtCore

Item {
    id: root

    Settings {
        id: settings
        property string activeName: "hell"
    }

    property string activeName: settings.activeName || "hell"

    function setTheme(name) {
        settings.activeName = name
    }

    readonly property var _allThemes: ({
        "dunkel": {
            surface:       "#0a1628",
            sidebar:       "#0d1b2a",
            surfaceDeep:   "#09121e",
            inputBg:       "#0a1628",
            border:        "#1e3a5f",
            borderLight:   "#4a6080",
            borderDark:    "#2a4060",
            divider:       "#111e2e",
            textPrimary:   "#e8f0fe",
            textSecondary: "#c0d8f0",
            textMuted:     "#8899aa",
            textBright:    "#c8d8e8",
            textSubtle:    "#7a9ab8",
            accent:        "#4a9eff",
            accentLight:   "#7aaddd",
            logoGruen:     "#55d400",
            akzentGold:    "#f0c040",
            panelMid:      "#5577aa",
            hover:         "#0f2540",
            hoverSidebar:  "#162d4a",
            hoverBtn:      "#0d1528",
            activeItem:    "#1e3a5f",
            activeItemAlt: "#1a3a6a",
            btnPrimary:    "#1a4a8a",
            btnDisabled:   "#1a2a3a",
            badge:         "#1a3050",
            tableEven:     "#070e1a",
            tableOdd:      "#0a1321",
            tableHeader:   "#0d1f33"
        },
        "hell": {
            surface:       "#f0f4f8",
            sidebar:       "#e2eaf4",
            surfaceDeep:   "#d8e4f0",
            inputBg:       "#f4f8fc",
            border:        "#7a9ab8",
            borderLight:   "#6080a0",
            borderDark:    "#405060",
            divider:       "#c8d8e8",
            textPrimary:   "#1a2a3a",
            textSecondary: "#2a4060",
            textMuted:     "#3a5878",
            textBright:    "#3a5070",
            textSubtle:    "#506070",
            accent:        "#1a6fd8",
            accentLight:   "#4a90c8",
            logoGruen:     "#000000",
            akzentGold:    "#3d7a00",
            panelMid:      "#3a6090",
            hover:         "#c8dced",
            hoverSidebar:  "#bccfe0",
            hoverBtn:      "#d4e5f2",
            activeItem:    "#b8d0e8",
            activeItemAlt: "#9bbcd8",
            btnPrimary:    "#1a6fd8",
            btnDisabled:   "#a0b8d0",
            badge:         "#c8dcea",
            tableEven:     "#f0f5f9",
            tableOdd:      "#e6eef4",
            tableHeader:   "#d8e4ee"
        },
        "blueprint": {
            surface:       "#0c1f50",
            sidebar:       "#081640",
            surfaceDeep:   "#050e28",
            inputBg:       "#081640",
            border:        "#1a3a80",
            borderLight:   "#2050a0",
            borderDark:    "#3060a0",
            divider:       "#0f2060",
            textPrimary:   "#ffffff",
            textSecondary: "#c0d8ff",
            textMuted:     "#7090cc",
            textBright:    "#e0f0ff",
            textSubtle:    "#6080c0",
            accent:        "#40d0ff",
            accentLight:   "#80e0ff",
            logoGruen:     "#55d400",
            akzentGold:    "#f0c040",
            panelMid:      "#4070c0",
            hover:         "#102570",
            hoverSidebar:  "#102060",
            hoverBtn:      "#0c1d60",
            activeItem:    "#1a3a80",
            activeItemAlt: "#1a4a90",
            btnPrimary:    "#1a5090",
            btnDisabled:   "#1a2a50",
            badge:         "#1a3070",
            tableEven:     "#060f28",
            tableOdd:      "#081540",
            tableHeader:   "#0a1845"
        }
    })

    readonly property var _t: _allThemes[activeName] || _allThemes["dunkel"]

    readonly property string surface:       _t.surface
    readonly property string sidebar:       _t.sidebar
    readonly property string surfaceDeep:   _t.surfaceDeep
    readonly property string inputBg:       _t.inputBg
    readonly property string border:        _t.border
    readonly property string borderLight:   _t.borderLight
    readonly property string borderDark:    _t.borderDark
    readonly property string divider:       _t.divider
    readonly property string textPrimary:   _t.textPrimary
    readonly property string textSecondary: _t.textSecondary
    readonly property string textMuted:     _t.textMuted
    readonly property string textBright:    _t.textBright
    readonly property string textSubtle:    _t.textSubtle
    readonly property string accent:        _t.accent
    readonly property string accentLight:   _t.accentLight
    readonly property string logoGruen:     _t.logoGruen
    readonly property string akzentGold:    _t.akzentGold
    readonly property string panelMid:      _t.panelMid
    readonly property string hover:         _t.hover
    readonly property string hoverSidebar:  _t.hoverSidebar
    readonly property string hoverBtn:      _t.hoverBtn
    readonly property string activeItem:    _t.activeItem
    readonly property string activeItemAlt: _t.activeItemAlt
    readonly property string btnPrimary:    _t.btnPrimary
    readonly property string btnDisabled:   _t.btnDisabled
    readonly property string badge:         _t.badge
    readonly property string tableEven:     _t.tableEven
    readonly property string tableOdd:      _t.tableOdd
    readonly property string tableHeader:   _t.tableHeader
}
