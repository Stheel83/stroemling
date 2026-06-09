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
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite   s ON s.id  = ge.seite_id
        JOIN ort     o ON o.id  = s.ort_id
        JOIN anlage  a ON a.id  = o.anlage_id
        WHERE ge.typ = 'geraetekasten'
          AND a.projekt_id = :pid
        ORDER BY COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
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
        m[QStringLiteral("weltX")]       = q.value(6).toDouble();
        m[QStringLiteral("weltY")]       = q.value(7).toDouble();
        result.append(m);
    }
    return result;
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
