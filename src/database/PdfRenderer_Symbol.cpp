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


// bmk_seite eines Symboltyps ('auto' oder 'vertikal', s. symbol_definition,
// Schema-Migration 70 – aktuell nur bei 'spule' auf 'vertikal' gesetzt).
// 1:1-Analogie zu SymbolDefinitionModel::symbolInfo()["bmkSeite"].
static QString pdfBmkSeite(const QString &symbolId, const QSqlDatabase &db)
{
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT bmk_seite FROM symbol_definition WHERE id = :id LIMIT 1"));
    q.bindValue(":id", symbolId);
    if (q.exec() && q.next()) return q.value(0).toString();
    return QStringLiteral("auto");
}

// Kontaktspiegel-Zeilen für die Hauptfunktion eines Betriebsmittels (Jul 2026).
// 1:1-Port der QML-Logik im Kontaktspiegel-Block von CanvasRenderHandler.qml
// (maleElement) bzw. Database::betriebsmittelMitglieder() – liefert nur dann
// Zeilen, wenn eigeneElementId tatsächlich die Hauptfunktion des Betriebsmittels
// ist. Format je Nebenfunktion: "<Anschlusskennzeichnung>   Bl.<Blattnummer>".
static QStringList pdfKontaktspiegelZeilen(int betriebsmittelId, int eigeneElementId,
                                            const QSqlDatabase &db)
{
    QStringList zeilen;
    if (betriebsmittelId <= 0) return zeilen;

    int hauptId = 0;
    {
        QSqlQuery hq(db);
        hq.prepare(QStringLiteral("SELECT haupt_element_id FROM betriebsmittel WHERE id = :id"));
        hq.bindValue(":id", betriebsmittelId);
        if (hq.exec() && hq.next() && !hq.value(0).isNull())
            hauptId = hq.value(0).toInt();
    }
    if (hauptId <= 0 || hauptId != eigeneElementId) return zeilen;

    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT s.blattnummer, g.extra_daten "
        "FROM grafik_element g JOIN seite s ON s.id = g.seite_id "
        "WHERE g.betriebsmittel_id = :bid AND g.id != :hid "
        "ORDER BY s.blattnummer, g.id"));
    q.bindValue(":bid", betriebsmittelId);
    q.bindValue(":hid", hauptId);
    if (!q.exec()) return zeilen;
    while (q.next()) {
        QString blattnr = q.value(0).toString();
        QString extra   = q.value(1).toString();
        QString anschlusskennzeichnung;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                auto obj = doc.object();
                anschlusskennzeichnung = obj.value(QStringLiteral("anschlusskennzeichnung")).toString();
                // Fallback für Schütz-/Relais-Kontakte (pinBez statt anschlusskennzeichnung),
                // 1:1 zu Database::betriebsmittelMitglieder().
                if (anschlusskennzeichnung.isEmpty()) {
                    QJsonObject pinBez = obj.value(QStringLiteral("pinBez")).toObject();
                    if (!pinBez.isEmpty()) {
                        QStringList werte;
                        for (auto it = pinBez.constBegin(); it != pinBez.constEnd(); ++it)
                            werte << it.value().toString();
                        anschlusskennzeichnung = werte.join(QStringLiteral("/"));
                    }
                }
            }
        }
        QString bez = anschlusskennzeichnung.isEmpty() ? QStringLiteral("–") : anschlusskennzeichnung;
        zeilen << bez + QStringLiteral("   Bl.") + blattnr;
    }
    return zeilen;
}

// Beschriftungen (BMK, Freitexte) über/links neben einem Symbol rendern.
// 1:1-Port des BMK-Renderblocks in CanvasRenderHandler.qml (maleElement,
// Abschnitt "BMK-Label und Freitexte am Symbol rendern") – Text immer
// waagerecht; Anker-Seite hängt von Rotation + bmk_seite ab, Position wird
// zusätzlich per bmkOffsetX/Y (im Canvas per Drag verschiebbar) verschoben.
// Freitexte respektieren textReihenfolge + <feld>Sichtbar-Flags und sitzen
// bei waagerechter Anordnung UNTERHALB des Symbols (nicht bei der BMK).
static void pdfBeschriftungRendern(QPainter &p, const QVariantMap &el,
                                   double C, double pxPerMm, const QSqlDatabase &db)
{
    QString sid = el.value("symbolId").toString();
    static const QStringList kNoLabel = {
        "winkel","treffpunkt","treffpunkt_l","geraeteanschluss","unterbrechung",
        "aderdefinition","querverweis","klemme_anschluss","potenzial"
    };
    if (kNoLabel.contains(sid)) return;

    QVariantMap ed = el.value("extraDaten").toMap();
    QString bmk    = ed.value("bmk").toString();

    QVariantList reihenfolge = ed.value("textReihenfolge").toList();
    if (reihenfolge.isEmpty())
        reihenfolge << QStringLiteral("freitext1") << QStringLiteral("freitext2");
    QStringList ftZeilen;
    for (const QVariant &rv : reihenfolge) {
        QString key = rv.toString();
        bool sichtbar = ed.value(key + QStringLiteral("Sichtbar"), true).toBool();
        QString val = ed.value(key).toString();
        if (sichtbar && !val.isEmpty()) ftZeilen << val;
    }

    int bmId = el.value(QStringLiteral("betriebsmittelId")).toInt();
    if (bmId > 0 && ed.value(QStringLiteral("kontaktspiegelSichtbar"), true).toBool())
        ftZeilen << pdfKontaktspiegelZeilen(bmId, el.value(QStringLiteral("id")).toInt(), db);

    if (bmk.isEmpty() && ftZeilen.isEmpty()) return;

    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double vx1 = qMin(x1, x2), vx2 = qMax(x1, x2);
    double vy1 = qMin(y1, y2), vy2 = qMax(y1, y2);

    double schrift  = ed.value("schriftgroesse", 2.5).toDouble();
    double fsDev    = qMax(5.0, schrift * pxPerMm);
    double ftFsDev  = qMax(4.0, schrift * 0.85 * pxPerMm);

    QFont fontBmk, fontFt;
    fontBmk.setFamily(QStringLiteral("sans-serif"));
    fontBmk.setPixelSize(qMax(1, qRound(fsDev)));
    fontBmk.setBold(true);
    fontFt.setFamily(QStringLiteral("sans-serif"));
    fontFt.setPixelSize(qMax(1, qRound(ftFsDev)));

    p.save();
    p.setPen(pdfFarbe(el.value("strichFarbe").toString()));

    int rot = ((el.value("rotation").toInt() % 360) + 360) % 360;
    QString bmkSeite = pdfBmkSeite(sid, db);

    const double BIG = 1000.0; // großzügige Ausricht-Box, kein hartes Clipping bei üblichen Textlängen

    if (bmkSeite == QLatin1String("unten") || bmkSeite == QLatin1String("oben")) {
        // PIN-SEITE-ROTATION-01 (Aug 2026, 1:1 Analogie zu CanvasRenderHandler.qml):
        // Start-Kante (oben: "unten", unten: "oben"), durch spiegelY (vertikaler
        // Flip) und die 90°-Rotation weitergedreht (Zyklus unten->links->oben->
        // rechts je +90°). Label landet immer auf der gegenüberliegenden Kante.
        bool spiegelY = el.value("spiegelY").toBool();
        QString startKante = (bmkSeite == QLatin1String("oben"))
            ? (spiegelY ? QStringLiteral("oben") : QStringLiteral("unten"))
            : (spiegelY ? QStringLiteral("unten") : QStringLiteral("oben"));
        static const QStringList kantenZyklus = { "unten", "links", "oben", "rechts" };
        int startIdx = kantenZyklus.indexOf(startKante);
        QString pinKante = kantenZyklus.at((startIdx + (rot / 90)) % 4);
        static const QHash<QString, QString> gegenteil = {
            {"oben", "unten"}, {"unten", "oben"}, {"links", "rechts"}, {"rechts", "links"}
        };
        QString platz = gegenteil.value(pinKante);

        double bmkOx = ed.value("bmkOffsetX", 0.0).toDouble() * C;
        double bmkOy = ed.value("bmkOffsetY",
                                 (platz == QLatin1String("unten") || platz == QLatin1String("rechts"))
                                 ? 14.0 : -14.0).toDouble() * C;

        if (platz == QLatin1String("links") || platz == QLatin1String("rechts")) {
            bool istLinks = platz == QLatin1String("links");
            double bkAxLR = (istLinks ? vx1 : vx2) + bmkOy;
            double bkCyLR = (vy1 + vy2) / 2.0 + bmkOx;
            auto ausrichtung = istLinks ? Qt::AlignRight : Qt::AlignLeft;
            if (!bmk.isEmpty()) {
                p.setFont(fontBmk);
                p.drawText(QRectF(bkAxLR - BIG, bkCyLR - BIG, 2 * BIG, BIG),
                           ausrichtung | Qt::AlignBottom, bmk);
            }
            p.setFont(fontFt);
            double ftOffLR = bkCyLR + 2.0 * C;
            for (const QString &line : ftZeilen) {
                p.drawText(QRectF(bkAxLR - BIG, ftOffLR, 2 * BIG, BIG),
                           ausrichtung | Qt::AlignTop, line);
                ftOffLR += ftFsDev * 1.25;
            }
        } else if (platz == QLatin1String("unten")) {
            double bkCxU = (vx1 + vx2) / 2.0 + bmkOx;
            double bkBy  = vy2 + bmkOy;
            if (!bmk.isEmpty()) {
                p.setFont(fontBmk);
                p.drawText(QRectF(bkCxU - BIG, bkBy, 2 * BIG, BIG),
                           Qt::AlignHCenter | Qt::AlignTop, bmk);
            }
            p.setFont(fontFt);
            double ftYu = bkBy + fsDev + 2.0 * C;
            for (const QString &line : ftZeilen) {
                p.drawText(QRectF(bkCxU - BIG, ftYu, 2 * BIG, BIG),
                           Qt::AlignHCenter | Qt::AlignTop, line);
                ftYu += ftFsDev * 1.25;
            }
        } else {
            double bkCxO = (vx1 + vx2) / 2.0 + bmkOx;
            double bkByO = vy1 + bmkOy;
            if (!bmk.isEmpty()) {
                p.setFont(fontBmk);
                p.drawText(QRectF(bkCxO - BIG, bkByO - BIG, 2 * BIG, BIG),
                           Qt::AlignHCenter | Qt::AlignBottom, bmk);
            }
            p.setFont(fontFt);
            double ftYo = bkByO - fsDev - 2.0 * C;
            for (const QString &line : ftZeilen) {
                p.drawText(QRectF(bkCxO - BIG, ftYo - BIG, 2 * BIG, BIG),
                           Qt::AlignHCenter | Qt::AlignBottom, line);
                ftYo -= ftFsDev * 1.25;
            }
        }
    } else {
        // Bestehende Logik für "auto"/"vertikal" - unverändert.
        bool senkrecht = (bmkSeite == QLatin1String("vertikal"))
                         ? (rot == 0 || rot == 180)
                         : (rot == 90 || rot == 270);
        double bmkOx = ed.value("bmkOffsetX", 0.0).toDouble() * C;
        double bmkOy = ed.value("bmkOffsetY", -14.0).toDouble() * C;

        if (senkrecht) {
            double bkAx = vx1 + bmkOy;
            double bkCy = (vy1 + vy2) / 2.0 + bmkOx;
            if (!bmk.isEmpty()) {
                p.setFont(fontBmk);
                p.drawText(QRectF(bkAx - BIG, bkCy - BIG, BIG, BIG),
                           Qt::AlignRight | Qt::AlignBottom, bmk);
            }
            p.setFont(fontFt);
            double ftOff = bkCy + 2.0 * C;
            for (const QString &line : ftZeilen) {
                p.drawText(QRectF(bkAx - BIG, ftOff, BIG, BIG),
                           Qt::AlignRight | Qt::AlignTop, line);
                ftOff += ftFsDev * 1.25;
            }
        } else {
            double bkCx = (vx1 + vx2) / 2.0 + bmkOx;
            double bkTy = vy1 + bmkOy;
            if (!bmk.isEmpty()) {
                p.setFont(fontBmk);
                p.drawText(QRectF(bkCx - BIG, bkTy - BIG, 2 * BIG, BIG),
                           Qt::AlignHCenter | Qt::AlignBottom, bmk);
            }
            p.setFont(fontFt);
            double ftY = vy2 + 3.0 * C;
            for (const QString &line : ftZeilen) {
                p.drawText(QRectF(bkCx - BIG, ftY, 2 * BIG, BIG),
                           Qt::AlignHCenter | Qt::AlignTop, line);
                ftY += ftFsDev * 1.25;
            }
        }
    }
    p.restore();
}

// Pin-Bezeichnungen eines Symbols rendern (Default = symbol_pin.name, je
// Instanz überschreibbar via extraDaten.pinBez = { "pinName": "Label" }).
// 1:1-Port des Pin-Label-Blocks in CanvasRenderHandler.qml (maleElement,
// Abschnitt "Pin-Bezeichnungen rendern"). Nicht für Verbindungshelfer
// (eigene Beschriftungslogik) und nicht für Stecker/Buchse-Pin "2" (fiktive
// Steckverbindung, wird stattdessen farblich markiert).
static void pdfPinBezeichnungenRendern(QPainter &p, const QVariantMap &el,
                                       double C, double pxPerMm, const QSqlDatabase &db)
{
    QString sid = el.value("symbolId").toString();
    static const QSet<QString> kPbSkip = {
        "querverweis", "winkel", "treffpunkt", "treffpunkt_l", "klemme_anschluss",
        "geraeteanschluss", "potenzial", "aderdefinition", "isoliert_gelegte_ader"
    };
    if (kPbSkip.contains(sid)) return;

    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT name, x, y, offen_x, offen_y, steckkontakt FROM symbol_pin WHERE symbol_id = :sym"));
    q.bindValue(":sym", sid);
    if (!q.exec()) return;

    struct PbPin { QString name; double x, y, offenX, offenY; bool steckkontakt; };
    QVector<PbPin> pins;
    while (q.next())
        pins.append({ q.value(0).toString(), q.value(1).toDouble(), q.value(2).toDouble(),
                       q.value(3).toDouble(), q.value(4).toDouble(), q.value(5).toInt() != 0 });
    if (pins.isEmpty()) return;

    QVariantMap ed     = el.value("extraDaten").toMap();
    QVariantMap pinBez = ed.value("pinBez").toMap();
    QVariantMap pinLabelOffset = ed.value("pinLabelOffset").toMap(); // PIN-LABEL-OFFSET-01

    double x1 = el.value("x1").toDouble(), y1 = el.value("y1").toDouble();
    double x2 = el.value("x2").toDouble(), y2 = el.value("y2").toDouble();
    double rot = el.value("rotation").toDouble();
    bool spX = el.value("spiegelX").toBool(), spY = el.value("spiegelY").toBool();

    // Symbolweite Pin-Schriftgröße (PIN-LABEL-SCHRIFTGROESSE-01), Default 2.0mm.
    double pinSchriftMm = 2.0;
    QSqlQuery fsQ(db);
    fsQ.prepare(QStringLiteral("SELECT pin_schrift_mm FROM symbol_definition WHERE id = :sym LIMIT 1"));
    fsQ.bindValue(":sym", sid);
    if (fsQ.exec() && fsQ.next())
        pinSchriftMm = fsQ.value(0).toDouble();

    double fsDev = qMax(6.0, pinSchriftMm * pxPerMm);
    QFont font;
    font.setFamily(QStringLiteral("sans-serif"));
    font.setPixelSize(qMax(1, qRound(fsDev)));

    p.save();
    p.setFont(font);
    p.setPen(QColor(0x1a, 0x40, 0x60)); // dunkelblau, lesbar auf Weiß (analog Aderdefinitions-Textblock)

    double rotRad = rot * M_PI / 180.0;
    const double BIG = 1000.0;

    for (const PbPin &pin : pins) {
        if (pin.steckkontakt) continue; // Steckkontakt: keine Beschriftung (SYM-STECKKONTAKT-01)

        QString label = pinBez.value(pin.name).toString();
        if (label.isEmpty()) label = pin.name;

        QPointF pos = pdfPinWeltPos(x1, y1, x2, y2, rot, spX, spY, pin.x, pin.y);
        double px = pos.x() * C, py = pos.y() * C;

        // PIN-LABEL-OFFSET-01: manueller Zusatzversatz je Instanz/Pin, 1:1-Port
        // des EP-Felds "Versatz" (EpSymbolSection.qml) / des Renderer-Ports in
        // CanvasRenderHandler.qml - gleiche Werteinheit wie bmkOffsetX/Y.
        if (pinLabelOffset.contains(pin.name)) {
            QVariantMap off = pinLabelOffset.value(pin.name).toMap();
            px += off.value("dx", 0.0).toDouble() * C;
            py += off.value("dy", 0.0).toDouble() * C;
        }

        double ox = pin.offenX, oy = pin.offenY;
        if (spX) ox = -ox;
        if (spY) oy = -oy;
        double tx = ox * std::cos(rotRad) - oy * std::sin(rotRad);
        double ty = ox * std::sin(rotRad) + oy * std::cos(rotRad);
        double off = 2.5 * C;

        // Label wird QUER zur Pin-Richtung versetzt, nicht in dieselbe Richtung
        // wie der Pin zeigt - eine Verbindungslinie verläuft exakt entlang des
        // (transformierten) Pin-Richtungsvektors tx/ty, ein Versatz in dieselbe
        // Richtung legt das Label direkt in den Leitungsweg
        // (PIN-LABEL-UEBERLAPP-02, Nutzer-Screenshot: Verbindung lief durch
        // "D0"-Beschriftung). 1:1-Port des Fixes in CanvasRenderHandler.qml.
        if (std::abs(ty) > std::abs(tx)) {
            // Pin zeigt vorwiegend hoch/runter (Leitung verläuft senkrecht) ->
            // Label seitlich versetzen, damit es nicht auf der Leitung liegt.
            p.drawText(QRectF(px + off, py - BIG / 2, BIG, BIG),
                       Qt::AlignLeft | Qt::AlignVCenter, label);
        } else {
            // Pin zeigt vorwiegend links/rechts (Leitung verläuft waagerecht) ->
            // Label senkrecht versetzen, damit es nicht auf der Leitung liegt.
            // Richtung (oben) ist unabhängig vom Vorzeichen sinnvoll, da die
            // Leitung so oder so waagerecht durch die Pin-Position verläuft.
            p.drawText(QRectF(px - BIG / 2, py - off - BIG, BIG, BIG),
                       Qt::AlignHCenter | Qt::AlignBottom, label);
        }
    }
    p.restore();
}

// Sucht die Gegenstelle eines Querverweis-Symbols anhand des Signalnamens –
// 1:1-Port von querverweisPartnerCacheAktualisieren() in
// CanvasCacheHandler.qml (QUERVERWEIS-PDF-LABEL-01, Aug 2026): reine
// Signalname-Gleichheit, KEIN Abgleich von suchmodus/Anlage/Ort (genau wie
// im QML-Original), und nur die erste gefundene Übereinstimmung – nicht
// alle. Eine .strl-Datei enthält immer genau ein Projekt, kein
// projekt_id-Scope nötig (siehe pdfKlemmenAnschlussPartner unten).
static QString pdfQuerverweisPartner(const QSqlDatabase &db, const QString &signalname,
                                      int seiteId, double x1, double y1)
{
    if (signalname.isEmpty()) return QString();
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT ge.seite_id, s.blattnummer, COALESCE(s.bezeichnung, ''), ge.x1, ge.y1
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        WHERE ge.symbol_id = 'querverweis'
          AND json_extract(ge.extra_daten,'$.signalname') = :sn
    )");
    q.bindValue(":sn", signalname);
    if (!q.exec()) return QString();
    while (q.next()) {
        int    pSeite = q.value(0).toInt();
        double px = q.value(3).toDouble(), py = q.value(4).toDouble();
        if (pSeite == seiteId && qAbs(px - x1) < 0.5 && qAbs(py - y1) < 0.5) continue; // sich selbst
        QString blatt = q.value(1).toString();
        QString bez   = q.value(2).toString();
        return blatt + (bez.isEmpty() ? QString() : QLatin1Char(' ') + bez);
    }
    return QString();
}

// Sucht Gegenstellen desselben Klemmenanschlusses (gleiche klemmeId + Ebene,
// KLEMME-NET-01-Gruppierung) an anderen Positionen/Seiten des Projekts, damit
// der PDF-Export dieselbe "Verbunden mit ..."-Information zeigen kann wie der
// interaktive Canvas-Tooltip (KLEMMENANSCHLUSS-PARTNER-01). Eine .strl-Datei
// enthält immer genau ein Projekt (siehe schema.sql CREATE TABLE projekt),
// daher genügt die Suche über die ganze Datenbankverbindung ohne zusätzlichen
// projekt_id-Scope.
//
// KLEMMENANSCHLUSS-PARTNER-01-Nachtrag: das Label zeigt bewusst NUR die
// Anschlussbezeichnung der Gegenstelle (+ Blattnummer bei Fremdseite), NICHT
// die volle Leiste:Nr.-Kennung. Diese ist innerhalb einer Ebenen-Gruppe per
// Konstruktion immer identisch mit der bereits eine Zeile darüber
// angezeigten eigenen BMK (beide Anschlüsse gehören zur selben Klemme) —
// sie zu wiederholen brachte keine neue Information, sondern nur unnötig
// langen Text, der die feste 20mm-Textbox sprengte und in die Nachbarspalte
// lief (vom Nutzer per PDF-Screenshot gemeldet).
static QStringList pdfKlemmenAnschlussPartner(const QSqlDatabase &db, int klemmeId,
                                               const QString &ebene, int seiteId,
                                               double x1, double y1)
{
    QStringList result;
    if (klemmeId <= 0 || ebene.isEmpty()) return result;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT ge.seite_id, s.blattnummer,
               json_extract(ge.extra_daten,'$.anschlussBezeichnung'),
               ge.x1, ge.y1
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        WHERE ge.symbol_id = 'klemme_anschluss'
          AND CAST(json_extract(ge.extra_daten,'$.klemmeId') AS INTEGER) = :kid
    )");
    q.bindValue(":kid", klemmeId);
    if (!q.exec()) return result;
    while (q.next()) {
        QString pBez = q.value(2).toString();
        QString pEbene = (pBez == QLatin1String("PE") || !pBez.contains(QLatin1Char('.')))
                          ? pBez : pBez.section(QLatin1Char('.'), 0, 0);
        if (pEbene != ebene) continue;
        int    pSeite = q.value(0).toInt();
        double px = q.value(3).toDouble(), py = q.value(4).toDouble();
        // Sich selbst überspringen (gleiche Seite + praktisch gleiche Position)
        if (pSeite == seiteId && qAbs(px - x1) < 0.5 && qAbs(py - y1) < 0.5) continue;

        QString label = pBez.isEmpty() ? QStringLiteral("?") : pBez;
        if (pSeite != seiteId) label += QStringLiteral(" Bl.") + q.value(1).toString();
        result << label;
    }
    return result;
}

void pdfElementSymbolRendern(QPainter &p, const QVariantMap &el,
                                     double C, double pxPerMm, const QSqlDatabase &db,
                                     const QVector<PdfLeitungsSegment> *leitungsSegs,
                                     int seiteId,
                                     const QHash<int, bool> *winkelUmkehrenMap)
{
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 0.35).toDouble() * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

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
        // SYMBOL-ECKE-RUND-01 (Aug 2026): jedes Symbol-Primitiv (linie/rechteck/…)
        // wird einzeln per drawLine()/etc. gezeichnet (pdfPrimitivRendern) - mit
        // FlatCap bleibt am gemeinsamen Eckpunkt zweier Primitive eine
        // keilförmige Lücke sichtbar, da Qt Line-Joins nur innerhalb EINES
        // QPainterPath greifen, nicht über separate drawLine()-Aufrufe hinweg
        // (ursprünglich nur für "winkel" gefixt, PDF-WINKEL-TREFFPUNKT-ECKE-01 -
        // betraf aber jedes mehrsegmentige Symbol, z.B. schliesser nach
        // SYMBOL-VERTIKAL-01). RoundCap generisch für alle Symbol-Primitive
        // schließt die Lücke (rundes Eck-„Blob", analog zu abgerundeten
        // Leitungsecken); für geschlossene Formen (Rechteck/Kreis) und
        // freistehende Linienenden ohne Lücken-Nachbarn ist der Effekt bei den
        // dünnen Symbol-Strichbreiten nicht wahrnehmbar.
        symPen.setCapStyle(Qt::RoundCap);
        if (leitungsSegs && sid == "winkel") {
            double rx1 = el.value("x1").toDouble(), ry1 = el.value("y1").toDouble();
            double rx2 = el.value("x2").toDouble(), ry2 = el.value("y2").toDouble();
            double rmx = (rx1 + rx2) / 2.0, rmy = (ry1 + ry2) / 2.0;
            const QPointF kandidaten[8] = {
                { rx1, rmy }, { rx2, rmy }, { rmx, ry1 }, { rmx, ry2 },
                { rx1, ry1 }, { rx2, ry1 }, { rx1, ry2 }, { rx2, ry2 }
            };
            const PdfLeitungsSegment *mSeg = nullptr;
            for (const QPointF &k : kandidaten) {
                mSeg = pdfSegmentPtrFuerPunkt(k.x(), k.y(), *leitungsSegs);
                if (mSeg) {
                    symPen.setColor(mSeg->color);
                    symPen.setWidthF(mSeg->lw);
                    break;
                }
            }

            // Winkel: eigener Zeichenpfad (pdfMaleWinkel, SquareCap + ein
            // zusammenhängender QPainterPath statt zweier RoundCap-drawLine()-
            // Aufrufe über pdfSymbolRendern) – LEITUNG-ZOOM-BREITE-01-Nachtrag,
            // Aug 2026, 1:1-Analogie zum QML-Fix in CanvasRenderHandler.qml
            // _renderSymbol()/_maleWinkel(). WINKEL-FARBE-01 (Sep 2026): läuft
            // eine echte Zweifarb-Bänderung durch den Winkel (mSeg->gebaendert
            // && mSeg->zweifarbig), zeichnet pdfMaleWinkelGebaendert() zwei
            // parallele, bündige Linien statt des flachen Einzelstrichs –
            // bewusst in Weltkoordinaten*C (pdfPinWeltPos()) statt im lokalen
            // p.translate/rotate/scale-Block, s. dortiger Kommentar.
            if (mSeg && mSeg->gebaendert && mSeg->zweifarbig) {
                double rot = el.value("rotation").toDouble();
                bool   spX = el.value("spiegelX").toBool(), spY = el.value("spiegelY").toBool();
                QPointF wp0 = pdfPinWeltPos(rx1, ry1, rx2, ry2, rot, spX, spY, 0.0, 0.0);
                QPointF wp1 = pdfPinWeltPos(rx1, ry1, rx2, ry2, rot, spX, spY, 0.0, 1.0);
                QPointF wp2 = pdfPinWeltPos(rx1, ry1, rx2, ry2, rot, spX, spY, 1.0, 1.0);
                // WINKEL-DREHER-01-PDF (Sep 2026): die feste Zeichenreihenfolge
                // wp0→wp1→wp2 hat keinen Bezug zur tatsächlichen Netz-
                // Flussrichtung, die mSeg->flip bestimmt hat. Die Umkehr-
                // Entscheidung kommt jetzt fertig aus winkelUmkehrenMap (per
                // BFS in pdfLeitungenSammeln() berechnet, s. dortiger
                // Kommentar) statt hier lokal per Skalarprodukt gegen ein
                // beliebig gematchtes mSeg neu zu raten — dieselbe Lehre wie
                // im QML-Fix: nur die BFS-kausale Berechnung relativ zum
                // tatsächlichen Vorgänger-Segment ist über beliebig lange
                // Winkel-Ketten konsistent.
                bool umkehren = winkelUmkehrenMap && winkelUmkehrenMap->value(el.value("id").toInt(), false);
                if (umkehren)
                    pdfMaleWinkelGebaendert(p, QPointF(wp2.x()*C, wp2.y()*C),
                                                QPointF(wp1.x()*C, wp1.y()*C),
                                                QPointF(wp0.x()*C, wp0.y()*C), *mSeg);
                else
                    pdfMaleWinkelGebaendert(p, QPointF(wp0.x()*C, wp0.y()*C),
                                                QPointF(wp1.x()*C, wp1.y()*C),
                                                QPointF(wp2.x()*C, wp2.y()*C), *mSeg);
            } else {
                p.save();
                p.translate(symX + absSw / 2, symY + absSh / 2);
                if (el.value("rotation").toInt() != 0) p.rotate(el.value("rotation").toInt());
                if (el.value("spiegelX").toBool()) p.scale(-1.0, 1.0);
                if (el.value("spiegelY").toBool()) p.scale(1.0, -1.0);
                p.translate(-absSw / 2, -absSh / 2);
                pdfMaleWinkel(p, absSw, absSh, symPen);
                p.restore();
            }
        // Treffpunkt/Treffpunkt_L: eigener 3-Arm-Zeichenpfad (S1/S2/Ziel), da
        // der Ziel-Arm gebändert sein kann (VERBINDUNGSFARBE-03/04-Port,
        // 1:1-Analogie zu CanvasRenderHandler.qml maleElement/
        // _maleTreffpunktArme()) – ersetzt den generischen Einzel-QPen-Pfad
        // über pdfSymbolRendern für diese beiden Typen.
        } else if (leitungsSegs && (sid == "treffpunkt" || sid == "treffpunkt_l")) {
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
            pdfTreffpunktArmeRendern(p, sid, absSw, absSh, pen.widthF(), s1Seg, s2Seg, zielSeg);
            p.restore();
        } else {
            pdfSymbolRendern(p, sid, symX, symY, absSw, absSh,
                             el.value("rotation").toInt(),
                             el.value("spiegelX").toBool(),
                             el.value("spiegelY").toBool(),
                             symPen, db);
        }
        pdfBeschriftungRendern(p, el, C, pxPerMm, db);
        pdfPinBezeichnungenRendern(p, el, C, pxPerMm, db);

        // ── Aderdefinitions-Textblock ────────────────────────────────────────
        if (sid == QStringLiteral("aderdefinition")) {
            QVariantMap ed = el.value("extraDaten").toMap();
            QStringList zeilen;
            QString bez   = ed.value("bezeichnung").toString();
            if (!bez.isEmpty()) zeilen << bez;

            QString aderfarbe  = ed.value("aderfarbe").toString();
            QString aderfarbe2 = ed.value("aderfarbe2").toString();
            double  quer       = ed.value("querschnitt_mm2").toDouble();
            if (!aderfarbe.isEmpty() || quer > 0) {
                QString z = aderfarbe.isEmpty() ? QStringLiteral("–")
                           : (aderfarbe2.isEmpty() ? aderfarbe : aderfarbe + "/" + aderfarbe2);
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

            // bmkSichtbar: false → nur Klemmen-Nr (ohne Leisten-Präfix).
            // Granulare BMK-Sichtbarkeit (Leiste/Anlage/Ort/Gerät): 1:1-Port
            // aus CanvasRenderHandler.qml — vorher berücksichtigte der PDF-
            // Export nur bmkSichtbar, anlageAnzeigen/ortAnzeigen/
            // geraetAnzeigen wurden ignoriert und Anlage/Ort erschienen im
            // PDF immer, selbst wenn auf dem Canvas ausgeblendet
            // (KLEMME-PDF-ANLAGE-ORT-01).
            QString kaBmk;
            bool kaBmkVis = false;
            {
                int col = kaBmkBase.lastIndexOf(QLatin1Char(':'));
                if (col >= 0) {
                    QString kaBmkStrip = kaBmkBase.left(col + 1);
                    QString kaBmkNr    = kaBmkBase.mid(col + 1);
                    QString kaBmkPrefix;
                    if (kaed.value("bmkSichtbar", QVariant(true)).toBool()) {
                        bool kaAnlAn = kaed.value("anlageAnzeigen", QVariant(true)).toBool();
                        bool kaOrtAn = kaed.value("ortAnzeigen",    QVariant(true)).toBool();
                        bool kaGkAn  = kaed.value("geraetAnzeigen", QVariant(true)).toBool();
                        if (kaAnlAn && kaOrtAn && kaGkAn) {
                            kaBmkPrefix = kaBmkStrip;
                        } else {
                            QString kaS = kaBmkStrip.endsWith(QLatin1Char(':'))
                                          ? kaBmkStrip.left(kaBmkStrip.length() - 1)
                                          : kaBmkStrip;
                            static const QRegularExpression reTok(
                                QStringLiteral("(==\\w+|\\+\\+\\w+|=\\w+|\\+\\w+|-\\w+)"));
                            QStringList kaTok;
                            QRegularExpressionMatchIterator kaIt = reTok.globalMatch(kaS);
                            while (kaIt.hasNext()) kaTok << kaIt.next().captured(1);
                            if (kaTok.isEmpty()) kaTok << kaS;
                            int kaLM = -1;
                            for (int kaI = kaTok.size() - 1; kaI >= 0; kaI--) {
                                if (kaTok[kaI].startsWith(QLatin1Char('-'))) { kaLM = kaI; break; }
                            }
                            QString kaR;
                            for (int kaJ = 0; kaJ < kaTok.size(); kaJ++) {
                                const QString &kaT = kaTok[kaJ];
                                QChar kaTC = kaT.at(0);
                                if      (kaTC == QLatin1Char('=')) { if (kaAnlAn) kaR += kaT; }
                                else if (kaTC == QLatin1Char('+')) { if (kaOrtAn) kaR += kaT; }
                                else if (kaTC == QLatin1Char('-')) { if (kaJ == kaLM || kaGkAn) kaR += kaT; }
                            }
                            kaBmkPrefix = kaR + QLatin1Char(':');
                        }
                    }
                    kaBmk    = kaBmkPrefix + kaBmkNr;
                    kaBmkVis = !kaBmk.isEmpty();
                } else {
                    kaBmk    = kaBmkBase;
                    kaBmkVis = !kaBmkBase.isEmpty()
                               && kaed.value("bmkSichtbar", QVariant(true)).toBool();
                }
            }

            // Gegenstelle(n) desselben Klemmenanschlusses (KLEMMENANSCHLUSS-
            // PARTNER-01, Aug 2026): PDF-Pendant zum interaktiven Canvas-
            // Tooltip/Highlight (KLEMME-HL-01) — im statischen PDF gibt es
            // keinen Klick/Hover, daher wird die Info als zusätzliche,
            // dezente Textzeile direkt am Symbol gerendert.
            QString kaPartnerText;
            {
                QString kaEbene = (kaAnz == QLatin1String("PE") || !kaAnz.contains(QLatin1Char('.')))
                                   ? kaAnz : kaAnz.section(QLatin1Char('.'), 0, 0);
                int kaKlemmeId = kaed.value("klemmeId").toInt();
                QStringList kaPartnerListe = pdfKlemmenAnschlussPartner(
                    db, kaKlemmeId, kaEbene, seiteId,
                    el.value("x1").toDouble(), el.value("y1").toDouble());
                if (!kaPartnerListe.isEmpty())
                    kaPartnerText = QStringLiteral("↔ ") + kaPartnerListe.join(QStringLiteral(", "));
            }
            bool kaPartVis = !kaPartnerText.isEmpty();

            if (!kaAnz.isEmpty() || kaBmkVis || kaPartVis) {
                double anzFsDev  = 1.5 * pxPerMm;
                double bmkFsDev  = 2.2 * pxPerMm;
                double partFsDev = 1.6 * pxPerMm;

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
                QFont fPart; fPart.setFamily(QStringLiteral("sans-serif"));
                fPart.setPixelSize(qMax(1, qRound(partFsDev))); fPart.setBold(false);

                QColor colAnz(0x33, 0xbb, 0x66);
                QColor colBmk(0x44, 0x88, 0xcc);
                QColor colPart(0x7a, 0xaa, 0xcc);
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

                    // Bezeichnung oben, BMK darunter, Gegenstelle zuunterst,
                    // alle drei um Mittelpunkt zentriert
                    double totalH = (!kaAnz.isEmpty() ? anzFsDev * 1.2 : 0.0)
                                  + (kaBmkVis ? bmkFsDev * 1.2 : 0.0)
                                  + (kaPartVis ? partFsDev * 1.8 : 0.0);
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
                        curY += bmkFsDev * 1.2;
                    }
                    if (kaPartVis) {
                        p.setFont(fPart); p.setPen(colPart);
                        QRectF r = pinRechts ? QRectF(kaX - tw, curY, tw, partFsDev * 1.8)
                                             : QRectF(kaX, curY, tw, partFsDev * 1.8);
                        p.drawText(r, ha | Qt::AlignVCenter, kaPartnerText);
                    }
                } else {
                    // 0°: Pin oben → Text unten | 180°: Pin unten → Text oben
                    bool pinUnten = (kaRot == 180);
                    double gapDev = 0.75 * pxPerMm;
                    double kaCxO  = kaCx + kaOx;

                    if (!pinUnten) {
                        // Text wächst nach unten (anz näher am Symbol, Gegenstelle zuunterst)
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
                            curY += bmkFsDev * 1.2;
                        }
                        if (kaPartVis) {
                            p.setFont(fPart); p.setPen(colPart);
                            p.drawText(QRectF(kaCxO - tw/2, curY, tw, partFsDev * 1.8),
                                       Qt::AlignHCenter | Qt::AlignTop, kaPartnerText);
                        }
                    } else {
                        // Text wächst nach oben (anz näher am Symbol, Gegenstelle zuoberst)
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
                        if (kaPartVis) {
                            curY -= partFsDev * 1.8;
                            p.setFont(fPart); p.setPen(colPart);
                            p.drawText(QRectF(kaCxO - tw/2, curY, tw, partFsDev * 1.8),
                                       Qt::AlignHCenter | Qt::AlignTop, kaPartnerText);
                        }
                    }
                }
                p.restore();
            }
        }

        // ── querverweis: Signalname + Gegenstelle ("→ Seite") ──
        // Bisher im PDF komplett gefehlt (kNoLabel oben blendet die generische
        // BMK-Beschriftung bewusst aus, da querverweis kein bmk- sondern ein
        // signalname-Feld nutzt, aber nie ein eigener Ersatzblock nachgezogen
        // wurde) – 1:1-Port der Text-Positionierung aus
        // CanvasRenderHandler.qml (Abschnitt "querverweis"),
        // QUERVERWEIS-PDF-LABEL-01 (Aug 2026).
        if (sid == QStringLiteral("querverweis")) {
            QVariantMap qed = el.value("extraDaten").toMap();
            QString qSn = qed.value("signalname").toString();
            QString qPartner = pdfQuerverweisPartner(db, qSn, seiteId,
                                                       el.value("x1").toDouble(), el.value("y1").toDouble());

            if (!qSn.isEmpty() || !qPartner.isEmpty()) {
                double qFsDev  = 2.0 * pxPerMm;
                double qFsSDev = 1.6 * pxPerMm;

                int  qRot  = ((el.value("rotation").toInt() % 360) + 360) % 360;
                bool qSenk = (qRot == 90 || qRot == 270);
                double qCx = (x1 + x2) / 2.0;
                double qCy = (y1 + y2) / 2.0;

                QFont fSn; fSn.setFamily(QStringLiteral("sans-serif"));
                fSn.setPixelSize(qMax(1, qRound(qFsDev))); fSn.setBold(true);
                QFont fQp; fQp.setFamily(QStringLiteral("sans-serif"));
                fQp.setPixelSize(qMax(1, qRound(qFsSDev))); fQp.setBold(false);

                QColor colSn(0xc0, 0xd8, 0xf0);
                QColor colQp(0x7a, 0xaa, 0xcc);
                double qtw = 40.0 * pxPerMm;

                p.save();
                if (qSenk) {
                    // 90°/270°: Text linksbündig vom Symbol, Signalname oben
                    // + Gegenstelle darunter um Mittelpunkt zentriert
                    double gapDev = 1.0 * pxPerMm;
                    double qX     = qMin(x1, x2) - gapDev;
                    if (!qSn.isEmpty()) {
                        p.setFont(fSn); p.setPen(colSn);
                        double h   = qFsDev * 1.2;
                        double top = qPartner.isEmpty() ? (qCy - h / 2.0) : (qCy - h);
                        p.drawText(QRectF(qX - qtw, top, qtw, h), Qt::AlignRight | Qt::AlignTop, qSn);
                    }
                    if (!qPartner.isEmpty()) {
                        p.setFont(fQp); p.setPen(colQp);
                        double h = qFsSDev * 1.8;
                        p.drawText(QRectF(qX - qtw, qCy, qtw, h), Qt::AlignRight | Qt::AlignTop,
                                   QStringLiteral("→ ") + qPartner);
                    }
                } else {
                    // 0°/180°: Text über dem Symbol, Gegenstelle über dem Signalnamen
                    double gapDev = 0.75 * pxPerMm;
                    double qY     = qMin(y1, y2) - gapDev;
                    if (!qSn.isEmpty()) {
                        p.setFont(fSn); p.setPen(colSn);
                        double h = qFsDev * 1.2;
                        p.drawText(QRectF(qCx - qtw/2, qY - h, qtw, h),
                                   Qt::AlignHCenter | Qt::AlignBottom, qSn);
                    }
                    if (!qPartner.isEmpty()) {
                        p.setFont(fQp); p.setPen(colQp);
                        double h      = qFsSDev * 1.8;
                        double bottom = qY - qFsDev - 1.0;
                        p.drawText(QRectF(qCx - qtw/2, bottom - h, qtw, h),
                                   Qt::AlignHCenter | Qt::AlignBottom,
                                   QStringLiteral("→ ") + qPartner);
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
