#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QJsonDocument>
#include <QJsonObject>

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
                // Fallback für Schütz-/Relais-Kontakte: die haben kein
                // anschlusskennzeichnung (nur für geraeteanschluss/M5 gesetzt),
                // sondern eine pinBez-Karte (z.B. {"1":"13","2":"14"}) – daraus
                // eine Anzeige-Bezeichnung wie "13/14" bauen.
                if (anschlusskennzeichnung.isEmpty()) {
                    QJsonObject pinBez = obj.value(QStringLiteral("pinBez")).toObject();
                    if (!pinBez.isEmpty()) {
                        QStringList werte;
                        for (auto it = pinBez.constBegin(); it != pinBez.constEnd(); ++it)
                            werte << it.value().toString();
                        anschlusskennzeichnung = werte.join(QStringLiteral("/"));
                    }
                }
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
    q.prepare("SELECT id, betriebsmittel_kz, bezeichnung, haupt_element_id, ort_id "
              "FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (!q.exec() || !q.next()) return m;
    m[QStringLiteral("id")]             = q.value(0).toInt();
    m[QStringLiteral("kz")]             = q.value(1).toString();
    m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
    m[QStringLiteral("hauptElementId")] = q.value(3).isNull() ? 0 : q.value(3).toInt();
    m[QStringLiteral("ortId")]          = q.value(4).isNull() ? -1 : q.value(4).toInt();
    return m;
}

bool Database::betriebsmittelOrtSetzen(int betriebsmittelId, int ortId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE betriebsmittel SET ort_id = :oid WHERE id = :id");
    q.bindValue(":oid", ortId > 0 ? QVariant(ortId) : QVariant(QMetaType::fromType<int>()));
    q.bindValue(":id", betriebsmittelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "betriebsmittelOrtSetzen Fehler:" << q.lastError().text();
        return false;
    }
    return betriebsmittelBmkSynchronisieren(betriebsmittelId);
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
    QSqlQuery bmkQ(m_db);
    bmkQ.prepare("SELECT bmk_vollstaendig FROM betriebsmittel_bmk WHERE id = :id");
    bmkQ.bindValue(":id", betriebsmittelId);
    QString bmk;
    if (bmkQ.exec() && bmkQ.next())
        bmk = bmkQ.value(0).toString();
    else
        bmk = betriebsmittelKz(betriebsmittelId);
    if (bmk.isEmpty()) return false;

    QSqlQuery sel(m_db);
    sel.prepare("SELECT id, extra_daten FROM grafik_element WHERE betriebsmittel_id = :bid");
    sel.bindValue(":bid", betriebsmittelId);
    if (!sel.exec()) return false;

    QSqlQuery upd(m_db);
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
        obj[QStringLiteral("bmk")] = bmk;
        upd.bindValue(":ed", QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
        upd.bindValue(":id", gid);
        if (!upd.exec())
            qCWarning(lcDb) << "betriebsmittelBmkSynchronisieren Fehler Element" << gid << upd.lastError().text();
    }
    return true;
}

bool Database::grafikElementExtraMergeSetzen(int elementId, const QVariantMap& updates)
{
    QSqlQuery rd(m_db);
    rd.prepare("SELECT extra_daten FROM grafik_element WHERE id = :id");
    rd.bindValue(":id", elementId);
    if (!rd.exec() || !rd.next()) return false;

    QJsonObject ed;
    QString existing = rd.value(0).toString();
    if (!existing.isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(existing.toUtf8());
        if (doc.isObject()) ed = doc.object();
    }

    for (auto it = updates.cbegin(); it != updates.cend(); ++it) {
        const QVariant& v = it.value();
        if (!v.isValid() || v.isNull()) {
            ed[it.key()] = QJsonValue::Null;
            continue;
        }
        switch (v.typeId()) {
        case QMetaType::Bool:
            ed[it.key()] = v.toBool();
            break;
        // JS-Zahlenliterale aus QML (z.B. { ort_id: newOrtId }) kommen beim
        // QML→C++-Marshalling i.d.R. als QMetaType::Double an, nicht als
        // Int/LongLong (JS kennt nur einen Zahlentyp). Ohne diese Fälle
        // landete z.B. ort_id als String "42" statt Zahl 42 im JSON -
        // spätere strikte "==="-Vergleiche in QML (z.B. gkSetFromOrtId())
        // gegen echte Zahlen schlugen dadurch immer fehl (GK-SK-ORT-TYP-01).
        case QMetaType::Int:
        case QMetaType::UInt:
        case QMetaType::LongLong:
        case QMetaType::ULongLong:
        case QMetaType::Short:
        case QMetaType::UShort:
        case QMetaType::Double:
        case QMetaType::Float:
            ed[it.key()] = v.toDouble();
            break;
        default:
            ed[it.key()] = v.toString();
            break;
        }
    }

    QSqlQuery wr(m_db);
    wr.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    wr.bindValue(":ed", QJsonDocument(ed).toJson(QJsonDocument::Compact));
    wr.bindValue(":id", elementId);
    if (!wr.exec()) {
        qCWarning(lcDb) << "grafikElementExtraMergeSetzen Fehler:" << wr.lastError().text();
        return false;
    }
    return true;
}
