#include "Database.h"
#include "Database_CsvHelfer.h"
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

QVariantList Database::alleSeitenFlach(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT s.id, s.blattnummer, COALESCE(s.bezeichnung, '')
        FROM seite s
        JOIN ort     o ON o.id  = s.ort_id
        JOIN anlage  a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
        ORDER BY s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "alleSeitenFlach:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap s;
        s[QStringLiteral("id")]          = q.value(0).toInt();
        s[QStringLiteral("blattnummer")] = q.value(1).toString();
        s[QStringLiteral("bezeichnung")] = q.value(2).toString();
        result.append(s);
    }
    return result;
}

// ============================================================
// spotlightEintraege
// BMKs + platzierte Kabel für die Kommando-Palette.
// Gibt [{kategorie, label, info, seiteId, blattnummer, seiteBez, cx, cy}] zurück.
// ============================================================
QVariantList Database::spotlightEintraege(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT 'BMK'   AS kategorie,
               json_extract(ge.extra_daten, '$.bmk') AS label,
               s.blattnummer AS info,
               ge.seite_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
               (ge.x1 + ge.x2) / 2.0     AS cx,
               (ge.y1 + ge.y2) / 2.0     AS cy,
               ge.id                       AS element_id
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id IS NOT NULL
          AND json_extract(ge.extra_daten, '$.bmk') IS NOT NULL
          AND json_extract(ge.extra_daten, '$.bmk') != ''

        UNION ALL

        SELECT 'Kabel' AS kategorie,
               k.bezeichnung             AS label,
               s.blattnummer             AS info,
               ge.seite_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
               (ge.x1 + ge.x2) / 2.0     AS cx,
               (ge.y1 + ge.y2) / 2.0     AS cy,
               ge.id                       AS element_id
        FROM kabel k
        JOIN grafik_element ge ON ge.id = k.grafik_element_id
        JOIN seite  s ON s.id  = ge.seite_id
        WHERE k.projekt_id = :pid
          AND k.bezeichnung != ''

        ORDER BY label
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "spotlightEintraege:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("kategorie")]   = q.value(0).toString();
        m[QStringLiteral("label")]       = q.value(1).toString();
        m[QStringLiteral("info")]        = q.value(2).toString();
        m[QStringLiteral("seiteId")]     = q.value(3).toInt();
        m[QStringLiteral("blattnummer")] = q.value(4).toString();
        m[QStringLiteral("seiteBez")]    = q.value(5).toString();
        m[QStringLiteral("cx")]          = q.value(6).toDouble();
        m[QStringLiteral("cy")]          = q.value(7).toDouble();
        m[QStringLiteral("elementId")]   = q.value(8).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// querverweiseLadenProjekt
// Alle Querverweis-Elemente eines Projekts seitenübergreifend.
// Gibt [{seiteId, blattnummer, seitenBezeichnung,
//        signalname, richtung, suchmodus, x1, y1,
//        anlageKuerzel, ortKuerzel}] zurück.
// ============================================================
QVariantList Database::querverweiseLadenProjekt(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.seite_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS s_bez,
               ge.extra_daten,
               ge.x1, ge.y1,
               COALESCE(a.kuerzel, '') AS anlage_kuerzel,
               COALESCE(o.kuerzel, '') AS ort_kuerzel
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id  = 'querverweis'
        ORDER BY s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "querverweiseLadenProjekt:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seiteId")]           = q.value(0).toInt();
        m[QStringLiteral("blattnummer")]        = q.value(1).toString();
        m[QStringLiteral("seitenBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("x1")]                 = q.value(4).toDouble();
        m[QStringLiteral("y1")]                 = q.value(5).toDouble();
        m[QStringLiteral("anlageKuerzel")]       = q.value(6).toString();
        m[QStringLiteral("ortKuerzel")]          = q.value(7).toString();

        QString signalname, richtung, suchmodus;
        QString extraStr = q.value(3).toString();
        if (!extraStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname = obj[QStringLiteral("signalname")].toString();
                richtung   = obj[QStringLiteral("richtung")].toString();
                suchmodus  = obj[QStringLiteral("suchmodus")].toString();
            }
        }
        if (richtung.isEmpty())  richtung  = QStringLiteral("ausgang");
        if (suchmodus.isEmpty()) suchmodus = QStringLiteral("signal");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;
        // KLEMME-KONFLIKT-01-Folgefix (Querverweis-Cross-Page-Teil): suchmodus
        // wird gebraucht, damit der Cross-Page-Signaltyp-Import "bmk"-Modus-
        // Querverweise nicht fälschlich per reinem Signalnamen mit
        // "signal"-Modus-Querverweisen zusammenführt (unterschiedlicher
        // Paarungs-Schlüssel, s. SymbolDefinitionModel.cpp §4).
        m[QStringLiteral("suchmodus")]  = suchmodus;

        result.append(m);
    }
    return result;
}

// ============================================================
// stueckliste
// Alle platzierten Symbole (ohne Verbindungshelfer) mit BMK,
// Freitexten und Seiteninfo für ein Projekt.
// ============================================================
namespace {

// STUECKLISTE-SUBQUERY-01: Ersetzt die pro-Zeile korrelierte Strukturkasten-
// Subquery (kein Index auf die Bounding-Box-Spalten, daher Faktor ~700
// langsamer bei 7200 Elementen, real gemessen bei RESSOURCEN-MESSUNG-01)
// durch eine einmalige Vorabladung aller Strukturkästen des Projekts,
// gruppiert nach Seite. Der Punkt-in-Box-Test läuft danach in C++ nur noch
// gegen die (typischerweise wenigen) Kästen der jeweiligen Seite statt
// gegen die gesamte grafik_element-Tabelle pro Zeile.
struct StrukturkastenBox {
    double x1, y1, x2, y2, flaeche;
    QString extraDaten;
};

QHash<int, QVector<StrukturkastenBox>> strukturkaestenNachSeiteLaden(QSqlDatabase &db, int projektId)
{
    QHash<int, QVector<StrukturkastenBox>> result;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT sk.seite_id, sk.x1, sk.y1, sk.x2, sk.y2, sk.extra_daten
        FROM grafik_element sk
        JOIN seite  s ON s.id = sk.seite_id
        JOIN ort    o ON o.id = s.ort_id
        JOIN anlage a ON a.id = o.anlage_id
        WHERE a.projekt_id = :pid AND sk.typ = 'strukturkasten'
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        StrukturkastenBox b;
        int seiteId = q.value(0).toInt();
        b.x1 = q.value(1).toDouble();
        b.y1 = q.value(2).toDouble();
        b.x2 = q.value(3).toDouble();
        b.y2 = q.value(4).toDouble();
        b.flaeche = (b.x2 - b.x1) * (b.y2 - b.y1);
        b.extraDaten = q.value(5).toString();
        result[seiteId].append(b);
    }
    return result;
}

// Kleinster (flächenmäßig engster) Strukturkasten der Seite, der (x, y)
// enthält – gleiche Priorität wie das bisherige SQL ORDER BY … LIMIT 1.
QString strukturkastenExtraFuerPunkt(const QHash<int, QVector<StrukturkastenBox>> &boxen,
                                      int seiteId, double x, double y)
{
    auto it = boxen.constFind(seiteId);
    if (it == boxen.constEnd()) return QString();
    const StrukturkastenBox *best = nullptr;
    for (const StrukturkastenBox &b : it.value()) {
        if (x < b.x1 || x > b.x2 || y < b.y1 || y > b.y2) continue;
        if (!best || b.flaeche < best->flaeche) best = &b;
    }
    return best ? best->extraDaten : QString();
}

} // namespace

QVariantList Database::stueckliste(int projektId)
{
    QVariantList result;
    const QHash<int, QVector<StrukturkastenBox>> strukturkaesten =
        strukturkaestenNachSeiteLaden(m_db, projektId);

    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.extra_daten, ge.symbol_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
               a.kuerzel AS anlage_kz,
               o.kuerzel AS ort_kz,
               COALESCE(a.anlage_uebergeordnet, '')   AS anlage_uo,
               COALESCE(o.standort_uebergeordnet, '') AS ort_uo,
               s.id AS seite_id,
               (ge.x1 + ge.x2) / 2.0 AS welt_x,
               (ge.y1 + ge.y2) / 2.0 AS welt_y
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'symbol'
          AND ge.symbol_id NOT IN (
              'winkel','treffpunkt','geraeteanschluss','unterbrechung',
              'querverweis','aderdefinition','potenzial')
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "stueckliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("symbolId")]  = q.value(1).toString();
        m[QStringLiteral("seite")]     = q.value(2).toString();
        m[QStringLiteral("seiteBez")]  = q.value(3).toString();
        m[QStringLiteral("anlageKz")]  = q.value(4).toString();
        m[QStringLiteral("ortKz")]     = q.value(5).toString();
        const int    seiteId = q.value(8).toInt();
        const double weltX   = q.value(9).toDouble();
        const double weltY   = q.value(10).toDouble();
        m[QStringLiteral("seiteId")]   = seiteId;
        m[QStringLiteral("weltX")]     = weltX;
        m[QStringLiteral("weltY")]     = weltY;

        QString extra = q.value(0).toString();
        QString bmk, ft1, ft2;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bmk = obj[QStringLiteral("bmk")].toString();
                ft1 = obj[QStringLiteral("freitext1")].toString();
                ft2 = obj[QStringLiteral("freitext2")].toString();
            }
        }
        m[QStringLiteral("bmk")]       = bmk;
        m[QStringLiteral("freitext1")] = ft1;
        m[QStringLiteral("freitext2")] = ft2;

        QString anlageKz = m[QStringLiteral("anlageKz")].toString();
        QString ortKz    = m[QStringLiteral("ortKz")].toString();
        QString anlageUO = q.value(6).toString();
        QString ortUO    = q.value(7).toString();
        QString skExtra  = strukturkastenExtraFuerPunkt(strukturkaesten, seiteId, weltX, weltY);
        strukturkastenOverrideAnwenden(skExtra, anlageKz, ortKz, anlageUO, ortUO);
        m[QStringLiteral("anlageKz")] = anlageKz;
        m[QStringLiteral("ortKz")]    = ortKz;
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        m[QStringLiteral("typ")]      = QStringLiteral("symbol");
        result.append(m);
    }

    // Gerätekästen mit verknüpftem Bauteil als eigene Zeilen anhängen.
    QSqlQuery qGk(m_db);
    qGk.prepare(R"(
        SELECT COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
               COALESCE(b.bezeichnung, ''),
               COALESCE(b.hersteller, ''),
               COALESCE(b.artikelnummer, ''),
               s.blattnummer,
               COALESCE(s.bezeichnung, ''),
               a.kuerzel,
               o.kuerzel,
               COALESCE(a.anlage_uebergeordnet, ''),
               COALESCE(o.standort_uebergeordnet, ''),
               s.id AS seite_id,
               (ge.x1 + ge.x2) / 2.0 AS welt_x,
               (ge.y1 + ge.y2) / 2.0 AS welt_y
        FROM grafik_element ge
        JOIN seite  s ON s.id = ge.seite_id
        JOIN ort    o ON o.id = s.ort_id
        JOIN anlage a ON a.id = o.anlage_id
        JOIN bibliothek.bauteil b ON b.id = CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER)
        WHERE a.projekt_id = :pid
          AND ge.typ = 'geraetekasten'
          AND CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER) > 0
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    qGk.bindValue(":pid", projektId);
    if (!qGk.exec()) {
        qCWarning(lcDb) << "stueckliste GK:" << qGk.lastError().text();
    } else {
        while (qGk.next()) {
            QVariantMap m;
            m[QStringLiteral("typ")]      = QStringLiteral("geraetekasten");
            m[QStringLiteral("bmk")]      = qGk.value(0).toString();
            m[QStringLiteral("symbolId")] = QStringLiteral("Gerätekasten");
            m[QStringLiteral("freitext1")]= qGk.value(1).toString();
            QString hersteller  = qGk.value(2).toString();
            QString artikelnr   = qGk.value(3).toString();
            m[QStringLiteral("freitext2")]= artikelnr.isEmpty() ? hersteller
                                            : (hersteller.isEmpty() ? artikelnr
                                               : hersteller + u' ' + artikelnr);
            m[QStringLiteral("seite")]    = qGk.value(4).toString();
            m[QStringLiteral("seiteBez")] = qGk.value(5).toString();
            m[QStringLiteral("anlageKz")] = qGk.value(6).toString();
            m[QStringLiteral("ortKz")]    = qGk.value(7).toString();

            QString anlageKz2 = m[QStringLiteral("anlageKz")].toString();
            QString ortKz2    = m[QStringLiteral("ortKz")].toString();
            QString anlageUO2 = qGk.value(8).toString();
            QString ortUO2    = qGk.value(9).toString();
            const int    seiteId2 = qGk.value(10).toInt();
            const double weltX2   = qGk.value(11).toDouble();
            const double weltY2   = qGk.value(12).toDouble();
            QString skExtra2 = strukturkastenExtraFuerPunkt(strukturkaesten, seiteId2, weltX2, weltY2);
            strukturkastenOverrideAnwenden(skExtra2, anlageKz2, ortKz2, anlageUO2, ortUO2);
            m[QStringLiteral("anlageKz")] = anlageKz2;
            m[QStringLiteral("ortKz")]    = ortKz2;
            m[QStringLiteral("anlageUO")] = anlageUO2;
            m[QStringLiteral("ortUO")]    = ortUO2;
            m[QStringLiteral("seiteId")]  = seiteId2;
            m[QStringLiteral("weltX")]    = weltX2;
            m[QStringLiteral("weltY")]    = weltY2;
            result.append(m);
        }
    }

    return result;
}

// ============================================================
// querverweisListe
// Alle Querverweis-Symbole eines Projekts mit Signalname,
// Richtung, eigener Seite und Zielseite.
// ============================================================
QVariantList Database::querverweisListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.extra_daten,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
               ge.seite_id,
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id = 'querverweis'
        ORDER BY s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "querverweisListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seite")]    = q.value(1).toString();
        m[QStringLiteral("seiteBez")] = q.value(2).toString();
        m[QStringLiteral("seiteId")]  = q.value(3).toInt();
        m[QStringLiteral("weltX")]    = q.value(4).toDouble();
        m[QStringLiteral("weltY")]    = q.value(5).toDouble();

        QString signalname, richtung;
        int     zielSeiteId = -1;
        QString extra = q.value(0).toString();
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname  = obj[QStringLiteral("signalname")].toString();
                richtung    = obj[QStringLiteral("richtung")].toString();
                zielSeiteId = obj[QStringLiteral("zielSeiteId")].toInt(-1);
            }
        }
        if (richtung.isEmpty()) richtung = QStringLiteral("ausgang");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;

        QString zielBlatt;
        if (zielSeiteId > 0) {
            QSqlQuery qs;
            qs.prepare("SELECT blattnummer FROM seite WHERE id = :id");
            qs.bindValue(":id", zielSeiteId);
            if (qs.exec() && qs.next())
                zielBlatt = qs.value(0).toString();
        }
        m[QStringLiteral("zielSeite")] = zielBlatt;
        result.append(m);
    }
    return result;
}

// ============================================================
// aderliste
// Alle Aderdefinitionspunkte eines Projekts mit Aderfarbe,
// Querschnitt, Länge, Bezeichnung und Seiteninfo.
// ============================================================
QVariantList Database::aderliste(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.extra_daten,
               s.blattnummer,
               a.kuerzel AS anlage_kz,
               o.kuerzel AS ort_kz,
               COALESCE(a.anlage_uebergeordnet, '')   AS anlage_uo,
               COALESCE(o.standort_uebergeordnet, '') AS ort_uo,
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra,
               ge.seite_id,
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ       = 'symbol'
          AND ge.symbol_id = 'aderdefinition'
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "aderliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seite")]    = q.value(1).toString();
        m[QStringLiteral("anlageKz")] = q.value(2).toString();
        m[QStringLiteral("ortKz")]    = q.value(3).toString();

        QString extra = q.value(0).toString();
        QString bezeichnung, aderfarbe, aderfarbe2;
        double  querschnitt = 0.0, laenge = 0.0;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bezeichnung = obj[QStringLiteral("bezeichnung")].toString();
                aderfarbe   = obj[QStringLiteral("aderfarbe")].toString();
                aderfarbe2  = obj[QStringLiteral("aderfarbe2")].toString();
                querschnitt = obj[QStringLiteral("querschnitt_mm2")].toDouble(0.0);
                laenge      = obj[QStringLiteral("laenge_m")].toDouble(0.0);
            }
        }
        m[QStringLiteral("bezeichnung")]    = bezeichnung;
        m[QStringLiteral("aderfarbe")]      = aderfarbe;
        m[QStringLiteral("aderfarbe2")]     = aderfarbe2;
        m[QStringLiteral("querschnittMm2")] = querschnitt;
        m[QStringLiteral("laengeM")]        = laenge;

        QString anlageKz = m[QStringLiteral("anlageKz")].toString();
        QString ortKz    = m[QStringLiteral("ortKz")].toString();
        QString anlageUO = q.value(4).toString();
        QString ortUO    = q.value(5).toString();
        strukturkastenOverrideAnwenden(q.value(6).toString(), anlageKz, ortKz, anlageUO, ortUO);
        m[QStringLiteral("anlageKz")] = anlageKz;
        m[QStringLiteral("ortKz")]    = ortKz;
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        m[QStringLiteral("seiteId")]  = q.value(7).toInt();
        m[QStringLiteral("weltX")]    = q.value(8).toDouble();
        m[QStringLiteral("weltY")]    = q.value(9).toDouble();
        result.append(m);
    }
    return result;
}

// ============================================================
// strukturkastenOverrideAnwenden
// ============================================================
void Database::strukturkastenOverrideAnwenden(const QString &skExtraDaten,
                                                QString &anlageKz, QString &ortKz,
                                                QString &anlageUO, QString &ortUO)
{
    // anlageUO/ortUO kommen als Eingabe bereits mit dem projektweiten Default aus
    // anlage.anlage_uebergeordnet/ort.standort_uebergeordnet (NKZ-02b) – Strukturkasten
    // überschreibt nur, wenn er selbst einen Wert gesetzt hat.
    if (skExtraDaten.isEmpty()) return;
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(skExtraDaten.toUtf8(), &err);
    if (err.error || !doc.isObject()) return;
    QJsonObject obj = doc.object();
    QString skAnlageUO = obj[QStringLiteral("anlageUO")].toString();
    QString skOrtUO    = obj[QStringLiteral("ortUO")].toString();
    QString skAnlage   = obj[QStringLiteral("anlage")].toString();
    QString skOrt      = obj[QStringLiteral("ort")].toString();
    if (!skAnlageUO.isEmpty()) anlageUO = skAnlageUO;
    if (!skOrtUO.isEmpty())    ortUO    = skOrtUO;
    if (!skAnlage.isEmpty())   anlageKz = skAnlage;
    if (!skOrt.isEmpty())      ortKz    = skOrt;
}

// ============================================================
// Betriebsmittel-Verknüpfung
// ============================================================

QVariantList Database::bauteilKontaktListe(int bauteilId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, symbol_id, bezeichnung, pin_bez "
              "FROM bibliothek.bauteil_kontakt WHERE bauteil_id = :bid "
              "ORDER BY symbol_id, bezeichnung");
    q.bindValue(":bid", bauteilId);
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilKontaktListe Fehler:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]          = q.value(0).toInt();
        m[QStringLiteral("symbolId")]    = q.value(1).toString();
        m[QStringLiteral("bezeichnung")] = q.value(2).toString();
        m[QStringLiteral("pinBez")]      = q.value(3).toString();
        result.append(m);
    }
    return result;
}

int Database::bauteilKontaktHinzufuegen(int bauteilId, const QString &symbolId,
                                          const QString &bezeichnung, const QString &pinBez)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO bibliothek.bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez) "
              "VALUES (:bid, :sid, :bez, :pb)");
    q.bindValue(":bid", bauteilId);
    q.bindValue(":sid", symbolId);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":pb",  pinBez.isEmpty() ? QStringLiteral("{}") : pinBez);
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilKontaktHinzufuegen Fehler:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::bauteilKontaktAktualisieren(int id, const QString &symbolId,
                                             const QString &bezeichnung, const QString &pinBez)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE bibliothek.bauteil_kontakt SET symbol_id=:sid, bezeichnung=:bez, pin_bez=:pb WHERE id=:id");
    q.bindValue(":sid", symbolId);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":pb",  pinBez.isEmpty() ? QStringLiteral("{}") : pinBez);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilKontaktAktualisieren Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::bauteilKontaktLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM bibliothek.bauteil_kontakt WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilKontaktLoeschen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::betriebsmittelHfListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT b.id, b.haupt_element_id, s.blattnummer, g.seite_id "
        "FROM betriebsmittel b "
        "JOIN grafik_element g ON g.id = b.haupt_element_id "
        "JOIN seite s ON s.id = g.seite_id "
        "WHERE b.projekt_id = :pid "
        "  AND b.haupt_element_id IS NOT NULL");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("betriebsmittelId")] = q.value(0).toInt();
        m[QStringLiteral("hauptElementId")]   = q.value(1).toInt();
        m[QStringLiteral("blattnummer")]      = q.value(2).toString();
        m[QStringLiteral("seiteId")]          = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// klemmenplan
// ============================================================
QVariantList Database::klemmenplan(int projektId)
{
    QVariantList result;

    // klemmeId → {seiteId, blattnr, weltX, weltY} (erste Platzierung je Klemme)
    QHash<int, QVariantMap> klemmePos;
    {
        const QString sql = QString(
            "SELECT CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER),"
            "       ge.seite_id, COALESCE(s.blattnummer,''),"
            "       (ge.x1 + ge.x2) / 2.0, (ge.y1 + ge.y2) / 2.0"
            " FROM grafik_element ge"
            " JOIN seite s ON s.id = ge.seite_id"
            " WHERE ge.symbol_id = 'klemme_anschluss'"
            "   AND ge.seite_id IN (SELECT s2.id FROM seite s2"
            "     JOIN ort o ON o.id = s2.ort_id"
            "     JOIN anlage a ON a.id = o.anlage_id"
            "     WHERE a.projekt_id = %1)"
            "   AND CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER) > 0"
        ).arg(projektId);
        QSqlQuery qp(m_db);
        if (qp.exec(sql)) {
            while (qp.next()) {
                int kid = qp.value(0).toInt();
                if (!klemmePos.contains(kid)) {
                    QVariantMap pm;
                    pm[QStringLiteral("seiteId")] = qp.value(1).toInt();
                    pm[QStringLiteral("blattnr")] = qp.value(2).toString();
                    pm[QStringLiteral("weltX")]   = qp.value(3).toDouble();
                    pm[QStringLiteral("weltY")]   = qp.value(4).toDouble();
                    klemmePos[kid] = pm;
                }
            }
        }
    }

    QSqlQuery q(m_db);
    q.prepare(
        "SELECT kl.id, kl.bezeichnung, "
        "COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung), "
        "k.id, k.nummer, k.sortierung, "
        "COALESCE(b.bezeichnung,''), "
        "COALESCE(bk.anschluss_typ,''), "
        "COALESCE(fd.bezeichnung,''), "
        "COALESCE(fd.hex_wert,''), "
        "COALESCE(o.kuerzel,''), "
        "(SELECT MIN(bkq.min_mm2) || '\xe2\x80\x93' || MAX(bkq.max_mm2) || ' mm\xc2\xb2' "
        "   FROM bibliothek.bauteil_klemme_querschnitt bkq WHERE bkq.klemme_id = bk.id), "
        "(SELECT ks.potenzial_text FROM klemme_stegbruecke ks "
        " WHERE ks.klemmenleiste_id = kl.id "
        " AND (ks.von_klemme_id = k.id OR ks.bis_klemme_id = k.id) "
        " AND ks.potenzial_text IS NOT NULL LIMIT 1) "
        "FROM klemmenleiste kl "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "LEFT JOIN ort o ON o.id = kl.ort_id "
        "JOIN klemme k ON k.klemmenleiste_id = kl.id "
        "LEFT JOIN bibliothek.bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bibliothek.bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN bibliothek.farb_definition fd ON fd.id = bk.gehaeuse_farbe_id "
        "WHERE kl.projekt_id = :pid "
        "ORDER BY kl.bezeichnung, k.sortierung, k.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "Database::klemmenplan:" << q.lastError().text();
        return result;
    }

    int lastLeistenId = -1;
    while (q.next()) {
        int leisteId = q.value(0).toInt();

        if (leisteId != lastLeistenId) {
            QVariantMap row;
            row[QStringLiteral("typ")]         = QStringLiteral("leiste");
            row[QStringLiteral("leisteId")]    = leisteId;
            row[QStringLiteral("bezeichnung")] = q.value(1).toString();
            row[QStringLiteral("bmk")]         = q.value(2).toString();
            result.append(row);
            lastLeistenId = leisteId;
        }

        QString typ = q.value(7).toString();
        if      (typ == QLatin1String("schraube"))      typ = QStringLiteral("Schraubanschluss");
        else if (typ == QLatin1String("feder"))         typ = QStringLiteral("Federkraft");
        else if (typ == QLatin1String("kaefig"))        typ = QStringLiteral("Käfigzugfeder");
        else if (typ == QLatin1String("push_in"))       typ = QStringLiteral("Steckanschluss");
        else if (typ == QLatin1String("schneidklemme")) typ = QStringLiteral("Schneidklemme");

        const int klemmeId = q.value(3).toInt();
        const QVariantMap &pos = klemmePos.value(klemmeId);
        QVariantMap row;
        row[QStringLiteral("typ")]          = QStringLiteral("klemme");
        row[QStringLiteral("leisteId")]     = leisteId;
        row[QStringLiteral("leisteBmk")]    = q.value(2).toString();
        row[QStringLiteral("nummer")]       = q.value(4).toString();
        row[QStringLiteral("bauteilBez")]   = q.value(6).toString();
        row[QStringLiteral("anschlussTyp")] = typ;
        row[QStringLiteral("farbeBez")]     = q.value(8).toString();
        row[QStringLiteral("farbeHex")]     = q.value(9).toString();
        row[QStringLiteral("ortKz")]        = q.value(10).toString();
        row[QStringLiteral("querschnitt")]  = q.value(11).isNull() ? QString() : q.value(11).toString();
        row[QStringLiteral("potenzial")]    = q.value(12).isNull() ? QString() : q.value(12).toString();
        row[QStringLiteral("seiteId")]      = pos.value(QStringLiteral("seiteId"), 0).toInt();
        row[QStringLiteral("blattnr")]      = pos.value(QStringLiteral("blattnr")).toString();
        row[QStringLiteral("weltX")]        = pos.value(QStringLiteral("weltX"), 0.0).toDouble();
        row[QStringLiteral("weltY")]        = pos.value(QStringLiteral("weltY"), 0.0).toDouble();
        result.append(row);
    }
    return result;
}

// ============================================================
// klemmenplanCsvSpeichern
// ============================================================
bool Database::klemmenplanCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "klemmenplanCsvSpeichern"))
        return false;
    out << "Leiste;Nr.;Bauteil;Typ;Querschnitt;Farbe;Potenzial;Ort\n";

    auto csvQ = CsvHelfer::escapeBedarf;

    for (const QVariant &v : klemmenplan(projektId)) {
        const QVariantMap row = v.toMap();
        if (row[QStringLiteral("typ")] != QLatin1String("klemme")) continue;
        out << csvQ(row[QStringLiteral("leisteBmk")].toString())   << u';'
            << csvQ(row[QStringLiteral("nummer")].toString())       << u';'
            << csvQ(row[QStringLiteral("bauteilBez")].toString())   << u';'
            << csvQ(row[QStringLiteral("anschlussTyp")].toString()) << u';'
            << csvQ(row[QStringLiteral("querschnitt")].toString())  << u';'
            << csvQ(row[QStringLiteral("farbeBez")].toString())     << u';'
            << csvQ(row[QStringLiteral("potenzial")].toString())    << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())        << u'\n';
    }
    return true;
}

// ============================================================
// stuecklisteCsvSpeichern
// ============================================================
bool Database::stuecklisteCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "stuecklisteCsvSpeichern"))
        return false;
    out << "BMK;Typ;Freitext 1;Freitext 2;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = CsvHelfer::escapeBedarf;
    for (const QVariant &v : stueckliste(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("bmk")].toString())       << u';'
            << csvQ(row[QStringLiteral("symbolId")].toString())  << u';'
            << csvQ(row[QStringLiteral("freitext1")].toString()) << u';'
            << csvQ(row[QStringLiteral("freitext2")].toString()) << u';'
            << csvQ(row[QStringLiteral("seite")].toString())     << u';'
            << csvQ(row[QStringLiteral("anlageUO")].toString())  << u';'
            << csvQ(row[QStringLiteral("ortUO")].toString())     << u';'
            << csvQ(row[QStringLiteral("anlageKz")].toString())  << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())     << u'\n';
    }
    return true;
}

// ============================================================
// bestellliste (BESTELLLISTE-01, v1)
// Aggregiert Bauteile über die drei bereits bauteil_id-verknüpften
// Pfade (Klemmen, Kabel, Kontaktspiegel-Geräte). Normale Symbole ohne
// Bauteil-Verknüpfung erscheinen hier bewusst nicht, siehe Roadmap.
// ============================================================
// ============================================================
// bauteilAlleFuerPicker
// Alle Bauteile der Bibliothek für den generischen Symbol-Bauteil-Picker
// (BESTELLLISTE-02, EpBauteilZuordnungSection.qml) – keine Kategorie-
// Einschränkung wie bei den Klemmen-/Kabel-/Steckverbinder-Pickern.
// ============================================================
QVariantList Database::bauteilAlleFuerPicker() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, COALESCE(bezeichnung, ''), COALESCE(hersteller, ''), COALESCE(artikelnummer, '')
        FROM bibliothek.bauteil
        ORDER BY bezeichnung COLLATE NOCASE
    )");
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilAlleFuerPicker:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]            = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")]   = q.value(1).toString();
        m[QStringLiteral("hersteller")]    = q.value(2).toString();
        m[QStringLiteral("artikelnummer")] = q.value(3).toString();
        result.append(m);
    }
    return result;
}

QVariantList Database::bestellliste(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        WITH pos AS (
            SELECT k.bauteil_id AS bauteil_id, 1.0 AS menge, 'Stk' AS einheit
            FROM klemme k
            JOIN klemmenleiste kl ON kl.id = k.klemmenleiste_id
            WHERE kl.projekt_id = :pid1 AND k.bauteil_id IS NOT NULL
            UNION ALL
            SELECT bk.bauteil_id AS bauteil_id, COALESCE(ka.laenge_m, 0) AS menge, 'm' AS einheit
            FROM kabel ka
            JOIN bibliothek.bauteil_kabel bk ON bk.id = ka.bauteil_kabel_id
            WHERE ka.projekt_id = :pid2
            UNION ALL
            SELECT b.bauteil_id AS bauteil_id, 1.0 AS menge, 'Stk' AS einheit
            FROM betriebsmittel b
            WHERE b.projekt_id = :pid3 AND b.bauteil_id IS NOT NULL
            UNION ALL
            -- BESTELLLISTE-02: beliebige platzierte Symbole mit generischer
            -- Bauteil-Zuordnung im EP (extra_daten.bauteil_id). Symbole, die
            -- bereits über ein Kontaktspiegel-Betriebsmittel (s. oben) einen
            -- Bauteil-Bezug haben, sind ausgenommen, sonst Doppelzählung.
            SELECT CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER) AS bauteil_id,
                   1.0 AS menge, 'Stk' AS einheit
            FROM grafik_element ge
            JOIN seite  s ON s.id = ge.seite_id
            JOIN ort    o ON o.id = s.ort_id
            JOIN anlage a ON a.id = o.anlage_id
            WHERE ge.typ = 'symbol' AND a.projekt_id = :pid4
              AND CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER) > 0
              AND NOT EXISTS (
                  SELECT 1 FROM betriebsmittel bm
                  WHERE bm.id = ge.betriebsmittel_id AND bm.bauteil_id IS NOT NULL
              )
        )
        SELECT bt.id, bt.bezeichnung, COALESCE(bt.hersteller, ''), COALESCE(bt.artikelnummer, ''),
               COALESCE(bt.bestellnummer, ''), COALESCE(bt.lieferant, ''), bt.preis_eur,
               SUM(pos.menge), pos.einheit
        FROM pos
        JOIN bibliothek.bauteil bt ON bt.id = pos.bauteil_id
        GROUP BY pos.bauteil_id, pos.einheit
        ORDER BY bt.bezeichnung COLLATE NOCASE
    )");
    q.bindValue(":pid1", projektId);
    q.bindValue(":pid2", projektId);
    q.bindValue(":pid3", projektId);
    q.bindValue(":pid4", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "bestellliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        const double preis = q.value(6).isNull() ? 0.0 : q.value(6).toDouble();
        const double menge = q.value(7).toDouble();
        m[QStringLiteral("bauteilId")]     = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")]   = q.value(1).toString();
        m[QStringLiteral("hersteller")]    = q.value(2).toString();
        m[QStringLiteral("artikelnummer")] = q.value(3).toString();
        m[QStringLiteral("bestellnummer")] = q.value(4).toString();
        m[QStringLiteral("lieferant")]     = q.value(5).toString();
        m[QStringLiteral("preisEur")]      = preis;
        m[QStringLiteral("menge")]         = menge;
        m[QStringLiteral("einheit")]       = q.value(8).toString();
        m[QStringLiteral("summeEur")]      = preis * menge;
        result.append(m);
    }
    return result;
}

// ============================================================
// bestellisteCsvSpeichern
// ============================================================
bool Database::bestellisteCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "bestellisteCsvSpeichern"))
        return false;
    out << "Bezeichnung;Hersteller;Artikelnummer;Bestellnummer;Lieferant;Menge;Einheit;Einzelpreis EUR;Summe EUR\n";
    auto csvQ = CsvHelfer::escapeBedarf;
    for (const QVariant &v : bestellliste(projektId)) {
        const QVariantMap row = v.toMap();
        const double preis = row[QStringLiteral("preisEur")].toDouble();
        const double summe = row[QStringLiteral("summeEur")].toDouble();
        out << csvQ(row[QStringLiteral("bezeichnung")].toString())   << u';'
            << csvQ(row[QStringLiteral("hersteller")].toString())    << u';'
            << csvQ(row[QStringLiteral("artikelnummer")].toString()) << u';'
            << csvQ(row[QStringLiteral("bestellnummer")].toString()) << u';'
            << csvQ(row[QStringLiteral("lieferant")].toString())     << u';'
            << QString::number(row[QStringLiteral("menge")].toDouble(), 'f', 2) << u';'
            << csvQ(row[QStringLiteral("einheit")].toString())       << u';'
            << (preis > 0 ? QString::number(preis, 'f', 2) : QString()) << u';'
            << (summe > 0 ? QString::number(summe, 'f', 2) : QString()) << u'\n';
    }
    return true;
}

// ============================================================
// querverweislisteCsvSpeichern
// ============================================================
bool Database::querverweislisteCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "querverweislisteCsvSpeichern"))
        return false;
    out << "Signalname;Richtung;Seite;Zielseite\n";
    auto csvQ = CsvHelfer::escapeBedarf;
    for (const QVariant &v : querverweisListe(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("signalname")].toString()) << u';'
            << csvQ(row[QStringLiteral("richtung")].toString())   << u';'
            << csvQ(row[QStringLiteral("seite")].toString())      << u';'
            << csvQ(row[QStringLiteral("zielSeite")].toString())  << u'\n';
    }
    return true;
}

// ============================================================
// aderlisteCsvSpeichern
// ============================================================
bool Database::aderlisteCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "aderlisteCsvSpeichern"))
        return false;
    out << "Adernummer;Aderfarbe;Querschnitt mm2;Laenge m;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = CsvHelfer::escapeBedarf;
    for (const QVariant &v : aderliste(projektId)) {
        const QVariantMap row = v.toMap();
        QString af  = row[QStringLiteral("aderfarbe")].toString();
        QString af2 = row[QStringLiteral("aderfarbe2")].toString();
        out << csvQ(row[QStringLiteral("bezeichnung")].toString())                          << u';'
            << csvQ(af2.isEmpty() ? af : af + "/" + af2)                                    << u';'
            << csvQ(row[QStringLiteral("querschnittMm2")].toDouble() > 0
                    ? QString::number(row[QStringLiteral("querschnittMm2")].toDouble()) : QString()) << u';'
            << csvQ(row[QStringLiteral("laengeM")].toDouble() > 0
                    ? QString::number(row[QStringLiteral("laengeM")].toDouble()) : QString())        << u';'
            << csvQ(row[QStringLiteral("seite")].toString())    << u';'
            << csvQ(row[QStringLiteral("anlageUO")].toString()) << u';'
            << csvQ(row[QStringLiteral("ortUO")].toString())    << u';'
            << csvQ(row[QStringLiteral("anlageKz")].toString()) << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())    << u'\n';
    }
    return true;
}

// ============================================================
// kabellisteCsvSpeichern
// ============================================================
bool Database::kabellisteCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "kabellisteCsvSpeichern"))
        return false;
    out << "Kabel-BMK;Kabeltyp;Von-Ort;Nach-Ort;Ader-Nr;Farbe;Bezeichnung;Seite;Netz\n";
    auto csvQ = CsvHelfer::escapeBedarf;
    for (const QVariant &kv : kabelListeAufgeschluesselt(projektId)) {
        const QVariantMap k = kv.toMap();
        const QString bmk     = k[QStringLiteral("bezeichnung")].toString();
        const QString typ     = k[QStringLiteral("kabeltyp")].toString();
        const QString vonOrt  = k[QStringLiteral("vonOrt")].toString();
        const QString nachOrt = k[QStringLiteral("nachOrt")].toString();
        const QVariantList adern = k[QStringLiteral("adern")].toList();
        if (adern.isEmpty()) {
            // Kabel ohne Adern: eine Zeile nur mit Kabel-Metadaten
            out << csvQ(bmk) << u';' << csvQ(typ) << u';'
                << csvQ(vonOrt) << u';' << csvQ(nachOrt)
                << u";;;;;" << u'\n';
        } else {
            for (const QVariant &av : adern) {
                const QVariantMap a = av.toMap();
                const QString seite = a[QStringLiteral("blattnummer")].toString();
                const QString seiteBez = a[QStringLiteral("seitenBez")].toString();
                const QString seiteSpalte = seite.isEmpty() ? QString()
                    : (seiteBez.isEmpty() ? seite : seite + u' ' + seiteBez);
                const QString farbe  = a[QStringLiteral("farbe")].toString();
                const QString farbe2 = a[QStringLiteral("farbe2")].toString();
                out << csvQ(bmk)     << u';'
                    << csvQ(typ)     << u';'
                    << csvQ(vonOrt)  << u';'
                    << csvQ(nachOrt) << u';'
                    << csvQ(QString::number(a[QStringLiteral("nr")].toInt())) << u';'
                    << csvQ(farbe2.isEmpty() ? farbe : farbe + "/" + farbe2) << u';'
                    << csvQ(a[QStringLiteral("bezeichnung")].toString()) << u';'
                    << csvQ(seiteSpalte)                                  << u';'
                    << csvQ(a[QStringLiteral("netz")].toString())        << u'\n';
            }
        }
    }
    return true;
}

// ============================================================
// seiteBasisDaten – Blattnummer + Bezeichnung für eine Seite
// ============================================================
