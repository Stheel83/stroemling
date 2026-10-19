#pragma once
#include <QtTest>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include "utils/DateiBrowser.h"

// DateiBrowser: Auflisten, Filtern, Normalisieren für den eigenen Dateiwähler (kein nativer FileDialog im AppImage).
class TstDateiBrowser : public QObject
{
    Q_OBJECT

    QString p(const QString &rel) const { return m_dir.filePath(rel); }
    void datei(const QString &rel, int bytes = 10)
    {
        QDir().mkpath(QFileInfo(p(rel)).absolutePath());
        QFile f(p(rel));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(QByteArray(bytes, 'x'));
    }

private slots:
    void initTestCase() { QVERIFY(m_dir.isValid()); }

    void inhaltListetOrdnerZuerstSortiertOhneVersteckteUndFiltertDateien()
    {
        QDir().mkpath(p("wurzel/Zeta"));
        QDir().mkpath(p("wurzel/alpha"));
        QDir().mkpath(p("wurzel/.versteckt"));
        datei("wurzel/B.json");
        datei("wurzel/a.JSON", 2048);
        datei("wurzel/notiz.txt");
        datei("wurzel/.geheim.json");
        DateiBrowser b;
        const QVariantList alle = b.inhalt(p("wurzel"));
        QStringList namen;
        for (const QVariant &v : alle)
            namen << v.toMap().value("name").toString();
        QCOMPARE(namen, QStringList({ "alpha", "Zeta", "a.JSON", "B.json", "notiz.txt" }));      // Ordner zuerst, ohne Groß/Klein, ohne Versteckte
        QVERIFY(alle.at(0).toMap().value("istOrdner").toBool());
        QVERIFY(!alle.at(2).toMap().value("istOrdner").toBool());
        QVERIFY(alle.at(2).toMap().value("groesse").toString().contains("kB"));
        QVERIFY(alle.at(0).toMap().value("groesse").toString().isEmpty());
        QCOMPARE(alle.at(2).toMap().value("pfad").toString(), p("wurzel/a.JSON"));

        // Endungsfilter wirkt nur auf Dateien (mit und ohne Punkt, ohne Groß/Klein); Ordner bleiben sichtbar
        for (const QStringList &f : { QStringList { ".json" }, QStringList { "json" }, QStringList { ".JSON" } }) {
            QStringList n;
            for (const QVariant &v : b.inhalt(p("wurzel"), f))
                n << v.toMap().value("name").toString();
            QCOMPARE(n, QStringList({ "alpha", "Zeta", "a.JSON", "B.json" }));
        }
    }

    void fehlendeOrdnerGebenEineLeereListe()
    {
        DateiBrowser b;
        QVERIFY(b.inhalt(p("gibtsnicht")).isEmpty());
        QVERIFY(b.inhalt("").isEmpty());
        datei("nur_datei.json");
        QVERIFY(b.inhalt(p("nur_datei.json")).isEmpty());         // eine Datei ist kein Ordner
    }

    void elternOrdnerVonUndVerbinde()
    {
        DateiBrowser b;
        QDir().mkpath(p("a/b"));
        datei("a/b/x.json");
        QCOMPARE(b.eltern(p("a/b")), p("a"));
        QCOMPARE(b.eltern("/"), QStringLiteral("/"));                                // Wurzel bleibt Wurzel
        QCOMPARE(b.ordnerVon(p("a/b")), p("a/b"));
        QCOMPARE(b.ordnerVon(p("a/b/x.json")), p("a/b"));                            // Datei → ihr Ordner
        QCOMPARE(b.ordnerVon(p("a/b/noch/nicht/da.json")), p("a/b"));                // nächster vorhandener Vorfahre
        QCOMPARE(b.ordnerVon("file://" + p("a")), p("a"));                           // URL-Form
        QCOMPARE(b.ordnerVon("~"), QDir::homePath());
        QCOMPARE(b.ordnerVon(""), QDir::homePath());
        QCOMPARE(b.verbinde(p("a/"), "neu.json"), p("a/neu.json"));
        QCOMPARE(b.dateiname(p("a/b/x.json")), QStringLiteral("x.json"));
        QVERIFY(b.dateiExistiert(p("a/b/x.json")));
        QVERIFY(!b.dateiExistiert(p("a/b")));                                        // Ordner ist keine Datei
        QVERIFY(!b.dateiExistiert(p("a/b/nein.json")));
    }

private:
    QTemporaryDir m_dir;
};
