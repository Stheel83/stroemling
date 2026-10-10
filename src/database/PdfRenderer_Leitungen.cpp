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


// Zeichnet eine einzelne Bifarb-Ader (aderfarbe2) als längs alternierendes
// Strich-Band – zwei Striche gleicher Breite in Grundfarbe/Zweitfarbe, per
// Dash-Offset gegeneinander versetzt. Bewusst KEIN Parallel-Offset (das wäre
// mit der Treffpunkt-Bänderung optisch verwechselbar, siehe Feldkommentar an
// PdfLeitungsSegment::farbe2).
static void pdfMaleBifarbLinie(QPainter &p, double ax, double ay, double bx, double by,
                                const QColor &farbe1, const QColor &farbe2, double lw)
{
    const double dashLen = qMax(2.0, lw * 3.0);
    QPen pen1(farbe1, lw, Qt::CustomDashLine, Qt::RoundCap);
    pen1.setDashPattern({ dashLen / lw, dashLen / lw });
    pen1.setDashOffset(0.0);
    p.setPen(pen1);
    p.drawLine(QLineF(ax, ay, bx, by));

    QPen pen2(farbe2, lw, Qt::CustomDashLine, Qt::RoundCap);
    pen2.setDashPattern({ dashLen / lw, dashLen / lw });
    pen2.setDashOffset(dashLen / lw);
    p.setPen(pen2);
    p.drawLine(QLineF(ax, ay, bx, by));
}

// Zeichnet ein Geraden-Stück – einfarbig, bifarb (aderfarbe2) oder
// (Treffpunkt-Ziel-Arm, außerhalb des Symbols weiterlaufend) gebändert.
// 1:1-Port von _maleGebaenderteLinie() in CanvasRenderHandler.qml
// (VERBINDUNGSFARBE-03/04). ax,ay,bx,by bereits in derselben Zieleinheit
// des Aufrufers (Device-Pixel bei Leitungen). s.flip ist ein für das ganze
// Segment fester, vorab EINMAL berechneter Wert (WINKEL-FARBE-01-
// Nachbesserung, Sep 2026, s. Kommentar an PdfLeitungsSegment::flip) – wird
// hier nicht mehr aus refPunkt neu berechnet. RoundCap statt FlatCap:
// Leitungssegmente treffen sich an Ecken/Verzweigungen als mehrere separate
// drawLine()-Aufrufe (nicht ein QPainterPath) - Qt-Line-Joins greifen nur
// innerhalb eines Path, sonst bleibt am gemeinsamen Punkt eine keilförmige
// Lücke sichtbar (analog Winkel-Symbol, s. pdfElementRendern).
static void pdfMaleGebaenderteLinie(QPainter &p, double ax, double ay, double bx, double by,
                                     const PdfLeitungsSegment &s,
                                     double pxPerMm, Qt::PenCapStyle capStyle = Qt::RoundCap)
{
    if (!s.gebaendert && s.farbe2.isValid()) {
        pdfMaleBifarbLinie(p, ax, ay, bx, by, s.color, s.farbe2, s.lw);
        return;
    }
    if (!s.gebaendert || !s.zweifarbig) {
        // Ungebändert ODER zwei zufällig gleichfarbige Adern
        // (VERBINDUNGSFARBE-WEISSLINIE-01, Sep 2026, Nutzerentscheid): früher
        // zusätzlich eine dünne weiße Trennlinie in der Mitte — entfällt
        // ersatzlos, die höhere Dicke allein reicht als Erkennungsmerkmal.
        p.setPen(QPen(s.color, s.lw, Qt::SolidLine, capStyle));
        p.drawLine(QLineF(ax, ay, bx, by));
        return;
    }

    double dx = bx - ax, dy = by - ay;
    double len = std::sqrt(dx*dx + dy*dy);
    if (len < 1e-6) return;
    double px = -dy / len, py = dx / len;
    double basis = s.lw / 2.0;
    double off   = basis / 2.0;
    // WINKEL-DREHER-01-PDF (Sep 2026): s.segUmkehr invertiert flip nur für
    // DIESES Segment (s. Kommentar an PdfLeitungsSegment::segUmkehr) — 1:1-
    // Port von band.segUmkehr in _maleGebaenderteLinie()/CanvasRenderHandler.qml.
    bool flip = s.segUmkehr ? !s.flip : s.flip;
    QColor farbeNeg = flip ? s.farbeB : s.farbeA;
    QColor farbePos = flip ? s.farbeA : s.farbeB;
    // BIFARB-TREFFPUNKT-01-PDF (Sep 2026, 1:1-Port von farben2 in
    // _maleGebaenderteLinie()/CanvasRenderHandler.qml): ist einer der beiden
    // Arme selbst eine bifarb Ader, trägt farbeA2/farbeB2 ihre
    // Sekundärfarbe (sonst ungültig) — dieses Band wird dann per
    // pdfMaleBifarbLinie() alternierend statt einfarbig gezeichnet, exakt
    // dieselbe Funktion wie für eine eigenständige Bifarb-Ader.
    QColor farbe2Neg = flip ? s.farbeB2 : s.farbeA2;
    QColor farbe2Pos = flip ? s.farbeA2 : s.farbeB2;

    if (farbe2Neg.isValid())
        pdfMaleBifarbLinie(p, ax - px*off, ay - py*off, bx - px*off, by - py*off, farbeNeg, farbe2Neg, basis);
    else {
        p.setPen(QPen(farbeNeg, basis, Qt::SolidLine, capStyle));
        p.drawLine(QLineF(ax - px*off, ay - py*off, bx - px*off, by - py*off));
    }
    if (farbe2Pos.isValid())
        pdfMaleBifarbLinie(p, ax + px*off, ay + py*off, bx + px*off, by + py*off, farbePos, farbe2Pos, basis);
    else {
        p.setPen(QPen(farbePos, basis, Qt::SolidLine, capStyle));
        p.drawLine(QLineF(ax + px*off, ay + py*off, bx + px*off, by + py*off));
    }
}

// Zeichnet einen kompletten S1- oder S2-Arm als EINEN zusammenhängenden
// QPainterPath vom eigenen äußeren Pin bis zum Ziel-Pin
// (TREFFPUNKT-CAP-UEBERLAPP-01, Nutzer-Konzeptentscheid Sep 2026, 1:1-Port
// von _maleTreffpunktArmEinfarbig() in CanvasRenderHandler.qml — s. dortiger
// Kommentar für die Design-Begründung). points enthält bereits die fertige,
// ggf. zum Ziel hin seitlich versetzte Wegpunkt-Kette (s.
// pdfTreffpunktArmeRendern()); beide Enden (eigener Pin UND Ziel-Ende) sind
// echte Übergänge zu externen Leitungen und werden hier manuell um die
// halbe Linienbreite verlängert. seg == nullptr: unverbunden → Default-Blau.
static void pdfMaleTreffpunktArmEinfarbig(QPainter &p, QVector<QPointF> points,
                                          const PdfLeitungsSegment *seg, double lwBasis)
{
    if (points.size() < 2) return;
    double lw = seg ? seg->lw : lwBasis;
    int n = points.size();
    double dxA = points[1].x() - points[0].x(), dyA = points[1].y() - points[0].y();
    double lenA = std::sqrt(dxA*dxA + dyA*dyA);
    if (lenA > 1e-6) points[0] -= QPointF(dxA/lenA, dyA/lenA) * (lw / 2.0);
    double dxB = points[n-1].x() - points[n-2].x(), dyB = points[n-1].y() - points[n-2].y();
    double lenB = std::sqrt(dxB*dxB + dyB*dyB);
    if (lenB > 1e-6) points[n-1] += QPointF(dxB/lenB, dyB/lenB) * (lw / 2.0);

    QPainterPath path;
    path.moveTo(points[0]);
    for (int i = 1; i < points.size(); ++i) path.lineTo(points[i]);

    if (seg && seg->farbe2.isValid()) {
        // Zweifarbige Ader (aderfarbe2, z.B. PE grün-gelb) — analog
        // pdfMaleBifarbLinie(), nur über den ganzen (ggf. geknickten)
        // Arm-Pfad statt eines einzelnen Segments.
        const double dashLen = qMax(2.0, lw * 3.0);
        QPen pen1(seg->color, lw, Qt::CustomDashLine, Qt::FlatCap, Qt::MiterJoin);
        pen1.setDashPattern({ dashLen / lw, dashLen / lw });
        pen1.setDashOffset(0.0);
        p.setPen(pen1);
        p.drawPath(path);
        QPen pen2(seg->farbe2, lw, Qt::CustomDashLine, Qt::FlatCap, Qt::MiterJoin);
        pen2.setDashPattern({ dashLen / lw, dashLen / lw });
        pen2.setDashOffset(dashLen / lw);
        p.setPen(pen2);
        p.drawPath(path);
        return;
    }
    QColor color = seg ? seg->color : QColor("#4a9eff");
    p.setPen(QPen(color, lw, Qt::SolidLine, Qt::FlatCap, Qt::MiterJoin));
    p.drawPath(path);
}

// Winkel: transparenter Durchlaufpunkt (§2.2), keine Bänderung nötig (immer
// genau ein Netzsegment durch beide Arme). Beide Primitiv-Linien als EIN
// QPainterPath statt zweier getrennter drawLine()-Aufrufe (wie
// pdfSymbolRendern()/pdfPrimitivRendern() es täte) – Qt fügt am gemeinsamen
// Punkt automatisch einen sauberen Miter-Join ein, kein RoundCap-Workaround
// nötig. SquareCap wie bei normalen Leitungssegmenten, damit der Übergang
// zur anschließenden Leitung nahtlos wirkt statt als runder "Blob"
// (LEITUNG-ZOOM-BREITE-01-Nachtrag, Aug 2026, 1:1-Analogie zur QML-
// Funktion _maleWinkel() in CanvasRenderHandler.qml). Koordinaten aus
// symbole.sql (0,0)→(0,1)→(1,1), w/h bereits lokale Symbol-Pixel.
void pdfMaleWinkel(QPainter &p, double w, double h, const QPen &pen)
{
    QPen winkelPen = pen;
    winkelPen.setCapStyle(Qt::SquareCap);
    p.setPen(winkelPen);
    QPainterPath path;
    path.moveTo(0.0, 0.0);
    path.lineTo(0.0, h);
    path.lineTo(w, h);
    p.drawPath(path);
}

// WINKEL-FARBE-01 (Sep 2026): 1:1-Port von _maleWinkelGebaendertViewport()
// in CanvasRenderHandler.qml. Zwei parallele, bündige (Versatz = halbe
// Einzel-Ader-Breite, kein Zwischenraum) Pfade durch den 90°-Knick statt
// des flachen Einzelstrichs von pdfMaleWinkel() – für den Fall, dass zwei
// unterschiedlich gefärbte Adern durch denselben, an sich transparenten
// Winkel laufen (s.gebaendert && s.zweifarbig). vp0/vp1/vp2 bereits in
// Device-Pixeln (Welt-Pin-Position via pdfPinWeltPos() * C) – bewusst NICHT
// im lokalen, ggf. rotierten/gespiegelten Symbol-Koordinatensystem, um die
// VERBINDUNGSFARBE-04-Fallenklasse (Seitenzuordnung kippt bei Rotation) von
// vornherein zu vermeiden. s.flip ist ein FESTER, für das ganze Segment
// (und damit für BEIDE Teilstücke hier) gleicher Wert (s. Kommentar an
// PdfLeitungsSegment::flip) – dieselbe Konstante für n1 UND n2 verwendet,
// nicht pro Teilstück neu berechnet: nur so bleibt der Übergang am Knick
// nicht-kreuzend (Nutzerskizze) UND stimmt automatisch mit der davor/danach
// weiterlaufenden externen Leitung überein (pdfMaleGebaenderteLinie(),
// dieselbe Konstante). Jede Linie ein durchgehender 4-Punkt-QPainterPath.
void pdfMaleWinkelGebaendert(QPainter &p, QPointF vp0, QPointF vp1, QPointF vp2,
                                     const PdfLeitungsSegment &s)
{
    auto normale = [](QPointF a, QPointF b) {
        double dx = b.x() - a.x(), dy = b.y() - a.y();
        double len = std::sqrt(dx*dx + dy*dy);
        return len < 1e-6 ? QPointF(0.0, 0.0) : QPointF(-dy/len, dx/len);
    };
    QPointF n1 = normale(vp0, vp1);
    QPointF n2 = normale(vp1, vp2);
    double basis = s.lw / 2.0;   // Breite je Einzel-Ader-Band, wie pdfMaleGebaenderteLinie
    double off   = basis / 2.0;

    // WINKEL-BAND-ECKE-01 (Sep 2026, 1:1-Port der QML-Nachbesserung): statt
    // zweier getrennter Versatzpunkte an vp1 (vp1+n1*off UND vp1+n2*off, mit
    // schräger Verbindungslinie dazwischen — ergab mit MiterJoin eine
    // sichtbare Dreiecksspitze am äußeren Eck) wird der eine, geometrisch
    // exakte Schnittpunkt der beiden Versatzgeraden verwendet: bei einem
    // 90°-Knick stehen n1/n2 senkrecht zueinander, die Versatzgeraden
    // schneiden sich exakt in vp1 + n1*off + n2*off (Parallelogrammsumme).
    // BIFARB-TREFFPUNKT-01-PDF (Sep 2026, Winkel-Nachtrag, 1:1-Port von
    // farben2 in _maleWinkelGebaendertViewport()/CanvasRenderHandler.qml):
    // ist einer der beiden Arme selbst eine bifarb Ader, zeichnet dieses
    // Band ein alternierendes Strichmuster über den kompletten Pfad (beide
    // Arme + Eckpunkt aus WINKEL-BAND-ECKE-01) statt Vollfarbe — Qt führt
    // den Dash-Offset über den Knick hinweg nahtlos fort, da beide Arme
    // EIN zusammenhängender QPainterPath sind.
    auto seite = [&](double sign, const QColor &farbe, const QColor &farbe2) {
        QPointF ecke(vp1.x() + (n1.x() + n2.x()) * off * sign,
                     vp1.y() + (n1.y() + n2.y()) * off * sign);
        QPainterPath path;
        path.moveTo(vp0.x() + n1.x()*off*sign, vp0.y() + n1.y()*off*sign);
        path.lineTo(ecke);
        path.lineTo(vp2.x() + n2.x()*off*sign, vp2.y() + n2.y()*off*sign);
        if (farbe2.isValid()) {
            double dashLen = qMax(2.0, basis * 3.0);
            QPen pen1(farbe, basis, Qt::CustomDashLine, Qt::SquareCap, Qt::MiterJoin);
            pen1.setDashPattern({ dashLen / basis, dashLen / basis });
            pen1.setDashOffset(0.0);
            p.setPen(pen1);
            p.drawPath(path);
            QPen pen2(farbe2, basis, Qt::CustomDashLine, Qt::SquareCap, Qt::MiterJoin);
            pen2.setDashPattern({ dashLen / basis, dashLen / basis });
            pen2.setDashOffset(dashLen / basis);
            p.setPen(pen2);
            p.drawPath(path);
        } else {
            p.setPen(QPen(farbe, basis, Qt::SolidLine, Qt::SquareCap, Qt::MiterJoin));
            p.drawPath(path);
        }
    };
    seite(-1.0, s.flip ? s.farbeB : s.farbeA, s.flip ? s.farbeB2 : s.farbeA2);
    seite(+1.0, s.flip ? s.farbeA : s.farbeB, s.flip ? s.farbeA2 : s.farbeB2);
}

// Zeichnet die S1-/S2-Arme eines Treffpunkt-/Treffpunkt_L-Symbols als zwei
// unabhängige, durchgehende Adern (TREFFPUNKT-CAP-UEBERLAPP-01, Nutzer-
// Konzeptentscheid Sep 2026 — ersetzt das vorherige Modell mit einem
// gemeinsamen Verzweigungsknoten komplett, 1:1-Port von
// _maleTreffpunktArme() in CanvasRenderHandler.qml, s. dortiger Kommentar
// für die Design-Begründung). S1 bleibt im Bündel Richtung Ziel auf der
// linken, S2 auf der rechten Seite — fest im Symbol definiert, rotiert/
// spiegelt mit. Der Versatz-Betrag ist bewusst NICHT aus S1/S2s eigener
// Breite abgeleitet, sondern exakt derselbe wie im gebänderten Zweig von
// pdfMaleGebaenderteLinie() (dort für die EXTERNE, außerhalb des Symbols
// weiterlaufende Leitung genutzt) — nur so schließt die Symbol-eigene
// Darstellung nahtlos an, ohne an der Ziel-Pin-Grenze einen seitlichen
// Sprung ("Stufe") zu zeigen (dritte Nutzer-Nachbesserung, Sep 2026, per
// Skizze). Ist die externe Leitung dort undividiert (gleiche Farbe/nur
// eine Ader), ist der Versatz hier ebenfalls 0. Läuft im bereits
// transformierten (translate/rotate/scale) Koordinatensystem wie
// pdfSymbolRendern – lokale, unrotierte 0..1-Koordinaten (s.
// symbol_primitiv für 'treffpunkt'/'treffpunkt_l'). s1Seg/s2Seg: das
// jeweils an diesem Pin anliegende, bereits farblich aufgelöste
// Leitungssegment (nullptr = unverbunden → Default-Blau). zielSeg wird nur
// für den Versatz-Betrag gelesen (gebaendert/zweifarbig/lw), seine Farbe
// bleibt für die Symbol-eigene Darstellung ungenutzt.
void pdfTreffpunktArmeRendern(QPainter &p, const QString &symbolId, double w, double h,
                                     double lwBasis, const PdfLeitungsSegment *s1Seg,
                                     const PdfLeitungsSegment *s2Seg,
                                     const PdfLeitungsSegment *zielSeg)
{
    auto P = [&](double nx, double ny) { return QPointF(nx * w, ny * h); };
    double off = (zielSeg && zielSeg->gebaendert && zielSeg->zweifarbig) ? zielSeg->lw / 4.0 : 0.0;

    if (symbolId == QLatin1String("treffpunkt")) {
        pdfMaleTreffpunktArmEinfarbig(p, {
            P(0, 0.5), P(0.25, 0.5),
            QPointF(0.5*w - off, 0.75*h), QPointF(0.5*w - off, h)
        }, s1Seg, lwBasis);
        pdfMaleTreffpunktArmEinfarbig(p, {
            P(1, 0.5), P(0.75, 0.5),
            QPointF(0.5*w + off, 0.75*h), QPointF(0.5*w + off, h)
        }, s2Seg, lwBasis);
    } else if (symbolId == QLatin1String("treffpunkt_l")) {
        // Dritte Nutzer-Nachbesserung: S2 startet zentriert am eigenen Pin,
        // schwenkt aber jetzt (statt komplett gerade zu bleiben) ab dem
        // Knotenpunkt leicht schräg zur versetzten Position, S1
        // spiegelbildlich in die andere Richtung — beide enden symmetrisch
        // ± off neben der Mittelachse.
        pdfMaleTreffpunktArmEinfarbig(p, {
            P(0, 0.5), P(0.25, 0.5),
            QPointF(0.5*w - off, 0.75*h), QPointF(0.5*w - off, h)
        }, s1Seg, lwBasis);
        pdfMaleTreffpunktArmEinfarbig(p, {
            P(0.5, 0), QPointF(0.5*w, 0.75*h),
            QPointF(0.5*w + off, h)
        }, s2Seg, lwBasis);
    }
}

// ============================================================
// KABEL-ADERFARBE-01 (PDF-Parität, Aug 2026)
// 1:1-Port von _stabilerPunktSchluessel()/_naechsterStabilerPunkt()/
// _lokalerAderSchluessel() in CanvasNetzberechnung.qml — muss synchron
// gehalten werden. PDF hat keinen Live-Netzgraphen (elIdx/pinName pro
// Segment), daher werden Segment-Endpunkte hier geometrisch auf Pin-
// Weltpositionen der Symbole der Seite gematcht (analog zum bestehenden
// Winkel-/Querverweis-Matching oben), um dieselbe Adjazenz wie im Canvas
// nachzubilden.
// ============================================================
struct PdfSymElement {
    QString     symbolId;
    double      x1 = 0, y1 = 0, x2 = 0, y2 = 0;
    double      rotation = 0;
    bool        spiegelX = false, spiegelY = false;
    QJsonObject extraDaten;
};

static const QSet<QString> &pdfRoutingSymbolTypen()
{
    static const QSet<QString> s = { QStringLiteral("winkel"), QStringLiteral("treffpunkt"),
                                      QStringLiteral("treffpunkt_l"), QStringLiteral("aderdefinition") };
    return s;
}

// 1:1-Port von _stabilerPunktSchluessel().
static QString pdfStabilerPunktSchluessel(int elIdx, const QString &pinName,
                                           const QVector<PdfSymElement> &els,
                                           const QVector<PdfSymElement> &geraetekaesten)
{
    if (elIdx < 0 || elIdx >= els.size()) return {};
    const PdfSymElement &el  = els[elIdx];
    const QString       &sid = el.symbolId;

    if (sid == QLatin1String("geraeteanschluss")) {
        QString ank = el.extraDaten.value(QStringLiteral("anschlusskennzeichnung")).toString();
        if (ank.isEmpty()) return {};
        double cx = (el.x1 + el.x2) / 2.0, cy = (el.y1 + el.y2) / 2.0;
        const PdfSymElement *best = nullptr;
        double bestA = std::numeric_limits<double>::infinity();
        for (const PdfSymElement &gk : geraetekaesten) {
            double gx1 = std::min(gk.x1, gk.x2), gx2 = std::max(gk.x1, gk.x2);
            double gy1 = std::min(gk.y1, gk.y2), gy2 = std::max(gk.y1, gk.y2);
            if (cx >= gx1 && cx <= gx2 && cy >= gy1 && cy <= gy2) {
                double a = (gx2 - gx1) * (gy2 - gy1);
                if (a < bestA) { bestA = a; best = &gk; }
            }
        }
        QString bmk = best ? best->extraDaten.value(QStringLiteral("bmk")).toString() : QString();
        if (bmk.isEmpty()) return {};
        return QStringLiteral("GA:") + bmk + ":" + ank;
    }
    if (sid == QLatin1String("klemme_anschluss")) {
        QString bmk = el.extraDaten.value(QStringLiteral("bmk")).toString();
        QString anz = el.extraDaten.value(QStringLiteral("anschlussBezeichnung")).toString();
        if (bmk.isEmpty() || anz.isEmpty()) return {};
        return QStringLiteral("KA:") + bmk + ":" + anz;
    }
    if (sid == QLatin1String("potenzial")) {
        QString sig = el.extraDaten.value(QStringLiteral("signalname")).toString();
        if (sig.isEmpty()) return {};
        return QStringLiteral("POT:") + sig;
    }
    QString bmk2 = el.extraDaten.value(QStringLiteral("bmk")).toString();
    if (bmk2.isEmpty() || pinName.isEmpty()) return {};
    return QStringLiteral("SYM:") + bmk2 + ":" + pinName;
}

// 1:1-Port von _naechsterStabilerPunkt().
static QString pdfNaechsterStabilerPunkt(int elIdx, int vonIdx, const QString &pinName,
                                          const QHash<int, QVector<QPair<int, QString>>> &adj,
                                          const QVector<PdfSymElement> &els,
                                          const QVector<PdfSymElement> &geraetekaesten,
                                          int tiefe)
{
    if (tiefe <= 0 || elIdx < 0) return {};
    QString stabil = pdfStabilerPunktSchluessel(elIdx, pinName, els, geraetekaesten);
    if (!stabil.isEmpty()) return stabil;
    if (elIdx >= els.size() || !pdfRoutingSymbolTypen().contains(els[elIdx].symbolId)) return {};
    auto it = adj.find(elIdx);
    if (it == adj.end()) return {};
    for (const auto &nb : it.value()) {
        if (nb.first != vonIdx)
            return pdfNaechsterStabilerPunkt(nb.first, elIdx, nb.second, adj, els, geraetekaesten, tiefe - 1);
    }
    return {};
}

// ── pdfLeitungenSammeln(): Phasen ───────────────────────────────────────────
// REFACTOR-CPP-05 (Okt 2026): die frühere ~700-Zeilen-Funktion ist in benannte
// Phasen zerlegt (Logik 1:1 unverändert, abgesichert per Referenz-PDF-Vergleich):
//   1. ladeAderdefinitionspunkte / ladeRohSegmente   (DB → Rohdaten)
//   2. baueSymbolGraph + kabellinienAderfarben       (Kabellinien-Fallback, Kreuzungslabel)
//   3. direktFarben / wurzelnJeSegment / berechneEndfarben (ADP-Farbe, Winkel-/Querverweis-Gruppen)
//   4. ladeTreffpunktKandidaten / ladeWinkelListe / propagiereBaenderung (Treffpunkt-Bänderung)
//   5. pdfLeitungenSammeln: setzt die PdfLeitungsSegment zusammen
namespace {

struct Adp { double cx, cy; QString farbe; QString farbe2; };
struct RawSeg { double x1, y1, x2, y2; int verbId; QString signaltyp; QString potenzial; };
struct TpKandidat { int s1Idx, s2Idx, zielIdx; QPointF s1Welt; };
struct PdfWinkelInfo {
    int id; double x1, y1, x2, y2, rot; bool spX, spY;
    int segAmP0 = -1, segAmP2 = -1;
};

// Symbol-Elemente der Seite + geometrisch gematchte Segment-Endpunkte (Stabiler-Punkt-Suche)
struct SymbolGraph {
    QVector<PdfSymElement> els, geraetekaesten;
    QVector<int>     segElA, segElB;
    QVector<QString> segPinA, segPinB;
    QHash<int, QVector<QPair<int, QString>>> adj;   // elIdx → [(nachbarElIdx, pinNameDortDrüben)]
};

// Ergebnis der Treffpunkt-Bänderungs-Propagation (je raw[]-Segment)
struct BandErgebnis {
    QVector<bool>   segGebaendert, segZweifarbig, segUmkehrV, segFlipV, segMehrfach;
    QVector<QColor> segFarbeAV, segFarbeBV, segFarbeA2V, segFarbeB2V;
    QVector<double> segBreiteV;
    QVector<int>    segArmAnzahlV;
    QHash<int, bool> winkelUmkehren;   // key: winkelListe-Index
};

inline bool nahPunkt(double px, double py, const QPointF &w)
{
    return std::hypot(px - w.x(), py - w.y()) < 2.0;   // Canvas-Einheiten (0.5 mm)
}

// Erstes raw[]-Segment, dessen Endpunkt auf w liegt; -1 wenn keines.
int segAnPunkt(const QVector<RawSeg> &raw, const QPointF &w)
{
    const int n = raw.size();
    for (int i = 0; i < n; i++)
        if (nahPunkt(raw[i].x1, raw[i].y1, w) || nahPunkt(raw[i].x2, raw[i].y2, w))
            return i;
    return -1;
}

QVector<Adp> ladeAderdefinitionspunkte(int seiteId, const QSqlDatabase &db)
{
    // Aderdefinitionspunkte dieser Seite: cx,cy,aderfarbe. Analog aderdefMap
    // in Database_Klemmen.cpp (klemmlistenauszug) – Aderfarbe hat Vorrang vor
    // der Signaltyp-Farbe, s.u. (gleiche Priorität wie CanvasRenderHandler.qml
    // _segmentFarbeUndBreite()).
    QVector<Adp> adps;
    {
        QSqlQuery aq(db);
        aq.prepare(R"(
            SELECT (x1+x2)/2.0, (y1+y2)/2.0,
                   COALESCE(json_extract(extra_daten,'$.aderfarbe'),''),
                   COALESCE(json_extract(extra_daten,'$.aderfarbe2'),'')
            FROM grafik_element
            WHERE seite_id = :sid AND symbol_id = 'aderdefinition'
        )");
        aq.bindValue(":sid", seiteId);
        if (aq.exec()) {
            while (aq.next()) {
                QString af  = aq.value(2).toString();
                QString af2 = aq.value(3).toString();
                if (!af.isEmpty())
                    adps.append({ aq.value(0).toDouble(), aq.value(1).toDouble(), af, af2 });
            }
        }
    }
    return adps;
}

QVector<RawSeg> ladeRohSegmente(int seiteId, const QSqlDatabase &db)
{
    // Rohe Leitungssegmente (noch ohne Farbe) – Farbauflösung erfolgt erst
    // nach der Winkel-/Querverweis-Propagation weiter unten. `potenzial`
    // (= net.netKey im Live-Canvas, s. verbindungenSynchronisieren()) wird
    // für den KABEL-ADERFARBE-01-Fallback unten mitgeführt.
    QVector<RawSeg> raw;
    {
        QSqlQuery q(db);
        q.prepare(R"(
            SELECT vs.punkte, vs.verbindung_id, v.signaltyp, v.potenzial
            FROM verbindung_segment vs
            JOIN verbindung v ON vs.verbindung_id = v.id
            WHERE vs.seite_id = :sid
        )");
        q.bindValue(":sid", seiteId);
        if (!q.exec()) return {};
        while (q.next()) {
            QJsonDocument doc = QJsonDocument::fromJson(q.value(0).toString().toUtf8());
            if (!doc.isArray() || doc.array().size() < 2) continue;
            QJsonArray arr = doc.array();
            raw.append({ arr[0].toObject()["x"].toDouble(), arr[0].toObject()["y"].toDouble(),
                         arr[1].toObject()["x"].toDouble(), arr[1].toObject()["y"].toDouble(),
                         q.value(1).toInt(), q.value(2).toString(), q.value(3).toString() });
        }
    }
    return raw;
}

SymbolGraph baueSymbolGraph(int seiteId, const QSqlDatabase &db, const QVector<RawSeg> &raw)
{
    const int n = raw.size();
    // Alle Symbol-Elemente der Seite laden (für die Stabiler-Punkt-Suche).
    QVector<PdfSymElement> els, geraetekaesten;
    QSqlQuery eq(db);
    eq.prepare(R"(
        SELECT symbol_id, x1, y1, x2, y2, rotation, spiegel_x, spiegel_y, extra_daten
        FROM grafik_element WHERE seite_id = :sid AND typ = 'symbol'
    )");
    eq.bindValue(":sid", seiteId);
    if (eq.exec()) {
        while (eq.next()) {
            PdfSymElement e;
            e.symbolId = eq.value(0).toString();
            e.x1 = eq.value(1).toDouble(); e.y1 = eq.value(2).toDouble();
            e.x2 = eq.value(3).toDouble(); e.y2 = eq.value(4).toDouble();
            e.rotation = eq.value(5).toDouble();
            e.spiegelX = eq.value(6).toBool(); e.spiegelY = eq.value(7).toBool();
            e.extraDaten = QJsonDocument::fromJson(eq.value(8).toString().toUtf8()).object();
            els.append(e);
        }
    }
    QSqlQuery gq(db);
    gq.prepare(R"(
        SELECT x1, y1, x2, y2, extra_daten FROM grafik_element
        WHERE seite_id = :sid AND typ = 'geraetekasten'
    )");
    gq.bindValue(":sid", seiteId);
    if (gq.exec()) {
        while (gq.next()) {
            PdfSymElement gk;
            gk.x1 = gq.value(0).toDouble(); gk.y1 = gq.value(1).toDouble();
            gk.x2 = gq.value(2).toDouble(); gk.y2 = gq.value(3).toDouble();
            gk.extraDaten = QJsonDocument::fromJson(gq.value(4).toString().toUtf8()).object();
            geraetekaesten.append(gk);
        }
    }

    // Pin-Definitionen (normiert 0..1) je vorkommendem Symbol-Typ bulk laden.
    QSet<QString> symbolIds;
    for (const PdfSymElement &e : els) symbolIds.insert(e.symbolId);
    QHash<QString, QVector<QPair<QString, QPointF>>> pinDefs;
    if (!symbolIds.isEmpty()) {
        QStringList idList; for (const QString &s : symbolIds) idList << QStringLiteral("'%1'").arg(s);
        QSqlQuery pq(db);
        pq.exec(QStringLiteral("SELECT symbol_id, name, x, y FROM symbol_pin WHERE symbol_id IN (%1)")
                .arg(idList.join(',')));
        while (pq.next())
            pinDefs[pq.value(0).toString()].append({ pq.value(1).toString(),
                QPointF(pq.value(2).toDouble(), pq.value(3).toDouble()) });
    }

    // Weltposition jedes Pins jedes Elements berechnen.
    struct ElPin { int elIdx; QString pinName; QPointF pos; };
    QVector<ElPin> elPins;
    for (int ei = 0; ei < els.size(); ei++) {
        const PdfSymElement &e = els[ei];
        for (const auto &pd : pinDefs.value(e.symbolId)) {
            QPointF w = pdfPinWeltPos(e.x1, e.y1, e.x2, e.y2, e.rotation, e.spiegelX, e.spiegelY,
                                      pd.second.x(), pd.second.y());
            elPins.append({ ei, pd.first, w });
        }
    }

    // Jeden raw[]-Segment-Endpunkt auf das nächste Pin (elIdx, pinName) matchen.
    const double PIN_TOL2 = 2.0;
    auto matchPin = [&](double px, double py) -> QPair<int, QString> {
        for (const ElPin &ep : elPins)
            if (std::hypot(px - ep.pos.x(), py - ep.pos.y()) < PIN_TOL2)
                return { ep.elIdx, ep.pinName };
        return { -1, QString() };
    };
    QVector<int> segElA(n), segElB(n);
    QVector<QString> segPinA(n), segPinB(n);
    for (int i = 0; i < n; i++) {
        auto a = matchPin(raw[i].x1, raw[i].y1);
        auto b = matchPin(raw[i].x2, raw[i].y2);
        segElA[i] = a.first;  segPinA[i] = a.second;
        segElB[i] = b.first;  segPinB[i] = b.second;
    }

    // Adjazenz für den Stabiler-Punkt-Walk aufbauen (elIdx → [(nachbarElIdx, pinNameDortDrüben)]).
    QHash<int, QVector<QPair<int, QString>>> adj;
    for (int i = 0; i < n; i++) {
        if (segElA[i] >= 0 && segElB[i] >= 0) {
            adj[segElA[i]].append({ segElB[i], segPinB[i] });
            adj[segElB[i]].append({ segElA[i], segPinA[i] });
        }
    }

    SymbolGraph g;
    g.els = els; g.geraetekaesten = geraetekaesten;
    g.segElA = segElA; g.segElB = segElB; g.segPinA = segPinA; g.segPinB = segPinB;
    g.adj = adj;
    return g;
}

void kabellinienAderfarben(int seiteId, const QSqlDatabase &db, const QVector<RawSeg> &raw,
                           const SymbolGraph &g,
                           QVector<QColor> &kabelSegFarbe, QVector<QColor> &kabelSegFarbe2,
                           QVector<PdfKabelAderLabel> *aderLabelsOut)
{
    const int n = raw.size();
    const QVector<PdfSymElement> &els = g.els, &geraetekaesten = g.geraetekaesten;
    const QVector<int> &segElA = g.segElA, &segElB = g.segElB;
    const QVector<QString> &segPinA = g.segPinA, &segPinB = g.segPinB;
    const auto &adj = g.adj;

    // Lokaler Ader-Schlüssel je Segment, nur bei Bedarf berechnet (Kreuzungen
    // sind i.d.R. eine kleine Teilmenge aller Segmente der Seite).
    QHash<int, QString> aderKeyCache;
    auto aderKeyFuerSeg = [&](int segIdx) -> QString {
        auto it = aderKeyCache.find(segIdx);
        if (it != aderKeyCache.end()) return it.value();
        QString seiteA = pdfNaechsterStabilerPunkt(segElA[segIdx], segElB[segIdx], segPinA[segIdx],
                                                    adj, els, geraetekaesten, 20);
        QString seiteB = pdfNaechsterStabilerPunkt(segElB[segIdx], segElA[segIdx], segPinB[segIdx],
                                                    adj, els, geraetekaesten, 20);
        QStringList teile;
        if (!seiteA.isEmpty()) teile << seiteA;
        if (!seiteB.isEmpty()) teile << seiteB;
        teile.sort();
        QString key = teile.join(QStringLiteral("|"));
        aderKeyCache[segIdx] = key;
        return key;
    };

    // Kabellinien der Seite laden und geometrisch mit raw[] schneiden —
    // 1:1-Port von kabelSchnittNetzeBerechnen()/maleKabelSchnitte() in
    // CanvasGeometrie.qml/CanvasRenderHandler.qml.
    //
    // PDF-ADERNUMMER-POOL-01 (Aug 2026): fehlte bisher komplett die
    // mittlere Prioritätsstufe des Canvas-Pendants
    // (CanvasNetzberechnung.qml::_aderNrFuerKreuzung(): explizite
    // aderZuordnung > gepoolte kabel_ader-Tabelle > lokaler si+1-
    // Fallback) — hier gab es nur "explizit" und den lokalen
    // Fallback, jede Kabellinie zählte deshalb unabhängig wieder bei 1
    // los, exakt der vor PROPAGATION-04/07 im Canvas behobene Bug, nur
    // nie in den PDF-Export übernommen. gepooltJeKabel cacht die
    // bereits über kabelAderProjektweitSynchronisieren() persistierten
    // aderKey→Adernnummer-Zuordnungen je kabelId (eine Seite kann
    // mehrere Kabel enthalten, daher pro kabelId einmal geladen).
    QHash<int, QHash<QString, int>> gepooltJeKabel;
    auto gepoolteAderNrn = [&](int kabelId) -> const QHash<QString, int> & {
        auto it = gepooltJeKabel.find(kabelId);
        if (it != gepooltJeKabel.end()) return it.value();
        QHash<QString, int> map;
        if (kabelId > 0) {
            QSqlQuery gq(db);
            gq.prepare(R"(
                SELECT ader_key, ader_nr FROM kabel_ader
                WHERE kabel_id = :kid AND ader_key IS NOT NULL AND ader_key != ''
            )");
            gq.bindValue(":kid", kabelId);
            if (gq.exec()) {
                while (gq.next()) map.insert(gq.value(0).toString(), gq.value(1).toInt());
            }
        }
        return gepooltJeKabel.insert(kabelId, map).value();
    };

    QSqlQuery klq(db);
    klq.prepare(R"(
        SELECT x1, y1, x2, y2, extra_daten, kabel_id, strich_farbe FROM grafik_element
        WHERE seite_id = :sid AND typ = 'kabellinie'
    )");
    klq.bindValue(":sid", seiteId);
    if (klq.exec()) {
        while (klq.next()) {
            double kx1 = klq.value(0).toDouble(), ky1 = klq.value(1).toDouble();
            double kx2 = klq.value(2).toDouble(), ky2 = klq.value(3).toDouble();
            double kDxW = kx2 - kx1, kDyW = ky2 - ky1;
            double kLenW = std::hypot(kDxW, kDyW);
            if (kLenW < 0.5) continue;
            QJsonObject ed = QJsonDocument::fromJson(klq.value(4).toString().toUtf8()).object();
            QJsonArray adern = ed.value(QStringLiteral("adern")).toArray();
            QString klStrichFarbeStr = klq.value(6).toString();
            QColor  klStrichFarbe = (!klStrichFarbeStr.isEmpty() && QColor(klStrichFarbeStr).isValid())
                                   ? QColor(klStrichFarbeStr) : QColor(0xe0, 0x70, 0x00);
            double klNx = -kDyW / kLenW, klNy = kDxW / kLenW;
            if (klNy > 0.0) { klNx = -klNx; klNy = -klNy; }
            if (adern.isEmpty()) continue;
            QJsonObject aderZuordnung = ed.value(QStringLiteral("aderZuordnung")).toObject();
            const QHash<QString, int> &gepoolt = gepoolteAderNrn(klq.value(5).toInt());

            struct Schnitt { double t; int segIdx; };
            QVector<Schnitt> schnitte;
            QSet<QString> gesehen;
            for (int i = 0; i < n; i++) {
                const QString &pot = raw[i].potenzial;
                if (!pot.isEmpty() && gesehen.contains(pot)) continue;
                double dax = raw[i].x2 - raw[i].x1, day = raw[i].y2 - raw[i].y1;
                double D = kDxW * day - kDyW * dax;
                if (std::abs(D) < 0.001) continue;
                double t = ((raw[i].x1 - kx1) * day - (raw[i].y1 - ky1) * dax) / D;
                double s = ((raw[i].x1 - kx1) * kDyW - (raw[i].y1 - ky1) * kDxW) / D;
                if (t >= -0.005 && t <= 1.005 && s >= -0.005 && s <= 1.005) {
                    schnitte.append({ std::clamp(t, 0.0, 1.0), i });
                    if (!pot.isEmpty()) gesehen.insert(pot);
                }
            }
            std::sort(schnitte.begin(), schnitte.end(),
                      [](const Schnitt &a, const Schnitt &b) { return a.t < b.t; });

            for (int si = 0; si < schnitte.size(); si++) {
                int segIdx = schnitte[si].segIdx;
                int aderNr = si + 1;
                QString aderKey = aderKeyFuerSeg(segIdx);
                bool gefunden = false;
                int  z = 0;
                if (!aderKey.isEmpty() && aderZuordnung.contains(aderKey)) {
                    z = aderZuordnung.value(aderKey).toInt(-1); gefunden = true;
                } else if (!raw[segIdx].potenzial.isEmpty() && aderZuordnung.contains(raw[segIdx].potenzial)) {
                    z = aderZuordnung.value(raw[segIdx].potenzial).toInt(-1); gefunden = true;
                }
                if (gefunden && z == 0) continue; // explizit "keine Ader" - weder Farbe noch Label
                if (gefunden) {
                    if (z > 0) aderNr = z;
                } else {
                    auto git = aderKey.isEmpty() ? gepoolt.constEnd() : gepoolt.constFind(aderKey);
                    if (git != gepoolt.constEnd()) aderNr = git.value();
                }
                QString farbe, farbe2;
                for (int ai = 0; ai < adern.size(); ai++) {
                    QJsonObject ao = adern.at(ai).toObject();
                    int nr = ao.contains(QStringLiteral("aderNr")) ? ao.value(QStringLiteral("aderNr")).toInt()
                                                                    : (ai + 1);
                    if (nr == aderNr) {
                        farbe  = ao.value(QStringLiteral("farbe")).toString();
                        farbe2 = ao.value(QStringLiteral("farbe2")).toString();
                        break;
                    }
                }
                // PDF-ADERBESCHRIFTUNG-POOL-01: Kreuzungslabel ("1  BK") mit
                // derselben Adernummer wie die Segmentfarbe unten - vorher
                // rechnete pdfKabelAderBeschriftungRendern() das Label separat
                // und einfacher (nur sci+1 pro Linie, nie gepoolt) aus, was zum
                // gemeldeten Auseinanderlaufen von Farbe und Beschriftung führte.
                if (aderLabelsOut) {
                    double t = schnitte[si].t;
                    QString label = QString::number(aderNr);
                    if (!farbe.isEmpty()) label += QStringLiteral("  ") + farbe;
                    aderLabelsOut->append({ kx1 + t * kDxW, ky1 + t * kDyW,
                                             klNx, klNy, label, klStrichFarbe });
                }
                if (farbe.isEmpty()) continue;
                kabelSegFarbe[segIdx] = pdfAderFarbeZuCanvas(farbe);
                if (!farbe2.isEmpty())
                    kabelSegFarbe2[segIdx] = pdfAderFarbeZuCanvas(farbe2);
            }
        }
    }
}

void direktFarben(const QVector<RawSeg> &raw, const QVector<Adp> &adps,
                  QVector<QColor> &direktFarbe, QVector<QColor> &direktFarbe2)
{
    const int n = raw.size();
    direktFarbe  = QVector<QColor>(n);
    direktFarbe2 = QVector<QColor>(n);
    // Direkte ADP-Farbe je Segment (erster Treffer, wie bisher). farbe2 (falls
    // gesetzt) wird parallel mitgeführt für die Bifarb-Ader-Darstellung.
    for (int i = 0; i < n; i++) {
        if (raw[i].signaltyp == QLatin1String("konflikt")) continue;
        for (const Adp &ad : adps) {
            if (pdfPunktAufSegment(ad.cx, ad.cy, raw[i].x1, raw[i].y1, raw[i].x2, raw[i].y2, 3.0)) {
                direktFarbe[i] = pdfAderFarbeZuCanvas(ad.farbe);
                if (!ad.farbe2.isEmpty())
                    direktFarbe2[i] = pdfAderFarbeZuCanvas(ad.farbe2);
                break;
            }
        }
    }
}

QVector<int> wurzelnJeSegment(int seiteId, const QSqlDatabase &db, const QVector<RawSeg> &raw)
{
    const int n = raw.size();
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

    QVector<int> wurzel(n);
    for (int i = 0; i < n; i++) wurzel[i] = find(i);
    return wurzel;
}

void berechneEndfarben(const QVector<RawSeg> &raw, const QVector<int> &wurzel,
                       const QVector<QColor> &direktFarbe, const QVector<QColor> &direktFarbe2,
                       const QVector<QColor> &kabelSegFarbe, const QVector<QColor> &kabelSegFarbe2,
                       QVector<QColor> &endFarbe, QVector<QColor> &endFarbe2)
{
    const int n = raw.size();
    // PDF-WINKEL-ADERFARBE-01 (Aug 2026): gruppenFarbe wurde bisher NUR aus
    // direktFarbe (ADP-Treffer) gespeist — ein Segment, das seine Farbe nur
    // über den Kabellinien-Fallback (kabelSegFarbe, normaler "Kabellinie
    // zeichnen + Adern eintragen"-Workflow ohne Aderdefinitionspunkt) hat,
    // gab diese Farbe dadurch nie an eine über winkel/querverweis
    // verbundene Gruppe weiter — im Canvas (CanvasRenderHandler.qml::
    // _segmentFarbeUndBreite()) läuft derselbe Kabellinien-Fallback bereits
    // VOR der winkel-Gruppierung und wird dadurch automatisch mitvererbt.
    // Zwei Durchgänge: zuerst direktFarbe (ADP hat Vorrang vor dem
    // Kabellinien-Fallback, falls eine Gruppe beides enthält), erst danach
    // Lücken aus kabelSegFarbe auffüllen.
    QHash<int, QColor> gruppenFarbe, gruppenFarbe2; // Wurzel → erste gefundene Aderfarbe/-farbe2
    for (int i = 0; i < n; i++) {
        if (direktFarbe[i].isValid() && !gruppenFarbe.contains(wurzel[i]))
            gruppenFarbe[wurzel[i]] = direktFarbe[i];
        if (direktFarbe2[i].isValid() && !gruppenFarbe2.contains(wurzel[i]))
            gruppenFarbe2[wurzel[i]] = direktFarbe2[i];
    }
    for (int i = 0; i < n; i++) {
        if (kabelSegFarbe[i].isValid() && !gruppenFarbe.contains(wurzel[i]))
            gruppenFarbe[wurzel[i]] = kabelSegFarbe[i];
        if (kabelSegFarbe2[i].isValid() && !gruppenFarbe2.contains(wurzel[i]))
            gruppenFarbe2[wurzel[i]] = kabelSegFarbe2[i];
    }

    endFarbe  = QVector<QColor>(n);
    endFarbe2 = QVector<QColor>(n);
    for (int i = 0; i < n; i++) {
        QColor clr = pdfSignaltypFarbe(raw[i].signaltyp);
        QColor clr2;
        if (raw[i].signaltyp != QLatin1String("konflikt")) {
            if (direktFarbe[i].isValid())              clr = direktFarbe[i];
            else if (gruppenFarbe.contains(wurzel[i]))    clr = gruppenFarbe[wurzel[i]];
            else if (kabelSegFarbe[i].isValid()) {
                // KABEL-ADERFARBE-01: kein Aderdefinitionspunkt getroffen –
                // Fallback auf die Kabellinien-Aderfarbe dieses Segments.
                clr = kabelSegFarbe[i];
                if (kabelSegFarbe2[i].isValid())
                    clr2 = kabelSegFarbe2[i];
            }
            if (direktFarbe2[i].isValid())              clr2 = direktFarbe2[i];
            else if (gruppenFarbe2.contains(wurzel[i]))    clr2 = gruppenFarbe2[wurzel[i]];
        }
        endFarbe[i]  = clr;
        endFarbe2[i] = clr2;
    }
}

QVector<TpKandidat> ladeTreffpunktKandidaten(int seiteId, const QSqlDatabase &db, const QVector<RawSeg> &raw)
{
    // Treffpunkt-/Treffpunkt_L-Ziel-Arm-Bänderung (VERBINDUNGSFARBE-03/04-
    // Port, WINKEL-DREHER-01-PDF Sep 2026 erweitert um Mehrfach-Winkel-
    // Propagation, TREFFPUNKT-MEHRFARB-MARKER-01 Sep 2026 erweitert um
    // Treffpunkt-VERKETTUNG): S1/S2-Pins geometrisch auf ihr jeweiliges
    // Segment matchen, bei unterschiedlicher (gleicher) Endfarbe den
    // Ziel-Arm zweifarbig (mit Trennlinie) markieren – und die Bänderung
    // per BFS über beliebig viele nachfolgende winkel-Elemente propagieren
    // (1:1-Port von _treffpunktZielBaender()/propagiere() in
    // CanvasRenderHandler.qml). Verkettung mehrerer TREFFPUNKTE (Ziel-Arm
    // eines Treffpunkts = Quell-Arm eines zweiten) wird jetzt ebenfalls
    // aufgelöst: eine Konvergenz-Schleife (1:1-Port des QML-Fixes für
    // TREFFPUNKT-MEHRFARB-MARKER-01, s. dortiger Kommentar) berechnet jeden
    // Kandidaten neu, solange sich armAnzahl/Modus ändern, statt ihn wie
    // vorher nach der ersten Berechnung dauerhaft zu sperren – bei
    // ungünstiger `kandidaten`-Reihenfolge (nachgelagerter Treffpunkt vor
    // seinem vorgelagerten) blieb die armAnzahl sonst zu niedrig eingefroren.
    // Ab armAnzahl>=3 "mehrfach"-Modus (einfarbige Linie + Zahl-Label,
    // s. PdfLeitungsSegment::mehrfach) statt 2-Band-Bänderung.
    QVector<TpKandidat> kandidaten;
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
                int s1i = segAnPunkt(raw, s1W), s2i = segAnPunkt(raw, s2W), zi = segAnPunkt(raw, zielW);
                if (s1i < 0 || s2i < 0 || zi < 0) continue;
                kandidaten.append({ s1i, s2i, zi, s1W });
            }
        }
    }
    return kandidaten;
}

void ladeWinkelListe(int seiteId, const QSqlDatabase &db, const QVector<RawSeg> &raw,
                     QVector<PdfWinkelInfo> &winkelListe,
                     QHash<int, QVector<QPair<int,int>>> &segAdj,
                     QHash<int, QVector<int>> &segZuWinkel)
{
    // WINKEL-DREHER-01-PDF: alle winkel-Elemente der Seite + welches
    // raw[]-Segment an welchem ihrer beiden Pins (lokal (0,0) bzw. (1,1))
    // anliegt — 1:1-Analogie zu net.segmente[].elIdxA/elIdxB +
    // _winkelAdjazenz() in CanvasGeometrie.qml, hier geometrisch statt über
    // einen elIdx-Graphen (PDF-Export hat keinen Live-Netzgraphen).
    {
        QSqlQuery wtq(db);
        wtq.prepare(R"(
            SELECT id, x1, y1, x2, y2, rotation, spiegel_x, spiegel_y
            FROM grafik_element WHERE seite_id = :sid AND typ = 'symbol' AND symbol_id = 'winkel'
        )");
        wtq.bindValue(":sid", seiteId);
        if (wtq.exec()) {
            while (wtq.next()) {
                PdfWinkelInfo w;
                w.id  = wtq.value(0).toInt();
                w.x1  = wtq.value(1).toDouble(); w.y1 = wtq.value(2).toDouble();
                w.x2  = wtq.value(3).toDouble(); w.y2 = wtq.value(4).toDouble();
                w.rot = wtq.value(5).toDouble();
                w.spX = wtq.value(6).toBool();   w.spY = wtq.value(7).toBool();
                QPointF p0 = pdfPinWeltPos(w.x1, w.y1, w.x2, w.y2, w.rot, w.spX, w.spY, 0.0, 0.0);
                QPointF p2 = pdfPinWeltPos(w.x1, w.y1, w.x2, w.y2, w.rot, w.spX, w.spY, 1.0, 1.0);
                w.segAmP0 = segAnPunkt(raw, p0);
                w.segAmP2 = segAnPunkt(raw, p2);
                winkelListe.append(w);
            }
        }
    }
    // Adjazenz: raw[]-Segmentindex → Liste von (Nachbarsegment, winkelListe-Index) —
    // nur für Winkel mit BEIDEN Pins verbunden (für die eigentliche
    // BFS-Weiterverfolgung; ein totes Kettenende hat ohnehin nichts, wohin
    // weitergegangen werden könnte).
    // Zusätzlich: raw[]-Segmentindex → Liste ALLER berührenden winkel-Indizes,
    // auch wenn der jeweils ANDERE Pin unverbunden ist (totes Kettenende) —
    // WINKEL-DREHER-01-PDF-Nachbesserung (direkter Nachtrag, 1:1-Port der
    // entsprechenden QML-Nachbesserung): ohne das bliebe die Umkehr-
    // Entscheidung für einen Winkel am Ende einer Kette unberechnet
    // (fällt sonst stillschweigend auf "kein Tausch" zurück).
    for (int wi = 0; wi < winkelListe.size(); wi++) {
        const PdfWinkelInfo &w = winkelListe[wi];
        if (w.segAmP0 >= 0 && w.segAmP2 >= 0) {
            segAdj[w.segAmP0].append({ w.segAmP2, wi });
            segAdj[w.segAmP2].append({ w.segAmP0, wi });
        }
        if (w.segAmP0 >= 0) segZuWinkel[w.segAmP0].append(wi);
        if (w.segAmP2 >= 0) segZuWinkel[w.segAmP2].append(wi);
    }
}

BandErgebnis propagiereBaenderung(const QVector<RawSeg> &raw,
                                  const QVector<QColor> &endFarbe, const QVector<QColor> &endFarbe2,
                                  const QVector<TpKandidat> &kandidaten,
                                  const QVector<PdfWinkelInfo> &winkelListe,
                                  const QHash<int, QVector<QPair<int,int>>> &segAdj,
                                  const QHash<int, QVector<int>> &segZuWinkel)
{
    const int n = raw.size();
    // Pro Segment vorberechnete Bänderungsinfo (statt nur für das eine
    // zielIdx-Segment wie bisher) + pro Winkel die Umkehr-Entscheidung.
    QVector<bool>   segGebaendert(n, false), segZweifarbig(n, false), segUmkehrV(n, false), segFlipV(n, false);
    QVector<QColor> segFarbeAV(n), segFarbeBV(n), segFarbeA2V(n), segFarbeB2V(n);
    QVector<double> segBreiteV(n, 0.0);
    QHash<int, bool> winkelUmkehren; // key: winkelListe-Index

    // TREFFPUNKT-MEHRFARB-MARKER-01 (Sep 2026, 1:1-Port von band.modus===
    // "mehrfach"/band.armAnzahl in _treffpunktZielBaender()): armAnzahl je
    // Ziel-Segment, damit eine Verkettung mehrerer Treffpunkte (Ziel-Arm
    // eines Treffpunkts = Quell-Arm eines zweiten) erkannt statt wie bisher
    // per zielIdxSet-Skip komplett übersprungen wird. Ab armAnzahl>=3
    // "mehrfach"-Modus (einfarbige Linie + Zahl-Label) statt 2-Band.
    QVector<bool> segMehrfach(n, false);
    QVector<int>  segArmAnzahlV(n, 0);
    QVector<int>  segModusV(n, 0);   // 0=unbestimmt, 1=gebaendert, 2=mehrfach — für den Konvergenzvergleich unten
    auto armAnzahlFuer = [&](int idx) -> int {
        return (segGebaendert[idx] || segMehrfach[idx]) ? segArmAnzahlV[idx] : 1;
    };

    // Konvergenz-Schleife statt Einzeldurchlauf (1:1-Port des QML-Fixes für
    // TREFFPUNKT-MEHRFARB-MARKER-01, s. ausführlicher Kommentar an
    // _treffpunktZielBaender() in CanvasRenderHandler.qml): wurde ein
    // Kandidat verarbeitet, BEVOR sein vorgelagerter Treffpunkt (falls s1/s2
    // selbst ein Ziel-Arm sind) an der Reihe war, sah er seinen Arm noch als
    // unverschmolzen (armAnzahlFuer()==1 statt der später korrekten 2) — bei
    // einem einmaligen Durchlauf (wie vorher) wäre dieses zu niedrige
    // Ergebnis für immer eingefroren geblieben. Jeder Kandidat wird jetzt
    // neu berechnet, solange sich armAnzahl/Modus seines Ziel-Segments
    // gegenüber der letzten Berechnung ändern; armAnzahl kann pro Runde nur
    // wachsen, Konvergenz bleibt innerhalb der Rundenzahl-Schranke garantiert.
    bool geaendert = true; int runden = 0;
    while (geaendert && runden < kandidaten.size() + 2) {
        geaendert = false; runden++;
        for (const TpKandidat &k : kandidaten) {
            if (!endFarbe[k.s1Idx].isValid() || !endFarbe[k.s2Idx].isValid()) continue;

            int  armAnzahl = armAnzahlFuer(k.s1Idx) + armAnzahlFuer(k.s2Idx);
            bool mehrfach  = armAnzahl >= 3;
            int  neuerModus = mehrfach ? 2 : 1;
            if (segModusV[k.zielIdx] == neuerModus && segArmAnzahlV[k.zielIdx] == armAnzahl)
                continue; // Konvergenz: keine Änderung gegenüber der letzten Berechnung

            QColor fa = endFarbe[k.s1Idx], fb = endFarbe[k.s2Idx];
            QColor fa2 = endFarbe2[k.s1Idx], fb2 = endFarbe2[k.s2Idx];
            // BIFARB-TREFFPUNKT-01: ein Arm gilt auch dann als "zweifarbig"
            // (zeichnet zwei Bänder statt einer Volllinie), wenn seine Farben
            // zufällig gleich sind, aber einer der Arme selbst bifarb ist —
            // sonst würde eine gültige Sekundärfarbe stillschweigend verworfen.
            // Nur relevant im 2-Band-Fall — im mehrfach-Fall gibt es ohnehin
            // nur eine Signalfarbe (band.farbe/farben[0]-Äquivalent).
            bool   zweifarbig = !mehrfach && (fa.name() != fb.name() || fa2.isValid() || fb2.isValid());
            double breiteWelt = pdfBreiteFuerAnzahl(mehrfach ? armAnzahl : 2, raw[k.zielIdx].signaltyp);
            double zdx = raw[k.zielIdx].x2 - raw[k.zielIdx].x1, zdy = raw[k.zielIdx].y2 - raw[k.zielIdx].y1;
            bool   flip0 = (zdx * (k.s1Welt.y() - raw[k.zielIdx].y1) - zdy * (k.s1Welt.x() - raw[k.zielIdx].x1)) >= 0.0;

            // BFS ab dem Ziel-Segment über segAdj — 1:1-Analogie zu propagiere()
            // in CanvasRenderHandler.qml. segUmkehrLokal[startSi]=false ist die
            // Basis (dort ist flip0 per Kreuzprodukt-Test bereits korrekt); an
            // jedem gekreuzten Winkel werden Winkel- UND Ausgangssegment-
            // Umkehrung GEMEINSAM aus derselben Berührpunkt-Geometrie berechnet
            // (_winkelDurchgang()-Äquivalent), konsistent mit dem bereits
            // akkumulierten Umkehr-Zustand des Eingangssegments.
            QVector<int> queue; QSet<int> visited;
            QHash<int, bool> segUmkehrLokal;
            queue.append(k.zielIdx);
            segUmkehrLokal[k.zielIdx] = false;
            for (int qi = 0; qi < queue.size(); qi++) {
                int cur = queue[qi];
                if (visited.contains(cur)) continue;
                visited.insert(cur);

                segGebaendert[cur] = !mehrfach;
                segMehrfach[cur]   = mehrfach;
                segModusV[cur]     = neuerModus;
                segArmAnzahlV[cur] = armAnzahl;
                segZweifarbig[cur] = zweifarbig;
                segFarbeAV[cur] = fa; segFarbeBV[cur] = fb;
                segFarbeA2V[cur] = mehrfach ? QColor() : fa2;
                segFarbeB2V[cur] = mehrfach ? QColor() : fb2;
                segFlipV[cur] = flip0;
                segUmkehrV[cur] = segUmkehrLokal.value(cur, false);
                segBreiteV[cur] = breiteWelt;

                // Beide berührenden Winkel dieses Segments direkt prüfen (auch
                // ohne Ausgangssegment, s. Kommentar an segZuWinkel oben) —
                // 1:1-Port der QML-Nachbesserung (curCands-Schleife in
                // propagiere()). winkelUmkehren ist rein geometrisch (hängt
                // nicht von armAnzahl ab) und bleibt daher bewusst über alle
                // Runden hinweg ein einmaliger Sperr-Cache (kein Konvergenz-
                // Vergleich nötig, anders als oben bei segModusV).
                for (int wi : segZuWinkel.value(cur)) {
                    if (winkelUmkehren.contains(wi)) continue;
                    const PdfWinkelInfo &w = winkelListe[wi];
                    QPointF p0 = pdfPinWeltPos(w.x1, w.y1, w.x2, w.y2, w.rot, w.spX, w.spY, 0.0, 0.0);
                    QPointF p1 = pdfPinWeltPos(w.x1, w.y1, w.x2, w.y2, w.rot, w.spX, w.spY, 0.0, 1.0);
                    QPointF p2 = pdfPinWeltPos(w.x1, w.y1, w.x2, w.y2, w.rot, w.spX, w.spY, 1.0, 1.0);
                    bool ankerIstP0 = (w.segAmP0 == cur);
                    double ankerDx = raw[cur].x2 - raw[cur].x1, ankerDy = raw[cur].y2 - raw[cur].y1;
                    if (segUmkehrV[cur]) { ankerDx = -ankerDx; ankerDy = -ankerDy; }
                    double legAnkerDx, legAnkerDy;
                    if (ankerIstP0) { legAnkerDx = p1.x()-p0.x(); legAnkerDy = p1.y()-p0.y(); }
                    else            { legAnkerDx = p2.x()-p1.x(); legAnkerDy = p2.y()-p1.y(); }
                    bool umk = (legAnkerDx*ankerDx + legAnkerDy*ankerDy) < 0.0;
                    winkelUmkehren[wi] = umk;

                    // Ausgangssegment (das jeweils andere Ende dieses Winkels) —
                    // -1, wenn dort nichts angeschlossen ist (totes Kettenende).
                    int ausgangSi = ankerIstP0 ? w.segAmP2 : w.segAmP0;
                    if (ausgangSi >= 0) {
                        double legAusgDx, legAusgDy;
                        if (ankerIstP0) { legAusgDx = p2.x()-p1.x(); legAusgDy = p2.y()-p1.y(); }
                        else            { legAusgDx = p1.x()-p0.x(); legAusgDy = p1.y()-p0.y(); }
                        if (umk) { legAusgDx = -legAusgDx; legAusgDy = -legAusgDy; }
                        double ausgDx = raw[ausgangSi].x2 - raw[ausgangSi].x1, ausgDy = raw[ausgangSi].y2 - raw[ausgangSi].y1;
                        if (!segUmkehrLokal.contains(ausgangSi))
                            segUmkehrLokal[ausgangSi] = (legAusgDx*ausgDx + legAusgDy*ausgDy) < 0.0;
                    }
                }

                for (const auto &nb : segAdj.value(cur)) {
                    int nbSeg = nb.first;
                    if (!visited.contains(nbSeg)) queue.append(nbSeg);
                }
            }
            geaendert = true;
        }
    }

    BandErgebnis res;
    res.segGebaendert = segGebaendert; res.segZweifarbig = segZweifarbig;
    res.segUmkehrV = segUmkehrV;       res.segFlipV = segFlipV;
    res.segMehrfach = segMehrfach;     res.segArmAnzahlV = segArmAnzahlV;
    res.segFarbeAV = segFarbeAV;       res.segFarbeBV = segFarbeBV;
    res.segFarbeA2V = segFarbeA2V;     res.segFarbeB2V = segFarbeB2V;
    res.segBreiteV = segBreiteV;       res.winkelUmkehren = winkelUmkehren;
    return res;
}

} // namespace


QVector<PdfLeitungsSegment> pdfLeitungenSammeln(int seiteId, double pxPerMm,
                                                        const QSqlDatabase &db,
                                                        QVector<PdfKabelAderLabel> *aderLabelsOut,
                                                        QHash<int, bool> *winkelUmkehrenOut)
{
    QVector<PdfLeitungsSegment> segs;

    const QVector<Adp>    adps = ladeAderdefinitionspunkte(seiteId, db);
    const QVector<RawSeg> raw  = ladeRohSegmente(seiteId, db);
    const int n = raw.size();
    if (n == 0) return segs;

    // KABEL-ADERFARBE-01 (PDF-Parität, Aug 2026): Fallback-Aderfarbe aus der
    // Kabellinien-Aderzuordnung (grafik_element.extra_daten.{adern, aderZuordnung}
    // der Kabellinie selbst) für Segmente ohne eigenen Aderdefinitionspunkt —
    // dieselbe Datenquelle wie im Canvas (CanvasRenderHandler.qml::
    // _sammleKabelAderFarben()), NICHT die kabel_ader-DB-Tabelle (Details in den
    // Kommentaren von kabellinienAderfarben()).
    QVector<QColor> kabelSegFarbe(n), kabelSegFarbe2(n);
    {
        const SymbolGraph graph = baueSymbolGraph(seiteId, db, raw);
        kabellinienAderfarben(seiteId, db, raw, graph, kabelSegFarbe, kabelSegFarbe2, aderLabelsOut);
    }

    QVector<QColor> direktFarbe, direktFarbe2;
    direktFarben(raw, adps, direktFarbe, direktFarbe2);

    const QVector<int> wurzel = wurzelnJeSegment(seiteId, db, raw);

    QVector<QColor> endFarbe, endFarbe2;
    berechneEndfarben(raw, wurzel, direktFarbe, direktFarbe2, kabelSegFarbe, kabelSegFarbe2,
                      endFarbe, endFarbe2);

    const QVector<TpKandidat> kandidaten = ladeTreffpunktKandidaten(seiteId, db, raw);
    QVector<PdfWinkelInfo> winkelListe;
    QHash<int, QVector<QPair<int,int>>> segAdj;
    QHash<int, QVector<int>> segZuWinkel;
    ladeWinkelListe(seiteId, db, raw, winkelListe, segAdj, segZuWinkel);

    const BandErgebnis band = propagiereBaenderung(raw, endFarbe, endFarbe2, kandidaten,
                                                   winkelListe, segAdj, segZuWinkel);

    if (winkelUmkehrenOut) {
        winkelUmkehrenOut->clear();
        for (auto it = band.winkelUmkehren.constBegin(); it != band.winkelUmkehren.constEnd(); ++it)
            winkelUmkehrenOut->insert(winkelListe[it.key()].id, it.value());
    }

    segs.reserve(n);
    for (int i = 0; i < n; i++) {
        PdfLeitungsSegment s;
        s.cx1 = raw[i].x1; s.cy1 = raw[i].y1; s.cx2 = raw[i].x2; s.cy2 = raw[i].y2;
        s.verbId = raw[i].verbId;
        s.color  = endFarbe[i];
        s.farbe2 = endFarbe2[i]; // nur gueltig wenn eine Bifarb-ADP getroffen wurde
        s.lw     = qMax(0.3, 1.5 * 0.25 * pxPerMm);

        if (band.segGebaendert[i]) {
            s.gebaendert = true;
            s.zweifarbig = band.segZweifarbig[i];
            s.farbeA = band.segFarbeAV[i]; s.farbeB = band.segFarbeBV[i];
            s.farbeA2 = band.segFarbeA2V[i]; s.farbeB2 = band.segFarbeB2V[i];
            s.flip   = band.segFlipV[i];
            s.segUmkehr = band.segUmkehrV[i];
            s.lw = qMax(0.3, band.segBreiteV[i] * 0.25 * pxPerMm);
            s.color = s.farbeA; // Fallback für die Treffpunkt-Symbolfarbe (pdfSegmentFuerPunkt, s.u.)
        } else if (band.segMehrfach[i]) {
            // TREFFPUNKT-MEHRFARB-MARKER-01: ≥3 verschmolzene Adern – keine
            // 2-Band-Bänderung (gebaendert bleibt false, pdfMaleGebaenderteLinie()
            // zeichnet dadurch automatisch eine einfarbige Linie), stattdessen
            // Zahl-Label in pdfLeitungenRendern().
            s.mehrfach  = true;
            s.armAnzahl = band.segArmAnzahlV[i];
            s.color     = band.segFarbeAV[i]; // erste der ≥3 beteiligten Farben, wie band.farbe=farben[0] im Canvas
            s.lw        = qMax(0.3, band.segBreiteV[i] * 0.25 * pxPerMm);
            // s.farbe2 (oben unconditional aus endFarbe2[i] gesetzt) hier
            // bewusst zurücksetzen: pdfMaleGebaenderteLinie() prüft
            // "!s.gebaendert && s.farbe2.isValid()" zuerst — ohne diesen Reset
            // würde ein Segment, das zufällig ZUSÄTZLICH einen eigenen
            // Bifarb-Aderdefinitionspunkt trägt, zweifarbig-gestreift statt
            // als einfarbige mehrfach-Linie gezeichnet.
            s.farbe2 = QColor();
        }
        segs.append(s);
    }
    return segs;
}

// Nächstgelegenes Segment zu einem Punkt (Canvas-Einheiten) – gleiche Technik
// wie das geometrische Matching in Database_Klemmen.cpp (klemmlistenauszug).
// WINKEL-FARBE-01 (Sep 2026): gibt jetzt den vollen Segment-Zeiger zurück
// (statt nur Farbe+Breite), damit der Winkel-Zeichenpfad auch
// gebaendert/zweifarbig/farbeA/farbeB/refPunkt auswerten kann.
const PdfLeitungsSegment *pdfSegmentPtrFuerPunkt(double cx, double cy,
                                const QVector<PdfLeitungsSegment> &segs)
{
    const double TOL = 2.0;   // Canvas-Einheiten (0.5 mm)
    for (const PdfLeitungsSegment &s : segs) {
        if (pdfPunktAufSegment(cx, cy, s.cx1, s.cy1, s.cx2, s.cy2, TOL))
            return &s;
    }
    return nullptr;
}

// Aderbezeichnungen an Kabellinie-Schnittpunkten rendern
// PDF-ADERBESCHRIFTUNG-POOL-01 (Aug 2026): reiner Renderer, keine eigene
// Kreuzungserkennung mehr — die Labels (Weltposition, Normalenvektor, fertiger
// Text, Linienfarbe) kommen jetzt vorberechnet aus pdfLeitungenSammeln(), das
// dieselbe aderKey-/kabel_ader-gepoolte Adernummer wie die Segmentfärbung
// verwendet. Vorher betrieb diese Funktion eine dritte, eigene (nur nach
// verbindung_id dedupliziende, nie gepoolte) Kreuzungserkennung — dadurch lief
// die angezeigte Nummer bei mehrseitigen/mehrlinigen Kabeln auseinander:
// jede Linie zeigte unabhängig 1,2,3,… statt der kabelweit fortlaufenden
// Nummer, wie sie die Segmentfarbe (kabelSegFarbe) längst korrekt nutzte.
void pdfKabelAderBeschriftungRendern(QPainter &p, double C, double pxPerMm,
                                           const QVector<PdfKabelAderLabel> &labels)
{
    if (labels.isEmpty()) return;

    double fsDev   = 1.8 * pxPerMm;
    double tickLen = 0.5 * pxPerMm;
    double lblOff  = tickLen + 0.4 * pxPerMm;

    QFont f; f.setFamily(QStringLiteral("sans-serif"));
    f.setPixelSize(qMax(1, qRound(fsDev)));

    p.save();
    p.setBrush(Qt::NoBrush);
    p.setFont(f);

    for (const PdfKabelAderLabel &lbl : labels) {
        double vx = lbl.wx * C, vy = lbl.wy * C;

        // Kurzer Querstrich
        QPen tickPen(lbl.klColor, 0.4 * pxPerMm, Qt::SolidLine, Qt::FlatCap);
        p.setPen(tickPen);
        p.drawLine(QLineF(vx - lbl.nx * tickLen, vy - lbl.ny * tickLen,
                          vx + lbl.nx * tickLen, vy + lbl.ny * tickLen));

        // Label — achsenparallele Kabellinie: rechts neben dem Tick (wie QML)
        p.setPen(lbl.klColor);
        bool achsenParallel = (std::abs(lbl.nx) < 0.1 || std::abs(lbl.ny) < 0.1);
        double lx, ly;
        if (achsenParallel) {
            lx = vx + lblOff;               // immer rechts
            ly = vy + lbl.ny * lblOff;      // Offset senkrecht zur Linie
        } else {
            lx = vx + lbl.nx * lblOff;
            ly = vy + lbl.ny * lblOff;
        }
        Qt::Alignment ha = Qt::AlignLeft;
        double tw = 15.0 * pxPerMm;
        // Rect mit textBaseline "bottom" (QML-Konvention: Text wächst nach oben von ly)
        QRectF r(lx, ly - fsDev * 1.2, tw, fsDev * 1.2);
        p.drawText(r, ha | Qt::AlignBottom, lbl.label);
    }
    p.restore();
}

// Verbindungsleitungen aus verbindung_segment rendern (segs vorab per
// pdfLeitungenSammeln geladen – gemeinsam genutzt mit der Winkel/Treffpunkt-
// Farbübernahme in pdfElementRendern).
void pdfLeitungenRendern(QPainter &p, double C, double pxPerMm,
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

        auto it = crossings.constFind(i);
        if (it == crossings.constEnd() || it->isEmpty()) {
            // Kein Kreuzungspunkt: normal zeichnen
            pdfMaleGebaenderteLinie(p, s.cx1*C, s.cy1*C, s.cx2*C, s.cy2*C, s, pxPerMm);
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
                    pdfMaleGebaenderteLinie(p, pos*C, hy*C, ls*C, hy*C, s, pxPerMm);
                pos = le;
            }
            if (pos < hx2)
                pdfMaleGebaenderteLinie(p, pos*C, hy*C, hx2*C, hy*C, s, pxPerMm);
        }

        // TREFFPUNKT-MEHRFARB-MARKER-01 (Sep 2026, 1:1-Port des Canvas-
        // Zahl-Labels, s. CanvasRenderHandler.qml::_zahlLabelPosition()):
        // "armAnzahl*" senkrecht zur Segmentrichtung versetzt, damit die
        // (ggf. mehrere Punkt breite) Linie selbst das Label nicht verdeckt.
        if (s.mehrfach) {
            double mx = (s.cx1 + s.cx2) / 2.0 * C;
            double my = (s.cy1 + s.cy2) / 2.0 * C;
            bool   istVert  = qAbs(s.cx2 - s.cx1) < 0.5;
            double versatz  = s.lw / 2.0 + 2.0 * pxPerMm;
            double fsDev    = 2.2 * pxPerMm;
            QFont f; f.setFamily(QStringLiteral("sans-serif")); f.setBold(true);
            f.setPixelSize(qMax(1, qRound(fsDev)));
            QString text = QString::number(s.armAnzahl) + QStringLiteral("*");
            double  tw    = QFontMetricsF(f).horizontalAdvance(text);
            p.save();
            p.setFont(f);
            p.setPen(s.color);
            if (istVert) {
                QRectF r(mx + versatz, my - fsDev * 0.6, tw + 2.0, fsDev * 1.2);
                p.drawText(r, Qt::AlignLeft | Qt::AlignVCenter, text);
            } else {
                QRectF r(mx - tw / 2.0 - 1.0, my - versatz - fsDev * 1.2, tw + 2.0, fsDev * 1.2);
                p.drawText(r, Qt::AlignHCenter | Qt::AlignBottom, text);
            }
            p.restore();
        }
    }
}
