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
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
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


Database::Database(QObject *parent)
    : QObject(parent)
{
}

bool Database::open(const QString &path)
{
    return openProjekt(path);
}

void Database::close()
{
    m_db.close();
    if (m_wikiDb.isValid())    m_wikiDb.close();
    if (m_makroDb.isValid())   m_makroDb.close();
    if (m_launcherDb.isValid()) m_launcherDb.close();
}

// ============================================================
// openLauncher
// Öffnet oder legt die Launcher-DB an (stroemling.db).
// Diese Datei enthält nur die zuletzt_geoeffnet-Tabelle –
// keine Projektdaten.
// ============================================================
bool Database::openLauncher(const QString &path)
{
    // Ausstehende Wiederherstellung aus komplettarchivImportieren() anwenden.
    // DBs sind zu diesem Zeitpunkt noch nicht geöffnet – sicheres Überschreiben möglich.
    QString pendingDir = QFileInfo(path).absolutePath() + "/_pendingrestore";
    if (QDir(pendingDir).exists()) {
        QString dataDir = QFileInfo(path).absolutePath();
        for (const QString &dateiname : {"makros.db", "wiki.db"}) {
            QString src = pendingDir + "/" + dateiname;
            if (QFile::exists(src)) {
                QFile::remove(dataDir + "/" + dateiname);
                QFile::rename(src, dataDir + "/" + dateiname);
            }
        }
        // wiki_blobs/ übertragen
        QString blobsSrc = pendingDir + "/wiki_blobs";
        if (QDir(blobsSrc).exists()) {
            QString blobsDst = dataDir + "/wiki_blobs";
            QDir().mkpath(blobsDst);
            QDirIterator it(blobsSrc, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                it.next();
                QString rel = QDir(blobsSrc).relativeFilePath(it.filePath());
                QString dst = blobsDst + "/" + rel;
                QDir().mkpath(QFileInfo(dst).absolutePath());
                QFile::remove(dst);
                QFile::rename(it.filePath(), dst);
            }
        }
        QDir(pendingDir).removeRecursively();
        qCInfo(lcDb) << "BACKUP-01: Ausstehende Wiederherstellung angewendet aus" << pendingDir;
    }

    m_launcherDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_launcher");
    m_launcherDb.setDatabaseName(path);
    if (!m_launcherDb.open()) {
        qCWarning(lcDb) << "Launcher-DB konnte nicht geöffnet werden:" << m_launcherDb.lastError().text();
        return false;
    }
    {
        QSqlQuery q(m_launcherDb);
        q.exec("PRAGMA journal_mode = WAL");
        if (!q.exec(R"(
            CREATE TABLE IF NOT EXISTS zuletzt_geoeffnet (
                id           INTEGER PRIMARY KEY,
                pfad         TEXT NOT NULL UNIQUE,
                name         TEXT NOT NULL DEFAULT '',
                geoeffnet_am TEXT NOT NULL DEFAULT (datetime('now'))
            )
        )")) {
            qCWarning(lcDb) << "zuletzt_geoeffnet Tabelle:" << q.lastError().text();
        }
        // Achievement-Tabellen (global, nicht projektspezifisch)
        q.exec(R"(CREATE TABLE IF NOT EXISTS achievement_errungen (
            id                  TEXT    PRIMARY KEY,
            freigeschaltet_am   INTEGER NOT NULL
        ))");
        q.exec(R"(CREATE TABLE IF NOT EXISTS achievement_zaehler (
            schluessel  TEXT    PRIMARY KEY,
            wert        INTEGER NOT NULL DEFAULT 0
        ))");

        if (!q.exec(R"(
            CREATE TABLE IF NOT EXISTS bekannte_projekte (
                id                INTEGER PRIMARY KEY,
                datei_pfad        TEXT NOT NULL UNIQUE,
                projekt_name      TEXT,
                projekt_nummer    TEXT,
                erstellt          TEXT NOT NULL DEFAULT (date('now')),
                zuletzt_geoeffnet TEXT NOT NULL DEFAULT (datetime('now'))
            )
        )")) {
            qCWarning(lcDb) << "bekannte_projekte Tabelle:" << q.lastError().text();
        }
    }
    qCInfo(lcDb) << "Launcher-DB geöffnet:" << path;
    return true;
}

// ============================================================
// openProjekt
// Öffnet eine existierende .stroemling-Projektdatei und führt
// ggf. ausstehende Migrationen aus.
// ============================================================
bool Database::openProjekt(const QString &path)
{
    const QString localPath = QUrl(path).isLocalFile() ? QUrl(path).toLocalFile() : path;

    // Bestehende Projektverbindung trennen
    if (m_projektOffen || m_db.isOpen()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        m_projektOffen = false;
        emit projektOffenChanged();  // QML bekommt false → räumt Canvas/Tabs/SeiteId auf
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(localPath);
    if (!m_db.open()) {
        qCWarning(lcDb) << "Projekt konnte nicht geöffnet werden:" << m_db.lastError().text();
        emit projektOffenChanged();
        return false;
    }
    {
        QSqlQuery pragma;
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA busy_timeout = 5000");
        pragma.exec("PRAGMA journal_mode = WAL");
    }

    if (!checkAndApplySchema()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        emit projektOffenChanged();
        return false;
    }

    m_projektOffen = true;

    QString projektName;
    QString projektNummer;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT name, projektnummer FROM projekt ORDER BY id DESC LIMIT 1") && q.next()) {
            projektName   = q.value(0).toString();
            projektNummer = q.value(1).toString();
        }
    }
    if (projektName.isEmpty())
        projektName = QFileInfo(localPath).baseName();

    zuletzGeoeffnetEintragen(localPath, projektName);
    bekannteProjecteEintragen(localPath, projektName, projektNummer);
    qCInfo(lcDb) << "Projekt geöffnet:" << localPath;
    emit projektOffenChanged();
    return true;
}

// ============================================================
// createProjekt
// Legt eine neue leere Projektdatei an (ohne Beispieldaten).
// ============================================================
bool Database::createProjekt(const QString &path, const QString &projektName)
{
    const QString localPath = QUrl(path).isLocalFile() ? QUrl(path).toLocalFile() : path;

    // Elternverzeichnis anlegen (für Ordner-pro-Projekt-Struktur: ~/Projekte/Name/projekt.strl)
    QDir().mkpath(QFileInfo(localPath).absolutePath());

    if (QFile::exists(localPath)) {
        qCWarning(lcDb) << "Projektdatei existiert bereits:" << localPath;
        return false;
    }

    // Bestehende Projektverbindung trennen
    if (m_projektOffen || m_db.isOpen()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        m_projektOffen = false;
        emit projektOffenChanged();  // QML bekommt false → räumt Canvas/Tabs/SeiteId auf
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(localPath);
    if (!m_db.open()) {
        qCWarning(lcDb) << "Projektdatei konnte nicht erstellt werden:" << m_db.lastError().text();
        return false;
    }
    {
        QSqlQuery pragma;
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA journal_mode = WAL");
    }

    // schema_migration-Tabelle anlegen (außerhalb der Transaktion)
    {
        QSqlQuery q(m_db);
        if (!q.exec("CREATE TABLE IF NOT EXISTS schema_migration ("
                    "version INTEGER PRIMARY KEY, beschreibung TEXT NOT NULL, "
                    "angewendet_am TEXT NOT NULL DEFAULT (datetime('now')))")) {
            qCWarning(lcDb) << "schema_migration für neues Projekt:" << q.lastError().text();
            m_db.close(); m_db = QSqlDatabase();
            QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
            QFile::remove(localPath);
            return false;
        }
    }

    if (!m_db.transaction()) {
        qCWarning(lcDb) << "Transaktion für neues Projekt fehlgeschlagen";
        m_db.close(); m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        QFile::remove(localPath);
        return false;
    }

    bool ok = createSchema()
           && seedSymbolKatalog()
           && seedBuiltinSymbolDefinitionen()
           && seedIbnFeldvorlagen()
           && seedStandardKlemmen();

    if (ok) {
        // Projektzeile mit Nutzernamen anlegen
        QSqlQuery qp;
        qp.prepare("INSERT INTO projekt (name) VALUES (:n)");
        // Bei Ordner-pro-Projekt-Struktur (projekt.strl) den Ordnernamen als Fallback nutzen
        QString fallbackName;
        if (QFileInfo(localPath).fileName() == QStringLiteral("projekt.strl"))
            fallbackName = QFileInfo(localPath).absoluteDir().dirName();
        else
            fallbackName = QFileInfo(localPath).baseName();
        qp.bindValue(":n", projektName.isEmpty() ? fallbackName : projektName);
        ok = qp.exec();
        if (!ok)
            qCWarning(lcDb) << "Projekt-Eintrag anlegen:" << qp.lastError().text();
    }

    if (ok) {
        // Aktuelle Schema-Version eintragen (alle Migrationen bis hier bereits in schema.sql)
        QSqlQuery qm;
        qm.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :d)");
        qm.bindValue(":v", CURRENT_SCHEMA_VERSION);
        qm.bindValue(":d", QString("Baseline v%1 – neues Projekt").arg(CURRENT_SCHEMA_VERSION));
        ok = qm.exec();
    }

    if (!ok || !m_db.commit()) {
        m_db.rollback();
        m_db.close(); m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        QFile::remove(localPath);
        return false;
    }

    m_projektOffen = true;
    QString name = projektName.isEmpty() ? QFileInfo(localPath).baseName() : projektName;
    zuletzGeoeffnetEintragen(localPath, name);
    bekannteProjecteEintragen(localPath, name, "");
    qCInfo(lcDb) << "Neues Projekt erstellt:" << localPath;
    emit projektOffenChanged();
    return true;
}

// ============================================================
// closeProjekt
// Schließt die aktuelle Projektdatei.
// ============================================================
void Database::closeProjekt()
{
    if (!m_projektOffen) return;
    m_db.close();
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
    m_projektOffen = false;
    qCInfo(lcDb) << "Projekt geschlossen.";
    emit projektOffenChanged();
}

bool Database::projektExportieren(const QString &destPfad)
{
    const QString localPfad = QUrl(destPfad).isLocalFile() ? QUrl(destPfad).toLocalFile() : destPfad;

    if (!m_projektOffen) {
        qCWarning(lcDb) << "projektExportieren: kein Projekt geöffnet";
        return false;
    }

    // VACUUM INTO schlägt fehl wenn die Zieldatei bereits existiert
    if (QFile::exists(localPfad) && !QFile::remove(localPfad)) {
        qCWarning(lcDb) << "projektExportieren: Zieldatei konnte nicht gelöscht werden:" << localPfad;
        return false;
    }

    QString escaped = localPfad;
    escaped.replace("'", "''");
    QSqlQuery q(m_db);
    if (!q.exec("VACUUM INTO '" + escaped + "'")) {
        qCWarning(lcDb) << "projektExportieren:" << q.lastError().text();
        return false;
    }
    qCInfo(lcDb) << "Projekt exportiert nach:" << localPfad;
    return true;
}

QString Database::projektPfad() const
{
    return m_db.isOpen() ? m_db.databaseName() : QString();
}

// ============================================================
// zuletzGeoeffnete
// Gibt die zuletzt geöffneten Projekte aus der Launcher-DB zurück.
// ============================================================
QVariantList Database::zuletzGeoeffnete() const
{
    QVariantList list;
    if (!m_launcherDb.isOpen()) return list;
    QSqlQuery q(m_launcherDb);
    if (!q.exec("SELECT pfad, name, geoeffnet_am FROM zuletzt_geoeffnet "
                "ORDER BY geoeffnet_am DESC LIMIT 10"))
        return list;
    while (q.next()) {
        QString pfad = q.value(0).toString();
        if (QFile::exists(pfad)) {
            list.append(QVariantMap{
                { "pfad",        pfad },
                { "name",        q.value(1).toString() },
                { "geoeffnetAm", q.value(2).toString() },
            });
        }
    }
    return list;
}

// ============================================================
// projektLoeschen
// Löscht die .stroemling-Datei vom Dateisystem und entfernt
// den Launcher-Eintrag aus zuletzt_geoeffnet.
// ============================================================
bool Database::projektLoeschen(const QString &pfad)
{
    if (QFile::exists(pfad)) {
        if (!QFile::remove(pfad)) {
            qCWarning(lcDb) << "projektLoeschen: Datei konnte nicht gelöscht werden:" << pfad;
            return false;
        }
    }
    if (m_launcherDb.isOpen()) {
        QSqlQuery q(m_launcherDb);
        q.prepare("DELETE FROM zuletzt_geoeffnet WHERE pfad = :p");
        q.bindValue(":p", pfad);
        q.exec();
        QSqlQuery q2(m_launcherDb);
        q2.prepare("DELETE FROM bekannte_projekte WHERE datei_pfad = :p");
        q2.bindValue(":p", pfad);
        q2.exec();
        emit registryGeaendert();
    }
    return true;
}

// ============================================================
// ersteProjektInfo
// Gibt alle Meta-Daten des ersten Projekts der geöffneten DB zurück.
// ============================================================
QVariantMap Database::ersteProjektInfo() const
{
    QVariantMap m;
    if (!m_projektOffen) return m;
    QSqlQuery q(m_db);
    if (q.exec("SELECT id, name, projektnummer, auftraggeber, auftragnehmer, bearbeiter "
               "FROM projekt ORDER BY id DESC LIMIT 1") && q.next()) {
        m["id"]            = q.value(0).toInt();
        m["name"]          = q.value(1).toString();
        m["projektnummer"] = q.value(2).toString();
        m["auftraggeber"]  = q.value(3).toString();
        m["auftragnehmer"] = q.value(4).toString();
        m["bearbeiter"]    = q.value(5).toString();
    }
    return m;
}

// ============================================================
// projektMetaDatenSpeichern
// ============================================================
bool Database::projektMetaDatenSpeichern(const QString &name,
                                          const QString &nummer,
                                          const QString &auftraggeber,
                                          const QString &auftragnehmer,
                                          const QString &bearbeiter)
{
    if (!m_projektOffen) return false;
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET name=:n, projektnummer=:nr, "
              "auftraggeber=:ag, auftragnehmer=:an, bearbeiter=:b, "
              "geaendert_am=datetime('now') "
              "WHERE id=(SELECT MAX(id) FROM projekt)");
    q.bindValue(":n",  name.trimmed());
    q.bindValue(":nr", nummer.trimmed());
    q.bindValue(":ag", auftraggeber.trimmed());
    q.bindValue(":an", auftragnehmer.trimmed());
    q.bindValue(":b",  bearbeiter.trimmed());
    if (!q.exec()) {
        qCWarning(lcDb) << "projektMetaDatenSpeichern:" << q.lastError().text();
        return false;
    }
    bekannteProjecteEintragen(m_db.databaseName(), name.trimmed(), nummer.trimmed());
    emit projektOffenChanged();
    return true;
}

// ============================================================
// zuletzGeoeffnetEintragen (privat)
// ============================================================
void Database::zuletzGeoeffnetEintragen(const QString &path, const QString &name)
{
    if (!m_launcherDb.isOpen()) return;
    QSqlQuery q(m_launcherDb);
    q.prepare(R"(
        INSERT INTO zuletzt_geoeffnet (pfad, name, geoeffnet_am)
        VALUES (:p, :n, datetime('now'))
        ON CONFLICT(pfad) DO UPDATE SET name = :n, geoeffnet_am = datetime('now')
    )");
    q.bindValue(":p", path);
    q.bindValue(":n", name);
    q.exec();
}

// ============================================================
// bekannteProjecteEintragen (privat)
// Trägt ein Projekt in bekannte_projekte ein oder aktualisiert es.
// ============================================================
void Database::bekannteProjecteEintragen(const QString &pfad, const QString &name, const QString &nummer)
{
    if (!m_launcherDb.isOpen()) return;
    QSqlQuery q(m_launcherDb);
    q.prepare(R"(
        INSERT INTO bekannte_projekte (datei_pfad, projekt_name, projekt_nummer, zuletzt_geoeffnet)
        VALUES (:p, :n, :nr, datetime('now'))
        ON CONFLICT(datei_pfad) DO UPDATE SET
            projekt_name      = :n,
            projekt_nummer    = :nr,
            zuletzt_geoeffnet = datetime('now')
    )");
    q.bindValue(":p",  pfad);
    q.bindValue(":n",  name);
    q.bindValue(":nr", nummer);
    if (!q.exec())
        qCWarning(lcDb) << "bekannteProjecteEintragen:" << q.lastError().text();
    emit registryGeaendert();
}

// ============================================================
// bekannteProjecteLaden
// Gibt alle bekannten Projekte aus der Launcher-Registry zurück.
// ============================================================
QVariantList Database::bekannteProjecteLaden() const
{
    QVariantList list;
    if (!m_launcherDb.isOpen()) return list;
    QSqlQuery q(m_launcherDb);
    if (!q.exec("SELECT datei_pfad, projekt_name, projekt_nummer, erstellt, zuletzt_geoeffnet "
                "FROM bekannte_projekte ORDER BY id DESC"))
        return list;
    while (q.next()) {
        QString pfad = q.value(0).toString();
        list.append(QVariantMap{
            { "dateiPfad",        pfad },
            { "projektName",      q.value(1).toString() },
            { "projektNummer",    q.value(2).toString() },
            { "erstellt",         q.value(3).toString() },
            { "zuletztGeoeffnet", q.value(4).toString() },
            { "dateiExistiert",   QFile::exists(pfad) },
        });
    }
    return list;
}

// ============================================================
// projektAusRegistryEntfernen
// Entfernt ein Projekt aus bekannte_projekte (löscht die Datei NICHT).
// ============================================================
bool Database::projektAusRegistryEntfernen(const QString &pfad)
{
    if (!m_launcherDb.isOpen()) return false;
    QSqlQuery q(m_launcherDb);
    q.prepare("DELETE FROM bekannte_projekte WHERE datei_pfad = :p");
    q.bindValue(":p", pfad);
    if (!q.exec()) {
        qCWarning(lcDb) << "projektAusRegistryEntfernen:" << q.lastError().text();
        return false;
    }
    QSqlQuery q2(m_launcherDb);
    q2.prepare("DELETE FROM zuletzt_geoeffnet WHERE pfad = :p");
    q2.bindValue(":p", pfad);
    q2.exec();
    emit registryGeaendert();
    return true;
}


bool Database::isOpen() const
{
    return m_db.isOpen();
}

QString Database::lastError() const
{
    return m_db.lastError().text();
}

QVariantMap Database::datenbankInfos() const
{
    QVariantMap m;
    QString projektDatei = m_projektOffen ? m_db.databaseName() : QString();
    QString wikiPfad     = m_wikiDb.isValid() ? m_wikiDb.databaseName() : QString();
    // Backup-Verzeichnis neben der Launcher-DB (App-Datenverzeichnis)
    QString backupDir = m_launcherDb.isOpen()
        ? QFileInfo(m_launcherDb.databaseName()).absolutePath() + "/backups"
        : (!projektDatei.isEmpty() ? QFileInfo(projektDatei).absolutePath() + "/backups" : QString());

    int schemaVersion = 0;
    if (m_projektOffen) {
        QSqlQuery q(m_db);
        if (q.exec("SELECT COALESCE(MAX(version),0) FROM schema_migration") && q.next())
            schemaVersion = q.value(0).toInt();
    }

    m["hauptDb"]           = projektDatei;
    m["wikiDb"]            = wikiPfad;
    m["makrosDb"]          = m_makroPfad;
    QStringList backupDateien = backupDir.isEmpty()
        ? QStringList()
        : QDir(backupDir).entryList({"makros_*.db"}, QDir::Files, QDir::Name);
    QString letztesSicherung;
    if (!backupDateien.isEmpty()) {
        // Dateiname: "makros_YYYY-MM-DD.db" → ab Position 7 (nach "makros_"), 10 Zeichen
        QString basename = backupDateien.last();
        if (basename.size() >= 17) letztesSicherung = basename.mid(7, 10);
    }

    m["backupDir"]         = backupDir;
    m["schemaVersion"]     = schemaVersion;
    m["wikiSchemaVersion"] = WIKI_SCHEMA_VERSION;
    m["backupAnzahl"]      = backupDateien.size();
    m["letztesSicherung"]  = letztesSicherung;
    return m;
}



// ============================================================
// datenbankAutobackup (BACKUP-01 Ebene 1)
// Einmal täglich: makros.db + wiki.db per VACUUM INTO nach backups/,
// max. 7 rotierende Dateien pro Datenbank.
// ============================================================
QVariantMap Database::datenbankAutobackup()
{
    if (!m_launcherDb.isOpen()) return {{"erfolg", false}};

    QString dataDir   = QFileInfo(m_launcherDb.databaseName()).absolutePath();
    QString backupDir = dataDir + "/backups";
    QDir().mkpath(backupDir);

    QString heute = QDate::currentDate().toString("yyyy-MM-dd");

    auto sichereDb = [&](QSqlDatabase &db, const QString &prefix) -> bool {
        if (!db.isOpen()) return false;

        // Bereits heute gesichert?
        QStringList vorhanden = QDir(backupDir).entryList(
            {prefix + "_*.db"}, QDir::Files, QDir::Name);
        for (const QString &f : vorhanden)
            if (f.contains(heute)) return true;

        QString zielPfad = backupDir + "/" + prefix + "_" + heute + ".db";
        QString zielEsc  = zielPfad;
        zielEsc.replace("'", "''");
        QSqlQuery q(db);
        bool ok = q.exec(QString("VACUUM INTO '%1'").arg(zielEsc));
        if (!ok) {
            qCWarning(lcDb) << "BACKUP-01 Auto-Backup" << prefix << ":" << q.lastError().text();
            return false;
        }

        // Rotation: älteste löschen wenn > 7
        vorhanden = QDir(backupDir).entryList({prefix + "_*.db"}, QDir::Files, QDir::Name);
        while (vorhanden.size() > 7)
            QFile::remove(backupDir + "/" + vorhanden.takeFirst());

        return true;
    };

    bool makroOk = sichereDb(m_makroDb, "makros");
    bool wikiOk  = sichereDb(m_wikiDb,  "wiki");

    QStringList alle = QDir(backupDir).entryList({"makros_*.db"}, QDir::Files, QDir::Name);
    QString letztesSicherung;
    if (!alle.isEmpty()) {
        QString basename = alle.last();
        if (basename.size() >= 17) letztesSicherung = basename.mid(7, 10);
    }

    qCInfo(lcDb) << "BACKUP-01 Auto-Backup: makros=" << makroOk << "wiki=" << wikiOk
            << "→" << backupDir;
    return {
        {"erfolg",           true},
        {"makroOk",          makroOk},
        {"wikiOk",           wikiOk},
        {"letztesSicherung", letztesSicherung},
        {"anzahlBackups",    alle.size()},
        {"backupDir",        backupDir}
    };
}

// ============================================================
// standardProjektOrdner (GIT-00)
// Liefert ~/Strömling-Projekte/ als Standard-Ablageort für neue Projekte.
// ============================================================
QString Database::standardProjektOrdner() const
{
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString ordner = home + QStringLiteral("/Strömling-Projekte");
    QDir().mkpath(ordner);
    return ordner;
}

// ============================================================
// symboleNachNorm
// Gibt alle Symbole zurück deren norm-Feld die gesuchte Norm enthält.
// ============================================================
QVariantList Database::symboleNachNorm(const QString &norm)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, code, name, kategorie_pfad, norm, favorit, anschluesse
        FROM symbol
        WHERE instr(norm, :n) > 0
        ORDER BY kategorie_pfad, name
    )");
    q.bindValue(":n", norm);
    if (!q.exec()) {
        qCWarning(lcDb) << "symboleNachNorm:" << q.lastError().text();
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
    QSqlQuery q(m_db);
    q.prepare("UPDATE symbol SET favorit = :fav WHERE id = :id");
    q.bindValue(":fav", favorit ? 1 : 0);
    q.bindValue(":id",  symbolId);
    if (!q.exec()) {
        qCWarning(lcDb) << "symbolFavoritSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// projektNormLaden / projektNormSpeichern
// ============================================================
QString Database::projektNormLaden(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT norm FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("IEC");
}

bool Database::projektNormSpeichern(int projektId, const QString &norm)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET norm = :norm WHERE id = :pid");
    q.bindValue(":norm", norm);
    q.bindValue(":pid",  projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "projektNormSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// projektHintergrundLaden / projektHintergrundSpeichern
// ============================================================
QString Database::projektHintergrundLaden(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT canvas_hintergrund FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next()) {
        QString farbe = q.value(0).toString().trimmed();
        if (!farbe.isEmpty()) return farbe;
    }
    return QStringLiteral("#fdf8e8");
}

bool Database::projektHintergrundSpeichern(int projektId, const QString &farbe)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET canvas_hintergrund = :farbe WHERE id = :pid");
    q.bindValue(":farbe", farbe);
    q.bindValue(":pid",   projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "projektHintergrundSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// grafikLaden
// Gibt alle Grafik-Elemente einer Seite als QVariantList zurück.
// Die Maps verwenden dieselben camelCase-Schlüssel wie das QML-Modell.
// ============================================================
