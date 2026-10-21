#pragma once
#include <QtTest>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariantMap>
#include "database/Database.h"

// WIKI-EXP-01: ein Export-/Import-Weg für Sicherung und Bundle (Konzept 25 §12). Die Verbindung "stroemling_wiki" ist je
// Prozess nur einmal vergeben, daher wird jedes Wiki in einem eigenen Block geöffnet und danach wieder abgemeldet.

class TstWikiExport : public QObject
{
    Q_OBJECT

    static QSqlDatabase wdb() { return QSqlDatabase::database(QStringLiteral("stroemling_wiki")); }
    static QString neuerOrdner(const char *name)
    {
        const QString o = QDir::tempPath() + "/stroemling_test_wikiexp_" + name + "_"
                        + QString::number(QDateTime::currentMSecsSinceEpoch());
        QDir().mkpath(o);
        return o;
    }
    static int ex(const QString &sql, const QVariantList &w = {})
    {
        QSqlQuery q(wdb());
        q.prepare(sql);
        for (const QVariant &v : w) q.addBindValue(v);
        if (!q.exec()) { qWarning() << q.lastError().text() << sql.left(100); return -1; }
        return q.lastInsertId().toInt();
    }
    static QVariant wert(const QString &sql, const QVariantList &w = {})
    {
        QSqlQuery q(wdb());
        q.prepare(sql);
        for (const QVariant &v : w) q.addBindValue(v);
        return (q.exec() && q.next()) ? q.value(0) : QVariant();
    }
    static int katAnlegen(const QString &name) { return ex("INSERT INTO wiki_kategorie (name, sortierung) VALUES (?, 99)", { name }); }
    static int artikel(int kat, const QString &titel, const QString &inhalt, const QString &bundle = QString(), int vng = 0)
    {
        return ex("INSERT INTO wiki_artikel (kategorie_id, titel, inhalt, tags, bundle_kennung, von_nutzer_geaendert, ist_system) "
                  "VALUES (?, ?, ?, '', ?, ?, 0)",
                  { kat, titel, inhalt, bundle.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : QVariant(bundle), vng });
    }
    static int artikelAnzahl(const QString &titel)
    {
        return wert("SELECT COUNT(*) FROM wiki_artikel WHERE titel = ? AND ist_system = 0", { titel }).toInt();
    }
    static QJsonObject lesen(const QString &pfad)
    {
        QFile f(pfad);
        return f.open(QIODevice::ReadOnly) ? QJsonDocument::fromJson(f.readAll()).object() : QJsonObject();
    }
    static void schreiben(const QString &pfad, const QJsonObject &o)
    {
        QFile f(pfad);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(QJsonDocument(o).toJson());
    }

    // Quell-Wiki: eigener Artikel mit Bild, Artikel aus Bundle "b1" (vom Nutzer geändert), Bundle-Stand 3
    void quelleBauen(const QString &ordner, const QString &sicherung, const QString &bundleDatei)
    {
        Database d;
        QVERIFY(d.openWiki(ordner + "/wiki.db"));
        const int kat = katAnlegen("TestKat");
        const int a1 = artikel(kat, "Eigen", "Text mit Bild ![x](wiki://bild/__ID__)");
        const int bid = ex("INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, blob_pfad, sortierung) VALUES (?, 'x.png', 'image/png', 'q.png', 1)", { a1 });
        ex("UPDATE wiki_artikel SET inhalt = ? WHERE id = ?", { QString("Text mit Bild ![x](wiki://bild/%1)").arg(bid), a1 });
        QFile blob(ordner + "/wiki_blobs/q.png");
        QVERIFY(blob.open(QIODevice::WriteOnly)); blob.write("PNGDATA"); blob.close();
        artikel(kat, "Aus Bundle", "Bundle-Text", "b1", 1);
        ex("INSERT OR REPLACE INTO wiki_meta (schluessel, wert) VALUES ('bundle_version_b1', '3')");
        QVERIFY(d.wikiExportieren(sicherung, {}).value("erfolg").toBool());
        const int katId = wert("SELECT id FROM wiki_kategorie WHERE name = 'TestKat'").toInt();
        const QVariantMap r = d.wikiExportieren(bundleDatei, { { "bundle", true }, { "kennung", "firma" }, { "titel", "Firma" },
                                                                { "version", 2 }, { "kategorieIds", QVariantList { katId } } });
        QVERIFY2(r.value("erfolg").toBool(), qPrintable(r.value("meldung").toString()));
        QCOMPARE(r.value("artikel").toInt(), 1);          // nur "Eigen"
        QCOMPARE(r.value("ausgelassen").toInt(), 1);      // "Aus Bundle" gehört dem Bundle b1 (O5)
    }

private slots:
    // Sicherung -> leeres Wiki: Artikel, Bild (mit neu gesetzter Bild-ID im Text), Bundle-Herkunft und -Stand kommen zurück
    void test_01_sicherungRundlauf()
    {
        const QString q = neuerOrdner("q1"), z = neuerOrdner("z1");
        const QString sich = q + "/sicherung.json", bund = q + "/bundle.json";
        quelleBauen(q, sich, bund);
        QSqlDatabase::removeDatabase("stroemling_wiki");

        const QJsonObject root = lesen(sich);
        QVERIFY(!root.contains("bundle_kennung"));
        QCOMPARE(root.value("bundle_staende").toObject().value("b1").toInt(), 3);

        {
            Database d;
            QVERIFY(d.openWiki(z + "/wiki.db"));
            const QVariantMap r = d.wikiImportieren(sich, true);
            QVERIFY2(r.value("erfolg").toBool(), qPrintable(r.value("meldung").toString()));
            QCOMPARE(r.value("art").toString(), QString("sicherung"));
            QCOMPARE(r.value("neu").toInt(), 2);                      // Seed-Artikel sind schon da (übersprungen)
            QCOMPARE(wert("SELECT bundle_kennung FROM wiki_artikel WHERE titel = 'Aus Bundle'").toString(), QString("b1"));
            QCOMPARE(wert("SELECT von_nutzer_geaendert FROM wiki_artikel WHERE titel = 'Aus Bundle'").toInt(), 1);
            QCOMPARE(wert("SELECT wert FROM wiki_meta WHERE schluessel = 'bundle_version_b1'").toString(), QString("3"));
            const int bildId = wert("SELECT wb.id FROM wiki_bild wb JOIN wiki_artikel wa ON wa.id = wb.artikel_id WHERE wa.titel = 'Eigen'").toInt();
            QVERIFY(bildId > 0);
            QVERIFY(wert("SELECT inhalt FROM wiki_artikel WHERE titel = 'Eigen'").toString()
                        .contains(QString("wiki://bild/%1)").arg(bildId)));
            QVERIFY(QFile::exists(z + "/wiki_blobs/" + wert("SELECT blob_pfad FROM wiki_bild WHERE id = ?", { bildId }).toString()));

            // Bundle-Update gleicher Kennung danach: keine Dubletten (B2)
            QJsonObject b;
            b["wiki_export_version"] = 1; b["bundle_kennung"] = "b1"; b["bundle_version"] = 4; b["bundle_titel"] = "B1";
            b["kategorien"] = QJsonArray { QJsonObject { { "id", 1 }, { "name", "TestKat" } } };
            b["artikel"] = QJsonArray { QJsonObject { { "id", 1 }, { "kategorie_id", 1 }, { "kategorie_name", "TestKat" },
                                                       { "titel", "Aus Bundle" }, { "inhalt", "neu" }, { "tags", "" } } };
            schreiben(z + "/b1_v4.json", b);
            const QVariantMap u = d.wikiImportieren(z + "/b1_v4.json", true);
            QVERIFY2(u.value("erfolg").toBool(), qPrintable(u.value("meldung").toString()));
            QCOMPARE(u.value("art").toString(), QString("bundle"));
            QCOMPARE(artikelAnzahl("Aus Bundle"), 1);
            QCOMPARE(u.value("uebersprungen").toInt(), 1);   // vom Nutzer geändert → geschützt
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        QDir(q).removeRecursively(); QDir(z).removeRecursively();
    }

    // Zusammenführen: Gleiches wird übersprungen, Abweichendes unter "(Import)" angelegt, nichts überschrieben, wiederholbar
    void test_02_zusammenfuehrenOhneDubletten()
    {
        const QString q = neuerOrdner("q2"), z = neuerOrdner("z2");
        const QString sich = q + "/sicherung.json", bund = q + "/bundle.json";
        quelleBauen(q, sich, bund);
        QSqlDatabase::removeDatabase("stroemling_wiki");
        {
            Database d;
            QVERIFY(d.openWiki(z + "/wiki.db"));
            const QVariantMap eins = d.wikiImportieren(sich, true);
            QVERIFY(eins.value("erfolg").toBool());
            const QVariantMap zwei = d.wikiImportieren(sich, true);        // zweimal importiert
            QCOMPARE(zwei.value("neu").toInt(), 0);
            QCOMPARE(zwei.value("uebersprungen").toInt(), eins.value("uebersprungen").toInt() + eins.value("neu").toInt());
            QCOMPARE(artikelAnzahl("Eigen"), 1);

            // lokal geändert, dann Sicherung erneut: lokaler Text bleibt, Datei-Fassung kommt als "(Import)"
            ex("UPDATE wiki_artikel SET inhalt = 'lokal geaendert' WHERE titel = 'Eigen'");
            const QVariantMap drei = d.wikiImportieren(sich, true);
            QCOMPARE(drei.value("neu").toInt(), 1);                          // nur der abweichende Artikel
            QCOMPARE(drei.value("umbenannt").toInt(), 1);
            QCOMPARE(wert("SELECT inhalt FROM wiki_artikel WHERE titel = 'Eigen'").toString(), QString("lokal geaendert"));
            QCOMPARE(artikelAnzahl("Eigen (Import)"), 1);
            const QVariantMap vier = d.wikiImportieren(sich, true);        // wiederholbar
            QCOMPARE(vier.value("neu").toInt(), 0);
            QCOMPARE(artikelAnzahl("Eigen (Import)"), 1);
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        QDir(q).removeRecursively(); QDir(z).removeRecursively();
    }

    // Bundle-Datei im gemeinsamen Import: Versionsvergleich greift, ältere/gleiche Version ändert nichts (B4)
    void test_03_bundleImportVersionsvergleich()
    {
        const QString q = neuerOrdner("q3"), z = neuerOrdner("z3");
        const QString sich = q + "/sicherung.json", bund = q + "/bundle.json";
        quelleBauen(q, sich, bund);
        QSqlDatabase::removeDatabase("stroemling_wiki");
        const QJsonObject b = lesen(bund);
        QCOMPARE(b.value("bundle_kennung").toString(), QString("firma"));
        QCOMPARE(b.value("bundle_version").toInt(), 2);
        {
            Database d;
            QVERIFY(d.openWiki(z + "/wiki.db"));
            const QVariantMap r1 = d.wikiImportieren(bund, false);          // mergeMode ohne Wirkung bei Bundle
            QCOMPARE(r1.value("art").toString(), QString("bundle"));
            QCOMPARE(r1.value("neu").toInt(), 1);
            QCOMPARE(wert("SELECT bundle_kennung FROM wiki_artikel WHERE titel = 'Eigen'").toString(), QString("firma"));
            const QVariantMap r2 = d.wikiImportieren(bund, true);
            QVERIFY(r2.value("erfolg").toBool());
            QCOMPARE(r2.value("neu").toInt(), 0);
            QVERIFY(r2.value("meldung").toString().contains("aktuell"));
            QCOMPARE(artikelAnzahl("Eigen"), 1);
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        QDir(q).removeRecursively(); QDir(z).removeRecursively();
    }

    // Bundle-Export: Pflichtfelder, eigene Artikel enthalten, Artikel installierter Bundles nicht; Hinweiszahl
    void test_04_bundleExportRegeln()
    {
        const QString q = neuerOrdner("q4");
        {
            Database d;
            QVERIFY(d.openWiki(q + "/wiki.db"));
            const int kat = katAnlegen("K4");
            artikel(kat, "Meins", "a");
            artikel(kat, "Fremd", "b", "andere", 0);
            QCOMPARE(d.wikiBundleFremdArtikelAnzahl({ kat }), 1);
            QVERIFY(!d.wikiExportieren(q + "/x.json", { { "bundle", true }, { "kennung", "" }, { "version", 1 }, { "kategorieIds", QVariantList { kat } } })
                         .value("erfolg").toBool());
            QVERIFY(!d.wikiExportieren(q + "/x.json", { { "bundle", true }, { "kennung", "k" }, { "version", 0 }, { "kategorieIds", QVariantList { kat } } })
                         .value("erfolg").toBool());
            QVERIFY(!d.wikiExportieren(q + "/x.json", { { "bundle", true }, { "kennung", "k" }, { "version", 1 } }).value("erfolg").toBool());
            QVERIFY(d.wikiExportieren(q + "/ok.json", { { "bundle", true }, { "kennung", "k" }, { "titel", "T" }, { "version", 1 },
                                                         { "kategorieIds", QVariantList { kat } } }).value("erfolg").toBool());
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        const QJsonObject b = lesen(q + "/ok.json");
        QCOMPARE(b.value("artikel").toArray().size(), 1);
        QCOMPARE(b.value("artikel").toArray().at(0).toObject().value("titel").toString(), QString("Meins"));
        QVERIFY(!b.value("artikel").toArray().at(0).toObject().contains("bundle_kennung"));
        QDir(q).removeRecursively();
    }

    // Altes Sicherungsformat (ohne neue Felder) bleibt lesbar; Ersetzen löscht Nutzer- und Bundle-Artikel samt Bundle-Ständen
    void test_05_altesFormatUndErsetzen()
    {
        const QString z = neuerOrdner("z5");
        QJsonObject alt;
        alt["wiki_export_version"] = 1;
        alt["kategorien"] = QJsonArray { QJsonObject { { "id", 7 }, { "name", "AltKat" }, { "sortierung", 1 } } };
        alt["artikel"] = QJsonArray { QJsonObject { { "id", 5 }, { "kategorie_id", 7 }, { "kategorie_name", "AltKat" },
                                                     { "titel", "Alt" }, { "inhalt", "alt" }, { "tags", "" } } };
        alt["bilder"] = QJsonArray();
        schreiben(z + "/alt.json", alt);
        {
            Database d;
            QVERIFY(d.openWiki(z + "/wiki.db"));
            const int kat = katAnlegen("Lokal");
            artikel(kat, "Lokal", "x");
            artikel(kat, "Bundleartikel", "y", "b9", 0);
            ex("INSERT OR REPLACE INTO wiki_meta (schluessel, wert) VALUES ('bundle_version_b9', '5')");
            const QVariantMap r = d.wikiImportieren(z + "/alt.json", false);   // Ersetzen
            QVERIFY2(r.value("erfolg").toBool(), qPrintable(r.value("meldung").toString()));
            QCOMPARE(r.value("neu").toInt(), 1);
            QCOMPARE(artikelAnzahl("Alt"), 1);
            QCOMPARE(artikelAnzahl("Lokal"), 0);
            QCOMPARE(artikelAnzahl("Bundleartikel"), 0);
            QCOMPARE(wert("SELECT COUNT(*) FROM wiki_meta WHERE schluessel = 'bundle_version_b9'").toInt(), 0);
            QVERIFY(!d.wikiImportieren(z + "/nichtda.json", true).value("erfolg").toBool());
        }
        QSqlDatabase::removeDatabase("stroemling_wiki");
        QDir(z).removeRecursively();
    }
};
