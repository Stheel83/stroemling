#pragma once
#include <QtTest>
#include <QVariantMap>
#include "models/KabelRechnerModel.h"
#include "utils/KabelTabellen.h"

// Regressionstests für den Kabelquerschnitt-Rechner (KabelRechnerModel / KabelTabellen):
//   - die 17 Anwendungsfall-Vorlagen liefern die dokumentierten Querschnitte
//   - Bedarf > 50 mm² → keine Empfehlung (statt stillem Abschneiden)
//   - Abschaltbedingung mit U_0 und eingebbarer Netzimpedanz
//   - Tabellen-Stichproben (A1/B2/E korrigiert, F/G ab 25 mm²)
// Erwartete Werte: Handrechnung mit den Formeln aus konzept/features/12_Kabelberechnung.md.

class TstKabelrechner : public QObject
{
    Q_OBJECT

    static QVariantMap rechne(KabelRechnerModel &m, int betriebsart, double spannung, double strom,
                              double cosPhi, double laenge, double duMax, int verlegeart,
                              int typ, double inSchutz, double rNetz = 0.3, int material = 0)
    {
        m.setBetriebsart(betriebsart);   m.setSpannung(spannung);  m.setStrom(strom);
        m.setCosPhi(cosPhi);             m.setLaenge(laenge);      m.setDuMaxProzent(duMax);
        m.setVerlegeart(verlegeart);     m.setSchutzOrganTyp(typ); m.setSchutzOrganStrom(inSchutz);
        m.setNetzImpedanz(rNetz);        m.setMaterial(material);
        m.setTemperatur(30.0);           m.setHaefung(0);
        m.berechnen();
        return m.ergebnis();
    }

private slots:
    void vorlagen_vollstaendig()
    {
        KabelRechnerModel m;
        const QVariantList v = m.vorlagen();
        QCOMPARE(v.size(), 17);
        const QStringList keys = { "name", "betriebsart", "spannung", "strom", "cosPhi", "laenge",
                                   "duMaxProzent", "verlegeart", "schutzOrganTyp", "schutzOrganStrom" };
        for (const QVariant &e : v) {
            const QVariantMap mp = e.toMap();
            for (const QString &k : keys)
                QVERIFY2(mp.contains(k), qPrintable("Vorlage ohne Feld " + k));
            QVERIFY(!mp["name"].toString().isEmpty());
            QVERIFY(mp["strom"].toDouble() > 0.0);
        }
    }

    // Jede Vorlage muss eine gültige Empfehlung liefern, die der Konzeptdatei entspricht.
    void vorlagen_ergebnisse()
    {
        const QMap<QString, double> erwartet = {
            { "Lichtkreis (10 A)",              1.5 },
            { "Steckdosenkreis (16 A)",         2.5 },
            { "Herd / Backofen (3~, 16 A)",     2.5 },
            { "Durchlauferhitzer (3~, 32 A)",   6.0 },
            { "Wallbox 11 kW (3~, 16 A)",       2.5 },
            { "Bordnetz 12 V DC (10 A)",        6.0 },
            { "Waschmaschine / Trockner (16 A)", 1.5 },
            { "Unterverteilung (3~, 32 A)",      6.0 },
            { "CEE-Steckdose 16 A (3~)",         2.5 },
            { "CEE-Steckdose 32 A (3~)",         6.0 },
            { "Kühlbox / Pumpe 12 V DC (5 A)",   4.0 },
            { "Steuerstromkreis 24 V DC (5 A)",  2.5 },
            { "Drehstrommotor 0,75 kW (1,9 A)", 1.5 },
            { "Drehstrommotor 2,2 kW (4,7 A)",  1.5 },
            { "Drehstrommotor 5,5 kW (11 A)",   1.5 },
            { "Drehstrommotor 11 kW (21 A)",    4.0 },
            { "Drehstrommotor 22 kW (41 A)",   10.0 },
        };
        KabelRechnerModel m;
        const QVariantList liste = m.vorlagen();
        QCOMPARE(liste.size(), erwartet.size());
        for (const QVariant &e : liste) {
            const QVariantMap v = e.toMap();
            const QString name = v["name"].toString();
            QVERIFY2(erwartet.contains(name), qPrintable("Unbekannte Vorlage: " + name));
            const QVariantMap r = rechne(m, v["betriebsart"].toInt(), v["spannung"].toDouble(),
                                         v["strom"].toDouble(), v["cosPhi"].toDouble(),
                                         v["laenge"].toDouble(), v["duMaxProzent"].toDouble(),
                                         v["verlegeart"].toInt(), v["schutzOrganTyp"].toInt(),
                                         v["schutzOrganStrom"].toDouble());
            QVERIFY2(r["gueltig"].toBool(), qPrintable(name));
            QVERIFY2(!r["ueberTabelle"].toBool(), qPrintable(name + ": ueberTabelle"));
            QCOMPARE(r["querschnittMm2"].toDouble(), erwartet.value(name));
        }
    }

    // DC 130 A / 12 V / 25 m / 3 % / A2: kein Normquerschnitt, echter Bedarf ≈ 323 mm²
    void bedarf_ueber_tabelle()
    {
        KabelRechnerModel m;
        const QVariantMap r = rechne(m, 2, 12.0, 130.0, 1.0, 25.0, 3.0, 1, 0, 16);
        QVERIFY(r["ueberTabelle"].toBool());
        QCOMPARE(r["querschnittMm2"].toDouble(), 0.0);
        QCOMPARE(r["querschnittText"].toString(), QString("> 50 mm²"));
        const QVariantMap du = r["spannungsfall"].toMap();
        QVERIFY2(du["mindestText"].toString().contains("323"), qPrintable(du["mindestText"].toString()));
        QVERIFY(!du["ok"].toBool());
        QVERIFY(!r["thermik"].toMap()["ok"].toBool());
    }

    // Drehstrom: Fehlerschleife mit U_0 = U/√3. D50 ist bei 0,3 Ω nicht mehr abschaltbar,
    // mit 0,1 Ω Netzimpedanz schon.
    void abschaltbedingung_u0_und_netzimpedanz()
    {
        KabelRechnerModel m;
        // C50, 41 A, 20 m: rMax = 231/500 - 0,3 = 0,162 Ω → aMin = 40/(56·0,162) = 4,4 → 6 mm²
        QVariantMap r = rechne(m, 1, 400.0, 41.0, 0.85, 20.0, 3.0, 4, 1, 50.0);
        QCOMPARE(r["kurzschluss"].toMap()["mindestText"].toString(), QString("6 mm²"));
        QVERIFY(r["kurzschluss"].toMap()["ok"].toBool());

        // D50 bei 0,3 Ω: 231/1000 - 0,3 < 0 → nicht erreichbar → keine Empfehlung
        r = rechne(m, 1, 400.0, 41.0, 0.85, 20.0, 3.0, 4, 2, 50.0, 0.3);
        QVERIFY(!r["kurzschluss"].toMap()["ok"].toBool());
        QVERIFY(r["ueberTabelle"].toBool());

        // D50 bei 0,1 Ω: rMax = 0,131 Ω → aMin = 40/(56·0,131) = 5,45 → 6 mm²
        r = rechne(m, 1, 400.0, 41.0, 0.85, 20.0, 3.0, 4, 2, 50.0, 0.1);
        QVERIFY(r["kurzschluss"].toMap()["ok"].toBool());
        QVERIFY(!r["ueberTabelle"].toBool());
        QCOMPARE(r["kurzschluss"].toMap()["mindestText"].toString(), QString("6 mm²"));
        // Gesamt 10 mm²: Überlast verlangt I_z ≥ I_n = 50 A (C-Belastbarkeit 10 mm² = 57 A)
        QCOMPARE(r["querschnittMm2"].toDouble(), 10.0);

        // DC: keine Abschaltbedingung
        r = rechne(m, 2, 12.0, 10.0, 1.0, 5.0, 3.0, 4, 0, 10.0);
        QVERIFY(r["kurzschluss"].toMap()["ok"].toBool());
        QCOMPARE(r["kurzschluss"].toMap()["mindestText"].toString(), QString("—"));
    }

    // Überlastbedingung I_b ≤ I_n ≤ I_z: B25 auf Verlegeart B2 verlangt I_z ≥ 25 A → 4 mm² (27 A),
    // obwohl für 10 A Betriebsstrom 1,5 mm² thermisch reichen würden.
    void ueberlast_in_kleiner_iz()
    {
        KabelRechnerModel m;
        QVariantMap r = rechne(m, 0, 230.0, 10.0, 1.0, 20.0, 3.0, 3, 0, 25.0);
        QCOMPARE(r["thermik"].toMap()["mindestText"].toString(), QString("1,5 mm²"));
        const QVariantMap ul = r["ueberlast"].toMap();
        QVERIFY(ul["aktiv"].toBool());
        QCOMPARE(ul["mindestText"].toString(), QString("4 mm²"));
        QVERIFY(ul["ok"].toBool());
        QCOMPARE(r["querschnittMm2"].toDouble(), 4.0);

        // I_n < I_b: Warnung, Querschnitt richtet sich nach dem Betriebsstrom
        r = rechne(m, 0, 230.0, 16.0, 1.0, 20.0, 3.0, 3, 0, 10.0);
        bool warnung = false;
        for (const QVariant &w : r["warnungen"].toList())
            if (w.toString().contains("kleiner als der Betriebsstrom")) warnung = true;
        QVERIFY(warnung);
        QCOMPARE(r["querschnittMm2"].toDouble(), 2.5);

        // I_n über I_z bei 50 mm² → keine Empfehlung
        r = rechne(m, 0, 230.0, 50.0, 1.0, 5.0, 5.0, 3, 0, 160.0);
        QVERIFY(r["ueberTabelle"].toBool());
        QVERIFY(!r["ueberlast"].toMap()["ok"].toBool());
    }

    // Aufgenommene Wirkleistung: AC U·I·cosφ, Drehstrom √3·U·I·cosφ, DC U·I
    void leistungsanzeige()
    {
        KabelRechnerModel m;
        QVariantMap r = rechne(m, 1, 400.0, 16.0, 1.0, 20.0, 3.0, 3, 1, 16.0);   // Wallbox
        QCOMPARE(r["leistungText"].toString(), QString("11,1 kW"));
        r = rechne(m, 0, 230.0, 16.0, 1.0, 25.0, 3.0, 3, 0, 16.0);               // Steckdosenkreis
        QCOMPARE(r["leistungText"].toString(), QString("3,7 kW"));
        r = rechne(m, 2, 12.0, 10.0, 1.0, 5.0, 3.0, 4, 0, 10.0);                 // Bordnetz
        QCOMPARE(r["leistungText"].toString(), QString("120 W"));
        r = rechne(m, 1, 400.0, 11.0, 0.85, 20.0, 3.0, 4, 1, 16.0);              // Motor 5,5 kW (Wellenleistung)
        QCOMPARE(r["leistungText"].toString(), QString("6,5 kW"));
        // Wellenleistungs-Hinweis nur bei cos φ < 1 und nicht DC
        r = rechne(m, 1, 400.0, 11.0, 0.85, 20.0, 3.0, 4, 1, 16.0);
        QVERIFY(r["leistungHinweis"].toBool());
        r = rechne(m, 1, 400.0, 16.0, 1.0, 20.0, 3.0, 3, 1, 16.0);   // ohmsch (Wallbox)
        QVERIFY(!r["leistungHinweis"].toBool());
        r = rechne(m, 2, 12.0, 10.0, 0.5, 5.0, 3.0, 4, 0, 10.0);     // DC
        QVERIFY(!r["leistungHinweis"].toBool());
        // cos φ wird bei DC ignoriert
        r = rechne(m, 2, 12.0, 10.0, 0.5, 5.0, 3.0, 4, 0, 10.0);
        QCOMPARE(r["leistungText"].toString(), QString("120 W"));
    }

    // Verlegeart D: ungeprüfte Werte → Warnung; andere Verlegearten ohne diese Warnung
    void verlegeart_d_warnung()
    {
        KabelRechnerModel m;
        auto hatDWarnung = [](const QVariantMap &r) {
            for (const QVariant &w : r["warnungen"].toList())
                if (w.toString().contains("Verlegeart D")) return true;
            return false;
        };
        QVERIFY(hatDWarnung(rechne(m, 0, 230.0, 16.0, 1.0, 20.0, 3.0, 5, 0, 16.0)));
        QVERIFY(!hatDWarnung(rechne(m, 0, 230.0, 16.0, 1.0, 20.0, 3.0, 3, 0, 16.0)));
    }

    // Zwei belastete Adern (AC einphasig, DC) haben höhere Belastbarkeit als drei (Drehstrom):
    // B2, 1,5 mm²: 16,5 A (2 Adern) gegen 15 A (3 Adern). Gleicher Strom, kurze Leitung.
    void zwei_belastete_adern()
    {
        KabelRechnerModel m;
        QVariantMap ac = rechne(m, 0, 230.0, 16.0, 1.0, 5.0, 3.0, 3, 0, 16.0);
        QCOMPARE(ac["querschnittMm2"].toDouble(), 1.5);
        QCOMPARE(ac["thermik"].toMap()["kenngroesse"].toString(), QString("I_z = 16,5 A"));
        QVariantMap dreh = rechne(m, 1, 400.0, 16.0, 1.0, 5.0, 3.0, 3, 0, 16.0);
        QCOMPARE(dreh["querschnittMm2"].toDouble(), 2.5);
        QCOMPARE(dreh["thermik"].toMap()["kenngroesse"].toString(), QString("I_z = 20,0 A"));
        // DC rechnet wie AC einphasig mit 2 belasteten Adern
        QVariantMap dc = rechne(m, 2, 24.0, 16.0, 1.0, 1.0, 3.0, 3, 0, 16.0);
        QCOMPARE(dc["thermik"].toMap()["kenngroesse"].toString(), QString("I_z = 16,5 A"));
    }

    // Al + Verlegeart F/G: Thermik nicht bewertbar → eine Meldung, keine Empfehlung
    void aluminium_verlegeart_fg()
    {
        KabelRechnerModel m;
        const QVariantMap r = rechne(m, 0, 230.0, 20.0, 1.0, 20.0, 3.0, 7, 1, 20.0, 0.3, 1);
        QVERIFY(r["thermikFehlt"].toBool());
        QVERIFY(r["ueberTabelle"].toBool());
        QCOMPARE(r["querschnittText"].toString(), QString("—"));
        QVERIFY(r["ueberTabelleGrund"].toString().contains("Aluminium"));
        for (const QVariant &w : r["warnungen"].toList())
            QVERIFY2(!w.toString().contains("reicht für den angegebenen Strom nicht"), qPrintable(w.toString()));
    }

    // Tabellenstichproben gegen Tabellenbuch (DIN VDE 0298-4:03-08, 25 °C ×0,94) bzw. ABB-Auszug
    void tabellen_stichproben()
    {
        using namespace KabelTabellen;
        // Index: A1=0 A2=1 B1=2 B2=3 C=4 D=5 E=6 F=7 G=8
        QCOMPARE(referenzstrom(0, 1.5, 0), 13.5);   // A1
        QCOMPARE(referenzstrom(0, 50.0, 0), 108.0);
        QCOMPARE(referenzstrom(0, 50.0, 1), 99.0);   // A2
        QCOMPARE(referenzstrom(0, 50.0, 3), 118.0);  // B2 (vorher 125)
        QCOMPARE(referenzstrom(0, 50.0, 6), 153.0);  // E  (vorher 158)
        QCOMPARE(referenzstrom(0, 16.0, 7), 0.0);    // F erst ab 25 mm²
        QCOMPARE(referenzstrom(0, 25.0, 7), 110.0);  // F
        QCOMPARE(referenzstrom(0, 50.0, 8), 197.0);  // G
        QCOMPARE(referenzstrom(0, 10.0, 8), 0.0);    // G erst ab 25 mm²
        QCOMPARE(referenzstrom(1, 10.0, 7), 0.0);    // Al: F nicht hinterlegt
        QCOMPARE(referenzstrom(0, 3.0, 3), 0.0);     // kein Normquerschnitt
        QCOMPARE(referenzstrom(0, 6.0, 9), 0.0);     // Verlegeart außerhalb
        // 2 belastete Adern: höhere Werte, wo tabelliert; sonst Rückfall auf 3 Adern
        QCOMPARE(referenzstrom(0, 50.0, 1, 2), 110.0);   // A2
        QCOMPARE(referenzstrom(0, 50.0, 1, 3), 99.0);
        QCOMPARE(referenzstrom(0, 25.0, 7, 2), 131.0);   // F
        QCOMPARE(referenzstrom(0, 50.0, 8, 2), 197.0);   // G: nur 3 Adern tabelliert → Rückfall
        QCOMPARE(referenzstrom(0, 50.0, 5, 2), 122.0);   // D: Rückfall
        QCOMPARE(referenzstrom(1, 50.0, 1, 2), 77.0);    // Al: Rückfall
        QCOMPARE(naechsterNormquerschnitt(7.0), 10.0);
        QVERIFY(qFuzzyCompare(temperaturfaktor(40.0), 0.87));
    }
};
