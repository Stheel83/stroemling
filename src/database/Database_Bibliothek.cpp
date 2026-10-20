#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QUuid>

namespace {

// UUIDv4 rein in SQL (zufällig): Backfill vorhandener Bauteile und Trigger für alle künftigen INSERTs.
const char *const kUuidV4Sql =
    "lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-' || "
    "substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))";

} // namespace

QString Database::bauteilSystemUid(const QString &bezeichnung)
{
    // Namespace für Seed-Bauteil-UIDs – einmalig erzeugt und FÜR IMMER FEST (eine Änderung würde alle Standard-UIDs ändern).
    static const QUuid ns(QStringLiteral("{646fa01d-e27f-44af-9f0c-777c924fc973}"));
    return QUuid::createUuidV5(ns, bezeichnung.toUtf8()).toString(QUuid::WithoutBraces);
}

QString Database::bibliothekSichern(const QString &anlass)
{
    const QString ordner = QFileInfo(m_bibliothekPfad).absolutePath() + QStringLiteral("/backups");
    QDir().mkpath(ordner);
    const QString ziel = ordner + QStringLiteral("/bibliothek_%1_%2.db").arg(anlass,
                             QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss_zzz")));
    QString maskiert = ziel;
    maskiert.replace(QLatin1Char('\''), QStringLiteral("''"));
    QSqlQuery q(m_bibliothekDb);
    if (QFileInfo::exists(ziel) || !q.exec(QStringLiteral("VACUUM INTO '%1'").arg(maskiert))) {
        qCWarning(lcDb) << "Bibliothek-Sicherung nicht angelegt:" << q.lastError().text() << ziel;
        return {};
    }
    qCInfo(lcDb) << "Bibliothek-Sicherung:" << ziel;
    return ziel;
}

int Database::bauteilIdFuerUid(const QString &uid) const
{
    if (uid.isEmpty() || !m_bibliothekDb.isOpen())
        return -1;
    QSqlQuery q(m_bibliothekDb);
    q.prepare("SELECT id FROM bauteil WHERE uid = :u");
    q.bindValue(":u", uid);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    QSqlQuery a(m_bibliothekDb);
    a.prepare("SELECT bauteil_id FROM bauteil_alias WHERE alias_uid = :u");
    a.bindValue(":u", uid);
    if (a.exec() && a.next())
        return a.value(0).toInt();
    return -1;
}

bool Database::bauteilUidsAbgleichen()
{
    QSqlQuery q(m_bibliothekDb);
    QSet<QString> belegt;
    struct Zeile { int id; QString bezeichnung; QString uid; };
    QList<Zeile> system;
    if (!q.exec("SELECT id, bezeichnung, uid, ist_system FROM bauteil ORDER BY id")) {
        qCWarning(lcDb) << "Bauteil-UIDs lesen:" << q.lastError().text();
        return false;
    }
    while (q.next()) {
        belegt.insert(q.value(2).toString());
        if (q.value(3).toInt() != 0)
            system.append({ q.value(0).toInt(), q.value(1).toString(), q.value(2).toString() });
    }
    QSqlQuery upd(m_bibliothekDb);
    upd.prepare("UPDATE bauteil SET uid = :uid WHERE id = :id");
    for (const Zeile &z : system) {
        const QString soll = bauteilSystemUid(z.bezeichnung);
        // Gleichnamige Seed-Zeilen (aus einem früheren Namens-Backfill): die erste bekommt die Standard-UID, die übrigen
        // behalten ihre – UIDs müssen eindeutig bleiben, ein Öffnen der Bibliothek darf daran nie scheitern.
        if (z.uid == soll || belegt.contains(soll))
            continue;
        upd.bindValue(":uid", soll);
        upd.bindValue(":id", z.id);
        if (!upd.exec()) {
            qCWarning(lcDb) << "Bauteil-UID setzen:" << z.bezeichnung << upd.lastError().text();
            continue;
        }
        belegt.remove(z.uid);
        belegt.insert(soll);
    }
    return true;
}

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
            return seedStandardKlemmen() && seedNutzerBauteile() && bauteilUidsAbgleichen();
        }
        // Vor dem Migrieren einer bestehenden Bibliothek eine Sicherung ablegen (die Datei ist projektübergreifend und
        // nicht Teil des Komplettarchivs). Die Migration ist additiv und läuft in einer Transaktion; ein Fehlschlag der
        // Sicherung blockiert sie daher nicht, wird aber gemeldet.
        q.finish();   // sonst „cannot VACUUM – SQL statements in progress“ (die Versionsabfrage ist noch offen)
        if (version > 0)
            bibliothekSichern(QStringLiteral("v%1_vor_v%2").arg(version).arg(BIBLIOTHEK_SCHEMA_VERSION));
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

    // Schema v9 (SYM-KOPIE-VON-06): die Builtin-Symbole fi/sicherung/not_halt wurden
    // entfernt (Projekt-Migration 158) - Bauteile, die sie als Hauptfunktion-
    // Symbol referenzierten, auf die Nachfolger umhaengen.
    {
        static const char *const umhaengen[][2] = {
            { "fi", "fi_2pol" }, { "sicherung", "sicherung_einpolig" },
            { "sicherung_3pol", "sicherung_dreipolig" }, { "not_halt", "not_halt_nc_einpolig" },
            { "hupe", "horn_hupe" }, { "summer", "schnarre_summer" },
        };
        for (const auto &u : umhaengen) {
            QSqlQuery uq(m_bibliothekDb);
            uq.prepare("UPDATE bauteil SET hauptfunktion_symbol_id = :neu WHERE hauptfunktion_symbol_id = :alt");
            uq.bindValue(":neu", QString::fromLatin1(u[1]));
            uq.bindValue(":alt", QString::fromLatin1(u[0]));
            QSqlQuery kq(m_bibliothekDb);
            kq.prepare("UPDATE bauteil_kontakt SET symbol_id = :neu WHERE symbol_id = :alt");
            kq.bindValue(":neu", QString::fromLatin1(u[1]));
            kq.bindValue(":alt", QString::fromLatin1(u[0]));
            if (!uq.exec() || !kq.exec()) {
                qCWarning(lcDb) << "Bibliothek-Schema v9 Symbol-Umhaengen:" << uq.lastError().text() << kq.lastError().text();
                m_bibliothekDb.rollback();
                return false;
            }
        }
    }

    // Schema v10 (BIB-UID-01): bauteil.uid – stabile Bauteil-Identität statt rechnerlokaler Integer-ID (s. Manager-Konzept
    // M-03 §3/§7). Alle INSERT-Stellen nennen ihre Spalten ausdrücklich und kennen keine UID; ein Trigger vergibt daher
    // bei JEDEM künftigen Bauteil eine UUIDv4. Seed-Bauteile (ist_system=1) bekommen danach per bauteilUidsAbgleichen()
    // eine deterministische UID (UUIDv5 aus der Bezeichnung), damit sie auf allen Rechnern gleich ist.
    {
        const QStringList uidStmts = {
            QStringLiteral("ALTER TABLE bauteil ADD COLUMN uid TEXT NOT NULL DEFAULT ''"),
            QStringLiteral("UPDATE bauteil SET uid = %1 WHERE uid = ''").arg(QLatin1String(kUuidV4Sql)),
            // Teil-Index: ein leerer Wert ist zwischen INSERT und Trigger kurz erlaubt
            QStringLiteral("CREATE UNIQUE INDEX IF NOT EXISTS idx_bauteil_uid ON bauteil(uid) WHERE uid <> ''"),
            QStringLiteral("CREATE TRIGGER IF NOT EXISTS bauteil_uid_setzen AFTER INSERT ON bauteil WHEN NEW.uid = '' "
                           "BEGIN UPDATE bauteil SET uid = %1 WHERE id = NEW.id; END").arg(QLatin1String(kUuidV4Sql)),
        };
        for (const QString &sql : uidStmts) {
            if (!q.exec(sql)) {
                if (sql.startsWith(QLatin1String("ALTER")) && q.lastError().databaseText().toLower().contains("duplicate column"))
                    continue;
                qCWarning(lcDb) << "Bibliothek-Schema v10 (UID):" << q.lastError().text() << sql.left(60);
                m_bibliothekDb.rollback();
                return false;
            }
        }
    }

    // Schema v11 (BIB-IMPORT-01): bauteil_alias – eine FREMDE UID, die lokal als dasselbe Bauteil wie bauteil_id gilt
    // (entsteht beim Import durch „mit lokalem Bauteil verknüpfen“; UIDs selbst werden nie umgeschrieben).
    if (!q.exec("CREATE TABLE IF NOT EXISTS bauteil_alias ("
                "alias_uid TEXT PRIMARY KEY, "
                "bauteil_id INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE)")) {
        qCWarning(lcDb) << "Bibliothek-Schema v11 (Alias):" << q.lastError().text();
        m_bibliothekDb.rollback();
        return false;
    }

    // Schema v12 (Schutz von Standardteilen, Manager M-11): bauteil.standard_herkunft – '' = normales Bauteil,
    // 'firmenstandard' = beim Import als Firmenstandard gekennzeichnet. Zusammen mit ist_system (mitgeliefert) ergibt das den Begriff
    // „Standardteil“: Löschen verlangt eine Bestätigung, Bearbeiten zeigt einen Warnhinweis (kein Sperren).
    if (!q.exec("ALTER TABLE bauteil ADD COLUMN standard_herkunft TEXT NOT NULL DEFAULT ''")) {
        if (!q.lastError().databaseText().toLower().contains("duplicate column")) {
            qCWarning(lcDb) << "Bibliothek-Schema v12 (standard_herkunft):" << q.lastError().text();
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

    if (!seedStandardKlemmen() || !seedNutzerBauteile() || !bauteilUidsAbgleichen()) {
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
