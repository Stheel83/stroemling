#include "logging.h"
#include "SymbolDefinitionModel.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QHash>
#include <QQueue>
#include <QPointF>
#include <cmath>
#include <algorithm>
#include <limits>

SymbolDefinitionModel::SymbolDefinitionModel(QObject *parent)
    : QObject(parent)
{
}

// ── Lesemethoden ────────────────────────────────────────────────────────────

QVariantList SymbolDefinitionModel::primitiveFuerSymbol(const QString &symbolId) const
{
    auto it = m_primitivCache.find(symbolId);
    if (it != m_primitivCache.end())
        return it.value();

    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id,
               typ,
               x1, y1, x2, y2, x3, y3,
               radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
               text_inhalt, schrift_relativ, schrift_fett,
               text_align, text_baseline, linienart
        FROM symbol_primitiv
        WHERE symbol_id = :sym
        ORDER BY reihenfolge
    )");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qCWarning(lcModel) << "primitiveFuerSymbol:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]                    = q.value(0).toInt();
        m["typ"]                   = q.value(1).toString();
        m["x1"]                    = q.value(2).toDouble();
        m["y1"]                    = q.value(3).toDouble();
        m["x2"]                    = q.value(4).toDouble();
        m["y2"]                    = q.value(5).toDouble();
        m["x3"]                    = q.value(6).toDouble();
        m["y3"]                    = q.value(7).toDouble();
        m["radius"]                = q.value(8).toDouble();
        m["winkel_von"]            = q.value(9).toDouble();
        m["winkel_bis"]            = q.value(10).toDouble();
        m["bogen_gegen_uhrzeiger"] = q.value(11).toInt() != 0;
        m["text_inhalt"]           = q.value(12).toString();
        m["schrift_relativ"]       = q.value(13).toDouble();
        m["schrift_fett"]          = q.value(14).toInt() != 0;
        m["text_align"]            = q.value(15).toString();
        m["text_baseline"]         = q.value(16).toString();
        m["linienart"]             = q.value(17).toString();
        result.append(m);
    }
    m_primitivCache.insert(symbolId, result);
    return result;
}

bool SymbolDefinitionModel::hatPrimitive(const QString &symbolId) const
{
    QSqlQuery q;
    q.prepare("SELECT 1 FROM symbol_definition WHERE id = :sym LIMIT 1");
    q.bindValue(":sym", symbolId);
    if (q.exec() && q.next())
        return true;
    return false;
}

QVariantList SymbolDefinitionModel::pinsForSymbol(const QString &symbolId) const
{
    auto it = m_pinCache.find(symbolId);
    if (it != m_pinCache.end())
        return it.value();

    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, name, x, y, offen_x, offen_y, signaltyp, kontext
        FROM symbol_pin
        WHERE symbol_id = :sym
    )");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qCWarning(lcModel) << "pinsForSymbol:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap offen;
        offen["x"] = q.value(4).toDouble();
        offen["y"] = q.value(5).toDouble();

        QVariantMap m;
        m["id"]        = q.value(0).toInt();
        m["name"]      = q.value(1).toString();
        m["x"]         = q.value(2).toDouble();
        m["y"]         = q.value(3).toDouble();
        m["offen"]     = offen;
        m["offenX"]    = q.value(4).toDouble();
        m["offenY"]    = q.value(5).toDouble();
        m["signaltyp"] = q.value(6).toString();
        m["kontext"]   = q.value(7).toString();
        result.append(m);
    }
    m_pinCache.insert(symbolId, result);
    return result;
}

QString SymbolDefinitionModel::rolleForSymbol(const QString &symbolId) const
{
    QSqlQuery q;
    q.prepare("SELECT rolle FROM symbol_definition WHERE id = :sym LIMIT 1");
    q.bindValue(":sym", symbolId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("durchleiter");
}

QVariantMap SymbolDefinitionModel::symbolInfo(const QString &symbolId) const
{
    QSqlQuery q;
    q.prepare("SELECT name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite FROM symbol_definition WHERE id = :id LIMIT 1");
    q.bindValue(":id", symbolId);
    if (q.exec() && q.next()) {
        QVariantMap m;
        m["name"]        = q.value(0).toString();
        m["kategorie"]   = q.value(1).toString();
        m["breiteMm"]    = q.value(2).toInt();
        m["hoeheMm"]     = q.value(3).toInt();
        m["rolle"]       = q.value(4).toString();
        m["ist_builtin"] = q.value(5).toInt() != 0;
        m["bmkSeite"]    = q.value(6).toString();
        return m;
    }
    return {};
}

QVariantList SymbolDefinitionModel::alleSymbole() const
{
    QVariantList result;
    QSqlQuery q("SELECT id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin FROM symbol_definition ORDER BY ist_builtin DESC, kategorie, name");
    while (q.next()) {
        QVariantMap m;
        m["id"]          = q.value(0).toString();
        m["name"]        = q.value(1).toString();
        m["kategorie"]   = q.value(2).toString();
        m["breiteMm"]    = q.value(3).toInt();
        m["hoeheMm"]     = q.value(4).toInt();
        m["rolle"]       = q.value(5).toString();
        m["ist_builtin"] = q.value(6).toInt() != 0;
        result.append(m);
    }
    return result;
}

// ── Schreibmethoden ─────────────────────────────────────────────────────────

bool SymbolDefinitionModel::symbolAnlegen(const QString &id, const QString &name,
                                           const QString &kategorie, int breiteMm, int hoeheMm,
                                           const QString &rolle)
{
    QSqlQuery q;
    q.prepare("INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES (:id, :name, :kat, :bMm, :hMm, :rolle, 0)");
    q.bindValue(":id",    id);
    q.bindValue(":name",  name);
    q.bindValue(":kat",   kategorie);
    q.bindValue(":bMm",   breiteMm);
    q.bindValue(":hMm",   hoeheMm);
    q.bindValue(":rolle", rolle);
    if (!q.exec()) {
        qCWarning(lcModel) << "symbolAnlegen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool SymbolDefinitionModel::symbolAktualisieren(const QString &id, const QString &name,
                                                  const QString &kategorie, int breiteMm, int hoeheMm,
                                                  const QString &rolle)
{
    QSqlQuery q;
    q.prepare("UPDATE symbol_definition SET name=:name, kategorie=:kat, breite_mm=:bMm, hoehe_mm=:hMm, rolle=:rolle WHERE id=:id AND ist_builtin=0");
    q.bindValue(":name",  name);
    q.bindValue(":kat",   kategorie);
    q.bindValue(":bMm",   breiteMm);
    q.bindValue(":hMm",   hoeheMm);
    q.bindValue(":rolle", rolle);
    q.bindValue(":id",    id);
    if (!q.exec()) {
        qCWarning(lcModel) << "symbolAktualisieren:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool SymbolDefinitionModel::symbolLoeschen(const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM symbol_definition WHERE id=:id AND ist_builtin=0");
    q.bindValue(":id", symbolId);
    if (!q.exec()) {
        qCWarning(lcModel) << "symbolLoeschen:" << q.lastError().text();
        return false;
    }
    m_primitivCache.remove(symbolId);
    m_pinCache.remove(symbolId);
    return q.numRowsAffected() > 0;
}

void SymbolDefinitionModel::cacheLeeren()
{
    m_primitivCache.clear();
    m_pinCache.clear();
}

int SymbolDefinitionModel::primitivHinzufuegen(const QString &symbolId, const QVariantMap &daten)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO symbol_primitiv
            (symbol_id, reihenfolge, typ,
             x1, y1, x2, y2, x3, y3,
             radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
             text_inhalt, schrift_relativ, schrift_fett,
             text_align, text_baseline, linienart)
        VALUES
            (:sym, :reihe, :typ,
             :x1, :y1, :x2, :y2, :x3, :y3,
             :rad, :wvon, :wbis, :ccw,
             :ti, :sr, :sf,
             :ta, :tb, :la)
    )");
    q.bindValue(":sym",   symbolId);
    q.bindValue(":reihe", daten.value("reihenfolge", 0));
    q.bindValue(":typ",   daten.value("typ", "linie"));
    q.bindValue(":x1",    daten.value("x1", 0.0));
    q.bindValue(":y1",    daten.value("y1", 0.0));
    q.bindValue(":x2",    daten.value("x2", 0.0));
    q.bindValue(":y2",    daten.value("y2", 0.0));
    q.bindValue(":x3",    daten.value("x3", 0.0));
    q.bindValue(":y3",    daten.value("y3", 0.0));
    q.bindValue(":rad",   daten.value("radius", 0.0));
    q.bindValue(":wvon",  daten.value("winkel_von", 0.0));
    q.bindValue(":wbis",  daten.value("winkel_bis", 360.0));
    q.bindValue(":ccw",   daten.value("bogen_gegen_uhrzeiger", false).toBool() ? 1 : 0);
    q.bindValue(":ti",    daten.value("text_inhalt", ""));
    q.bindValue(":sr",    daten.value("schrift_relativ", 0.15));
    q.bindValue(":sf",    daten.value("schrift_fett", false).toBool() ? 1 : 0);
    q.bindValue(":ta",    daten.value("text_align", "center"));
    q.bindValue(":tb",    daten.value("text_baseline", "middle"));
    q.bindValue(":la",    daten.value("linienart", "solid"));
    if (!q.exec()) {
        qCWarning(lcModel) << "primitivHinzufuegen:" << q.lastError().text();
        return -1;
    }
    m_primitivCache.remove(symbolId);
    return q.lastInsertId().toInt();
}

bool SymbolDefinitionModel::primitivAlleLoeschen(const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM symbol_primitiv WHERE symbol_id = :sym");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qCWarning(lcModel) << "primitivAlleLoeschen:" << q.lastError().text();
        return false;
    }
    m_primitivCache.remove(symbolId);
    return true;
}

int SymbolDefinitionModel::pinHinzufuegen(const QString &symbolId, const QVariantMap &daten)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, kontext)
        VALUES (:sym, :name, :x, :y, :ox, :oy, :sig, :ctx)
    )");
    q.bindValue(":sym",  symbolId);
    q.bindValue(":name", daten.value("name", ""));
    q.bindValue(":x",    daten.value("x", 0.0));
    q.bindValue(":y",    daten.value("y", 0.5));
    q.bindValue(":ox",   daten.value("offenX", -1.0));
    q.bindValue(":oy",   daten.value("offenY", 0.0));
    q.bindValue(":sig",  daten.value("signaltyp", "neutral"));
    q.bindValue(":ctx",  daten.value("kontext", ""));
    if (!q.exec()) {
        qCWarning(lcModel) << "pinHinzufuegen:" << q.lastError().text();
        return -1;
    }
    m_pinCache.remove(symbolId);
    return q.lastInsertId().toInt();
}

bool SymbolDefinitionModel::pinAlleLoeschen(const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM symbol_pin WHERE symbol_id = :sym");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qCWarning(lcModel) << "pinAlleLoeschen:" << q.lastError().text();
        return false;
    }
    m_pinCache.remove(symbolId);
    return true;
}

// ── autoVerbindungenBerechnen ─────────────────────────────────────────────
// Portierung des gleichnamigen JS-Algorithmus aus SchaltplanCanvas.qml.
// Läuft im C++-Thread, vermeidet JS-GC-Pausen bei großen Schaltplänen.
// ─────────────────────────────────────────────────────────────────────────

namespace {

struct PinInfo {
    double  x, y;
    int     elIdx;
    QString richtung;
    bool    hatOffen = false;
    double  offenX   = 0.0, offenY = 0.0;
    QString rolle;
    QString quellSig;
};

struct Unterbrechung { double cx, cy, hw, hh; };
struct StrukturKasten { double x1, y1, x2, y2; QString anlage, ort; };

static QPointF pinWeltPos(const QVariantMap &el, double pinX, double pinY)
{
    const double x1 = el["x1"].toDouble(), y1 = el["y1"].toDouble();
    const double x2 = el["x2"].toDouble(), y2 = el["y2"].toDouble();
    const double sw = x2 - x1, sh = y2 - y1;
    const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
    double cx = (pinX - 0.5) * std::abs(sw);
    double cy = (pinY - 0.5) * std::abs(sh);
    if (el["spiegelX"].toBool()) cx = -cx;
    if (el["spiegelY"].toBool()) cy = -cy;
    const double rot = el["rotation"].toDouble() * M_PI / 180.0;
    return { scx + cx * std::cos(rot) - cy * std::sin(rot),
             scy + cx * std::sin(rot) + cy * std::cos(rot) };
}

static QString pinEffektiveRichtung(const QString &richtung, double rotation)
{
    if (richtung.isEmpty()) return {};
    const int rot = (static_cast<int>(rotation) % 360 + 360) % 360;
    if (rot == 90 || rot == 270)
        return richtung == QLatin1String("H") ? QStringLiteral("V") : QStringLiteral("H");
    return richtung;
}

static bool hBlockiert(double ax, double bx, double y,
                        const QVector<Unterbrechung> &ub, double gridPx)
{
    const double xMin = std::min(ax, bx), xMax = std::max(ax, bx);
    for (const auto &u : ub)
        if (std::abs(u.cy - y) <= u.hh + gridPx * 0.5 && u.cx > xMin && u.cx < xMax)
            return true;
    return false;
}

static bool vBlockiert(double x, double ay, double by,
                        const QVector<Unterbrechung> &ub, double gridPx)
{
    const double yMin = std::min(ay, by), yMax = std::max(ay, by);
    for (const auto &u : ub)
        if (std::abs(u.cx - x) <= u.hw + gridPx * 0.5 && u.cy > yMin && u.cy < yMax)
            return true;
    return false;
}

} // namespace

QVariantList SymbolDefinitionModel::autoVerbindungenBerechnen(
    const QVariantList &snapshot, double gridPx, const QVariantMap &normblatt) const
{
    const double eps = 0.1;

    // ── 1. Pin-Weltpositionen + blockierende Elemente sammeln ────────────
    QVector<PinInfo>      allePins;
    QVector<Unterbrechung> unterbrechungen;
    QVector<StrukturKasten> kaesten;

    for (int i = 0; i < snapshot.size(); i++) {
        const QVariantMap el = snapshot[i].toMap();
        const QString     typ = el["typ"].toString();

        if (typ == QLatin1String("strukturkasten")) {
            const QVariantMap ed = el["extraDaten"].toMap();
            kaesten.append({
                std::min(el["x1"].toDouble(), el["x2"].toDouble()),
                std::min(el["y1"].toDouble(), el["y2"].toDouble()),
                std::max(el["x1"].toDouble(), el["x2"].toDouble()),
                std::max(el["y1"].toDouble(), el["y2"].toDouble()),
                ed.value("anlage").toString(),
                ed.value("ort").toString()
            });
            continue;
        }
        if (typ != QLatin1String("symbol")) continue;

        const QString symbolId = el["symbolId"].toString();
        const bool istSperrelement = (symbolId == QLatin1String("unterbrechung") ||
                                      symbolId == QLatin1String("querverweis"));
        if (istSperrelement) {
            unterbrechungen.append({
                (el["x1"].toDouble() + el["x2"].toDouble()) / 2.0,
                (el["y1"].toDouble() + el["y2"].toDouble()) / 2.0,
                std::abs(el["x2"].toDouble() - el["x1"].toDouble()) / 2.0,
                std::abs(el["y2"].toDouble() - el["y1"].toDouble()) / 2.0
            });
        }

        // Pins ermitteln
        QVariantList pins;
        if (symbolId == QLatin1String("querverweis")) {
            const QVariantMap ed = el["extraDaten"].toMap();
            const bool eingang = (ed.value("richtung").toString() == QLatin1String("eingang"));
            QVariantMap pin;
            pin["name"] = QStringLiteral("1");
            pin["x"]    = eingang ? 1.0 : 0.0;
            pin["y"]    = 0.5;
            pin["richtung"] = QString();
            QVariantMap offen;
            offen["x"] = eingang ? 1 : -1;
            offen["y"] = 0;
            pin["offen"] = offen;
            pins.append(pin);
        } else {
            pins = pinsForSymbol(symbolId);
        }
        if (pins.isEmpty()) continue;

        // Rolle + Quell-Signaltyp
        QString rolle = rolleForSymbol(symbolId);
        const QVariantMap ed = el["extraDaten"].toMap();
        if (rolle == QLatin1String("variabel"))
            rolle = ed.value("rolle", QStringLiteral("ziel")).toString();
        const QString quellSig = (rolle == QLatin1String("quelle"))
                                 ? ed.value("signaltyp", QStringLiteral("neutral")).toString()
                                 : QStringLiteral("neutral");

        const double rotation = el["rotation"].toDouble();
        const double rot  = rotation * M_PI / 180.0;
        const double cosR = std::cos(rot), sinR = std::sin(rot);
        const bool spX = el["spiegelX"].toBool(), spY = el["spiegelY"].toBool();

        for (const QVariant &pv : pins) {
            const QVariantMap pin = pv.toMap();
            const QPointF pos = pinWeltPos(el, pin["x"].toDouble(), pin["y"].toDouble());

            PinInfo pi;
            pi.x        = pos.x();
            pi.y        = pos.y();
            pi.elIdx    = i;
            pi.richtung = pinEffektiveRichtung(pin["richtung"].toString(), rotation);
            pi.rolle    = rolle;
            pi.quellSig = quellSig;

            const QVariantMap offen = pin["offen"].toMap();
            if (!offen.isEmpty()) {
                double ox = spX ? -offen["x"].toDouble() : offen["x"].toDouble();
                double oy = spY ? -offen["y"].toDouble() : offen["y"].toDouble();
                pi.hatOffen = true;
                pi.offenX   = ox * cosR - oy * sinR;
                pi.offenY   = ox * sinR + oy * cosR;
            }
            allePins.append(pi);
        }
    }

    // ── 2. H-Lanes ──────────────────────────────────────────────────────
    QVariantList verbindungen;

    QHash<int, QVector<PinInfo>> hLanes;
    for (const PinInfo &p : allePins) {
        if (p.richtung == QLatin1String("V")) continue;
        hLanes[static_cast<int>(std::round(p.y / gridPx))].append(p);
    }
    for (auto &lane : hLanes) {
        if (lane.size() < 2) continue;
        std::sort(lane.begin(), lane.end(), [](const PinInfo &a, const PinInfo &b) {
            return a.x < b.x;
        });
        for (int li = 0; li < lane.size() - 1; li++) {
            const PinInfo &a = lane[li], &b = lane[li + 1];
            if (a.elIdx == b.elIdx) continue;
            if ((!a.hatOffen || a.offenX > eps) &&
                (!b.hatOffen || b.offenX < -eps) &&
                !hBlockiert(a.x, b.x, a.y, unterbrechungen, gridPx))
            {
                QVariantMap v;
                v["x1"] = a.x; v["y1"] = a.y; v["x2"] = b.x; v["y2"] = b.y;
                v["elIdxA"] = a.elIdx; v["rolleA"] = a.rolle; v["quellSigA"] = a.quellSig;
                v["elIdxB"] = b.elIdx; v["rolleB"] = b.rolle; v["quellSigB"] = b.quellSig;
                v["signaltyp"] = QStringLiteral("neutral");
                verbindungen.append(v);
            }
        }
    }

    // ── 3. V-Lanes ──────────────────────────────────────────────────────
    QHash<int, QVector<PinInfo>> vLanes;
    for (const PinInfo &p : allePins) {
        if (p.richtung == QLatin1String("H")) continue;
        vLanes[static_cast<int>(std::round(p.x / gridPx))].append(p);
    }
    for (auto &lane : vLanes) {
        if (lane.size() < 2) continue;
        std::sort(lane.begin(), lane.end(), [](const PinInfo &a, const PinInfo &b) {
            return a.y < b.y;
        });
        for (int li = 0; li < lane.size() - 1; li++) {
            const PinInfo &a = lane[li], &b = lane[li + 1];
            if (a.elIdx == b.elIdx) continue;
            if ((!a.hatOffen || a.offenY > eps) &&
                (!b.hatOffen || b.offenY < -eps) &&
                !vBlockiert(a.x, a.y, b.y, unterbrechungen, gridPx))
            {
                QVariantMap v;
                v["x1"] = a.x; v["y1"] = a.y; v["x2"] = b.x; v["y2"] = b.y;
                v["elIdxA"] = a.elIdx; v["rolleA"] = a.rolle; v["quellSigA"] = a.quellSig;
                v["elIdxB"] = b.elIdx; v["rolleB"] = b.rolle; v["quellSigB"] = b.quellSig;
                v["signaltyp"] = QStringLiteral("neutral");
                verbindungen.append(v);
            }
        }
    }

    // ── 4. Querverweis-Pairing (projektweiter Signalname) ───────────────
    auto anlageOrtFuer = [&](const QVariantMap &el) -> QPair<QString,QString> {
        const double cx = (el["x1"].toDouble() + el["x2"].toDouble()) / 2.0;
        const double cy = (el["y1"].toDouble() + el["y2"].toDouble()) / 2.0;
        QString anlage = normblatt.value("anlageKuerzel").toString();
        QString ort    = normblatt.value("ortKuerzel").toString();
        double bestArea = std::numeric_limits<double>::infinity();
        for (const auto &sk : kaesten) {
            if (cx >= sk.x1 && cx <= sk.x2 && cy >= sk.y1 && cy <= sk.y2) {
                const double area = (sk.x2 - sk.x1) * (sk.y2 - sk.y1);
                if (area < bestArea) {
                    bestArea = area;
                    if (!sk.anlage.isEmpty()) anlage = sk.anlage;
                    if (!sk.ort.isEmpty())    ort    = sk.ort;
                }
            }
        }
        return { anlage, ort };
    };

    QHash<QString, QVector<int>> qvBySignal;
    for (int i = 0; i < snapshot.size(); i++) {
        const QVariantMap el = snapshot[i].toMap();
        if (el["typ"].toString() != QLatin1String("symbol") ||
            el["symbolId"].toString() != QLatin1String("querverweis")) continue;
        const QVariantMap ed  = el["extraDaten"].toMap();
        const QString sn      = ed.value("signalname").toString();
        if (sn.isEmpty()) continue;
        const QString mode    = ed.value("suchmodus", QStringLiteral("signal")).toString();
        QString key = sn;
        if (mode == QLatin1String("bmk")) {
            const auto ao = anlageOrtFuer(el);
            key = sn + QLatin1Char('|') + ao.first + QLatin1Char('+') + ao.second;
        }
        qvBySignal[key].append(i);
    }
    for (auto it = qvBySignal.cbegin(); it != qvBySignal.cend(); ++it) {
        const QVector<int> &grp = it.value();
        for (int gi = 1; gi < grp.size(); gi++) {
            const QVariantMap qvA = snapshot[grp[0]].toMap();
            const QVariantMap qvB = snapshot[grp[gi]].toMap();
            const double pinAxR = (qvA["extraDaten"].toMap().value("richtung").toString()
                                   == QLatin1String("eingang")) ? 1.0 : 0.0;
            const double pinBxR = (qvB["extraDaten"].toMap().value("richtung").toString()
                                   == QLatin1String("eingang")) ? 1.0 : 0.0;
            const QPointF posA = pinWeltPos(qvA, pinAxR, 0.5);
            const QPointF posB = pinWeltPos(qvB, pinBxR, 0.5);
            QVariantMap v;
            v["x1"] = posA.x(); v["y1"] = posA.y();
            v["x2"] = posB.x(); v["y2"] = posB.y();
            v["elIdxA"] = grp[0];   v["rolleA"] = QStringLiteral("durchleiter"); v["quellSigA"] = QStringLiteral("neutral");
            v["elIdxB"] = grp[gi];  v["rolleB"] = QStringLiteral("durchleiter"); v["quellSigB"] = QStringLiteral("neutral");
            v["signaltyp"] = QStringLiteral("neutral");
            v["logisch"]   = true;
            verbindungen.append(v);
        }
    }

    // ── 5. Potenzial-Propagation (BFS von Quellen) ──────────────────────
    if (!verbindungen.isEmpty()) {
        struct NbEntry { int nb, ci; };
        QHash<int, QVector<NbEntry>> adj;
        for (int ci = 0; ci < verbindungen.size(); ci++) {
            const QVariantMap c = verbindungen[ci].toMap();
            const int ia = c["elIdxA"].toInt(), ib = c["elIdxB"].toInt();
            adj[ia].append({ ib, ci });
            adj[ib].append({ ia, ci });
        }

        QHash<int, QString> besucht;
        QQueue<QPair<int,QString>> queue;
        for (int ci = 0; ci < verbindungen.size(); ci++) {
            const QVariantMap &qc = verbindungen[ci].toMap();
            const int ia = qc["elIdxA"].toInt(), ib = qc["elIdxB"].toInt();
            if (qc["rolleA"].toString() == QLatin1String("quelle") && !besucht.contains(ia)) {
                besucht[ia] = qc["quellSigA"].toString();
                queue.enqueue({ ia, qc["quellSigA"].toString() });
            }
            if (qc["rolleB"].toString() == QLatin1String("quelle") && !besucht.contains(ib)) {
                besucht[ib] = qc["quellSigB"].toString();
                queue.enqueue({ ib, qc["quellSigB"].toString() });
            }
        }

        while (!queue.isEmpty()) {
            const auto [curIdx, curSig] = queue.dequeue();
            for (const NbEntry &nb : adj.value(curIdx)) {
                QVariantMap conn = verbindungen[nb.ci].toMap();

                // Verbindungsfarbe setzen
                const QString st = conn["signaltyp"].toString();
                if (st == QLatin1String("neutral"))
                    conn["signaltyp"] = curSig;
                else if (st != curSig)
                    conn["signaltyp"] = QStringLiteral("konflikt");

                // Nachbar-Rolle: nicht durch Verbraucher/Ziel propagieren
                const QString nbRolle = (conn["elIdxA"].toInt() == curIdx)
                                        ? conn["rolleB"].toString()
                                        : conn["rolleA"].toString();
                verbindungen[nb.ci] = conn;

                if (nbRolle == QLatin1String("verbraucher") ||
                    nbRolle == QLatin1String("ziel")) continue;

                if (besucht.contains(nb.nb)) {
                    if (besucht[nb.nb] != curSig) {
                        QVariantMap c2 = verbindungen[nb.ci].toMap();
                        c2["signaltyp"] = QStringLiteral("konflikt");
                        verbindungen[nb.ci] = c2;
                    }
                    continue;
                }
                besucht[nb.nb] = curSig;
                queue.enqueue({ nb.nb, curSig });
            }
        }

        // Verbindungen ohne Quellenversorgung als "unversorgt" markieren
        for (int ci2 = 0; ci2 < verbindungen.size(); ci2++) {
            QVariantMap c2 = verbindungen[ci2].toMap();
            if (c2["signaltyp"].toString() != QLatin1String("neutral")) continue;
            const int ia = c2["elIdxA"].toInt(), ib = c2["elIdxB"].toInt();
            if (besucht.contains(ia) || besucht.contains(ib)) continue;
            const QString rA = c2["rolleA"].toString(), rB = c2["rolleB"].toString();
            if (rA == QLatin1String("ziel")        || rA == QLatin1String("verbraucher") ||
                rB == QLatin1String("ziel")        || rB == QLatin1String("verbraucher"))
            {
                c2["signaltyp"] = QStringLiteral("unversorgt");
                verbindungen[ci2] = c2;
            }
        }
    }

    return verbindungen;
}
