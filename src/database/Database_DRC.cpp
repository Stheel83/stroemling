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
#include <QMap>
#include <algorithm>

// NKZ-03: betriebsmittel.funktion/einbauort/anlage_uebergeordnet/standort_uebergeordnet
// (und damit die betriebsmittel_bmk-View) werden nirgends beschrieben – der frühere
// GROUP BY bv.bmk_vollstaendig verglich faktisch nur die nackte Kennzeichnung ohne
// Anlage/Ort-Scope. Stattdessen wird hier – analog zu stueckliste()/aderliste() in
// Database_Listen.cpp – die Anlage/Ort-Zugehörigkeit über das (Haupt-)grafik_element
// des Betriebsmittels aufgelöst, inkl. Strukturkasten-Override, und erst danach
// gruppiert. Siehe konzept/features/07_normkennzeichnung.md §5.2.
QVariantList Database::drcDoppelteBmk(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT b.id, b.betriebsmittel_kz,
               a.kuerzel, o.kuerzel,
               COALESCE(a.anlage_uebergeordnet, ''),
               COALESCE(o.standort_uebergeordnet, ''),
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra
        FROM betriebsmittel b
        JOIN grafik_element ge ON ge.id = COALESCE(
            b.haupt_element_id,
            (SELECT MIN(g2.id) FROM grafik_element g2 WHERE g2.betriebsmittel_id = b.id)
        )
        JOIN seite  s ON s.id = ge.seite_id
        JOIN ort    o ON o.id = s.ort_id
        JOIN anlage a ON a.id = o.anlage_id
        WHERE b.projekt_id = :pid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcDoppelteBmk:" << q.lastError().text();
        return ergebnis;
    }

    struct Gruppe { int anzahl = 0; QVariantList ids; };
    QMap<QString, Gruppe> gruppen; // Vollkennzeichen -> Treffer (QMap sortiert nach Schlüssel)

    while (q.next()) {
        const int     id       = q.value(0).toInt();
        const QString kz       = q.value(1).toString();
        QString anlageKz = q.value(2).toString();
        QString ortKz    = q.value(3).toString();
        QString anlageUO = q.value(4).toString();
        QString ortUO    = q.value(5).toString();
        strukturkastenOverrideAnwenden(q.value(6).toString(), anlageKz, ortKz, anlageUO, ortUO);

        QString vollkz;
        if (!anlageUO.isEmpty()) vollkz += "==" + anlageUO;
        if (!ortUO.isEmpty())    vollkz += "++" + ortUO;
        if (!anlageKz.isEmpty()) vollkz += "=" + anlageKz;
        if (!ortKz.isEmpty())    vollkz += "+" + ortKz;
        vollkz += "-" + kz;

        Gruppe &g = gruppen[vollkz];
        g.anzahl++;
        g.ids << id;
    }

    for (auto it = gruppen.constBegin(); it != gruppen.constEnd(); ++it) {
        if (it.value().anzahl <= 1) continue;
        QVariantMap fund;
        fund["bmk"]    = it.key();
        fund["anzahl"] = it.value().anzahl;
        fund["ids"]    = it.value().ids;
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcSymboleOhneBmk(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT ge.id, ge.symbol_id, ge.seite_id, s.bezeichnung "
        "FROM grafik_element ge "
        "JOIN seite s ON ge.seite_id = s.id "
        "JOIN ort o ON o.id = s.ort_id "
        "JOIN anlage a ON a.id = o.anlage_id "
        "LEFT JOIN betriebsmittel b ON ge.betriebsmittel_id = b.id "
        "WHERE a.projekt_id = :pid "
        "  AND ge.typ = 'symbol' "
        "  AND ge.symbol_id NOT IN ("
        "    'winkel','treffpunkt','treffpunkt_l','geraeteanschluss',"
        "    'unterbrechung','querverweis','aderdefinition','klemme_anschluss') "
        "  AND (ge.betriebsmittel_id IS NULL "
        "       OR TRIM(COALESCE(b.betriebsmittel_kz,'')) = '') "
        "ORDER BY s.blattnummer, ge.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcSymboleOhneBmk:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["elementId"] = q.value(0).toInt();
        fund["symbolId"]  = q.value(1).toString();
        fund["seiteId"]   = q.value(2).toInt();
        fund["seiteName"] = q.value(3).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcSeitenOhneBezeichnung(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT s.id, s.blattnummer FROM seite s "
        "JOIN ort o ON o.id = s.ort_id "
        "JOIN anlage a ON a.id = o.anlage_id "
        "WHERE a.projekt_id = :pid "
        "  AND TRIM(COALESCE(s.bezeichnung,'')) = '' "
        "ORDER BY s.blattnummer"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcSeitenOhneBezeichnung:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["seiteId"]     = q.value(0).toInt();
        fund["blattnummer"] = q.value(1).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcKabeladernOhneAnschluss(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT ka.id, ka.ader_nr, ka.bezeichnung, k.bezeichnung, "
        "  CASE "
        "    WHEN TRIM(COALESCE(ka.von_gerat_pin,''))  = '' "
        "     AND TRIM(COALESCE(ka.nach_gerat_pin,'')) = '' THEN 'Von + Nach fehlen' "
        "    WHEN TRIM(COALESCE(ka.von_gerat_pin,''))  = '' THEN 'Von fehlt' "
        "    ELSE 'Nach fehlt' "
        "  END "
        "FROM kabel_ader ka "
        "JOIN kabel k ON ka.kabel_id = k.id "
        "WHERE k.projekt_id = :pid "
        "  AND (TRIM(COALESCE(ka.von_gerat_pin,''))  = '' "
        "    OR TRIM(COALESCE(ka.nach_gerat_pin,'')) = '') "
        "ORDER BY k.bezeichnung, ka.ader_nr"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcKabeladernOhneAnschluss:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["aderId"]    = q.value(0).toInt();
        fund["aderNr"]    = q.value(1).toInt();
        fund["aderBez"]   = q.value(2).toString();
        fund["kabelName"] = q.value(3).toString();
        fund["wasFehlt"]  = q.value(4).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcUnverbundenePins(int projektId)
{
    // Hilfs-Symbole, die keine BMK-Verbindung benötigen
    static const QSet<QString> hilfs = {
        "winkel", "treffpunkt", "treffpunkt_l", "geraeteanschluss",
        "unterbrechung", "querverweis", "aderdefinition", "klemme_anschluss"
    };

    QVariantList ergebnis;

    // Alle Seiten des Projekts laden
    QSqlQuery seitenQ;
    seitenQ.prepare("SELECT s.id, s.bezeichnung FROM seite s "
                     "JOIN ort o ON o.id = s.ort_id "
                     "JOIN anlage a ON a.id = o.anlage_id "
                     "WHERE a.projekt_id = :pid ORDER BY s.blattnummer");
    seitenQ.bindValue(":pid", projektId);
    if (!seitenQ.exec()) {
        qCWarning(lcDb) << "drcUnverbundenePins seiten:" << seitenQ.lastError().text();
        return ergebnis;
    }

    while (seitenQ.next()) {
        const int    seiteId   = seitenQ.value(0).toInt();
        const QString seiteName = seitenQ.value(1).toString();

        // Linienendpunkte dieser Seite sammeln
        struct Pt { double x, y; };
        QVector<Pt> enden;
        {
            QSqlQuery lQ;
            lQ.prepare("SELECT x1,y1,x2,y2 FROM grafik_element "
                       "WHERE seite_id=:sid AND typ='linie'");
            lQ.bindValue(":sid", seiteId);
            if (lQ.exec()) {
                while (lQ.next()) {
                    enden.push_back({lQ.value(0).toDouble(), lQ.value(1).toDouble()});
                    enden.push_back({lQ.value(2).toDouble(), lQ.value(3).toDouble()});
                }
            }
        }

        // Pin-Cache: symbol_id → [{x,y,name}]
        struct PinDef { double x, y; QString name; };
        QMap<QString, QList<PinDef>> pinCache;

        // Symbole laden (keine Hilfs-Symbole)
        QSqlQuery symQ;
        symQ.prepare("SELECT id, symbol_id, x1,y1,x2,y2, rotation, spiegel_x, spiegel_y "
                     "FROM grafik_element "
                     "WHERE seite_id=:sid AND typ='symbol'");
        symQ.bindValue(":sid", seiteId);
        if (!symQ.exec()) continue;

        while (symQ.next()) {
            const QString symId = symQ.value(1).toString();
            if (hilfs.contains(symId)) continue;

            const int    elId  = symQ.value(0).toInt();
            const double x1    = symQ.value(2).toDouble();
            const double y1    = symQ.value(3).toDouble();
            const double x2    = symQ.value(4).toDouble();
            const double y2    = symQ.value(5).toDouble();
            const int    rot   = symQ.value(6).toInt();
            const bool   spX   = symQ.value(7).toInt() != 0;
            const bool   spY   = symQ.value(8).toInt() != 0;

            // Pins für dieses Symbol (gecacht)
            if (!pinCache.contains(symId)) {
                QList<PinDef> pList;
                QSqlQuery pQ;
                pQ.prepare("SELECT x, y, name FROM symbol_pin WHERE symbol_id=:sid");
                pQ.bindValue(":sid", symId);
                if (pQ.exec()) {
                    while (pQ.next())
                        pList.push_back({pQ.value(0).toDouble(),
                                         pQ.value(1).toDouble(),
                                         pQ.value(2).toString()});
                }
                pinCache[symId] = pList;
            }

            const double sw  = x2 - x1, sh = y2 - y1;
            const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
            const double rad = rot * M_PI / 180.0;
            const double cosR = std::cos(rad), sinR = std::sin(rad);

            for (const PinDef &p : pinCache[symId]) {
                // pinWeltPos – identische Formel wie in SchaltplanCanvas.qml
                double cx = (p.x - 0.5) * std::abs(sw);
                double cy = (p.y - 0.5) * std::abs(sh);
                if (spX) cx = -cx;
                if (spY) cy = -cy;
                const double wx = scx + cx * cosR - cy * sinR;
                const double wy = scy + cx * sinR + cy * cosR;

                // Prüfen ob ein Leitungsende diesen Pin trifft
                bool verbunden = false;
                for (const Pt &lp : enden) {
                    if (std::abs(lp.x - wx) < 0.5 && std::abs(lp.y - wy) < 0.5) {
                        verbunden = true;
                        break;
                    }
                }
                if (!verbunden) {
                    QVariantMap fund;
                    fund["elementId"] = elId;
                    fund["symbolId"]  = symId;
                    fund["pinName"]   = p.name;
                    fund["seiteId"]   = seiteId;
                    fund["seiteName"] = seiteName;
                    ergebnis << fund;
                }
            }
        }
    }
    return ergebnis;
}

QVariantList Database::drcLeitungsenden(int projektId)
{
    static const QSet<QString> hilfs = {
        "winkel", "treffpunkt", "treffpunkt_l", "geraeteanschluss",
        "unterbrechung", "querverweis", "aderdefinition", "klemme_anschluss"
    };
    const double eps = 0.5;

    QVariantList ergebnis;

    QSqlQuery seitenQ;
    seitenQ.prepare("SELECT s.id, s.bezeichnung FROM seite s "
                     "JOIN ort o ON o.id = s.ort_id "
                     "JOIN anlage a ON a.id = o.anlage_id "
                     "WHERE a.projekt_id = :pid ORDER BY s.blattnummer");
    seitenQ.bindValue(":pid", projektId);
    if (!seitenQ.exec()) {
        qCWarning(lcDb) << "drcLeitungsenden seiten:" << seitenQ.lastError().text();
        return ergebnis;
    }

    while (seitenQ.next()) {
        const int     seiteId   = seitenQ.value(0).toInt();
        const QString seiteName = seitenQ.value(1).toString();

        struct Pt { double x, y; };

        // Alle Leitungsendpunkte dieser Seite
        struct LiniePt { int elId; double x, y; };
        QVector<LiniePt> liniePunkte;
        {
            QSqlQuery lQ;
            lQ.prepare("SELECT id,x1,y1,x2,y2 FROM grafik_element "
                       "WHERE seite_id=:sid AND typ='linie'");
            lQ.bindValue(":sid", seiteId);
            if (lQ.exec()) {
                while (lQ.next()) {
                    int id = lQ.value(0).toInt();
                    liniePunkte.push_back({id, lQ.value(1).toDouble(), lQ.value(2).toDouble()});
                    liniePunkte.push_back({id, lQ.value(3).toDouble(), lQ.value(4).toDouble()});
                }
            }
        }
        if (liniePunkte.isEmpty()) continue;

        // Pin-Weltpositionen aller Symbole auf dieser Seite
        struct PinDef { double x, y; QString name; };
        QMap<QString, QList<PinDef>> pinCache;
        QVector<Pt> pinWeltPos;

        {
            QSqlQuery symQ;
            symQ.prepare("SELECT symbol_id,x1,y1,x2,y2,rotation,spiegel_x,spiegel_y "
                         "FROM grafik_element WHERE seite_id=:sid AND typ='symbol'");
            symQ.bindValue(":sid", seiteId);
            if (symQ.exec()) {
                while (symQ.next()) {
                    const QString symId = symQ.value(0).toString();
                    if (!pinCache.contains(symId)) {
                        QList<PinDef> pList;
                        QSqlQuery pQ;
                        pQ.prepare("SELECT x,y,name FROM symbol_pin WHERE symbol_id=:sid");
                        pQ.bindValue(":sid", symId);
                        if (pQ.exec())
                            while (pQ.next())
                                pList.push_back({pQ.value(0).toDouble(),
                                                 pQ.value(1).toDouble(),
                                                 pQ.value(2).toString()});
                        pinCache[symId] = pList;
                    }
                    const double sw  = symQ.value(3).toDouble() - symQ.value(1).toDouble();
                    const double sh  = symQ.value(4).toDouble() - symQ.value(2).toDouble();
                    const double scx = symQ.value(1).toDouble() + sw / 2.0;
                    const double scy = symQ.value(2).toDouble() + sh / 2.0;
                    const double rad = symQ.value(5).toInt() * M_PI / 180.0;
                    const double cosR = std::cos(rad), sinR = std::sin(rad);
                    const bool   spX = symQ.value(6).toInt() != 0;
                    const bool   spY = symQ.value(7).toInt() != 0;

                    for (const PinDef &p : pinCache[symId]) {
                        double cx = (p.x - 0.5) * std::abs(sw);
                        double cy = (p.y - 0.5) * std::abs(sh);
                        if (spX) cx = -cx;
                        if (spY) cy = -cy;
                        pinWeltPos.push_back({scx + cx*cosR - cy*sinR,
                                              scy + cx*sinR + cy*cosR});
                    }
                }
            }
        }

        // Schirm-Pins dieser Seite (kein Symbol, kein Pinkatalog-Eintrag, vgl.
        // SymbolDefinitionModel::autoVerbindungenBerechnen) – sonst würde eine
        // an einem Schirm-Pin endende freie Linie fälschlich als "Leitungsende
        // ohne Verbindung" gemeldet.
        {
            QSqlQuery shQ;
            shQ.prepare("SELECT x1,y1,x2,y2,extra_daten FROM grafik_element "
                        "WHERE seite_id=:sid AND typ='schirm'");
            shQ.bindValue(":sid", seiteId);
            if (shQ.exec()) {
                while (shQ.next()) {
                    const double x1 = shQ.value(0).toDouble(), y1 = shQ.value(1).toDouble();
                    const double x2 = shQ.value(2).toDouble(), y2 = shQ.value(3).toDouble();
                    const QJsonObject ext  = QJsonDocument::fromJson(shQ.value(4).toString().toUtf8()).object();
                    const QString     seite = ext.value("anschlussSeite").toString(QStringLiteral("links"));
                    double px, py;
                    if      (seite == QLatin1String("rechts")) { px = std::max(x1, x2); py = (y1 + y2) / 2.0; }
                    else if (seite == QLatin1String("oben"))   { px = (x1 + x2) / 2.0;  py = std::min(y1, y2); }
                    else if (seite == QLatin1String("unten"))  { px = (x1 + x2) / 2.0;  py = std::max(y1, y2); }
                    else                                       { px = std::min(x1, x2); py = (y1 + y2) / 2.0; }
                    pinWeltPos.push_back({px, py});
                }
            }
        }

        // Jedes Leitungsende prüfen
        QSet<int> gemeldet; // elId deduplizieren (ein Element max. einmal)
        for (int i = 0; i < liniePunkte.size(); i++) {
            const LiniePt &lp = liniePunkte[i];
            if (gemeldet.contains(lp.elId)) continue;

            // 1. Trifft es einen Symbol-Pin?
            bool verbunden = false;
            for (const Pt &pp : pinWeltPos) {
                if (std::abs(pp.x - lp.x) < eps && std::abs(pp.y - lp.y) < eps) {
                    verbunden = true; break;
                }
            }
            if (verbunden) continue;

            // 2. Trifft es ein anderes Leitungsende?
            for (int j = 0; j < liniePunkte.size(); j++) {
                if (i == j) continue;
                const LiniePt &lp2 = liniePunkte[j];
                if (std::abs(lp2.x - lp.x) < eps && std::abs(lp2.y - lp.y) < eps) {
                    verbunden = true; break;
                }
            }
            if (verbunden) continue;

            // Leitungsende hängt in der Luft
            gemeldet.insert(lp.elId);
            QVariantMap fund;
            fund["elementId"] = lp.elId;
            fund["seiteId"]   = seiteId;
            fund["seiteName"] = seiteName;
            fund["endpunkt"]  = QString("(%1, %2)").arg(lp.x, 0, 'f', 1).arg(lp.y, 0, 'f', 1);
            ergebnis << fund;
        }
    }
    return ergebnis;
}

QVariantList Database::drcPotenzialkonflikte(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, COALESCE(NULLIF(bezeichnung,''), potenzial, 'unbekannt'), potenzial
        FROM verbindung
        WHERE projekt_id = :pid AND signaltyp = 'konflikt'
        ORDER BY id
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcPotenzialkonflikte:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap m;
        m["verbindungId"] = q.value(0).toInt();
        m["name"]         = q.value(1).toString();
        m["potenzial"]    = q.value(2).toString();
        ergebnis << m;
    }
    return ergebnis;
}

QVariantList Database::drcParallelQuellen(int projektId)
{
    // Findet Netze auf denen >= 2 Quell-Symbole (rolle='quelle') liegen.
    // Variabel-Symbole mit extraDaten.rolle='quelle' werden ebenfalls erfasst.
    // PE- und N-Netze sind bewusst ausgenommen (mehrere Erdungspunkte sind normal).

    struct PinDef { double x, y; };
    const double eps = 0.5;

    // verbindung_id → {seiten-Set, quellen-Anzahl}
    struct NetInfo { QSet<QString> seiten; int quellen = 0; QString name; };
    QMap<int, NetInfo> netMap;

    // Alle Seiten des Projekts
    QSqlQuery seitenQ;
    seitenQ.prepare("SELECT s.id, s.bezeichnung FROM seite s "
                     "JOIN ort o ON o.id = s.ort_id "
                     "JOIN anlage a ON a.id = o.anlage_id "
                     "WHERE a.projekt_id = :pid ORDER BY s.blattnummer");
    seitenQ.bindValue(":pid", projektId);
    if (!seitenQ.exec()) {
        qCWarning(lcDb) << "drcParallelQuellen seiten:" << seitenQ.lastError().text();
        return {};
    }

    // Pin-Definitions-Cache: symbol_id → [{x,y}]
    QMap<QString, QList<PinDef>> pinCache;

    while (seitenQ.next()) {
        const int     seiteId   = seitenQ.value(0).toInt();
        const QString seiteName = seitenQ.value(1).toString();

        // Verbindungssegment-Endpunkte dieser Seite: verbindung_id → [{x,y}]
        QMap<int, QList<PinDef>> segEnden;
        {
            QSqlQuery vsQ;
            vsQ.prepare(R"(
                SELECT vs.verbindung_id, vs.punkte, v.bezeichnung, v.potenzial, v.signaltyp
                FROM verbindung_segment vs
                JOIN verbindung v ON vs.verbindung_id = v.id
                WHERE vs.seite_id = :sid AND v.projekt_id = :pid
            )");
            vsQ.bindValue(":sid", seiteId);
            vsQ.bindValue(":pid", projektId);
            if (!vsQ.exec()) continue;
            while (vsQ.next()) {
                const int     vid      = vsQ.value(0).toInt();
                const QString sig      = vsQ.value(4).toString();
                // PE und N ausschließen (mehrere Quellen erlaubt)
                if (sig == "pe" || sig == "n") continue;

                const QString punkte   = vsQ.value(1).toString();
                const QString bez      = vsQ.value(2).toString();
                const QString pot      = vsQ.value(3).toString();

                if (!netMap.contains(vid)) {
                    NetInfo ni;
                    ni.name = bez.isEmpty() ? pot : bez;
                    netMap[vid] = ni;
                }

                const QJsonArray pts = QJsonDocument::fromJson(punkte.toUtf8()).array();
                for (const QJsonValue &pt : pts) {
                    const QJsonObject o = pt.toObject();
                    segEnden[vid].push_back({o["x"].toDouble(), o["y"].toDouble()});
                }
            }
        }
        if (segEnden.isEmpty()) continue;

        // Quelle-Symbole dieser Seite mit ihren Pin-Weltpositionen
        QSqlQuery symQ;
        symQ.prepare(R"(
            SELECT ge.id, ge.symbol_id, ge.x1, ge.y1, ge.x2, ge.y2,
                   ge.rotation, ge.spiegel_x, ge.spiegel_y, ge.extra_daten,
                   sd.rolle
            FROM grafik_element ge
            LEFT JOIN symbol_definition sd ON sd.id = ge.symbol_id
            WHERE ge.seite_id = :sid AND ge.typ = 'symbol'
        )");
        symQ.bindValue(":sid", seiteId);
        if (!symQ.exec()) continue;

        while (symQ.next()) {
            const QString symId   = symQ.value(1).toString();
            const QString rolleSd = symQ.value(10).toString();
            const QString extJson = symQ.value(9).toString();

            // Rolle bestimmen (variabel kann durch extraDaten überschrieben werden)
            QString rolle = rolleSd;
            if (rolle == "variabel") {
                const QJsonObject ext = QJsonDocument::fromJson(extJson.toUtf8()).object();
                rolle = ext["rolle"].toString("ziel");
            }
            if (rolle != "quelle") continue;

            // Pin-Weltpositionen berechnen
            if (!pinCache.contains(symId)) {
                QList<PinDef> pList;
                QSqlQuery pQ;
                pQ.prepare("SELECT x, y FROM symbol_pin WHERE symbol_id = :sid");
                pQ.bindValue(":sid", symId);
                if (pQ.exec())
                    while (pQ.next())
                        pList.push_back({pQ.value(0).toDouble(), pQ.value(1).toDouble()});
                pinCache[symId] = pList;
            }

            const double sw  = symQ.value(4).toDouble() - symQ.value(2).toDouble();
            const double sh  = symQ.value(5).toDouble() - symQ.value(3).toDouble();
            const double scx = symQ.value(2).toDouble() + sw / 2.0;
            const double scy = symQ.value(3).toDouble() + sh / 2.0;
            const double rad = symQ.value(6).toInt() * M_PI / 180.0;
            const double cosR = std::cos(rad), sinR = std::sin(rad);
            const bool   spX = symQ.value(7).toInt() != 0;
            const bool   spY = symQ.value(8).toInt() != 0;

            for (const PinDef &p : pinCache[symId]) {
                double cx = (p.x - 0.5) * std::abs(sw);
                double cy = (p.y - 0.5) * std::abs(sh);
                if (spX) cx = -cx;
                if (spY) cy = -cy;
                const double wx = scx + cx * cosR - cy * sinR;
                const double wy = scy + cx * sinR + cy * cosR;

                // Liegt dieser Pin auf einem Verbindungssegment-Endpunkt?
                for (auto it = segEnden.begin(); it != segEnden.end(); ++it) {
                    for (const PinDef &ep : it.value()) {
                        if (std::abs(ep.x - wx) < eps && std::abs(ep.y - wy) < eps) {
                            netMap[it.key()].quellen++;
                            netMap[it.key()].seiten.insert(seiteName);
                            goto nextPin;
                        }
                    }
                }
                nextPin:;
            }
        }
    }

    // Netze mit >= 2 Quellen melden
    QVariantList ergebnis;
    for (auto it = netMap.begin(); it != netMap.end(); ++it) {
        if (it.value().quellen >= 2) {
            QVariantMap m;
            m["verbindungId"]  = it.key();
            m["name"]          = it.value().name.isEmpty()
                                 ? QString("Netz %1").arg(it.key()) : it.value().name;
            m["quellenAnzahl"] = it.value().quellen;
            m["seiteNamen"]    = QStringList(it.value().seiten.begin(),
                                             it.value().seiten.end()).join(", ");
            ergebnis << m;
        }
    }
    return ergebnis;
}

QVariantList Database::drcKlemmeGeister(int projektId)
{
    // KLEMME-DUP-01/Makro-Fall: aus Copy/Paste oder Makro-Einfügen entstandene
    // Klemmenanschluss-Platzhalter (extra_daten.geist=true) – noch nicht zu
    // einer echten Klemme im Klemmenreihen-Editor hochgestuft.
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT ge.id, ge.seite_id, s.bezeichnung, "
        "COALESCE(json_extract(ge.extra_daten,'$.anschlussBezeichnung'),''), "
        "COALESCE(json_extract(ge.extra_daten,'$.bmk'),'') "
        "FROM grafik_element ge "
        "JOIN seite s ON ge.seite_id = s.id "
        "JOIN ort o ON o.id = s.ort_id "
        "JOIN anlage a ON a.id = o.anlage_id "
        "WHERE a.projekt_id = :pid "
        "  AND ge.typ = 'symbol' "
        "  AND ge.symbol_id = 'klemme_anschluss' "
        "  AND json_extract(ge.extra_daten,'$.geist') = 1 "
        "ORDER BY s.blattnummer, ge.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcKlemmeGeister:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["elementId"]            = q.value(0).toInt();
        fund["seiteId"]              = q.value(1).toInt();
        fund["seiteName"]            = q.value(2).toString();
        fund["anschlussBezeichnung"] = q.value(3).toString();
        fund["bmk"]                  = q.value(4).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

// ============================================================
// drcSchirmOhneAnschluss (D-11, SCH-02)
// Schirm-Element (Konzept 46_schirmung.md) dessen einziger Anschlusspunkt
// keine Leitung berührt – analog "Flunder ohne PE-Bodenkontakt" aus der
// Stromlinge-Metapher. Pin-Positionsformel identisch zu drcLeitungsenden()
// (Schirm-Pin-Sammlung dort), damit beide Prüfungen konsistent bleiben.
// ============================================================
QVariantList Database::drcSchirmOhneAnschluss(int projektId)
{
    const double eps = 0.5;
    QVariantList ergebnis;

    QSqlQuery seitenQ;
    seitenQ.prepare("SELECT s.id, s.bezeichnung FROM seite s "
                     "JOIN ort o ON o.id = s.ort_id "
                     "JOIN anlage a ON a.id = o.anlage_id "
                     "WHERE a.projekt_id = :pid ORDER BY s.blattnummer");
    seitenQ.bindValue(":pid", projektId);
    if (!seitenQ.exec()) {
        qCWarning(lcDb) << "drcSchirmOhneAnschluss seiten:" << seitenQ.lastError().text();
        return ergebnis;
    }

    while (seitenQ.next()) {
        const int     seiteId   = seitenQ.value(0).toInt();
        const QString seiteName = seitenQ.value(1).toString();

        QSqlQuery shQ;
        shQ.prepare("SELECT id, x1,y1,x2,y2, extra_daten FROM grafik_element "
                    "WHERE seite_id=:sid AND typ='schirm'");
        shQ.bindValue(":sid", seiteId);
        if (!shQ.exec() || !shQ.next()) continue;

        // Leitungsendpunkte dieser Seite nur laden, wenn überhaupt ein
        // Schirm-Element existiert (sonst nichts zu prüfen).
        struct Pt { double x, y; };
        QVector<Pt> enden;
        {
            QSqlQuery lQ;
            lQ.prepare("SELECT x1,y1,x2,y2 FROM grafik_element "
                       "WHERE seite_id=:sid AND typ='linie'");
            lQ.bindValue(":sid", seiteId);
            if (lQ.exec()) {
                while (lQ.next()) {
                    enden.push_back({lQ.value(0).toDouble(), lQ.value(1).toDouble()});
                    enden.push_back({lQ.value(2).toDouble(), lQ.value(3).toDouble()});
                }
            }
        }

        do {
            const int    elId = shQ.value(0).toInt();
            const double x1   = shQ.value(1).toDouble(), y1 = shQ.value(2).toDouble();
            const double x2   = shQ.value(3).toDouble(), y2 = shQ.value(4).toDouble();
            const QJsonObject ext = QJsonDocument::fromJson(shQ.value(5).toString().toUtf8()).object();
            const QString     seite = ext.value("anschlussSeite").toString(QStringLiteral("links"));
            const QString     bezeichnung = ext.value("bezeichnung").toString(QStringLiteral("SH"));

            double px, py;
            if      (seite == QLatin1String("rechts")) { px = std::max(x1, x2); py = (y1 + y2) / 2.0; }
            else if (seite == QLatin1String("oben"))   { px = (x1 + x2) / 2.0;  py = std::min(y1, y2); }
            else if (seite == QLatin1String("unten"))  { px = (x1 + x2) / 2.0;  py = std::max(y1, y2); }
            else                                       { px = std::min(x1, x2); py = (y1 + y2) / 2.0; }

            bool verbunden = false;
            for (const Pt &e : enden) {
                if (std::abs(e.x - px) < eps && std::abs(e.y - py) < eps) {
                    verbunden = true;
                    break;
                }
            }
            if (!verbunden) {
                QVariantMap fund;
                fund["elementId"]   = elId;
                fund["seiteId"]     = seiteId;
                fund["seiteName"]   = seiteName;
                fund["bezeichnung"] = bezeichnung;
                ergebnis << fund;
            }
        } while (shQ.next());
    }
    return ergebnis;
}

// ============================================================
// drcKabelOhneKabellinie (D-12, KABEL-VERWAIST-01)
// Kabel-Datensatz ohne jedes 'kabellinie'-Grafikelement — z.B. wenn
// die gezeichnete Linie gelöscht wurde und die Wiederverwendung über
// "bestehendes Kabel" im Kabellinie-Dialog nie stattfand. Gleicher
// JOIN-Ansatz wie kabelAlleLinienLaden() (extra_daten.kabelId ist die
// maßgebliche Verknüpfung, nicht kabel.grafik_element_id).
// ============================================================
QVariantList Database::drcKabelOhneKabellinie(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id, k.bezeichnung
        FROM kabel k
        WHERE k.projekt_id = :pid
          AND NOT EXISTS (
              SELECT 1 FROM grafik_element ge
              WHERE ge.typ = 'kabellinie'
                AND CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER) = k.id
          )
        ORDER BY k.bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "drcKabelOhneKabellinie:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["kabelId"]   = q.value(0).toInt();
        fund["kabelName"] = q.value(1).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::bauteilAlleKategorienFlach()
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec("SELECT id, name FROM bibliothek.bauteil_kategorie ORDER BY sortierung, name");
    while (q.next()) {
        QVariantMap m;
        m["id"]   = q.value(0).toInt();
        m["name"] = q.value(1).toString();
        result.append(m);
    }
    return result;
}
