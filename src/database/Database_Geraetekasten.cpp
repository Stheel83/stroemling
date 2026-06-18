#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QVariantMap>
#include <QDebug>

// ============================================================
// geraetekastenListeMitPos
// Alle Gerätekästen des Projekts mit Seite und Mittelpunkt,
// sortiert nach BMK und Blattnummer.
// ============================================================
QVariantList Database::geraetekastenListeMitPos(int projektId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.id,
               ge.seite_id,
               COALESCE(s.blattnummer, ''),
               COALESCE(s.bezeichnung, ''),
               COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
               COALESCE(json_extract(ge.extra_daten, '$.bezeichnung'), ''),
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0,
               COALESCE(CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER), 0),
               COALESCE(b.bezeichnung, ''),
               COALESCE(b.hersteller, ''),
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
                LIMIT 1) AS sk_extra
        FROM grafik_element ge
        JOIN seite   s ON s.id  = ge.seite_id
        JOIN ort     o ON o.id  = s.ort_id
        JOIN anlage  a ON a.id  = o.anlage_id
        LEFT JOIN bauteil b ON b.id = CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER)
        WHERE ge.typ = 'geraetekasten'
          AND a.projekt_id = :pid
        ORDER BY a.kuerzel, o.kuerzel,
                 COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
                 s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "geraetekastenListeMitPos:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]          = q.value(0).toInt();
        m[QStringLiteral("seiteId")]     = q.value(1).toInt();
        m[QStringLiteral("blattnr")]     = q.value(2).toString();
        m[QStringLiteral("seiteBez")]    = q.value(3).toString();
        m[QStringLiteral("bmk")]         = q.value(4).toString();
        m[QStringLiteral("bezeichnung")] = q.value(5).toString();
        m[QStringLiteral("weltX")]            = q.value(6).toDouble();
        m[QStringLiteral("weltY")]            = q.value(7).toDouble();
        m[QStringLiteral("bauteilId")]        = q.value(8).toInt();
        m[QStringLiteral("bauteilBez")]       = q.value(9).toString();
        m[QStringLiteral("bauteilHersteller")]= q.value(10).toString();

        QString anlageKz = q.value(11).toString();
        QString ortKz    = q.value(12).toString();
        QString anlageUO = q.value(13).toString();
        QString ortUO    = q.value(14).toString();
        strukturkastenOverrideAnwenden(q.value(15).toString(), anlageKz, ortKz, anlageUO, ortUO);
        m[QStringLiteral("anlageKz")] = anlageKz;
        m[QStringLiteral("ortKz")]    = ortKz;
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        result.append(m);
    }
    return result;
}

// ============================================================
// geraetekastenBauteilSetzen
// Setzt oder löscht bauteil_id in extra_daten eines grafik_element.
// bauteilId <= 0 entfernt den Eintrag (setzt auf 0).
// ============================================================
bool Database::geraetekastenBauteilSetzen(int grafikElementId, int bauteilId)
{
    QSqlQuery q(m_db);
    if (bauteilId > 0) {
        q.prepare(R"(
            UPDATE grafik_element
            SET extra_daten = json_set(COALESCE(extra_daten, '{}'), '$.bauteil_id', :bid)
            WHERE id = :id
        )");
        q.bindValue(":bid", bauteilId);
    } else {
        q.prepare(R"(
            UPDATE grafik_element
            SET extra_daten = json_remove(COALESCE(extra_daten, '{}'), '$.bauteil_id')
            WHERE id = :id
        )");
    }
    q.bindValue(":id", grafikElementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "geraetekastenBauteilSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// geraetekastenNachBmk
// Alle Gerätekästen eines Projekts mit gegebenem BMK (für EP).
// ============================================================
QVariantList Database::geraetekastenNachBmk(int projektId, const QString &bmk) const
{
    QVariantList result;
    if (bmk.isEmpty() || projektId < 0)
        return result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.id,
               ge.seite_id,
               COALESCE(s.blattnummer, ''),
               COALESCE(s.bezeichnung, ''),
               COALESCE(json_extract(ge.extra_daten, '$.bezeichnung'), ''),
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite   s ON s.id  = ge.seite_id
        JOIN ort     o ON o.id  = s.ort_id
        JOIN anlage  a ON a.id  = o.anlage_id
        WHERE ge.typ = 'geraetekasten'
          AND a.projekt_id = :pid
          AND json_extract(ge.extra_daten, '$.bmk') = :bmk
        ORDER BY s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qCWarning(lcDb) << "geraetekastenNachBmk:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]          = q.value(0).toInt();
        m[QStringLiteral("seiteId")]     = q.value(1).toInt();
        m[QStringLiteral("blattnr")]     = q.value(2).toString();
        m[QStringLiteral("seiteBez")]    = q.value(3).toString();
        m[QStringLiteral("bezeichnung")] = q.value(4).toString();
        m[QStringLiteral("weltX")]       = q.value(5).toDouble();
        m[QStringLiteral("weltY")]       = q.value(6).toDouble();
        result.append(m);
    }
    return result;
}
