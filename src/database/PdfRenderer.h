#pragma once
// ============================================================
// PdfRenderer.h – interne Schnittstelle der PDF-Rendering-Dateien
// (PdfRenderer_*.cpp). Nur von src/database/ nutzen; keine öffentliche API.
//
// Aufteilung (Refactor Okt 2026, vorher eine Datei Database_PDF.cpp):
//   PdfRenderer_Basis       Farben, Stifte, Symbol-/Primitiv-Zeichnung, Pin-Helfer
//   PdfRenderer_Leitungen   Leitungssegmente sammeln/zeichnen, Treffpunkt-Arme, Aderbeschriftung
//   PdfRenderer_Symbol      Symbol-Element (Beschriftung, Pin-Bezeichnungen, Querverweise)
//   PdfRenderer_Elemente    übrige Element-Typen + Dispatcher pdfElementRendern()
//   PdfRenderer_Normblatt   Normblatt, Infostreifen, Revisions-Wasserzeichen, Bounding-Box
//   Database_PDF.cpp        öffentliche Database-Methoden (canvasPdfExportieren/-SeiteExportieren)
// ============================================================
#include <QColor>
#include <QHash>
#include <QJsonObject>
#include <QPainter>
#include <QPen>
#include <QSqlDatabase>
#include <QString>
#include <QVariantMap>
#include <QVector>

// Verbindungssegment für die Winkel/Treffpunkt-Farbübernahme (s.u.) und für
// pdfLeitungenRendern. Koordinaten in Canvas-Einheiten (1 Einheit = 0.25 mm),
// noch nicht mit C multipliziert.
// VERBINDUNGSFARBE-03/04-Port (Jul 2026): gebaendert/zweifarbig/farbeA/farbeB/
// refPunkt bilden die Treffpunkt-Ziel-Arm-Bänderung ab (1:1-Port von
// _treffpunktZielBaender()/_maleGebaenderteLinie() in CanvasRenderHandler.qml).
struct PdfLeitungsSegment {
    double cx1, cy1, cx2, cy2;
    int    verbId;
    QColor color;
    double lw;   // Linienbreite in Device-Pixeln (bei gebaendert: Vollbreite, s.u.)

    bool    gebaendert = false;   // true: Ziel-Arm eines Treffpunkts mit 2 Adern
    bool    zweifarbig = false;   // true: farbeA/farbeB nebeneinander; false: eine Volllinie in farbeA
    QColor  farbeA, farbeB;       // bei zweifarbig: farbeA auf der Seite mit flip==false
    // BIFARB-TREFFPUNKT-01 (Sep 2026, 1:1-Port von band.farben2 in
    // CanvasRenderHandler.qml): ist einer der beiden am Treffpunkt
    // zusammenlaufenden Arme selbst eine bifarb Ader (aderfarbe2), trägt
    // farbeA2/farbeB2 (nur das jeweils passende gültig) ihre Sekundärfarbe —
    // pdfMaleGebaenderteLinie()/pdfMaleWinkelGebaendert() zeichnen DIESES
    // Band dann alternierend statt einfarbig, das andere Band bleibt
    // unverändert.
    QColor  farbeA2, farbeB2;
    QPointF refPunkt;             // Weltkoordinate (Canvas-Einheiten) des S1-Pins (nur zur Berechnung von flip)
    // WINKEL-FARBE-01 (Sep 2026): EINMAL beim Aufbau dieses Segments per
    // Kreuzprodukt-Test gegen refPunkt bestimmt und danach als fester Wert
    // verwendet (1:1-Port der QML-Nachbesserung, s. _treffpunktZielBaender()
    // in CanvasRenderHandler.qml) — eine erneute Berechnung pro Aufrufer
    // (frühere Fassung) konnte an einem 90°-Knick (Winkel) ein anderes
    // Ergebnis liefern als am Segment selbst, sichtbar als Farbtausch/
    // -kreuzung direkt am Winkel.
    bool    flip = false;
    // WINKEL-DREHER-01-PDF (Sep 2026, 1:1-Port des vierten/finalen QML-Fixes,
    // s. Kommentar an pdfLeitungenSammeln()): pro-Segment-Umkehrung, analog
    // band.segUmkehr in CanvasRenderHandler.qml — flip ist für die GANZE
    // propagierte Winkel-Kette fest, aber ein einzelnes gerades Segment kann
    // "rückwärts" (cx2/cy2→cx1/cy1 statt in Kettenrichtung) gespeichert sein;
    // pdfMaleGebaenderteLinie() muss dann effektiv mit invertiertem flip
    // zeichnen, um am Übergang zum Nachbarsegment/Winkel konsistent zu bleiben.
    bool    segUmkehr = false;

    // Bifarb-Ader (aderfarbe2, z.B. PE oder DIN-47100-Bifarben): einzelne Ader
    // mit zweifarbiger Isolierung, als Strich-Alternierung gezeichnet – NICHT
    // zu verwechseln mit obiger Treffpunkt-Bänderung (zwei verschiedene Adern
    // treffen sich). Nur gesetzt wenn !gebaendert (Bänderung hat Vorrang).
    QColor  farbe2;

    // TREFFPUNKT-MEHRFARB-MARKER-01 (Sep 2026, 1:1-Port von
    // band.modus==="mehrfach"/band.armAnzahl in _treffpunktZielBaender()):
    // ≥3 an einem Treffpunkt-Ziel-Arm zusammenlaufende Adern (Verkettung
    // mehrerer Treffpunkte) lassen sich nicht mehr als 2-Band-Bänderung
    // darstellen – stattdessen einfarbige Linie (color/lw wie unten) PLUS
    // Zahl-Label ("armAnzahl*", Sternchen wie im Canvas) in
    // pdfLeitungenRendern(). gebaendert bleibt dabei false.
    bool mehrfach  = false;
    int  armAnzahl = 0;
};

// PDF-ADERNUMMER-POOL-01/PDF-ADERBESCHRIFTUNG-POOL-01 (Aug 2026): Ader-Kreuzungslabel
// ("1 BK") für eine Kabellinie — vorberechnet in pdfLeitungenSammeln() (das dort
// bereits die korrekte, aderKey-/kabel_ader-gepoolte Adernummer ermittelt, s.
// dort), damit pdfKabelAderBeschriftungRendern() nur noch zeichnet statt selbst
// eine dritte, simplere (und bis dahin falsche) Kreuzungserkennung zu betreiben.
struct PdfKabelAderLabel {
    double  wx, wy;      // Weltposition des Kreuzungspunkts (Canvas-Einheiten)
    double  nx, ny;      // Normalenvektor senkrecht zur Kabellinie ("nach oben")
    QString label;       // fertiger Anzeigetext, z.B. "1  BK"
    QColor  klColor;     // Farbe der Kabellinie selbst (strich_farbe), für Tick+Text
};

// Lokale (unrotierte) Pin-Koordinaten je Symboltyp, aus symbole.sql
// (symbol_pin) übernommen – nur die für die Winkel-/Treffpunkt-Propagation
// relevanten Typen.
struct PdfPinDef { QString name; double px, py; };

// ── Bounding-Box einer Seite berechnen (für vollCanvas-Modus) ───────────────
struct PdfBBox { double txCu, tyCu, bMm, hMm; };

// ── Funktionen (Definitionen in den PdfRenderer_*.cpp) ──────────────────────
QColor pdfFarbe(const QString &s, const QColor &def = Qt::black);
QColor pdfAderFarbeZuCanvas(const QString &code);
QColor pdfSignaltypFarbe(const QString &sig);
QPen pdfPen(const QVariantMap &el, double lw_dev);
void pdfSymbolRendern(QPainter &p, const QString &symbolId,
                      double x, double y, double sw, double sh,
                      int rotation, bool spiegelX, bool spiegelY,
                      const QPen &pen, const QSqlDatabase &db);
QPointF pdfPinWeltPos(double x1, double y1, double x2, double y2,
                       double rotation, bool spiegelX, bool spiegelY,
                       double pinX, double pinY);
QVector<PdfPinDef> pdfPinsFuerTyp(const QString &symbolId);
double pdfBreiteFuerAnzahl(int anz, const QString &signaltyp);
void pdfMaleWinkel(QPainter &p, double w, double h, const QPen &pen);
void pdfMaleWinkelGebaendert(QPainter &p, QPointF vp0, QPointF vp1, QPointF vp2,
                              const PdfLeitungsSegment &s);
void pdfTreffpunktArmeRendern(QPainter &p, const QString &symbolId, double w, double h,
                              double lwBasis, const PdfLeitungsSegment *s1Seg,
                              const PdfLeitungsSegment *s2Seg,
                              const PdfLeitungsSegment *zielSeg);
bool pdfPunktAufSegment(double cx, double cy,
                        double sx1, double sy1, double sx2, double sy2, double tol);
QVector<PdfLeitungsSegment> pdfLeitungenSammeln(int seiteId, double pxPerMm,
                                                 const QSqlDatabase &db,
                                                 QVector<PdfKabelAderLabel> *aderLabelsOut = nullptr,
                                                 QHash<int, bool> *winkelUmkehrenOut = nullptr);
const PdfLeitungsSegment *pdfSegmentPtrFuerPunkt(double cx, double cy,
                         const QVector<PdfLeitungsSegment> &segs);
void pdfElementSymbolRendern(QPainter &p, const QVariantMap &el,
                              double C, double pxPerMm, const QSqlDatabase &db,
                              const QVector<PdfLeitungsSegment> *leitungsSegs,
                              int seiteId,
                              const QHash<int, bool> *winkelUmkehrenMap = nullptr);
void pdfElementRendern(QPainter &p, const QVariantMap &el,
                        double C, double pxPerMm, const QSqlDatabase &db,
                        const QVector<PdfLeitungsSegment> *leitungsSegs = nullptr,
                        int seiteId = -1,
                        const QHash<int, bool> *winkelUmkehrenMap = nullptr);
void pdfKabelAderBeschriftungRendern(QPainter &p, double C, double pxPerMm,
                                    const QVector<PdfKabelAderLabel> &labels);
void pdfLeitungenRendern(QPainter &p, double C, double pxPerMm,
                         const QVector<PdfLeitungsSegment> &segs);
void pdfNormblattRendern(QPainter &p, const QVariantMap &nb, double pxPerMm);
void pdfInfostreifenRendern(QPainter &p, const QVariantMap &nb,
                             double bMm, double hMm, double pxPerMm);
void pdfRevisionswasserzeichenRendern(QPainter &p, const QVariantMap &nb,
                                       double bMm, double hMm, double pxPerMm);
PdfBBox pdfBoundingBox(int seiteId, double normBMm, double normHMm,
                        const QSqlDatabase &db);
