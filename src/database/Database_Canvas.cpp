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
               bild_daten, bild_mime, extra_daten, betriebsmittel_id
        FROM grafik_element
        WHERE seite_id = :sid
        ORDER BY sortierung
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "grafikLaden:" << q.lastError().text();
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

        // bild_daten: BLOB-Bytes + bild_mime → Base64-Data-URL für QML-Canvas
        QByteArray bildBytes = q.value(22).toByteArray();
        if (!bildBytes.isEmpty()) {
            QString bildMime = q.value(23).toString();
            if (bildMime.isEmpty())
                bildMime = QStringLiteral("image/png");
            el[QStringLiteral("bildDaten")] = QStringLiteral("data:") + bildMime
                + QStringLiteral(";base64,")
                + QString::fromLatin1(bildBytes.toBase64());
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

// ============================================================
// grafikSpeichern
// Ersetzt alle Grafik-Elemente einer Seite in einer Transaktion.
// ============================================================
bool Database::grafikSpeichern(int seiteId, const QVariantList &elemente)
{
    if (!m_db.transaction()) {
        auto msg = m_db.lastError().text();
        qWarning() << "grafikSpeichern: Transaktion:" << msg;
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

    QSqlQuery qDel;
    qDel.prepare("DELETE FROM grafik_element WHERE seite_id = :sid");
    qDel.bindValue(":sid", seiteId);
    if (!qDel.exec()) {
        qWarning() << "grafikSpeichern delete:" << qDel.lastError().text();
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
             bild_daten, bild_mime, extra_daten, betriebsmittel_id)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             :sf, :sb, :sa, :fu, :ff, :fo, :op, :er, :sort,
             :symid, :rot, :spx, :spy,
             :punkte, :textinhalt, :textausrichtung, :texteinpassen,
             :bilddaten, :bildmime, :extradaten, :bmid)
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
        qIns.bindValue(":sb",   el.value(QStringLiteral("strichBreite"),   1.5).toDouble());
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

        // bild_daten: Data-URL aus QML → BLOB-Bytes + MIME für Datenbank
        QVariant bildDatenVar = el.value(QStringLiteral("bildDaten"));
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
                    qIns.bindValue(":bilddaten", rawBytes);
                    qIns.bindValue(":bildmime",  mime);
                } else {
                    qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
                    qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
                }
            } else {
                qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
                qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
            }
        } else {
            qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
            qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
        }

        // extra_daten: extraDaten-Map als kompaktes JSON serialisieren
        QVariant extraVar = el.value(QStringLiteral("extraDaten"));
        if (extraVar.isValid() && !extraVar.isNull() && extraVar.canConvert<QVariantMap>()) {
            QVariantMap extraMap = extraVar.toMap();
            if (!extraMap.isEmpty()) {
                QJsonObject obj;
                for (auto it = extraMap.constBegin(); it != extraMap.constEnd(); ++it)
                    obj.insert(it.key(), QJsonValue::fromVariant(it.value()));
                qIns.bindValue(":extradaten",
                    QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
            } else {
                qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
            }
        } else {
            qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
        }

        // betriebsmittel_id (nullable FK)
        QVariant bmidVar = el.value(QStringLiteral("betriebsmittelId"));
        if (bmidVar.isValid() && !bmidVar.isNull() && bmidVar.toInt() > 0)
            qIns.bindValue(":bmid", bmidVar.toInt());
        else
            qIns.bindValue(":bmid", QVariant(QMetaType::fromType<int>()));

        if (!qIns.exec()) {
            qWarning() << "grafikSpeichern insert:" << qIns.lastError().text();
            m_db.rollback(); return false;
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
                        qWarning() << "grafikSpeichern kabel relink:" << upd.lastError().text();

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
                                qWarning() << "grafikSpeichern ader relink:" << upd2.lastError().text();
                        }
                    }
                }
            }
        }
    }

    if (!m_db.commit()) {
        auto msg = m_db.lastError().text();
        qWarning() << "grafikSpeichern commit:" << msg;
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
        qWarning() << "naechsteBmkNummer:" << q.lastError().text();
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
        qWarning() << "verbindungenSynchronisieren: Transaktion:" << m_db.lastError().text();
        return false;
    }

    // 1. Alte Segmente dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM verbindung_segment WHERE seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qWarning() << "verbindungenSynchronisieren del segments:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 2. Alte Querverweise dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM querverweis WHERE von_seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qWarning() << "verbindungenSynchronisieren del querverweis:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 3. Netze verarbeiten
    for (const QVariant &netVar : netze) {
        const QVariantMap net = netVar.toMap();
        const QString netKey      = net.value(QStringLiteral("netKey")).toString();
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
            if (lookup.exec() && lookup.next()) {
                verbId = lookup.value(0).toInt();
                // Nur signaltyp aktualisieren; Annotation (bezeichnung, farbe, querschnitt)
                // wird nur durch expliziten Nutzeraktion via verbindungAktualisieren geändert
                QSqlQuery upd;
                upd.prepare("UPDATE verbindung SET signaltyp = :sig WHERE id = :id");
                upd.bindValue(":sig", signaltyp);
                upd.bindValue(":id",  verbId);
                if (!upd.exec()) {
                    qWarning() << "verbindungenSynchronisieren update:" << upd.lastError().text();
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
                    qWarning() << "verbindungenSynchronisieren insert verbindung:" << ins.lastError().text();
                    m_db.rollback(); return false;
                }
                verbId = ins.lastInsertId().toInt();
            }
        }

        // Segmente einfügen
        const QVariantList segmente = net.value(QStringLiteral("segmente")).toList();
        for (const QVariant &segVar : segmente) {
            const QVariantMap seg = segVar.toMap();
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
                qWarning() << "verbindungenSynchronisieren insert segment:" << insSeg.lastError().text();
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
                qWarning() << "verbindungenSynchronisieren insert querverweis:" << insQv.lastError().text();
                m_db.rollback(); return false;
            }
        }
    }

    if (!m_db.commit()) {
        qWarning() << "verbindungenSynchronisieren commit:" << m_db.lastError().text();
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
        qWarning() << "verbindungAktualisieren:" << q.lastError().text();
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
        qWarning() << "verbindungAnnotationenLaden:" << q.lastError().text();
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
        qWarning() << "verbindungenProjektLaden:" << q.lastError().text();
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
        qWarning() << "verbindungenBulkBezeichnungSetzen: transaction:" << m_db.lastError().text();
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
            qWarning() << "verbindungenBulkBezeichnungSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    return m_db.commit();
}

// ============================================================
// alleSeitenFlach
// Gibt alle Seiten eines Projekts als flache Liste zurück.
// Wird im EigenschaftenPanel für den Querverweis-Seitenpicker
// benötigt: [{id, blattnummer, bezeichnung}].
// ============================================================
