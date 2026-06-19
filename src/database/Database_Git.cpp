#include "Database.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QProcess>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDateTime>

// ── projektOrdner ────────────────────────────────────────────────────────────
QString Database::projektOrdner() const
{
    if (!m_projektOffen) return {};
    return QFileInfo(m_db.databaseName()).absolutePath();
}

// ── gitVerfuegbar ────────────────────────────────────────────────────────────
bool Database::gitVerfuegbar() const
{
    return QProcess::execute("git", {"--version"}) == 0;
}

// ── snapshotErstellen ────────────────────────────────────────────────────────
// Schreibt snapshot.json mit menschenlesbaren Projektdaten (für Git-Diffs).
bool Database::snapshotErstellen(const QString &ordner)
{
    if (!m_projektOffen || ordner.isEmpty()) return false;

    QString projektName;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT name FROM projekt ORDER BY id LIMIT 1") && q.next())
            projektName = q.value(0).toString();
    }

    int schemaVer = 0;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT COALESCE(MAX(version),0) FROM schema_migration") && q.next())
            schemaVer = q.value(0).toInt();
    }

    QJsonArray seiten;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT name FROM seite ORDER BY reihenfolge, id"))
            while (q.next()) seiten.append(q.value(0).toString());
    }

    int elementAnzahl = 0, klemmenAnzahl = 0, kabelAnzahl = 0;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT COUNT(*) FROM grafik_element") && q.next())
            elementAnzahl = q.value(0).toInt();
        if (q.exec("SELECT COUNT(*) FROM grafik_element WHERE typ='klemme'") && q.next())
            klemmenAnzahl = q.value(0).toInt();
        if (q.exec("SELECT COUNT(*) FROM kabel") && q.next())
            kabelAnzahl = q.value(0).toInt();
    }

    QJsonArray bmkListe;
    {
        QSqlQuery q(m_db);
        if (q.exec(R"(SELECT DISTINCT json_extract(extra_daten,'$.bmk')
                      FROM grafik_element
                      WHERE json_extract(extra_daten,'$.bmk') IS NOT NULL
                      ORDER BY 1 LIMIT 30)"))
            while (q.next()) bmkListe.append(q.value(0).toString());
    }

    QJsonObject snap{
        {"projektname",    projektName},
        {"schema_version", schemaVer},
        {"gespeichert_am", QDateTime::currentDateTime().toString(Qt::ISODate)},
        {"seiten",         seiten},
        {"element_anzahl", elementAnzahl},
        {"klemmen_anzahl", klemmenAnzahl},
        {"kabel_anzahl",   kabelAnzahl},
        {"bmk_liste",      bmkListe}
    };

    QFile f(ordner + "/snapshot.json");
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "snapshotErstellen: Datei nicht schreibbar:" << f.fileName();
        return false;
    }
    f.write(QJsonDocument(snap).toJson(QJsonDocument::Indented));
    return true;
}

// ── gitProjektInit ───────────────────────────────────────────────────────────
// git init + .gitignore + erster Commit nach Anlegen eines neuen Projekts.
void Database::gitProjektInit(const QString &ordner)
{
    if (ordner.isEmpty() || !QDir(ordner).exists()) return;

    // .gitignore für SQLite-Hilfsdateien
    QFile gi(ordner + "/.gitignore");
    if (gi.open(QIODevice::WriteOnly | QIODevice::Text))
        gi.write("*.db-wal\n*.db-shm\n*.db-journal\n");

    snapshotErstellen(ordner);

    // git init → git add → git commit (Kette async via QProcess)
    auto init = new QProcess();
    init->setWorkingDirectory(ordner);
    QObject::connect(init, &QProcess::finished, init,
        [init, ordner](int exitCode) {
            init->deleteLater();
            if (exitCode != 0) {
                qCWarning(lcDb) << "gitProjektInit: git init fehlgeschlagen";
                return;
            }
            auto add = new QProcess();
            add->setWorkingDirectory(ordner);
            QObject::connect(add, &QProcess::finished, add,
                [add, ordner](int) {
                    add->deleteLater();
                    auto commit = new QProcess();
                    commit->setWorkingDirectory(ordner);
                    QObject::connect(commit, &QProcess::finished, commit,
                        [commit](int code) {
                            commit->deleteLater();
                            qCInfo(lcDb) << "GIT-01 Init-Commit:" << (code == 0 ? "ok" : "fehlgeschlagen");
                        });
                    commit->start("git", {"commit", "-m", "Projekt angelegt"});
                });
            add->start("git", {"add", "projekt.strl", "snapshot.json", ".gitignore", "bilder"});
        });
    init->start("git", {"init"});
}

// ── gitAutoCommit ────────────────────────────────────────────────────────────
// WAL-Checkpoint + snapshot.json aktualisieren + git add + git commit.
// Wird nach explizitem Ctrl+S aufgerufen.
void Database::gitAutoCommit(const QString &ordner, const QString &nachricht)
{
    if (ordner.isEmpty()) return;
    if (!QDir(ordner + "/.git").exists()) return;

    // WAL in Hauptdatei schreiben damit projekt.strl vollständig ist
    {
        QSqlQuery q(m_db);
        q.exec("PRAGMA wal_checkpoint(FULL)");
    }

    snapshotErstellen(ordner);

    auto add = new QProcess();
    add->setWorkingDirectory(ordner);
    QObject::connect(add, &QProcess::finished, add,
        [add, ordner, nachricht](int) {
            add->deleteLater();
            auto commit = new QProcess();
            commit->setWorkingDirectory(ordner);
            QObject::connect(commit, &QProcess::finished, commit,
                [commit, ordner](int code) {
                    commit->deleteLater();
                    if (code != 0) return; // "nothing to commit" oder Fehler
                    qCInfo(lcDb) << "GIT-01 Auto-Commit ok";
                    // GIT-02: Push wenn Remote konfiguriert (stiller Fehler)
                    QProcess remoteCheck;
                    remoteCheck.setWorkingDirectory(ordner);
                    remoteCheck.start("git", {"remote", "get-url", "origin"});
                    if (!remoteCheck.waitForFinished(1000) || remoteCheck.exitCode() != 0)
                        return;
                    auto push = new QProcess();
                    push->setWorkingDirectory(ordner);
                    QObject::connect(push, &QProcess::finished, push,
                        [push](int pCode) {
                            push->deleteLater();
                            if (pCode == 0) qCInfo(lcDb) << "GIT-02 Push ok";
                            else qCWarning(lcDb) << "GIT-02 Push fehlgeschlagen (ignoriert)";
                        });
                    push->start("git", {"push", "--set-upstream", "origin", "HEAD"});
                });
            commit->start("git", {"commit", "--allow-empty-message", "-m", nachricht});
        });
    add->start("git", {"add", "projekt.strl", "snapshot.json", "bilder"});
}

// ── gitLog ───────────────────────────────────────────────────────────────────
// Gibt die letzten 50 Commits als [{hash, hashFull, datum, nachricht}] zurück.
QVariantList Database::gitLog(const QString &ordner)
{
    QVariantList result;
    if (ordner.isEmpty() || !QDir(ordner + "/.git").exists()) return result;

    QProcess proc;
    proc.setWorkingDirectory(ordner);
    proc.start("git", {"log", "--format=%H|%ai|%s", "--max-count=50"});
    if (!proc.waitForFinished(3000)) return result;

    for (const QByteArray &zeile : proc.readAllStandardOutput().split('\n')) {
        if (zeile.trimmed().isEmpty()) continue;
        QList<QByteArray> parts = zeile.split('|');
        if (parts.size() < 3) continue;
        QVariantMap e;
        e["hash"]      = QString(parts[0]).left(8);
        e["hashFull"]  = QString(parts[0]);
        e["datum"]     = QString(parts[1]).trimmed();
        e["nachricht"] = QString(QByteArray(zeile).mid(parts[0].size() + parts[1].size() + 2)).trimmed();
        result.append(e);
    }
    return result;
}

// ── gitCheckout ──────────────────────────────────────────────────────────────
// Stellt projekt.strl auf den angegebenen Commit-Hash zurück + öffnet neu.
bool Database::gitCheckout(const QString &ordner, const QString &hash)
{
    if (ordner.isEmpty() || hash.isEmpty()) return false;

    // Aktuelles Projekt schließen
    if (m_projektOffen) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        m_projektOffen = false;
        emit projektOffenChanged();
    }

    QProcess proc;
    proc.setWorkingDirectory(ordner);
    proc.start("git", {"checkout", hash, "--", "projekt.strl", "snapshot.json"});
    if (!proc.waitForFinished(5000) || proc.exitCode() != 0) {
        qCWarning(lcDb) << "gitCheckout fehlgeschlagen:" << proc.readAllStandardError();
        return false;
    }

    qCInfo(lcDb) << "GIT-01 Checkout:" << hash << "→" << ordner;
    return openProjekt(ordner + "/projekt.strl");
}

// ── gitRemoteUrl (GIT-02) ────────────────────────────────────────────────────
// Liefert die aktuelle Remote-URL (origin) oder leeren String.
QString Database::gitRemoteUrl(const QString &ordner) const
{
    if (ordner.isEmpty() || !QDir(ordner + "/.git").exists()) return {};
    QProcess proc;
    proc.setWorkingDirectory(ordner);
    proc.start("git", {"remote", "get-url", "origin"});
    if (!proc.waitForFinished(2000) || proc.exitCode() != 0) return {};
    return QString(proc.readAllStandardOutput()).trimmed();
}

// ── gitRemoteSetzen (GIT-02) ─────────────────────────────────────────────────
// Setzt oder aktualisiert die Remote-URL und löst einen initialen Push aus.
void Database::gitRemoteSetzen(const QString &ordner, const QString &url)
{
    if (ordner.isEmpty() || url.trimmed().isEmpty()) return;

    // remote add oder set-url je nachdem ob origin bereits existiert
    QProcess check;
    check.setWorkingDirectory(ordner);
    check.start("git", {"remote", "get-url", "origin"});
    check.waitForFinished(2000);

    QStringList remoteArgs = (check.exitCode() == 0)
        ? QStringList{"remote", "set-url", "origin", url}
        : QStringList{"remote", "add", "origin", url};

    auto remote = new QProcess();
    remote->setWorkingDirectory(ordner);
    QObject::connect(remote, &QProcess::finished, remote,
        [remote, ordner](int code) {
            remote->deleteLater();
            if (code != 0) {
                qCWarning(lcDb) << "GIT-02 gitRemoteSetzen: remote-Befehl fehlgeschlagen";
                return;
            }
            // Initialer Push
            auto push = new QProcess();
            push->setWorkingDirectory(ordner);
            QObject::connect(push, &QProcess::finished, push,
                [push](int pCode) {
                    push->deleteLater();
                    if (pCode == 0) qCInfo(lcDb) << "GIT-02 Initialer Push ok";
                    else qCWarning(lcDb) << "GIT-02 Initialer Push fehlgeschlagen (SSH-Key / Zugangsdaten prüfen)";
                });
            push->start("git", {"push", "--set-upstream", "origin", "HEAD"});
        });
    remote->start("git", remoteArgs);
    qCInfo(lcDb) << "GIT-02 Remote gesetzt:" << url;
}
