cmake_minimum_required(VERSION 3.16)
project(stroemling VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Sql LinguistTools PrintSupport Test)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(stroemling_app
    WIN32 MACOSX_BUNDLE
    src/logging.cpp
    src/logging.h
    src/main.cpp
    src/database/Database.cpp
    src/database/Database_Schema.cpp
    src/database/Database_Canvas.cpp
    src/database/Database_Listen.cpp
    src/database/Database_Normblatt.cpp
    src/database/Database_Kabel.cpp
    src/database/Database_Klemmen.cpp
    src/database/Database_Makro.cpp
    src/database/Database_IBN.cpp
    src/database/Database_Wiki.cpp
    src/database/Database_SPS.cpp
    src/database/Database_PDF.cpp
    src/database/Database_DRC.cpp
    src/database/Database_Git.cpp
    src/database/Database_Geraetekasten.cpp
    src/database/Database_Archiv.cpp
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
    src/canvas/ElementeModel.cpp
    src/canvas/ElementeModel.h
    src/achievements/AchievementManager.cpp
    src/achievements/AchievementManager.h
)

# Qt 6: pragma Singleton allein reicht nicht – qmldir bekommt "singleton"-Schlüsselwort
# nur wenn diese Property VOR qt_add_qml_module gesetzt ist.
set_source_files_properties(qml/AppTheme.qml
    PROPERTIES QT_QML_SINGLETON_TYPE true)

qt_add_qml_module(stroemling_app
    URI stroemling
    VERSION 1.0
    QML_FILES
        qml/AppTheme.qml
        qml/Main.qml
        qml/ProjectTree.qml
        qml/PtEigenschaftenDialog.qml
        qml/PtLoeschenDialog.qml
        qml/SeitenBaum.qml
        qml/SeitenBaumNormblattPanel.qml
        qml/SeitenBaumBauteilePanel.qml
        qml/BauteilAnsicht.qml
        qml/SchaltplanCanvas.qml
        qml/PokestroemPlaceholder.qml
        qml/ShortcutUebersicht.qml
        qml/EigenschaftenPanel.qml
        qml/SymbolPalette.qml
        qml/ListenAnsicht.qml

        qml/components/SidebarButton.qml
        qml/components/DebugLabel.qml
        qml/components/NavTextField.qml
        qml/components/InputField.qml
        qml/components/ColorPalette.qml
        qml/components/MiniButton.qml
        qml/components/AderfarbenSwatch.qml
        qml/components/StilSlider.qml
        qml/components/MassField.qml
        qml/components/AchievementToast.qml

        qml/AchievementsPanel.qml

        qml/ep/EpGeraetekastenSection.qml
        qml/ep/EpStrukturkastenSection.qml
        qml/ep/EpMakrokastenSection.qml
        qml/ep/EpKlemmenAnschlussSection.qml
        qml/ep/EpKabelDefinitionSection.qml
        qml/ep/EpKabelStammdatenBlock.qml
        qml/ep/EpKabelLinienBlock.qml
        qml/ep/EpKabelAdernBlock.qml
        qml/ep/EpBetriebsmittelSection.qml
        qml/ep/EpBmVerknuepfenDialog.qml
        qml/ep/EpBmVerknuepfungBlock.qml
        qml/ep/EpBmKontaktBlock.qml
        qml/ep/EpBmBeschriftungBlock.qml
        qml/ep/EpQuerverweisSection.qml
        qml/ep/EpGeraeteanschlussSection.qml
        qml/ep/EpVerbindungSection.qml
        qml/ep/EpStilSection.qml
        qml/ep/EpFuellungSection.qml
        qml/ep/EpFormSection.qml
        qml/ep/EpFormatPinselSection.qml
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
        qml/ep/EpSpsKanalSection.qml

        qml/ibn/IbnBmSplit.qml
        qml/ibn/IbnKabelSplit.qml
        qml/ibn/IbnAnsicht.qml
        qml/ibn/IbnFeldEditorDialog.qml
        qml/ibn/IbnFeldPanel.qml

        qml/ba/BaFormContent.qml
        qml/ba/BaKategorieSidebar.qml
        qml/ba/BaKategorieNeuDialog.qml
        qml/ba/BaKategorieBearbeitenDialog.qml
        qml/ba/BaBauteilNeuDialog.qml
        qml/ba/BaSymbolPickerDialog.qml
        qml/ba/BaCsvImportDialog.qml
        qml/ba/BaBauteilListe.qml
        qml/ba/BaGeraetekastenAnsicht.qml
        qml/ba/BaMakroBibliothek.qml

        qml/la/LaCsvLeiste.qml
        qml/la/LaTabStueckliste.qml
        qml/la/LaTabQuerverweise.qml
        qml/la/LaTabAderliste.qml
        qml/la/LaTabKlemmenplan.qml
        qml/la/LaTabKlemmlistenauszug.qml
        qml/la/LaTabKabelliste.qml

        qml/canvas/WerkzeugButton.qml
        qml/canvas/CanvasHeaderBar.qml
        qml/canvas/CanvasFooterBar.qml
        qml/canvas/CanvasWerkzeugLeiste.qml
        qml/canvas/CanvasInteraktionArea.qml
        qml/canvas/CanvasNavigationHandler.qml
        qml/canvas/CanvasDialogLayer.qml
        qml/canvas/CanvasAktionenHandler.qml
        qml/canvas/CanvasBildWerkzeug.qml
        qml/canvas/CanvasTextEditor.qml
        qml/canvas/CanvasMinimap.qml

        qml/symboleditor/SeSymbolListe.qml
        qml/symboleditor/SeEditorHeader.qml
        qml/symboleditor/SeWerkzeugToolbar.qml
        qml/symboleditor/SeEigenschaftenPanel.qml
        qml/symboleditor/SePinListe.qml

        qml/klemmen/KlemmenVorschau.qml
        qml/klemmen/KlemmenEditor.qml
        qml/klemmen/KlemmenEditorLinksBlock.qml
        qml/klemmen/KlemmenEditorAnschlussTabelle.qml
        qml/klemmen/KlemmePlatzierDialog.qml
        qml/klemmen/KlemmenreihenAnsicht.qml
        qml/klemmen/KrVorschauPanel.qml
        qml/klemmen/KrEigenschaftenPanel.qml
        qml/SymbolEditorAnsicht.qml
        qml/kabel/KabelEditor.qml
        qml/kabel/KabelEditorLinksBlock.qml
        qml/kabel/KabelEditorAdernTabelle.qml
        qml/kabel/KabelRechner.qml
        qml/kabel/KabellinieDialog.qml
        qml/kabel/BauteilKabelPickerDialog.qml
        qml/kabel/AderzuordnungDialog.qml
        qml/MakrobenennDialog.qml
        qml/MakroPalette.qml
        qml/MakroBibliothekDialog.qml
        qml/DrcPanel.qml
        qml/PdfExportDialog.qml
        qml/CanvasPanel.qml
        qml/KommandoPalette.qml
        qml/NormblattEditorDialog.qml
        qml/nb/NormblattEditorCanvas.qml
        qml/nb/NormblattFeldPalette.qml
        qml/nb/NormblattFeldProperties.qml
        qml/wiki/WikiAnsicht.qml
        qml/wiki/WikiFormatierungsToolbar.qml
        qml/wiki/WikiBildGalerie.qml
        qml/wiki/WikiBundleDialog.qml
        qml/einstellungen/EinstellungenAnsicht.qml
        qml/einstellungen/EinDatenbankpfadeBlock.qml
        qml/einstellungen/EinDatensicherungBlock.qml
        qml/einstellungen/EinFunModusBlock.qml
        qml/einstellungen/EinMitwirkendeBlock.qml
        qml/einstellungen/EinEntstehungBlock.qml
        qml/sps/SpsAnsicht.qml
        qml/sps/SpsRackDialog.qml
        qml/sps/SpsBaugruppeDialog.qml
        qml/sps/SpsAutoAnlegenDialog.qml
        qml/sps/SpsKanalDialog.qml
        qml/FehlersuchAnsicht.qml
        qml/ProjektStartAnsicht.qml
        qml/fun/FunModusOverlay.qml
        qml/fun/FunSprite.qml
        qml/fun/FunSzeneDvd.qml
        qml/fun/FunSzeneOrbit.qml
        qml/fun/FunSzeneConga.qml
        qml/fun/FunSzeneFangen.qml
        qml/fun/FunSzeneSpringeil.qml
        qml/fun/FunSzeneFormation.qml
        qml/fun/FunSzeneGespraech.qml
        qml/fun/FunSzeneFall.qml
        qml/fun/FunSzeneImpulsino.qml
        qml/logos/LogoHeader.qml
        qml/logos/LogoIconSinus.qml
        qml/logos/LogoIconAtom.qml
        qml/logos/LogoIconBernstein.qml
        qml/logos/LogoIconCee.qml
        qml/logos/LogoIconOstsee.qml
        qml/logos/LogoIconFischKondensator.qml
        qml/logos/LogoIconFischSpule.qml
        qml/logos/LogoIconFischWiderstand.qml
        qml/logos/LogoIconFischDiode.qml
        qml/logos/LogoIconGruenerFisch.qml
        qml/logos/LogoFischBase.js
        qml/logos/LogoBase.js
        qml/SymbolKlassen.js
)

qt_add_resources(stroemling_app "stromlinge_assets"
    PREFIX "/assets"
    BASE "qml/assets"
    FILES
        qml/assets/schwaerzchen_sheet.png
        qml/assets/pokestroem_cee.png
        qml/assets/impulsino_sheet.png
        qml/assets/isolus.png
        qml/assets/brauno_uebersicht.png
        qml/assets/blaubertha_uebersicht.png
        qml/assets/grausel_uebersicht.png
        qml/assets/erdikus_uebersicht.png
        qml/assets/datinchen_uebersicht.png
        qml/assets/impulsino_uebersicht.png
        qml/assets/isolus_kampf.png
        qml/assets/gruener_fisch_logo.png
        qml/assets/linus_uebersicht.png
)

qt_add_resources(stroemling_app "database_seeds"
    PREFIX "/database"
    BASE "src/database"
    FILES
        src/database/schema.sql
        src/database/symbole.sql
)

qt_add_resources(stroemling_app "wiki_seed_res"
    PREFIX "/wiki_seed"
    BASE "src/wiki_seed"
    FILES
        src/wiki_seed/manifest.json
        src/wiki_seed/bedienhinweise/programmuebersicht.md
        src/wiki_seed/bedienhinweise/schaltplan_erste_schritte.md
        src/wiki_seed/bedienhinweise/symbole_platzieren.md
        src/wiki_seed/bedienhinweise/kabelrechner.md
        src/wiki_seed/bedienhinweise/ibn_inbetriebnahme.md
        src/wiki_seed/bedienhinweise/versionierung_git.md
        src/wiki_seed/bedienhinweise/lizenz_open_source.md
        src/wiki_seed/bedienhinweise/ueber_dieses_projekt.md
        src/wiki_seed/bedienhinweise/seitenbaum_sortierung.md
        src/wiki_seed/bedienhinweise/fehlersuchmodus.md
        src/wiki_seed/altbestand_west/klassische_nullung_grundlagen.md
        src/wiki_seed/altbestand_west/klassische_nullung_verbotsdaten.md
        src/wiki_seed/altbestand_ost/klassische_nullung_kuriosum.md
        src/wiki_seed/altbestand_ost/aluminium_leitungen_tgl.md
        src/wiki_seed/altbestand_ost/ddr_farbnormen_tgl.md
        src/wiki_seed/aderendhuelsen/querschnitt_farb_groesstabelle.md
        src/wiki_seed/stroemlinge/ueberblick.md
        src/wiki_seed/stroemlinge/schwaerzchen.md
        src/wiki_seed/stroemlinge/impulsino.md
        src/wiki_seed/stroemlinge/isolus.md
        src/wiki_seed/stroemlinge/brauno.md
        src/wiki_seed/stroemlinge/blaubertha.md
        src/wiki_seed/stroemlinge/grausel.md
        src/wiki_seed/stroemlinge/erdikus.md
        src/wiki_seed/stroemlinge/datinchen.md
        src/wiki_seed/stroemlinge/pokestroem.md
        src/wiki_seed/stroemlinge/linus.md
        src/wiki_seed/stroemlinge/krizzo.md
        src/wiki_seed/stroemlinge/errinka.md
        src/wiki_seed/stroemlinge/fusia.md
        src/wiki_seed/stroemlinge/stoppius.md
        src/wiki_seed/tester/testanleitung.md
)

target_link_libraries(stroemling_app PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Sql
    Qt6::PrintSupport
)

target_include_directories(stroemling_app PRIVATE src)

string(TIMESTAMP BUILD_DATE "%Y-%m-%d")
target_compile_definitions(stroemling_app PRIVATE BUILD_DATE="${BUILD_DATE}" APP_VERSION="0.5")

# ============================================================
# Tests
# ============================================================
enable_testing()

qt_add_executable(stroemling_test
    tests/tst_migrationen.cpp
    src/logging.cpp
    src/logging.h
    src/database/Database.cpp
    src/database/Database_Schema.cpp
    src/database/Database_Canvas.cpp
    src/database/Database_Listen.cpp
    src/database/Database_Normblatt.cpp
    src/database/Database_Kabel.cpp
    src/database/Database_Klemmen.cpp
    src/database/Database_Makro.cpp
    src/database/Database_IBN.cpp
    src/database/Database_Wiki.cpp
    src/database/Database_SPS.cpp
    src/database/Database_PDF.cpp
    src/database/Database_Archiv.cpp
    src/database/Database_DRC.cpp
    src/database/Database_Git.cpp
    src/database/Database_Geraetekasten.cpp
    src/database/Database.h
)

qt_add_resources(stroemling_test "database_seeds_test"
    PREFIX "/database"
    BASE "src/database"
    FILES
        src/database/schema.sql
        src/database/symbole.sql
)

qt_add_resources(stroemling_test "wiki_seed_res_test"
    PREFIX "/wiki_seed"
    BASE "src/wiki_seed"
    FILES
        src/wiki_seed/manifest.json
        src/wiki_seed/bedienhinweise/programmuebersicht.md
        src/wiki_seed/bedienhinweise/schaltplan_erste_schritte.md
        src/wiki_seed/bedienhinweise/symbole_platzieren.md
        src/wiki_seed/bedienhinweise/kabelrechner.md
        src/wiki_seed/bedienhinweise/ibn_inbetriebnahme.md
        src/wiki_seed/bedienhinweise/versionierung_git.md
        src/wiki_seed/bedienhinweise/lizenz_open_source.md
        src/wiki_seed/bedienhinweise/ueber_dieses_projekt.md
        src/wiki_seed/bedienhinweise/seitenbaum_sortierung.md
        src/wiki_seed/bedienhinweise/fehlersuchmodus.md
        src/wiki_seed/altbestand_west/klassische_nullung_grundlagen.md
        src/wiki_seed/altbestand_west/klassische_nullung_verbotsdaten.md
        src/wiki_seed/altbestand_ost/klassische_nullung_kuriosum.md
        src/wiki_seed/altbestand_ost/aluminium_leitungen_tgl.md
        src/wiki_seed/altbestand_ost/ddr_farbnormen_tgl.md
        src/wiki_seed/aderendhuelsen/querschnitt_farb_groesstabelle.md
        src/wiki_seed/stroemlinge/ueberblick.md
        src/wiki_seed/stroemlinge/schwaerzchen.md
        src/wiki_seed/stroemlinge/impulsino.md
        src/wiki_seed/stroemlinge/isolus.md
        src/wiki_seed/stroemlinge/brauno.md
        src/wiki_seed/stroemlinge/blaubertha.md
        src/wiki_seed/stroemlinge/grausel.md
        src/wiki_seed/stroemlinge/erdikus.md
        src/wiki_seed/stroemlinge/datinchen.md
        src/wiki_seed/stroemlinge/pokestroem.md
        src/wiki_seed/stroemlinge/linus.md
        src/wiki_seed/stroemlinge/krizzo.md
        src/wiki_seed/stroemlinge/errinka.md
        src/wiki_seed/stroemlinge/fusia.md
        src/wiki_seed/stroemlinge/stoppius.md
        src/wiki_seed/tester/testanleitung.md
)

target_include_directories(stroemling_test PRIVATE src)

target_link_libraries(stroemling_test PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::Sql
    Qt6::PrintSupport
)

add_test(NAME TstMigrationen COMMAND stroemling_test)
set_tests_properties(TstMigrationen PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# ============================================================
qt_add_translations(stroemling_app
    TS_FILES
        i18n/stroemling_en.ts
    SOURCES
        qml/Main.qml
        qml/ProjectTree.qml
        qml/SeitenBaum.qml
        qml/SeitenBaumNormblattPanel.qml
        qml/SeitenBaumBauteilePanel.qml
        qml/BauteilAnsicht.qml
        qml/SchaltplanCanvas.qml
        qml/PokestroemPlaceholder.qml
        qml/ShortcutUebersicht.qml
        qml/EigenschaftenPanel.qml
        qml/SymbolPalette.qml
        qml/ListenAnsicht.qml
        qml/components/SidebarButton.qml
)
