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

// pdfElementRendern() Typ-Handler (REFACTOR-CPP-02: aus pdfElementRendern() extrahiert)
static void pdfElementLinieRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawLine(QLineF(x1, y1, x2, y2));
}

static void pdfElementPolygonlinieRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

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
}

static void pdfElementRechteckRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        p.setPen(pen);
        double er = el.value("eckenRadius", 0.0).toDouble() * pxPerMm;
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
}

static void pdfElementKreisRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

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
}

static void pdfElementTextRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        QString inhalt = el.value("textInhalt").toString();
        if (inhalt.isEmpty()) return;
        QVariantMap edTxt = el.value("extraDaten").toMap();
        double fsMm = edTxt.value("schriftgroesse", 3.5).toDouble();
        double fsDev = fsMm * pxPerMm;
        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fsDev)));
        font.setBold(true);
        p.setFont(font);
        QColor txtFarbe = pdfFarbe(el.value("strichFarbe").toString(), QColor(192,216,240));
        txtFarbe.setAlphaF(txtFarbe.alphaF() * el.value("opazitaet", 1.0).toDouble());
        p.setPen(txtFarbe);
        p.setBrush(Qt::NoBrush);

        QString ausrichtung = el.value("textAusrichtung", "links").toString();

        // 1:1-Port von normTextRot() in CanvasRenderHandler.qml: erst auf [0,360)
        // normalisieren (Mehrfachauswahl-Drehung kann auch 180/270 liefern), dann
        // auf 0°/90° einschränken - Text darf nie kopfstehen.
        int rawRot  = el.value("rotation", 0).toInt();
        int normRot = ((rawRot % 360) + 360) % 360;
        p.save();
        p.translate(x1, y1);
        if (normRot == 90 || normRot == 270) p.rotate(-90);
        QStringList lines = inhalt.split('\n');
        double lineH = fsDev * 1.3;
        // TEXT-WERKZEUG-PDF-BREITE-01: Das Text-Werkzeug bricht bewusst NICHT
        // automatisch um (EP-Editor: TextEdit.NoWrap, Canvas: ctx.fillText() ohne
        // maxWidth - 1:1-Port von CanvasRenderHandler.qml::_renderText()) - jede
        // Zeile wird einzeln um den Ankerpunkt x=0 aus-/eingerückt, je nach
        // Ausrichtung. Die alte feste Box (qMax(sw,200)) war oft schmaler als der
        // tatsächliche Text und schnitt lange Zeilen am rechten Rand ab. Fix:
        // Breite pro Zeile per QFontMetrics messen statt raten, Box exakt um den
        // Ankerpunkt positionieren (mitte/rechts wie im Canvas je Zeile einzeln,
        // nicht um eine gemeinsame Blockbreite).
        QFontMetricsF fm(font);
        for (int i = 0; i < lines.size(); i++) {
            double lineW = fm.horizontalAdvance(lines[i]) + 4.0;
            double lx = 0.0;
            if      (ausrichtung == "mitte")  lx = -lineW / 2.0;
            else if (ausrichtung == "rechts") lx = -lineW;
            p.drawText(QRectF(lx, i * lineH, lineW, fsDev * 1.5),
                       Qt::AlignLeft | Qt::AlignTop, lines[i]);
        }
        p.restore();
}

static void pdfElementBildRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        QVariant bildVar = el.value("bildDaten");
        if (!bildVar.isValid()) return;
        QString dataUrl = bildVar.toString();
        // data:image/xxx;base64,... → decode
        int commaPos = dataUrl.indexOf(',');
        if (commaPos < 0) return;
        QByteArray bytes = QByteArray::fromBase64(dataUrl.mid(commaPos + 1).toLatin1());
        QImage img;
        if (!img.loadFromData(bytes)) return;

        double bw = qAbs(sw), bh = qAbs(sh);
        if (bw < 1 || bh < 1) return;
        double bcx = qMin(x1,x2) + bw / 2.0, bcy = qMin(y1,y2) + bh / 2.0;

        // 1:1-Port von CanvasRenderHandler.qml _renderBild: Rotation um den
        // Mittelpunkt, Spiegelung per Skalierung, Ausschnitt als Clip auf das
        // volle (auf bw×bh gestreckte) Bild - nicht als Zuschnitt der Quellpixel.
        p.save();
        p.setOpacity(el.value("opazitaet", 1.0).toDouble());
        p.translate(bcx, bcy);
        p.rotate(el.value("rotation", 0.0).toDouble());
        p.scale(el.value("spiegelX").toBool() ? -1.0 : 1.0,
                el.value("spiegelY").toBool() ? -1.0 : 1.0);

        double aL = el.value("ausschnittLinks",  0.0).toDouble();
        double aR = el.value("ausschnittRechts", 0.0).toDouble();
        double aO = el.value("ausschnittOben",   0.0).toDouble();
        double aU = el.value("ausschnittUnten",  0.0).toDouble();
        double cw = bw * (1.0 - aL - aR), ch = bh * (1.0 - aO - aU);
        if (cw > 0 && ch > 0) {
            p.setClipRect(QRectF(-bw/2 + aL * bw, -bh/2 + aO * bh, cw, ch));
            p.drawImage(QRectF(-bw/2, -bh/2, bw, bh), img);
        }
        p.restore();
}

static void pdfElementNotizRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

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
        QColor borderFarbe = pdfFarbe(el.value("strichFarbe").toString(), QColor(204,204,34));
        borderFarbe.setAlphaF(borderFarbe.alphaF() * el.value("opazitaet", 1.0).toDouble());
        borderPen.setColor(borderFarbe);
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
        QColor notizTxtFarbe = pdfFarbe(el.value("strichFarbe").toString(), QColor(204,204,34));
        notizTxtFarbe.setAlphaF(notizTxtFarbe.alphaF() * el.value("opazitaet", 1.0).toDouble());
        p.setPen(notizTxtFarbe);
        double pad = qMax(4.0, fsDev * 0.35);
        p.drawText(QRectF(rx + pad, ry + pad, rw - 2*pad, rh - 2*pad),
                   Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap, text);
}

static void pdfElementKabellinieRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

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
}

static void pdfElementGeraetekastenRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

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
            // BEZEICHNUNG-SHIFT-ENTER-PDF-01/-WRAP-01: descr kann eingebettete \n
            // enthalten (BEZEICHNUNG-SHIFT-ENTER-01) und einzelne Zeilen können
            // breiter als der Kasten sein (im Canvas-EP bricht TextEdit.WordWrap
            // das optisch um, das ist aber kein echtes \n im gespeicherten Text).
            // drawText() bricht ohne Qt::TextWordWrap nicht um und schneidet zu
            // breite Zeilen am rechten Rand der Box ab. Höhe pro Absatz wird per
            // boundingRect() gemessen statt geraten (fester Faktor reicht nicht,
            // sobald ein Absatz mehrzeilig umbricht).
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev2)));
            p.setFont(f); p.setPen(pen.color());
            double descrBoxW = rw - 2*pad;
            const QStringList descrLines = descr.split('\n');
            for (const QString &descrLine : descrLines) {
                QRectF descrMeasure(rx+pad, ty, descrBoxW, 10000.0);
                QRectF descrBound = p.boundingRect(descrMeasure, Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop, descrLine);
                double descrLineH = qMax(descrBound.height(), fsDev2 * 1.4);
                p.drawText(QRectF(rx+pad, ty, descrBoxW, descrLineH),
                           Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop, descrLine);
                ty += descrLineH;
            }
        }
}

static void pdfElementStrukturkastenRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        double skEr = el.value("eckenRadius", 0.0).toDouble() * pxPerMm;
        QPen skPen = pen;
        skPen.setStyle(Qt::DashLine);
        p.setPen(skPen);
        if (el.value("fuell").toBool()) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString());
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        if (skEr > 0.5) p.drawRoundedRect(QRectF(rx, ry, rw, rh), skEr, skEr);
        else            p.drawRect(QRectF(rx, ry, rw, rh));
        p.setBrush(Qt::NoBrush);
        // Text-Layout 1:1 nach CanvasRenderHandler.qml::_renderStrukturkasten()
        // gespiegelt: linksbündig, Anlage/Ort-Label (fett) über der
        // Bezeichnung (kleiner, 0.85×) gestapelt, beide per bmkOffsetX/Y
        // verschiebbar. Vorher stand das Label hier rechtsbündig ohne
        // bmkOffset-Unterstützung - wich vom Canvas-Bild ab (GK-SK-ORT-KEY-01
        // Nachtrag).
        QVariantMap ed  = el.value("extraDaten").toMap();
        double schrift  = ed.value("schriftgroesse", 2.5).toDouble();
        double fsDev    = schrift * pxPerMm;
        double fsDevB   = schrift * 0.85 * pxPerMm;
        double pad      = 5.0 * 0.25 * pxPerMm;
        double skOx     = ed.value("bmkOffsetX", 0.0).toDouble() * C;
        double skOy     = ed.value("bmkOffsetY", 0.0).toDouble() * C;
        double textX    = rx + pad + skOx;
        double textY    = ry + pad + skOy;
        double textW    = rw - 2*pad;

        QString lbl;
        if (!ed.value("skAnlageUO").toString().isEmpty()) lbl += "==" + ed.value("skAnlageUO").toString() + " ";
        if (!ed.value("skOrtUO").toString().isEmpty())    lbl += "++" + ed.value("skOrtUO").toString() + " ";
        if (!ed.value("skAnlage").toString().isEmpty())   lbl += "="  + ed.value("skAnlage").toString() + " ";
        if (!ed.value("skOrt").toString().isEmpty())      lbl += "+"  + ed.value("skOrt").toString();
        lbl = lbl.trimmed();
        if (!lbl.isEmpty()) {
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1, qRound(fsDev))); f.setBold(true);
            p.setFont(f); p.setPen(pen.color());
            QStringList lblLines = lbl.split('\n');
            for (const QString &lblLine : lblLines) {
                p.drawText(QRectF(textX, textY, textW, fsDev*1.4),
                           Qt::AlignLeft | Qt::AlignTop, lblLine);
                textY += fsDev * 1.3;
            }
        }
        QString bez = ed.value("bezeichnung").toString();
        if (!bez.isEmpty()) {
            // BEZEICHNUNG-SHIFT-ENTER-WRAP-01: dieselbe Wortumbruch-Korrektur wie
            // bei pdfElementGeraetekastenRendern() oben - ohne Qt::TextWordWrap
            // schneidet drawText() zu breite Zeilen am rechten Rand ab, Höhe pro
            // Absatz wird per boundingRect() gemessen statt geraten.
            QFont fb; fb.setFamily("sans-serif"); fb.setPixelSize(qMax(1, qRound(fsDevB)));
            p.setFont(fb); p.setPen(pen.color());
            QStringList bezLines = bez.split('\n');
            for (const QString &bezLine : bezLines) {
                QRectF bezMeasure(textX, textY, textW, 10000.0);
                QRectF bezBound = p.boundingRect(bezMeasure, Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop, bezLine);
                double bezLineH = qMax(bezBound.height(), fsDevB * 1.4);
                p.drawText(QRectF(textX, textY, textW, bezLineH),
                           Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop, bezLine);
                textY += bezLineH;
            }
        }
}

static void pdfElementMakrokastenRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        double mkEr = el.value("eckenRadius", 0.0).toDouble() * pxPerMm;
        QPen mkPen = pen;
        mkPen.setStyle(Qt::DotLine);
        mkPen.setColor(QColor(0xa0, 0x60, 0xc0));
        p.setPen(mkPen);
        if (el.value("fuell").toBool()) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString());
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        if (mkEr > 0.5) p.drawRoundedRect(QRectF(rx, ry, rw, rh), mkEr, mkEr);
        else            p.drawRect(QRectF(rx, ry, rw, rh));
        p.setBrush(Qt::NoBrush);

        QVariantMap ed = el.value("extraDaten").toMap();
        QString name = ed.value("name").toString();
        if (name.isEmpty()) name = QStringLiteral("Makro");
        bool saved  = ed.value("makroId", 0).toInt() > 0;
        double fsMm  = 2.2;
        double fsDev = fsMm * pxPerMm;
        double off   = 4.0 * 0.25 * pxPerMm;
        double mkOx  = ed.value("bmkOffsetX", 0.0).toDouble() * C;
        double mkOy  = ed.value("bmkOffsetY", 0.0).toDouble() * C;
        QFont mf; mf.setFamily("sans-serif"); mf.setPixelSize(qMax(1, qRound(fsDev)));
        p.setFont(mf); p.setPen(mkPen.color());
        QString prefix = saved ? QStringLiteral("✓ ") : QStringLiteral("⬜ ");
        QStringList lines = name.split('\n');
        double centerX = rx + rw/2.0 + mkOx;
        double ty = ry + off + mkOy;
        for (int li = 0; li < lines.size(); ++li) {
            QString line = (li == 0 ? prefix : QStringLiteral("  ")) + lines.at(li);
            p.drawText(QRectF(centerX - rw*1.5, ty, rw*3.0, fsDev*1.4),
                       Qt::AlignHCenter | Qt::AlignTop, line);
            ty += fsDev * 1.3;
        }
}

static void pdfElementSchirmRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        if (rw < 2 || rh < 2) return;
        // Kapsel-/Stadium-Form (analog CanvasRenderHandler.qml stadiumPfad()):
        // volle Rundung mit Radius = halbe kleinere Kantenlänge ergibt exakt
        // dieselbe Form wie die dortigen zwei Halbkreise + Geraden.
        double r = qMin(rw, rh) / 2.0;
        p.setPen(pen);
        if (el.value("fuell").toBool()) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString());
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        p.drawRoundedRect(QRectF(rx, ry, rw, rh), r, r, Qt::AbsoluteSize);
        p.setBrush(Qt::NoBrush);

        QVariantMap ed = el.value("extraDaten").toMap();
        QString seite  = ed.value("anschlussSeite", QStringLiteral("links")).toString();
        double cx = rx + rw/2.0, cy = ry + rh/2.0;
        double px = cx, py = cy;
        if      (seite == QLatin1String("links"))  px = rx;
        else if (seite == QLatin1String("rechts")) px = rx + rw;
        else if (seite == QLatin1String("oben"))   py = ry;
        else if (seite == QLatin1String("unten"))  py = ry + rh;

        // Anschlusspunkt
        double dotR = 4.0 * 0.25 * pxPerMm;
        p.setPen(Qt::NoPen);
        p.setBrush(pen.color());
        p.drawEllipse(QPointF(px, py), dotR, dotR);
        p.setBrush(Qt::NoBrush);

        QString bez = ed.value("bezeichnung").toString();
        if (!bez.isEmpty()) {
            double fsDev = 2.5 * pxPerMm;
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1, qRound(fsDev)));
            p.setFont(f); p.setPen(pen.color());
            p.drawText(QRectF(rx, cy - fsDev*0.7, rw, fsDev*1.4),
                       Qt::AlignHCenter | Qt::AlignVCenter, bez);
        }
}

// Einzelnes grafik_element rendern (Dispatcher, s. Typ-Handler oben)
void pdfElementRendern(QPainter &p, const QVariantMap &el,
                               double C, double pxPerMm, const QSqlDatabase &db,
                               const QVector<PdfLeitungsSegment> *leitungsSegs,
                               int seiteId,
                               const QHash<int, bool> *winkelUmkehrenMap)
{
    QString typ = el.value("typ").toString();
    if (typ == "linie") pdfElementLinieRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "polygonlinie") pdfElementPolygonlinieRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "rechteck") pdfElementRechteckRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "kreis") pdfElementKreisRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "text") pdfElementTextRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "bild") pdfElementBildRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "notiz") pdfElementNotizRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "kabellinie") pdfElementKabellinieRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "geraetekasten") pdfElementGeraetekastenRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "strukturkasten") pdfElementStrukturkastenRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "makrokasten") pdfElementMakrokastenRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "schirm") pdfElementSchirmRendern(p, el, C, pxPerMm, db, leitungsSegs);
    else if (typ == "symbol") pdfElementSymbolRendern(p, el, C, pxPerMm, db, leitungsSegs, seiteId, winkelUmkehrenMap);
}
