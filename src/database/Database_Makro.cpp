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

bool Database::openMakro(const QString &path)
{
    m_makroPfad = path;
    m_makroDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_makro");
    m_makroDb.setDatabaseName(path);
    if (!m_makroDb.open()) {
        qWarning() << "Makro-DB konnte nicht geöffnet werden:" << m_makroDb.lastError().text();
        return false;
    }
    QSqlQuery q(m_makroDb);
    q.exec("PRAGMA journal_mode = WAL");
    q.exec("PRAGMA busy_timeout = 5000");
    q.exec("PRAGMA foreign_keys = ON");

    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS makro (
        id            INTEGER PRIMARY KEY,
        name          TEXT    NOT NULL,
        beschreibung  TEXT    DEFAULT '',
        kategorie     TEXT    DEFAULT '',
        kasten_breite REAL    NOT NULL DEFAULT 100,
        kasten_hoehe  REAL    NOT NULL DEFAULT 100,
        erstellt_am   TEXT    DEFAULT (datetime('now'))
    ))")) {
        qWarning() << "Makro-DB makro-Tabelle:" << q.lastError().text();
        return false;
    }
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS makro_element (
        id          INTEGER PRIMARY KEY,
        makro_id    INTEGER NOT NULL REFERENCES makro(id) ON DELETE CASCADE,
        typ         TEXT    NOT NULL,
        rel_x1      REAL    NOT NULL,
        rel_y1      REAL    NOT NULL,
        rel_x2      REAL    NOT NULL DEFAULT 0,
        rel_y2      REAL    NOT NULL DEFAULT 0,
        extra_daten TEXT    DEFAULT '{}',
        symbol_key  TEXT    DEFAULT '',
        sortierung  INTEGER DEFAULT 0
    ))")) {
        qWarning() << "Makro-DB makro_element-Tabelle:" << q.lastError().text();
        return false;
    }

    // Fehlende Spalten nachrüsten (silent falls schon vorhanden)
    {
        QSqlQuery qc(m_makroDb);
        qc.exec("PRAGMA table_info(makro_element)");
        QSet<QString> cols;
        while (qc.next()) cols.insert(qc.value(1).toString());
        if (!cols.contains("rotation"))       m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN rotation       REAL    DEFAULT 0");
        if (!cols.contains("spiegel_x"))      m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN spiegel_x      INTEGER DEFAULT 0");
        if (!cols.contains("spiegel_y"))      m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN spiegel_y      INTEGER DEFAULT 0");
        if (!cols.contains("strich_farbe"))   m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN strich_farbe   TEXT    DEFAULT '#4a9eff'");
        if (!cols.contains("strich_breite"))  m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN strich_breite  REAL    DEFAULT 1.5");
        if (!cols.contains("strich_art"))     m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN strich_art     TEXT    DEFAULT 'solid'");
        if (!cols.contains("fuell"))          m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN fuell          INTEGER DEFAULT 0");
        if (!cols.contains("fuell_farbe"))    m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN fuell_farbe    TEXT    DEFAULT '#000000'");
        if (!cols.contains("fuell_opazitaet"))m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN fuell_opazitaet REAL   DEFAULT 0.0");
        if (!cols.contains("opazitaet"))      m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN opazitaet      REAL    DEFAULT 1.0");
        if (!cols.contains("ecken_radius"))   m_makroDb.exec("ALTER TABLE makro_element ADD COLUMN ecken_radius   REAL    DEFAULT 0");
    }

    qInfo() << "Makro-DB geöffnet:" << path;
    return true;
}

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
        SELECT typ, x1, y1, x2, y2, extra_daten, symbol_id, sortierung,
               rotation, spiegel_x, spiegel_y,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius
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
                                   extra_daten, symbol_key, sortierung,
                                   rotation, spiegel_x, spiegel_y,
                                   strich_farbe, strich_breite, strich_art,
                                   fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius)
        VALUES (:mid, :typ, :rx1, :ry1, :rx2, :ry2, :ed, :sk, :sort,
                :rot, :spx, :spy,
                :sf, :sb, :sa, :fl, :ff, :fo, :op, :er)
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
        qi.bindValue(":rot",  qe.value(8));
        qi.bindValue(":spx",  qe.value(9));
        qi.bindValue(":spy",  qe.value(10));
        qi.bindValue(":sf",   qe.value(11));
        qi.bindValue(":sb",   qe.value(12));
        qi.bindValue(":sa",   qe.value(13));
        qi.bindValue(":fl",   qe.value(14));
        qi.bindValue(":ff",   qe.value(15));
        qi.bindValue(":fo",   qe.value(16));
        qi.bindValue(":op",   qe.value(17));
        qi.bindValue(":er",   qe.value(18));
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
               COUNT(me.id) AS element_anzahl,
               m.kasten_breite, m.kasten_hoehe
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
        row["kastenBreite"]  = q.value(5).toDouble();
        row["kastenHoehe"]   = q.value(6).toDouble();
        result.append(row);
    }
    return result;
}

// ============================================================
// makroElementeVorschau
// Liefert alle Renderfelder aller Elemente eines Makros mit relativen
// Koordinaten – nur zum Rendern einer Platzier-Vorschau.
// ============================================================
QVariantList Database::makroElementeVorschau(int makroId)
{
    QVariantList result;
    if (!m_makroDb.isOpen()) return result;
    QSqlQuery q(m_makroDb);
    q.prepare(R"(
        SELECT typ, rel_x1, rel_y1, rel_x2, rel_y2,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet,
               opazitaet, ecken_radius,
               rotation, spiegel_x, spiegel_y,
               symbol_key, extra_daten
        FROM makro_element WHERE makro_id = :mid ORDER BY sortierung
    )");
    q.bindValue(":mid", makroId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("typ")]            = q.value(0).toString();
        m[QStringLiteral("x1")]             = q.value(1).toDouble();
        m[QStringLiteral("y1")]             = q.value(2).toDouble();
        m[QStringLiteral("x2")]             = q.value(3).toDouble();
        m[QStringLiteral("y2")]             = q.value(4).toDouble();
        m[QStringLiteral("strichFarbe")]    = q.value(5).toString();
        m[QStringLiteral("strichBreite")]   = q.value(6).toDouble();
        m[QStringLiteral("strichArt")]      = q.value(7).toString();
        m[QStringLiteral("fuell")]          = q.value(8).toBool();
        m[QStringLiteral("fuellFarbe")]     = q.value(9).toString();
        m[QStringLiteral("fuellOpazitaet")] = q.value(10).toDouble();
        m[QStringLiteral("opazitaet")]      = q.value(11).toDouble();
        m[QStringLiteral("eckenRadius")]    = q.value(12).toDouble();
        m[QStringLiteral("rotation")]       = q.value(13).toDouble();
        m[QStringLiteral("spiegelX")]       = q.value(14).toBool();
        m[QStringLiteral("spiegelY")]       = q.value(15).toBool();
        m[QStringLiteral("symbolId")]       = q.value(16).toString();
        QJsonDocument edDoc = QJsonDocument::fromJson(q.value(17).toString().toUtf8());
        m[QStringLiteral("extraDaten")]     = edDoc.object().toVariantMap();
        result.append(m);
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
        SELECT typ, rel_x1, rel_y1, rel_x2, rel_y2, extra_daten, symbol_key, sortierung,
               rotation, spiegel_x, spiegel_y,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius
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
             :sf, :sb, :sa,
             :fl, :ff, :fo, :op, :er,
             :sort, :sk, :rot, :spx, :spy, :ed)
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
        qi.bindValue(":rot",  qe.value(8));
        qi.bindValue(":spx",  qe.value(9));
        qi.bindValue(":spy",  qe.value(10));
        qi.bindValue(":sf",   qe.value(11));
        qi.bindValue(":sb",   qe.value(12));
        qi.bindValue(":sa",   qe.value(13));
        qi.bindValue(":fl",   qe.value(14));
        qi.bindValue(":ff",   qe.value(15));
        qi.bindValue(":fo",   qe.value(16));
        qi.bindValue(":op",   qe.value(17));
        qi.bindValue(":er",   qe.value(18));
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
