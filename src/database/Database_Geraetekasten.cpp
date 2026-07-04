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
               COALESCE(CAST(json_extract(ge.extra_daten, '$.partnerGeraetekastenId') AS INTEGER), 0),
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
        LEFT JOIN bibliothek.bauteil b ON b.id = CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER)
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
        m[QStringLiteral("partnerGeraetekastenId")] = q.value(11).toInt();

        QString anlageKz = q.value(12).toString();
        QString ortKz    = q.value(13).toString();
        QString anlageUO = q.value(14).toString();
        QString ortUO    = q.value(15).toString();
        strukturkastenOverrideAnwenden(q.value(16).toString(), anlageKz, ortKz, anlageUO, ortUO);
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
// geraetekastenPartnerSetzen
// Verknüpft zwei Gerätekästen symmetrisch als Steckpaar-Partner (§10.3).
// A→B setzt automatisch auch B→A; hatte einer der beiden vorher einen
// anderen Partner, wird dieser alte Link aufgelöst (1:1-Beziehung).
// ============================================================
bool Database::geraetekastenPartnerSetzen(int grafikElementId, int partnerGrafikElementId)
{
    if (grafikElementId <= 0 || partnerGrafikElementId <= 0 || grafikElementId == partnerGrafikElementId)
        return false;

    auto aktuellerPartner = [this](int id) -> int {
        QSqlQuery q(m_db);
        q.prepare("SELECT CAST(json_extract(extra_daten, '$.partnerGeraetekastenId') AS INTEGER) FROM grafik_element WHERE id = :id");
        q.bindValue(":id", id);
        if (q.exec() && q.next()) return q.value(0).toInt();
        return 0;
    };
    auto partnerLoesen = [this](int id) {
        QSqlQuery q(m_db);
        q.prepare("UPDATE grafik_element SET extra_daten = json_remove(COALESCE(extra_daten,'{}'), '$.partnerGeraetekastenId') WHERE id = :id");
        q.bindValue(":id", id);
        q.exec();
    };

    const int alterPartnerA = aktuellerPartner(grafikElementId);
    if (alterPartnerA > 0 && alterPartnerA != partnerGrafikElementId)
        partnerLoesen(alterPartnerA);

    const int alterPartnerB = aktuellerPartner(partnerGrafikElementId);
    if (alterPartnerB > 0 && alterPartnerB != grafikElementId)
        partnerLoesen(alterPartnerB);

    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE grafik_element
        SET extra_daten = json_set(COALESCE(extra_daten, '{}'), '$.partnerGeraetekastenId', :pid)
        WHERE id = :id
    )");
    q.bindValue(":pid", partnerGrafikElementId);
    q.bindValue(":id",  grafikElementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "geraetekastenPartnerSetzen (A→B):" << q.lastError().text();
        return false;
    }
    q.bindValue(":pid", grafikElementId);
    q.bindValue(":id",  partnerGrafikElementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "geraetekastenPartnerSetzen (B→A):" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// geraetekastenPartnerAufheben
// Löst die Partner-Verknüpfung symmetrisch auf beiden Seiten auf.
// ============================================================
bool Database::geraetekastenPartnerAufheben(int grafikElementId)
{
    if (grafikElementId <= 0) return false;

    QSqlQuery sel(m_db);
    sel.prepare("SELECT CAST(json_extract(extra_daten, '$.partnerGeraetekastenId') AS INTEGER) FROM grafik_element WHERE id = :id");
    sel.bindValue(":id", grafikElementId);
    int partnerId = 0;
    if (sel.exec() && sel.next()) partnerId = sel.value(0).toInt();

    QSqlQuery q(m_db);
    q.prepare("UPDATE grafik_element SET extra_daten = json_remove(COALESCE(extra_daten,'{}'), '$.partnerGeraetekastenId') WHERE id = :id");
    q.bindValue(":id", grafikElementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "geraetekastenPartnerAufheben:" << q.lastError().text();
        return false;
    }
    if (partnerId > 0) {
        q.bindValue(":id", partnerId);
        q.exec();
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
