#include <QtTest>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QDir>
#include <QFile>
#include <QDateTime>
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
        static const QStringList erwartet = {
            "schema_migration",
            "projekt", "seite",
            "grafik_element", "verbindung", "verbindung_segment",
            "bauteil", "bauteil_kategorie",
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
};

QTEST_GUILESS_MAIN(TstMigrationen)
#include "tst_migrationen.moc"
