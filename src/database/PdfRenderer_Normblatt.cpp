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


// Normblatt-Rahmen und Schriftfeld rendern (Koordinaten in Device-Pixeln via pxPerMm)
void pdfNormblattRendern(QPainter &p, const QVariantMap &nb, double pxPerMm)
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
void pdfInfostreifenRendern(QPainter &p, const QVariantMap &nb,
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
                  : blatt + QStringLiteral(" – ") + bez;
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
void pdfRevisionswasserzeichenRendern(QPainter &p, const QVariantMap &nb,
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

PdfBBox pdfBoundingBox(int seiteId, double normBMm, double normHMm,
                               const QSqlDatabase &db)
{
    const double randCu = 60.0; // 15 mm Rand
    double bxMin =  1e9, byMin =  1e9;
    double bxMax = -1e9, byMax = -1e9;

    QSqlQuery bq(db);
    bq.prepare(R"(
        SELECT CASE WHEN x1<x2 THEN x1 ELSE x2 END,
               CASE WHEN y1<y2 THEN y1 ELSE y2 END,
               CASE WHEN x1>x2 THEN x1 ELSE x2 END,
               CASE WHEN y1>y2 THEN y1 ELSE y2 END,
               extra_daten
        FROM grafik_element WHERE seite_id = :sid
    )");
    bq.bindValue(":sid", seiteId);
    if (bq.exec()) {
        while (bq.next()) {
            double ex1 = bq.value(0).toDouble(), ey1 = bq.value(1).toDouble();
            double ex2 = bq.value(2).toDouble(), ey2 = bq.value(3).toDouble();
            bxMin = qMin(bxMin, ex1); byMin = qMin(byMin, ey1);
            bxMax = qMax(bxMax, ex2); byMax = qMax(byMax, ey2);

            // PDF-RAND-BMK-01: manuell verschobene BMK-/Freitext-Labels
            // (bmkOffsetX/Y in mm, s. LABEL-DRAG-BMKSEITE-01/-02) können weit
            // außerhalb von x1..x2/y1..y2 liegen - ohne Berücksichtigung hier
            // schneidet der vollCanvas-Export weit verschobene Labels ab.
            // Bewusst grobe, großzügige Schätzung statt exakter Textmetrik
            // (ob der Offset horizontal oder vertikal wirkt, hängt von
            // Rotation/bmk_seite ab, hier nicht ohne Weiteres bekannt) -
            // Offset-Betrag plus Textausdehnungs-Puffer auf allen vier
            // Seiten gleich einrechnen statt die Richtung zu erraten.
            QString exStr = bq.value(4).toString();
            if (!exStr.isEmpty()) {
                QJsonDocument exDoc = QJsonDocument::fromJson(exStr.toUtf8());
                if (exDoc.isObject()) {
                    QJsonObject exObj = exDoc.object();
                    if (exObj.contains(QStringLiteral("bmkOffsetX")) || exObj.contains(QStringLiteral("bmkOffsetY"))) {
                        double offXCu = qAbs(exObj.value(QStringLiteral("bmkOffsetX")).toDouble()) * 4.0;
                        double offYCu = qAbs(exObj.value(QStringLiteral("bmkOffsetY")).toDouble()) * 4.0;
                        const double textPufferCu = 120.0; // ~30 mm Textausdehnung
                        double reichweite = offXCu + offYCu + textPufferCu;
                        bxMin = qMin(bxMin, ex1 - reichweite); byMin = qMin(byMin, ey1 - reichweite);
                        bxMax = qMax(bxMax, ex2 + reichweite); byMax = qMax(byMax, ey2 + reichweite);
                    }
                }
            }
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
