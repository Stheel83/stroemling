#include "Database.h"
#include <QCoreApplication>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSysInfo>
#include <QTimer>
#include <QUuid>

// VERT-01 (konzept/features/55 §3): Sperrdatei "<projekt>.lock" neben der Projektdatei.
// Wer ein Projekt zuerst oeffnet, schreibt die Sperre; jeder weitere oeffnet nur lesend.
// Eine Sperre gilt nach 24 Stunden ohne Herzschlag als veraltet, auf demselben Rechner
// (Linux) auch sofort, wenn der Prozess nicht mehr laeuft.

static QString lokalerRechner() { return QSysInfo::machineHostName(); }

static QString lokalerBenutzer()
{
    return qEnvironmentVariable("USER", qEnvironmentVariable("USERNAME"));
}

QString Database::sperrDateiPfad(const QString &projektPfad)
{
    return projektPfad + QStringLiteral(".lock");
}

QVariantMap Database::sperreLesen(const QString &lockPfad)
{
    QFile f(lockPfad);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return { { "defekt", true } };   // vorhanden, aber unlesbar -> gilt als veraltet
    return doc.object().toVariantMap();
}

bool Database::sperreVeraltet(const QVariantMap &info, const QDateTime &jetzt)
{
    const QDateTime zeit = QDateTime::fromString(info.value("zeit").toString(), Qt::ISODate);
    if (!zeit.isValid())
        return true;
    if (zeit.secsTo(jetzt) > qint64(SPERRE_VERALTET_STUNDEN) * 3600)
        return true;
#ifdef Q_OS_LINUX
    const qint64 pid = info.value("pid").toLongLong();
    if (info.value("rechner").toString() == lokalerRechner() && pid > 0
        && !QFileInfo::exists(QStringLiteral("/proc/%1").arg(pid)))
        return true;
#endif
    return false;
}

void Database::sperreErwerben(const QString &projektPfad)
{
    sperreFreigeben();
    m_schreibgeschuetzt = false;
    m_sperreInfo.clear();
    m_sperrePfad = sperrDateiPfad(projektPfad);

    const qint64 eigenePid = QCoreApplication::applicationPid();
    const QVariantMap info = sperreLesen(m_sperrePfad);
    if (!info.isEmpty()) {
        const bool eigene = info.value("sitzung").toString() == m_sperreSitzung
            || (info.value("rechner").toString() == lokalerRechner()
                && info.value("pid").toLongLong() == eigenePid);
        if (!eigene && !sperreVeraltet(info)) {
            m_schreibgeschuetzt = true;
            m_sperreInfo = {
                { "rechner",  info.value("rechner") },
                { "benutzer", info.value("benutzer") },
                { "zeit",     QDateTime::fromString(info.value("zeit").toString(), Qt::ISODate)
                                  .toLocalTime().toString(QStringLiteral("dd.MM.yyyy HH:mm")) },
            };
            m_sperrePfad.clear();   // fremde Sperre nie anfassen
            qCInfo(lcDb) << "Projekt gesperrt von" << info.value("benutzer").toString() << "@"
                         << info.value("rechner").toString() << "- Schreibschutz";
            emit schreibschutzChanged();
            return;
        }
        if (!eigene)
            qCInfo(lcDb) << "Veraltete Sperre von" << info.value("benutzer").toString() << "@"
                         << info.value("rechner").toString() << "uebernommen";
    }

    sperreSchreiben();
    if (!m_sperreTimer) {
        m_sperreTimer = new QTimer(this);
        m_sperreTimer->setInterval(10 * 60 * 1000);
        connect(m_sperreTimer, &QTimer::timeout, this, &Database::sperreHerzschlag);
    }
    m_sperreTimer->start();
    emit schreibschutzChanged();
}

bool Database::sperreSchreiben()
{
    const QJsonObject o{
        { "rechner",  lokalerRechner() },
        { "benutzer", lokalerBenutzer() },
        { "pid",      QCoreApplication::applicationPid() },
        { "sitzung",  m_sperreSitzung },
        { "zeit",     QDateTime::currentDateTimeUtc().toString(Qt::ISODate) },
    };
    QSaveFile f(m_sperrePfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qCWarning(lcDb) << "Sperrdatei nicht schreibbar:" << m_sperrePfad;
        return false;
    }
    f.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
    return f.commit();
}

void Database::sperreHerzschlag()
{
    if (m_sperrePfad.isEmpty())
        return;
    if (sperreLesen(m_sperrePfad).value("sitzung").toString() != m_sperreSitzung) {
        qCWarning(lcDb) << "Sperrdatei gehoert nicht mehr dieser Sitzung - Herzschlag uebersprungen";
        return;
    }
    sperreSchreiben();
}

void Database::sperreFreigeben()
{
    if (m_sperreTimer)
        m_sperreTimer->stop();
    if (!m_sperrePfad.isEmpty()
        && sperreLesen(m_sperrePfad).value("sitzung").toString() == m_sperreSitzung)
        QFile::remove(m_sperrePfad);
    m_sperrePfad.clear();
}

// VERT-02c: Sperren fuer Schreibzugriffe ausserhalb der Zeichenflaeche.
//  - Verdrahtung (Kabel, Klemmenreihen, SPS-Zuweisung zu Elementen): bei fremder Sperre, in einer
//    IBN-Kopie und in der Hauptkopie, solange Kopien ausgegeben sind (ohne Override).
//  - Projektdaten (Projekteinstellungen, SPS-Aufbau): bei fremder Sperre und in einer IBN-Kopie;
//    in der Hauptkopie mit ausgegebenen Kopien bleiben sie frei.
// melden = true: der Nutzer hat die Aktion ausgeloest -> Toast ueber sperreVerweigert().
bool Database::verdrahtungGesperrt(bool melden, const QString &was)
{
    if (!m_schreibgeschuetzt && !schaltplanGesperrt())
        return false;
    qCInfo(lcDb) << "Gesperrt (Verdrahtung):" << was;
    if (melden)
        emit sperreVerweigert(m_schreibgeschuetzt
            ? tr("Schreibgeschützt – „%1“ ist nicht möglich.").arg(was)
            : (m_istIbnKopie ? tr("IBN-Kopie – „%1“ ist nicht möglich; der Schaltplan ist gesperrt.").arg(was)
                             : tr("Kopien ausgegeben – „%1“ ist gesperrt (Schaltplan freigeben im Dialog „IBN-Kopien“).").arg(was)));
    return true;
}

bool Database::projektdatenGesperrt(bool melden, const QString &was)
{
    if (!m_schreibgeschuetzt && !m_istIbnKopie)
        return false;
    qCInfo(lcDb) << "Gesperrt (Projektdaten):" << was;
    if (melden)
        emit sperreVerweigert(m_schreibgeschuetzt
            ? tr("Schreibgeschützt – „%1“ ist nicht möglich.").arg(was)
            : tr("IBN-Kopie – „%1“ ist nicht möglich; nur Inbetriebnahme und Fehlersuche sind bearbeitbar.").arg(was));
    return true;
}
