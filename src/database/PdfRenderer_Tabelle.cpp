// ============================================================
// PdfRenderer_Tabelle.cpp – generische Tabelle (Titel, Untertitel,
// Kopfzeile, Zeilen) mit Seitenumbruch in einen QPdfWriter.
// Gemeinsamer Weg für Listen-PDFs (listePdfSpeichern) und die
// Abschnitte des Dokumentations-PDFs (DOKU-PDF-02, SPS/PLS-I/O-Liste).
// ============================================================
#include "PdfRenderer.h"

#include <QAbstractTextDocumentLayout>
#include <QColor>
#include <QFont>
#include <QObject>
#include <QPageLayout>
#include <QPageSize>
#include <QPdfWriter>
#include <QTextDocument>
#include <QVariantList>

QPageLayout pdfTabellenSeitenLayout()
{
    return QPageLayout(QPageSize(QPageSize::A4), QPageLayout::Landscape,
                       QMarginsF(12, 12, 12, 12), QPageLayout::Millimeter);
}

static QString htmlEsc(const QString &s)
{
    QString r = s;
    r.replace(u'&', QLatin1String("&amp;"));
    r.replace(u'<', QLatin1String("&lt;"));
    r.replace(u'>', QLatin1String("&gt;"));
    return r;
}

static QString pdfTabelleHtml(const QString &titel, const QString &untertitel,
                              const QStringList &spalten, const QVariantList &zeilen)
{
    QString html;
    html.reserve(32 * 1024);
    html += QStringLiteral(R"(<!DOCTYPE html><html><head><meta charset="utf-8">
<style>
  body  { font-family: Arial, Helvetica, sans-serif; font-size: 8.5pt; color: #222; margin: 0; }
  h1    { font-size: 13pt; color: #1a3560; margin: 0 0 2px 0; }
  .subtitle { font-size: 9pt; color: #555; margin-bottom: 10px; }
  table { width: 100%; border-collapse: collapse; }
  th    { text-align: left; background: #eef2f7; padding: 4px 6px; font-size: 8pt;
          color: #1a3560; border-bottom: 1px solid #1a3560; }
  td    { padding: 3px 6px; font-size: 8.5pt; border-bottom: 1px solid #e0e0e0; }
  tr:nth-child(even) td { background: #f7f7f7; }
</style></head><body>)");

    html += QStringLiteral("<h1>") + htmlEsc(titel) + QStringLiteral("</h1>");
    if (!untertitel.isEmpty())
        html += QStringLiteral("<div class='subtitle'>") + htmlEsc(untertitel) + QStringLiteral("</div>");

    html += QStringLiteral("<table width=\"100%\"><thead><tr>");
    for (const QString &s : spalten)
        html += QStringLiteral("<th>") + htmlEsc(s) + QStringLiteral("</th>");
    html += QStringLiteral("</tr></thead><tbody>");

    for (const QVariant &zv : zeilen) {
        const QVariantList zeile = zv.toList();
        html += QStringLiteral("<tr>");
        for (const QVariant &cv : zeile)
            html += QStringLiteral("<td>") + htmlEsc(cv.toString()) + QStringLiteral("</td>");
        html += QStringLiteral("</tr>");
    }
    html += QStringLiteral("</tbody></table></body></html>");
    return html;
}

// Logik wie QTextDocument::print(): Layout auf das Gerät des Painters, Seitengröße = beschreibbarer
// Bereich in Geräte-Pixeln, je Seite ein verschobener Ausschnitt. Unten bleibt eine Fußzeile frei
// ("Seite x von y", rechtsbündig) - dieselbe Rolle wie die Seitenzahl, die QTextDocument::print() zeichnet.
int pdfTabelleRendern(QPainter &p, QPdfWriter &w, const QString &titel, const QString &untertitel,
                      const QStringList &spalten, const QVariantList &zeilen, bool ersteSeiteNeu,
                      int seitenNrStart, int seitenGesamt)
{
    if (ersteSeiteNeu) {
        w.setPageLayout(pdfTabellenSeitenLayout());
        w.newPage();
    }

    const double pxProMm = w.logicalDpiY() / 25.4;
    const double fussH   = 8.0 * pxProMm;                 // Platz für die Fußzeile

    QTextDocument doc;
    doc.setHtml(pdfTabelleHtml(titel, untertitel, spalten, zeilen));
    doc.documentLayout()->setPaintDevice(&w);
    const double breite = w.width();
    const double hoehe  = w.height() - fussH;
    doc.setPageSize(QSizeF(breite, hoehe));

    const int seiten = qMax(1, doc.pageCount());
    const int gesamt = seitenGesamt > 0 ? seitenGesamt : seitenNrStart - 1 + seiten;
    QFont fussFont(QStringLiteral("Arial"));
    fussFont.setPointSizeF(8.0);
    for (int s = 0; s < seiten; ++s) {
        if (s > 0) w.newPage();
        const QRectF ausschnitt(0, s * hoehe, breite, hoehe);
        p.save();
        p.translate(0, -s * hoehe);
        p.setClipRect(ausschnitt);
        QAbstractTextDocumentLayout::PaintContext ctx;
        ctx.clip = ausschnitt;
        doc.documentLayout()->draw(&p, ctx);
        p.restore();

        p.save();
        p.setFont(fussFont);
        p.setPen(QColor(0x55, 0x55, 0x55));
        p.drawText(QRectF(0, w.height() - fussH, breite, fussH), Qt::AlignRight | Qt::AlignVCenter,
                   QObject::tr("Seite %1 von %2").arg(seitenNrStart + s).arg(gesamt));
        p.restore();
    }
    return seiten;
}
