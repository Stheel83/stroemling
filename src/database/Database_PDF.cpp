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

// Seiten des Projekts in Anzeigereihenfolge, nur die mit Flag in_doku_pdf (DOKU-PDF-01)
QList<int> Database::dokuPdfSeitenIds(int projektId)
{
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
    QList<int> ids;
    if (!q.exec()) {
        qCWarning(lcDb) << "dokuPdfSeitenIds:" << q.lastError().text();
        return ids;
    }
    while (q.next()) ids << q.value(0).toInt();
    return ids;
}

bool Database::canvasPdfExportieren(int projektId, const QString &pfad, bool mitNormblatt, bool vollCanvas, bool mitInfostreifen)
{
    const QList<int> seiteIds = dokuPdfSeitenIds(projektId);
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

// ── Dokumentations-PDF (DOKU-PDF-02) ─────────────────────────
// Optionen-JSON:
//   { "mitNormblatt": true, "vollCanvas": false, "mitInfostreifen": false,
//     "seiteIds": [..]            // optional; Standard: alle Seiten mit in_doku_pdf = 1
//     "abschnitte": [ {"typ":"schaltplan"},
//                     {"typ":"sps_io", "konfig": { SPS-Export-Konfiguration, s. spsExportZeilen() }} ] }
// Reihenfolge der Abschnitte = Reihenfolge im PDF. Alle Abschnitte rendern in denselben Writer.
// Zwei Durchläufe: Dry-Run in einen Puffer ermittelt die Gesamtseitenzahl für "Seite x von y"
// (und liefert in DOKU-PDF-03 die Seitenzahlen des Inhaltsverzeichnisses).
namespace {
struct DokuAbschnitt {
    QString     typ;
    QString     spsKonfig;   // nur sps_io: JSON-Text der Export-Konfiguration
};
struct DokuOptionen {
    bool mitNormblatt = true, vollCanvas = false, mitInfostreifen = false;
    QList<int>          seiteIds;
    QList<DokuAbschnitt> abschnitte;
    QString             projektName;
};
}

bool Database::dokuPdfExportieren(int projektId, const QString &pfad, const QString &optionenJson)
{
    QJsonParseError pe;
    const QJsonObject o = QJsonDocument::fromJson(optionenJson.toUtf8(), &pe).object();
    if (pe.error != QJsonParseError::NoError && !optionenJson.trimmed().isEmpty()) {
        qCWarning(lcDb) << "dokuPdfExportieren: Optionen-JSON ungültig:" << pe.errorString();
        return false;
    }

    DokuOptionen opt;
    opt.mitNormblatt    = o.value("mitNormblatt").toBool(true);
    opt.vollCanvas      = o.value("vollCanvas").toBool(false);
    opt.mitInfostreifen = o.value("mitInfostreifen").toBool(false);

    if (o.contains("seiteIds")) {
        for (const QJsonValue &v : o.value("seiteIds").toArray()) opt.seiteIds << v.toInt();
    } else {
        opt.seiteIds = dokuPdfSeitenIds(projektId);
    }

    const QJsonArray abs = o.value("abschnitte").toArray();
    if (abs.isEmpty()) {
        opt.abschnitte << DokuAbschnitt{QStringLiteral("schaltplan"), QString()};
    } else {
        for (const QJsonValue &v : abs) {
            const QJsonObject a = v.toObject();
            DokuAbschnitt da;
            da.typ = a.value("typ").toString();
            if (da.typ == QLatin1String("sps_io")) {
                da.spsKonfig = QString::fromUtf8(QJsonDocument(a.value("konfig").toObject()).toJson(QJsonDocument::Compact));
            } else if (da.typ != QLatin1String("schaltplan")) {
                qCWarning(lcDb) << "dokuPdfExportieren: unbekannter Abschnittstyp" << da.typ;
                return false;
            }
            opt.abschnitte << da;
        }
    }

    {
        QSqlQuery q(m_db);
        q.prepare("SELECT name FROM projekt WHERE id = :pid");
        q.bindValue(":pid", projektId);
        if (q.exec() && q.next()) opt.projektName = q.value(0).toString();
    }

    // Abschnitte ohne Inhalt weglassen (Schaltplan ohne Seiten)
    for (int i = opt.abschnitte.size() - 1; i >= 0; --i)
        if (opt.abschnitte[i].typ == QLatin1String("schaltplan") && opt.seiteIds.isEmpty())
            opt.abschnitte.removeAt(i);
    if (opt.abschnitte.isEmpty()) {
        qCWarning(lcDb) << "dokuPdfExportieren: nichts zu exportieren";
        return false;
    }

    // Start-Layout des Writers = Layout des ersten Abschnitts
    QPageLayout startLayout = pdfTabellenSeitenLayout();
    if (opt.abschnitte.first().typ == QLatin1String("schaltplan")) {
        startLayout = QPageLayout(
            QPageSize(pdfSchaltplanSeitenGroesseMm(opt.seiteIds.first(), opt.vollCanvas), QPageSize::Millimeter),
            QPageLayout::Portrait, QMarginsF(0, 0, 0, 0));
    }

    // Ein Durchlauf; gesamtSeiten = 0 im Dry-Run. Gibt die Seitenzahl zurück, -1 bei Fehler.
    auto durchlauf = [&](QPdfWriter &writer, int gesamtSeiten) -> int {
        writer.setCreator(QStringLiteral("Stroemling Design"));
        writer.setTitle(opt.projektName);
        writer.setPageMargins(QMarginsF(0, 0, 0, 0));
        writer.setPageLayout(startLayout);

        QPainter painter(&writer);
        if (!painter.isActive()) {
            qCWarning(lcDb) << "dokuPdfExportieren: QPainter konnte nicht gestartet werden";
            return -1;
        }
        int seiten = 0;
        for (int i = 0; i < opt.abschnitte.size(); ++i) {
            const DokuAbschnitt &a = opt.abschnitte[i];
            const bool neu = i > 0;   // erste Seite des Dokuments: Layout steht schon im Writer
            if (a.typ == QLatin1String("schaltplan")) {
                seiten += pdfSchaltplanSeitenRendern(painter, writer, opt.seiteIds,
                                                     opt.mitNormblatt, opt.vollCanvas, opt.mitInfostreifen, neu);
            } else {   // sps_io
                QStringList titel;
                QList<QStringList> daten;
                QString fehler;
                if (!spsExportZeilen(projektId, a.spsKonfig, titel, daten, fehler)) {
                    qCWarning(lcDb) << "dokuPdfExportieren: SPS-Abschnitt:" << fehler;
                    painter.end();
                    return -1;
                }
                QVariantList zeilen;
                for (const QStringList &z : daten) zeilen.append(QVariant(z));
                seiten += pdfTabelleRendern(painter, writer, QStringLiteral("SPS/PLS – I/O-Liste"),
                                            opt.projektName, titel, zeilen, neu, seiten + 1, gesamtSeiten);
            }
        }
        painter.end();
        return seiten;
    };

    // 1) Dry-Run in einen Puffer: Gesamtseitenzahl
    int gesamt = 0;
    {
        QBuffer puffer;
        puffer.open(QIODevice::WriteOnly);
        QPdfWriter dry(&puffer);
        gesamt = durchlauf(dry, 0);
        if (gesamt < 0) return false;
    }

    // 2) Echter Lauf
    const QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;
    QPdfWriter writer(localPath);
    const int seiten = durchlauf(writer, gesamt);
    if (seiten < 0) return false;
    qCInfo(lcDb) << "dokuPdfExportieren: PDF gespeichert:" << localPath << "(" << seiten << "Seiten,"
                 << opt.abschnitte.size() << "Abschnitte)";
    return QFile::exists(localPath);
}
