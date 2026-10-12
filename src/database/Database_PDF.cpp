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


// ── Öffentliche Methoden ─────────────────────────────────────

bool Database::dateiExistiert(const QString &pfad) const
{
    QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;
    return QFile::exists(localPath);
}

// ── Gemeinsamer Seiten-Renderer (DOKU-PDF-01) ───────────────
// Rendert Schaltplan-Seiten nacheinander in einen bereits geöffneten Writer.
// ersteSeiteNeu=false: die erste Seite nutzt das Layout, das der Writer beim
// Anlegen bekam (kein newPage()). ersteSeiteNeu=true: auch die erste Seite
// bekommt setPageLayout()+newPage() - nötig, wenn davor schon ein anderer
// Abschnitt (Deckblatt, Verzeichnis, ...) im selben Dokument steht.
// pxPerMm/C leiten sich aus dem Writer ab (konstant je Writer).
// Rückgabe: Anzahl gerenderter Seiten.
int Database::pdfSchaltplanSeitenRendern(QPainter &painter, QPdfWriter &writer,
                                          const QList<int> &seiteIds,
                                          bool mitNormblatt, bool vollCanvas, bool mitInfostreifen,
                                          bool ersteSeiteNeu)
{
    // DPI-basierte Skalierung: alle Zeichenaufrufe in Device-Pixeln
    const double pxPerMm = (double)writer.logicalDpiX() / 25.4;
    const double C       = pxPerMm / 4.0;   // Canvas-Pixel → Device-Pixel

    for (int i = 0; i < seiteIds.size(); ++i) {
        const int seiteId = seiteIds[i];
        QVariantMap nb = normblattDatenLaden(seiteId);
        double bMm = nb.value("breiteMm", 297.0).toDouble();
        double hMm = nb.value("hoeheMm",  210.0).toDouble();
        double txCu = 0.0, tyCu = 0.0;

        if (vollCanvas) {
            PdfBBox bb = pdfBoundingBox(seiteId, bMm, hMm, m_db);
            txCu = bb.txCu; tyCu = bb.tyCu;
            bMm  = bb.bMm;  hMm  = bb.hMm;
        }

        if (i > 0 || ersteSeiteNeu) {
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
        QVector<PdfKabelAderLabel> aderLabels;
        QHash<int, bool> winkelUmkehrenMap;
        QVector<PdfLeitungsSegment> leitungsSegs = pdfLeitungenSammeln(seiteId, pxPerMm, m_db, &aderLabels, &winkelUmkehrenMap);
        for (const QVariant &ev : elemente)
            pdfElementRendern(painter, ev.toMap(), C, pxPerMm, m_db, &leitungsSegs, seiteId, &winkelUmkehrenMap);
        pdfLeitungenRendern(painter, C, pxPerMm, leitungsSegs);
        pdfKabelAderBeschriftungRendern(painter, C, pxPerMm, aderLabels);
        painter.restore();  // Translate entfernt – ab hier absolute Seitenkoordinaten

        // Normblatt + Infostreifen in absoluten Koordinaten (kein Translate aktiv)
        // Infostreifen nur wenn das Normblatt auf dieser Seite tatsächlich NICHT
        // gezeichnet wird (auch im vollCanvas-Modus, wo es unabhängig von
        // normblattAnzeigen unterdrückt wird - sonst fehlt sonst bei "Ganzes
        // Canvas" sowohl Normblatt als auch Infostreifen, INFOSTREIFEN-VOLLCANVAS-01).
        const bool normblattGezeichnet = mitNormblatt && !vollCanvas && nb.value("normblattAnzeigen").toBool();
        if (normblattGezeichnet)
            pdfNormblattRendern(painter, nb, pxPerMm);
        if (mitInfostreifen && !normblattGezeichnet)
            pdfInfostreifenRendern(painter, nb, bMm, hMm, pxPerMm);
        pdfRevisionswasserzeichenRendern(painter, nb, bMm, hMm, pxPerMm);
    }
    return seiteIds.size();
}

// Seitengröße (mm) einer Schaltplan-Seite im Export - für das Start-Layout des Writers.
QSizeF Database::pdfSchaltplanSeitenGroesseMm(int seiteId, bool vollCanvas)
{
    QVariantMap nb = normblattDatenLaden(seiteId);
    double b = nb.value("breiteMm", 297.0).toDouble();
    double h = nb.value("hoeheMm",  210.0).toDouble();
    if (vollCanvas) {
        PdfBBox bb = pdfBoundingBox(seiteId, b, h, m_db);
        b = bb.bMm; h = bb.hMm;
    }
    return QSizeF(b, h);
}

// Schaltplan-Pipeline als eigenständiges PDF (Start-Layout aus der ersten Seite).
bool Database::pdfSchaltplanDatei(const QList<int> &seiteIds, const QString &pfad,
                                   bool mitNormblatt, bool vollCanvas, bool mitInfostreifen)
{
    if (seiteIds.isEmpty()) return false;

    // Ausgabepfad normalisieren
    const QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    const QSizeF groesse = pdfSchaltplanSeitenGroesseMm(seiteIds.first(), vollCanvas);

    QPdfWriter writer(localPath);
    writer.setCreator(QStringLiteral("Stroemling Design"));
    writer.setTitle(normblattDatenLaden(seiteIds.first()).value("projektName").toString());
    writer.setPageMargins(QMarginsF(0, 0, 0, 0));
    writer.setPageLayout(QPageLayout(
        QPageSize(groesse, QPageSize::Millimeter),
        QPageLayout::Portrait, QMarginsF(0,0,0,0)));

    QPainter painter(&writer);
    if (!painter.isActive()) {
        qCWarning(lcDb) << "pdfSchaltplanDatei: QPainter konnte nicht gestartet werden";
        return false;
    }

    pdfSchaltplanSeitenRendern(painter, writer, seiteIds, mitNormblatt, vollCanvas, mitInfostreifen, false);

    painter.end();
    qCInfo(lcDb) << "pdfSchaltplanDatei: PDF gespeichert:" << localPath
            << "(" << seiteIds.size() << "Seiten)" << (vollCanvas ? "(vollCanvas)" : "");
    return QFile::exists(localPath);
}

bool Database::canvasPdfExportieren(int projektId, const QString &pfad, bool mitNormblatt, bool vollCanvas, bool mitInfostreifen)
{
    // Seiten des Projekts in Anzeigereihenfolge, nur die mit Flag in_doku_pdf (DOKU-PDF-01)
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT s.id
        FROM seite s
        JOIN ort     o ON s.ort_id      = o.id
        JOIN anlage  a ON o.anlage_id   = a.id
        WHERE a.projekt_id = :pid AND s.in_doku_pdf = 1
        ORDER BY a.kuerzel, o.kuerzel, s.sortierung, s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    QList<int> seiteIds;
    if (!q.exec()) {
        qCWarning(lcDb) << "canvasPdfExportieren:" << q.lastError().text();
        return false;
    }
    while (q.next()) seiteIds << q.value(0).toInt();
    if (seiteIds.isEmpty()) {
        qCWarning(lcDb) << "canvasPdfExportieren: keine Seiten für Projekt" << projektId
                        << "(oder keine mit in_doku_pdf=1)";
        return false;
    }
    return pdfSchaltplanDatei(seiteIds, pfad, mitNormblatt, vollCanvas, mitInfostreifen);
}

bool Database::canvasSeiteExportieren(int seiteId, const QString &pfad, bool mitNormblatt, bool vollCanvas, bool mitInfostreifen)
{
    // Einzelseite: Flag in_doku_pdf bewusst ignoriert (ausdrücklicher Wunsch des Nutzers)
    return pdfSchaltplanDatei({seiteId}, pfad, mitNormblatt, vollCanvas, mitInfostreifen);
}
