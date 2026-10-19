#include "DateiBrowser.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QLocale>
#include <QUrl>

namespace {

// "file://…" und "~" auflösen
QString bereinigt(const QString &eingabe)
{
    QString s = eingabe.trimmed();
    if (s.startsWith(QLatin1String("file://")))
        s = QUrl(s).toLocalFile();
    if (s == QLatin1String("~"))
        s = QDir::homePath();
    else if (s.startsWith(QLatin1String("~/")))
        s = QDir::homePath() + s.mid(1);
    return s.isEmpty() ? QString() : QDir::cleanPath(s);
}

} // namespace

QVariantList DateiBrowser::inhalt(const QString &ordner, const QStringList &endungen) const
{
    QVariantList liste;
    const QString bereinigter = bereinigt(ordner);
    if (bereinigter.isEmpty())
        return liste;   // QDir("") hieße „aktuelles Arbeitsverzeichnis“ – nie auflisten
    const QDir dir(bereinigter);
    if (!dir.exists())
        return liste;

    QStringList endungenKlein;
    for (const QString &e : endungen)
        endungenKlein << (e.startsWith(QLatin1Char('.')) ? e : QLatin1Char('.') + e).toLower();

    const QFileInfoList eintraege = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Readable,
                                                      QDir::DirsFirst | QDir::IgnoreCase | QDir::Name);
    for (const QFileInfo &fi : eintraege) {
        if (fi.fileName().startsWith(QLatin1Char('.')))
            continue;   // versteckt
        const bool istOrdner = fi.isDir();
        if (!istOrdner && !endungenKlein.isEmpty()) {
            bool passt = false;
            for (const QString &e : endungenKlein)
                passt = passt || fi.fileName().toLower().endsWith(e);
            if (!passt)
                continue;
        }
        liste.append(QVariantMap {
            { "name", fi.fileName() },
            { "pfad", fi.absoluteFilePath() },
            { "istOrdner", istOrdner },
            { "groesse", istOrdner ? QString() : QLocale().formattedDataSize(fi.size(), 1, QLocale::DataSizeTraditionalFormat) },
            { "geaendert", fi.lastModified().toString(QStringLiteral("dd.MM.yyyy HH:mm")) },
        });
    }
    return liste;
}

QString DateiBrowser::eltern(const QString &ordner) const
{
    const QString s = bereinigt(ordner);
    if (s.isEmpty())
        return QDir::homePath();
    QDir d(s);
    return d.cdUp() ? d.absolutePath() : s;
}

QString DateiBrowser::ordnerVon(const QString &eingabe) const
{
    QString s = bereinigt(eingabe);
    if (s.isEmpty())
        return QDir::homePath();
    const QFileInfo fi(s);
    if (fi.isDir())
        return fi.absoluteFilePath();
    // Datei oder noch nicht vorhandener Pfad: nächster vorhandener Vorfahre (QDir::cdUp scheitert auf nicht vorhandenen Ordnern,
    // daher den Pfad selbst Schritt für Schritt kürzen)
    QString kandidat = fi.absolutePath();
    while (!QFileInfo(kandidat).isDir()) {
        const QString oben = QFileInfo(kandidat).absolutePath();
        if (oben == kandidat)
            return QDir::homePath();
        kandidat = oben;
    }
    return kandidat;
}

QString DateiBrowser::dateiname(const QString &pfad) const
{
    return QFileInfo(bereinigt(pfad)).fileName();
}

QString DateiBrowser::verbinde(const QString &ordner, const QString &name) const
{
    return QDir::cleanPath(bereinigt(ordner) + QLatin1Char('/') + name);
}

bool DateiBrowser::dateiExistiert(const QString &pfad) const
{
    return QFileInfo(bereinigt(pfad)).isFile();
}
