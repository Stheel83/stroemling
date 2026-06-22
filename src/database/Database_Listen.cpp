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
//        signalname, richtung, x1, y1}] zurück.
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

        QString signalname, richtung;
        QString extraStr = q.value(3).toString();
        if (!extraStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname = obj[QStringLiteral("signalname")].toString();
                richtung   = obj[QStringLiteral("richtung")].toString();
            }
        }
        if (richtung.isEmpty()) richtung = QStringLiteral("ausgang");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;

        result.append(m);
    }
    return result;
}

// ============================================================
// stueckliste
// Alle platzierten Symbole (ohne Verbindungshelfer) mit BMK,
// Freitexten und Seiteninfo für ein Projekt.
// ============================================================
QVariantList Database::stueckliste(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.extra_daten, ge.symbol_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
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
        m[QStringLiteral("seiteId")]   = q.value(9).toInt();
        m[QStringLiteral("weltX")]     = q.value(10).toDouble();
        m[QStringLiteral("weltY")]     = q.value(11).toDouble();

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
        strukturkastenOverrideAnwenden(q.value(8).toString(), anlageKz, ortKz, anlageUO, ortUO);
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
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1),
               s.id AS seite_id,
               (ge.x1 + ge.x2) / 2.0 AS welt_x,
               (ge.y1 + ge.y2) / 2.0 AS welt_y
        FROM grafik_element ge
        JOIN seite  s ON s.id = ge.seite_id
        JOIN ort    o ON o.id = s.ort_id
        JOIN anlage a ON a.id = o.anlage_id
        JOIN bauteil b ON b.id = CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER)
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
            strukturkastenOverrideAnwenden(qGk.value(10).toString(), anlageKz2, ortKz2, anlageUO2, ortUO2);
            m[QStringLiteral("anlageKz")] = anlageKz2;
            m[QStringLiteral("ortKz")]    = ortKz2;
            m[QStringLiteral("anlageUO")] = anlageUO2;
            m[QStringLiteral("ortUO")]    = ortUO2;
            m[QStringLiteral("seiteId")]  = qGk.value(11).toInt();
            m[QStringLiteral("weltX")]    = qGk.value(12).toDouble();
            m[QStringLiteral("weltY")]    = qGk.value(13).toDouble();
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
               COALESCE(s.bezeichnung, '') AS seite_bez
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
                LIMIT 1) AS sk_extra
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
        QString bezeichnung, aderfarbe;
        double  querschnitt = 0.0, laenge = 0.0;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bezeichnung = obj[QStringLiteral("bezeichnung")].toString();
                aderfarbe   = obj[QStringLiteral("aderfarbe")].toString();
                querschnitt = obj[QStringLiteral("querschnitt_mm2")].toDouble(0.0);
                laenge      = obj[QStringLiteral("laenge_m")].toDouble(0.0);
            }
        }
        m[QStringLiteral("bezeichnung")]    = bezeichnung;
        m[QStringLiteral("aderfarbe")]      = aderfarbe;
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

QVariantList Database::betriebsmittelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT b.id, b.betriebsmittel_kz, b.bezeichnung, "
        "       COUNT(g.id) AS anzahl "
        "FROM betriebsmittel b "
        "LEFT JOIN grafik_element g ON g.betriebsmittel_id = b.id "
        "WHERE b.projekt_id = :pid "
        "GROUP BY b.id ORDER BY b.betriebsmittel_kz");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]             = q.value(0).toInt();
        m[QStringLiteral("kz")]             = q.value(1).toString();
        m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        m[QStringLiteral("anzahl")]         = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

int Database::betriebsmittelAnlegen(int projektId, const QString &kz, const QString &bezeichnung, int bauteilId)
{
    QSqlQuery q(m_db);
    if (bauteilId > 0) {
        q.prepare("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz, bezeichnung, bauteil_id) "
                  "VALUES (:pid, :kz, :bez, :bid)");
        q.bindValue(":bid", bauteilId);
    } else {
        q.prepare("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz, bezeichnung) "
                  "VALUES (:pid, :kz, :bez)");
    }
    q.bindValue(":pid", projektId);
    q.bindValue(":kz",  kz);
    q.bindValue(":bez", bezeichnung);
    if (!q.exec()) {
        qCWarning(lcDb) << "betriebsmittelAnlegen Fehler:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

int Database::betriebsmittelBauteilId(int betriebsmittelId) const
{
    QSqlQuery q(m_db);
    q.prepare("SELECT bauteil_id FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (!q.exec() || !q.next()) return 0;
    return q.value(0).toInt();
}

QVariantList Database::bauteilKontaktListe(int bauteilId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, symbol_id, bezeichnung, pin_bez "
              "FROM bauteil_kontakt WHERE bauteil_id = :bid "
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
    q.prepare("INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez) "
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
    q.prepare("UPDATE bauteil_kontakt SET symbol_id=:sid, bezeichnung=:bez, pin_bez=:pb WHERE id=:id");
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
    q.prepare("DELETE FROM bauteil_kontakt WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilKontaktLoeschen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::grafikElementVerknuepfen(int elementId, int betriebsmittelId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE grafik_element SET betriebsmittel_id = :bid WHERE id = :id");
    q.bindValue(":bid", betriebsmittelId);
    q.bindValue(":id",  elementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "grafikElementVerknuepfen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::grafikElementEntknuepfen(int elementId)
{
    // Falls dieses Element Hauptfunktion ist → haupt_element_id freigeben
    QSqlQuery clr;
    clr.prepare("UPDATE betriebsmittel SET haupt_element_id = NULL "
                "WHERE haupt_element_id = :eid");
    clr.bindValue(":eid", elementId);
    clr.exec();

    QSqlQuery q(m_db);
    q.prepare("UPDATE grafik_element SET betriebsmittel_id = NULL WHERE id = :id");
    q.bindValue(":id", elementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "grafikElementEntknuepfen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::betriebsmittelMitglieder(int betriebsmittelId)
{
    // haupt_element_id laden um istHauptfunktion zu bestimmen
    int hauptId = 0;
    {
        QSqlQuery hq;
        hq.prepare("SELECT haupt_element_id FROM betriebsmittel WHERE id = :id");
        hq.bindValue(":id", betriebsmittelId);
        if (hq.exec() && hq.next() && !hq.value(0).isNull())
            hauptId = hq.value(0).toInt();
    }

    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT g.id, s.blattnummer, s.bezeichnung, g.extra_daten, g.symbol_id, g.typ,"
        "       s.id, (g.x1+g.x2)/2.0, (g.y1+g.y2)/2.0 "
        "FROM grafik_element g "
        "JOIN seite s ON s.id = g.seite_id "
        "WHERE g.betriebsmittel_id = :bid "
        "ORDER BY (g.id = :hid) DESC, s.blattnummer, g.id");
    q.bindValue(":bid", betriebsmittelId);
    q.bindValue(":hid", hauptId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        int gid = q.value(0).toInt();
        m[QStringLiteral("id")]               = gid;
        m[QStringLiteral("blattnummer")]      = q.value(1).toString();
        m[QStringLiteral("seiteBezeichnung")] = q.value(2).toString();
        m[QStringLiteral("symbolId")]         = q.value(4).toString();
        m[QStringLiteral("typ")]              = q.value(5).toString();
        m[QStringLiteral("seiteId")]          = q.value(6).toInt();
        m[QStringLiteral("weltX")]            = q.value(7).toDouble();
        m[QStringLiteral("weltY")]            = q.value(8).toDouble();
        m[QStringLiteral("istHauptfunktion")] = (hauptId > 0 && gid == hauptId);
        QString extra = q.value(3).toString();
        QString bmk, anschlusskennzeichnung;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                auto obj = doc.object();
                bmk = obj[QStringLiteral("bmk")].toString();
                anschlusskennzeichnung = obj[QStringLiteral("anschlusskennzeichnung")].toString();
            }
        }
        m[QStringLiteral("bmk")]                   = bmk;
        m[QStringLiteral("anschlusskennzeichnung")] = anschlusskennzeichnung;
        result.append(m);
    }
    return result;
}

QVariantList Database::betriebsmittelMitgliederMitPos(int betriebsmittelId) const
{
    int hauptId = 0;
    {
        QSqlQuery hq(m_db);
        hq.prepare("SELECT haupt_element_id FROM betriebsmittel WHERE id = :id");
        hq.bindValue(":id", betriebsmittelId);
        if (hq.exec() && hq.next() && !hq.value(0).isNull())
            hauptId = hq.value(0).toInt();
    }
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT g.id, g.seite_id, s.blattnummer, COALESCE(s.bezeichnung,'') AS sbez,"
        "       g.symbol_id, g.extra_daten,"
        "       (g.x1+g.x2)/2.0, (g.y1+g.y2)/2.0"
        " FROM grafik_element g"
        " JOIN seite s ON s.id = g.seite_id"
        " WHERE g.betriebsmittel_id = :bid"
        " ORDER BY (g.id = :hid) DESC, s.blattnummer, g.id");
    q.bindValue(":bid", betriebsmittelId);
    q.bindValue(":hid", hauptId);
    if (!q.exec()) return result;
    while (q.next()) {
        int gid = q.value(0).toInt();
        QVariantMap m;
        m[QStringLiteral("elementId")]        = gid;
        m[QStringLiteral("seiteId")]          = q.value(1).toInt();
        m[QStringLiteral("blattnr")]          = q.value(2).toString();
        m[QStringLiteral("seiteBez")]         = q.value(3).toString();
        m[QStringLiteral("symbolId")]         = q.value(4).toString();
        m[QStringLiteral("istHauptfunktion")] = (hauptId > 0 && gid == hauptId);
        m[QStringLiteral("weltX")]            = q.value(6).toDouble();
        m[QStringLiteral("weltY")]            = q.value(7).toDouble();
        QString extra = q.value(5).toString();
        QString bmk;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject())
                bmk = doc.object()[QStringLiteral("bmk")].toString();
        }
        m[QStringLiteral("bmk")] = bmk;
        result.append(m);
    }
    return result;
}

QString Database::betriebsmittelKz(int betriebsmittelId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT betriebsmittel_kz FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return {};
}

QVariantMap Database::betriebsmittelInfo(int betriebsmittelId)
{
    QVariantMap m;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, betriebsmittel_kz, bezeichnung, haupt_element_id "
              "FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (!q.exec() || !q.next()) return m;
    m[QStringLiteral("id")]             = q.value(0).toInt();
    m[QStringLiteral("kz")]             = q.value(1).toString();
    m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
    m[QStringLiteral("hauptElementId")] = q.value(3).isNull() ? 0 : q.value(3).toInt();
    return m;
}

bool Database::betriebsmittelHauptfunktionSetzen(int betriebsmittelId, int elementId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE betriebsmittel SET haupt_element_id = :eid WHERE id = :bid");
    q.bindValue(":eid", elementId);
    q.bindValue(":bid", betriebsmittelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "betriebsmittelHauptfunktionSetzen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::betriebsmittelKzSetzen(int betriebsmittelId, const QString& neuKz)
{
    QSqlQuery upd(m_db);
    upd.prepare("UPDATE betriebsmittel SET betriebsmittel_kz = :kz WHERE id = :id");
    upd.bindValue(":kz", neuKz);
    upd.bindValue(":id", betriebsmittelId);
    if (!upd.exec()) {
        qCWarning(lcDb) << "betriebsmittelKzSetzen Fehler:" << upd.lastError().text();
        return false;
    }
    return betriebsmittelBmkSynchronisieren(betriebsmittelId);
}

bool Database::betriebsmittelBmkSynchronisieren(int betriebsmittelId)
{
    QString kz = betriebsmittelKz(betriebsmittelId);
    if (kz.isEmpty()) return false;

    QSqlQuery sel;
    sel.prepare("SELECT id, extra_daten FROM grafik_element WHERE betriebsmittel_id = :bid");
    sel.bindValue(":bid", betriebsmittelId);
    if (!sel.exec()) return false;

    QSqlQuery upd;
    upd.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    while (sel.next()) {
        int gid = sel.value(0).toInt();
        QString extra = sel.value(1).toString();
        QJsonObject obj;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject())
                obj = doc.object();
        }
        obj[QStringLiteral("bmk")] = kz;
        upd.bindValue(":ed", QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
        upd.bindValue(":id", gid);
        if (!upd.exec())
            qCWarning(lcDb) << "betriebsmittelBmkSynchronisieren Fehler Element" << gid << upd.lastError().text();
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
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT kl.id, kl.bezeichnung, "
        "COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung), "
        "k.id, k.nummer, k.sortierung, "
        "COALESCE(b.bezeichnung,''), "
        "COALESCE(bk.anschluss_typ,''), "
        "COALESCE(fd.bezeichnung,''), "
        "COALESCE(fd.hex_wert,''), "
        "COALESCE(kl.standort_uebergeordnet,''), "
        "(SELECT MIN(bkq.min_mm2) || '\xe2\x80\x93' || MAX(bkq.max_mm2) || ' mm\xc2\xb2' "
        "   FROM bauteil_klemme_querschnitt bkq WHERE bkq.klemme_id = bk.id), "
        "(SELECT ks.potenzial_text FROM klemme_stegbruecke ks "
        " WHERE ks.klemmenleiste_id = kl.id "
        " AND (ks.von_klemme_id = k.id OR ks.bis_klemme_id = k.id) "
        " AND ks.potenzial_text IS NOT NULL LIMIT 1) "
        "FROM klemmenleiste kl "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "JOIN klemme k ON k.klemmenleiste_id = kl.id "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN farb_definition fd ON fd.id = bk.gehaeuse_farbe_id "
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
        result.append(row);
    }
    return result;
}

// ============================================================
// klemmenplanCsvSpeichern
// ============================================================
bool Database::klemmenplanCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "klemmenplanCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";  // UTF-8 BOM für Excel
    out << "Leiste;Nr.;Bauteil;Typ;Querschnitt;Farbe;Potenzial;Ort\n";

    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };

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
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "stuecklisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "BMK;Typ;Freitext 1;Freitext 2;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
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
// querverweislisteCsvSpeichern
// ============================================================
bool Database::querverweislisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "querverweislisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Signalname;Richtung;Seite;Zielseite\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
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
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "aderlisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Adernummer;Aderfarbe;Querschnitt mm2;Laenge m;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : aderliste(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("bezeichnung")].toString())                          << u';'
            << csvQ(row[QStringLiteral("aderfarbe")].toString())                            << u';'
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
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "kabellisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Kabel-BMK;Kabeltyp;Von-Ort;Nach-Ort;Ader-Nr;Farbe;Bezeichnung;Seite;Netz\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
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
                out << csvQ(bmk)     << u';'
                    << csvQ(typ)     << u';'
                    << csvQ(vonOrt)  << u';'
                    << csvQ(nachOrt) << u';'
                    << csvQ(QString::number(a[QStringLiteral("nr")].toInt())) << u';'
                    << csvQ(a[QStringLiteral("farbe")].toString())       << u';'
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
