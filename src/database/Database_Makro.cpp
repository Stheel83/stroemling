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

int Database::makroSpeichern(int grafikElementId, int seiteId)
{
    if (!m_makroDb.isOpen()) {
        qWarning() << "makroSpeichern: Makro-DB nicht geöffnet";
        return -1;
    }

    // Makrokasten-Geometrie aus Projekt-DB laden
    QSqlQuery qk(m_db);
    qk.prepare("SELECT x1, y1, x2, y2, extra_daten FROM grafik_element WHERE id = :id");
    qk.bindValue(":id", grafikElementId);
    if (!qk.exec() || !qk.next()) {
        qWarning() << "makroSpeichern: Kasten nicht gefunden" << grafikElementId;
        return -1;
    }
    const double kx1 = qk.value(0).toDouble();
    const double ky1 = qk.value(1).toDouble();
    const double kx2 = qk.value(2).toDouble();
    const double ky2 = qk.value(3).toDouble();
    const QString edJson = qk.value(4).toString();

    QJsonDocument edDoc  = QJsonDocument::fromJson(edJson.toUtf8());
    QJsonObject   ed     = edDoc.object();
    const QString name   = ed.value("name").toString("Makro");
    const QString beschr = ed.value("beschreibung").toString();
    const QString kat    = ed.value("kategorie").toString();
    const int existId    = ed.value("makroId").toInt(0);

    const double minX = std::min(kx1, kx2);
    const double minY = std::min(ky1, ky2);
    const double maxX = std::max(kx1, kx2);
    const double maxY = std::max(ky1, ky2);

    // Elemente aus Projekt-DB sammeln
    QSqlQuery qe(m_db);
    qe.prepare(R"(
        SELECT typ, x1, y1, x2, y2, extra_daten, symbol_id, sortierung
        FROM grafik_element
        WHERE seite_id = :sid
          AND id != :kid
          AND typ != 'makrokasten'
          AND (x1+x2)/2.0 BETWEEN :minx AND :maxx
          AND (y1+y2)/2.0 BETWEEN :miny AND :maxy
        ORDER BY sortierung
    )");
    qe.bindValue(":sid",  seiteId);
    qe.bindValue(":kid",  grafikElementId);
    qe.bindValue(":minx", minX);
    qe.bindValue(":maxx", maxX);
    qe.bindValue(":miny", minY);
    qe.bindValue(":maxy", maxY);
    if (!qe.exec()) {
        qWarning() << "makroSpeichern SELECT elemente:" << qe.lastError().text();
        return -1;
    }

    // Makro in Makro-DB schreiben (eigene Transaktion)
    if (!m_makroDb.transaction()) {
        qWarning() << "makroSpeichern: makroDb transaction fehlgeschlagen";
        return -1;
    }

    int makroId = existId;
    QSqlQuery qm(m_makroDb);

    if (makroId > 0) {
        qm.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k, "
                   "kasten_breite=:w, kasten_hoehe=:h WHERE id=:id");
        qm.bindValue(":n",  name);
        qm.bindValue(":b",  beschr);
        qm.bindValue(":k",  kat);
        qm.bindValue(":w",  maxX - minX);
        qm.bindValue(":h",  maxY - minY);
        qm.bindValue(":id", makroId);
        if (!qm.exec()) {
            qWarning() << "makroSpeichern UPDATE makro:" << qm.lastError().text();
            m_makroDb.rollback(); return -1;
        }
        QSqlQuery qdel(m_makroDb);
        qdel.prepare("DELETE FROM makro_element WHERE makro_id = :id");
        qdel.bindValue(":id", makroId);
        if (!qdel.exec()) {
            qWarning() << "makroSpeichern DELETE makro_element:" << qdel.lastError().text();
            m_makroDb.rollback(); return -1;
        }
    } else {
        qm.prepare("INSERT INTO makro (name, beschreibung, kategorie, kasten_breite, kasten_hoehe) "
                   "VALUES (:n, :b, :k, :w, :h)");
        qm.bindValue(":n",  name);
        qm.bindValue(":b",  beschr);
        qm.bindValue(":k",  kat);
        qm.bindValue(":w",  maxX - minX);
        qm.bindValue(":h",  maxY - minY);
        if (!qm.exec()) {
            qWarning() << "makroSpeichern INSERT makro:" << qm.lastError().text();
            m_makroDb.rollback(); return -1;
        }
        makroId = qm.lastInsertId().toInt();
    }

    QSqlQuery qi(m_makroDb);
    qi.prepare(R"(
        INSERT INTO makro_element (makro_id, typ, rel_x1, rel_y1, rel_x2, rel_y2,
                                   extra_daten, symbol_key, sortierung)
        VALUES (:mid, :typ, :rx1, :ry1, :rx2, :ry2, :ed, :sk, :sort)
    )");

    while (qe.next()) {
        qi.bindValue(":mid",  makroId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":rx1",  qe.value(1).toDouble() - minX);
        qi.bindValue(":ry1",  qe.value(2).toDouble() - minY);
        qi.bindValue(":rx2",  qe.value(3).toDouble() - minX);
        qi.bindValue(":ry2",  qe.value(4).toDouble() - minY);
        qi.bindValue(":ed",   qe.value(5));
        qi.bindValue(":sk",   qe.value(6));
        qi.bindValue(":sort", qe.value(7));
        if (!qi.exec()) {
            qWarning() << "makroSpeichern INSERT makro_element:" << qi.lastError().text();
            m_makroDb.rollback(); return -1;
        }
    }

    if (!m_makroDb.commit()) {
        qWarning() << "makroSpeichern: commit fehlgeschlagen";
        return -1;
    }

    // makroId in extra_daten des Kastens zurückschreiben (Projekt-DB)
    ed["makroId"] = makroId;
    QSqlQuery qu(m_db);
    qu.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    qu.bindValue(":ed", QString::fromUtf8(QJsonDocument(ed).toJson(QJsonDocument::Compact)));
    qu.bindValue(":id", grafikElementId);
    if (!qu.exec()) {
        qWarning() << "makroSpeichern UPDATE extra_daten:" << qu.lastError().text();
        return -1;
    }

    return makroId;
}

// ============================================================
// makroListe
// ============================================================
QVariantList Database::makroListe()
{
    QVariantList result;
    if (!m_makroDb.isOpen()) return result;
    QSqlQuery q(m_makroDb);
    q.exec(R"(
        SELECT m.id, m.name, m.beschreibung, m.kategorie,
               COUNT(me.id) AS element_anzahl
        FROM makro m
        LEFT JOIN makro_element me ON me.makro_id = m.id
        GROUP BY m.id
        ORDER BY m.kategorie, m.name
    )");
    while (q.next()) {
        QVariantMap row;
        row["id"]            = q.value(0).toInt();
        row["name"]          = q.value(1).toString();
        row["beschreibung"]  = q.value(2).toString();
        row["kategorie"]     = q.value(3).toString();
        row["elementAnzahl"] = q.value(4).toInt();
        result.append(row);
    }
    return result;
}

// ============================================================
// makroElementeEinfuegen
// ============================================================
QVariantList Database::makroElementeEinfuegen(int makroId, int seiteId,
                                               double offsetX, double offsetY)
{
    QVariantList newIds;
    if (!m_makroDb.isOpen()) {
        qWarning() << "makroElementeEinfuegen: Makro-DB nicht geöffnet";
        return newIds;
    }

    QSqlQuery qe(m_makroDb);
    qe.prepare(R"(
        SELECT typ, rel_x1, rel_y1, rel_x2, rel_y2, extra_daten, symbol_key, sortierung
        FROM makro_element WHERE makro_id = :mid ORDER BY sortierung
    )");
    qe.bindValue(":mid", makroId);
    if (!qe.exec()) {
        qWarning() << "makroElementeEinfuegen SELECT:" << qe.lastError().text();
        return newIds;
    }

    if (!m_db.transaction()) { qWarning() << "makroElementeEinfuegen: transaction"; return newIds; }

    QSqlQuery qi(m_db);
    qi.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
             sortierung, symbol_id, rotation, spiegel_x, spiegel_y, extra_daten)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             '#4a9eff', 1.5, 'solid',
             0, '#000000', 0.0, 1.0, 0,
             :sort, :sk, 0, 0, 0, :ed)
    )");

    while (qe.next()) {
        qi.bindValue(":sid",  seiteId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":x1",   qe.value(1).toDouble() + offsetX);
        qi.bindValue(":y1",   qe.value(2).toDouble() + offsetY);
        qi.bindValue(":x2",   qe.value(3).toDouble() + offsetX);
        qi.bindValue(":y2",   qe.value(4).toDouble() + offsetY);
        qi.bindValue(":ed",   qe.value(5));
        qi.bindValue(":sk",   qe.value(6));
        qi.bindValue(":sort", qe.value(7));
        if (!qi.exec()) {
            qWarning() << "makroElementeEinfuegen INSERT:" << qi.lastError().text();
            m_db.rollback(); return QVariantList();
        }
        newIds.append(qi.lastInsertId().toInt());
    }

    if (!m_db.commit()) { qWarning() << "makroElementeEinfuegen: commit"; return QVariantList(); }
    return newIds;
}

// ============================================================
// makroLoeschen
// ============================================================
bool Database::makroLoeschen(int makroId)
{
    if (!m_makroDb.isOpen()) return false;
    QSqlQuery q(m_makroDb);
    q.prepare("DELETE FROM makro WHERE id = :id");
    q.bindValue(":id", makroId);
    if (!q.exec()) {
        qWarning() << "makroLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// makroMetaAktualisieren
// ============================================================
bool Database::makroMetaAktualisieren(int makroId, const QString &name,
                                       const QString &beschreibung,
                                       const QString &kategorie)
{
    if (!m_makroDb.isOpen()) return false;
    QSqlQuery q(m_makroDb);
    q.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k WHERE id=:id");
    q.bindValue(":n",  name);
    q.bindValue(":b",  beschreibung);
    q.bindValue(":k",  kategorie);
    q.bindValue(":id", makroId);
    if (!q.exec()) {
        qWarning() << "makroMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Inbetriebnahme-Modus
// ============================================================
