#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>

// ── kontaktTypLaden ───────────────────────────────────────────────────────
// Lädt den kontakt_typ-Datensatz für ein Bauteil. Leere Map wenn keiner existiert.
QVariantMap Database::kontaktTypLaden(int bauteilId) const
{
    QVariantMap m;
    if (bauteilId < 0) return m;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, geschlecht, kontaktgroesse,
               querschnitt_steckseite_min, querschnitt_steckseite_max,
               querschnitt_kabel_min, querschnitt_kabel_max,
               nennstrom_a, nennspannung_v, verbindungstechnik
        FROM bibliothek.kontakt_typ WHERE bauteil_id = :bid
    )");
    q.bindValue(":bid", bauteilId);
    if (!q.exec() || !q.next()) return m;
    m["id"]                       = q.value(0).toInt();
    m["geschlecht"]               = q.value(1).toString();
    m["kontaktgroesse"]           = q.value(2).toDouble();
    m["querschnittSteckseiteMin"] = q.value(3).toDouble();
    m["querschnittSteckseiteMax"] = q.value(4).toDouble();
    m["querschnittKabelMin"]      = q.value(5).toDouble();
    m["querschnittKabelMax"]      = q.value(6).toDouble();
    m["nennstromA"]               = q.value(7).toDouble();
    m["nennspannungV"]            = q.value(8).toDouble();
    m["verbindungstechnik"]       = q.value(9).toString();
    return m;
}

// ── kontaktTypSpeichern ───────────────────────────────────────────────────
// INSERT OR REPLACE (per SELECT+UPDATE/INSERT) des kontakt_typ-Datensatzes.
// Gibt die id zurück (>0) oder -1 bei Fehler.
int Database::kontaktTypSpeichern(int bauteilId, const QString &geschlecht,
    double kontaktgroesse,
    double querschnittSteckseiteMin, double querschnittSteckseiteMax,
    double querschnittKabelMin, double querschnittKabelMax,
    double nennstromA, double nennspannungV,
    const QString &verbindungstechnik)
{
    QSqlQuery sel(m_db);
    sel.prepare("SELECT id FROM bibliothek.kontakt_typ WHERE bauteil_id = :bid");
    sel.bindValue(":bid", bauteilId);
    if (!sel.exec()) {
        qCWarning(lcDb) << "kontaktTypSpeichern SELECT:" << sel.lastError().text();
        return -1;
    }

    const QString gs = geschlecht.isEmpty() ? QStringLiteral("stift") : geschlecht;

    QSqlQuery q(m_db);
    if (sel.next()) {
        int existingId = sel.value(0).toInt();
        q.prepare(R"(
            UPDATE bibliothek.kontakt_typ
            SET geschlecht=:gs, kontaktgroesse=:kg,
                querschnitt_steckseite_min=:qsmn, querschnitt_steckseite_max=:qsmx,
                querschnitt_kabel_min=:qkmn, querschnitt_kabel_max=:qkmx,
                nennstrom_a=:ia, nennspannung_v=:uv, verbindungstechnik=:vt
            WHERE id=:id
        )");
        q.bindValue(":id", existingId);
        q.bindValue(":gs",   gs);
        q.bindValue(":kg",   kontaktgroesse            > 0 ? kontaktgroesse            : QVariant());
        q.bindValue(":qsmn", querschnittSteckseiteMin   > 0 ? querschnittSteckseiteMin  : QVariant());
        q.bindValue(":qsmx", querschnittSteckseiteMax   > 0 ? querschnittSteckseiteMax  : QVariant());
        q.bindValue(":qkmn", querschnittKabelMin        > 0 ? querschnittKabelMin       : QVariant());
        q.bindValue(":qkmx", querschnittKabelMax        > 0 ? querschnittKabelMax       : QVariant());
        q.bindValue(":ia",   nennstromA                 > 0 ? nennstromA                : QVariant());
        q.bindValue(":uv",   nennspannungV              > 0 ? nennspannungV             : QVariant());
        q.bindValue(":vt",   verbindungstechnik.isEmpty() ? QVariant() : verbindungstechnik);
        if (!q.exec()) {
            qCWarning(lcDb) << "kontaktTypSpeichern UPDATE:" << q.lastError().text();
            return -1;
        }
        return existingId;
    } else {
        q.prepare(R"(
            INSERT INTO bibliothek.kontakt_typ
                (bauteil_id, geschlecht, kontaktgroesse,
                 querschnitt_steckseite_min, querschnitt_steckseite_max,
                 querschnitt_kabel_min, querschnitt_kabel_max,
                 nennstrom_a, nennspannung_v, verbindungstechnik)
            VALUES (:bid, :gs, :kg, :qsmn, :qsmx, :qkmn, :qkmx, :ia, :uv, :vt)
        )");
        q.bindValue(":bid",  bauteilId);
        q.bindValue(":gs",   gs);
        q.bindValue(":kg",   kontaktgroesse            > 0 ? kontaktgroesse            : QVariant());
        q.bindValue(":qsmn", querschnittSteckseiteMin   > 0 ? querschnittSteckseiteMin  : QVariant());
        q.bindValue(":qsmx", querschnittSteckseiteMax   > 0 ? querschnittSteckseiteMax  : QVariant());
        q.bindValue(":qkmn", querschnittKabelMin        > 0 ? querschnittKabelMin       : QVariant());
        q.bindValue(":qkmx", querschnittKabelMax        > 0 ? querschnittKabelMax       : QVariant());
        q.bindValue(":ia",   nennstromA                 > 0 ? nennstromA                : QVariant());
        q.bindValue(":uv",   nennspannungV              > 0 ? nennspannungV             : QVariant());
        q.bindValue(":vt",   verbindungstechnik.isEmpty() ? QVariant() : verbindungstechnik);
        if (!q.exec()) {
            qCWarning(lcDb) << "kontaktTypSpeichern INSERT:" << q.lastError().text();
            return -1;
        }
        return q.lastInsertId().toInt();
    }
}
