#include "Database.h"
#include <cmath>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <algorithm>
#include <QPrinter>
#include <QTextDocument>
#include <QPdfWriter>
#include <QPainter>
#include <QPen>
#include <QFont>
#include <QFontMetricsF>
#include <QColor>
#include <QPolygonF>
#include <QPageSize>
#include <QPageLayout>

QVariantList Database::ibnListeLaden(int projektId, int seiteId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT
            MIN(ge.id)                                       AS element_id,
            ge.seite_id,
            s.blattnummer,
            COALESCE(s.bezeichnung, '')                      AS seitenbezeichnung,
            json_extract(ge.extra_daten, '$.bmk')            AS bmk,
            COALESCE(ibn.status, 'offen')                    AS status,
            COALESCE(ibn.id, 0)                              AS ibn_id,
            COALESCE(ibn.notiz, '')                          AS notiz,
            COALESCE(ibn.bauteil_id, '')                     AS bauteil_id,
            COALESCE(ibn.geprueft_von, '')                   AS geprueft_von,
            COALESCE(ibn.geprueft_am, '')                    AS geprueft_am,
            MIN(ge.x1)                                       AS x1,
            MIN(ge.y1)                                       AS y1,
            COALESCE(MAX(sd.ibn_kategorie), '')              AS symbol_kategorie,
            a.kuerzel                                        AS anlage_kz,
            o.kuerzel                                        AS ort_kz,
            COALESCE(a.anlage_uebergeordnet, '')             AS anlage_uo,
            COALESCE(o.standort_uebergeordnet, '')           AS ort_uo,
            (SELECT sk.extra_daten
             FROM grafik_element sk
             WHERE sk.seite_id = ge.seite_id
               AND sk.typ = 'strukturkasten'
               AND (MIN(ge.x1) + MIN(ge.x2)) / 2.0 >= sk.x1
               AND (MIN(ge.x1) + MIN(ge.x2)) / 2.0 <= sk.x2
               AND (MIN(ge.y1) + MIN(ge.y2)) / 2.0 >= sk.y1
               AND (MIN(ge.y1) + MIN(ge.y2)) / 2.0 <= sk.y2
             ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
             LIMIT 1)                                         AS sk_extra
        FROM grafik_element ge
        JOIN seite   s ON ge.seite_id   = s.id
        JOIN ort     o ON s.ort_id      = o.id
        JOIN anlage  a ON o.anlage_id   = a.id
        LEFT JOIN symbol_definition sd ON ge.symbol_id = sd.id
        LEFT JOIN inbetriebnahme ibn
               ON ibn.seite_id = ge.seite_id
              AND ibn.bmk      = json_extract(ge.extra_daten, '$.bmk')
        WHERE a.projekt_id  = :pid
          AND (:sid = -1 OR ge.seite_id = :sid)
          AND ge.typ        = 'symbol'
          AND json_extract(ge.extra_daten, '$.bmk') IS NOT NULL
          AND json_extract(ge.extra_daten, '$.bmk') != ''
        GROUP BY ge.seite_id, json_extract(ge.extra_daten, '$.bmk')
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, bmk
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":sid", seiteId);

    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnListeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QString anlageKz = q.value("anlage_kz").toString();
        QString ortKz    = q.value("ort_kz").toString();
        QString anlageUO = q.value("anlage_uo").toString();
        QString ortUO    = q.value("ort_uo").toString();
        strukturkastenOverrideAnwenden(q.value("sk_extra").toString(), anlageKz, ortKz, anlageUO, ortUO);

        result.append(QVariantMap{
            { "elementId",        q.value("element_id")      },
            { "seiteId",          q.value("seite_id")        },
            { "blattnummer",      q.value("blattnummer")     },
            { "seitenbezeichnung",q.value("seitenbezeichnung")},
            { "bmk",              q.value("bmk")             },
            { "status",           q.value("status")          },
            { "ibnId",            q.value("ibn_id")          },
            { "notiz",            q.value("notiz")           },
            { "bauteilId",        q.value("bauteil_id")      },
            { "geprueftVon",      q.value("geprueft_von")    },
            { "geprueftAm",       q.value("geprueft_am")     },
            { "x1",               q.value("x1")              },
            { "y1",               q.value("y1")              },
            { "symbolKategorie",  q.value("symbol_kategorie") },
            { "anlageKz",         anlageKz                    },
            { "ortKz",            ortKz                       },
            { "anlageUO",         anlageUO                    },
            { "ortUO",            ortUO                       },
        });
    }
    return result;
}

bool Database::ibnEintragSpeichern(int projektId, int seiteId,
                                    const QString &bmk,
                                    const QString &status,
                                    const QString &notiz,
                                    const QString &bauteilId,
                                    const QString &geprueftVon,
                                    const QString &geprueftAm)
{
    QSqlQuery q(m_db);
    // Sicherstellen dass ein Datensatz existiert
    q.prepare(R"(
        INSERT INTO inbetriebnahme (projekt_id, seite_id, bmk, erstellt_am)
        VALUES (:pid, :sid, :bmk, datetime('now'))
        ON CONFLICT(seite_id, bmk) DO NOTHING
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnEintragSpeichern INSERT:" << q.lastError().text();
        return false;
    }

    q.prepare(R"(
        UPDATE inbetriebnahme
        SET status       = :st,
            notiz        = :no,
            bauteil_id   = :bid,
            geprueft_von = :gv,
            geprueft_am  = :ga
        WHERE seite_id = :sid AND bmk = :bmk
    )");
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":bid", bauteilId);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnEintragSpeichern UPDATE:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnStatusSetzen(int seiteId, const QString &bmk, const QString &status)
{
    QSqlQuery q(m_db);
    // Eintrag anlegen falls noch nicht vorhanden (projekt_id wird aus seite abgeleitet)
    q.prepare(R"(
        INSERT INTO inbetriebnahme (projekt_id, seite_id, bmk, status, erstellt_am)
        SELECT a.projekt_id, :sid, :bmk, :st, datetime('now')
        FROM seite s JOIN ort o ON s.ort_id=o.id JOIN anlage a ON o.anlage_id=a.id
        WHERE s.id = :sid
        ON CONFLICT(seite_id, bmk) DO UPDATE SET status = :st
    )");
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    q.bindValue(":st",  status);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnStatusSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantMap Database::ibnEintragFuerBmk(int seiteId, const QString &bmk)
{
    if (bmk.isEmpty()) return {};
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, status, bauteil_id, geprueft_von, geprueft_am, notiz, symbol_kategorie
        FROM inbetriebnahme
        WHERE seite_id = :sid AND bmk = :bmk
    )");
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec() || !q.next()) return {};

    int ibnId = q.value("id").toInt();
    QVariantMap result{
        { "ibnId",           ibnId                       },
        { "status",          q.value("status")           },
        { "bauteilId",       q.value("bauteil_id")       },
        { "geprueftVon",     q.value("geprueft_von")     },
        { "geprueftAm",      q.value("geprueft_am")      },
        { "notiz",           q.value("notiz")            },
        { "symbolKategorie", q.value("symbol_kategorie") },
        { "felder",          ibnFeldwerteLaden(ibnId)    },
    };
    return result;
}

// ── IBN Kabel ────────────────────────────────────────────────────────────

QVariantList Database::ibnKabelListeLaden(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id              AS kabel_id,
               k.bezeichnung,
               k.kabeltyp,
               k.aderzahl,
               k.querschnitt_mm2,
               k.laenge_m,
               COALESCE(k.von_ort, '')          AS von_ort,
               COALESCE(k.nach_ort, '')         AS nach_ort,
               COALESCE(k.grafik_element_id, 0) AS grafik_element_id,
               COALESCE(ge.seite_id, -1)        AS seite_id,
               COALESCE(ge.x1, 0)               AS x1,
               COALESCE(ge.y1, 0)               AS y1,
               COALESCE(ib.status, 'offen')     AS status,
               COALESCE(ib.notiz, '')           AS notiz,
               COALESCE(ib.geprueft_von, '')    AS geprueft_von,
               COALESCE(ib.geprueft_am, '')     AS geprueft_am
        FROM kabel k
        LEFT JOIN ibn_kabel ib ON ib.kabel_id = k.id
        LEFT JOIN grafik_element ge ON ge.id = k.grafik_element_id
        WHERE k.projekt_id = :pid
        ORDER BY k.bezeichnung
    )");
    q.bindValue(":pid", projektId);

    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnKabelListeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "kabelId",        q.value("kabel_id")        },
            { "bezeichnung",    q.value("bezeichnung")     },
            { "kabeltyp",       q.value("kabeltyp")        },
            { "aderzahl",       q.value("aderzahl")        },
            { "querschnittMm2", q.value("querschnitt_mm2") },
            { "laengeM",        q.value("laenge_m")        },
            { "vonOrt",         q.value("von_ort")         },
            { "nachOrt",        q.value("nach_ort")        },
            { "grafikElementId",q.value("grafik_element_id")},
            { "seiteId",        q.value("seite_id")        },
            { "x1",             q.value("x1")              },
            { "y1",             q.value("y1")              },
            { "status",         q.value("status")          },
            { "notiz",          q.value("notiz")           },
            { "geprueftVon",    q.value("geprueft_von")    },
            { "geprueftAm",     q.value("geprueft_am")     },
        });
    }
    return result;
}

bool Database::ibnKabelSpeichern(int projektId, int kabelId,
                                  const QString &status,
                                  const QString &notiz,
                                  const QString &geprueftVon,
                                  const QString &geprueftAm)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO ibn_kabel (projekt_id, kabel_id, status, notiz, geprueft_von, geprueft_am)
        VALUES (:pid, :kid, :st, :no, :gv, :ga)
        ON CONFLICT(kabel_id) DO NOTHING
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":kid", kabelId);
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnKabelSpeichern INSERT:" << q.lastError().text();
        return false;
    }
    q.prepare(R"(
        UPDATE ibn_kabel
        SET status       = :st,
            notiz        = :no,
            geprueft_von = :gv,
            geprueft_am  = :ga
        WHERE kabel_id = :kid
    )");
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnKabelSpeichern UPDATE:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnKabelStatusSetzen(int kabelId, const QString &status)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO ibn_kabel (projekt_id, kabel_id, status)
        VALUES ((SELECT projekt_id FROM kabel WHERE id = :kid), :kid, :st)
        ON CONFLICT(kabel_id) DO UPDATE SET status = :st
    )");
    q.bindValue(":kid", kabelId);
    q.bindValue(":st",  status);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnKabelStatusSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── IBN Feldvorlagen / Feldwerte ─────────────────────────────────────────────

bool Database::seedIbnFeldvorlagen()
{
    struct Feld {
        QString kategorie, feldname, label, feldtyp, optionen, einheit;
        int pflicht, reihenfolge;
    };
    static const QList<Feld> felder = {
        // Leitungsschutzschalter
        { "leitungsschutzschalter", "nennstrom",       "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "leitungsschutzschalter", "ausloesekurve",    "Auslösekurve",          "auswahl",  "B,C,D", "", 1, 2 },
        { "leitungsschutzschalter", "pole",             "Polzahl",               "auswahl",  "1,2,3,4", "", 1, 3 },
        { "leitungsschutzschalter", "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  0, 4 },
        { "leitungsschutzschalter", "ausschaltvermoegen","Ausschaltvermögen (kA)","zahl",     "", "kA", 0, 5 },
        { "leitungsschutzschalter", "bemerkung",        "Bemerkung",             "text",     "", "",   0, 6 },
        // Sicherung
        { "sicherung",              "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "sicherung",              "sicherungstyp",    "Sicherungstyp",         "auswahl",  "gG,gL,aM,NH", "", 1, 2 },
        { "sicherung",              "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  0, 3 },
        { "sicherung",              "bemerkung",        "Bemerkung",             "text",     "", "",   0, 4 },
        // FI-Schutzschalter
        { "fi_schutzschalter",      "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "fi_schutzschalter",      "fehlerstrom",      "Fehlerstrom (mA)",       "auswahl",  "10,30,100,300", "", 1, 2 },
        { "fi_schutzschalter",      "typ",              "FI-Typ",                "auswahl",  "Typ A,Typ B,Typ F", "", 1, 3 },
        { "fi_schutzschalter",      "pole",             "Polzahl",               "auswahl",  "2,4", "",   1, 4 },
        { "fi_schutzschalter",      "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 5 },
        { "fi_schutzschalter",      "bemerkung",        "Bemerkung",             "text",     "", "",   0, 6 },
        // Motorschutzschalter
        { "motorschutzschalter",    "einstellstrom",    "Einstellstrom (A)",      "zahl",     "", "A",  1, 1 },
        { "motorschutzschalter",    "einstellbereich",  "Einstellbereich (A)",    "text",     "", "A",  0, 2 },
        { "motorschutzschalter",    "klasse",           "Auslöseklasse",         "auswahl",  "10,10A,20,30", "", 0, 3 },
        { "motorschutzschalter",    "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 4 },
        { "motorschutzschalter",    "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Schütz
        { "schuetz",                "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "schuetz",                "spulenspannung",   "Spulenspannung (V)",     "zahl",     "", "V",  1, 2 },
        { "schuetz",                "spulenfrequenz",   "Spulenfrequenz",        "auswahl",  "DC,50 Hz,60 Hz", "", 0, 3 },
        { "schuetz",                "einschaltdauer",   "Einschaltdauer (%ED)",   "zahl",     "", "%",  0, 4 },
        { "schuetz",                "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Motor
        { "motor",                  "nennleistung",     "Nennleistung (kW)",      "zahl",     "", "kW", 1, 1 },
        { "motor",                  "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 2 },
        { "motor",                  "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  1, 3 },
        { "motor",                  "drehzahl",         "Nenndrehzahl (U/min)",   "zahl",     "", "U/min", 0, 4 },
        { "motor",                  "cos_phi",          "cos φ",                 "zahl",     "", "",   0, 5 },
        { "motor",                  "drehrichtung",     "Drehrichtung geprüft",  "boolean",  "", "",   0, 6 },
        { "motor",                  "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 7 },
        { "motor",                  "bemerkung",        "Bemerkung",             "text",     "", "",   0, 8 },
        // Transformator
        { "transformator",          "primaerspannung",  "Primärspannung (V)",     "zahl",     "", "V",  1, 1 },
        { "transformator",          "sekundaerspannung","Sekundärspannung (V)",   "zahl",     "", "V",  1, 2 },
        { "transformator",          "nennleistung",     "Nennleistung (VA)",      "zahl",     "", "VA", 1, 3 },
        { "transformator",          "leerlaufspannung", "Leerlaufspannung (V)",   "zahl",     "", "V",  0, 4 },
        { "transformator",          "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Temperatursensor
        { "temperatursensor",  "sensortyp",      "Sensortyp",                   "auswahl", "PT100,PT1000,Thermoelement Typ K,Thermoelement Typ J,NTC,Bimetall", "", 1,  1 },
        { "temperatursensor",  "messbereich_min","Messbereich min (°C)",   "zahl",    "", "°C",  0,  2 },
        { "temperatursensor",  "messbereich_max","Messbereich max (°C)",   "zahl",    "", "°C",  0,  3 },
        { "temperatursensor",  "ausgangssignal", "Ausgangssignal",              "auswahl", "4-20mA,0-10V,2-10V,Widerstand,digital", "", 0, 4 },
        { "temperatursensor",  "istwert",        "Istwert bei IBN (°C)",  "zahl",    "", "°C",  0,  5 },
        { "temperatursensor",  "kalibriert",     "Kalibriert",                 "boolean", "", "",         0,  6 },
        { "temperatursensor",  "bemerkung",      "Bemerkung",                  "text",    "", "",         0,  7 },
        // Drucksensor
        { "drucksensor",  "messprinzip",     "Messprinzip",                "auswahl", "Piezoresistiv,Kapazitiv,Piezoelektrisch,Differenzdruck", "", 0, 1 },
        { "drucksensor",  "messbereich_min", "Messbereich min (bar)",      "zahl",    "", "bar", 0, 2 },
        { "drucksensor",  "messbereich_max", "Messbereich max (bar)",      "zahl",    "", "bar", 1, 3 },
        { "drucksensor",  "prozessanschluss","Prozessanschluss",           "text",    "", "",    0, 4 },
        { "drucksensor",  "ausgangssignal",  "Ausgangssignal",             "auswahl", "4-20mA,0-10V,2-10V,0-20mA,HART", "", 0, 5 },
        { "drucksensor",  "istwert",         "Istwert bei IBN (bar)",      "zahl",    "", "bar", 0, 6 },
        { "drucksensor",  "kalibriert",      "Kalibriert",                 "boolean", "", "",    0, 7 },
        { "drucksensor",  "bemerkung",       "Bemerkung",                  "text",    "", "",    0, 8 },
        // Füllstandssensor
        { "fuellstandssensor",  "messprinzip",     "Messprinzip",             "auswahl", "Ultraschall,Radar,Schwimmer,Hydrostatisch,Leitfähigkeit,Kapazitiv", "", 1, 1 },
        { "fuellstandssensor",  "messbereich_min", "Messbereich min (m)",     "zahl",    "", "m",   0, 2 },
        { "fuellstandssensor",  "messbereich_max", "Messbereich max (m)",     "zahl",    "", "m",   0, 3 },
        { "fuellstandssensor",  "ausgangssignal",  "Ausgangssignal",          "auswahl", "4-20mA,0-10V,2-10V,HART,digital", "", 0, 4 },
        { "fuellstandssensor",  "istwert",         "Istwert bei IBN (%)",     "zahl",    "", "%",   0, 5 },
        { "fuellstandssensor",  "kalibriert",      "Kalibriert",              "boolean", "", "",    0, 6 },
        { "fuellstandssensor",  "bemerkung",       "Bemerkung",               "text",    "", "",    0, 7 },
        // Grenzwertschalter (Hoch-/Niedrigalarm)
        { "grenzwertschalter",  "schaltgroesse",       "Schaltgröße",        "auswahl", "Temperatur,Druck,Füllstand,Durchfluss,Strom,Spannung,Drehzahl", "", 1, 1 },
        { "grenzwertschalter",  "schaltpunkt_hoch",    "Schaltpunkt Hoch",              "zahl",    "", "", 0, 2 },
        { "grenzwertschalter",  "schaltpunkt_niedrig", "Schaltpunkt Niedrig",           "zahl",    "", "", 0, 3 },
        { "grenzwertschalter",  "einheit_schaltpunkt", "Einheit Schaltpunkt",           "text",    "", "", 0, 4 },
        { "grenzwertschalter",  "hysterese",           "Hysterese",                     "zahl",    "", "", 0, 5 },
        { "grenzwertschalter",  "schaltfunktion",      "Schaltfunktion",                "auswahl", "Öffner (NC),Schließer (NO),Wechsler", "", 0, 6 },
        { "grenzwertschalter",  "auslosung_geprueft",  "Auslösung geprüft",  "boolean", "", "", 0, 7 },
        { "grenzwertschalter",  "bemerkung",           "Bemerkung",                     "text",    "", "", 0, 8 },
        // Frequenzumrichter
        { "frequenzumrichter",  "nennleistung",      "Nennleistung (kW)",           "zahl",    "", "kW",  1,  1 },
        { "frequenzumrichter",  "nennstrom",         "Nennstrom Motor (A)",         "zahl",    "", "A",   1,  2 },
        { "frequenzumrichter",  "nennspannung",      "Nennspannung (V)",            "zahl",    "", "V",   1,  3 },
        { "frequenzumrichter",  "max_frequenz",      "Max. Ausgangsfrequenz (Hz)",  "zahl",    "", "Hz",  0,  4 },
        { "frequenzumrichter",  "min_frequenz",      "Min. Frequenz (Hz)",          "zahl",    "", "Hz",  0,  5 },
        { "frequenzumrichter",  "rampe_hochlauf",    "Rampenzeit Hochlauf (s)",     "zahl",    "", "s",   0,  6 },
        { "frequenzumrichter",  "rampe_ruecklauf",   "Rampenzeit Rücklauf (s)","zahl",   "", "s",   0,  7 },
        { "frequenzumrichter",  "steuerart",         "Steuerart",                  "auswahl", "U/f,FOC,DTC,Sensorlos", "", 0, 8 },
        { "frequenzumrichter",  "motorschutz_a",     "Motorschutz eingestellt (A)", "zahl",   "", "A",   0,  9 },
        { "frequenzumrichter",  "drehrichtung",      "Drehrichtung geprüft",  "boolean", "", "",    0, 10 },
        { "frequenzumrichter",  "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 11 },
        { "frequenzumrichter",  "emv_filter",        "EMV-Filter verbaut",         "boolean", "", "",    0, 12 },
        { "frequenzumrichter",  "bremswiderstand",   "Bremswiderstand verbaut",    "boolean", "", "",    0, 13 },
        { "frequenzumrichter",  "bemerkung",         "Bemerkung",                  "text",    "", "",    0, 14 },
        // Sanftanlauf
        { "sanftanlauf",  "nennleistung",    "Nennleistung (kW)",          "zahl",    "", "kW",  1,  1 },
        { "sanftanlauf",  "nennstrom",       "Nennstrom (A)",              "zahl",    "", "A",   1,  2 },
        { "sanftanlauf",  "nennspannung",    "Nennspannung (V)",           "zahl",    "", "V",   1,  3 },
        { "sanftanlauf",  "anlaufstrom",     "Anlaufstrombegrenzung (%In)","zahl",    "", "%In", 0,  4 },
        { "sanftanlauf",  "anlaufzeit",      "Anlaufzeit (s)",             "zahl",    "", "s",   0,  5 },
        { "sanftanlauf",  "stoppzeit",       "Stoppzeit (s)",              "zahl",    "", "s",   0,  6 },
        { "sanftanlauf",  "bypass_schuetz",  "Bypass-Schütz verbaut","boolean", "", "",    0,  7 },
        { "sanftanlauf",  "drehrichtung",    "Drehrichtung geprüft", "boolean", "", "",    0,  8 },
        { "sanftanlauf",  "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 9 },
        { "sanftanlauf",  "bemerkung",       "Bemerkung",                  "text",    "", "",    0, 10 },
        // Durchflussmesser
        { "durchflussmesser",  "messprinzip",    "Messprinzip",           "auswahl", "Magnetisch-induktiv,Ultraschall,Corioliskraft,Wirbelzähler,Differenzdruck,Thermisch", "", 1, 1 },
        { "durchflussmesser",  "nennweite_dn",   "Nennweite DN (mm)",     "zahl",    "", "mm",    0, 2 },
        { "durchflussmesser",  "messbereich_max","Messbereich max",        "zahl",    "", "m³/h", 0, 3 },
        { "durchflussmesser",  "ausgangssignal", "Ausgangssignal",        "auswahl", "4-20mA,0-10V,Pulsausgang,HART,Feldbus", "", 0, 4 },
        { "durchflussmesser",  "istwert",        "Istwert bei IBN",       "zahl",    "", "m³/h", 0, 5 },
        { "durchflussmesser",  "kalibriert",     "Kalibriert",            "boolean", "", "",      0, 6 },
        { "durchflussmesser",  "bemerkung",      "Bemerkung",             "text",    "", "",      0, 7 },
    };

    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT OR IGNORE INTO ibn_feldvorlage
            (symbol_kategorie, feldname, label, feldtyp, optionen, einheit, pflichtfeld, reihenfolge, erstellt_von)
        VALUES (:kat, :fn, :lbl, :typ, :opt, :ein, :pfl, :rei, 'system')
    )");
    for (const auto &f : felder) {
        q.bindValue(":kat", f.kategorie);
        q.bindValue(":fn",  f.feldname);
        q.bindValue(":lbl", f.label);
        q.bindValue(":typ", f.feldtyp);
        q.bindValue(":opt", f.optionen);
        q.bindValue(":ein", f.einheit);
        q.bindValue(":pfl", f.pflicht);
        q.bindValue(":rei", f.reihenfolge);
        if (!q.exec()) {
            qCWarning(lcDb) << "seedIbnFeldvorlagen:" << q.lastError().text();
            return false;
        }
    }

    // symbol_definition.ibn_kategorie für bekannte Symbole setzen
    struct KatMap { QString symbolId, kategorie; };
    static const QList<KatMap> katMap = {
        { "lss",          "leitungsschutzschalter" },
        { "sicherung",    "sicherung"              },
        { "fi",           "fi_schutzschalter"      },
        { "bimetall_nc",  "motorschutzschalter"    },
        { "spule",        "schuetz"                },
        { "spule_ansi",   "schuetz"                },
        { "motor",        "motor"                  },
        { "trafo",        "transformator"          },
        { "sensor_temp",  "temperatursensor"       },
        { "sensor_druck", "drucksensor"            },
    };
    QSqlQuery qu;
    qu.prepare("UPDATE symbol_definition SET ibn_kategorie = :kat WHERE id = :id");
    for (const auto &km : katMap) {
        qu.bindValue(":kat", km.kategorie);
        qu.bindValue(":id",  km.symbolId);
        if (!qu.exec())
            qCWarning(lcDb) << "seedIbnFeldvorlagen update" << km.symbolId << ":" << qu.lastError().text();
    }
    return true;
}

QVariantList Database::ibnFeldvorlagenLaden(const QString &symbolKategorie)
{
    if (symbolKategorie.isEmpty())
        return {};
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT feldname, label, feldtyp, optionen, einheit, pflichtfeld
        FROM ibn_feldvorlage
        WHERE symbol_kategorie = :kat
        ORDER BY reihenfolge
    )");
    q.bindValue(":kat", symbolKategorie);
    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnFeldvorlagenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "feldname",   q.value("feldname")   },
            { "label",      q.value("label")      },
            { "feldtyp",    q.value("feldtyp")    },
            { "optionen",   q.value("optionen")   },
            { "einheit",    q.value("einheit")    },
            { "pflichtfeld",q.value("pflichtfeld") },
        });
    }
    return result;
}

QVariantList Database::ibnAlleVorlagenLaden()
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, symbol_kategorie, feldname, label, feldtyp, optionen,
               einheit, pflichtfeld, reihenfolge, erstellt_von
        FROM ibn_feldvorlage
        ORDER BY symbol_kategorie, reihenfolge, id
    )");
    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnAlleVorlagenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "id",              q.value("id")              },
            { "symbolKategorie", q.value("symbol_kategorie") },
            { "feldname",        q.value("feldname")        },
            { "label",           q.value("label")           },
            { "feldtyp",         q.value("feldtyp")         },
            { "optionen",        q.value("optionen")        },
            { "einheit",         q.value("einheit")         },
            { "pflichtfeld",     q.value("pflichtfeld")     },
            { "reihenfolge",     q.value("reihenfolge")     },
            { "erstelltVon",     q.value("erstellt_von")    },
        });
    }
    return result;
}

QVariantList Database::ibnAlleKategorienLaden()
{
    QSqlQuery q("SELECT DISTINCT symbol_kategorie FROM ibn_feldvorlage ORDER BY symbol_kategorie");
    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnAlleKategorienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(q.value(0));
    return result;
}

bool Database::ibnFeldVorlageSpeichern(const QString &symbolKategorie,
                                        const QString &feldname,
                                        const QString &label,
                                        const QString &feldtyp,
                                        const QString &optionen,
                                        const QString &einheit,
                                        bool pflichtfeld)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO ibn_feldvorlage
            (symbol_kategorie, feldname, label, feldtyp, optionen, einheit,
             pflichtfeld, reihenfolge, erstellt_von)
        VALUES (:kat, :fn, :lbl, :typ, :opt, :ein, :pfl,
                (SELECT COALESCE(MAX(reihenfolge), 0) + 1
                 FROM ibn_feldvorlage WHERE symbol_kategorie = :kat2),
                'user')
    )");
    q.bindValue(":kat",  symbolKategorie);
    q.bindValue(":kat2", symbolKategorie);
    q.bindValue(":fn",   feldname);
    q.bindValue(":lbl",  label);
    q.bindValue(":typ",  feldtyp);
    q.bindValue(":opt",  optionen);
    q.bindValue(":ein",  einheit);
    q.bindValue(":pfl",  pflichtfeld ? 1 : 0);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnFeldVorlageSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnFeldVorlageLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM ibn_feldvorlage WHERE id = :id AND erstellt_von = 'user'");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnFeldVorlageLoeschen:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

// ============================================================
// ibnFeldVorlageUmordnen (IBN-05, Feld-Reihenfolge per Drag & Drop)
// reihenfolge ist pro symbol_kategorie skaliert (0..n-1) – neues Feld
// bekommt beim Anlegen bereits MAX(reihenfolge)+1 innerhalb seiner
// Kategorie (siehe ibnFeldVorlageSpeichern). Gleiches Muster wie
// SeitenModel::seiteUmordnen() (Pro-Skop-Neu-Nummerierung nach Verschieben).
// ============================================================
bool Database::ibnFeldVorlageUmordnen(int id, int neuerIndex)
{
    QSqlQuery kq(m_db);
    kq.prepare("SELECT symbol_kategorie FROM ibn_feldvorlage WHERE id = :id");
    kq.bindValue(":id", id);
    if (!kq.exec() || !kq.next()) return false;
    const QString kategorie = kq.value(0).toString();

    QSqlQuery lq(m_db);
    lq.prepare("SELECT id FROM ibn_feldvorlage WHERE symbol_kategorie = :kat "
               "ORDER BY reihenfolge, id");
    lq.bindValue(":kat", kategorie);
    if (!lq.exec()) {
        qCWarning(lcDb) << "ibnFeldVorlageUmordnen SELECT:" << lq.lastError().text();
        return false;
    }
    QList<int> ids;
    while (lq.next()) ids.append(lq.value(0).toInt());

    const int alterIndex = ids.indexOf(id);
    if (alterIndex < 0) return false;
    neuerIndex = qBound(0, neuerIndex, ids.size() - 1);
    if (alterIndex == neuerIndex) return false;

    ids.removeAt(alterIndex);
    ids.insert(neuerIndex, id);

    QSqlQuery uq(m_db);
    uq.prepare("UPDATE ibn_feldvorlage SET reihenfolge = :r WHERE id = :id");
    for (int i = 0; i < ids.size(); ++i) {
        uq.bindValue(":r",  i);
        uq.bindValue(":id", ids[i]);
        if (!uq.exec()) {
            qCWarning(lcDb) << "ibnFeldVorlageUmordnen UPDATE:" << uq.lastError().text();
            return false;
        }
    }
    return true;
}

bool Database::ibnFeldVorlageAktualisieren(int id,
                                             const QString &label,
                                             const QString &feldtyp,
                                             const QString &optionen,
                                             const QString &einheit,
                                             bool pflichtfeld)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE ibn_feldvorlage
        SET label = :lbl, feldtyp = :typ, optionen = :opt,
            einheit = :ein, pflichtfeld = :pfl
        WHERE id = :id AND erstellt_von = 'user'
    )");
    q.bindValue(":id",  id);
    q.bindValue(":lbl", label);
    q.bindValue(":typ", feldtyp);
    q.bindValue(":opt", optionen);
    q.bindValue(":ein", einheit);
    q.bindValue(":pfl", pflichtfeld ? 1 : 0);
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnFeldVorlageAktualisieren:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVariantList Database::ibnFeldwerteLaden(int inbetriebnahmeId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT feldname, wert FROM ibn_feldwert
        WHERE inbetriebnahme_id = :id
    )");
    q.bindValue(":id", inbetriebnahmeId);
    QVariantList result;
    if (!q.exec()) {
        qCWarning(lcDb) << "ibnFeldwerteLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "feldname", q.value("feldname") },
            { "wert",     q.value("wert")     },
        });
    }
    return result;
}

bool Database::ibnFeldwerteAktualisieren(int inbetriebnahmeId, const QVariantList &felder)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO ibn_feldwert (inbetriebnahme_id, feldname, wert)
        VALUES (:id, :fn, :wert)
        ON CONFLICT(inbetriebnahme_id, feldname) DO UPDATE SET wert = :wert
    )");
    for (const auto &f : felder) {
        QVariantMap m = f.toMap();
        q.bindValue(":id",   inbetriebnahmeId);
        q.bindValue(":fn",   m.value("feldname").toString());
        q.bindValue(":wert", m.value("wert").toString());
        if (!q.exec()) {
            qCWarning(lcDb) << "ibnFeldwerteAktualisieren:" << q.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// ibnProtokollPdfSpeichern
// ============================================================
bool Database::ibnProtokollPdfSpeichern(int projektId, int seiteId,
                                         const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    // ── Projektmeta laden ─────────────────────────────────
    QString projektName, projektnummer, auftraggeber, auftragnehmer, bearbeiter;
    {
        QSqlQuery qp;
        qp.prepare("SELECT name, projektnummer, auftraggeber, auftragnehmer, bearbeiter "
                   "FROM projekt WHERE id = :id");
        qp.bindValue(":id", projektId);
        if (qp.exec() && qp.next()) {
            projektName   = qp.value("name").toString();
            projektnummer = qp.value("projektnummer").toString();
            auftraggeber  = qp.value("auftraggeber").toString();
            auftragnehmer = qp.value("auftragnehmer").toString();
            bearbeiter    = qp.value("bearbeiter").toString();
        }
    }

    // ── IBN-Liste laden ───────────────────────────────────
    const QVariantList liste = ibnListeLaden(projektId, seiteId);

    int anzGesamt      = liste.size();
    int anzAbgeschlossen = 0, anzInArbeit = 0, anzOffen = 0;
    for (const QVariant &v : liste) {
        const QString st = v.toMap().value("status").toString();
        if (st == QLatin1String("abgeschlossen")) ++anzAbgeschlossen;
        else if (st == QLatin1String("in_arbeit")) ++anzInArbeit;
        else ++anzOffen;
    }

    // ── HTML aufbauen ─────────────────────────────────────
    auto esc = [](const QString &s) -> QString {
        QString r = s;
        r.replace(u'&', QLatin1String("&amp;"));
        r.replace(u'<', QLatin1String("&lt;"));
        r.replace(u'>', QLatin1String("&gt;"));
        return r;
    };

    auto statusLabel = [](const QString &st) -> QString {
        if (st == QLatin1String("abgeschlossen")) return QStringLiteral("✓ Fertig");
        if (st == QLatin1String("in_arbeit"))     return QStringLiteral("In Arbeit");
        return QStringLiteral("Offen");
    };
    auto statusColor = [](const QString &st) -> QString {
        if (st == QLatin1String("abgeschlossen")) return QStringLiteral("#2a8a4a");
        if (st == QLatin1String("in_arbeit"))     return QStringLiteral("#b08000");
        return QStringLiteral("#666688");
    };

    QString html;
    html.reserve(64 * 1024);
    html += QStringLiteral(R"(<!DOCTYPE html><html><head><meta charset="utf-8">
<style>
  body   { font-family: Arial, Helvetica, sans-serif; font-size: 9pt; color: #222; margin: 0; }
  h1     { font-size: 13pt; color: #1a3560; margin: 0 0 6px 0; }
  .subtitle { font-size: 9pt; color: #555; margin-bottom: 10px; }
  table.meta { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
  table.meta td { padding: 2px 6px; font-size: 8.5pt; }
  table.meta td.lbl { color: #777; width: 130px; }
  .summary { background: #eef2f7; padding: 6px 10px; margin-bottom: 12px;
             font-size: 8.5pt; border-left: 3px solid #1a3560; }
  .bm { border: 1px solid #ccc; padding: 6px 8px; margin-bottom: 6px;
        page-break-inside: avoid; }
  .bm-head { font-size: 10pt; font-weight: bold; }
  .bm-sub  { font-size: 8pt; color: #666; margin: 1px 0 4px 0; }
  table.felder { width: 100%; border-collapse: collapse; margin-top: 3px; }
  table.felder td { padding: 2px 6px; font-size: 8.5pt; vertical-align: top; }
  table.felder td.lbl { color: #666; width: 42%; }
  table.felder tr:nth-child(even) { background: #f7f7f7; }
  .notiz { font-style: italic; color: #555; margin-top: 3px; font-size: 8.5pt; }
  hr  { border: none; border-top: 1px solid #bbb; margin: 14px 0; }
  .sig { margin-top: 30px; }
  .sig table { width: 100%; border-collapse: collapse; }
  .sig td { width: 33%; padding: 4px 8px; border-top: 1px solid #888;
             font-size: 8pt; color: #555; }
</style></head><body>)");

    // Kopfzeile
    html += QStringLiteral("<h1>Prüfprotokoll IBN</h1>");
    html += QStringLiteral("<div class='subtitle'>Erstellt: ")
          + esc(QDateTime::currentDateTime().toString(QStringLiteral("dd.MM.yyyy  hh:mm")))
          + QStringLiteral("</div>");

    // Projektmeta
    html += QStringLiteral("<table class='meta'>");
    auto metaRow = [&](const QString &lbl, const QString &val) {
        if (val.isEmpty()) return;
        html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
              + QStringLiteral("</td><td>") + esc(val) + QStringLiteral("</td></tr>");
    };
    metaRow(QStringLiteral("Projekt"),        projektName);
    metaRow(QStringLiteral("Projektnummer"),  projektnummer);
    metaRow(QStringLiteral("Auftraggeber"),   auftraggeber);
    metaRow(QStringLiteral("Auftragnehmer"),  auftragnehmer);
    metaRow(QStringLiteral("Bearbeiter"),     bearbeiter);
    html += QStringLiteral("</table>");

    // Zusammenfassung
    html += QStringLiteral("<div class='summary'>")
          + QString::number(anzGesamt) + QStringLiteral(" Betriebsmittel gesamt  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#2a8a4a'>") + QString::number(anzAbgeschlossen)
          + QStringLiteral(" Fertig</span>  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#b08000'>") + QString::number(anzInArbeit)
          + QStringLiteral(" In Arbeit</span>  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#666688'>") + QString::number(anzOffen)
          + QStringLiteral(" Offen</span>")
          + QStringLiteral("</div>");

    html += QStringLiteral("<hr>");

    // ── BM-Blöcke ─────────────────────────────────────────
    QString lastBlatt;
    for (const QVariant &v : liste) {
        const QVariantMap e   = v.toMap();
        const QString bmk     = e.value("bmk").toString();
        const QString blatt   = e.value("blattnummer").toString();
        const QString seitenBez = e.value("seitenbezeichnung").toString();
        const QString status  = e.value("status").toString();
        const QString notiz   = e.value("notiz").toString();
        const QString bauteilId = e.value("bauteilId").toString();
        const QString geprueftVon = e.value("geprueftVon").toString();
        const QString geprueftAm  = e.value("geprueftAm").toString();
        const QString kat     = e.value("symbolKategorie").toString();
        const int ibnId       = e.value("ibnId").toInt();

        // Seiten-Trennzeile
        if (blatt != lastBlatt) {
            if (!lastBlatt.isEmpty()) html += QStringLiteral("<br>");
            html += QStringLiteral("<div style='font-size:8pt;color:#999;margin-bottom:4px;'>")
                  + QStringLiteral("Blatt ") + esc(blatt);
            if (!seitenBez.isEmpty())
                html += QStringLiteral(" – ") + esc(seitenBez);
            html += QStringLiteral("</div>");
            lastBlatt = blatt;
        }

        html += QStringLiteral("<div class='bm'>");
        html += QStringLiteral("<div class='bm-head'><span style='color:#1a3560'>")
              + esc(bmk) + QStringLiteral("</span>")
              + QStringLiteral("  <span style='color:") + statusColor(status)
              + QStringLiteral(";font-size:9pt'>") + esc(statusLabel(status))
              + QStringLiteral("</span></div>");

        // Blattnummer + Kategorie als Sub-Info
        QString subInfo = QStringLiteral("Blatt ") + esc(blatt);
        if (!kat.isEmpty()) subInfo += QStringLiteral("  ·  ") + esc(kat);
        html += QStringLiteral("<div class='bm-sub'>") + subInfo + QStringLiteral("</div>");

        // Feldwerte-Tabelle
        html += QStringLiteral("<table class='felder'>");

        // Feste Felder (Bauteil-ID, Geprüft von/am)
        auto fRow = [&](const QString &lbl, const QString &val) {
            if (val.isEmpty()) return;
            html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
                  + QStringLiteral("</td><td>") + esc(val) + QStringLiteral("</td></tr>");
        };
        fRow(QStringLiteral("Seriennummer / Bauteil-ID"), bauteilId);
        fRow(QStringLiteral("Geprüft von"),  geprueftVon);
        fRow(QStringLiteral("Datum"),        geprueftAm);

        // Dynamische Felder
        if (!kat.isEmpty() && ibnId > 0) {
            const QVariantList vorlagen = ibnFeldvorlagenLaden(kat);
            const QVariantList werteListe = ibnFeldwerteLaden(ibnId);

            // Werte-Map aufbauen
            QMap<QString, QString> werteMap;
            for (const QVariant &wv : werteListe) {
                const QVariantMap wm = wv.toMap();
                werteMap.insert(wm.value("feldname").toString(),
                                wm.value("wert").toString());
            }

            for (const QVariant &fv : vorlagen) {
                const QVariantMap fm = fv.toMap();
                const QString feldname = fm.value("feldname").toString();
                const QString lbl      = fm.value("label").toString();
                const QString typ      = fm.value("feldtyp").toString();
                QString wert = werteMap.value(feldname);

                if (typ == QLatin1String("boolean"))
                    wert = (wert == QLatin1String("1")) ? QStringLiteral("Ja") : QStringLiteral("Nein");
                if (wert.isEmpty()) wert = QStringLiteral("–");

                html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
                      + QStringLiteral("</td><td>") + esc(wert) + QStringLiteral("</td></tr>");
            }
        }

        html += QStringLiteral("</table>");

        if (!notiz.isEmpty())
            html += QStringLiteral("<div class='notiz'>Notiz: ") + esc(notiz)
                  + QStringLiteral("</div>");

        html += QStringLiteral("</div>"); // .bm
    }

    // ── Unterschriftsfeld ─────────────────────────────────
    html += QStringLiteral("<div class='sig'>");
    html += QStringLiteral("<table><tr>"
            "<td>Erstellt von</td>"
            "<td>Geprüft von</td>"
            "<td>Datum / Unterschrift</td>"
            "</tr></table>");
    html += QStringLiteral("</div>");

    html += QStringLiteral("</body></html>");

    // ── In PDF rendern ────────────────────────────────────
    QPrinter printer(QPrinter::HighResolution);
    printer.setOutputFormat(QPrinter::PdfFormat);
    printer.setOutputFileName(localPath);
    printer.setPageSize(QPageSize(QPageSize::A4));
    printer.setPageOrientation(QPageLayout::Portrait);
    printer.setPageMargins(QMarginsF(20, 15, 15, 15), QPageLayout::Millimeter);

    QTextDocument doc;
    doc.setHtml(html);
    doc.print(&printer);

    return QFile::exists(localPath);
}

// ============================================================
// Wiki – Kategorien
// ============================================================
