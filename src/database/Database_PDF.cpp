#include "Database.h"
#include <cmath>
#include <functional>
#include <QSqlQuery>
#include <QSqlError>
#include <QBuffer>
#include <QFile>
#include <QImage>
#include <QSet>
#include <QHash>
#include <QUrl>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <algorithm>
#include <QPdfWriter>
#include <QPainter>
#include <QPen>
#include <QFont>
#include <QFontMetricsF>
#include <QColor>
#include <QPolygonF>
#include <QPageSize>
#include <QPageLayout>

static QColor pdfFarbe(const QString &s, const QColor &def = Qt::black)
{
    if (s.isEmpty()) return def;
    QColor c(s);
    return c.isValid() ? c : def;
}

// IEC-60757-Farbcode → Canvas-Farbe. 1:1-Port von aderFarbeZuCanvas()
// in qml/canvas/CanvasGeometrie.qml – muss synchron gehalten werden.
static QColor pdfAderFarbeZuCanvas(const QString &code)
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
    if (code == "GNYE") return QColor("#88bb00");
    return QColor("#4a9eff");
}

// Signaltyp → Canvas-Farbe. 1:1-Port von signaltypFarbe() in
// qml/canvas/CanvasGeometrie.qml – muss synchron gehalten werden.
static QColor pdfSignaltypFarbe(const QString &sig)
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

static QPen pdfPen(const QVariantMap &el, double lw_dev)
{
    QPen pen;
    pen.setColor(pdfFarbe(el.value("strichFarbe").toString()));
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
        double rx = pr.value("x1").toDouble() * w;
        double ry = pr.value("y1").toDouble() * h;
        double rw = (pr.value("x2").toDouble() - pr.value("x1").toDouble()) * w;
        double rh = (pr.value("y2").toDouble() - pr.value("y1").toDouble()) * h;
        p.drawRect(QRectF(rx, ry, rw, rh));

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
        double tx     = pr.value("x1").toDouble() * w;
        double ty     = pr.value("y1").toDouble() * h;
        double fs     = pr.value("schrift_relativ").toDouble() * h;
        bool   bold   = pr.value("schrift_fett").toBool();
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

        double rectW = w, rectH = qMax(fs * 2, 4.0);
        double rx = tx, ry = ty;
        if (align == "center") rx -= w / 2;
        if (baseline == "middle")       ry -= fs * 0.5;
        else if (baseline == "bottom")  ry -= fs;

        p.drawText(QRectF(rx, ry, rectW, rectH), qa | Qt::AlignTop, inhalt);

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
static void pdfSymbolRendern(QPainter &p, const QString &symbolId,
                             double x, double y, double sw, double sh,
                             int rotation, bool spiegelX, bool spiegelY,
                             const QPen &pen, const QSqlDatabase &db)
{
    if (sw < 0.5 || sh < 0.5) return;

    QSqlQuery q(db);
    q.prepare(R"(SELECT typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,
                        bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,
                        text_align,text_baseline,linienart
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
}

// Beschriftungen (BMK, Freitext) über/neben einem Symbol rendern
static void pdfBeschriftungRendern(QPainter &p, const QVariantMap &el,
                                   double C, double pxPerMm)
{
    Q_UNUSED(pxPerMm)
    QString sid = el.value("symbolId").toString();
    static const QStringList kNoLabel = {
        "winkel","treffpunkt","treffpunkt_l","geraeteanschluss","unterbrechung",
        "aderdefinition","querverweis","klemme_anschluss","potenzial"
    };
    if (kNoLabel.contains(sid)) return;

    QVariantMap ed  = el.value("extraDaten").toMap();
    QString bmk     = ed.value("bmk").toString();
    QString ft1     = ed.value("freitext1").toString();
    QString ft2     = ed.value("freitext2").toString();
    if (bmk.isEmpty() && ft1.isEmpty() && ft2.isEmpty()) return;

    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = qAbs(x2 - x1);
    double sh  = qAbs(y2 - y1);
    double cx  = (x1 + x2) / 2;
    double rot = el.value("rotation").toInt();

    double schrift = ed.value("schriftgroesse", 2.5).toDouble();
    double fsMm    = schrift;
    double fsDev   = fsMm * pxPerMm;

    QFont fontBmk, fontFt;
    fontBmk.setFamily(QStringLiteral("sans-serif"));
    fontBmk.setPixelSize(qMax(1, qRound(fsDev)));
    fontBmk.setBold(true);
    fontFt.setFamily(QStringLiteral("sans-serif"));
    fontFt.setPixelSize(qMax(1, qRound(fsDev * 0.85)));

    p.save();
    p.setPen(pdfFarbe(el.value("strichFarbe").toString()));

    // Beschriftung immer waagerecht; Position über/links vom Symbol
    bool vertikal = (rot == 90 || rot == 270);
    double anchorX, anchorY;
    if (vertikal) {
        anchorX = x1 < x2 ? qMin(x1,x2) - fsDev * 0.3 : qMin(x1,x2) - fsDev * 0.3;
        anchorY = (y1 + y2) / 2;
    } else {
        anchorX = cx;
        anchorY = qMin(y1, y2) - fsDev * 0.3;
    }

    double ty = anchorY;
    if (vertikal) {
        double tx = anchorX - fsDev * 3;
        if (!bmk.isEmpty()) {
            p.setFont(fontBmk);
            p.drawText(QRectF(tx - sw, ty - sh/2, sw, sh), Qt::AlignRight | Qt::AlignVCenter, bmk);
        }
        if (!ft1.isEmpty()) {
            p.setFont(fontFt);
            p.drawText(QRectF(tx - sw, ty - sh/2 + fsDev * 1.3, sw, sh), Qt::AlignRight | Qt::AlignVCenter, ft1);
        }
    } else {
        if (!bmk.isEmpty()) {
            p.setFont(fontBmk);
            p.drawText(QRectF(cx - sw, ty - fsDev * 1.5, sw*2, fsDev * 1.3),
                       Qt::AlignHCenter | Qt::AlignBottom, bmk);
            ty -= fsDev * 1.4;
        }
        if (!ft1.isEmpty()) {
            p.setFont(fontFt);
            p.drawText(QRectF(cx - sw, ty - fsDev * 1.5, sw*2, fsDev * 1.3),
                       Qt::AlignHCenter | Qt::AlignBottom, ft1);
            ty -= fsDev * 1.2;
        }
        if (!ft2.isEmpty()) {
            p.setFont(fontFt);
            p.drawText(QRectF(cx - sw, ty - fsDev * 1.5, sw*2, fsDev * 1.3),
                       Qt::AlignHCenter | Qt::AlignBottom, ft2);
        }
    }
    p.restore();
}

// Verbindungssegment für die Winkel/Treffpunkt-Farbübernahme (s.u.) und für
// pdfLeitungenRendern. Koordinaten in Canvas-Einheiten (1 Einheit = 0.25 mm),
// noch nicht mit C multipliziert.
// VERBINDUNGSFARBE-03/04-Port (Jul 2026): gebaendert/zweifarbig/farbeA/farbeB/
// refPunkt bilden die Treffpunkt-Ziel-Arm-Bänderung ab (1:1-Port von
// _treffpunktZielBaender()/_maleGebaenderteLinie() in CanvasRenderHandler.qml).
struct PdfLeitungsSegment {
    double cx1, cy1, cx2, cy2;
    int    verbId;
    QColor color;
    double lw;   // Linienbreite in Device-Pixeln (bei gebaendert: Vollbreite, s.u.)

    bool    gebaendert = false;   // true: Ziel-Arm eines Treffpunkts mit 2 Adern
    bool    zweifarbig = false;   // true: farbeA/farbeB nebeneinander; false: farbeA + Trennlinie
    QColor  farbeA, farbeB;       // bei zweifarbig: farbeA auf der refPunkt-Seite
    QPointF refPunkt;             // Weltkoordinate (Canvas-Einheiten) des S1-Pins
};

// Pin-Weltposition eines Symbols (Bbox + Rotation/Spiegel), Canvas-Einheiten.
// 1:1-Port von pinWeltPos() in src/models/SymbolDefinitionModel.cpp – muss
// synchron gehalten werden.
static QPointF pdfPinWeltPos(double x1, double y1, double x2, double y2,
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

// Lokale (unrotierte) Pin-Koordinaten je Symboltyp, aus symbole.sql
// (symbol_pin) übernommen – nur die für die Winkel-/Treffpunkt-Propagation
// relevanten Typen.
struct PdfPinDef { QString name; double px, py; };
static QVector<PdfPinDef> pdfPinsFuerTyp(const QString &symbolId)
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
static double pdfBreiteFuerAnzahl(int anz, const QString &signaltyp)
{
    double b = anz <= 3 ? anz * 1.5 : 4.5;
    if (signaltyp == QLatin1String("konflikt"))   b *= 2.0;
    if (signaltyp == QLatin1String("unversorgt")) b *= 1.5;
    return b;
}

// Zeichnet ein Geraden-Stück – einfarbig oder (Treffpunkt-Ziel-Arm) gebändert.
// 1:1-Port von _maleGebaenderteLinie() in CanvasRenderHandler.qml
// (VERBINDUNGSFARBE-03/04). ax,ay,bx,by,refX,refY bereits in derselben
// Zieleinheit des Aufrufers (Device-Pixel bei Leitungen, lokale Symbol-Pixel
// bei Treffpunkt-Armen – s. pdfTreffpunktArmeRendern).
static void pdfMaleGebaenderteLinie(QPainter &p, double ax, double ay, double bx, double by,
                                     const PdfLeitungsSegment &s, double refX, double refY,
                                     double pxPerMm)
{
    if (!s.gebaendert) {
        p.setPen(QPen(s.color, s.lw, Qt::SolidLine, Qt::FlatCap));
        p.drawLine(QLineF(ax, ay, bx, by));
        return;
    }
    double dx = bx - ax, dy = by - ay;
    double len = std::sqrt(dx*dx + dy*dy);
    if (len < 1e-6) return;

    if (!s.zweifarbig) {
        p.setPen(QPen(s.farbeA, s.lw, Qt::SolidLine, Qt::FlatCap));
        p.drawLine(QLineF(ax, ay, bx, by));
        p.setPen(QPen(Qt::white, qMax(0.3, 1.0 * 0.25 * pxPerMm), Qt::SolidLine, Qt::FlatCap));
        p.drawLine(QLineF(ax, ay, bx, by));
        return;
    }

    double px = -dy / len, py = dx / len;
    double basis = s.lw / 2.0;
    double off   = basis / 2.0;
    bool flip = (dx * (refY - ay) - dy * (refX - ax)) >= 0.0;
    QColor farbeNeg = flip ? s.farbeB : s.farbeA;
    QColor farbePos = flip ? s.farbeA : s.farbeB;

    p.setPen(QPen(farbeNeg, basis, Qt::SolidLine, Qt::FlatCap));
    p.drawLine(QLineF(ax - px*off, ay - py*off, bx - px*off, by - py*off));
    p.setPen(QPen(farbePos, basis, Qt::SolidLine, Qt::FlatCap));
    p.drawLine(QLineF(ax + px*off, ay + py*off, bx + px*off, by + py*off));
}

// Zeichnet die Arme eines Treffpunkt-/Treffpunkt_L-Symbols einzeln (statt
// über die generischen symbol_primitiv-Zeilen), damit der Ziel-Arm bei Bedarf
// gebändert werden kann. 1:1-Analogie zu _maleTreffpunktArme() in
// CanvasRenderHandler.qml. Läuft im bereits transformierten (translate/
// rotate/scale) Koordinatensystem wie pdfSymbolRendern – lokale, unrotierte
// 0..1-Koordinaten (s. symbol_primitiv für 'treffpunkt'/'treffpunkt_l').
// s1Seg/s2Seg/zielSeg: das jeweils an diesem Pin anliegende, bereits farblich
// aufgelöste Leitungssegment (nullptr = unverbunden → Default-Blau).
static void pdfTreffpunktArmeRendern(QPainter &p, const QString &symbolId, double w, double h,
                                     double lwBasis, const PdfLeitungsSegment *s1Seg,
                                     const PdfLeitungsSegment *s2Seg,
                                     const PdfLeitungsSegment *zielSeg, double pxPerMm)
{
    auto P = [&](double nx, double ny) { return QPointF(nx * w, ny * h); };
    QPointF s1RefLocal = P(0.0, 0.5); // S1-Pin ist bei beiden Symboltypen lokal (0, 0.5)
    auto L = [&](QPointF a, QPointF b, const PdfLeitungsSegment *seg) {
        if (seg) {
            pdfMaleGebaenderteLinie(p, a.x(), a.y(), b.x(), b.y(), *seg,
                                    s1RefLocal.x(), s1RefLocal.y(), pxPerMm);
        } else {
            p.setPen(QPen(QColor("#4a9eff"), lwBasis, Qt::SolidLine, Qt::FlatCap));
            p.drawLine(QLineF(a, b));
        }
    };

    if (symbolId == QLatin1String("treffpunkt")) {
        QPointF j = P(0.5, 0.75);
        L(P(0, 0.5),    P(0.25, 0.5), s1Seg);
        L(P(0.25, 0.5), j,            s1Seg);
        L(j,            P(0.5, 1),    zielSeg);
        L(j,            P(0.75, 0.5), s2Seg);
        L(P(0.75, 0.5), P(1, 0.5),    s2Seg);
    } else if (symbolId == QLatin1String("treffpunkt_l")) {
        QPointF j2 = P(0.5, 0.75);
        L(P(0, 0.5),    P(0.25, 0.5), s1Seg);
        L(P(0.25, 0.5), j2,           s1Seg);
        L(P(0.5, 0),    j2,           s2Seg);
        L(j2,           P(0.5, 1),    zielSeg);
    }
}

// Lotfußpunkt-Test: liegt (cx,cy) auf dem Segment (sx1,sy1)-(sx2,sy2)
// (± tol)? Gemeinsam genutzt von pdfLeitungenSammeln (ADP-Matching) und
// pdfSegmentFuerPunkt (Winkel/Treffpunkt-Matching).
static bool pdfPunktAufSegment(double cx, double cy,
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

static QVector<PdfLeitungsSegment> pdfLeitungenSammeln(int seiteId, double pxPerMm,
                                                        const QSqlDatabase &db)
{
    QVector<PdfLeitungsSegment> segs;

    // Aderdefinitionspunkte dieser Seite: cx,cy,aderfarbe. Analog aderdefMap
    // in Database_Klemmen.cpp (klemmlistenauszug) – Aderfarbe hat Vorrang vor
    // der Signaltyp-Farbe, s.u. (gleiche Priorität wie CanvasRenderHandler.qml
    // _segmentFarbeUndBreite()).
    struct Adp { double cx, cy; QString farbe; };
    QVector<Adp> adps;
    {
        QSqlQuery aq(db);
        aq.prepare(R"(
            SELECT (x1+x2)/2.0, (y1+y2)/2.0,
                   COALESCE(json_extract(extra_daten,'$.aderfarbe'),'')
            FROM grafik_element
            WHERE seite_id = :sid AND symbol_id = 'aderdefinition'
        )");
        aq.bindValue(":sid", seiteId);
        if (aq.exec()) {
            while (aq.next()) {
                QString af = aq.value(2).toString();
                if (!af.isEmpty())
                    adps.append({ aq.value(0).toDouble(), aq.value(1).toDouble(), af });
            }
        }
    }

    // Rohe Leitungssegmente (noch ohne Farbe) – Farbauflösung erfolgt erst
    // nach der Winkel-/Querverweis-Propagation weiter unten.
    struct RawSeg { double x1, y1, x2, y2; int verbId; QString signaltyp; };
    QVector<RawSeg> raw;
    {
        QSqlQuery q(db);
        q.prepare(R"(
            SELECT vs.punkte, vs.verbindung_id, v.signaltyp
            FROM verbindung_segment vs
            JOIN verbindung v ON vs.verbindung_id = v.id
            WHERE vs.seite_id = :sid
        )");
        q.bindValue(":sid", seiteId);
        if (!q.exec()) return segs;
        while (q.next()) {
            QJsonDocument doc = QJsonDocument::fromJson(q.value(0).toString().toUtf8());
            if (!doc.isArray() || doc.array().size() < 2) continue;
            QJsonArray arr = doc.array();
            raw.append({ arr[0].toObject()["x"].toDouble(), arr[0].toObject()["y"].toDouble(),
                         arr[1].toObject()["x"].toDouble(), arr[1].toObject()["y"].toDouble(),
                         q.value(1).toInt(), q.value(2).toString() });
        }
    }
    const int n = raw.size();
    if (n == 0) return segs;

    // Direkte ADP-Farbe je Segment (erster Treffer, wie bisher).
    QVector<QColor> direktFarbe(n);
    for (int i = 0; i < n; i++) {
        if (raw[i].signaltyp == QLatin1String("konflikt")) continue;
        for (const Adp &ad : adps) {
            if (pdfPunktAufSegment(ad.cx, ad.cy, raw[i].x1, raw[i].y1, raw[i].x2, raw[i].y2, 3.0)) {
                direktFarbe[i] = pdfAderFarbeZuCanvas(ad.farbe);
                break;
            }
        }
    }

    // Winkel-/Querverweis-transparente Propagation (VERBINDUNGSFARBE-01/03-
    // Port): Segmente, die über einen gemeinsamen winkel-/querverweis-Pin
    // verbunden sind, bilden eine Gruppe und teilen sich die erste in der
    // Gruppe gefundene Aderfarbe – 1:1-Analogie zu adpFuerNetSegmente()/
    // _winkelAdjazenz() in CanvasGeometrie.qml, hier geometrisch statt über
    // den elIdx-Netzgraphen (PDF-Export hat keinen Live-Netzgraphen, s.
    // VERBINDUNGSFARBE-01).
    QVector<int> parent(n);
    for (int i = 0; i < n; i++) parent[i] = i;
    std::function<int(int)> find = [&](int x) {
        while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
        return x;
    };
    auto uni = [&](int a, int b) { int ra = find(a), rb = find(b); if (ra != rb) parent[ra] = rb; };

    const double PIN_TOL = 2.0; // Canvas-Einheiten (0.5 mm)
    auto nah = [&](double px_, double py_, const QPointF &w) {
        return std::hypot(px_ - w.x(), py_ - w.y()) < PIN_TOL;
    };

    {
        QSqlQuery wq(db);
        wq.prepare(R"(
            SELECT x1, y1, x2, y2, rotation, spiegel_x, spiegel_y, symbol_id
            FROM grafik_element
            WHERE seite_id = :sid AND typ = 'symbol' AND symbol_id IN ('winkel', 'querverweis')
        )");
        wq.bindValue(":sid", seiteId);
        if (wq.exec()) {
            while (wq.next()) {
                double ex1 = wq.value(0).toDouble(), ey1 = wq.value(1).toDouble();
                double ex2 = wq.value(2).toDouble(), ey2 = wq.value(3).toDouble();
                double rot = wq.value(4).toDouble();
                bool spX = wq.value(5).toBool(), spY = wq.value(6).toBool();
                QString sid = wq.value(7).toString();

                QVector<int> beruehrt;
                for (const PdfPinDef &pin : pdfPinsFuerTyp(sid)) {
                    QPointF w = pdfPinWeltPos(ex1, ey1, ex2, ey2, rot, spX, spY, pin.px, pin.py);
                    for (int i = 0; i < n; i++)
                        if (nah(raw[i].x1, raw[i].y1, w) || nah(raw[i].x2, raw[i].y2, w))
                            beruehrt.append(i);
                }
                for (int k = 1; k < beruehrt.size(); k++) uni(beruehrt[0], beruehrt[k]);
            }
        }
    }

    QHash<int, QColor> gruppenFarbe; // Wurzel → erste gefundene Aderfarbe
    for (int i = 0; i < n; i++)
        if (direktFarbe[i].isValid() && !gruppenFarbe.contains(find(i)))
            gruppenFarbe[find(i)] = direktFarbe[i];

    QVector<QColor> endFarbe(n);
    for (int i = 0; i < n; i++) {
        QColor clr = pdfSignaltypFarbe(raw[i].signaltyp);
        if (raw[i].signaltyp != QLatin1String("konflikt")) {
            if (direktFarbe[i].isValid())              clr = direktFarbe[i];
            else if (gruppenFarbe.contains(find(i)))    clr = gruppenFarbe[find(i)];
        }
        endFarbe[i] = clr;
    }

    // Treffpunkt-/Treffpunkt_L-Ziel-Arm-Bänderung (VERBINDUNGSFARBE-03/04-
    // Port): S1/S2-Pins geometrisch auf ihr jeweiliges Segment matchen, bei
    // unterschiedlicher (gleicher) Endfarbe den Ziel-Arm zweifarbig (mit
    // Trennlinie) markieren. Verkettung mehrerer Treffpunkte (Ziel-Arm eines
    // Treffpunkts = Quell-Arm eines zweiten) wird hier bewusst NICHT
    // aufgelöst (kein Zahl-Label-Fallback im PDF wie im Live-Canvas) – ein
    // beteiligter Treffpunkt fällt dann auf die einfache Endfarbe zurück,
    // statt eine irreführende Bänderung zu zeichnen.
    auto segAnPunkt = [&](const QPointF &w) -> int {
        for (int i = 0; i < n; i++)
            if (nah(raw[i].x1, raw[i].y1, w) || nah(raw[i].x2, raw[i].y2, w))
                return i;
        return -1;
    };

    struct TpKandidat { int s1Idx, s2Idx, zielIdx; QPointF s1Welt; };
    QVector<TpKandidat> kandidaten;
    QSet<int> zielIdxSet;
    {
        QSqlQuery tq(db);
        tq.prepare(R"(
            SELECT x1, y1, x2, y2, rotation, spiegel_x, spiegel_y, symbol_id
            FROM grafik_element
            WHERE seite_id = :sid AND typ = 'symbol' AND symbol_id IN ('treffpunkt', 'treffpunkt_l')
        )");
        tq.bindValue(":sid", seiteId);
        if (tq.exec()) {
            while (tq.next()) {
                double ex1 = tq.value(0).toDouble(), ey1 = tq.value(1).toDouble();
                double ex2 = tq.value(2).toDouble(), ey2 = tq.value(3).toDouble();
                double rot = tq.value(4).toDouble();
                bool spX = tq.value(5).toBool(), spY = tq.value(6).toBool();
                QString sid = tq.value(7).toString();

                QPointF s1W, s2W, zielW;
                for (const PdfPinDef &pin : pdfPinsFuerTyp(sid)) {
                    QPointF w = pdfPinWeltPos(ex1, ey1, ex2, ey2, rot, spX, spY, pin.px, pin.py);
                    if      (pin.name == QLatin1String("s1"))   s1W = w;
                    else if (pin.name == QLatin1String("s2"))   s2W = w;
                    else if (pin.name == QLatin1String("ziel")) zielW = w;
                }
                int s1i = segAnPunkt(s1W), s2i = segAnPunkt(s2W), zi = segAnPunkt(zielW);
                if (s1i < 0 || s2i < 0 || zi < 0) continue;
                kandidaten.append({ s1i, s2i, zi, s1W });
                zielIdxSet.insert(zi);
            }
        }
    }
    // Finales Zusammenbau: normale Endfarbe, ggf. mit Bänderungsinfo für
    // Ziel-Arm-Segmente überschrieben.
    QHash<int, TpKandidat> baenderMap;
    for (const TpKandidat &k : kandidaten) {
        if (zielIdxSet.contains(k.s1Idx) || zielIdxSet.contains(k.s2Idx)) continue;
        if (!endFarbe[k.s1Idx].isValid() || !endFarbe[k.s2Idx].isValid()) continue;
        baenderMap.insert(k.zielIdx, k);
    }

    segs.reserve(n);
    for (int i = 0; i < n; i++) {
        PdfLeitungsSegment s;
        s.cx1 = raw[i].x1; s.cy1 = raw[i].y1; s.cx2 = raw[i].x2; s.cy2 = raw[i].y2;
        s.verbId = raw[i].verbId;
        s.color  = endFarbe[i];
        s.lw     = qMax(0.3, 1.5 * 0.25 * pxPerMm);

        auto bit = baenderMap.constFind(i);
        if (bit != baenderMap.constEnd()) {
            const TpKandidat &k = bit.value();
            QColor fa = endFarbe[k.s1Idx], fb = endFarbe[k.s2Idx];
            double breiteWelt = pdfBreiteFuerAnzahl(2, raw[i].signaltyp);
            s.gebaendert = true;
            s.zweifarbig = fa.name() != fb.name();
            s.farbeA = fa; s.farbeB = fb;
            s.refPunkt = k.s1Welt;
            s.lw = qMax(0.3, breiteWelt * 0.25 * pxPerMm);
            s.color = fa; // Fallback für die Treffpunkt-Symbolfarbe (pdfSegmentFuerPunkt, s.u.)
        }
        segs.append(s);
    }
    return segs;
}

// Nächstgelegenes Segment zu einem Punkt (Canvas-Einheiten) – gleiche Technik
// wie das geometrische Matching in Database_Klemmen.cpp (klemmlistenauszug).
static bool pdfSegmentFuerPunkt(double cx, double cy,
                                const QVector<PdfLeitungsSegment> &segs,
                                QColor &farbeOut, double &lwOut)
{
    const double TOL = 2.0;   // Canvas-Einheiten (0.5 mm)
    for (const PdfLeitungsSegment &s : segs) {
        if (pdfPunktAufSegment(cx, cy, s.cx1, s.cy1, s.cx2, s.cy2, TOL)) {
            farbeOut = s.color;
            lwOut    = s.lw;
            return true;
        }
    }
    return false;
}

// Einzelnes grafik_element rendern
static void pdfElementRendern(QPainter &p, const QVariantMap &el,
                               double C, double pxPerMm, const QSqlDatabase &db,
                               const QVector<PdfLeitungsSegment> *leitungsSegs = nullptr)
{
    QString typ = el.value("typ").toString();
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 1.5).toDouble() * 0.25 * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

    if (typ == "linie") {
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawLine(QLineF(x1, y1, x2, y2));

    } else if (typ == "polygonlinie") {
        QVariantList pts = el.value("punkte").toList();
        if (pts.size() < 2) return;
        QVector<QPointF> poly;
        for (const QVariant &v : pts) {
            QVariantMap pt = v.toMap();
            poly << QPointF(pt.value("x").toDouble() * C, pt.value("y").toDouble() * C);
        }
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawPolyline(poly.data(), poly.size());

    } else if (typ == "rechteck") {
        p.setPen(pen);
        double er = el.value("eckenRadius", 0.0).toDouble() * 0.25 * pxPerMm;
        bool fu   = el.value("fuell").toBool();
        if (fu) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString(), QColor(26,58,106));
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        if (er > 0.5)
            p.drawRoundedRect(QRectF(x1, y1, sw, sh), er, er);
        else
            p.drawRect(QRectF(x1, y1, sw, sh));

    } else if (typ == "kreis") {
        double dx = x2 - x1, dy = y2 - y1;
        double r  = qSqrt(dx*dx + dy*dy);
        if (r < 0.5) return;
        p.setPen(pen);
        bool fu = el.value("fuell").toBool();
        if (fu) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString(), QColor(26,58,106));
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        p.drawEllipse(QPointF(x1, y1), r, r);

    } else if (typ == "text") {
        QString inhalt = el.value("textInhalt").toString();
        if (inhalt.isEmpty()) return;
        QVariantMap edTxt = el.value("extraDaten").toMap();
        double fsMm = edTxt.value("schriftgroesse", 3.5).toDouble();
        double fsDev = fsMm * 0.25 * pxPerMm;
        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fsDev)));
        font.setBold(true);
        p.setFont(font);
        p.setPen(pdfFarbe(el.value("strichFarbe").toString(), QColor(192,216,240)));
        p.setBrush(Qt::NoBrush);

        QString ausrichtung = el.value("textAusrichtung", "links").toString();
        Qt::Alignment qa = Qt::AlignLeft;
        if (ausrichtung == "mitte") qa = Qt::AlignHCenter;
        else if (ausrichtung == "rechts") qa = Qt::AlignRight;

        int normRot = el.value("rotation", 0).toInt();
        // Nur 0° und 90° (senkrecht) sind erlaubt
        p.save();
        p.translate(x1, y1);
        if (normRot == 90 || normRot == -270) p.rotate(-90);
        QStringList lines = inhalt.split('\n');
        double lineH = fsDev * 1.3;
        for (int i = 0; i < lines.size(); i++)
            p.drawText(QRectF(0, i * lineH, qMax(qAbs(sw), 200.0), fsDev * 1.5),
                       qa | Qt::AlignTop, lines[i]);
        p.restore();

    } else if (typ == "bild") {
        QVariant bildVar = el.value("bildDaten");
        if (!bildVar.isValid()) return;
        QString dataUrl = bildVar.toString();
        // data:image/xxx;base64,... → decode
        int commaPos = dataUrl.indexOf(',');
        if (commaPos < 0) return;
        QByteArray bytes = QByteArray::fromBase64(dataUrl.mid(commaPos + 1).toLatin1());
        QImage img;
        if (!img.loadFromData(bytes)) return;
        p.save();
        p.setOpacity(el.value("opazitaet", 1.0).toDouble());
        p.drawImage(QRectF(qMin(x1,x2), qMin(y1,y2), qAbs(sw), qAbs(sh)), img);
        p.restore();

    } else if (typ == "notiz") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        if (rw < 2 || rh < 2) return;
        QColor bgColor = pdfFarbe(el.value("fuellFarbe").toString(), QColor(26,26,0));
        bgColor.setAlphaF(el.value("fuellOpazitaet", 0.9).toDouble());
        p.setBrush(bgColor);
        p.setPen(Qt::NoPen);
        p.drawRect(QRectF(rx, ry, rw, rh));
        p.setBrush(Qt::NoBrush);
        QPen borderPen = pen;
        borderPen.setColor(pdfFarbe(el.value("strichFarbe").toString(), QColor(204,204,34)));
        borderPen.setWidthF(strichBr);
        p.setPen(borderPen);
        p.drawRect(QRectF(rx, ry, rw, rh));

        QString text = el.value("textInhalt").toString();
        if (text.isEmpty()) return;
        QVariantMap ed = el.value("extraDaten").toMap();
        double fsMm  = ed.value("schriftgroesse", 3.5).toDouble();
        double fsDev = fsMm * pxPerMm;
        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fsDev)));
        p.setFont(font);
        p.setPen(pdfFarbe(el.value("strichFarbe").toString(), QColor(204,204,34)));
        double pad = qMax(4.0, fsDev * 0.35);
        p.drawText(QRectF(rx + pad, ry + pad, rw - 2*pad, rh - 2*pad),
                   Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap, text);

    } else if (typ == "kabellinie") {
        // Gestrichelte orange Linie
        QPen kPen;
        kPen.setColor(pdfFarbe(el.value("strichFarbe").toString(), QColor(224,112,0)));
        kPen.setWidthF(qMax(0.5, 2.5 * 0.25 * pxPerMm));
        kPen.setStyle(Qt::DashLine);
        kPen.setCapStyle(Qt::RoundCap);
        p.setPen(kPen);
        p.setBrush(Qt::NoBrush);
        p.drawLine(QLineF(x1, y1, x2, y2));
        // Endpunkt-Kreise
        QPen cPen = kPen;
        cPen.setStyle(Qt::SolidLine);
        p.setPen(Qt::NoPen);
        p.setBrush(kPen.color());
        double cr = 4.0 * 0.25 * pxPerMm;
        p.drawEllipse(QPointF(x1, y1), cr, cr);
        p.drawEllipse(QPointF(x2, y2), cr, cr);
        p.setBrush(Qt::NoBrush);
        // Kabelkopf-Label: mehrzeilig, senkrecht zur Linie auf der "oberen" Seite
        {
            QVariantMap ed  = el.value("extraDaten").toMap();
            QString bez     = ed.value("bezeichnung").toString();
            QString klTyp   = ed.value("kabeltyp").toString();
            int     adz     = ed.value("aderzahl").toInt();
            double  que     = ed.value("querschnittMm2").toDouble();
            double  len     = ed.value("laenge_m").toDouble();

            struct Zeile { QString text; bool bold; };
            QVector<Zeile> zeilen;
            if (!bez.isEmpty())   zeilen.append({bez,   true});
            if (!klTyp.isEmpty()) zeilen.append({klTyp, false});
            // Aderanzahl×Querschnitt nur wenn kabeltyp kein '×' enthält
            bool typHatX = klTyp.contains(QLatin1Char('x'), Qt::CaseInsensitive)
                        || klTyp.contains(QChar(0x00D7));
            if (!typHatX && (adz > 0 || que > 0)) {
                QString z3;
                if (adz > 0 && que > 0)
                    z3 = QString::number(adz) + QStringLiteral(" × ")
                         + QString::number(que, 'f', que == qFloor(que) ? 0 : 1)
                               .replace(QLatin1Char('.'), QLatin1Char(','))
                         + QStringLiteral(" mm²");
                else if (adz > 0)
                    z3 = QString::number(adz) + QStringLiteral(" Adern");
                else
                    z3 = QString::number(que, 'f', que == qFloor(que) ? 0 : 1)
                             .replace(QLatin1Char('.'), QLatin1Char(','))
                         + QStringLiteral(" mm²");
                zeilen.append({z3, false});
            }
            if (len > 0)
                zeilen.append({QStringLiteral("→ ")
                               + QString::number(len, 'f', 1)
                                     .replace(QLatin1Char('.'), QLatin1Char(','))
                               + QStringLiteral(" m"), false});

            if (!zeilen.isEmpty()) {
                double fsDev = 2.5 * pxPerMm;
                double lineH = fsDev * 1.3;
                // Normalvektor senkrecht zur Linie, auf der "oberen" Seite (kleinstes y)
                double dx = x2 - x1, dy = y2 - y1;
                double len2 = std::sqrt(dx*dx + dy*dy);
                if (len2 < 0.001) len2 = 0.001;
                double ccwX = -dy/len2, ccwY = dx/len2;
                double cwX  =  dy/len2, cwY  = -dx/len2;
                bool useCC  = (ccwY < cwY) || (ccwY == cwY && ccwX < cwX);
                double nx   = useCC ? ccwX : cwX;
                double ny   = useCC ? ccwY : cwY;
                double off  = fsDev * 0.5 + 4.0 * 0.25 * pxPerMm;
                double ax   = x1 + nx * off;
                double ay   = y1 + ny * off;
                double tw   = 40.0 * pxPerMm;
                Qt::Alignment ha = (nx >= 0) ? Qt::AlignLeft : Qt::AlignRight;
                QColor colBold  = kPen.color();
                QColor colNorm(0xbb, 0x88, 0x00);

                // Zeilen von unten nach oben (baseline=bottom, rückwärts iterieren)
                double curY = ay;
                for (int zi = zeilen.size() - 1; zi >= 0; --zi) {
                    QFont f; f.setFamily(QStringLiteral("sans-serif"));
                    f.setPixelSize(qMax(1, qRound(fsDev)));
                    f.setBold(zeilen[zi].bold);
                    p.setFont(f);
                    p.setPen(zeilen[zi].bold ? colBold : colNorm);
                    QRectF r = (nx >= 0)
                        ? QRectF(ax, curY - fsDev * 1.2, tw, fsDev * 1.2)
                        : QRectF(ax - tw, curY - fsDev * 1.2, tw, fsDev * 1.2);
                    p.drawText(r, ha | Qt::AlignBottom, zeilen[zi].text);
                    curY -= lineH;
                }
            }
        }

    } else if (typ == "geraetekasten") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        double er = 4.0 * 0.25 * pxPerMm;
        bool fu = el.value("fuell").toBool();
        if (fu) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString());
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        p.setPen(pen);
        p.drawRoundedRect(QRectF(rx, ry, rw, rh), er, er);
        p.setBrush(Qt::NoBrush);
        QVariantMap ed  = el.value("extraDaten").toMap();
        QString bmk     = ed.value("bmk").toString();
        QString descr   = ed.value("bezeichnung").toString();
        double schrift  = ed.value("schriftgroesse", 2.5).toDouble();
        double fsDev    = schrift * pxPerMm;
        double fsDev2   = fsDev * 0.85;
        double pad      = 5.0 * 0.25 * pxPerMm;
        double ty       = ry + pad;
        if (!bmk.isEmpty()) {
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev))); f.setBold(true);
            p.setFont(f); p.setPen(pen.color());
            p.drawText(QRectF(rx+pad, ty, rw-2*pad, fsDev*1.4), Qt::AlignLeft|Qt::AlignTop, bmk);
            ty += fsDev * 1.4;
        }
        if (!descr.isEmpty()) {
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev2)));
            p.setFont(f); p.setPen(pen.color());
            p.drawText(QRectF(rx+pad, ty, rw-2*pad, fsDev2*1.4), Qt::AlignLeft|Qt::AlignTop, descr);
        }

    } else if (typ == "strukturkasten") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        QPen skPen = pen;
        skPen.setStyle(Qt::DashLine);
        p.setPen(skPen);
        p.setBrush(Qt::NoBrush);
        p.drawRect(QRectF(rx, ry, rw, rh));
        QVariantMap ed  = el.value("extraDaten").toMap();
        double schrift  = ed.value("schriftgroesse", 2.5).toDouble();
        double fsDev    = schrift * pxPerMm;
        double off      = 4.0 * 0.25 * pxPerMm;
        QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev))); f.setBold(true);
        p.setFont(f); p.setPen(pen.color());
        QString lbl;
        if (!ed.value("anlageUO").toString().isEmpty()) lbl += "==" + ed.value("anlageUO").toString() + " ";
        if (!ed.value("ortUO").toString().isEmpty())    lbl += "++" + ed.value("ortUO").toString() + " ";
        if (!ed.value("anlage").toString().isEmpty())   lbl += "="  + ed.value("anlage").toString() + " ";
        if (!ed.value("ort").toString().isEmpty())      lbl += "+"  + ed.value("ort").toString();
        if (!lbl.isEmpty())
            p.drawText(QRectF(rx, ry + off, rw - off, fsDev*1.4),
                       Qt::AlignRight | Qt::AlignTop, lbl.trimmed());
        QString bez = ed.value("bezeichnung").toString();
        if (!bez.isEmpty()) {
            QFont fb = f; fb.setBold(false); p.setFont(fb);
            p.drawText(QRectF(rx + off, ry + off, rw - 2*off, fsDev*1.4),
                       Qt::AlignLeft | Qt::AlignTop, bez);
        }

    } else if (typ == "makrokasten") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        QPen mkPen = pen;
        mkPen.setStyle(Qt::DotLine);
        mkPen.setColor(QColor(0xa0, 0x60, 0xc0));
        p.setPen(mkPen);
        p.setBrush(Qt::NoBrush);
        p.drawRect(QRectF(rx, ry, rw, rh));

    } else if (typ == "symbol") {
        double absSw = qAbs(sw), absSh = qAbs(sh);
        if (absSw < 0.5 || absSh < 0.5) return;
        double symX = qMin(x1, x2);
        double symY = qMin(y1, y2);
        QString sid = el.value("symbolId").toString();

        // Winkel: transparenter Durchlauf – Farbe+Breite kommen vom anliegenden
        // Verbindungssegment statt aus el.strichFarbe/strichBreite (analog
        // CanvasRenderHandler.qml maleElement). Die Pins sitzen laut symbol_pin
        // auf Bbox-Ecken (0,0)/(1,1), nie im Bbox-Zentrum – daher werden alle
        // acht Kandidatenpunkte geprüft. Da Rotation nur in 90°-Schritten
        // vorkommt, bildet jede Rotation Ecken auf Ecken ab, die
        // Kandidatenmenge ist also rotations-/spiegelunabhängig.
        QPen symPen = pen;
        if (leitungsSegs && sid == "winkel") {
            double rx1 = el.value("x1").toDouble(), ry1 = el.value("y1").toDouble();
            double rx2 = el.value("x2").toDouble(), ry2 = el.value("y2").toDouble();
            double rmx = (rx1 + rx2) / 2.0, rmy = (ry1 + ry2) / 2.0;
            const QPointF kandidaten[8] = {
                { rx1, rmy }, { rx2, rmy }, { rmx, ry1 }, { rmx, ry2 },
                { rx1, ry1 }, { rx2, ry1 }, { rx1, ry2 }, { rx2, ry2 }
            };
            QColor mFarbe; double mLw;
            for (const QPointF &k : kandidaten) {
                if (pdfSegmentFuerPunkt(k.x(), k.y(), *leitungsSegs, mFarbe, mLw)) {
                    symPen.setColor(mFarbe);
                    symPen.setWidthF(mLw);
                    break;
                }
            }
        }

        // Treffpunkt/Treffpunkt_L: eigener 3-Arm-Zeichenpfad (S1/S2/Ziel), da
        // der Ziel-Arm gebändert sein kann (VERBINDUNGSFARBE-03/04-Port,
        // 1:1-Analogie zu CanvasRenderHandler.qml maleElement/
        // _maleTreffpunktArme()) – ersetzt den generischen Einzel-QPen-Pfad
        // über pdfSymbolRendern für diese beiden Typen.
        if (leitungsSegs && (sid == "treffpunkt" || sid == "treffpunkt_l")) {
            double rx1 = el.value("x1").toDouble(), ry1 = el.value("y1").toDouble();
            double rx2 = el.value("x2").toDouble(), ry2 = el.value("y2").toDouble();
            double rot = el.value("rotation").toDouble();
            bool   spX = el.value("spiegelX").toBool(), spY = el.value("spiegelY").toBool();

            const PdfLeitungsSegment *s1Seg = nullptr, *s2Seg = nullptr, *zielSeg = nullptr;
            for (const PdfPinDef &pin : pdfPinsFuerTyp(sid)) {
                QPointF w = pdfPinWeltPos(rx1, ry1, rx2, ry2, rot, spX, spY, pin.px, pin.py);
                for (int fi = 0; fi < leitungsSegs->size(); fi++) {
                    const PdfLeitungsSegment &ls = (*leitungsSegs)[fi];
                    if (!pdfPunktAufSegment(w.x(), w.y(), ls.cx1, ls.cy1, ls.cx2, ls.cy2, 2.0))
                        continue;
                    if      (pin.name == QLatin1String("s1"))   s1Seg = &ls;
                    else if (pin.name == QLatin1String("s2"))   s2Seg = &ls;
                    else if (pin.name == QLatin1String("ziel")) zielSeg = &ls;
                    break;
                }
            }

            p.save();
            p.translate(symX + absSw / 2, symY + absSh / 2);
            if (el.value("rotation").toInt() != 0) p.rotate(el.value("rotation").toInt());
            if (spX) p.scale(-1.0, 1.0);
            if (spY) p.scale(1.0, -1.0);
            p.translate(-absSw / 2, -absSh / 2);
            pdfTreffpunktArmeRendern(p, sid, absSw, absSh, pen.widthF(), s1Seg, s2Seg, zielSeg, pxPerMm);
            p.restore();
        } else {
            pdfSymbolRendern(p, sid, symX, symY, absSw, absSh,
                             el.value("rotation").toInt(),
                             el.value("spiegelX").toBool(),
                             el.value("spiegelY").toBool(),
                             symPen, db);
        }
        pdfBeschriftungRendern(p, el, C, pxPerMm);

        // ── Aderdefinitions-Textblock ────────────────────────────────────────
        if (sid == QStringLiteral("aderdefinition")) {
            QVariantMap ed = el.value("extraDaten").toMap();
            QStringList zeilen;
            QString bez   = ed.value("bezeichnung").toString();
            if (!bez.isEmpty()) zeilen << bez;

            QString aderfarbe = ed.value("aderfarbe").toString();
            double  quer      = ed.value("querschnitt_mm2").toDouble();
            if (!aderfarbe.isEmpty() || quer > 0) {
                QString z = aderfarbe.isEmpty() ? QStringLiteral("–") : aderfarbe;
                if (quer > 0)
                    z += QStringLiteral("  ") +
                         QString::number(quer, 'f', quer == qFloor(quer) ? 0 : 1)
                             .replace(QLatin1Char('.'), QLatin1Char(','))
                         + QStringLiteral(" mm²");
                zeilen << z;
            }
            double laenge = ed.value("laenge_m").toDouble();
            if (laenge > 0)
                zeilen << (QStringLiteral("→ ")
                           + QString::number(laenge, 'f', 1)
                               .replace(QLatin1Char('.'), QLatin1Char(','))
                           + QStringLiteral(" m"));

            if (!zeilen.isEmpty()) {
                double fsDev  = 2.0 * pxPerMm;       // 2 mm Schriftgröße
                double lineH  = fsDev * 1.3;
                double gap    = 0.5 * pxPerMm;        // 0.5 mm Abstand zum Symbol
                int rot = ((el.value("rotation").toInt() % 360) + 360) % 360;
                bool senk = (rot == 90 || rot == 270);

                double cx  = (x1 + x2) / 2.0;
                double cy  = (y1 + y2) / 2.0;
                QColor textClr(0x1a, 0x40, 0x60);     // Dunkelblau – lesbar auf Weiß

                p.save();
                if (senk) {
                    // Senkrecht: Text links des Symbols, rechtsbündig, Zeilen oben→unten
                    double lx = qMin(x1, x2) - gap;
                    double ly = cy - zeilen.size() * lineH / 2.0;
                    double tw = 30.0 * pxPerMm;        // 30 mm Textbreite
                    for (int zi = 0; zi < zeilen.size(); zi++) {
                        QFont f; f.setFamily(QStringLiteral("sans-serif"));
                        f.setPixelSize(qMax(1, qRound(fsDev)));
                        f.setBold(zi == 0 && !bez.isEmpty());
                        p.setFont(f);
                        p.setPen(textClr);
                        p.drawText(QRectF(lx - tw, ly + zi * lineH, tw, lineH * 1.2),
                                   Qt::AlignRight | Qt::AlignTop, zeilen[zi]);
                    }
                } else {
                    // Waagerecht: Text über dem Symbol, zentriert, letzte Zeile am nächsten
                    double tw = 30.0 * pxPerMm;
                    double oy = qMin(y1, y2) - gap;
                    for (int zi = zeilen.size() - 1; zi >= 0; zi--) {
                        QFont f; f.setFamily(QStringLiteral("sans-serif"));
                        f.setPixelSize(qMax(1, qRound(fsDev)));
                        f.setBold(zi == 0 && !bez.isEmpty());
                        p.setFont(f);
                        p.setPen(textClr);
                        oy -= lineH;
                        p.drawText(QRectF(cx - tw / 2.0, oy, tw, lineH * 1.2),
                                   Qt::AlignHCenter | Qt::AlignTop, zeilen[zi]);
                    }
                }
                p.restore();
            }
        }

        // ── klemme_anschluss: Bezeichnung + BMK (Pin-gegenüber, bmkOffset) ──
        if (el.value("symbolId").toString() == QStringLiteral("klemme_anschluss")) {
            QVariantMap kaed = el.value("extraDaten").toMap();
            QString kaAnz    = kaed.value("anschlussBezeichnung").toString();
            QString kaBmkRaw = kaed.value("bmk").toString();

            // Redundantes ":anschlussBezeichnung" am Ende kürzen
            QString kaBmkBase = (!kaAnz.isEmpty()
                                 && kaBmkRaw.endsWith(QLatin1Char(':') + kaAnz))
                                ? kaBmkRaw.left(kaBmkRaw.length() - kaAnz.length() - 1)
                                : kaBmkRaw;

            // bmkSichtbar: false → nur Klemmen-Nr (ohne Leisten-Präfix)
            QString kaBmk;
            bool kaBmkVis = false;
            {
                int col = kaBmkBase.lastIndexOf(QLatin1Char(':'));
                if (col >= 0) {
                    bool vis = kaed.value("bmkSichtbar", QVariant(true)).toBool();
                    kaBmk    = (vis ? kaBmkBase.left(col + 1) : QString())
                               + kaBmkBase.mid(col + 1);
                    kaBmkVis = !kaBmk.isEmpty();
                } else {
                    kaBmk    = kaBmkBase;
                    kaBmkVis = !kaBmkBase.isEmpty()
                               && kaed.value("bmkSichtbar", QVariant(true)).toBool();
                }
            }

            if (!kaAnz.isEmpty() || kaBmkVis) {
                double anzFsDev = 1.5 * pxPerMm;
                double bmkFsDev = 2.2 * pxPerMm;

                double kaOx = kaed.value("bmkOffsetX", 0.0).toDouble() * C;
                double kaOy = kaed.value("bmkOffsetY", 0.0).toDouble() * C;

                int  kaRot  = ((el.value("rotation").toInt() % 360) + 360) % 360;
                bool kaSenk = (kaRot == 90 || kaRot == 270);
                double kaCx = (x1 + x2) / 2.0;
                double kaCy = (y1 + y2) / 2.0;

                QFont fAnz; fAnz.setFamily(QStringLiteral("sans-serif"));
                fAnz.setPixelSize(qMax(1, qRound(anzFsDev))); fAnz.setBold(true);
                QFont fBmk; fBmk.setFamily(QStringLiteral("sans-serif"));
                fBmk.setPixelSize(qMax(1, qRound(bmkFsDev))); fBmk.setBold(true);

                QColor colAnz(0x33, 0xbb, 0x66);
                QColor colBmk(0x44, 0x88, 0xcc);
                double tw = 20.0 * pxPerMm;

                p.save();
                if (kaSenk) {
                    // 90°: Pin rechts → Text links | 270°: Pin links → Text rechts
                    bool pinRechts = (kaRot == 90);
                    double gapDev  = 1.0 * pxPerMm;
                    double kaX     = pinRechts
                                     ? qMin(x1, x2) - gapDev + kaOy
                                     : qMax(x1, x2) + gapDev + kaOy;
                    double kaCyO   = kaCy + kaOx;

                    // Bezeichnung oben, BMK darunter, beide um Mittelpunkt zentriert
                    double totalH = (!kaAnz.isEmpty() ? anzFsDev * 1.2 : 0.0)
                                  + (kaBmkVis ? bmkFsDev * 1.2 : 0.0);
                    double curY   = kaCyO - totalH / 2.0;
                    Qt::Alignment ha = pinRechts ? Qt::AlignRight : Qt::AlignLeft;

                    if (!kaAnz.isEmpty()) {
                        p.setFont(fAnz); p.setPen(colAnz);
                        QRectF r = pinRechts ? QRectF(kaX - tw, curY, tw, anzFsDev * 1.2)
                                             : QRectF(kaX, curY, tw, anzFsDev * 1.2);
                        p.drawText(r, ha | Qt::AlignVCenter, kaAnz);
                        curY += anzFsDev * 1.2;
                    }
                    if (kaBmkVis) {
                        p.setFont(fBmk); p.setPen(colBmk);
                        QRectF r = pinRechts ? QRectF(kaX - tw, curY, tw, bmkFsDev * 1.2)
                                             : QRectF(kaX, curY, tw, bmkFsDev * 1.2);
                        p.drawText(r, ha | Qt::AlignVCenter, kaBmk);
                    }
                } else {
                    // 0°: Pin oben → Text unten | 180°: Pin unten → Text oben
                    bool pinUnten = (kaRot == 180);
                    double gapDev = 0.75 * pxPerMm;
                    double kaCxO  = kaCx + kaOx;

                    if (!pinUnten) {
                        // Text wächst nach unten (anz näher am Symbol)
                        double curY = qMax(y1, y2) + gapDev + kaOy;
                        if (!kaAnz.isEmpty()) {
                            p.setFont(fAnz); p.setPen(colAnz);
                            p.drawText(QRectF(kaCxO - tw/2, curY, tw, anzFsDev * 1.2),
                                       Qt::AlignHCenter | Qt::AlignTop, kaAnz);
                            curY += anzFsDev * 1.2;
                        }
                        if (kaBmkVis) {
                            p.setFont(fBmk); p.setPen(colBmk);
                            p.drawText(QRectF(kaCxO - tw/2, curY, tw, bmkFsDev * 1.2),
                                       Qt::AlignHCenter | Qt::AlignTop, kaBmk);
                        }
                    } else {
                        // Text wächst nach oben (anz näher am Symbol)
                        double curY = qMin(y1, y2) - gapDev + kaOy;
                        if (!kaAnz.isEmpty()) {
                            curY -= anzFsDev * 1.2;
                            p.setFont(fAnz); p.setPen(colAnz);
                            p.drawText(QRectF(kaCxO - tw/2, curY, tw, anzFsDev * 1.2),
                                       Qt::AlignHCenter | Qt::AlignTop, kaAnz);
                        }
                        if (kaBmkVis) {
                            curY -= bmkFsDev * 1.2;
                            p.setFont(fBmk); p.setPen(colBmk);
                            p.drawText(QRectF(kaCxO - tw/2, curY, tw, bmkFsDev * 1.2),
                                       Qt::AlignHCenter | Qt::AlignTop, kaBmk);
                        }
                    }
                }
                p.restore();
            }
        }

        // ── potenzial: BMK + Freitext am Pin-gegenüber (bmkOffset, strichFarbe) ──
        if (el.value("symbolId").toString() == QStringLiteral("potenzial")) {
            QVariantMap paed = el.value("extraDaten").toMap();
            QString paBmk    = paed.value("bmk").toString();

            // textReihenfolge + *Sichtbar-Flags auswerten
            QStringList reihe;
            QVariant rv = paed.value("textReihenfolge");
            if (rv.isValid()) {
                const auto arr = rv.toList();
                for (const QVariant &v : arr) reihe << v.toString();
            }
            if (reihe.isEmpty()) reihe << QStringLiteral("freitext1")
                                       << QStringLiteral("freitext2");

            QStringList paFt;
            for (const QString &k : reihe) {
                if (paed.value(k + QStringLiteral("Sichtbar"), QVariant(true)).toBool()) {
                    QString v = paed.value(k).toString();
                    if (!v.isEmpty()) paFt << v;
                }
            }

            if (paBmk.isEmpty() && paFt.isEmpty())
                goto paDone;

            {
                double schrift  = paed.value("schriftgroesse", 2.5).toDouble();
                double bmkFsDev = schrift * pxPerMm;
                double ftFsDev  = schrift * 0.85 * pxPerMm;

                double paOx = paed.value("bmkOffsetX", 0.0).toDouble() * C;
                double paOy = paed.value("bmkOffsetY", 0.0).toDouble() * C;

                int  paRot  = ((el.value("rotation").toInt() % 360) + 360) % 360;
                bool paSenk = (paRot == 90 || paRot == 270);
                double paCx = (x1 + x2) / 2.0;
                double paCy = (y1 + y2) / 2.0;

                // BMK-Farbe aus strichFarbe des Elements, Freitext heller
                QString sfStr = el.value("strichFarbe").toString();
                QColor colBmk = sfStr.isEmpty() ? QColor(0x4a, 0x9e, 0xff)
                                                 : QColor(sfStr);
                QColor colFt(0x8a, 0xb4, 0xd4);

                QFont fBmk; fBmk.setFamily(QStringLiteral("sans-serif"));
                fBmk.setPixelSize(qMax(1, qRound(bmkFsDev))); fBmk.setBold(true);
                QFont fFt;  fFt.setFamily(QStringLiteral("sans-serif"));
                fFt.setPixelSize(qMax(1, qRound(ftFsDev)));

                double tw = 20.0 * pxPerMm;

                p.save();
                if (paSenk) {
                    // 90°: Pin unten → Text oben | 270°: Pin oben → Text unten
                    bool pinUnten  = (paRot == 90);
                    double gapDev  = 0.75 * pxPerMm;
                    double paCxO   = paCx + paOx;

                    if (pinUnten) {
                        // Text wächst nach oben vom Symbolrand
                        double curY = qMin(y1, y2) - gapDev + paOy;
                        for (int i = paFt.size() - 1; i >= 0; --i) {
                            curY -= ftFsDev * 1.3;
                            p.setFont(fFt); p.setPen(colFt);
                            p.drawText(QRectF(paCxO - tw/2, curY, tw, ftFsDev * 1.3),
                                       Qt::AlignHCenter | Qt::AlignTop, paFt[i]);
                        }
                        if (!paBmk.isEmpty()) {
                            curY -= bmkFsDev * 1.2;
                            p.setFont(fBmk); p.setPen(colBmk);
                            p.drawText(QRectF(paCxO - tw/2, curY, tw, bmkFsDev * 1.2),
                                       Qt::AlignHCenter | Qt::AlignTop, paBmk);
                        }
                    } else {
                        // Text wächst nach unten vom Symbolrand
                        double curY = qMax(y1, y2) + gapDev + paOy;
                        if (!paBmk.isEmpty()) {
                            p.setFont(fBmk); p.setPen(colBmk);
                            p.drawText(QRectF(paCxO - tw/2, curY, tw, bmkFsDev * 1.2),
                                       Qt::AlignHCenter | Qt::AlignTop, paBmk);
                            curY += bmkFsDev * 1.2;
                        }
                        for (const QString &ft : paFt) {
                            p.setFont(fFt); p.setPen(colFt);
                            p.drawText(QRectF(paCxO - tw/2, curY, tw, ftFsDev * 1.3),
                                       Qt::AlignHCenter | Qt::AlignTop, ft);
                            curY += ftFsDev * 1.3;
                        }
                    }
                } else {
                    // 0°: Pin rechts → Text links | 180°: Pin links → Text rechts
                    bool pinRechts = (paRot == 0);
                    double gapDev  = 1.0 * pxPerMm;
                    double paX     = pinRechts
                                     ? qMin(x1, x2) - gapDev + paOx
                                     : qMax(x1, x2) + gapDev + paOx;
                    double paCyO   = paCy + paOy;
                    Qt::Alignment ha = pinRechts ? Qt::AlignRight : Qt::AlignLeft;

                    // Gesamthöhe für vertikale Zentrierung
                    double totalH = (!paBmk.isEmpty() ? bmkFsDev * 1.1 : 0.0)
                                  + paFt.size() * ftFsDev * 1.3;
                    double curY = paCyO - totalH / 2.0;

                    if (!paBmk.isEmpty()) {
                        p.setFont(fBmk); p.setPen(colBmk);
                        QRectF r = pinRechts ? QRectF(paX - tw, curY, tw, bmkFsDev * 1.2)
                                             : QRectF(paX, curY, tw, bmkFsDev * 1.2);
                        p.drawText(r, ha | Qt::AlignTop, paBmk);
                        curY += bmkFsDev * 1.1;
                    }
                    for (const QString &ft : paFt) {
                        p.setFont(fFt); p.setPen(colFt);
                        QRectF r = pinRechts ? QRectF(paX - tw, curY, tw, ftFsDev * 1.3)
                                             : QRectF(paX, curY, tw, ftFsDev * 1.3);
                        p.drawText(r, ha | Qt::AlignTop, ft);
                        curY += ftFsDev * 1.3;
                    }
                }
                p.restore();
            }
            paDone:;
        }
    }
}

// Aderbezeichnungen an Kabellinie-Schnittpunkten rendern
static void pdfKabelAderBeschriftungRendern(QPainter &p, int seiteId, double C, double pxPerMm,
                                           const QSqlDatabase &db)
{
    // Kabellinie-Elemente laden
    QSqlQuery qk(db);
    qk.prepare(R"(
        SELECT x1, y1, x2, y2, extra_daten, strich_farbe
        FROM grafik_element
        WHERE seite_id = :sid AND typ = 'kabellinie'
    )");
    qk.bindValue(":sid", seiteId);
    if (!qk.exec()) return;

    struct KabelEl {
        double kx1, ky1, kx2, ky2;
        QJsonObject aderZuordnung;
        QJsonArray  adern;
        QColor      klColor;
    };
    QVector<KabelEl> kabel;
    while (qk.next()) {
        KabelEl ke;
        ke.kx1 = qk.value(0).toDouble();
        ke.ky1 = qk.value(1).toDouble();
        ke.kx2 = qk.value(2).toDouble();
        ke.ky2 = qk.value(3).toDouble();
        QString exStr = qk.value(4).toString();
        if (!exStr.isEmpty()) {
            QJsonDocument doc = QJsonDocument::fromJson(exStr.toUtf8());
            if (doc.isObject()) {
                QJsonObject obj = doc.object();
                if (obj.contains(QStringLiteral("aderZuordnung")))
                    ke.aderZuordnung = obj.value(QStringLiteral("aderZuordnung")).toObject();
                if (obj.contains(QStringLiteral("adern")))
                    ke.adern = obj.value(QStringLiteral("adern")).toArray();
            }
        }
        QString sf = qk.value(5).toString();
        ke.klColor = (!sf.isEmpty() && QColor(sf).isValid()) ? QColor(sf)
                                                              : QColor(0xe0, 0x70, 0x00);
        kabel.append(ke);
    }
    if (kabel.isEmpty()) return;

    // Verbindungssegmente laden
    struct VSeg { double x1, y1, x2, y2; int verbId; };
    QVector<VSeg> vsegs;
    QSqlQuery qv(db);
    qv.prepare(R"(SELECT punkte, verbindung_id FROM verbindung_segment WHERE seite_id = :sid)");
    qv.bindValue(":sid", seiteId);
    if (!qv.exec()) return;
    while (qv.next()) {
        QJsonDocument doc = QJsonDocument::fromJson(qv.value(0).toString().toUtf8());
        if (!doc.isArray()) continue;
        QJsonArray arr = doc.array();
        int vId = qv.value(1).toInt();
        // Iterate consecutive point pairs
        for (int i = 0; i < arr.size() - 1; ++i) {
            QJsonObject a = arr[i].toObject();
            QJsonObject b = arr[i+1].toObject();
            vsegs.append({a["x"].toDouble(), a["y"].toDouble(),
                          b["x"].toDouble(), b["y"].toDouble(), vId});
        }
    }

    // Für jede Kabellinie: Schnittpunkte berechnen und Aderbezeichnungen rendern
    for (const KabelEl &ke : kabel) {
        double kdx = ke.kx2 - ke.kx1, kdy = ke.ky2 - ke.ky1;
        double kLen = std::sqrt(kdx*kdx + kdy*kdy);
        if (kLen < 0.5) continue;

        // Schnitte pro verbindung_id (einer pro verbindung)
        struct Schnitt { double t; int verbId; };
        QVector<Schnitt> schnitte;
        QSet<int> gesehen;

        for (const VSeg &vs : vsegs) {
            if (gesehen.contains(vs.verbId)) continue;
            double dax = vs.x2 - vs.x1, day = vs.y2 - vs.y1;
            double D = kdx * day - kdy * dax;
            if (std::abs(D) < 0.001) continue;
            double t = ((vs.x1 - ke.kx1) * day - (vs.y1 - ke.ky1) * dax) / D;
            double s = ((vs.x1 - ke.kx1) * kdy - (vs.y1 - ke.ky1) * kdx) / D;
            if (t >= -0.005 && t <= 1.005 && s >= -0.005 && s <= 1.005) {
                schnitte.append({qBound(0.0, t, 1.0), vs.verbId});
                gesehen.insert(vs.verbId);
            }
        }
        if (schnitte.isEmpty()) continue;
        std::sort(schnitte.begin(), schnitte.end(),
                  [](const Schnitt &a, const Schnitt &b){ return a.t < b.t; });

        // Normalvektor senkrecht zur Kabellinie, nach "oben" (kleinstes y)
        double nx = -kdy/kLen, ny = kdx/kLen;
        if (ny > 0.0) { nx = -nx; ny = -ny; }

        double fsDev   = 1.8 * pxPerMm;
        double tickLen = 0.5 * pxPerMm;
        double lblOff  = tickLen + 0.4 * pxPerMm;

        QFont f; f.setFamily(QStringLiteral("sans-serif"));
        f.setPixelSize(qMax(1, qRound(fsDev)));

        p.save();
        p.setBrush(Qt::NoBrush);

        for (int sci = 0; sci < schnitte.size(); ++sci) {
            double t  = schnitte[sci].t;
            double wx = ke.kx1 + t * kdx;
            double wy = ke.ky1 + t * kdy;
            double vx = wx * C, vy = wy * C;

            // Aderfarbe + nummer aus adern-Array (sequenziell)
            int aderNr = sci + 1;
            QString farbe;
            for (int ai = 0; ai < ke.adern.size(); ++ai) {
                QJsonObject ad = ke.adern[ai].toObject();
                int nr = ad.contains(QStringLiteral("aderNr")) ? ad[QStringLiteral("aderNr")].toInt() : (ai + 1);
                if (nr == aderNr) { farbe = ad[QStringLiteral("farbe")].toString(); break; }
            }

            QString label = QString::number(aderNr);
            if (!farbe.isEmpty()) label += QStringLiteral("  ") + farbe;

            // Kurzer Querstrich
            QPen tickPen(ke.klColor, 0.4 * pxPerMm, Qt::SolidLine, Qt::FlatCap);
            p.setPen(tickPen);
            p.drawLine(QLineF(vx - nx * tickLen, vy - ny * tickLen,
                              vx + nx * tickLen, vy + ny * tickLen));

            // Label — achsenparallele Kabellinie: rechts neben dem Tick (wie QML)
            p.setFont(f);
            p.setPen(ke.klColor);
            bool achsenParallel = (std::abs(nx) < 0.1 || std::abs(ny) < 0.1);
            double lx, ly;
            if (achsenParallel) {
                lx = vx + lblOff;           // immer rechts
                ly = vy + ny * lblOff;      // Offset senkrecht zur Linie
            } else {
                lx = vx + nx * lblOff;
                ly = vy + ny * lblOff;
            }
            Qt::Alignment ha = Qt::AlignLeft;
            double tw = 15.0 * pxPerMm;
            // Rect mit textBaseline "bottom" (QML-Konvention: Text wächst nach oben von ly)
            QRectF r(lx, ly - fsDev * 1.2, tw, fsDev * 1.2);
            p.drawText(r, ha | Qt::AlignBottom, label);
        }
        p.restore();
    }
}

// Verbindungsleitungen aus verbindung_segment rendern (segs vorab per
// pdfLeitungenSammeln geladen – gemeinsam genutzt mit der Winkel/Treffpunkt-
// Farbübernahme in pdfElementRendern).
static void pdfLeitungenRendern(QPainter &p, double C, double pxPerMm,
                                const QVector<PdfLeitungsSegment> &segs)
{
    // ── Kreuzungslücken berechnen ────────────────────────────────────────────
    // Konvention: H-Segment bekommt Lücke, V-Segment verläuft durch.
    struct HSeg { int idx; double x1, x2, y; };
    struct VSeg { int idx; double x,  y1, y2; };
    QVector<HSeg> hSegs;
    QVector<VSeg> vSegs;

    for (int i = 0; i < segs.size(); i++) {
        const PdfLeitungsSegment &s = segs[i];
        if      (qAbs(s.cy2 - s.cy1) < 0.5)
            hSegs.append({i, qMin(s.cx1,s.cx2), qMax(s.cx1,s.cx2), (s.cy1+s.cy2)/2.0});
        else if (qAbs(s.cx2 - s.cx1) < 0.5)
            vSegs.append({i, (s.cx1+s.cx2)/2.0, qMin(s.cy1,s.cy2), qMax(s.cy1,s.cy2)});
    }

    // crossings[segIdx] = sortierte X-Positionen (Canvas-Einheiten) der Kreuzungspunkte
    QHash<int, QVector<double>> crossings;
    for (const HSeg &h : hSegs) {
        for (const VSeg &v : vSegs) {
            if (segs[h.idx].verbId == segs[v.idx].verbId) continue; // selbes Netz
            if (v.x <= h.x1 || v.x >= h.x2) continue;              // V außerhalb H
            if (h.y <= v.y1 || h.y >= v.y2) continue;              // H außerhalb V
            crossings[h.idx].append(v.x);
        }
    }
    for (auto &xList : crossings)
        std::sort(xList.begin(), xList.end());

    // ── Segmente zeichnen ────────────────────────────────────────────────────
    // Lückengröße: 4 Canvas-Einheiten = 1 mm je Seite → 2 mm Gesamtlücke (druckfest)
    const double luecke = 4.0;

    p.setBrush(Qt::NoBrush);
    for (int i = 0; i < segs.size(); i++) {
        const PdfLeitungsSegment &s = segs[i];
        double refX = s.refPunkt.x() * C, refY = s.refPunkt.y() * C;

        auto it = crossings.constFind(i);
        if (it == crossings.constEnd() || it->isEmpty()) {
            // Kein Kreuzungspunkt: normal zeichnen
            pdfMaleGebaenderteLinie(p, s.cx1*C, s.cy1*C, s.cx2*C, s.cy2*C, s, refX, refY, pxPerMm);
        } else {
            // H-Segment mit Lücken: stückweise zeichnen
            double hx1 = qMin(s.cx1, s.cx2);
            double hx2 = qMax(s.cx1, s.cx2);
            double hy  = (s.cy1 + s.cy2) / 2.0;
            double pos = hx1;
            for (double cx : *it) {
                double ls = cx - luecke;
                double le = cx + luecke;
                if (ls > pos)
                    pdfMaleGebaenderteLinie(p, pos*C, hy*C, ls*C, hy*C, s, refX, refY, pxPerMm);
                pos = le;
            }
            if (pos < hx2)
                pdfMaleGebaenderteLinie(p, pos*C, hy*C, hx2*C, hy*C, s, refX, refY, pxPerMm);
        }
    }
}

// Normblatt-Rahmen und Schriftfeld rendern (Koordinaten in Device-Pixeln via pxPerMm)
static void pdfNormblattRendern(QPainter &p, const QVariantMap &nb, double pxPerMm)
{
    double bMm = nb.value("breiteMm", 297.0).toDouble();
    double hMm = nb.value("hoeheMm",  210.0).toDouble();
    double mL  = nb.value("randLinksMm",  20.0).toDouble();
    double mR  = nb.value("randRechtsMm", 10.0).toDouble();
    double mO  = nb.value("randObenMm",   10.0).toDouble();
    double mU  = nb.value("randUntenMm",  10.0).toDouble();

    auto mm = [&](double v){ return v * pxPerMm; };

    // Seitenhintergrund
    QString bg = nb.value("hintergrundFarbe").toString().trimmed();
    if (!bg.isEmpty()) {
        QColor bgC(bg);
        if (bgC.isValid()) {
            p.setBrush(bgC);
            p.setPen(Qt::NoPen);
            p.drawRect(QRectF(0, 0, mm(bMm), mm(hMm)));
        }
    }

    double iX0 = mm(mL),        iY0 = mm(mO);
    double iX1 = mm(bMm - mR),  iY1 = mm(hMm - mU);
    double iW  = iX1 - iX0,     iH  = iY1 - iY0;

    // Seitenbegrenzung (dünn gestrichelt)
    QPen outerPen(QColor(0x2a, 0x4a, 0x7a), mm(0.25), Qt::DashLine);
    p.setPen(outerPen);
    p.setBrush(Qt::NoBrush);
    p.drawRect(QRectF(0, 0, mm(bMm), mm(hMm)));

    // Zeichnungsrahmen (dick)
    QPen framePen(QColor(0x4a, 0x7a, 0xb0), mm(0.7));
    p.setPen(framePen);
    p.drawRect(QRectF(iX0, iY0, iW, iH));

    // Benutzerdefinierte Felder (Phase 2)
    QVariantList felder = nb.value("felder").toList();
    if (!felder.isEmpty()) {
        for (const QVariant &fv : felder) {
            QVariantMap f = fv.toMap();
            double fx = mm(f.value("xMm").toDouble());
            double fy = mm(f.value("yMm").toDouble());
            double fw = mm(f.value("breiteMm").toDouble());
            double fh = mm(f.value("hoeheMm").toDouble());
            // Zelle: Label oben, Wert mittig
            QString feldtyp = f.value("feldtyp").toString();
            QString inhalt;
            if (feldtyp == "fest") {
                inhalt = f.value("inhalt").toString();
            } else if (feldtyp == "logo") {
                // Logo überspringen in v1
                continue;
            } else {
                QString qs = f.value("quelleSpalte").toString();
                QMap<QString,QString> qmap;
                qmap["name"]          = nb.value("projektName").toString();
                qmap["projektnummer"] = nb.value("projektnummer").toString();
                qmap["auftraggeber"]  = nb.value("auftraggeber").toString();
                qmap["auftragnehmer"] = nb.value("auftragnehmer").toString();
                qmap["bearbeiter"]    = nb.value("bearbeiter").toString();
                qmap["norm"]          = nb.value("norm").toString();
                qmap["blattnummer"]   = nb.value("blattnummer").toString();
                qmap["bezeichnung"]   = nb.value("bezeichnung").toString();
                inhalt = qmap.value(qs);
            }
            if (f.value("rahmen").toBool()) {
                p.setPen(QPen(QColor(0x2a, 0x50, 0x80), mm(0.25)));
                p.setBrush(Qt::NoBrush);
                p.drawRect(QRectF(fx, fy, fw, fh));
            }
            // Label
            double lFs = qMax(mm(1.5), qMin(fh * 0.22, mm(2.8)));
            QFont lf; lf.setFamily("sans-serif"); lf.setPixelSize(qMax(1,qRound(lFs)));
            p.setFont(lf); p.setPen(QColor(0x5a,0x7a,0xa0));
            p.drawText(QRectF(fx+mm(1), fy+fh*0.08, fw-mm(2), lFs*1.4), Qt::AlignLeft|Qt::AlignTop,
                       f.value("label").toString());
            // Wert
            double vFs = qMax(mm(2.5), qMin(fh * 0.38, mm(4.5)));
            QFont vf; vf.setFamily("sans-serif"); vf.setPixelSize(qMax(1,qRound(vFs))); vf.setBold(true);
            p.setFont(vf); p.setPen(QColor(0xc8,0xdd,0xf0));
            p.drawText(QRectF(fx+mm(1.2), fy+fh*0.42, fw-mm(2), fh*0.55), Qt::AlignLeft|Qt::AlignTop, inhalt);
        }
        return;  // Benutzerdefinierte Felder gesetzt, fertig
    }

    // Standard-Schriftfeld
    QString vorlage = nb.value("titelblattVorlage", "din6771").toString();
    if (vorlage == "rahmen") return;  // nur Rahmen, kein Schriftfeld

    // Hilfsfunktion: Datum formatieren
    auto datumText = [&]() -> QString {
        QString raw = nb.value("erstelltAm").toString();
        if (raw.length() >= 10) {
            QStringList parts = raw.left(10).split('-');
            if (parts.size() == 3) return parts[2] + "." + parts[1] + "." + parts[0];
        }
        return raw;
    };
    // Vollkennzeichen
    auto vollkz = [&]() -> QString {
        QString auo = nb.value("anlageUO").toString();
        QString ouo = nb.value("ortUO").toString();
        QString a = nb.value("anlageKuerzel").toString();
        QString o = nb.value("ortKuerzel").toString();
        QString bn = nb.value("blattnummer").toString();
        QString kz;
        if (!auo.isEmpty()) kz += "==" + auo;
        if (!ouo.isEmpty()) kz += "++" + ouo;
        if (!a.isEmpty())   kz += "=" + a;
        if (!o.isEmpty())   kz += "+" + o;
        if (!kz.isEmpty()) kz += "/";
        return kz + bn;
    };
    // Seitenformat
    auto formatText = [&]() -> QString {
        double b = bMm, h = hMm;
        double mx = qMax(b,h), mn = qMin(b,h);
        QString fmt;
        if      (qAbs(mx-420)<5 && qAbs(mn-297)<5) fmt="A3";
        else if (qAbs(mx-297)<5 && qAbs(mn-210)<5) fmt="A4";
        else if (qAbs(mx-594)<5 && qAbs(mn-420)<5) fmt="A2";
        else fmt=QString::number(qRound(b))+"x"+QString::number(qRound(h));
        return fmt + (b > h ? " QF" : " HF");
    };

    // Hilfsfunktion: Zelle (Label oben, Wert mittig)
    auto zelle = [&](const QString &label, const QString &wert,
                     double fx, double fy, double fw, double fh) {
        p.setBrush(Qt::NoBrush);
        p.setPen(Qt::NoPen);
        double lFs = qMax(mm(1.5), qMin(fh * 0.22, mm(2.8)));
        QFont lf; lf.setFamily("sans-serif"); lf.setPixelSize(qMax(1,qRound(lFs)));
        p.setFont(lf); p.setPen(QColor(0x5a,0x7a,0xa0));
        p.drawText(QRectF(fx+mm(1), fy+fh*0.08, fw-mm(2), lFs*1.4), Qt::AlignLeft|Qt::AlignTop, label);
        double vFs = qMax(mm(2.5), qMin(fh * 0.38, mm(4.5)));
        QFont vf; vf.setFamily("sans-serif"); vf.setPixelSize(qMax(1,qRound(vFs))); vf.setBold(true);
        p.setFont(vf); p.setPen(QColor(0xc8,0xdd,0xf0));
        p.drawText(QRectF(fx+mm(1.2), fy+fh*0.42, fw-mm(2), fh*0.55), Qt::AlignLeft|Qt::AlignTop, wert);
    };

    QPen cellPen(QColor(0x2a, 0x50, 0x80), mm(0.25));

    if (vorlage == "kompakt") {
        double rowH = mm(8);
        double sfY0 = iY1 - 2 * rowH;
        double sfH  = 2 * rowH;
        double cX[4] = { iX0, iX0+iW*0.45, iX0+iW*0.72, iX1 };
        double rY[2] = { sfY0, sfY0+rowH };

        // Hintergrund
        p.setBrush(QColor(5,15,35,180)); p.setPen(Qt::NoPen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
        p.setBrush(Qt::NoBrush);

        p.setPen(cellPen);
        for (int c = 1; c <= 2; c++)
            p.drawLine(QLineF(cX[c], sfY0, cX[c], iY1));
        for (int r = 0; r < 2; r++)
            p.drawLine(QLineF(iX0, rY[r], iX1, rY[r]));

        zelle("PROJEKT",      nb.value("projektName").toString(),   cX[0],rY[0],cX[1]-cX[0],rowH);
        zelle("BLATT",        nb.value("blattnummer").toString(),   cX[1],rY[0],cX[2]-cX[1],rowH);
        zelle("DATUM",        datumText(),                          cX[2],rY[0],cX[3]-cX[2],rowH);
        zelle("BEZEICHNUNG",  nb.value("bezeichnung").toString(),   cX[0],rY[1],cX[1]-cX[0],rowH);
        zelle("SEITENKENNZ.", vollkz(),                             cX[1],rY[1],cX[2]-cX[1],rowH);
        zelle("BEARBEITER",   nb.value("bearbeiter").toString(),    cX[2],rY[1],cX[3]-cX[2],rowH);

        p.setPen(framePen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));

    } else {
        // DIN 6771: 3 Zeilen × 13mm
        double rowH = mm(13);
        double sfY0 = iY1 - 3 * rowH;
        double sfH  = 3 * rowH;
        double cX[5] = { iX0, iX0+iW*0.21, iX0+iW*0.66, iX0+iW*0.86, iX1 };
        double rY[3] = { sfY0, sfY0+rowH, sfY0+2*rowH };

        // Hintergrund
        p.setBrush(QColor(5,15,35,204)); p.setPen(Qt::NoPen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
        p.setBrush(Qt::NoBrush);

        p.setPen(cellPen);
        for (int c = 1; c <= 3; c++)
            p.drawLine(QLineF(cX[c], sfY0, cX[c], iY1));
        for (int r = 0; r < 3; r++)
            p.drawLine(QLineF(iX0, rY[r], iX1, rY[r]));

        zelle("AUFTRAGGEBER", nb.value("auftraggeber").toString(),  cX[0],rY[0],cX[1]-cX[0],rowH);
        zelle("PROJEKT",      nb.value("projektName").toString(),   cX[1],rY[0],cX[2]-cX[1],rowH);
        zelle("PROJEKTNR.",   nb.value("projektnummer").toString(), cX[2],rY[0],cX[3]-cX[2],rowH);
        zelle("BLATT",        nb.value("blattnummer").toString(),   cX[3],rY[0],cX[4]-cX[3],rowH);

        zelle("AUFTRAGNEHMER",nb.value("auftragnehmer").toString(), cX[0],rY[1],cX[1]-cX[0],rowH);
        zelle("BEZEICHNUNG",  nb.value("bezeichnung").toString(),   cX[1],rY[1],cX[2]-cX[1],rowH);
        zelle("FORMAT",       formatText(),                         cX[2],rY[1],cX[3]-cX[2],rowH);
        zelle("DATUM",        datumText(),                          cX[3],rY[1],cX[4]-cX[3],rowH);

        zelle("BEARBEITER",   nb.value("bearbeiter").toString(),    cX[0],rY[2],cX[1]-cX[0],rowH);
        zelle("SEITENKENNZ.", vollkz(),                             cX[1],rY[2],cX[2]-cX[1],rowH);
        zelle("NORM",         nb.value("norm", "IEC").toString(),   cX[2],rY[2],cX[3]-cX[2],rowH);
        {
            QString rev = nb.value("revisionKennung").toString();
            zelle("REV.", rev.isEmpty() ? QStringLiteral("–") : rev, cX[3],rY[2],cX[4]-cX[3],rowH);
        }

        p.setPen(framePen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
    }
}

// ── Minimaler Infostreifen für Seiten ohne Normblatt ────────────────────────
// Zeichnet einen 8 mm hohen Streifen am unteren Seitenrand mit:
//   Links: Projektname · Auftraggeber   |   Mitte: Blatt – Bezeichnung (fett)
//   Rechts: Exportdatum · Bearbeiter
static void pdfInfostreifenRendern(QPainter &p, const QVariantMap &nb,
                                    double bMm, double hMm, double pxPerMm)
{
    const double hStrMm = 8.0;
    const double padMm  = 1.5;
    double y0 = (hMm - hStrMm) * pxPerMm;
    double w  =  bMm           * pxPerMm;
    double h  =  hStrMm        * pxPerMm;

    p.fillRect(QRectF(0, y0, w, h), Qt::white);

    QPen linePen(Qt::black, 0.4 * pxPerMm);
    p.setPen(linePen);
    p.drawLine(QLineF(0, y0, w, y0));                // obere Trennlinie

    // Abschnittsgrenzen (prozentual)
    double x1 = w * 0.40;
    double x2 = w * 0.72;
    p.drawLine(QLineF(x1, y0, x1, hMm * pxPerMm));  // 1. vertikale Linie
    p.drawLine(QLineF(x2, y0, x2, hMm * pxPerMm));  // 2. vertikale Linie

    // Textstil
    QFont font;
    font.setFamily(QStringLiteral("sans-serif"));
    font.setPixelSize(qMax(1, qRound(2.8 * pxPerMm)));
    p.setFont(font);
    p.setPen(Qt::black);

    double pad  = padMm * pxPerMm;
    double tY   = y0 + pad;
    double tH   = h - 2.0 * pad;

    // Links: Projektname · Auftraggeber
    QString links = nb.value("projektName").toString();
    QString ag    = nb.value("auftraggeber").toString();
    if (!ag.isEmpty()) links += QStringLiteral("  \xB7  ") + ag;
    p.drawText(QRectF(pad, tY, x1 - 2*pad, tH),
               Qt::AlignLeft | Qt::AlignVCenter | Qt::TextWordWrap, links);

    // Mitte: Blattnummer – Bezeichnung (fett)
    QString blatt = nb.value("blattnummer").toString();
    QString bez   = nb.value("bezeichnung").toString();
    QString mitte = blatt.isEmpty() ? bez
                  : bez.isEmpty()   ? blatt
                  : blatt + QStringLiteral(" \x2013 ") + bez;
    QFont fontB = font; fontB.setBold(true);
    p.setFont(fontB);
    p.drawText(QRectF(x1 + pad, tY, x2 - x1 - 2*pad, tH),
               Qt::AlignHCenter | Qt::AlignVCenter, mitte);

    // Rechts: Datum · Bearbeiter
    p.setFont(font);
    QString datum      = QDateTime::currentDateTime().toString("dd.MM.yyyy");
    QString bearbeiter = nb.value("bearbeiter").toString();
    QString rechts     = datum;
    if (!bearbeiter.isEmpty()) rechts += QStringLiteral("  \xB7  ") + bearbeiter;
    p.drawText(QRectF(x2 + pad, tY, w - x2 - 2*pad, tH),
               Qt::AlignRight | Qt::AlignVCenter, rechts);
}

// ── Revisionsmarker-Wasserzeichen (analog SchaltplanCanvas.qml) ─────────────
// Wird unabhängig von Normblatt/Infostreifen/vollCanvas auf jeder Seite gezeichnet,
// sofern ein Revisionsstatus gesetzt ist.
static void pdfRevisionswasserzeichenRendern(QPainter &p, const QVariantMap &nb,
                                              double bMm, double hMm, double pxPerMm)
{
    QString status = nb.value("revisionStatus").toString();
    if (status.isEmpty()) return;

    QString text;
    QColor  farbe;
    if (status == QStringLiteral("entwurf")) {
        text  = QStringLiteral("ENTWURF");
        farbe = QColor(0xd9, 0x77, 0x06);
    } else if (status == QStringLiteral("freigegeben")) {
        QString kennung = nb.value("revisionKennung").toString();
        text = QStringLiteral("FREIGEGEBEN") +
               (kennung.isEmpty() ? QString() : QStringLiteral("  REV. ") + kennung);
        farbe = QColor(0x16, 0xa3, 0x4a);
    } else if (status == QStringLiteral("veraltet")) {
        text  = QStringLiteral("VERALTET");
        farbe = QColor(0xdc, 0x26, 0x26);
    } else {
        return;
    }

    p.save();
    p.translate(bMm * pxPerMm / 2.0, hMm * pxPerMm / 2.0);
    p.rotate(-30);
    p.setOpacity(0.10);
    QFont f; f.setFamily(QStringLiteral("sans-serif")); f.setBold(true);
    f.setPixelSize(qMax(1, qRound(qMin(bMm, hMm) * pxPerMm / 5.0)));
    p.setFont(f);
    p.setPen(farbe);
    QFontMetricsF fm(f);
    QRectF bound = fm.boundingRect(text);
    p.drawText(QRectF(-bound.width() / 2.0, -bound.height() / 2.0, bound.width(), bound.height()),
               Qt::AlignCenter, text);
    p.restore();
}

// ── Bounding-Box einer Seite berechnen (für vollCanvas-Modus) ───────────────
struct PdfBBox { double txCu, tyCu, bMm, hMm; };

static PdfBBox pdfBoundingBox(int seiteId, double normBMm, double normHMm,
                               const QSqlDatabase &db)
{
    const double randCu = 20.0; // 5 mm Rand
    double bxMin =  1e9, byMin =  1e9;
    double bxMax = -1e9, byMax = -1e9;

    QSqlQuery bq(db);
    bq.prepare(R"(
        SELECT CASE WHEN x1<x2 THEN x1 ELSE x2 END,
               CASE WHEN y1<y2 THEN y1 ELSE y2 END,
               CASE WHEN x1>x2 THEN x1 ELSE x2 END,
               CASE WHEN y1>y2 THEN y1 ELSE y2 END
        FROM grafik_element WHERE seite_id = :sid
    )");
    bq.bindValue(":sid", seiteId);
    if (bq.exec()) {
        while (bq.next()) {
            bxMin = qMin(bxMin, bq.value(0).toDouble());
            byMin = qMin(byMin, bq.value(1).toDouble());
            bxMax = qMax(bxMax, bq.value(2).toDouble());
            byMax = qMax(byMax, bq.value(3).toDouble());
        }
    }
    QSqlQuery sq(db);
    sq.prepare("SELECT punkte FROM verbindung_segment WHERE seite_id = :sid");
    sq.bindValue(":sid", seiteId);
    if (sq.exec()) {
        while (sq.next()) {
            QJsonDocument doc = QJsonDocument::fromJson(sq.value(0).toString().toUtf8());
            if (!doc.isArray()) continue;
            for (const QJsonValue &v : doc.array()) {
                double px = v.toObject()["x"].toDouble();
                double py = v.toObject()["y"].toDouble();
                bxMin = qMin(bxMin, px); byMin = qMin(byMin, py);
                bxMax = qMax(bxMax, px); byMax = qMax(byMax, py);
            }
        }
    }
    if (bxMin < bxMax && byMin < byMax)
        return { bxMin - randCu, byMin - randCu,
                 (bxMax - bxMin + 2.0 * randCu) * 0.25,
                 (byMax - byMin + 2.0 * randCu) * 0.25 };
    return { 0.0, 0.0, normBMm, normHMm };
}

// ── Öffentliche Methoden ─────────────────────────────────────

bool Database::dateiExistiert(const QString &pfad) const
{
    QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;
    return QFile::exists(localPath);
}

bool Database::canvasPdfExportieren(int projektId, const QString &pfad, bool mitNormblatt, bool vollCanvas, bool mitInfostreifen)
{
    // Alle Seiten des Projekts in Anzeigereihenfolge laden
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT s.id
        FROM seite s
        JOIN ort     o ON s.ort_id      = o.id
        JOIN anlage  a ON o.anlage_id   = a.id
        WHERE a.projekt_id = :pid
        ORDER BY a.kuerzel, o.kuerzel, s.sortierung, s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec() || !q.next()) {
        qCWarning(lcDb) << "canvasPdfExportieren: keine Seiten für Projekt" << projektId;
        return false;
    }
    QList<int> seiteIds;
    seiteIds << q.value(0).toInt();
    while (q.next()) seiteIds << q.value(0).toInt();

    // Ausgabepfad normalisieren
    QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    // Erste Seite für initiale Papiergröße
    QVariantMap nb0 = normblattDatenLaden(seiteIds.first());
    double b0 = nb0.value("breiteMm", 297.0).toDouble();
    double h0 = nb0.value("hoeheMm",  210.0).toDouble();
    if (vollCanvas) {
        PdfBBox bb0 = pdfBoundingBox(seiteIds.first(), b0, h0, m_db);
        b0 = bb0.bMm; h0 = bb0.hMm;
    }

    QPdfWriter writer(localPath);
    writer.setCreator(QStringLiteral("Stroemling Design"));
    writer.setTitle(nb0.value("projektName").toString());
    writer.setPageMargins(QMarginsF(0, 0, 0, 0));
    writer.setPageLayout(QPageLayout(
        QPageSize(QSizeF(b0, h0), QPageSize::Millimeter),
        QPageLayout::Portrait, QMarginsF(0,0,0,0)));

    QPainter painter(&writer);
    if (!painter.isActive()) {
        qCWarning(lcDb) << "canvasPdfExportieren: QPainter konnte nicht gestartet werden";
        return false;
    }

    // DPI-basierte Skalierung: alle Zeichenaufrufe in Device-Pixeln
    double pxPerMm = (double)writer.logicalDpiX() / 25.4;
    double C       = pxPerMm / 4.0;   // Canvas-Pixel → Device-Pixel

    for (int i = 0; i < seiteIds.size(); ++i) {
        int seiteId = seiteIds[i];
        QVariantMap nb = normblattDatenLaden(seiteId);
        double bMm = nb.value("breiteMm", 297.0).toDouble();
        double hMm = nb.value("hoeheMm",  210.0).toDouble();
        double txCu = 0.0, tyCu = 0.0;

        if (vollCanvas) {
            PdfBBox bb = pdfBoundingBox(seiteId, bMm, hMm, m_db);
            txCu = bb.txCu; tyCu = bb.tyCu;
            bMm  = bb.bMm;  hMm  = bb.hMm;
        }

        if (i > 0) {
            writer.setPageLayout(QPageLayout(
                QPageSize(QSizeF(bMm, hMm), QPageSize::Millimeter),
                QPageLayout::Portrait, QMarginsF(0,0,0,0)));
            writer.newPage();
        }

        // Weißer Seitenhintergrund + Elemente im eigenen save/restore-Block
        // (enthält ggf. den vollCanvas-Translate)
        painter.save();
        painter.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);
        if (vollCanvas)
            painter.translate(-txCu * C, -tyCu * C);
        QVariantList elemente = grafikLaden(seiteId);
        QVector<PdfLeitungsSegment> leitungsSegs = pdfLeitungenSammeln(seiteId, pxPerMm, m_db);
        for (const QVariant &ev : elemente)
            pdfElementRendern(painter, ev.toMap(), C, pxPerMm, m_db, &leitungsSegs);
        pdfLeitungenRendern(painter, C, pxPerMm, leitungsSegs);
        pdfKabelAderBeschriftungRendern(painter, seiteId, C, pxPerMm, m_db);
        painter.restore();  // Translate entfernt – ab hier absolute Seitenkoordinaten

        // Normblatt + Infostreifen in absoluten Koordinaten (kein Translate aktiv)
        if (mitNormblatt && !vollCanvas && nb.value("normblattAnzeigen").toBool())
            pdfNormblattRendern(painter, nb, pxPerMm);
        if (mitInfostreifen && !nb.value("normblattAnzeigen").toBool())
            pdfInfostreifenRendern(painter, nb, bMm, hMm, pxPerMm);
        pdfRevisionswasserzeichenRendern(painter, nb, bMm, hMm, pxPerMm);
    }

    painter.end();
    qCInfo(lcDb) << "canvasPdfExportieren: PDF gespeichert:" << localPath
            << "(" << seiteIds.size() << "Seiten)";
    return QFile::exists(localPath);
}

bool Database::canvasSeiteExportieren(int seiteId, const QString &pfad, bool mitNormblatt, bool vollCanvas, bool mitInfostreifen)
{
    QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QVariantMap nb = normblattDatenLaden(seiteId);
    double bMm = nb.value("breiteMm", 297.0).toDouble();
    double hMm = nb.value("hoeheMm",  210.0).toDouble();

    // ── Vollständiger Canvas-Bereich: Seitengröße aus Bounding-Box berechnen ─
    double txCu = 0.0, tyCu = 0.0;
    if (vollCanvas) {
        PdfBBox bb = pdfBoundingBox(seiteId, bMm, hMm, m_db);
        txCu = bb.txCu; tyCu = bb.tyCu;
        bMm  = bb.bMm;  hMm  = bb.hMm;
    }

    QPdfWriter writer(localPath);
    writer.setCreator(QStringLiteral("Stroemling Design"));
    writer.setTitle(nb.value("projektName").toString());
    writer.setPageMargins(QMarginsF(0, 0, 0, 0));
    writer.setPageLayout(QPageLayout(
        QPageSize(QSizeF(bMm, hMm), QPageSize::Millimeter),
        QPageLayout::Portrait, QMarginsF(0,0,0,0)));

    QPainter painter(&writer);
    if (!painter.isActive()) {
        qCWarning(lcDb) << "canvasSeiteExportieren: QPainter konnte nicht gestartet werden";
        return false;
    }

    double pxPerMm = (double)writer.logicalDpiX() / 25.4;
    double C       = pxPerMm / 4.0;

    painter.save();
    painter.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);
    if (vollCanvas)
        painter.translate(-txCu * C, -tyCu * C);
    QVariantList elemente = grafikLaden(seiteId);
    QVector<PdfLeitungsSegment> leitungsSegs = pdfLeitungenSammeln(seiteId, pxPerMm, m_db);
    for (const QVariant &ev : elemente)
        pdfElementRendern(painter, ev.toMap(), C, pxPerMm, m_db, &leitungsSegs);
    pdfLeitungenRendern(painter, C, pxPerMm, leitungsSegs);
    pdfKabelAderBeschriftungRendern(painter, seiteId, C, pxPerMm, m_db);
    painter.restore();

    if (mitNormblatt && !vollCanvas && nb.value("normblattAnzeigen").toBool())
        pdfNormblattRendern(painter, nb, pxPerMm);
    if (mitInfostreifen && !nb.value("normblattAnzeigen").toBool())
        pdfInfostreifenRendern(painter, nb, bMm, hMm, pxPerMm);
    pdfRevisionswasserzeichenRendern(painter, nb, bMm, hMm, pxPerMm);

    painter.end();
    qCInfo(lcDb) << "canvasSeiteExportieren: PDF gespeichert:" << localPath
            << (vollCanvas ? "(vollCanvas)" : "");
    return QFile::exists(localPath);
}
