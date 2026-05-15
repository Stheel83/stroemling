#include "ElementeModel.h"
#include <cmath>
#include <algorithm>
#include <QSqlQuery>
#include <QSqlError>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QJsonValue>
#include <QByteArray>
#include <QVariant>

QVariantMap GrafikElement::toVariantMap() const
{
    QVariantMap el;
    el[QStringLiteral("id")]             = id;
    el[QStringLiteral("typ")]            = typ;
    el[QStringLiteral("x1")]             = x1;
    el[QStringLiteral("y1")]             = y1;
    el[QStringLiteral("x2")]             = x2;
    el[QStringLiteral("y2")]             = y2;
    el[QStringLiteral("strichFarbe")]    = strichFarbe;
    el[QStringLiteral("strichBreite")]   = strichBreite;
    el[QStringLiteral("strichArt")]      = strichArt;
    el[QStringLiteral("fuell")]          = fuell;
    el[QStringLiteral("fuellFarbe")]     = fuellFarbe;
    el[QStringLiteral("fuellOpazitaet")] = fuellOpazitaet;
    el[QStringLiteral("opazitaet")]      = opazitaet;
    el[QStringLiteral("eckenRadius")]    = eckenRadius;
    el[QStringLiteral("symbolId")]       = symbolId;
    el[QStringLiteral("rotation")]       = rotation;
    el[QStringLiteral("spiegelX")]       = spiegelX;
    el[QStringLiteral("spiegelY")]       = spiegelY;
    if (!punkte.isEmpty())
        el[QStringLiteral("punkte")]     = punkte;
    if (!textInhalt.isEmpty())
        el[QStringLiteral("textInhalt")] = textInhalt;
    el[QStringLiteral("textAusrichtung")] = textAusrichtung.isEmpty()
                                            ? QStringLiteral("links") : textAusrichtung;
    el[QStringLiteral("textEinpassen")]  = textEinpassen;
    if (!bildDaten.isEmpty())
        el[QStringLiteral("bildDaten")]  = bildDaten;
    if (!extraDaten.isEmpty())
        el[QStringLiteral("extraDaten")] = extraDaten;
    if (betriebsmittelId != 0)
        el[QStringLiteral("betriebsmittelId")] = betriebsmittelId;
    return el;
}

ElementeModel::ElementeModel(QObject *parent)
    : QObject(parent)
{}

void ElementeModel::laden(int seiteId)
{
    m_elemente.clear();
    m_undoStack.clear();
    m_redoStack.clear();

    QSqlQuery q;
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
    q.bindValue(QStringLiteral(":sid"), seiteId);
    if (!q.exec()) {
        qWarning() << "ElementeModel::laden:" << q.lastError().text();
        emit geaendert();
        return;
    }

    while (q.next()) {
        GrafikElement el;
        el.id             = q.value(0).toInt();
        el.typ            = q.value(1).toString();
        el.x1             = q.value(2).toDouble();
        el.y1             = q.value(3).toDouble();
        el.x2             = q.value(4).toDouble();
        el.y2             = q.value(5).toDouble();
        el.strichFarbe    = q.value(6).toString();
        el.strichBreite   = q.value(7).toDouble();
        el.strichArt      = q.value(8).toString();
        el.fuell          = q.value(9).toInt() != 0;
        el.fuellFarbe     = q.value(10).toString();
        el.fuellOpazitaet = q.value(11).toDouble();
        el.opazitaet      = q.value(12).toDouble();
        el.eckenRadius    = q.value(13).toDouble();
        el.symbolId       = q.value(14).toString();
        el.rotation       = q.value(15).toInt();
        el.spiegelX       = q.value(16).toInt() != 0;
        el.spiegelY       = q.value(17).toInt() != 0;
        el.textInhalt     = q.value(19).toString();
        el.textAusrichtung = q.value(20).toString();
        el.textEinpassen  = q.value(21).toInt() != 0;

        QByteArray bildBytes = q.value(22).toByteArray();
        if (!bildBytes.isEmpty()) {
            QString bildMime = q.value(23).toString();
            if (bildMime.isEmpty())
                bildMime = QStringLiteral("image/png");
            el.bildDaten = QStringLiteral("data:") + bildMime
                           + QStringLiteral(";base64,")
                           + QString::fromLatin1(bildBytes.toBase64());
        }

        QString extraDatenStr = q.value(24).toString();
        if (!extraDatenStr.isEmpty()) {
            QJsonParseError jsonErr;
            QJsonDocument extraDoc = QJsonDocument::fromJson(extraDatenStr.toUtf8(), &jsonErr);
            if (!jsonErr.error && extraDoc.isObject())
                el.extraDaten = extraDoc.object().toVariantMap();
        }

        if (!q.value(25).isNull())
            el.betriebsmittelId = q.value(25).toInt();

        QString punkteStr = q.value(18).toString();
        if (!punkteStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(punkteStr.toUtf8(), &err);
            if (!err.error && doc.isArray()) {
                for (const QJsonValue &v : doc.array()) {
                    if (v.isObject()) {
                        QVariantMap p;
                        p[QStringLiteral("x")] = v[QStringLiteral("x")].toDouble();
                        p[QStringLiteral("y")] = v[QStringLiteral("y")].toDouble();
                        el.punkte.append(p);
                    }
                }
            }
        }

        m_elemente.push_back(std::move(el));
    }

    emit geaendert();
}

std::vector<GrafikElement> ElementeModel::parseVariantList(const QVariantList &liste)
{
    std::vector<GrafikElement> result;
    result.reserve(static_cast<size_t>(liste.size()));
    for (const QVariant &v : liste) {
        const QVariantMap m = v.toMap();
        GrafikElement el;
        el.id              = m.value(QStringLiteral("id")).toInt();
        el.typ             = m.value(QStringLiteral("typ")).toString();
        el.x1              = m.value(QStringLiteral("x1")).toDouble();
        el.y1              = m.value(QStringLiteral("y1")).toDouble();
        el.x2              = m.value(QStringLiteral("x2")).toDouble();
        el.y2              = m.value(QStringLiteral("y2")).toDouble();
        el.strichFarbe     = m.value(QStringLiteral("strichFarbe")).toString();
        el.strichBreite    = m.value(QStringLiteral("strichBreite")).toDouble();
        el.strichArt       = m.value(QStringLiteral("strichArt")).toString();
        el.fuell           = m.value(QStringLiteral("fuell")).toBool();
        el.fuellFarbe      = m.value(QStringLiteral("fuellFarbe")).toString();
        el.fuellOpazitaet  = m.value(QStringLiteral("fuellOpazitaet")).toDouble();
        el.opazitaet       = m.value(QStringLiteral("opazitaet")).toDouble();
        el.eckenRadius     = m.value(QStringLiteral("eckenRadius")).toDouble();
        el.symbolId        = m.value(QStringLiteral("symbolId")).toString();
        el.rotation        = m.value(QStringLiteral("rotation")).toInt();
        el.spiegelX        = m.value(QStringLiteral("spiegelX")).toBool();
        el.spiegelY        = m.value(QStringLiteral("spiegelY")).toBool();
        el.punkte          = m.value(QStringLiteral("punkte")).toList();
        el.textInhalt      = m.value(QStringLiteral("textInhalt")).toString();
        el.textAusrichtung = m.value(QStringLiteral("textAusrichtung")).toString();
        el.textEinpassen   = m.value(QStringLiteral("textEinpassen")).toBool();
        el.bildDaten       = m.value(QStringLiteral("bildDaten")).toString();
        el.extraDaten      = m.value(QStringLiteral("extraDaten")).toMap();
        el.betriebsmittelId = m.value(QStringLiteral("betriebsmittelId")).toInt();
        result.push_back(std::move(el));
    }
    return result;
}

void ElementeModel::fromVariantList(const QVariantList &liste)
{
    m_elemente = parseVariantList(liste);
    emit geaendert();
}

void ElementeModel::leeren()
{
    m_elemente.clear();
    m_undoStack.clear();
    m_redoStack.clear();
    emit geaendert();
}

QVariantList ElementeModel::snapshot() const
{
    QVariantList result;
    result.reserve(static_cast<int>(m_elemente.size()));
    for (const GrafikElement &el : m_elemente)
        result.append(el.toVariantMap());
    return result;
}

QVariantMap ElementeModel::element(int idx) const
{
    if (idx < 0 || idx >= static_cast<int>(m_elemente.size())) return {};
    return m_elemente[idx].toVariantMap();
}

int ElementeModel::anzahl() const
{
    return static_cast<int>(m_elemente.size());
}

// ── Mutationen ───────────────────────────────────────────────────────────────

static void applyField(GrafikElement &el, const QString &key, const QVariant &value)
{
    if      (key == QLatin1String("typ"))              el.typ              = value.toString();
    else if (key == QLatin1String("x1"))               el.x1               = value.toDouble();
    else if (key == QLatin1String("y1"))               el.y1               = value.toDouble();
    else if (key == QLatin1String("x2"))               el.x2               = value.toDouble();
    else if (key == QLatin1String("y2"))               el.y2               = value.toDouble();
    else if (key == QLatin1String("strichFarbe"))      el.strichFarbe      = value.toString();
    else if (key == QLatin1String("strichBreite"))     el.strichBreite     = value.toDouble();
    else if (key == QLatin1String("strichArt"))        el.strichArt        = value.toString();
    else if (key == QLatin1String("fuell"))            el.fuell            = value.toBool();
    else if (key == QLatin1String("fuellFarbe"))       el.fuellFarbe       = value.toString();
    else if (key == QLatin1String("fuellOpazitaet"))   el.fuellOpazitaet   = value.toDouble();
    else if (key == QLatin1String("opazitaet"))        el.opazitaet        = value.toDouble();
    else if (key == QLatin1String("eckenRadius"))      el.eckenRadius      = value.toDouble();
    else if (key == QLatin1String("symbolId"))         el.symbolId         = value.toString();
    else if (key == QLatin1String("rotation"))         el.rotation         = value.toInt();
    else if (key == QLatin1String("spiegelX"))         el.spiegelX         = value.toBool();
    else if (key == QLatin1String("spiegelY"))         el.spiegelY         = value.toBool();
    else if (key == QLatin1String("punkte"))           el.punkte           = value.toList();
    else if (key == QLatin1String("textInhalt"))       el.textInhalt       = value.toString();
    else if (key == QLatin1String("textAusrichtung"))  el.textAusrichtung  = value.toString();
    else if (key == QLatin1String("textEinpassen"))    el.textEinpassen    = value.toBool();
    else if (key == QLatin1String("bildDaten"))        el.bildDaten        = value.toString();
    else if (key == QLatin1String("extraDaten"))       el.extraDaten       = value.toMap();
    else if (key == QLatin1String("betriebsmittelId")) el.betriebsmittelId = value.toInt();
}

void ElementeModel::eigenschaftSetzen(int idx, const QString &key, const QVariant &value)
{
    if (idx < 0 || idx >= static_cast<int>(m_elemente.size())) return;
    applyField(m_elemente[idx], key, value);
    emit geaendert();
}

void ElementeModel::elementAktualisieren(int idx, const QVariantMap &felder)
{
    if (idx < 0 || idx >= static_cast<int>(m_elemente.size())) return;
    GrafikElement &el = m_elemente[idx];
    for (auto it = felder.constBegin(); it != felder.constEnd(); ++it)
        applyField(el, it.key(), it.value());
    emit geaendert();
}

// ── Undo / Redo ──────────────────────────────────────────────────────────────

void ElementeModel::undoCheckpoint()
{
    m_undoStack.push_back(m_elemente);
    m_redoStack.clear();
}

void ElementeModel::undoCheckpointFromSnapshot(const QVariantList &snapshot)
{
    m_undoStack.push_back(parseVariantList(snapshot));
    m_redoStack.clear();
}

void ElementeModel::undo()
{
    if (m_undoStack.empty()) return;
    m_redoStack.push_back(std::move(m_elemente));
    m_elemente = std::move(m_undoStack.back());
    m_undoStack.pop_back();
    emit geaendert();
}

void ElementeModel::redo()
{
    if (m_redoStack.empty()) return;
    m_undoStack.push_back(std::move(m_elemente));
    m_elemente = std::move(m_redoStack.back());
    m_redoStack.pop_back();
    emit geaendert();
}

bool ElementeModel::undoMoeglich() const { return !m_undoStack.empty(); }
bool ElementeModel::redoMoeglich() const { return !m_redoStack.empty(); }

// ── Hit-Testing ──────────────────────────────────────────────────────────────

static double punktZuStrecke(double px, double py,
                              double x1, double y1, double x2, double y2)
{
    double dx = x2-x1, dy = y2-y1;
    double lenSq = dx*dx + dy*dy;
    if (lenSq < 0.001)
        return std::sqrt((px-x1)*(px-x1) + (py-y1)*(py-y1));
    double t = std::max(0.0, std::min(1.0, ((px-x1)*dx + (py-y1)*dy) / lenSq));
    double qx = px-x1-t*dx, qy = py-y1-t*dy;
    return std::sqrt(qx*qx + qy*qy);
}

int ElementeModel::elementBeiPosition(double vpX, double vpY,
                                       double zoom, double worldX, double worldY) const
{
    const double s = 7.0;
    for (int i = static_cast<int>(m_elemente.size()) - 1; i >= 0; --i) {
        const GrafikElement &el = m_elemente[i];
        double vx1 = el.x1 * zoom + worldX, vy1 = el.y1 * zoom + worldY;
        double vx2 = el.x2 * zoom + worldX, vy2 = el.y2 * zoom + worldY;

        if (el.typ == QLatin1String("linie") || el.typ == QLatin1String("kabellinie")) {
            if (punktZuStrecke(vpX, vpY, vx1, vy1, vx2, vy2) < s) return i;
        } else if (el.typ == QLatin1String("polygonlinie")) {
            for (int pi = 0; pi + 1 < el.punkte.size(); ++pi) {
                const QVariantMap p1 = el.punkte[pi].toMap();
                const QVariantMap p2 = el.punkte[pi+1].toMap();
                double phx1 = p1.value(QStringLiteral("x")).toDouble() * zoom + worldX;
                double phy1 = p1.value(QStringLiteral("y")).toDouble() * zoom + worldY;
                double phx2 = p2.value(QStringLiteral("x")).toDouble() * zoom + worldX;
                double phy2 = p2.value(QStringLiteral("y")).toDouble() * zoom + worldY;
                if (punktZuStrecke(vpX, vpY, phx1, phy1, phx2, phy2) < s) return i;
            }
        } else if (el.typ == QLatin1String("rechteck")
                   || el.typ == QLatin1String("geraetekasten")
                   || el.typ == QLatin1String("strukturkasten")
                   || el.typ == QLatin1String("makrokasten")
                   || el.typ == QLatin1String("notiz")) {
            if (el.typ == QLatin1String("notiz")) {
                double nx1 = std::min(vx1,vx2)-s, ny1 = std::min(vy1,vy2)-s;
                double nx2 = std::max(vx1,vx2)+s, ny2 = std::max(vy1,vy2)+s;
                if (vpX >= nx1 && vpX <= nx2 && vpY >= ny1 && vpY <= ny2) return i;
            } else {
                if (punktZuStrecke(vpX, vpY, vx1,vy1, vx2,vy1) < s) return i;
                if (punktZuStrecke(vpX, vpY, vx2,vy1, vx2,vy2) < s) return i;
                if (punktZuStrecke(vpX, vpY, vx2,vy2, vx1,vy2) < s) return i;
                if (punktZuStrecke(vpX, vpY, vx1,vy2, vx1,vy1) < s) return i;
            }
        } else if (el.typ == QLatin1String("kreis")) {
            double dx = el.x2 - el.x1, dy = el.y2 - el.y1;
            double r   = std::sqrt(dx*dx + dy*dy) * zoom;
            double dcx = vpX - vx1, dcy = vpY - vy1;
            if (std::abs(std::sqrt(dcx*dcx + dcy*dcy) - r) < s) return i;
        } else {
            // bild, symbol, text: Bounding-Box
            double bx1 = std::min(vx1,vx2)-s, by1 = std::min(vy1,vy2)-s;
            double bx2 = std::max(vx1,vx2)+s, by2 = std::max(vy1,vy2)+s;
            if (vpX >= bx1 && vpX <= bx2 && vpY >= by1 && vpY <= by2) return i;
        }
    }
    return -1;
}
