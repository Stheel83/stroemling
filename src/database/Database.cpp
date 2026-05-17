#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <QPrinter>
#include <QTextDocument>
#include <algorithm>

Database::Database(QObject *parent)
    : QObject(parent)
{
}

bool Database::open(const QString &path)
{
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(path);

    if (!m_db.open()) {
        qWarning() << "Datenbank konnte nicht geöffnet werden:" << m_db.lastError().text();
        return false;
    }

    {
        // Block-Scope: pragma-Query muss vor checkAndApplySchema zerstört sein.
        // PRAGMA journal_mode = WAL gibt eine Ergebniszeile zurück – der offene
        // Lesecursor würde sonst den exklusiven Lock bei DROP TABLE blockieren.
        QSqlQuery pragma;
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA busy_timeout = 5000");   // 5s warten wenn DB gesperrt
        pragma.exec("PRAGMA journal_mode = WAL");    // bessere Nebenläufigkeit
    } // pragma-Cursor wird hier freigegeben

    qInfo() << "Datenbank geöffnet:" << path;
    return checkAndApplySchema();
}

void Database::close()
{
    m_db.close();
}

bool Database::isOpen() const
{
    return m_db.isOpen();
}

QString Database::lastError() const
{
    return m_db.lastError().text();
}

// ============================================================
// checkAndApplySchema
// Liest die gespeicherte Schema-Version. Stimmt sie nicht mit
// SCHEMA_VERSION überein, werden alle Objekte gelöscht und das
// Schema komplett neu angelegt. Migrationen gibt es erst vor
// dem ersten stabilen Release.
// ============================================================
bool Database::checkAndApplySchema()
{
    // Versionscheck in eigenem Block – Query muss zerstört sein bevor
    // die Transaktion startet, sonst hält sie ein SQLite-Lock auf schema_version.
    int storedVersion = -1;
    {
        QSqlQuery q;
        if (!q.exec("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")) {
            qWarning() << "schema_version anlegen fehlgeschlagen:" << q.lastError().text();
            return false;
        }
        if (q.exec("SELECT version FROM schema_version LIMIT 1") && q.next())
            storedVersion = q.value(0).toInt();
    } // q wird hier zerstört → Lock freigegeben

    if (storedVersion == SCHEMA_VERSION) {
        qInfo() << "Schema bereits auf Version" << SCHEMA_VERSION << "– kein Update nötig.";
        return true;
    }

    qInfo() << "Schema-Version:" << storedVersion << "→" << SCHEMA_VERSION
            << "– Datenbank wird neu aufgebaut.";

    if (!m_db.transaction()) {
        qWarning() << "Transaktion konnte nicht gestartet werden:" << m_db.lastError().text();
        return false;
    }

    if (!dropAllTables() || !createSchema() || !seedSymbolKatalog()
            || !seedBuiltinSymbolDefinitionen() || !seedIbnFeldvorlagen() || !seedExampleData()) {
        m_db.rollback();
        return false;
    }

    QSqlQuery ins;
    ins.prepare("INSERT INTO schema_version (version) VALUES (:v)");
    ins.bindValue(":v", SCHEMA_VERSION);
    if (!ins.exec()) {
        qWarning() << "schema_version schreiben fehlgeschlagen:" << ins.lastError().text();
        m_db.rollback();
        return false;
    }

    if (!m_db.commit()) {
        qWarning() << "Commit fehlgeschlagen:" << m_db.lastError().text();
        m_db.rollback();
        return false;
    }

    qInfo() << "Schema v" << SCHEMA_VERSION << "erfolgreich angelegt.";
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
    QSqlQuery q;
    q.exec("PRAGMA foreign_keys = OFF");

    const QStringList views = {
        "klemmenleiste_bmk",
        "betriebsmittel_bmk",
        "seite_kennzeichen"
    };
    const QStringList tables = {
        // abhängige Tabellen zuerst
        "ibn_feldwert",
        "ibn_feldvorlage",
        "inbetriebnahme",
        "ibn_kabel",
        "klemme_anschluss",
        "klemme_stegbruecke",
        "klemme",
        "klemmenleiste",
        "makro_element",
        "makro",
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
        "schema_version"
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
    QSqlQuery q;

    // ----------------------------------------------------------
    // schema_version
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE schema_version (
            version INTEGER NOT NULL
        )
    )")) {
        qWarning() << "Fehler schema_version:" << q.lastError().text();
        return false;
    }

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
            rastend           INTEGER NOT NULL DEFAULT 1
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
            betriebsmittel_id   INTEGER REFERENCES betriebsmittel(id)
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
            groesse_raster INTEGER NOT NULL DEFAULT 1,
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
    // Makro-Bibliothek (Schema v31)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE makro (
            id            INTEGER PRIMARY KEY,
            name          TEXT    NOT NULL,
            beschreibung  TEXT    DEFAULT '',
            kategorie     TEXT    DEFAULT '',
            kasten_breite REAL    NOT NULL DEFAULT 100,
            kasten_hoehe  REAL    NOT NULL DEFAULT 100,
            erstellt_am   TEXT    DEFAULT (datetime('now'))
        )
    )")) {
        qWarning() << "Fehler makro:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE makro_element (
            id          INTEGER PRIMARY KEY,
            makro_id    INTEGER NOT NULL REFERENCES makro(id) ON DELETE CASCADE,
            typ         TEXT    NOT NULL,
            rel_x1      REAL    NOT NULL,
            rel_y1      REAL    NOT NULL,
            rel_x2      REAL    NOT NULL DEFAULT 0,
            rel_y2      REAL    NOT NULL DEFAULT 0,
            extra_daten TEXT    DEFAULT '{}',
            symbol_key  TEXT    DEFAULT '',
            sortierung  INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler makro_element:" << q.lastError().text();
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

    return true;
}

// ============================================================
// seedExampleData
// Füllt die frisch angelegte Datenbank mit einem Beispielprojekt,
// damit die Anwendung beim ersten Start nicht leer ist.
// Wird nur nach dropAllTables + createSchema aufgerufen.
// ============================================================
bool Database::seedExampleData()
{
    // gridPx = gridMm(4) * mmToPx(4) = 16 px
    // Standardsymbol: 8*16 = 128 breit, 4*16 = 64 hoch
    // Verbindungselement (QV): 2*16 = 32 × 32
    constexpr double G = 16.0;   // gridPx
    constexpr double SW = 8*G;   // Symbol-Breite  128
    constexpr double SH = 4*G;   // Symbol-Höhe     64
    constexpr double VW = 2*G;   // Verbindungs-Symbol 32

    auto insertGrafik = [&](int seiteId, int sort,
                             const QString &typ, const QString &symId,
                             double x1, double y1, double x2, double y2,
                             const QString &strichFarbe, double strichBreite,
                             bool fuell, const QString &fuellFarbe, double fuellOp,
                             const QString &extraJson) -> bool
    {
        QSqlQuery qi;
        qi.prepare(R"(
            INSERT INTO grafik_element
                (seite_id, typ, x1, y1, x2, y2,
                 strich_farbe, strich_breite, strich_art,
                 fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
                 sortierung, symbol_id, rotation, spiegel_x, spiegel_y,
                 extra_daten)
            VALUES
                (:sid, :typ, :x1, :y1, :x2, :y2,
                 :sf, :sb, 'solid',
                 :fu, :ff, :fo, 1.0, 0,
                 :sort, :symid, 0, 0, 0,
                 :ed)
        )");
        qi.bindValue(":sid",   seiteId);
        qi.bindValue(":typ",   typ);
        qi.bindValue(":x1",    x1);   qi.bindValue(":y1", y1);
        qi.bindValue(":x2",    x2);   qi.bindValue(":y2", y2);
        qi.bindValue(":sf",    strichFarbe);
        qi.bindValue(":sb",    strichBreite);
        qi.bindValue(":fu",    fuell ? 1 : 0);
        qi.bindValue(":ff",    fuellFarbe);
        qi.bindValue(":fo",    fuellOp);
        qi.bindValue(":sort",  sort);
        qi.bindValue(":symid", symId);
        qi.bindValue(":ed",    extraJson.isEmpty()
                               ? QVariant(QMetaType::fromType<QString>())
                               : QVariant(extraJson));
        if (!qi.exec()) {
            qWarning() << "Seed grafik_element:" << qi.lastError().text();
            return false;
        }
        return true;
    };

    // Helper: BMK + Freitexte als JSON
    auto bmkJson = [](const QString &bmk, const QString &ft1 = {},
                      const QString &ft2 = {}) -> QString {
        return QString(R"({"bmk":"%1","freitext1":"%2","freitext2":"%3"})")
               .arg(bmk, ft1, ft2);
    };

    QSqlQuery q;

    // ----------------------------------------------------------
    // Projekt
    // ----------------------------------------------------------
    q.prepare("INSERT INTO projekt (name, projektnummer, status) "
              "VALUES (:name, :nr, 'in_bearbeitung')");
    q.bindValue(":name", "Beispielprojekt – Stallbeleuchtung");
    q.bindValue(":nr",   "2026-001");
    if (!q.exec()) { qWarning() << "Seed projekt:" << q.lastError().text(); return false; }
    const int projektId = q.lastInsertId().toInt();

    // ----------------------------------------------------------
    // Anlage
    // ----------------------------------------------------------
    q.prepare("INSERT INTO anlage (projekt_id, kuerzel, bezeichnung, sortierung) "
              "VALUES (:pid, 'EG', 'Erdgeschoss', 0)");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qWarning() << "Seed anlage:" << q.lastError().text(); return false; }
    const int anlageId = q.lastInsertId().toInt();

    // ----------------------------------------------------------
    // Ort + Seiten
    // ----------------------------------------------------------
    q.prepare("INSERT INTO ort (anlage_id, kuerzel, bezeichnung, sortierung) "
              "VALUES (:aid, 'KS', 'Kuhstall', 0)");
    q.bindValue(":aid", anlageId);
    if (!q.exec()) { qWarning() << "Seed ort:" << q.lastError().text(); return false; }
    const int ortId = q.lastInsertId().toInt();

    auto insertSeite = [&](const QString &nr, const QString &bez, int sort) -> int {
        QSqlQuery qs;
        qs.prepare("INSERT INTO seite (ort_id, anlage_kuerzel, ort_kuerzel, "
                   "blattnummer, bezeichnung, seitentyp, sortierung) "
                   "VALUES (:oid, 'EG', 'KS', :nr, :bez, 'schaltplan', :sort)");
        qs.bindValue(":oid",  ortId);
        qs.bindValue(":nr",   nr);
        qs.bindValue(":bez",  bez);
        qs.bindValue(":sort", sort);
        if (!qs.exec()) { qWarning() << "Seed seite:" << qs.lastError().text(); return -1; }
        return qs.lastInsertId().toInt();
    };

    const int s1 = insertSeite("001", "Hauptstromkreis", 0);
    const int s2 = insertSeite("002", "Steuerstromkreis", 1);
    const int s3 = insertSeite("003", "Klemmenplan", 2);
    if (s1 < 0 || s2 < 0 || s3 < 0) return false;

    // ----------------------------------------------------------
    // Seite 001 – Hauptstromkreis
    //   Gerätekasten -X1, LSS -Q1, Sicherung -F1, Motor -M1
    //   Querverweis "230V_L1" → Seite 002
    // ----------------------------------------------------------
    // Gerätekasten -X1  (6 × SW breit, 4 × SH hoch)
    if (!insertGrafik(s1, 0, "geraetekasten", {},
                      5*G, 5*G, 5*G + 6*SW, 5*G + 4*SH,
                      "#cc7700", 1.5, true, "#331a00", 0.15,
                      R"({"bmk":"-X1","bezeichnung":"Schaltschrank"})")) return false;

    // LSS -Q1  (oben links im Kasten)
    if (!insertGrafik(s1, 1, "symbol", "lss",
                      6*G, 6*G, 6*G + SW, 6*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-Q1", "Leitungsschutzschalter", "B16A"))) return false;

    // Sicherung -F1  (rechts neben LSS)
    if (!insertGrafik(s1, 2, "symbol", "sicherung",
                      6*G + SW + 2*G, 6*G, 6*G + 2*SW + 2*G, 6*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-F1", "Motorschutzschalter", "1,6-2,5 A"))) return false;

    // Motor -M1  (darunter, mittig)
    if (!insertGrafik(s1, 3, "symbol", "motor",
                      6*G + SW/2, 6*G + SH + 4*G, 6*G + SW/2 + SW, 6*G + 2*SH + 4*G,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-M1", "Kreiselpumpe P1", "0,75 kW / 230V"))) return false;

    // Querverweis "230V_L1" ausgang → Seite 002
    const QString qvAusgangJson =
        QString(R"({"signalname":"230V_L1","richtung":"ausgang","zielSeiteId":%1})").arg(s2);
    if (!insertGrafik(s1, 4, "symbol", "querverweis",
                      5*G, 5*G + 4*SH + 3*G, 5*G + VW, 5*G + 4*SH + 3*G + VW,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      qvAusgangJson)) return false;

    // ----------------------------------------------------------
    // Seite 002 – Steuerstromkreis
    //   Schliesser -K1.1, Spule -K1, Lampe -H1
    //   Querverweis "230V_L1" eingang ← Seite 001
    // ----------------------------------------------------------
    // Schliesser -K1.1
    if (!insertGrafik(s2, 0, "symbol", "schliesser",
                      10*G, 10*G, 10*G + SW, 10*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-K1.1", "Hilfskontakt Schütz"))) return false;

    // Schütz-Spule -K1  (rechts neben Schliesser)
    if (!insertGrafik(s2, 1, "symbol", "spule",
                      10*G + SW + 2*G, 10*G, 10*G + 2*SW + 2*G, 10*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-K1", "Schütz Pumpe P1"))) return false;

    // Meldelampe -H1  (in zweiter Reihe)
    if (!insertGrafik(s2, 2, "symbol", "lampe",
                      10*G, 10*G + SH + 4*G, 10*G + SW, 10*G + 2*SH + 4*G,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-H1", "Betriebsanzeige", "grün"))) return false;

    // Querverweis "230V_L1" eingang ← Seite 001
    const QString qvEingangJson =
        QString(R"({"signalname":"230V_L1","richtung":"eingang","zielSeiteId":%1})").arg(s1);
    if (!insertGrafik(s2, 3, "symbol", "querverweis",
                      10*G, 10*G + 2*SH + 8*G, 10*G + VW, 10*G + 2*SH + 8*G + VW,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      qvEingangJson)) return false;

    // ----------------------------------------------------------
    // Seite 003 – Klemmenplan (nur Gerätekasten als Rahmen)
    // ----------------------------------------------------------
    if (!insertGrafik(s3, 0, "geraetekasten", {},
                      5*G, 5*G, 5*G + 10*SW, 5*G + 3*SH,
                      "#cc7700", 1.5, true, "#331a00", 0.15,
                      R"({"bmk":"-X1","bezeichnung":"Klemmenleiste"})")) return false;

    // Klemmen X1:1 … X1:4
    const QStringList kmmBez = { ":1", ":2", ":3", ":4" };
    for (int ki = 0; ki < kmmBez.size(); ++ki) {
        if (!insertGrafik(s3, ki + 1, "symbol", "klemme",
                          6*G + ki * (SW + G), 6*G, 6*G + ki * (SW + G) + SW, 6*G + SH,
                          "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                          bmkJson("-X1" + kmmBez[ki]))) return false;
    }

    // ----------------------------------------------------------
    // Bauteil-Katalog (Beispieleinträge)
    // ----------------------------------------------------------
    q.prepare("INSERT INTO bauteil_kategorie (name, parent_id, sortierung) "
              "VALUES (:n, NULL, :s)");
    q.bindValue(":n", "Schutzgeräte"); q.bindValue(":s", 0);
    if (!q.exec()) { qWarning() << "Seed kat:" << q.lastError().text(); return false; }
    const int katSchutz = q.lastInsertId().toInt();

    q.bindValue(":n", "Antriebe"); q.bindValue(":s", 1);
    if (!q.exec()) { qWarning() << "Seed kat2:" << q.lastError().text(); return false; }
    const int katAntriebe = q.lastInsertId().toInt();

    q.bindValue(":n", "Schaltgeräte"); q.bindValue(":s", 2);
    if (!q.exec()) { qWarning() << "Seed kat3:" << q.lastError().text(); return false; }
    const int katSchalt = q.lastInsertId().toInt();

    struct BauteilDef {
        int kat; QString bez; QString hersteller; QString artNr;
    };
    const QList<BauteilDef> bauteile = {
        { katSchutz,  "Leitungsschutzschalter B16A", "ABB",       "S201-B16"      },
        { katSchutz,  "Motorschutzschalter 1,6-2,5A","Siemens",   "3RV2011-1CA10" },
        { katAntriebe,"Kreiselpumpe 0,75 kW",         "Grundfos",  "CM3-5 A-R-I"  },
        { katSchalt,  "Schütz 9A 230VAC",             "Siemens",   "3RT2015-1AP01" },
    };
    for (const BauteilDef &b : bauteile) {
        q.prepare("INSERT INTO bauteil (kategorie_id, bezeichnung, hersteller, artikelnummer) "
                  "VALUES (:kid, :bez, :her, :art)");
        q.bindValue(":kid", b.kat);
        q.bindValue(":bez", b.bez);
        q.bindValue(":her", b.hersteller);
        q.bindValue(":art", b.artNr);
        if (!q.exec()) { qWarning() << "Seed bauteil:" << q.lastError().text(); return false; }
    }

    // ----------------------------------------------------------
    // Kabel-Bibliothek (Beispieleinträge)
    // ----------------------------------------------------------
    q.prepare("INSERT INTO bauteil_kategorie (name, parent_id, sortierung) "
              "VALUES (:n, NULL, :s)");
    q.bindValue(":n", "Kabel"); q.bindValue(":s", 3);
    if (!q.exec()) { qWarning() << "Seed kat Kabel:" << q.lastError().text(); return false; }
    const int katKabel = q.lastInsertId().toInt();

    struct KabelDef {
        QString bezeichnung; QString hersteller; QString artNr;
        QString kabeltyp; int geschirmt;
        struct Ader { int nr; QString farbe; QString bez; double quer; };
        QList<Ader> adern;
    };
    const QList<KabelDef> kabelDefs = {
        {
            "NYM-J 3×1,5", "diverse", "NYM-J 3x1,5",
            "NYM-J 3×1,5 mm²", 0,
            { {1,"BN","L",1.5}, {2,"BU","N",1.5}, {3,"GNYE","PE",1.5} }
        },
        {
            "NYM-J 5×1,5", "diverse", "NYM-J 5x1,5",
            "NYM-J 5×1,5 mm²", 0,
            { {1,"BN","L1",1.5}, {2,"BK","L2",1.5}, {3,"GY","L3",1.5},
              {4,"BU","N",1.5},  {5,"GNYE","PE",1.5} }
        },
        {
            "H05VV-F 3G1,5", "diverse", "H05VV-F 3G1,5",
            "H05VV-F 3G1,5 mm²", 0,
            { {1,"BN","L",1.5}, {2,"BU","N",1.5}, {3,"GNYE","PE",1.5} }
        },
        {
            "LIYY 4×0,5", "diverse", "LIYY 4x0,5",
            "LIYY 4×0,5 mm²", 0,
            { {1,"BN","1",0.5}, {2,"WH","2",0.5}, {3,"BU","3",0.5}, {4,"BK","4",0.5} }
        },
        {
            "ÖLFLEX CLASSIC 110 4G1,5", "Lapp", "1119304",
            "ÖLFLEX 110 4G1,5 mm²", 0,
            { {1,"BN","L",1.5}, {2,"BK","L2",1.5}, {3,"GY","L3",1.5}, {4,"GNYE","PE",1.5} }
        },
    };

    for (const KabelDef &kd : kabelDefs) {
        // bauteil anlegen
        q.prepare("INSERT INTO bauteil (kategorie_id, bezeichnung, hersteller, artikelnummer) "
                  "VALUES (:kid, :bez, :her, :art)");
        q.bindValue(":kid", katKabel);
        q.bindValue(":bez", kd.bezeichnung);
        q.bindValue(":her", kd.hersteller);
        q.bindValue(":art", kd.artNr);
        if (!q.exec()) { qWarning() << "Seed bauteil Kabel:" << q.lastError().text(); return false; }
        const int bauteilId = q.lastInsertId().toInt();

        // bauteil_kabel anlegen
        q.prepare("INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt) "
                  "VALUES (:bid, :typ, :gs)");
        q.bindValue(":bid", bauteilId);
        q.bindValue(":typ", kd.kabeltyp);
        q.bindValue(":gs",  kd.geschirmt);
        if (!q.exec()) { qWarning() << "Seed bauteil_kabel:" << q.lastError().text(); return false; }
        const int bkId = q.lastInsertId().toInt();

        // Adern anlegen
        for (const KabelDef::Ader &a : kd.adern) {
            q.prepare("INSERT INTO bauteil_kabel_ader "
                      "(kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2) "
                      "VALUES (:kid, :nr, :f, :bez, :quer)");
            q.bindValue(":kid",  bkId);
            q.bindValue(":nr",   a.nr);
            q.bindValue(":f",    a.farbe);
            q.bindValue(":bez",  a.bez);
            q.bindValue(":quer", a.quer);
            if (!q.exec()) { qWarning() << "Seed bauteil_kabel_ader:" << q.lastError().text(); return false; }
        }
    }

    qInfo() << "Beispieldaten eingefügt (Projekt 'Beispielprojekt – Stallbeleuchtung').";
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
    };

    QSqlQuery q;
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

    QSqlQuery q;
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


// ============================================================
// symboleNachNorm
// Gibt alle Symbole zurück deren norm-Feld die gesuchte Norm enthält.
// ============================================================
QVariantList Database::symboleNachNorm(const QString &norm)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, code, name, kategorie_pfad, norm, favorit, anschluesse
        FROM symbol
        WHERE instr(norm, :n) > 0
        ORDER BY kategorie_pfad, name
    )");
    q.bindValue(":n", norm);
    if (!q.exec()) {
        qWarning() << "symboleNachNorm:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]           = q.value(0).toInt();
        m[QStringLiteral("code")]         = q.value(1).toString();
        m[QStringLiteral("name")]         = q.value(2).toString();
        m[QStringLiteral("kategoriePfad")]= q.value(3).toString();
        m[QStringLiteral("norm")]         = q.value(4).toString();
        m[QStringLiteral("favorit")]      = q.value(5).toInt() != 0;
        m[QStringLiteral("anschluesse")]  = q.value(6).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// symbolFavoritSetzen
// ============================================================
bool Database::symbolFavoritSetzen(int symbolId, bool favorit)
{
    QSqlQuery q;
    q.prepare("UPDATE symbol SET favorit = :fav WHERE id = :id");
    q.bindValue(":fav", favorit ? 1 : 0);
    q.bindValue(":id",  symbolId);
    if (!q.exec()) {
        qWarning() << "symbolFavoritSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// projektNormLaden / projektNormSpeichern
// ============================================================
QString Database::projektNormLaden(int projektId)
{
    QSqlQuery q;
    q.prepare("SELECT norm FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("IEC");
}

bool Database::projektNormSpeichern(int projektId, const QString &norm)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET norm = :norm WHERE id = :pid");
    q.bindValue(":norm", norm);
    q.bindValue(":pid",  projektId);
    if (!q.exec()) {
        qWarning() << "projektNormSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// projektHintergrundLaden / projektHintergrundSpeichern
// ============================================================
QString Database::projektHintergrundLaden(int projektId)
{
    QSqlQuery q;
    q.prepare("SELECT canvas_hintergrund FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("#080f1c");
}

bool Database::projektHintergrundSpeichern(int projektId, const QString &farbe)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET canvas_hintergrund = :farbe WHERE id = :pid");
    q.bindValue(":farbe", farbe);
    q.bindValue(":pid",   projektId);
    if (!q.exec()) {
        qWarning() << "projektHintergrundSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// grafikLaden
// Gibt alle Grafik-Elemente einer Seite als QVariantList zurück.
// Die Maps verwenden dieselben camelCase-Schlüssel wie das QML-Modell.
// ============================================================
QVariantList Database::grafikLaden(int seiteId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, typ, x1, y1, x2, y2,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet,
               opazitaet, ecken_radius,
               symbol_id, rotation, spiegel_x, spiegel_y,
               punkte, text_inhalt, text_ausrichtung, text_einpassen,
               bild_daten, bild_mime, extra_daten, betriebsmittel_id
        FROM grafik_element
        WHERE seite_id = :sid
        ORDER BY sortierung
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "grafikLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap el;
        el[QStringLiteral("id")]             = q.value(0).toInt();
        el[QStringLiteral("typ")]            = q.value(1).toString();
        el[QStringLiteral("x1")]             = q.value(2).toDouble();
        el[QStringLiteral("y1")]             = q.value(3).toDouble();
        el[QStringLiteral("x2")]             = q.value(4).toDouble();
        el[QStringLiteral("y2")]             = q.value(5).toDouble();
        el[QStringLiteral("strichFarbe")]    = q.value(6).toString();
        el[QStringLiteral("strichBreite")]   = q.value(7).toDouble();
        el[QStringLiteral("strichArt")]      = q.value(8).toString();
        el[QStringLiteral("fuell")]          = q.value(9).toInt() != 0;
        el[QStringLiteral("fuellFarbe")]     = q.value(10).toString();
        el[QStringLiteral("fuellOpazitaet")] = q.value(11).toDouble();
        el[QStringLiteral("opazitaet")]      = q.value(12).toDouble();
        el[QStringLiteral("eckenRadius")]    = q.value(13).toDouble();
        el[QStringLiteral("symbolId")]       = q.value(14).toString();
        el[QStringLiteral("rotation")]       = q.value(15).toInt();
        el[QStringLiteral("spiegelX")]       = q.value(16).toInt() != 0;
        el[QStringLiteral("spiegelY")]       = q.value(17).toInt() != 0;

        // text_inhalt / text_ausrichtung / text_einpassen (für Text-Elemente)
        QString textInhalt = q.value(19).toString();
        if (!textInhalt.isEmpty())
            el[QStringLiteral("textInhalt")] = textInhalt;
        QString textAusrichtung = q.value(20).toString();
        el[QStringLiteral("textAusrichtung")] = textAusrichtung.isEmpty()
                                                ? QStringLiteral("links") : textAusrichtung;
        el[QStringLiteral("textEinpassen")] = q.value(21).toInt() != 0;

        // bild_daten: BLOB-Bytes + bild_mime → Base64-Data-URL für QML-Canvas
        QByteArray bildBytes = q.value(22).toByteArray();
        if (!bildBytes.isEmpty()) {
            QString bildMime = q.value(23).toString();
            if (bildMime.isEmpty())
                bildMime = QStringLiteral("image/png");
            el[QStringLiteral("bildDaten")] = QStringLiteral("data:") + bildMime
                + QStringLiteral(";base64,")
                + QString::fromLatin1(bildBytes.toBase64());
        }

        // extra_daten: JSON → extraDaten-Map für symbol-spezifische Eigenschaften
        QString extraDatenStr = q.value(24).toString();
        if (!extraDatenStr.isEmpty()) {
            QJsonParseError jsonErr;
            QJsonDocument extraDoc = QJsonDocument::fromJson(extraDatenStr.toUtf8(), &jsonErr);
            if (!jsonErr.error && extraDoc.isObject())
                el[QStringLiteral("extraDaten")] = extraDoc.object().toVariantMap();
        }

        // betriebsmittel_id (Spalte 25) – nullable FK
        if (!q.value(25).isNull())
            el[QStringLiteral("betriebsmittelId")] = q.value(25).toInt();

        // punkte (für Leitung-Elemente als JSON gespeichert)
        QString punkteStr = q.value(18).toString();
        if (!punkteStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(punkteStr.toUtf8(), &err);
            if (!err.error && doc.isArray()) {
                QVariantList punkte;
                for (const QJsonValue &v : doc.array()) {
                    if (v.isObject()) {
                        QVariantMap p;
                        p[QStringLiteral("x")] = v[QStringLiteral("x")].toDouble();
                        p[QStringLiteral("y")] = v[QStringLiteral("y")].toDouble();
                        punkte.append(p);
                    }
                }
                el[QStringLiteral("punkte")] = punkte;
            }
        }

        result.append(el);
    }
    return result;
}

// ============================================================
// grafikSpeichern
// Ersetzt alle Grafik-Elemente einer Seite in einer Transaktion.
// ============================================================
bool Database::grafikSpeichern(int seiteId, const QVariantList &elemente)
{
    if (!m_db.transaction()) {
        qWarning() << "grafikSpeichern: Transaktion:" << m_db.lastError().text();
        return false;
    }

    // Kabellinie-Ader-Zuordnungen vor dem DELETE sichern:
    // elementIndex → {kabelId, liste_ader_nummern}
    // Nach dem re-Insert werden die kabellinie_grafik_element_id-Werte wiederhergestellt.
    QMap<int, QPair<int, QList<int>>> kabelLinieAderMap;
    for (int i = 0; i < elemente.size(); i++) {
        const QVariantMap el = elemente.at(i).toMap();
        if (el.value(QStringLiteral("typ")).toString() != QLatin1String("kabellinie")) continue;
        int oldGeid  = el.value(QStringLiteral("id"), 0).toInt();
        if (oldGeid <= 0) continue;
        int kabelId  = el.value(QStringLiteral("extraDaten")).toMap()
                          .value(QStringLiteral("kabelId"), 0).toInt();
        if (kabelId <= 0) continue;
        QSqlQuery qa;
        qa.prepare("SELECT ader_nr FROM kabel_ader WHERE kabel_id=:kid AND kabellinie_grafik_element_id=:geid");
        qa.bindValue(":kid",  kabelId);
        qa.bindValue(":geid", oldGeid);
        QList<int> adern;
        if (qa.exec()) { while (qa.next()) adern.append(qa.value(0).toInt()); }
        if (!adern.isEmpty()) kabelLinieAderMap[i] = qMakePair(kabelId, adern);
    }

    QSqlQuery qDel;
    qDel.prepare("DELETE FROM grafik_element WHERE seite_id = :sid");
    qDel.bindValue(":sid", seiteId);
    if (!qDel.exec()) {
        qWarning() << "grafikSpeichern delete:" << qDel.lastError().text();
        m_db.rollback(); return false;
    }

    QSqlQuery qIns;
    qIns.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet,
             opazitaet, ecken_radius, sortierung,
             symbol_id, rotation, spiegel_x, spiegel_y,
             punkte, text_inhalt, text_ausrichtung, text_einpassen,
             bild_daten, bild_mime, extra_daten, betriebsmittel_id)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             :sf, :sb, :sa, :fu, :ff, :fo, :op, :er, :sort,
             :symid, :rot, :spx, :spy,
             :punkte, :textinhalt, :textausrichtung, :texteinpassen,
             :bilddaten, :bildmime, :extradaten, :bmid)
    )");

    for (int i = 0; i < elemente.size(); i++) {
        const QVariantMap el = elemente.at(i).toMap();
        qIns.bindValue(":sid",  seiteId);
        qIns.bindValue(":typ",  el.value(QStringLiteral("typ")).toString());
        qIns.bindValue(":x1",   el.value(QStringLiteral("x1")).toDouble());
        qIns.bindValue(":y1",   el.value(QStringLiteral("y1")).toDouble());
        qIns.bindValue(":x2",   el.value(QStringLiteral("x2")).toDouble());
        qIns.bindValue(":y2",   el.value(QStringLiteral("y2")).toDouble());
        qIns.bindValue(":sf",   el.value(QStringLiteral("strichFarbe"),    QStringLiteral("#4a9eff")).toString());
        qIns.bindValue(":sb",   el.value(QStringLiteral("strichBreite"),   1.5).toDouble());
        qIns.bindValue(":sa",   el.value(QStringLiteral("strichArt"),      QStringLiteral("solid")).toString());
        qIns.bindValue(":fu",   el.value(QStringLiteral("fuell"),          false).toBool() ? 1 : 0);
        qIns.bindValue(":ff",   el.value(QStringLiteral("fuellFarbe"),     QStringLiteral("#1a3a6a")).toString());
        qIns.bindValue(":fo",   el.value(QStringLiteral("fuellOpazitaet"), 0.3).toDouble());
        qIns.bindValue(":op",   el.value(QStringLiteral("opazitaet"),      1.0).toDouble());
        qIns.bindValue(":er",   el.value(QStringLiteral("eckenRadius"),    0.0).toDouble());
        qIns.bindValue(":sort", i);
        qIns.bindValue(":symid", el.value(QStringLiteral("symbolId")).toString());
        qIns.bindValue(":rot",   el.value(QStringLiteral("rotation"),  0).toInt());
        qIns.bindValue(":spx",   el.value(QStringLiteral("spiegelX"),  false).toBool() ? 1 : 0);
        qIns.bindValue(":spy",   el.value(QStringLiteral("spiegelY"),  false).toBool() ? 1 : 0);

        // text_inhalt / text_ausrichtung / text_einpassen (für Text-Elemente)
        QVariant textInhaltVar = el.value(QStringLiteral("textInhalt"));
        if (textInhaltVar.isValid() && !textInhaltVar.isNull())
            qIns.bindValue(":textinhalt", textInhaltVar.toString());
        else
            qIns.bindValue(":textinhalt", QVariant(QMetaType::fromType<QString>()));
        qIns.bindValue(":textausrichtung",
                       el.value(QStringLiteral("textAusrichtung"), QStringLiteral("links")).toString());
        qIns.bindValue(":texteinpassen",
                       el.value(QStringLiteral("textEinpassen"), false).toBool() ? 1 : 0);

        // punkte als JSON serialisieren (nur für Leitungen)
        QVariant punkteVar = el.value(QStringLiteral("punkte"));
        if (punkteVar.isValid() && !punkteVar.isNull() && punkteVar.canConvert<QVariantList>()) {
            QVariantList punkte = punkteVar.toList();
            QJsonArray arr;
            for (const QVariant &pv : punkte) {
                QVariantMap pm = pv.toMap();
                QJsonObject obj;
                obj[QStringLiteral("x")] = pm.value(QStringLiteral("x")).toDouble();
                obj[QStringLiteral("y")] = pm.value(QStringLiteral("y")).toDouble();
                arr.append(obj);
            }
            qIns.bindValue(":punkte", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
        } else {
            qIns.bindValue(":punkte", QVariant(QMetaType::fromType<QString>()));
        }

        // bild_daten: Data-URL aus QML → BLOB-Bytes + MIME für Datenbank
        QVariant bildDatenVar = el.value(QStringLiteral("bildDaten"));
        if (bildDatenVar.isValid() && !bildDatenVar.isNull()) {
            QString dataUrl = bildDatenVar.toString();
            // Format: "data:<mime>;base64,<daten>"
            if (dataUrl.startsWith(QLatin1String("data:"))) {
                int semiPos   = dataUrl.indexOf(QLatin1Char(';'), 5);
                int commaPos  = dataUrl.indexOf(QLatin1Char(','), semiPos + 1);
                if (semiPos > 0 && commaPos > 0) {
                    QString    mime     = dataUrl.mid(5, semiPos - 5);
                    QByteArray rawBytes = QByteArray::fromBase64(
                                             dataUrl.mid(commaPos + 1).toLatin1());
                    qIns.bindValue(":bilddaten", rawBytes);
                    qIns.bindValue(":bildmime",  mime);
                } else {
                    qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
                    qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
                }
            } else {
                qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
                qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
            }
        } else {
            qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
            qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
        }

        // extra_daten: extraDaten-Map als kompaktes JSON serialisieren
        QVariant extraVar = el.value(QStringLiteral("extraDaten"));
        if (extraVar.isValid() && !extraVar.isNull() && extraVar.canConvert<QVariantMap>()) {
            QVariantMap extraMap = extraVar.toMap();
            if (!extraMap.isEmpty()) {
                QJsonObject obj;
                for (auto it = extraMap.constBegin(); it != extraMap.constEnd(); ++it)
                    obj.insert(it.key(), QJsonValue::fromVariant(it.value()));
                qIns.bindValue(":extradaten",
                    QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
            } else {
                qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
            }
        } else {
            qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
        }

        // betriebsmittel_id (nullable FK)
        QVariant bmidVar = el.value(QStringLiteral("betriebsmittelId"));
        if (bmidVar.isValid() && !bmidVar.isNull() && bmidVar.toInt() > 0)
            qIns.bindValue(":bmid", bmidVar.toInt());
        else
            qIns.bindValue(":bmid", QVariant(QMetaType::fromType<int>()));

        if (!qIns.exec()) {
            qWarning() << "grafikSpeichern insert:" << qIns.lastError().text();
            m_db.rollback(); return false;
        }

        // Kabellinie: kabel.grafik_element_id + kabel_ader.kabellinie_grafik_element_id
        // nach re-Insert auf neue ID aktualisieren.
        if (el.value(QStringLiteral("typ")).toString() == QLatin1String("kabellinie")) {
            QVariant extraVar2 = el.value(QStringLiteral("extraDaten"));
            if (extraVar2.isValid() && extraVar2.canConvert<QVariantMap>()) {
                int kabelId = extraVar2.toMap().value(QStringLiteral("kabelId"), 0).toInt();
                if (kabelId > 0) {
                    int newGeid = qIns.lastInsertId().toInt();
                    QSqlQuery upd;
                    upd.prepare("UPDATE kabel SET grafik_element_id = :geid WHERE id = :kid");
                    upd.bindValue(":geid", newGeid);
                    upd.bindValue(":kid",  kabelId);
                    if (!upd.exec())
                        qWarning() << "grafikSpeichern kabel relink:" << upd.lastError().text();

                    // Ader-Linie-Zuordnungen wiederherstellen
                    if (kabelLinieAderMap.contains(i)) {
                        const QList<int> &adern = kabelLinieAderMap[i].second;
                        for (int aderNr : adern) {
                            QSqlQuery upd2;
                            upd2.prepare(R"(
                                UPDATE kabel_ader SET kabellinie_grafik_element_id=:geid
                                WHERE kabel_id=:kid AND ader_nr=:nr
                            )");
                            upd2.bindValue(":geid", newGeid);
                            upd2.bindValue(":kid",  kabelId);
                            upd2.bindValue(":nr",   aderNr);
                            if (!upd2.exec())
                                qWarning() << "grafikSpeichern ader relink:" << upd2.lastError().text();
                        }
                    }
                }
            }
        }
    }

    if (!m_db.commit()) {
        qWarning() << "grafikSpeichern commit:" << m_db.lastError().text();
        m_db.rollback(); return false;
    }
    return true;
}

// ============================================================
// bildAlsDataUrl
// Liest eine Bilddatei ein, prüft die Größe und gibt eine
// Base64-Data-URL zurück (z. B. "data:image/png;base64,...").
// Diese Data-URL wird in QML für Canvas-Vorschau und In-Memory-
// Darstellung genutzt. Beim Speichern (grafikSpeichern) wird die
// Data-URL serverseitig dekodiert: MIME und Rohdaten werden getrennt
// als TEXT bzw. BLOB in der Datenbank abgelegt.
// Bei Fehler wird "error:<Meldung>" zurückgegeben.
// ============================================================
QString Database::bildAlsDataUrl(const QString &pfad, qint64 maxBytes)
{
    // URL-Schema entfernen falls übergeben (file:///path → /path)
    QUrl url(pfad);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;

    QFileInfo info(localPath);
    if (!info.exists())
        return QStringLiteral("error:Datei nicht gefunden");

    if (info.size() > maxBytes)
        return QStringLiteral("error:Datei zu groß (max. %1 MB)")
               .arg(maxBytes / (1024 * 1024));

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly))
        return QStringLiteral("error:Datei konnte nicht geöffnet werden");

    QByteArray data = file.readAll();
    file.close();

    // MIME-Typ aus Dateiendung ableiten
    QString suffix = info.suffix().toLower();
    QString mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg")  || suffix == QLatin1String("jpeg"))
        mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))
        mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))
        mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("svg"))
        mime = QStringLiteral("image/svg+xml");
    else if (suffix == QLatin1String("webp"))
        mime = QStringLiteral("image/webp");

    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

// ============================================================
// naechsteBmkNummer
// Durchsucht alle grafik_element.extra_daten im Projekt nach
// vorhandenen BMK-Werten mit dem gegebenen Präfix (z.B. "-K")
// und gibt den ersten freien Wert zurück (z.B. "-K3").
// Präfix muss die Kennbuchstaben enthalten, z.B. "-K", "-M", "-F".
// ============================================================
QString Database::naechsteBmkNummer(int projektId, const QString &praefix)
{
    if (praefix.isEmpty())
        return praefix + QStringLiteral("1");

    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten
        FROM grafik_element ge
        JOIN seite   s ON s.id = ge.seite_id
        JOIN ort     o ON o.id = s.ort_id
        JOIN anlage  a ON a.id = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'symbol'
          AND ge.extra_daten IS NOT NULL
    )");
    q.bindValue(":pid", projektId);

    QSet<int> vorhandene;
    const int praefixLen = praefix.length();

    if (q.exec()) {
        while (q.next()) {
            QString extraStr = q.value(0).toString();
            if (extraStr.isEmpty()) continue;
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (err.error || !doc.isObject()) continue;
            QString bmk = doc.object()[QStringLiteral("bmk")].toString();
            if (bmk.startsWith(praefix) && bmk.length() > praefixLen) {
                bool ok;
                int num = bmk.mid(praefixLen).toInt(&ok);
                if (ok && num > 0) vorhandene.insert(num);
            }
        }
    } else {
        qWarning() << "naechsteBmkNummer:" << q.lastError().text();
    }

    int next = 1;
    while (vorhandene.contains(next)) ++next;
    return praefix + QString::number(next);
}

// ============================================================
// verbindungenSynchronisieren
// Schreibt erkannte Auto-Verbindungen (Netze) in verbindung +
// verbindung_segment. Bestehende Segmente der Seite werden zuerst
// gelöscht; die verbindung-Zeilen (mit Annotation) bleiben erhalten
// und werden per potenzial-Feld (= netKey) wiederverwendet.
// ============================================================
bool Database::verbindungenSynchronisieren(int seiteId, int projektId, const QVariantList &netze)
{
    if (!m_db.transaction()) {
        qWarning() << "verbindungenSynchronisieren: Transaktion:" << m_db.lastError().text();
        return false;
    }

    // 1. Alte Segmente dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM verbindung_segment WHERE seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qWarning() << "verbindungenSynchronisieren del segments:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 2. Alte Querverweise dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM querverweis WHERE von_seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qWarning() << "verbindungenSynchronisieren del querverweis:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 3. Netze verarbeiten
    for (const QVariant &netVar : netze) {
        const QVariantMap net = netVar.toMap();
        const QString netKey      = net.value(QStringLiteral("netKey")).toString();
        const QString bezeichnung = net.value(QStringLiteral("bezeichnung")).toString();
        const QString signaltyp   = net.value(QStringLiteral("signaltyp"),  QStringLiteral("neutral")).toString();
        const QString farbe       = net.value(QStringLiteral("farbe")).toString();
        const double  querschnitt = net.value(QStringLiteral("querschnitt")).toDouble();

        if (netKey.isEmpty()) continue;

        // Verbindung per netKey (potenzial-Feld) suchen oder anlegen
        int verbId = -1;
        {
            QSqlQuery lookup;
            lookup.prepare("SELECT id FROM verbindung WHERE projekt_id = :pid AND potenzial = :key LIMIT 1");
            lookup.bindValue(":pid", projektId);
            lookup.bindValue(":key", netKey);
            if (lookup.exec() && lookup.next()) {
                verbId = lookup.value(0).toInt();
                // Nur signaltyp aktualisieren; Annotation (bezeichnung, farbe, querschnitt)
                // wird nur durch expliziten Nutzeraktion via verbindungAktualisieren geändert
                QSqlQuery upd;
                upd.prepare("UPDATE verbindung SET signaltyp = :sig WHERE id = :id");
                upd.bindValue(":sig", signaltyp);
                upd.bindValue(":id",  verbId);
                if (!upd.exec()) {
                    qWarning() << "verbindungenSynchronisieren update:" << upd.lastError().text();
                    m_db.rollback(); return false;
                }
            } else {
                QSqlQuery ins;
                ins.prepare(R"(
                    INSERT INTO verbindung (projekt_id, potenzial, bezeichnung, signaltyp, farbe, querschnitt_mm2)
                    VALUES (:pid, :key, :bez, :sig, :farbe, :q)
                )");
                ins.bindValue(":pid",   projektId);
                ins.bindValue(":key",   netKey);
                ins.bindValue(":bez",   bezeichnung.isEmpty()
                                        ? QVariant(QMetaType::fromType<QString>()) : bezeichnung);
                ins.bindValue(":sig",   signaltyp);
                ins.bindValue(":farbe", farbe.isEmpty()
                                        ? QVariant(QMetaType::fromType<QString>()) : farbe);
                ins.bindValue(":q",     querschnitt > 0
                                        ? querschnitt : QVariant(QMetaType::fromType<double>()));
                if (!ins.exec()) {
                    qWarning() << "verbindungenSynchronisieren insert verbindung:" << ins.lastError().text();
                    m_db.rollback(); return false;
                }
                verbId = ins.lastInsertId().toInt();
            }
        }

        // Segmente einfügen
        const QVariantList segmente = net.value(QStringLiteral("segmente")).toList();
        for (const QVariant &segVar : segmente) {
            const QVariantMap seg = segVar.toMap();
            QJsonArray punkte;
            punkte.append(QJsonObject{{ QStringLiteral("x"), seg.value(QStringLiteral("x1")).toDouble() },
                                      { QStringLiteral("y"), seg.value(QStringLiteral("y1")).toDouble() }});
            punkte.append(QJsonObject{{ QStringLiteral("x"), seg.value(QStringLiteral("x2")).toDouble() },
                                      { QStringLiteral("y"), seg.value(QStringLiteral("y2")).toDouble() }});
            QSqlQuery insSeg;
            insSeg.prepare("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (:vid, :sid, :pt)");
            insSeg.bindValue(":vid", verbId);
            insSeg.bindValue(":sid", seiteId);
            insSeg.bindValue(":pt",  QString::fromUtf8(QJsonDocument(punkte).toJson(QJsonDocument::Compact)));
            if (!insSeg.exec()) {
                qWarning() << "verbindungenSynchronisieren insert segment:" << insSeg.lastError().text();
                m_db.rollback(); return false;
            }
        }

        // Querverweise einfügen
        const QVariantList querverweise = net.value(QStringLiteral("querverweise")).toList();
        for (const QVariant &qvVar : querverweise) {
            const QVariantMap qv = qvVar.toMap();
            QSqlQuery insQv;
            insQv.prepare(R"(
                INSERT INTO querverweis (verbindung_id, von_seite_id, nach_seite_id, von_bezeichnung, nach_bezeichnung)
                VALUES (:vid, :von, :nach, :vonbez, :nachbez)
            )");
            insQv.bindValue(":vid",    verbId);
            insQv.bindValue(":von",    qv.value(QStringLiteral("vonSeiteId")).toInt());
            insQv.bindValue(":nach",   qv.value(QStringLiteral("nachSeiteId")).toInt());
            insQv.bindValue(":vonbez", qv.value(QStringLiteral("vonBezeichnung")).toString());
            insQv.bindValue(":nachbez",qv.value(QStringLiteral("nachBezeichnung")).toString());
            if (!insQv.exec()) {
                qWarning() << "verbindungenSynchronisieren insert querverweis:" << insQv.lastError().text();
                m_db.rollback(); return false;
            }
        }
    }

    if (!m_db.commit()) {
        qWarning() << "verbindungenSynchronisieren commit:" << m_db.lastError().text();
        m_db.rollback(); return false;
    }
    return true;
}

// ============================================================
// verbindungAktualisieren
// Schreibt Bezeichnung, Aderfarbe und Querschnitt einer Verbindung.
// ============================================================
bool Database::verbindungAktualisieren(int verbindungId, const QString &bezeichnung,
                                        const QString &farbe, double querschnitt)
{
    QSqlQuery q;
    q.prepare("UPDATE verbindung SET bezeichnung = :bez, farbe = :farbe, querschnitt_mm2 = :q WHERE id = :id");
    q.bindValue(":bez",   bezeichnung.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : bezeichnung);
    q.bindValue(":farbe", farbe.isEmpty()       ? QVariant(QMetaType::fromType<QString>()) : farbe);
    q.bindValue(":q",     querschnitt > 0       ? querschnitt : QVariant(QMetaType::fromType<double>()));
    q.bindValue(":id",    verbindungId);
    if (!q.exec()) {
        qWarning() << "verbindungAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// verbindungAnnotationenLaden
// Gibt alle Verbindungsannotationen für eine Seite zurück.
// Jede Zeile: {netKey (= potenzial), verbindungId, bezeichnung,
//              farbe, querschnitt_mm2, signaltyp}
// ============================================================
QVariantList Database::verbindungAnnotationenLaden(int seiteId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT v.id, v.potenzial, v.bezeichnung, v.farbe, v.querschnitt_mm2, v.signaltyp
        FROM verbindung_segment vs
        JOIN verbindung v ON v.id = vs.verbindung_id
        WHERE vs.seite_id = :sid
        GROUP BY v.id
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "verbindungAnnotationenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("verbindungId")]   = q.value(0).toInt();
        m[QStringLiteral("netKey")]         = q.value(1).toString();
        m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        m[QStringLiteral("farbe")]          = q.value(3).toString();
        m[QStringLiteral("querschnitt_mm2")]= q.value(4).isNull() ? 0.0 : q.value(4).toDouble();
        m[QStringLiteral("signaltyp")]      = q.value(5).toString();
        result.append(m);
    }
    return result;
}

// ============================================================
// verbindungenProjektLaden
// Alle Verbindungen eines Projekts (für Potenzial-Nummerierung).
// ============================================================
QVariantList Database::verbindungenProjektLaden(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare("SELECT id, bezeichnung, signaltyp FROM verbindung WHERE projekt_id = :pid ORDER BY id");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "verbindungenProjektLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]          = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")] = q.value(1).toString();
        m[QStringLiteral("signaltyp")]   = q.value(2).toString();
        result.append(m);
    }
    return result;
}

// ============================================================
// naechsteFreiePotenzialNummer
// Gibt die nächste freie Bezeichnung nach Schema (praefix + Nummer)
// zurück, die noch nicht in verbindung.bezeichnung vergeben ist.
// ============================================================
QString Database::naechsteFreiePotenzialNummer(int projektId,
                                                const QString &praefix,
                                                int start, int schrittweite)
{
    QSqlQuery q;
    q.prepare("SELECT bezeichnung FROM verbindung WHERE projekt_id = :pid AND bezeichnung IS NOT NULL");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return praefix + QString::number(start);

    QSet<int> verwendet;
    while (q.next()) {
        QString bez = q.value(0).toString();
        if (!bez.startsWith(praefix)) continue;
        QString rest = bez.mid(praefix.length());
        bool ok = false;
        int n = rest.toInt(&ok);
        if (ok) verwendet.insert(n);
    }
    int n = start;
    const int sc = schrittweite > 0 ? schrittweite : 1;
    while (verwendet.contains(n)) n += sc;
    return praefix + QString::number(n);
}

// ============================================================
// verbindungenBulkBezeichnungSetzen
// Setzt in einer Transaktion die Bezeichnung mehrerer Verbindungen.
// zuweisungen: [{id (int), bezeichnung (string)}]
// ============================================================
bool Database::verbindungenBulkBezeichnungSetzen(int projektId, const QVariantList &zuweisungen)
{
    if (zuweisungen.isEmpty()) return true;
    if (!m_db.transaction()) {
        qWarning() << "verbindungenBulkBezeichnungSetzen: transaction:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q;
    q.prepare("UPDATE verbindung SET bezeichnung = :bez WHERE id = :id AND projekt_id = :pid");
    for (const QVariant &var : zuweisungen) {
        QVariantMap m = var.toMap();
        QString bez = m.value(QStringLiteral("bezeichnung")).toString();
        q.bindValue(":bez", bez.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : bez);
        q.bindValue(":id",  m.value(QStringLiteral("id")).toInt());
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qWarning() << "verbindungenBulkBezeichnungSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    return m_db.commit();
}

// ============================================================
// alleSeitenFlach
// Gibt alle Seiten eines Projekts als flache Liste zurück.
// Wird im EigenschaftenPanel für den Querverweis-Seitenpicker
// benötigt: [{id, blattnummer, bezeichnung}].
// ============================================================
QVariantList Database::alleSeitenFlach(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT s.id, s.blattnummer, COALESCE(s.bezeichnung, '')
        FROM seite s
        JOIN ort     o ON o.id  = s.ort_id
        JOIN anlage  a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
        ORDER BY s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "alleSeitenFlach:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap s;
        s[QStringLiteral("id")]          = q.value(0).toInt();
        s[QStringLiteral("blattnummer")] = q.value(1).toString();
        s[QStringLiteral("bezeichnung")] = q.value(2).toString();
        result.append(s);
    }
    return result;
}

// ============================================================
// querverweiseLadenProjekt
// Alle Querverweis-Elemente eines Projekts seitenübergreifend.
// Gibt [{seiteId, blattnummer, seitenBezeichnung,
//        signalname, richtung, x1, y1}] zurück.
// ============================================================
QVariantList Database::querverweiseLadenProjekt(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.seite_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS s_bez,
               ge.extra_daten,
               ge.x1, ge.y1,
               COALESCE(a.kuerzel, '') AS anlage_kuerzel,
               COALESCE(o.kuerzel, '') AS ort_kuerzel
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id  = 'querverweis'
        ORDER BY s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "querverweiseLadenProjekt:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seiteId")]           = q.value(0).toInt();
        m[QStringLiteral("blattnummer")]        = q.value(1).toString();
        m[QStringLiteral("seitenBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("x1")]                 = q.value(4).toDouble();
        m[QStringLiteral("y1")]                 = q.value(5).toDouble();
        m[QStringLiteral("anlageKuerzel")]       = q.value(6).toString();
        m[QStringLiteral("ortKuerzel")]          = q.value(7).toString();

        QString signalname, richtung;
        QString extraStr = q.value(3).toString();
        if (!extraStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname = obj[QStringLiteral("signalname")].toString();
                richtung   = obj[QStringLiteral("richtung")].toString();
            }
        }
        if (richtung.isEmpty()) richtung = QStringLiteral("ausgang");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;

        result.append(m);
    }
    return result;
}

// ============================================================
// stueckliste
// Alle platzierten Symbole (ohne Verbindungshelfer) mit BMK,
// Freitexten und Seiteninfo für ein Projekt.
// ============================================================
QVariantList Database::stueckliste(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten, ge.symbol_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
               a.kuerzel AS anlage_kz,
               o.kuerzel AS ort_kz,
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'symbol'
          AND ge.symbol_id NOT IN (
              'winkel','treffpunkt','geraeteanschluss','unterbrechung',
              'querverweis','aderdefinition','potenzial')
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "stueckliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("symbolId")]  = q.value(1).toString();
        m[QStringLiteral("seite")]     = q.value(2).toString();
        m[QStringLiteral("seiteBez")]  = q.value(3).toString();
        m[QStringLiteral("anlageKz")]  = q.value(4).toString();
        m[QStringLiteral("ortKz")]     = q.value(5).toString();

        QString extra = q.value(0).toString();
        QString bmk, ft1, ft2;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bmk = obj[QStringLiteral("bmk")].toString();
                ft1 = obj[QStringLiteral("freitext1")].toString();
                ft2 = obj[QStringLiteral("freitext2")].toString();
            }
        }
        m[QStringLiteral("bmk")]       = bmk;
        m[QStringLiteral("freitext1")] = ft1;
        m[QStringLiteral("freitext2")] = ft2;

        QString skExtra = q.value(6).toString();
        QString anlageUO, ortUO;
        if (!skExtra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(skExtra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                anlageUO = obj[QStringLiteral("anlageUO")].toString();
                ortUO    = obj[QStringLiteral("ortUO")].toString();
                // = und + aus Strukturkasten überschreiben Seitenbaum-Werte
                QString skAnlage = obj[QStringLiteral("anlage")].toString();
                QString skOrt    = obj[QStringLiteral("ort")].toString();
                if (!skAnlage.isEmpty()) m[QStringLiteral("anlageKz")] = skAnlage;
                if (!skOrt.isEmpty())    m[QStringLiteral("ortKz")]    = skOrt;
            }
        }
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        result.append(m);
    }
    return result;
}

// ============================================================
// querverweisListe
// Alle Querverweis-Symbole eines Projekts mit Signalname,
// Richtung, eigener Seite und Zielseite.
// ============================================================
QVariantList Database::querverweisListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id = 'querverweis'
        ORDER BY s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "querverweisListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seite")]    = q.value(1).toString();
        m[QStringLiteral("seiteBez")] = q.value(2).toString();

        QString signalname, richtung;
        int     zielSeiteId = -1;
        QString extra = q.value(0).toString();
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname  = obj[QStringLiteral("signalname")].toString();
                richtung    = obj[QStringLiteral("richtung")].toString();
                zielSeiteId = obj[QStringLiteral("zielSeiteId")].toInt(-1);
            }
        }
        if (richtung.isEmpty()) richtung = QStringLiteral("ausgang");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;

        QString zielBlatt;
        if (zielSeiteId > 0) {
            QSqlQuery qs;
            qs.prepare("SELECT blattnummer FROM seite WHERE id = :id");
            qs.bindValue(":id", zielSeiteId);
            if (qs.exec() && qs.next())
                zielBlatt = qs.value(0).toString();
        }
        m[QStringLiteral("zielSeite")] = zielBlatt;
        result.append(m);
    }
    return result;
}

// ============================================================
// aderliste
// Alle Aderdefinitionspunkte eines Projekts mit Aderfarbe,
// Querschnitt, Länge, Bezeichnung und Seiteninfo.
// ============================================================
QVariantList Database::aderliste(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten,
               s.blattnummer,
               a.kuerzel AS anlage_kz,
               o.kuerzel AS ort_kz,
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ       = 'symbol'
          AND ge.symbol_id = 'aderdefinition'
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "aderliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seite")]    = q.value(1).toString();
        m[QStringLiteral("anlageKz")] = q.value(2).toString();
        m[QStringLiteral("ortKz")]    = q.value(3).toString();

        QString extra = q.value(0).toString();
        QString bezeichnung, aderfarbe;
        double  querschnitt = 0.0, laenge = 0.0;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bezeichnung = obj[QStringLiteral("bezeichnung")].toString();
                aderfarbe   = obj[QStringLiteral("aderfarbe")].toString();
                querschnitt = obj[QStringLiteral("querschnitt_mm2")].toDouble(0.0);
                laenge      = obj[QStringLiteral("laenge_m")].toDouble(0.0);
            }
        }
        m[QStringLiteral("bezeichnung")]    = bezeichnung;
        m[QStringLiteral("aderfarbe")]      = aderfarbe;
        m[QStringLiteral("querschnittMm2")] = querschnitt;
        m[QStringLiteral("laengeM")]        = laenge;

        QString skExtra = q.value(4).toString();
        QString anlageUO, ortUO;
        if (!skExtra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(skExtra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                anlageUO = obj[QStringLiteral("anlageUO")].toString();
                ortUO    = obj[QStringLiteral("ortUO")].toString();
                // = und + aus Strukturkasten überschreiben Seitenbaum-Werte
                QString skAnlage = obj[QStringLiteral("anlage")].toString();
                QString skOrt    = obj[QStringLiteral("ort")].toString();
                if (!skAnlage.isEmpty()) m[QStringLiteral("anlageKz")] = skAnlage;
                if (!skOrt.isEmpty())    m[QStringLiteral("ortKz")]    = skOrt;
            }
        }
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        result.append(m);
    }
    return result;
}

// ============================================================
// Betriebsmittel-Verknüpfung
// ============================================================

QVariantList Database::betriebsmittelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT b.id, b.betriebsmittel_kz, b.bezeichnung, "
        "       COUNT(g.id) AS anzahl "
        "FROM betriebsmittel b "
        "LEFT JOIN grafik_element g ON g.betriebsmittel_id = b.id "
        "WHERE b.projekt_id = :pid "
        "GROUP BY b.id ORDER BY b.betriebsmittel_kz");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]             = q.value(0).toInt();
        m[QStringLiteral("kz")]             = q.value(1).toString();
        m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        m[QStringLiteral("anzahl")]         = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

int Database::betriebsmittelAnlegen(int projektId, const QString &kz, const QString &bezeichnung)
{
    QSqlQuery q;
    q.prepare("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz, bezeichnung) "
              "VALUES (:pid, :kz, :bez)");
    q.bindValue(":pid", projektId);
    q.bindValue(":kz",  kz);
    q.bindValue(":bez", bezeichnung);
    if (!q.exec()) {
        qWarning() << "betriebsmittelAnlegen Fehler:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::grafikElementVerknuepfen(int elementId, int betriebsmittelId)
{
    QSqlQuery q;
    q.prepare("UPDATE grafik_element SET betriebsmittel_id = :bid WHERE id = :id");
    q.bindValue(":bid", betriebsmittelId);
    q.bindValue(":id",  elementId);
    if (!q.exec()) {
        qWarning() << "grafikElementVerknuepfen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::grafikElementEntknuepfen(int elementId)
{
    // Falls dieses Element Hauptfunktion ist → haupt_element_id freigeben
    QSqlQuery clr;
    clr.prepare("UPDATE betriebsmittel SET haupt_element_id = NULL "
                "WHERE haupt_element_id = :eid");
    clr.bindValue(":eid", elementId);
    clr.exec();

    QSqlQuery q;
    q.prepare("UPDATE grafik_element SET betriebsmittel_id = NULL WHERE id = :id");
    q.bindValue(":id", elementId);
    if (!q.exec()) {
        qWarning() << "grafikElementEntknuepfen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::betriebsmittelMitglieder(int betriebsmittelId)
{
    // haupt_element_id laden um istHauptfunktion zu bestimmen
    int hauptId = 0;
    {
        QSqlQuery hq;
        hq.prepare("SELECT haupt_element_id FROM betriebsmittel WHERE id = :id");
        hq.bindValue(":id", betriebsmittelId);
        if (hq.exec() && hq.next() && !hq.value(0).isNull())
            hauptId = hq.value(0).toInt();
    }

    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT g.id, s.blattnummer, s.bezeichnung, g.extra_daten, g.symbol_id, g.typ "
        "FROM grafik_element g "
        "JOIN seite s ON s.id = g.seite_id "
        "WHERE g.betriebsmittel_id = :bid "
        "ORDER BY s.blattnummer, g.id");
    q.bindValue(":bid", betriebsmittelId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        int gid = q.value(0).toInt();
        m[QStringLiteral("id")]               = gid;
        m[QStringLiteral("blattnummer")]      = q.value(1).toString();
        m[QStringLiteral("seiteBezeichnung")] = q.value(2).toString();
        m[QStringLiteral("symbolId")]         = q.value(4).toString();
        m[QStringLiteral("typ")]              = q.value(5).toString();
        m[QStringLiteral("istHauptfunktion")] = (hauptId > 0 && gid == hauptId);
        QString extra = q.value(3).toString();
        QString bmk;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject())
                bmk = doc.object()[QStringLiteral("bmk")].toString();
        }
        m[QStringLiteral("bmk")] = bmk;
        result.append(m);
    }
    return result;
}

QString Database::betriebsmittelKz(int betriebsmittelId)
{
    QSqlQuery q;
    q.prepare("SELECT betriebsmittel_kz FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return {};
}

QVariantMap Database::betriebsmittelInfo(int betriebsmittelId)
{
    QVariantMap m;
    QSqlQuery q;
    q.prepare("SELECT id, betriebsmittel_kz, bezeichnung, haupt_element_id "
              "FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (!q.exec() || !q.next()) return m;
    m[QStringLiteral("id")]             = q.value(0).toInt();
    m[QStringLiteral("kz")]             = q.value(1).toString();
    m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
    m[QStringLiteral("hauptElementId")] = q.value(3).isNull() ? 0 : q.value(3).toInt();
    return m;
}

bool Database::betriebsmittelHauptfunktionSetzen(int betriebsmittelId, int elementId)
{
    QSqlQuery q;
    q.prepare("UPDATE betriebsmittel SET haupt_element_id = :eid WHERE id = :bid");
    q.bindValue(":eid", elementId);
    q.bindValue(":bid", betriebsmittelId);
    if (!q.exec()) {
        qWarning() << "betriebsmittelHauptfunktionSetzen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::betriebsmittelBmkSynchronisieren(int betriebsmittelId)
{
    QString kz = betriebsmittelKz(betriebsmittelId);
    if (kz.isEmpty()) return false;

    QSqlQuery sel;
    sel.prepare("SELECT id, extra_daten FROM grafik_element WHERE betriebsmittel_id = :bid");
    sel.bindValue(":bid", betriebsmittelId);
    if (!sel.exec()) return false;

    QSqlQuery upd;
    upd.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    while (sel.next()) {
        int gid = sel.value(0).toInt();
        QString extra = sel.value(1).toString();
        QJsonObject obj;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject())
                obj = doc.object();
        }
        obj[QStringLiteral("bmk")] = kz;
        upd.bindValue(":ed", QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
        upd.bindValue(":id", gid);
        if (!upd.exec())
            qWarning() << "betriebsmittelBmkSynchronisieren Fehler Element" << gid << upd.lastError().text();
    }
    return true;
}

QVariantList Database::betriebsmittelHfListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT b.id, b.haupt_element_id, s.blattnummer, g.seite_id "
        "FROM betriebsmittel b "
        "JOIN grafik_element g ON g.id = b.haupt_element_id "
        "JOIN seite s ON s.id = g.seite_id "
        "WHERE b.projekt_id = :pid "
        "  AND b.haupt_element_id IS NOT NULL");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("betriebsmittelId")] = q.value(0).toInt();
        m[QStringLiteral("hauptElementId")]   = q.value(1).toInt();
        m[QStringLiteral("blattnummer")]      = q.value(2).toString();
        m[QStringLiteral("seiteId")]          = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// klemmenplan
// ============================================================
QVariantList Database::klemmenplan(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT kl.id, kl.bezeichnung, "
        "COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung), "
        "k.id, k.nummer, k.sortierung, "
        "COALESCE(b.bezeichnung,''), "
        "COALESCE(bk.anschluss_typ,''), "
        "COALESCE(fd.bezeichnung,''), "
        "COALESCE(fd.hex_wert,''), "
        "COALESCE(kl.standort_uebergeordnet,''), "
        "(SELECT MIN(bkq.min_mm2) || '\xe2\x80\x93' || MAX(bkq.max_mm2) || ' mm\xc2\xb2' "
        "   FROM bauteil_klemme_querschnitt bkq WHERE bkq.klemme_id = bk.id), "
        "(SELECT ks.potenzial_text FROM klemme_stegbruecke ks "
        " WHERE ks.klemmenleiste_id = kl.id "
        " AND (ks.von_klemme_id = k.id OR ks.bis_klemme_id = k.id) "
        " AND ks.potenzial_text IS NOT NULL LIMIT 1) "
        "FROM klemmenleiste kl "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "JOIN klemme k ON k.klemmenleiste_id = kl.id "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN farb_definition fd ON fd.id = bk.gehaeuse_farbe_id "
        "WHERE kl.projekt_id = :pid "
        "ORDER BY kl.bezeichnung, k.sortierung, k.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "Database::klemmenplan:" << q.lastError().text();
        return result;
    }

    int lastLeistenId = -1;
    while (q.next()) {
        int leisteId = q.value(0).toInt();

        if (leisteId != lastLeistenId) {
            QVariantMap row;
            row[QStringLiteral("typ")]         = QStringLiteral("leiste");
            row[QStringLiteral("leisteId")]    = leisteId;
            row[QStringLiteral("bezeichnung")] = q.value(1).toString();
            row[QStringLiteral("bmk")]         = q.value(2).toString();
            result.append(row);
            lastLeistenId = leisteId;
        }

        QString typ = q.value(7).toString();
        if      (typ == QLatin1String("schraube"))      typ = QStringLiteral("Schraube");
        else if (typ == QLatin1String("feder"))         typ = QStringLiteral("Feder");
        else if (typ == QLatin1String("push_in"))       typ = QStringLiteral("Push-In");
        else if (typ == QLatin1String("schneidklemme")) typ = QStringLiteral("Schneidklemme");

        QVariantMap row;
        row[QStringLiteral("typ")]          = QStringLiteral("klemme");
        row[QStringLiteral("leisteId")]     = leisteId;
        row[QStringLiteral("leisteBmk")]    = q.value(2).toString();
        row[QStringLiteral("nummer")]       = q.value(4).toString();
        row[QStringLiteral("bauteilBez")]   = q.value(6).toString();
        row[QStringLiteral("anschlussTyp")] = typ;
        row[QStringLiteral("farbeBez")]     = q.value(8).toString();
        row[QStringLiteral("farbeHex")]     = q.value(9).toString();
        row[QStringLiteral("ortKz")]        = q.value(10).toString();
        row[QStringLiteral("querschnitt")]  = q.value(11).isNull() ? QString() : q.value(11).toString();
        row[QStringLiteral("potenzial")]    = q.value(12).isNull() ? QString() : q.value(12).toString();
        result.append(row);
    }
    return result;
}

// ============================================================
// klemmenplanCsvSpeichern
// ============================================================
bool Database::klemmenplanCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "klemmenplanCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";  // UTF-8 BOM für Excel
    out << "Leiste;Nr.;Bauteil;Typ;Querschnitt;Farbe;Potenzial;Ort\n";

    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };

    for (const QVariant &v : klemmenplan(projektId)) {
        const QVariantMap row = v.toMap();
        if (row[QStringLiteral("typ")] != QLatin1String("klemme")) continue;
        out << csvQ(row[QStringLiteral("leisteBmk")].toString())   << u';'
            << csvQ(row[QStringLiteral("nummer")].toString())       << u';'
            << csvQ(row[QStringLiteral("bauteilBez")].toString())   << u';'
            << csvQ(row[QStringLiteral("anschlussTyp")].toString()) << u';'
            << csvQ(row[QStringLiteral("querschnitt")].toString())  << u';'
            << csvQ(row[QStringLiteral("farbeBez")].toString())     << u';'
            << csvQ(row[QStringLiteral("potenzial")].toString())    << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())        << u'\n';
    }
    return true;
}

// ============================================================
// stuecklisteCsvSpeichern
// ============================================================
bool Database::stuecklisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "stuecklisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "BMK;Typ;Freitext 1;Freitext 2;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : stueckliste(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("bmk")].toString())       << u';'
            << csvQ(row[QStringLiteral("symbolId")].toString())  << u';'
            << csvQ(row[QStringLiteral("freitext1")].toString()) << u';'
            << csvQ(row[QStringLiteral("freitext2")].toString()) << u';'
            << csvQ(row[QStringLiteral("seite")].toString())     << u';'
            << csvQ(row[QStringLiteral("anlageUO")].toString())  << u';'
            << csvQ(row[QStringLiteral("ortUO")].toString())     << u';'
            << csvQ(row[QStringLiteral("anlageKz")].toString())  << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())     << u'\n';
    }
    return true;
}

// ============================================================
// querverweislisteCsvSpeichern
// ============================================================
bool Database::querverweislisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "querverweislisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Signalname;Richtung;Seite;Zielseite\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : querverweisListe(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("signalname")].toString()) << u';'
            << csvQ(row[QStringLiteral("richtung")].toString())   << u';'
            << csvQ(row[QStringLiteral("seite")].toString())      << u';'
            << csvQ(row[QStringLiteral("zielSeite")].toString())  << u'\n';
    }
    return true;
}

// ============================================================
// aderlisteCsvSpeichern
// ============================================================
bool Database::aderlisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "aderlisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Bezeichnung;Aderfarbe;Querschnitt mm2;Laenge m;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : aderliste(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("bezeichnung")].toString())                          << u';'
            << csvQ(row[QStringLiteral("aderfarbe")].toString())                            << u';'
            << csvQ(row[QStringLiteral("querschnittMm2")].toDouble() > 0
                    ? QString::number(row[QStringLiteral("querschnittMm2")].toDouble()) : QString()) << u';'
            << csvQ(row[QStringLiteral("laengeM")].toDouble() > 0
                    ? QString::number(row[QStringLiteral("laengeM")].toDouble()) : QString())        << u';'
            << csvQ(row[QStringLiteral("seite")].toString())    << u';'
            << csvQ(row[QStringLiteral("anlageUO")].toString()) << u';'
            << csvQ(row[QStringLiteral("ortUO")].toString())    << u';'
            << csvQ(row[QStringLiteral("anlageKz")].toString()) << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())    << u'\n';
    }
    return true;
}

// ============================================================
// kabellisteCsvSpeichern
// ============================================================
bool Database::kabellisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "kabellisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Kabel-BMK;Kabeltyp;Von-Ort;Nach-Ort;Ader-Nr;Farbe;Bezeichnung;Seite;Netz\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &kv : kabelListeAufgeschluesselt(projektId)) {
        const QVariantMap k = kv.toMap();
        const QString bmk     = k[QStringLiteral("bezeichnung")].toString();
        const QString typ     = k[QStringLiteral("kabeltyp")].toString();
        const QString vonOrt  = k[QStringLiteral("vonOrt")].toString();
        const QString nachOrt = k[QStringLiteral("nachOrt")].toString();
        const QVariantList adern = k[QStringLiteral("adern")].toList();
        if (adern.isEmpty()) {
            // Kabel ohne Adern: eine Zeile nur mit Kabel-Metadaten
            out << csvQ(bmk) << u';' << csvQ(typ) << u';'
                << csvQ(vonOrt) << u';' << csvQ(nachOrt)
                << u";;;;;" << u'\n';
        } else {
            for (const QVariant &av : adern) {
                const QVariantMap a = av.toMap();
                const QString seite = a[QStringLiteral("blattnummer")].toString();
                const QString seiteBez = a[QStringLiteral("seitenBez")].toString();
                const QString seiteSpalte = seite.isEmpty() ? QString()
                    : (seiteBez.isEmpty() ? seite : seite + u' ' + seiteBez);
                out << csvQ(bmk)     << u';'
                    << csvQ(typ)     << u';'
                    << csvQ(vonOrt)  << u';'
                    << csvQ(nachOrt) << u';'
                    << csvQ(QString::number(a[QStringLiteral("nr")].toInt())) << u';'
                    << csvQ(a[QStringLiteral("farbe")].toString())       << u';'
                    << csvQ(a[QStringLiteral("bezeichnung")].toString()) << u';'
                    << csvQ(seiteSpalte)                                  << u';'
                    << csvQ(a[QStringLiteral("netz")].toString())        << u'\n';
            }
        }
    }
    return true;
}

// ============================================================
// seiteBasisDaten – Blattnummer + Bezeichnung für eine Seite
// ============================================================
QVariantMap Database::seiteBasisDaten(int seiteId)
{
    QSqlQuery q;
    q.prepare("SELECT blattnummer, COALESCE(bezeichnung,'') FROM seite WHERE id = :id");
    q.bindValue(":id", seiteId);
    if (!q.exec() || !q.next()) return {};
    QVariantMap m;
    m[QStringLiteral("blattnummer")] = q.value(0).toString();
    m[QStringLiteral("bezeichnung")] = q.value(1).toString();
    return m;
}

// ============================================================
// normblattDatenLaden / normblattAnzeigenSetzen
// ============================================================
QVariantMap Database::normblattDatenLaden(int seiteId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT s.blattnummer, s.bezeichnung, s.anlage_kuerzel, s.ort_kuerzel,
               s.breite_mm, s.hoehe_mm, s.normblatt_anzeigen,
               s.hintergrund_farbe, s.aussen_overlay, s.titelblatt_vorlage,
               p.name         AS projekt_name,
               p.projektnummer,
               p.auftraggeber,
               p.auftragnehmer,
               p.bearbeiter,
               p.norm,
               p.erstellt_am,
               COALESCE(s.rand_links_mm,  nv.rand_links_mm,  20) AS rand_links_mm,
               COALESCE(s.rand_rechts_mm, nv.rand_rechts_mm, 10) AS rand_rechts_mm,
               COALESCE(s.rand_oben_mm,   nv.rand_oben_mm,   10) AS rand_oben_mm,
               COALESCE(s.rand_unten_mm,  nv.rand_unten_mm,  10) AS rand_unten_mm
        FROM seite s
        JOIN ort     o  ON s.ort_id      = o.id
        JOIN anlage  a  ON o.anlage_id   = a.id
        JOIN projekt p  ON a.projekt_id  = p.id
        LEFT JOIN normblatt_vorlage nv ON s.normblatt_id = nv.id
        WHERE s.id = :sid
    )");
    q.bindValue(":sid", seiteId);

    QVariantMap m;
    if (!q.exec() || !q.next()) {
        qWarning() << "normblattDatenLaden:" << q.lastError().text();
        return m;
    }
    m[QStringLiteral("blattnummer")]      = q.value("blattnummer");
    m[QStringLiteral("bezeichnung")]      = q.value("bezeichnung");
    m[QStringLiteral("anlageKuerzel")]    = q.value("anlage_kuerzel");
    m[QStringLiteral("ortKuerzel")]       = q.value("ort_kuerzel");
    m[QStringLiteral("breiteMm")]         = q.value("breite_mm");
    m[QStringLiteral("hoeheMm")]          = q.value("hoehe_mm");
    m[QStringLiteral("normblattAnzeigen")] = q.value("normblatt_anzeigen");
    m[QStringLiteral("hintergrundFarbe")] = q.value("hintergrund_farbe");
    m[QStringLiteral("aussenOverlay")]    = q.value("aussen_overlay");
    m[QStringLiteral("titelblattVorlage")]= q.value("titelblatt_vorlage");
    m[QStringLiteral("projektName")]      = q.value("projekt_name");
    m[QStringLiteral("projektnummer")]    = q.value("projektnummer");
    m[QStringLiteral("auftraggeber")]     = q.value("auftraggeber");
    m[QStringLiteral("auftragnehmer")]    = q.value("auftragnehmer");
    m[QStringLiteral("bearbeiter")]       = q.value("bearbeiter");
    m[QStringLiteral("norm")]             = q.value("norm");

    // Logo als Data-URL — separater Query damit der BLOB-Join nicht bei jeder
    // Seite lädt wenn kein Logo gesetzt ist.
    {
        QSqlQuery ql;
        ql.prepare(R"(
            SELECT p.logo_data, p.logo_mime
            FROM seite s
            JOIN ort o ON s.ort_id = o.id
            JOIN anlage a ON o.anlage_id = a.id
            JOIN projekt p ON a.projekt_id = p.id
            WHERE s.id = :sid AND p.logo_data IS NOT NULL
        )");
        ql.bindValue(":sid", seiteId);
        if (ql.exec() && ql.next()) {
            QByteArray logoData = ql.value(0).toByteArray();
            QString    logoMime = ql.value(1).toString();
            if (!logoData.isEmpty() && !logoMime.isEmpty())
                m[QStringLiteral("logoDataUrl")] = QStringLiteral("data:") + logoMime
                    + QStringLiteral(";base64,") + QString::fromLatin1(logoData.toBase64());
        }
    }
    m[QStringLiteral("erstelltAm")]       = q.value("erstellt_am");
    m[QStringLiteral("randLinksMm")]      = q.value("rand_links_mm");
    m[QStringLiteral("randRechtsMm")]     = q.value("rand_rechts_mm");
    m[QStringLiteral("randObenMm")]       = q.value("rand_oben_mm");
    m[QStringLiteral("randUntenMm")]      = q.value("rand_unten_mm");

    // Benutzerdefinierte Felder laden (nur wenn normblatt_id gesetzt)
    {
        QSqlQuery qnid;
        qnid.prepare("SELECT normblatt_id FROM seite WHERE id = :sid");
        qnid.bindValue(":sid", seiteId);
        if (qnid.exec() && qnid.next()) {
            QVariant normblattId = qnid.value(0);
            if (!normblattId.isNull() && normblattId.toInt() > 0) {
                m[QStringLiteral("normblattVorlageId")] = normblattId;
                m[QStringLiteral("felder")] = normblattFelderLaden(normblattId.toInt());
            }
        }
    }

    return m;
}

bool Database::normblattEinstellungenSetzen(int seiteId, bool anzeigen,
                                             const QString &hintergrundFarbe,
                                             bool aussenOverlay,
                                             const QString &titelblattVorlage,
                                             int normblattId)
{
    QSqlQuery q;
    q.prepare(R"(UPDATE seite SET
        normblatt_anzeigen = :an,
        hintergrund_farbe  = :hf,
        aussen_overlay     = :ao,
        titelblatt_vorlage = :tv,
        normblatt_id       = :nid
        WHERE id = :sid)");
    q.bindValue(":an",  anzeigen ? 1 : 0);
    q.bindValue(":hf",  hintergrundFarbe);
    q.bindValue(":ao",  aussenOverlay ? 1 : 0);
    q.bindValue(":tv",  titelblattVorlage.isEmpty() ? QStringLiteral("din6771") : titelblattVorlage);
    q.bindValue(":nid", normblattId > 0 ? QVariant(normblattId) : QVariant());
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "normblattEinstellungenSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// normblattVorlagen* / normblattFelder*
// ============================================================

QVariantList Database::normblattVorlagenListe()
{
    QSqlQuery q;
    if (!q.exec("SELECT id, name, beschreibung, ist_standard, breite_mm, hoehe_mm, "
                "rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm "
                "FROM normblatt_vorlage ORDER BY name")) {
        qWarning() << "normblattVorlagenListe:" << q.lastError().text();
        return {};
    }
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]           = q.value("id");
        m[QStringLiteral("name")]         = q.value("name");
        m[QStringLiteral("beschreibung")] = q.value("beschreibung");
        m[QStringLiteral("istStandard")]  = q.value("ist_standard");
        m[QStringLiteral("breiteMm")]     = q.value("breite_mm");
        m[QStringLiteral("hoeheMm")]      = q.value("hoehe_mm");
        m[QStringLiteral("randLinksMm")]  = q.value("rand_links_mm");
        m[QStringLiteral("randRechtsMm")] = q.value("rand_rechts_mm");
        m[QStringLiteral("randObenMm")]   = q.value("rand_oben_mm");
        m[QStringLiteral("randUntenMm")]  = q.value("rand_unten_mm");
        result.append(m);
    }
    return result;
}

int Database::normblattVorlageSpeichern(const QVariantMap &v)
{
    QSqlQuery q;
    if (v.value(QStringLiteral("id")).toInt() > 0) {
        q.prepare(R"(UPDATE normblatt_vorlage SET
            name           = :name,
            beschreibung   = :beschr,
            breite_mm      = :bMm,
            hoehe_mm       = :hMm,
            rand_links_mm  = :rl,
            rand_rechts_mm = :rr,
            rand_oben_mm   = :ro,
            rand_unten_mm  = :ru
            WHERE id = :id)");
        q.bindValue(":id",    v.value(QStringLiteral("id")));
    } else {
        q.prepare(R"(INSERT INTO normblatt_vorlage
            (name, beschreibung, breite_mm, hoehe_mm,
             rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm)
            VALUES (:name, :beschr, :bMm, :hMm, :rl, :rr, :ro, :ru))");
    }
    q.bindValue(":name",   v.value(QStringLiteral("name")));
    q.bindValue(":beschr", v.value(QStringLiteral("beschreibung")));
    q.bindValue(":bMm",    v.value(QStringLiteral("breiteMm"),    297.0));
    q.bindValue(":hMm",    v.value(QStringLiteral("hoeheMm"),     210.0));
    q.bindValue(":rl",     v.value(QStringLiteral("randLinksMm"),  20.0));
    q.bindValue(":rr",     v.value(QStringLiteral("randRechtsMm"), 10.0));
    q.bindValue(":ro",     v.value(QStringLiteral("randObenMm"),   10.0));
    q.bindValue(":ru",     v.value(QStringLiteral("randUntenMm"),  10.0));
    if (!q.exec()) {
        qWarning() << "normblattVorlageSpeichern:" << q.lastError().text();
        return -1;
    }
    if (v.value(QStringLiteral("id")).toInt() > 0)
        return v.value(QStringLiteral("id")).toInt();
    return q.lastInsertId().toInt();
}

bool Database::normblattVorlageLoeschen(int vorlageId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM normblatt_vorlage WHERE id = :id");
    q.bindValue(":id", vorlageId);
    if (!q.exec()) {
        qWarning() << "normblattVorlageLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::normblattFelderLaden(int vorlageId)
{
    QSqlQuery q;
    q.prepare(R"(SELECT id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm,
                        label, inhalt, quelle_spalte,
                        schriftgroesse, fett, rahmen, reihenfolge
                 FROM normblatt_feld
                 WHERE vorlage_id = :vid
                 ORDER BY reihenfolge, id)");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qWarning() << "normblattFelderLaden:" << q.lastError().text();
        return {};
    }
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]            = q.value("id");
        m[QStringLiteral("feldtyp")]       = q.value("feldtyp");
        m[QStringLiteral("xMm")]           = q.value("x_mm");
        m[QStringLiteral("yMm")]           = q.value("y_mm");
        m[QStringLiteral("breiteMm")]      = q.value("breite_mm");
        m[QStringLiteral("hoeheMm")]       = q.value("hoehe_mm");
        m[QStringLiteral("label")]         = q.value("label");
        m[QStringLiteral("inhalt")]        = q.value("inhalt");
        m[QStringLiteral("quelleSpalte")]  = q.value("quelle_spalte");
        m[QStringLiteral("schriftgroesse")]= q.value("schriftgroesse");
        m[QStringLiteral("fett")]          = q.value("fett");
        m[QStringLiteral("rahmen")]        = q.value("rahmen");
        m[QStringLiteral("reihenfolge")]   = q.value("reihenfolge");
        result.append(m);
    }
    return result;
}

bool Database::normblattFelderSpeichern(int vorlageId, const QVariantList &felder)
{
    QSqlDatabase db = QSqlDatabase::database();
    if (!db.transaction()) {
        qWarning() << "normblattFelderSpeichern: Transaction fehlgeschlagen";
        return false;
    }
    QSqlQuery q;
    q.prepare("DELETE FROM normblatt_feld WHERE vorlage_id = :vid");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qWarning() << "normblattFelderSpeichern DELETE:" << q.lastError().text();
        db.rollback();
        return false;
    }
    q.prepare(R"(INSERT INTO normblatt_feld
        (vorlage_id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm,
         label, inhalt, quelle_spalte, schriftgroesse, fett, rahmen, reihenfolge)
        VALUES (:vid, :ft, :x, :y, :b, :h, :lbl, :inh, :qs, :sg, :fett, :rahmen, :rei))");
    for (int i = 0; i < felder.size(); ++i) {
        const QVariantMap f = felder[i].toMap();
        q.bindValue(":vid",    vorlageId);
        q.bindValue(":ft",     f.value(QStringLiteral("feldtyp"), QStringLiteral("fest")));
        q.bindValue(":x",      f.value(QStringLiteral("xMm"), 0.0));
        q.bindValue(":y",      f.value(QStringLiteral("yMm"), 0.0));
        q.bindValue(":b",      f.value(QStringLiteral("breiteMm"), 50.0));
        q.bindValue(":h",      f.value(QStringLiteral("hoeheMm"), 13.0));
        q.bindValue(":lbl",    f.value(QStringLiteral("label")));
        q.bindValue(":inh",    f.value(QStringLiteral("inhalt")));
        q.bindValue(":qs",     f.value(QStringLiteral("quelleSpalte")));
        q.bindValue(":sg",     f.value(QStringLiteral("schriftgroesse"), 3.5));
        q.bindValue(":fett",   f.value(QStringLiteral("fett"), 0));
        q.bindValue(":rahmen", f.value(QStringLiteral("rahmen"), 1));
        q.bindValue(":rei",    i);
        if (!q.exec()) {
            qWarning() << "normblattFelderSpeichern INSERT:" << q.lastError().text();
            db.rollback();
            return false;
        }
    }
    db.commit();
    return true;
}

bool Database::projektMetaSpeichern(int projektId,
                                     const QString &name,
                                     const QString &projektnummer,
                                     const QString &auftraggeber,
                                     const QString &auftragnehmer,
                                     const QString &bearbeiter)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET name = :name, projektnummer = :nr, "
              "auftraggeber = :ag, auftragnehmer = :an, bearbeiter = :be "
              "WHERE id = :id");
    q.bindValue(":name", name);
    q.bindValue(":nr",   projektnummer);
    q.bindValue(":ag",   auftraggeber);
    q.bindValue(":an",   auftragnehmer);
    q.bindValue(":be",   bearbeiter);
    q.bindValue(":id",   projektId);
    if (!q.exec()) {
        qWarning() << "projektMetaSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::projektLogoSpeichern(int projektId, const QString &pfad)
{
    QUrl url(pfad);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;

    QFileInfo info(localPath);
    if (!info.exists()) { qWarning() << "projektLogoSpeichern: Datei nicht gefunden:" << localPath; return false; }
    if (info.size() > 5 * 1024 * 1024) { qWarning() << "projektLogoSpeichern: Datei zu groß"; return false; }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) { qWarning() << "projektLogoSpeichern: Öffnen fehlgeschlagen"; return false; }
    QByteArray data = file.readAll();
    file.close();

    QString suffix = info.suffix().toLower();
    QString mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg") || suffix == QLatin1String("jpeg")) mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))  mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))  mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("webp")) mime = QStringLiteral("image/webp");

    QSqlQuery q;
    q.prepare("UPDATE projekt SET logo_data = :d, logo_mime = :m WHERE id = :id");
    q.bindValue(":d",  data);
    q.bindValue(":m",  mime);
    q.bindValue(":id", projektId);
    if (!q.exec()) { qWarning() << "projektLogoSpeichern:" << q.lastError().text(); return false; }
    return true;
}

QString Database::projektLogoDataUrl(int projektId)
{
    QSqlQuery q;
    q.prepare("SELECT logo_data, logo_mime FROM projekt WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec() || !q.next()) return {};
    QByteArray data = q.value(0).toByteArray();
    QString    mime = q.value(1).toString();
    if (data.isEmpty() || mime.isEmpty()) return {};
    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

bool Database::projektLogoLoeschen(int projektId)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET logo_data = NULL, logo_mime = NULL WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec()) { qWarning() << "projektLogoLoeschen:" << q.lastError().text(); return false; }
    return true;
}

QVariantList Database::klemmenFuerLeiste(int leisteId) const
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT k.id, k.nummer, k.sortierung, k.bauteil_id, "
        "       bk.id, COALESCE(b.bezeichnung,''), "
        "       COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung) "
        "FROM klemme k "
        "JOIN klemmenleiste kl ON kl.id = k.klemmenleiste_id "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "WHERE k.klemmenleiste_id = :lid "
        "ORDER BY k.sortierung, k.id"
    );
    q.bindValue(":lid", leisteId);
    if (!q.exec()) { qWarning() << "klemmenFuerLeiste:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap row;
        row[QStringLiteral("id")]             = q.value(0).toInt();
        row[QStringLiteral("nummer")]         = q.value(1).toString();
        row[QStringLiteral("sortierung")]     = q.value(2).toInt();
        row[QStringLiteral("bauteilId")]      = q.value(3).toInt();
        row[QStringLiteral("bauteilKlemmeId")]= q.value(4).toInt();
        row[QStringLiteral("bezeichnung")]    = q.value(5).toString();
        row[QStringLiteral("leisteBmk")]      = q.value(6).toString();
        result.append(row);
    }
    return result;
}

QVariantList Database::anschluesseFuerKlemme(int bauteilId) const
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT ebenen_anzahl, punkte_seite_a, punkte_seite_b, fuss_kontakt_pe "
        "FROM bauteil_klemme WHERE bauteil_id = :bid"
    );
    q.bindValue(":bid", bauteilId);
    if (!q.exec() || !q.next()) return result;

    int  ebenen = q.value(0).toInt();
    int  pA     = q.value(1).toInt();
    int  pB     = q.value(2).toInt();
    bool pe     = q.value(3).toInt() != 0;

    for (int e = 1; e <= ebenen; ++e) {
        int idx = 1;
        for (int a = 0; a < pA; ++a, ++idx) {
            QVariantMap anschluss;
            anschluss[QStringLiteral("bezeichnung")] = QString("%1.%2").arg(e).arg(idx);
            anschluss[QStringLiteral("seite")]       = QStringLiteral("A");
            anschluss[QStringLiteral("ebene")]       = e;
            result.append(anschluss);
        }
        for (int b = 0; b < pB; ++b, ++idx) {
            QVariantMap anschluss;
            anschluss[QStringLiteral("bezeichnung")] = QString("%1.%2").arg(e).arg(idx);
            anschluss[QStringLiteral("seite")]       = QStringLiteral("B");
            anschluss[QStringLiteral("ebene")]       = e;
            result.append(anschluss);
        }
    }
    if (pe) {
        QVariantMap anschluss;
        anschluss[QStringLiteral("bezeichnung")] = QStringLiteral("PE");
        anschluss[QStringLiteral("seite")]       = QString::fromUtf8("Fu\xc3\x9f");
        anschluss[QStringLiteral("ebene")]       = QStringLiteral("\xe2\x80\x93");
        result.append(anschluss);
    }
    return result;
}

// ============================================================
// kabelAnlegen
// Legt einen neuen kabel-Datensatz an und verknüpft ihn mit
// dem grafik_element der Kabeldefinitionslinie.
// Gibt die neue kabel-ID zurück oder -1 bei Fehler.
// ============================================================
int Database::kabelAnlegen(int projektId, const QString &bezeichnung,
                           const QString &kabeltyp, int aderzahl,
                           double querschnittMm2, int grafikElementId,
                           const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO kabel (projekt_id, bezeichnung, kabeltyp, aderzahl,
                           querschnitt_mm2, grafik_element_id, von_ort, nach_ort)
        VALUES (:pid, :bez, :typ, :anz, :qs, :geid, :von, :nach)
    )");
    q.bindValue(":pid",  projektId);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":geid", grafikElementId > 0 ? grafikElementId : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    if (!q.exec()) {
        qWarning() << "kabelAnlegen fehlgeschlagen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ============================================================
// kabelAderZuordnen
// Legt eine kabel_ader-Zeile an (oder aktualisiert sie falls
// ader_nr für dieses Kabel bereits vorhanden).
// ============================================================
bool Database::kabelAderZuordnen(int kabelId, int aderNr,
                                 const QString &farbe,
                                 const QString &bezeichnung,
                                 int verbindungId,
                                 int kabellinieGrafikElementId)
{
    QSqlQuery q;
    q.prepare("SELECT id FROM kabel_ader WHERE kabel_id=:kid AND ader_nr=:nr");
    q.bindValue(":kid", kabelId);
    q.bindValue(":nr",  aderNr);
    if (!q.exec()) {
        qWarning() << "kabelAderZuordnen SELECT:" << q.lastError().text();
        return false;
    }
    if (q.next()) {
        int existingId = q.value(0).toInt();
        QSqlQuery upd;
        upd.prepare(R"(
            UPDATE kabel_ader SET farbe=:f, bezeichnung=:b, verbindung_id=:vid,
                                  kabellinie_grafik_element_id=:lgeid
            WHERE id=:id
        )");
        upd.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        upd.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        upd.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":id",    existingId);
        if (!upd.exec()) {
            qWarning() << "kabelAderZuordnen UPDATE:" << upd.lastError().text();
            return false;
        }
    } else {
        QSqlQuery ins;
        ins.prepare(R"(
            INSERT INTO kabel_ader (kabel_id, ader_nr, farbe, bezeichnung,
                                   verbindung_id, kabellinie_grafik_element_id)
            VALUES (:kid, :nr, :f, :b, :vid, :lgeid)
        )");
        ins.bindValue(":kid",   kabelId);
        ins.bindValue(":nr",    aderNr);
        ins.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        ins.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        ins.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        ins.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        if (!ins.exec()) {
            qWarning() << "kabelAderZuordnen INSERT:" << ins.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// kabelLinieDetails
// Lädt Kabelmetadaten + Adern für ein grafik_element.
// ============================================================
QVariantMap Database::kabelLinieDetails(int grafikElementId)
{
    QVariantMap result;
    if (grafikElementId <= 0) return result;

    // Kabel über den kabelId-Eintrag im extra_daten-JSON des Grafikelements suchen.
    // Funktioniert auch für nicht-primäre Linien eines Kabels (M9).
    QSqlQuery q;
    q.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.grafik_element_id, k.bauteil_kabel_id, k.von_ort, k.nach_ort
        FROM kabel k
        WHERE k.id = (
            SELECT CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER)
            FROM grafik_element ge WHERE ge.id = :geid
        )
        LIMIT 1
    )");
    q.bindValue(":geid", grafikElementId);
    if (!q.exec() || !q.next())
        return result;

    int kabelId = q.value(0).toInt();
    result[QStringLiteral("id")]              = kabelId;
    result[QStringLiteral("bezeichnung")]     = q.value(1).toString();
    result[QStringLiteral("kabeltyp")]        = q.value(2).toString();
    result[QStringLiteral("aderzahl")]        = q.value(3).toInt();
    result[QStringLiteral("querschnittMm2")]  = q.value(4).toDouble();
    result[QStringLiteral("grafikElementId")] = q.value(5).toInt();
    result[QStringLiteral("bauteilKabelId")]  = q.value(6).toInt();
    result[QStringLiteral("vonOrt")]          = q.value(7).toString();
    result[QStringLiteral("nachOrt")]         = q.value(8).toString();

    QSqlQuery qa;
    qa.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id, kabellinie_grafik_element_id
        FROM kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
    )");
    qa.bindValue(":kid", kabelId);
    QVariantList adern;
    if (qa.exec()) {
        while (qa.next()) {
            QVariantMap ader;
            ader[QStringLiteral("aderNr")]                      = qa.value(0).toInt();
            ader[QStringLiteral("farbe")]                       = qa.value(1).toString();
            ader[QStringLiteral("bezeichnung")]                 = qa.value(2).toString();
            ader[QStringLiteral("verbindungId")]                = qa.value(3).toInt();
            ader[QStringLiteral("kabellinieGrafikElementId")]   = qa.value(4).toInt();
            adern.append(ader);
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelListe
// Alle Kabel eines Projekts – für den Kabel-Editor / Kabelliste.
// ============================================================
QVariantList Database::kabelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, bezeichnung, kabeltyp, aderzahl, querschnitt_mm2,
               laenge_m, von_ort, nach_ort, grafik_element_id
        FROM kabel WHERE projekt_id = :pid ORDER BY bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "kabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q.value(7).toString();
        k[QStringLiteral("grafikElementId")]= q.value(8).toInt();
        result.append(k);
    }
    return result;
}

// ============================================================
// kabelListeAufgeschluesselt
// Alle Kabel eines Projekts mit ihren Ader-Unterzeilen.
// Zwei Queries: (1) Kabel + Linienanzahl, (2) alle Adern mit Seite + Netz.
// ============================================================
QVariantList Database::kabelListeAufgeschluesselt(int projektId)
{
    // ─── Pass 1: Kabel laden ────────────────────────────────
    QVariantList kabel;
    QHash<int, int> kabelIdx;  // kabelId → Index in kabel

    QSqlQuery q1;
    q1.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.laenge_m, k.von_ort, k.nach_ort,
               COUNT(DISTINCT ka.kabellinie_grafik_element_id) AS linien_anzahl
        FROM kabel k
        LEFT JOIN kabel_ader ka ON ka.kabel_id = k.id
                                AND ka.kabellinie_grafik_element_id IS NOT NULL
        WHERE k.projekt_id = :pid
        GROUP BY k.id
        ORDER BY k.bezeichnung
    )");
    q1.bindValue(":pid", projektId);
    if (!q1.exec()) {
        qWarning() << "kabelListeAufgeschluesselt (kabel):" << q1.lastError().text();
        return kabel;
    }
    while (q1.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q1.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q1.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q1.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q1.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q1.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q1.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q1.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q1.value(7).toString();
        k[QStringLiteral("linienAnzahl")]   = q1.value(8).toInt();
        k[QStringLiteral("adern")]          = QVariantList();
        kabelIdx[q1.value(0).toInt()]       = kabel.size();
        kabel.append(k);
    }

    // ─── Pass 2: Adern laden (alle Kabel des Projekts, ein Query) ──
    QSqlQuery q2;
    q2.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, COALESCE(ka.farbe, ''), COALESCE(ka.bezeichnung, ''),
               COALESCE(s.blattnummer, ''), COALESCE(s.bezeichnung, ''),
               COALESCE(v.bezeichnung, ''),
               COALESCE(ka.von_gerat_pin, ''), COALESCE(ka.nach_gerat_pin, '')
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        LEFT JOIN grafik_element ge ON ge.id = ka.kabellinie_grafik_element_id
        LEFT JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN verbindung v ON v.id = ka.verbindung_id
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q2.bindValue(":pid", projektId);
    if (!q2.exec()) {
        qWarning() << "kabelListeAufgeschluesselt (adern):" << q2.lastError().text();
        return kabel;
    }
    while (q2.next()) {
        int kId = q2.value(0).toInt();
        if (!kabelIdx.contains(kId)) continue;
        QVariantMap a;
        a[QStringLiteral("nr")]               = q2.value(1).toInt();
        a[QStringLiteral("farbe")]            = q2.value(2).toString();
        a[QStringLiteral("bezeichnung")]      = q2.value(3).toString();
        a[QStringLiteral("blattnummer")]      = q2.value(4).toString();
        a[QStringLiteral("seitenBez")]        = q2.value(5).toString();
        a[QStringLiteral("netz")]             = q2.value(6).toString();
        a[QStringLiteral("vonGeratPin")]      = q2.value(7).toString();
        a[QStringLiteral("nachGeratPin")]     = q2.value(8).toString();
        int idx = kabelIdx[kId];
        QVariantMap kMap = kabel[idx].toMap();
        QVariantList adern = kMap[QStringLiteral("adern")].toList();
        adern.append(a);
        kMap[QStringLiteral("adern")] = adern;
        kabel[idx] = kMap;
    }
    return kabel;
}

// ============================================================
// kabelMetaAktualisieren
// Aktualisiert Bezeichnung, Typ, Aderzahl, Querschnitt eines
// bestehenden Kabel-Datensatzes (z. B. nach EigenschaftenPanel-Änderung).
// ============================================================
bool Database::kabelMetaAktualisieren(int kabelId, const QString &bezeichnung,
                                       const QString &kabeltyp, int aderzahl,
                                       double querschnittMm2,
                                       const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q;
    q.prepare(R"(
        UPDATE kabel SET bezeichnung=:bez, kabeltyp=:typ, aderzahl=:anz,
                         querschnitt_mm2=:qs, von_ort=:von, nach_ort=:nach
        WHERE id = :id
    )");
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qWarning() << "kabelMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// kabelAderListeMitVerbindung
// Gibt alle kabel_adern eines Projekts mit ihrer verbindung_id zurück –
// benötigt für den Verdrahtungsweg-Algorithmus (M11) in QML.
// ============================================================
QVariantList Database::kabelAderListeMitVerbindung(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, ka.verbindung_id,
               COALESCE(ka.kabellinie_grafik_element_id, 0)
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        WHERE ka.verbindung_id IS NOT NULL AND ka.verbindung_id > 0
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "kabelAderListeMitVerbindung:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap a;
        a[QStringLiteral("kabelId")]                   = q.value(0).toInt();
        a[QStringLiteral("aderNr")]                    = q.value(1).toInt();
        a[QStringLiteral("verbindungId")]              = q.value(2).toInt();
        a[QStringLiteral("kabellinieGrafikElementId")] = q.value(3).toInt();
        result.append(a);
    }
    return result;
}

// ============================================================
// kabelAderEndpunkteBulkSetzen
// Speichert Von/Nach-Gerät:Pin für eine Liste von kabel_adern.
// adern: [{kabelId, aderNr, von, nach}]
// ============================================================
bool Database::kabelAderEndpunkteBulkSetzen(int projektId, const QVariantList &adern)
{
    if (adern.isEmpty()) return true;
    if (!m_db.transaction()) {
        qWarning() << "kabelAderEndpunkteBulkSetzen: Transaktion:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q;
    q.prepare(R"(
        UPDATE kabel_ader SET von_gerat_pin = :von, nach_gerat_pin = :nach
        WHERE kabel_id = :kid AND ader_nr = :nr
          AND EXISTS (SELECT 1 FROM kabel WHERE id = :kid2 AND projekt_id = :pid)
    )");
    for (const QVariant &av : adern) {
        const QVariantMap a = av.toMap();
        const QString von  = a.value(QStringLiteral("von")).toString();
        const QString nach = a.value(QStringLiteral("nach")).toString();
        q.bindValue(":von",  von.isEmpty()  ? QVariant(QMetaType::fromType<QString>()) : von);
        q.bindValue(":nach", nach.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : nach);
        q.bindValue(":kid",  a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":kid2", a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":nr",   a.value(QStringLiteral("aderNr")).toInt());
        q.bindValue(":pid",  projektId);
        if (!q.exec()) {
            qWarning() << "kabelAderEndpunkteBulkSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    if (!m_db.commit()) {
        qWarning() << "kabelAderEndpunkteBulkSetzen commit:" << m_db.lastError().text();
        m_db.rollback();
        return false;
    }
    return true;
}

// ============================================================
// kabelLoeschen
// Löscht Kabel + Adern. Das grafik_element selbst wird von QML
// gelöscht (grafikSpeichern); ON DELETE SET NULL sorgt dafür,
// dass kabel.grafik_element_id auf NULL gesetzt wird falls das
// Element zuerst gelöscht wird.
// ============================================================
bool Database::kabelLoeschen(int kabelId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM kabel WHERE id = :id");
    q.bindValue(":id", kabelId);
    if (!q.exec()) {
        qWarning() << "kabelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// bauteilKabelListe
// Alle Kabel-Bibliothekseinträge für den Picker-Dialog.
// Gibt [{id, bauteilId, bezeichnung, kabeltyp, aderzahl,
//        querschnittMm2, adern:[{farbe,querschnittMm2}]}] zurück.
// ============================================================
QVariantList Database::bauteilKabelListe()
{
    QVariantList result;
    {
        QSqlQuery cnt;
        cnt.exec("SELECT COUNT(*) FROM bauteil_kabel");
        if (cnt.next())
            qDebug() << "bauteilKabelListe: bauteil_kabel Zeilen=" << cnt.value(0).toInt();
        else
            qWarning() << "bauteilKabelListe: COUNT Fehler:" << cnt.lastError().text();
    }
    QSqlQuery q;
    if (!q.exec(R"(
        SELECT bk.id, bk.bauteil_id, b.bezeichnung, bk.kabeltyp,
               COUNT(ba.id) AS aderzahl,
               MAX(ba.querschnitt_mm2) AS quer
        FROM bauteil_kabel bk
        JOIN bauteil b ON b.id = bk.bauteil_id
        LEFT JOIN bauteil_kabel_ader ba ON ba.kabel_id = bk.id
        GROUP BY bk.id
        ORDER BY b.bezeichnung, bk.kabeltyp
    )")) {
        qWarning() << "bauteilKabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        int bkId = q.value(0).toInt();
        k[QStringLiteral("id")]             = bkId;
        k[QStringLiteral("bauteilId")]      = q.value(1).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(3).toString();
        k[QStringLiteral("aderzahl")]       = q.value(4).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(5).toDouble();
        // Aderfarben für Farbvorschau laden
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT farbe, querschnitt_mm2 FROM bauteil_kabel_ader
            WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bkId);
        QVariantList adern;
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("farbe")]          = qa.value(0).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(1).toDouble();
                adern.append(a);
            }
        }
        k[QStringLiteral("adern")] = adern;
        result.append(k);
    }
    qDebug() << "bauteilKabelListe: Einträge=" << result.size();
    return result;
}

// ============================================================
// kabelBauteilKabelSetzen
// Weist einer Kabellinie ein Bauteil-Kabel zu (bauteilKabelId > 0)
// oder hebt die Zuweisung auf (bauteilKabelId <= 0).
// Bei Zuweisung werden kabeltyp/aderzahl/querschnitt_mm2 aus dem
// Bauteil-Kabel übernommen (können manuell überschrieben werden).
// Gibt die aktualisierten Metadaten zurück.
// ============================================================
QVariantMap Database::kabelBauteilKabelSetzen(int kabelId, int bauteilKabelId)
{
    QVariantMap result;
    QString neuerTyp;
    int     neueAderzahl = 0;
    double  neuerQuer    = 0.0;

    if (bauteilKabelId > 0) {
        QSqlQuery qbk;
        qbk.prepare(R"(
            SELECT bk.kabeltyp, COUNT(ba.id), MAX(ba.querschnitt_mm2)
            FROM bauteil_kabel bk
            LEFT JOIN bauteil_kabel_ader ba ON ba.kabel_id = bk.id
            WHERE bk.id = :id GROUP BY bk.id
        )");
        qbk.bindValue(":id", bauteilKabelId);
        if (qbk.exec() && qbk.next()) {
            neuerTyp     = qbk.value(0).toString();
            neueAderzahl = qbk.value(1).toInt();
            neuerQuer    = qbk.value(2).toDouble();
        }
    }

    QSqlQuery q;
    q.prepare(R"(
        UPDATE kabel SET bauteil_kabel_id=:bkid, kabeltyp=:typ,
               aderzahl=:anz, querschnitt_mm2=:qs
        WHERE id = :id
    )");
    q.bindValue(":bkid", bauteilKabelId > 0 ? QVariant(bauteilKabelId) : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":typ",  neuerTyp.isEmpty()  ? QVariant(QMetaType(QMetaType::QString)) : neuerTyp);
    q.bindValue(":anz",  neueAderzahl > 0    ? neueAderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   neuerQuer > 0       ? neuerQuer    : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qWarning() << "kabelBauteilKabelSetzen:" << q.lastError().text();
        return result;
    }
    result[QStringLiteral("kabeltyp")]       = neuerTyp;
    result[QStringLiteral("aderzahl")]       = neueAderzahl;
    result[QStringLiteral("querschnittMm2")] = neuerQuer;
    result[QStringLiteral("bauteilKabelId")] = bauteilKabelId > 0 ? bauteilKabelId : 0;

    // Aderliste für Canvas-Schnittpunkt-Beschriftung
    QVariantList adern;
    if (bauteilKabelId > 0) {
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT ader_nr, farbe, bezeichnung, querschnitt_mm2
            FROM bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bauteilKabelId);
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("aderNr")]         = qa.value(0).toInt();
                a[QStringLiteral("farbe")]          = qa.value(1).toString();
                a[QStringLiteral("bezeichnung")]    = qa.value(2).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(3).toDouble();
                adern.append(a);
            }
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelAlleLinienLaden
// Alle Kabellinie-Grafikelemente eines Kabels (alle Seiten).
// ============================================================
QVariantList Database::kabelAlleLinienLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.id, ge.seite_id, s.bezeichnung,
               COUNT(ka.id) AS ader_anzahl
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN kabel_ader ka ON ka.kabellinie_grafik_element_id = ge.id
        WHERE ge.typ = 'kabellinie'
          AND CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER) = :kid
        GROUP BY ge.id
        ORDER BY ge.seite_id, ge.sortierung
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qWarning() << "kabelAlleLinienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("grafikElementId")]   = q.value(0).toInt();
        m[QStringLiteral("seiteId")]           = q.value(1).toInt();
        m[QStringLiteral("seiteBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("aderAnzahl")]        = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabelFreieAderLaden
// Adern eines Kabels die keiner Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelFreieAderLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabel_id = :kid AND kabellinie_grafik_element_id IS NULL
        ORDER BY ader_nr
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qWarning() << "kabelFreieAderLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(2).toString();
        ader[QStringLiteral("verbindungId")]= q.value(3).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// kabelAderFuerLinieLaden
// Adern die einer bestimmten Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelAderFuerLinieLaden(int kabellinieGrafikElementId)
{
    QVariantList result;
    if (kabellinieGrafikElementId <= 0) return result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabellinie_grafik_element_id = :geid
        ORDER BY ader_nr
    )");
    q.bindValue(":geid", kabellinieGrafikElementId);
    if (!q.exec()) {
        qWarning() << "kabelAderFuerLinieLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(2).toString();
        ader[QStringLiteral("verbindungId")]= q.value(3).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// makroSpeichern
// Sammelt alle grafik_element innerhalb des Makrokastens
// (Mittelpunkt-Einschlussregel) und schreibt makro + makro_element.
// Gibt makro.id zurück (>0) oder -1 bei Fehler.
// ============================================================
int Database::makroSpeichern(int grafikElementId, int seiteId)
{
    // Makrokasten-Geometrie laden
    QSqlQuery qk;
    qk.prepare("SELECT x1, y1, x2, y2, extra_daten FROM grafik_element WHERE id = :id");
    qk.bindValue(":id", grafikElementId);
    if (!qk.exec() || !qk.next()) {
        qWarning() << "makroSpeichern: Kasten nicht gefunden" << grafikElementId;
        return -1;
    }
    const double kx1 = qk.value(0).toDouble();
    const double ky1 = qk.value(1).toDouble();
    const double kx2 = qk.value(2).toDouble();
    const double ky2 = qk.value(3).toDouble();
    const QString edJson = qk.value(4).toString();

    QJsonDocument edDoc  = QJsonDocument::fromJson(edJson.toUtf8());
    QJsonObject   ed     = edDoc.object();
    const QString name   = ed.value("name").toString("Makro");
    const QString beschr = ed.value("beschreibung").toString();
    const QString kat    = ed.value("kategorie").toString();
    const int existId    = ed.value("makroId").toInt(0);

    const double minX = std::min(kx1, kx2);
    const double minY = std::min(ky1, ky2);
    const double maxX = std::max(kx1, kx2);
    const double maxY = std::max(ky1, ky2);

    QSqlDatabase dbConn = QSqlDatabase::database();
    if (!dbConn.transaction()) {
        qWarning() << "makroSpeichern: transaction fehlgeschlagen";
        return -1;
    }

    int makroId = existId;
    QSqlQuery qm;

    if (makroId > 0) {
        qm.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k, "
                   "kasten_breite=:w, kasten_hoehe=:h WHERE id=:id");
        qm.bindValue(":n",  name);
        qm.bindValue(":b",  beschr);
        qm.bindValue(":k",  kat);
        qm.bindValue(":w",  maxX - minX);
        qm.bindValue(":h",  maxY - minY);
        qm.bindValue(":id", makroId);
        if (!qm.exec()) {
            qWarning() << "makroSpeichern UPDATE makro:" << qm.lastError().text();
            dbConn.rollback(); return -1;
        }
        QSqlQuery qdel;
        qdel.prepare("DELETE FROM makro_element WHERE makro_id = :id");
        qdel.bindValue(":id", makroId);
        if (!qdel.exec()) {
            qWarning() << "makroSpeichern DELETE makro_element:" << qdel.lastError().text();
            dbConn.rollback(); return -1;
        }
    } else {
        qm.prepare("INSERT INTO makro (name, beschreibung, kategorie, kasten_breite, kasten_hoehe) "
                   "VALUES (:n, :b, :k, :w, :h)");
        qm.bindValue(":n",  name);
        qm.bindValue(":b",  beschr);
        qm.bindValue(":k",  kat);
        qm.bindValue(":w",  maxX - minX);
        qm.bindValue(":h",  maxY - minY);
        if (!qm.exec()) {
            qWarning() << "makroSpeichern INSERT makro:" << qm.lastError().text();
            dbConn.rollback(); return -1;
        }
        makroId = qm.lastInsertId().toInt();
    }

    QSqlQuery qe;
    qe.prepare(R"(
        SELECT typ, x1, y1, x2, y2, extra_daten, symbol_id, sortierung
        FROM grafik_element
        WHERE seite_id = :sid
          AND id != :kid
          AND typ != 'makrokasten'
          AND (x1+x2)/2.0 BETWEEN :minx AND :maxx
          AND (y1+y2)/2.0 BETWEEN :miny AND :maxy
        ORDER BY sortierung
    )");
    qe.bindValue(":sid",  seiteId);
    qe.bindValue(":kid",  grafikElementId);
    qe.bindValue(":minx", minX);
    qe.bindValue(":maxx", maxX);
    qe.bindValue(":miny", minY);
    qe.bindValue(":maxy", maxY);
    if (!qe.exec()) {
        qWarning() << "makroSpeichern SELECT elemente:" << qe.lastError().text();
        dbConn.rollback(); return -1;
    }

    QSqlQuery qi;
    qi.prepare(R"(
        INSERT INTO makro_element (makro_id, typ, rel_x1, rel_y1, rel_x2, rel_y2,
                                   extra_daten, symbol_key, sortierung)
        VALUES (:mid, :typ, :rx1, :ry1, :rx2, :ry2, :ed, :sk, :sort)
    )");

    while (qe.next()) {
        qi.bindValue(":mid",  makroId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":rx1",  qe.value(1).toDouble() - minX);
        qi.bindValue(":ry1",  qe.value(2).toDouble() - minY);
        qi.bindValue(":rx2",  qe.value(3).toDouble() - minX);
        qi.bindValue(":ry2",  qe.value(4).toDouble() - minY);
        qi.bindValue(":ed",   qe.value(5));
        qi.bindValue(":sk",   qe.value(6));
        qi.bindValue(":sort", qe.value(7));
        if (!qi.exec()) {
            qWarning() << "makroSpeichern INSERT makro_element:" << qi.lastError().text();
            dbConn.rollback(); return -1;
        }
    }

    // makroId in extra_daten des Kastens zurückschreiben
    ed["makroId"] = makroId;
    QSqlQuery qu;
    qu.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    qu.bindValue(":ed", QString::fromUtf8(QJsonDocument(ed).toJson(QJsonDocument::Compact)));
    qu.bindValue(":id", grafikElementId);
    if (!qu.exec()) {
        qWarning() << "makroSpeichern UPDATE extra_daten:" << qu.lastError().text();
        dbConn.rollback(); return -1;
    }

    if (!dbConn.commit()) {
        qWarning() << "makroSpeichern: commit fehlgeschlagen";
        return -1;
    }
    return makroId;
}

// ============================================================
// makroListe
// ============================================================
QVariantList Database::makroListe()
{
    QVariantList result;
    QSqlQuery q(R"(
        SELECT m.id, m.name, m.beschreibung, m.kategorie,
               COUNT(me.id) AS element_anzahl
        FROM makro m
        LEFT JOIN makro_element me ON me.makro_id = m.id
        GROUP BY m.id
        ORDER BY m.kategorie, m.name
    )");
    while (q.next()) {
        QVariantMap row;
        row["id"]            = q.value(0).toInt();
        row["name"]          = q.value(1).toString();
        row["beschreibung"]  = q.value(2).toString();
        row["kategorie"]     = q.value(3).toString();
        row["elementAnzahl"] = q.value(4).toInt();
        result.append(row);
    }
    return result;
}

// ============================================================
// makroElementeEinfuegen
// ============================================================
QVariantList Database::makroElementeEinfuegen(int makroId, int seiteId,
                                               double offsetX, double offsetY)
{
    QVariantList newIds;
    QSqlQuery qe;
    qe.prepare(R"(
        SELECT typ, rel_x1, rel_y1, rel_x2, rel_y2, extra_daten, symbol_key, sortierung
        FROM makro_element WHERE makro_id = :mid ORDER BY sortierung
    )");
    qe.bindValue(":mid", makroId);
    if (!qe.exec()) {
        qWarning() << "makroElementeEinfuegen SELECT:" << qe.lastError().text();
        return newIds;
    }

    // Stich- und Füllwerte aus erstem Element ableiten wäre ideal, aber grafik_element
    // speichert diese im extra_daten nicht zuverlässig. Wir lesen sie aus dem Original.
    // Für eine saubere Implementierung: in makro_element auch strich_farbe etc. speichern.
    // Aktuell: Standard-Werte, werden nach Speichern vom grafikSpeichern-Roundtrip überschrieben.
    QSqlDatabase dbConn = QSqlDatabase::database();
    if (!dbConn.transaction()) { qWarning() << "makroElementeEinfuegen: transaction"; return newIds; }

    QSqlQuery qi;
    qi.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
             sortierung, symbol_id, rotation, spiegel_x, spiegel_y, extra_daten)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             '#4a9eff', 1.5, 'solid',
             0, '#000000', 0.0, 1.0, 0,
             :sort, :sk, 0, 0, 0, :ed)
    )");

    while (qe.next()) {
        qi.bindValue(":sid",  seiteId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":x1",   qe.value(1).toDouble() + offsetX);
        qi.bindValue(":y1",   qe.value(2).toDouble() + offsetY);
        qi.bindValue(":x2",   qe.value(3).toDouble() + offsetX);
        qi.bindValue(":y2",   qe.value(4).toDouble() + offsetY);
        qi.bindValue(":ed",   qe.value(5));
        qi.bindValue(":sk",   qe.value(6));
        qi.bindValue(":sort", qe.value(7));
        if (!qi.exec()) {
            qWarning() << "makroElementeEinfuegen INSERT:" << qi.lastError().text();
            dbConn.rollback(); return QVariantList();
        }
        newIds.append(qi.lastInsertId().toInt());
    }

    if (!dbConn.commit()) { qWarning() << "makroElementeEinfuegen: commit"; return QVariantList(); }
    return newIds;
}

// ============================================================
// makroLoeschen
// ============================================================
bool Database::makroLoeschen(int makroId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM makro WHERE id = :id");
    q.bindValue(":id", makroId);
    if (!q.exec()) {
        qWarning() << "makroLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// makroMetaAktualisieren
// ============================================================
bool Database::makroMetaAktualisieren(int makroId, const QString &name,
                                       const QString &beschreibung,
                                       const QString &kategorie)
{
    QSqlQuery q;
    q.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k WHERE id=:id");
    q.bindValue(":n",  name);
    q.bindValue(":b",  beschreibung);
    q.bindValue(":k",  kategorie);
    q.bindValue(":id", makroId);
    if (!q.exec()) {
        qWarning() << "makroMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Inbetriebnahme-Modus
// ============================================================
QVariantList Database::ibnListeLaden(int projektId, int seiteId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT
            MIN(ge.id)                                       AS element_id,
            ge.seite_id,
            s.blattnummer,
            COALESCE(s.bezeichnung, '')                      AS seitenbezeichnung,
            json_extract(ge.extra_daten, '$.bmk')            AS bmk,
            COALESCE(ibn.status, 'offen')                    AS status,
            COALESCE(ibn.id, 0)                              AS ibn_id,
            COALESCE(ibn.notiz, '')                          AS notiz,
            COALESCE(ibn.bauteil_id, '')                     AS bauteil_id,
            COALESCE(ibn.geprueft_von, '')                   AS geprueft_von,
            COALESCE(ibn.geprueft_am, '')                    AS geprueft_am,
            MIN(ge.x1)                                       AS x1,
            MIN(ge.y1)                                       AS y1,
            COALESCE(MAX(sd.ibn_kategorie), '')              AS symbol_kategorie
        FROM grafik_element ge
        JOIN seite   s ON ge.seite_id   = s.id
        JOIN ort     o ON s.ort_id      = o.id
        JOIN anlage  a ON o.anlage_id   = a.id
        LEFT JOIN symbol_definition sd ON ge.symbol_id = sd.id
        LEFT JOIN inbetriebnahme ibn
               ON ibn.seite_id = ge.seite_id
              AND ibn.bmk      = json_extract(ge.extra_daten, '$.bmk')
        WHERE a.projekt_id  = :pid
          AND (:sid = -1 OR ge.seite_id = :sid)
          AND ge.typ        = 'symbol'
          AND json_extract(ge.extra_daten, '$.bmk') IS NOT NULL
          AND json_extract(ge.extra_daten, '$.bmk') != ''
        GROUP BY ge.seite_id, json_extract(ge.extra_daten, '$.bmk')
        ORDER BY s.blattnummer, bmk
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":sid", seiteId);

    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnListeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "elementId",        q.value("element_id")      },
            { "seiteId",          q.value("seite_id")        },
            { "blattnummer",      q.value("blattnummer")     },
            { "seitenbezeichnung",q.value("seitenbezeichnung")},
            { "bmk",              q.value("bmk")             },
            { "status",           q.value("status")          },
            { "ibnId",            q.value("ibn_id")          },
            { "notiz",            q.value("notiz")           },
            { "bauteilId",        q.value("bauteil_id")      },
            { "geprueftVon",      q.value("geprueft_von")    },
            { "geprueftAm",       q.value("geprueft_am")     },
            { "x1",               q.value("x1")              },
            { "y1",               q.value("y1")              },
            { "symbolKategorie",  q.value("symbol_kategorie") },
        });
    }
    return result;
}

bool Database::ibnEintragSpeichern(int projektId, int seiteId,
                                    const QString &bmk,
                                    const QString &status,
                                    const QString &notiz,
                                    const QString &bauteilId,
                                    const QString &geprueftVon,
                                    const QString &geprueftAm)
{
    QSqlQuery q;
    // Sicherstellen dass ein Datensatz existiert
    q.prepare(R"(
        INSERT INTO inbetriebnahme (projekt_id, seite_id, bmk, erstellt_am)
        VALUES (:pid, :sid, :bmk, datetime('now'))
        ON CONFLICT(seite_id, bmk) DO NOTHING
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qWarning() << "ibnEintragSpeichern INSERT:" << q.lastError().text();
        return false;
    }

    q.prepare(R"(
        UPDATE inbetriebnahme
        SET status       = :st,
            notiz        = :no,
            bauteil_id   = :bid,
            geprueft_von = :gv,
            geprueft_am  = :ga
        WHERE seite_id = :sid AND bmk = :bmk
    )");
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":bid", bauteilId);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qWarning() << "ibnEintragSpeichern UPDATE:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnStatusSetzen(int seiteId, const QString &bmk, const QString &status)
{
    QSqlQuery q;
    // Eintrag anlegen falls noch nicht vorhanden (projekt_id wird aus seite abgeleitet)
    q.prepare(R"(
        INSERT INTO inbetriebnahme (projekt_id, seite_id, bmk, status, erstellt_am)
        SELECT a.projekt_id, :sid, :bmk, :st, datetime('now')
        FROM seite s JOIN ort o ON s.ort_id=o.id JOIN anlage a ON o.anlage_id=a.id
        WHERE s.id = :sid
        ON CONFLICT(seite_id, bmk) DO UPDATE SET status = :st
    )");
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    q.bindValue(":st",  status);
    if (!q.exec()) {
        qWarning() << "ibnStatusSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── IBN Kabel ────────────────────────────────────────────────────────────

QVariantList Database::ibnKabelListeLaden(int projektId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT k.id              AS kabel_id,
               k.bezeichnung,
               k.kabeltyp,
               k.aderzahl,
               k.querschnitt_mm2,
               k.laenge_m,
               COALESCE(k.von_ort, '')          AS von_ort,
               COALESCE(k.nach_ort, '')         AS nach_ort,
               COALESCE(k.grafik_element_id, 0) AS grafik_element_id,
               COALESCE(ib.status, 'offen')     AS status,
               COALESCE(ib.notiz, '')           AS notiz,
               COALESCE(ib.geprueft_von, '')    AS geprueft_von,
               COALESCE(ib.geprueft_am, '')     AS geprueft_am
        FROM kabel k
        LEFT JOIN ibn_kabel ib ON ib.kabel_id = k.id
        WHERE k.projekt_id = :pid
        ORDER BY k.bezeichnung
    )");
    q.bindValue(":pid", projektId);

    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnKabelListeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "kabelId",        q.value("kabel_id")        },
            { "bezeichnung",    q.value("bezeichnung")     },
            { "kabeltyp",       q.value("kabeltyp")        },
            { "aderzahl",       q.value("aderzahl")        },
            { "querschnittMm2", q.value("querschnitt_mm2") },
            { "laengeM",        q.value("laenge_m")        },
            { "vonOrt",         q.value("von_ort")         },
            { "nachOrt",        q.value("nach_ort")        },
            { "grafikElementId",q.value("grafik_element_id")},
            { "status",         q.value("status")          },
            { "notiz",          q.value("notiz")           },
            { "geprueftVon",    q.value("geprueft_von")    },
            { "geprueftAm",     q.value("geprueft_am")     },
        });
    }
    return result;
}

bool Database::ibnKabelSpeichern(int projektId, int kabelId,
                                  const QString &status,
                                  const QString &notiz,
                                  const QString &geprueftVon,
                                  const QString &geprueftAm)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_kabel (projekt_id, kabel_id, status, notiz, geprueft_von, geprueft_am)
        VALUES (:pid, :kid, :st, :no, :gv, :ga)
        ON CONFLICT(kabel_id) DO NOTHING
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":kid", kabelId);
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    if (!q.exec()) {
        qWarning() << "ibnKabelSpeichern INSERT:" << q.lastError().text();
        return false;
    }
    q.prepare(R"(
        UPDATE ibn_kabel
        SET status       = :st,
            notiz        = :no,
            geprueft_von = :gv,
            geprueft_am  = :ga
        WHERE kabel_id = :kid
    )");
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qWarning() << "ibnKabelSpeichern UPDATE:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnKabelStatusSetzen(int kabelId, const QString &status)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_kabel (projekt_id, kabel_id, status)
        VALUES ((SELECT projekt_id FROM kabel WHERE id = :kid), :kid, :st)
        ON CONFLICT(kabel_id) DO UPDATE SET status = :st
    )");
    q.bindValue(":kid", kabelId);
    q.bindValue(":st",  status);
    if (!q.exec()) {
        qWarning() << "ibnKabelStatusSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── IBN Feldvorlagen / Feldwerte ─────────────────────────────────────────────

bool Database::seedIbnFeldvorlagen()
{
    struct Feld {
        QString kategorie, feldname, label, feldtyp, optionen, einheit;
        int pflicht, reihenfolge;
    };
    static const QList<Feld> felder = {
        // Leitungsschutzschalter
        { "leitungsschutzschalter", "nennstrom",       "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "leitungsschutzschalter", "ausloesekurve",    "Auslösekurve",          "auswahl",  "B,C,D", "", 1, 2 },
        { "leitungsschutzschalter", "pole",             "Polzahl",               "auswahl",  "1,2,3,4", "", 1, 3 },
        { "leitungsschutzschalter", "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  0, 4 },
        { "leitungsschutzschalter", "ausschaltvermoegen","Ausschaltvermögen (kA)","zahl",     "", "kA", 0, 5 },
        { "leitungsschutzschalter", "bemerkung",        "Bemerkung",             "text",     "", "",   0, 6 },
        // Sicherung
        { "sicherung",              "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "sicherung",              "sicherungstyp",    "Sicherungstyp",         "auswahl",  "gG,gL,aM,NH", "", 1, 2 },
        { "sicherung",              "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  0, 3 },
        { "sicherung",              "bemerkung",        "Bemerkung",             "text",     "", "",   0, 4 },
        // FI-Schutzschalter
        { "fi_schutzschalter",      "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "fi_schutzschalter",      "fehlerstrom",      "Fehlerstrom (mA)",       "auswahl",  "10,30,100,300", "", 1, 2 },
        { "fi_schutzschalter",      "typ",              "FI-Typ",                "auswahl",  "Typ A,Typ B,Typ F", "", 1, 3 },
        { "fi_schutzschalter",      "pole",             "Polzahl",               "auswahl",  "2,4", "",   1, 4 },
        { "fi_schutzschalter",      "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 5 },
        { "fi_schutzschalter",      "bemerkung",        "Bemerkung",             "text",     "", "",   0, 6 },
        // Motorschutzschalter
        { "motorschutzschalter",    "einstellstrom",    "Einstellstrom (A)",      "zahl",     "", "A",  1, 1 },
        { "motorschutzschalter",    "einstellbereich",  "Einstellbereich (A)",    "text",     "", "A",  0, 2 },
        { "motorschutzschalter",    "klasse",           "Auslöseklasse",         "auswahl",  "10,10A,20,30", "", 0, 3 },
        { "motorschutzschalter",    "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 4 },
        { "motorschutzschalter",    "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Schütz
        { "schuetz",                "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "schuetz",                "spulenspannung",   "Spulenspannung (V)",     "zahl",     "", "V",  1, 2 },
        { "schuetz",                "spulenfrequenz",   "Spulenfrequenz",        "auswahl",  "DC,50 Hz,60 Hz", "", 0, 3 },
        { "schuetz",                "einschaltdauer",   "Einschaltdauer (%ED)",   "zahl",     "", "%",  0, 4 },
        { "schuetz",                "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Motor
        { "motor",                  "nennleistung",     "Nennleistung (kW)",      "zahl",     "", "kW", 1, 1 },
        { "motor",                  "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 2 },
        { "motor",                  "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  1, 3 },
        { "motor",                  "drehzahl",         "Nenndrehzahl (U/min)",   "zahl",     "", "U/min", 0, 4 },
        { "motor",                  "cos_phi",          "cos φ",                 "zahl",     "", "",   0, 5 },
        { "motor",                  "drehrichtung",     "Drehrichtung geprüft",  "boolean",  "", "",   0, 6 },
        { "motor",                  "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 7 },
        { "motor",                  "bemerkung",        "Bemerkung",             "text",     "", "",   0, 8 },
        // Transformator
        { "transformator",          "primaerspannung",  "Primärspannung (V)",     "zahl",     "", "V",  1, 1 },
        { "transformator",          "sekundaerspannung","Sekundärspannung (V)",   "zahl",     "", "V",  1, 2 },
        { "transformator",          "nennleistung",     "Nennleistung (VA)",      "zahl",     "", "VA", 1, 3 },
        { "transformator",          "leerlaufspannung", "Leerlaufspannung (V)",   "zahl",     "", "V",  0, 4 },
        { "transformator",          "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
    };

    QSqlQuery q;
    q.prepare(R"(
        INSERT OR IGNORE INTO ibn_feldvorlage
            (symbol_kategorie, feldname, label, feldtyp, optionen, einheit, pflichtfeld, reihenfolge, erstellt_von)
        VALUES (:kat, :fn, :lbl, :typ, :opt, :ein, :pfl, :rei, 'system')
    )");
    for (const auto &f : felder) {
        q.bindValue(":kat", f.kategorie);
        q.bindValue(":fn",  f.feldname);
        q.bindValue(":lbl", f.label);
        q.bindValue(":typ", f.feldtyp);
        q.bindValue(":opt", f.optionen);
        q.bindValue(":ein", f.einheit);
        q.bindValue(":pfl", f.pflicht);
        q.bindValue(":rei", f.reihenfolge);
        if (!q.exec()) {
            qWarning() << "seedIbnFeldvorlagen:" << q.lastError().text();
            return false;
        }
    }

    // symbol_definition.ibn_kategorie für bekannte Symbole setzen
    struct KatMap { QString symbolId, kategorie; };
    static const QList<KatMap> katMap = {
        { "lss",          "leitungsschutzschalter" },
        { "sicherung",    "sicherung"              },
        { "fi",           "fi_schutzschalter"      },
        { "bimetall_nc",  "motorschutzschalter"    },
        { "spule",        "schuetz"                },
        { "spule_ansi",   "schuetz"                },
        { "motor",        "motor"                  },
        { "trafo",        "transformator"          },
    };
    QSqlQuery qu;
    qu.prepare("UPDATE symbol_definition SET ibn_kategorie = :kat WHERE id = :id");
    for (const auto &km : katMap) {
        qu.bindValue(":kat", km.kategorie);
        qu.bindValue(":id",  km.symbolId);
        if (!qu.exec())
            qWarning() << "seedIbnFeldvorlagen update" << km.symbolId << ":" << qu.lastError().text();
    }
    return true;
}

QVariantList Database::ibnFeldvorlagenLaden(const QString &symbolKategorie)
{
    if (symbolKategorie.isEmpty())
        return {};
    QSqlQuery q;
    q.prepare(R"(
        SELECT feldname, label, feldtyp, optionen, einheit, pflichtfeld
        FROM ibn_feldvorlage
        WHERE symbol_kategorie = :kat
        ORDER BY reihenfolge
    )");
    q.bindValue(":kat", symbolKategorie);
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnFeldvorlagenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "feldname",   q.value("feldname")   },
            { "label",      q.value("label")      },
            { "feldtyp",    q.value("feldtyp")    },
            { "optionen",   q.value("optionen")   },
            { "einheit",    q.value("einheit")    },
            { "pflichtfeld",q.value("pflichtfeld") },
        });
    }
    return result;
}

QVariantList Database::ibnAlleVorlagenLaden()
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, symbol_kategorie, feldname, label, feldtyp, optionen,
               einheit, pflichtfeld, reihenfolge, erstellt_von
        FROM ibn_feldvorlage
        ORDER BY symbol_kategorie, reihenfolge, id
    )");
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnAlleVorlagenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "id",              q.value("id")              },
            { "symbolKategorie", q.value("symbol_kategorie") },
            { "feldname",        q.value("feldname")        },
            { "label",           q.value("label")           },
            { "feldtyp",         q.value("feldtyp")         },
            { "optionen",        q.value("optionen")        },
            { "einheit",         q.value("einheit")         },
            { "pflichtfeld",     q.value("pflichtfeld")     },
            { "reihenfolge",     q.value("reihenfolge")     },
            { "erstelltVon",     q.value("erstellt_von")    },
        });
    }
    return result;
}

QVariantList Database::ibnAlleKategorienLaden()
{
    QSqlQuery q("SELECT DISTINCT symbol_kategorie FROM ibn_feldvorlage ORDER BY symbol_kategorie");
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnAlleKategorienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(q.value(0));
    return result;
}

bool Database::ibnFeldVorlageSpeichern(const QString &symbolKategorie,
                                        const QString &feldname,
                                        const QString &label,
                                        const QString &feldtyp,
                                        const QString &optionen,
                                        const QString &einheit,
                                        bool pflichtfeld)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_feldvorlage
            (symbol_kategorie, feldname, label, feldtyp, optionen, einheit,
             pflichtfeld, reihenfolge, erstellt_von)
        VALUES (:kat, :fn, :lbl, :typ, :opt, :ein, :pfl,
                (SELECT COALESCE(MAX(reihenfolge), 0) + 1
                 FROM ibn_feldvorlage WHERE symbol_kategorie = :kat2),
                'user')
    )");
    q.bindValue(":kat",  symbolKategorie);
    q.bindValue(":kat2", symbolKategorie);
    q.bindValue(":fn",   feldname);
    q.bindValue(":lbl",  label);
    q.bindValue(":typ",  feldtyp);
    q.bindValue(":opt",  optionen);
    q.bindValue(":ein",  einheit);
    q.bindValue(":pfl",  pflichtfeld ? 1 : 0);
    if (!q.exec()) {
        qWarning() << "ibnFeldVorlageSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnFeldVorlageLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM ibn_feldvorlage WHERE id = :id AND erstellt_von = 'user'");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "ibnFeldVorlageLoeschen:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVariantList Database::ibnFeldwerteLaden(int inbetriebnahmeId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT feldname, wert FROM ibn_feldwert
        WHERE inbetriebnahme_id = :id
    )");
    q.bindValue(":id", inbetriebnahmeId);
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnFeldwerteLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "feldname", q.value("feldname") },
            { "wert",     q.value("wert")     },
        });
    }
    return result;
}

bool Database::ibnFeldwerteAktualisieren(int inbetriebnahmeId, const QVariantList &felder)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_feldwert (inbetriebnahme_id, feldname, wert)
        VALUES (:id, :fn, :wert)
        ON CONFLICT(inbetriebnahme_id, feldname) DO UPDATE SET wert = :wert
    )");
    for (const auto &f : felder) {
        QVariantMap m = f.toMap();
        q.bindValue(":id",   inbetriebnahmeId);
        q.bindValue(":fn",   m.value("feldname").toString());
        q.bindValue(":wert", m.value("wert").toString());
        if (!q.exec()) {
            qWarning() << "ibnFeldwerteAktualisieren:" << q.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// ibnProtokollPdfSpeichern
// ============================================================
bool Database::ibnProtokollPdfSpeichern(int projektId, int seiteId,
                                         const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    // ── Projektmeta laden ─────────────────────────────────
    QString projektName, projektnummer, auftraggeber, auftragnehmer, bearbeiter;
    {
        QSqlQuery qp;
        qp.prepare("SELECT name, projektnummer, auftraggeber, auftragnehmer, bearbeiter "
                   "FROM projekt WHERE id = :id");
        qp.bindValue(":id", projektId);
        if (qp.exec() && qp.next()) {
            projektName   = qp.value("name").toString();
            projektnummer = qp.value("projektnummer").toString();
            auftraggeber  = qp.value("auftraggeber").toString();
            auftragnehmer = qp.value("auftragnehmer").toString();
            bearbeiter    = qp.value("bearbeiter").toString();
        }
    }

    // ── IBN-Liste laden ───────────────────────────────────
    const QVariantList liste = ibnListeLaden(projektId, seiteId);

    int anzGesamt      = liste.size();
    int anzAbgeschlossen = 0, anzInArbeit = 0, anzOffen = 0;
    for (const QVariant &v : liste) {
        const QString st = v.toMap().value("status").toString();
        if (st == QLatin1String("abgeschlossen")) ++anzAbgeschlossen;
        else if (st == QLatin1String("in_arbeit")) ++anzInArbeit;
        else ++anzOffen;
    }

    // ── HTML aufbauen ─────────────────────────────────────
    auto esc = [](const QString &s) -> QString {
        QString r = s;
        r.replace(u'&', QLatin1String("&amp;"));
        r.replace(u'<', QLatin1String("&lt;"));
        r.replace(u'>', QLatin1String("&gt;"));
        return r;
    };

    auto statusLabel = [](const QString &st) -> QString {
        if (st == QLatin1String("abgeschlossen")) return QStringLiteral("✓ Fertig");
        if (st == QLatin1String("in_arbeit"))     return QStringLiteral("In Arbeit");
        return QStringLiteral("Offen");
    };
    auto statusColor = [](const QString &st) -> QString {
        if (st == QLatin1String("abgeschlossen")) return QStringLiteral("#2a8a4a");
        if (st == QLatin1String("in_arbeit"))     return QStringLiteral("#b08000");
        return QStringLiteral("#666688");
    };

    QString html;
    html.reserve(64 * 1024);
    html += QStringLiteral(R"(<!DOCTYPE html><html><head><meta charset="utf-8">
<style>
  body   { font-family: Arial, Helvetica, sans-serif; font-size: 9pt; color: #222; margin: 0; }
  h1     { font-size: 13pt; color: #1a3560; margin: 0 0 6px 0; }
  .subtitle { font-size: 9pt; color: #555; margin-bottom: 10px; }
  table.meta { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
  table.meta td { padding: 2px 6px; font-size: 8.5pt; }
  table.meta td.lbl { color: #777; width: 130px; }
  .summary { background: #eef2f7; padding: 6px 10px; margin-bottom: 12px;
             font-size: 8.5pt; border-left: 3px solid #1a3560; }
  .bm { border: 1px solid #ccc; padding: 6px 8px; margin-bottom: 6px;
        page-break-inside: avoid; }
  .bm-head { font-size: 10pt; font-weight: bold; }
  .bm-sub  { font-size: 8pt; color: #666; margin: 1px 0 4px 0; }
  table.felder { width: 100%; border-collapse: collapse; margin-top: 3px; }
  table.felder td { padding: 2px 6px; font-size: 8.5pt; vertical-align: top; }
  table.felder td.lbl { color: #666; width: 42%; }
  table.felder tr:nth-child(even) { background: #f7f7f7; }
  .notiz { font-style: italic; color: #555; margin-top: 3px; font-size: 8.5pt; }
  hr  { border: none; border-top: 1px solid #bbb; margin: 14px 0; }
  .sig { margin-top: 30px; }
  .sig table { width: 100%; border-collapse: collapse; }
  .sig td { width: 33%; padding: 4px 8px; border-top: 1px solid #888;
             font-size: 8pt; color: #555; }
</style></head><body>)");

    // Kopfzeile
    html += QStringLiteral("<h1>Prüfprotokoll IBN</h1>");
    html += QStringLiteral("<div class='subtitle'>Erstellt: ")
          + esc(QDateTime::currentDateTime().toString(QStringLiteral("dd.MM.yyyy  hh:mm")))
          + QStringLiteral("</div>");

    // Projektmeta
    html += QStringLiteral("<table class='meta'>");
    auto metaRow = [&](const QString &lbl, const QString &val) {
        if (val.isEmpty()) return;
        html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
              + QStringLiteral("</td><td>") + esc(val) + QStringLiteral("</td></tr>");
    };
    metaRow(QStringLiteral("Projekt"),        projektName);
    metaRow(QStringLiteral("Projektnummer"),  projektnummer);
    metaRow(QStringLiteral("Auftraggeber"),   auftraggeber);
    metaRow(QStringLiteral("Auftragnehmer"),  auftragnehmer);
    metaRow(QStringLiteral("Bearbeiter"),     bearbeiter);
    html += QStringLiteral("</table>");

    // Zusammenfassung
    html += QStringLiteral("<div class='summary'>")
          + QString::number(anzGesamt) + QStringLiteral(" Betriebsmittel gesamt  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#2a8a4a'>") + QString::number(anzAbgeschlossen)
          + QStringLiteral(" Fertig</span>  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#b08000'>") + QString::number(anzInArbeit)
          + QStringLiteral(" In Arbeit</span>  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#666688'>") + QString::number(anzOffen)
          + QStringLiteral(" Offen</span>")
          + QStringLiteral("</div>");

    html += QStringLiteral("<hr>");

    // ── BM-Blöcke ─────────────────────────────────────────
    QString lastBlatt;
    for (const QVariant &v : liste) {
        const QVariantMap e   = v.toMap();
        const QString bmk     = e.value("bmk").toString();
        const QString blatt   = e.value("blattnummer").toString();
        const QString seitenBez = e.value("seitenbezeichnung").toString();
        const QString status  = e.value("status").toString();
        const QString notiz   = e.value("notiz").toString();
        const QString bauteilId = e.value("bauteilId").toString();
        const QString geprueftVon = e.value("geprueftVon").toString();
        const QString geprueftAm  = e.value("geprueftAm").toString();
        const QString kat     = e.value("symbolKategorie").toString();
        const int ibnId       = e.value("ibnId").toInt();

        // Seiten-Trennzeile
        if (blatt != lastBlatt) {
            if (!lastBlatt.isEmpty()) html += QStringLiteral("<br>");
            html += QStringLiteral("<div style='font-size:8pt;color:#999;margin-bottom:4px;'>")
                  + QStringLiteral("Blatt ") + esc(blatt);
            if (!seitenBez.isEmpty())
                html += QStringLiteral(" – ") + esc(seitenBez);
            html += QStringLiteral("</div>");
            lastBlatt = blatt;
        }

        html += QStringLiteral("<div class='bm'>");
        html += QStringLiteral("<div class='bm-head'><span style='color:#1a3560'>")
              + esc(bmk) + QStringLiteral("</span>")
              + QStringLiteral("  <span style='color:") + statusColor(status)
              + QStringLiteral(";font-size:9pt'>") + esc(statusLabel(status))
              + QStringLiteral("</span></div>");

        // Blattnummer + Kategorie als Sub-Info
        QString subInfo = QStringLiteral("Blatt ") + esc(blatt);
        if (!kat.isEmpty()) subInfo += QStringLiteral("  ·  ") + esc(kat);
        html += QStringLiteral("<div class='bm-sub'>") + subInfo + QStringLiteral("</div>");

        // Feldwerte-Tabelle
        html += QStringLiteral("<table class='felder'>");

        // Feste Felder (Bauteil-ID, Geprüft von/am)
        auto fRow = [&](const QString &lbl, const QString &val) {
            if (val.isEmpty()) return;
            html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
                  + QStringLiteral("</td><td>") + esc(val) + QStringLiteral("</td></tr>");
        };
        fRow(QStringLiteral("Seriennummer / Bauteil-ID"), bauteilId);
        fRow(QStringLiteral("Geprüft von"),  geprueftVon);
        fRow(QStringLiteral("Datum"),        geprueftAm);

        // Dynamische Felder
        if (!kat.isEmpty() && ibnId > 0) {
            const QVariantList vorlagen = ibnFeldvorlagenLaden(kat);
            const QVariantList werteListe = ibnFeldwerteLaden(ibnId);

            // Werte-Map aufbauen
            QMap<QString, QString> werteMap;
            for (const QVariant &wv : werteListe) {
                const QVariantMap wm = wv.toMap();
                werteMap.insert(wm.value("feldname").toString(),
                                wm.value("wert").toString());
            }

            for (const QVariant &fv : vorlagen) {
                const QVariantMap fm = fv.toMap();
                const QString feldname = fm.value("feldname").toString();
                const QString lbl      = fm.value("label").toString();
                const QString typ      = fm.value("feldtyp").toString();
                QString wert = werteMap.value(feldname);

                if (typ == QLatin1String("boolean"))
                    wert = (wert == QLatin1String("1")) ? QStringLiteral("Ja") : QStringLiteral("Nein");
                if (wert.isEmpty()) wert = QStringLiteral("–");

                html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
                      + QStringLiteral("</td><td>") + esc(wert) + QStringLiteral("</td></tr>");
            }
        }

        html += QStringLiteral("</table>");

        if (!notiz.isEmpty())
            html += QStringLiteral("<div class='notiz'>Notiz: ") + esc(notiz)
                  + QStringLiteral("</div>");

        html += QStringLiteral("</div>"); // .bm
    }

    // ── Unterschriftsfeld ─────────────────────────────────
    html += QStringLiteral("<div class='sig'>");
    html += QStringLiteral("<table><tr>"
            "<td>Erstellt von</td>"
            "<td>Geprüft von</td>"
            "<td>Datum / Unterschrift</td>"
            "</tr></table>");
    html += QStringLiteral("</div>");

    html += QStringLiteral("</body></html>");

    // ── In PDF rendern ────────────────────────────────────
    QPrinter printer(QPrinter::HighResolution);
    printer.setOutputFormat(QPrinter::PdfFormat);
    printer.setOutputFileName(localPath);
    printer.setPageSize(QPageSize(QPageSize::A4));
    printer.setPageOrientation(QPageLayout::Portrait);
    printer.setPageMargins(QMarginsF(20, 15, 15, 15), QPageLayout::Millimeter);

    QTextDocument doc;
    doc.setHtml(html);
    doc.print(&printer);

    return QFile::exists(localPath);
}
