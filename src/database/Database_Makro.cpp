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
        qCWarning(lcDb) << "Makro-DB konnte nicht geöffnet werden:" << m_makroDb.lastError().text();
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
        qCWarning(lcDb) << "Makro-DB makro-Tabelle:" << q.lastError().text();
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
        qCWarning(lcDb) << "Makro-DB makro_element-Tabelle:" << q.lastError().text();
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

    // SCHRIFT-STRICH-01: Schriftgröße (Text/Notiz) lag bislang in strich_breite,
    // jetzt in extra_daten.schriftgroesse. Bestehende Makro-Elemente einmalig
    // migrieren (idempotent über die IS NULL-Bedingung, kein Versionszähler nötig).
    m_makroDb.exec(R"(
        UPDATE makro_element
        SET extra_daten = json_set(COALESCE(extra_daten, '{}'), '$.schriftgroesse', strich_breite)
        WHERE typ IN ('text', 'notiz')
          AND json_extract(COALESCE(extra_daten, '{}'), '$.schriftgroesse') IS NULL
    )");

    qCInfo(lcDb) << "Makro-DB geöffnet:" << path;
    return true;
}

#include <QDateTime>
#include <algorithm>

int Database::makroSpeichern(int grafikElementId, int seiteId)
{
    if (!m_makroDb.isOpen()) {
        qCWarning(lcDb) << "makroSpeichern: Makro-DB nicht geöffnet";
        return -1;
    }

    // Makrokasten-Geometrie aus Projekt-DB laden
    QSqlQuery qk(m_db);
    qk.prepare("SELECT x1, y1, x2, y2, extra_daten FROM grafik_element WHERE id = :id");
    qk.bindValue(":id", grafikElementId);
    if (!qk.exec() || !qk.next()) {
        qCWarning(lcDb) << "makroSpeichern: Kasten nicht gefunden" << grafikElementId;
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

    // Elemente aus Projekt-DB sammeln (inkl. Bauteil-Snapshot via LEFT JOIN)
    QSqlQuery qe(m_db);
    qe.prepare(R"(
        SELECT ge.typ, ge.x1, ge.y1, ge.x2, ge.y2, ge.extra_daten,
               ge.symbol_id, ge.sortierung,
               ge.rotation, ge.spiegel_x, ge.spiegel_y,
               ge.strich_farbe, ge.strich_breite, ge.strich_art,
               ge.fuell, ge.fuell_farbe, ge.fuell_opazitaet,
               ge.opazitaet, ge.ecken_radius,
               b.bezeichnung  AS bauteil_bezeichnung,
               b.hersteller   AS bauteil_hersteller,
               b.artikelnummer AS bauteil_artikelnummer
        FROM grafik_element ge
        LEFT JOIN betriebsmittel bm ON bm.id = ge.betriebsmittel_id
        LEFT JOIN bauteil b         ON b.id  = bm.bauteil_id
        WHERE ge.seite_id = :sid
          AND ge.id != :kid
          AND ge.typ != 'makrokasten'
          AND (ge.x1+ge.x2)/2.0 BETWEEN :minx AND :maxx
          AND (ge.y1+ge.y2)/2.0 BETWEEN :miny AND :maxy
        ORDER BY ge.sortierung
    )");
    qe.bindValue(":sid",  seiteId);
    qe.bindValue(":kid",  grafikElementId);
    qe.bindValue(":minx", minX);
    qe.bindValue(":maxx", maxX);
    qe.bindValue(":miny", minY);
    qe.bindValue(":maxy", maxY);
    if (!qe.exec()) {
        qCWarning(lcDb) << "makroSpeichern SELECT elemente:" << qe.lastError().text();
        return -1;
    }

    // Makro in Makro-DB schreiben (eigene Transaktion)
    if (!m_makroDb.transaction()) {
        qCWarning(lcDb) << "makroSpeichern: makroDb transaction fehlgeschlagen";
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
            qCWarning(lcDb) << "makroSpeichern UPDATE makro:" << qm.lastError().text();
            m_makroDb.rollback(); return -1;
        }
        QSqlQuery qdel(m_makroDb);
        qdel.prepare("DELETE FROM makro_element WHERE makro_id = :id");
        qdel.bindValue(":id", makroId);
        if (!qdel.exec()) {
            qCWarning(lcDb) << "makroSpeichern DELETE makro_element:" << qdel.lastError().text();
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
            qCWarning(lcDb) << "makroSpeichern INSERT makro:" << qm.lastError().text();
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
        // Bauteil-Snapshot in extra_daten einbetten (falls Bauteil verknüpft)
        const QString bauteilBezeich = qe.value(19).toString();
        QString edJson = qe.value(5).toString();
        if (!bauteilBezeich.isEmpty()) {
            QJsonObject edObj = QJsonDocument::fromJson(edJson.toUtf8()).object();
            QJsonObject snap;
            snap[QStringLiteral("bezeichnung")]   = bauteilBezeich;
            snap[QStringLiteral("hersteller")]    = qe.value(20).toString();
            snap[QStringLiteral("artikelnummer")] = qe.value(21).toString();
            edObj[QStringLiteral("bauteilSnapshot")] = snap;
            edJson = QString::fromUtf8(QJsonDocument(edObj).toJson(QJsonDocument::Compact));
        }

        qi.bindValue(":mid",  makroId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":rx1",  qe.value(1).toDouble() - minX);
        qi.bindValue(":ry1",  qe.value(2).toDouble() - minY);
        qi.bindValue(":rx2",  qe.value(3).toDouble() - minX);
        qi.bindValue(":ry2",  qe.value(4).toDouble() - minY);
        qi.bindValue(":ed",   edJson);
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
            qCWarning(lcDb) << "makroSpeichern INSERT makro_element:" << qi.lastError().text();
            m_makroDb.rollback(); return -1;
        }
    }

    if (!m_makroDb.commit()) {
        qCWarning(lcDb) << "makroSpeichern: commit fehlgeschlagen";
        return -1;
    }

    // makroId in extra_daten des Kastens zurückschreiben (Projekt-DB)
    ed["makroId"] = makroId;
    QSqlQuery qu(m_db);
    qu.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    qu.bindValue(":ed", QString::fromUtf8(QJsonDocument(ed).toJson(QJsonDocument::Compact)));
    qu.bindValue(":id", grafikElementId);
    if (!qu.exec()) {
        qCWarning(lcDb) << "makroSpeichern UPDATE extra_daten:" << qu.lastError().text();
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
        qCWarning(lcDb) << "makroElementeEinfuegen: Makro-DB nicht geöffnet";
        return newIds;
    }

    // projekt_id aus seite-Tabelle ermitteln (für betriebsmittel-Anlage)
    int projektId = -1;
    {
        QSqlQuery qs(m_db);
        qs.prepare("SELECT projekt_id FROM seite WHERE id = :sid");
        qs.bindValue(":sid", seiteId);
        if (qs.exec() && qs.next()) projektId = qs.value(0).toInt();
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
        qCWarning(lcDb) << "makroElementeEinfuegen SELECT:" << qe.lastError().text();
        return newIds;
    }

    if (!m_db.transaction()) { qCWarning(lcDb) << "makroElementeEinfuegen: transaction"; return newIds; }

    QSqlQuery qi(m_db);
    qi.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
             sortierung, symbol_id, rotation, spiegel_x, spiegel_y,
             extra_daten, betriebsmittel_id)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             :sf, :sb, :sa,
             :fl, :ff, :fo, :op, :er,
             :sort, :sk, :rot, :spx, :spy,
             :ed, :bmid)
    )");

    while (qe.next()) {
        QString edJson = qe.value(5).toString();
        QJsonObject edObj = QJsonDocument::fromJson(edJson.toUtf8()).object();

        // Bauteil-Snapshot verarbeiten: Bauteil finden oder anlegen, betriebsmittel erstellen
        QVariant bmId; // NULL by default
        const QJsonObject snap = edObj.value(QStringLiteral("bauteilSnapshot")).toObject();
        if (!snap.isEmpty() && projektId > 0) {
            const QString bezeichnung   = snap.value(QStringLiteral("bezeichnung")).toString();
            const QString hersteller    = snap.value(QStringLiteral("hersteller")).toString();
            const QString artikelnummer = snap.value(QStringLiteral("artikelnummer")).toString();

            int bauteilId = -1;
            if (!artikelnummer.isEmpty()) {
                QSqlQuery qb(m_db);
                qb.prepare("SELECT id FROM bauteil WHERE artikelnummer = :an LIMIT 1");
                qb.bindValue(":an", artikelnummer);
                if (qb.exec() && qb.next()) bauteilId = qb.value(0).toInt();
            }
            if (bauteilId < 0 && !bezeichnung.isEmpty()) {
                QSqlQuery qins(m_db);
                qins.prepare("INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer) "
                             "VALUES (:bez, :her, :art)");
                qins.bindValue(":bez", bezeichnung);
                qins.bindValue(":her", hersteller.isEmpty() ? QVariant() : QVariant(hersteller));
                qins.bindValue(":art", artikelnummer.isEmpty() ? QVariant() : QVariant(artikelnummer));
                if (qins.exec()) bauteilId = qins.lastInsertId().toInt();
                else qCWarning(lcDb) << "makroElementeEinfuegen INSERT bauteil:" << qins.lastError().text();
            }
            if (bauteilId > 0) {
                const QString bmk       = edObj.value(QStringLiteral("bmk")).toString();
                const QString symbolKey = qe.value(6).toString();
                QSqlQuery qbm(m_db);
                qbm.prepare("INSERT INTO betriebsmittel "
                            "(projekt_id, bauteil_id, betriebsmittel_kz, symbol_code) "
                            "VALUES (:pid, :bid, :kz, :sc)");
                qbm.bindValue(":pid", projektId);
                qbm.bindValue(":bid", bauteilId);
                qbm.bindValue(":kz",  bmk.isEmpty() ? QStringLiteral("?") : bmk);
                qbm.bindValue(":sc",  symbolKey.isEmpty() ? QVariant() : QVariant(symbolKey));
                if (qbm.exec()) bmId = qbm.lastInsertId().toInt();
                else qCWarning(lcDb) << "makroElementeEinfuegen INSERT betriebsmittel:" << qbm.lastError().text();
            }
            // Snapshot aus extra_daten entfernen (projekt-intern, nicht persistieren)
            edObj.remove(QStringLiteral("bauteilSnapshot"));
            edJson = QString::fromUtf8(QJsonDocument(edObj).toJson(QJsonDocument::Compact));
        }

        qi.bindValue(":sid",  seiteId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":x1",   qe.value(1).toDouble() + offsetX);
        qi.bindValue(":y1",   qe.value(2).toDouble() + offsetY);
        qi.bindValue(":x2",   qe.value(3).toDouble() + offsetX);
        qi.bindValue(":y2",   qe.value(4).toDouble() + offsetY);
        qi.bindValue(":ed",   edJson);
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
        qi.bindValue(":bmid", bmId);
        if (!qi.exec()) {
            qCWarning(lcDb) << "makroElementeEinfuegen INSERT:" << qi.lastError().text();
            m_db.rollback(); return QVariantList();
        }
        newIds.append(qi.lastInsertId().toInt());
    }

    if (!m_db.commit()) { qCWarning(lcDb) << "makroElementeEinfuegen: commit"; return QVariantList(); }
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
        qCWarning(lcDb) << "makroLoeschen:" << q.lastError().text();
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
        qCWarning(lcDb) << "makroMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Inbetriebnahme-Modus
// ============================================================
