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
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <algorithm>
#include <QPrinter>
#include <QTextDocument>
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
        "aderdefinition","querverweis"
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

// Einzelnes grafik_element rendern
static void pdfElementRendern(QPainter &p, const QVariantMap &el,
                               double C, double pxPerMm, const QSqlDatabase &db)
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
        double fsMm = el.value("strichBreite", 3.5).toDouble();
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
        double fsMm  = ed.value("schriftGroesse", 3.5).toDouble();
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
        // Kabelkopf-Label (nur Bezeichnung, kompakt)
        QVariantMap ed = el.value("extraDaten").toMap();
        QString bez = ed.value("bezeichnung").toString();
        if (!bez.isEmpty()) {
            double fsDev = 2.5 * pxPerMm;
            QFont font;
            font.setFamily(QStringLiteral("sans-serif"));
            font.setPixelSize(qMax(1, qRound(fsDev)));
            font.setBold(true);
            p.setFont(font);
            p.setPen(kPen.color());
            p.drawText(QRectF(x1 + cr + 2, y1 - fsDev, 200 * 0.25 * pxPerMm, fsDev * 1.4),
                       Qt::AlignLeft | Qt::AlignBottom, bez);
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
        pdfSymbolRendern(p,
                         el.value("symbolId").toString(),
                         symX, symY, absSw, absSh,
                         el.value("rotation").toInt(),
                         el.value("spiegelX").toBool(),
                         el.value("spiegelY").toBool(),
                         pen, db);
        pdfBeschriftungRendern(p, el, C, pxPerMm);

        // ── Aderdefinitions-Textblock ────────────────────────────────────────
        if (el.value("symbolId").toString() == QStringLiteral("aderdefinition")) {
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
    }
}

// Verbindungsleitungen aus verbindung_segment rendern
static void pdfLeitungenRendern(QPainter &p, int seiteId, double C, double pxPerMm,
                                const QSqlDatabase &db)
{
    // ── Alle Segmente laden ──────────────────────────────────────────────────
    struct Seg {
        double cx1, cy1, cx2, cy2;   // Canvas-Koordinaten (1 Einheit = 0.25 mm)
        int    verbId;
        QColor color;
        double lw;                    // Linienbreite in Device-Pixeln
    };
    QVector<Seg> segs;

    QSqlQuery q(db);
    q.prepare(R"(
        SELECT vs.punkte, vs.verbindung_id, v.signaltyp, v.farbe
        FROM verbindung_segment vs
        JOIN verbindung v ON vs.verbindung_id = v.id
        WHERE vs.seite_id = :sid
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) return;

    while (q.next()) {
        QJsonDocument doc = QJsonDocument::fromJson(q.value(0).toString().toUtf8());
        if (!doc.isArray() || doc.array().size() < 2) continue;
        QJsonArray arr = doc.array();

        QString signaltyp = q.value(2).toString();
        QString farbe     = q.value(3).toString();

        QColor clr;
        if      (signaltyp == "phase")    clr = QColor(0x40, 0x90, 0xff);
        else if (signaltyp == "pe")       clr = QColor(0x20, 0xb0, 0x20);
        else if (signaltyp == "n")        clr = QColor(0xa0, 0xa0, 0xff);
        else if (signaltyp == "steuer")   clr = QColor(0xff, 0xc0, 0x40);
        else if (signaltyp == "konflikt") clr = QColor(0xff, 0x30, 0x30);
        else                              clr = Qt::black;
        if (!farbe.isEmpty()) { QColor fc(farbe); if (fc.isValid()) clr = fc; }

        segs.append({ arr[0].toObject()["x"].toDouble(),
                      arr[0].toObject()["y"].toDouble(),
                      arr[1].toObject()["x"].toDouble(),
                      arr[1].toObject()["y"].toDouble(),
                      q.value(1).toInt(),
                      clr,
                      qMax(0.3, 1.5 * 0.25 * pxPerMm) });
    }

    // ── Kreuzungslücken berechnen ────────────────────────────────────────────
    // Konvention: H-Segment bekommt Lücke, V-Segment verläuft durch.
    struct HSeg { int idx; double x1, x2, y; };
    struct VSeg { int idx; double x,  y1, y2; };
    QVector<HSeg> hSegs;
    QVector<VSeg> vSegs;

    for (int i = 0; i < segs.size(); i++) {
        const Seg &s = segs[i];
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
        const Seg &s = segs[i];
        QPen pen(s.color, s.lw, Qt::SolidLine, Qt::FlatCap);

        auto it = crossings.constFind(i);
        if (it == crossings.constEnd() || it->isEmpty()) {
            // Kein Kreuzungspunkt: normal zeichnen
            p.setPen(pen);
            p.drawLine(QLineF(s.cx1*C, s.cy1*C, s.cx2*C, s.cy2*C));
        } else {
            // H-Segment mit Lücken: stückweise zeichnen
            double hx1 = qMin(s.cx1, s.cx2);
            double hx2 = qMax(s.cx1, s.cx2);
            double hy  = (s.cy1 + s.cy2) / 2.0;
            pen.setCapStyle(Qt::FlatCap);
            p.setPen(pen);
            double pos = hx1;
            for (double cx : *it) {
                double ls = cx - luecke;
                double le = cx + luecke;
                if (ls > pos)
                    p.drawLine(QLineF(pos*C, hy*C, ls*C, hy*C));
                pos = le;
            }
            if (pos < hx2)
                p.drawLine(QLineF(pos*C, hy*C, hx2*C, hy*C));
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
        QString a = nb.value("anlageKuerzel").toString();
        QString o = nb.value("ortKuerzel").toString();
        QString bn = nb.value("blattnummer").toString();
        QString kz;
        if (!a.isEmpty()) kz += "=" + a;
        if (!o.isEmpty()) kz += "+" + o;
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
        zelle("INDEX",        QStringLiteral("–"),             cX[3],rY[2],cX[4]-cX[3],rowH);

        p.setPen(framePen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
    }
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

bool Database::canvasPdfExportieren(int projektId, const QString &pfad, bool mitNormblatt, bool vollCanvas)
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
        qWarning() << "canvasPdfExportieren: keine Seiten für Projekt" << projektId;
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
        qWarning() << "canvasPdfExportieren: QPainter konnte nicht gestartet werden";
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

        painter.save();

        // Weißer Seitenhintergrund
        painter.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);

        if (vollCanvas)
            painter.translate(-txCu * C, -tyCu * C);

        // Canvas-Elemente rendern
        QVariantList elemente = grafikLaden(seiteId);
        for (const QVariant &ev : elemente)
            pdfElementRendern(painter, ev.toMap(), C, pxPerMm, m_db);

        // Verbindungsleitungen aus DB
        pdfLeitungenRendern(painter, seiteId, C, pxPerMm, m_db);

        // Normblatt-Rahmen + Schriftfeld (nicht im vollCanvas-Modus)
        if (!vollCanvas && mitNormblatt && nb.value("normblattAnzeigen").toBool())
            pdfNormblattRendern(painter, nb, pxPerMm);

        painter.restore();
    }

    painter.end();
    qInfo() << "canvasPdfExportieren: PDF gespeichert:" << localPath
            << "(" << seiteIds.size() << "Seiten)";
    return QFile::exists(localPath);
}

bool Database::canvasSeiteExportieren(int seiteId, const QString &pfad, bool mitNormblatt, bool vollCanvas)
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
        qWarning() << "canvasSeiteExportieren: QPainter konnte nicht gestartet werden";
        return false;
    }

    double pxPerMm = (double)writer.logicalDpiX() / 25.4;
    double C       = pxPerMm / 4.0;

    painter.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);

    // Vollständiger Canvas-Modus: alle Zeichenaufrufe um Bounding-Box-Ursprung verschieben
    if (vollCanvas)
        painter.translate(-txCu * C, -tyCu * C);

    QVariantList elemente = grafikLaden(seiteId);
    for (const QVariant &ev : elemente)
        pdfElementRendern(painter, ev.toMap(), C, pxPerMm, m_db);

    pdfLeitungenRendern(painter, seiteId, C, pxPerMm, m_db);

    if (mitNormblatt && nb.value("normblattAnzeigen").toBool())
        pdfNormblattRendern(painter, nb, pxPerMm);

    painter.end();
    qInfo() << "canvasSeiteExportieren: PDF gespeichert:" << localPath
            << (vollCanvas ? "(vollCanvas)" : "");
    return QFile::exists(localPath);
}

// ── Verzeichnis rekursiv kopieren (interner Helfer) ──────────────────────────
static void kopierVerzeichnis(const QString &von, const QString &nach)
{
    QDir().mkpath(nach);
    QDirIterator it(von, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        QString rel = QDir(von).relativeFilePath(it.filePath());
        QString dst = nach + "/" + rel;
        QDir().mkpath(QFileInfo(dst).absolutePath());
        QFile::remove(dst);
        QFile::copy(it.filePath(), dst);
    }
}

// ── Komplettarchiv-Export (BACKUP-01 Ebene 2) ───────────────────────────────
// Struktur im Zielordner:
//   manifest.json       — Metadaten + Projektliste
//   wiki_export.json    — Wiki-Sicherung (JSON, für menschenlesbaren Merge)
//   makros.db           — Makro-Bibliothek (VACUUM INTO)
//   wiki.db             — Wiki-Datenbank (VACUUM INTO)
//   wiki_blobs/         — Wiki-Anhänge (rekursive Kopie)
//   projekte/           — Kopien aller bekannten .strl-Projektdateien
// ────────────────────────────────────────────────────────────────────────────
QVariantMap Database::komplettarchivExportieren(const QString &zielOrdner)
{
    QString ziel = QUrl(zielOrdner).isLocalFile() ? QUrl(zielOrdner).toLocalFile() : zielOrdner;
    if (!QDir().mkpath(ziel))
        return {{"erfolg", false}, {"meldung", QStringLiteral("Zielordner konnte nicht erstellt werden")}};

    // 1a. Wiki als JSON exportieren (menschenlesbarer Fallback)
    QString wikiJsonPfad = ziel + QStringLiteral("/wiki_export.json");
    bool wikiJsonOk = wikiExportJson(wikiJsonPfad);

    // 1b. makros.db per VACUUM INTO sichern
    bool makroDbOk = false;
    if (m_makroDb.isOpen()) {
        QString zielPfad = ziel + QStringLiteral("/makros.db");
        QString esc = zielPfad; esc.replace("'", "''");
        QSqlQuery q(m_makroDb);
        makroDbOk = q.exec(QString("VACUUM INTO '%1'").arg(esc));
        if (!makroDbOk)
            qWarning() << "komplettarchivExportieren makros.db:" << q.lastError().text();
    }

    // 1c. wiki.db per VACUUM INTO sichern
    bool wikiDbOk = false;
    if (m_wikiDb.isOpen()) {
        QString zielPfad = ziel + QStringLiteral("/wiki.db");
        QString esc = zielPfad; esc.replace("'", "''");
        QSqlQuery q(m_wikiDb);
        wikiDbOk = q.exec(QString("VACUUM INTO '%1'").arg(esc));
        if (!wikiDbOk)
            qWarning() << "komplettarchivExportieren wiki.db:" << q.lastError().text();
    }

    // 1d. wiki_blobs/ rekursiv kopieren
    if (m_launcherDb.isOpen()) {
        QString blobsSrc = QFileInfo(m_launcherDb.databaseName()).absolutePath() + "/wiki_blobs";
        if (QDir(blobsSrc).exists())
            kopierVerzeichnis(blobsSrc, ziel + "/wiki_blobs");
    }

    // 2. Bekannte Projektdateien kopieren
    QString projOrdner = ziel + QStringLiteral("/projekte");
    if (!QDir().mkpath(projOrdner))
        return {{"erfolg", false}, {"meldung", QStringLiteral("Projektordner konnte nicht erstellt werden")}};

    int projekteAnzahl = 0;
    QJsonArray projekteListe;

    QSqlQuery q(m_launcherDb);
    if (q.exec("SELECT pfad, name FROM zuletzt_geoeffnet ORDER BY geoeffnet_am DESC")) {
        while (q.next()) {
            QString pfad = q.value(0).toString();
            QString name = q.value(1).toString();
            if (!QFile::exists(pfad)) continue;

            QString dateiName = QFileInfo(pfad).fileName();
            QString zielPfad  = projOrdner + "/" + dateiName;
            if (QFile::exists(zielPfad)) {
                QString stem = QFileInfo(dateiName).baseName();
                dateiName = stem + "_" + QString::number(projekteAnzahl + 1) + ".strl";
                zielPfad  = projOrdner + "/" + dateiName;
            }
            if (QFile::copy(pfad, zielPfad)) {
                projekteAnzahl++;
                projekteListe.append(QJsonObject{
                    {QStringLiteral("name"),         name},
                    {QStringLiteral("datei"),        dateiName},
                    {QStringLiteral("originalPfad"), pfad}
                });
            } else {
                qWarning() << "komplettarchivExportieren: Projektkopie fehlgeschlagen:" << pfad;
            }
        }
    }

    // 3. manifest.json schreiben (Version 2)
    QJsonObject manifest{
        {QStringLiteral("stroemling_backup_version"), 2},
        {QStringLiteral("exportiert_am"),   QDateTime::currentDateTime().toString(Qt::ISODate)},
        {QStringLiteral("makros_db"),        makroDbOk},
        {QStringLiteral("wiki_db"),          wikiDbOk},
        {QStringLiteral("wiki_json"),        wikiJsonOk},
        {QStringLiteral("projekte"),         projekteListe}
    };
    QFile mf(ziel + QStringLiteral("/manifest.json"));
    if (mf.open(QIODevice::WriteOnly | QIODevice::Text))
        mf.write(QJsonDocument(manifest).toJson(QJsonDocument::Indented));

    QString meldung = QString("%1 Projekt(e)").arg(projekteAnzahl);
    if (makroDbOk) meldung += ", Makros";
    if (wikiDbOk)  meldung += ", Wiki";
    meldung += QStringLiteral(" gesichert");

    qInfo() << "komplettarchivExportieren:" << projekteAnzahl << "Projekt(e),"
            << "makros=" << makroDbOk << "wiki=" << wikiDbOk << "→" << ziel;
    return {
        {QStringLiteral("erfolg"),         true},
        {QStringLiteral("projekteAnzahl"), projekteAnzahl},
        {QStringLiteral("makroDbOk"),      makroDbOk},
        {QStringLiteral("wikiDbOk"),       wikiDbOk},
        {QStringLiteral("meldung"),        meldung}
    };
}

// ── Komplettarchiv-Import (BACKUP-01 Ebene 2) ───────────────────────────────
// 1. makros.db + wiki.db + wiki_blobs/ → _pendingrestore/ (angewendet beim nächsten Start)
// 2. Wiki-JSON merge (sofort, für schnellen Zugriff ohne Neustart)
// 3. .strl-Projektdateien → dataDir/importierte_projekte/ + in zuletzt_geoeffnet eintragen
// ────────────────────────────────────────────────────────────────────────────
QVariantMap Database::komplettarchivImportieren(const QString &quellOrdner)
{
    QString quelle = QUrl(quellOrdner).isLocalFile() ? QUrl(quellOrdner).toLocalFile() : quellOrdner;

    // manifest.json lesen
    QFile mf(quelle + QStringLiteral("/manifest.json"));
    if (!mf.open(QIODevice::ReadOnly))
        return {{"erfolg", false}, {"meldung", QStringLiteral("manifest.json nicht gefunden – kein gültiges Archiv")}};

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(mf.readAll(), &err);
    if (doc.isNull() || !doc.isObject())
        return {{"erfolg", false}, {"meldung", QStringLiteral("Ungültiges Archiv: ") + err.errorString()}};

    QJsonObject root = doc.object();
    int backupVer = root.value(QStringLiteral("stroemling_backup_version")).toInt();
    if (backupVer != 2)
        return {{"erfolg", false}, {"meldung", QStringLiteral("Unbekannte Archiv-Version (erwartet v2)")}};

    if (!m_launcherDb.isOpen())
        return {{"erfolg", false}, {"meldung", QStringLiteral("Launcher-DB nicht geöffnet")}};

    QString dataDir    = QFileInfo(m_launcherDb.databaseName()).absolutePath();
    QString pendingDir = dataDir + QStringLiteral("/_pendingrestore");
    QDir().mkpath(pendingDir);

    // 1. DB-Dateien für Neustart-Wiederherstellung vorbereiten
    bool makroDbGeplant = false, wikiDbGeplant = false;
    for (const auto &[dateiname, geplant] :
         std::initializer_list<std::pair<QString, bool*>>{
             {"makros.db", &makroDbGeplant},
             {"wiki.db",   &wikiDbGeplant}}) {
        QString src = quelle + "/" + dateiname;
        if (QFile::exists(src)) {
            QString dst = pendingDir + "/" + dateiname;
            QFile::remove(dst);
            *geplant = QFile::copy(src, dst);
        }
    }

    // wiki_blobs/ kopieren (in _pendingrestore, wird beim Start verschoben)
    QString blobsSrc = quelle + "/wiki_blobs";
    if (QDir(blobsSrc).exists())
        kopierVerzeichnis(blobsSrc, pendingDir + "/wiki_blobs");

    // 2. Wiki-JSON sofort mergen (Artikel bleiben ohne Neustart zugänglich)
    bool wikiJsonOk = false;
    QString wikiJsonPfad = quelle + QStringLiteral("/wiki_export.json");
    if (QFile::exists(wikiJsonPfad))
        wikiJsonOk = wikiImportJson(wikiJsonPfad, true);

    // 3. Projektdateien nach dataDir/importierte_projekte/ kopieren
    int projekteAnzahl = 0;
    QJsonArray projekteListe = root.value(QStringLiteral("projekte")).toArray();
    QString projSrcOrdner   = quelle + QStringLiteral("/projekte");
    QString projZielOrdner  = dataDir + QStringLiteral("/importierte_projekte");
    QDir().mkpath(projZielOrdner);

    for (const QJsonValue &v : projekteListe) {
        QJsonObject pj    = v.toObject();
        QString dateiName = pj.value(QStringLiteral("datei")).toString();
        QString name      = pj.value(QStringLiteral("name")).toString();
        QString srcPfad   = projSrcOrdner + "/" + dateiName;

        if (!QFile::exists(srcPfad)) {
            qWarning() << "komplettarchivImportieren: Projektdatei fehlt:" << srcPfad;
            continue;
        }

        // Zieldatei bestimmen, Konflikt auflösen
        QString zielPfad = projZielOrdner + "/" + dateiName;
        if (QFile::exists(zielPfad)) {
            QString stem = QFileInfo(dateiName).baseName();
            zielPfad = projZielOrdner + "/" + stem
                       + "_importiert_" + QString::number(projekteAnzahl + 1) + ".strl";
        }
        if (!QFile::copy(srcPfad, zielPfad)) continue;

        QSqlQuery q(m_launcherDb);
        q.prepare(R"(
            INSERT INTO zuletzt_geoeffnet (pfad, name, geoeffnet_am)
            VALUES (:p, :n, datetime('now'))
            ON CONFLICT(pfad) DO UPDATE SET name=excluded.name, geoeffnet_am=excluded.geoeffnet_am
        )");
        q.bindValue(":p", zielPfad);
        q.bindValue(":n", name);
        if (q.exec()) projekteAnzahl++;
    }

    QString meldung = QString("%1 Projekt(e) importiert").arg(projekteAnzahl);
    if (makroDbGeplant || wikiDbGeplant)
        meldung += QStringLiteral(" · Makros/Wiki werden beim nächsten Start wiederhergestellt");

    qInfo() << "komplettarchivImportieren:" << projekteAnzahl << "Projekt(e)"
            << "makroPending=" << makroDbGeplant << "wikiPending=" << wikiDbGeplant;
    return {
        {QStringLiteral("erfolg"),          true},
        {QStringLiteral("projekteAnzahl"),  projekteAnzahl},
        {QStringLiteral("makroDbGeplant"),  makroDbGeplant},
        {QStringLiteral("wikiDbGeplant"),   wikiDbGeplant},
        {QStringLiteral("wikiJsonOk"),      wikiJsonOk},
        {QStringLiteral("neustartNoetig"),  makroDbGeplant || wikiDbGeplant},
        {QStringLiteral("meldung"),         meldung}
    };
}

// ============================================================
// CSV-Import Bauteilkatalog (M7)
// ============================================================

static QList<QStringList> parseCsvRows(const QString &pfad, QChar &trenn)
{
    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    f.close();

    QStringList lines = content.split('\n');
    if (lines.isEmpty()) return {};

    // Trennzeichen aus erster Zeile ermitteln
    QString first = lines.first();
    trenn = (first.count(';') >= first.count(',')) ? ';' : ',';

    QList<QStringList> result;
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;

        QStringList row;
        bool inQuotes = false;
        QString field;
        for (int i = 0; i < line.length(); i++) {
            QChar c = line[i];
            if (c == '"') {
                if (inQuotes && i + 1 < line.length() && line[i + 1] == '"') {
                    field += '"'; ++i;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c == trenn && !inQuotes) {
                row.append(field.trimmed());
                field.clear();
            } else {
                field += c;
            }
        }
        row.append(field.trimmed());
        result.append(row);
    }
    return result;
}

QStringList Database::csvKopfzeile(const QString &pfad)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    return rows.isEmpty() ? QStringList() : rows.first();
}

QVariantList Database::csvVorschau(const QString &pfad, int maxZeilen)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    QVariantList result;
    for (int i = 1; i < rows.size() && result.size() < maxZeilen; i++) {
        QVariantList row;
        for (const QString &s : rows[i]) row.append(s);
        result.append(QVariant(row));
    }
    return result;
}

int Database::csvBauteileImportieren(const QString &pfad, int kategorieId,
                                      const QVariantMap &mapping)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    if (rows.size() < 2) return 0;

    static const QStringList numericFelder = {
        "preis_eur", "spannung_v", "strom_a", "leistung_w"
    };
    static const QStringList erlaubteFelder = {
        "bezeichnung", "hersteller", "artikelnummer", "artikelnummer_2",
        "lieferant", "bestellnummer", "preis_eur", "spannung_v",
        "strom_a", "leistung_w", "schutzart", "norm", "bmk_vorlage", "bemerkung"
    };

    QStringList dbFelder;
    QStringList bindVars;
    QList<int>  colIndizes;
    for (auto it = mapping.begin(); it != mapping.end(); ++it) {
        const QString &feld = it.key();
        int colIdx = it.value().toInt();
        if (colIdx < 0 || !erlaubteFelder.contains(feld)) continue;
        dbFelder   << feld;
        bindVars   << (":" + feld);
        colIndizes << colIdx;
    }
    if (!dbFelder.contains("bezeichnung")) return -1;

    QString sql = QString("INSERT INTO bauteil (kategorie_id, %1) VALUES (:katId, %2)")
                      .arg(dbFelder.join(", "), bindVars.join(", "));

    if (!m_db.transaction()) {
        qWarning() << "csvBauteileImportieren: transaction fehlgeschlagen";
        return 0;
    }
    QSqlQuery q(m_db);
    int count = 0;
    for (int row = 1; row < rows.size(); row++) {
        const QStringList &cols = rows[row];
        q.prepare(sql);
        q.bindValue(":katId", kategorieId > 0 ? QVariant(kategorieId) : QVariant());
        for (int f = 0; f < dbFelder.size(); f++) {
            int     ci  = colIndizes[f];
            QString val = (ci < cols.size()) ? cols[ci] : QString();
            if (numericFelder.contains(dbFelder[f])) {
                bool ok;
                double d = QString(val).replace(',', '.').toDouble(&ok);
                q.bindValue(":" + dbFelder[f], (ok && !val.isEmpty()) ? QVariant(d) : QVariant());
            } else {
                q.bindValue(":" + dbFelder[f], val.isEmpty() ? QVariant() : QVariant(val));
            }
        }
        if (q.exec()) ++count;
        else qWarning() << "csvBauteileImportieren Zeile" << row << ":" << q.lastError().text();
    }
    m_db.commit();
    return count;
}

