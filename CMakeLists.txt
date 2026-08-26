cmake_minimum_required(VERSION 3.16)
project(stroemling VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Der Quellcode enthält direkt eingebettete UTF-8-Zeichen (Umlaute,
# Sonderzeichen wie "–") in String-Literalen - MSVC interpretiert
# Quelldateien ohne /utf-8 nicht zuverlässig als UTF-8 (im Gegensatz zu
# GCC/Clang, die UTF-8-Quellen standardmäßig korrekt lesen).
if (MSVC)
    add_compile_options(/utf-8)
endif()

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
    src/database/Database_Zwischenablage.cpp
    src/database/Database_IBN.cpp
    src/database/Database_Wiki.cpp
    src/database/Database_SPS.cpp
    src/database/Database_PDF.cpp
    src/database/Database_DRC.cpp
    src/database/Database_Git.cpp
    src/database/Database_Geraetekasten.cpp
    src/database/Database_Steckverbinder.cpp
    src/database/Database_Kontakt.cpp
    src/database/Database_Betriebsmittel.cpp
    src/database/Database_Archiv.cpp
    src/database/Database_Bibliothek.cpp
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
    src/utils/AktivitaetsMonitor.h
    src/utils/AktivitaetsMonitor.cpp
    src/canvas/ElementeModel.cpp
    src/canvas/ElementeModel.h
    src/achievements/AchievementManager.cpp
    src/achievements/AchievementManager.h
    src/MeldungManager.cpp
    src/MeldungManager.h
    src/rosi/RosiManager.cpp
    src/rosi/RosiManager.h
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
        qml/CrossProjektEinfuegenDialog.qml
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
        qml/components/MeldungToast.qml

        qml/AchievementsPanel.qml
        qml/MeldungenPanel.qml

        qml/ep/EpGeraetekastenSection.qml
        qml/ep/EpStrukturkastenSection.qml
        qml/ep/EpMakrokastenSection.qml
        qml/ep/EpSchirmSection.qml
        qml/ep/EpKlemmenAnschlussSection.qml
        qml/ep/EpKabelDefinitionSection.qml
        qml/ep/EpKabelStammdatenBlock.qml
        qml/ep/EpKabelLinienBlock.qml
        qml/ep/EpKabelAdernBlock.qml
        qml/ep/EpBetriebsmittelSection.qml
        qml/ep/EpBauteilZuordnungSection.qml
        qml/ep/EpIbnStatusSection.qml
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
        qml/ba/BaSteckverbinderBauteilPickerDialog.qml
        qml/ba/BaKontaktPlatzierenDialog.qml
        qml/ba/BaPartnerPickerDialog.qml

        qml/sb/SbSeiteLoeschenDialog.qml
        qml/sb/SbAnlageOrtLoeschenDialog.qml
        qml/sb/SbAnlageDialog.qml
        qml/sb/SbOrtDialog.qml
        qml/sb/SbSeiteDialog.qml
        qml/sb/SbAnlageBearbeitenDialog.qml
        qml/sb/SbOrtBearbeitenDialog.qml
        qml/sb/SbSeiteBearbeitenDialog.qml
        qml/sb/SbSeiteVerschiebenDialog.qml
        qml/sb/SbOrtVerschiebenDialog.qml
        qml/sb/SbBauteileKlemmenleisten.qml
        qml/sb/SbBauteileGeraete.qml
        qml/sb/SbBauteileKabel.qml
        qml/sb/SbBauteileGeraetekaesten.qml
        qml/sb/SbBauteileBibliothek.qml

        qml/la/LaCsvLeiste.qml
        qml/la/LaSpaltenHeader.qml
        qml/la/LaTabStueckliste.qml
        qml/la/LaTabQuerverweise.qml
        qml/la/LaTabAderliste.qml
        qml/la/LaTabKlemmenplan.qml
        qml/la/LaTabKlemmlistenauszug.qml
        qml/la/LaTabKabelliste.qml
        qml/la/LaTabSteckverbinder.qml
        qml/la/LaTabBelegungsplan.qml
        qml/la/LaTabBestellliste.qml

        qml/canvas/WerkzeugButton.qml
        qml/canvas/CanvasHeaderBar.qml
        qml/canvas/CanvasFooterBar.qml
        qml/canvas/CanvasWerkzeugLeiste.qml
        qml/canvas/CanvasInteraktionArea.qml
        qml/canvas/CanvasNavigationHandler.qml
        qml/canvas/CanvasNetzberechnung.qml
        qml/canvas/CanvasGeometrie.qml
        qml/canvas/CanvasCacheHandler.qml
        qml/canvas/CanvasRenderHandler.qml
        qml/canvas/CanvasDialogLayer.qml
        qml/canvas/CanvasAktionenHandler.qml
        qml/canvas/CanvasFehlersuchHandler.qml
        qml/canvas/CanvasVerdrahtungsHandler.qml
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
        qml/kabel/AderKreuzungPicker.qml

        qml/steckverbinder/SteckverbinderEditor.qml
        qml/konfkabel/KonfkabelEditor.qml
        qml/kontakt/KontaktEditor.qml
        qml/MakrobenennDialog.qml
        qml/MakroPalette.qml
        qml/DrcPanel.qml
        qml/PdfExportDialog.qml
        qml/CanvasPanel.qml
        qml/KommandoPalette.qml
        qml/NormblattEditorDialog.qml
        qml/nb/NormblattEditorCanvas.qml
        qml/nb/NormblattFeldPalette.qml
        qml/nb/NormblattFeldProperties.qml
        qml/nb/NormblattAusrichtenPanel.qml
        qml/wiki/WikiAnsicht.qml
        qml/wiki/WikiFormatierungsToolbar.qml
        qml/wiki/WikiBildGalerie.qml
        qml/wiki/WikiBundleDialog.qml
        qml/wiki/WikiBildEinfuegenPopup.qml
        qml/wiki/WikiImportModePopup.qml
        qml/wiki/WikiVollbildPopup.qml
        qml/einstellungen/EinstellungenAnsicht.qml
        qml/einstellungen/EinDatenbankpfadeBlock.qml
        qml/einstellungen/EinDatensicherungBlock.qml
        qml/einstellungen/EinFunModusBlock.qml
        qml/einstellungen/EinRosiBlock.qml
        qml/einstellungen/EinMitwirkendeBlock.qml
        qml/einstellungen/EinEntstehungBlock.qml
        qml/einstellungen/EinHilfeKontaktBlock.qml
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

        qml/rosi/RosiSprechblase.qml
        qml/rosi/RosiPostkarte.qml
        qml/logos/LogoHeader.qml
        qml/SymbolKlassen.js
        qml/Normwerte.js
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
        qml/assets/isolus_logo_collage.png
        qml/assets/linus_uebersicht.png
        qml/assets/stroemling_logo.png
        qml/assets/stroemling_icon.png
        qml/assets/rosi_roehrenaal.png
        qml/assets/rosi_rohroeffnung.png
        qml/assets/rosi_roehrenaal_uebersicht.png
        qml/assets/kabeljau_uebersicht.png
        qml/assets/krizzo_uebersicht.png
        qml/assets/hilfe_kontakt.png
        qml/assets/aals_ob.png
)

qt_add_resources(stroemling_app "database_seeds"
    PREFIX "/database"
    BASE "src/database"
    FILES
        src/database/schema.sql
        src/database/symbole.sql
        src/database/bauteile_nutzer.sql
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
        src/wiki_seed/bedienhinweise/sprungfunktion.md
        src/wiki_seed/bedienhinweise/steckverbinder_konfkabel.md
        src/wiki_seed/bedienhinweise/geraetekasten_workflow.md
        src/wiki_seed/bedienhinweise/strukturkennzeichen.md
        src/wiki_seed/bedienhinweise/achievements.md
        src/wiki_seed/bedienhinweise/meldungen_toast.md
        src/wiki_seed/bedienhinweise/minimap.md
        src/wiki_seed/bedienhinweise/makro_palette.md
        src/wiki_seed/bedienhinweise/sps_integration.md
        src/wiki_seed/bedienhinweise/pdf_export.md
        src/wiki_seed/bedienhinweise/bauteilbibliothek.md
        src/wiki_seed/bedienhinweise/klemmen_editor.md
        src/wiki_seed/bedienhinweise/klemmenanschluss_platzierung.md
        src/wiki_seed/bedienhinweise/kabel_editor.md
        src/wiki_seed/bedienhinweise/normblatt_editor.md
        src/wiki_seed/bedienhinweise/einstellungen.md
        src/wiki_seed/bedienhinweise/listenansicht.md
        src/wiki_seed/nachschlagetabellen/lss_ausloesecharakteristik.md
        src/wiki_seed/nachschlagetabellen/strombelastbarkeit_vde0298.md
        src/wiki_seed/nachschlagetabellen/rcd_typen.md
        src/wiki_seed/nachschlagetabellen/ip_schutzarten.md
        src/wiki_seed/nachschlagetabellen/ik_schutzklassen.md
        src/wiki_seed/nachschlagetabellen/anzugsdrehmomente_klemmen.md
        src/wiki_seed/nachschlagetabellen/awg_mm2_umrechnung.md
        src/wiki_seed/nachschlagetabellen/wallbox_kabeldimensionierung.md
        src/wiki_seed/altbestand_west/klassische_nullung_grundlagen.md
        src/wiki_seed/altbestand_west/klassische_nullung_verbotsdaten.md
        src/wiki_seed/altbestand_west/nullleiter_unterbrechung_tt.md
        src/wiki_seed/altbestand_west/aluminium_klemmen_bimetall.md
        src/wiki_seed/altbestand_ost/klassische_nullung_kuriosum.md
        src/wiki_seed/altbestand_ost/aluminium_leitungen_tgl.md
        src/wiki_seed/altbestand_ost/ddr_farbnormen_tgl.md
        src/wiki_seed/altbestand_ost/ddr_125v_anlagen.md
        src/wiki_seed/normen/bmk_din_81346.md
        src/wiki_seed/normen/klemmenbezeichnungen_din60445.md
        src/wiki_seed/normen/seitenkennzeichnung_din6771.md
        src/wiki_seed/schutz/fuenf_sicherheitsregeln.md
        src/wiki_seed/schutz/ueberspannungsschutz_spd.md
        src/wiki_seed/schutz/tn_tt_it_netze.md
        src/wiki_seed/schutz/schirmung.md
        src/wiki_seed/schutz/pe_fe_funktionserde.md
        src/wiki_seed/kabel_aderfarben/aderfarben_normen_geschichte.md
        src/wiki_seed/kabel_aderfarben/din47100_steuerleitungen.md
        src/wiki_seed/aderendhuelsen/querschnitt_farb_groesstabelle.md
        src/wiki_seed/kabelverschraubungen/kabelverschraubungen_masse.md
        src/wiki_seed/kabeltypen/standardkabel_hausinstallation.md
        src/wiki_seed/motorsteuerung/drehstrommotor.md
        src/wiki_seed/motorsteuerung/schuetz_thermorelay.md
        src/wiki_seed/motorsteuerung/stern_dreieck_anlasser.md
        src/wiki_seed/motorsteuerung/motorschutz_vergleich.md
        src/wiki_seed/motorsteuerung/sanftanlauf.md
        src/wiki_seed/motorsteuerung/frequenzumrichter.md
        src/wiki_seed/waermepumpen/funktionsprinzip_kaeltekreislauf.md
        src/wiki_seed/waermepumpen/kaeltemittel_und_f_gase_verordnung.md
        src/wiki_seed/waermepumpen/kennzahlen_cop_jaz_bivalenzpunkt.md
        src/wiki_seed/waermepumpen/bauarten_im_ueberblick.md
        src/wiki_seed/waermepumpen/trinkwarmwasser_und_hybrid.md
        src/wiki_seed/waermepumpen/elektrischer_anschluss.md
        src/wiki_seed/waermepumpen/paragraf14a_enwg_steuerbare_verbrauchseinrichtung.md
        src/wiki_seed/waermepumpen/trennvorrichtung_notaus_potentialausgleich.md
        src/wiki_seed/waermepumpen/steuer_und_busanbindung_sg_ready.md
        src/wiki_seed/waermepumpen/notheizstab_auslegung.md
        src/wiki_seed/waermepumpen/aufstellung_schallschutz.md
        src/wiki_seed/waermepumpen/hydraulik_grundlagen.md
        src/wiki_seed/waermepumpen/normen_rechtlicher_rahmen.md
        src/wiki_seed/waermepumpen/kaeltemittel_vergleichstabelle.md
        src/wiki_seed/waermepumpen/waermepumpentypen_vergleich.md
        src/wiki_seed/waermepumpen/hersteller_deutschland_marktuebersicht.md
        src/wiki_seed/waermepumpen/waermepumpen_weltweit_vergleich.md
        src/wiki_seed/waermepumpen/einstellen_betriebsparameter.md
        src/wiki_seed/waermepumpen/bestandsgebaeude_heizkoerper.md
        src/wiki_seed/waermepumpen/kuriositaeten_planungsfehler.md
        src/wiki_seed/waermepumpen/wirtschaftlichkeit_gas_oel_vergleich.md
        src/wiki_seed/kfz_elektrik/von_6v_auf_12v.md
        src/wiki_seed/kfz_elektrik/plus_minus_masse.md
        src/wiki_seed/kfz_elektrik/dynamo_zur_lichtmaschine.md
        src/wiki_seed/kfz_elektrik/zuendanlagen_im_wandel.md
        src/wiki_seed/kfz_elektrik/anlasser_technik.md
        src/wiki_seed/kfz_elektrik/sicherungstechnik_im_wandel.md
        src/wiki_seed/kfz_elektrik/steckverbinder_leitungsfarben_kfz.md
        src/wiki_seed/kfz_elektrik/batterietechnik_im_wandel.md
        src/wiki_seed/kfz_elektrik/bordnetz_architektur_can_lin.md
        src/wiki_seed/kfz_elektrik/diagnose_im_wandel_obd.md
        src/wiki_seed/kfz_elektrik/beleuchtung_im_wandel.md
        src/wiki_seed/kfz_elektrik/motorrad_bordnetz.md
        src/wiki_seed/kfz_elektrik/elektro_hybrid_hochvolt_ausblick.md
        src/wiki_seed/kfz_elektrik/nachschlagetabelle_sicherungen_klemmen.md
        src/wiki_seed/kfz_elektrik/kuriositaeten_oldtimer_fehlerbilder.md
        src/wiki_seed/wohnmobil_elektrik/bordnetz_grundlagen_zwei_batterien.md
        src/wiki_seed/wohnmobil_elektrik/trennrelais_und_ladebooster.md
        src/wiki_seed/wohnmobil_elektrik/batterietechnik_camper.md
        src/wiki_seed/wohnmobil_elektrik/solaranlage_aufbau_laderegler.md
        src/wiki_seed/wohnmobil_elektrik/230v_landstrom_wechselrichter.md
        src/wiki_seed/wohnmobil_elektrik/sicherungstechnik_wohnmobil.md
        src/wiki_seed/wohnmobil_elektrik/spannungsabfall_lange_leitungswege.md
        src/wiki_seed/wohnmobil_elektrik/gasanlage_elektrik_schnittstellen.md
        src/wiki_seed/wohnmobil_elektrik/vorschriften_tuev_ausbau.md
        src/wiki_seed/wohnmobil_elektrik/kuriositaeten_haeufige_fehler_selbstausbau.md
        src/wiki_seed/boot_elektrik/bordnetz_grundlagen_boot.md
        src/wiki_seed/boot_elektrik/galvanische_korrosion_isolationstransformator.md
        src/wiki_seed/boot_elektrik/batterietechnik_trennung_boot.md
        src/wiki_seed/boot_elektrik/marine_leitungen_steckverbinder.md
        src/wiki_seed/boot_elektrik/sicherungen_schutzschalter_boot.md
        src/wiki_seed/boot_elektrik/masseschleifen_navigationselektronik.md
        src/wiki_seed/boot_elektrik/kuriositaeten_korrosion_verkabelung.md
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
        src/wiki_seed/stroemlinge/rosi.md
        src/wiki_seed/stroemlinge/kabeljau.md
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
target_compile_definitions(stroemling_app PRIVATE BUILD_DATE="${BUILD_DATE}" APP_VERSION="0.666")

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
    src/database/Database_Zwischenablage.cpp
    src/database/Database_IBN.cpp
    src/database/Database_Wiki.cpp
    src/database/Database_SPS.cpp
    src/database/Database_PDF.cpp
    src/database/Database_Archiv.cpp
    src/database/Database_Bibliothek.cpp
    src/database/Database_DRC.cpp
    src/database/Database_Git.cpp
    src/database/Database_Geraetekasten.cpp
    src/database/Database_Steckverbinder.cpp
    src/database/Database_Kontakt.cpp
    src/database/Database_Betriebsmittel.cpp
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
        src/wiki_seed/bedienhinweise/sprungfunktion.md
        src/wiki_seed/bedienhinweise/steckverbinder_konfkabel.md
        src/wiki_seed/bedienhinweise/geraetekasten_workflow.md
        src/wiki_seed/bedienhinweise/strukturkennzeichen.md
        src/wiki_seed/bedienhinweise/achievements.md
        src/wiki_seed/bedienhinweise/meldungen_toast.md
        src/wiki_seed/bedienhinweise/minimap.md
        src/wiki_seed/bedienhinweise/makro_palette.md
        src/wiki_seed/bedienhinweise/sps_integration.md
        src/wiki_seed/bedienhinweise/pdf_export.md
        src/wiki_seed/bedienhinweise/bauteilbibliothek.md
        src/wiki_seed/bedienhinweise/klemmen_editor.md
        src/wiki_seed/bedienhinweise/klemmenanschluss_platzierung.md
        src/wiki_seed/bedienhinweise/kabel_editor.md
        src/wiki_seed/bedienhinweise/normblatt_editor.md
        src/wiki_seed/bedienhinweise/einstellungen.md
        src/wiki_seed/bedienhinweise/listenansicht.md
        src/wiki_seed/nachschlagetabellen/lss_ausloesecharakteristik.md
        src/wiki_seed/nachschlagetabellen/strombelastbarkeit_vde0298.md
        src/wiki_seed/nachschlagetabellen/rcd_typen.md
        src/wiki_seed/nachschlagetabellen/ip_schutzarten.md
        src/wiki_seed/nachschlagetabellen/ik_schutzklassen.md
        src/wiki_seed/nachschlagetabellen/anzugsdrehmomente_klemmen.md
        src/wiki_seed/nachschlagetabellen/awg_mm2_umrechnung.md
        src/wiki_seed/nachschlagetabellen/wallbox_kabeldimensionierung.md
        src/wiki_seed/altbestand_west/klassische_nullung_grundlagen.md
        src/wiki_seed/altbestand_west/klassische_nullung_verbotsdaten.md
        src/wiki_seed/altbestand_west/nullleiter_unterbrechung_tt.md
        src/wiki_seed/altbestand_west/aluminium_klemmen_bimetall.md
        src/wiki_seed/altbestand_ost/klassische_nullung_kuriosum.md
        src/wiki_seed/altbestand_ost/aluminium_leitungen_tgl.md
        src/wiki_seed/altbestand_ost/ddr_farbnormen_tgl.md
        src/wiki_seed/altbestand_ost/ddr_125v_anlagen.md
        src/wiki_seed/normen/bmk_din_81346.md
        src/wiki_seed/normen/klemmenbezeichnungen_din60445.md
        src/wiki_seed/normen/seitenkennzeichnung_din6771.md
        src/wiki_seed/schutz/fuenf_sicherheitsregeln.md
        src/wiki_seed/schutz/ueberspannungsschutz_spd.md
        src/wiki_seed/schutz/tn_tt_it_netze.md
        src/wiki_seed/schutz/schirmung.md
        src/wiki_seed/schutz/pe_fe_funktionserde.md
        src/wiki_seed/kabel_aderfarben/aderfarben_normen_geschichte.md
        src/wiki_seed/kabel_aderfarben/din47100_steuerleitungen.md
        src/wiki_seed/aderendhuelsen/querschnitt_farb_groesstabelle.md
        src/wiki_seed/kabelverschraubungen/kabelverschraubungen_masse.md
        src/wiki_seed/kabeltypen/standardkabel_hausinstallation.md
        src/wiki_seed/motorsteuerung/drehstrommotor.md
        src/wiki_seed/motorsteuerung/schuetz_thermorelay.md
        src/wiki_seed/motorsteuerung/stern_dreieck_anlasser.md
        src/wiki_seed/motorsteuerung/motorschutz_vergleich.md
        src/wiki_seed/motorsteuerung/sanftanlauf.md
        src/wiki_seed/motorsteuerung/frequenzumrichter.md
        src/wiki_seed/waermepumpen/funktionsprinzip_kaeltekreislauf.md
        src/wiki_seed/waermepumpen/kaeltemittel_und_f_gase_verordnung.md
        src/wiki_seed/waermepumpen/kennzahlen_cop_jaz_bivalenzpunkt.md
        src/wiki_seed/waermepumpen/bauarten_im_ueberblick.md
        src/wiki_seed/waermepumpen/trinkwarmwasser_und_hybrid.md
        src/wiki_seed/waermepumpen/elektrischer_anschluss.md
        src/wiki_seed/waermepumpen/paragraf14a_enwg_steuerbare_verbrauchseinrichtung.md
        src/wiki_seed/waermepumpen/trennvorrichtung_notaus_potentialausgleich.md
        src/wiki_seed/waermepumpen/steuer_und_busanbindung_sg_ready.md
        src/wiki_seed/waermepumpen/notheizstab_auslegung.md
        src/wiki_seed/waermepumpen/aufstellung_schallschutz.md
        src/wiki_seed/waermepumpen/hydraulik_grundlagen.md
        src/wiki_seed/waermepumpen/normen_rechtlicher_rahmen.md
        src/wiki_seed/waermepumpen/kaeltemittel_vergleichstabelle.md
        src/wiki_seed/waermepumpen/waermepumpentypen_vergleich.md
        src/wiki_seed/waermepumpen/hersteller_deutschland_marktuebersicht.md
        src/wiki_seed/waermepumpen/waermepumpen_weltweit_vergleich.md
        src/wiki_seed/waermepumpen/einstellen_betriebsparameter.md
        src/wiki_seed/waermepumpen/bestandsgebaeude_heizkoerper.md
        src/wiki_seed/waermepumpen/kuriositaeten_planungsfehler.md
        src/wiki_seed/waermepumpen/wirtschaftlichkeit_gas_oel_vergleich.md
        src/wiki_seed/kfz_elektrik/von_6v_auf_12v.md
        src/wiki_seed/kfz_elektrik/plus_minus_masse.md
        src/wiki_seed/kfz_elektrik/dynamo_zur_lichtmaschine.md
        src/wiki_seed/kfz_elektrik/zuendanlagen_im_wandel.md
        src/wiki_seed/kfz_elektrik/anlasser_technik.md
        src/wiki_seed/kfz_elektrik/sicherungstechnik_im_wandel.md
        src/wiki_seed/kfz_elektrik/steckverbinder_leitungsfarben_kfz.md
        src/wiki_seed/kfz_elektrik/batterietechnik_im_wandel.md
        src/wiki_seed/kfz_elektrik/bordnetz_architektur_can_lin.md
        src/wiki_seed/kfz_elektrik/diagnose_im_wandel_obd.md
        src/wiki_seed/kfz_elektrik/beleuchtung_im_wandel.md
        src/wiki_seed/kfz_elektrik/motorrad_bordnetz.md
        src/wiki_seed/kfz_elektrik/elektro_hybrid_hochvolt_ausblick.md
        src/wiki_seed/kfz_elektrik/nachschlagetabelle_sicherungen_klemmen.md
        src/wiki_seed/kfz_elektrik/kuriositaeten_oldtimer_fehlerbilder.md
        src/wiki_seed/wohnmobil_elektrik/bordnetz_grundlagen_zwei_batterien.md
        src/wiki_seed/wohnmobil_elektrik/trennrelais_und_ladebooster.md
        src/wiki_seed/wohnmobil_elektrik/batterietechnik_camper.md
        src/wiki_seed/wohnmobil_elektrik/solaranlage_aufbau_laderegler.md
        src/wiki_seed/wohnmobil_elektrik/230v_landstrom_wechselrichter.md
        src/wiki_seed/wohnmobil_elektrik/sicherungstechnik_wohnmobil.md
        src/wiki_seed/wohnmobil_elektrik/spannungsabfall_lange_leitungswege.md
        src/wiki_seed/wohnmobil_elektrik/gasanlage_elektrik_schnittstellen.md
        src/wiki_seed/wohnmobil_elektrik/vorschriften_tuev_ausbau.md
        src/wiki_seed/wohnmobil_elektrik/kuriositaeten_haeufige_fehler_selbstausbau.md
        src/wiki_seed/boot_elektrik/bordnetz_grundlagen_boot.md
        src/wiki_seed/boot_elektrik/galvanische_korrosion_isolationstransformator.md
        src/wiki_seed/boot_elektrik/batterietechnik_trennung_boot.md
        src/wiki_seed/boot_elektrik/marine_leitungen_steckverbinder.md
        src/wiki_seed/boot_elektrik/sicherungen_schutzschalter_boot.md
        src/wiki_seed/boot_elektrik/masseschleifen_navigationselektronik.md
        src/wiki_seed/boot_elektrik/kuriositaeten_korrosion_verkabelung.md
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
        src/wiki_seed/stroemlinge/rosi.md
        src/wiki_seed/stroemlinge/kabeljau.md
        src/wiki_seed/tester/testanleitung.md
)

target_include_directories(stroemling_test PRIVATE src)

# Lokaler Ordner fuer reale Projekt-Fixtures (echte Kundendaten, siehe
# tests/fixtures/README.md) - nie committet, Test ueberspringt sich selbst
# wenn die Datei fehlt (z.B. bei anderen Mitwirkenden oder in CI).
target_compile_definitions(stroemling_test PRIVATE
    TEST_FIXTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures"
)

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
