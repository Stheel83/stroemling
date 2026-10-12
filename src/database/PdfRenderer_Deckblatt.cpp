// ============================================================
// PdfRenderer_Deckblatt.cpp – Deckblatt und Inhaltsverzeichnis des
// Dokumentations-PDFs. Das Deckblatt kommt seit BLATTVORLAGEN-01b aus einer
// Blattvorlage (pdfNormblattRendern); das Inhaltsverzeichnis zeichnet direkt
// mit QPainter in mm, A4 hoch mit 15 mm Rand (pdfHochSeitenLayout()).
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

void pdfDeckblattRendern(QPainter &p, QPdfWriter &w, const QVariantMap &nb, bool ersteSeiteNeu)
{
    const double bMm = nb.value("breiteMm", 210.0).toDouble();
    const double hMm = nb.value("hoeheMm", 297.0).toDouble();
    if (ersteSeiteNeu) {
        w.setPageLayout(pdfDeckblattSeitenLayout(bMm, hMm));
        w.newPage();
    }
    const double pxPerMm = w.logicalDpiX() / 25.4;
    p.save();
    p.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);
    pdfNormblattRendern(p, nb, pxPerMm);
    p.restore();
}

QPageLayout pdfDeckblattSeitenLayout(double bMm, double hMm)
{
    return QPageLayout(QPageSize(QSizeF(bMm, hMm), QPageSize::Millimeter),
                       QPageLayout::Portrait, QMarginsF(0, 0, 0, 0));
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
