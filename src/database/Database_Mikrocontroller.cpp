// MCU-PINBELEGUNG-01: Pinbelegung von Mikrokontroller-Boards (Arduino, ESP32, Raspberry Pi ...)
// aus den gezeichneten Verbindungen. Ein Board ist ein Symbol mit symbol_definition.
// ist_mikrocontroller = 1. Zu jedem Pin wird über die persistierten Verbindungsnetze
// (verbindung / verbindung_segment, dieselbe Grundlage wie DRC D-08) ermittelt, welche
// Pins anderer Symbole am selben Netz liegen. Netze, die über Seiten hinweg dieselbe
// verbindung_id tragen, werden seitenübergreifend zusammengeführt.
#include "Database.h"
#include "Database_CsvHelfer.h"
#include <cmath>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QMap>
#include <QHash>
#include <QSqlError>
#include <QSqlQuery>

namespace {

struct Pt { double x, y; };

struct NetPin {
    int     elementId = 0;
    QString symbolId, symbolName, bmk, pin;
    int     seiteId = 0;
    bool    istBoard = false;
};

QString bezeichnerBereinigen(const QString &s)
{
    QString r;
    for (const QChar c : s.toUpper()) {
        if (c.isLetterOrNumber() && c.unicode() < 128) r += c;
        else if (!r.endsWith(QLatin1Char('_'))) r += QLatin1Char('_');
    }
    while (r.startsWith(QLatin1Char('_'))) r.remove(0, 1);
    while (r.endsWith(QLatin1Char('_'))) r.chop(1);
    if (!r.isEmpty() && r[0].isDigit()) r.prepend(QLatin1Char('P'));
    return r;
}

// Board-Pinname → Pin-Literal für den Sketch (D7 → 7, A0 → A0, GPIO21 → 21, 13 → 13)
QString pinLiteral(const QString &name)
{
    static const QRegularExpression dig(QStringLiteral("^(?:D|GPIO|GP|IO)?(\\d+)$"),
                                        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression ana(QStringLiteral("^A(\\d+)$"), QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatch m = ana.match(name.trimmed());
    if (m.hasMatch()) return QStringLiteral("A") + m.captured(1);
    m = dig.match(name.trimmed());
    if (m.hasMatch()) return m.captured(1);
    return QString();
}

} // namespace

QVariantList Database::mikrocontrollerPinbelegung(int projektId)
{
    QVariantList ergebnis;

    // Board-Symbole
    QSet<QString> boards;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT id FROM symbol_definition WHERE ist_mikrocontroller = 1"))
            while (q.next()) boards.insert(q.value(0).toString());
    }
    if (boards.isEmpty()) return ergebnis;

    // Hilfs-Symbole ohne eigenen Bauteil-Charakter (wie DRC D-05; Geräte-/Klemmenanschluss
    // bleiben bewusst drin – dort endet die Leitung am eigentlichen Gerät/Klemmpunkt)
    static const QSet<QString> hilfs = {
        "winkel", "treffpunkt", "treffpunkt_l", "unterbrechung", "querverweis", "aderdefinition"
    };

    struct PinDef { double x, y; QString name; };
    QHash<QString, QList<PinDef>> pinCache;
    QHash<QString, QString> nameCache;
    auto pinsVon = [&](const QString &symId) -> const QList<PinDef> & {
        if (!pinCache.contains(symId)) {
            QList<PinDef> l;
            QSqlQuery pQ(m_db);
            pQ.prepare("SELECT x, y, name FROM symbol_pin WHERE symbol_id = :s ORDER BY id");
            pQ.bindValue(":s", symId);
            if (pQ.exec())
                while (pQ.next()) l.push_back({pQ.value(0).toDouble(), pQ.value(1).toDouble(), pQ.value(2).toString()});
            pinCache.insert(symId, l);
        }
        return pinCache[symId];
    };
    auto symbolName = [&](const QString &symId) {
        if (!nameCache.contains(symId)) {
            QSqlQuery nQ(m_db);
            nQ.prepare("SELECT name FROM symbol_definition WHERE id = :s");
            nQ.bindValue(":s", symId);
            nameCache.insert(symId, (nQ.exec() && nQ.next()) ? nQ.value(0).toString() : symId);
        }
        return nameCache[symId];
    };

    // Netznamen
    QHash<int, QString> netzName;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, COALESCE(NULLIF(bezeichnung,''), COALESCE(potenzial,'')) FROM verbindung WHERE projekt_id = :p");
        q.bindValue(":p", projektId);
        if (q.exec()) while (q.next()) netzName.insert(q.value(0).toInt(), q.value(1).toString());
    }

    struct SeiteInfo { int id; QString blatt, bez; };
    QList<SeiteInfo> seiten;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT s.id, s.blattnummer, COALESCE(s.bezeichnung,'') FROM seite s "
                  "JOIN ort o ON o.id = s.ort_id JOIN anlage a ON a.id = o.anlage_id "
                  "WHERE a.projekt_id = :p ORDER BY s.blattnummer");
        q.bindValue(":p", projektId);
        if (!q.exec()) { qCWarning(lcDb) << "mikrocontrollerPinbelegung seiten:" << q.lastError().text(); return ergebnis; }
        while (q.next()) seiten.push_back({q.value(0).toInt(), q.value(1).toString(), q.value(2).toString()});
    }

    struct BoardPin {
        int elementId; QString symbolId, bmk, pin; int seiteId; QString blatt, seiteBez;
        double wx, wy;      // Board-Mittelpunkt (Sprungziel)
        int netz;           // verbindung_id oder -1
    };
    QList<BoardPin> boardPins;
    QMap<int, QList<NetPin>> netMitglieder;       // verbindung_id → Pins (alle Seiten)

    const double eps = 0.5;

    for (const SeiteInfo &se : seiten) {
        // Segment-Punkte dieser Seite: verbindung_id → Punkte
        QMap<int, QList<Pt>> segPunkte;
        {
            QSqlQuery vq(m_db);
            vq.prepare("SELECT vs.verbindung_id, vs.punkte FROM verbindung_segment vs "
                       "JOIN verbindung v ON v.id = vs.verbindung_id "
                       "WHERE vs.seite_id = :s AND v.projekt_id = :p");
            vq.bindValue(":s", se.id);
            vq.bindValue(":p", projektId);
            if (vq.exec()) {
                while (vq.next()) {
                    const QJsonArray pts = QJsonDocument::fromJson(vq.value(1).toString().toUtf8()).array();
                    for (const QJsonValue &pv : pts) {
                        const QJsonObject o = pv.toObject();
                        segPunkte[vq.value(0).toInt()].push_back({o["x"].toDouble(), o["y"].toDouble()});
                    }
                }
            }
        }

        QSqlQuery symQ(m_db);
        symQ.prepare("SELECT id, symbol_id, x1, y1, x2, y2, rotation, spiegel_x, spiegel_y, extra_daten "
                     "FROM grafik_element WHERE seite_id = :s AND typ = 'symbol' ORDER BY id");
        symQ.bindValue(":s", se.id);
        if (!symQ.exec()) continue;

        while (symQ.next()) {
            const QString symId = symQ.value(1).toString();
            if (hilfs.contains(symId)) continue;
            const bool istBoard = boards.contains(symId);
            if (segPunkte.isEmpty() && !istBoard) continue;

            const int    elId = symQ.value(0).toInt();
            const double x1 = symQ.value(2).toDouble(), y1 = symQ.value(3).toDouble();
            const double x2 = symQ.value(4).toDouble(), y2 = symQ.value(5).toDouble();
            const double rad = symQ.value(6).toInt() * M_PI / 180.0;
            const bool spX = symQ.value(7).toInt() != 0, spY = symQ.value(8).toInt() != 0;
            const QJsonObject ext = QJsonDocument::fromJson(symQ.value(9).toString().toUtf8()).object();

            QString bmk = ext.value("bmk").toString();
            const QString anschluss = ext.value("anschlussBezeichnung").toString();

            const double sw = x2 - x1, sh = y2 - y1;
            const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
            const double cosR = std::cos(rad), sinR = std::sin(rad);

            for (const PinDef &p : pinsVon(symId)) {
                double cx = (p.x - 0.5) * std::abs(sw);
                double cy = (p.y - 0.5) * std::abs(sh);
                if (spX) cx = -cx;
                if (spY) cy = -cy;
                const double wx = scx + cx * cosR - cy * sinR;
                const double wy = scy + cx * sinR + cy * cosR;

                int netz = -1;
                for (auto it = segPunkte.constBegin(); it != segPunkte.constEnd() && netz < 0; ++it)
                    for (const Pt &pt : it.value())
                        if (std::abs(pt.x - wx) < eps && std::abs(pt.y - wy) < eps) { netz = it.key(); break; }

                if (istBoard)
                    boardPins.push_back({elId, symId, bmk, p.name, se.id, se.blatt, se.bez, scx, scy, netz});
                if (netz >= 0) {
                    NetPin np;
                    np.elementId = elId; np.symbolId = symId; np.symbolName = symbolName(symId);
                    np.bmk = bmk; np.seiteId = se.id; np.istBoard = istBoard;
                    np.pin = anschluss.isEmpty() ? p.name : anschluss;
                    netMitglieder[netz].push_back(np);
                }
            }
        }
    }

    // Zeilen aufbauen + #define-Namen je Board eindeutig vergeben
    QHash<QString, QSet<QString>> definesJeBoard;   // Element → belegte Namen
    for (const BoardPin &bp : boardPins) {
        QList<NetPin> verbunden;
        if (bp.netz >= 0)
            for (const NetPin &np : netMitglieder.value(bp.netz))
                if (np.elementId != bp.elementId) verbunden.push_back(np);

        const QString literal = pinLiteral(bp.pin);
        QString defineName;
        bool defineVergeben = false;

        auto basisZeile = [&]() {
            QVariantMap m;
            m["elementId"]   = bp.elementId;
            m["boardBmk"]    = bp.bmk;
            m["boardName"]   = symbolName(bp.symbolId);
            m["pin"]         = bp.pin;
            m["netz"]        = bp.netz >= 0 ? netzName.value(bp.netz) : QString();
            m["seiteId"]     = bp.seiteId;
            m["blattnr"]     = bp.blatt;
            m["seiteBez"]    = bp.seiteBez;
            m["weltX"]       = bp.wx;
            m["weltY"]       = bp.wy;
            return m;
        };

        if (verbunden.isEmpty()) {
            QVariantMap m = basisZeile();
            m["verbundenBmk"] = QString(); m["verbundenSymbol"] = QString(); m["verbundenPin"] = QString();
            m["istFrei"] = true;
            m["defineName"] = QString(); m["defineWert"] = QString();
            ergebnis << m;
            continue;
        }
        for (const NetPin &np : verbunden) {
            QVariantMap m = basisZeile();
            m["verbundenBmk"]    = np.bmk;
            m["verbundenSymbol"] = np.symbolName;
            m["verbundenPin"]    = np.pin;
            m["verbundenIstBoard"] = np.istBoard;
            m["istFrei"]         = false;

            // #define nur für die erste nicht-Board-Gegenstelle eines digitalen/analogen Pins
            if (!defineVergeben && !literal.isEmpty() && !np.istBoard) {
                QString basis = bezeichnerBereinigen(np.bmk.isEmpty() ? np.symbolName : np.bmk);
                const QString pinTeil = bezeichnerBereinigen(np.pin);
                if (!pinTeil.isEmpty() && basis != pinTeil) basis += QLatin1Char('_') + pinTeil;
                if (basis.isEmpty()) basis = QStringLiteral("PIN_") + bezeichnerBereinigen(bp.pin);
                const QString key = QString::number(bp.elementId);
                QString name = basis;
                int n = 2;
                while (definesJeBoard[key].contains(name)) name = basis + QLatin1Char('_') + QString::number(n++);
                definesJeBoard[key].insert(name);
                defineName = name;
                defineVergeben = true;
                m["defineName"] = defineName;
                m["defineWert"] = literal;
            } else {
                m["defineName"] = QString();
                m["defineWert"] = QString();
            }
            ergebnis << m;
        }
    }
    return ergebnis;
}

QString Database::mikrocontrollerCode(int projektId)
{
    const QVariantList zeilen = mikrocontrollerPinbelegung(projektId);
    QString out;
    QMap<int, QStringList> jeBoard;     // elementId → define-Zeilen
    QMap<int, QString> kopf;
    QList<int> reihenfolge;
    for (const QVariant &v : zeilen) {
        const QVariantMap m = v.toMap();
        const int id = m["elementId"].toInt();
        if (!kopf.contains(id)) {
            const QString bmk = m["boardBmk"].toString();
            kopf[id] = QStringLiteral("// Board: %1 (%2), Blatt %3")
                           .arg(bmk.isEmpty() ? QStringLiteral("ohne BMK") : bmk,
                                m["boardName"].toString(), m["blattnr"].toString());
            reihenfolge << id;
        }
        if (!m["defineName"].toString().isEmpty())
            jeBoard[id] << QStringLiteral("#define %1 %2   // %3 – %4")
                               .arg(m["defineName"].toString(), m["defineWert"].toString(),
                                    m["pin"].toString(), m["verbundenSymbol"].toString());
    }
    for (int id : reihenfolge) {
        out += kopf[id] + QLatin1Char('\n');
        const QStringList defs = jeBoard.value(id);
        if (defs.isEmpty()) out += QStringLiteral("// (keine belegten digitalen/analogen Pins)\n");
        else out += defs.join(QLatin1Char('\n')) + QLatin1Char('\n');
        out += QLatin1Char('\n');
    }
    return out;
}

bool Database::mikrocontrollerPinbelegungCsvSpeichern(int projektId, const QString &pfad)
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "mikrocontrollerPinbelegungCsvSpeichern"))
        return false;
    out << "Board-BMK;Board;Pin;Netz;Verbunden mit (BMK);Bauteil;Anschluss;#define;Wert;Seite\n";
    auto csv = CsvHelfer::escapeBedarf;
    for (const QVariant &v : mikrocontrollerPinbelegung(projektId)) {
        const QVariantMap m = v.toMap();
        out << csv(m["boardBmk"].toString()) << u';' << csv(m["boardName"].toString()) << u';'
            << csv(m["pin"].toString()) << u';' << csv(m["netz"].toString()) << u';'
            << csv(m["verbundenBmk"].toString()) << u';' << csv(m["verbundenSymbol"].toString()) << u';'
            << csv(m["verbundenPin"].toString()) << u';' << csv(m["defineName"].toString()) << u';'
            << csv(m["defineWert"].toString()) << u';' << csv(m["blattnr"].toString()) << u'\n';
    }
    return true;
}
