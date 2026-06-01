#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

QVariantList Database::klemmenFuerLeiste(int leisteId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT k.id, k.nummer, k.sortierung, k.bauteil_id, "
        "       bk.id, COALESCE(b.bezeichnung,''), "
        "       COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung) "
        "FROM klemme k "
        "JOIN klemmenleiste kl ON kl.id = k.klemmenleiste_id "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "WHERE k.klemmenleiste_id = :lid "
        "ORDER BY k.sortierung, k.id"
    );
    q.bindValue(":lid", leisteId);
    if (!q.exec()) { qWarning() << "klemmenFuerLeiste:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap row;
        row[QStringLiteral("id")]              = q.value(0).toInt();
        row[QStringLiteral("nummer")]          = q.value(1).toString();
        row[QStringLiteral("sortierung")]      = q.value(2).toInt();
        row[QStringLiteral("bauteilId")]       = q.value(3).toInt();
        row[QStringLiteral("bauteilKlemmeId")] = q.value(4).toInt();
        row[QStringLiteral("bezeichnung")]     = q.value(5).toString();
        row[QStringLiteral("leisteBmk")]       = q.value(6).toString();
        result.append(row);
    }
    return result;
}

QVariantList Database::anschluesseFuerKlemme(int bauteilId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT ebenen_anzahl, punkte_seite_a, punkte_seite_b, fuss_kontakt_pe "
        "FROM bauteil_klemme WHERE bauteil_id = :bid"
    );
    q.bindValue(":bid", bauteilId);
    if (!q.exec() || !q.next()) return result;

    int  ebenen = q.value(0).toInt();
    int  pA     = q.value(1).toInt();
    int  pB     = q.value(2).toInt();
    bool pe     = q.value(3).toInt() != 0;

    for (int e = 1; e <= ebenen; ++e) {
        int idx = 1;
        for (int a = 0; a < pA; ++a, ++idx) {
            QVariantMap anschluss;
            anschluss[QStringLiteral("bezeichnung")] = QString("%1.%2").arg(e).arg(idx);
            anschluss[QStringLiteral("seite")]       = QStringLiteral("A");
            anschluss[QStringLiteral("ebene")]       = e;
            result.append(anschluss);
        }
        for (int b = 0; b < pB; ++b, ++idx) {
            QVariantMap anschluss;
            anschluss[QStringLiteral("bezeichnung")] = QString("%1.%2").arg(e).arg(idx);
            anschluss[QStringLiteral("seite")]       = QStringLiteral("B");
            anschluss[QStringLiteral("ebene")]       = e;
            result.append(anschluss);
        }
    }
    if (pe) {
        QVariantMap anschluss;
        anschluss[QStringLiteral("bezeichnung")] = QStringLiteral("PE");
        anschluss[QStringLiteral("seite")]       = QString::fromUtf8("Fu\xc3\x9f");
        anschluss[QStringLiteral("ebene")]       = QStringLiteral("\xe2\x80\x93");
        result.append(anschluss);
    }
    return result;
}

// Gibt alle bereits platzierten klemme_anschluss-Elemente zurück:
// [{klemmeId: int, anschlussBezeichnung: string}]
QVariantList Database::platzierteKlemmenAnschluesse() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    if (!q.exec(
            "SELECT CAST(json_extract(extra_daten,'$.klemmeId') AS INTEGER),"
            "       json_extract(extra_daten,'$.anschlussBezeichnung')"
            " FROM grafik_element"
            " WHERE symbol_id='klemme_anschluss'"
            "   AND extra_daten IS NOT NULL"
            "   AND json_extract(extra_daten,'$.klemmeId') IS NOT NULL"
            "   AND json_extract(extra_daten,'$.klemmeId') != 'null'")) {
        qWarning() << "platzierteKlemmenAnschluesse:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        int kid = q.value(0).toInt();
        if (kid <= 0) continue;
        QVariantMap row;
        row[QStringLiteral("klemmeId")]             = kid;
        row[QStringLiteral("anschlussBezeichnung")] = q.value(1).toString();
        result.append(row);
    }
    return result;
}

bool Database::klemmeAnschlussIstPlatziert(int klemmeId, const QString &anschlussBezeichnung) const
{
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT COUNT(*) FROM grafik_element"
        " WHERE symbol_id='klemme_anschluss'"
        "   AND CAST(json_extract(extra_daten,'$.klemmeId') AS INTEGER) = :kid"
        "   AND json_extract(extra_daten,'$.anschlussBezeichnung') = :bez");
    q.bindValue(":kid", klemmeId);
    q.bindValue(":bez", anschlussBezeichnung);
    if (q.exec() && q.next())
        return q.value(0).toInt() > 0;
    return false;
}

// Alle klemme_anschluss-Platzierungen im Projekt über alle Seiten.
// Gibt [{seiteId, klemmeId, anschlussBezeichnung}] zurück.
QVariantList Database::klemmenAnschlussAlleSeiten(int projektId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    // Hinweis: projektId als Integer direkt einbetten, da QSQLITE benannte
    // Parameter in IN-Subqueries nicht unterstützt.
    const QString sql = QString(
        "SELECT ge.seite_id,"
        " CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER),"
        " json_extract(ge.extra_daten,'$.anschlussBezeichnung')"
        " FROM grafik_element ge"
        " WHERE ge.symbol_id = 'klemme_anschluss'"
        "  AND ge.seite_id IN (SELECT s.id FROM seite s"
        "    JOIN ort o ON o.id = s.ort_id"
        "    JOIN anlage a ON a.id = o.anlage_id"
        "    WHERE a.projekt_id = %1)"
        "  AND json_extract(ge.extra_daten,'$.klemmeId') IS NOT NULL"
        "  AND json_extract(ge.extra_daten,'$.klemmeId') != 'null'"
    ).arg(projektId);
    if (!q.exec(sql)) {
        qWarning() << "klemmenAnschlussAlleSeiten:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        int kid = q.value(1).toInt();
        if (kid <= 0) continue;
        QVariantMap row;
        row[QStringLiteral("seiteId")]              = q.value(0).toInt();
        row[QStringLiteral("klemmeId")]             = kid;
        row[QStringLiteral("anschlussBezeichnung")] = q.value(2).toString();
        result.append(row);
    }
    return result;
}

// Gibt für jede Stegbrücke im Projekt alle Klemmen-IDs zurück,
// die im Sortierungsbereich von→bis liegen.
// Ergebnis: [{stegId, ebene, klemmeIds:[id,...]}]
QVariantList Database::klemmenStegbrueckenGruppen(int projektId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT ks.id, ks.ebene, k.id "
        "FROM klemme_stegbruecke ks "
        "JOIN klemme vonK ON vonK.id = ks.von_klemme_id "
        "JOIN klemme bisK ON bisK.id = ks.bis_klemme_id "
        "JOIN klemme k ON k.klemmenleiste_id = vonK.klemmenleiste_id "
        "  AND k.sortierung >= vonK.sortierung "
        "  AND k.sortierung <= bisK.sortierung "
        "WHERE vonK.klemmenleiste_id IN "
        "  (SELECT id FROM klemmenleiste WHERE projekt_id = :pid) "
        "ORDER BY ks.id, k.sortierung"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "klemmenStegbrueckenGruppen:" << q.lastError().text();
        return result;
    }
    QHash<int, QVariantList> klemmeIds;
    QHash<int, int>          stegEbenen;
    QList<int>               stegOrder;
    while (q.next()) {
        int stegId   = q.value(0).toInt();
        int ebene    = q.value(1).toInt();
        int klemmeId = q.value(2).toInt();
        if (!stegEbenen.contains(stegId)) {
            stegEbenen[stegId] = ebene;
            stegOrder.append(stegId);
        }
        klemmeIds[stegId].append(klemmeId);
    }
    for (int stegId : stegOrder) {
        QVariantMap g;
        g[QStringLiteral("stegId")]    = stegId;
        g[QStringLiteral("ebene")]     = stegEbenen[stegId];
        g[QStringLiteral("klemmeIds")] = klemmeIds[stegId];
        result.append(g);
    }
    return result;
}
