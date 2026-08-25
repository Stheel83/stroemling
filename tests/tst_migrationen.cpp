#include <QtTest>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QSet>
#include "database/Database.h"

// Testet das Migrations-System auf einer temporären SQLite-Datei.
// Ablauf: createProjekt (v40-Baseline) → closeProjekt → openProjekt
//         (wendet v41..vN an) → Schema-Integrität prüfen.

class TstMigrationen : public QObject
{
    Q_OBJECT

    QString   m_tmpPfad;
    Database *m_db = nullptr;

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
};

QTEST_GUILESS_MAIN(TstMigrationen)
#include "tst_migrationen.moc"
