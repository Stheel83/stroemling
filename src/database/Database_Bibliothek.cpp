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
        if (q.exec("SELECT MAX(version) FROM bibliothek_schema_version") && q.next())
            version = q.value(0).toInt();
        if (version >= BIBLIOTHEK_SCHEMA_VERSION) {
            qCInfo(lcDb) << "Bibliothek-Schema aktuell (v" << version << ")";
            // Seeds trotzdem erneut anwenden (idempotent, WHERE NOT EXISTS-Guard) –
            // sonst kommen später zu bauteile_nutzer.sql hinzugefügte Bauteile bei
            // bereits initialisierten Installationen nie an (GERAETE-SEED-01-Fund).
            return seedStandardKlemmen() && seedNutzerBauteile();
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
            farbe2          TEXT,
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
            verbindungstechnik    TEXT,
            litze_farbe           TEXT,
            litze_querschnitt     REAL,
            litze_bezeichnung     TEXT
        ))",
        R"(CREATE TABLE IF NOT EXISTS kontakt_typ (
            id                         INTEGER PRIMARY KEY,
            bauteil_id                 INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            geschlecht                 TEXT NOT NULL DEFAULT 'stift',
            kontaktgroesse             REAL,
            querschnitt_steckseite_min REAL,
            querschnitt_steckseite_max REAL,
            querschnitt_kabel_min      REAL,
            querschnitt_kabel_max      REAL,
            nennstrom_a                REAL,
            nennspannung_v             REAL,
            verbindungstechnik         TEXT
        ))",
        R"(CREATE TABLE IF NOT EXISTS steckverbinder_position (
            id                    INTEGER PRIMARY KEY,
            steckverbinder_typ_id INTEGER NOT NULL REFERENCES steckverbinder_typ(id) ON DELETE CASCADE,
            position_nr           INTEGER NOT NULL,
            kontakt_typ_id        INTEGER NOT NULL REFERENCES kontakt_typ(id),
            ist_schirmkontakt     INTEGER DEFAULT 0
        ))",
        R"(CREATE TABLE IF NOT EXISTS konfektioniertes_kabel (
            id                  INTEGER PRIMARY KEY,
            bauteil_id          INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            bauteil_kabel_id    INTEGER REFERENCES bauteil_kabel(id),
            stecker_a_bauteil_id INTEGER REFERENCES bauteil(id),
            stecker_b_bauteil_id INTEGER REFERENCES bauteil(id),
            laenge_m            REAL
        ))",
        R"(CREATE TABLE IF NOT EXISTS konfkabel_pin_zuordnung (
            id           INTEGER PRIMARY KEY,
            konfkabel_id INTEGER NOT NULL REFERENCES konfektioniertes_kabel(id) ON DELETE CASCADE,
            seite        TEXT    NOT NULL CHECK(seite IN ('A','B')),
            ader_nr      INTEGER NOT NULL,
            pin_nr       INTEGER NOT NULL,
            UNIQUE(konfkabel_id, seite, ader_nr)
        ))",
    };

    for (const QString &stmt : stmts) {
        if (!q.exec(stmt)) {
            qCWarning(lcDb) << "Bibliothek-Schema CREATE:" << q.lastError().text();
            m_bibliothekDb.rollback();
            return false;
        }
    }

    // Schema v2: litze-Spalten nachrüsten (no-op bei Frischinstall, toleriert Duplikat)
    // Schema v3: montageform nachrüsten (frei_stecker/frei_buchse/einbau_stecker/einbau_buchse)
    const QStringList upgradeStmts = {
        "ALTER TABLE steckverbinder_kontakt_typ ADD COLUMN litze_farbe TEXT",
        "ALTER TABLE steckverbinder_kontakt_typ ADD COLUMN litze_querschnitt REAL",
        "ALTER TABLE steckverbinder_kontakt_typ ADD COLUMN litze_bezeichnung TEXT",
        "ALTER TABLE steckverbinder_typ ADD COLUMN montageform TEXT",
    };
    for (const QString &upStmt : upgradeStmts) {
        if (!q.exec(upStmt)) {
            if (!q.lastError().databaseText().toLower().contains("duplicate column")) {
                qCWarning(lcDb) << "Bibliothek-Schema ALTER:" << q.lastError().text();
                m_bibliothekDb.rollback();
                return false;
            }
        }
    }

    // Schema v5: steckverbinder_kontakt_typ durch kontakt_typ + steckverbinder_position
    // ersetzt (Neukonzeption Jul 2026, keine Produktivnutzer → kein Datenübernahme-Pfad
    // nötig, siehe konzept/features/45_steckverbinder.md §3.1/§12).
    if (!q.exec("DROP TABLE IF EXISTS steckverbinder_kontakt_typ")) {
        qCWarning(lcDb) << "Bibliothek-Schema DROP steckverbinder_kontakt_typ:" << q.lastError().text();
        m_bibliothekDb.rollback();
        return false;
    }

    // Schema v6: bauteil_kabel_ader.farbe2 fuer echte Zweifarbigkeit (PE, DIN-47100-
    // Bifarben) – GNYE-Sonderfall entfaellt zugunsten farbe=GN/farbe2=YE.
    if (!q.exec("ALTER TABLE bauteil_kabel_ader ADD COLUMN farbe2 TEXT")) {
        if (!q.lastError().databaseText().toLower().contains("duplicate column")) {
            qCWarning(lcDb) << "Bibliothek-Schema ALTER farbe2:" << q.lastError().text();
            m_bibliothekDb.rollback();
            return false;
        }
    }
    if (!q.exec("UPDATE bauteil_kabel_ader SET farbe2 = 'YE', farbe = 'GN' WHERE farbe = 'GNYE'")) {
        qCWarning(lcDb) << "Bibliothek-Schema GNYE-Migration:" << q.lastError().text();
        m_bibliothekDb.rollback();
        return false;
    }

    // Schema v7: fuer_seed_vormerken (ONBOARDING-KETTEN-01) – reiner
    // Entwicklungs-Merker (analog symbol_definition.markiert_loeschen), um beim
    // Bauteil-Anlegen zu markieren, welche Bauteile noch in bauteile_nutzer.sql
    // übernommen werden sollen. Rein informativ, löscht/exportiert nichts selbst.
    if (!q.exec("ALTER TABLE bauteil ADD COLUMN fuer_seed_vormerken INTEGER NOT NULL DEFAULT 0")) {
        if (!q.lastError().databaseText().toLower().contains("duplicate column")) {
            qCWarning(lcDb) << "Bibliothek-Schema ALTER fuer_seed_vormerken:" << q.lastError().text();
            m_bibliothekDb.rollback();
            return false;
        }
    }

    // Schema v8: bauteil.ist_system (BAUTEIL-IST-SYSTEM-01, s.
    // konzept/features/06_bauteilbibliothek.md §8.8) – markiert Bauteile, die
    // aus dem mitgelieferten Seed stammen (seedStandardKlemmen()/
    // seedNutzerBauteile() setzen die Spalte ab jetzt selbst beim INSERT).
    // Grundlage für künftige sichere Korrekturen per gezieltem
    // UPDATE ... WHERE ist_system=1 AND bezeichnung=..., ohne Gefahr, ein
    // zufällig gleichnamiges echtes Nutzer-Bauteil zu treffen.
    if (!q.exec("ALTER TABLE bauteil ADD COLUMN ist_system INTEGER NOT NULL DEFAULT 0")) {
        if (!q.lastError().databaseText().toLower().contains("duplicate column")) {
            qCWarning(lcDb) << "Bibliothek-Schema ALTER ist_system:" << q.lastError().text();
            m_bibliothekDb.rollback();
            return false;
        }
    }

    // Einmaliges Backfill: bereits vor v8 vorhandene Seed-Bauteile nachträglich
    // als ist_system=1 markieren (der INSERT-Guard in seedStandardKlemmen()/
    // seedNutzerBauteile() prüft nur "bezeichnung existiert bereits" und
    // überspringt sie deshalb sonst dauerhaft). Liste = alle Bezeichnungen,
    // die zum Zeitpunkt dieser Migration im Seed stehen (6 Standard-Klemmen +
    // bauteile_nutzer.sql) – bei künftigen Ergänzungen setzt der jeweilige
    // Seed-Lauf ist_system schon selbst, kein neuer Backfill nötig.
    {
        static const QStringList seedBezeichnungen = {
            QStringLiteral("Durchgangsklemme 2,5mm²"), QStringLiteral("Durchgangsklemme 4mm²"),
            QStringLiteral("PE-Klemme 2,5mm²"), QStringLiteral("N-Klemme 2,5mm²"),
            QStringLiteral("Doppelstockklemme 2,5mm²"), QStringLiteral("Trennklemme 2,5mm²"),
            QStringLiteral("NYM-J 3x1,5"), QStringLiteral("NYM-J 5x1,5"),
            QStringLiteral("LIYY 5x0,5"), QStringLiteral("LiYCY 4x0,25"),
            QStringLiteral("Schütz 3RT2015-1AP01"), QStringLiteral("Hilfsrelais Finder 55.34"),
            QStringLiteral("LS-Schalter B16"), QStringLiteral("FI-Schutzschalter 25A/30mA"),
            QStringLiteral("Feinsicherung 5x20mm 2A"), QStringLiteral("Not-Halt-Taster"),
            QStringLiteral("Taster grün (Ein)"), QStringLiteral("Taster rot (Aus)"),
            QStringLiteral("Meldeleuchte rot 230V"), QStringLiteral("Drehstrommotor 0,55kW"),
            QStringLiteral("Steuertrafo 230/24V 63VA"), QStringLiteral("Wago 2er"),
            QStringLiteral("Wago 3er"), QStringLiteral("Wago 5er"),
            QStringLiteral("Wago 1er Durchgangsverbinder"),
        };
        QSqlQuery qBackfill(m_bibliothekDb);
        qBackfill.prepare("UPDATE bauteil SET ist_system = 1 WHERE bezeichnung = :bez");
        for (const QString &bez : seedBezeichnungen) {
            qBackfill.bindValue(":bez", bez);
            if (!qBackfill.exec()) {
                qCWarning(lcDb) << "Bibliothek-Schema ist_system-Backfill:" << bez << qBackfill.lastError().text();
                m_bibliothekDb.rollback();
                return false;
            }
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
    QSqlQuery fqExist(m_bibliothekDb);
    fqExist.prepare("SELECT 1 FROM farb_definition WHERE bezeichnung = :bez LIMIT 1");
    QSqlQuery fq(m_bibliothekDb);
    fq.prepare("INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) "
               "VALUES (:hex, :bez, 1, :sort)");
    for (const Farbe &f : farben) {
        // Idempotenz-Guard: bereits vorhandene Farbdefinition nicht erneut anlegen
        fqExist.bindValue(":bez", QString::fromUtf8(f.bez));
        if (fqExist.exec() && fqExist.next()) continue;

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

    // bibliothek_schema_version hat keine UNIQUE-Constraint auf 'version' – daher
    // erst alle Zeilen löschen und die aktuelle Version neu einfügen, statt
    // INSERT OR REPLACE (das ohne Konflikt-Ziel nie ersetzt, sondern immer anhängt).
    if (!q.exec("DELETE FROM bibliothek_schema_version") ||
        !q.exec(QString("INSERT INTO bibliothek_schema_version (version) VALUES (%1)")
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
