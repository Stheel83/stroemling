cmake_minimum_required(VERSION 3.16)
project(stroemling VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Sql LinguistTools PrintSupport)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(stroemling_app
    src/main.cpp
    src/database/Database.cpp
    src/database/Database.h
    src/models/ProjektModel.cpp
    src/models/ProjektModel.h
    src/models/SeitenModel.cpp
    src/models/SeitenModel.h
    src/models/BauteilModel.cpp
    src/models/BauteilModel.h
    src/models/KlemmeModel.cpp
    src/models/KlemmeModel.h
    src/models/KlemmenreihenModel.cpp
    src/models/KlemmenreihenModel.h
    src/models/KabelModel.cpp
    src/models/KabelModel.h
    src/models/SymbolDefinitionModel.cpp
    src/models/SymbolDefinitionModel.h
    src/models/KabelRechnerModel.cpp
    src/models/KabelRechnerModel.h
    src/utils/KabelTabellen.h
)

qt_add_qml_module(stroemling_app
    URI stroemling
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/ProjectTree.qml
        qml/SeitenBaum.qml
        qml/BauteilAnsicht.qml
        qml/SchaltplanCanvas.qml
        qml/EigenschaftenPanel.qml
        qml/SymbolPalette.qml
        qml/ListenAnsicht.qml

        qml/components/SidebarButton.qml
        qml/components/DebugLabel.qml
        qml/components/NavTextField.qml
        qml/components/InputField.qml
        qml/components/ColorPalette.qml
        qml/components/MiniButton.qml
        qml/components/StilSlider.qml
        qml/components/MassField.qml

        qml/ep/EpGeraetekastenSection.qml
        qml/ep/EpStrukturkastenSection.qml
        qml/ep/EpMakrokastenSection.qml
        qml/ep/EpKlemmenAnschlussSection.qml
        qml/ep/EpKabelDefinitionSection.qml
        qml/ep/EpBetriebsmittelSection.qml
        qml/ep/EpQuerverweisSection.qml
        qml/ep/EpGeraeteanschlussSection.qml
        qml/ep/EpVerbindungSection.qml
        qml/ep/EpStilSection.qml
        qml/ep/EpFuellungSection.qml
        qml/ep/EpFormSection.qml
        qml/ep/EpMehrfachauswahlSection.qml
        qml/ep/EpSymbolSection.qml
        qml/ep/EpAderdefinitionSection.qml
        qml/ep/EpPotenzialSection.qml
        qml/ep/EpTreffpunktSection.qml
        qml/ep/EpBildSection.qml
        qml/ep/EpTextInhaltSection.qml
        qml/ep/EpNotizSection.qml
        qml/ep/EpSteckverbinderSection.qml
        qml/ep/EpMasseSection.qml

        qml/ibn/IbnBmSplit.qml
        qml/ibn/IbnKabelSplit.qml

        qml/ba/BaFormContent.qml
        qml/ba/BaKategorieSidebar.qml
        qml/ba/BaBauteilListe.qml
        qml/ba/BaMakroAnsicht.qml

        qml/la/LaCsvLeiste.qml
        qml/la/LaTabStueckliste.qml
        qml/la/LaTabQuerverweise.qml
        qml/la/LaTabAderliste.qml
        qml/la/LaTabKlemmenplan.qml
        qml/la/LaTabKabelliste.qml

        qml/klemmenreihen/KrVorschauPanel.qml
        qml/klemmenreihen/KrEigenschaftenPanel.qml

        qml/canvas/WerkzeugButton.qml
        qml/canvas/CanvasHeaderBar.qml
        qml/canvas/CanvasFooterBar.qml
        qml/canvas/CanvasWerkzeugLeiste.qml

        qml/symboleditor/SeSymbolListe.qml
        qml/symboleditor/SeEditorHeader.qml
        qml/symboleditor/SeWerkzeugToolbar.qml
        qml/symboleditor/SeEigenschaftenPanel.qml
        qml/symboleditor/SePinListe.qml

        qml/KlemmenVorschau.qml
        qml/KlemmenEditor.qml
        qml/KlemmePlatzierDialog.qml
        qml/KlemmenreihenAnsicht.qml
        qml/SymbolEditorAnsicht.qml
        qml/KabelEditor.qml
        qml/KabelRechner.qml
        qml/KabellinieDialog.qml
        qml/BauteilKabelPickerDialog.qml
        qml/AderzuordnungDialog.qml
        qml/MakrobenennDialog.qml
        qml/IbnAnsicht.qml
        qml/IbnFeldEditorDialog.qml
        qml/CanvasPanel.qml
        qml/KommandoPalette.qml
)

qt_add_resources(stroemling_app "database_seeds"
    PREFIX "/database"
    BASE "src/database"
    FILES
        src/database/symbole.sql
)

target_link_libraries(stroemling_app PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Sql
    Qt6::PrintSupport
)

qt_add_translations(stroemling_app
    TS_FILES
        i18n/stroemling_en.ts
    SOURCES
        qml/Main.qml
        qml/ProjectTree.qml
        qml/SeitenBaum.qml
        qml/BauteilAnsicht.qml
        qml/SchaltplanCanvas.qml
        qml/EigenschaftenPanel.qml
        qml/SymbolPalette.qml
        qml/ListenAnsicht.qml
        qml/components/SidebarButton.qml
)
