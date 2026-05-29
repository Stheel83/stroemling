#include "KabelModel.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

KabelModel::KabelModel(QObject *parent)
    : QObject(parent)
{
}

void KabelModel::laden(int bauteilId)
{
    m_bauteilId  = bauteilId;
    m_kabelId    = -1;
    m_stammdaten = {};
    m_adern      = {};
    m_paare      = {};

    if (bauteilId <= 0) {
        emit geladen();
        return;
    }

    QSqlQuery q;
    q.prepare("SELECT id, kabeltyp, geschirmt, "
              "paarweise_verdrillt, aussenmantel_farbe, "
              "aussenmantel_mm, material_leiter, material_isolierung "
              "FROM bauteil_kabel WHERE bauteil_id = :bid LIMIT 1");
    q.bindValue(":bid", bauteilId);

    if (!q.exec() || !q.next()) {
        emit geladen();
        return;
    }

    m_kabelId = q.value(0).toInt();
    m_stammdaten = {
        { "id",                  m_kabelId              },
        { "kabeltyp",            q.value(1).toString()  },
        { "geschirmt",           q.value(2).toBool()    },
        { "paarweise_verdrillt", q.value(3).toBool()    },
        { "aussenmantel_farbe",  q.value(4).toString()  },
        { "aussenmantel_mm",     q.value(5).toDouble()  },
        { "material_leiter",     q.value(6).toString()  },
        { "material_isolierung", q.value(7).toString()  },
    };

    ladeAdern();
    ladePaare();
    emit geladen();
}

void KabelModel::ladeAdern()
{
    m_adern.clear();
    if (m_kabelId < 0) return;

    QSqlQuery q;
    q.prepare("SELECT id, ader_nr, farbe, nummer, bezeichnung, querschnitt_mm2 "
              "FROM bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr");
    q.bindValue(":kid", m_kabelId);
    if (!q.exec()) {
        qWarning() << "KabelModel::ladeAdern:" << q.lastError().text();
        return;
    }
    while (q.next()) {
        m_adern.append(QVariantMap{
            { "id",             q.value(0).toInt()    },
            { "aderNr",         q.value(1).toInt()    },
            { "farbe",          q.value(2).toString() },
            { "nummer",         q.value(3).toString() },
            { "bezeichnung",    q.value(4).toString() },
            { "querschnittMm2", q.value(5).toDouble() },
        });
    }
}

void KabelModel::ladePaare()
{
    m_paare.clear();
    if (m_kabelId < 0) return;

    QSqlQuery q;
    q.prepare("SELECT id, paar_nr, ader_a, ader_b "
              "FROM bauteil_kabel_paar WHERE kabel_id = :kid ORDER BY paar_nr");
    q.bindValue(":kid", m_kabelId);
    if (!q.exec()) {
        qWarning() << "KabelModel::ladePaare:" << q.lastError().text();
        return;
    }
    while (q.next()) {
        m_paare.append(QVariantMap{
            { "id",     q.value(0).toInt() },
            { "paarNr", q.value(1).toInt() },
            { "aderA",  q.value(2).toInt() },
            { "aderB",  q.value(3).toInt() },
        });
    }
}

bool KabelModel::stammdatenSpeichern(const QVariantMap &daten)
{
    if (m_bauteilId <= 0) return false;

    QSqlQuery q;

    if (m_kabelId < 0) {
        // Noch kein Eintrag – anlegen
        q.prepare("INSERT INTO bauteil_kabel "
                  "(bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt, "
                  " aussenmantel_farbe, aussenmantel_mm, material_leiter, material_isolierung) "
                  "VALUES (:bid, :kt, :gs, :pv, :af, :am, :ml, :mi)");
    } else {
        q.prepare("UPDATE bauteil_kabel SET "
                  "kabeltyp = :kt, geschirmt = :gs, paarweise_verdrillt = :pv, "
                  "aussenmantel_farbe = :af, aussenmantel_mm = :am, "
                  "material_leiter = :ml, material_isolierung = :mi "
                  "WHERE id = :bid");  // :bid wird als kabelId verwendet
    }

    auto bindOpt = [&](const QString &key, const QString &placeholder) {
        QVariant v = daten.value(key);
        q.bindValue(placeholder, v.isNull() || v.toString().isEmpty() ? QVariant() : v);
    };

    if (m_kabelId < 0)
        q.bindValue(":bid", m_bauteilId);
    else
        q.bindValue(":bid", m_kabelId);

    q.bindValue(":kt", daten.value("kabeltyp").toString().trimmed());
    q.bindValue(":gs", daten.value("geschirmt").toBool() ? 1 : 0);
    q.bindValue(":pv", daten.value("paarweise_verdrillt").toBool() ? 1 : 0);
    bindOpt("aussenmantel_farbe",  ":af");
    bindOpt("aussenmantel_mm",     ":am");
    bindOpt("material_leiter",     ":ml");
    bindOpt("material_isolierung", ":mi");

    if (!q.exec()) {
        qWarning() << "KabelModel::stammdatenSpeichern:" << q.lastError().text();
        return false;
    }

    if (m_kabelId < 0) {
        m_kabelId = q.lastInsertId().toInt();
        qDebug() << "bauteil_kabel INSERT: bauteil_id=" << m_bauteilId
                 << "neueId=" << m_kabelId;
    }

    laden(m_bauteilId);
    return true;
}

bool KabelModel::kabelLoeschen()
{
    if (m_kabelId < 0) return false;

    QSqlQuery q;
    q.prepare("DELETE FROM bauteil_kabel WHERE id = :id");
    q.bindValue(":id", m_kabelId);
    if (!q.exec()) {
        qWarning() << "KabelModel::kabelLoeschen:" << q.lastError().text();
        return false;
    }
    laden(m_bauteilId);
    return true;
}

int KabelModel::aderAnlegen()
{
    if (m_kabelId < 0) return -1;

    QSqlQuery q;
    q.prepare("SELECT COALESCE(MAX(ader_nr), 0) + 1 FROM bauteil_kabel_ader WHERE kabel_id = :kid");
    q.bindValue(":kid", m_kabelId);
    int nextNr = (q.exec() && q.next()) ? q.value(0).toInt() : 1;

    q.prepare("INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr) VALUES (:kid, :nr)");
    q.bindValue(":kid", m_kabelId);
    q.bindValue(":nr",  nextNr);
    if (!q.exec()) {
        qWarning() << "KabelModel::aderAnlegen:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    ladeAdern();
    emit geladen();
    return newId;
}

bool KabelModel::aderLoeschen(int aderId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM bauteil_kabel_ader WHERE id = :id AND kabel_id = :kid");
    q.bindValue(":id",  aderId);
    q.bindValue(":kid", m_kabelId);
    if (!q.exec()) {
        qWarning() << "KabelModel::aderLoeschen:" << q.lastError().text();
        return false;
    }

    // ader_nr-Lücken schließen
    q.prepare("SELECT id FROM bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr");
    q.bindValue(":kid", m_kabelId);
    q.exec();
    int nr = 1;
    QList<int> ids;
    while (q.next()) ids.append(q.value(0).toInt());
    for (int id : ids) {
        QSqlQuery upd;
        upd.prepare("UPDATE bauteil_kabel_ader SET ader_nr = :nr WHERE id = :id");
        upd.bindValue(":nr", nr++);
        upd.bindValue(":id", id);
        upd.exec();
    }

    ladeAdern();
    emit geladen();
    return true;
}

bool KabelModel::aderAktualisieren(int aderId, const QVariantMap &daten)
{
    QSqlQuery q;
    q.prepare("UPDATE bauteil_kabel_ader SET "
              "farbe = :farbe, nummer = :nummer, bezeichnung = :bez, "
              "querschnitt_mm2 = :qs "
              "WHERE id = :id AND kabel_id = :kid");

    auto bindOpt = [&](const QString &key, const QString &placeholder) {
        QString v = daten.value(key).toString().trimmed();
        q.bindValue(placeholder, v.isEmpty() ? QVariant() : QVariant(v));
    };

    bindOpt("farbe",       ":farbe");
    bindOpt("nummer",      ":nummer");
    bindOpt("bezeichnung", ":bez");

    QVariant qs = daten.value("querschnitt_mm2");
    q.bindValue(":qs", (qs.isNull() || qs.toString().isEmpty()) ? QVariant() : qs);

    q.bindValue(":id",  aderId);
    q.bindValue(":kid", m_kabelId);

    if (!q.exec()) {
        qWarning() << "KabelModel::aderAktualisieren:" << q.lastError().text();
        return false;
    }
    ladeAdern();
    emit geladen();
    return true;
}

bool KabelModel::aderSchieben(int aderId, int richtung)
{
    int idx = -1;
    for (int i = 0; i < m_adern.size(); ++i) {
        if (m_adern[i].toMap()["id"].toInt() == aderId) { idx = i; break; }
    }
    if (idx < 0) return false;

    int tauschIdx = idx + richtung;
    if (tauschIdx < 0 || tauschIdx >= m_adern.size()) return false;

    int nrA  = m_adern[idx].toMap()["aderNr"].toInt();
    int nrB  = m_adern[tauschIdx].toMap()["aderNr"].toInt();
    int idB  = m_adern[tauschIdx].toMap()["id"].toInt();

    QSqlQuery q;
    q.prepare("UPDATE bauteil_kabel_ader SET ader_nr = -1 WHERE id = :id");
    q.bindValue(":id", aderId); q.exec();

    q.prepare("UPDATE bauteil_kabel_ader SET ader_nr = :nr WHERE id = :id");
    q.bindValue(":nr", nrA); q.bindValue(":id", idB); q.exec();

    q.prepare("UPDATE bauteil_kabel_ader SET ader_nr = :nr WHERE id = :id");
    q.bindValue(":nr", nrB); q.bindValue(":id", aderId); q.exec();

    ladeAdern();
    emit geladen();
    return true;
}

int KabelModel::paarAnlegen(int aderA, int aderB)
{
    if (m_kabelId < 0) return -1;

    QSqlQuery q;
    q.prepare("SELECT COALESCE(MAX(paar_nr), 0) + 1 FROM bauteil_kabel_paar WHERE kabel_id = :kid");
    q.bindValue(":kid", m_kabelId);
    int nextNr = (q.exec() && q.next()) ? q.value(0).toInt() : 1;

    q.prepare("INSERT INTO bauteil_kabel_paar (kabel_id, paar_nr, ader_a, ader_b) "
              "VALUES (:kid, :nr, :a, :b)");
    q.bindValue(":kid", m_kabelId);
    q.bindValue(":nr",  nextNr);
    q.bindValue(":a",   aderA);
    q.bindValue(":b",   aderB);
    if (!q.exec()) {
        qWarning() << "KabelModel::paarAnlegen:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    ladePaare();
    emit geladen();
    return newId;
}

bool KabelModel::paarLoeschen(int paarId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM bauteil_kabel_paar WHERE id = :id AND kabel_id = :kid");
    q.bindValue(":id",  paarId);
    q.bindValue(":kid", m_kabelId);
    if (!q.exec()) {
        qWarning() << "KabelModel::paarLoeschen:" << q.lastError().text();
        return false;
    }
    ladePaare();
    emit geladen();
    return true;
}

bool KabelModel::aderMehrfachAktualisieren(const QVariantList &ids, const QVariantMap &daten)
{
    if (ids.isEmpty() || m_kabelId < 0) return false;

    QString farbe = daten.value("farbe").toString().trimmed();
    QString bez   = daten.value("bezeichnung").toString().trimmed();
    QString qsStr = daten.value("querschnitt_mm2").toString().trimmed();

    QStringList setClauses;
    if (!farbe.isEmpty()) setClauses << QStringLiteral("farbe = :farbe");
    if (!bez.isEmpty())   setClauses << QStringLiteral("bezeichnung = :bez");
    if (!qsStr.isEmpty()) setClauses << QStringLiteral("querschnitt_mm2 = :qs");
    if (setClauses.isEmpty()) return true;

    QStringList ph;
    for (int i = 0; i < ids.size(); ++i)
        ph << QString(":id%1").arg(i);

    QString sql = QString(
        "UPDATE bauteil_kabel_ader SET %1 "
        "WHERE id IN (%2) AND kabel_id = :kid")
        .arg(setClauses.join(QStringLiteral(", ")), ph.join(QStringLiteral(", ")));

    QSqlQuery q;
    q.prepare(sql);
    if (!farbe.isEmpty()) q.bindValue(":farbe", farbe);
    if (!bez.isEmpty())   q.bindValue(":bez",   bez);
    if (!qsStr.isEmpty()) q.bindValue(":qs",    qsStr.toDouble());
    for (int i = 0; i < ids.size(); ++i)
        q.bindValue(QString(":id%1").arg(i), ids[i].toInt());
    q.bindValue(":kid", m_kabelId);

    if (!q.exec()) {
        qWarning() << "KabelModel::aderMehrfachAktualisieren:" << q.lastError().text();
        return false;
    }
    ladeAdern();
    emit geladen();
    return true;
}

bool KabelModel::paarAktualisieren(int paarId, int aderA, int aderB)
{
    QSqlQuery q;
    q.prepare("UPDATE bauteil_kabel_paar SET ader_a = :a, ader_b = :b "
              "WHERE id = :id AND kabel_id = :kid");
    q.bindValue(":a",   aderA);
    q.bindValue(":b",   aderB);
    q.bindValue(":id",  paarId);
    q.bindValue(":kid", m_kabelId);
    if (!q.exec()) {
        qWarning() << "KabelModel::paarAktualisieren:" << q.lastError().text();
        return false;
    }
    ladePaare();
    emit geladen();
    return true;
}
