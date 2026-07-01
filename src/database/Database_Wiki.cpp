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

bool Database::openWiki(const QString &path)
{
    m_wikiPfad = path;
    m_wikiBlobDir = QFileInfo(path).absolutePath() + "/wiki_blobs";
    QDir().mkpath(m_wikiBlobDir);

    m_wikiDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_wiki");
    m_wikiDb.setDatabaseName(path);
    if (!m_wikiDb.open()) {
        qCWarning(lcDb) << "Wiki-Datenbank konnte nicht geöffnet werden:" << m_wikiDb.lastError().text();
        return false;
    }
    {
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA journal_mode = WAL");
    }
    qCInfo(lcDb) << "Wiki-Datenbank geöffnet:" << path;
    if (!checkAndApplyWikiSchema())
        return false;
    // Eingebettete Bundles (Qt-Ressourcen) automatisch einspielen
    const QStringList eingebetteteBundles = {};  // hier :/bundles/xxx.json eintragen sobald vorhanden
    for (const QString &res : eingebetteteBundles) {
        if (QFile::exists(res))
            wikiBundleAnwenden(res);
    }
    return true;
}

bool Database::checkAndApplyWikiSchema()
{
    int storedVersion = -1;
    {
        QSqlQuery q(m_wikiDb);
        if (!q.exec("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")) {
            qCWarning(lcDb) << "wiki schema_version anlegen:" << q.lastError().text();
            return false;
        }
        if (q.exec("SELECT version FROM schema_version LIMIT 1") && q.next())
            storedVersion = q.value(0).toInt();
    }

    if (storedVersion == WIKI_SCHEMA_VERSION) {
        qCInfo(lcDb) << "Wiki-Schema bereits auf Version" << WIKI_SCHEMA_VERSION << "– seed prüfen.";
        return seedWikiStarterInhalte();
    }

    qCInfo(lcDb) << "Wiki-Schema:" << storedVersion << "→" << WIKI_SCHEMA_VERSION;

    // Backup vor Wiki-Migration (nur wenn DB bereits Daten hat)
    if (storedVersion >= 0)
        erstelleBackup("stroemling_wiki", "wiki", storedVersion);

    if (!m_wikiDb.transaction()) {
        qCWarning(lcDb) << "Wiki-Transaktion konnte nicht gestartet werden:" << m_wikiDb.lastError().text();
        return false;
    }

    // Inkrementelle Spalten-Migrationen (einmalig je Version)
    if (storedVersion >= 1 && storedVersion < 3) {
        bool hatIstSystem = false;
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA table_info(wiki_artikel)");
        while (pragma.next()) {
            if (pragma.value(1).toString() == "ist_system") { hatIstSystem = true; break; }
        }
        if (!hatIstSystem) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_artikel ADD COLUMN ist_system INTEGER NOT NULL DEFAULT 0")) {
                qCWarning(lcDb) << "ALTER TABLE wiki_artikel ADD ist_system:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
    }

    // v10: bundle_kennung + von_nutzer_geaendert in wiki_artikel; wiki_meta-Tabelle
    if (storedVersion >= 1 && storedVersion < 10) {
        bool hatBundleKennung = false, hatVonNutzerGeaendert = false;
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA table_info(wiki_artikel)");
        while (pragma.next()) {
            const QString col = pragma.value(1).toString();
            if (col == "bundle_kennung")       hatBundleKennung = true;
            if (col == "von_nutzer_geaendert") hatVonNutzerGeaendert = true;
        }
        if (!hatBundleKennung) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_artikel ADD COLUMN bundle_kennung TEXT DEFAULT NULL")) {
                qCWarning(lcDb) << "ALTER wiki_artikel ADD bundle_kennung:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
        if (!hatVonNutzerGeaendert) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_artikel ADD COLUMN von_nutzer_geaendert INTEGER NOT NULL DEFAULT 0")) {
                qCWarning(lcDb) << "ALTER wiki_artikel ADD von_nutzer_geaendert:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
        QSqlQuery q(m_wikiDb);
        if (!q.exec("CREATE TABLE IF NOT EXISTS wiki_meta (schluessel TEXT PRIMARY KEY, wert TEXT NOT NULL)")) {
            qCWarning(lcDb) << "CREATE wiki_meta:" << q.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    // v11: wiki_bild.daten (BLOB) → externe Dateien in wiki_blobs/
    if (storedVersion >= 1 && storedVersion < 11) {
        bool hasBlobPfad = false, hasDaten = false;
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA table_info(wiki_bild)");
        while (pragma.next()) {
            const QString col = pragma.value(1).toString();
            if (col == "blob_pfad") hasBlobPfad = true;
            if (col == "daten")     hasDaten    = true;
        }
        if (!hasBlobPfad) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_bild ADD COLUMN blob_pfad TEXT NOT NULL DEFAULT ''")) {
                qCWarning(lcDb) << "ALTER wiki_bild ADD blob_pfad:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
        if (hasDaten) {
            // Bestehende BLOBs in Dateien auslagern
            QSqlQuery sel(m_wikiDb);
            sel.exec("SELECT id, mime_typ, daten FROM wiki_bild WHERE blob_pfad = ''");
            while (sel.next()) {
                const int        blobId = sel.value(0).toInt();
                const QString    mime   = sel.value(1).toString();
                const QByteArray daten  = sel.value(2).toByteArray();
                if (daten.isEmpty()) continue;
                const QString ext = mime.contains("png") ? ".png" : ".jpg";
                const QString fn  = QString::number(blobId) + ext;
                QFile f(m_wikiBlobDir + "/" + fn);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(daten);
                    QSqlQuery upd(m_wikiDb);
                    upd.prepare("UPDATE wiki_bild SET blob_pfad = :p WHERE id = :id");
                    upd.bindValue(":p",  fn);
                    upd.bindValue(":id", blobId);
                    upd.exec();
                } else {
                    qCWarning(lcDb) << "wiki_bild Migration: Datei nicht schreibbar:" << fn;
                }
            }
            QSqlQuery drop(m_wikiDb);
            if (!drop.exec("ALTER TABLE wiki_bild DROP COLUMN daten")) {
                qCWarning(lcDb) << "ALTER wiki_bild DROP COLUMN daten:" << drop.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
    }

    // v13: Schwärzchen-Wiki-Bild aktualisiert (neues Charakterblatt). seedWikiStarterInhalte()
    // legt Bilder nur an, wenn der Artikel noch keines hat — bestehende BLOB-Datei am
    // festen blob_pfad daher direkt mit den aktuellen QRC-Bytes überschreiben.
    if (storedVersion >= 1 && storedVersion < 13) {
        QSqlQuery qSel(m_wikiDb);
        qSel.exec(R"(
            SELECT wb.blob_pfad FROM wiki_bild wb
            JOIN wiki_artikel wa ON wa.id = wb.artikel_id
            WHERE wa.titel = 'Schwärzchen – Systemfisch L2'
        )");
        if (qSel.next()) {
            const QString blobPfad = qSel.value(0).toString();
            QFile qrc(":/assets/schwaerzchen_sheet.png");
            if (!blobPfad.isEmpty() && qrc.open(QIODevice::ReadOnly)) {
                QFile out(m_wikiBlobDir + "/" + blobPfad);
                if (out.open(QIODevice::WriteOnly | QIODevice::Truncate))
                    out.write(qrc.readAll());
                else
                    qCWarning(lcDb) << "Schwärzchen-Bild-Update: Datei nicht schreibbar:" << blobPfad;
            }
        }
    }

    if (!createWikiSchema() || !seedWikiStarterInhalte()) {
        m_wikiDb.rollback();
        return false;
    }

    // Alte Zeile löschen, damit LIMIT-1-Abfrage beim nächsten Start korrekt ist
    QSqlQuery del(m_wikiDb);
    del.exec("DELETE FROM schema_version");
    QSqlQuery ins(m_wikiDb);
    ins.prepare("INSERT INTO schema_version (version) VALUES (:v)");
    ins.bindValue(":v", WIKI_SCHEMA_VERSION);
    if (!ins.exec()) {
        qCWarning(lcDb) << "wiki schema_version schreiben:" << ins.lastError().text();
        m_wikiDb.rollback();
        return false;
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        return false;
    }

    qCInfo(lcDb) << "Wiki-Schema v" << WIKI_SCHEMA_VERSION << "erfolgreich angelegt.";
    return true;
}

bool Database::createWikiSchema()
{
    QSqlQuery q(m_wikiDb);

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_kategorie (
            id           INTEGER PRIMARY KEY,
            name         TEXT    NOT NULL UNIQUE,
            beschreibung TEXT    NOT NULL DEFAULT '',
            sortierung   INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qCWarning(lcDb) << "Fehler wiki_kategorie:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_artikel (
            id                   INTEGER PRIMARY KEY,
            kategorie_id         INTEGER NOT NULL REFERENCES wiki_kategorie(id) ON DELETE RESTRICT,
            titel                TEXT    NOT NULL,
            inhalt               TEXT    NOT NULL DEFAULT '',
            tags                 TEXT    NOT NULL DEFAULT '',
            ist_system           INTEGER NOT NULL DEFAULT 0,
            bundle_kennung       TEXT    DEFAULT NULL,
            von_nutzer_geaendert INTEGER NOT NULL DEFAULT 0,
            erstellt_am          TEXT    NOT NULL DEFAULT (datetime('now')),
            geaendert_am         TEXT    NOT NULL DEFAULT (datetime('now'))
        )
    )")) {
        qCWarning(lcDb) << "Fehler wiki_artikel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_meta (
            schluessel TEXT PRIMARY KEY,
            wert       TEXT NOT NULL
        )
    )")) {
        qCWarning(lcDb) << "Fehler wiki_meta:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_bild (
            id           INTEGER PRIMARY KEY,
            artikel_id   INTEGER NOT NULL REFERENCES wiki_artikel(id) ON DELETE CASCADE,
            dateiname    TEXT    NOT NULL,
            mime_typ     TEXT    NOT NULL DEFAULT 'image/jpeg',
            blob_pfad    TEXT    NOT NULL DEFAULT '',
            beschreibung TEXT    NOT NULL DEFAULT '',
            sortierung   INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qCWarning(lcDb) << "Fehler wiki_bild:" << q.lastError().text();
        return false;
    }

    // FTS5 optional – fehlt z.B. in MXE-SQLite (Windows-Cross-Build)
    m_fts5Verfuegbar = q.exec(R"(
        CREATE VIRTUAL TABLE IF NOT EXISTS wiki_suche USING fts5(
            titel, inhalt, tags,
            content='wiki_artikel',
            content_rowid='id'
        )
    )");
    if (!m_fts5Verfuegbar) {
        qCWarning(lcDb) << "FTS5 nicht verfügbar – Wiki-Suche deaktiviert:" << q.lastError().text();
    } else {
        if (!q.exec(R"(
            CREATE TRIGGER IF NOT EXISTS wiki_artikel_ai AFTER INSERT ON wiki_artikel BEGIN
                INSERT INTO wiki_suche(rowid, titel, inhalt, tags)
                VALUES (new.id, new.titel, new.inhalt, new.tags);
            END
        )")) { qCWarning(lcDb) << "Trigger wiki_artikel_ai:" << q.lastError().text(); }

        if (!q.exec(R"(
            CREATE TRIGGER IF NOT EXISTS wiki_artikel_ad AFTER DELETE ON wiki_artikel BEGIN
                INSERT INTO wiki_suche(wiki_suche, rowid, titel, inhalt, tags)
                VALUES ('delete', old.id, old.titel, old.inhalt, old.tags);
            END
        )")) { qCWarning(lcDb) << "Trigger wiki_artikel_ad:" << q.lastError().text(); }

        if (!q.exec(R"(
            CREATE TRIGGER IF NOT EXISTS wiki_artikel_au AFTER UPDATE ON wiki_artikel BEGIN
                INSERT INTO wiki_suche(wiki_suche, rowid, titel, inhalt, tags)
                VALUES ('delete', old.id, old.titel, old.inhalt, old.tags);
                INSERT INTO wiki_suche(rowid, titel, inhalt, tags)
                VALUES (new.id, new.titel, new.inhalt, new.tags);
            END
        )")) { qCWarning(lcDb) << "Trigger wiki_artikel_au:" << q.lastError().text(); }
    }

    return true;
}


QVariantList Database::wikiAlleKategorien()
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name");
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0);
        m["name"]         = q.value(1);
        m["beschreibung"] = q.value(2);
        m["sortierung"]   = q.value(3);
        result << m;
    }
    return result;
}

int Database::wikiKategorieAnlegen(const QString &name, const QString &beschreibung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("INSERT INTO wiki_kategorie (name, beschreibung) VALUES (:n, :b)");
    q.bindValue(":n", name);
    q.bindValue(":b", beschreibung);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiKategorieAnlegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiKategorieUmbenennen(int id, const QString &name, const QString &beschreibung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_kategorie SET name = :n, beschreibung = :b WHERE id = :id");
    q.bindValue(":n",   name);
    q.bindValue(":b",   beschreibung);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiKategorieUmbenennen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiKategorieLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_kategorie WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiKategorieLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiKategorieSortierungSetzen(int id, int sortierung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_kategorie SET sortierung = :s WHERE id = :id");
    q.bindValue(":s",  sortierung);
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiKategorieSortierungSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Wiki – Artikel
// ============================================================
QVariantList Database::wikiArtikelFuerKategorie(int kategorieId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, titel, tags, geaendert_am, ist_system, bundle_kennung, von_nutzer_geaendert FROM wiki_artikel WHERE kategorie_id = :kid ORDER BY titel");
    q.bindValue(":kid", kategorieId);
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]                 = q.value(0);
        m["titel"]              = q.value(1);
        m["tags"]               = q.value(2);
        m["geaendertAm"]        = q.value(3);
        m["istSystem"]          = q.value(4);
        m["bundleKennung"]      = q.value(5);
        m["vonNutzerGeaendert"] = q.value(6);
        result << m;
    }
    return result;
}

QVariantMap Database::wikiArtikelLaden(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, kategorie_id, titel, inhalt, tags, ist_system, bundle_kennung, von_nutzer_geaendert, erstellt_am, geaendert_am FROM wiki_artikel WHERE id = :id");
    q.bindValue(":id", id);
    QVariantMap m;
    if (!q.exec() || !q.next()) return m;
    m["id"]                 = q.value(0);
    m["kategorieId"]        = q.value(1);
    m["titel"]              = q.value(2);
    m["inhalt"]             = q.value(3);
    m["tags"]               = q.value(4);
    m["istSystem"]          = q.value(5);
    m["bundleKennung"]      = q.value(6);
    m["vonNutzerGeaendert"] = q.value(7);
    m["erstelltAm"]         = q.value(8);
    m["geaendertAm"]        = q.value(9);
    return m;
}

int Database::wikiArtikelAnlegen(int kategorieId, const QString &titel)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("INSERT INTO wiki_artikel (kategorie_id, titel) VALUES (:kid, :t)");
    q.bindValue(":kid", kategorieId);
    q.bindValue(":t",   titel);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiArtikelAnlegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiArtikelSpeichern(int id, const QString &titel,
                                     const QString &inhalt, const QString &tags)
{
    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        UPDATE wiki_artikel
        SET titel = :t, inhalt = :i, tags = :tags,
            geaendert_am = datetime('now')
        WHERE id = :id
    )");
    q.bindValue(":t",    titel);
    q.bindValue(":i",    inhalt);
    q.bindValue(":tags", tags);
    q.bindValue(":id",   id);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiArtikelSpeichern:" << q.lastError().text();
        return false;
    }
    // Wenn es ein Bundle-Artikel ist, Nutzer-Änderung markieren
    QSqlQuery flag(m_wikiDb);
    flag.prepare("UPDATE wiki_artikel SET von_nutzer_geaendert = 1 WHERE id = :id AND bundle_kennung IS NOT NULL");
    flag.bindValue(":id", id);
    flag.exec();
    return true;
}

bool Database::wikiArtikelLoeschen(int id)
{
    wikiBlobDateienLoeschenFuerArtikel(id);
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_artikel WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiArtikelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Wiki – Bilder  (Blobs liegen als Dateien in m_wikiBlobDir)
// ============================================================

void Database::wikiBlobDateienLoeschenFuerArtikel(int artikelId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT blob_pfad FROM wiki_bild WHERE artikel_id = :aid");
    q.bindValue(":aid", artikelId);
    if (!q.exec()) return;
    while (q.next()) {
        const QString fn = q.value(0).toString();
        if (!fn.isEmpty())
            QFile::remove(m_wikiBlobDir + "/" + fn);
    }
}

void Database::wikiBlobDateienAlleNutzerArtikelLoeschen()
{
    QSqlQuery q(m_wikiDb);
    q.exec("SELECT wb.blob_pfad FROM wiki_bild wb JOIN wiki_artikel wa ON wa.id = wb.artikel_id WHERE wa.ist_system = 0");
    while (q.next()) {
        const QString fn = q.value(0).toString();
        if (!fn.isEmpty())
            QFile::remove(m_wikiBlobDir + "/" + fn);
    }
}

QVariantList Database::wikiBilderFuerArtikel(int artikelId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, dateiname, mime_typ, beschreibung, sortierung FROM wiki_bild WHERE artikel_id = :aid ORDER BY sortierung, id");
    q.bindValue(":aid", artikelId);
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0);
        m["dateiname"]    = q.value(1);
        m["mimeTyp"]      = q.value(2);
        m["beschreibung"] = q.value(3);
        m["sortierung"]   = q.value(4);
        result << m;
    }
    return result;
}

int Database::wikiBildHinzufuegen(int artikelId, const QString &pfad)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QImage img(localPfad);
    if (img.isNull()) {
        qCWarning(lcDb) << "wikiBildHinzufuegen: Bild nicht lesbar:" << localPfad;
        return -1;
    }
    if (img.width() > 1920)
        img = img.scaledToWidth(1920, Qt::SmoothTransformation);

    QByteArray daten;
    QBuffer buf(&daten);
    buf.open(QIODevice::WriteOnly);
    const QString ext = QFileInfo(localPfad).suffix().toLower();
    const QByteArray fmt = (ext == "png") ? "PNG" : "JPEG";
    img.save(&buf, fmt.constData(), 85);

    const QString mimeTyp   = (ext == "png") ? "image/png" : "image/jpeg";
    const QString dateiname = QFileInfo(localPfad).fileName();

    // Zuerst Zeile einfügen, um die ID zu bekommen
    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, blob_pfad, sortierung)
        VALUES (:aid, :fn, :mime, '',
                (SELECT COALESCE(MAX(sortierung), 0) + 1 FROM wiki_bild WHERE artikel_id = :aid2))
    )");
    q.bindValue(":aid",  artikelId);
    q.bindValue(":fn",   dateiname);
    q.bindValue(":mime", mimeTyp);
    q.bindValue(":aid2", artikelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiBildHinzufuegen INSERT:" << q.lastError().text();
        return -1;
    }
    const int newId = q.lastInsertId().toInt();

    // Bilddatei schreiben
    const QString fn = QString::number(newId) + (ext == "png" ? ".png" : ".jpg");
    QFile f(m_wikiBlobDir + "/" + fn);
    if (!f.open(QIODevice::WriteOnly)) {
        qCWarning(lcDb) << "wikiBildHinzufuegen: Datei nicht schreibbar:" << fn;
        QSqlQuery del(m_wikiDb);
        del.prepare("DELETE FROM wiki_bild WHERE id = :id");
        del.bindValue(":id", newId);
        del.exec();
        return -1;
    }
    f.write(daten);

    QSqlQuery upd(m_wikiDb);
    upd.prepare("UPDATE wiki_bild SET blob_pfad = :p WHERE id = :id");
    upd.bindValue(":p",  fn);
    upd.bindValue(":id", newId);
    upd.exec();

    return newId;
}

bool Database::wikiBildLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT blob_pfad FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (q.exec() && q.next()) {
        const QString fn = q.value(0).toString();
        if (!fn.isEmpty())
            QFile::remove(m_wikiBlobDir + "/" + fn);
    }
    q.prepare("DELETE FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiBildLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

QString Database::wikiBildAlsTempDatei(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT blob_pfad FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec() || !q.next()) return {};
    const QString fn = q.value(0).toString();
    if (fn.isEmpty()) return {};
    return m_wikiBlobDir + "/" + fn;
}

// ============================================================
// Wiki – Volltext-Suche (FTS5)
// ============================================================
QVariantList Database::wikiSuchen(const QString &suchbegriff)
{
    if (suchbegriff.trimmed().isEmpty() || !m_fts5Verfuegbar) return {};

    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        SELECT wa.id, wa.kategorie_id, wa.titel, wa.tags,
               snippet(wiki_suche, 1, '<b>', '</b>', '…', 20) AS snippet
        FROM wiki_suche
        JOIN wiki_artikel wa ON wa.id = wiki_suche.rowid
        WHERE wiki_suche MATCH :q
        ORDER BY rank
    )");
    q.bindValue(":q", suchbegriff + "*");

    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "wikiSuchen:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]          = q.value(0);
        m["kategorieId"] = q.value(1);
        m["titel"]       = q.value(2);
        m["tags"]        = q.value(3);
        m["snippet"]     = q.value(4);
        result << m;
    }
    return result;
}

// ============================================================
// Wiki – Export / Import (JSON)
// ============================================================
bool Database::wikiExportJson(const QString &pfad)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    // Kategorien
    QJsonArray kategorienArr;
    QSqlQuery qKat(m_wikiDb);
    if (!qKat.exec("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name")) {
        qCWarning(lcDb) << "wikiExportJson kategorien:" << qKat.lastError().text();
        return false;
    }
    while (qKat.next()) {
        QJsonObject o;
        o["id"]           = qKat.value(0).toInt();
        o["name"]         = qKat.value(1).toString();
        o["beschreibung"] = qKat.value(2).toString();
        o["sortierung"]   = qKat.value(3).toInt();
        kategorienArr.append(o);
    }

    // Nur Nutzer-Artikel (ist_system = 0)
    QJsonArray artikelArr;
    QSqlQuery qArt(m_wikiDb);
    if (!qArt.exec(R"(
        SELECT wa.id, wa.kategorie_id, wk.name, wa.titel, wa.inhalt, wa.tags
        FROM wiki_artikel wa
        JOIN wiki_kategorie wk ON wk.id = wa.kategorie_id
        WHERE wa.ist_system = 0
        ORDER BY wk.sortierung, wk.name, wa.titel
    )")) {
        qCWarning(lcDb) << "wikiExportJson artikel:" << qArt.lastError().text();
        return false;
    }
    while (qArt.next()) {
        QJsonObject o;
        o["id"]             = qArt.value(0).toInt();
        o["kategorie_id"]   = qArt.value(1).toInt();
        o["kategorie_name"] = qArt.value(2).toString();
        o["titel"]          = qArt.value(3).toString();
        o["inhalt"]         = qArt.value(4).toString();
        o["tags"]           = qArt.value(5).toString();
        artikelArr.append(o);
    }

    // Bilder der exportierten Artikel
    QJsonArray bilderArr;
    QSqlQuery qBild(m_wikiDb);
    if (!qBild.exec(R"(
        SELECT wb.id, wb.artikel_id, wb.dateiname, wb.mime_typ, wb.blob_pfad, wb.beschreibung, wb.sortierung
        FROM wiki_bild wb
        JOIN wiki_artikel wa ON wa.id = wb.artikel_id
        WHERE wa.ist_system = 0
        ORDER BY wb.artikel_id, wb.sortierung, wb.id
    )")) {
        qCWarning(lcDb) << "wikiExportJson bilder:" << qBild.lastError().text();
        return false;
    }
    while (qBild.next()) {
        const QString fn = qBild.value(4).toString();
        QFile bf(m_wikiBlobDir + "/" + fn);
        if (!bf.open(QIODevice::ReadOnly)) continue;
        QJsonObject o;
        o["id"]           = qBild.value(0).toInt();
        o["artikel_id"]   = qBild.value(1).toInt();
        o["dateiname"]    = qBild.value(2).toString();
        o["mime_typ"]     = qBild.value(3).toString();
        o["daten_base64"] = QString::fromLatin1(bf.readAll().toBase64());
        o["beschreibung"] = qBild.value(5).toString();
        o["sortierung"]   = qBild.value(6).toInt();
        bilderArr.append(o);
    }

    QJsonObject root;
    root["wiki_export_version"] = 1;
    root["exportiert_am"]       = QDateTime::currentDateTime().toString(Qt::ISODate);
    root["kategorien"]          = kategorienArr;
    root["artikel"]             = artikelArr;
    root["bilder"]              = bilderArr;

    QFile f(localPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qCWarning(lcDb) << "wikiExportJson: Datei nicht schreibbar:" << localPfad;
        return false;
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    qCInfo(lcDb) << "Wiki exportiert:" << localPfad << "-" << artikelArr.size() << "Artikel";
    return true;
}

bool Database::wikiImportJson(const QString &pfad, bool mergeMode)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QFile f(localPfad);
    if (!f.open(QIODevice::ReadOnly)) {
        qCWarning(lcDb) << "wikiImportJson: Datei nicht lesbar:" << localPfad;
        return false;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (doc.isNull()) {
        qCWarning(lcDb) << "wikiImportJson: JSON-Fehler:" << err.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root["wiki_export_version"].toInt() != 1) {
        qCWarning(lcDb) << "wikiImportJson: Unbekannte Export-Version:" << root["wiki_export_version"].toInt();
        return false;
    }

    if (!m_wikiDb.transaction()) {
        qCWarning(lcDb) << "wikiImportJson: Transaktion fehlgeschlagen";
        return false;
    }

    // Replace-Modus: alle Nutzer-Artikel löschen (Bilder cascaden automatisch)
    if (!mergeMode) {
        wikiBlobDateienAlleNutzerArtikelLoeschen();
        QSqlQuery del(m_wikiDb);
        if (!del.exec("DELETE FROM wiki_artikel WHERE ist_system = 0")) {
            qCWarning(lcDb) << "wikiImportJson replace:" << del.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    // Kategorien: vorhandene nach Name finden oder neu anlegen; old-ID → new-ID Map
    QMap<int, int> katIdMap;
    const QJsonArray katArr = root["kategorien"].toArray();
    for (const QJsonValue &v : katArr) {
        const QJsonObject o = v.toObject();
        const int    oldId  = o["id"].toInt();
        const QString name  = o["name"].toString();

        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        find.bindValue(":n", name);
        if (find.exec() && find.next()) {
            katIdMap[oldId] = find.value(0).toInt();
        } else {
            QSqlQuery ins(m_wikiDb);
            ins.prepare("INSERT INTO wiki_kategorie (name, beschreibung, sortierung) VALUES (:n, :b, :s)");
            ins.bindValue(":n", name);
            ins.bindValue(":b", o["beschreibung"].toString());
            ins.bindValue(":s", o["sortierung"].toInt());
            if (!ins.exec()) {
                qCWarning(lcDb) << "wikiImportJson Kategorie anlegen:" << ins.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
            katIdMap[oldId] = ins.lastInsertId().toInt();
        }
    }

    // Artikel einfügen; old-Art-ID → new-Art-ID Map für Bild-Zuordnung
    QMap<int, int> artIdMap;
    const QJsonArray artArr = root["artikel"].toArray();
    for (const QJsonValue &v : artArr) {
        const QJsonObject o   = v.toObject();
        const int oldArtId    = o["id"].toInt();
        const int oldKatId    = o["kategorie_id"].toInt();
        const QString katName = o["kategorie_name"].toString();

        int newKatId = katIdMap.value(oldKatId, -1);
        if (newKatId < 0) {
            // Kategorie nicht im Export enthalten – nach Name suchen
            QSqlQuery find(m_wikiDb);
            find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
            find.bindValue(":n", katName);
            if (find.exec() && find.next()) {
                newKatId = find.value(0).toInt();
                katIdMap[oldKatId] = newKatId;
            } else {
                QSqlQuery ins(m_wikiDb);
                ins.prepare("INSERT INTO wiki_kategorie (name) VALUES (:n)");
                ins.bindValue(":n", katName);
                if (!ins.exec()) { m_wikiDb.rollback(); return false; }
                newKatId = ins.lastInsertId().toInt();
                katIdMap[oldKatId] = newKatId;
            }
        }

        QSqlQuery ins(m_wikiDb);
        ins.prepare(R"(
            INSERT INTO wiki_artikel (kategorie_id, titel, inhalt, tags, ist_system)
            VALUES (:kid, :t, :i, :tags, 0)
        )");
        ins.bindValue(":kid",  newKatId);
        ins.bindValue(":t",    o["titel"].toString());
        ins.bindValue(":i",    o["inhalt"].toString());
        ins.bindValue(":tags", o["tags"].toString());
        if (!ins.exec()) {
            qCWarning(lcDb) << "wikiImportJson Artikel einfügen:" << ins.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
        artIdMap[oldArtId] = ins.lastInsertId().toInt();
    }

    // Bilder einfügen
    const QJsonArray bildArr = root["bilder"].toArray();
    for (const QJsonValue &v : bildArr) {
        const QJsonObject o = v.toObject();
        const int newArtId  = artIdMap.value(o["artikel_id"].toInt(), -1);
        if (newArtId < 0) continue;

        const QString mime  = o["mime_typ"].toString();
        const QString ext   = mime.contains("png") ? ".png" : ".jpg";
        QSqlQuery ins(m_wikiDb);
        ins.prepare(R"(
            INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, blob_pfad, beschreibung, sortierung)
            VALUES (:aid, :fn, :mime, '', :beschr, :sort)
        )");
        ins.bindValue(":aid",   newArtId);
        ins.bindValue(":fn",    o["dateiname"].toString());
        ins.bindValue(":mime",  mime);
        ins.bindValue(":beschr", o["beschreibung"].toString());
        ins.bindValue(":sort",  o["sortierung"].toInt());
        if (!ins.exec()) {
            qCWarning(lcDb) << "wikiImportJson Bild einfügen:" << ins.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
        const int newBildId = ins.lastInsertId().toInt();
        const QString fn    = QString::number(newBildId) + ext;
        QFile bf(m_wikiBlobDir + "/" + fn);
        if (bf.open(QIODevice::WriteOnly)) {
            bf.write(QByteArray::fromBase64(o["daten_base64"].toString().toLatin1()));
            QSqlQuery upd(m_wikiDb);
            upd.prepare("UPDATE wiki_bild SET blob_pfad = :p WHERE id = :id");
            upd.bindValue(":p",  fn);
            upd.bindValue(":id", newBildId);
            upd.exec();
        } else {
            qCWarning(lcDb) << "wikiImportJson: Bilddatei nicht schreibbar:" << fn;
        }
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        qCWarning(lcDb) << "wikiImportJson commit:" << m_wikiDb.lastError().text();
        return false;
    }
    qCInfo(lcDb) << "Wiki importiert:" << artArr.size() << "Artikel"
            << (mergeMode ? "(Merge)" : "(Replace)");
    return true;
}

// ============================================================
// wikiBundleAnwenden
// Spielt ein Bundle (Datei oder Qt-Ressource) ein.
// Gibt {erfolg, neu, aktualisiert, uebersprungen, meldung} zurück.
// ============================================================
QVariantMap Database::wikiBundleAnwenden(const QString &pfad)
{
    QVariantMap result;
    result["erfolg"]        = false;
    result["neu"]           = 0;
    result["aktualisiert"]  = 0;
    result["uebersprungen"] = 0;
    result["meldung"]       = QString();

    // Pfad normalisieren: file:// → lokaler Pfad; qrc:/ → :/
    QString localPfad = pfad;
    if (QUrl(pfad).isLocalFile())
        localPfad = QUrl(pfad).toLocalFile();
    else if (localPfad.startsWith("qrc:/"))
        localPfad = localPfad.mid(3);

    QFile f(localPfad);
    if (!f.open(QIODevice::ReadOnly)) {
        result["meldung"] = QString("Datei nicht lesbar: %1").arg(localPfad);
        qCWarning(lcDb) << "wikiBundleAnwenden:" << result["meldung"].toString();
        return result;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (doc.isNull()) {
        result["meldung"] = QString("JSON-Fehler: %1").arg(err.errorString());
        qCWarning(lcDb) << "wikiBundleAnwenden:" << result["meldung"].toString();
        return result;
    }
    const QJsonObject root = doc.object();
    if (root["wiki_export_version"].toInt() != 1) {
        result["meldung"] = QString("Unbekannte Export-Version: %1").arg(root["wiki_export_version"].toInt());
        return result;
    }
    const QString kennung       = root["bundle_kennung"].toString();
    const int     bundleVersion = root["bundle_version"].toInt();
    if (kennung.isEmpty()) {
        result["meldung"] = "Bundle hat keine Kennung (bundle_kennung fehlt) – nutze Wiki-Import statt Bundle-Import";
        return result;
    }

    // Versionsprüfung gegen wiki_meta
    {
        QSqlQuery vq(m_wikiDb);
        vq.prepare("SELECT wert FROM wiki_meta WHERE schluessel = :s");
        vq.bindValue(":s", "bundle_version_" + kennung);
        if (vq.exec() && vq.next()) {
            const int gespeichert = vq.value(0).toString().toInt();
            if (bundleVersion <= gespeichert) {
                result["erfolg"]  = true;
                result["meldung"] = QString("Bereits aktuell (v%1)").arg(gespeichert);
                return result;
            }
        }
    }

    if (!m_wikiDb.transaction()) {
        result["meldung"] = "Transaktion fehlgeschlagen";
        return result;
    }

    int neuCount = 0, aktCount = 0, skipCount = 0;

    // Kategorien: nach Name finden oder neu anlegen
    QMap<int, int> katIdMap;
    for (const QJsonValue &v : root["kategorien"].toArray()) {
        const QJsonObject o  = v.toObject();
        const int    oldId   = o["id"].toInt();
        const QString name   = o["name"].toString();
        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        find.bindValue(":n", name);
        if (find.exec() && find.next()) {
            katIdMap[oldId] = find.value(0).toInt();
        } else {
            QSqlQuery ins(m_wikiDb);
            ins.prepare("INSERT INTO wiki_kategorie (name, beschreibung, sortierung) VALUES (:n, :b, :s)");
            ins.bindValue(":n", name);
            ins.bindValue(":b", o["beschreibung"].toString());
            ins.bindValue(":s", o["sortierung"].toInt());
            if (!ins.exec()) {
                m_wikiDb.rollback();
                result["meldung"] = "Kategorie anlegen: " + ins.lastError().text();
                return result;
            }
            katIdMap[oldId] = ins.lastInsertId().toInt();
        }
    }

    // Bilder nach bundle-lokaler Artikel-ID gruppieren
    QMap<int, QList<QJsonObject>> bilderNachArtId;
    for (const QJsonValue &v : root["bilder"].toArray())
        bilderNachArtId[v.toObject()["artikel_id"].toInt()].append(v.toObject());

    // Artikel einfügen / aktualisieren / überspringen
    for (const QJsonValue &v : root["artikel"].toArray()) {
        const QJsonObject o   = v.toObject();
        const int  oldArtId   = o["id"].toInt();
        const int  oldKatId   = o["kategorie_id"].toInt();
        const QString katName = o["kategorie_name"].toString();
        const QString titel   = o["titel"].toString();
        const QString inhalt  = o["inhalt"].toString();
        const QString tags    = o["tags"].toString();

        // Kategorie-ID auflösen (Fallback über Name)
        int newKatId = katIdMap.value(oldKatId, -1);
        if (newKatId < 0) {
            QSqlQuery find(m_wikiDb);
            find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
            find.bindValue(":n", katName);
            if (find.exec() && find.next()) {
                newKatId = find.value(0).toInt();
                katIdMap[oldKatId] = newKatId;
            } else {
                QSqlQuery ins(m_wikiDb);
                ins.prepare("INSERT INTO wiki_kategorie (name) VALUES (:n)");
                ins.bindValue(":n", katName);
                if (!ins.exec()) { m_wikiDb.rollback(); result["meldung"] = "Kategorie (Fallback): " + ins.lastError().text(); return result; }
                newKatId = ins.lastInsertId().toInt();
                katIdMap[oldKatId] = newKatId;
            }
        }

        // Vorhandenen Artikel suchen
        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id, von_nutzer_geaendert FROM wiki_artikel WHERE bundle_kennung = :bk AND titel = :t");
        find.bindValue(":bk", kennung);
        find.bindValue(":t",  titel);

        auto _bilderEinfuegen = [&](int artDbId, const QString &inhaltVorlage) -> QString {
            QMap<int, int> bildIdMap;
            for (const QJsonObject &b : bilderNachArtId.value(oldArtId)) {
                const QString mime = b["mime_typ"].toString();
                const QString ext  = mime.contains("png") ? ".png" : ".jpg";
                QSqlQuery bIns(m_wikiDb);
                bIns.prepare(R"(
                    INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, blob_pfad, beschreibung, sortierung)
                    VALUES (:aid, :fn, :mime, '', :beschr, :sort)
                )");
                bIns.bindValue(":aid",   artDbId);
                bIns.bindValue(":fn",    b["dateiname"].toString());
                bIns.bindValue(":mime",  mime);
                bIns.bindValue(":beschr", b["beschreibung"].toString());
                bIns.bindValue(":sort",  b["sortierung"].toInt());
                if (!bIns.exec()) continue;
                const int newBildId = bIns.lastInsertId().toInt();
                bildIdMap[b["id"].toInt()] = newBildId;
                const QString fn = QString::number(newBildId) + ext;
                QFile bf(m_wikiBlobDir + "/" + fn);
                if (bf.open(QIODevice::WriteOnly)) {
                    bf.write(QByteArray::fromBase64(b["daten_base64"].toString().toLatin1()));
                    QSqlQuery upd(m_wikiDb);
                    upd.prepare("UPDATE wiki_bild SET blob_pfad = :p WHERE id = :id");
                    upd.bindValue(":p",  fn);
                    upd.bindValue(":id", newBildId);
                    upd.exec();
                }
            }
            // wiki://bild/{bundle-lokal} → wiki://bild/{db-id}
            QString inhaltRemap = inhaltVorlage;
            for (auto it = bildIdMap.cbegin(); it != bildIdMap.cend(); ++it)
                inhaltRemap.replace(
                    QString("wiki://bild/%1").arg(it.key()),
                    QString("wiki://bild/%1").arg(it.value())
                );
            return inhaltRemap;
        };

        if (find.exec() && find.next()) {
            const int existingId          = find.value(0).toInt();
            const int vonNutzerGeaendert  = find.value(1).toInt();
            if (vonNutzerGeaendert == 1) {
                skipCount++;
            } else {
                // Bilder löschen – zuerst Dateien, dann DB-Zeilen
                wikiBlobDateienLoeschenFuerArtikel(existingId);
                QSqlQuery delBilder(m_wikiDb);
                delBilder.prepare("DELETE FROM wiki_bild WHERE artikel_id = :aid");
                delBilder.bindValue(":aid", existingId);
                delBilder.exec();

                const QString inhaltRemap = _bilderEinfuegen(existingId, inhalt);
                QSqlQuery upd(m_wikiDb);
                upd.prepare(R"(
                    UPDATE wiki_artikel
                    SET titel = :t, inhalt = :i, tags = :tags,
                        kategorie_id = :kid, geaendert_am = datetime('now')
                    WHERE id = :id
                )");
                upd.bindValue(":t",   titel);
                upd.bindValue(":i",   inhaltRemap);
                upd.bindValue(":tags", tags);
                upd.bindValue(":kid", newKatId);
                upd.bindValue(":id",  existingId);
                if (!upd.exec()) {
                    m_wikiDb.rollback();
                    result["meldung"] = "UPDATE: " + upd.lastError().text();
                    return result;
                }
                // Inhalt mit remappten IDs zurückschreiben
                if (inhaltRemap != inhalt) {
                    QSqlQuery updInhalt(m_wikiDb);
                    updInhalt.prepare("UPDATE wiki_artikel SET inhalt = :i WHERE id = :id");
                    updInhalt.bindValue(":i",  inhaltRemap);
                    updInhalt.bindValue(":id", existingId);
                    updInhalt.exec();
                }
                aktCount++;
            }
        } else {
            // Neu anlegen
            QSqlQuery ins(m_wikiDb);
            ins.prepare(R"(
                INSERT INTO wiki_artikel (kategorie_id, titel, inhalt, tags, bundle_kennung, ist_system)
                VALUES (:kid, :t, :i, :tags, :bk, 0)
            )");
            ins.bindValue(":kid",  newKatId);
            ins.bindValue(":t",    titel);
            ins.bindValue(":i",    inhalt);
            ins.bindValue(":tags", tags);
            ins.bindValue(":bk",   kennung);
            if (!ins.exec()) {
                m_wikiDb.rollback();
                result["meldung"] = "INSERT: " + ins.lastError().text();
                return result;
            }
            const int newArtId    = ins.lastInsertId().toInt();
            const QString inhaltRemap = _bilderEinfuegen(newArtId, inhalt);
            if (inhaltRemap != inhalt) {
                QSqlQuery updInhalt(m_wikiDb);
                updInhalt.prepare("UPDATE wiki_artikel SET inhalt = :i WHERE id = :id");
                updInhalt.bindValue(":i",  inhaltRemap);
                updInhalt.bindValue(":id", newArtId);
                updInhalt.exec();
            }
            neuCount++;
        }
    }

    // Bundle-Version speichern
    {
        QSqlQuery upsert(m_wikiDb);
        upsert.prepare("INSERT OR REPLACE INTO wiki_meta (schluessel, wert) VALUES (:s, :v)");
        upsert.bindValue(":s", "bundle_version_" + kennung);
        upsert.bindValue(":v", QString::number(bundleVersion));
        upsert.exec();
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        result["meldung"] = "Commit fehlgeschlagen";
        return result;
    }

    result["erfolg"]        = true;
    result["neu"]           = neuCount;
    result["aktualisiert"]  = aktCount;
    result["uebersprungen"] = skipCount;
    result["meldung"]       = QString("%1 neu, %2 aktualisiert, %3 übersprungen")
                                .arg(neuCount).arg(aktCount).arg(skipCount);
    qCInfo(lcDb) << "wikiBundleAnwenden" << kennung << "v" << bundleVersion << "–" << result["meldung"].toString();
    return result;
}

// ============================================================
// wikiBundleExportieren
// ============================================================
bool Database::wikiBundleExportieren(const QString &pfad, const QString &kennung,
                                      const QString &titel, int version,
                                      const QVariantList &kategorieIds)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QSet<int> katIdSet;
    for (const QVariant &v : kategorieIds)
        katIdSet.insert(v.toInt());

    // Kategorien
    QJsonArray kategorienArr;
    QSqlQuery qKat(m_wikiDb);
    if (!qKat.exec("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name"))
        return false;
    while (qKat.next()) {
        if (!katIdSet.contains(qKat.value(0).toInt())) continue;
        QJsonObject o;
        o["id"]           = qKat.value(0).toInt();
        o["name"]         = qKat.value(1).toString();
        o["beschreibung"] = qKat.value(2).toString();
        o["sortierung"]   = qKat.value(3).toInt();
        kategorienArr.append(o);
    }

    // Artikel (keine ist_system=1)
    QJsonArray artikelArr;
    QSet<int> exportArtIds;
    QSqlQuery qArt(m_wikiDb);
    if (!qArt.exec(R"(
        SELECT wa.id, wa.kategorie_id, wk.name, wa.titel, wa.inhalt, wa.tags
        FROM wiki_artikel wa JOIN wiki_kategorie wk ON wk.id = wa.kategorie_id
        WHERE wa.ist_system = 0
        ORDER BY wk.sortierung, wk.name, wa.titel
    )")) return false;
    while (qArt.next()) {
        if (!katIdSet.contains(qArt.value(1).toInt())) continue;
        QJsonObject o;
        o["id"]             = qArt.value(0).toInt();
        o["kategorie_id"]   = qArt.value(1).toInt();
        o["kategorie_name"] = qArt.value(2).toString();
        o["titel"]          = qArt.value(3).toString();
        o["inhalt"]         = qArt.value(4).toString();
        o["tags"]           = qArt.value(5).toString();
        artikelArr.append(o);
        exportArtIds.insert(qArt.value(0).toInt());
    }

    // Bilder der exportierten Artikel
    QJsonArray bilderArr;
    QSqlQuery qBild(m_wikiDb);
    if (!qBild.exec(R"(
        SELECT wb.id, wb.artikel_id, wb.dateiname, wb.mime_typ, wb.blob_pfad, wb.beschreibung, wb.sortierung
        FROM wiki_bild wb JOIN wiki_artikel wa ON wa.id = wb.artikel_id
        WHERE wa.ist_system = 0
        ORDER BY wb.artikel_id, wb.sortierung, wb.id
    )")) return false;
    while (qBild.next()) {
        if (!exportArtIds.contains(qBild.value(1).toInt())) continue;
        const QString fn = qBild.value(4).toString();
        QFile bf(m_wikiBlobDir + "/" + fn);
        if (!bf.open(QIODevice::ReadOnly)) continue;
        QJsonObject o;
        o["id"]           = qBild.value(0).toInt();
        o["artikel_id"]   = qBild.value(1).toInt();
        o["dateiname"]    = qBild.value(2).toString();
        o["mime_typ"]     = qBild.value(3).toString();
        o["daten_base64"] = QString::fromLatin1(bf.readAll().toBase64());
        o["beschreibung"] = qBild.value(5).toString();
        o["sortierung"]   = qBild.value(6).toInt();
        bilderArr.append(o);
    }

    QJsonObject rootObj;
    rootObj["wiki_export_version"] = 1;
    rootObj["bundle_kennung"]      = kennung;
    rootObj["bundle_version"]      = version;
    rootObj["bundle_titel"]        = titel;
    rootObj["exportiert_am"]       = QDateTime::currentDateTime().toString(Qt::ISODate);
    rootObj["kategorien"]          = kategorienArr;
    rootObj["artikel"]             = artikelArr;
    rootObj["bilder"]              = bilderArr;

    QFile f(localPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qCWarning(lcDb) << "wikiBundleExportieren: nicht schreibbar:" << localPfad;
        return false;
    }
    f.write(QJsonDocument(rootObj).toJson());
    qCInfo(lcDb) << "wikiBundleExportieren:" << kennung << "v" << version
            << artikelArr.size() << "Artikel, Pfad:" << localPfad;
    return true;
}

// ============================================================
// wikiBundleArtikelZuruecksetzen / wikiBundleAktiveListe
// ============================================================
bool Database::wikiBundleArtikelZuruecksetzen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_artikel SET von_nutzer_geaendert = 0 WHERE id = :id AND bundle_kennung IS NOT NULL");
    q.bindValue(":id", id);
    return q.exec();
}

QVariantList Database::wikiBundleAktiveListe()
{
    QSqlQuery q(m_wikiDb);
    q.exec("SELECT schluessel, wert FROM wiki_meta WHERE schluessel LIKE 'bundle_version_%' ORDER BY schluessel");
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m["kennung"] = q.value(0).toString().mid(QString("bundle_version_").length());
        m["version"] = q.value(1).toString().toInt();
        result << m;
    }
    return result;
}

// ============================================================
// seedWikiStarterInhalte
// Liest src/wiki_seed/manifest.json + .md-Dateien aus QRC-Ressourcen.
// Kategorien/Artikel werden angelegt bzw. für ist_system=true aktualisiert.
// ============================================================
bool Database::seedWikiStarterInhalte()
{
    // Manifest laden
    QFile mf(":/wiki_seed/manifest.json");
    if (!mf.open(QIODevice::ReadOnly)) {
        qCWarning(lcDb) << "seedWikiStarterInhalte: manifest.json nicht gefunden";
        return false;
    }
    QJsonParseError parseErr;
    const QJsonDocument doc = QJsonDocument::fromJson(mf.readAll(), &parseErr);
    if (doc.isNull()) {
        qCWarning(lcDb) << "seedWikiStarterInhalte: JSON-Fehler:" << parseErr.errorString();
        return false;
    }

    QSqlQuery qKat(m_wikiDb);
    qKat.prepare("INSERT OR IGNORE INTO wiki_kategorie (name, beschreibung, sortierung) VALUES (:name, :beschr, :sort)");
    QSqlQuery qArtIns(m_wikiDb);
    qArtIns.prepare(R"(
        INSERT OR IGNORE INTO wiki_artikel (kategorie_id, titel, inhalt, tags, ist_system)
        SELECT :kid, :titel, :inhalt, :tags, :sys
        WHERE NOT EXISTS (
            SELECT 1 FROM wiki_artikel WHERE kategorie_id = :kid2 AND titel = :titel2
        )
    )");
    QSqlQuery qArtUpd(m_wikiDb);
    qArtUpd.prepare(R"(
        UPDATE wiki_artikel SET inhalt = :inhalt, tags = :tags
        WHERE kategorie_id = :kid AND titel = :titel AND ist_system = 1
    )");

    for (const QJsonValue &katVal : doc["kategorien"].toArray()) {
        const QJsonObject kat     = katVal.toObject();
        const QString     katName = kat["name"].toString();
        const bool        istSys  = kat["ist_system"].toBool();

        qKat.bindValue(":name",  katName);
        qKat.bindValue(":beschr", kat["beschreibung"].toString());
        qKat.bindValue(":sort",  kat["sortierung"].toInt());
        if (!qKat.exec()) {
            qCWarning(lcDb) << "seedWikiStarterInhalte Kategorie:" << qKat.lastError().text();
            return false;
        }

        QSqlQuery qKatId(m_wikiDb);
        qKatId.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        qKatId.bindValue(":n", katName);
        qKatId.exec();
        if (!qKatId.next()) continue;
        const int katId = qKatId.value(0).toInt();

        for (const QJsonValue &artVal : kat["artikel"].toArray()) {
            const QJsonObject art   = artVal.toObject();
            const QString     titel = art["titel"].toString();
            const QString     tags  = art["tags"].toString();
            const QString     datei = art["datei"].toString();

            QString inhalt;
            if (!datei.isEmpty()) {
                QFile f(":/wiki_seed/" + datei);
                if (f.open(QIODevice::ReadOnly))
                    inhalt = QString::fromUtf8(f.readAll());
                else
                    qCWarning(lcDb) << "seedWikiStarterInhalte: Datei nicht gefunden:" << datei;
            }

            qArtIns.bindValue(":kid",    katId);
            qArtIns.bindValue(":kid2",   katId);
            qArtIns.bindValue(":titel",  titel);
            qArtIns.bindValue(":titel2", titel);
            qArtIns.bindValue(":inhalt", inhalt);
            qArtIns.bindValue(":tags",   tags);
            qArtIns.bindValue(":sys",    istSys ? 1 : 0);
            if (!qArtIns.exec()) {
                qCWarning(lcDb) << "seedWikiStarterInhalte Artikel insert:" << qArtIns.lastError().text();
                return false;
            }
            if (istSys) {
                qArtUpd.bindValue(":kid",    katId);
                qArtUpd.bindValue(":titel",  titel);
                qArtUpd.bindValue(":inhalt", inhalt);
                qArtUpd.bindValue(":tags",   tags);
                if (!qArtUpd.exec()) {
                    qCWarning(lcDb) << "seedWikiStarterInhalte Artikel update:" << qArtUpd.lastError().text();
                    return false;
                }
            }

            // Bild einsäen (einmalig, nur wenn kein Bild vorhanden)
            const QString bildQrc = art["bild_qrc"].toString();
            const QString bildFn  = art["bild_dateiname"].toString();
            if (bildQrc.isEmpty() || bildFn.isEmpty()) continue;

            QSqlQuery qId(m_wikiDb);
            qId.prepare("SELECT id FROM wiki_artikel WHERE kategorie_id = :kid AND titel = :t");
            qId.bindValue(":kid", katId);
            qId.bindValue(":t",   titel);
            if (!qId.exec() || !qId.next()) continue;
            const int artId = qId.value(0).toInt();

            QSqlQuery qCount(m_wikiDb);
            qCount.prepare("SELECT COUNT(*) FROM wiki_bild WHERE artikel_id = :aid");
            qCount.bindValue(":aid", artId);
            if (!qCount.exec() || !qCount.next() || qCount.value(0).toInt() > 0) continue;

            QFile bf(bildQrc);
            if (!bf.open(QIODevice::ReadOnly)) {
                qCWarning(lcDb) << "seedWikiStarterInhalte: Bild nicht gefunden:" << bildQrc;
                continue;
            }
            const QByteArray daten = bf.readAll();
            bf.close();
            if (daten.isEmpty()) continue;

            const QString ext = bildFn.endsWith(".png") ? ".png" : ".jpg";
            QSqlQuery qIns(m_wikiDb);
            qIns.prepare(R"(
                INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, blob_pfad, sortierung)
                VALUES (:aid, :fn, 'image/png', '', 1)
            )");
            qIns.bindValue(":aid", artId);
            qIns.bindValue(":fn",  bildFn);
            if (!qIns.exec()) {
                qCWarning(lcDb) << "seedWikiStarterInhalte Bild INSERT:" << qIns.lastError().text();
                continue;
            }
            const int newId = qIns.lastInsertId().toInt();
            const QString fn = QString::number(newId) + ext;
            QFile out(m_wikiBlobDir + "/" + fn);
            if (out.open(QIODevice::WriteOnly)) {
                out.write(daten);
                QSqlQuery upd(m_wikiDb);
                upd.prepare("UPDATE wiki_bild SET blob_pfad = :p WHERE id = :id");
                upd.bindValue(":p",  fn);
                upd.bindValue(":id", newId);
                upd.exec();
            }
        }
    }

    return true;
}
// ============================================================
// SPS/PLS-Integration
// ============================================================

// --- Rack ---

