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

// ============================================================
// kabelAnlegen
// Legt einen neuen kabel-Datensatz an und verknüpft ihn mit
// dem grafik_element der Kabeldefinitionslinie.
// Gibt die neue kabel-ID zurück oder -1 bei Fehler.
// ============================================================
int Database::kabelAnlegen(int projektId, const QString &bezeichnung,
                           const QString &kabeltyp, int aderzahl,
                           double querschnittMm2, int grafikElementId,
                           const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO kabel (projekt_id, bezeichnung, kabeltyp, aderzahl,
                           querschnitt_mm2, grafik_element_id, von_ort, nach_ort)
        VALUES (:pid, :bez, :typ, :anz, :qs, :geid, :von, :nach)
    )");
    q.bindValue(":pid",  projektId);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":geid", grafikElementId > 0 ? grafikElementId : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAnlegen fehlgeschlagen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ============================================================
// kabelAderZuordnen
// Legt eine kabel_ader-Zeile an (oder aktualisiert sie falls
// ader_nr für dieses Kabel bereits vorhanden).
// ============================================================
bool Database::kabelAderZuordnen(int kabelId, int aderNr,
                                 const QString &farbe,
                                 const QString &bezeichnung,
                                 int verbindungId,
                                 int kabellinieGrafikElementId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id FROM kabel_ader WHERE kabel_id=:kid AND ader_nr=:nr");
    q.bindValue(":kid", kabelId);
    q.bindValue(":nr",  aderNr);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAderZuordnen SELECT:" << q.lastError().text();
        return false;
    }
    if (q.next()) {
        int existingId = q.value(0).toInt();
        QSqlQuery upd;
        upd.prepare(R"(
            UPDATE kabel_ader SET farbe=:f, bezeichnung=:b, verbindung_id=:vid,
                                  kabellinie_grafik_element_id=:lgeid
            WHERE id=:id
        )");
        upd.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        upd.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        upd.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":id",    existingId);
        if (!upd.exec()) {
            qCWarning(lcDb) << "kabelAderZuordnen UPDATE:" << upd.lastError().text();
            return false;
        }
    } else {
        QSqlQuery ins;
        ins.prepare(R"(
            INSERT INTO kabel_ader (kabel_id, ader_nr, farbe, bezeichnung,
                                   verbindung_id, kabellinie_grafik_element_id)
            VALUES (:kid, :nr, :f, :b, :vid, :lgeid)
        )");
        ins.bindValue(":kid",   kabelId);
        ins.bindValue(":nr",    aderNr);
        ins.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        ins.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        ins.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        ins.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        if (!ins.exec()) {
            qCWarning(lcDb) << "kabelAderZuordnen INSERT:" << ins.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// kabelLinieDetails
// Lädt Kabelmetadaten + Adern für ein grafik_element.
// ============================================================
QVariantMap Database::kabelLinieDetails(int grafikElementId)
{
    QVariantMap result;
    if (grafikElementId <= 0) return result;

    // Kabel über den kabelId-Eintrag im extra_daten-JSON des Grafikelements suchen.
    // Funktioniert auch für nicht-primäre Linien eines Kabels (M9).
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.grafik_element_id, k.bauteil_kabel_id, k.von_ort, k.nach_ort
        FROM kabel k
        WHERE k.id = (
            SELECT CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER)
            FROM grafik_element ge WHERE ge.id = :geid
        )
        LIMIT 1
    )");
    q.bindValue(":geid", grafikElementId);
    if (!q.exec() || !q.next())
        return result;

    int kabelId = q.value(0).toInt();
    result[QStringLiteral("id")]              = kabelId;
    result[QStringLiteral("bezeichnung")]     = q.value(1).toString();
    result[QStringLiteral("kabeltyp")]        = q.value(2).toString();
    result[QStringLiteral("aderzahl")]        = q.value(3).toInt();
    result[QStringLiteral("querschnittMm2")]  = q.value(4).toDouble();
    result[QStringLiteral("grafikElementId")] = q.value(5).toInt();
    result[QStringLiteral("bauteilKabelId")]  = q.value(6).toInt();
    result[QStringLiteral("vonOrt")]          = q.value(7).toString();
    result[QStringLiteral("nachOrt")]         = q.value(8).toString();

    QSqlQuery qa;
    qa.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id, kabellinie_grafik_element_id
        FROM kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
    )");
    qa.bindValue(":kid", kabelId);
    QVariantList adern;
    if (qa.exec()) {
        while (qa.next()) {
            QVariantMap ader;
            ader[QStringLiteral("aderNr")]                      = qa.value(0).toInt();
            ader[QStringLiteral("farbe")]                       = qa.value(1).toString();
            ader[QStringLiteral("bezeichnung")]                 = qa.value(2).toString();
            ader[QStringLiteral("verbindungId")]                = qa.value(3).toInt();
            ader[QStringLiteral("kabellinieGrafikElementId")]   = qa.value(4).toInt();
            adern.append(ader);
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelListe
// Alle Kabel eines Projekts – für den Kabel-Editor / Kabelliste.
// ============================================================
QVariantList Database::kabelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, bezeichnung, kabeltyp, aderzahl, querschnitt_mm2,
               laenge_m, von_ort, nach_ort, grafik_element_id
        FROM kabel WHERE projekt_id = :pid ORDER BY bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q.value(7).toString();
        k[QStringLiteral("grafikElementId")]= q.value(8).toInt();
        result.append(k);
    }
    return result;
}

// ============================================================
// kabelListeMitPos
// Wie kabelListe, aber mit Seite und Mittelpunktposition der primären Kabellinie.
// ============================================================
QVariantList Database::kabelListeMitPos(int projektId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               COALESCE(ge.seite_id, 0),
               COALESCE(s.blattnummer, ''),
               COALESCE(s.bezeichnung, ''),
               COALESCE((ge.x1 + ge.x2) / 2.0, 0.0),
               COALESCE((ge.y1 + ge.y2) / 2.0, 0.0)
        FROM kabel k
        LEFT JOIN grafik_element ge ON ge.id = k.grafik_element_id
        LEFT JOIN seite s ON s.id = ge.seite_id
        WHERE k.projekt_id = :pid
        ORDER BY k.bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelListeMitPos:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]             = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")]    = q.value(1).toString();
        m[QStringLiteral("kabeltyp")]       = q.value(2).toString();
        m[QStringLiteral("aderzahl")]       = q.value(3).toInt();
        m[QStringLiteral("querschnittMm2")] = q.value(4).toDouble();
        m[QStringLiteral("seiteId")]        = q.value(5).toInt();
        m[QStringLiteral("blattnr")]        = q.value(6).toString();
        m[QStringLiteral("seiteBez")]       = q.value(7).toString();
        m[QStringLiteral("weltX")]          = q.value(8).toDouble();
        m[QStringLiteral("weltY")]          = q.value(9).toDouble();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabellinienMitPos
// Alle kabellinie-Grafik-Elemente eines Kabels mit Seite und Mittelpunkt.
// ============================================================
QVariantList Database::kabellinienMitPos(int kabelId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.id, ge.seite_id,
               COALESCE(s.blattnummer, ''),
               COALESCE(s.bezeichnung, ''),
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        WHERE ge.typ = 'kabellinie'
          AND CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER) = :kid
        ORDER BY s.blattnummer, ge.id
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabellinienMitPos:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("grafikElementId")] = q.value(0).toInt();
        m[QStringLiteral("seiteId")]         = q.value(1).toInt();
        m[QStringLiteral("blattnr")]         = q.value(2).toString();
        m[QStringLiteral("seiteBez")]        = q.value(3).toString();
        m[QStringLiteral("weltX")]           = q.value(4).toDouble();
        m[QStringLiteral("weltY")]           = q.value(5).toDouble();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabelListeAufgeschluesselt
// Alle Kabel eines Projekts mit ihren Ader-Unterzeilen.
// Zwei Queries: (1) Kabel + Linienanzahl, (2) alle Adern mit Seite + Netz.
// ============================================================
QVariantList Database::kabelListeAufgeschluesselt(int projektId)
{
    // ─── Pass 1: Kabel laden ────────────────────────────────
    QVariantList kabel;
    QHash<int, int> kabelIdx;  // kabelId → Index in kabel

    QSqlQuery q1;
    q1.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.laenge_m, k.von_ort, k.nach_ort,
               COUNT(DISTINCT ka.kabellinie_grafik_element_id) AS linien_anzahl
        FROM kabel k
        LEFT JOIN kabel_ader ka ON ka.kabel_id = k.id
                                AND ka.kabellinie_grafik_element_id IS NOT NULL
        WHERE k.projekt_id = :pid
        GROUP BY k.id
        ORDER BY k.bezeichnung
    )");
    q1.bindValue(":pid", projektId);
    if (!q1.exec()) {
        qCWarning(lcDb) << "kabelListeAufgeschluesselt (kabel):" << q1.lastError().text();
        return kabel;
    }
    while (q1.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q1.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q1.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q1.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q1.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q1.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q1.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q1.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q1.value(7).toString();
        k[QStringLiteral("linienAnzahl")]   = q1.value(8).toInt();
        k[QStringLiteral("adern")]          = QVariantList();
        kabelIdx[q1.value(0).toInt()]       = kabel.size();
        kabel.append(k);
    }

    // ─── Pass 2: Adern laden (alle Kabel des Projekts, ein Query) ──
    QSqlQuery q2;
    q2.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, COALESCE(ka.farbe, ''), COALESCE(ka.bezeichnung, ''),
               COALESCE(s.blattnummer, ''), COALESCE(s.bezeichnung, ''),
               COALESCE(v.bezeichnung, ''),
               COALESCE(ka.von_gerat_pin, ''), COALESCE(ka.nach_gerat_pin, '')
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        LEFT JOIN grafik_element ge ON ge.id = ka.kabellinie_grafik_element_id
        LEFT JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN verbindung v ON v.id = ka.verbindung_id
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q2.bindValue(":pid", projektId);
    if (!q2.exec()) {
        qCWarning(lcDb) << "kabelListeAufgeschluesselt (adern):" << q2.lastError().text();
        return kabel;
    }
    while (q2.next()) {
        int kId = q2.value(0).toInt();
        if (!kabelIdx.contains(kId)) continue;
        QVariantMap a;
        a[QStringLiteral("nr")]               = q2.value(1).toInt();
        a[QStringLiteral("farbe")]            = q2.value(2).toString();
        a[QStringLiteral("bezeichnung")]      = q2.value(3).toString();
        a[QStringLiteral("blattnummer")]      = q2.value(4).toString();
        a[QStringLiteral("seitenBez")]        = q2.value(5).toString();
        a[QStringLiteral("netz")]             = q2.value(6).toString();
        a[QStringLiteral("vonGeratPin")]      = q2.value(7).toString();
        a[QStringLiteral("nachGeratPin")]     = q2.value(8).toString();
        int idx = kabelIdx[kId];
        QVariantMap kMap = kabel[idx].toMap();
        QVariantList adern = kMap[QStringLiteral("adern")].toList();
        adern.append(a);
        kMap[QStringLiteral("adern")] = adern;
        kabel[idx] = kMap;
    }
    return kabel;
}

// ============================================================
// kabelMetaAktualisieren
// Aktualisiert Bezeichnung, Typ, Aderzahl, Querschnitt eines
// bestehenden Kabel-Datensatzes (z. B. nach EigenschaftenPanel-Änderung).
// ============================================================
bool Database::kabelMetaAktualisieren(int kabelId, const QString &bezeichnung,
                                       const QString &kabeltyp, int aderzahl,
                                       double querschnittMm2,
                                       const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE kabel SET bezeichnung=:bez, kabeltyp=:typ, aderzahl=:anz,
                         querschnitt_mm2=:qs, von_ort=:von, nach_ort=:nach
        WHERE id = :id
    )");
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// kabelAderListeMitVerbindung
// Gibt alle kabel_adern eines Projekts mit ihrer verbindung_id zurück –
// benötigt für den Verdrahtungsweg-Algorithmus (M11) in QML.
// ============================================================
QVariantList Database::kabelAderListeMitVerbindung(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, ka.verbindung_id,
               COALESCE(ka.kabellinie_grafik_element_id, 0)
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        WHERE ka.verbindung_id IS NOT NULL AND ka.verbindung_id > 0
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAderListeMitVerbindung:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap a;
        a[QStringLiteral("kabelId")]                   = q.value(0).toInt();
        a[QStringLiteral("aderNr")]                    = q.value(1).toInt();
        a[QStringLiteral("verbindungId")]              = q.value(2).toInt();
        a[QStringLiteral("kabellinieGrafikElementId")] = q.value(3).toInt();
        result.append(a);
    }
    return result;
}

// ============================================================
// kabelAderEndpunkteBerechnenUndSpeichern
// Berechnet von_gerat_pin / nach_gerat_pin für alle kabel_adern des Projekts
// rein aus der DB (ohne Canvas). Nutzt verbindung_segment-Endpunkte und
// sucht geometrisch benachbarte Endpunkt-Symbole (geraeteanschluss,
// klemme_anschluss, potenzial, isoliert_gelegte_ader). Speichert direkt.
// ============================================================
bool Database::kabelAderEndpunkteBerechnenUndSpeichern(int projektId)
{
    // ── 1. Adern mit verbindung_id und Seite der Kabellinie ────────
    struct AderInfo { int kabelId, aderNr, verbId, seiteId; };
    QVector<AderInfo> adern;
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ka.kabel_id, ka.ader_nr, ka.verbindung_id, ge.seite_id
            FROM kabel_ader ka
            JOIN kabel k  ON k.id  = ka.kabel_id
                          AND k.projekt_id = :pid
            JOIN grafik_element ge ON ge.id = ka.kabellinie_grafik_element_id
            WHERE ka.verbindung_id          > 0
              AND ka.kabellinie_grafik_element_id > 0
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (adern):" << q.lastError().text();
            return false;
        }
        while (q.next())
            adern.append({q.value(0).toInt(), q.value(1).toInt(),
                          q.value(2).toInt(), q.value(3).toInt()});
    }
    if (adern.isEmpty()) return true;

    // ── 2. Segment-Punkte aller relevanten Verbindungen ───────────
    // Schlüssel: (verbindungId << 32) | seiteId
    QHash<qint64, QVector<QPointF>> segPunkte;
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT vs.verbindung_id, vs.seite_id,
                   CAST(json_extract(vs.punkte,'$[0].x') AS REAL),
                   CAST(json_extract(vs.punkte,'$[0].y') AS REAL),
                   CAST(json_extract(vs.punkte,'$[1].x') AS REAL),
                   CAST(json_extract(vs.punkte,'$[1].y') AS REAL)
            FROM verbindung_segment vs
            JOIN verbindung v ON v.id = vs.verbindung_id
                              AND v.projekt_id = :pid
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (segmente):" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            qint64 key = ((qint64)q.value(0).toInt() << 32) | (quint32)q.value(1).toInt();
            segPunkte[key].append({q.value(2).toDouble(), q.value(3).toDouble()});
            segPunkte[key].append({q.value(4).toDouble(), q.value(5).toDouble()});
        }
    }

    // ── 3. Endpunkt-Elemente nach Seite ───────────────────────────
    struct EndEl { int idx; QString symbolId; double cx, cy; QJsonObject extra; };
    QHash<int, QVector<EndEl>> endEls; // seiteId → []
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ge.seite_id, ge.symbol_id,
                   (ge.x1 + ge.x2) / 2.0, (ge.y1 + ge.y2) / 2.0,
                   COALESCE(ge.extra_daten, '{}')
            FROM grafik_element ge
            JOIN seite s ON s.id = ge.seite_id AND s.projekt_id = :pid
            WHERE ge.symbol_id IN ('geraeteanschluss','klemme_anschluss',
                                   'potenzial','isoliert_gelegte_ader')
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (endels):" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            int sid = q.value(0).toInt();
            EndEl el;
            el.idx      = endEls[sid].size();
            el.symbolId = q.value(1).toString();
            el.cx       = q.value(2).toDouble();
            el.cy       = q.value(3).toDouble();
            auto doc    = QJsonDocument::fromJson(q.value(4).toString().toUtf8());
            el.extra    = doc.isObject() ? doc.object() : QJsonObject{};
            endEls[sid].append(el);
        }
    }

    // ── 4. Gerätekasten nach Seite (für geraeteanschluss BMK) ─────
    struct GkEl { double x1, y1, x2, y2; QString bmk; };
    QHash<int, QVector<GkEl>> gkMap; // seiteId → []
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ge.seite_id, ge.x1, ge.y1, ge.x2, ge.y2,
                   COALESCE(json_extract(ge.extra_daten,'$.bmk'), '')
            FROM grafik_element ge
            JOIN seite s ON s.id = ge.seite_id AND s.projekt_id = :pid
            WHERE ge.typ = 'geraetekasten'
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (gk):" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            int sid = q.value(0).toInt();
            GkEl gk{ q.value(1).toDouble(), q.value(2).toDouble(),
                     q.value(3).toDouble(), q.value(4).toDouble(),
                     q.value(5).toString() };
            gkMap[sid].append(gk);
        }
    }

    // ── 5. Verbindungs-Bezeichnungen (für potenzial-Label) ────────
    QHash<int, QString> verbBez;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, COALESCE(bezeichnung,'') FROM verbindung WHERE projekt_id = :pid");
        q.bindValue(":pid", projektId);
        if (q.exec())
            while (q.next())
                verbBez[q.value(0).toInt()] = q.value(1).toString();
    }

    // ── Hilfsfunktion: Endpunkt-String formatieren ─────────────────
    auto formatEndpunkt = [&](const EndEl &el, int seiteId, int verbId) -> QString {
        if (el.symbolId == QLatin1String("geraeteanschluss")) {
            const QString ank = el.extra[QStringLiteral("anschlussKennzeichnung")].toString();
            const GkEl *best  = nullptr;
            double bestArea   = std::numeric_limits<double>::max();
            for (const GkEl &gk : gkMap.value(seiteId)) {
                double xMin = std::min(gk.x1,gk.x2), xMax = std::max(gk.x1,gk.x2);
                double yMin = std::min(gk.y1,gk.y2), yMax = std::max(gk.y1,gk.y2);
                if (el.cx >= xMin && el.cx <= xMax && el.cy >= yMin && el.cy <= yMax) {
                    double a = (xMax-xMin)*(yMax-yMin);
                    if (a < bestArea) { bestArea = a; best = &gk; }
                }
            }
            const QString bmk = best ? best->bmk : QString{};
            return bmk.isEmpty() ? ank : (bmk + QLatin1Char(':') + ank);
        }
        if (el.symbolId == QLatin1String("klemme_anschluss")) {
            const QString abez = el.extra[QStringLiteral("anschlussBezeichnung")].toString();
            const QString bmk  = el.extra[QStringLiteral("bmk")].toString();
            return bmk.isEmpty() ? abez : (bmk + QLatin1Char(':') + abez);
        }
        if (el.symbolId == QLatin1String("potenzial")) {
            const QString sn = el.extra[QStringLiteral("signalname")].toString();
            const QString bz = verbBez.value(verbId);
            return bz.isEmpty() ? sn : bz;
        }
        if (el.symbolId == QLatin1String("isoliert_gelegte_ader"))
            return QStringLiteral("isoliert");
        return {};
    };

    // ── 6. Matching: Segment-Punkte ↔ Endpunkt-Elemente ──────────
    // Toleranz 3 Einheiten (deckt Abstand Symbolzentrum ↔ Pin ab)
    constexpr double TOL = 3.0;
    QVariantList ergebnisse;

    for (const AderInfo &ad : adern) {
        qint64 key = ((qint64)ad.verbId << 32) | (quint32)ad.seiteId;
        const QVector<QPointF> &punkte = segPunkte.value(key);
        if (punkte.isEmpty()) continue;

        const QVector<EndEl> &els = endEls.value(ad.seiteId);
        QString von, nach;
        int vonIdx = -1;

        for (const QPointF &pt : punkte) {
            for (const EndEl &el : els) {
                if (std::abs(el.cx - pt.x()) > TOL || std::abs(el.cy - pt.y()) > TOL)
                    continue;
                if (von.isEmpty()) {
                    von    = formatEndpunkt(el, ad.seiteId, ad.verbId);
                    vonIdx = el.idx;
                } else if (el.idx != vonIdx && nach.isEmpty()) {
                    nach = formatEndpunkt(el, ad.seiteId, ad.verbId);
                }
                if (!von.isEmpty() && !nach.isEmpty()) break;
            }
            if (!von.isEmpty() && !nach.isEmpty()) break;
        }

        ergebnisse.append(QVariantMap{
            { QStringLiteral("kabelId"), ad.kabelId },
            { QStringLiteral("aderNr"),  ad.aderNr  },
            { QStringLiteral("von"),     von         },
            { QStringLiteral("nach"),    nach         },
        });
    }

    return kabelAderEndpunkteBulkSetzen(projektId, ergebnisse);
}

// ============================================================
// kabelAderEndpunkteBulkSetzen
// Speichert Von/Nach-Gerät:Pin für eine Liste von kabel_adern.
// adern: [{kabelId, aderNr, von, nach}]
// ============================================================
bool Database::kabelAderEndpunkteBulkSetzen(int projektId, const QVariantList &adern)
{
    if (adern.isEmpty()) return true;
    if (!m_db.transaction()) {
        qCWarning(lcDb) << "kabelAderEndpunkteBulkSetzen: Transaktion:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE kabel_ader SET von_gerat_pin = :von, nach_gerat_pin = :nach
        WHERE kabel_id = :kid AND ader_nr = :nr
          AND EXISTS (SELECT 1 FROM kabel WHERE id = :kid2 AND projekt_id = :pid)
    )");
    for (const QVariant &av : adern) {
        const QVariantMap a = av.toMap();
        const QString von  = a.value(QStringLiteral("von")).toString();
        const QString nach = a.value(QStringLiteral("nach")).toString();
        q.bindValue(":von",  von.isEmpty()  ? QVariant(QMetaType::fromType<QString>()) : von);
        q.bindValue(":nach", nach.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : nach);
        q.bindValue(":kid",  a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":kid2", a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":nr",   a.value(QStringLiteral("aderNr")).toInt());
        q.bindValue(":pid",  projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBulkSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    if (!m_db.commit()) {
        qCWarning(lcDb) << "kabelAderEndpunkteBulkSetzen commit:" << m_db.lastError().text();
        m_db.rollback();
        return false;
    }
    return true;
}

// ============================================================
// kabelLoeschen
// Löscht Kabel + Adern. Das grafik_element selbst wird von QML
// gelöscht (grafikSpeichern); ON DELETE SET NULL sorgt dafür,
// dass kabel.grafik_element_id auf NULL gesetzt wird falls das
// Element zuerst gelöscht wird.
// ============================================================
bool Database::kabelLoeschen(int kabelId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM kabel WHERE id = :id");
    q.bindValue(":id", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// bauteilKabelListe
// Alle Kabel-Bibliothekseinträge für den Picker-Dialog.
// Gibt [{id, bauteilId, bezeichnung, kabeltyp, aderzahl,
//        querschnittMm2, adern:[{farbe,querschnittMm2}]}] zurück.
// ============================================================
QVariantList Database::bauteilKabelListe()
{
    QVariantList result;
    {
        QSqlQuery cnt;
        cnt.exec("SELECT COUNT(*) FROM bauteil_kabel");
        if (cnt.next())
            qCDebug(lcDb) << "bauteilKabelListe: bauteil_kabel Zeilen=" << cnt.value(0).toInt();
        else
            qCWarning(lcDb) << "bauteilKabelListe: COUNT Fehler:" << cnt.lastError().text();
    }
    QSqlQuery q(m_db);
    if (!q.exec(R"(
        SELECT bk.id, bk.bauteil_id, b.bezeichnung, bk.kabeltyp,
               COUNT(ba.id) AS aderzahl,
               MAX(ba.querschnitt_mm2) AS quer
        FROM bauteil_kabel bk
        JOIN bauteil b ON b.id = bk.bauteil_id
        LEFT JOIN bauteil_kabel_ader ba ON ba.kabel_id = bk.id
        GROUP BY bk.id
        ORDER BY b.bezeichnung, bk.kabeltyp
    )")) {
        qCWarning(lcDb) << "bauteilKabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        int bkId = q.value(0).toInt();
        k[QStringLiteral("id")]             = bkId;
        k[QStringLiteral("bauteilId")]      = q.value(1).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(3).toString();
        k[QStringLiteral("aderzahl")]       = q.value(4).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(5).toDouble();
        // Aderfarben für Farbvorschau laden
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT farbe, querschnitt_mm2 FROM bauteil_kabel_ader
            WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bkId);
        QVariantList adern;
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("farbe")]          = qa.value(0).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(1).toDouble();
                adern.append(a);
            }
        }
        k[QStringLiteral("adern")] = adern;
        result.append(k);
    }
    qCDebug(lcDb) << "bauteilKabelListe: Einträge=" << result.size();
    return result;
}

// ============================================================
// kabelBauteilKabelSetzen
// Weist einer Kabellinie ein Bauteil-Kabel zu (bauteilKabelId > 0)
// oder hebt die Zuweisung auf (bauteilKabelId <= 0).
// Bei Zuweisung werden kabeltyp/aderzahl/querschnitt_mm2 aus dem
// Bauteil-Kabel übernommen (können manuell überschrieben werden).
// Gibt die aktualisierten Metadaten zurück.
// ============================================================
QVariantMap Database::kabelBauteilKabelSetzen(int kabelId, int bauteilKabelId)
{
    QVariantMap result;
    QString neuerTyp;
    int     neueAderzahl = 0;
    double  neuerQuer    = 0.0;

    if (bauteilKabelId > 0) {
        QSqlQuery qbk;
        qbk.prepare(R"(
            SELECT bk.kabeltyp, COUNT(ba.id), MAX(ba.querschnitt_mm2)
            FROM bauteil_kabel bk
            LEFT JOIN bauteil_kabel_ader ba ON ba.kabel_id = bk.id
            WHERE bk.id = :id GROUP BY bk.id
        )");
        qbk.bindValue(":id", bauteilKabelId);
        if (qbk.exec() && qbk.next()) {
            neuerTyp     = qbk.value(0).toString();
            neueAderzahl = qbk.value(1).toInt();
            neuerQuer    = qbk.value(2).toDouble();
        }
    }

    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE kabel SET bauteil_kabel_id=:bkid, kabeltyp=:typ,
               aderzahl=:anz, querschnitt_mm2=:qs
        WHERE id = :id
    )");
    q.bindValue(":bkid", bauteilKabelId > 0 ? QVariant(bauteilKabelId) : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":typ",  neuerTyp.isEmpty()  ? QVariant(QMetaType(QMetaType::QString)) : neuerTyp);
    q.bindValue(":anz",  neueAderzahl > 0    ? neueAderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   neuerQuer > 0       ? neuerQuer    : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelBauteilKabelSetzen:" << q.lastError().text();
        return result;
    }
    result[QStringLiteral("kabeltyp")]       = neuerTyp;
    result[QStringLiteral("aderzahl")]       = neueAderzahl;
    result[QStringLiteral("querschnittMm2")] = neuerQuer;
    result[QStringLiteral("bauteilKabelId")] = bauteilKabelId > 0 ? bauteilKabelId : 0;

    // Aderliste für Canvas-Schnittpunkt-Beschriftung
    QVariantList adern;
    if (bauteilKabelId > 0) {
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT ader_nr, farbe, bezeichnung, querschnitt_mm2
            FROM bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bauteilKabelId);
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("aderNr")]         = qa.value(0).toInt();
                a[QStringLiteral("farbe")]          = qa.value(1).toString();
                a[QStringLiteral("bezeichnung")]    = qa.value(2).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(3).toDouble();
                adern.append(a);
            }
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelAlleLinienLaden
// Alle Kabellinie-Grafikelemente eines Kabels (alle Seiten).
// ============================================================
QVariantList Database::kabelAlleLinienLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.id, ge.seite_id, s.bezeichnung,
               COUNT(ka.id) AS ader_anzahl
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN kabel_ader ka ON ka.kabellinie_grafik_element_id = ge.id
        WHERE ge.typ = 'kabellinie'
          AND CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER) = :kid
        GROUP BY ge.id
        ORDER BY ge.seite_id, ge.sortierung
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAlleLinienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("grafikElementId")]   = q.value(0).toInt();
        m[QStringLiteral("seiteId")]           = q.value(1).toInt();
        m[QStringLiteral("seiteBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("aderAnzahl")]        = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabelFreieAderLaden
// Adern eines Kabels die keiner Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelFreieAderLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabel_id = :kid AND kabellinie_grafik_element_id IS NULL
        ORDER BY ader_nr
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelFreieAderLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(2).toString();
        ader[QStringLiteral("verbindungId")]= q.value(3).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// kabelAderFuerLinieLaden
// Adern die einer bestimmten Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelAderFuerLinieLaden(int kabellinieGrafikElementId)
{
    QVariantList result;
    if (kabellinieGrafikElementId <= 0) return result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabellinie_grafik_element_id = :geid
        ORDER BY ader_nr
    )");
    q.bindValue(":geid", kabellinieGrafikElementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAderFuerLinieLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(2).toString();
        ader[QStringLiteral("verbindungId")]= q.value(3).toInt();
        result.append(ader);
    }
    return result;
}

