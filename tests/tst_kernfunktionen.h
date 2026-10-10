#pragma once
#include <QtTest>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDir>
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
        for (int voll = 0; voll <= 1; ++voll)
            for (int nb = 0; nb <= 1; ++nb)
                for (int inf = 0; inf <= 1; ++inf) {
                    const QString f = QString("%1/%2_nb%3_inf%4.pdf").arg(aus, voll ? "voll" : "seite").arg(nb).arg(inf);
                    QVERIFY2(m_db->canvasPdfExportieren(pid, f, nb, voll, inf), qPrintable(f));
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
        QVERIFY(m_db->canvasPdfExportieren(pid, aus + "/synth_seite.pdf", true, false, true));
        QVERIFY(m_db->canvasPdfExportieren(pid, aus + "/synth_voll.pdf", false, true, true));
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
