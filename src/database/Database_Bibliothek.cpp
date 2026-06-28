#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

bool Database::openBibliothek(const QString &path)
{
    m_bibliothekPfad = path;

    m_bibliothekDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_bibliothek");
    m_bibliothekDb.setDatabaseName(path);
    if (!m_bibliothekDb.open()) {
        qCWarning(lcDb) << "Bibliothek-DB konnte nicht geöffnet werden:"
                        << m_bibliothekDb.lastError().text();
        return false;
    }
    {
        QSqlQuery pragma(m_bibliothekDb);
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA journal_mode = WAL");
    }
    qCInfo(lcDb) << "Bibliothek-DB geöffnet:" << path;
    return checkAndApplyBibliothekSchema();
}

bool Database::checkAndApplyBibliothekSchema()
{
    {
        QSqlQuery q(m_bibliothekDb);
        if (!q.exec("CREATE TABLE IF NOT EXISTS bibliothek_schema_version "
                    "(version INTEGER NOT NULL)")) {
            qCWarning(lcDb) << "bibliothek_schema_version anlegen:"
                            << q.lastError().text();
            return false;
        }
        int version = 0;
        if (q.exec("SELECT version FROM bibliothek_schema_version LIMIT 1") && q.next())
            version = q.value(0).toInt();
        if (version >= BIBLIOTHEK_SCHEMA_VERSION) {
            qCInfo(lcDb) << "Bibliothek-Schema aktuell (v" << version << ")";
            return true;
        }
    }

    if (!m_bibliothekDb.transaction()) {
        qCWarning(lcDb) << "Bibliothek-Schema: Transaktion fehlgeschlagen";
        return false;
    }

    QSqlQuery q(m_bibliothekDb);
    const QStringList stmts = {
        R"(CREATE TABLE IF NOT EXISTS bauteil_kategorie (
            id          INTEGER PRIMARY KEY,
            name        TEXT NOT NULL,
            parent_id   INTEGER REFERENCES bauteil_kategorie(id),
            sortierung  INTEGER DEFAULT 0
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil (
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
            url_hersteller  TEXT,
            url_datenblatt  TEXT,
            hauptfunktion_symbol_id TEXT,
            bild_mime       TEXT
        ))",
        R"(CREATE TABLE IF NOT EXISTS farb_definition (
            id           INTEGER PRIMARY KEY,
            hex_wert     TEXT,
            bezeichnung  TEXT NOT NULL,
            ist_standard INTEGER DEFAULT 0,
            sortierung   INTEGER DEFAULT 0
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_klemme (
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
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_klemme_querschnitt (
            id        INTEGER PRIMARY KEY,
            klemme_id INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            adertyp   TEXT NOT NULL,
            min_mm2   REAL NOT NULL,
            max_mm2   REAL NOT NULL
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_klemme_bruecke (
            id          INTEGER PRIMARY KEY,
            klemme_id   INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            von_ebene   INTEGER NOT NULL,
            nach_ebene  INTEGER NOT NULL,
            ist_pe_fuss INTEGER DEFAULT 0
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_klemme_eigenschaft (
            id           INTEGER PRIMARY KEY,
            klemme_id    INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            schluessel   TEXT NOT NULL,
            wert         TEXT NOT NULL,
            beschreibung TEXT
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_kabel (
            id                  INTEGER PRIMARY KEY,
            bauteil_id          INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            kabeltyp            TEXT,
            geschirmt           INTEGER NOT NULL DEFAULT 0,
            paarweise_verdrillt INTEGER NOT NULL DEFAULT 0,
            aussenmantel_farbe  TEXT,
            aussenmantel_mm     REAL,
            material_leiter     TEXT,
            material_isolierung TEXT
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_kabel_ader (
            id              INTEGER PRIMARY KEY,
            kabel_id        INTEGER NOT NULL REFERENCES bauteil_kabel(id) ON DELETE CASCADE,
            ader_nr         INTEGER NOT NULL,
            farbe           TEXT,
            nummer          TEXT,
            bezeichnung     TEXT,
            querschnitt_mm2 REAL
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_kabel_paar (
            id       INTEGER PRIMARY KEY,
            kabel_id INTEGER NOT NULL REFERENCES bauteil_kabel(id) ON DELETE CASCADE,
            paar_nr  INTEGER NOT NULL,
            ader_a   INTEGER NOT NULL,
            ader_b   INTEGER NOT NULL
        ))",
        R"(CREATE TABLE IF NOT EXISTS bauteil_kontakt (
            id          INTEGER PRIMARY KEY,
            bauteil_id  INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            symbol_id   TEXT    NOT NULL,
            bezeichnung TEXT    NOT NULL DEFAULT '',
            pin_bez     TEXT    NOT NULL DEFAULT '{}'
        ))",
        R"(CREATE TABLE IF NOT EXISTS steckverbinder_typ (
            id                INTEGER PRIMARY KEY,
            bauteil_id        INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            polzahl           INTEGER,
            ip_getrennt       TEXT,
            ip_gesteckt       TEXT,
            kodierung         TEXT,
            verriegelung      TEXT,
            hat_schirmkontakt INTEGER DEFAULT 0,
            geschirmt         INTEGER DEFAULT 0
        ))",
        R"(CREATE TABLE IF NOT EXISTS steckverbinder_kabeleinf (
            id                    INTEGER PRIMARY KEY,
            steckverbinder_typ_id INTEGER NOT NULL REFERENCES steckverbinder_typ(id) ON DELETE CASCADE,
            einf_nr               INTEGER NOT NULL DEFAULT 1,
            aussen_min_mm         REAL,
            aussen_max_mm         REAL,
            einf_typ              TEXT,
            zugentlastung         TEXT
        ))",
        R"(CREATE TABLE IF NOT EXISTS steckverbinder_kontakt_typ (
            id                    INTEGER PRIMARY KEY,
            steckverbinder_typ_id INTEGER NOT NULL REFERENCES steckverbinder_typ(id) ON DELETE CASCADE,
            position_nr           INTEGER NOT NULL,
            ist_schirmkontakt     INTEGER DEFAULT 0,
            kontaktgroesse        TEXT,
            querschnitt_kabel_min REAL,
            querschnitt_kabel_max REAL,
            nennstrom_a           REAL,
            nennspannung_v        REAL,
            verbindungstechnik    TEXT
        ))",
    };

    for (const QString &stmt : stmts) {
        if (!q.exec(stmt)) {
            qCWarning(lcDb) << "Bibliothek-Schema CREATE:" << q.lastError().text();
            m_bibliothekDb.rollback();
            return false;
        }
    }

    // Farb-Definitionen (Gehäuse- und Aderfarben)
    struct Farbe { const char *hex; const char *bez; int sort; };
    static const QList<Farbe> farben = {
        { "#808080", "Grau",                            1 },
        { "#0000CC", "Blau – N-Leiter (DIN VDE 0100)",         2 },
        { "#66AAFF", "Blau – Eigensicher (IEC 60079-14)",       3 },
        { "#3366CC", "Blau – ohne Definition",                  4 },
        { "#88AA00", "Grün-Gelb – PE (normverpflichtend)", 5 },
        { "#FF8800", "Orange – Trennstelle / Potenzialgruppe",  6 },
        { "#CC0000", "Rot – L-Leiter / Sonderkreis",           7 },
        { "#222222", "Schwarz – L-Leiter (ältere Norm)",   8 },
        { "#EEEEEE", "Weiß – Sonderkreis",                 9 },
        { "#FFCC00", "Gelb – Sicherheitskreis",                10 },
        { "#E8D8B0", "Beige – ältere Installation",        11 },
        { "transparent", "Transparent / farblos",                    0 },
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
    QSqlQuery fq(m_bibliothekDb);
    fq.prepare("INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) "
               "VALUES (:hex, :bez, 1, :sort)");
    for (const Farbe &f : farben) {
        fq.bindValue(":hex",  QString::fromUtf8(f.hex));
        fq.bindValue(":bez",  QString::fromUtf8(f.bez));
        fq.bindValue(":sort", f.sort);
        if (!fq.exec()) {
            qCWarning(lcDb) << "Bibliothek-Seed farb_definition:" << fq.lastError().text();
            m_bibliothekDb.rollback();
            return false;
        }
    }

    if (!seedStandardKlemmen() || !seedNutzerBauteile()) {
        qCWarning(lcDb) << "Bibliothek-Seed fehlgeschlagen";
        m_bibliothekDb.rollback();
        return false;
    }

    if (!q.exec(QString("INSERT OR REPLACE INTO bibliothek_schema_version (version) VALUES (%1)")
                    .arg(BIBLIOTHEK_SCHEMA_VERSION))) {
        qCWarning(lcDb) << "bibliothek_schema_version schreiben:" << q.lastError().text();
        m_bibliothekDb.rollback();
        return false;
    }

    if (!m_bibliothekDb.commit()) {
        m_bibliothekDb.rollback();
        return false;
    }

    qCInfo(lcDb) << "Bibliothek-Schema v" << BIBLIOTHEK_SCHEMA_VERSION << " angelegt.";
    return true;
}
