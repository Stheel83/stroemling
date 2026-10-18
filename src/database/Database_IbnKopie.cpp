#include "Database.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

// VERT-02 (konzept/features/55 §4.1a): Kopien-Register der Hauptkopie, IBN-Kopien erstellen,
// Sperre des Schaltplans solange Kopien ausgegeben sind (mit bewusstem Override).

static QString bereichAlsJson(const QVariantList &bereich)
{
    if (bereich.isEmpty())
        return QString("");   // nicht QString(): wuerde NULL binden (NOT NULL-Spalte)
    return QString::fromUtf8(QJsonDocument::fromVariant(bereich).toJson(QJsonDocument::Compact));
}

// Zwei Bereiche ueberlappen, wenn ein Eintrag des einen mit einem des anderen auf allen
// Ebenen (Anlage/Ort/Seite) vereinbar ist; leer = ganzes Projekt = ueberlappt alles.
static bool bereicheUeberlappen(const QVariantList &a, const QVariantList &b)
{
    if (a.isEmpty() || b.isEmpty())
        return true;
    auto vereinbar = [](const QString &x, const QString &y) { return x.isEmpty() || y.isEmpty() || x == y; };
    for (const QVariant &va : a)
        for (const QVariant &vb : b) {
            const QVariantMap ma = va.toMap(), mb = vb.toMap();
            if (vereinbar(ma.value("anlage").toString(), mb.value("anlage").toString())
                && vereinbar(ma.value("ort").toString(),   mb.value("ort").toString())
                && vereinbar(ma.value("seite").toString(), mb.value("seite").toString()))
                return true;
        }
    return false;
}

void Database::ibnKopieStatusAktualisieren()
{
    bool istKopie = false;
    int  offene   = 0;
    if (m_projektOffen) {
        QSqlQuery q(m_db);
        if (q.exec("SELECT kopie_uuid FROM projekt ORDER BY id DESC LIMIT 1") && q.next())
            istKopie = !q.value(0).toString().isEmpty();
        if (q.exec("SELECT COUNT(*) FROM ibn_kopie WHERE status = 'ausgegeben'") && q.next())
            offene = q.value(0).toInt();
    }
    if (offene == 0)
        m_schaltplanOverride = false;   // Override gilt nur, solange Kopien draussen sind
    m_istIbnKopie   = istKopie;
    m_offeneKopien  = offene;
    emit ibnKopieChanged();
}

bool Database::schaltplanGesperrt() const
{
    return m_istIbnKopie || (m_offeneKopien > 0 && !m_schaltplanOverride);
}

QVariantList Database::ibnKopieRegisterLaden(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id, k.kopie_uuid, k.name, k.erstellt_am, k.haupt_revision, k.durchgang_nr,
               k.bereich, k.status, k.eingesammelt_am, k.dateiname,
               (k.haupt_revision < p.haupt_revision) AS veraltet
        FROM ibn_kopie k JOIN projekt p ON p.id = k.projekt_id
        WHERE k.projekt_id = :pid
        ORDER BY k.id DESC
    )");
    q.bindValue(":pid", projektId);
    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnKopieRegisterLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "id",            q.value("id")              },
            { "kopieUuid",     q.value("kopie_uuid")      },
            { "name",          q.value("name")            },
            { "erstelltAm",    q.value("erstellt_am")     },
            { "hauptRevision", q.value("haupt_revision")  },
            { "durchgangNr",   q.value("durchgang_nr")    },
            { "bereich",       QJsonDocument::fromJson(q.value("bereich").toString().toUtf8())
                                   .array().toVariantList() },
            { "status",        q.value("status")          },
            { "eingesammeltAm",q.value("eingesammelt_am") },
            { "dateiname",     q.value("dateiname")       },
            { "veraltet",      q.value("veraltet").toInt() != 0 },
        });
    }
    return result;
}

QStringList Database::ibnKopiePruefen(int projektId, const QVariantList &bereich)
{
    QStringList warnungen;
    if (m_istIbnKopie)
        warnungen << tr("Dies ist selbst eine IBN-Kopie – Kopien können nur in der Hauptkopie erstellt werden.");

    // Doppelte Seitenschluessel (Anlage, Ort, Blattnummer) machen den Overlay-Import mehrdeutig
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT a.kuerzel, o.kuerzel, s.blattnummer, COUNT(*)
        FROM seite s JOIN ort o ON s.ort_id = o.id JOIN anlage a ON o.anlage_id = a.id
        WHERE a.projekt_id = :pid
        GROUP BY a.kuerzel, o.kuerzel, s.blattnummer HAVING COUNT(*) > 1
    )");
    q.bindValue(":pid", projektId);
    if (q.exec())
        while (q.next())
            warnungen << tr("Seitenschlüssel doppelt: %1 / %2 / Blatt %3 (%4×) – der Overlay-Import kann diese Seiten nicht unterscheiden.")
                             .arg(q.value(0).toString(), q.value(1).toString(), q.value(2).toString())
                             .arg(q.value(3).toInt());

    for (const QVariant &v : ibnKopieRegisterLaden(projektId)) {
        const QVariantMap k = v.toMap();
        if (k.value("status").toString() == "ausgegeben"
            && bereicheUeberlappen(bereich, k.value("bereich").toList()))
            warnungen << tr("Bereich überlappt mit der ausgegebenen Kopie „%1“.").arg(k.value("name").toString());
    }
    return warnungen;
}

QVariantMap Database::ibnKopieErstellen(int projektId, const QString &name,
                                        const QVariantList &bereich, const QString &zielOrdner)
{
    auto fehler = [](const QString &t) { return QVariantMap{ { "ok", false }, { "fehler", t } }; };

    if (!m_projektOffen)           return fehler(tr("Kein Projekt geöffnet."));
    if (m_schreibgeschuetzt)       return fehler(tr("Das Projekt ist schreibgeschützt."));
    if (m_istIbnKopie)             return fehler(tr("Eine IBN-Kopie kann keine weiteren Kopien erzeugen."));
    if (name.trimmed().isEmpty())  return fehler(tr("Bitte einen Namen für die Kopie angeben."));

    int revision = 0;
    QString projektName;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT haupt_revision, name FROM projekt WHERE id = :pid");
        q.bindValue(":pid", projektId);
        if (!q.exec() || !q.next()) return fehler(tr("Projekt nicht gefunden."));
        revision    = q.value(0).toInt();
        projektName = q.value(1).toString();
    }
    const int durchgang = ibnAktuellerDurchgang(projektId);

    const QRegularExpression unsauber(QStringLiteral("[^A-Za-z0-9_-]+"));
    auto sauber = [&](QString t) { t.replace(unsauber, "_"); return t.trimmed(); };

    QString ordner = zielOrdner.trimmed();
    if (ordner.isEmpty())
        ordner = QFileInfo(m_db.databaseName()).absolutePath() + "/ibn_kopien";
    if (!QDir().mkpath(ordner))
        return fehler(tr("Zielordner konnte nicht angelegt werden: %1").arg(ordner));

    const QString basis = QStringLiteral("%1_IBN_%2_R%3_%4")
        .arg(sauber(projektName), sauber(name)).arg(revision)
        .arg(QDate::currentDate().toString("yyyyMMdd"));
    QString pfad = ordner + "/" + basis + ".strl";
    for (int n = 2; QFile::exists(pfad); ++n)
        pfad = ordner + "/" + basis + QString("_%1.strl").arg(n);

    const QString uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);

    QSqlQuery qi(m_db);
    qi.prepare(R"(
        INSERT INTO ibn_kopie (projekt_id, kopie_uuid, name, haupt_revision, durchgang_nr, bereich, dateiname)
        VALUES (:pid, :uuid, :name, :rev, :dg, :ber, :datei)
    )");
    qi.bindValue(":pid",  projektId);
    qi.bindValue(":uuid", uuid);
    qi.bindValue(":name", name.trimmed());
    qi.bindValue(":rev",  revision);
    qi.bindValue(":dg",   durchgang);
    qi.bindValue(":ber",  bereichAlsJson(bereich));
    qi.bindValue(":datei", QFileInfo(pfad).fileName());
    if (!qi.exec())
        return fehler(tr("Register-Eintrag fehlgeschlagen: %1").arg(qi.lastError().text()));
    const int kopieId = qi.lastInsertId().toInt();

    auto zurueck = [&](const QString &t) {
        QSqlQuery qd(m_db);
        qd.prepare("DELETE FROM ibn_kopie WHERE id = :id");
        qd.bindValue(":id", kopieId);
        qd.exec();
        QFile::remove(pfad);
        return fehler(t);
    };

    if (!projektExportieren(pfad))
        return zurueck(tr("Die Kopie konnte nicht geschrieben werden."));

    // Kopie markieren: kopie_uuid gesetzt = diese Datei IST eine IBN-Kopie; das Register der
    // Hauptkopie gehoert nicht in die Kopie.
    {
        const QString verb = QStringLiteral("ibn_kopie_markieren");
        bool ok = false;
        {
            QSqlDatabase kdb = QSqlDatabase::addDatabase("QSQLITE", verb);
            kdb.setDatabaseName(pfad);
            if (kdb.open()) {
                QSqlQuery qk(kdb);
                qk.prepare("UPDATE projekt SET kopie_uuid = :u, kopie_name = :n, kopie_bereich = :b, "
                           "kopie_durchgang_nr = :d");
                qk.bindValue(":u", uuid);
                qk.bindValue(":n", name.trimmed());
                qk.bindValue(":b", bereichAlsJson(bereich));
                qk.bindValue(":d", durchgang);
                ok = qk.exec() && qk.exec("DELETE FROM ibn_kopie");
                if (!ok) qCWarning(lcDb) << "ibnKopieErstellen markieren:" << qk.lastError().text();
                kdb.close();
            }
        }
        QSqlDatabase::removeDatabase(verb);
        if (!ok)
            return zurueck(tr("Die Kopie konnte nicht als IBN-Kopie markiert werden."));
    }

    ibnKopieStatusAktualisieren();
    qCInfo(lcDb) << "IBN-Kopie erstellt:" << pfad;
    return { { "ok", true }, { "pfad", pfad }, { "kopieUuid", uuid }, { "kopieId", kopieId } };
}

bool Database::ibnKopieStatusSetzen(int kopieId, const QString &status)
{
    if (status != "verworfen" && status != "ausgegeben")
        return false;   // 'eingesammelt' setzt nur der Overlay-Import
    QSqlQuery q(m_db);
    q.prepare("UPDATE ibn_kopie SET status = :s WHERE id = :id AND status <> 'eingesammelt'");
    q.bindValue(":s",  status);
    q.bindValue(":id", kopieId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    ibnKopieStatusAktualisieren();
    return ok;
}

bool Database::ibnKopieEingesammeltMarkieren(const QString &kopieUuid)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE ibn_kopie SET status = 'eingesammelt', eingesammelt_am = datetime('now') "
              "WHERE kopie_uuid = :u");
    q.bindValue(":u", kopieUuid);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    ibnKopieStatusAktualisieren();
    return ok;
}

int Database::ibnSchaltplanOverride()
{
    if (!m_projektOffen || m_schreibgeschuetzt || m_istIbnKopie || m_offeneKopien == 0)
        return -1;
    QSqlQuery q(m_db);
    if (!q.exec("UPDATE projekt SET haupt_revision = haupt_revision + 1") ) {
        qCWarning(lcDb) << "ibnSchaltplanOverride:" << q.lastError().text();
        return -1;
    }
    m_schaltplanOverride = true;
    ibnKopieStatusAktualisieren();
    q.exec("SELECT haupt_revision FROM projekt ORDER BY id DESC LIMIT 1");
    return q.next() ? q.value(0).toInt() : -1;
}
