#include "Database.h"
#include <cmath>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <QPrinter>
#include <QTextDocument>
#include <QPdfWriter>
#include <QPainter>
#include <QPen>
#include <QFont>
#include <QFontMetricsF>
#include <QColor>
#include <QPolygonF>
#include <QPageSize>
#include <QPageLayout>
#include <algorithm>



// ============================================================
// Migrations-Katalog
// Jede Migration hat eine aufsteigende Versionsnummer, eine
// kurze Beschreibung und eine Liste von SQL-Statements.
// Die Baseline-Version (BASELINE_VERSION) wird von
// checkAndApplySchema() speziell behandelt: dropAllTables()
// + createSchema() + Seeds. Statements-Liste bleibt leer.
//
// Bei einem Squash (keine Produktivdaten): BASELINE_VERSION
// erhöhen, alle alten Einträge entfernen, neuen Baseline-
// Eintrag hier eintragen. Dev-DBs werden beim nächsten
// Start automatisch neu aufgebaut.
// ============================================================
struct SchemaMigration {
    int         version;
    QString     beschreibung;
    QStringList statements;
};

static QList<SchemaMigration> alleMigrationen()
{
    return {
        // Squash v40-v51: alle Tabellen + Spalten sind in createSchema() enthalten.
        // Dev-DBs < v52 werden beim ersten Start neu aufgebaut (dropAllTables + createSchema).
        { 52, "Baseline v52 – Schema konsolidiert (v40-v51 gefaltet)", {} },

        // Baseline v53: createSchema() liest jetzt schema.sql (statt Inline-C++).
        // schema.sql enthält vollständiges Schema inkl. gruppe_id, revision-Spalten, SPS-Tabellen.
        // Dev-DBs bei v52 werden neu aufgebaut (dropAllTables + createSchema aus schema.sql).
        { 53, "Baseline v53 – Schema in schema.sql, SPS/Revision/Gruppe vollständig", {} },

        // B9: Brückengleichrichter (passive, IEC-Raute 32x32mm) + sensor_temp-Absicherung.
        // INSERT OR IGNORE: sicher falls symbol_definition/pin/primitiv schon vorhanden.
        { 54, "B9 – Brückengleichrichter-Symbol + sensor_temp-Absicherung", {
            // sensor_temp (PT100) – falls DB vor dessen Aufnahme in symbole.sql angelegt wurde
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sensor_temp', 'Temperatursensor (PT100)', 'Sensoren', 16, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sensor_temp', '1', 0, 0.5, -1, 0, 'neutral'), ('sensor_temp', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sensor_temp', 0, 'rechteck', 0.1, 0.1, 0.9, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_temp', 1, 'linie', 0, 0.5, 0.1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_temp', 2, 'linie', 0.9, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_temp', 3, 'text', 0.5, 0.35, 0, 0, 0, 0, 0, 0, 0, 0, 'PT', 0.22, 1, 'center', 'middle', 'solid'), ('sensor_temp', 4, 'text', 0.5, 0.65, 0, 0, 0, 0, 0, 0, 0, 0, '100', 0.18, 0, 'center', 'middle', 'solid'))",
            // Brückengleichrichter
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('brueckengleichrichter', 'Brückengleichrichter', 'Passive', 32, 32, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('brueckengleichrichter', '~1', 0, 0.5, -1, 0, 'power'), ('brueckengleichrichter', '~2', 1, 0.5, 1, 0, 'power'), ('brueckengleichrichter', '+', 0.5, 0, 0, -1, 'power'), ('brueckengleichrichter', '-', 0.5, 1, 0, 1, 'power'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('brueckengleichrichter', 0, 'linie', 0.15, 0.5, 0.5, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 1, 'linie', 0.5, 0.15, 0.85, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 2, 'linie', 0.85, 0.5, 0.5, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 3, 'linie', 0.5, 0.85, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 4, 'linie', 0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 5, 'linie', 0.85, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 6, 'linie', 0.5, 0, 0.5, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 7, 'linie', 0.5, 0.85, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 8, 'text', 0.5, 0.3, 0, 0, 0, 0, 0, 0, 0, 0, '+', 0.18, 1, 'center', 'middle', 'solid'), ('brueckengleichrichter', 9, 'text', 0.5, 0.7, 0, 0, 0, 0, 0, 0, 0, 0, '-', 0.18, 1, 'center', 'middle', 'solid'))",
        }},

        // Geräteanschluss + Potenzialpunkt: 16x16mm → 8x8mm, Kreis-Radius 0.22→0.25
        // (Proportionen nach Nutzer-Vorlage: Kreis berührt linke Kante und Mittelpunkt exakt)
        { 55, "Geraeteanschluss + Potenzial: 16x16mm auf 8x8mm verkleinert", {
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='geraeteanschluss' AND ist_builtin=1)",
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='potenzial'        AND ist_builtin=1)",
            R"(UPDATE symbol_primitiv SET x1=0.25, radius=0.25 WHERE symbol_id='geraeteanschluss' AND reihenfolge=1)",
            R"(UPDATE symbol_primitiv SET x1=0.25, radius=0.25 WHERE symbol_id='potenzial'        AND reihenfolge=1)",
        }},
    };
}


// ============================================================
// checkAndApplySchema
// Inkrementelles Migrations-System: liest den höchsten
// angewendeten Versions-Eintrag aus schema_migration und
// führt alle ausstehenden Migrationen in Reihenfolge aus.
//
// Übergangslogik: existiert die alte schema_version-Tabelle
// mit v=40, wird v40 als bereits angewendet übernommen ohne
// Rebuild.
// ============================================================
bool Database::checkAndApplySchema()
{
    // schema_migration-Tabelle sicherstellen (außerhalb jeder Transaktion)
    {
        QSqlQuery q(m_db);
        if (!q.exec(
            "CREATE TABLE IF NOT EXISTS schema_migration ("
            "    version       INTEGER PRIMARY KEY,"
            "    beschreibung  TEXT    NOT NULL,"
            "    angewendet_am TEXT    NOT NULL DEFAULT (datetime('now'))"
            ")")) {
            qWarning() << "schema_migration anlegen:" << q.lastError().text();
            return false;
        }
    }

    // Aktuelle Version ermitteln
    int currentVersion = 0;
    {
        QSqlQuery q(m_db);
        bool leer = true;
        if (q.exec("SELECT COUNT(*) FROM schema_migration") && q.next())
            leer = (q.value(0).toInt() == 0);

        if (leer) {
            // Übergang: alte schema_version-Tabelle prüfen
            QSqlQuery sv;
            if (sv.exec("SELECT version FROM schema_version LIMIT 1") && sv.next()
                    && sv.value(0).toInt() == BASELINE_VERSION) {
                QSqlQuery ins;
                ins.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :b)");
                ins.bindValue(":v", BASELINE_VERSION);
                ins.bindValue(":b", QString("Baseline v%1 – übernommen aus schema_version").arg(BASELINE_VERSION));
                ins.exec();
                currentVersion = BASELINE_VERSION;
                qInfo() << "schema_migration: Übergang schema_version → v" << BASELINE_VERSION;
            }
        } else {
            if (q.exec("SELECT COALESCE(MAX(version), 0) FROM schema_migration") && q.next())
                currentVersion = q.value(0).toInt();
        }
    }

    // Backup erstellen wenn Migrationen ausstehen
    {
        const auto &migrationen = alleMigrationen();
        bool hatAusstehende = std::any_of(migrationen.begin(), migrationen.end(),
            [currentVersion](const SchemaMigration &m){ return m.version > currentVersion; });
        if (hatAusstehende)
            erstelleBackup("", "stroemling", currentVersion);
    }

    // Ausstehende Migrationen anwenden
    for (const SchemaMigration &mig : alleMigrationen()) {
        if (mig.version <= currentVersion) continue;

        qInfo() << "Wende Migration" << mig.version << "an:" << mig.beschreibung;

        if (!m_db.transaction()) {
            qWarning() << "Transaktion fehlgeschlagen:" << m_db.lastError().text();
            return false;
        }

        bool ok = false;
        if (mig.version == BASELINE_VERSION) {
            // Baseline: vollständiger Neuaufbau
            ok = dropAllTables() && createSchema()
                 && seedSymbolKatalog() && seedBuiltinSymbolDefinitionen()
                 && seedIbnFeldvorlagen();
        } else {
            ok = applyMigrationStatements(mig.statements);
        }

        if (!ok) {
            m_db.rollback();
            emit dbFehler(QString("Migration v%1 fehlgeschlagen. Die Datenbank wurde nicht verändert "
                                  "(Backup vorhanden).").arg(mig.version));
            return false;
        }

        QSqlQuery ins;
        ins.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :b)");
        ins.bindValue(":v", mig.version);
        ins.bindValue(":b", mig.beschreibung);
        if (!ins.exec()) {
            qWarning() << "schema_migration schreiben:" << ins.lastError().text();
            m_db.rollback();
            return false;
        }

        if (!m_db.commit()) {
            qWarning() << "Commit fehlgeschlagen:" << m_db.lastError().text();
            m_db.rollback();
            return false;
        }

        qInfo() << "Migration" << mig.version << "erfolgreich angewendet.";
        currentVersion = mig.version;
    }

    qInfo() << "Hauptdatenbank auf Schema-Version" << currentVersion;
    return true;
}

bool Database::applyMigrationStatements(const QStringList &statements)
{
    QSqlQuery q(m_db);
    for (const QString &stmt : statements) {
        if (stmt.trimmed().isEmpty()) continue;
        if (!q.exec(stmt)) {
            qWarning() << "Migration-Statement fehlgeschlagen:" << q.lastError().text();
            qWarning() << "Statement:" << stmt.left(200);
            return false;
        }
    }
    return true;
}

// ============================================================
// erstelleBackup
// Kopiert dbPfad nach <dataDir>/backups/<prefix>_v<version>_<datum>.db.
// Hält maximal 5 Backups je Prefix (älteste werden gelöscht).
// Wird vor jeder ausstehenden Migration aufgerufen.
// ============================================================
bool Database::erstelleBackup(const QString &verbindungsName, const QString &prefix, int version)
{
    QSqlDatabase db = verbindungsName.isEmpty()
                      ? m_db
                      : QSqlDatabase::database(verbindungsName);

    QString dbPfad = db.databaseName();
    QFileInfo fi(dbPfad);
    if (!fi.exists()) return true;  // Neuinstallation – nichts zu sichern

    QString backupDir = fi.absolutePath() + "/backups";
    if (!QDir().mkpath(backupDir)) {
        qWarning() << "Backup-Verzeichnis konnte nicht angelegt werden:" << backupDir;
        return false;
    }

    QString datum = QDate::currentDate().toString("yyyy-MM-dd");
    QString backupPfad = backupDir + "/" + prefix + "_v" + QString::number(version)
                         + "_" + datum + ".db";

    // Zweiter Backup am selben Tag: Uhrzeit ergänzen
    if (QFile::exists(backupPfad)) {
        QString zeit = QTime::currentTime().toString("HHmm");
        backupPfad = backupDir + "/" + prefix + "_v" + QString::number(version)
                     + "_" + datum + "_" + zeit + ".db";
    }

    // VACUUM INTO erzeugt eine saubere Kopie einer offenen SQLite-DB (WAL-sicher)
    QString escaped = backupPfad;
    escaped.replace("'", "''");
    QSqlQuery q(db);
    if (!q.exec("VACUUM INTO '" + escaped + "'")) {
        qWarning() << "Backup fehlgeschlagen:" << backupPfad << q.lastError().text();
        return false;
    }
    qInfo() << "Backup erstellt:" << backupPfad;

    // Älteste Backups löschen wenn mehr als 5 vorhanden
    QDir bd(backupDir);
    QStringList backups = bd.entryList({ prefix + "_v*.db" }, QDir::Files, QDir::Name);
    while (backups.size() > 5) {
        QString alt = backups.takeFirst();
        if (bd.remove(alt))
            qInfo() << "Altes Backup gelöscht:" << alt;
    }

    return true;
}

// ============================================================
// dropAllTables
// Views zuerst, dann Tabellen in FK-sicherer Reihenfolge
// (abhängige Tabellen vor den referenzierten).
// ============================================================
bool Database::dropAllTables()
{
    // Foreign Keys während des Drops deaktivieren – SQLite ignoriert
    // FK-Constraints bei DDL ohnehin, aber sicherheitshalber.
    QSqlQuery q(m_db);
    q.exec("PRAGMA foreign_keys = OFF");

    const QStringList views = {
        "klemmenleiste_bmk",
        "betriebsmittel_bmk",
        "seite_kennzeichen"
    };
    const QStringList tables = {
        // abhängige Tabellen zuerst
        "sps_kanal",
        "sps_baugruppe",
        "sps_rack",
        "ibn_feldwert",
        "ibn_feldvorlage",
        "inbetriebnahme",
        "ibn_kabel",
        "klemme_anschluss",
        "klemme_stegbruecke",
        "klemme",
        "klemmenleiste",
        "bauteil_kabel_paar",
        "bauteil_kabel_ader",
        "bauteil_kabel",
        "kabel_ader",
        "kabel",
        "querverweis",
        "verbindung_segment",
        "verbindung",
        "leiter",
        "grafik_element",
        "betriebsmittel",
        "bauteil_klemme_eigenschaft",
        "bauteil_klemme_bruecke",
        "bauteil_klemme_querschnitt",
        "bauteil_klemme",
        "farb_definition",
        "bauteil",
        "bauteil_kategorie",
        "symbol_pin",
        "symbol_primitiv",
        "symbol_definition",
        "symbol_textfeld",
        "symbol_anschluss",
        "symbol",
        "seite",
        "ort",
        "anlage",
        "changelog",
        "normblatt_feld",
        "normblatt_vorlage",
        "projekt",
        "schema_version"   // alte Tabelle – wird beim ersten Rebuild entfernt
    };

    for (const QString &v : views) {
        if (!q.exec("DROP VIEW IF EXISTS " + v)) {
            qWarning() << "View löschen fehlgeschlagen:" << v << q.lastError().text();
            return false;
        }
    }
    for (const QString &t : tables) {
        if (!q.exec("DROP TABLE IF EXISTS " + t)) {
            qWarning() << "Tabelle löschen fehlgeschlagen:" << t << q.lastError().text();
            return false;
        }
    }

    q.exec("PRAGMA foreign_keys = ON");
    return true;
}

// ============================================================
// createSchema
// Legt alle Tabellen und Views an. Wird nur nach dropAllTables
// aufgerufen – deshalb kein IF NOT EXISTS.
// ============================================================
bool Database::createSchema()
{
    QFile f(QStringLiteral(":/database/schema.sql"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "createSchema: schema.sql nicht gefunden (:/database/schema.sql)";
        return false;
    }
    const QString sql = QString::fromUtf8(f.readAll());
    f.close();

    QStringList cleanLines;
    for (const QString &line : sql.split(QLatin1Char('\n'))) {
        if (!line.trimmed().startsWith(QLatin1String("--")))
            cleanLines << line;
    }

    QSqlQuery q(m_db);
    const QStringList statements = cleanLines.join(QLatin1Char('\n')).split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (const QString &raw : statements) {
        const QString stmt = raw.trimmed();
        if (stmt.isEmpty()) continue;
        if (!q.exec(stmt)) {
            qWarning() << "createSchema:" << q.lastError().text()
                       << "\nStatement:" << stmt.left(120);
            return false;
        }
    }

    qInfo() << "Schema aus schema.sql geladen.";
    return true;
}


// ============================================================
// seedSymbolKatalog
// Befüllt die symbol-Tabelle mit dem eingebauten Symbol-Katalog.
// norm: "IEC", "ANSI" oder "IEC,ANSI" (instr-kompatibel).
// ============================================================
bool Database::seedSymbolKatalog()
{
    struct Sym {
        QString code; QString name; QString kat; QString norm; int anschluesse;
    };
    const QList<Sym> symbole = {
        // Kontakte
        { "schliesser",      "Schließer (NO)",          "kontakte",       "IEC,ANSI", 2 },
        { "oeffner",         "Öffner (NC)",             "kontakte",       "IEC,ANSI", 2 },
        { "wechsler",        "Wechsler",                "kontakte",       "IEC,ANSI", 3 },
        { "taster_no",       "Taster (NO)",             "kontakte",       "IEC,ANSI", 2 },
        { "taster_nc",       "Taster NC",               "kontakte",       "IEC,ANSI", 2 },
        { "not_halt",        "Not-Halt (NC)",           "kontakte",       "IEC,ANSI", 2 },
        // Schutzgeräte
        { "sicherung",       "Sicherung",               "schutz",         "IEC,ANSI", 2 },
        { "lss",             "Leitungsschutzschalter",  "schutz",         "IEC",      2 },
        { "fi",              "FI-Schutzschalter",       "schutz",         "IEC",      2 },
        { "bimetall_nc",     "Bimetall-Kontakt (NC)",   "schutz",         "IEC,ANSI", 2 },
        // Antriebe
        { "motor",           "Motor",                   "antriebe",       "IEC,ANSI", 2 },
        { "spule",           "Spule / Relais",          "antriebe",       "IEC",      2 },
        { "spule_ansi",      "Coil / Relay",            "antriebe",       "ANSI",     2 },
        { "trafo",           "Transformator",           "antriebe",       "IEC,ANSI", 4 },
        // Passive Bauelemente
        { "widerstand_iec",  "Widerstand",              "passive",        "IEC",      2 },
        { "widerstand_ansi", "Resistor",                "passive",        "ANSI",     2 },
        { "kondensator",     "Kondensator",             "passive",        "IEC,ANSI", 2 },
        { "diode",           "Diode",                   "passive",        "IEC,ANSI", 2 },
        // Signalgeräte
        { "lampe",           "Lampe",                   "signalgeraete",  "IEC,ANSI", 2 },
        { "hupe",            "Hupe / Klingel",          "signalgeraete",  "IEC,ANSI", 2 },
        { "summer",          "Summer",                  "signalgeraete",  "IEC,ANSI", 2 },
        // Klemmen & Verbinder
        { "klemme",          "Klemme",                  "klemmen",        "IEC,ANSI", 2 },
        { "stecker",         "Stecker",                 "klemmen",        "IEC,ANSI", 2 },
        { "buchse",          "Buchse",                  "klemmen",        "IEC,ANSI", 2 },
        // SPS/PLS-Baugruppen
        { "sps_di_8",  "DI-Baugruppe 8-Kanal",     "sps_pls", "IEC,ANSI", 8  },
        { "sps_di_16", "DI-Baugruppe 16-Kanal",    "sps_pls", "IEC,ANSI", 16 },
        { "sps_do_8",  "DO-Baugruppe 8-Kanal",     "sps_pls", "IEC,ANSI", 8  },
        { "sps_do_16", "DO-Baugruppe 16-Kanal",    "sps_pls", "IEC,ANSI", 16 },
        { "sps_ai_4",  "AI-Baugruppe 4-Kanal",     "sps_pls", "IEC,ANSI", 4  },
        { "sps_ai_8",  "AI-Baugruppe 8-Kanal",     "sps_pls", "IEC,ANSI", 8  },
        { "sps_ao_4",  "AO-Baugruppe 4-Kanal",     "sps_pls", "IEC,ANSI", 4  },
        { "sps_cpu",   "CPU-Baugruppe",            "sps_pls", "IEC,ANSI", 2  },
        { "pls_ai_8",  "PLS AI-Baugruppe 8-Kanal", "sps_pls", "IEC,ANSI", 8  },
        { "pls_ao_4",  "PLS AO-Baugruppe 4-Kanal", "sps_pls", "IEC,ANSI", 4  },
        // KFZ-Elektrik
        { "kfz_sicherung",    "Flachstecksicherung",       "kfz", "IEC,ANSI", 2 },
        { "kfz_relais_4",     "KFZ-Relais 4-polig",        "kfz", "IEC,ANSI", 4 },
        { "kfz_relais_5",     "KFZ-Relais 5-polig",        "kfz", "IEC,ANSI", 5 },
        { "kfz_masse",        "Fahrzeugmasse (GND)",        "kfz", "IEC,ANSI", 1 },
        { "kfz_batterie",     "Batterie 12V",               "kfz", "IEC,ANSI", 2 },
        { "kfz_lichtmaschine","Lichtmaschine (Generator)",  "kfz", "IEC,ANSI", 2 },
        { "kfz_stecker_2",    "KFZ-Stecker 2-polig",        "kfz", "IEC,ANSI", 2 },
        { "kfz_stecker_3",    "KFZ-Stecker 3-polig",        "kfz", "IEC,ANSI", 3 },
        { "kfz_stecker_4",    "KFZ-Stecker 4-polig",        "kfz", "IEC,ANSI", 4 },
        // Arduino
        { "ard_uno",    "Arduino UNO",    "arduino", "IEC,ANSI", 27 },
        { "ard_nano",   "Arduino Nano",   "arduino", "IEC,ANSI", 28 },
        { "ard_mega",   "Arduino Mega",   "arduino", "IEC,ANSI", 40 },
        { "ard_dht",    "DHT Sensor",     "arduino", "IEC,ANSI",  3 },
        { "ard_hcsr04", "HC-SR04 Sensor", "arduino", "IEC,ANSI",  4 },
        { "ard_pir",    "PIR Sensor",     "arduino", "IEC,ANSI",  3 },
        // Sensoren
        { "sensor_induktiv",   "Induktiver Näherungsschalter",  "sensoren", "IEC,ANSI", 3 },
        { "sensor_kapazitiv",  "Kapazitiver Näherungsschalter", "sensoren", "IEC,ANSI", 3 },
        { "sensor_optisch",    "Optischer Sensor",              "sensoren", "IEC,ANSI", 3 },
        { "sensor_ultraschall","Ultraschallsensor",             "sensoren", "IEC,ANSI", 3 },
        { "sensor_druck",      "Drucksensor",                   "sensoren", "IEC,ANSI", 3 },
        { "sensor_temp",       "Temperatursensor (PT100)",       "sensoren", "IEC,ANSI", 2 },
    };

    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO symbol (code, name, kategorie_pfad, norm, anschluesse)
        VALUES (:code, :name, :kat, :norm, :anschl)
    )");

    for (const Sym &s : symbole) {
        q.bindValue(":code",   s.code);
        q.bindValue(":name",   s.name);
        q.bindValue(":kat",    s.kat);
        q.bindValue(":norm",   s.norm);
        q.bindValue(":anschl", s.anschluesse);
        if (!q.exec()) {
            qWarning() << "seedSymbolKatalog:" << s.code << q.lastError().text();
            return false;
        }
    }

    qInfo() << "Symbol-Katalog befüllt:" << symbole.size() << "Symbole.";

    // ----------------------------------------------------------
    // Vordefinierte Gehäusefarben (farb_definition, ist_standard=1)
    // ----------------------------------------------------------
    struct Farbe { QString hex; QString bez; int sort; };
    const QList<Farbe> farben = {
        { "#808080", "Grau",                         1 },
        { "#0000CC", "Blau \u2013 N-Leiter (DIN VDE 0100)",          2 },
        { "#66AAFF", "Blau \u2013 Eigensicher (IEC 60079-14)",        3 },
        { "#3366CC", "Blau \u2013 ohne Definition",                   4 },
        { "#88AA00", "Gr\u00fcn-Gelb \u2013 PE (normverpflichtend)",  5 },
        { "#FF8800", "Orange \u2013 Trennstelle / Potenzialgruppe",   6 },
        { "#CC0000", "Rot \u2013 L-Leiter / Sonderkreis",            7 },
        { "#222222", "Schwarz \u2013 L-Leiter (\u00e4ltere Norm)",    8 },
        { "#EEEEEE", "Wei\u00df \u2013 Sonderkreis",                  9 },
        { "#FFCC00", "Gelb \u2013 Sicherheitskreis",                 10 },
        { "#E8D8B0", "Beige \u2013 \u00e4ltere Installation",         11 },
        // DIN 72551 KFZ-Leitungsfarben
        { "#CC0000", "Rot - DIN 72551 (rt)",     100 },
        { "#222222", "Schwarz - DIN 72551 (sw)", 101 },
        { "#FFCC00", "Gelb - DIN 72551 (ge)",    102 },
        { "#663300", "Braun - DIN 72551 (br)",   103 },
        { "#0044CC", "Blau - DIN 72551 (bl)",    104 },
        { "#228B22", "Gruen - DIN 72551 (gn)",   105 },
        { "#888888", "Grau - DIN 72551 (gr)",    106 },
        { "#EEEEEE", "Weiss - DIN 72551 (ws)",   107 },
        { "#8B008B", "Violett - DIN 72551 (vi)", 108 },
        { "#FF6600", "Orange - DIN 72551 (or)",  109 },
    };

    QSqlQuery fq;
    fq.prepare("INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) "
               "VALUES (:hex, :bez, 1, :sort)");
    for (const Farbe &f : farben) {
        fq.bindValue(":hex",  f.hex);
        fq.bindValue(":bez",  f.bez);
        fq.bindValue(":sort", f.sort);
        if (!fq.exec()) {
            qWarning() << "seedFarbDefinition:" << f.bez << fq.lastError().text();
            return false;
        }
    }
    qInfo() << "Farb-Katalog befüllt:" << farben.size() << "Einträge.";

    return true;
}

// ============================================================
// seedBuiltinSymbolDefinitionen
// Liest src/database/symbole.sql als Qt-Ressource ein und führt
// alle darin enthaltenen INSERT-Statements aus.
// Läuft innerhalb der äußeren Transaktion von initDatabase().
// ============================================================
bool Database::seedBuiltinSymbolDefinitionen()
{
    QFile f(QStringLiteral(":/database/symbole.sql"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "seedBuiltinSymbolDefinitionen: symbole.sql nicht gefunden (:/database/symbole.sql)";
        return false;
    }
    const QString sql = QString::fromUtf8(f.readAll());
    f.close();

    // Kommentarzeilen entfernen, damit kein Statement nach dem Semikolon-Split
    // fälschlicherweise mit "--" beginnt und übersprungen wird.
    QStringList cleanLines;
    for (const QString &line : sql.split(QLatin1Char('\n'))) {
        if (!line.trimmed().startsWith(QLatin1String("--")))
            cleanLines << line;
    }
    const QString cleanSql = cleanLines.join(QLatin1Char('\n'));

    QSqlQuery q(m_db);
    const QStringList statements = cleanSql.split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (const QString &raw : statements) {
        const QString stmt = raw.trimmed();
        if (stmt.isEmpty())
            continue;
        if (!q.exec(stmt)) {
            qWarning() << "seedBuiltinSymbolDefinitionen:" << q.lastError().text()
                       << "\nStatement:" << stmt.left(120);
            return false;
        }
    }

    qInfo() << "Builtin-Symboldefinitionen aus symbole.sql geladen.";
    return true;
}
