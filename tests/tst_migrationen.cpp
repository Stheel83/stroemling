#include <QtTest>
#include <QGuiApplication>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QSet>
#include "database/Database.h"
#include "models/SymbolDefinitionModel.h"
#include "models/SeitenModel.h"
#include "tst_kernfunktionen.h"

// Testet das Migrations-System auf einer temporären SQLite-Datei.
// Ablauf: createProjekt (v40-Baseline) → closeProjekt → openProjekt
//         (wendet v41..vN an) → Schema-Integrität prüfen.

class TstMigrationen : public QObject
{
    Q_OBJECT

    QString   m_tmpPfad;
    Database *m_db = nullptr;

    // Eigenes Frisch-Projekt je Test (test_10/11 lassen die Default-Verbindung
    // nicht offen zurück).
    struct TmpProjekt {
        QString pfad; Database db;
        explicit TmpProjekt(const QString &tag) {
            pfad = QDir::tempPath() + "/stroemling_test_" + tag + "_"
                 + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".stroemling";
            db.createProjekt(pfad, "Tmp");
        }
        ~TmpProjekt() { db.closeProjekt(); QFile::remove(pfad); QFile::remove(pfad + "-wal"); QFile::remove(pfad + "-shm"); }
    };

private slots:
    void initTestCase()
    {
        m_tmpPfad = QDir::tempPath()
                  + "/stroemling_test_"
                  + QString::number(QDateTime::currentMSecsSinceEpoch())
                  + ".stroemling";

        m_db = new Database(this);
        QVERIFY2(m_db->createProjekt(m_tmpPfad, "Testprojekt"),
                 "createProjekt() schlug fehl – Schema-Baseline konnte nicht angelegt werden");
        m_db->closeProjekt();

        QVERIFY2(m_db->openProjekt(m_tmpPfad),
                 "openProjekt() nach createProjekt() schlug fehl – Migrationen fehlgeschlagen?");
    }

    void cleanupTestCase()
    {
        if (m_db) m_db->closeProjekt();
        QFile::remove(m_tmpPfad);
        // WAL-Hilfsdateien aufräumen
        QFile::remove(m_tmpPfad + "-wal");
        QFile::remove(m_tmpPfad + "-shm");
    }

    void test_01_isOpen()
    {
        QVERIFY2(m_db->isOpen(), "Datenbank nicht geöffnet nach Migration");
    }

    void test_02_schemaVersion()
    {
        QVariantMap info = m_db->datenbankInfos();
        int version = info.value("schemaVersion").toInt();
        QVERIFY2(version >= 48,
                 qPrintable(QString("Schema-Version zu niedrig: %1 (erwartet >= 48)").arg(version)));
    }

    void test_02b_defaultAnlageOrt()
    {
        // createProjekt() legt eine Default-Anlage + Default-Ort an, damit
        // "+Seite" ohne manuellen Anlage/Ort-Bootstrap nutzbar ist.
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("SELECT kuerzel, bezeichnung FROM anlage"));
        QVERIFY2(q.next(), "Keine Default-Anlage nach createProjekt() angelegt");
        QCOMPARE(q.value(0).toString(), QStringLiteral("AQ"));
        QCOMPARE(q.value(1).toString(), QStringLiteral("Pokeströms Aquarium"));

        QVERIFY(q.exec("SELECT kuerzel, bezeichnung FROM ort"));
        QVERIFY2(q.next(), "Kein Default-Ort nach createProjekt() angelegt");
        QCOMPARE(q.value(0).toString(), QStringLiteral("TR"));
        QCOMPARE(q.value(1).toString(), QStringLiteral("Technikraum"));
    }

    void test_02c_defaultCanvasHintergrundPapier()
    {
        // Neue Projekte sollen mit Canvas-Hintergrund "Papier" (#fdf8e8) starten,
        // nicht mit dem dunklen Theme-Hintergrund (#080f1c).
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("SELECT canvas_hintergrund FROM projekt"));
        QVERIFY2(q.next(), "Keine Projektzeile gefunden");
        QCOMPARE(q.value(0).toString(), QStringLiteral("#fdf8e8"));
    }

    void test_03_alleTabellen()
    {
        // bauteil/bauteil_kategorie seit ARCH-01 in der separaten bibliothek.db,
        // nicht mehr Teil des Projekt-Hauptschemas – hier bewusst nicht geprüft.
        static const QStringList erwartet = {
            "schema_migration",
            "projekt", "seite",
            "grafik_element", "verbindung", "verbindung_segment",
            "klemme", "klemmenleiste",
            "symbol_definition", "symbol_pin",
            "kabel", "kabel_ader",
            "sps_rack", "sps_baugruppe", "sps_kanal",
        };

        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("SELECT name FROM sqlite_master WHERE type='table'"));
        QStringList vorhandene;
        while (q.next())
            vorhandene << q.value(0).toString();

        for (const QString &tabelle : erwartet) {
            QVERIFY2(vorhandene.contains(tabelle),
                     qPrintable("Tabelle fehlt: " + tabelle));
        }
    }

    void test_04_spaltenV48()
    {
        // Migration v48 fügt revision_status + revision_kennung zu seite hinzu
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("PRAGMA table_info(seite)"));
        QStringList spalten;
        while (q.next())
            spalten << q.value(1).toString();

        QVERIFY2(spalten.contains("revision_status"),
                 "Spalte seite.revision_status fehlt (Migration v48)");
        QVERIFY2(spalten.contains("revision_kennung"),
                 "Spalte seite.revision_kennung fehlt (Migration v48)");
    }

    void test_05_symbolKatalog()
    {
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_definition WHERE ist_builtin = 1"));
        QVERIFY(q.next());
        int anzahl = q.value(0).toInt();
        QVERIFY2(anzahl > 0,
                 qPrintable(QString("Keine Built-in-Symbole im Katalog (%1 gefunden)").arg(anzahl)));
    }

    void test_06_schemaHistorie()
    {
        // Alle Migrations-Versionen müssen lückenlos in schema_migration eingetragen sein
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("SELECT version FROM schema_migration ORDER BY version"));
        QList<int> versionen;
        while (q.next())
            versionen << q.value(0).toInt();

        QVERIFY2(!versionen.isEmpty(), "schema_migration ist leer");

        for (int i = 1; i < versionen.size(); ++i) {
            int erwartet = versionen[i - 1] + 1;
            QVERIFY2(versionen[i] == erwartet,
                     qPrintable(QString("Lücke in schema_migration: nach v%1 kommt v%2 (erwartet v%3)")
                                .arg(versionen[i - 1]).arg(versionen[i]).arg(erwartet)));
        }

        int maxVersion = versionen.last();
        QVERIFY2(maxVersion >= 48,
                 qPrintable(QString("Maximale Schema-Version zu niedrig: %1").arg(maxVersion)));
    }

    void test_07_spalteFarbe2()
    {
        // Migration v94 fügt kabel_ader.farbe2 für Bifarb-Adern hinzu
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("PRAGMA table_info(kabel_ader)"));
        QStringList spalten;
        while (q.next())
            spalten << q.value(1).toString();

        QVERIFY2(spalten.contains("farbe2"),
                 "Spalte kabel_ader.farbe2 fehlt (Migration v94)");
    }

    void test_08_symbolKatalogDualitaet()
    {
        // SYMBOL-DUALITAET-01: symbol_definition (Rendering/Pins/DRC/IBN/PDF)
        // und die separate Legacy-Tabelle `symbol` (Palette-Listing, gefüllt
        // von seedSymbolKatalog(), gelesen von SymbolPalette.qml über
        // db.symboleNachNorm()) müssen für jedes Built-in-Symbol synchron
        // gepflegt werden. Beide Fehlerrichtungen sind schon real passiert:
        // Migration 90 (motor_dc fehlte in `symbol` – Symbol unsichtbar in
        // der Palette trotz korrektem Rendering) und Migration 121
        // (rollladenschalter u.a. aus symbol_definition gelöscht, aber
        // Karteileiche in `symbol` vergessen – Platzieren schlug fehl).
        //
        // Ausnahme: die "Verbindungshilfen" werden bewusst NICHT in `symbol`
        // geseedet, sondern direkt in SymbolPalette.qml
        // (symboleInKategorie("verbindungen")) hartcodiert. Diese Liste hier
        // muss mit der dortigen QML-Liste synchron gehalten werden.
        // klemme_anschluss ist ebenfalls ausgenommen: wird nie über die
        // normale Palette gesucht, sondern von Main.qml direkt per
        // canvas.paletteSymbolId="klemme_anschluss" gesetzt (Klemmenreihen-
        // Editor-Workflow) - siehe auch SK.VERB_SYMS in SymbolKlassen.js.
        static const QSet<QString> verbindungshilfen = {
            "winkel", "treffpunkt", "treffpunkt_l", "geraeteanschluss",
            "potenzial", "unterbrechung", "querverweis", "aderdefinition",
            "isoliert_gelegte_ader", "klemme_anschluss"
        };

        QSqlQuery q(QSqlDatabase::database());

        QVERIFY(q.exec("SELECT id FROM symbol_definition WHERE ist_builtin = 1"));
        QSet<QString> definitionen;
        while (q.next()) definitionen.insert(q.value(0).toString());

        QVERIFY(q.exec("SELECT code FROM symbol"));
        QSet<QString> katalog;
        while (q.next()) katalog.insert(q.value(0).toString());

        // Jedes Built-in-Symbol (außer Verbindungshilfen) braucht einen
        // Palette-Eintrag, sonst ist es unsichtbar (Migration-90-Fehlerklasse).
        QSet<QString> fehltInKatalog = definitionen - verbindungshilfen - katalog;
        QStringList fehltListe;
        for (const QString &s : fehltInKatalog) fehltListe << s;
        QVERIFY2(fehltInKatalog.isEmpty(),
                 qPrintable("Built-in-Symbole ohne Eintrag in `symbol` (Palette zeigt sie nicht an): "
                            + fehltListe.join(", ")));

        // Jeder Palette-Eintrag braucht eine Definition, sonst schlägt das
        // Platzieren fehl (Migration-121-Fehlerklasse, umgekehrte Richtung).
        QSet<QString> verwaistImKatalog = katalog - definitionen;
        QStringList verwaistListe;
        for (const QString &s : verwaistImKatalog) verwaistListe << s;
        QVERIFY2(verwaistImKatalog.isEmpty(),
                 qPrintable("Karteileichen in `symbol` ohne symbol_definition (Platzieren schlägt fehl): "
                            + verwaistListe.join(", ")));
    }

    void test_09_symbolPinPrimitivDuplikate()
    {
        // SCHEMA-VERSION-BUMP-TEST-01: INSERT OR IGNORE auf symbol_pin/
        // symbol_primitiv (autoincrement-PK, keine natuerliche Eindeutigkeit)
        // hat bereits dreimal (v97, v119->123, v127/SEED-DUPLIKAT-01) Zeilen
        // lautlos verdoppelt, wenn eine Migration ein Symbol trifft, das im
        // Zielprojekt schon lokal existierte (INSERT OR IGNORE greift dort
        // nicht, DELETE+INSERT-Migrationen fuer bereits vorhandene IDs legen
        // dann Duplikate an). Prueft direkt auf die fehlende natuerliche
        // Eindeutigkeit statt gegen symbole.sql zu parsen.
        QSqlQuery q(QSqlDatabase::database());

        QVERIFY(q.exec("SELECT symbol_id, reihenfolge, COUNT(*) AS anzahl "
                        "FROM symbol_primitiv GROUP BY symbol_id, reihenfolge HAVING COUNT(*) > 1"));
        QStringList primitivDuplikate;
        while (q.next())
            primitivDuplikate << QString("%1 (reihenfolge=%2, %3x)")
                                      .arg(q.value(0).toString())
                                      .arg(q.value(1).toInt())
                                      .arg(q.value(2).toInt());
        QVERIFY2(primitivDuplikate.isEmpty(),
                 qPrintable("Duplikate in symbol_primitiv (symbol_id, reihenfolge): "
                            + primitivDuplikate.join(", ")));

        QVERIFY(q.exec("SELECT symbol_id, name, COUNT(*) AS anzahl "
                        "FROM symbol_pin GROUP BY symbol_id, name HAVING COUNT(*) > 1"));
        QStringList pinDuplikate;
        while (q.next())
            pinDuplikate << QString("%1 (name=%2, %3x)")
                                .arg(q.value(0).toString())
                                .arg(q.value(1).toString())
                                .arg(q.value(2).toInt());
        QVERIFY2(pinDuplikate.isEmpty(),
                 qPrintable("Duplikate in symbol_pin (symbol_id, name): "
                            + pinDuplikate.join(", ")));
    }

    void test_10_downgradeSchutz()
    {
        // Schutz gegen das Oeffnen einer Projektdatei, die mit einer neueren
        // Strömling-Version gespeichert wurde als diese Binary kennt: Migrationen
        // sind additiv (ADD COLUMN, CREATE TABLE), stillschweigendes Weiterarbeiten
        // mit unbekanntem Schema kann Daten inkonsistent machen. checkAndApplySchema()
        // muss das erkennen und das Oeffnen verweigern statt einfach durchzulaufen.
        // Muss der letzte Test sein - manipuliert die geteilte Test-Datenbank
        // dauerhaft (cleanupTestCase loescht die Datei danach ohnehin).
        {
            QSqlQuery q(QSqlDatabase::database());
            QVERIFY(q.exec(
                "INSERT INTO schema_migration (version, beschreibung) "
                "VALUES (999999, 'Test: simulierte zukuenftige Version')"));
        }

        m_db->closeProjekt();
        QVERIFY2(!m_db->openProjekt(m_tmpPfad),
                 "openProjekt() haette wegen zu hoher Schema-Version fehlschlagen muessen");
        QVERIFY2(!m_db->isOpen(),
                 "Datenbank sollte nach verweigertem Downgrade-Oeffnen geschlossen sein");
    }

    void test_11_realeProjektMigration()
    {
        // Testet die volle Migrationskette gegen eine echte, alte Projektdatei
        // statt nur den synthetischen createProjekt()-Zyklus (Baseline-Pfad) -
        // deckt reale Datenkonstellationen ab, die eine leere Baseline nicht hat.
        //
        // Die Fixture ist bewusst NICHT Teil des Repos (echte Kundendaten,
        // siehe .gitignore) - lokal ablegen unter:
        //   tests/fixtures/reales_projekt_v85.db
        // z.B. eine Kopie aus einem echten Pre-Migrations-Backup
        // (~/Stroemling_Projekte/<Projekt>/backups/stroemling_v*.db, per
        // VACUUM INTO erzeugt, daher ein sauberes Einzeldatei-Snapshot ohne
        // WAL-Anhang). Fehlt die Datei (andere Mitwirkende, CI), ueberspringt
        // sich der Test selbst statt fehlzuschlagen.
        const QString fixture = QStringLiteral(TEST_FIXTURES_DIR "/reales_projekt_v85.db");
        if (!QFile::exists(fixture))
            QSKIP("Keine reale Projekt-Fixture vorhanden (tests/fixtures/reales_projekt_v85.db) - "
                  "siehe Kommentar in diesem Test, lokal aus einem echten Projekt-Backup ablegen.");

        const QString kopie = QDir::tempPath() + "/stroemling_test_real_"
                             + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".db";
        QVERIFY2(QFile::copy(fixture, kopie),
                 "Fixture konnte nicht ins Temp-Verzeichnis kopiert werden");

        QVERIFY2(m_db->openProjekt(kopie),
                 "openProjekt() auf realer Alt-Fixture (v85) schlug fehl - Migrationskette gebrochen?");
        QVERIFY(m_db->isOpen());

        QVariantMap info = m_db->datenbankInfos();
        int version = info.value("schemaVersion").toInt();
        QVERIFY2(version >= 129,
                 qPrintable(QString("Reale Fixture nach Migration auf zu niedriger Version: %1")
                            .arg(version)));

        // Bonus-Absicherung: dieselbe Duplikat-Klasse wie test_09, aber gegen
        // echte historisch gewachsene Daten statt einer frischen Baseline.
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("SELECT symbol_id, reihenfolge, COUNT(*) FROM symbol_primitiv "
                        "GROUP BY symbol_id, reihenfolge HAVING COUNT(*) > 1"));
        QVERIFY2(!q.next(), "Duplikate in symbol_primitiv nach Migration der realen Fixture");

        m_db->closeProjekt();
        QFile::remove(kopie);
        QFile::remove(kopie + "-wal");
        QFile::remove(kopie + "-shm");
    }

    // GRAFIK-INSERT-MISMATCH-01 Regressionstest: createProjekt() muss alle
    // Migrationen > CURRENT_SCHEMA_VERSION sofort anwenden, nicht erst beim
    // naechsten openProjekt(). Sonst laeuft ein frisch erstelltes Projekt
    // seine gesamte erste Sitzung mit veraltetem Schema (z.B. fehlendes
    // grafik_element.kabel_id aus Migration 140) - sichtbar geworden als
    // irrefuehrendes "Parameter count mismatch" beim allerersten Speichern.
    // Eigene Database-Instanz/Connection, damit es die anderen Tests (m_db)
    // nicht stoert - deshalb ans Ende gesetzt.
    // SYM-STECKKONTAKT-01 (Migration 157): stecker/buchse laufen über den
    // verallgemeinerten Mechanismus (steck_rolle + Pin-Flag steckkontakt).
    void test_13_steckkontaktMigration()
    {
        TmpProjekt tp("sk13"); QVERIFY(tp.db.isOpen());
        SymbolDefinitionModel m;
        QCOMPARE(m.steckRolleForSymbol("stecker"), QStringLiteral("stecker"));
        QCOMPARE(m.steckRolleForSymbol("buchse"),  QStringLiteral("buchse"));
        QCOMPARE(m.steckRolleForSymbol("motor"),   QString());
        const QVariantList info = m.steckkontaktInfo("stecker");
        QCOMPARE(info.size(), 1);
        QCOMPARE(info[0].toMap().value("name").toString(), QStringLiteral("2"));
        // Rechteck (Index 1) berührt Pin 2, die Zuleitung (Linie, Index 0) nicht
        QCOMPARE(info[0].toMap().value("primitive").toList(), QVariantList{1});
        const QVariantList binfo = m.steckkontaktInfo("buchse");
        QCOMPARE(binfo.size(), 1);
        QCOMPARE(binfo[0].toMap().value("primitive").toList(), QVariantList{1});
    }

    // Steckkopplung eigener Symbole: Partner nur Stecker<->Buchse mit gleichem
    // Pin-Namen, in jeder Ausrichtung, als logisches (ungezeichnetes) Segment.
    void test_14_steckkontaktKopplung()
    {
        TmpProjekt tp("sk14"); QVERIFY(tp.db.isOpen());
        SymbolDefinitionModel m;
        auto anlegen = [&](const QString &id, const QString &rolle, const QString &kontaktName) {
            QVERIFY(m.symbolAnlegen(id, id, "Test", 24, 4, "durchleiter"));
            QVERIFY(m.steckRolleSetzen(id, rolle));
            // Anschluss unten (offen nach unten), Kontakt oben (offen nach oben)
            QVariantMap a; a["name"] = "L"; a["x"] = 0.5; a["y"] = 1.0; a["offenX"] = 0.0; a["offenY"] = 1.0;
            QVariantMap k; k["name"] = kontaktName; k["x"] = 0.5; k["y"] = 0.0; k["offenX"] = 0.0; k["offenY"] = -1.0;
            k["steckkontakt"] = true;
            QVERIFY(m.pinHinzufuegen(id, a) > 0);
            QVERIFY(m.pinHinzufuegen(id, k) > 0);
            QVariantMap r; r["typ"] = "rechteck"; r["x1"] = 0.4; r["y1"] = 0.0; r["x2"] = 0.6; r["y2"] = 0.5; r["reihenfolge"] = 0;
            QVERIFY(m.primitivHinzufuegen(id, r) > 0);
        };
        anlegen("t_stecker", "stecker", "L'");
        anlegen("t_buchse",  "buchse",  "L'");
        anlegen("t_stecker2", "stecker", "L'");
        anlegen("t_buchse_x", "buchse",  "N'");

        auto el = [](const QString &sid, double y1, double rot) {
            QVariantMap e;
            e["typ"] = "symbol"; e["symbolId"] = sid;
            e["x1"] = 40.0; e["y1"] = y1; e["x2"] = 64.0; e["y2"] = y1 + 4.0;
            e["rotation"] = rot; e["spiegelX"] = false; e["spiegelY"] = false;
            e["extraDaten"] = QVariantMap();
            return e;
        };
        auto logischeSegmente = [&](const QVariantList &snap) {
            int n = 0;
            for (const QVariant &v : m.autoVerbindungenBerechnen(snap, 4.0, QVariantMap())) {
                const QVariantMap seg = v.toMap();
                if (seg.value("logisch").toBool()) n++;
            }
            return n;
        };
        auto alleSegmente = [&](const QVariantList &snap) {
            return m.autoVerbindungenBerechnen(snap, 4.0, QVariantMap()).size();
        };

        // Stecker (oben, Kontakt zeigt nach UNTEN → gedreht) über Buchse:
        // Buchse oben mit Kontakt nach unten = Rotation 180, Stecker unten Rotation 0.
        QVariantList snap{ el("t_buchse", 0.0, 180.0), el("t_stecker", 8.0, 0.0) };
        QCOMPARE(logischeSegmente(snap), 1);

        // gleiche Rolle koppelt nicht (und verbindet sich auch nicht anderweitig)
        QVariantList gleich{ el("t_stecker2", 0.0, 180.0), el("t_stecker", 8.0, 0.0) };
        QCOMPARE(logischeSegmente(gleich), 0);
        QCOMPARE(alleSegmente(gleich), 0);

        // anderer Kontakt-Name koppelt nicht
        QVariantList anders{ el("t_buchse_x", 0.0, 180.0), el("t_stecker", 8.0, 0.0) };
        QCOMPARE(logischeSegmente(anders), 0);
        QCOMPARE(alleSegmente(anders), 0);

        // seitlich (alle Ausrichtungen): Rotation 90/270 statt vertikal
        QVariantMap b90 = el("t_buchse", 0.0, 90.0);
        QVariantMap s90 = el("t_stecker", 0.0, 270.0);
        b90["x1"] = 0.0;  b90["x2"] = 24.0;  b90["y1"] = 0.0; b90["y2"] = 4.0;
        s90["x1"] = 24.0 + 8.0 - 10.0; s90["x2"] = s90["x1"].toDouble() + 24.0; s90["y1"] = 0.0; s90["y2"] = 4.0;
        // Kontakt-Pin von b90 sitzt rotiert an anderer Stelle; hier genügt: Kopplung
        // wird in dieser Konstellation entweder erkannt (logisch) oder gar nicht
        // gezeichnet verbunden - nie als normale Leitung.
        const QVariantList seit{ b90, s90 };
        QCOMPARE(alleSegmente(seit), logischeSegmente(seit));
    }

    // SYM-KOPIE-VON-06 (Migration 158): uebernommene Symbole vorhanden, die
    // sechs geloeschten Builtins weg, Steckkontakte der Schuko-/Drehstrom-Symbole gesetzt.
    void test_15_symbolUebernahme158()
    {
        TmpProjekt tp("sk15"); QVERIFY(tp.db.isOpen());
        QSqlQuery q(QSqlDatabase::database());
        for (const char *gone : { "fi", "sicherung", "sicherung_3pol", "not_halt", "hupe", "summer",
                                  "kopie_von_summer", "sicherung_dreipol" }) {
            q.prepare("SELECT COUNT(*) FROM symbol_definition WHERE id = :i");
            q.bindValue(":i", QString::fromLatin1(gone)); QVERIFY(q.exec() && q.next());
            QVERIFY2(q.value(0).toInt() == 0, gone);
            q.prepare("SELECT COUNT(*) FROM symbol WHERE code = :i");
            q.bindValue(":i", QString::fromLatin1(gone)); QVERIFY(q.exec() && q.next());
            QVERIFY2(q.value(0).toInt() == 0, gone);
        }
        for (const char *da : { "not_halt_nc_vierpolig", "sicherung_einpolig", "sicherung_dreipolig", "horn_hupe",
                                "optokoppler", "motorschutzschalter", "schuko_stecker_pe_mittig", "drehstromsteckdose" }) {
            q.prepare("SELECT ist_builtin, (SELECT COUNT(*) FROM symbol_pin WHERE symbol_id = :i), "
                      "(SELECT COUNT(*) FROM symbol_primitiv WHERE symbol_id = :i) FROM symbol_definition WHERE id = :i");
            q.bindValue(":i", QString::fromLatin1(da)); QVERIFY(q.exec());
            QVERIFY2(q.next(), da);
            QCOMPARE(q.value(0).toInt(), 1);
            QVERIFY2(q.value(1).toInt() > 0 && q.value(2).toInt() > 0, da);
        }
        QVERIFY(q.exec("SELECT breite_mm, hoehe_mm FROM symbol_definition WHERE id = 'sicherungstrennschalter'") && q.next());
        QCOMPARE(q.value(0).toInt(), 8); QCOMPARE(q.value(1).toInt(), 12);
        // Migration 159: Kategorie Signalübertragung (Optokoppler, Spulen, Trafo, Netzteil)
        QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_definition WHERE kategorie = 'Signalübertragung' "
                       "AND id IN ('optokoppler','spule','anzugverzoegerte_spule_relais',"
                       "'rueckfallverzoegerte_spule_relais','thermo_spule_relais','trafo','netzteil')") && q.next());
        QCOMPARE(q.value(0).toInt(), 7);
        QVERIFY(q.exec("SELECT COUNT(*) FROM symbol WHERE kategorie_pfad = 'signaluebertragung'") && q.next());
        QCOMPARE(q.value(0).toInt(), 7);
        QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_definition WHERE kategorie IN ('Signalumwandlung')") && q.next());
        QCOMPARE(q.value(0).toInt(), 0);
        // Migration 160: BMK-Ausrichtung 'vertikal' uebernommen, Kopien weg
        QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_definition WHERE bmk_seite='vertikal' AND id IN ('optokoppler','motor','motor_mit_pe')") && q.next());
        QCOMPARE(q.value(0).toInt(), 3);
        QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_definition WHERE id LIKE 'kopie_von_%'") && q.next());
        QCOMPARE(q.value(0).toInt(), 0);
        SymbolDefinitionModel m;
        QCOMPARE(m.steckRolleForSymbol("drehstromstecker"), QStringLiteral("stecker"));
        QCOMPARE(m.steckkontaktInfo("drehstromstecker").size(), 5);
        QCOMPARE(m.steckkontaktInfo("schuko_steckdose_pe_mittig").size(), 3);
    }

    void test_16_ledVentilFehlenMigration145Und161()
    {
        // Regression SYM-MIGRATION-LED-VENTIL-01: Projekt Stresstest hatte durch
        // Migration 133 weder 'led' noch 'ventil' - Migration 145 scheiterte am FK
        // symbol_bmk_kennbuchstabe -> symbol_definition, das Projekt liess sich nicht
        // mehr oeffnen. Nachgestellt: led/ventil entfernen, 145..161 als "noch nicht
        // angewendet" markieren, neu oeffnen.
        const QString pfad = QDir::tempPath() + "/stroemling_test_ledventil_"
                           + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".stroemling";
        Database d;
        QVERIFY(d.createProjekt(pfad, "LedVentil"));
        {
            QSqlQuery q(QSqlDatabase::database());
            QVERIFY(q.exec("DELETE FROM symbol WHERE code IN ('led','ventil')"));
            QVERIFY(q.exec("DELETE FROM symbol_definition WHERE id IN ('led','ventil')"));
            QVERIFY(q.exec("DELETE FROM schema_migration WHERE version >= 145"));
        }
        d.closeProjekt();
        QVERIFY2(d.openProjekt(pfad), "openProjekt() mit fehlendem led/ventil muss Migration 145 + 161 ueberstehen");
        {
            QSqlQuery q(QSqlDatabase::database());
            QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_definition WHERE id IN ('led','ventil') AND ist_builtin=1") && q.next());
            QCOMPARE(q.value(0).toInt(), 2);
            QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_pin WHERE symbol_id IN ('led','ventil')") && q.next());
            QCOMPARE(q.value(0).toInt(), 4);
            QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_primitiv WHERE symbol_id IN ('led','ventil')") && q.next());
            QCOMPARE(q.value(0).toInt(), 22);
            QVERIFY(q.exec("SELECT COUNT(*) FROM symbol_bmk_kennbuchstabe WHERE (symbol_id='led' AND kennbuchstabe='V') "
                           "OR (symbol_id='ventil' AND kennbuchstabe='YA')") && q.next());
            QCOMPARE(q.value(0).toInt(), 2);
        }
        d.closeProjekt();
        QFile::remove(pfad); QFile::remove(pfad + "-wal"); QFile::remove(pfad + "-shm");
    }

    void test_17_backupStrategieUndWiederherstellen()
    {
        // BACKUP-STRATEGIE-01 / BACKUP-OEFFNEN-01 (Konzept 26 §4)
        const QString ordner = QDir::tempPath() + "/stroemling_test_backup_"
                             + QString::number(QDateTime::currentMSecsSinceEpoch());
        QVERIFY(QDir().mkpath(ordner + "/bilder"));
        const QString pfad = ordner + "/projekt.strl";
        {
            QFile bild(ordner + "/bilder/x.png");
            QVERIFY(bild.open(QIODevice::WriteOnly)); bild.write("png"); bild.close();
        }
        Database d;
        QVERIFY(d.createProjekt(pfad, "Backup"));
        d.closeProjekt();
        QVERIFY(d.openProjekt(pfad));       // wendet alle Migrationen an (legt dabei eigene Backups an)
        d.closeProjekt();
        QDir(ordner + "/backups").removeRecursively();

        // Vorhandene Fake-Backups: Versionen 100..108, je 3 Zustaende, verschieden alt.
        QVERIFY(QDir().mkpath(ordner + "/backups"));
        const QDateTime jetzt = QDateTime::currentDateTime();
        for (int v = 100; v <= 108; ++v)
            for (int n = 0; n < 3; ++n) {
                QFile f(QString("%1/backups/stroemling_v%2_2026-01-0%3.db").arg(ordner).arg(v).arg(n + 1));
                QVERIFY(f.open(QIODevice::WriteOnly)); f.write(QByteArray(10, char('a' + n))); 
                QVERIFY(f.setFileTime(jetzt.addDays(-(v - 99) * 3 + n), QFileDevice::FileModificationTime));
                f.close();
            }

        auto backupsMitVersion = [&](int v) {
            return QDir(ordner + "/backups").entryList({QString("stroemling_v%1_*.db").arg(v)}, QDir::Files).size();
        };
        auto ausstehendMachen = [&]() {
            QVERIFY(d.openProjekt(pfad));
            QSqlQuery q(QSqlDatabase::database());
            QVERIFY(q.exec("DELETE FROM schema_migration WHERE version >= 161"));
            d.closeProjekt();
        };
        ausstehendMachen();                 // Zustand mit ausstehender Migration 161
        QVERIFY(d.openProjekt(pfad));       // legt Backup v160 an
        d.closeProjekt();
        QCOMPARE(backupsMitVersion(160), 1);
        // Hoechste 6 Versionen (160, 108..104), je hoechstens 2 Zustaende
        for (int v = 100; v <= 103; ++v) QCOMPARE(backupsMitVersion(v), 0);
        for (int v = 104; v <= 108; ++v) QCOMPARE(backupsMitVersion(v), 2);

        // Fehlversuch-Szenario: gleicher Zustand nochmal -> kein neues Backup
        ausstehendMachen();
        QVERIFY(d.openProjekt(pfad));
        d.closeProjekt();
        QCOMPARE(backupsMitVersion(160), 1);

        // Wiederherstellen als neues Projekt daneben
        QVERIFY(d.openProjekt(pfad));
        const QVariantList liste = d.projektBackups();
        QVERIFY(!liste.isEmpty());
        QCOMPARE(liste.first().toMap()["version"].toInt(), 160);
        const QString neu = d.backupWiederherstellen(liste.first().toMap()["pfad"].toString());
        QVERIFY(!neu.isEmpty());
        QVERIFY(neu != pfad);
        QVERIFY(QFile::exists(neu));
        QVERIFY(QFile::exists(QFileInfo(neu).absolutePath() + "/bilder/x.png"));
        QVERIFY(QFile::exists(pfad));
        // Fremde Datei wird abgelehnt
        QFile fremd(ordner + "/fremd.db");
        QVERIFY(fremd.open(QIODevice::WriteOnly)); fremd.close();
        QVERIFY(d.backupWiederherstellen(fremd.fileName()).isEmpty());
        d.closeProjekt();
        QVERIFY2(d.openProjekt(neu), "wiederhergestelltes Projekt muss sich oeffnen lassen");
        d.closeProjekt();

        QDir(QFileInfo(neu).absolutePath()).removeRecursively();
        QDir(ordner).removeRecursively();
    }

    void test_18_autobackupFasstMigrationsBackupsNichtAn()
    {
        // BACKUP-AUTOGLOB-01: datenbankAutobackup() ("wiki_*.db", max. 7) darf die
        // Vor-Migrations-Backups "wiki_v<N>_….db" aus erstelleBackup() weder loeschen
        // noch als "heute schon gesichert" werten.
        const QString ordner = QDir::tempPath() + "/stroemling_test_autobackup_"
                             + QString::number(QDateTime::currentMSecsSinceEpoch());
        QVERIFY(QDir().mkpath(ordner + "/backups"));
        Database d;
        QVERIFY(d.openLauncher(ordner + "/launcher.db"));
        QVERIFY(d.openWiki(ordner + "/wiki.db"));

        const QString heute = QDate::currentDate().toString("yyyy-MM-dd");
        QStringList migrationsBackups;
        for (int v = 1; v <= 9; ++v) {
            const QString n = QString("wiki_v%1_%2.db").arg(v).arg(heute);
            QFile f(ordner + "/backups/" + n);
            QVERIFY(f.open(QIODevice::WriteOnly)); f.write("x"); f.close();
            migrationsBackups << n;
        }
        d.datenbankAutobackup();
        QVERIFY2(QFile::exists(ordner + "/backups/wiki_" + heute + ".db"),
                 "Tages-Backup muss trotz vorhandener wiki_v*-Dateien von heute angelegt werden");
        for (const QString &n : migrationsBackups)
            QVERIFY2(QFile::exists(ordner + "/backups/" + n), qPrintable(n + " wurde geloescht"));

        d.closeProjekt();
        QDir(ordner).removeRecursively();
    }

    void test_19_wikiV16EntferntStroemlingBilder()
    {
        // Wiki-Schema v16: Bilder von Brauno/Blaubertha werden nicht mehr eingesaet
        // (Linus hat seit Okt 2026 ein neues Bild; die Assets liegen im Test-Binary nicht vor, das Einsaeen
        // der neuen Bilder ist daher nur im App-Build pruefbar) und in bestehenden Wikis (v15) samt BLOB-Datei entfernt.
        const QString ordner = QDir::tempPath() + "/stroemling_test_wiki16_"
                             + QString::number(QDateTime::currentMSecsSinceEpoch());
        QVERIFY(QDir().mkpath(ordner));
        const QString wikiPfad = ordner + "/wiki.db";
        {
            Database d;
            QVERIFY(d.openWiki(wikiPfad));
            QSqlDatabase w = QSqlDatabase::database("stroemling_wiki");
            QSqlQuery q(w);
            QVERIFY(q.exec("SELECT COUNT(*) FROM wiki_bild wb JOIN wiki_artikel wa ON wa.id=wb.artikel_id "
                           "WHERE wa.titel LIKE 'Brauno %' OR wa.titel LIKE 'Blaubertha %'") && q.next());
            QCOMPARE(q.value(0).toInt(), 0);
            // Altbestand simulieren: Bild + BLOB fuer Brauno, Version zurueck auf 15
            QVERIFY(q.exec("INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, blob_pfad, sortierung) "
                           "SELECT id, 'brauno_uebersicht.png', 'image/png', '9999.png', 1 FROM wiki_artikel WHERE titel LIKE 'Brauno %'"));
            QFile blob(ordner + "/wiki_blobs/9999.png");
            QVERIFY(blob.open(QIODevice::WriteOnly)); blob.write("x"); blob.close();
            QVERIFY(q.exec("DELETE FROM schema_version"));
            QVERIFY(q.exec("INSERT INTO schema_version (version) VALUES (15)"));
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        {
            Database d;
            QVERIFY(d.openWiki(wikiPfad));
            QSqlQuery q(QSqlDatabase::database("stroemling_wiki"));
            QVERIFY(q.exec("SELECT COUNT(*) FROM wiki_bild WHERE dateiname='brauno_uebersicht.png'") && q.next());
            QCOMPARE(q.value(0).toInt(), 0);
            QVERIFY(!QFile::exists(ordner + "/wiki_blobs/9999.png"));
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        QDir(ordner).removeRecursively();
    }

    void test_12_createProjektWendetNeueMigrationenSofortAn()
    {
        const QString tmp = QDir::tempPath() + "/stroemling_test_sofort_"
                           + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".stroemling";
        Database frisch;
        QVERIFY2(frisch.createProjekt(tmp, "Soforttest"),
                 "createProjekt() sollte auch die neuen Migrationen (>129) sofort anwenden");

        QSqlQuery qs(QSqlDatabase::database());
        QVERIFY(qs.exec("INSERT INTO seite (blattnummer, bezeichnung) VALUES ('1', 'Sofort')"));
        int seiteId = qs.lastInsertId().toInt();

        QVariantList elemente;
        QVariantMap symbol;
        symbol["typ"] = "symbol";
        symbol["x1"] = 10.0; symbol["y1"] = 10.0;
        symbol["x2"] = 30.0; symbol["y2"] = 30.0;
        symbol["symbolId"] = "motor";
        elemente.append(symbol);
        QVERIFY2(frisch.grafikSpeichern(seiteId, elemente),
                 "grafikSpeichern() direkt nach createProjekt() sollte funktionieren (kabel_id etc. aus Migration 140)");

        QVERIFY2(frisch.projektZuletztVerwendeteSymboleSpeichern(1, {"motor"}),
                 "projektZuletztVerwendeteSymboleSpeichern() direkt nach createProjekt() (Migration 146)");

        frisch.closeProjekt();
        QFile::remove(tmp);
        QFile::remove(tmp + "-wal");
        QFile::remove(tmp + "-shm");
    }

    void test_20_seitenbaumLoeschenKaskadiert()
    {
        // SEITENBAUM-LOESCHEN-KASKADE-01: Ort/Anlage mit Seiten (samt Segmenten, Querverweisen,
        // Betriebsmittel-/Klemmenleisten-Zuordnung) liess sich wegen NO-ACTION-FKs nicht loeschen.
        TmpProjekt t("seitenbaumloeschen");
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("PRAGMA foreign_keys=ON"));
        auto ins = [&](const QString &sql) {
            QVERIFY2(q.exec(sql), qPrintable(sql + " -> " + q.lastError().text()));
        };
        ins("INSERT INTO anlage (projekt_id, kuerzel, bezeichnung) VALUES (1,'AQ','A')");
        const int anlageId = q.lastInsertId().toInt();
        ins(QString("INSERT INTO ort (anlage_id, kuerzel, bezeichnung) VALUES (%1,'TR','O')").arg(anlageId));
        const int ortId = q.lastInsertId().toInt();
        ins(QString("INSERT INTO seite (ort_id, blattnummer, bezeichnung) VALUES (%1,'1','S1')").arg(ortId));
        const int s1 = q.lastInsertId().toInt();
        ins(QString("INSERT INTO seite (ort_id, blattnummer, bezeichnung) VALUES (%1,'2','S2')").arg(ortId));
        const int s2 = q.lastInsertId().toInt();
        ins(QString("INSERT INTO verbindung (projekt_id, bezeichnung) VALUES (1,'N1')"));
        const int v = q.lastInsertId().toInt();
        ins(QString("INSERT INTO verbindung_segment (verbindung_id, seite_id) VALUES (%1,%2)").arg(v).arg(s1));
        ins(QString("INSERT INTO querverweis (verbindung_id, von_seite_id, nach_seite_id) VALUES (%1,%2,%3)").arg(v).arg(s1).arg(s2));
        ins(QString("INSERT INTO klemmenleiste (projekt_id, bezeichnung, ort_id) VALUES (1,'X1',%1)").arg(ortId));

        SeitenModel m;
        m.laden(1);
        QVERIFY2(m.loeschen(1, ortId), "Ort mit Seiten muss loeschbar sein");
        auto zaehle = [&](const QString &sql) { QSqlQuery c(QSqlDatabase::database()); c.exec(sql); c.next(); return c.value(0).toInt(); };
        QCOMPARE(zaehle(QString("SELECT COUNT(*) FROM ort WHERE id=%1").arg(ortId)), 0);
        QCOMPARE(zaehle(QString("SELECT COUNT(*) FROM seite WHERE id IN (%1,%2)").arg(s1).arg(s2)), 0);
        QCOMPARE(zaehle("SELECT COUNT(*) FROM verbindung_segment WHERE verbindung_id=" + QString::number(v)), 0);
        QCOMPARE(zaehle("SELECT COUNT(*) FROM querverweis WHERE verbindung_id=" + QString::number(v)), 0);
        QCOMPARE(zaehle("SELECT COUNT(*) FROM klemmenleiste WHERE bezeichnung='X1' AND ort_id IS NULL"), 1);   // bleibt, nur Zuordnung weg

        // Anlage mit Ort + Seite
        ins(QString("INSERT INTO ort (anlage_id, kuerzel, bezeichnung) VALUES (%1,'TR2','O2')").arg(anlageId));
        const int ort2 = q.lastInsertId().toInt();
        ins(QString("INSERT INTO seite (ort_id, blattnummer, bezeichnung) VALUES (%1,'1','S')").arg(ort2));
        const int s3 = q.lastInsertId().toInt();
        m.laden(1);
        QVERIFY2(m.loeschen(0, anlageId), "Anlage mit Orten/Seiten muss loeschbar sein");
        QCOMPARE(zaehle(QString("SELECT COUNT(*) FROM anlage WHERE id=%1").arg(anlageId)), 0);
        QCOMPARE(zaehle(QString("SELECT COUNT(*) FROM ort WHERE id=%1").arg(ort2)), 0);
        QCOMPARE(zaehle(QString("SELECT COUNT(*) FROM seite WHERE id=%1").arg(s3)), 0);
    }
};

// Zwei Testklassen in einem Executable: Migrationen + Kernfunktionen (grafikSpeichern/klemmlistenauszug).
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);   // Schriften/QPainter fuer PDF-Export noetig
    TstMigrationen   migrationen;
    TstKernfunktionen kern;
    int rc = QTest::qExec(&migrationen, argc, argv);
    rc |= QTest::qExec(&kern, argc, argv);
    return rc;
}
#include "tst_migrationen.moc"
