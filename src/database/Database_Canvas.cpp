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
#include <QCryptographicHash>
#include <algorithm>

// MIME-Typ → Dateiendung für Canvas-Bilddateien in m_grafikBilderDir.
// Gegenstück zur MIME-Ableitung aus der Dateiendung in bildAlsDataUrl().
static QString _grafikBildExtensionFuerMime(const QString &mime)
{
    if (mime == QLatin1String("image/jpeg")) return QStringLiteral(".jpg");
    if (mime == QLatin1String("image/bmp"))  return QStringLiteral(".bmp");
    if (mime == QLatin1String("image/gif"))  return QStringLiteral(".gif");
    if (mime == QLatin1String("image/webp")) return QStringLiteral(".webp");
    return QStringLiteral(".png");
}

// ============================================================
// migriereGrafikBilderAufDateien (D-02, Migration v77)
// Lagert grafik_element.bild_daten (BLOB) in Dateien unter
// m_grafikBilderDir aus. Idempotent via PRAGMA table_info-Check:
// läuft bei frischen DBs (Spalte laut schema.sql schon final) als
// No-Op durch, bei Altdaten konvertiert sie und dropt die Spalte.
// ============================================================
bool Database::migriereGrafikBilderAufDateien()
{
    bool hatBildDaten = false, hatBildPfad = false;
    {
        QSqlQuery pragma(m_db);
        pragma.exec("PRAGMA table_info(grafik_element)");
        while (pragma.next()) {
            const QString col = pragma.value(1).toString();
            if (col == QLatin1String("bild_daten")) hatBildDaten = true;
            if (col == QLatin1String("bild_pfad"))  hatBildPfad  = true;
        }
    }

    if (!hatBildDaten)
        return true; // schon im finalen Zustand (frische DB über schema.sql)

    if (!hatBildPfad) {
        QSqlQuery alter(m_db);
        if (!alter.exec("ALTER TABLE grafik_element ADD COLUMN bild_pfad TEXT NOT NULL DEFAULT ''")) {
            qCWarning(lcDb) << "ALTER grafik_element ADD bild_pfad:" << alter.lastError().text();
            return false;
        }
    }

    QDir().mkpath(m_grafikBilderDir);

    QSqlQuery sel(m_db);
    sel.exec("SELECT id, bild_daten, bild_mime FROM grafik_element WHERE bild_pfad = '' AND bild_daten IS NOT NULL");
    while (sel.next()) {
        const int        elId  = sel.value(0).toInt();
        const QByteArray bytes = sel.value(1).toByteArray();
        const QString    mime  = sel.value(2).toString();
        if (bytes.isEmpty()) continue;

        const QString hash = QCryptographicHash::hash(bytes, QCryptographicHash::Sha1).toHex();
        const QString fn   = hash + _grafikBildExtensionFuerMime(mime);

        QFile f(m_grafikBilderDir + "/" + fn);
        if (!f.exists()) {
            if (!f.open(QIODevice::WriteOnly)) {
                qCWarning(lcDb) << "migriereGrafikBilderAufDateien: Datei nicht schreibbar:" << fn;
                continue;
            }
            f.write(bytes);
            f.close();
        }

        QSqlQuery upd(m_db);
        upd.prepare("UPDATE grafik_element SET bild_pfad = :p WHERE id = :id");
        upd.bindValue(":p",  fn);
        upd.bindValue(":id", elId);
        upd.exec();
    }

    QSqlQuery drop(m_db);
    if (!drop.exec("ALTER TABLE grafik_element DROP COLUMN bild_daten")) {
        qCWarning(lcDb) << "ALTER grafik_element DROP COLUMN bild_daten:" << drop.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::grafikLaden(int seiteId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, typ, x1, y1, x2, y2,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet,
               opazitaet, ecken_radius,
               symbol_id, rotation, spiegel_x, spiegel_y,
               punkte, text_inhalt, text_ausrichtung, text_einpassen,
               bild_pfad, bild_mime, extra_daten, betriebsmittel_id,
               gruppe_id
        FROM grafik_element
        WHERE seite_id = :sid
        ORDER BY sortierung
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "grafikLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap el;
        el[QStringLiteral("id")]             = q.value(0).toInt();
        el[QStringLiteral("typ")]            = q.value(1).toString();
        el[QStringLiteral("x1")]             = q.value(2).toDouble();
        el[QStringLiteral("y1")]             = q.value(3).toDouble();
        el[QStringLiteral("x2")]             = q.value(4).toDouble();
        el[QStringLiteral("y2")]             = q.value(5).toDouble();
        el[QStringLiteral("strichFarbe")]    = q.value(6).toString();
        el[QStringLiteral("strichBreite")]   = q.value(7).toDouble();
        el[QStringLiteral("strichArt")]      = q.value(8).toString();
        el[QStringLiteral("fuell")]          = q.value(9).toInt() != 0;
        el[QStringLiteral("fuellFarbe")]     = q.value(10).toString();
        el[QStringLiteral("fuellOpazitaet")] = q.value(11).toDouble();
        el[QStringLiteral("opazitaet")]      = q.value(12).toDouble();
        el[QStringLiteral("eckenRadius")]    = q.value(13).toDouble();
        el[QStringLiteral("symbolId")]       = q.value(14).toString();
        el[QStringLiteral("rotation")]       = q.value(15).toInt();
        el[QStringLiteral("spiegelX")]       = q.value(16).toInt() != 0;
        el[QStringLiteral("spiegelY")]       = q.value(17).toInt() != 0;

        // text_inhalt / text_ausrichtung / text_einpassen (für Text-Elemente)
        QString textInhalt = q.value(19).toString();
        if (!textInhalt.isEmpty())
            el[QStringLiteral("textInhalt")] = textInhalt;
        QString textAusrichtung = q.value(20).toString();
        el[QStringLiteral("textAusrichtung")] = textAusrichtung.isEmpty()
                                                ? QStringLiteral("links") : textAusrichtung;
        el[QStringLiteral("textEinpassen")] = q.value(21).toInt() != 0;

        // bild_pfad: Datei aus m_grafikBilderDir lesen + bild_mime → Base64-Data-URL für QML-Canvas
        QString bildPfad = q.value(22).toString();
        if (!bildPfad.isEmpty()) {
            QFile bf(m_grafikBilderDir + "/" + bildPfad);
            if (bf.open(QIODevice::ReadOnly)) {
                QByteArray bildBytes = bf.readAll();
                QString bildMime = q.value(23).toString();
                if (bildMime.isEmpty())
                    bildMime = QStringLiteral("image/png");
                el[QStringLiteral("bildDaten")] = QStringLiteral("data:") + bildMime
                    + QStringLiteral(";base64,")
                    + QString::fromLatin1(bildBytes.toBase64());
            } else {
                qCWarning(lcDb) << "grafikLaden: Bilddatei fehlt:" << bildPfad;
            }
        }

        // extra_daten: JSON → extraDaten-Map für symbol-spezifische Eigenschaften
        QString extraDatenStr = q.value(24).toString();
        if (!extraDatenStr.isEmpty()) {
            QJsonParseError jsonErr;
            QJsonDocument extraDoc = QJsonDocument::fromJson(extraDatenStr.toUtf8(), &jsonErr);
            if (!jsonErr.error && extraDoc.isObject())
                el[QStringLiteral("extraDaten")] = extraDoc.object().toVariantMap();
        }

        // betriebsmittel_id (Spalte 25) – nullable FK
        if (!q.value(25).isNull())
            el[QStringLiteral("betriebsmittelId")] = q.value(25).toInt();

        // gruppe_id (Spalte 26) – nullable
        if (!q.value(26).isNull())
            el[QStringLiteral("gruppeId")] = q.value(26).toInt();

        // punkte (für Leitung-Elemente als JSON gespeichert)
        QString punkteStr = q.value(18).toString();
        if (!punkteStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(punkteStr.toUtf8(), &err);
            if (!err.error && doc.isArray()) {
                QVariantList punkte;
                for (const QJsonValue &v : doc.array()) {
                    if (v.isObject()) {
                        QVariantMap p;
                        p[QStringLiteral("x")] = v[QStringLiteral("x")].toDouble();
                        p[QStringLiteral("y")] = v[QStringLiteral("y")].toDouble();
                        punkte.append(p);
                    }
                }
                el[QStringLiteral("punkte")] = punkte;
            }
        }

        result.append(el);
    }
    return result;
}

int Database::letzteGrafikElementId(int seiteId) const
{
    QSqlQuery q;
    q.prepare("SELECT MAX(id) FROM grafik_element WHERE seite_id = :sid");
    q.bindValue(":sid", seiteId);
    if (q.exec() && q.next() && !q.value(0).isNull())
        return q.value(0).toInt();
    return -1;
}

// ============================================================
// grafikSpeichern
// Ersetzt alle Grafik-Elemente einer Seite in einer Transaktion.
// ============================================================
bool Database::grafikSpeichern(int seiteId, const QVariantList &elemente)
{
    if (!m_db.transaction()) {
        auto msg = m_db.lastError().text();
        qCWarning(lcDb) << "grafikSpeichern: Transaktion:" << msg;
        emit dbFehler("Speichern fehlgeschlagen (Transaktion konnte nicht gestartet werden).\n" + msg);
        return false;
    }

    // Kabellinie-Ader-Zuordnungen vor dem DELETE sichern:
    // elementIndex → {kabelId, liste_ader_nummern}
    // Nach dem re-Insert werden die kabellinie_grafik_element_id-Werte wiederhergestellt.
    QMap<int, QPair<int, QList<int>>> kabelLinieAderMap;
    for (int i = 0; i < elemente.size(); i++) {
        const QVariantMap el = elemente.at(i).toMap();
        if (el.value(QStringLiteral("typ")).toString() != QLatin1String("kabellinie")) continue;
        int oldGeid  = el.value(QStringLiteral("id"), 0).toInt();
        if (oldGeid <= 0) continue;
        int kabelId  = el.value(QStringLiteral("extraDaten")).toMap()
                          .value(QStringLiteral("kabelId"), 0).toInt();
        if (kabelId <= 0) continue;
        QSqlQuery qa;
        qa.prepare("SELECT ader_nr FROM kabel_ader WHERE kabel_id=:kid AND kabellinie_grafik_element_id=:geid");
        qa.bindValue(":kid",  kabelId);
        qa.bindValue(":geid", oldGeid);
        QList<int> adern;
        if (qa.exec()) { while (qa.next()) adern.append(qa.value(0).toInt()); }
        if (!adern.isEmpty()) kabelLinieAderMap[i] = qMakePair(kabelId, adern);
    }

    // Betriebsmittel-Hauptfunktion vor dem DELETE sichern:
    // bmId → alter grafik_element.id (haupt_element_id)
    // Nach dem re-Insert wird haupt_element_id auf die neue ID umgeschrieben.
    QMap<int, int> bmHfOldElId;
    {
        QSqlQuery q;
        q.prepare("SELECT bm.id, bm.haupt_element_id "
                  "FROM betriebsmittel bm "
                  "JOIN grafik_element ge ON ge.id = bm.haupt_element_id "
                  "WHERE ge.seite_id = :sid");
        q.bindValue(":sid", seiteId);
        if (q.exec()) {
            while (q.next())
                bmHfOldElId[q.value(0).toInt()] = q.value(1).toInt();
        }
    }

    // SPS/PLS-Kanal-Zuweisung vor dem DELETE sichern (SPS-KANAL-RESAVE-01):
    // kanalId → alter grafik_element.id. sps_kanal.grafik_element_id hat
    // ON DELETE SET NULL - ohne dieses Nachziehen loescht das DELETE unten
    // JEDE bestehende Kanal-Zuweisung auf der Seite bei jedem Speichervorgang,
    // nicht nur bei einer inhaltlichen Aenderung.
    QMap<int, int> spsKanalOldElId;
    {
        QSqlQuery q;
        q.prepare("SELECT sk.id, sk.grafik_element_id "
                  "FROM sps_kanal sk "
                  "JOIN grafik_element ge ON ge.id = sk.grafik_element_id "
                  "WHERE ge.seite_id = :sid");
        q.bindValue(":sid", seiteId);
        if (q.exec()) {
            while (q.next())
                spsKanalOldElId[q.value(0).toInt()] = q.value(1).toInt();
        }
    }
    // Alter grafik_element.id → Neue ID (wird im INSERT-Loop befüllt)
    QMap<int, int> oldElIdToNewId;

    QSqlQuery qDel;
    qDel.prepare("DELETE FROM grafik_element WHERE seite_id = :sid");
    qDel.bindValue(":sid", seiteId);
    if (!qDel.exec()) {
        qCWarning(lcDb) << "grafikSpeichern delete:" << qDel.lastError().text();
        m_db.rollback(); return false;
    }

    QSqlQuery qIns;
    qIns.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet,
             opazitaet, ecken_radius, sortierung,
             symbol_id, rotation, spiegel_x, spiegel_y,
             punkte, text_inhalt, text_ausrichtung, text_einpassen,
             bild_pfad, bild_mime, extra_daten, betriebsmittel_id,
             gruppe_id, kabel_id)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             :sf, :sb, :sa, :fu, :ff, :fo, :op, :er, :sort,
             :symid, :rot, :spx, :spy,
             :punkte, :textinhalt, :textausrichtung, :texteinpassen,
             :bildpfad, :bildmime, :extradaten, :bmid,
             :gid, :kid)
    )");

    for (int i = 0; i < elemente.size(); i++) {
        const QVariantMap el = elemente.at(i).toMap();
        qIns.bindValue(":sid",  seiteId);
        qIns.bindValue(":typ",  el.value(QStringLiteral("typ")).toString());
        qIns.bindValue(":x1",   el.value(QStringLiteral("x1")).toDouble());
        qIns.bindValue(":y1",   el.value(QStringLiteral("y1")).toDouble());
        qIns.bindValue(":x2",   el.value(QStringLiteral("x2")).toDouble());
        qIns.bindValue(":y2",   el.value(QStringLiteral("y2")).toDouble());
        qIns.bindValue(":sf",   el.value(QStringLiteral("strichFarbe"),    QStringLiteral("#4a9eff")).toString());
        qIns.bindValue(":sb",   el.value(QStringLiteral("strichBreite"),   0.35).toDouble());
        qIns.bindValue(":sa",   el.value(QStringLiteral("strichArt"),      QStringLiteral("solid")).toString());
        qIns.bindValue(":fu",   el.value(QStringLiteral("fuell"),          false).toBool() ? 1 : 0);
        qIns.bindValue(":ff",   el.value(QStringLiteral("fuellFarbe"),     QStringLiteral("#1a3a6a")).toString());
        qIns.bindValue(":fo",   el.value(QStringLiteral("fuellOpazitaet"), 0.3).toDouble());
        qIns.bindValue(":op",   el.value(QStringLiteral("opazitaet"),      1.0).toDouble());
        qIns.bindValue(":er",   el.value(QStringLiteral("eckenRadius"),    0.0).toDouble());
        qIns.bindValue(":sort", i);
        qIns.bindValue(":symid", el.value(QStringLiteral("symbolId")).toString());
        qIns.bindValue(":rot",   el.value(QStringLiteral("rotation"),  0).toInt());
        qIns.bindValue(":spx",   el.value(QStringLiteral("spiegelX"),  false).toBool() ? 1 : 0);
        qIns.bindValue(":spy",   el.value(QStringLiteral("spiegelY"),  false).toBool() ? 1 : 0);

        // text_inhalt / text_ausrichtung / text_einpassen (für Text-Elemente)
        QVariant textInhaltVar = el.value(QStringLiteral("textInhalt"));
        if (textInhaltVar.isValid() && !textInhaltVar.isNull())
            qIns.bindValue(":textinhalt", textInhaltVar.toString());
        else
            qIns.bindValue(":textinhalt", QVariant(QMetaType::fromType<QString>()));
        qIns.bindValue(":textausrichtung",
                       el.value(QStringLiteral("textAusrichtung"), QStringLiteral("links")).toString());
        qIns.bindValue(":texteinpassen",
                       el.value(QStringLiteral("textEinpassen"), false).toBool() ? 1 : 0);

        // punkte als JSON serialisieren (nur für Leitungen)
        QVariant punkteVar = el.value(QStringLiteral("punkte"));
        if (punkteVar.isValid() && !punkteVar.isNull() && punkteVar.canConvert<QVariantList>()) {
            QVariantList punkte = punkteVar.toList();
            QJsonArray arr;
            for (const QVariant &pv : punkte) {
                QVariantMap pm = pv.toMap();
                QJsonObject obj;
                obj[QStringLiteral("x")] = pm.value(QStringLiteral("x")).toDouble();
                obj[QStringLiteral("y")] = pm.value(QStringLiteral("y")).toDouble();
                arr.append(obj);
            }
            qIns.bindValue(":punkte", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
        } else {
            qIns.bindValue(":punkte", QVariant(QMetaType::fromType<QString>()));
        }

        // bildDaten: Data-URL aus QML → Datei in m_grafikBilderDir (Dateiname = SHA-1-Hash
        // der Bytes, stabil über DELETE+INSERT-Saves hinweg, siehe Plan-Begründung D-02)
        QVariant bildDatenVar = el.value(QStringLiteral("bildDaten"));
        bool bildGesetzt = false;
        if (bildDatenVar.isValid() && !bildDatenVar.isNull()) {
            QString dataUrl = bildDatenVar.toString();
            // Format: "data:<mime>;base64,<daten>"
            if (dataUrl.startsWith(QLatin1String("data:"))) {
                int semiPos   = dataUrl.indexOf(QLatin1Char(';'), 5);
                int commaPos  = dataUrl.indexOf(QLatin1Char(','), semiPos + 1);
                if (semiPos > 0 && commaPos > 0) {
                    QString    mime     = dataUrl.mid(5, semiPos - 5);
                    QByteArray rawBytes = QByteArray::fromBase64(
                                             dataUrl.mid(commaPos + 1).toLatin1());
                    const QString hash = QCryptographicHash::hash(rawBytes, QCryptographicHash::Sha1).toHex();
                    const QString fn   = hash + _grafikBildExtensionFuerMime(mime);
                    QDir().mkpath(m_grafikBilderDir);
                    QFile bf(m_grafikBilderDir + "/" + fn);
                    if (!bf.exists()) {
                        if (bf.open(QIODevice::WriteOnly)) {
                            bf.write(rawBytes);
                            bf.close();
                        }
                    }
                    qIns.bindValue(":bildpfad", fn);
                    qIns.bindValue(":bildmime", mime);
                    bildGesetzt = true;
                }
            }
        }
        if (!bildGesetzt) {
            qIns.bindValue(":bildpfad", QStringLiteral(""));
            qIns.bindValue(":bildmime", QVariant(QMetaType::fromType<QString>()));
        }

        // extra_daten: extraDaten-Map + bild-spezifische Felder als kompaktes JSON
        QVariant extraVar = el.value(QStringLiteral("extraDaten"));
        QVariantMap extraMap = (extraVar.isValid() && extraVar.canConvert<QVariantMap>())
                               ? extraVar.toMap() : QVariantMap{};
        if (el.value(QStringLiteral("proportional"), false).toBool())
            extraMap[QStringLiteral("proportional")] = true;
        auto packDouble = [&](const QString &key) {
            double v = el.value(key, 0.0).toDouble();
            if (v != 0.0) extraMap[key] = v;
        };
        packDouble(QStringLiteral("ausschnittLinks"));
        packDouble(QStringLiteral("ausschnittRechts"));
        packDouble(QStringLiteral("ausschnittOben"));
        packDouble(QStringLiteral("ausschnittUnten"));
        if (!extraMap.isEmpty()) {
            QJsonObject obj;
            for (auto it = extraMap.constBegin(); it != extraMap.constEnd(); ++it)
                obj.insert(it.key(), QJsonValue::fromVariant(it.value()));
            qIns.bindValue(":extradaten",
                QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
        } else {
            qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
        }

        // betriebsmittel_id (nullable FK)
        QVariant bmidVar = el.value(QStringLiteral("betriebsmittelId"));
        if (bmidVar.isValid() && !bmidVar.isNull() && bmidVar.toInt() > 0)
            qIns.bindValue(":bmid", bmidVar.toInt());
        else
            qIns.bindValue(":bmid", QVariant(QMetaType::fromType<int>()));

        // gruppe_id (nullable)
        int gid = el.value(QStringLiteral("gruppeId"), -1).toInt();
        if (gid >= 0)
            qIns.bindValue(":gid", gid);
        else
            qIns.bindValue(":gid", QVariant(QMetaType::fromType<int>()));

        // KABEL-UEBERARBEITUNG-01 Punkt 3: kabel_id (nullable FK, nur für
        // typ='kabellinie' gesetzt) direkt aus extraMap.kabelId — dieselbe
        // Quelle, die extra_daten.kabelId weiter unten befüllt, hier aber
        // als echte, indizierbare Spalte statt reiner JSON-Konvention.
        // Kein Nachzieh-Schritt nötig (anders als kabel.grafik_element_id/
        // kabel_ader.kabellinie_grafik_element_id, die eine sich ändernde
        // grafik_element.id referenzieren) — die Quelle steht hier schon
        // fest, bevor diese Zeile überhaupt eingefügt wird.
        //
        // Existenzprüfung: elementeFuerExportSanitisieren() (Database_
        // Zwischenablage.cpp) lässt extraDaten.kabelId beim Cross-Projekt-
        // Einfügen bewusst ungesäubert stehen (dokumentierte, bisher
        // harmlose Lücke, da nur JSON). Mit einer echten FK-Spalte würde
        // dieselbe Lücke bei aktivierten Foreign Keys das komplette
        // grafikSpeichern() der Seite zum Scheitern bringen (Transaktion
        // rollt bei einer einzigen ungültigen Referenz komplett zurück),
        // statt weiterhin nur "kein Link" zu ergeben. Daher hier prüfen,
        // ob die kabelId in DIESEM Projekt wirklich existiert, bevor sie
        // gebunden wird — sonst NULL, wie es die bisherige Lücke ohnehin
        // schon faktisch bedeutete.
        int kabelIdCol = extraMap.value(QStringLiteral("kabelId"), 0).toInt();
        if (kabelIdCol > 0) {
            QSqlQuery qKabelCheck;
            qKabelCheck.prepare("SELECT 1 FROM kabel WHERE id = :kid");
            qKabelCheck.bindValue(":kid", kabelIdCol);
            if (qKabelCheck.exec() && qKabelCheck.next())
                qIns.bindValue(":kid", kabelIdCol);
            else
                qIns.bindValue(":kid", QVariant(QMetaType::fromType<int>()));
        } else {
            qIns.bindValue(":kid", QVariant(QMetaType::fromType<int>()));
        }

        if (!qIns.exec()) {
            qCWarning(lcDb) << "grafikSpeichern insert:" << qIns.lastError().text();
            m_db.rollback(); return false;
        }

        // Alte → neue Element-ID tracken (für HF-Wiederherstellung)
        {
            int oldId = el.value(QStringLiteral("id"), 0).toInt();
            if (oldId > 0)
                oldElIdToNewId[oldId] = qIns.lastInsertId().toInt();
        }

        // Kabellinie: kabel.grafik_element_id + kabel_ader.kabellinie_grafik_element_id
        // nach re-Insert auf neue ID aktualisieren.
        if (el.value(QStringLiteral("typ")).toString() == QLatin1String("kabellinie")) {
            QVariant extraVar2 = el.value(QStringLiteral("extraDaten"));
            if (extraVar2.isValid() && extraVar2.canConvert<QVariantMap>()) {
                int kabelId = extraVar2.toMap().value(QStringLiteral("kabelId"), 0).toInt();
                if (kabelId > 0) {
                    int newGeid = qIns.lastInsertId().toInt();
                    QSqlQuery upd;
                    upd.prepare("UPDATE kabel SET grafik_element_id = :geid WHERE id = :kid");
                    upd.bindValue(":geid", newGeid);
                    upd.bindValue(":kid",  kabelId);
                    if (!upd.exec())
                        qCWarning(lcDb) << "grafikSpeichern kabel relink:" << upd.lastError().text();

                    // Ader-Linie-Zuordnungen wiederherstellen
                    if (kabelLinieAderMap.contains(i)) {
                        const QList<int> &adern = kabelLinieAderMap[i].second;
                        for (int aderNr : adern) {
                            QSqlQuery upd2;
                            upd2.prepare(R"(
                                UPDATE kabel_ader SET kabellinie_grafik_element_id=:geid
                                WHERE kabel_id=:kid AND ader_nr=:nr
                            )");
                            upd2.bindValue(":geid", newGeid);
                            upd2.bindValue(":kid",  kabelId);
                            upd2.bindValue(":nr",   aderNr);
                            if (!upd2.exec())
                                qCWarning(lcDb) << "grafikSpeichern ader relink:" << upd2.lastError().text();
                        }
                    }
                }
            }
        }
    }

    // Betriebsmittel-Hauptfunktion wiederherstellen: haupt_element_id auf neue IDs umschreiben
    for (auto it = bmHfOldElId.constBegin(); it != bmHfOldElId.constEnd(); ++it) {
        int newElId = oldElIdToNewId.value(it.value(), -1);
        if (newElId <= 0) continue;
        QSqlQuery qHf;
        qHf.prepare("UPDATE betriebsmittel SET haupt_element_id = :eid WHERE id = :bmid");
        qHf.bindValue(":eid",  newElId);
        qHf.bindValue(":bmid", it.key());
        if (!qHf.exec())
            qCWarning(lcDb) << "grafikSpeichern hf relink:" << qHf.lastError().text();
    }

    // SPS/PLS-Kanal-Zuweisung wiederherstellen (SPS-KANAL-RESAVE-01):
    // grafik_element_id auf neue IDs umschreiben
    for (auto it = spsKanalOldElId.constBegin(); it != spsKanalOldElId.constEnd(); ++it) {
        int newElId = oldElIdToNewId.value(it.value(), -1);
        if (newElId <= 0) continue;
        QSqlQuery qSps;
        qSps.prepare("UPDATE sps_kanal SET grafik_element_id = :eid WHERE id = :kid");
        qSps.bindValue(":eid", newElId);
        qSps.bindValue(":kid", it.key());
        if (!qSps.exec())
            qCWarning(lcDb) << "grafikSpeichern sps_kanal relink:" << qSps.lastError().text();
    }

    if (!m_db.commit()) {
        auto msg = m_db.lastError().text();
        qCWarning(lcDb) << "grafikSpeichern commit:" << msg;
        m_db.rollback();
        emit dbFehler("Speichern fehlgeschlagen (Commit nicht möglich). Änderungen dieser Aktion "
                      "wurden zurückgerollt.\n" + msg);
        return false;
    }
    return true;
}

// ============================================================
// bildAlsDataUrl
// Liest eine Bilddatei ein, prüft die Größe und gibt eine
// Base64-Data-URL zurück (z. B. "data:image/png;base64,...").
// Diese Data-URL wird in QML für Canvas-Vorschau und In-Memory-
// Darstellung genutzt. Beim Speichern (grafikSpeichern) wird die
// Data-URL serverseitig dekodiert: MIME und Rohdaten werden getrennt
// als TEXT bzw. BLOB in der Datenbank abgelegt.
// Bei Fehler wird "error:<Meldung>" zurückgegeben.
// ============================================================
QString Database::bildAlsDataUrl(const QString &pfad, qint64 maxBytes)
{
    // URL-Schema entfernen falls übergeben (file:///path → /path)
    QUrl url(pfad);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;

    QFileInfo info(localPath);
    if (!info.exists())
        return QStringLiteral("error:Datei nicht gefunden");

    if (info.size() > maxBytes)
        return QStringLiteral("error:Datei zu groß (max. %1 MB)")
               .arg(maxBytes / (1024 * 1024));

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly))
        return QStringLiteral("error:Datei konnte nicht geöffnet werden");

    QByteArray data = file.readAll();
    file.close();

    // MIME-Typ aus Dateiendung ableiten
    QString suffix = info.suffix().toLower();
    QString mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg")  || suffix == QLatin1String("jpeg"))
        mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))
        mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))
        mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("svg"))
        mime = QStringLiteral("image/svg+xml");
    else if (suffix == QLatin1String("webp"))
        mime = QStringLiteral("image/webp");

    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

// ============================================================
// naechsteBmkNummer
// Durchsucht alle grafik_element.extra_daten im Projekt nach
// vorhandenen BMK-Werten mit dem gegebenen Präfix (z.B. "-K")
// und gibt den ersten freien Wert zurück (z.B. "-K3").
// Präfix muss die Kennbuchstaben enthalten, z.B. "-K", "-M", "-F".
// ============================================================
QString Database::naechsteBmkNummer(int projektId, const QString &praefix)
{
    if (praefix.isEmpty())
        return praefix + QStringLiteral("1");

    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.extra_daten
        FROM grafik_element ge
        JOIN seite   s ON s.id = ge.seite_id
        JOIN ort     o ON o.id = s.ort_id
        JOIN anlage  a ON a.id = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'symbol'
          AND ge.extra_daten IS NOT NULL
    )");
    q.bindValue(":pid", projektId);

    QSet<int> vorhandene;
    const int praefixLen = praefix.length();

    if (q.exec()) {
        while (q.next()) {
            QString extraStr = q.value(0).toString();
            if (extraStr.isEmpty()) continue;
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (err.error || !doc.isObject()) continue;
            QString bmk = doc.object()[QStringLiteral("bmk")].toString();
            if (bmk.startsWith(praefix) && bmk.length() > praefixLen) {
                bool ok;
                int num = bmk.mid(praefixLen).toInt(&ok);
                if (ok && num > 0) vorhandene.insert(num);
            }
        }
    } else {
        qCWarning(lcDb) << "naechsteBmkNummer:" << q.lastError().text();
    }

    int next = 1;
    while (vorhandene.contains(next)) ++next;
    return praefix + QString::number(next);
}

// ============================================================
// verbindungenSynchronisieren
// Schreibt erkannte Auto-Verbindungen (Netze) in verbindung +
// verbindung_segment. Bestehende Segmente der Seite werden zuerst
// gelöscht; die verbindung-Zeilen (mit Annotation) bleiben erhalten
// und werden per potenzial-Feld (= netKey) wiederverwendet.
// ============================================================
bool Database::verbindungenSynchronisieren(int seiteId, int projektId, const QVariantList &netze)
{
    if (!m_db.transaction()) {
        qCWarning(lcDb) << "verbindungenSynchronisieren: Transaktion:" << m_db.lastError().text();
        return false;
    }

    // 1. Alte Segmente dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM verbindung_segment WHERE seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qCWarning(lcDb) << "verbindungenSynchronisieren del segments:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 2. Alte Querverweise dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM querverweis WHERE von_seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qCWarning(lcDb) << "verbindungenSynchronisieren del querverweis:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 3. Netze verarbeiten
    for (const QVariant &netVar : netze) {
        const QVariantMap net = netVar.toMap();
        const QString netKey      = net.value(QStringLiteral("netKey")).toString();
        const QString legacyKey   = net.value(QStringLiteral("legacyNetKey")).toString();
        const QString bezeichnung = net.value(QStringLiteral("bezeichnung")).toString();
        const QString signaltyp   = net.value(QStringLiteral("signaltyp"),  QStringLiteral("neutral")).toString();
        const QString farbe       = net.value(QStringLiteral("farbe")).toString();
        const double  querschnitt = net.value(QStringLiteral("querschnitt")).toDouble();

        if (netKey.isEmpty()) continue;

        // Verbindung per netKey (potenzial-Feld) suchen oder anlegen
        int verbId = -1;
        {
            QSqlQuery lookup;
            lookup.prepare("SELECT id FROM verbindung WHERE projekt_id = :pid AND potenzial = :key LIMIT 1");
            lookup.bindValue(":pid", projektId);
            lookup.bindValue(":key", netKey);
            bool gefunden = lookup.exec() && lookup.next();
            bool ueberLegacyKey = false;
            if (gefunden) verbId = lookup.value(0).toInt();

            // NETZ-01: Fallback über legacyNetKey (alter, positionsbasierter
            // Key). Greift z.B. wenn ein verbundenes Element verschoben wurde
            // und das Netz dadurch jetzt einen neuen netKey hat, aber sonst
            // unverändert ist — verhindert eine verwaiste Alt-Zeile samt
            // Verlust von Bezeichnung/Farbe/Querschnitt/Aderzuordnung.
            if (!gefunden && !legacyKey.isEmpty() && legacyKey != netKey) {
                QSqlQuery lookupAlt;
                lookupAlt.prepare("SELECT id FROM verbindung WHERE projekt_id = :pid AND potenzial = :key LIMIT 1");
                lookupAlt.bindValue(":pid", projektId);
                lookupAlt.bindValue(":key", legacyKey);
                if (lookupAlt.exec() && lookupAlt.next()) {
                    verbId = lookupAlt.value(0).toInt();
                    gefunden = true;
                    ueberLegacyKey = true;
                }
            }

            if (gefunden) {
                // Nur signaltyp (+ ggf. Key-Migration) aktualisieren; Annotation
                // (bezeichnung, farbe, querschnitt) wird nur durch expliziten
                // Nutzeraktion via verbindungAktualisieren geändert
                QSqlQuery upd;
                if (ueberLegacyKey) {
                    upd.prepare("UPDATE verbindung SET potenzial = :key, signaltyp = :sig WHERE id = :id");
                    upd.bindValue(":key", netKey);
                } else {
                    upd.prepare("UPDATE verbindung SET signaltyp = :sig WHERE id = :id");
                }
                upd.bindValue(":sig", signaltyp);
                upd.bindValue(":id",  verbId);
                if (!upd.exec()) {
                    qCWarning(lcDb) << "verbindungenSynchronisieren update:" << upd.lastError().text();
                    m_db.rollback(); return false;
                }
            } else {
                QSqlQuery ins;
                ins.prepare(R"(
                    INSERT INTO verbindung (projekt_id, potenzial, bezeichnung, signaltyp, farbe, querschnitt_mm2)
                    VALUES (:pid, :key, :bez, :sig, :farbe, :q)
                )");
                ins.bindValue(":pid",   projektId);
                ins.bindValue(":key",   netKey);
                ins.bindValue(":bez",   bezeichnung.isEmpty()
                                        ? QVariant(QMetaType::fromType<QString>()) : bezeichnung);
                ins.bindValue(":sig",   signaltyp);
                ins.bindValue(":farbe", farbe.isEmpty()
                                        ? QVariant(QMetaType::fromType<QString>()) : farbe);
                ins.bindValue(":q",     querschnitt > 0
                                        ? querschnitt : QVariant(QMetaType::fromType<double>()));
                if (!ins.exec()) {
                    qCWarning(lcDb) << "verbindungenSynchronisieren insert verbindung:" << ins.lastError().text();
                    m_db.rollback(); return false;
                }
                verbId = ins.lastInsertId().toInt();
            }
        }

        // Segmente einfügen (logische Verbindungen wie Klemmen-Durchleitung
        // werden nicht gespeichert – sie sind auf dem Canvas nicht sichtbar
        // und sollen daher auch im PDF nicht als Linie erscheinen)
        const QVariantList segmente = net.value(QStringLiteral("segmente")).toList();
        for (const QVariant &segVar : segmente) {
            const QVariantMap seg = segVar.toMap();
            if (seg.value(QStringLiteral("logisch")).toBool()) continue;
            QJsonArray punkte;
            punkte.append(QJsonObject{{ QStringLiteral("x"), seg.value(QStringLiteral("x1")).toDouble() },
                                      { QStringLiteral("y"), seg.value(QStringLiteral("y1")).toDouble() }});
            punkte.append(QJsonObject{{ QStringLiteral("x"), seg.value(QStringLiteral("x2")).toDouble() },
                                      { QStringLiteral("y"), seg.value(QStringLiteral("y2")).toDouble() }});
            QSqlQuery insSeg;
            insSeg.prepare("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (:vid, :sid, :pt)");
            insSeg.bindValue(":vid", verbId);
            insSeg.bindValue(":sid", seiteId);
            insSeg.bindValue(":pt",  QString::fromUtf8(QJsonDocument(punkte).toJson(QJsonDocument::Compact)));
            if (!insSeg.exec()) {
                qCWarning(lcDb) << "verbindungenSynchronisieren insert segment:" << insSeg.lastError().text();
                m_db.rollback(); return false;
            }
        }

        // Querverweise einfügen
        const QVariantList querverweise = net.value(QStringLiteral("querverweise")).toList();
        for (const QVariant &qvVar : querverweise) {
            const QVariantMap qv = qvVar.toMap();
            QSqlQuery insQv;
            insQv.prepare(R"(
                INSERT INTO querverweis (verbindung_id, von_seite_id, nach_seite_id, von_bezeichnung, nach_bezeichnung)
                VALUES (:vid, :von, :nach, :vonbez, :nachbez)
            )");
            insQv.bindValue(":vid",    verbId);
            insQv.bindValue(":von",    qv.value(QStringLiteral("vonSeiteId")).toInt());
            insQv.bindValue(":nach",   qv.value(QStringLiteral("nachSeiteId")).toInt());
            insQv.bindValue(":vonbez", qv.value(QStringLiteral("vonBezeichnung")).toString());
            insQv.bindValue(":nachbez",qv.value(QStringLiteral("nachBezeichnung")).toString());
            if (!insQv.exec()) {
                qCWarning(lcDb) << "verbindungenSynchronisieren insert querverweis:" << insQv.lastError().text();
                m_db.rollback(); return false;
            }
        }
    }

    if (!m_db.commit()) {
        qCWarning(lcDb) << "verbindungenSynchronisieren commit:" << m_db.lastError().text();
        m_db.rollback(); return false;
    }
    return true;
}

// ============================================================
// verbindungAktualisieren
// Schreibt Bezeichnung, Aderfarbe und Querschnitt einer Verbindung.
// ============================================================
bool Database::verbindungAktualisieren(int verbindungId, const QString &bezeichnung,
                                        const QString &farbe, double querschnitt)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE verbindung SET bezeichnung = :bez, farbe = :farbe, querschnitt_mm2 = :q WHERE id = :id");
    q.bindValue(":bez",   bezeichnung.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : bezeichnung);
    q.bindValue(":farbe", farbe.isEmpty()       ? QVariant(QMetaType::fromType<QString>()) : farbe);
    q.bindValue(":q",     querschnitt > 0       ? querschnitt : QVariant(QMetaType::fromType<double>()));
    q.bindValue(":id",    verbindungId);
    if (!q.exec()) {
        qCWarning(lcDb) << "verbindungAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// verbindungAnnotationenLaden
// Gibt alle Verbindungsannotationen für eine Seite zurück.
// Jede Zeile: {netKey (= potenzial), verbindungId, bezeichnung,
//              farbe, querschnitt_mm2, signaltyp}
// ============================================================
QVariantList Database::verbindungAnnotationenLaden(int seiteId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT v.id, v.potenzial, v.bezeichnung, v.farbe, v.querschnitt_mm2, v.signaltyp
        FROM verbindung_segment vs
        JOIN verbindung v ON v.id = vs.verbindung_id
        WHERE vs.seite_id = :sid
        GROUP BY v.id
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "verbindungAnnotationenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("verbindungId")]   = q.value(0).toInt();
        m[QStringLiteral("netKey")]         = q.value(1).toString();
        m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        m[QStringLiteral("farbe")]          = q.value(3).toString();
        m[QStringLiteral("querschnitt_mm2")]= q.value(4).isNull() ? 0.0 : q.value(4).toDouble();
        m[QStringLiteral("signaltyp")]      = q.value(5).toString();
        result.append(m);
    }
    return result;
}

// ============================================================
// verbindungenProjektLaden
// Alle Verbindungen eines Projekts (für Potenzial-Nummerierung).
// ============================================================
QVariantList Database::verbindungenProjektLaden(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, bezeichnung, signaltyp FROM verbindung WHERE projekt_id = :pid ORDER BY id");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "verbindungenProjektLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]          = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")] = q.value(1).toString();
        m[QStringLiteral("signaltyp")]   = q.value(2).toString();
        result.append(m);
    }
    return result;
}

// ============================================================
// naechsteFreiePotenzialNummer
// Gibt die nächste freie Bezeichnung nach Schema (praefix + Nummer)
// zurück, die noch nicht in verbindung.bezeichnung vergeben ist.
// ============================================================
QString Database::naechsteFreiePotenzialNummer(int projektId,
                                                const QString &praefix,
                                                int start, int schrittweite)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT bezeichnung FROM verbindung WHERE projekt_id = :pid AND bezeichnung IS NOT NULL");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return praefix + QString::number(start);

    QSet<int> verwendet;
    while (q.next()) {
        QString bez = q.value(0).toString();
        if (!bez.startsWith(praefix)) continue;
        QString rest = bez.mid(praefix.length());
        bool ok = false;
        int n = rest.toInt(&ok);
        if (ok) verwendet.insert(n);
    }
    int n = start;
    const int sc = schrittweite > 0 ? schrittweite : 1;
    while (verwendet.contains(n)) n += sc;
    return praefix + QString::number(n);
}

// ============================================================
// verbindungenBulkBezeichnungSetzen
// Setzt in einer Transaktion die Bezeichnung mehrerer Verbindungen.
// zuweisungen: [{id (int), bezeichnung (string)}]
// ============================================================
bool Database::verbindungenBulkBezeichnungSetzen(int projektId, const QVariantList &zuweisungen)
{
    if (zuweisungen.isEmpty()) return true;
    if (!m_db.transaction()) {
        qCWarning(lcDb) << "verbindungenBulkBezeichnungSetzen: transaction:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q(m_db);
    q.prepare("UPDATE verbindung SET bezeichnung = :bez WHERE id = :id AND projekt_id = :pid");
    for (const QVariant &var : zuweisungen) {
        QVariantMap m = var.toMap();
        QString bez = m.value(QStringLiteral("bezeichnung")).toString();
        q.bindValue(":bez", bez.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : bez);
        q.bindValue(":id",  m.value(QStringLiteral("id")).toInt());
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "verbindungenBulkBezeichnungSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    return m_db.commit();
}

// ============================================================
// fehlersuchQuerverweisZiel
// Sucht die Zielseite + Position für einen Querverweis-Sprung
// im Fehlersuchmodus.
// Ablauf:
//   1. Mittelpunkt des Querverweis-Elements ermitteln
//   2. Nächstes verbindung_segment-Endpunkt auf vonSeiteId finden
//   3. nach_seite_id aus querverweis-Tabelle lesen
//   4. Position des Querverweis-Elements auf Zielseite (gleicher signalname)
// ============================================================
QVariantMap Database::fehlersuchQuerverweisZiel(int vonSeiteId, int qvElementId)
{
    QVariantMap result;
    result[QStringLiteral("nachSeiteId")] = -1;
    result[QStringLiteral("zielX")]       = 0.0;
    result[QStringLiteral("zielY")]       = 0.0;
    result[QStringLiteral("partnerId")]   = -1;

    // 1. Mittelpunkt des Querverweis-Elements
    QSqlQuery elQ;
    elQ.prepare("SELECT (x1 + x2) / 2.0, (y1 + y2) / 2.0 FROM grafik_element WHERE id = :id");
    elQ.bindValue(":id", qvElementId);
    if (!elQ.exec() || !elQ.next()) return result;
    const double elX = elQ.value(0).toDouble();
    const double elY = elQ.value(1).toDouble();

    // 2. Nächstes verbindung_segment-Endpunkt auf der Quellseite
    QSqlQuery segQ;
    segQ.prepare("SELECT verbindung_id, punkte FROM verbindung_segment WHERE seite_id = :sid");
    segQ.bindValue(":sid", vonSeiteId);
    if (!segQ.exec()) return result;

    int    bestVerbId = -1;
    double bestDist2  = 16.0; // Toleranz: 4 WE
    while (segQ.next()) {
        const int     vid = segQ.value(0).toInt();
        const QJsonArray pts = QJsonDocument::fromJson(
            segQ.value(1).toByteArray()).array();
        for (const QJsonValue &pv : pts) {
            const QJsonObject p = pv.toObject();
            const double dx = p[QStringLiteral("x")].toDouble() - elX;
            const double dy = p[QStringLiteral("y")].toDouble() - elY;
            const double d2 = dx * dx + dy * dy;
            if (d2 < bestDist2) { bestDist2 = d2; bestVerbId = vid; }
        }
    }
    if (bestVerbId < 0) return result;

    // 3. nach_seite_id aus querverweis-Tabelle
    QSqlQuery qvQ;
    qvQ.prepare("SELECT nach_seite_id FROM querverweis "
                "WHERE verbindung_id = :vid AND von_seite_id = :sid LIMIT 1");
    qvQ.bindValue(":vid", bestVerbId);
    qvQ.bindValue(":sid", vonSeiteId);
    if (!qvQ.exec() || !qvQ.next()) return result;
    const int nachSeiteId = qvQ.value(0).toInt();
    result[QStringLiteral("nachSeiteId")] = nachSeiteId;

    // 4. Position des Querverweis-Elements auf der Zielseite (gleicher signalname)
    QSqlQuery snQ;
    snQ.prepare("SELECT json_extract(extra_daten, '$.signalname') "
                "FROM grafik_element WHERE id = :id");
    snQ.bindValue(":id", qvElementId);
    const QString signalname = (snQ.exec() && snQ.next())
                               ? snQ.value(0).toString() : QString();

    QSqlQuery targetQ;
    if (!signalname.isEmpty()) {
        targetQ.prepare(R"(
            SELECT id, (x1 + x2) / 2.0, (y1 + y2) / 2.0
            FROM grafik_element
            WHERE seite_id = :sid AND symbol_id = 'querverweis'
            AND json_extract(extra_daten, '$.signalname') = :sn
            LIMIT 1
        )");
        targetQ.bindValue(":sid", nachSeiteId);
        targetQ.bindValue(":sn",  signalname);
    } else {
        targetQ.prepare(R"(
            SELECT id, (x1 + x2) / 2.0, (y1 + y2) / 2.0
            FROM grafik_element
            WHERE seite_id = :sid AND symbol_id = 'querverweis'
            LIMIT 1
        )");
        targetQ.bindValue(":sid", nachSeiteId);
    }
    if (targetQ.exec() && targetQ.next()) {
        result[QStringLiteral("partnerId")] = targetQ.value(0).toInt();
        result[QStringLiteral("zielX")]     = targetQ.value(1).toDouble();
        result[QStringLiteral("zielY")]     = targetQ.value(2).toDouble();
    }

    return result;
}

// ============================================================
// alleSeitenFlach
// Gibt alle Seiten eines Projekts als flache Liste zurück.
// Wird im EigenschaftenPanel für den Querverweis-Seitenpicker
// benötigt: [{id, blattnummer, bezeichnung}].
// ============================================================
