#include "Database.h"
#include "PdfRenderer.h"
#include <cmath>
#include <functional>
#include <QSqlQuery>
#include <QSqlError>
#include <QBuffer>
#include <QFile>
#include <QImage>
#include <QSet>
#include <QHash>
#include <QPair>
#include <limits>
#include <QUrl>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <algorithm>
#include <QPdfWriter>
#include <QPainter>
#include <QPainterPath>
#include <QPen>
#include <QRegularExpression>
#include <QFont>
#include <QFontMetricsF>
#include <QColor>
#include <QPolygonF>
#include <QPageSize>
#include <QPageLayout>

QColor pdfFarbe(const QString &s, const QColor &def)
{
    if (s.isEmpty()) return def;
    QColor c(s);
    return c.isValid() ? c : def;
}

// IEC-60757-Farbcode → Canvas-Farbe. 1:1-Port von aderFarbeZuCanvas()
// in qml/canvas/CanvasGeometrie.qml – muss synchron gehalten werden.
QColor pdfAderFarbeZuCanvas(const QString &code)
{
    if (code == "BK")   return QColor("#222222");
    if (code == "BN")   return QColor("#7b3f00");
    if (code == "RD")   return QColor("#cc0000");
    if (code == "OG")   return QColor("#ff6600");
    if (code == "YE")   return QColor("#ccaa00");
    if (code == "GN")   return QColor("#006600");
    if (code == "BU")   return QColor("#0044cc");
    if (code == "VT")   return QColor("#880099");
    if (code == "GY")   return QColor("#666666");
    if (code == "WH")   return QColor("#dddddd");
    if (code == "PK")   return QColor("#ff88aa");
    return QColor("#4a9eff");
}

// Signaltyp → Canvas-Farbe. 1:1-Port von signaltypFarbe() in
// qml/canvas/CanvasGeometrie.qml – muss synchron gehalten werden.
QColor pdfSignaltypFarbe(const QString &sig)
{
    if (sig == "power")          return QColor("#cc3300");
    if (sig == "pe")             return QColor("#88cc00");
    if (sig == "n")              return QColor("#4488ff");
    if (sig == "dc_plus")        return QColor("#dd5500");
    if (sig == "dc_minus")       return QColor("#334488");
    if (sig == "input_digital")  return QColor("#44aaff");
    if (sig == "output_digital") return QColor("#44cc66");
    if (sig == "input_analog")   return QColor("#88bbff");
    if (sig == "output_analog")  return QColor("#66ddaa");
    if (sig == "kommunikation")  return QColor("#aa44cc");
    if (sig == "temp")           return QColor("#e07030");
    if (sig == "stepper")        return QColor("#20a890");
    if (sig == "sicherheit")     return QColor("#d4a017");
    if (sig == "fe")             return QColor("#4caf7d");
    if (sig == "konflikt")       return QColor("#ff2200");
    if (sig == "unversorgt")     return QColor("#ffaa00");
    return QColor("#4a9eff");   // neutral
}

static Qt::PenStyle pdfLinienart(const QString &art)
{
    if (art == "gestrichelt")  return Qt::DashLine;
    if (art == "gepunktet")    return Qt::DotLine;
    return Qt::SolidLine;
}

QPen pdfPen(const QVariantMap &el, double lw_dev)
{
    QPen pen;
    QColor farbe = pdfFarbe(el.value("strichFarbe").toString());
    // "Linien-Deckkraft" (opazitaet) im Eigenschaften-Panel für Grafik-Elemente -
    // 1:1-Analogie zu CanvasRenderHandler.qml maleElement() (ctx.globalAlpha = op
    // beim Stroke). Betrifft nur den Strich, Füllung läuft separat über
    // fuellOpazitaet.
    farbe.setAlphaF(farbe.alphaF() * el.value("opazitaet", 1.0).toDouble());
    pen.setColor(farbe);
    pen.setWidthF(lw_dev);
    pen.setCapStyle(Qt::FlatCap);
    pen.setJoinStyle(Qt::MiterJoin);
    pen.setStyle(pdfLinienart(el.value("strichArt").toString()));
    return pen;
}

// Symbol-Primitiv zeichnen im lokalen Koordinatensystem 0..w × 0..h (in Device-Pixel)
static void pdfPrimitivRendern(QPainter &p, const QVariantMap &pr,
                               double w, double h, const QPen &basePen)
{
    QPen pen = basePen;
    QString la = pr.value("linienart").toString();
    if      (la == "dash")    pen.setStyle(Qt::DashLine);
    else if (la == "dot")     pen.setStyle(Qt::DotLine);
    else if (la == "dashdot") pen.setStyle(Qt::DashDotLine);
    else                      pen.setStyle(Qt::SolidLine);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);

    QString typ = pr.value("typ").toString();

    if (typ == "linie") {
        p.drawLine(QLineF(pr.value("x1").toDouble() * w, pr.value("y1").toDouble() * h,
                          pr.value("x2").toDouble() * w, pr.value("y2").toDouble() * h));

    } else if (typ == "rechteck") {
        double x1v = pr.value("x1").toDouble(), y1v = pr.value("y1").toDouble();
        double x2v = pr.value("x2").toDouble(), y2v = pr.value("y2").toDouble();
        double rw  = (x2v - x1v) * w, rh = (y2v - y1v) * h;
        double cx  = (x1v + x2v) / 2.0 * w, cy = (y1v + y2v) / 2.0 * h;
        double rot = pr.value("rotation").toDouble();
        p.save();
        p.translate(cx, cy);
        if (rot != 0.0) p.rotate(rot);
        p.drawRect(QRectF(-rw / 2.0, -rh / 2.0, rw, rh));
        p.restore();

    } else if (typ == "rechteck_gefuellt") {
        double x1v = pr.value("x1").toDouble(), y1v = pr.value("y1").toDouble();
        double x2v = pr.value("x2").toDouble(), y2v = pr.value("y2").toDouble();
        double rw  = (x2v - x1v) * w, rh = (y2v - y1v) * h;
        double cx  = (x1v + x2v) / 2.0 * w, cy = (y1v + y2v) / 2.0 * h;
        double rot = pr.value("rotation").toDouble();
        p.save();
        p.translate(cx, cy);
        if (rot != 0.0) p.rotate(rot);
        p.setBrush(pen.color());
        p.setPen(Qt::NoPen);
        p.drawRect(QRectF(-rw / 2.0, -rh / 2.0, rw, rh));
        p.restore();

    } else if (typ == "kreis_offen") {
        double cx = pr.value("x1").toDouble() * w;
        double cy = pr.value("y1").toDouble() * h;
        double r  = pr.value("radius").toDouble() * w;
        p.drawEllipse(QPointF(cx, cy), r, r);

    } else if (typ == "kreis_gefuellt") {
        double cx = pr.value("x1").toDouble() * w;
        double cy = pr.value("y1").toDouble() * h;
        double r  = pr.value("radius").toDouble() * w;
        p.setBrush(pen.color());
        p.setPen(Qt::NoPen);
        p.drawEllipse(QPointF(cx, cy), r, r);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);

    } else if (typ == "bogen") {
        double cx = pr.value("x1").toDouble() * w;
        double cy = pr.value("y1").toDouble() * h;
        double r  = pr.value("radius").toDouble() * w;
        // Canvas: 0=east, CW positive (Y-down), angles in degrees
        // QPainter: 0=east, CCW positive
        // Conversion: qp_start = -canvas_start; CW canvas = negative QPainter span
        double vonDeg = pr.value("winkel_von").toDouble();
        double bisDeg = pr.value("winkel_bis").toDouble();
        bool   ccw    = pr.value("bogen_gegen_uhrzeiger").toBool();
        double span   = bisDeg - vonDeg;
        while (span < 0)   span += 360;
        while (span > 360) span -= 360;
        if (qAbs(span) < 0.01) span = 360;
        double qpStart = -vonDeg;
        double qpSpan  = ccw ? span : -span;
        p.drawArc(QRectF(cx - r, cy - r, 2*r, 2*r),
                  qRound(qpStart * 16), qRound(qpSpan * 16));

    } else if (typ == "text") {
        // SYMBOL-TEXT-LESBAR-01: wird stattdessen separat aufrecht in
        // pdfSymbolRendern() gezeichnet - 1:1 Analogie zum QML-Pendant.
        if (pr.value("lesbar_halten").toBool()) return;
        double tx     = pr.value("x1").toDouble() * w;
        double ty     = pr.value("y1").toDouble() * h;
        double fs     = pr.value("schrift_relativ").toDouble() * h;
        bool   bold   = pr.value("schrift_fett").toBool();
        double rot    = pr.value("rotation").toDouble();
        QString align    = pr.value("text_align").toString();
        QString baseline = pr.value("text_baseline").toString();
        QString inhalt   = pr.value("text_inhalt").toString();
        if (inhalt.isEmpty()) return;

        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fs)));
        font.setBold(bold);
        p.setFont(font);
        p.setPen(pen);

        Qt::Alignment qa = Qt::AlignLeft;
        if (align == "center") qa = Qt::AlignHCenter;
        else if (align == "right") qa = Qt::AlignRight;

        // Rotiert um den Textanker (tx,ty) selbst, daher relativ zu (0,0)
        // nach dem translate/rotate statt zu (tx,ty) im Ausgangssystem.
        double rectW = w, rectH = qMax(fs * 2, 4.0);
        double rx = 0.0, ry = 0.0;
        if (align == "center") rx -= w / 2;
        if (baseline == "middle")       ry -= fs * 0.5;
        else if (baseline == "bottom")  ry -= fs;

        p.save();
        p.translate(tx, ty);
        if (rot != 0.0) p.rotate(rot);
        p.drawText(QRectF(rx, ry, rectW, rectH), qa | Qt::AlignTop, inhalt);
        p.restore();

    } else if (typ == "dreieck_gefuellt") {
        QPolygonF tri;
        tri << QPointF(pr.value("x1").toDouble() * w, pr.value("y1").toDouble() * h)
            << QPointF(pr.value("x2").toDouble() * w, pr.value("y2").toDouble() * h)
            << QPointF(pr.value("x3").toDouble() * w, pr.value("y3").toDouble() * h);
        p.setBrush(pen.color());
        p.setPen(Qt::NoPen);
        p.drawPolygon(tri);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
    }
}

// Symbol mit Primitiven rendern (Position + Größe in Device-Pixeln)
void pdfSymbolRendern(QPainter &p, const QString &symbolId,
                             double x, double y, double sw, double sh,
                             int rotation, bool spiegelX, bool spiegelY,
                             const QPen &pen, const QSqlDatabase &db)
{
    if (sw < 0.5 || sh < 0.5) return;

    QSqlQuery q(db);
    q.prepare(R"(SELECT typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,
                        bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,
                        text_align,text_baseline,linienart,rotation,lesbar_halten
                 FROM symbol_primitiv WHERE symbol_id=:sid ORDER BY reihenfolge)");
    q.bindValue(":sid", symbolId);
    if (!q.exec()) return;

    QVector<QVariantMap> prims;
    while (q.next()) {
        QVariantMap m;
        m["typ"]                    = q.value(0).toString();
        m["x1"]                     = q.value(1).toDouble();
        m["y1"]                     = q.value(2).toDouble();
        m["x2"]                     = q.value(3).toDouble();
        m["y2"]                     = q.value(4).toDouble();
        m["x3"]                     = q.value(5).toDouble();
        m["y3"]                     = q.value(6).toDouble();
        m["radius"]                 = q.value(7).toDouble();
        m["winkel_von"]             = q.value(8).toDouble();
        m["winkel_bis"]             = q.value(9).toDouble();
        m["bogen_gegen_uhrzeiger"]  = q.value(10).toInt() != 0;
        m["text_inhalt"]            = q.value(11).toString();
        m["schrift_relativ"]        = q.value(12).toDouble();
        m["schrift_fett"]           = q.value(13).toInt() != 0;
        m["text_align"]             = q.value(14).toString();
        m["text_baseline"]          = q.value(15).toString();
        m["linienart"]              = q.value(16).toString();
        m["rotation"]               = q.value(17).toDouble();
        m["lesbar_halten"]          = q.value(18).toInt() != 0;
        prims.append(m);
    }
    if (prims.isEmpty()) return;

    p.save();
    p.translate(x + sw / 2, y + sh / 2);
    if (rotation != 0) p.rotate(rotation);
    if (spiegelX) p.scale(-1.0, 1.0);
    if (spiegelY) p.scale(1.0, -1.0);
    p.translate(-sw / 2, -sh / 2);

    for (const QVariantMap &pr : prims)
        pdfPrimitivRendern(p, pr, sw, sh, pen);

    p.restore();

    // SYMBOL-TEXT-LESBAR-01: Text-Primitive mit lesbar_halten=true wurden oben
    // im rotierten/gespiegelten Block übersprungen (pdfPrimitivRendern) und
    // werden hier separat aufrecht an der transformierten Ankerposition
    // gezeichnet - 1:1 Analogie zum QML-Pendant in
    // CanvasRenderHandler.qml::_renderSymbol().
    double rotRad = rotation * M_PI / 180.0;
    for (const QVariantMap &pr : prims) {
        if (pr.value("typ").toString() != QLatin1String("text") || !pr.value("lesbar_halten").toBool())
            continue;
        QString inhalt = pr.value("text_inhalt").toString();
        if (inhalt.isEmpty()) continue;

        double ox = pr.value("x1").toDouble() * sw - sw / 2.0;
        double oy = pr.value("y1").toDouble() * sh - sh / 2.0;
        if (spiegelX) ox = -ox;
        if (spiegelY) oy = -oy;
        double tx = ox * std::cos(rotRad) - oy * std::sin(rotRad);
        double ty = ox * std::sin(rotRad) + oy * std::cos(rotRad);

        double fs     = pr.value("schrift_relativ").toDouble() * sh;
        bool   bold   = pr.value("schrift_fett").toBool();
        QString align    = pr.value("text_align").toString();
        QString baseline = pr.value("text_baseline").toString();

        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fs)));
        font.setBold(bold);
        p.save();
        p.setFont(font);
        p.setPen(pen);
        Qt::Alignment qa = Qt::AlignLeft;
        if (align == "center") qa = Qt::AlignHCenter;
        else if (align == "right") qa = Qt::AlignRight;
        double rectW = sw, rectH = qMax(fs * 2, 4.0);
        double bx = 0.0, by = 0.0;
        if (align == "center") bx -= sw / 2;
        if (baseline == "middle")       by -= fs * 0.5;
        else if (baseline == "bottom")  by -= fs;
        p.drawText(QRectF(x + sw / 2.0 + tx + bx, y + sh / 2.0 + ty + by, rectW, rectH),
                   qa | Qt::AlignTop, inhalt);
        p.restore();
    }
}

// Pin-Weltposition eines Symbols (Bbox + Rotation/Spiegel), Canvas-Einheiten.
// 1:1-Port von pinWeltPos() in src/models/SymbolDefinitionModel.cpp – muss
// synchron gehalten werden.
QPointF pdfPinWeltPos(double x1, double y1, double x2, double y2,
                              double rotation, bool spiegelX, bool spiegelY,
                              double pinX, double pinY)
{
    const double sw = x2 - x1, sh = y2 - y1;
    const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
    double cx = (pinX - 0.5) * std::abs(sw);
    double cy = (pinY - 0.5) * std::abs(sh);
    if (spiegelX) cx = -cx;
    if (spiegelY) cy = -cy;
    const double rot = rotation * M_PI / 180.0;
    return { scx + cx * std::cos(rot) - cy * std::sin(rot),
             scy + cx * std::sin(rot) + cy * std::cos(rot) };
}
QVector<PdfPinDef> pdfPinsFuerTyp(const QString &symbolId)
{
    if (symbolId == QLatin1String("winkel"))
        return { {"1", 0.0, 0.0}, {"2", 1.0, 1.0} };
    if (symbolId == QLatin1String("querverweis"))
        return { {"1", 0.0, 0.5} };
    if (symbolId == QLatin1String("treffpunkt"))
        return { {"s1", 0.0, 0.5}, {"s2", 1.0, 0.5}, {"ziel", 0.5, 1.0} };
    if (symbolId == QLatin1String("treffpunkt_l"))
        return { {"s1", 0.0, 0.5}, {"s2", 0.5, 0.0}, {"ziel", 0.5, 1.0} };
    return {};
}

// Linienbreite aus Aderanzahl + Signaltyp-Zuschlägen, Canvas-Einheiten. 1:1-Port
// von _breiteFuerAnzahl() in CanvasRenderHandler.qml.
double pdfBreiteFuerAnzahl(int anz, const QString &signaltyp)
{
    double b = anz <= 3 ? anz * 1.5 : 4.5;
    if (signaltyp == QLatin1String("konflikt"))   b *= 2.0;
    if (signaltyp == QLatin1String("unversorgt")) b *= 1.5;
    return b;
}

// Lotfußpunkt-Test: liegt (cx,cy) auf dem Segment (sx1,sy1)-(sx2,sy2)
// (± tol)? Gemeinsam genutzt von pdfLeitungenSammeln (ADP-Matching) und
// pdfSegmentFuerPunkt (Winkel/Treffpunkt-Matching).
bool pdfPunktAufSegment(double cx, double cy,
                               double sx1, double sy1, double sx2, double sy2, double tol)
{
    double dx = sx2 - sx1, dy = sy2 - sy1;
    double len2 = dx*dx + dy*dy;
    if (len2 < 1e-6) return false;
    double t = ((cx - sx1) * dx + (cy - sy1) * dy) / len2;
    if (t < -0.05 || t > 1.05) return false;
    double projX = sx1 + t * dx, projY = sy1 + t * dy;
    return qAbs(cx - projX) < tol && qAbs(cy - projY) < tol;
}
