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

        // v53: Fehlende Spalten und SPS-Tabellen nachgezogen (waren im Baseline-Squash nicht enthalten)
        { 53, "Nachzug: gruppe_id, revision_spalten, SPS-Tabellen", {
            // grafik_element: Gruppierfunktion
            "ALTER TABLE grafik_element ADD COLUMN gruppe_id INTEGER DEFAULT NULL",
            // seite: Revisionsspalten
            "ALTER TABLE seite ADD COLUMN revision_status  TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE seite ADD COLUMN revision_kennung TEXT NOT NULL DEFAULT ''",
            // SPS-Rack
            R"(CREATE TABLE sps_rack (
                id           INTEGER PRIMARY KEY,
                projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
                rack_nr      INTEGER NOT NULL DEFAULT 0,
                system_typ   TEXT    NOT NULL DEFAULT 'SPS',
                bezeichnung  TEXT    NOT NULL DEFAULT '',
                beschreibung TEXT,
                hersteller   TEXT,
                sortierung   INTEGER NOT NULL DEFAULT 0
            ))",
            // SPS-Baugruppe
            R"(CREATE TABLE sps_baugruppe (
                id                INTEGER PRIMARY KEY,
                rack_id           INTEGER NOT NULL REFERENCES sps_rack(id) ON DELETE CASCADE,
                slot              INTEGER NOT NULL DEFAULT 0,
                typ               TEXT    NOT NULL DEFAULT '',
                bezeichnung       TEXT,
                artikel_nr        TEXT,
                kanaele           INTEGER NOT NULL DEFAULT 8,
                datentyp_standard TEXT    NOT NULL DEFAULT 'BOOL',
                adress_byte_start INTEGER NOT NULL DEFAULT 0,
                kommentar         TEXT
            ))",
            // SPS-Kanal
            R"(CREATE TABLE sps_kanal (
                id                INTEGER PRIMARY KEY,
                projekt_id        INTEGER NOT NULL REFERENCES projekt(id)       ON DELETE CASCADE,
                baugruppe_id      INTEGER          REFERENCES sps_baugruppe(id) ON DELETE SET NULL,
                kanal_nr          INTEGER,
                adress_typ        TEXT    NOT NULL DEFAULT 'I',
                byte_nr           INTEGER NOT NULL DEFAULT 0,
                bit_nr            INTEGER NOT NULL DEFAULT 0,
                datentyp          TEXT    NOT NULL DEFAULT 'BOOL',
                variablenname     TEXT,
                kommentar         TEXT,
                grafik_element_id INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
                pls_einheit       TEXT,
                pls_bereich_min   REAL,
                pls_bereich_max   REAL,
                pls_alarm_ll      REAL,
                pls_alarm_lo      REAL,
                pls_alarm_hi      REAL,
                pls_alarm_hh      REAL,
                pls_hart_adresse  INTEGER,
                pls_protokoll     TEXT
            ))",
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
    QSqlQuery q(m_db);

    // ----------------------------------------------------------
    // Normblatt Vorlage
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE normblatt_vorlage (
            id              INTEGER PRIMARY KEY,
            name            TEXT NOT NULL,
            beschreibung    TEXT,
            ist_standard    INTEGER DEFAULT 0,
            breite_mm       REAL NOT NULL DEFAULT 297,
            hoehe_mm        REAL NOT NULL DEFAULT 210,
            rand_links_mm   REAL DEFAULT 20,
            rand_rechts_mm  REAL DEFAULT 10,
            rand_oben_mm    REAL DEFAULT 10,
            rand_unten_mm   REAL DEFAULT 10,
            logo_data       BLOB,
            logo_mime       TEXT,
            logo_x_mm       REAL,
            logo_y_mm       REAL,
            logo_breite_mm  REAL,
            logo_hoehe_mm   REAL,
            schriftart      TEXT DEFAULT 'Arial'
        )
    )")) {
        qWarning() << "Fehler normblatt_vorlage:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Normblatt Felder
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE normblatt_feld (
            id             INTEGER PRIMARY KEY,
            vorlage_id     INTEGER NOT NULL REFERENCES normblatt_vorlage(id) ON DELETE CASCADE,
            feldtyp        TEXT NOT NULL DEFAULT 'fest',
            x_mm           REAL NOT NULL DEFAULT 0,
            y_mm           REAL NOT NULL DEFAULT 0,
            breite_mm      REAL NOT NULL DEFAULT 50,
            hoehe_mm       REAL NOT NULL DEFAULT 13,
            label          TEXT,
            inhalt         TEXT,
            quelle_spalte  TEXT,
            schriftgroesse REAL NOT NULL DEFAULT 3.5,
            fett           INTEGER NOT NULL DEFAULT 0,
            rahmen         INTEGER NOT NULL DEFAULT 1,
            reihenfolge    INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler normblatt_feld:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Projekt
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE projekt (
            id              INTEGER PRIMARY KEY,
            name            TEXT NOT NULL,
            projektnummer   TEXT,
            auftraggeber    TEXT,
            auftragnehmer   TEXT,
            bearbeiter      TEXT,
            logo_data       BLOB,
            logo_mime       TEXT,
            erstellt_am     TEXT DEFAULT (datetime('now')),
            geaendert_am    TEXT DEFAULT (datetime('now')),
            werk            TEXT,
            abteilung       TEXT,
            normblatt_id    INTEGER REFERENCES normblatt_vorlage(id),
            status          TEXT DEFAULT 'in_bearbeitung',
            bemerkung       TEXT,
            norm                TEXT NOT NULL DEFAULT 'IEC',
            canvas_hintergrund  TEXT NOT NULL DEFAULT '#080f1c'
        )
    )")) {
        qWarning() << "Fehler projekt:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Changelog
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE changelog (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
            version         TEXT NOT NULL,
            datum           TEXT NOT NULL DEFAULT (date('now')),
            autor           TEXT,
            aenderung       TEXT NOT NULL,
            aenderungstyp   TEXT DEFAULT 'aenderung'
        )
    )")) {
        qWarning() << "Fehler changelog:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Seitenbaum
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE anlage (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
            kuerzel         TEXT NOT NULL,
            bezeichnung     TEXT NOT NULL,
            sortierung      INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler anlage:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE ort (
            id              INTEGER PRIMARY KEY,
            anlage_id       INTEGER NOT NULL REFERENCES anlage(id),
            kuerzel         TEXT NOT NULL,
            bezeichnung     TEXT NOT NULL,
            sortierung      INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler ort:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE seite (
            id              INTEGER PRIMARY KEY,
            ort_id          INTEGER REFERENCES ort(id),
            parent_id       INTEGER REFERENCES seite(id),
            werk            TEXT,
            anlage_kuerzel  TEXT,
            ort_kuerzel     TEXT,
            blattnummer     TEXT NOT NULL,
            bezeichnung     TEXT,
            seitentyp       TEXT DEFAULT 'schaltplan',
            breite_mm       REAL DEFAULT 297,
            hoehe_mm        REAL DEFAULT 210,
            rand_links_mm   REAL DEFAULT 20,
            rand_rechts_mm  REAL DEFAULT 10,
            rand_oben_mm    REAL DEFAULT 10,
            rand_unten_mm   REAL DEFAULT 10,
            ausrichtung     TEXT DEFAULT 'quer',
            normblatt_id         INTEGER REFERENCES normblatt_vorlage(id),
            normblatt_anzeigen   INTEGER NOT NULL DEFAULT 0,
            hintergrund_farbe    TEXT    NOT NULL DEFAULT '',
            aussen_overlay       INTEGER NOT NULL DEFAULT 0,
            titelblatt_vorlage   TEXT    NOT NULL DEFAULT 'din6771',
            sortierung           INTEGER DEFAULT 0,
            gesperrt          INTEGER DEFAULT 0,
            bemerkung         TEXT,
            raster_mm         REAL NOT NULL DEFAULT 4.0,
            rastend           INTEGER NOT NULL DEFAULT 1,
            revision_status   TEXT NOT NULL DEFAULT '',
            revision_kennung  TEXT NOT NULL DEFAULT ''
        )
    )")) {
        qWarning() << "Fehler seite:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Grafik-Elemente (Linie / Rechteck / Kreis / Symbol als Zeichenobjekte)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE grafik_element (
            id              INTEGER PRIMARY KEY,
            seite_id        INTEGER NOT NULL REFERENCES seite(id) ON DELETE CASCADE,
            typ             TEXT NOT NULL,
            x1              REAL NOT NULL DEFAULT 0,
            y1              REAL NOT NULL DEFAULT 0,
            x2              REAL NOT NULL DEFAULT 0,
            y2              REAL NOT NULL DEFAULT 0,
            strich_farbe    TEXT NOT NULL DEFAULT '#4a9eff',
            strich_breite   REAL NOT NULL DEFAULT 1.5,
            strich_art      TEXT NOT NULL DEFAULT 'solid',
            fuell           INTEGER NOT NULL DEFAULT 0,
            fuell_farbe     TEXT NOT NULL DEFAULT '#1a3a6a',
            fuell_opazitaet REAL NOT NULL DEFAULT 0.3,
            opazitaet       REAL NOT NULL DEFAULT 1.0,
            ecken_radius    REAL NOT NULL DEFAULT 0,
            sortierung      INTEGER NOT NULL DEFAULT 0,
            symbol_id       TEXT,
            rotation        INTEGER NOT NULL DEFAULT 0,
            spiegel_x       INTEGER NOT NULL DEFAULT 0,
            spiegel_y       INTEGER NOT NULL DEFAULT 0,
            punkte          TEXT DEFAULT NULL,
            text_inhalt     TEXT DEFAULT NULL,
            text_ausrichtung TEXT DEFAULT 'links',
            text_einpassen  INTEGER NOT NULL DEFAULT 0,
            bild_daten          BLOB DEFAULT NULL,
            bild_mime           TEXT DEFAULT NULL,
            extra_daten         TEXT DEFAULT NULL,
            betriebsmittel_id   INTEGER REFERENCES betriebsmittel(id),
            gruppe_id           INTEGER DEFAULT NULL
        )
    )")) {
        qWarning() << "Fehler grafik_element:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Symbole (eingebauter Katalog)
    // norm: "IEC", "ANSI" oder "IEC,ANSI" → Abfrage via instr()
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE symbol (
            id              INTEGER PRIMARY KEY,
            code            TEXT NOT NULL UNIQUE,
            name            TEXT NOT NULL,
            kategorie_pfad  TEXT NOT NULL DEFAULT '',
            norm            TEXT NOT NULL DEFAULT 'IEC',
            favorit         INTEGER NOT NULL DEFAULT 0,
            anschluesse     INTEGER DEFAULT 2,
            origin_x        REAL DEFAULT 0,
            origin_y        REAL DEFAULT 0,
            svg_data        TEXT
        )
    )")) {
        qWarning() << "Fehler symbol:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE symbol_anschluss (
            id          INTEGER PRIMARY KEY,
            symbol_id   INTEGER NOT NULL REFERENCES symbol(id),
            bezeichnung TEXT NOT NULL,
            x_pos       REAL,
            y_pos       REAL,
            typ         TEXT,
            richtung    TEXT
        )
    )")) {
        qWarning() << "Fehler symbol_anschluss:" << q.lastError().text();
        return false;
    }

    // Textfelder die auf einem Symbol platziert werden können.
    // Die Werte (z.B. Betriebsmittelkennzeichen, Typ) kommen zur
    // Laufzeit aus der Bauteil-/Betriebsmittelstruktur; hier steht
    // nur wo und wie sie dargestellt werden.
    if (!q.exec(R"(
        CREATE TABLE symbol_textfeld (
            id          INTEGER PRIMARY KEY,
            symbol_id   INTEGER NOT NULL REFERENCES symbol(id),
            feldname    TEXT NOT NULL,
            x           REAL NOT NULL DEFAULT 0,
            y           REAL NOT NULL DEFAULT 0,
            rotation    INTEGER NOT NULL DEFAULT 0,
            ausrichtung TEXT NOT NULL DEFAULT 'links'
        )
    )")) {
        qWarning() << "Fehler symbol_textfeld:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Primitiv-Symbolsystem (Phase A Symboleditor)
    // Alle Symbole als Primitiv-Listen – ersetzt langfristig symbole.js/pinkatalog.js
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE symbol_definition (
            id             TEXT    PRIMARY KEY,
            name           TEXT    NOT NULL,
            kategorie      TEXT,
            breite_mm      INTEGER NOT NULL DEFAULT 16,
            hoehe_mm       INTEGER NOT NULL DEFAULT 16,
            rolle          TEXT    NOT NULL DEFAULT 'durchleiter',
            ist_builtin    INTEGER NOT NULL DEFAULT 0,
            ibn_kategorie  TEXT    NOT NULL DEFAULT ''
        )
    )")) {
        qWarning() << "Fehler symbol_definition:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE symbol_primitiv (
            id                    INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol_id             TEXT    NOT NULL REFERENCES symbol_definition(id) ON DELETE CASCADE,
            reihenfolge           INTEGER NOT NULL DEFAULT 0,
            typ                   TEXT    NOT NULL,
            x1                    REAL,
            y1                    REAL,
            x2                    REAL,
            y2                    REAL,
            x3                    REAL,
            y3                    REAL,
            radius                REAL,
            winkel_von            REAL,
            winkel_bis            REAL,
            bogen_gegen_uhrzeiger INTEGER DEFAULT 0,
            text_inhalt           TEXT,
            schrift_relativ       REAL    DEFAULT 0.5,
            schrift_fett          INTEGER DEFAULT 0,
            text_align            TEXT    DEFAULT 'center',
            text_baseline         TEXT    DEFAULT 'middle',
            linienart             TEXT    DEFAULT 'solid'
        )
    )")) {
        qWarning() << "Fehler symbol_primitiv:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE symbol_pin (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol_id  TEXT    NOT NULL REFERENCES symbol_definition(id) ON DELETE CASCADE,
            name       TEXT    NOT NULL,
            x          REAL    NOT NULL,
            y          REAL    NOT NULL,
            offen_x    REAL    NOT NULL,
            offen_y    REAL    NOT NULL,
            signaltyp  TEXT    NOT NULL DEFAULT 'neutral',
            kontext    TEXT
        )
    )")) {
        qWarning() << "Fehler symbol_pin:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Bauteil-Datenbank
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE bauteil_kategorie (
            id          INTEGER PRIMARY KEY,
            name        TEXT NOT NULL,
            parent_id   INTEGER REFERENCES bauteil_kategorie(id),
            sortierung  INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler bauteil_kategorie:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil (
            id              INTEGER PRIMARY KEY,
            kategorie_id    INTEGER REFERENCES bauteil_kategorie(id),
            bezeichnung     TEXT NOT NULL,
            hersteller      TEXT,
            artikelnummer   TEXT,
            artikelnummer_2 TEXT,
            lieferant       TEXT,
            bestellnummer   TEXT,
            preis_eur       REAL,
            spannung_v      REAL,
            strom_a         REAL,
            leistung_w      REAL,
            schutzart       TEXT,
            norm            TEXT,
            symbol_code     TEXT,
            bmk_vorlage     TEXT,
            bemerkung       TEXT,
            bild_data       BLOB,
            bild_mime       TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Klemmen-Physik (Schema v8) – projektübergreifende Bibliothek
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE farb_definition (
            id           INTEGER PRIMARY KEY,
            hex_wert     TEXT,
            bezeichnung  TEXT NOT NULL,
            ist_standard INTEGER DEFAULT 0,
            sortierung   INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler farb_definition:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme (
            id                 INTEGER PRIMARY KEY,
            bauteil_id         INTEGER NOT NULL REFERENCES bauteil(id),
            norm               TEXT,
            anschluss_typ      TEXT NOT NULL,
            ebenen_anzahl      INTEGER NOT NULL DEFAULT 1,
            punkte_seite_a     INTEGER NOT NULL DEFAULT 1,
            punkte_seite_b     INTEGER NOT NULL DEFAULT 1,
            fuss_kontakt_pe    INTEGER DEFAULT 0,
            stegbruecke_faehig INTEGER DEFAULT 0,
            breite_mm          REAL,
            gehaeuse_farbe_id  INTEGER REFERENCES farb_definition(id),
            bemerkung          TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme_querschnitt (
            id        INTEGER PRIMARY KEY,
            klemme_id INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            adertyp   TEXT NOT NULL,
            min_mm2   REAL NOT NULL,
            max_mm2   REAL NOT NULL
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme_querschnitt:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme_bruecke (
            id          INTEGER PRIMARY KEY,
            klemme_id   INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            von_ebene   INTEGER NOT NULL,
            nach_ebene  INTEGER NOT NULL,
            ist_pe_fuss INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme_bruecke:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme_eigenschaft (
            id           INTEGER PRIMARY KEY,
            klemme_id    INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            schluessel   TEXT NOT NULL,
            wert         TEXT NOT NULL,
            beschreibung TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme_eigenschaft:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Kabel-Bibliothek (Bauteilkatalog-Erweiterung)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE bauteil_kabel (
            id                  INTEGER PRIMARY KEY,
            bauteil_id          INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            kabeltyp            TEXT,
            geschirmt           INTEGER NOT NULL DEFAULT 0,
            paarweise_verdrillt INTEGER NOT NULL DEFAULT 0,
            aussenmantel_farbe  TEXT,
            aussenmantel_mm     REAL,
            material_leiter     TEXT,
            material_isolierung TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil_kabel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_kabel_ader (
            id              INTEGER PRIMARY KEY,
            kabel_id        INTEGER NOT NULL REFERENCES bauteil_kabel(id) ON DELETE CASCADE,
            ader_nr         INTEGER NOT NULL,
            farbe           TEXT,
            nummer          TEXT,
            bezeichnung     TEXT,
            querschnitt_mm2 REAL
        )
    )")) {
        qWarning() << "Fehler bauteil_kabel_ader:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_kabel_paar (
            id       INTEGER PRIMARY KEY,
            kabel_id INTEGER NOT NULL REFERENCES bauteil_kabel(id) ON DELETE CASCADE,
            paar_nr  INTEGER NOT NULL,
            ader_a   INTEGER NOT NULL,
            ader_b   INTEGER NOT NULL
        )
    )")) {
        qWarning() << "Fehler bauteil_kabel_paar:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Betriebsmittel
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE betriebsmittel (
            id                      INTEGER PRIMARY KEY,
            projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
            bauteil_id              INTEGER REFERENCES bauteil(id),
            symbol_code             TEXT,
            anlage_uebergeordnet    TEXT,
            standort_uebergeordnet  TEXT,
            funktion                TEXT,
            einbauort               TEXT,
            betriebsmittel_kz       TEXT NOT NULL,
            bezeichnung             TEXT,
            bemerkung               TEXT,
            haupt_element_id        INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
        )
    )")) {
        qWarning() << "Fehler betriebsmittel:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Verbindungen & Querverweise
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE verbindung (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
            bezeichnung     TEXT,
            farbe           TEXT,
            querschnitt_mm2 REAL,
            potenzial       TEXT,
            signaltyp       TEXT NOT NULL DEFAULT 'neutral'
        )
    )")) {
        qWarning() << "Fehler verbindung:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE verbindung_segment (
            id                  INTEGER PRIMARY KEY,
            verbindung_id       INTEGER NOT NULL REFERENCES verbindung(id),
            seite_id            INTEGER NOT NULL REFERENCES seite(id),
            von_anschluss_id    INTEGER,
            nach_anschluss_id   INTEGER,
            punkte              TEXT
        )
    )")) {
        qWarning() << "Fehler verbindung_segment:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE querverweis (
            id                  INTEGER PRIMARY KEY,
            verbindung_id       INTEGER NOT NULL REFERENCES verbindung(id),
            von_seite_id        INTEGER NOT NULL REFERENCES seite(id),
            nach_seite_id       INTEGER NOT NULL REFERENCES seite(id),
            von_bezeichnung     TEXT,
            nach_bezeichnung    TEXT
        )
    )")) {
        qWarning() << "Fehler querverweis:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Kabel
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE kabel (
            id                  INTEGER PRIMARY KEY,
            projekt_id          INTEGER NOT NULL REFERENCES projekt(id),
            bezeichnung         TEXT NOT NULL,
            kabeltyp            TEXT,
            aderzahl            INTEGER,
            querschnitt_mm2     REAL,
            laenge_m            REAL,
            farbe_mantel        TEXT,
            von_ort             TEXT,
            nach_ort            TEXT,
            bemerkung           TEXT,
            bauteil_kabel_id    INTEGER REFERENCES bauteil_kabel(id) ON DELETE SET NULL,
            grafik_element_id   INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
        )
    )")) {
        qWarning() << "Fehler kabel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE kabel_ader (
            id                              INTEGER PRIMARY KEY,
            kabel_id                        INTEGER NOT NULL REFERENCES kabel(id),
            ader_nr                         INTEGER NOT NULL,
            farbe                           TEXT,
            bezeichnung                     TEXT,
            verbindung_id                   INTEGER REFERENCES verbindung(id),
            kabellinie_grafik_element_id    INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
            von_gerat_pin                   TEXT,
            nach_gerat_pin                  TEXT
        )
    )")) {
        qWarning() << "Fehler kabel_ader:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Klemmen
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE klemmenleiste (
            id                      INTEGER PRIMARY KEY,
            projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
            ort_id                  INTEGER REFERENCES ort(id),
            bezeichnung             TEXT NOT NULL,
            ausrichtung             TEXT NOT NULL DEFAULT 'senkrecht',
            anlage_uebergeordnet    TEXT,
            standort_uebergeordnet  TEXT,
            bemerkung               TEXT
        )
    )")) {
        qWarning() << "Fehler klemmenleiste:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE klemme (
            id                  INTEGER PRIMARY KEY,
            klemmenleiste_id    INTEGER NOT NULL REFERENCES klemmenleiste(id),
            bauteil_id          INTEGER REFERENCES bauteil(id),
            nummer              TEXT NOT NULL DEFAULT '',
            sortierung          INTEGER DEFAULT 0,
            bemerkung           TEXT
        )
    )")) {
        qWarning() << "Fehler klemme:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE klemme_stegbruecke (
            id               INTEGER PRIMARY KEY,
            klemmenleiste_id INTEGER NOT NULL REFERENCES klemmenleiste(id),
            ebene            INTEGER NOT NULL DEFAULT 1,
            von_klemme_id    INTEGER NOT NULL REFERENCES klemme(id),
            bis_klemme_id    INTEGER NOT NULL REFERENCES klemme(id),
            verbindung_id    INTEGER REFERENCES verbindung(id),
            potenzial_text   TEXT,
            hat_konflikt     INTEGER DEFAULT 0,
            konflikt_text    TEXT
        )
    )")) {
        qWarning() << "Fehler klemme_stegbruecke:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Leiter (Einzeladern ohne Kabelmantel)
    // Muss vor klemme_anschluss kommen – klemme_anschluss referenziert leiter!
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE leiter (
            id                  INTEGER PRIMARY KEY,
            projekt_id          INTEGER NOT NULL REFERENCES projekt(id),
            verbindung_id       INTEGER REFERENCES verbindung(id),
            bezeichnung         TEXT,
            farbe               TEXT,
            querschnitt_mm2     REAL,
            von_anschluss_id    INTEGER,
            nach_anschluss_id   INTEGER,
            von_freitext        TEXT,
            nach_freitext       TEXT,
            kabel_ader_id       INTEGER REFERENCES kabel_ader(id),
            bemerkung           TEXT
        )
    )")) {
        qWarning() << "Fehler leiter:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE klemme_anschluss (
            id              INTEGER PRIMARY KEY,
            klemme_id       INTEGER NOT NULL REFERENCES klemme(id),
            bezeichnung     TEXT NOT NULL,
            seite           TEXT,
            verbindung_id   INTEGER REFERENCES verbindung(id),
            leiter_id       INTEGER REFERENCES leiter(id),
            sortierung      INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler klemme_anschluss:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Views
    // ----------------------------------------------------------
    if (!q.exec(
        "CREATE VIEW seite_kennzeichen AS "
        "SELECT s.id, s.bezeichnung, s.blattnummer, s.seitentyp, "
        "s.breite_mm, s.hoehe_mm, s.sortierung, s.parent_id, "
        "COALESCE('=' || s.anlage_kuerzel, '') || "
        "COALESCE('+' || s.ort_kuerzel, '') || "
        "'/' || s.blattnummer AS vollkennzeichen FROM seite s"
    )) {
        qWarning() << "Fehler View seite_kennzeichen:" << q.lastError().text();
        return false;
    }

    if (!q.exec(
        "CREATE VIEW betriebsmittel_bmk AS "
        "SELECT id, bezeichnung, "
        "COALESCE('==' || anlage_uebergeordnet, '') || "
        "COALESCE('++' || standort_uebergeordnet, '') || "
        "COALESCE('=' || funktion, '') || "
        "COALESCE('+' || einbauort, '') || "
        "'-' || betriebsmittel_kz AS bmk_vollstaendig, "
        "COALESCE('=' || funktion, '') || "
        "COALESCE('+' || einbauort, '') || "
        "'-' || betriebsmittel_kz AS bmk_kurz "
        "FROM betriebsmittel"
    )) {
        qWarning() << "Fehler View betriebsmittel_bmk:" << q.lastError().text();
        return false;
    }

    if (!q.exec(
        "CREATE VIEW klemmenleiste_bmk AS "
        "SELECT kl.id, kl.bezeichnung, kl.projekt_id, "
        "COALESCE('==' || kl.anlage_uebergeordnet, '') || "
        "COALESCE('++' || kl.standort_uebergeordnet, '') || "
        "COALESCE('=' || a.kuerzel, '') || "
        "COALESCE('+' || o.kuerzel, '') || "
        "'-' || kl.bezeichnung AS bmk_vollstaendig, "
        "COALESCE('=' || a.kuerzel, '') || "
        "COALESCE('+' || o.kuerzel, '') || "
        "'-' || kl.bezeichnung AS bmk_kurz "
        "FROM klemmenleiste kl "
        "LEFT JOIN ort o ON o.id = kl.ort_id "
        "LEFT JOIN anlage a ON a.id = o.anlage_id"
    )) {
        qWarning() << "Fehler View klemmenleiste_bmk:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Inbetriebnahme-Modus (Schema v33)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE inbetriebnahme (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
            seite_id        INTEGER REFERENCES seite(id) ON DELETE CASCADE,
            bmk             TEXT    NOT NULL,
            bauteil_id      TEXT    DEFAULT '',
            symbol_kategorie TEXT   DEFAULT '',
            status          TEXT    NOT NULL DEFAULT 'offen',
            geprueft_von    TEXT    DEFAULT '',
            geprueft_am     TEXT    DEFAULT '',
            notiz           TEXT    DEFAULT '',
            erstellt_am     TEXT    DEFAULT (datetime('now')),
            UNIQUE (seite_id, bmk)
        )
    )")) {
        qWarning() << "Fehler inbetriebnahme:" << q.lastError().text();
        return false;
    }

    // Schema v35: Feldvorlagen für kategorieabhängige Messwerte
    if (!q.exec(R"(
        CREATE TABLE ibn_feldvorlage (
            id               INTEGER PRIMARY KEY,
            symbol_kategorie TEXT    NOT NULL,
            feldname         TEXT    NOT NULL,
            label            TEXT    NOT NULL,
            feldtyp          TEXT    NOT NULL DEFAULT 'text',
            optionen         TEXT    DEFAULT '',
            einheit          TEXT    DEFAULT '',
            pflichtfeld      INTEGER NOT NULL DEFAULT 0,
            reihenfolge      INTEGER NOT NULL DEFAULT 0,
            erstellt_von     TEXT    NOT NULL DEFAULT 'system',
            UNIQUE(symbol_kategorie, feldname)
        )
    )")) {
        qWarning() << "Fehler ibn_feldvorlage:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE ibn_feldwert (
            id                INTEGER PRIMARY KEY,
            inbetriebnahme_id INTEGER NOT NULL REFERENCES inbetriebnahme(id) ON DELETE CASCADE,
            feldname          TEXT    NOT NULL,
            wert              TEXT    DEFAULT '',
            UNIQUE(inbetriebnahme_id, feldname)
        )
    )")) {
        qWarning() << "Fehler ibn_feldwert:" << q.lastError().text();
        return false;
    }

    // Schema v34: IBN-Status pro Kabel
    if (!q.exec(R"(
        CREATE TABLE ibn_kabel (
            id           INTEGER PRIMARY KEY,
            projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
            kabel_id     INTEGER NOT NULL REFERENCES kabel(id)   ON DELETE CASCADE,
            status       TEXT    NOT NULL DEFAULT 'offen',
            geprueft_von TEXT    DEFAULT '',
            geprueft_am  TEXT    DEFAULT '',
            notiz        TEXT    DEFAULT '',
            UNIQUE(kabel_id)
        )
    )")) {
        qWarning() << "Fehler ibn_kabel:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // SPS / PLS-Integration
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE sps_rack (
            id           INTEGER PRIMARY KEY,
            projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
            rack_nr      INTEGER NOT NULL DEFAULT 0,
            system_typ   TEXT    NOT NULL DEFAULT 'SPS',
            bezeichnung  TEXT    NOT NULL DEFAULT '',
            beschreibung TEXT,
            hersteller   TEXT,
            sortierung   INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler sps_rack:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE sps_baugruppe (
            id                INTEGER PRIMARY KEY,
            rack_id           INTEGER NOT NULL REFERENCES sps_rack(id) ON DELETE CASCADE,
            slot              INTEGER NOT NULL DEFAULT 0,
            typ               TEXT    NOT NULL DEFAULT '',
            bezeichnung       TEXT,
            artikel_nr        TEXT,
            kanaele           INTEGER NOT NULL DEFAULT 8,
            datentyp_standard TEXT    NOT NULL DEFAULT 'BOOL',
            adress_byte_start INTEGER NOT NULL DEFAULT 0,
            kommentar         TEXT
        )
    )")) {
        qWarning() << "Fehler sps_baugruppe:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE sps_kanal (
            id                INTEGER PRIMARY KEY,
            projekt_id        INTEGER NOT NULL REFERENCES projekt(id)       ON DELETE CASCADE,
            baugruppe_id      INTEGER          REFERENCES sps_baugruppe(id) ON DELETE SET NULL,
            kanal_nr          INTEGER,
            adress_typ        TEXT    NOT NULL DEFAULT 'I',
            byte_nr           INTEGER NOT NULL DEFAULT 0,
            bit_nr            INTEGER NOT NULL DEFAULT 0,
            datentyp          TEXT    NOT NULL DEFAULT 'BOOL',
            variablenname     TEXT,
            kommentar         TEXT,
            grafik_element_id INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
            pls_einheit       TEXT,
            pls_bereich_min   REAL,
            pls_bereich_max   REAL,
            pls_alarm_ll      REAL,
            pls_alarm_lo      REAL,
            pls_alarm_hi      REAL,
            pls_alarm_hh      REAL,
            pls_hart_adresse  INTEGER,
            pls_protokoll     TEXT
        )
    )")) {
        qWarning() << "Fehler sps_kanal:" << q.lastError().text();
        return false;
    }

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
