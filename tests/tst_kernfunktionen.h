#pragma once
#include <QtTest>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDir>
#include <QProcess>
#include <QFile>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QSignalSpy>
#include "database/Database.h"

// Regressionstests für die zwei kritischsten, größten Datenbank-Funktionen:
//   Database::grafikSpeichern()   – DELETE+INSERT aller Elemente einer Seite samt Nachziehen der FKs
//   Database::klemmlistenauszug() – Verdrahtungsliste (Klemmen, Stegbrücken, Geometrie-Matching)
// Absicherung vor einem Refactoring dieser Funktionen (QML-/C++-Refactor-Audit Okt 2026).
// Laufen auf temporären Projektdateien + temporärer Bibliothek-DB, nie auf echten Nutzerdaten.

class TstKernfunktionen : public QObject
{
    Q_OBJECT

    Database *m_db = nullptr;
    QString   m_bibPfad;
    QString   m_projPfad;

    // ── Hilfen ───────────────────────────────────────────────────
    static int ins(const QString &sql, QSqlDatabase db = QSqlDatabase::database())
    {
        QSqlQuery q(db);
        if (!q.exec(sql)) {
            qWarning() << "SQL fehlgeschlagen:" << sql << q.lastError().text();
            return -1;
        }
        return q.lastInsertId().toInt();
    }
    static QVariant einWert(const QString &sql)
    {
        QSqlQuery q(QSqlDatabase::database());
        if (!q.exec(sql) || !q.next()) return QVariant();
        return q.value(0);
    }
    static QVariantMap elem(const QString &typ, double x1, double y1, double x2, double y2,
                            const QVariantMap &extra = {})
    {
        QVariantMap m;
        m["typ"] = typ;
        m["x1"] = x1; m["y1"] = y1; m["x2"] = x2; m["y2"] = y2;
        if (!extra.isEmpty()) m["extraDaten"] = extra;
        return m;
    }
    static QVariantMap symbol(const QString &symbolId, double x, double y, const QVariantMap &extra = {})
    {
        QVariantMap m = elem("symbol", x, y, x + 8, y + 8, extra);
        m["symbolId"] = symbolId;
        return m;
    }
    // Projekt-Grundgerüst: liefert Seiten-ID (Default-Anlage/-Ort aus createProjekt)
    // PDF-Export des Schaltplan-Abschnitts über dokuPdfExportieren() (ersetzt canvasPdfExportieren/-SeiteExportieren).
    // ids leer = alle Seiten mit in_doku_pdf = 1.
    bool schaltplanPdf(int pid, const QString &pfad, bool nb, const QList<int> &ids = {})
    {
        QJsonObject o;
        o["mitNormblatt"] = nb;
        if (!ids.isEmpty()) {
            QJsonArray a;
            for (int id : ids) a.append(id);
            o["seiteIds"] = a;
        }
        o["abschnitte"] = QJsonArray{QJsonObject{{"typ", "schaltplan"}}};
        return m_db->dokuPdfExportieren(pid, pfad, QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact)));
    }

    int neueSeite(const QString &blatt)
    {
        const int ortId = einWert("SELECT id FROM ort LIMIT 1").toInt();
        return ins(QString("INSERT INTO seite (ort_id, blattnummer) VALUES (%1,'%2')").arg(ortId).arg(blatt));
    }

private slots:
    void initTestCase()
    {
        const QString stamp = QString::number(QDateTime::currentMSecsSinceEpoch());
        m_bibPfad  = QDir::tempPath() + "/stroemling_test_kern_bib_" + stamp + ".db";
        m_projPfad = QDir::tempPath() + "/stroemling_test_kern_proj_" + stamp + ".stroemling";
        m_db = new Database(this);
        QVERIFY2(m_db->openBibliothek(m_bibPfad), "Temporäre Bibliothek-DB konnte nicht angelegt werden");
    }

    void cleanupTestCase()
    {
        if (m_db) m_db->closeProjekt();
        for (const QString &p : {m_projPfad, m_bibPfad})
            for (const QString &suf : {QString(), QString("-wal"), QString("-shm")})
                QFile::remove(p + suf);
    }

    // Frisches Projekt je Test
    void init()
    {
        QFile::remove(m_projPfad);
        QVERIFY(m_db->createProjekt(m_projPfad, "KernTest"));
    }
    void cleanup() { m_db->closeProjekt(); }

    // ════════════════════════════════════════════════════════════
    // grafikSpeichern
    // ════════════════════════════════════════════════════════════

    void gs_01_roundtrip()
    {
        const int sid = neueSeite("1");
        QVERIFY(sid > 0);

        QVariantMap linie = elem("linie", 1, 2, 30, 4);
        linie["strichFarbe"] = "#ff0000";
        linie["strichBreite"] = 0.7;
        QVariantMap text = elem("text", 5, 6, 40, 12);
        text["textInhalt"] = "Hallo";
        text["textEinpassen"] = true;
        QVariantMap leitung = elem("leitung", 0, 0, 0, 0);
        leitung["punkte"] = QVariantList{ QVariantMap{{"x", 1.5}, {"y", 2.5}},
                                          QVariantMap{{"x", 9.0}, {"y", 2.5}} };
        QVariantMap sym = symbol("motor", 20, 20, {{"foo", "bar"}, {"n", 3}});
        sym["rotation"] = 90;
        sym["spiegelX"] = true;

        QVERIFY(m_db->grafikSpeichern(sid, {linie, text, leitung, sym}));
        const QVariantList l = m_db->grafikLaden(sid);
        QCOMPARE(l.size(), 4);

        // Reihenfolge = Übergabereihenfolge (sortierung = Index)
        QCOMPARE(l[0].toMap()["typ"].toString(), QString("linie"));
        QCOMPARE(l[1].toMap()["typ"].toString(), QString("text"));
        QCOMPARE(l[2].toMap()["typ"].toString(), QString("leitung"));
        QCOMPARE(l[3].toMap()["typ"].toString(), QString("symbol"));

        const QVariantMap a = l[0].toMap();
        QCOMPARE(a["x1"].toDouble(), 1.0);
        QCOMPARE(a["x2"].toDouble(), 30.0);
        QCOMPARE(a["strichFarbe"].toString(), QString("#ff0000"));
        QCOMPARE(a["strichBreite"].toDouble(), 0.7);
        QCOMPARE(a["strichArt"].toString(), QString("solid"));      // Default

        const QVariantMap b = l[1].toMap();
        QCOMPARE(b["textInhalt"].toString(), QString("Hallo"));
        QCOMPARE(b["textEinpassen"].toBool(), true);

        const QVariantList pk = l[2].toMap()["punkte"].toList();
        QCOMPARE(pk.size(), 2);
        QCOMPARE(pk[0].toMap()["x"].toDouble(), 1.5);
        QCOMPARE(pk[1].toMap()["x"].toDouble(), 9.0);

        const QVariantMap d = l[3].toMap();
        QCOMPARE(d["symbolId"].toString(), QString("motor"));
        QCOMPARE(d["rotation"].toInt(), 90);
        QCOMPARE(d["spiegelX"].toBool(), true);
        QCOMPARE(d["spiegelY"].toBool(), false);
        QCOMPARE(d["extraDaten"].toMap()["foo"].toString(), QString("bar"));
        QCOMPARE(d["extraDaten"].toMap()["n"].toInt(), 3);
    }

    void gs_02_ersetztNurDieEigeneSeite()
    {
        const int s1 = neueSeite("1"), s2 = neueSeite("2");
        QVERIFY(m_db->grafikSpeichern(s2, {elem("linie", 0, 0, 1, 1), elem("linie", 2, 2, 3, 3)}));
        QVERIFY(m_db->grafikSpeichern(s1, {elem("linie", 0, 0, 5, 5)}));
        QVERIFY(m_db->grafikSpeichern(s1, {elem("rechteck", 0, 0, 5, 5), elem("rechteck", 1, 1, 6, 6),
                                           elem("rechteck", 2, 2, 7, 7)}));
        QCOMPARE(m_db->grafikLaden(s1).size(), 3);
        QCOMPARE(m_db->grafikLaden(s2).size(), 2);
        // Leere Liste löscht alles auf der Seite
        QVERIFY(m_db->grafikSpeichern(s1, {}));
        QCOMPARE(m_db->grafikLaden(s1).size(), 0);
        QCOMPARE(m_db->grafikLaden(s2).size(), 2);
    }

    void gs_03_zaehlerSteigtNurBeiErfolg()
    {
        const int sid = neueSeite("1");
        const int z0 = m_db->grafikAenderungszaehler();
        QVERIFY(m_db->grafikSpeichern(sid, {elem("linie", 0, 0, 1, 1)}));
        QCOMPARE(m_db->grafikAenderungszaehler(), z0 + 1);

        // Ungültiger FK (betriebsmittel_id) → komplettes Speichern scheitert
        QVariantMap schlecht = elem("symbol", 0, 0, 1, 1);
        schlecht["betriebsmittelId"] = 99999;
        QSignalSpy fehler(m_db, &Database::dbFehler);
        QVERIFY(!m_db->grafikSpeichern(sid, {elem("linie", 9, 9, 9, 9), schlecht}));
        QCOMPARE(m_db->grafikAenderungszaehler(), z0 + 1);
    }

    void gs_04_fehlerRolltZurueck()
    {
        const int sid = neueSeite("1");
        QVERIFY(m_db->grafikSpeichern(sid, {elem("linie", 1, 1, 2, 2), elem("linie", 3, 3, 4, 4)}));
        const QVariantList vorher = m_db->grafikLaden(sid);

        QVariantMap schlecht = elem("symbol", 0, 0, 1, 1);
        schlecht["betriebsmittelId"] = 99999;
        QVERIFY(!m_db->grafikSpeichern(sid, {elem("kreis", 7, 7, 8, 8), schlecht}));

        const QVariantList nachher = m_db->grafikLaden(sid);
        QCOMPARE(nachher.size(), vorher.size());
        for (int i = 0; i < vorher.size(); ++i) {
            QCOMPARE(nachher[i].toMap()["id"].toInt(), vorher[i].toMap()["id"].toInt());
            QCOMPARE(nachher[i].toMap()["typ"].toString(), vorher[i].toMap()["typ"].toString());
        }
    }

    void gs_05_betriebsmittelHauptfunktionWirdNachgezogen()
    {
        const int sid = neueSeite("1"), anderes = neueSeite("2");
        QVERIFY(m_db->grafikSpeichern(sid, {symbol("schuetz", 0, 0), symbol("schuetz", 20, 0)}));
        const QVariantList l = m_db->grafikLaden(sid);
        // Andere Seite danach füllen: belegt die nächsten IDs, die neuen IDs von sid müssen sich dadurch ändern
        QVERIFY(m_db->grafikSpeichern(anderes, {elem("linie", 0, 0, 1, 1), elem("linie", 0, 0, 2, 2)}));
        const int bm = ins("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz, haupt_element_id) VALUES (1,'K1',"
                           + QString::number(l[1].toMap()["id"].toInt()) + ")");
        QVERIFY(bm > 0);

        QVERIFY(m_db->grafikSpeichern(sid, l));            // Re-Save mit alten IDs
        const QVariantList neu = m_db->grafikLaden(sid);
        const QVariant hf = einWert(QString("SELECT haupt_element_id FROM betriebsmittel WHERE id=%1").arg(bm));
        QVERIFY2(!hf.isNull(), "haupt_element_id wurde beim Speichern genullt");
        QCOMPARE(hf.toInt(), neu[1].toMap()["id"].toInt());
        // IDs haben sich tatsächlich geändert (sonst wäre der Test nicht aussagekräftig)
        QVERIFY(neu[1].toMap()["id"].toInt() != l[1].toMap()["id"].toInt());
    }

    void gs_06_spsKanalZuweisungBleibtErhalten()
    {
        const int sid = neueSeite("1"), anderes = neueSeite("2");
        QVERIFY(m_db->grafikSpeichern(sid, {symbol("sps_eingang", 0, 0), symbol("sps_ausgang", 20, 0)}));
        const QVariantList l = m_db->grafikLaden(sid);
        QVERIFY(m_db->grafikSpeichern(anderes, {elem("linie", 0, 0, 1, 1), elem("linie", 0, 0, 2, 2)}));
        const int k = ins(QString("INSERT INTO sps_kanal (projekt_id, grafik_element_id) VALUES (1,%1)")
                              .arg(l[0].toMap()["id"].toInt()));
        QVERIFY(k > 0);

        QVERIFY(m_db->grafikSpeichern(sid, l));
        const QVariant ge = einWert(QString("SELECT grafik_element_id FROM sps_kanal WHERE id=%1").arg(k));
        QVERIFY2(!ge.isNull(), "SPS-Kanal-Zuweisung wurde beim Speichern verworfen");
        QCOMPARE(ge.toInt(), m_db->grafikLaden(sid)[0].toMap()["id"].toInt());
        QVERIFY(m_db->grafikLaden(sid)[0].toMap()["id"].toInt() != l[0].toMap()["id"].toInt());

        // dreimal hintereinander: bleibt stabil
        for (int i = 0; i < 3; ++i)
            QVERIFY(m_db->grafikSpeichern(sid, m_db->grafikLaden(sid)));
        QVERIFY(!einWert(QString("SELECT grafik_element_id FROM sps_kanal WHERE id=%1").arg(k)).isNull());
    }

    // ── SPS-INTEGRITAET-01 ───────────────────────────────────────
    static bool hatArt(const QVariantList &l, const QString &art)
    {
        for (const QVariant &v : l)
            if (v.toMap()["art"].toString() == art) return true;
        return false;
    }

    void sps_01_eindeutigkeitUndKollisionen()
    {
        const int r0 = m_db->spsRackAnlegen(1, 70, "SPS", "Rack A", "");
        QVERIFY(r0 > 0);
        QCOMPARE(m_db->spsRackAnlegen(1, 70, "SPS", "Rack doppelt", ""), -1);
        const int r1 = m_db->spsRackAnlegen(1, 71, "SPS", "Rack B", "");
        QVERIFY(r1 > 0);
        QVERIFY2(!m_db->spsRackAktualisieren(r1, 70, "SPS", "Rack B", "", ""),
                 "Rack-Nr. 70 darf nicht ein zweites Mal vergeben werden");
        QVERIFY(m_db->spsRackAktualisieren(r1, 71, "SPS", "Rack B neu", "", ""));  // unverändert: ok

        const int bg = m_db->spsBaugruppeAnlegen(r0, 1, "DI", "DI 16", 16, 0);
        QVERIFY(bg > 0);
        QCOMPARE(m_db->spsBaugruppeAnlegen(r0, 1, "DO", "Slot doppelt", 16, 2), -1);
        const int bg2 = m_db->spsBaugruppeAnlegen(r0, 2, "DO", "DO 16", 16, 0);
        QVERIFY(bg2 > 0);
        QVERIFY(!m_db->spsBaugruppeAktualisieren(bg2, 1, "DO", "DO 16", "", 16, "BOOL", 0, ""));

        const int k0 = m_db->spsKanalAnlegen(1, bg, 0, "E", 0, 0, "BOOL", "Start", "");
        QVERIFY(k0 > 0);
        QCOMPARE(m_db->spsKanalAnlegen(1, bg, 0, "E", 0, 0, "BOOL", "", ""), -1);       // gleiche Adresse
        QCOMPARE(m_db->spsKanalAnlegen(1, bg, 0, "E", 0, -1, "WORD", "", ""), -1);      // EW0 überlappt E0.0
        QVERIFY(m_db->spsKanalAnlegen(1, bg, 1, "E", 0, 1, "BOOL", "", "") > 0);        // E0.1 frei
        QVERIFY(m_db->spsKanalAnlegen(1, bg2, 0, "A", 0, 0, "BOOL", "", "") > 0);       // A0.0 ist ein anderer Adressraum
        // anderes Rack: gleiche Adresse E0.0 erlaubt (eigener Adressraum)
        const int bgB = m_db->spsBaugruppeAnlegen(r1, 1, "DI", "DI B", 16, 0);
        QVERIFY(bgB > 0);
        QVERIFY(m_db->spsKanalAnlegen(1, bgB, 0, "E", 0, 0, "BOOL", "", "") > 0);

        // Vorab-Prüfung liefert den Partner
        const QVariantMap konflikt = m_db->spsKanalKonflikt(1, bg, 5, "E", 0, 0, "BOOL", 0);
        QCOMPARE(konflikt["kanalId"].toInt(), k0);
        QCOMPARE(konflikt["adresse"].toString(), QString("E0.0"));
        QCOMPARE(konflikt["variablenname"].toString(), QString("Start"));
        QVERIFY(m_db->spsKanalKonflikt(1, bg, 5, "E", 1, 0, "BOOL", 0).isEmpty());

        // Ändern auf belegte Adresse wird abgewiesen, Kommentar ändern bleibt möglich
        const int k1 = m_db->spsKanalAnlegen(1, bg, 2, "E", 0, 2, "BOOL", "", "");
        QVERIFY(k1 > 0);
        QVERIFY(!m_db->spsKanalAktualisieren(k1, {{"bit_nr", 0}}));
        QVERIFY(m_db->spsKanalAktualisieren(k1, {{"kommentar", "ok"}, {"bit_nr", 2}}));
    }

    void sps_02_konfliktMengeUndDrc()
    {
        const int r = m_db->spsRackAnlegen(1, 80, "SPS", "Rack C", "");
        const int bg = m_db->spsBaugruppeAnlegen(r, 1, "DI", "DI 8", 8, 0);
        QVERIFY(r > 0 && bg > 0);

        const int sid = neueSeite("SPS");
        QVERIFY(m_db->grafikSpeichern(sid, {symbol("sps_di_einpolig", 0, 0),
                                             symbol("sps_di_einpolig", 20, 0),
                                             symbol("sps_do_einpolig", 40, 0)}));
        const QVariantList l = m_db->grafikLaden(sid);
        const int e0 = l[0].toMap()["id"].toInt(), e1 = l[1].toMap()["id"].toInt();
        const int e2 = l[2].toMap()["id"].toInt();

        // Altbestand: direkte INSERTs umgehen die Sperre (so entstehen Duplikate in alten Projekten)
        const int a = ins(QString("INSERT INTO sps_kanal (projekt_id,baugruppe_id,kanal_nr,adress_typ,byte_nr,bit_nr,datentyp,variablenname,grafik_element_id) "
                                  "VALUES (1,%1,0,'E',0,0,'BOOL','Sensor_A',%2)").arg(bg).arg(e0));
        const int b = ins(QString("INSERT INTO sps_kanal (projekt_id,baugruppe_id,kanal_nr,adress_typ,byte_nr,bit_nr,datentyp,variablenname,grafik_element_id) "
                                  "VALUES (1,%1,1,'E',0,0,'BOOL','Sensor_B',%2)").arg(bg).arg(e1));
        const int weit = ins(QString("INSERT INTO sps_kanal (projekt_id,baugruppe_id,kanal_nr,adress_typ,byte_nr,bit_nr,datentyp) "
                                     "VALUES (1,%1,2,'E',5,0,'BOOL')").arg(bg));
        const int typfalsch = ins(QString("INSERT INTO sps_kanal (projekt_id,baugruppe_id,kanal_nr,adress_typ,byte_nr,bit_nr,datentyp,grafik_element_id) "
                                          "VALUES (1,%1,3,'E',0,3,'BOOL',%2)").arg(bg).arg(e2));
        const int ohneBg = ins("INSERT INTO sps_kanal (projekt_id,adress_typ,byte_nr,bit_nr,datentyp,variablenname) "
                               "VALUES (1,'E',9,0,'BOOL','Waise')");
        const int ohneEl = ins(QString("INSERT INTO sps_kanal (projekt_id,baugruppe_id,kanal_nr,adress_typ,byte_nr,bit_nr,datentyp,variablenname) "
                                       "VALUES (1,%1,4,'E',0,4,'BOOL','Tag_ohne_Symbol')").arg(bg));
        QVERIFY(a > 0 && b > 0 && weit > 0 && typfalsch > 0 && ohneBg > 0 && ohneEl > 0);

        // Sprungziel (SPS-SPRUNG-01): Seite + Elementmittelpunkt kommen mit der Kanalliste
        bool gefunden = false;
        for (const QVariant &kv : m_db->spsKanalListe(1)) {
            const QVariantMap k = kv.toMap();
            if (k["id"].toInt() != a) continue;
            gefunden = true;
            QCOMPARE(k["seite_id"].toInt(), sid);
            QCOMPARE(k["welt_x"].toDouble(), 4.0);   // Symbol x=0..8
            QCOMPARE(k["welt_y"].toDouble(), 4.0);
        }
        QVERIFY(gefunden);

        // Canvas-Markierung: beide kollidierenden Elemente, nicht das dritte
        QSet<int> ids;
        for (const QVariant &v : m_db->spsKonfliktElementIds(1)) ids.insert(v.toInt());
        QVERIFY(ids.contains(e0));
        QVERIFY(ids.contains(e1));
        QVERIFY(!ids.contains(e2));

        const QVariantList drc = m_db->drcSpsPruefung(1);
        QVERIFY2(hatArt(drc, "adresse_doppelt"),       "Adresskollision nicht gemeldet");
        QVERIFY2(hatArt(drc, "adresse_ausserhalb"),    "Adresse außerhalb der Baugruppe nicht gemeldet");
        QVERIFY2(hatArt(drc, "kanal_typ_passt_nicht"), "DO-Symbol an DI-Kanal nicht gemeldet");
        QVERIFY2(hatArt(drc, "kanal_ohne_baugruppe"),  "Kanal ohne Baugruppe nicht gemeldet");
        QVERIFY2(hatArt(drc, "kanal_ohne_element"),    "Kanal mit Tag ohne Element nicht gemeldet");

        // Gegenprobe: eine freie Adresse im selben Rack kollidiert nicht
        QVERIFY(m_db->spsKanalKonflikt(1, bg, 6, "E", 0, 6, "BOOL", 0).isEmpty());
    }

    void sps_03_alarmLoeschenUndCsvExport()
    {
        const int r = m_db->spsRackAnlegen(1, 90, "PLS", "PLS-Rack", "");
        const int bg = m_db->spsBaugruppeAnlegen(r, 3, "AI", "AI 8", 8, 0);
        QVERIFY(r > 0 && bg > 0);
        const int k = m_db->spsKanalAnlegen(1, bg, 0, "E", 0, 0, "REAL", "TIC-001", "Reaktor");
        QVERIFY(k > 0);

        QVERIFY(m_db->spsKanalAktualisieren(k, {{"pls_alarm_hi", 450.0}, {"pls_alarm_hh", 480.0},
                                                 {"pls_einheit", "°C"}}));
        QCOMPARE(einWert(QString("SELECT pls_alarm_hi FROM sps_kanal WHERE id=%1").arg(k)).toDouble(), 450.0);

        // Alarm löschen (leeres Feld im Dialog = null)
        QVERIFY(m_db->spsKanalAktualisieren(k, {{"pls_alarm_hi", QVariant()}, {"pls_alarm_hh", QVariant()}}));
        QVERIFY(einWert(QString("SELECT pls_alarm_hi FROM sps_kanal WHERE id=%1").arg(k)).isNull());
        QVERIFY(einWert(QString("SELECT pls_alarm_hh FROM sps_kanal WHERE id=%1").arg(k)).isNull());
        QCOMPARE(einWert(QString("SELECT pls_einheit FROM sps_kanal WHERE id=%1").arg(k)).toString(), QString("°C"));

        // CSV: Rack/Slot/Kanal als eigene Spalten, Signal-Art, keine rohe Element-ID
        const QString csv = m_projPfad + "_io.csv";
        QVERIFY(m_db->spsIOListeCsvSpeichern(1, csv));
        QFile f(csv);
        QVERIFY(f.open(QIODevice::ReadOnly));
        const QString inhalt = QString::fromUtf8(f.readAll());
        f.close();
        QFile::remove(csv);
        QVERIFY(inhalt.contains("\"Rack\";\"Slot\";\"Kanal\""));
        QVERIFY(!inhalt.contains("Element-ID"));
        QVERIFY2(inhalt.contains("\"PLS\";\"90\";\"3\";\"1\";\"AI 8\";\"AI\";\"AI\";\"R90 S3 K1\""),
                 qPrintable(inhalt));
    }

    void sps_04_konfigurierbarerExport()
    {
        const int r = m_db->spsRackAnlegen(1, 95, "PLS", "Messwarte", "ACME");
        const int bg = m_db->spsBaugruppeAnlegen(r, 2, "AI", "AI 4", 4, 0);
        const int bgDo = m_db->spsBaugruppeAnlegen(r, 3, "DO", "DO 4", 4, 0);
        QVERIFY(r > 0 && bg > 0 && bgDo > 0);
        const int k1 = m_db->spsKanalAnlegen(1, bg, 0, "E", 0, 0, "REAL", "TIC;001", "Temp \"Reaktor\"");
        QVERIFY(m_db->spsKanalAktualisieren(k1, {{"pls_bereich_min", 0.0}, {"pls_bereich_max", 99.5}}));
        QVERIFY(m_db->spsKanalAnlegen(1, bgDo, 0, "A", 0, 0, "REAL", "Ventil", "") > 0);

        // Feldkatalog enthält Standard- und Zusatzfelder
        QVariantList kat = m_db->spsExportFeldKatalog();
        QVERIFY(kat.size() > 22);

        // eigene Spalten, Reihenfolge, Titel, Komma-Trenner, Dezimalpunkt, Rack-/Signalfilter
        const QString konfig = R"({"spalten":[
            {"feld":"adresse","titel":"Addr"},
            {"feld":"variablenname","titel":"Tag"},
            {"feld":"bereich_max","titel":"Max"},
            {"feld":"fest","titel":"Quelle","wert":"Strömling"},
            {"feld":"hersteller","titel":"Hersteller"}],
            "trennzeichen":",","dezimal":".","kopfzeile":true,"bom":false,"anfuehrung":"bei_bedarf",
            "filter":{"system":"PLS","rack":"95","signal":"AI","belegung":"alle"}})";
        const QVariantMap v = m_db->spsExportVorschau(1, konfig, 10);
        QVERIFY2(v["fehler"].toString().isEmpty(), qPrintable(v["fehler"].toString()));
        QCOMPARE(v["zeilen"].toInt(), 1);   // nur der AI-Kanal
        const QStringList z = v["text"].toString().split('\n', Qt::SkipEmptyParts);
        QCOMPARE(z.size(), 2);
        QCOMPARE(z[0], QString("Addr,Tag,Max,Quelle,Hersteller"));
        // Semikolon im Tag erzwingt bei "bei_bedarf" nur bei Komma-Trenner kein Quoting,
        // Dezimalpunkt statt Komma, fester Text, Hersteller aus dem Rack
        QCOMPARE(z[1], QString("R95 S2 K1,TIC;001,99.5,Strömling,ACME"));

        // Trenner im Wert wird gequotet; Dezimalkomma
        const QString k2 = R"({"spalten":[{"feld":"variablenname"},{"feld":"kommentar"},{"feld":"bereich_max"}],
            "trennzeichen":";","dezimal":",","kopfzeile":false,"anfuehrung":"bei_bedarf",
            "filter":{"rack":"95","signal":"AI"}})";
        const QVariantMap v2 = m_db->spsExportVorschau(1, k2, -1);
        QCOMPARE(v2["text"].toString(), QString("\"TIC;001\";\"Temp \"\"Reaktor\"\"\";99,5\n"));

        // Filter „ohne Element" findet beide Kanäle, Vorschau begrenzt die Ausgabe, zählt aber alle
        const QString k3 = R"({"spalten":[{"feld":"adresse"}],"kopfzeile":false,
            "filter":{"rack":"95","belegung":"ohne_element"}})";
        const QVariantMap v3 = m_db->spsExportVorschau(1, k3, 1);
        QCOMPARE(v3["zeilen"].toInt(), 2);
        QCOMPARE(v3["text"].toString().split('\n', Qt::SkipEmptyParts).size(), 1);

        // Ungültig: keine Spalten / kein JSON
        QVERIFY(!m_db->spsExportVorschau(1, R"({"spalten":[]})", 5)["fehler"].toString().isEmpty());
        QVERIFY(!m_db->spsExportVorschau(1, "kein json", 5)["fehler"].toString().isEmpty());

        // Datei ohne BOM
        const QString pfad = m_projPfad + "_cfg.csv";
        QVERIFY(m_db->spsExportCsvSpeichern(1, pfad, konfig));
        QFile f(pfad);
        QVERIFY(f.open(QIODevice::ReadOnly));
        const QByteArray roh = f.readAll();
        f.close();
        QFile::remove(pfad);
        QVERIFY(!roh.startsWith("\xEF\xBB\xBF"));
        QVERIFY(roh.startsWith("Addr,Tag"));

        // PDF nutzt dieselbe Aufbereitung (SPS-EXPORT-03)
        const QString pdf = m_projPfad + "_io.pdf";
        QVERIFY(m_db->spsExportPdfSpeichern(1, "Testprojekt", pdf, konfig));
        QVERIFY(QFileInfo(pdf).size() > 500);
        QFile::remove(pdf);
        QVERIFY(!m_db->spsExportPdfSpeichern(1, "Testprojekt", pdf, R"({"spalten":[]})"));
    }

    // SPS-EXPORT-04: Schemata je Signalart
    void sps_04b_exportSchemata()
    {
        const int r = m_db->spsRackAnlegen(1, 96, "PLS", "Messwarte", "ACME");
        const int bgAi = m_db->spsBaugruppeAnlegen(r, 2, "AI", "AI 4", 4, 0);
        const int bgDi = m_db->spsBaugruppeAnlegen(r, 3, "DI", "DI 4", 4, 0);
        QVERIFY(r > 0 && bgAi > 0 && bgDi > 0);
        const int kA = m_db->spsKanalAnlegen(1, bgAi, 0, "E", 0, 0, "REAL", "TIC-1", "");
        QVERIFY(m_db->spsKanalAktualisieren(kA, {{"pls_einheit", "°C"}, {"pls_alarm_hh", 80.0}}));
        QVERIFY(m_db->spsKanalAnlegen(1, bgDi, 0, "E", 0, 0, "BOOL", "XS-1", "") > 0);

        // Standard = Adresse;Tag, nur AI hat ein eigenes Schema mit Einheit und HH
        const QString konfig = R"({"spalten":[{"feld":"adresse","titel":"Addr"},{"feld":"variablenname","titel":"Tag"}],
            "schemata":{"AI":{"spalten":[{"feld":"adresse","titel":"Addr"},{"feld":"einheit","titel":"Unit"},
                                          {"feld":"alarm_hh","titel":"HH"}]}},
            "trennzeichen":";","dezimal":".","kopfzeile":true,"bom":false,"anfuehrung":"bei_bedarf",
            "ausgabe":"einzeln","filter":{"rack":"96"}})";
        const QVariantMap v = m_db->spsExportVorschau(1, konfig, -1);
        QVERIFY2(v["fehler"].toString().isEmpty(), qPrintable(v["fehler"].toString()));
        QCOMPARE(v["zeilen"].toInt(), 2);
        const QVariantList g = v["gruppen"].toList();
        QCOMPARE(g.size(), 2);
        QCOMPARE(g[0].toMap()["schema"].toString(), QString("Standard"));
        QCOMPARE(g[0].toMap()["text"].toString(), QString("Addr;Tag\nR96 S3 K1;XS-1\n"));
        QCOMPARE(g[1].toMap()["schema"].toString(), QString("AI"));
        QCOMPARE(g[1].toMap()["text"].toString(), QString("Addr;Unit;HH\nR96 S2 K1;°C;80\n"));
        // Gesamttext: Abschnitte durch Leerzeile
        QVERIFY(v["text"].toString().contains("XS-1\n\nAddr;Unit;HH"));

        // CSV „einzeln": zwei Dateien mit Suffix, Basisname bleibt frei
        const QString basis = m_projPfad + "_schema.csv";
        QVERIFY(m_db->spsExportCsvSpeichern(1, basis, konfig));
        const QString dAi = m_projPfad + "_schema_AI.csv";
        const QString dStd = m_projPfad + "_schema_Standard.csv";
        QVERIFY(QFileInfo::exists(dAi) && QFileInfo::exists(dStd));
        QVERIFY(!QFileInfo::exists(basis));
        QFile::remove(dAi); QFile::remove(dStd);

        // CSV „eine_datei": eine Datei mit beiden Abschnitten
        QString k2 = konfig;
        k2.replace("\"einzeln\"", "\"eine_datei\"");
        QVERIFY(m_db->spsExportCsvSpeichern(1, basis, k2));
        QVERIFY(QFileInfo::exists(basis));
        QFile::remove(basis);

        // Filter auf eine Signalart → nur eine Gruppe, Dateiname unverändert
        QString k3 = konfig;
        k3.replace("\"filter\":{\"rack\":\"96\"}", "\"filter\":{\"rack\":\"96\",\"signal\":\"AI\"}");
        QVERIFY(m_db->spsExportCsvSpeichern(1, basis, k3));
        QVERIFY(QFileInfo::exists(basis));
        QFile::remove(basis);

        // PDF mit mehreren Schemata
        const QString pdf = m_projPfad + "_schema.pdf";
        QVERIFY(m_db->spsExportPdfSpeichern(1, "Testprojekt", pdf, konfig));
        QVERIFY(QFileInfo(pdf).size() > 500);
        QFile::remove(pdf);

        // Schema ohne Spalten ist ein Fehler; Vorschlagsliste
        QString k4 = R"({"spalten":[{"feld":"adresse"}],"schemata":{"DI":{"spalten":[]}}})";
        QVERIFY(!m_db->spsExportVorschau(1, k4, 5)["fehler"].toString().isEmpty());
        QVERIFY(m_db->spsExportSchemaIrrelevanteFelder("DI").contains("alarm_ll"));
        QVERIFY(!m_db->spsExportSchemaIrrelevanteFelder("AI").contains("einheit"));
    }

    // SPS-EXPORT-05: abgeleitete Felder, Anlage/Ort samt Filter, Platzhalter-Text
    void sps_04c_exportAbgeleiteteFelder()
    {
        const int r = m_db->spsRackAnlegen(1, 97, "SPS", "Schrank", "ACME");
        const int bgDi = m_db->spsBaugruppeAnlegen(r, 1, "DI", "DI 8", 8, 0);
        const int bgAi = m_db->spsBaugruppeAnlegen(r, 2, "AI", "AI 4", 4, 64);
        QVERIFY(r > 0 && bgDi > 0 && bgAi > 0);
        const int k1 = m_db->spsKanalAnlegen(1, bgDi, 0, "E", 0, 3, "BOOL", "XS-1", "");
        QVERIFY(m_db->spsKanalAnlegen(1, bgDi, 1, "E", 0, 5, "BOOL", "XS-2", "") > 0);
        const int k3 = m_db->spsKanalAnlegen(1, bgAi, 1, "E", 64, 0, "WORD", "TIC-1", "");
        QVERIFY(k1 > 0 && k3 > 0);
        QVERIFY(m_db->spsKanalAktualisieren(k3, {{"pls_bereich_min", 10.0}, {"pls_bereich_max", 60.0}}));

        // k1 bekommt ein Schaltplan-Element (Anlage/Ort der Seite, Freitext aus extra_daten)
        const int sid = neueSeite("1");
        QVERIFY(m_db->grafikSpeichern(sid, {symbol("sps_eingang", 0, 0)}));
        const int geId = m_db->grafikLaden(sid)[0].toMap()["id"].toInt();
        QVERIFY(ins(QString("UPDATE grafik_element SET extra_daten='{\"bmk\":\"-B1\",\"freitext1\":\"Fz\"}' WHERE id=%1").arg(geId)) >= 0);
        QVERIFY(ins(QString("UPDATE sps_kanal SET grafik_element_id=%1 WHERE id=%2").arg(geId).arg(k1)) >= 0);
        const QString anlage = einWert("SELECT kuerzel FROM anlage LIMIT 1").toString();
        const QString ort    = einWert("SELECT kuerzel FROM ort LIMIT 1").toString();

        const QString konfig = QString(R"({"spalten":[
            {"feld":"variablenname","titel":"Tag"},{"feld":"adresse_iec"},{"feld":"richtung"},
            {"feld":"analog_digital"},{"feld":"rack_slot_kanal"},{"feld":"kanal_absolut"},
            {"feld":"baugruppen_bereich"},{"feld":"alarm_vorhanden"},{"feld":"spannweite"},
            {"feld":"anlage"},{"feld":"ort"},{"feld":"freitext1"},
            {"feld":"fest","titel":"Text","wert":"{anlage}_{variablenname}-{unbekannt}-{fest}"}],
            "trennzeichen":";","dezimal":".","kopfzeile":false,"bom":false,"anfuehrung":"bei_bedarf",
            "filter":{"rack":"97"}})");
        const QVariantMap v = m_db->spsExportVorschau(1, konfig, -1);
        QVERIFY2(v["fehler"].toString().isEmpty(), qPrintable(v["fehler"].toString()));
        const QStringList z = v["text"].toString().split('\n', Qt::SkipEmptyParts);
        QCOMPARE(z.size(), 3);
        // Reihenfolge: Slot 1 Kanal 1, Slot 1 Kanal 2, Slot 2 Kanal 2
        QCOMPARE(z[0], QString("XS-1;%IX0.3;Eingang;digital;R97.S1.K1;1;E0.3–E0.5;nein;;%1;%2;Fz;%1_XS-1-{unbekannt}-{fest}")
                           .arg(anlage, ort));
        QCOMPARE(z[1], QString("XS-2;%IX0.5;Eingang;digital;R97.S1.K2;2;E0.3–E0.5;nein;;;;;_XS-2-{unbekannt}-{fest}"));
        // AI: 8 Kanäle der DI-Karte davor + Kanal 2 = 10; belegter Bereich nur ein Kanal
        QCOMPARE(z[2], QString("TIC-1;%IW64;Eingang;analog;R97.S2.K2;10;EW64;nein;50;;;;_TIC-1-{unbekannt}-{fest}"));

        // Filter Anlage/Ort: nur Kanäle mit Element auf dieser Anlage/diesem Ort
        const QString kA = QString(R"({"spalten":[{"feld":"variablenname"}],"kopfzeile":false,
            "filter":{"anlage":"%1","ort":"%2"}})").arg(anlage, ort);
        QCOMPARE(m_db->spsExportVorschau(1, kA, -1)["zeilen"].toInt(), 1);
        const QString kB = QString(R"({"spalten":[{"feld":"variablenname"}],"kopfzeile":false,
            "filter":{"anlage":"gibtsnicht"}})");
        QCOMPARE(m_db->spsExportVorschau(1, kB, -1)["zeilen"].toInt(), 0);

        const QVariantMap fw = m_db->spsExportFilterWerte(1);
        QVERIFY(fw["anlagen"].toStringList().contains(anlage));
        QVERIFY(fw["orte"].toStringList().contains(ort));

        // Katalog: abgeleitete Felder sind nicht importierbar, Standardfelder schon
        bool ioFeldGefunden = false;
        for (const QVariant &fv : m_db->spsExportFeldKatalog()) {
            const QVariantMap f = fv.toMap();
            if (f["feld"].toString() == "richtung") { QVERIFY(!f["importierbar"].toBool()); ioFeldGefunden = true; }
            if (f["feld"].toString() == "variablenname") QVERIFY(f["importierbar"].toBool());
        }
        QVERIFY(ioFeldGefunden);
    }

    // SPS-EXPORT-06: Präfix/Suffix, Sortierung, leere Spalten ausblenden, Verdrahtung (nur eindeutig)
    void sps_04d_exportSortierungUndVerdrahtung()
    {
        const int r = m_db->spsRackAnlegen(1, 98, "SPS", "Schrank", "ACME");
        const int bg = m_db->spsBaugruppeAnlegen(r, 1, "DI", "DI 8", 8, 0);
        QVERIFY(r > 0 && bg > 0);
        const int k1 = m_db->spsKanalAnlegen(1, bg, 0, "E", 0, 0, "BOOL", "B10", "");
        const int k2 = m_db->spsKanalAnlegen(1, bg, 1, "E", 0, 1, "BOOL", "B2", "");
        const int k3 = m_db->spsKanalAnlegen(1, bg, 2, "E", 0, 2, "BOOL", "", "");
        QVERIFY(k1 > 0 && k2 > 0 && k3 > 0);

        // Sortierung natürlich (B2 vor B10), absteigend, leere Werte zuletzt; Präfix/Suffix nur bei Wert
        const QString kSort = R"({"spalten":[{"feld":"variablenname","titel":"Tag","prefix":"<","suffix":">"},
            {"feld":"einheit","titel":"Einheit"}],"kopfzeile":false,"trennzeichen":";","anfuehrung":"bei_bedarf",
            "sortierung":[{"feld":"variablenname"}],"filter":{"rack":"98"}})";
        QStringList z = m_db->spsExportVorschau(1, kSort, -1)["text"].toString().split('\n', Qt::SkipEmptyParts);
        QCOMPARE(z.size(), 3);
        QCOMPARE(z[0], QString("<B2>;"));
        QCOMPARE(z[1], QString("<B10>;"));
        QCOMPARE(z[2], QString(";"));            // leerer Tag zuletzt, kein Präfix/Suffix
        QString kAb = kSort;
        kAb.replace(R"("sortierung":[{"feld":"variablenname"}])", R"("sortierung":[{"feld":"variablenname","absteigend":true}])");
        z = m_db->spsExportVorschau(1, kAb, -1)["text"].toString().split('\n', Qt::SkipEmptyParts);
        QCOMPARE(z[0], QString("<B10>;"));
        QCOMPARE(z[1], QString("<B2>;"));

        // leere Spalten ausblenden: Einheit ist überall leer
        QString kLeer = kSort;
        kLeer.replace(R"("kopfzeile":false,)", R"("kopfzeile":true,"leere_ausblenden":true,)");
        const QVariantMap vl = m_db->spsExportVorschau(1, kLeer, -1);
        QVERIFY(vl["text"].toString().startsWith("Tag\n"));

        // Verdrahtung: Kanal-Element K (sps_di_einpolig) — Netz — Gerät G (ventil)
        const int sid = neueSeite("1");
        const QString pinX = einWert("SELECT x FROM symbol_pin WHERE symbol_id='ventil' ORDER BY id LIMIT 1").toString();
        const QString pinY = einWert("SELECT y FROM symbol_pin WHERE symbol_id='ventil' ORDER BY id LIMIT 1").toString();
        QVERIFY2(!pinX.isEmpty(), "Symbol ventil ohne Pins");
        const double gx = 50, gy = 50, gs = 8;
        const double px = gx + gs / 2 + (pinX.toDouble() - 0.5) * gs;
        const double py = gy + gs / 2 + (pinY.toDouble() - 0.5) * gs;
        QVERIFY(m_db->grafikSpeichern(sid, {symbol("sps_di_einpolig", 0, 0), symbol("ventil", gx, gy)}));
        const QVariantList el = m_db->grafikLaden(sid);
        int kId = 0, gId = 0;
        for (const QVariant &e : el) {
            if (e.toMap()["symbolId"].toString() == "sps_di_einpolig") kId = e.toMap()["id"].toInt();
            if (e.toMap()["symbolId"].toString() == "ventil") gId = e.toMap()["id"].toInt();
        }
        QVERIFY(kId > 0 && gId > 0);
        QVERIFY(ins(QString("UPDATE grafik_element SET extra_daten='{\"bmk\":\"-Y1\",\"freitext1\":\"Heizung\"}' WHERE id=%1").arg(gId)) >= 0);
        QVERIFY(ins(QString("UPDATE sps_kanal SET grafik_element_id=%1 WHERE id=%2").arg(kId).arg(k1)) >= 0);
        const int net = ins("INSERT INTO verbindung (projekt_id, bezeichnung) VALUES (1,'N1')");
        const QString pts = QString("[{\"x\":2,\"y\":0},{\"x\":%1,\"y\":%2}]").arg(px).arg(py);
        QVERIFY(ins(QString("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (%1,%2,'%3')")
                        .arg(net).arg(sid).arg(pts)) > 0);
        const int kabel = ins("INSERT INTO kabel (projekt_id, bezeichnung) VALUES (1,'W1')");
        QVERIFY(ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr, farbe, verbindung_id) VALUES (%1,3,'BN',%2)")
                        .arg(kabel).arg(net)) > 0);

        const QString kVw = R"({"spalten":[{"feld":"variablenname"},{"feld":"gegenstelle_bmk"},
            {"feld":"gegenstelle_anschluss"},{"feld":"kabel"},{"feld":"ader"}],
            "kopfzeile":false,"trennzeichen":";","anfuehrung":"bei_bedarf","filter":{"rack":"98"}})";
        z = m_db->spsExportVorschau(1, kVw, -1)["text"].toString().split('\n', Qt::SkipEmptyParts);
        QCOMPARE(z.filter("B10;-Y1;").size(), 1);
        QVERIFY2(z.filter("B10;-Y1;").first().endsWith(";W1;3 (BN)"), qPrintable(z.join('|')));

        // Freitext der Gegenstelle (direkter Nachbar)
        const QString kFt = R"({"spalten":[{"feld":"gegenstelle_freitext1"}],"kopfzeile":false,"filter":{"rack":"98"}})";
        QVERIFY(m_db->spsExportVorschau(1, kFt, -1)["text"].toString().contains("Heizung"));

        // Verzweigung: zweite Ader im selben Netz → Kabel/Ader bleiben leer, Gegenstelle bleibt
        QVERIFY(ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr, verbindung_id) VALUES (%1,4,%2)")
                        .arg(kabel).arg(net)) > 0);
        z = m_db->spsExportVorschau(1, kVw, -1)["text"].toString().split('\n', Qt::SkipEmptyParts);
        QVERIFY2(z.filter("B10;-Y1;").first().endsWith(";;"), qPrintable(z.join('|')));
    }

    // SPS-EXPORT-07: Verdrahtungsweg über Klemmen und Kabel hinweg
    void sps_04e_exportVerdrahtungsweg()
    {
        const int r = m_db->spsRackAnlegen(1, 99, "SPS", "Schrank", "ACME");
        const int bg = m_db->spsBaugruppeAnlegen(r, 1, "DI", "DI 8", 8, 0);
        const int k1 = m_db->spsKanalAnlegen(1, bg, 0, "E", 0, 0, "BOOL", "B1", "");
        QVERIFY(r > 0 && bg > 0 && k1 > 0);

        auto pinPos = [&](const QString &sym, double x, double y, double s) {
            const double px = einWert(QString("SELECT x FROM symbol_pin WHERE symbol_id='%1' ORDER BY id LIMIT 1").arg(sym)).toDouble();
            const double py = einWert(QString("SELECT y FROM symbol_pin WHERE symbol_id='%1' ORDER BY id LIMIT 1").arg(sym)).toDouble();
            return QPointF(x + s / 2 + (px - 0.5) * s, y + s / 2 + (py - 0.5) * s);
        };
        const int sid = neueSeite("1");
        QVERIFY(m_db->grafikSpeichern(sid, {symbol("sps_di_einpolig", 0, 0), symbol("klemme_anschluss", 30, 0),
                                            symbol("klemme_anschluss", 30, 30), symbol("ventil", 60, 60)}));
        QMap<QString, QList<int>> ids;
        for (const QVariant &e : m_db->grafikLaden(sid))
            ids[e.toMap()["symbolId"].toString()].append(e.toMap()["id"].toInt());
        QVERIFY(ids["klemme_anschluss"].size() == 2 && ids["ventil"].size() == 1 && ids["sps_di_einpolig"].size() == 1);

        const int leiste = ins("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (1,'X1')");
        const int klemme = ins(QString("INSERT INTO klemme (klemmenleiste_id, nummer) VALUES (%1,'3')").arg(leiste));
        QVERIFY(leiste > 0 && klemme > 0);
        QVERIFY(ins(QString("UPDATE grafik_element SET extra_daten='{\"klemmeId\":%1,\"anschlussBezeichnung\":\"1.1\"}' WHERE id=%2")
                        .arg(klemme).arg(ids["klemme_anschluss"][0])) >= 0);
        QVERIFY(ins(QString("UPDATE grafik_element SET extra_daten='{\"klemmeId\":%1,\"anschlussBezeichnung\":\"1.2\"}' WHERE id=%2")
                        .arg(klemme).arg(ids["klemme_anschluss"][1])) >= 0);
        QVERIFY(ins(QString("UPDATE grafik_element SET extra_daten='{\"bmk\":\"-Y1\",\"freitext1\":\"Ventil Z\",\"freitext2\":\"24V\"}' WHERE id=%1").arg(ids["ventil"][0])) >= 0);
        QVERIFY(ins(QString("UPDATE sps_kanal SET grafik_element_id=%1 WHERE id=%2").arg(ids["sps_di_einpolig"][0]).arg(k1)) >= 0);

        const QPointF pK  = pinPos("sps_di_einpolig", 0, 0, 8);
        const QPointF pA1 = pinPos("klemme_anschluss", 30, 0, 8);
        const QPointF pA2 = pinPos("klemme_anschluss", 30, 30, 8);
        const QPointF pV  = pinPos("ventil", 60, 60, 8);
        auto netz = [&](const QPointF &a, const QPointF &b) {
            const int n = ins("INSERT INTO verbindung (projekt_id) VALUES (1)");
            const QString pts = QString("[{\"x\":%1,\"y\":%2},{\"x\":%3,\"y\":%4}]").arg(a.x()).arg(a.y()).arg(b.x()).arg(b.y());
            ins(QString("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (%1,%2,'%3')").arg(n).arg(sid).arg(pts));
            return n;
        };
        netz(pK, pA1);
        const int n2 = netz(pA2, pV);
        const int kabel = ins("INSERT INTO kabel (projekt_id, bezeichnung) VALUES (1,'W1')");
        QVERIFY(ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr, verbindung_id) VALUES (%1,3,%2)").arg(kabel).arg(n2)) > 0);

        const QString kfg = R"({"spalten":[{"feld":"variablenname"},{"feld":"kette"},{"feld":"ziel_bmk"},
            {"feld":"gegenstelle_bmk"}],"kopfzeile":false,"trennzeichen":";","anfuehrung":"bei_bedarf",
            "filter":{"rack":"99"}})";
        QStringList z = m_db->spsExportVorschau(1, kfg, -1)["text"].toString().split('\n', Qt::SkipEmptyParts);
        QCOMPARE(z.size(), 1);
        // Gegenstelle direkt am Kanal: nur Klemme, kein Gerät → leer; Weg führt bis zum Ventil
        QCOMPARE(z[0], QString("B1;X1:3 → W1/3 → -Y1:A1;-Y1;"));

        // Freitexte des Zielgeräts
        const QString kfgFt = R"({"spalten":[{"feld":"ziel_freitext1"},{"feld":"ziel_freitext2"}],
            "kopfzeile":false,"trennzeichen":";","filter":{"rack":"99"}})";
        QCOMPARE(m_db->spsExportVorschau(1, kfgFt, -1)["text"].toString().trimmed(), QString("\"Ventil Z\";\"24V\""));

        // Verzweigung: zweite Ader im Netz hinter der Klemme → Weg bleibt leer
        QVERIFY(ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr, verbindung_id) VALUES (%1,4,%2)").arg(kabel).arg(n2)) > 0);
        z = m_db->spsExportVorschau(1, kfg, -1)["text"].toString().split('\n', Qt::SkipEmptyParts);
        QVERIFY2(z.size() == 1 && z[0] == "B1;;;", qPrintable(z.join('|')));
    }

    // ── SPS-IMPORT-01 ────────────────────────────────────────────
    QString csvSchreiben(const QString &name, const QString &inhalt)
    {
        const QString pfad = m_projPfad + "_" + name;
        QFile f(pfad);
        f.open(QIODevice::WriteOnly);
        f.write(inhalt.toUtf8());
        f.close();
        return pfad;
    }
    static QString konfigJson(const QStringList &spalten, const QString &system, const QString &modus,
                              bool hw = true)
    {
        QJsonArray sp;
        for (const QString &s : spalten) sp.append(s);
        QJsonObject o{{"spalten", sp}, {"systemStandard", system}, {"vorhandene", modus},
                      {"hardwareAnlegen", hw}, {"kopfzeile", true}, {"dezimal", ","}};
        return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
    }

    void sps_05_csvImport()
    {
        // (A) Eigenes Export-Format: Spalten werden über die Titel automatisch erkannt (PLS)
        const QString a = csvSchreiben("imp_a.csv",
            "System;Rack;Slot;Kanal;Baugruppe;Baugruppen-Typ;Signal;Adresse;Datentyp;Variable / Tag;Kommentar;Einheit;Bereich Min;Bereich Max\n"
            "PLS;120;4;1;AI Karte;AI;AI;R120 S4 K1;REAL;TIC-100;Reaktor;\xC2\xB0" "C;0;500\n"
            "PLS;120;4;2;AI Karte;AI;AI;R120 S4 K2;REAL;PIC-100;Druck;bar;0;\"16,5\"\n"
            "PLS;120;5;1;;;DO;;;XV-1;Ventil;;;\n");
        const QVariantMap l = m_db->spsImportLesen(a);
        QVERIFY2(l["fehler"].toString().isEmpty(), qPrintable(l["fehler"].toString()));
        QCOMPARE(l["zeilen"].toInt(), 3);
        const QStringList vs = l["vorschlag"].toStringList();
        QCOMPARE(vs[1], QString("rack"));
        QCOMPARE(vs[9], QString("variablenname"));
        QCOMPARE(vs[12], QString("bereich_min"));

        const QString kA = konfigJson(vs, "PLS", "auffuellen");
        QVariantMap p = m_db->spsImportPruefen(1, a, kA);
        QCOMPARE(p["neueRacks"].toInt(), 1);
        QCOMPARE(p["neueBaugruppen"].toInt(), 2);
        QCOMPARE(p["neueKanaele"].toInt(), 3);
        QCOMPARE(p["fehlerhaft"].toInt(), 0);
        // Trockenlauf schreibt nichts
        QCOMPARE(einWert("SELECT COUNT(*) FROM sps_rack WHERE rack_nr=120").toInt(), 0);

        QVariantMap r = m_db->spsImportAusfuehren(1, a, kA);
        QVERIFY2(r["ausgefuehrt"].toBool(), qPrintable(r["fehler"].toString()));
        QCOMPARE(r["racksNeu"].toList().size(), 1);
        QCOMPARE(r["racksNeu"].toList()[0].toInt(), 120);
        QCOMPARE(einWert("SELECT system_typ FROM sps_rack WHERE rack_nr=120").toString(), QString("PLS"));
        QCOMPARE(einWert("SELECT typ FROM sps_baugruppe b JOIN sps_rack r ON r.id=b.rack_id "
                         "WHERE r.rack_nr=120 AND b.slot=4").toString(), QString("AI"));
        QCOMPARE(einWert("SELECT kanaele FROM sps_baugruppe b JOIN sps_rack r ON r.id=b.rack_id "
                         "WHERE r.rack_nr=120 AND b.slot=4").toInt(), 2);
        QCOMPARE(einWert("SELECT typ FROM sps_baugruppe b JOIN sps_rack r ON r.id=b.rack_id "
                         "WHERE r.rack_nr=120 AND b.slot=5").toString(), QString("DO"));
        QCOMPARE(einWert("SELECT pls_bereich_max FROM sps_kanal WHERE variablenname='PIC-100'").toDouble(), 16.5);
        QCOMPARE(einWert("SELECT pls_einheit FROM sps_kanal WHERE variablenname='TIC-100'").toString(),
                 QString::fromUtf8("\xC2\xB0" "C"));
        QCOMPARE(einWert("SELECT adress_typ FROM sps_kanal WHERE variablenname='XV-1'").toString(), QString("A"));

        // Erneuter Import: alles vorhanden -> nichts neu, nichts geändert
        p = m_db->spsImportPruefen(1, a, kA);
        QCOMPARE(p["neueKanaele"].toInt(), 0);
        QCOMPARE(p["aktualisiert"].toInt(), 0);
        QCOMPARE(p["uebersprungen"].toInt(), 3);

        // Überschreiben ändert Felder, Auffüllen lässt Bestehendes stehen
        const QString a2 = csvSchreiben("imp_a2.csv",
            "Rack;Slot;Kanal;Variable / Tag;Kommentar\n120;4;1;TIC-100;Neu kommentiert\n");
        const QStringList sp2 = {"rack", "slot", "kanal", "variablenname", "kommentar"};
        p = m_db->spsImportPruefen(1, a2, konfigJson(sp2, "PLS", "auffuellen"));
        QCOMPARE(p["aktualisiert"].toInt(), 0);
        p = m_db->spsImportAusfuehren(1, a2, konfigJson(sp2, "PLS", "ueberschreiben"));
        QCOMPARE(p["aktualisiert"].toInt(), 1);
        QVERIFY(p["racksNeu"].toList().isEmpty());
        QCOMPARE(p["racksBetroffen"].toList()[0].toInt(), 120);
        QCOMPARE(einWert("SELECT kommentar FROM sps_kanal WHERE variablenname='TIC-100'").toString(),
                 QString("Neu kommentiert"));

        // (B) SPS mit Adresstexten (Siemens + IEC), Standard-System SPS
        const QString b = csvSchreiben("imp_b.csv",
            "Rack,Slot,Adresse,Tag\n"
            "130,2,E0.0,Start\n130,2,%IX0.1,Stop\n130,3,A0.0,Motor\n130,4,EW4,Pegel\n");
        const QStringList spB = {"rack", "slot", "adresse", "variablenname"};
        r = m_db->spsImportAusfuehren(1, b, konfigJson(spB, "SPS", "ueberspringen"));
        QVERIFY2(r["ausgefuehrt"].toBool(), qPrintable(r["fehler"].toString()));
        QCOMPARE(r["neueKanaele"].toInt(), 4);
        QCOMPARE(einWert("SELECT b.typ FROM sps_baugruppe b JOIN sps_rack r ON r.id=b.rack_id "
                         "WHERE r.rack_nr=130 AND b.slot=2").toString(), QString("DI"));
        QCOMPARE(einWert("SELECT b.typ FROM sps_baugruppe b JOIN sps_rack r ON r.id=b.rack_id "
                         "WHERE r.rack_nr=130 AND b.slot=4").toString(), QString("AI"));
        QCOMPARE(einWert("SELECT byte_nr||'.'||bit_nr FROM sps_kanal WHERE variablenname='Stop'").toString(),
                 QString("0.1"));
        QCOMPARE(einWert("SELECT datentyp FROM sps_kanal WHERE variablenname='Pegel'").toString(), QString("WORD"));
        // fortlaufende Kanalnummern je Richtung
        QCOMPARE(einWert("SELECT kanal_nr FROM sps_kanal WHERE variablenname='Stop'").toInt(), 1);

        // (C) Überlappung und CSV-interne Duplikate werden als Fehler gemeldet, nichts wird geschrieben
        const QString c = csvSchreiben("imp_c.csv",
            "Rack,Slot,Adresse,Tag\n130,2,EW0,Ueberlappt\n130,5,E8.0,Neu\n130,5,E8.0,Doppelt\n");
        p = m_db->spsImportPruefen(1, c, konfigJson(spB, "SPS", "auffuellen"));
        QCOMPARE(p["fehlerhaft"].toInt(), 2);
        QCOMPARE(p["neueKanaele"].toInt(), 1);

        // Hardware-Anlegen aus: unbekanntes Rack ist ein Fehler
        const QString d = csvSchreiben("imp_d.csv", "Rack,Slot,Adresse,Tag\n999,1,E0.0,X\n");
        p = m_db->spsImportPruefen(1, d, konfigJson(spB, "SPS", "auffuellen", false));
        QCOMPARE(p["fehlerhaft"].toInt(), 1);
        QCOMPARE(p["neueKanaele"].toInt(), 0);

        for (const QString &n : {"imp_a.csv", "imp_a2.csv", "imp_b.csv", "imp_c.csv", "imp_d.csv"})
            QFile::remove(m_projPfad + "_" + n);
    }

    // ── MCU-PINBELEGUNG-01 ───────────────────────────────────────
    // Weltposition eines Symbol-Pins (Rotation 0, ohne Spiegelung) – gleiche Formel wie im DRC
    QPointF pinWelt(const QString &symbolId, const QString &pin, double x1, double y1, double x2, double y2)
    {
        QSqlQuery q(QSqlDatabase::database());
        q.prepare("SELECT x, y FROM symbol_pin WHERE symbol_id=:s AND name=:n");
        q.bindValue(":s", symbolId);
        q.bindValue(":n", pin);
        if (!q.exec() || !q.next()) return {};
        return QPointF(x1 + q.value(0).toDouble() * (x2 - x1), y1 + q.value(1).toDouble() * (y2 - y1));
    }
    int netzAnlegen(int seiteId, const QPointF &a, const QPointF &b, const QString &name)
    {
        const int v = ins(QString("INSERT INTO verbindung (projekt_id, bezeichnung) VALUES (1,'%1')").arg(name));
        const QString pkt = QString("[{\"x\":%1,\"y\":%2},{\"x\":%3,\"y\":%4}]")
                                .arg(a.x()).arg(a.y()).arg(b.x()).arg(b.y());
        ins(QString("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (%1,%2,'%3')")
                .arg(v).arg(seiteId).arg(pkt));
        return v;
    }

    void mcu_01_pinbelegung()
    {
        // Migration 162: nur die drei Boards sind markiert, Sensoren nicht
        QCOMPARE(einWert("SELECT ist_mikrocontroller FROM symbol_definition WHERE id='ard_uno'").toInt(), 1);
        QCOMPARE(einWert("SELECT ist_mikrocontroller FROM symbol_definition WHERE id='ard_hcsr04'").toInt(), 0);

        const int sid = neueSeite("MCU");
        QVariantMap board = symbol("ard_uno", 0, 0, {{"bmk", "A1"}});
        board["x2"] = 32.0; board["y2"] = 64.0;
        QVariantMap sensor = symbol("ard_hcsr04", 100, 0, {{"bmk", "B1"}});
        sensor["x2"] = 116.0; sensor["y2"] = 20.0;
        QVariantMap led = symbol("ard_pir", 100, 40, {{"bmk", "B2"}});
        led["x2"] = 116.0; led["y2"] = 56.0;
        QVERIFY(m_db->grafikSpeichern(sid, {board, sensor, led}));

        // D7 ↔ HC-SR04 TRIG, A0 ↔ PIR OUT, D3 bleibt frei
        netzAnlegen(sid, pinWelt("ard_uno", "D7", 0, 0, 32, 64), pinWelt("ard_hcsr04", "TRIG", 100, 0, 116, 20), "N_TRIG");
        netzAnlegen(sid, pinWelt("ard_uno", "A0", 0, 0, 32, 64), pinWelt("ard_pir", "OUT", 100, 40, 116, 56), "N_PIR");

        const QVariantList z = m_db->mikrocontrollerPinbelegung(1);
        QVERIFY(!z.isEmpty());
        QVariantMap d7, a0, d3;
        for (const QVariant &v : z) {
            const QVariantMap m = v.toMap();
            if (m["boardBmk"].toString() != "A1") continue;
            if (m["pin"].toString() == "D7") d7 = m;
            if (m["pin"].toString() == "A0") a0 = m;
            if (m["pin"].toString() == "D3") d3 = m;
        }
        QCOMPARE(d7["verbundenBmk"].toString(), QString("B1"));
        QCOMPARE(d7["verbundenPin"].toString(), QString("TRIG"));
        QCOMPARE(d7["netz"].toString(), QString("N_TRIG"));
        QCOMPARE(d7["defineName"].toString(), QString("B1_TRIG"));
        QCOMPARE(d7["defineWert"].toString(), QString("7"));
        QCOMPARE(a0["verbundenBmk"].toString(), QString("B2"));
        QCOMPARE(a0["defineWert"].toString(), QString("A0"));
        QVERIFY(d3["istFrei"].toBool());
        QVERIFY(d3["defineName"].toString().isEmpty());
        // die Sensoren sind keine Boards: keine eigenen Zeilen
        for (const QVariant &v : z) QVERIFY(v.toMap()["boardBmk"].toString() != "B1");

        const QString code = m_db->mikrocontrollerCode(1);
        QVERIFY2(code.contains("#define B1_TRIG 7"), qPrintable(code));
        QVERIFY(code.contains("#define B2_OUT A0"));

        // Editor-Flag setzbar (eigenes Board-Symbol)
        QVERIFY(!einWert("SELECT 1 FROM symbol_definition WHERE id='ard_dht' AND ist_mikrocontroller=1").isValid());
    }

    void gs_07_kabellinieUndAderzuordnungWerdenNachgezogen()
    {
        const int sid = neueSeite("1"), anderes = neueSeite("2");
        const int kabel = ins("INSERT INTO kabel (projekt_id, bezeichnung) VALUES (1,'W1')");
        QVERIFY(kabel > 0);
        const int a1 = ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr) VALUES (%1,1)").arg(kabel));
        const int a2 = ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr) VALUES (%1,2)").arg(kabel));
        QVERIFY(a1 > 0 && a2 > 0);

        QVERIFY(m_db->grafikSpeichern(sid, {elem("kabellinie", 0, 0, 50, 0, {{"kabelId", kabel}})}));
        const int geid = m_db->grafikLaden(sid)[0].toMap()["id"].toInt();
        QVERIFY(ins(QString("UPDATE kabel SET grafik_element_id=%1 WHERE id=%2").arg(geid).arg(kabel)) >= 0);
        QVERIFY(ins(QString("UPDATE kabel_ader SET kabellinie_grafik_element_id=%1 WHERE id=%2").arg(geid).arg(a1)) >= 0);

        // Andere Seite belegt die nächsten IDs → die Kabellinie bekommt beim Re-Save eine neue ID
        QVERIFY(m_db->grafikSpeichern(anderes, {elem("linie", 0, 0, 1, 1), elem("linie", 0, 0, 2, 2)}));
        QVERIFY(m_db->grafikSpeichern(sid, m_db->grafikLaden(sid)));
        const int neu = m_db->grafikLaden(sid)[0].toMap()["id"].toInt();
        QVERIFY(neu != geid);
        QCOMPARE(einWert(QString("SELECT grafik_element_id FROM kabel WHERE id=%1").arg(kabel)).toInt(), neu);
        QCOMPARE(einWert(QString("SELECT kabellinie_grafik_element_id FROM kabel_ader WHERE id=%1").arg(a1)).toInt(), neu);
        QVERIFY2(einWert(QString("SELECT kabellinie_grafik_element_id FROM kabel_ader WHERE id=%1").arg(a2)).isNull(),
                 "Nicht zugeordnete Ader darf der Kabellinie nicht zugeordnet werden");
        // Die echte FK-Spalte kabel_id wird aus extraDaten.kabelId befüllt
        QCOMPARE(einWert(QString("SELECT kabel_id FROM grafik_element WHERE id=%1").arg(neu)).toInt(), kabel);
    }

    void gs_08_unbekannteKabelIdWirdNull()
    {
        const int sid = neueSeite("1");
        // kabelId verweist auf ein Kabel, das es in diesem Projekt nicht gibt (z.B. nach Cross-Projekt-Einfügen)
        QVERIFY(m_db->grafikSpeichern(sid, {elem("kabellinie", 0, 0, 10, 0, {{"kabelId", 4711}})}));
        QCOMPARE(m_db->grafikLaden(sid).size(), 1);
        QVERIFY(einWert("SELECT kabel_id FROM grafik_element WHERE typ='kabellinie'").isNull());
    }

    void gs_09_betriebsmittelVerknuepfungBleibtAmElement()
    {
        const int sid = neueSeite("1");
        const int bm = ins("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz) VALUES (1,'M1')");
        QVariantMap s = symbol("motor", 0, 0);
        s["betriebsmittelId"] = bm;
        s["gruppeId"] = 3;
        QVERIFY(m_db->grafikSpeichern(sid, {s, elem("linie", 0, 0, 1, 1)}));
        const QVariantList l = m_db->grafikLaden(sid);
        QCOMPARE(l[0].toMap()["betriebsmittelId"].toInt(), bm);
        QCOMPARE(l[0].toMap()["gruppeId"].toInt(), 3);
        QVERIFY(!l[1].toMap().contains("betriebsmittelId"));
        QVERIFY(!l[1].toMap().contains("gruppeId"));
    }

    // ════════════════════════════════════════════════════════════
    // PDF-Referenzexport (Hilfswerkzeug, kein Regressionstest)
    // ════════════════════════════════════════════════════════════
    // Exportiert eine KOPIE eines echten Projekts in allen Options-Kombinationen, damit vor/nach einem
    // Umbau von Database_PDF.cpp die Ausgabe (gerendert) verglichen werden kann. Läuft nur, wenn gesetzt:
    //   STROEMLING_PDF_PROJEKT  = Pfad der Projekt-KOPIE (.strl, per `sqlite3 .backup` erzeugt)
    //   STROEMLING_PDF_BIB      = Pfad der Bibliothek-KOPIE
    //   STROEMLING_PDF_AUSGABE  = Zielordner für die PDFs
    // Echte Nutzerdaten werden nie ins Repo übernommen; die Eingaben liegen außerhalb des Repos.
    void pdf_referenzexport()
    {
        const QString proj = qEnvironmentVariable("STROEMLING_PDF_PROJEKT");
        const QString bib  = qEnvironmentVariable("STROEMLING_PDF_BIB");
        const QString aus  = qEnvironmentVariable("STROEMLING_PDF_AUSGABE");
        if (proj.isEmpty() || aus.isEmpty())
            QSKIP("STROEMLING_PDF_PROJEKT/STROEMLING_PDF_AUSGABE nicht gesetzt");
        QDir().mkpath(aus);
        m_db->closeProjekt();
        if (!bib.isEmpty())
            QVERIFY2(m_db->openBibliothek(bib), "Bibliothek-Kopie konnte nicht geöffnet werden");
        QVERIFY2(m_db->openProjekt(proj), "Projekt-Kopie konnte nicht geöffnet werden");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        QVERIFY(pid > 0);
        for (int nb = 0; nb <= 1; ++nb) {
            const QString f = QString("%1/nb%2.pdf").arg(aus).arg(nb);
            QVERIFY2(schaltplanPdf(pid, f, nb), qPrintable(f));
        }
    }

    // Synthetisches Projekt für den PDF-Vergleich vor/nach Umbauten: deckt Symbol-Sonderfälle ab, die
    // ein reales Projekt evtl. nicht enthält (klemme_anschluss in allen Rotationen/BMK-Sichtbarkeiten,
    // Gegenstellen-Zeile, querverweis, potenzial, aderdefinition). Nur mit STROEMLING_PDF_SYNTH=<Ausgabeordner>.
    void pdf_synthetik()
    {
        const QString aus = qEnvironmentVariable("STROEMLING_PDF_SYNTH");
        if (aus.isEmpty()) QSKIP("STROEMLING_PDF_SYNTH nicht gesetzt");
        QDir().mkpath(aus);
        const int kl = ins("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (1,'X1')");
        const int k1 = ins(QString("INSERT INTO klemme (klemmenleiste_id, nummer, sortierung) VALUES (%1,'1',1)").arg(kl));
        const int sid = neueSeite("1");
        QVariantList els;
        const int rots[4] = {0, 90, 180, 270};
        for (int i = 0; i < 4; ++i) {
            QVariantMap ka = symbol("klemme_anschluss", 20 + i * 40, 20,
                {{"klemmeId", k1}, {"anschlussBezeichnung", QString("1.%1").arg(i + 1)},
                 {"bmk", QString("=A+B-X1:%1").arg(i + 1)}, {"rotation", rots[i]},
                 {"bmkOffsetX", i * 0.5}, {"bmkOffsetY", i * 0.25}});
            ka["rotation"] = rots[i];
            els << ka;
        }
        // BMK-Sichtbarkeits-Varianten (Anlage/Ort/Gerät einzeln aus)
        els << symbol("klemme_anschluss", 20, 70, {{"klemmeId", k1}, {"anschlussBezeichnung", "PE"},
                      {"bmk", "=A+B-X1:PE"}, {"anlageAnzeigen", false}, {"ortAnzeigen", true}, {"geraetAnzeigen", false}});
        els << symbol("klemme_anschluss", 60, 70, {{"klemmeId", k1}, {"anschlussBezeichnung", "2.1"},
                      {"bmk", "-X1:2"}, {"bmkSichtbar", false}});
        for (int i = 0; i < 4; ++i) {
            QVariantMap qv = symbol("querverweis", 20 + i * 40, 110, {{"signalname", QString("SIG%1").arg(i)}});
            qv["rotation"] = rots[i];
            els << qv;
            QVariantMap pot = symbol("potenzial", 20 + i * 40, 150,
                {{"bmk", QString("-P%1").arg(i)}, {"textReihenfolge", QVariantList{"freitext1", "freitext2"}},
                 {"freitext1", "Text A"}, {"freitext2", "Text B"}, {"schriftgroesse", 2.5}});
            pot["rotation"] = rots[i];
            els << pot;
            QVariantMap ad = symbol("aderdefinition", 20 + i * 40, 190,
                {{"bezeichnung", QString("W%1").arg(i)}, {"aderfarbe", "rot"}, {"aderfarbe2", i % 2 ? "weiss" : ""},
                 {"querschnitt_mm2", 1.5}, {"laenge_m", 2.5}});
            ad["rotation"] = rots[i];
            els << ad;
        }
        QVERIFY(m_db->grafikSpeichern(sid, els));
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        QVERIFY(schaltplanPdf(pid, aus + "/synth_normblatt.pdf", true));
        QVERIFY(schaltplanPdf(pid, aus + "/synth_ohne.pdf", false));
    }

    // Referenz-PDF der generischen Listen-Tabelle (listePdfSpeichern) für Vorher/Nachher-Vergleiche bei Umbauten
    // des Tabellen-Renderers (DOKU-PDF-02). Nur mit STROEMLING_LISTE_PDF_AUSGABE=<Ordner>.
    void liste_pdf_referenz()
    {
        const QString aus = qEnvironmentVariable("STROEMLING_LISTE_PDF_AUSGABE");
        if (aus.isEmpty()) QSKIP("STROEMLING_LISTE_PDF_AUSGABE nicht gesetzt");
        QDir().mkpath(aus);
        const QStringList spalten = {"BMK", "Typ", "Bezeichnung", "Seite", "Bemerkung"};
        QVariantList zeilen;
        for (int i = 0; i < 150; ++i)
            zeilen.append(QVariant(QStringList{QString("-K%1").arg(i), "Schütz <3-polig> & Co.",
                                               QString("Zeile %1 äöüß").arg(i), QString::number(i % 9 + 1),
                                               i % 7 == 0 ? "ein längerer Bemerkungstext, der in der Zelle umbrechen kann, wenn er nur lang genug ist" : ""}));
        QVERIFY(m_db->listePdfSpeichern("Testliste", "Projekt Ü", spalten, zeilen, aus + "/liste_lang.pdf"));
        QVERIFY(m_db->listePdfSpeichern("Kurz", "", {"A", "B"}, {QVariant(QStringList{"1", "2"})}, aus + "/liste_kurz.pdf"));
        QVERIFY(m_db->listePdfSpeichern("Leer", "P", spalten, {}, aus + "/liste_leer.pdf"));
    }

    // DOKU-PDF-01: Seiten-Flag in_doku_pdf steuert den Schaltplan-Export "alle Seiten"; Einzelseite ignoriert es.
    static int pdfSeitenAnzahl(const QString &pfad)
    {
        QFile f(pfad);
        if (!f.open(QIODevice::ReadOnly)) return -1;
        const QByteArray d = f.readAll();
        int n = 0, pos = 0;
        while ((pos = d.indexOf("/Type /Page", pos)) >= 0) {
            pos += 11;
            if (pos >= d.size() || d.at(pos) != 's') ++n;   // "/Type /Pages" ausschließen
        }
        return n;
    }

    void doku_pdf_01_seitenFlag()
    {
        const int a = neueSeite("DP1");
        const int b = neueSeite("DP2");
        const int c = neueSeite("DP3");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();

        // Default: alle Seiten enthalten, Flag über normblattDatenLaden lesbar
        QCOMPARE(m_db->normblattDatenLaden(a).value("inDokuPdf").toInt(), 1);

        const QString dir = QDir::tempPath();
        const QString alle = dir + "/stroemling_dokupdf_alle.pdf";
        QVERIFY(schaltplanPdf(pid, alle, false));
        const int gesamt = pdfSeitenAnzahl(alle);
        QVERIFY(gesamt >= 3);

        // Eine Seite abwählen → eine PDF-Seite weniger
        QVERIFY(m_db->seiteInDokuPdfSetzen(b, false));
        QCOMPARE(m_db->normblattDatenLaden(b).value("inDokuPdf").toInt(), 0);
        const QString ohne = dir + "/stroemling_dokupdf_ohne.pdf";
        QVERIFY(schaltplanPdf(pid, ohne, false));
        QCOMPARE(pdfSeitenAnzahl(ohne), gesamt - 1);

        // Explizite Seitenauswahl ignoriert das Flag
        const QString einzel = dir + "/stroemling_dokupdf_einzel.pdf";
        QVERIFY(schaltplanPdf(pid, einzel, false, {b}));
        QCOMPARE(pdfSeitenAnzahl(einzel), 1);

        // Duplizieren übernimmt das Flag
        const int kopie = m_db->seiteDuplizieren(b);
        QVERIFY(kopie > 0);
        QCOMPARE(m_db->normblattDatenLaden(kopie).value("inDokuPdf").toInt(), 0);

        // Alles abgewählt → kein Export (false), statt leerem PDF
        Q_UNUSED(c);
        QSqlQuery q(QSqlDatabase::database());
        QVERIFY(q.exec("UPDATE seite SET in_doku_pdf = 0"));
        QVERIFY(!schaltplanPdf(pid, dir + "/stroemling_dokupdf_leer.pdf", false));
        QVERIFY(q.exec("UPDATE seite SET in_doku_pdf = 1"));
    }

    // DOKU-PDF-02: Kombi-PDF aus Abschnitten (Schaltplan + SPS-I/O-Liste) in einem Writer
    void doku_pdf_02_kombi()
    {
        neueSeite("DK1");
        neueSeite("DK2");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();

        // SPS-Rack mit genug Kanälen, dass die Tabelle mehrere Seiten braucht
        const int r  = m_db->spsRackAnlegen(pid, 96, "PLS", "Doku", "ACME");
        const int bg = m_db->spsBaugruppeAnlegen(r, 1, "AI", "AI 64", 64, 0);
        QVERIFY(r > 0 && bg > 0);
        for (int i = 0; i < 64; ++i)
            QVERIFY(m_db->spsKanalAnlegen(pid, bg, i, "E", 0, 0, "REAL", QString("TIC%1").arg(i), "Test") > 0);
        const QString sps = R"({"typ":"sps_io","konfig":{"spalten":[{"feld":"adresse"},{"feld":"variablenname"}],
            "filter":{"rack":"96"}}})";
        const QString dir = QDir::tempPath();

        const QString nurPlan = dir + "/stroemling_dokupdf_plan.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, nurPlan, R"({"abschnitte":[{"typ":"schaltplan"}],"mitNormblatt":false})"));
        const int planSeiten = pdfSeitenAnzahl(nurPlan);
        QVERIFY(planSeiten >= 2);

        const QString nurSps = dir + "/stroemling_dokupdf_sps.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, nurSps, "{\"abschnitte\":[" + sps + "]}"));
        const int spsSeiten = pdfSeitenAnzahl(nurSps);
        QVERIFY(spsSeiten >= 2);   // 64 Zeilen passen nicht auf eine Seite

        const QString kombi = dir + "/stroemling_dokupdf_kombi.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, kombi,
            "{\"mitNormblatt\":false,\"abschnitte\":[{\"typ\":\"schaltplan\"}," + sps + "]}"));
        QCOMPARE(pdfSeitenAnzahl(kombi), planSeiten + spsSeiten);

        // Reihenfolge umkehrbar, gleiche Seitenzahl
        const QString umgekehrt = dir + "/stroemling_dokupdf_umgekehrt.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, umgekehrt,
            "{\"mitNormblatt\":false,\"abschnitte\":[" + sps + ",{\"typ\":\"schaltplan\"}]}"));
        QCOMPARE(pdfSeitenAnzahl(umgekehrt), planSeiten + spsSeiten);

        // Explizite Seitenauswahl überschreibt das Flag
        const int ersteId = einWert("SELECT id FROM seite ORDER BY id LIMIT 1").toInt();
        const QString eine = dir + "/stroemling_dokupdf_eine.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, eine,
            QString("{\"seiteIds\":[%1],\"mitNormblatt\":false,\"abschnitte\":[{\"typ\":\"schaltplan\"}]}").arg(ersteId)));
        QCOMPARE(pdfSeitenAnzahl(eine), 1);

        // Fehlerfälle: unbekannter Typ, kaputtes JSON, leerer Schaltplan ohne weiteren Abschnitt
        QVERIFY(!m_db->dokuPdfExportieren(pid, dir + "/stroemling_dokupdf_x.pdf", R"({"abschnitte":[{"typ":"gibtsnicht"}]})"));
        QVERIFY(!m_db->dokuPdfExportieren(pid, dir + "/stroemling_dokupdf_x.pdf", "{kein json"));
        QVERIFY(!m_db->dokuPdfExportieren(pid, dir + "/stroemling_dokupdf_x.pdf",
                                          R"({"seiteIds":[],"abschnitte":[{"typ":"schaltplan"}]})"));
    }

    // DOKU-PDF-03: Deckblatt + Inhaltsverzeichnis (Seitenzahl des Verzeichnisses steht vorab fest)
    void doku_pdf_03_deckblattVerzeichnis()
    {
        neueSeite("D31");
        neueSeite("D32");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const QString dir = QDir::tempPath();
        const QString nurPlan = dir + "/stroemling_dokupdf3_plan.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, nurPlan, R"({"mitNormblatt":false,"abschnitte":[{"typ":"schaltplan"}]})"));
        const int plan = pdfSeitenAnzahl(nurPlan);
        QVERIFY(plan >= 1);

        const QString f1 = dir + "/stroemling_dokupdf3_a.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f1,
            R"({"mitNormblatt":false,"abschnitte":[{"typ":"deckblatt","titelzusatz":"Prüfstand 3"},
                {"typ":"inhaltsverzeichnis"},{"typ":"schaltplan"}]})"));
        QVERIFY(pdfSeitenAnzahl(f1) >= 1 + 1 + plan);

        // Viele Blätter → Verzeichnis läuft über mehrere Seiten
        for (int i = 0; i < 60; ++i) neueSeite(QString("V%1").arg(i));
        const QString f2 = dir + "/stroemling_dokupdf3_b.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f2,
            R"({"mitNormblatt":false,"abschnitte":[{"typ":"deckblatt"},{"typ":"inhaltsverzeichnis"},{"typ":"schaltplan"}]})"));
        const QString f2plan = dir + "/stroemling_dokupdf3_b_plan.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f2plan, R"({"mitNormblatt":false,"abschnitte":[{"typ":"schaltplan"}]})"));
        const int plan2 = pdfSeitenAnzahl(f2plan);
        QVERIFY(plan2 >= 61);
        const int ueber = pdfSeitenAnzahl(f2) - plan2 - 1;   // Rest = Verzeichnisseiten
        QVERIFY2(ueber >= 2, qPrintable(QString("Verzeichnisseiten: %1").arg(ueber)));

        // Verzeichnis ohne Inhalt entfällt, Deckblatt allein ist erlaubt
        const QString f3 = dir + "/stroemling_dokupdf3_c.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f3, R"({"seiteIds":[],"abschnitte":[{"typ":"deckblatt"},{"typ":"inhaltsverzeichnis"}]})"));
        QCOMPARE(pdfSeitenAnzahl(f3), 1);
    }

    // DOKU-PDF-05: Zellenaufbereitung der Listen (eine Abbildung für Tabs und Dokumentations-PDF)
    void doku_pdf_05_listen()
    {
        // Katalog: 11 Listen, Ids eindeutig
        const QVariantList kat = m_db->listenPdfKatalog();
        QCOMPARE(kat.size(), 11);

        // Unbekannte Liste → leeres Ergebnis
        QVERIFY(m_db->listenPdfTabelle("gibtsnicht", {}).isEmpty());

        // Stückliste: Zellen aus Rohzeilen, kein "Canvas Pos."-Platzhalter, Spaltenzahl = Zellenzahl
        QVariantMap row;
        row["bmk"] = "-K1"; row["symbolId"] = "schuetz"; row["freitext1"] = "F1"; row["seite"] = "3";
        row["anlageKz"] = "A"; row["ortKz"] = "O";
        QVariantMap t = m_db->listenPdfTabelle("stueckliste", {row});
        QCOMPARE(t["spalten"].toStringList().size(), 9);
        QCOMPARE(t["zeilen"].toList().size(), 1);
        const QStringList z = t["zeilen"].toList().first().toStringList();
        QCOMPARE(z.size(), 9);
        QCOMPARE(z[0], QString("-K1"));
        QCOMPARE(z[1], QString("schuetz"));
        QCOMPARE(z[7], QString("A"));
        QVERIFY(!t["spalten"].toStringList().contains("Canvas Pos."));

        // Adersummenliste: je Anlage/Ort fügt zwei Spalten vorn ein, Formatierung wie bisher in QML
        QVariantMap as;
        as["aderfarbe"] = "rot"; as["aderfarbe2"] = "weiss"; as["querschnittMm2"] = 1.5; as["anzahl"] = 4;
        as["laengeGesamtM"] = 12.345; as["anlageKz"] = "AQ"; as["ortKz"] = "TR";
        QVariantMap ohne = m_db->listenPdfTabelle("adersummenliste", {as});
        QCOMPARE(ohne["spalten"].toStringList().size(), 4);
        const QStringList zo = ohne["zeilen"].toList().first().toStringList();
        QCOMPARE(zo, (QStringList{"rot/weiss", "1.5 mm²", "4", "12.35 m"}));   // toFixed(2) wie in QML
        QVariantMap opt; opt["jeAnlageOrt"] = true;
        QVariantMap mit = m_db->listenPdfTabelle("adersummenliste", {as}, opt);
        QCOMPARE(mit["spalten"].toStringList().size(), 6);
        QCOMPARE(mit["zeilen"].toList().first().toStringList().first(), QString("AQ"));

        // Klemmlistenauszug / Belegungsplan: Gruppenköpfe liefern den Leisten-/Gehäuse-Kontext, erzeugen aber keine Zeile
        QVariantMap leiste; leiste["typ"] = "leiste"; leiste["bmk"] = "-X1";
        QVariantMap ans; ans["typ"] = "anschluss"; ans["klemmeNr"] = "1"; ans["anschlussVon"] = "A";
        ans["vonPlatziert"] = true; ans["vonVerbBez"] = "";
        QVariantMap kla = m_db->listenPdfTabelle("klemmlistenauszug", {leiste, ans});
        QCOMPARE(kla["zeilen"].toList().size(), 1);
        const QStringList kz = kla["zeilen"].toList().first().toStringList();
        QCOMPARE(kz.size(), kla["spalten"].toStringList().size());
        QCOMPARE(kz[0], QString("-X1"));
        QCOMPARE(kz[3], QString("(offen)"));   // platziert ohne Verbindungsname

        QVariantMap gh; gh["typ"] = "gehaeuse"; gh["bmk"] = "-X5";
        QVariantMap kt; kt["typ"] = "kontakt"; kt["kontaktBez"] = "1"; kt["querschnitt"] = 0.75;
        QVariantMap bp = m_db->listenPdfTabelle("belegungsplan", {gh, kt});
        QCOMPARE(bp["zeilen"].toList().size(), 1);
        QCOMPARE(bp["zeilen"].toList().first().toStringList()[0], QString("-X5"));

        // Jede Liste liefert für ein leeres Projekt gültige Spalten und keine Zeilen
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        for (const QVariant &kv : kat) {
            const QString id = kv.toMap()["id"].toString();
            const QVariantMap tab = m_db->listenPdfStandard(pid, id);
            QVERIFY2(!tab.isEmpty(), qPrintable(id));
            QVERIFY2(!tab["spalten"].toStringList().isEmpty(), qPrintable(id));
            for (const QVariant &zv : tab["zeilen"].toList())
                QCOMPARE(zv.toStringList().size(), tab["spalten"].toStringList().size());
        }

        // Kombi-PDF: Liste als Abschnitt; leere Liste entfällt still, unbekannte Liste ist ein Fehler
        const int sid = neueSeite("L5");
        QVariantMap a = symbol("ard_uno", 0, 0, {{"bmk", "A1"}});
        a["x2"] = 32.0; a["y2"] = 64.0;
        QVERIFY(m_db->grafikSpeichern(sid, {a}));
        QVERIFY(!m_db->stueckliste(pid).isEmpty());
        const QString dir = QDir::tempPath();
        const QString nurPlan = dir + "/stroemling_dokupdf5_plan.pdf";
        QVERIFY(schaltplanPdf(pid, nurPlan, false));
        const QString mitListe = dir + "/stroemling_dokupdf5_liste.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, mitListe,
            R"({"mitNormblatt":false,"abschnitte":[{"typ":"schaltplan"},{"typ":"liste","liste":"stueckliste"},
                {"typ":"liste","liste":"querverweise"}]})"));
        // querverweise ist leer → entfällt; Stückliste = 1 Tabellenseite
        QCOMPARE(pdfSeitenAnzahl(mitListe), pdfSeitenAnzahl(nurPlan) + 1);
        QVERIFY(!m_db->dokuPdfExportieren(pid, dir + "/stroemling_dokupdf5_x.pdf",
                                          R"({"abschnitte":[{"typ":"liste","liste":"gibtsnicht"}]})"));
    }

    // BLATTVORLAGEN-01a: eigene Normblatt-Felder im PDF auf Canvas-Niveau (alle Feldtypen, Logo, Schriftgröße/Fett)
    // und das Logo in der Auftragnehmer-Zelle des Standard-Schriftfelds.
    void blattvorlagen_01_renderer()
    {
        const int sid = neueSeite("BV1");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const QString dir = QDir::tempPath();

        auto pdfText = [&](const QString &pdf) {
            QProcess pr;
            pr.start("pdftotext", {"-layout", pdf, "-"});
            if (!pr.waitForFinished(20000)) return QString();
            return QString::fromUtf8(pr.readAllStandardOutput());
        };
        auto bildAnzahl = [&](const QString &pdf) {
            QProcess pr;
            pr.start("pdfimages", {"-list", pdf});
            if (!pr.waitForFinished(20000)) return -1;
            const QStringList z = QString::fromUtf8(pr.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
            return int(z.size()) - 2;   // zwei Kopfzeilen
        };
        {
            QProcess pr;
            pr.start("pdftotext", {"-v"});
            if (!pr.waitForFinished(5000) || pr.exitStatus() != QProcess::NormalExit)
                QSKIP("pdftotext nicht verfügbar");
        }

        // Logo 200x50 (Seitenverhältnis 4:1)
        const QString logoPfad = dir + "/stroemling_bv1_logo.png";
        { QImage img(200, 50, QImage::Format_RGB32); img.fill(Qt::red); QVERIFY(img.save(logoPfad)); }

        // Standard-Schriftfeld: ohne Vorlage kein Logo, Auftragnehmer-Zelle bleibt
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, "", false, "din6771", 0));
        const QString std = dir + "/stroemling_bv1_std.pdf";
        QVERIFY(schaltplanPdf(pid, std, true));
        QVERIFY(pdfText(std).contains("AUFTRAGNEHMER"));
        if (bildAnzahl(std) >= 0) QCOMPARE(bildAnzahl(std), 0);

        // Eigene Felder
        QVariantMap v; v["name"] = "BV1"; v["breiteMm"] = 297.0; v["hoeheMm"] = 210.0;
        const int vid = m_db->normblattVorlageSpeichern(v);
        QVERIFY(vid > 0);
        auto feld = [](const QString &typ, double x, double y, const QVariantMap &extra) {
            QVariantMap f{{"feldtyp", typ}, {"xMm", x}, {"yMm", y}, {"breiteMm", 80.0}, {"hoeheMm", 20.0},
                          {"label", ""}, {"inhalt", ""}, {"quelleSpalte", ""},
                          {"schriftgroesse", 3.5}, {"fett", 0}, {"rahmen", 1}, {"reihenfolge", 0}};
            for (auto it = extra.begin(); it != extra.end(); ++it) f[it.key()] = it.value();
            return f;
        };
        QVariantList felder;
        felder << feld("fest", 30, 30, {{"inhalt", "Titel-Hallo-Welt"}, {"schriftgroesse", 8.0}, {"fett", 1}})
               << feld("projekt", 30, 55, {{"label", "PROJEKT"}, {"quelleSpalte", "name"}})
               << feld("seite", 30, 80, {{"label", "ANLAGE"}, {"quelleSpalte", "anlage_kuerzel"}})
               << feld("datum", 30, 105, {{"label", "DATUM"}})
               << feld("format", 30, 130, {{"label", "FORMAT"}})
               << feld("logo", 120, 30, {{"hoeheMm", 40.0}});
        QVERIFY(m_db->normblattFelderSpeichern(vid, felder));
        QVERIFY(m_db->normblattVorlageLogoSpeichern(vid, logoPfad));
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, "", false, "din6771", vid));
        const QVariantMap nd0 = m_db->normblattDatenLaden(sid);
        QVERIFY(nd0.contains("logoDataUrl"));
        QVERIFY2(qAbs(nd0.value("logoAspekt").toDouble() - 4.0) < 0.01, "logoAspekt");

        const QString eig = dir + "/stroemling_bv1_eigen.pdf";
        QVERIFY(schaltplanPdf(pid, eig, true));
        const QString text = pdfText(eig);
        QVERIFY2(text.contains("Titel-Hallo-Welt"), qPrintable(text));
        QVERIFY2(text.contains("A4 QF"), qPrintable(text));
        QVERIFY2(text.contains("PROJEKT") && text.contains("ANLAGE") && text.contains("DATUM"), qPrintable(text));
        const QString anlageKz = einWert("SELECT a.kuerzel FROM anlage a JOIN ort o ON o.anlage_id=a.id "
                                         "JOIN seite s ON s.ort_id=o.id WHERE s.id=" + QString::number(sid)).toString();
        if (!anlageKz.isEmpty()) QVERIFY2(text.contains(anlageKz), "Anlagen-Kürzel fehlt");
        if (bildAnzahl(eig) >= 0) QCOMPARE(bildAnzahl(eig), 1);
    }

    // BLATTVORLAGEN-01b: Deckblatt aus Blattvorlage (Seed 'Standard-Deckblatt', Platzhalter, Vorlagen-Logo).
    void blattvorlagen_01b_deckblatt()
    {
        neueSeite("BD1");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const QString dir = QDir::tempPath();
        auto pdfText = [&](const QString &pdf) {
            QProcess pr;
            pr.start("pdftotext", {"-layout", pdf, "-"});
            if (!pr.waitForFinished(20000)) return QString();
            return QString::fromUtf8(pr.readAllStandardOutput());
        };
        auto bilder = [&](const QString &pdf) {
            QProcess pr;
            pr.start("pdfimages", {"-list", pdf});
            if (!pr.waitForFinished(20000)) return -1;
            return int(QString::fromUtf8(pr.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts).size()) - 2;
        };

        // Seed: genau eine Deckblattvorlage, A4 hoch, mit Feldern; Schriftfeld-Vorlagen haben art 'schriftfeld'
        QVariantList deck;
        for (const QVariant &v : m_db->normblattVorlagenListe())
            if (v.toMap().value("art").toString() == "deckblatt") deck << v;
        QCOMPARE(deck.size(), 1);
        const int vid = deck.first().toMap().value("id").toInt();
        QCOMPARE(deck.first().toMap().value("breiteMm").toInt(), 210);
        QVERIFY(m_db->normblattFelderLaden(vid).size() >= 10);

        const QString f1 = dir + "/stroemling_bv1b_a.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f1,
            R"({"seiteIds":[],"abschnitte":[{"typ":"deckblatt","titelzusatz":"Pruefstand-Drei","logo":false}]})"));
        QCOMPARE(pdfSeitenAnzahl(f1), 1);
        QString t = pdfText(f1);
        QVERIFY2(t.contains("Dokumentation"), qPrintable(t));
        QVERIFY2(t.contains("Pruefstand-Drei"), qPrintable(t));
        QVERIFY2(t.contains("KernTest"), qPrintable(t));          // {projekt.name}
        QVERIFY2(t.contains("erstellt mit"), qPrintable(t));
        QVERIFY2(!t.contains("{"), qPrintable(t));                // alle Platzhalter ersetzt
        if (bilder(f1) >= 0) QCOMPARE(bilder(f1), 0);            // logo:false

        // Logo der Vorlage: ohne Logo kein Bild, mit Logo eines, nach Loeschen wieder keins
        QVERIFY(!m_db->deckblattDatenLaden(pid, vid, QString(), true).contains("logoDataUrl"));
        const QString logo2 = dir + "/stroemling_bv1b_logo2.png";
        { QImage img(80, 80, QImage::Format_RGB32); img.fill(Qt::green); QVERIFY(img.save(logo2)); }
        QVERIFY(m_db->normblattVorlageLogoSpeichern(vid, logo2));
        QVERIFY(m_db->deckblattDatenLaden(pid, vid, QString(), true).contains("logoDataUrl"));
        QVERIFY(!m_db->deckblattDatenLaden(pid, vid, QString(), false).contains("logoDataUrl"));   // logo:false
        const QString f2 = dir + "/stroemling_bv1b_b.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f2, R"({"seiteIds":[],"abschnitte":[{"typ":"deckblatt"}]})"));
        if (bilder(f2) >= 0) QCOMPARE(bilder(f2), 1);
        QVERIFY(m_db->normblattVorlageLogoLoeschen(vid));
        QVERIFY(!m_db->deckblattDatenLaden(pid, vid, QString(), true).contains("logoDataUrl"));

        // Deckblatt + Verzeichnis + Plan: Seitenzahl = 1 + Verzeichnis + Plan
        const QString f3 = dir + "/stroemling_bv1b_c.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f3,
            R"({"abschnitte":[{"typ":"deckblatt"},{"typ":"inhaltsverzeichnis"},{"typ":"schaltplan"}]})"));
        QVERIFY(pdfSeitenAnzahl(f3) >= 3);

        // Vorlage geloescht -> Export scheitert sauber
        QVERIFY(m_db->normblattVorlageLoeschen(vid));
        QVERIFY(!m_db->dokuPdfExportieren(pid, dir + "/stroemling_bv1b_d.pdf",
                                          R"({"seiteIds":[],"abschnitte":[{"typ":"deckblatt"}]})"));
    }

    // NORMBLATT-DYNAMISCH-01 N-03: Infostreifen als Schriftfeld-Vorlage (Rahmen aus), relative Feldgeometrie,
    // Seiten ohne Normblatt = Bounding-Box-Blatt, Altspalten entfernt
    void normblatt_dynamisch_03_streifenVorlage()
    {
        neueSeite("ND3");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const int sid = einWert("SELECT id FROM seite ORDER BY id DESC LIMIT 1").toInt();
        const QString dir = QDir::tempPath();
        auto pdfGroesse = [&](const QString &pdf) {
            QProcess pr; pr.start("pdfinfo", {pdf});
            if (!pr.waitForFinished(20000)) return QString();
            const QString o = QString::fromUtf8(pr.readAllStandardOutput());
            const int k = o.indexOf("Page size:");
            return k < 0 ? QString() : o.mid(k, o.indexOf('\n', k) - k);
        };
        auto pdfText = [&](const QString &pdf) {
            QProcess pr; pr.start("pdftotext", {"-layout", pdf, "-"});
            if (!pr.waitForFinished(20000)) return QString();
            return QString::fromUtf8(pr.readAllStandardOutput());
        };
        auto spalten = [&](const QString &tabelle) {
            QStringList l; QSqlQuery q(QSqlDatabase::database());
            q.exec("PRAGMA table_info(" + tabelle + ")");
            while (q.next()) l << q.value(1).toString();
            return l;
        };

        // Altspalten entfernt, Vorlagen-Art infostreifen gibt es nicht mehr
        QVERIFY(!spalten("seite").contains("infostreifen"));
        QVERIFY(!spalten("seite").contains("infostreifen_ausrichtung"));
        QVERIFY(!spalten("projekt").contains("infostreifen_vorlage_id"));
        int streifen = 0;
        for (const QVariant &v : m_db->normblattVorlagenListe()) {
            QVERIFY(v.toMap().value("art").toString() != "infostreifen");
            if (v.toMap().value("name").toString() == "Standard-Infostreifen") {
                ++streifen;
                QCOMPARE(v.toMap().value("art").toString(), QStringLiteral("schriftfeld"));
                QCOMPARE(v.toMap().value("hoeheMm").toInt(), 8);
            }
        }
        QCOMPARE(streifen, 1);
        int vid = 0;
        for (const QVariant &v : m_db->normblattVorlagenListe())
            if (v.toMap().value("name").toString() == "Standard-Infostreifen") vid = v.toMap().value("id").toInt();

        // Streifen als Normblatt: Position inhalt, Rahmen aus, A3 fest
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), vid));
        QVERIFY(m_db->grafikSpeichern(sid, {elem("rechteck", 100, 100, 500, 300)}));    // 25..125 x 25..75 mm
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "inhalt", "a3", "links", false));
        QVariantMap nd = m_db->normblattDatenLaden(sid);
        QVERIFY(!nd.value("normblattRahmen").toBool());
        QCOMPARE(nd.value("vorlageBreiteMm").toInt(), 297);
        QCOMPARE(nd.value("vorlageHoeheMm").toInt(), 8);
        QVERIFY(nd.value("schriftfeldHoeheMm").toDouble() > 0 && nd.value("schriftfeldHoeheMm").toDouble() <= 8.0);
        const QString opt = R"({"mitNormblatt":true,"abschnitte":[{"typ":"schaltplan"}]})";
        const QString f1 = dir + "/stroemling_nd3_a.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f1, opt));
        const QString g1 = pdfGroesse(f1);
        if (!g1.isEmpty()) QVERIFY2(g1.contains("1190") || g1.contains("1191"), qPrintable(g1));   // A3 quer
        QVERIFY2(pdfText(f1).contains("KernTest"), qPrintable(pdfText(f1)));   // Projektname aus dem Streifen

        // eigene Vorlage ist nicht mehr "fest" gesperrt: Automatisch -> kleinstes DIN-Format, hier A4
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "inhalt", "auto", "links", false));
        const QString f2 = dir + "/stroemling_nd3_b.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f2, opt));
        const QString g2 = pdfGroesse(f2);
        if (!g2.isEmpty()) QVERIFY2(g2.contains("842") && g2.contains("595"), qPrintable(g2));

        // Blattkopf Keiner (kein Normblatt): Blatt = Bounding-Box + 15 mm (100 + 30 breit, 50 + 30 hoch)
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, false, QStringLiteral(""), false, QStringLiteral("din6771"), 0));
        const QString f3 = dir + "/stroemling_nd3_c.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f3, opt));
        const QString g3 = pdfGroesse(f3);
        if (!g3.isEmpty()) QVERIFY2((g3.contains("368") || g3.contains("369")) && g3.contains("227"), qPrintable(g3));       // 130 x 80 mm
        QVERIFY(!pdfText(f3).contains("KernTest"));
        // Export-Option "Normblatt einschliessen" aus: ebenfalls Bounding-Box-Blatt
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), vid));
        const QString f4 = dir + "/stroemling_nd3_d.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f4, R"({"mitNormblatt":false,"abschnitte":[{"typ":"schaltplan"}]})"));
        const QString g4 = pdfGroesse(f4);
        if (!g4.isEmpty()) QVERIFY2((g4.contains("368") || g4.contains("369")) && g4.contains("227"), qPrintable(g4));

        // Relative Geometrie: Vorlage 100 x 20 mm mit festem Text; auf A4-Blatt bleibt die Feldhoehe, Breite skaliert
        const int eigen = m_db->normblattVorlageSpeichern({{"name", "Mein Streifen"}, {"art", "schriftfeld"},
            {"breiteMm", 100}, {"hoeheMm", 20}, {"randLinksMm", 0}, {"randRechtsMm", 0}, {"randObenMm", 0}, {"randUntenMm", 0}});
        QVERIFY(eigen > 0);
        QVariantMap fd{{"feldtyp", "fest"}, {"xMm", 10}, {"yMm", 12}, {"breiteMm", 50}, {"hoeheMm", 6},
                       {"inhalt", "Relativ-Text-N03"}, {"schriftgroesse", 3.0}, {"reihenfolge", 0}};
        QVERIFY(m_db->normblattFelderSpeichern(eigen, {fd}));
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), eigen));
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "fest", "auto", "links", true));
        nd = m_db->normblattDatenLaden(sid);
        QCOMPARE(nd.value("vorlageBreiteMm").toInt(), 100);
        QCOMPARE(nd.value("schriftfeldHoeheMm").toDouble(), 8.0);                    // 20 - 12
        const QString f5 = dir + "/stroemling_nd3_e.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f5, opt));
        QVERIFY2(pdfText(f5).contains("Relativ-Text-N03"), qPrintable(pdfText(f5)));
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), 0));
        QVERIFY(m_db->normblattVorlageLoeschen(eigen));
    }

    // NORMBLATT-DYNAMISCH-01 N-04: seitenbezogene Platzhalter, Aenderungsdatum, Standard-Infostreifen-Felder
    void normblatt_dynamisch_04_platzhalter()
    {
        neueSeite("ND4");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const int sid = einWert("SELECT id FROM seite ORDER BY id DESC LIMIT 1").toInt();
        auto pdfText = [&](const QString &pdf) {
            QProcess pr; pr.start("pdftotext", {"-layout", pdf, "-"});
            if (!pr.waitForFinished(20000)) return QString();
            return QString::fromUtf8(pr.readAllStandardOutput());
        };
        // Standard-Infostreifen: Datumsfeld auf {seite.geaendert}, Feld "Bl. x/y" vorhanden
        int vid = 0;
        for (const QVariant &v : m_db->normblattVorlagenListe())
            if (v.toMap().value("name").toString() == "Standard-Infostreifen") vid = v.toMap().value("id").toInt();
        QVERIFY(vid > 0);
        QStringList inhalte;
        for (const QVariant &f : m_db->normblattFelderLaden(vid)) inhalte << f.toMap().value("inhalt").toString();
        QVERIFY(inhalte.contains("{seite.geaendert}"));
        QVERIFY(inhalte.contains("Bl. {seite.nr}/{seite.anzahl}"));
        QVERIFY(!inhalte.contains("{heute}"));

        // Speichern setzt das Aenderungsdatum; Blattzaehler im Projekt
        QVERIFY(m_db->grafikSpeichern(sid, {elem("rechteck", 100, 100, 500, 300)}));
        QVariantMap nd = m_db->normblattDatenLaden(sid);
        QCOMPARE(nd.value("geaendertAm").toString(), QDate::currentDate().toString(Qt::ISODate));
        QVERIFY(nd.value("blattNr").toInt() >= 1);
        QVERIFY(nd.value("blattAnzahl").toInt() >= nd.value("blattNr").toInt());

        // eigene Vorlage mit Platzhaltern im PDF
        const int eigen = m_db->normblattVorlageSpeichern({{"name", "Platzhalter-Test"}, {"art", "schriftfeld"},
            {"breiteMm", 297}, {"hoeheMm", 210}, {"randLinksMm", 10}, {"randRechtsMm", 10}, {"randObenMm", 10}, {"randUntenMm", 10}});
        QVERIFY(eigen > 0);
        QVariantMap fd{{"feldtyp", "fest"}, {"xMm", 20}, {"yMm", 190}, {"breiteMm", 200}, {"hoeheMm", 8},
                       {"inhalt", "Blatt {seite.nr} von {seite.anzahl} / {seite.blattnummer} / {seite.geaendert}"},
                       {"schriftgroesse", 3.0}, {"reihenfolge", 0}};
        QVERIFY(m_db->normblattFelderSpeichern(eigen, {fd}));
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), eigen));
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "fest", "auto", "links", true));
        const QString f = QDir::tempPath() + "/stroemling_nd4.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f, R"({"mitNormblatt":true,"abschnitte":[{"typ":"schaltplan"}]})"));
        const QString t = pdfText(f);
        const QString heute = QDate::currentDate().toString("dd.MM.yyyy");
        QVERIFY2(t.contains(QString("Blatt %1 von %2").arg(nd.value("blattNr").toInt()).arg(nd.value("blattAnzahl").toInt())),
                 qPrintable(t));
        QVERIFY2(t.contains(heute), qPrintable(t));
        QVERIFY2(!t.contains("{seite."), qPrintable(t));
        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), 0));
        QVERIFY(m_db->normblattVorlageLoeschen(eigen));
    }

    // NORMBLATT-DYNAMISCH-01 N-02: Normblatt "folgt Inhalt" (Position inhalt), Format auto/fest, PDF-Blatt = Flaeche
    void normblatt_dynamisch_02_inhalt()
    {
        neueSeite("ND1");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const int sid = einWert("SELECT id FROM seite ORDER BY id DESC LIMIT 1").toInt();
        const QString dir = QDir::tempPath();
        auto pdfGroesse = [&](const QString &pdf) {
            QProcess pr; pr.start("pdfinfo", {pdf});
            if (!pr.waitForFinished(20000)) return QString();
            const QString o = QString::fromUtf8(pr.readAllStandardOutput());
            const int k = o.indexOf("Page size:");
            return k < 0 ? QString() : o.mid(k, o.indexOf('\n', k) - k);
        };
        auto pdfText = [&](const QString &pdf) {
            QProcess pr; pr.start("pdftotext", {"-layout", pdf, "-"});
            if (!pr.waitForFinished(20000)) return QString();
            return QString::fromUtf8(pr.readAllStandardOutput());
        };
        const QString opt = R"({"mitNormblatt":true,"abschnitte":[{"typ":"schaltplan"}]})";

        // Standard: fest, Rahmen an
        QVariantMap nd = m_db->normblattDatenLaden(sid);
        QCOMPARE(nd.value("normblattPosition").toString(), QStringLiteral("fest"));
        QCOMPARE(nd.value("normblattFormat").toString(), QStringLiteral("auto"));
        QVERIFY(nd.value("normblattRahmen").toBool());
        QVERIFY(!m_db->seiteNormblattLageSetzen(sid, "mitte", "auto", "links", true));
        QVERIFY(!m_db->seiteNormblattLageSetzen(sid, "inhalt", "a9", "links", true));

        QVERIFY(m_db->normblattEinstellungenSetzen(sid, true, QStringLiteral(""), false, QStringLiteral("din6771"), 0));
        QVERIFY(m_db->grafikSpeichern(sid, {elem("rechteck", 100, 100, 500, 300)}));    // 25..125 x 25..75 mm
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "inhalt", "auto", "links", true));

        // Automatisch: 100+20+30 breit, 50+20+39+20 hoch -> A4 quer
        const QString f1 = dir + "/stroemling_nd2_a.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f1, opt));
        const QString g1 = pdfGroesse(f1);
        if (!g1.isEmpty()) QVERIFY2(g1.contains("842") && g1.contains("595"), qPrintable(g1));
        QVERIFY2(pdfText(f1).contains("AUFTRAGGEBER"), qPrintable(pdfText(f1)));       // Schriftfeld DIN 6771 steht auf dem Blatt

        // Elemente 400 mm breit: 400+20+30 = 450 > 420 -> A2 quer (594 x 420 = 1684 x 1191 pt)
        QVERIFY(m_db->grafikSpeichern(sid, {elem("rechteck", 100, 100, 1700, 300)}));
        const QString f2 = dir + "/stroemling_nd2_b.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f2, opt));
        const QString g2 = pdfGroesse(f2);
        if (!g2.isEmpty()) QVERIFY2(g2.contains("1683") || g2.contains("1684"), qPrintable(g2));

        // festes Format A3: Blatt = 420 x 297; passt der Inhalt nicht -> Hinweis
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "inhalt", "a3", "rechts", true));
        QVERIFY(m_db->normblattInhaltZuGross(sid, "a3", "din6771"));                  // 450 > 420
        QVERIFY(!m_db->normblattInhaltZuGross(sid, "a2", "din6771"));
        QVERIFY(!m_db->normblattInhaltZuGross(sid, "auto", "din6771"));
        const QString f3 = dir + "/stroemling_nd2_c.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f3, opt));
        const QString g3 = pdfGroesse(f3);
        if (!g3.isEmpty()) QVERIFY2(g3.contains("1190") || g3.contains("1191"), qPrintable(g3));

        // Position fest: Blatt = Seitenformat (A4 quer 297 x 210), unabhaengig vom Inhalt
        QVERIFY(m_db->seiteNormblattLageSetzen(sid, "fest", "auto", "links", true));
        const QString f4 = dir + "/stroemling_nd2_d.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f4, opt));
        const QString g4 = pdfGroesse(f4);
        if (!g4.isEmpty()) QVERIFY2(g4.contains("842") && g4.contains("595"), qPrintable(g4));
    }

    // BLATTVORLAGEN-02: Kunden-Logo je Projekt, Feldtypen logo_kunde/linie/textblock, Deckblatt-Art per API.
    void blattvorlagen_02_kundenlogoFeldtypen()
    {
        neueSeite("K1");
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const QString dir = QDir::tempPath();
        auto pdfText = [&](const QString &pdf) {
            QProcess pr;
            pr.start("pdftotext", {"-layout", pdf, "-"});
            if (!pr.waitForFinished(20000)) return QString();
            return QString::fromUtf8(pr.readAllStandardOutput());
        };
        auto bilder = [&](const QString &pdf) {
            QProcess pr;
            pr.start("pdfimages", {"-list", pdf});
            if (!pr.waitForFinished(20000)) return -1;
            return int(QString::fromUtf8(pr.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts).size()) - 2;
        };

        // Seed (Migration 165): Standard-Deckblatt hat Trennlinie und Kunden-Logo-Feld
        int stdId = 0;
        for (const QVariant &v : m_db->normblattVorlagenListe())
            if (v.toMap().value("art").toString() == "deckblatt") stdId = v.toMap().value("id").toInt();
        QVERIFY(stdId > 0);
        QStringList typen;
        for (const QVariant &f : m_db->normblattFelderLaden(stdId)) typen << f.toMap().value("feldtyp").toString();
        QVERIFY(typen.contains("linie"));
        QVERIFY(typen.contains("logo_kunde"));

        // Kunden-Logo: Standard-Deckblatt zeigt es als zweites Bild; Projekt-Logo bleibt getrennt
        QVERIFY(m_db->projektKundenLogoDataUrl(pid).isEmpty());
        const QString lp = dir + "/stroemling_bv2_kunde.png";
        { QImage img(100, 50, QImage::Format_RGB32); img.fill(Qt::darkGreen); QVERIFY(img.save(lp)); }
        QVERIFY(m_db->projektKundenLogoSpeichern(pid, lp));
        QVERIFY(m_db->projektKundenLogoDataUrl(pid).startsWith("data:image/png;base64,"));
        QVERIFY(!m_db->projektKundenLogoSpeichern(pid, dir + "/gibtsnicht.png"));
        const QVariantMap d = m_db->deckblattDatenLaden(pid, stdId, QString(), true);
        QVERIFY(d.contains("kundenLogoDataUrl"));
        QVERIFY(qAbs(d.value("kundenLogoAspekt").toDouble() - 2.0) < 0.01);
        QVERIFY(!m_db->deckblattDatenLaden(pid, stdId, QString(), false).contains("kundenLogoDataUrl"));
        const QString f1 = dir + "/stroemling_bv2_a.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f1, R"({"seiteIds":[],"abschnitte":[{"typ":"deckblatt"}]})"));
        if (bilder(f1) >= 0) QCOMPARE(bilder(f1), 1);          // nur Kunden-Logo (kein Projekt-/Vorlagen-Logo gesetzt)
        QVERIFY(m_db->projektKundenLogoLoeschen(pid));
        QVERIFY(m_db->projektKundenLogoDataUrl(pid).isEmpty());

        // Eigene Deckblattvorlage per API: Art wird gespeichert; textblock mit Zeilenumbruch + Platzhalter
        QVariantMap v; v["name"] = "Mein Deckblatt"; v["breiteMm"] = 210.0; v["hoeheMm"] = 297.0;
        v["art"] = "deckblatt";
        const int vid = m_db->normblattVorlageSpeichern(v);
        QVERIFY(vid > 0);
        auto feld = [](const QString &typ, double x, double y, double b, double h, const QString &inhalt) {
            return QVariantMap{{"feldtyp", typ}, {"xMm", x}, {"yMm", y}, {"breiteMm", b}, {"hoeheMm", h},
                               {"label", ""}, {"inhalt", inhalt}, {"quelleSpalte", ""},
                               {"schriftgroesse", 4.0}, {"fett", 1}, {"rahmen", 0}, {"reihenfolge", 0}};
        };
        QVERIFY(m_db->normblattFelderSpeichern(vid, {
            feld("textblock", 20, 40, 120, 40, "Erste-Zeile\nZweite-Zeile fuer {projekt.name}"),
            feld("linie", 20, 90, 170, 1, ""),
            feld("linie", 100, 100, 1, 50, ""),
            feld("logo_kunde", 20, 160, 50, 30, "")}));
        bool gefunden = false;
        for (const QVariant &x : m_db->normblattVorlagenListe())
            if (x.toMap().value("id").toInt() == vid) gefunden = x.toMap().value("art").toString() == "deckblatt";
        QVERIFY(gefunden);
        // Update ohne art-Schluessel laesst die Art unveraendert
        QVariantMap u; u["id"] = vid; u["name"] = "Mein Deckblatt 2"; u["breiteMm"] = 210.0; u["hoeheMm"] = 297.0;
        QCOMPARE(m_db->normblattVorlageSpeichern(u), vid);
        for (const QVariant &x : m_db->normblattVorlagenListe())
            if (x.toMap().value("id").toInt() == vid) QCOMPARE(x.toMap().value("art").toString(), QString("deckblatt"));

        const QString f2 = dir + "/stroemling_bv2_b.pdf";
        QVERIFY(m_db->dokuPdfExportieren(pid, f2,
            QString(R"({"seiteIds":[],"abschnitte":[{"typ":"deckblatt","vorlageId":%1}]})").arg(vid)));
        const QString t = pdfText(f2);
        QVERIFY2(t.contains("Erste-Zeile"), qPrintable(t));
        QVERIFY2(t.contains("Zweite-Zeile fuer KernTest"), qPrintable(t));
        if (bilder(f2) >= 0) QCOMPARE(bilder(f2), 0);          // Kunden-Logo geloescht
    }

    // Werk/Abteilung/Norm sind editierbar (Projektseite) und stehen in ersteProjektInfo()/Platzhaltern.
    void projekt_meta_werkAbteilungNorm()
    {
        const int sid = neueSeite("M1");
        QVERIFY(m_db->projektMetaDatenSpeichern("P", "1", "AG", "AN", "Bea", " Werk 7 ", "Abt X", "VDE"));
        QVariantMap i = m_db->ersteProjektInfo();
        QCOMPARE(i.value("werk").toString(), QString("Werk 7"));
        QCOMPARE(i.value("abteilung").toString(), QString("Abt X"));
        QCOMPARE(i.value("norm").toString(), QString("VDE"));
        QCOMPARE(m_db->normblattDatenLaden(sid).value("werk").toString(), QString("Werk 7"));
        // leere Norm faellt auf den Spaltenstandard zurueck (NOT NULL)
        QVERIFY(m_db->projektMetaDatenSpeichern("P", "1", "AG", "AN", "Bea", "", "", "  "));
        i = m_db->ersteProjektInfo();
        QCOMPARE(i.value("norm").toString(), QString("IEC"));
        QCOMPARE(i.value("werk").toString(), QString(""));
    }

    // BLATTVORLAGEN-03: app-weite Vorlagenbibliothek (vorlagen.db) mit Abgleich.
    void blattvorlagen_03_bibliothek()
    {
        neueSeite("L1");
        const QString bibPfad = QDir::tempPath() + "/stroemling_vorlagen_test_" + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".db";
        QFile::remove(bibPfad);
        QVERIFY(m_db->openVorlagen(bibPfad));
        QVERIFY(m_db->vorlagenBibliothekListe().isEmpty());

        QVariantMap v; v["name"] = "Firma X"; v["breiteMm"] = 210.0; v["hoeheMm"] = 297.0; v["art"] = "deckblatt";
        const int vid = m_db->normblattVorlageSpeichern(v);
        QVERIFY(vid > 0);
        auto feld = [](const QString &inhalt, double x) {
            return QVariantMap{{"feldtyp", "fest"}, {"xMm", x}, {"yMm", 10.0}, {"breiteMm", 50.0}, {"hoeheMm", 10.0},
                               {"label", ""}, {"inhalt", inhalt}, {"quelleSpalte", ""},
                               {"schriftgroesse", 3.5}, {"fett", 0}, {"rahmen", 1}, {"reihenfolge", 0}};
        };
        QVERIFY(m_db->normblattFelderSpeichern(vid, {feld("A", 10), feld("B", 70)}));
        const QString logo = QDir::tempPath() + "/stroemling_bv3_logo.png";
        { QImage img(40, 20, QImage::Format_RGB32); img.fill(Qt::red); QVERIFY(img.save(logo)); }
        QVERIFY(m_db->normblattVorlageLogoSpeichern(vid, logo));
        QCOMPARE(m_db->vorlageBibliothekStatus(vid).value("status").toString(), QString("lokal"));

        // In die Bibliothek legen
        const QString uid = m_db->vorlageInBibliothekSpeichern(vid);
        QVERIFY(!uid.isEmpty());
        QCOMPARE(m_db->vorlageBibliothekStatus(vid).value("status").toString(), QString("aktuell"));
        QVariantList bib = m_db->vorlagenBibliothekListe();
        QCOMPARE(bib.size(), 1);
        QCOMPARE(bib[0].toMap().value("felder").toInt(), 2);
        QCOMPARE(bib[0].toMap().value("version").toInt(), 1);
        QCOMPARE(bib[0].toMap().value("imProjekt").toInt(), vid);
        QVERIFY(bib[0].toMap().value("hatLogo").toBool());

        // Umbenennen ist keine inhaltliche Aenderung; Feldaenderung schon
        QVariantMap u; u["id"] = vid; u["name"] = "Firma X neu"; u["breiteMm"] = 210.0; u["hoeheMm"] = 297.0;
        QCOMPARE(m_db->normblattVorlageSpeichern(u), vid);
        QCOMPARE(m_db->vorlageBibliothekStatus(vid).value("status").toString(), QString("aktuell"));
        QVERIFY(m_db->normblattFelderSpeichern(vid, {feld("A", 10), feld("B", 80)}));
        QCOMPARE(m_db->vorlageBibliothekStatus(vid).value("status").toString(), QString("lokalGeaendert"));

        // Erneut speichern: gleiche uid, Version 2
        QCOMPARE(m_db->vorlageInBibliothekSpeichern(vid), uid);
        QCOMPARE(m_db->vorlagenBibliothekListe()[0].toMap().value("version").toInt(), 2);
        QCOMPARE(m_db->vorlageBibliothekStatus(vid).value("status").toString(), QString("aktuell"));

        // Schon im Projekt -> Uebernehmen verweigert; nach Loeschen wieder moeglich
        QCOMPARE(m_db->vorlageAusBibliothekUebernehmen(uid), -1);
        QVERIFY(m_db->normblattVorlageLoeschen(vid));
        const int vid2 = m_db->vorlageAusBibliothekUebernehmen(uid);
        QVERIFY(vid2 > 0);
        QCOMPARE(m_db->normblattFelderLaden(vid2).size(), 2);
        QCOMPARE(m_db->normblattFelderLaden(vid2)[1].toMap().value("xMm").toInt(), 80);
        QCOMPARE(m_db->vorlageBibliothekStatus(vid2).value("status").toString(), QString("aktuell"));
        bool art = false, logoDa = false;
        for (const QVariant &x : m_db->normblattVorlagenListe())
            if (x.toMap().value("id").toInt() == vid2) {
                art = x.toMap().value("art").toString() == "deckblatt";
                logoDa = x.toMap().value("hatLogo").toBool();
            }
        QVERIFY(art);
        QVERIFY(logoDa);

        // Bibliothek neuer (Projektstand zurueckgesetzt), dann beides geaendert, dann aktualisieren
        { QSqlQuery qq(QSqlDatabase::database());
          QVERIFY(qq.exec("UPDATE normblatt_vorlage SET bibliothek_version = 1 WHERE id = " + QString::number(vid2))); }
        QCOMPARE(m_db->vorlageBibliothekStatus(vid2).value("status").toString(), QString("bibliothekNeuer"));
        QVERIFY(m_db->normblattFelderSpeichern(vid2, {feld("Z", 5)}));
        QCOMPARE(m_db->vorlageBibliothekStatus(vid2).value("status").toString(), QString("beides"));
        QVERIFY(m_db->vorlageAusBibliothekAktualisieren(vid2));
        QCOMPARE(m_db->normblattFelderLaden(vid2).size(), 2);
        QCOMPARE(m_db->vorlageBibliothekStatus(vid2).value("status").toString(), QString("aktuell"));

        // Aus der Bibliothek geloescht -> Projektkopie bleibt, Status meldet es
        QVERIFY(m_db->vorlageAusBibliothekLoeschen(uid));
        QVERIFY(m_db->vorlagenBibliothekListe().isEmpty());
        QCOMPARE(m_db->vorlageBibliothekStatus(vid2).value("status").toString(), QString("bibliothekFehlt"));
        QCOMPARE(m_db->normblattFelderLaden(vid2).size(), 2);
    }

    void blattvorlagen_05_austausch()
    {
        // S2: Bündel "stroemling-blattvorlagen" - Export, Analyse (neu/gleich/abweichend), Import mit Aktionen, Sicherung
        neueSeite("L5");
        const QString basis = QDir::tempPath() + "/stroemling_bv5_" + QString::number(QDateTime::currentMSecsSinceEpoch());
        QDir().mkpath(basis);
        QVERIFY(m_db->openVorlagen(basis + "/vorlagen.db"));
        auto feld = [](const QString &inhalt, double x) {
            return QVariantMap{{"feldtyp", "fest"}, {"xMm", x}, {"yMm", 10.0}, {"breiteMm", 50.0}, {"hoeheMm", 10.0},
                               {"label", ""}, {"inhalt", inhalt}, {"quelleSpalte", ""},
                               {"schriftgroesse", 3.5}, {"fett", 0}, {"rahmen", 1}, {"reihenfolge", 0}};
        };
        QVariantMap v; v["name"] = "Export A"; v["breiteMm"] = 210.0; v["hoeheMm"] = 297.0; v["art"] = "deckblatt";
        const int vid = m_db->normblattVorlageSpeichern(v);
        QVERIFY(m_db->normblattFelderSpeichern(vid, {feld("A", 10), feld("B", 70)}));
        const QString logo = basis + "/logo.png";
        { QImage img(40, 20, QImage::Format_RGB32); img.fill(Qt::blue); QVERIFY(img.save(logo)); }
        QVERIFY(m_db->normblattVorlageLogoSpeichern(vid, logo));
        const QString uid = m_db->vorlageInBibliothekSpeichern(vid);
        QVERIFY(!uid.isEmpty());

        // Export (nie ueberschreiben, leere Bibliothek meldet sich)
        const QString buendel = basis + "/buendel.json";
        QVariantMap ex = m_db->vorlagenExportieren(buendel, {});
        QVERIFY2(ex.value("ok").toBool(), qPrintable(ex.value("fehler").toString()));
        QCOMPARE(ex.value("anzahl").toInt(), 1);
        QVERIFY(!m_db->vorlagenExportieren(buendel, {}).value("ok").toBool());

        // Gleicher Stand: alles "gleich", nichts wird veraendert
        QVariantMap an = m_db->vorlagenImportAnalysieren(buendel);
        QVERIFY(an.value("ok").toBool());
        QCOMPARE(an.value("anzahlGleich").toInt(), 1);
        QCOMPARE(an.value("eintraege").toList().first().toMap().value("vorschlag").toString(), QString("ueberspringen"));

        // Lokal aendern (Version 2) -> Buendel ist nun aelter: "abweichend", Vorschlag ueberspringen; Namen ist keine Aenderung
        QVERIFY(m_db->normblattFelderSpeichern(vid, {feld("A", 10), feld("B", 99)}));
        QVERIFY(!m_db->vorlageInBibliothekSpeichern(vid).isEmpty());
        an = m_db->vorlagenImportAnalysieren(buendel);
        QCOMPARE(an.value("anzahlAbweichend").toInt(), 1);
        QVariantMap e = an.value("eintraege").toList().first().toMap();
        QCOMPARE(e.value("status").toString(), QString("abweichend"));
        QCOMPARE(e.value("vorschlag").toString(), QString("ueberspringen"));
        QCOMPARE(e.value("lokaleVersion").toInt(), 2);

        // Kopie: neue uid, Name mit Zusatz; Original unveraendert
        QVariantMap r = m_db->vorlagenImportAusfuehren(buendel, {{uid, "kopie"}});
        QVERIFY2(r.value("ok").toBool(), qPrintable(r.value("fehler").toString()));
        QCOMPARE(r.value("kopien").toInt(), 1);
        QVERIFY(!r.value("sicherung").toString().isEmpty());
        QVERIFY(QFileInfo::exists(r.value("sicherung").toString()));
        QCOMPARE(m_db->vorlagenBibliothekListe().size(), 2);
        bool kopieDa = false;
        for (const QVariant &x : m_db->vorlagenBibliothekListe())
            if (x.toMap().value("name").toString() == "Export A (Import)") kopieDa = true;
        QVERIFY(kopieDa);

        // Ersetzen: Inhalt aus dem Buendel, Version ueber beiden Staenden (>2), Felder und Logo da
        r = m_db->vorlagenImportAusfuehren(buendel, {{uid, "ersetzen"}});
        QCOMPARE(r.value("ersetzt").toInt(), 1);
        QVariantMap bib;
        for (const QVariant &x : m_db->vorlagenBibliothekListe())
            if (x.toMap().value("uid").toString() == uid) bib = x.toMap();
        QCOMPARE(bib.value("felder").toInt(), 2);
        QVERIFY(bib.value("hatLogo").toBool());
        QVERIFY(bib.value("version").toInt() >= 3);
        const QString kontrolle = basis + "/kontrolle.json";
        QVERIFY(m_db->vorlagenExportieren(kontrolle, {uid}).value("ok").toBool());
        { QFile kf(kontrolle); QVERIFY(kf.open(QIODevice::ReadOnly));
          const QJsonArray fa = QJsonDocument::fromJson(kf.readAll()).object().value("vorlagen").toArray().first().toObject().value("felder").toArray();
          QCOMPARE(fa.size(), 2);
          QCOMPARE(int(fa[1].toObject().value("x_mm").toDouble()), 70); }

        // Frische Bibliothek: Import legt neu an, zweiter Import ist "gleich"
        QVERIFY(m_db->openVorlagen(basis + "/leer.db"));
        QVERIFY(m_db->vorlagenBibliothekListe().isEmpty());
        an = m_db->vorlagenImportAnalysieren(buendel);
        QCOMPARE(an.value("anzahlNeu").toInt(), 1);
        r = m_db->vorlagenImportAusfuehren(buendel, {});
        QCOMPARE(r.value("angelegt").toInt(), 1);
        QCOMPARE(m_db->vorlagenBibliothekListe().size(), 1);
        QCOMPARE(m_db->vorlagenBibliothekListe().first().toMap().value("uid").toString(), uid);
        QCOMPARE(m_db->vorlagenImportAnalysieren(buendel).value("anzahlGleich").toInt(), 1);

        // Fehlerfaelle: fremdes Format, kaputtes JSON, fehlende Datei
        QFile f(basis + "/fremd.json"); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("{\"format\":\"x\"}"); f.close();
        QVERIFY(m_db->vorlagenImportAnalysieren(basis + "/fremd.json").value("fehler").toString().contains("Kein Blattvorlagen"));
        QVERIFY(!m_db->vorlagenImportAnalysieren(basis + "/gibtsnicht.json").value("ok").toBool());
        QDir(basis).removeRecursively();
    }

    void makro_01_austausch()
    {
        // S3: Makro-Identitaet (uid, Altbestand wird nachgetragen) und Buendel "stroemling-makros"
        const QString basis = QDir::tempPath() + "/stroemling_mk1_" + QString::number(QDateTime::currentMSecsSinceEpoch());
        QDir().mkpath(basis);
        // Altbestand: makros.db von vor S3 (ohne uid/version), zwei Makros mit Elementen
        {
            QSqlDatabase alt = QSqlDatabase::addDatabase("QSQLITE", "mk_alt");
            alt.setDatabaseName(basis + "/alt.db");
            QVERIFY(alt.open());
            QSqlQuery q(alt);
            QVERIFY(q.exec("CREATE TABLE makro (id INTEGER PRIMARY KEY, name TEXT NOT NULL, beschreibung TEXT DEFAULT '', kategorie TEXT DEFAULT '', "
                           "kasten_breite REAL NOT NULL DEFAULT 100, kasten_hoehe REAL NOT NULL DEFAULT 100, erstellt_am TEXT DEFAULT (datetime('now')))"));
            QVERIFY(q.exec("CREATE TABLE makro_element (id INTEGER PRIMARY KEY, makro_id INTEGER NOT NULL REFERENCES makro(id) ON DELETE CASCADE, "
                           "typ TEXT NOT NULL, rel_x1 REAL NOT NULL, rel_y1 REAL NOT NULL, rel_x2 REAL NOT NULL DEFAULT 0, rel_y2 REAL NOT NULL DEFAULT 0, "
                           "extra_daten TEXT DEFAULT '{}', symbol_key TEXT DEFAULT '', sortierung INTEGER DEFAULT 0)"));
            QVERIFY(q.exec("INSERT INTO makro (name, kategorie) VALUES ('Motorstarter', 'Antriebe'), ('Netzteil 24V', 'Versorgung')"));
            QVERIFY(q.exec("INSERT INTO makro_element (makro_id, typ, rel_x1, rel_y1, symbol_key, sortierung) VALUES "
                           "(1, 'symbol', 10, 20, 'schuetz', 0), (1, 'symbol', 30, 20, 'motor', 1), (2, 'symbol', 5, 5, 'netzteil', 0)"));
            alt.close();
        }
        QSqlDatabase::removeDatabase("mk_alt");
        QVERIFY(m_db->openMakro(basis + "/alt.db"));
        QSqlDatabase mk = QSqlDatabase::database("stroemling_makro");
        QSet<QString> uids;
        { QSqlQuery q(mk); QVERIFY(q.exec("SELECT uid, version FROM makro"));
          while (q.next()) { QVERIFY(!q.value(0).toString().isEmpty()); QCOMPARE(q.value(1).toInt(), 1); uids.insert(q.value(0).toString()); } }
        QCOMPARE(uids.size(), 2);
        // erneutes Oeffnen aendert die uids nicht
        QVERIFY(m_db->openMakro(basis + "/alt.db"));
        { QSqlQuery q(QSqlDatabase::database("stroemling_makro")); QVERIFY(q.exec("SELECT uid FROM makro"));
          while (q.next()) QVERIFY(uids.contains(q.value(0).toString())); }

        // Meta-Update zaehlt die Version hoch
        QVERIFY(m_db->makroMetaAktualisieren(1, "Motorstarter DOL", "", "Antriebe"));
        { QSqlQuery q(QSqlDatabase::database("stroemling_makro")); QVERIFY(q.exec("SELECT version FROM makro WHERE id = 1") && q.next()); QCOMPARE(q.value(0).toInt(), 2); }

        // Export
        const QString buendel = basis + "/buendel.json";
        QVariantMap ex = m_db->makrosExportieren(buendel, {});
        QVERIFY2(ex.value("ok").toBool(), qPrintable(ex.value("fehler").toString()));
        QCOMPARE(ex.value("anzahl").toInt(), 2);
        QVERIFY(!m_db->makrosExportieren(buendel, {}).value("ok").toBool());

        // gleicher Stand: alles gleich
        QVariantMap an = m_db->makrosImportAnalysieren(buendel);
        QVERIFY(an.value("ok").toBool());
        QCOMPARE(an.value("anzahlGleich").toInt(), 2);

        // lokal ein Element aendern (Version 3 per Meta) -> abweichend, Vorschlag ueberspringen (Buendel aelter)
        { QSqlQuery q(QSqlDatabase::database("stroemling_makro")); QVERIFY(q.exec("UPDATE makro_element SET rel_x1 = 99 WHERE makro_id = 2"));
          QVERIFY(q.exec("UPDATE makro SET version = 3 WHERE id = 2")); }
        an = m_db->makrosImportAnalysieren(buendel);
        QCOMPARE(an.value("anzahlAbweichend").toInt(), 1);
        QCOMPARE(an.value("anzahlGleich").toInt(), 1);
        QVariantMap abw;
        for (const QVariant &e : an.value("eintraege").toList()) if (e.toMap().value("status").toString() == "abweichend") abw = e.toMap();
        QCOMPARE(abw.value("vorschlag").toString(), QString("ueberspringen"));
        QCOMPARE(abw.value("lokaleVersion").toInt(), 3);
        const QString abwUid = abw.value("uid").toString();

        // Kopie, dann Ersetzen
        QVariantMap r = m_db->makrosImportAusfuehren(buendel, {{abwUid, "kopie"}});
        QVERIFY2(r.value("ok").toBool(), qPrintable(r.value("fehler").toString()));
        QCOMPARE(r.value("kopien").toInt(), 1);
        QVERIFY(QFileInfo::exists(r.value("sicherung").toString()));
        QCOMPARE(m_db->makroListe().size(), 3);
        r = m_db->makrosImportAusfuehren(buendel, {{abwUid, "ersetzen"}});
        QCOMPARE(r.value("ersetzt").toInt(), 1);
        { QSqlQuery q(QSqlDatabase::database("stroemling_makro"));
          QVERIFY(q.exec("SELECT e.rel_x1, m.version FROM makro m JOIN makro_element e ON e.makro_id = m.id WHERE m.uid = '" + abwUid + "'") && q.next());
          QCOMPARE(q.value(0).toInt(), 5);          // Wert aus dem Buendel zurueck
          QVERIFY(q.value(1).toInt() >= 4); }       // Version ueber beiden Staenden

        // frische Bibliothek: Import legt neu an (Elemente vollstaendig), danach alles gleich
        QVERIFY(m_db->openMakro(basis + "/leer.db"));
        QVERIFY(m_db->makroListe().isEmpty());
        QCOMPARE(m_db->makrosImportAnalysieren(buendel).value("anzahlNeu").toInt(), 2);
        r = m_db->makrosImportAusfuehren(buendel, {});
        QCOMPARE(r.value("angelegt").toInt(), 2);
        QCOMPARE(m_db->makroListe().size(), 2);
        QCOMPARE(m_db->makrosImportAnalysieren(buendel).value("anzahlGleich").toInt(), 2);
        int summeElemente = 0;
        for (const QVariant &m : m_db->makroListe()) summeElemente += m.toMap().value("elementAnzahl").toInt();
        QCOMPARE(summeElemente, 3);

        // Fehlerfaelle
        QFile f(basis + "/fremd.json"); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("{\"format\":\"x\"}"); f.close();
        QVERIFY(m_db->makrosImportAnalysieren(basis + "/fremd.json").value("fehler").toString().contains("Kein Makro-Bündel"));
        QVERIFY(!m_db->makrosImportAnalysieren(basis + "/gibtsnicht.json").value("ok").toBool());
        QDir(basis).removeRecursively();
    }

    // Hilfsslot: schreibt das Ergebnis von klemmlistenauszug() einer Projekt-KOPIE als JSON (Vorher/Nachher-
    // Vergleich bei Umbauten). Env: STROEMLING_KL_PROJEKT (Kopie), STROEMLING_KL_BIB (optional), STROEMLING_KL_AUSGABE (Datei).
    void kl_dump()
    {
        const QString proj = qEnvironmentVariable("STROEMLING_KL_PROJEKT");
        const QString aus  = qEnvironmentVariable("STROEMLING_KL_AUSGABE");
        if (proj.isEmpty() || aus.isEmpty()) QSKIP("STROEMLING_KL_PROJEKT/STROEMLING_KL_AUSGABE nicht gesetzt");
        m_db->closeProjekt();
        const QString bib = qEnvironmentVariable("STROEMLING_KL_BIB");
        if (!bib.isEmpty()) QVERIFY(m_db->openBibliothek(bib));
        QVERIFY(m_db->openProjekt(proj));
        const int pid = einWert("SELECT id FROM projekt LIMIT 1").toInt();
        const QVariantList l = m_db->klemmlistenauszug(pid);
        QFile f(aus);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(QJsonDocument(QJsonArray::fromVariantList(l)).toJson(QJsonDocument::Indented));
        qInfo() << "klemmlistenauszug-Zeilen:" << l.size();
    }

    // ════════════════════════════════════════════════════════════
    // klemmlistenauszug
    // ════════════════════════════════════════════════════════════

    // Liste → nur Zeilen eines Typs
    static QVariantList zeilen(const QVariantList &l, const QString &typ)
    {
        QVariantList r;
        for (const QVariant &v : l)
            if (v.toMap()["typ"].toString() == typ) r.append(v);
        return r;
    }

    void kl_01_leeresProjektLiefertNichts()
    {
        QCOMPARE(m_db->klemmlistenauszug(1).size(), 0);
    }

    void kl_02_klemmenOhneCanvasplatzierung()
    {
        QSqlDatabase bib = QSqlDatabase::database("stroemling_bibliothek");
        const int bt = ins("INSERT INTO bauteil (bezeichnung) VALUES ('Reihenklemme KlTest')", bib);
        QVERIFY(bt > 0);
        const int bk = ins(QString("INSERT INTO bauteil_klemme (bauteil_id, anschluss_typ, ebenen_anzahl,"
                                   " punkte_seite_a, punkte_seite_b) VALUES (%1,'schraub',2,1,1)").arg(bt), bib);
        QVERIFY(bk > 0);
        QVERIFY(ins(QString("INSERT INTO bauteil_klemme_querschnitt (klemme_id, adertyp, min_mm2, max_mm2)"
                            " VALUES (%1,'starr',0.5,4)").arg(bk), bib) > 0);

        const int kl = ins("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (1,'X1')");
        QVERIFY(kl > 0);
        QVERIFY(ins(QString("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) VALUES (%1,%2,'1',1)").arg(kl).arg(bt)) > 0);
        QVERIFY(ins(QString("INSERT INTO klemme (klemmenleiste_id, nummer, sortierung) VALUES (%1,'2',2)").arg(kl)) > 0);

        const QVariantList l = m_db->klemmlistenauszug(1);
        const QVariantList leisten = zeilen(l, "leiste");
        QCOMPARE(leisten.size(), 1);
        QCOMPARE(leisten[0].toMap()["bezeichnung"].toString(), QString("X1"));
        QVERIFY(leisten[0].toMap()["bmk"].toString().contains("X1"));
        QCOMPARE(leisten[0].toMap()["stegAnzahl"].toInt(), 0);

        // Klemme 1 hat Bauteil mit 2 Ebenen x (1 A + 1 B) = 2 Paar-Zeilen; Klemme 2 ohne Bauteil = 1 leere Zeile
        const QVariantList an = zeilen(l, "anschluss");
        QCOMPARE(an.size(), 3);
        const QVariantMap z0 = an[0].toMap();
        QCOMPARE(z0["klemmeNr"].toString(), QString("1"));          // nur in der ersten Zeile der Klemme
        QCOMPARE(z0["ebene"].toInt(), 1);
        QCOMPARE(z0["anschlussVon"].toString(), QString("1.1"));
        QCOMPARE(z0["anschlussNach"].toString(), QString("1.2"));
        QCOMPARE(z0["vonPlatziert"].toBool(), false);
        QCOMPARE(z0["klemmeReihenAnz"].toInt(), 1);
        QVERIFY(z0["querschnitt"].toString().startsWith("0.5"));
        const QVariantMap z1 = an[1].toMap();
        QCOMPARE(z1["klemmeNr"].toString(), QString());              // Folgezeile derselben Klemme leer
        QCOMPARE(z1["ebene"].toInt(), 2);
        QCOMPARE(z1["anschlussVon"].toString(), QString("2.1"));
        const QVariantMap z2 = an[2].toMap();
        QCOMPARE(z2["klemmeNr"].toString(), QString("2"));
        QCOMPARE(z2["anschlussVon"].toString(), QString());
    }

    void kl_03_platzierungVerbindungUndAderfarbe()
    {
        QSqlDatabase bib = QSqlDatabase::database("stroemling_bibliothek");
        const int bt = ins("INSERT INTO bauteil (bezeichnung) VALUES ('Klemme Platz')", bib);
        QVERIFY(ins(QString("INSERT INTO bauteil_klemme (bauteil_id, anschluss_typ, ebenen_anzahl,"
                            " punkte_seite_a, punkte_seite_b) VALUES (%1,'schraub',1,1,1)").arg(bt), bib) > 0);
        const int kl = ins("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (1,'X2')");
        const int k1 = ins(QString("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) VALUES (%1,%2,'1',1)").arg(kl).arg(bt));
        const int k2 = ins(QString("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) VALUES (%1,%2,'2',2)").arg(kl).arg(bt));
        QVERIFY(k1 > 0 && k2 > 0);
        const int sid = neueSeite("7");

        // Klemme 1: Anschluss "1.1" liegt bei (12,10); Leitung N1 endet dort; Kabelader liefert Farbe/Nr
        QVERIFY(m_db->grafikSpeichern(sid, {
            symbol("klemme_anschluss", 10, 10, {{"klemmeId", k1}, {"anschlussBezeichnung", "1.1"}, {"rotation", 0}}),
            symbol("klemme_anschluss", 30, 10, {{"klemmeId", k2}, {"anschlussBezeichnung", "1.1"}, {"rotation", 0}}),
            // Aderdefinition liegt auf Segment N2 (Fallback ohne Kabel)
            symbol("aderdefinition", 28, 26, {{"aderfarbe", "blau"}, {"aderfarbe2", "weiss"}, {"bezeichnung", "7"}}),
        }));
        // symbol() legt Elemente als (x,y)-(x+8,y+8) an → Pin 1: cx=14, y1=10 ; Pin 2: cx=34, y1=10
        const int v1 = ins("INSERT INTO verbindung (projekt_id, bezeichnung, signaltyp) VALUES (1,'N1','L')");
        const int v2 = ins("INSERT INTO verbindung (projekt_id, bezeichnung, signaltyp) VALUES (1,'N2','N')");
        QVERIFY(ins(QString("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (%1,%2,"
                            "'[{\"x\":14,\"y\":10},{\"x\":14,\"y\":60}]')").arg(v1).arg(sid)) > 0);
        QVERIFY(ins(QString("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (%1,%2,"
                            "'[{\"x\":34,\"y\":10},{\"x\":34,\"y\":60}]')").arg(v2).arg(sid)) > 0);
        const int kabel = ins("INSERT INTO kabel (projekt_id, bezeichnung) VALUES (1,'W1')");
        QVERIFY(ins(QString("INSERT INTO kabel_ader (kabel_id, ader_nr, farbe, farbe2, bezeichnung, verbindung_id)"
                            " VALUES (%1,1,'rot','','3',%2)").arg(kabel).arg(v1)) > 0);
        // Aderdefinition-Mittelpunkt (32,30) → nicht auf N2 (x=34) → Toleranz 3.0 trifft knapp; auf (34,30) verschieben
        QVERIFY(ins("UPDATE grafik_element SET x1=33,x2=35,y1=29,y2=31 WHERE symbol_id='aderdefinition'") >= 0);

        const QVariantList an = zeilen(m_db->klemmlistenauszug(1), "anschluss");
        QCOMPARE(an.size(), 2);

        const QVariantMap a = an[0].toMap();     // Klemme 1: Verbindung N1 + Kabelader
        QCOMPARE(a["klemmeNr"].toString(), QString("1"));
        QCOMPARE(a["vonPlatziert"].toBool(), true);
        QCOMPARE(a["vonBlattnummer"].toString(), QString("7"));
        QCOMPARE(a["vonVerbBez"].toString(), QString("N1"));
        QCOMPARE(a["vonSignaltyp"].toString(), QString("L"));
        QCOMPARE(a["vonAderFarbe"].toString(), QString("rot"));
        QCOMPARE(a["vonAderNr"].toString(), QString("3"));
        QCOMPARE(a["vonSeiteId"].toInt(), sid);
        QCOMPARE(a["vonWeltX"].toDouble(), 14.0);
        QCOMPARE(a["vonWeltY"].toDouble(), 10.0);
        QCOMPARE(a["nachPlatziert"].toBool(), false);
        QCOMPARE(a["nachVerbBez"].toString(), QString());

        const QVariantMap b = an[1].toMap();     // Klemme 2: Verbindung N2, Aderfarbe aus Aderdefinition
        QCOMPARE(b["vonVerbBez"].toString(), QString("N2"));
        QCOMPARE(b["vonAderFarbe"].toString(), QString("blau"));
        QCOMPARE(b["vonAderFarbe2"].toString(), QString("weiss"));
        QCOMPARE(b["vonAderNr"].toString(), QString("7"));
    }

    void kl_04_stegbrueckenUndJsonProLeiste()
    {
        QSqlDatabase bib = QSqlDatabase::database("stroemling_bibliothek");
        const int bt = ins("INSERT INTO bauteil (bezeichnung) VALUES ('Klemme Steg')", bib);
        QVERIFY(ins(QString("INSERT INTO bauteil_klemme (bauteil_id, anschluss_typ, ebenen_anzahl,"
                            " punkte_seite_a, punkte_seite_b) VALUES (%1,'schraub',1,1,1)").arg(bt), bib) > 0);
        const int kl = ins("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (1,'X3')");
        const int k1 = ins(QString("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) VALUES (%1,%2,'1',1)").arg(kl).arg(bt));
        const int k2 = ins(QString("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) VALUES (%1,%2,'2',2)").arg(kl).arg(bt));
        QVERIFY(ins(QString("INSERT INTO klemme_stegbruecke (klemmenleiste_id, ebene, von_klemme_id, bis_klemme_id, potenzial_text, hat_konflikt)"
                            " VALUES (%1,1,%2,%3,'L1',1)").arg(kl).arg(k1).arg(k2)) > 0);

        const QVariantList l = m_db->klemmlistenauszug(1);
        QCOMPARE(zeilen(l, "leiste")[0].toMap()["stegAnzahl"].toInt(), 1);
        const QVariantList an = zeilen(l, "anschluss");
        QCOMPARE(an.size(), 2);
        const QJsonDocument doc = QJsonDocument::fromJson(an[0].toMap()["leisteStegJson"].toString().toUtf8());
        QVERIFY(doc.isArray());
        QCOMPARE(doc.array().size(), 1);
        const QJsonObject o = doc.array()[0].toObject();
        QCOMPARE(o["pot"].toString(), QString("L1"));
        QCOMPARE(o["vn"].toString(), QString("1"));
        QCOMPARE(o["bn"].toString(), QString("2"));
        QCOMPARE(o["eb"].toInt(), 1);
    }

    void kl_05_klemmeOhneBauteilZeigtPlatzierteAnschluesse()
    {
        const int kl = ins("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (1,'X4')");
        const int k = ins(QString("INSERT INTO klemme (klemmenleiste_id, nummer, sortierung) VALUES (%1,'9',1)").arg(kl));
        const int sid = neueSeite("1");
        QVERIFY(m_db->grafikSpeichern(sid, {
            symbol("klemme_anschluss", 0, 0, {{"klemmeId", k}, {"anschlussBezeichnung", "A"}, {"rotation", 0}}),
            symbol("klemme_anschluss", 20, 0, {{"klemmeId", k}, {"anschlussBezeichnung", "B"}, {"rotation", 90}}),
        }));
        const QVariantList an = zeilen(m_db->klemmlistenauszug(1), "anschluss");
        QCOMPARE(an.size(), 2);
        QCOMPARE(an[0].toMap()["anschlussVon"].toString(), QString("A"));
        QCOMPARE(an[1].toMap()["anschlussVon"].toString(), QString("B"));
        QCOMPARE(an[0].toMap()["klemmeNr"].toString(), QString("9"));
        QCOMPARE(an[1].toMap()["klemmeNr"].toString(), QString());
        QCOMPARE(an[0].toMap()["klemmeReihenAnz"].toInt(), 2);
        // rotation 90 → Pin an der rechten Kante (x2, cy)
        QCOMPARE(an[1].toMap()["vonWeltX"].toDouble(), 28.0);
        QCOMPARE(an[1].toMap()["vonWeltY"].toDouble(), 4.0);
    }
};
