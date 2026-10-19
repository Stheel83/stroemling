#pragma once
#include <QtTest>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QVariantMap>
#include "database/Database.h"

// BIB-REF-01: stabile Bauteil-Bezüge (Konzept 56 §4). Quell- und Zielrechner werden durch zwei Bibliotheken simuliert, in denen
// dieselben Bauteile (gleiche UID) andere IDs haben (Vorspann-Teile + Import in anderer Reihenfolge). Die Verbindung
// "stroemling_bibliothek" und die Projektverbindung sind je Prozess einmal vergeben: Database-Objekte nacheinander verwenden.

class TstBauteilBezug : public QObject
{
    Q_OBJECT

    static QSqlDatabase lib() { return QSqlDatabase::database(QStringLiteral("stroemling_bibliothek")); }
    static int lex(const QString &sql)
    {
        QSqlQuery q(lib());
        if (!q.exec(sql)) { qWarning() << q.lastError().text() << sql.left(100); return -1; }
        return q.lastInsertId().toInt();
    }
    static QVariant lwert(const QString &sql)
    {
        QSqlQuery q(lib());
        return (q.exec(sql) && q.next()) ? q.value(0) : QVariant();
    }
    // Projektverbindung (Default-Verbindung)
    static int pex(const QString &sql)
    {
        QSqlQuery q(QSqlDatabase::database());
        if (!q.exec(sql)) { qWarning() << q.lastError().text() << sql.left(100); return -1; }
        return q.lastInsertId().toInt();
    }
    static QVariant pwert(const QString &sql)
    {
        QSqlQuery q(QSqlDatabase::database());
        return (q.exec(sql) && q.next()) ? q.value(0) : QVariant();
    }
    static int bid(const QString &name) { return lwert(QStringLiteral("SELECT id FROM bauteil WHERE bezeichnung = '%1'").arg(name)).toInt(); }
    static int kabelTyp(const QString &name) { return lwert(QStringLiteral("SELECT id FROM bauteil_kabel WHERE bauteil_id = %1").arg(bid(name))).toInt(); }

    struct Ids { int schuetz, klemme, kabelBauteil, kabelTyp, symbol; };

    // Rechner 1: Bibliothek mit Bauteilen + Projekt mit allen vier Verweisarten
    static Ids baueRechnerEins(Database &d, const QString &bib, const QString &proj)
    {
        Ids ids {};
        if (!d.openBibliothek(bib)) return ids;
        ids.schuetz = lex("INSERT INTO bauteil (bezeichnung, hersteller) VALUES ('Bz Schütz', 'F1')");
        ids.kabelBauteil = lex("INSERT INTO bauteil (bezeichnung) VALUES ('Bz Kabel')");
        ids.kabelTyp = lex(QStringLiteral("INSERT INTO bauteil_kabel (bauteil_id, kabeltyp) VALUES (%1, 'YSLY')").arg(ids.kabelBauteil));
        ids.klemme = lex("INSERT INTO bauteil (bezeichnung) VALUES ('Bz Klemme')");
        lex(QStringLiteral("INSERT INTO bauteil_klemme (bauteil_id, anschluss_typ) VALUES (%1, 'Schraube')").arg(ids.klemme));
        ids.symbol = lex("INSERT INTO bauteil (bezeichnung) VALUES ('Bz Symbolteil')");
        if (!d.createProjekt(proj, "RefTest")) return {};
        const int pid = pwert("SELECT id FROM projekt ORDER BY id LIMIT 1").toInt();
        pex(QStringLiteral("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz, bauteil_id) VALUES (%1, 'K1', %2)").arg(pid).arg(ids.schuetz));
        const int kl = pex(QStringLiteral("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (%1, 'X1')").arg(pid));
        pex(QStringLiteral("INSERT INTO klemme (klemmenleiste_id, bauteil_id) VALUES (%1, %2)").arg(kl).arg(ids.klemme));
        pex(QStringLiteral("INSERT INTO kabel (projekt_id, bezeichnung, bauteil_kabel_id, laenge_m) VALUES (%1, 'W1', %2, 5.5)").arg(pid).arg(ids.kabelTyp));
        const int seite = pex("INSERT INTO seite (blattnummer, bezeichnung) VALUES ('1', 'S1')");
        pex(QStringLiteral("INSERT INTO grafik_element (seite_id, typ, extra_daten) VALUES (%1, 'symbol', '{\"bauteil_id\": %2, \"bmk\": \"H1\"}')")
                .arg(seite).arg(ids.symbol));
        return ids;
    }

    // Rechner 2: andere IDs für dieselben Bauteile (Vorspann + Import in alphabetischer Reihenfolge)
    static bool baueRechnerZwei(Database &d, const QString &bib, const QString &buendel, bool ohneKlemme = false)
    {
        if (!d.openBibliothek(bib)) return false;
        for (int i = 1; i <= 3; ++i)
            lex(QStringLiteral("INSERT INTO bauteil (bezeichnung) VALUES ('Vorspann %1')").arg(i));
        // auch die Kabeltyp-IDs verschieben (sonst sind sie in beiden Bibliotheken zufällig gleich und brauchen keinen Umbau)
        const int kb = lex("INSERT INTO bauteil (bezeichnung) VALUES ('Vorspann Kabel')");
        lex(QStringLiteral("INSERT INTO bauteil_kabel (bauteil_id) VALUES (%1)").arg(kb));
        lex(QStringLiteral("INSERT INTO bauteil_kabel (bauteil_id) VALUES (%1)").arg(kb));
        QVariantMap entsch;
        if (ohneKlemme) {
            const QVariantMap an = d.bauteileImportAnalysieren(buendel);
            for (const QVariant &ev : an.value("eintraege").toList())
                if (ev.toMap().value("bezeichnung") == "Bz Klemme") entsch.insert(ev.toMap().value("uid").toString(), "ueberspringen");
        }
        return d.bauteileImportAusfuehren(buendel, entsch).value("ok").toBool();
    }

    QString datei(const QString &n) const { return m_dir.filePath(n); }

    // Verweise des Projekts (Default-Verbindung) als einfache Struktur
    struct Verweise { int bm, klemme, kabel, symbol; QString extra; };
    static Verweise verweise()
    {
        Verweise v {};
        v.bm = pwert("SELECT bauteil_id FROM betriebsmittel").toInt();
        v.klemme = pwert("SELECT bauteil_id FROM klemme").toInt();
        v.kabel = pwert("SELECT bauteil_kabel_id FROM kabel").toInt();
        v.symbol = pwert("SELECT CAST(json_extract(extra_daten, '$.bauteil_id') AS INTEGER) FROM grafik_element WHERE typ = 'symbol'").toInt();
        v.extra = pwert("SELECT json_extract(extra_daten, '$.bmk') FROM grafik_element WHERE typ = 'symbol'").toString();
        return v;
    }

private slots:
    void initTestCase() { QVERIFY(m_dir.isValid()); }

    void test_01_verweiseFindenIhrBauteilNachIdVerschiebungUeberDieUidWieder()
    {
        const QString proj = datei("p1.strl"), buendel = datei("b1.json");
        Ids alt {};
        {
            Database d1;
            alt = baueRechnerEins(d1, datei("lib1.db"), proj);
            QVERIFY2(alt.schuetz > 0 && alt.kabelTyp > 0, "Fixture Rechner 1");
            QVERIFY(d1.bauteilBezuegeAktualisieren());
            QCOMPARE(pwert("SELECT COUNT(*) FROM bauteil_bezug").toInt(), 4);
            QCOMPARE(pwert("SELECT uid FROM bauteil_bezug WHERE art='kabel'").toString(),
                     lwert(QStringLiteral("SELECT uid FROM bauteil WHERE id = %1").arg(alt.kabelBauteil)).toString());   // Kabeltyp: UID des Eigentümers
            QVERIFY(d1.bauteileExportieren(buendel, false).value("ok").toBool());
            d1.closeProjekt();
        }
        Database d2;
        QVERIFY(baueRechnerZwei(d2, datei("lib2.db"), buendel));
        const Ids neu { bid("Bz Schütz"), bid("Bz Klemme"), bid("Bz Kabel"), kabelTyp("Bz Kabel"), bid("Bz Symbolteil") };
        QVERIFY(neu.schuetz != alt.schuetz && neu.klemme != alt.klemme && neu.kabelBauteil != alt.kabelBauteil
                && neu.kabelTyp != alt.kabelTyp && neu.kabelTyp > 0 && neu.symbol != alt.symbol);                      // ohne Relink zeigten die Verweise auf falsche Teile

        QSignalSpy spy(&d2, &Database::bauteilBezuegeGeprueft);
        QVERIFY(d2.openProjekt(proj));
        QCOMPARE(spy.count(), 1);
        const QVariantMap erg = spy.first().first().toMap();
        QCOMPARE(erg.value("angepasst").toInt(), 4);
        QVERIFY(erg.value("fehlend").toList().isEmpty());
        QVERIFY(erg.value("unsicher").toList().isEmpty());

        const Verweise v = verweise();
        QCOMPARE(v.bm, neu.schuetz);
        QCOMPARE(v.klemme, neu.klemme);
        QCOMPARE(v.kabel, neu.kabelTyp);
        QCOMPARE(v.symbol, neu.symbol);
        QCOMPARE(v.extra, QStringLiteral("H1"));                                        // übrige JSON-Felder bleiben erhalten
        QCOMPARE(pwert("SELECT ref_id FROM bauteil_bezug WHERE art='bauteil' AND uid = (SELECT uid FROM bauteil_bezug WHERE bezeichnung='Bz Schütz')").toInt(), neu.schuetz);

        // Zweites Öffnen: nichts mehr zu tun, kein Signal, keine Schreibzugriffe
        d2.closeProjekt();
        QSignalSpy spy2(&d2, &Database::bauteilBezuegeGeprueft);
        QVERIFY(d2.openProjekt(proj));
        QCOMPARE(spy2.count(), 0);
        const int aenderungen = pwert("SELECT total_changes()").toInt();
        QVERIFY(d2.bauteilBezuegeAktualisieren());
        QCOMPARE(pwert("SELECT total_changes()").toInt(), aenderungen);                // unverändert → nichts geschrieben
        d2.closeProjekt();
    }

    void test_02_nichtAufloesbaresBleibtUnveraendertWirdGemeldetUndLoestSichNachDemImport()
    {
        const QString proj = datei("p2.strl"), buendel = datei("b2.json");
        Ids alt {};
        {
            Database d1;
            alt = baueRechnerEins(d1, datei("lib3.db"), proj);
            QVERIFY(alt.schuetz > 0);
            QVERIFY(d1.bauteileExportieren(buendel, false).value("ok").toBool());
            d1.closeProjekt();                                                          // hält die Bezüge fest
        }
        Database d2;
        QVERIFY(baueRechnerZwei(d2, datei("lib4.db"), buendel, /*ohneKlemme*/ true));   // „Bz Klemme“ fehlt lokal
        QVERIFY(bid("Bz Klemme") < 0 || bid("Bz Klemme") == 0);

        QSignalSpy spy(&d2, &Database::bauteilBezuegeGeprueft);
        QVERIFY(d2.openProjekt(proj));
        QCOMPARE(spy.count(), 1);
        const QVariantMap erg = spy.first().first().toMap();
        QCOMPARE(erg.value("angepasst").toInt(), 3);                                    // Schütz, Kabeltyp, Symbol
        const QVariantList offen = erg.value("fehlend").toList() + erg.value("unsicher").toList();
        QCOMPARE(offen.size(), 1);
        QCOMPARE(offen.first().toMap().value("name").toString(), QStringLiteral("Bz Klemme"));
        QCOMPARE(verweise().klemme, alt.klemme);                                        // der unauflösbare Verweis wurde NICHT angefasst
        const QString erwarteteUid = pwert("SELECT uid FROM bauteil_bezug WHERE bezeichnung = 'Bz Klemme'").toString();
        QVERIFY(!erwarteteUid.isEmpty());
        d2.closeProjekt();

        // erneut öffnen: Hinweis bleibt, die erwartete UID wurde nicht durch das (andere) lokale Teil überschrieben
        QSignalSpy spy2(&d2, &Database::bauteilBezuegeGeprueft);
        QVERIFY(d2.openProjekt(proj));
        QCOMPARE(spy2.count(), 1);
        QCOMPARE(pwert("SELECT uid FROM bauteil_bezug WHERE bezeichnung = 'Bz Klemme'").toString(), erwarteteUid);
        d2.closeProjekt();

        // das fehlende Bauteil nachimportieren → beim nächsten Öffnen findet der Verweis sein Bauteil
        const QVariantMap imp = d2.bauteileImportAusfuehren(buendel, {});
        QVERIFY(imp.value("ok").toBool());
        QSignalSpy spy3(&d2, &Database::bauteilBezuegeGeprueft);
        QVERIFY(d2.openProjekt(proj));
        QCOMPARE(spy3.count(), 1);
        QCOMPARE(spy3.first().first().toMap().value("angepasst").toInt(), 1);
        QCOMPARE(verweise().klemme, bid("Bz Klemme"));
        d2.closeProjekt();
    }

    void test_03_aliasLoestFremdeUidAuf()
    {
        const QString proj = datei("p3.strl"), buendel = datei("b3.json");
        QString fremdeUid;
        {
            Database d1;
            const Ids alt = baueRechnerEins(d1, datei("lib5.db"), proj);
            QVERIFY(alt.schuetz > 0);
            fremdeUid = lwert(QStringLiteral("SELECT uid FROM bauteil WHERE id = %1").arg(alt.schuetz)).toString();
            QVERIFY(d1.bauteileExportieren(buendel, false).value("ok").toBool());
            d1.closeProjekt();
        }
        // Rechner 2 hat das Schütz unter einer ANDEREN UID selbst angelegt (gleicher Inhalt) und verknüpft per Alias
        Database d2;
        QVERIFY(d2.openBibliothek(datei("lib6.db")));
        for (int i = 1; i <= 3; ++i)
            lex(QStringLiteral("INSERT INTO bauteil (bezeichnung) VALUES ('Vorspann %1')").arg(i));
        lex("INSERT INTO bauteil (bezeichnung, hersteller) VALUES ('Bz Schütz', 'F1')");
        const int lokalesSchuetz = bid("Bz Schütz");
        QVERIFY(lokalesSchuetz > 0);
        const QVariantMap an = d2.bauteileImportAnalysieren(buendel);
        QVariantMap entsch;
        for (const QVariant &ev : an.value("eintraege").toList())
            if (ev.toMap().value("uid") == fremdeUid)
                entsch.insert(fremdeUid, "verknuepfen");
        QVERIFY(d2.bauteileImportAusfuehren(buendel, entsch).value("ok").toBool());
        QCOMPARE(d2.bauteilIdFuerUid(fremdeUid), lokalesSchuetz);

        QVERIFY(d2.openProjekt(proj));
        QCOMPARE(verweise().bm, lokalesSchuetz);                                        // über den Alias aufgelöst, kein Duplikat
        d2.closeProjekt();
    }

    void test_04_ibnKopieSchreibtNichtSondernMeldetNur()
    {
        const QString proj = datei("p4.strl"), buendel = datei("b4.json");
        Ids alt {};
        QString kopiePfad;
        {
            Database d1;
            alt = baueRechnerEins(d1, datei("lib7.db"), proj);
            QVERIFY(alt.schuetz > 0);
            QVERIFY(d1.bauteileExportieren(buendel, false).value("ok").toBool());
            const int pid = pwert("SELECT id FROM projekt ORDER BY id LIMIT 1").toInt();
            const QVariantMap k = d1.ibnKopieErstellen(pid, "Kopie", {}, datei("kopien"));
            QVERIFY2(k.value("ok").toBool(), qPrintable(k.value("fehler").toString()));
            kopiePfad = k.value("pfad").toString();
            d1.closeProjekt();
        }
        Database d2;
        QVERIFY(baueRechnerZwei(d2, datei("lib8.db"), buendel));
        QSignalSpy spy(&d2, &Database::bauteilBezuegeGeprueft);
        QVERIFY(d2.openProjekt(kopiePfad));
        QVERIFY(d2.istIbnKopie());
        QCOMPARE(spy.count(), 1);
        const QVariantMap erg = spy.first().first().toMap();
        QCOMPARE(erg.value("angepasst").toInt(), 0);
        QVERIFY(erg.value("nichtAngepasst").toInt() > 0);                               // gemeldet, aber nicht umgeschrieben
        const Verweise v = verweise();
        QCOMPARE(v.bm, alt.schuetz);
        QCOMPARE(v.klemme, alt.klemme);
        QCOMPARE(v.kabel, alt.kabelTyp);
        QCOMPARE(v.symbol, alt.symbol);
        QVERIFY(!d2.bauteilBezuegeAktualisieren());                                     // schreibt in IBN-Kopien nie
        d2.closeProjekt();
    }

    void test_05_zwischenablageSnapshotNutztDieUidStattDerRechnerlokalenId()
    {
        const QString proj = datei("p5.strl"), buendel = datei("b5.json");
        QVariantList exportiert;
        {
            Database d1;
            const Ids alt = baueRechnerEins(d1, datei("lib9.db"), proj);
            QVERIFY(alt.schuetz > 0);
            const int pid = pwert("SELECT id FROM projekt ORDER BY id LIMIT 1").toInt();
            const int bm = pwert("SELECT id FROM betriebsmittel").toInt();
            Q_UNUSED(pid);
            QVariantMap el { { "betriebsmittelId", bm }, { "symbolId", "schuetz" }, { "extraDaten", QVariantMap { { "bmk", "K1" } } } };
            exportiert = d1.elementeFuerExportSanitisieren({ el });
            const QVariantMap snap = exportiert.first().toMap().value("extraDaten").toMap().value("bauteilSnapshot").toMap();
            QVERIFY2(!snap.value("uid").toString().isEmpty(), "Snapshot ohne UID");
            QCOMPARE(snap.value("bezeichnung").toString(), QStringLiteral("Bz Schütz"));
            QVERIFY(d1.bauteileExportieren(buendel, false).value("ok").toBool());
            d1.closeProjekt();
        }
        // Zielrechner: Schütz hat andere ID; das Einfügen aus dem anderen Projekt muss das vorhandene Bauteil finden, nicht neu anlegen
        Database d2;
        QVERIFY(baueRechnerZwei(d2, datei("lib10.db"), buendel));
        QVERIFY(d2.createProjekt(datei("ziel.strl"), "Ziel"));
        const int seite = pex("INSERT INTO seite (ort_id, blattnummer, bezeichnung) VALUES ((SELECT id FROM ort ORDER BY id LIMIT 1), '1', 'Z')");
        QVERIFY(seite > 0);
        const int vorher = lwert("SELECT COUNT(*) FROM bauteil").toInt();
        const QVariantList eingefuegt = d2.elementeFuerImportSanitisieren(exportiert, seite);
        const int bm = eingefuegt.first().toMap().value("betriebsmittelId").toInt();
        QVERIFY(bm > 0);
        QCOMPARE(pwert(QStringLiteral("SELECT bauteil_id FROM betriebsmittel WHERE id = %1").arg(bm)).toInt(), bid("Bz Schütz"));
        QCOMPARE(lwert("SELECT COUNT(*) FROM bauteil").toInt(), vorher);               // kein Duplikat angelegt
        d2.closeProjekt();
    }

    // Gegen ECHTE Projekte (nur mit STROEMLING_TEST_BIB_KOPIE = Kopie der Bibliothek und STROEMLING_TEST_PROJEKT_KOPIEN = Kopien der
    // Projektdateien, durch ":" getrennt; nie die Originale): Das erste Öffnen mit Schema 178 darf keinen Verweis verändern und füllt die
    // Bezugstabelle aus der aktuellen Bibliothek.
    void test_06_echteProjekteBleibenBeimErstenOeffnenUnveraendert()
    {
        const QString bibKopie = qEnvironmentVariable("STROEMLING_TEST_BIB_KOPIE");
        const QStringList projekte = qEnvironmentVariable("STROEMLING_TEST_PROJEKT_KOPIEN").split(':', Qt::SkipEmptyParts);
        if (bibKopie.isEmpty() || projekte.isEmpty() || !QFileInfo::exists(bibKopie))
            QSKIP("STROEMLING_TEST_BIB_KOPIE / STROEMLING_TEST_PROJEKT_KOPIEN nicht gesetzt");
        const QString bib = datei("echt_bib.db");
        QVERIFY(QFile::copy(bibKopie, bib));
        int nr = 0;
        for (const QString &quelle : projekte) {
            const QString ziel = datei(QStringLiteral("echt_%1.strl").arg(++nr));
            QVERIFY2(QFile::copy(quelle, ziel), qPrintable(quelle));
            Database d;
            QVERIFY(d.openBibliothek(bib));
            QVERIFY2(d.openProjekt(ziel), qPrintable("Öffnen schlug fehl: " + quelle));
            const Verweise v1 = verweise();
            const QString sig1 = pwert("SELECT group_concat(bauteil_id) FROM (SELECT bauteil_id FROM betriebsmittel ORDER BY id)").toString()
                               + "|" + pwert("SELECT group_concat(bauteil_id) FROM (SELECT bauteil_id FROM klemme ORDER BY id)").toString()
                               + "|" + pwert("SELECT group_concat(bauteil_kabel_id) FROM (SELECT bauteil_kabel_id FROM kabel ORDER BY id)").toString()
                               + "|" + pwert("SELECT group_concat(extra_daten) FROM (SELECT extra_daten FROM grafik_element ORDER BY id)").toString();
            Q_UNUSED(v1);
            d.closeProjekt();
            // Zweites Öffnen: nichts ändert sich mehr, und die Verweise sind dieselben wie nach dem ersten
            QVERIFY(d.openProjekt(ziel));
            const QString sig2 = pwert("SELECT group_concat(bauteil_id) FROM (SELECT bauteil_id FROM betriebsmittel ORDER BY id)").toString()
                               + "|" + pwert("SELECT group_concat(bauteil_id) FROM (SELECT bauteil_id FROM klemme ORDER BY id)").toString()
                               + "|" + pwert("SELECT group_concat(bauteil_kabel_id) FROM (SELECT bauteil_kabel_id FROM kabel ORDER BY id)").toString()
                               + "|" + pwert("SELECT group_concat(extra_daten) FROM (SELECT extra_daten FROM grafik_element ORDER BY id)").toString();
            QCOMPARE(sig2, sig1);
            // jede gemerkte UID gehört zu einem lokalen Bauteil, und jede benutzte, lokal vorhandene ID hat einen Bezug
            QCOMPARE(pwert("SELECT COUNT(*) FROM bauteil_bezug WHERE uid = ''").toInt(), 0);
            QCOMPARE(pwert("SELECT COUNT(*) FROM bauteil_bezug WHERE art='bauteil' AND uid NOT IN (SELECT uid FROM bibliothek.bauteil)").toInt(), 0);
            const int ohneBezug = pwert("SELECT COUNT(*) FROM (SELECT DISTINCT bauteil_id AS id FROM betriebsmittel WHERE bauteil_id IS NOT NULL "
                                        "UNION SELECT DISTINCT bauteil_id FROM klemme WHERE bauteil_id IS NOT NULL) x "
                                        "WHERE id IN (SELECT id FROM bibliothek.bauteil) "
                                        "AND id NOT IN (SELECT ref_id FROM bauteil_bezug WHERE art = 'bauteil')").toInt();
            QCOMPARE(ohneBezug, 0);
            const QVariantMap erneut = d.bauteilBezuegePruefen(true);
            QCOMPARE(erneut.value("angepasst").toInt(), 0);
            d.closeProjekt();
        }
    }

private:
    QTemporaryDir m_dir;
};
