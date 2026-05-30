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
    m_launcherDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_launcher");
    m_launcherDb.setDatabaseName(path);
    if (!m_launcherDb.open()) {
        qWarning() << "Launcher-DB konnte nicht geöffnet werden:" << m_launcherDb.lastError().text();
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
            qWarning() << "zuletzt_geoeffnet Tabelle:" << q.lastError().text();
        }
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
            qWarning() << "bekannte_projekte Tabelle:" << q.lastError().text();
        }
        // Einmalige Befüllung aus zuletzt_geoeffnet wenn bekannte_projekte noch leer
        {
            QSqlQuery cnt(m_launcherDb);
            if (cnt.exec("SELECT COUNT(*) FROM bekannte_projekte") && cnt.next()
                    && cnt.value(0).toInt() == 0) {
                QSqlQuery copy(m_launcherDb);
                copy.exec("INSERT OR IGNORE INTO bekannte_projekte "
                           "(datei_pfad, projekt_name, zuletzt_geoeffnet) "
                           "SELECT pfad, name, geoeffnet_am FROM zuletzt_geoeffnet");
            }
        }
    }
    qInfo() << "Launcher-DB geöffnet:" << path;

    // Alte stroemling.db-Pfade (vor R7) als Projekte anbieten.
    // Vor R7: org="Strömling Design", jetzt org="stroemling" → anderer XDG-Pfad.
    // Basis-Verzeichnis ableiten: ein Ebene über dem aktuellen dataDir.
    QString basedir = QFileInfo(path).absolutePath(); // z.B. ~/.local/share/stroemling/Strömling Design
    QDir parentDir(basedir);
    parentDir.cdUp(); // ~/.local/share/stroemling
    parentDir.cdUp(); // ~/.local/share
    const QString altPfad = parentDir.filePath(
        "Strömling Design/Strömling Design/stroemling.db");
    if (QFile::exists(altPfad)) {
        QSqlQuery qCheck(m_launcherDb);
        qCheck.prepare("SELECT COUNT(*) FROM zuletzt_geoeffnet WHERE pfad = :p");
        qCheck.bindValue(":p", altPfad);
        if (qCheck.exec() && qCheck.next() && qCheck.value(0).toInt() == 0) {
            zuletzGeoeffnetEintragen(altPfad, "Bisheriges Projekt (vor R7)");
            qInfo() << "Altes Projekt in zuletzt_geoeffnet eingetragen:" << altPfad;
        }
    }

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
        qWarning() << "Projekt konnte nicht geöffnet werden:" << m_db.lastError().text();
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
    qInfo() << "Projekt geöffnet:" << localPath;
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

    if (QFile::exists(localPath)) {
        qWarning() << "Projektdatei existiert bereits:" << localPath;
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
        qWarning() << "Projektdatei konnte nicht erstellt werden:" << m_db.lastError().text();
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
            qWarning() << "schema_migration für neues Projekt:" << q.lastError().text();
            m_db.close(); m_db = QSqlDatabase();
            QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
            QFile::remove(localPath);
            return false;
        }
    }

    if (!m_db.transaction()) {
        qWarning() << "Transaktion für neues Projekt fehlgeschlagen";
        m_db.close(); m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        QFile::remove(localPath);
        return false;
    }

    bool ok = createSchema()
           && seedSymbolKatalog()
           && seedBuiltinSymbolDefinitionen()
           && seedIbnFeldvorlagen();

    if (ok) {
        // Projektzeile mit Nutzernamen anlegen
        QSqlQuery qp;
        qp.prepare("INSERT INTO projekt (name) VALUES (:n)");
        qp.bindValue(":n", projektName.isEmpty() ? QFileInfo(localPath).baseName() : projektName);
        ok = qp.exec();
        if (!ok)
            qWarning() << "Projekt-Eintrag anlegen:" << qp.lastError().text();
    }

    if (ok) {
        // Baseline-Version eintragen
        QSqlQuery qm;
        qm.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :d)");
        qm.bindValue(":v", BASELINE_VERSION);
        qm.bindValue(":d", QString("Baseline v%1 – neues Projekt").arg(BASELINE_VERSION));
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
    qInfo() << "Neues Projekt erstellt:" << localPath;
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
    qInfo() << "Projekt geschlossen.";
    emit projektOffenChanged();
}

bool Database::projektExportieren(const QString &destPfad)
{
    const QString localPfad = QUrl(destPfad).isLocalFile() ? QUrl(destPfad).toLocalFile() : destPfad;

    if (!m_projektOffen) {
        qWarning() << "projektExportieren: kein Projekt geöffnet";
        return false;
    }

    // VACUUM INTO schlägt fehl wenn die Zieldatei bereits existiert
    if (QFile::exists(localPfad) && !QFile::remove(localPfad)) {
        qWarning() << "projektExportieren: Zieldatei konnte nicht gelöscht werden:" << localPfad;
        return false;
    }

    QString escaped = localPfad;
    escaped.replace("'", "''");
    QSqlQuery q(m_db);
    if (!q.exec("VACUUM INTO '" + escaped + "'")) {
        qWarning() << "projektExportieren:" << q.lastError().text();
        return false;
    }
    qInfo() << "Projekt exportiert nach:" << localPfad;
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
            qWarning() << "projektLoeschen: Datei konnte nicht gelöscht werden:" << pfad;
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
        qWarning() << "projektMetaDatenSpeichern:" << q.lastError().text();
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
        qWarning() << "bekannteProjecteEintragen:" << q.lastError().text();
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
        qWarning() << "projektAusRegistryEntfernen:" << q.lastError().text();
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
    m["backupDir"]         = backupDir;
    m["schemaVersion"]     = schemaVersion;
    m["wikiSchemaVersion"] = WIKI_SCHEMA_VERSION;
    m["backupAnzahl"]      = backupDir.isEmpty() ? 0 : QDir(backupDir).entryList({"*.db"}, QDir::Files).size();
    return m;
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
    QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);
    q.prepare("SELECT canvas_hintergrund FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("#080f1c");
}

bool Database::projektHintergrundSpeichern(int projektId, const QString &farbe)
{
    QSqlQuery q(m_db);
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
