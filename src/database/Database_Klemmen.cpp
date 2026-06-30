#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

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
        "LEFT JOIN bibliothek.bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bibliothek.bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "WHERE k.klemmenleiste_id = :lid "
        "ORDER BY k.sortierung, k.id"
    );
    q.bindValue(":lid", leisteId);
    if (!q.exec()) { qCWarning(lcDb) << "klemmenFuerLeiste:" << q.lastError().text(); return result; }
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
        "FROM bibliothek.bauteil_klemme WHERE bauteil_id = :bid"
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
        qCWarning(lcDb) << "platzierteKlemmenAnschluesse:" << q.lastError().text();
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

QVariantMap Database::klemmeAnschlussPosition(int klemmeId, const QString &anschlussBezeichnung) const
{
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT ge.seite_id, s.blattnummer, s.bezeichnung,"
        "       (ge.x1 + ge.x2) / 2.0, (ge.y1 + ge.y2) / 2.0"
        " FROM grafik_element ge"
        " JOIN seite s ON s.id = ge.seite_id"
        " WHERE ge.symbol_id = 'klemme_anschluss'"
        "   AND CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER) = :kid"
        "   AND json_extract(ge.extra_daten,'$.anschlussBezeichnung') = :bez"
        " LIMIT 1");
    q.bindValue(":kid", klemmeId);
    q.bindValue(":bez", anschlussBezeichnung);
    if (!q.exec() || !q.next()) return {};
    QVariantMap m;
    m[QStringLiteral("seiteId")]   = q.value(0).toInt();
    m[QStringLiteral("blattnr")]   = q.value(1).toString();
    m[QStringLiteral("seiteBez")]  = q.value(2).toString();
    m[QStringLiteral("weltX")]     = q.value(3).toDouble();
    m[QStringLiteral("weltY")]     = q.value(4).toDouble();
    return m;
}

QVariantMap Database::leisteInfoFuerKlemme(int klemmeId) const
{
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT kl.id, kl.bezeichnung,"
        "       COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung)"
        " FROM klemme k"
        " JOIN klemmenleiste kl ON kl.id = k.klemmenleiste_id"
        " LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id"
        " WHERE k.id = :kid"
        " LIMIT 1");
    q.bindValue(":kid", klemmeId);
    if (!q.exec() || !q.next()) return {};
    QVariantMap m;
    m[QStringLiteral("leisteId")]   = q.value(0).toInt();
    m[QStringLiteral("bezeichnung")] = q.value(1).toString();
    m[QStringLiteral("bmkKurz")]    = q.value(2).toString();
    return m;
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
        qCWarning(lcDb) << "klemmenAnschlussAlleSeiten:" << q.lastError().text();
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
QVariantList Database::klemmenInterneBruecken(int /*projektId*/) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    if (!q.exec(
        "SELECT DISTINCT CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER), "
        "       bkb.von_ebene, bkb.nach_ebene "
        "FROM grafik_element ge "
        "JOIN bibliothek.bauteil_klemme_bruecke bkb "
        "  ON bkb.klemme_id = CAST(json_extract(ge.extra_daten,'$.bauteilKlemmeId') AS INTEGER) "
        "WHERE ge.symbol_id = 'klemme_anschluss' "
        "  AND (bkb.ist_pe_fuss IS NULL OR bkb.ist_pe_fuss = 0)")) {
        qCWarning(lcDb) << "klemmenInterneBruecken:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("klemmeId")]  = q.value(0).toInt();
        m[QStringLiteral("vonEbene")]  = q.value(1).toInt();
        m[QStringLiteral("nachEbene")] = q.value(2).toInt();
        result.append(m);
    }
    return result;
}

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
        qCWarning(lcDb) << "klemmenStegbrueckenGruppen:" << q.lastError().text();
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

// ============================================================
// klemmlistenauszug
// ============================================================
// Verdrahtungsliste aller Klemmen im Projekt.
// Gibt flache Liste mit Zeilen-Typen zurück:
//   "leiste"   – Leistenheader (bmk, bezeichnung)
//   "steg"     – Stegbrücke-Trennzeile (vonNr, bisNr, ebene, potenzial, hatKonflikt, signaltyp)
//   "anschluss"– Verbindungszeile (klemmeNr, anschlussBez, seite, platziert,
//                                  blattnummer, verbBez, signaltyp, querschnitt, farbeBez, farbeHex)
// Von/Nach (Verbindung): Netz-Bezeichnung + Canvas-Seite aus verbindung_segment (geometrisches Matching).
QVariantList Database::klemmlistenauszug(int projektId)
{
    QVariantList result;

    // ── 1. Platzierte klemme_anschluss-Elemente ──────────────────────────────
    // klemmeId → [{abez, sid, bl, px, py}]  (bl=Blattnummer, px/py=Pinposition)
    QHash<int, QList<QVariantMap>> platz;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER),"
            "       ge.seite_id, COALESCE(s.blattnummer,''),"
            "       ge.x1, ge.y1, ge.x2, ge.y2,"
            "       CAST(COALESCE(json_extract(ge.extra_daten,'$.rotation'),0) AS INTEGER) % 360,"
            "       COALESCE(json_extract(ge.extra_daten,'$.anschlussBezeichnung'),'')"
            " FROM grafik_element ge"
            " JOIN seite s ON s.id = ge.seite_id"
            " WHERE ge.symbol_id = 'klemme_anschluss'"
            "   AND CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER) > 0"
        );
        if (q.exec()) {
            while (q.next()) {
                int    kid = q.value(0).toInt();
                double x1  = q.value(3).toDouble(), y1 = q.value(4).toDouble();
                double x2  = q.value(5).toDouble(), y2 = q.value(6).toDouble();
                int    rot = ((q.value(7).toInt() % 360) + 360) % 360;
                double cx  = (x1 + x2) / 2.0,  cy = (y1 + y2) / 2.0;
                double px, py;
                switch (rot) {
                    case 90:  px = x2; py = cy; break;
                    case 180: px = cx; py = y2; break;
                    case 270: px = x1; py = cy; break;
                    default:  px = cx; py = y1; break;
                }
                QVariantMap m;
                m[QStringLiteral("abez")] = q.value(8).toString();
                m[QStringLiteral("sid")]  = q.value(1).toInt();
                m[QStringLiteral("bl")]   = q.value(2).toString();
                m[QStringLiteral("px")]   = px;
                m[QStringLiteral("py")]   = py;
                platz[kid].append(m);
            }
        }
    }

    // Schnellzugriff: "klemmeId|abez" → platziert / blattnummer / position
    QSet<QString>               platzSet;
    QHash<QString,QString>      platzBl;
    QHash<QString, QVariantMap> platzPos;
    for (auto it = platz.cbegin(); it != platz.cend(); ++it) {
        const QString kid = QString::number(it.key());
        for (const QVariantMap &p : it.value()) {
            const QString key = kid + QLatin1Char('|') + p[QStringLiteral("abez")].toString();
            platzSet.insert(key);
            platzBl[key]  = p[QStringLiteral("bl")].toString();
            QVariantMap pm;
            pm[QStringLiteral("sid")] = p[QStringLiteral("sid")];
            pm[QStringLiteral("px")]  = p[QStringLiteral("px")];
            pm[QStringLiteral("py")]  = p[QStringLiteral("py")];
            platzPos[key] = pm;
        }
    }

    // ── 2. Verbindungssegmente nach Seite ────────────────────────────────────
    // seite_id → [{x1,y1,x2,y2, vb(Netzbezeichnung), st(Signaltyp), vid(verbindung_id)}]
    QHash<int, QList<QVariantMap>> segmente;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT vs.seite_id,"
            "       CAST(json_extract(vs.punkte,'$[0].x') AS REAL),"
            "       CAST(json_extract(vs.punkte,'$[0].y') AS REAL),"
            "       CAST(json_extract(vs.punkte,'$[1].x') AS REAL),"
            "       CAST(json_extract(vs.punkte,'$[1].y') AS REAL),"
            "       COALESCE(v.bezeichnung,''), v.signaltyp, v.id"
            " FROM verbindung_segment vs"
            " JOIN verbindung v ON v.id = vs.verbindung_id"
            " WHERE v.projekt_id = :pid"
        );
        q.bindValue(":pid", projektId);
        if (q.exec()) {
            while (q.next()) {
                int sid = q.value(0).toInt();
                QVariantMap seg;
                seg[QStringLiteral("x1")]  = q.value(1).toDouble();
                seg[QStringLiteral("y1")]  = q.value(2).toDouble();
                seg[QStringLiteral("x2")]  = q.value(3).toDouble();
                seg[QStringLiteral("y2")]  = q.value(4).toDouble();
                seg[QStringLiteral("vb")]  = q.value(5).toString();
                seg[QStringLiteral("st")]  = q.value(6).toString();
                seg[QStringLiteral("vid")] = q.value(7).toInt();
                segmente[sid].append(seg);
            }
        }
    }

    // ── 2a. Kabel-Ader-Daten: verbindung_id → {farbe, nr} ──────────────────
    QHash<int, QVariantMap> kabelAderMap;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT ka.verbindung_id, COALESCE(ka.farbe,''), COALESCE(ka.bezeichnung,'')"
            " FROM kabel_ader ka"
            " JOIN kabel kb ON kb.id = ka.kabel_id"
            " WHERE kb.projekt_id = :pid AND ka.verbindung_id IS NOT NULL"
        );
        q.bindValue(":pid", projektId);
        if (q.exec()) {
            while (q.next()) {
                int vid = q.value(0).toInt();
                QVariantMap m;
                m[QStringLiteral("farbe")] = q.value(1).toString();
                m[QStringLiteral("nr")]    = q.value(2).toString();
                kabelAderMap[vid] = m;
            }
        }
    }

    // ── 2b. Aderdefinition-Symbole: seite_id → [{cx,cy,farbe,nr}] ───────────
    QHash<int, QList<QVariantMap>> aderdefMap;
    {
        const QString sql = QString(
            "SELECT ge.seite_id,"
            "       (ge.x1+ge.x2)/2.0, (ge.y1+ge.y2)/2.0,"
            "       COALESCE(json_extract(ge.extra_daten,'$.aderfarbe'),''),"
            "       COALESCE(json_extract(ge.extra_daten,'$.bezeichnung'),'')"
            " FROM grafik_element ge"
            " JOIN seite s ON s.id = ge.seite_id"
            " JOIN ort o ON o.id = s.ort_id"
            " JOIN anlage a ON a.id = o.anlage_id"
            " WHERE ge.symbol_id = 'aderdefinition' AND a.projekt_id = %1"
        ).arg(projektId);
        QSqlQuery q(m_db);
        if (q.exec(sql)) {
            while (q.next()) {
                QVariantMap ad;
                ad[QStringLiteral("cx")]    = q.value(1).toDouble();
                ad[QStringLiteral("cy")]    = q.value(2).toDouble();
                ad[QStringLiteral("farbe")] = q.value(3).toString();
                ad[QStringLiteral("nr")]    = q.value(4).toString();
                aderdefMap[q.value(0).toInt()].append(ad);
            }
        }
    }

    // ── 3. Geometrisches Matching: Pinposition → Verbindung + Aderinfos ──────
    // Schlüssel "klemmeId|anschlussBezeichnung" → {bl, vb, st, af, an}
    auto punktAufSegment = [](double cx, double cy,
                               double sx1, double sy1, double sx2, double sy2,
                               double tol) -> bool {
        double dx = sx2 - sx1, dy = sy2 - sy1;
        double len2 = dx*dx + dy*dy;
        if (len2 < 1e-6) return false;
        double t = ((cx-sx1)*dx + (cy-sy1)*dy) / len2;
        if (t < 0.0 || t > 1.0) return false;
        double projX = sx1 + t*dx, projY = sy1 + t*dy;
        return qAbs(cx-projX) < tol && qAbs(cy-projY) < tol;
    };

    QHash<QString, QVariantMap> verbInfo;
    const double TOL = 2.0;
    for (auto it = platz.cbegin(); it != platz.cend(); ++it) {
        int kid = it.key();
        for (const QVariantMap &p : it.value()) {
            double px  = p[QStringLiteral("px")].toDouble();
            double py  = p[QStringLiteral("py")].toDouble();
            int    sid = p[QStringLiteral("sid")].toInt();
            QString key = QString::number(kid) + QLatin1Char('|') + p[QStringLiteral("abez")].toString();
            QString vb, st, af, an;
            for (const QVariantMap &seg : segmente.value(sid)) {
                bool h1 = qAbs(seg[QStringLiteral("x1")].toDouble() - px) < TOL &&
                          qAbs(seg[QStringLiteral("y1")].toDouble() - py) < TOL;
                bool h2 = qAbs(seg[QStringLiteral("x2")].toDouble() - px) < TOL &&
                          qAbs(seg[QStringLiteral("y2")].toDouble() - py) < TOL;
                if (h1 || h2) {
                    vb = seg[QStringLiteral("vb")].toString();
                    st = seg[QStringLiteral("st")].toString();
                    int vid = seg[QStringLiteral("vid")].toInt();
                    if (kabelAderMap.contains(vid)) {
                        af = kabelAderMap[vid][QStringLiteral("farbe")].toString();
                        an = kabelAderMap[vid][QStringLiteral("nr")].toString();
                    }
                    if (af.isEmpty() && an.isEmpty()) {
                        double sx1 = seg[QStringLiteral("x1")].toDouble();
                        double sy1 = seg[QStringLiteral("y1")].toDouble();
                        double sx2 = seg[QStringLiteral("x2")].toDouble();
                        double sy2 = seg[QStringLiteral("y2")].toDouble();
                        for (const QVariantMap &ad : aderdefMap.value(sid)) {
                            if (punktAufSegment(ad[QStringLiteral("cx")].toDouble(),
                                                ad[QStringLiteral("cy")].toDouble(),
                                                sx1, sy1, sx2, sy2, 3.0)) {
                                af = ad[QStringLiteral("farbe")].toString();
                                an = ad[QStringLiteral("nr")].toString();
                                break;
                            }
                        }
                    }
                    break;
                }
            }
            QVariantMap vm;
            vm[QStringLiteral("bl")] = p[QStringLiteral("bl")];
            vm[QStringLiteral("vb")] = vb;
            vm[QStringLiteral("st")] = st;
            vm[QStringLiteral("af")] = af;
            vm[QStringLiteral("an")] = an;
            verbInfo[key] = vm;
        }
    }

    // ── 4. Stegbrücken je Leiste ─────────────────────────────────────────────
    QHash<int, QList<QVariantMap>> stegMap;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT ks.klemmenleiste_id, ks.ebene,"
            "       kv.sortierung, kb.sortierung,"
            "       kv.nummer, kb.nummer,"
            "       COALESCE(ks.potenzial_text,''), ks.hat_konflikt,"
            "       COALESCE(v.signaltyp,'')"
            " FROM klemme_stegbruecke ks"
            " JOIN klemme kv ON kv.id = ks.von_klemme_id"
            " JOIN klemme kb ON kb.id = ks.bis_klemme_id"
            " JOIN klemmenleiste kl ON kl.id = ks.klemmenleiste_id"
            " LEFT JOIN verbindung v ON v.id = ks.verbindung_id"
            " WHERE kl.projekt_id = :pid"
            " ORDER BY ks.klemmenleiste_id, ks.ebene, kv.sortierung"
        );
        q.bindValue(":pid", projektId);
        if (q.exec()) {
            while (q.next()) {
                QVariantMap s;
                s[QStringLiteral("ebene")]       = q.value(1).toInt();
                s[QStringLiteral("vonSort")]     = q.value(2).toInt();
                s[QStringLiteral("bisSort")]     = q.value(3).toInt();
                s[QStringLiteral("vonNr")]       = q.value(4).toString();
                s[QStringLiteral("bisNr")]       = q.value(5).toString();
                s[QStringLiteral("potenzial")]   = q.value(6).toString();
                s[QStringLiteral("hatKonflikt")] = q.value(7).toBool();
                s[QStringLiteral("signaltyp")]   = q.value(8).toString();
                stegMap[q.value(0).toInt()].append(s);
            }
        }
    }

    // ── 5. Klemmenleiste + Klemme-Hierarchie ────────────────────────────────
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT kl.id, kl.bezeichnung,"
        "       COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung),"
        "       k.id, k.nummer, k.sortierung,"
        "       bk.ebenen_anzahl, bk.punkte_seite_a, bk.punkte_seite_b,"
        "       COALESCE(bk.fuss_kontakt_pe,0),"
        "       COALESCE(fd.bezeichnung,''), COALESCE(fd.hex_wert,''),"
        "       COALESCE("
        "           (SELECT MIN(bkq.min_mm2)||'\xe2\x80\x93'||MAX(bkq.max_mm2)||' mm\xc2\xb2'"
        "            FROM bibliothek.bauteil_klemme_querschnitt bkq WHERE bkq.klemme_id = bk.id)"
        "       ,'')"
        " FROM klemmenleiste kl"
        " LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id"
        " JOIN klemme k ON k.klemmenleiste_id = kl.id"
        " LEFT JOIN bibliothek.bauteil b ON b.id = k.bauteil_id"
        " LEFT JOIN bibliothek.bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id"
        " LEFT JOIN bibliothek.farb_definition fd ON fd.id = bk.gehaeuse_farbe_id"
        " WHERE kl.projekt_id = :pid"
        " ORDER BY kl.bezeichnung, k.sortierung, k.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "klemmlistenauszug:" << q.lastError().text();
        return result;
    }

    int     lastLeistenId    = -1;
    QList<QVariantMap> curStegs;
    QString curLeisteStegsJson = QStringLiteral("[]");

    while (q.next()) {
        int leisteId = q.value(0).toInt();

        if (leisteId != lastLeistenId) {
            lastLeistenId = leisteId;
            curStegs = stegMap.value(leisteId);
            // JSON aller Stegbrücken dieser Leiste (für Spalten-Darstellung im QML)
            QJsonArray lsArr;
            for (const QVariantMap &s : curStegs) {
                QJsonObject o;
                o[QLatin1String("st")]  = s[QStringLiteral("signaltyp")].toString();
                o[QLatin1String("pot")] = s[QStringLiteral("potenzial")].toString();
                o[QLatin1String("eb")]  = s[QStringLiteral("ebene")].toInt();
                o[QLatin1String("vn")]  = s[QStringLiteral("vonNr")].toString();
                o[QLatin1String("bn")]  = s[QStringLiteral("bisNr")].toString();
                o[QLatin1String("vs")]  = s[QStringLiteral("vonSort")].toInt();
                o[QLatin1String("bs")]  = s[QStringLiteral("bisSort")].toInt();
                lsArr.append(o);
            }
            curLeisteStegsJson =
                QString::fromUtf8(QJsonDocument(lsArr).toJson(QJsonDocument::Compact));

            QVariantMap row;
            row[QStringLiteral("typ")]         = QStringLiteral("leiste");
            row[QStringLiteral("leisteId")]    = leisteId;
            row[QStringLiteral("bezeichnung")] = q.value(1).toString();
            row[QStringLiteral("bmk")]         = q.value(2).toString();
            row[QStringLiteral("stegAnzahl")]  = curStegs.size();
            result.append(row);
        }

        int    klemmeId = q.value(3).toInt();
        QString kNr     = q.value(4).toString();
        int    kSort    = q.value(5).toInt();
        bool   hatBk    = !q.value(6).isNull();
        int    ebAnz    = hatBk ? q.value(6).toInt() : 0;
        int    ptA      = hatBk ? q.value(7).toInt() : 0;
        int    ptB      = hatBk ? q.value(8).toInt() : 0;
        bool   haPE     = hatBk && (q.value(9).toInt() != 0);
        QString farbBez = q.value(10).toString();
        QString farbHex = q.value(11).toString();
        QString qs      = q.value(12).toString();


        bool ersteZeile = true;

        // Verbindungsinfo für einen Anschluss
        auto vi = [&](const QString &abez) -> QVariantMap {
            return verbInfo.value(QString::number(klemmeId) + QLatin1Char('|') + abez);
        };
        // platziert = Element liegt im Canvas (unabhängig von Netzanschluss)
        auto isPlatz = [&](const QString &abez) -> bool {
            return !abez.isEmpty() &&
                   platzSet.contains(QString::number(klemmeId) + QLatin1Char('|') + abez);
        };
        // verbunden = geometrisch mit einem Verbindungssegment gematcht
        auto isVerb = [&](const QString &abez) -> bool {
            return !abez.isEmpty() &&
                   verbInfo.contains(QString::number(klemmeId) + QLatin1Char('|') + abez);
        };

        // Paar-Zeile: Seite A links, Seite B rechts
        // ri = 0-basierter Index innerhalb der Klemme; rn = Gesamtzahl Zeilen
        auto addPaar = [&](const QString &bezA, const QString &bezB, int ebene, int ri, int rn) {
            bool pA = isPlatz(bezA), pB = isPlatz(bezB);
            bool vA = isVerb(bezA),  vB = isVerb(bezB);
            QVariantMap viA = vA ? vi(bezA) : QVariantMap{};
            QVariantMap viB = vB ? vi(bezB) : QVariantMap{};
            const QString kidStr = QString::number(klemmeId);
            const QVariantMap posA = pA ? platzPos.value(kidStr + QLatin1Char('|') + bezA) : QVariantMap{};
            QVariantMap row;
            row[QStringLiteral("typ")]             = QStringLiteral("anschluss");
            row[QStringLiteral("leisteId")]        = leisteId;
            row[QStringLiteral("klemmeId")]        = klemmeId;
            row[QStringLiteral("klemmeNr")]        = ersteZeile ? kNr : QString();
            row[QStringLiteral("ebene")]           = ebene;
            row[QStringLiteral("anschlussVon")]    = bezA;
            row[QStringLiteral("vonPlatziert")]    = pA;
            row[QStringLiteral("vonBlattnummer")]  = pA ? platzBl.value(kidStr+"|"+bezA) : QString();
            row[QStringLiteral("vonVerbBez")]      = vA ? viA[QStringLiteral("vb")].toString() : QString();
            row[QStringLiteral("vonSignaltyp")]    = vA ? viA[QStringLiteral("st")].toString() : QString();
            row[QStringLiteral("vonAderFarbe")]    = vA ? viA[QStringLiteral("af")].toString() : QString();
            row[QStringLiteral("vonAderNr")]       = vA ? viA[QStringLiteral("an")].toString() : QString();
            row[QStringLiteral("anschlussNach")]   = bezB;
            row[QStringLiteral("nachPlatziert")]   = pB;
            row[QStringLiteral("nachBlattnummer")] = pB ? platzBl.value(kidStr+"|"+bezB) : QString();
            row[QStringLiteral("nachVerbBez")]     = vB ? viB[QStringLiteral("vb")].toString() : QString();
            row[QStringLiteral("nachSignaltyp")]   = vB ? viB[QStringLiteral("st")].toString() : QString();
            row[QStringLiteral("nachAderFarbe")]   = vB ? viB[QStringLiteral("af")].toString() : QString();
            row[QStringLiteral("nachAderNr")]      = vB ? viB[QStringLiteral("an")].toString() : QString();
            row[QStringLiteral("querschnitt")]      = qs;
            row[QStringLiteral("farbeBez")]         = farbBez;
            row[QStringLiteral("farbeHex")]         = farbHex;
            row[QStringLiteral("klemmeSort")]       = kSort;
            row[QStringLiteral("klemmeReiheIdx")]   = ri;
            row[QStringLiteral("klemmeReihenAnz")]  = rn;
            row[QStringLiteral("leisteStegJson")]   = curLeisteStegsJson;
            row[QStringLiteral("vonSeiteId")]       = posA.value(QStringLiteral("sid"), 0).toInt();
            row[QStringLiteral("vonWeltX")]         = posA.value(QStringLiteral("px"), 0.0).toDouble();
            row[QStringLiteral("vonWeltY")]         = posA.value(QStringLiteral("py"), 0.0).toDouble();
            result.append(row);
            ersteZeile = false;
        };

        if (hatBk) {
            for (int e = 1; e <= ebAnz; ++e) {
                QStringList aList, bList;
                int idx = 1;
                for (int a = 0; a < ptA; ++a, ++idx)
                    aList.append(QString("%1.%2").arg(e).arg(idx));
                for (int b = 0; b < ptB; ++b, ++idx)
                    bList.append(QString("%1.%2").arg(e).arg(idx));
                int paare = qMax(ptA, ptB);
                for (int i = 0; i < paare; ++i)
                    addPaar(i < aList.size() ? aList[i] : QString(),
                            i < bList.size() ? bList[i] : QString(), e, i, paare);
            }
            if (haPE)
                addPaar(QStringLiteral("PE"), QString(), 0, 0, 1);
        } else {
            const QList<QVariantMap> &placed = platz.value(klemmeId);
            if (!placed.isEmpty()) {
                int n = placed.size();
                for (int pi = 0; pi < n; ++pi)
                    addPaar(placed[pi][QStringLiteral("abez")].toString(), QString(), 0, pi, n);
            } else {
                addPaar(QString(), QString(), 0, 0, 1);
            }
        }
    }
    return result;
}

// ============================================================
// klemmlistenauszugCsvSpeichern
// ============================================================
bool Database::klemmlistenauszugCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "klemmlistenauszugCsvSpeichern: kann nicht \xc3\xb6" "ffnen:" << localPath;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Leiste;Nr.;Von-Anschl.;Von-Verbindung;Von-Signaltyp;Von-Seite;Von-Aderfarbe;Von-Adernr;"
           "Nach-Anschl.;Nach-Verbindung;Nach-Signaltyp;Nach-Seite;Nach-Aderfarbe;Nach-Adernr;"
           "Querschnitt;Farbe\n";

    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };

    QString curLeisteBmk;
    for (const QVariant &v : klemmlistenauszug(projektId)) {
        const QVariantMap row = v.toMap();
        const QString typ = row[QStringLiteral("typ")].toString();
        if (typ == QLatin1String("leiste")) {
            curLeisteBmk = row[QStringLiteral("bmk")].toString();
        } else if (typ == QLatin1String("anschluss")) {
            bool pA = row[QStringLiteral("vonPlatziert")].toBool();
            bool pB = row[QStringLiteral("nachPlatziert")].toBool();
            out << csvQ(curLeisteBmk)
                << u';' << csvQ(row[QStringLiteral("klemmeNr")].toString())
                << u';' << csvQ(row[QStringLiteral("anschlussVon")].toString())
                << u';' << csvQ(pA ? row[QStringLiteral("vonVerbBez")].toString()     : QString())
                << u';' << csvQ(pA ? row[QStringLiteral("vonSignaltyp")].toString()   : QString())
                << u';' << csvQ(pA ? row[QStringLiteral("vonBlattnummer")].toString() : QString())
                << u';' << csvQ(row[QStringLiteral("vonAderFarbe")].toString())
                << u';' << csvQ(row[QStringLiteral("vonAderNr")].toString())
                << u';' << csvQ(row[QStringLiteral("anschlussNach")].toString())
                << u';' << csvQ(pB ? row[QStringLiteral("nachVerbBez")].toString()     : QString())
                << u';' << csvQ(pB ? row[QStringLiteral("nachSignaltyp")].toString()   : QString())
                << u';' << csvQ(pB ? row[QStringLiteral("nachBlattnummer")].toString() : QString())
                << u';' << csvQ(row[QStringLiteral("nachAderFarbe")].toString())
                << u';' << csvQ(row[QStringLiteral("nachAderNr")].toString())
                << u';' << csvQ(row[QStringLiteral("querschnitt")].toString())
                << u';' << csvQ(row[QStringLiteral("farbeBez")].toString())
                << u'\n';
        }
    }
    return true;
}
