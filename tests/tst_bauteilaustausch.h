#pragma once
#include <QtTest>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QVariantMap>
#include "database/Database.h"

// BIB-IMPORT-01: Export/Import der Bauteil-Bibliothek (Konzept 56). Alle Tests arbeiten mit temporären Bibliotheken und
// Fantasiebauteilen; die Datenbankverbindung "stroemling_bibliothek" ist je Prozess nur einmal vergeben, daher werden
// Quell- und Zielbibliothek nacheinander (nicht gleichzeitig) geöffnet.

class TstBauteilAustausch : public QObject
{
    Q_OBJECT

    static QSqlDatabase lib() { return QSqlDatabase::database(QStringLiteral("stroemling_bibliothek")); }

    // Führt SQL aus und gibt die neue ID zurück (-1 bei Fehler)
    static int ex(const QString &sql)
    {
        QSqlQuery q(lib());
        if (!q.exec(sql)) {
            qWarning() << q.lastError().text() << sql.left(120);
            return -1;
        }
        return q.lastInsertId().toInt();
    }
    static QVariant wert(const QString &sql)
    {
        QSqlQuery q(lib());
        return (q.exec(sql) && q.next()) ? q.value(0) : QVariant();
    }
    static QString uidVon(const QString &bezeichnung)
    {
        QSqlQuery q(lib());
        q.prepare("SELECT uid FROM bauteil WHERE bezeichnung = ?");
        q.addBindValue(bezeichnung);
        return (q.exec() && q.next()) ? q.value(0).toString() : QString();
    }
    static int idVon(const QString &bezeichnung)
    {
        return wert(QStringLiteral("SELECT id FROM bauteil WHERE bezeichnung = '%1' ORDER BY id LIMIT 1").arg(QString(bezeichnung).replace("'", "''"))).toInt();
    }

    // Fantasie-Bibliothek mit allen Untertypen und Querverweisen (keine mitgelieferten Seeds außer denen von openBibliothek)
    static void baueFixture()
    {
        const int kat1 = ex("INSERT INTO bauteil_kategorie (name) VALUES ('Austausch-Test')");
        const int kat2 = ex(QStringLiteral("INSERT INTO bauteil_kategorie (name, parent_id) VALUES ('Schütze', %1)").arg(kat1));
        ex(QStringLiteral("INSERT INTO bauteil (kategorie_id, bezeichnung, hersteller, artikelnummer, preis_eur, norm) "
                          "VALUES (%1, 'T Schütz 3-polig', 'Testfabrik', 'TF-100', 12.5, 'IEC 60947')").arg(kat2));

        const int kabel = ex("INSERT INTO bauteil (bezeichnung, hersteller) VALUES ('T Steuerleitung 4x1,5', 'Kabelwerk')");
        const int kabelTyp = ex(QStringLiteral("INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt) VALUES (%1, 'YSLY', 1)").arg(kabel));
        for (int i = 1; i <= 4; ++i)
            ex(QStringLiteral("INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, querschnitt_mm2) VALUES (%1, %2, 'braun', 1.5)").arg(kabelTyp).arg(i));
        ex(QStringLiteral("INSERT INTO bauteil_kabel_paar (kabel_id, paar_nr, ader_a, ader_b) VALUES (%1, 1, 1, 2)").arg(kabelTyp));

        const int farbe = ex("INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) VALUES ('#123456', 'T Testgrau', 0, 77)");
        Q_UNUSED(farbe);
        const int klemme = ex("INSERT INTO bauteil (bezeichnung) VALUES ('T Reihenklemme')");
        const int klemmeTyp = ex(QStringLiteral("INSERT INTO bauteil_klemme (bauteil_id, anschluss_typ, ebenen_anzahl, gehaeuse_farbe_id) "
                                                "VALUES (%1, 'Schraube', 2, (SELECT id FROM farb_definition WHERE bezeichnung='T Testgrau'))").arg(klemme));
        ex(QStringLiteral("INSERT INTO bauteil_klemme_querschnitt (klemme_id, adertyp, min_mm2, max_mm2) VALUES (%1, 'starr', 0.5, 4)").arg(klemmeTyp));
        ex(QStringLiteral("INSERT INTO bauteil_klemme_querschnitt (klemme_id, adertyp, min_mm2, max_mm2) VALUES (%1, 'flexibel', 0.5, 2.5)").arg(klemmeTyp));
        ex(QStringLiteral("INSERT INTO bauteil_klemme_bruecke (klemme_id, von_ebene, nach_ebene) VALUES (%1, 1, 2)").arg(klemmeTyp));
        ex(QStringLiteral("INSERT INTO bauteil_klemme_eigenschaft (klemme_id, schluessel, wert) VALUES (%1, 'Farbe', 'grau')").arg(klemmeTyp));

        const int kontaktBauteil = ex("INSERT INTO bauteil (bezeichnung) VALUES ('T Kontakt Stift')");
        const int ktTyp = ex(QStringLiteral("INSERT INTO kontakt_typ (bauteil_id, geschlecht, nennstrom_a) VALUES (%1, 'stift', 8)").arg(kontaktBauteil));
        const int stecker = ex("INSERT INTO bauteil (bezeichnung) VALUES ('T M12-Stecker 4-polig')");
        const int svTyp = ex(QStringLiteral("INSERT INTO steckverbinder_typ (bauteil_id, polzahl, montageform) VALUES (%1, 4, 'Kabel')").arg(stecker));
        ex(QStringLiteral("INSERT INTO steckverbinder_kabeleinf (steckverbinder_typ_id, einf_nr, aussen_min_mm, aussen_max_mm) VALUES (%1, 1, 4, 8)").arg(svTyp));
        ex(QStringLiteral("INSERT INTO steckverbinder_position (steckverbinder_typ_id, position_nr, kontakt_typ_id, ist_schirmkontakt) VALUES (%1, 1, %2, 0)").arg(svTyp).arg(ktTyp));
        ex(QStringLiteral("INSERT INTO steckverbinder_position (steckverbinder_typ_id, position_nr, kontakt_typ_id, ist_schirmkontakt) VALUES (%1, 2, %2, 1)").arg(svTyp).arg(ktTyp));

        const int konf = ex("INSERT INTO bauteil (bezeichnung) VALUES ('T Anschlussleitung konfektioniert')");
        const int konfTyp = ex(QStringLiteral("INSERT INTO konfektioniertes_kabel (bauteil_id, bauteil_kabel_id, stecker_a_bauteil_id, stecker_b_bauteil_id, laenge_m) "
                                              "VALUES (%1, %2, %3, %3, 2.5)").arg(konf).arg(kabelTyp).arg(stecker));
        ex(QStringLiteral("INSERT INTO konfkabel_pin_zuordnung (konfkabel_id, seite, ader_nr, pin_nr) VALUES (%1, 'A', 1, 1)").arg(konfTyp));
        ex(QStringLiteral("INSERT INTO konfkabel_pin_zuordnung (konfkabel_id, seite, ader_nr, pin_nr) VALUES (%1, 'B', 1, 2)").arg(konfTyp));

        const int geraet = ex("INSERT INTO bauteil (bezeichnung) VALUES ('T Relais mit Kontakten')");
        ex(QStringLiteral("INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung) VALUES (%1, 'schliesser', 'K1')").arg(geraet));
        ex("INSERT INTO bauteil (bezeichnung, ist_system) VALUES ('T Systemteil', 1)");
    }

    static QStringList testNamen()
    {
        return { "T Schütz 3-polig", "T Steuerleitung 4x1,5", "T Reihenklemme", "T Kontakt Stift", "T M12-Stecker 4-polig",
                 "T Anschlussleitung konfektioniert", "T Relais mit Kontakten" };
    }

    QString datei(const QString &n) const { return m_dir.filePath(n); }

private slots:
    void initTestCase() { QVERIFY(m_dir.isValid()); }

    void test_01_roundtripUeberZweiBibliothekenErhaeltIdentitaetUndInhalt()
    {
        const QString bund = datei("a.json");
        QStringList uidsA;
        {
            Database a;
            QVERIFY(a.openBibliothek(datei("lib_a.db")));
            baueFixture();
            for (const QString &n : testNamen())
                uidsA << uidVon(n);
            const QVariantMap e = a.bauteileExportieren(bund, false);
            QVERIFY2(e.value("ok").toBool(), qPrintable(e.value("fehler").toString()));
            QCOMPARE(e.value("anzahl").toInt(), 7);                     // ohne das Systemteil
            QCOMPARE(a.bauteileExportieren(datei("a_mit.json"), true).value("anzahl").toInt() > 7, true);
        }
        for (const QString &u : uidsA)
            QVERIFY2(!u.isEmpty(), "Fixture-Bauteil ohne UID");

        Database b;
        QVERIFY(b.openBibliothek(datei("lib_b.db")));
        QVariantMap an = b.bauteileImportAnalysieren(bund);
        QVERIFY2(an.value("ok").toBool(), qPrintable(an.value("fehler").toString()));
        QCOMPARE(an.value("anzahlNeu").toInt(), 7);
        for (const QVariant &ev : an.value("eintraege").toList()) {
            QCOMPARE(ev.toMap().value("status").toString(), QStringLiteral("neu"));
            QCOMPARE(ev.toMap().value("vorschlag").toString(), QStringLiteral("anlegen"));
        }
        const QVariantMap erg = b.bauteileImportAusfuehren(bund, {});
        QVERIFY2(erg.value("ok").toBool(), qPrintable(erg.value("fehler").toString() + erg.value("warnungen").toStringList().join("|")));
        QCOMPARE(erg.value("angelegt").toInt(), 7);
        QVERIFY(erg.value("warnungen").toStringList().isEmpty());
        QVERIFY2(QFile::exists(erg.value("sicherung").toString()), "keine Sicherung vor dem Import");

        // Identität erhalten: dieselben UIDs wie in der Quelle
        for (int i = 0; i < testNamen().size(); ++i)
            QCOMPARE(uidVon(testNamen().at(i)), uidsA.at(i));

        // Inhalt vollständig und Querverweise aufgelöst
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil_kabel_ader WHERE kabel_id = (SELECT id FROM bauteil_kabel WHERE bauteil_id = (SELECT id FROM bauteil WHERE bezeichnung='T Steuerleitung 4x1,5'))").toInt(), 4);
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil_kabel_paar").toInt() >= 1, true);
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil_klemme_querschnitt WHERE klemme_id = (SELECT id FROM bauteil_klemme WHERE bauteil_id = (SELECT id FROM bauteil WHERE bezeichnung='T Reihenklemme'))").toInt(), 2);
        QCOMPARE(wert("SELECT f.hex_wert FROM bauteil_klemme k JOIN farb_definition f ON f.id = k.gehaeuse_farbe_id WHERE k.bauteil_id = (SELECT id FROM bauteil WHERE bezeichnung='T Reihenklemme')").toString(), QStringLiteral("#123456"));
        QCOMPARE(wert("SELECT name FROM bauteil_kategorie WHERE id = (SELECT kategorie_id FROM bauteil WHERE bezeichnung='T Schütz 3-polig')").toString(), QStringLiteral("Schütze"));
        QCOMPARE(wert("SELECT p.name FROM bauteil_kategorie k JOIN bauteil_kategorie p ON p.id = k.parent_id WHERE k.id = (SELECT kategorie_id FROM bauteil WHERE bezeichnung='T Schütz 3-polig')").toString(), QStringLiteral("Austausch-Test"));
        const int stecker = idVon("T M12-Stecker 4-polig");
        const int kontakt = idVon("T Kontakt Stift");
        QCOMPARE(wert(QStringLiteral("SELECT COUNT(*) FROM steckverbinder_position p JOIN kontakt_typ t ON t.id = p.kontakt_typ_id WHERE t.bauteil_id = %1").arg(kontakt)).toInt(), 2);
        QCOMPARE(wert(QStringLiteral("SELECT stecker_a_bauteil_id FROM konfektioniertes_kabel WHERE bauteil_id = %1").arg(idVon("T Anschlussleitung konfektioniert"))).toInt(), stecker);
        QCOMPARE(wert(QStringLiteral("SELECT bk.bauteil_id FROM konfektioniertes_kabel kk JOIN bauteil_kabel bk ON bk.id = kk.bauteil_kabel_id WHERE kk.bauteil_id = %1").arg(idVon("T Anschlussleitung konfektioniert"))).toInt(), idVon("T Steuerleitung 4x1,5"));
        QCOMPARE(wert("SELECT COUNT(*) FROM konfkabel_pin_zuordnung").toInt(), 2);
        QCOMPARE(wert("SELECT ist_system FROM bauteil WHERE bezeichnung = 'T Schütz 3-polig'").toInt(), 0);

        // Danach ist alles „gleich“ (Hash über Inhalt inkl. Kinder und Querverweisen)
        an = b.bauteileImportAnalysieren(bund);
        QCOMPARE(an.value("anzahlGleich").toInt(), 7);
        QCOMPARE(an.value("anzahlNeu").toInt(), 0);
        const QVariantMap nochmal = b.bauteileImportAusfuehren(bund, {});
        QCOMPARE(nochmal.value("angelegt").toInt(), 0);
        QCOMPARE(nochmal.value("uebersprungen").toInt(), 7);
    }

    void test_02_abweichendUeberschreibenBehaeltKinderIdsKopieBekommtNeueUid()
    {
        const QString bund = datei("b.json");
        {
            Database a;
            QVERIFY(a.openBibliothek(datei("lib_c.db")));
            baueFixture();
            QVERIFY(a.bauteileExportieren(bund, false).value("ok").toBool());
        }
        Database b;
        QVERIFY(b.openBibliothek(datei("lib_d.db")));
        QVERIFY(b.bauteileImportAusfuehren(bund, {}).value("ok").toBool());

        // lokal ändern: Hersteller des Schützes, Länge der Konfektionierung, eine Ader weniger
        const int kabelBauteil = idVon("T Steuerleitung 4x1,5");
        const int kabelTypIdVorher = wert(QStringLiteral("SELECT id FROM bauteil_kabel WHERE bauteil_id = %1").arg(kabelBauteil)).toInt();
        QVERIFY(ex("UPDATE bauteil SET hersteller = 'Lokal geändert' WHERE bezeichnung = 'T Schütz 3-polig'") >= 0);
        QVERIFY(ex(QStringLiteral("DELETE FROM bauteil_kabel_ader WHERE kabel_id = %1 AND ader_nr = 4").arg(kabelTypIdVorher)) >= 0);

        const QVariantMap an = b.bauteileImportAnalysieren(bund);
        QCOMPARE(an.value("anzahlAbweichend").toInt(), 2);
        QCOMPARE(an.value("anzahlGleich").toInt(), 5);
        QString uidSchuetz, uidKabel;
        for (const QVariant &ev : an.value("eintraege").toList()) {
            const QVariantMap m = ev.toMap();
            if (m.value("status") == "abweichend") {
                QCOMPARE(m.value("vorschlag").toString(), QStringLiteral("ueberspringen"));    // nie stilles Überschreiben
                QVERIFY(m.value("aktionen").toStringList().contains("ueberschreiben"));
                QVERIFY(m.value("aktionen").toStringList().contains("kopie"));
            }
            if (m.value("bezeichnung") == "T Schütz 3-polig") uidSchuetz = m.value("uid").toString();
            if (m.value("bezeichnung") == "T Steuerleitung 4x1,5") uidKabel = m.value("uid").toString();
        }

        // Standard: lokal behalten
        QVERIFY(b.bauteileImportAusfuehren(bund, {}).value("ok").toBool());
        QCOMPARE(wert("SELECT hersteller FROM bauteil WHERE bezeichnung = 'T Schütz 3-polig'").toString(), QStringLiteral("Lokal geändert"));

        // Überschreiben: Inhalt wie im Bündel, die ID des Kabeltyps (auf die Projekte zeigen) bleibt
        QVariantMap entsch { { uidSchuetz, "ueberschreiben" }, { uidKabel, "ueberschreiben" } };
        const QVariantMap erg = b.bauteileImportAusfuehren(bund, entsch);
        QVERIFY2(erg.value("ok").toBool(), qPrintable(erg.value("fehler").toString()));
        QCOMPARE(erg.value("ueberschrieben").toInt(), 2);
        QCOMPARE(wert("SELECT hersteller FROM bauteil WHERE bezeichnung = 'T Schütz 3-polig'").toString(), QStringLiteral("Testfabrik"));
        QCOMPARE(wert(QStringLiteral("SELECT id FROM bauteil_kabel WHERE bauteil_id = %1").arg(kabelBauteil)).toInt(), kabelTypIdVorher);
        QCOMPARE(wert(QStringLiteral("SELECT COUNT(*) FROM bauteil_kabel_ader WHERE kabel_id = %1").arg(kabelTypIdVorher)).toInt(), 4);
        QCOMPARE(b.bauteileImportAnalysieren(bund).value("anzahlGleich").toInt(), 7);

        // Als Kopie: neue UID, Bezeichnung mit Zusatz, Original bleibt
        QVERIFY(ex("UPDATE bauteil SET hersteller = 'Nochmal lokal' WHERE bezeichnung = 'T Schütz 3-polig'") >= 0);
        const int vorher = wert("SELECT COUNT(*) FROM bauteil").toInt();
        const QVariantMap kopie = b.bauteileImportAusfuehren(bund, { { uidSchuetz, "kopie" } });
        QCOMPARE(kopie.value("kopien").toInt(), 1);
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil").toInt(), vorher + 1);
        QVERIFY(!uidVon("T Schütz 3-polig (Import)").isEmpty());
        QVERIFY(uidVon("T Schütz 3-polig (Import)") != uidSchuetz);
        QCOMPARE(uidVon("T Schütz 3-polig"), uidSchuetz);
        QCOMPARE(wert("SELECT hersteller FROM bauteil WHERE bezeichnung = 'T Schütz 3-polig'").toString(), QStringLiteral("Nochmal lokal"));
    }

    void test_03_gleicherInhaltMitAndererUidWirdPerAliasVerknuepft()
    {
        const QString bund = datei("c.json");
        QString fremdeUid;
        {
            Database a;
            QVERIFY(a.openBibliothek(datei("lib_e.db")));
            baueFixture();
            fremdeUid = uidVon("T Reihenklemme");
            QVERIFY(a.bauteileExportieren(bund, false).value("ok").toBool());
        }
        Database b;
        QVERIFY(b.openBibliothek(datei("lib_f.db")));
        QVERIFY(b.bauteileImportAusfuehren(bund, {}).value("ok").toBool());
        // Identität „fremd“ simulieren: das lokale Teil hat dieselbe Beschaffenheit, aber eine andere UID (z. B. vor BIB-UID-01 selbst angelegt)
        const QString lokaleUid = QStringLiteral("aaaaaaaa-0000-4000-8000-000000000001");
        QVERIFY(ex(QStringLiteral("UPDATE bauteil SET uid = '%1' WHERE uid = '%2'").arg(lokaleUid, fremdeUid)) >= 0);
        QCOMPARE(b.bauteilIdFuerUid(fremdeUid), -1);

        const QVariantMap an = b.bauteileImportAnalysieren(bund);
        QCOMPARE(an.value("anzahlGleicherInhalt").toInt(), 1);
        QVariantMap eintrag;
        for (const QVariant &ev : an.value("eintraege").toList())
            if (ev.toMap().value("uid") == fremdeUid) eintrag = ev.toMap();
        QCOMPARE(eintrag.value("status").toString(), QStringLiteral("gleicherInhalt"));
        QCOMPARE(eintrag.value("vorschlag").toString(), QStringLiteral("verknuepfen"));
        QCOMPARE(eintrag.value("lokalId").toInt(), idVon("T Reihenklemme"));

        const int vorher = wert("SELECT COUNT(*) FROM bauteil").toInt();
        const QVariantMap erg = b.bauteileImportAusfuehren(bund, {});
        QVERIFY(erg.value("ok").toBool());
        QCOMPARE(erg.value("verknuepft").toInt(), 1);
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil").toInt(), vorher);                       // keine Dublette
        QCOMPARE(wert("SELECT uid FROM bauteil WHERE bezeichnung = 'T Reihenklemme'").toString(), lokaleUid);   // lokale UID bleibt unverändert
        QCOMPARE(b.bauteilIdFuerUid(fremdeUid), idVon("T Reihenklemme"));                      // Alias löst auf
        QCOMPARE(b.bauteileImportAnalysieren(bund).value("anzahlGleich").toInt(), 7);          // über den Alias jetzt „gleich“
    }

    void test_04_aehnlichGleicheBezeichnungAndererInhaltWirdAlsDubletteAngeboten()
    {
        const QString bund = datei("d.json");
        {
            Database a;
            QVERIFY(a.openBibliothek(datei("lib_g.db")));
            baueFixture();
            QVERIFY(a.bauteileExportieren(bund, false).value("ok").toBool());
        }
        Database b;
        QVERIFY(b.openBibliothek(datei("lib_h.db")));
        QVERIFY(ex("INSERT INTO bauteil (bezeichnung, hersteller) VALUES ('T Schütz 3-polig', 'Ein ganz anderer')") > 0);
        const QVariantMap an = b.bauteileImportAnalysieren(bund);
        QCOMPARE(an.value("anzahlAehnlich").toInt(), 1);
        for (const QVariant &ev : an.value("eintraege").toList()) {
            const QVariantMap m = ev.toMap();
            if (m.value("bezeichnung") == "T Schütz 3-polig") {
                QCOMPARE(m.value("status").toString(), QStringLiteral("aehnlich"));
                QCOMPARE(m.value("lokaleBezeichnung").toString(), QStringLiteral("T Schütz 3-polig"));
            }
        }
        const QVariantMap erg = b.bauteileImportAusfuehren(bund, {});
        QVERIFY(erg.value("ok").toBool());
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil WHERE bezeichnung = 'T Schütz 3-polig'").toInt(), 2);   // beide bleiben, nichts überschrieben
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil WHERE bezeichnung = 'T Schütz 3-polig' AND hersteller = 'Ein ganz anderer'").toInt(), 1);
    }

    void test_05_fehlerLassenDieBibliothekUnveraendertUndDateienWerdenGeprueft()
    {
        Database b;
        QVERIFY(b.openBibliothek(datei("lib_i.db")));
        const int vorher = wert("SELECT COUNT(*) FROM bauteil").toInt();

        // Bündel mit zwei Bauteilen gleicher UID: das zweite scheitert am Unique-Index → alles zurückrollen
        const auto teil = [](const QString &name) {
            return QJsonObject { { "uid", "doppelt-0000-4000-8000-000000000002" }, { "kategorie", QJsonArray() },
                                 { "felder", QJsonObject { { "bezeichnung", name } } } };
        };
        const QJsonObject wurzel { { "format", "stroemling-bauteile" }, { "version", 1 }, { "farben", QJsonArray() },
                                   { "bauteile", QJsonArray { teil("Doppelt A"), teil("Doppelt B") } } };
        { QFile f(datei("kaputt_uid.json")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write(QJsonDocument(wurzel).toJson()); }
        const QVariantMap erg = b.bauteileImportAusfuehren(datei("kaputt_uid.json"), {});
        QVERIFY(!erg.value("ok").toBool());
        QVERIFY(!erg.value("fehler").toString().isEmpty());
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil").toInt(), vorher);                    // Rollback: auch „Doppelt A“ fehlt
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil WHERE bezeichnung LIKE 'Doppelt%'").toInt(), 0);

        // fremde / kaputte / neuere Dateien
        { QFile f(datei("text.json")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("das ist kein JSON"); }
        QVERIFY(b.bauteileImportAnalysieren(datei("text.json")).value("fehler").toString().contains("JSON"));
        { QFile f(datei("fremd.json")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("{\"format\":\"etwas-anderes\"}"); }
        QVERIFY(b.bauteileImportAnalysieren(datei("fremd.json")).value("fehler").toString().contains("kein Bauteil-Bündel"));
        { QFile f(datei("neu.json")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("{\"format\":\"stroemling-bauteile\",\"version\":99,\"bauteile\":[]}"); }
        QVERIFY(b.bauteileImportAnalysieren(datei("neu.json")).value("fehler").toString().contains("neueren Strömling-Version"));
        QVERIFY(!b.bauteileImportAnalysieren(datei("gibtsnicht.json")).value("ok").toBool());
        QVERIFY(!b.bauteileImportAusfuehren(datei("gibtsnicht.json"), {}).value("ok").toBool());
    }

    void test_06_seedVerweisOhneMitexportLoestSichUeberDieDeterministischeUidAuf()
    {
        // Ein konfektioniertes Kabel verweist auf ein MITGELIEFERTES (ist_system) Teil als Stecker; der Export ohne Systemteile lässt dieses weg
        const QString bund = datei("e.json");
        QString seedBezeichnung;
        {
            Database a;
            QVERIFY(a.openBibliothek(datei("lib_j.db")));
            QSqlQuery q(lib());
            QVERIFY(q.exec("SELECT id, bezeichnung FROM bauteil WHERE ist_system = 1 ORDER BY id LIMIT 1") && q.next());
            const int seedId = q.value(0).toInt();
            seedBezeichnung = q.value(1).toString();
            const int konf = ex("INSERT INTO bauteil (bezeichnung) VALUES ('T Konfektion mit Seed-Stecker')");
            ex(QStringLiteral("INSERT INTO konfektioniertes_kabel (bauteil_id, stecker_a_bauteil_id, laenge_m) VALUES (%1, %2, 1.0)").arg(konf).arg(seedId));
            QVERIFY(a.bauteileExportieren(bund, false).value("ok").toBool());
            QCOMPARE(a.bauteileExportieren(datei("e_ohne_system.json"), false).value("anzahl").toInt(), 1);   // Seed nicht im Bündel
        }
        Database b;
        QVERIFY(b.openBibliothek(datei("lib_k.db")));
        const QVariantMap erg = b.bauteileImportAusfuehren(bund, {});
        QVERIFY2(erg.value("ok").toBool(), qPrintable(erg.value("fehler").toString()));
        QVERIFY2(erg.value("warnungen").toStringList().isEmpty(), qPrintable(erg.value("warnungen").toStringList().join("|")));
        QCOMPARE(wert(QStringLiteral("SELECT stecker_a_bauteil_id FROM konfektioniertes_kabel WHERE bauteil_id = %1").arg(idVon("T Konfektion mit Seed-Stecker"))).toInt(),
                 idVon(seedBezeichnung));
    }

    void test_07_unbekannteSpaltenImBuendelWerdenIgnoriertUndUnzulaessigeAktionenDurchVorschlagErsetzt()
    {
        const QJsonObject teil { { "uid", "spalte-0000-4000-8000-000000000003" }, { "kategorie", QJsonArray() },
                                 { "felder", QJsonObject { { "bezeichnung", "Teil mit neuer Spalte" }, { "gibt_es_lokal_nicht", 42 },
                                                          { "hersteller", "H" } } } };
        const QJsonObject wurzel { { "format", "stroemling-bauteile" }, { "version", 1 }, { "farben", QJsonArray() }, { "bauteile", QJsonArray { teil } } };
        { QFile f(datei("spalte.json")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write(QJsonDocument(wurzel).toJson()); }
        Database b;
        QVERIFY(b.openBibliothek(datei("lib_l.db")));
        // „ueberschreiben“ ist für einen neuen Eintrag unzulässig → Vorschlag (anlegen) greift
        const QVariantMap erg = b.bauteileImportAusfuehren(datei("spalte.json"), { { "spalte-0000-4000-8000-000000000003", "ueberschreiben" } });
        QVERIFY2(erg.value("ok").toBool(), qPrintable(erg.value("fehler").toString()));
        QCOMPARE(erg.value("angelegt").toInt(), 1);
        QCOMPARE(wert("SELECT hersteller FROM bauteil WHERE bezeichnung = 'Teil mit neuer Spalte'").toString(), QStringLiteral("H"));
        // „ueberspringen“ wird respektiert
        const QJsonObject teil2 { { "uid", "spalte-0000-4000-8000-000000000004" }, { "kategorie", QJsonArray() },
                                  { "felder", QJsonObject { { "bezeichnung", "Übersprungenes Teil" } } } };
        const QJsonObject w2 { { "format", "stroemling-bauteile" }, { "version", 1 }, { "bauteile", QJsonArray { teil2 } } };
        { QFile f(datei("skip.json")); QVERIFY(f.open(QIODevice::WriteOnly)); f.write(QJsonDocument(w2).toJson()); }
        const QVariantMap skip = b.bauteileImportAusfuehren(datei("skip.json"), { { "spalte-0000-4000-8000-000000000004", "ueberspringen" } });
        QCOMPARE(skip.value("uebersprungen").toInt(), 1);
        QCOMPARE(wert("SELECT COUNT(*) FROM bauteil WHERE bezeichnung = 'Übersprungenes Teil'").toInt(), 0);
    }

    // Gegen eine ECHTE Bibliothek (nur mit STROEMLING_TEST_BIB_KOPIE = Pfad zu einer KOPIE; nie das Original): alle Bauteile
    // exportieren, in eine frische Bibliothek importieren, danach muss jedes Teil dem Original inhaltlich entsprechen.
    void test_08_echteBibliothekRoundtrip()
    {
        const QString quelle = qEnvironmentVariable("STROEMLING_TEST_BIB_KOPIE");
        if (quelle.isEmpty() || !QFileInfo::exists(quelle))
            QSKIP("STROEMLING_TEST_BIB_KOPIE nicht gesetzt");
        const QString kopie = datei("echt_a.db");
        QVERIFY(QFile::copy(quelle, kopie));
        const QString alle = datei("echt_alle.json"), eigene = datei("echt_eigene.json");
        int anzahlAlle = 0, anzahlEigene = 0;
        {
            Database a;
            QVERIFY(a.openBibliothek(kopie));
            const QVariantMap ea = a.bauteileExportieren(alle, true);
            const QVariantMap ee = a.bauteileExportieren(eigene, false);
            QVERIFY2(ea.value("ok").toBool() && ee.value("ok").toBool(), "Export der echten Bibliothek fehlgeschlagen");
            anzahlAlle = ea.value("anzahl").toInt();
            anzahlEigene = ee.value("anzahl").toInt();
        }
        QVERIFY(anzahlAlle > 0);
        Database b;
        QVERIFY(b.openBibliothek(datei("echt_b.db")));
        // Der Export aller Bauteile gegen eine frische Bibliothek (hat dieselben Seeds)
        const QVariantMap an = b.bauteileImportAnalysieren(alle);
        QVERIFY(an.value("ok").toBool());
        qInfo() << "Echte Bibliothek:" << anzahlAlle << "Bauteile (" << anzahlEigene << "eigene ) | gegen frische Bibliothek: gleich"
                << an.value("anzahlGleich").toInt() << "neu" << an.value("anzahlNeu").toInt() << "abweichend" << an.value("anzahlAbweichend").toInt()
                << "gleicher Inhalt" << an.value("anzahlGleicherInhalt").toInt() << "aehnlich" << an.value("anzahlAehnlich").toInt();
        const QVariantMap erg = b.bauteileImportAusfuehren(alle, {});
        QVERIFY2(erg.value("ok").toBool(), qPrintable(erg.value("fehler").toString()));
        qInfo() << "Import-Warnungen:" << erg.value("warnungen").toStringList();
        // Nach dem Import entsprechen die NEU angelegten Teile dem Original exakt; „abweichende“ Seed-Teile blieben lokal
        const QVariantMap danach = b.bauteileImportAnalysieren(alle);
        QCOMPARE(danach.value("anzahlNeu").toInt(), 0);
        QCOMPARE(danach.value("anzahlGleicherInhalt").toInt(), 0);
        QCOMPARE(danach.value("anzahlAehnlich").toInt(), 0);
        QCOMPARE(danach.value("anzahlGleich").toInt() + danach.value("anzahlAbweichend").toInt(), anzahlAlle);
        // die eigenen Bauteile (nicht mitgeliefert) sind danach alle inhaltlich gleich
        const QVariantMap eig = b.bauteileImportAnalysieren(eigene);
        QCOMPARE(eig.value("anzahlGleich").toInt(), anzahlEigene);
    }

private:
    QTemporaryDir m_dir;
};
