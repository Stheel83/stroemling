// ============================================================
// PdfRenderer_Deckblatt.cpp – Deckblatt und Inhaltsverzeichnis des
// Dokumentations-PDFs (DOKU-PDF-03). Zeichnet direkt mit QPainter in mm,
// A4 hoch mit 15 mm Rand (pdfHochSeitenLayout()).
// ============================================================
#include "PdfRenderer.h"

#include <QDate>
#include <QFont>
#include <QFontMetricsF>
#include <QObject>
#include <QPageSize>
#include <QPdfWriter>
#include <QPen>

QPageLayout pdfHochSeitenLayout()
{
    return QPageLayout(QPageSize(QPageSize::A4), QPageLayout::Portrait,
                       QMarginsF(15, 15, 15, 15), QPageLayout::Millimeter);
}

namespace {
constexpr double kFussMm        = 8.0;    // Fußzeile unten
constexpr double kTocKopfMm     = 16.0;   // Titel + Abstand
constexpr double kTocZeileMm    = 6.0;
constexpr double kSeiteHoeheMm  = 297.0 - 2 * 15.0;   // beschreibbare Höhe von pdfHochSeitenLayout()
const QColor kAkzent(0x1a, 0x35, 0x60);

QFont arial(double pt, bool fett = false, bool kursiv = false)
{
    QFont f(QStringLiteral("Arial"));
    f.setPointSizeF(pt);
    f.setBold(fett);
    f.setItalic(kursiv);
    return f;
}
}

int pdfTocZeilenProSeite()
{
    return int((kSeiteHoeheMm - kFussMm - kTocKopfMm) / kTocZeileMm);
}

void pdfFusszeileZeichnen(QPainter &p, QPdfWriter &w, double fussHoehePx, int seite, int gesamt)
{
    p.save();
    p.setFont(arial(8.0));
    p.setPen(QColor(0x55, 0x55, 0x55));
    p.drawText(QRectF(0, w.height() - fussHoehePx, w.width(), fussHoehePx),
               Qt::AlignRight | Qt::AlignVCenter,
               QObject::tr("Seite %1 von %2").arg(seite).arg(gesamt));
    p.restore();
}

void pdfDeckblattRendern(QPainter &p, QPdfWriter &w, const PdfDeckblattDaten &d, bool ersteSeiteNeu)
{
    if (ersteSeiteNeu) {
        w.setPageLayout(pdfHochSeitenLayout());
        w.newPage();
    }
    const double mm = w.logicalDpiY() / 25.4;
    const double breite = w.width();

    p.save();

    // Logo oben rechts, höchstens 55 x 28 mm
    if (!d.logo.isNull()) {
        const QSizeF max(55 * mm, 28 * mm);
        QSizeF s = QSizeF(d.logo.size()).scaled(max, Qt::KeepAspectRatio);
        p.drawImage(QRectF(breite - s.width(), 0, s.width(), s.height()), d.logo);
    }

    // Titelblock
    p.setPen(QColor(0x55, 0x55, 0x55));
    p.setFont(arial(13.0));
    p.drawText(QRectF(0, 70 * mm, breite, 8 * mm), Qt::AlignLeft | Qt::AlignVCenter,
               QObject::tr("Dokumentation"));

    p.setPen(kAkzent);
    p.setFont(arial(30.0, true));
    const QRectF nameBox(0, 80 * mm, breite, 40 * mm);
    QRectF nameBR;
    p.drawText(nameBox, Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap, d.projektName, &nameBR);

    double y = nameBR.bottom() + 4 * mm;
    if (!d.titelzusatz.trimmed().isEmpty()) {
        p.setFont(arial(15.0));
        QRectF zBR;
        p.drawText(QRectF(0, y, breite, 30 * mm), Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap,
                   d.titelzusatz, &zBR);
        y = zBR.bottom() + 4 * mm;
    }

    QPen linie(kAkzent);
    linie.setWidthF(0.6 * mm);
    p.setPen(linie);
    p.drawLine(QPointF(0, y + 2 * mm), QPointF(breite, y + 2 * mm));

    // Felder (leere weglassen)
    double fy = qMax(y + 14 * mm, 150.0 * mm);
    const double labelBreite = 48 * mm;
    for (const auto &f : d.felder) {
        if (f.second.trimmed().isEmpty()) continue;
        p.setPen(QColor(0x66, 0x66, 0x66));
        p.setFont(arial(10.0));
        p.drawText(QRectF(0, fy, labelBreite, 7 * mm), Qt::AlignLeft | Qt::AlignTop, f.first);
        p.setPen(QColor(0x22, 0x22, 0x22));
        p.setFont(arial(11.0));
        QRectF vBR;
        p.drawText(QRectF(labelBreite, fy, breite - labelBreite, 20 * mm),
                   Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap, f.second, &vBR);
        fy += qMax(7.0 * mm, vBR.height() + 1.5 * mm);
    }

    // Fuß
    p.setPen(QColor(0x88, 0x88, 0x88));
    p.setFont(arial(8.0));
    p.drawText(QRectF(0, w.height() - 8 * mm, breite, 8 * mm), Qt::AlignLeft | Qt::AlignVCenter,
               QObject::tr("Stand: %1  ·  erstellt mit Strömling Design").arg(d.stand));
    p.restore();
}

int pdfInhaltsverzeichnisRendern(QPainter &p, QPdfWriter &w, const QList<PdfTocEintrag> &eintraege,
                                 bool ersteSeiteNeu, int seitenNrStart, int seitenGesamt)
{
    if (ersteSeiteNeu) {
        w.setPageLayout(pdfHochSeitenLayout());
        w.newPage();
    }
    const double mm = w.logicalDpiY() / 25.4;
    const double breite = w.width();
    const int proSeite = pdfTocZeilenProSeite();
    const int seiten = qMax(1, (int(eintraege.size()) + proSeite - 1) / proSeite);
    const int gesamt = seitenGesamt > 0 ? seitenGesamt : seitenNrStart - 1 + seiten;

    for (int s = 0; s < seiten; ++s) {
        if (s > 0) w.newPage();
        p.save();

        p.setPen(kAkzent);
        p.setFont(arial(16.0, true));
        p.drawText(QRectF(0, 0, breite, 10 * mm), Qt::AlignLeft | Qt::AlignVCenter,
                   s == 0 ? QObject::tr("Inhaltsverzeichnis") : QObject::tr("Inhaltsverzeichnis (Fortsetzung)"));
        QPen linie(kAkzent);
        linie.setWidthF(0.35 * mm);
        p.setPen(linie);
        p.drawLine(QPointF(0, 11 * mm), QPointF(breite, 11 * mm));

        double y = kTocKopfMm * mm;
        const int von = s * proSeite;
        const int bis = qMin(int(eintraege.size()), von + proSeite);
        for (int i = von; i < bis; ++i, y += kTocZeileMm * mm) {
            const PdfTocEintrag &e = eintraege[i];
            const double einzug = (e.ebene == 0 ? 0.0 : e.ebene == 1 ? 4.0 : 9.0) * mm;
            const QFont f = e.ebene == 0 ? arial(10.5, true)
                          : e.ebene == 1 ? arial(9.0, false, true)
                                         : arial(9.5);
            p.setFont(f);
            p.setPen(e.ebene == 1 ? QColor(0x66, 0x66, 0x66) : QColor(0x22, 0x22, 0x22));

            const QString nr = e.seite > 0 ? QString::number(e.seite) : QString();
            const QFontMetricsF fm(f, p.device());
            const double nrBreite = nr.isEmpty() ? 0.0 : fm.horizontalAdvance(nr) + 2 * mm;
            const QString text = fm.elidedText(e.text, Qt::ElideRight, breite - einzug - nrBreite - 3 * mm);
            const QRectF zeile(0, y, breite, kTocZeileMm * mm);

            p.drawText(zeile.adjusted(einzug, 0, 0, 0), Qt::AlignLeft | Qt::AlignVCenter, text);
            if (!nr.isEmpty()) {
                p.drawText(zeile, Qt::AlignRight | Qt::AlignVCenter, nr);
                // Führungspunkte zwischen Text und Seitenzahl
                const double x0 = einzug + fm.horizontalAdvance(text) + 2 * mm;
                const double x1 = breite - nrBreite;
                if (x1 > x0 + 2 * mm) {
                    QPen punkte(QColor(0x99, 0x99, 0x99));
                    punkte.setStyle(Qt::DotLine);
                    punkte.setWidthF(0.2 * mm);
                    p.setPen(punkte);
                    const double yl = y + kTocZeileMm * mm * 0.72;
                    p.drawLine(QPointF(x0, yl), QPointF(x1, yl));
                }
            }
        }
        p.restore();
        pdfFusszeileZeichnen(p, w, kFussMm * mm, seitenNrStart + s, gesamt);
    }
    return seiten;
}
