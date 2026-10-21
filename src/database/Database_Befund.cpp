#include "Database.h"

#include <QDate>
#include <QDebug>
#include <QLoggingCategory>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>


namespace {

const QStringList kKategorien = { "bauteil", "verdrahtung", "schaltplan", "sonstiges" };
const QStringList kStati      = { "offen", "behoben", "kein_fehler" };

// Null-QString wird in Qt 6 als SQL-NULL gebunden; die Textspalten sind NOT NULL -> immer als leerer String binden
QString nn(const QString &t) { return t.isNull() ? QStringLiteral("") : t; }

QVariantMap fehler(const QString &text)
{
    return { { "ok", false }, { "fehler", text } };
}

} // namespace

QVariantMap Database::befundAnlegen(int projektId, const QVariantMap &daten)
{
    const QString art = daten.value("bezugArt").toString();
    if (art != "bmk" && art != "kabel" && art != "stelle")
        return fehler(tr("Unbekannter Bezug."));
    const QString text = daten.value("text").toString().trimmed();
    if (text.isEmpty())
        return fehler(tr("Bitte einen Befundtext eingeben."));
    const QString kategorie = daten.value("kategorie", "sonstiges").toString();
    if (!kKategorien.contains(kategorie))
        return fehler(tr("Unbekannte Kategorie."));

    int seiteId = daten.value("seiteId", -1).toInt();
    QString bmk = daten.value("bmk").toString().trimmed();
    QString kabelBez;
    double x = daten.value("x", 0).toDouble(), y = daten.value("y", 0).toDouble();
    bool hatPosition = daten.contains("x") && daten.contains("y");

    if (art == "kabel") {
        QSqlQuery k(m_db);
        k.prepare("SELECT k.bezeichnung, ge.seite_id, (ge.x1 + ge.x2) / 2.0, (ge.y1 + ge.y2) / 2.0 "
                  "FROM kabel k LEFT JOIN grafik_element ge ON ge.id = k.grafik_element_id "
                  "WHERE k.id = :kid AND k.projekt_id = :pid");
        k.bindValue(":kid", daten.value("kabelId", -1).toInt());
        k.bindValue(":pid", projektId);
        if (!k.exec() || !k.next())
            return fehler(tr("Das Kabel wurde nicht gefunden."));
        kabelBez = k.value(0).toString();
        if (!k.value(1).isNull()) {
            seiteId = k.value(1).toInt();
            if (!hatPosition) { x = k.value(2).toDouble(); y = k.value(3).toDouble(); hatPosition = true; }
        } else {
            seiteId = -1;   // Kabel ohne Seitenbezug: Befund ohne Seite (nur Bereich "ganzes Projekt")
        }
    } else {
        if (art == "bmk" && bmk.isEmpty())
            return fehler(tr("Für einen Befund am Betriebsmittel fehlt die BMK."));
        if (seiteId < 0)
            return fehler(tr("Für diesen Befund fehlt die Seite."));
    }

    // Fachlicher Schluessel der Seite als Text (ueberlebt Umbenennungen, Grundlage fuer das Overlay)
    QString anlage, ort, blatt;
    if (seiteId >= 0) {
        QSqlQuery q(m_db);
        q.prepare("SELECT a.kuerzel, o.kuerzel, s.blattnummer FROM seite s JOIN ort o ON s.ort_id = o.id "
                  "JOIN anlage a ON o.anlage_id = a.id WHERE s.id = :sid AND a.projekt_id = :pid");
        q.bindValue(":sid", seiteId);
        q.bindValue(":pid", projektId);
        if (!q.exec() || !q.next())
            return fehler(tr("Die Seite wurde nicht gefunden."));
        anlage = q.value(0).toString();
        ort    = q.value(1).toString();
        blatt  = q.value(2).toString();
        if (m_istIbnKopie && !ibnImBereich(seiteId))
            return fehler(tr("Nicht gespeichert: Die Seite liegt außerhalb des Bereichs dieser IBN-Kopie."));
    } else if (m_istIbnKopie && !m_kopieBereich.isEmpty()) {
        return fehler(tr("Nicht gespeichert: Dieser Befund hat keine Seite und gehört nicht zum Bereich dieser IBN-Kopie."));
    }

    QString kopieUuid;
    if (m_istIbnKopie) {
        QSqlQuery q(m_db);
        if (q.exec("SELECT kopie_uuid FROM projekt ORDER BY id LIMIT 1") && q.next())
            kopieUuid = q.value(0).toString();
    }

    const QString uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString gefundenAm = daten.value("gefundenAm").toString().trimmed();
    if (gefundenAm.isEmpty())
        gefundenAm = QDate::currentDate().toString(Qt::ISODate);

    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO fs_befund (projekt_id, befund_uuid, bezug_art, seite_id, anlage, ort, blattnummer, bmk, kabel_bezeichnung,
                               x, y, kategorie, text, status, gefunden_von, gefunden_am, geaendert_am, kopie_uuid)
        VALUES (:pid, :uuid, :art, :sid, :an, :ort, :bl, :bmk, :kab, :x, :y, :kat, :txt, 'offen', :von, :am, datetime('now'), :kopie)
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":uuid", uuid);
    q.bindValue(":art", art);
    q.bindValue(":sid", seiteId >= 0 ? QVariant(seiteId) : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":an", nn(anlage));
    q.bindValue(":ort", nn(ort));
    q.bindValue(":bl", nn(blatt));
    q.bindValue(":bmk", nn(art == "bmk" ? bmk : QString()));
    q.bindValue(":kab", nn(kabelBez));
    q.bindValue(":x", hatPosition ? QVariant(x) : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":y", hatPosition ? QVariant(y) : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":kat", kategorie);
    q.bindValue(":txt", text);
    q.bindValue(":von", nn(daten.value("gefundenVon").toString().trimmed()));
    q.bindValue(":am", gefundenAm);
    q.bindValue(":kopie", nn(kopieUuid));
    if (!q.exec()) {
        qCWarning(lcDb) << "befundAnlegen:" << q.lastError().text();
        return fehler(tr("Der Befund konnte nicht gespeichert werden (siehe Log)."));
    }
    return { { "ok", true }, { "id", q.lastInsertId() }, { "befundUuid", uuid } };
}

bool Database::befundAendern(int befundId, const QVariantMap &daten)
{
    QSqlQuery s(m_db);
    s.prepare("SELECT seite_id, bezug_art, kabel_bezeichnung FROM fs_befund WHERE id = :id");
    s.bindValue(":id", befundId);
    if (!s.exec() || !s.next())
        return false;
    if (m_istIbnKopie) {
        // Befunde mit Seite nur im Bereich; ohne Seite nur bei Bereich "ganzes Projekt"
        const bool ohneSeite = s.value(0).isNull();
        if (ohneSeite ? !m_kopieBereich.isEmpty() : !ibnImBereich(s.value(0).toInt()))
            return false;
    }
    const QString text = daten.value("text").toString().trimmed();
    const QString kategorie = daten.value("kategorie").toString();
    const QString status = daten.value("status").toString();
    if (text.isEmpty() || !kKategorien.contains(kategorie) || !kStati.contains(status))
        return false;

    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE fs_befund
        SET text = :txt, kategorie = :kat, status = :st, gefunden_von = :von,
            behoben_am = CASE WHEN :st = 'behoben' THEN :heute ELSE '' END,
            geaendert_am = datetime('now')
        WHERE id = :id
    )");
    q.bindValue(":txt", text);
    q.bindValue(":kat", kategorie);
    q.bindValue(":st", status);
    q.bindValue(":von", nn(daten.value("gefundenVon").toString().trimmed()));
    q.bindValue(":heute", QDate::currentDate().toString(Qt::ISODate));
    q.bindValue(":id", befundId);
    if (!q.exec()) {
        qCWarning(lcDb) << "befundAendern:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVariantList Database::befundeLaden(int projektId, const QString &status, int seiteId)
{
    QVariantList result;
    QString sql = R"(
        SELECT id, befund_uuid, bezug_art, seite_id, anlage, ort, blattnummer, bmk, kabel_bezeichnung, x, y,
               kategorie, text, status, gefunden_von, gefunden_am, behoben_am, geaendert_am, kopie_uuid
        FROM fs_befund WHERE projekt_id = :pid
    )";
    if (status == QLatin1String("aktiv"))      sql += " AND status = 'offen'";
    else if (!status.isEmpty())                sql += " AND status = :st";
    if (seiteId >= 0)                          sql += " AND seite_id = :sid";
    sql += " ORDER BY geaendert_am DESC, id DESC";
    QSqlQuery q(m_db);
    q.prepare(sql);
    q.bindValue(":pid", projektId);
    if (!status.isEmpty() && status != QLatin1String("aktiv")) q.bindValue(":st", status);
    if (seiteId >= 0) q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "befundeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "id",              q.value(0) },
            { "befundUuid",      q.value(1) },
            { "bezugArt",        q.value(2) },
            { "seiteId",         q.value(3).isNull() ? QVariant(-1) : q.value(3) },
            { "zugeordnet",      !q.value(3).isNull() || q.value(2).toString() == "kabel" },
            { "anlage",          q.value(4) },
            { "ort",             q.value(5) },
            { "blattnummer",     q.value(6) },
            { "bmk",             q.value(7) },
            { "kabelBezeichnung",q.value(8) },
            { "x",               q.value(9) },
            { "y",               q.value(10) },
            { "hatPosition",     !q.value(9).isNull() && !q.value(10).isNull() },
            { "kategorie",       q.value(11) },
            { "text",            q.value(12) },
            { "status",          q.value(13) },
            { "gefundenVon",     q.value(14) },
            { "gefundenAm",      q.value(15) },
            { "behobenAm",       q.value(16) },
            { "geaendertAm",     q.value(17) },
            { "kopieUuid",       q.value(18) },
        });
    }
    return result;
}

QVariantMap Database::befundOffenProBmk(int projektId)
{
    QVariantMap m;
    QSqlQuery q(m_db);
    q.prepare("SELECT bmk, COUNT(*) FROM fs_befund WHERE projekt_id = :pid AND status = 'offen' AND bezug_art = 'bmk' AND bmk != '' GROUP BY bmk");
    q.bindValue(":pid", projektId);
    if (q.exec())
        while (q.next())
            m.insert(q.value(0).toString(), q.value(1).toInt());
    return m;
}

// FS-IBN-03: Import eines Befunds aus einem Overlay. Nur in der Hauptkopie (vom Import-Ablauf sichergestellt).
// neu = true: Befund mit dieser befund_uuid anlegen (Bezug und Herkunft wie im Overlay); sonst nur Inhalt aktualisieren.
// geaendert_am wird auf den Importzeitpunkt gesetzt, wie bei den IBN-Eintraegen.
bool Database::befundUebernehmen(int projektId, const QVariantMap &e, bool neu)
{
    const QString uuid = e.value("befundUuid").toString();
    const QString status = e.value("status").toString();
    const QString kategorie = e.value("kategorie").toString();
    const QString text = e.value("text").toString().trimmed();
    if (uuid.isEmpty() || text.isEmpty() || !kKategorien.contains(kategorie) || !kStati.contains(status))
        return false;

    QSqlQuery q(m_db);
    if (neu) {
        const QString art = e.value("bezugArt").toString();
        if (art != "bmk" && art != "kabel" && art != "stelle") return false;
        const int seiteId = e.value("seiteId", -1).toInt();
        const bool hatPos = e.value("hatPosition").toBool();
        q.prepare(R"(
            INSERT INTO fs_befund (projekt_id, befund_uuid, bezug_art, seite_id, anlage, ort, blattnummer, bmk, kabel_bezeichnung,
                                   x, y, kategorie, text, status, gefunden_von, gefunden_am, behoben_am, geaendert_am, kopie_uuid)
            VALUES (:pid, :uuid, :art, :sid, :an, :ort, :bl, :bmk, :kab, :x, :y, :kat, :txt, :st, :von, :am, :ba, datetime('now'), :kopie)
        )");
        q.bindValue(":pid", projektId);
        q.bindValue(":uuid", uuid);
        q.bindValue(":art", art);
        q.bindValue(":sid", seiteId >= 0 ? QVariant(seiteId) : QVariant(QMetaType(QMetaType::Int)));
        q.bindValue(":an", nn(e.value("anlage").toString()));
        q.bindValue(":ort", nn(e.value("ort").toString()));
        q.bindValue(":bl", nn(e.value("blattnummer").toString()));
        q.bindValue(":bmk", nn(e.value("bmk").toString()));
        q.bindValue(":kab", nn(e.value("kabelBezeichnung").toString()));
        q.bindValue(":x", hatPos ? QVariant(e.value("x").toDouble()) : QVariant(QMetaType(QMetaType::Double)));
        q.bindValue(":y", hatPos ? QVariant(e.value("y").toDouble()) : QVariant(QMetaType(QMetaType::Double)));
        q.bindValue(":kopie", nn(e.value("kopieUuid").toString()));
    } else {
        q.prepare(R"(
            UPDATE fs_befund
            SET kategorie = :kat, text = :txt, status = :st, gefunden_von = :von, gefunden_am = :am,
                behoben_am = :ba, geaendert_am = datetime('now')
            WHERE befund_uuid = :uuid AND projekt_id = :pid
        )");
        q.bindValue(":pid", projektId);
        q.bindValue(":uuid", uuid);
    }
    q.bindValue(":kat", kategorie);
    q.bindValue(":txt", text);
    q.bindValue(":st", status);
    q.bindValue(":von", nn(e.value("gefundenVon").toString()));
    q.bindValue(":am", nn(e.value("gefundenAm").toString()));
    q.bindValue(":ba", nn(e.value("behobenAm").toString()));
    if (!q.exec()) {
        qCWarning(lcDb) << "befundUebernehmen:" << q.lastError().text();
        return false;
    }
    return neu || q.numRowsAffected() > 0;
}
