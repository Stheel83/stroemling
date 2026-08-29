#include "Database.h"
#include <cmath>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QHash>
#include <QPair>
#include <QPointF>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <algorithm>

// ============================================================
// kabelAnlegen
// Legt einen neuen kabel-Datensatz an und verknüpft ihn mit
// dem grafik_element der Kabeldefinitionslinie.
// Gibt die neue kabel-ID zurück oder -1 bei Fehler.
// ============================================================
int Database::kabelAnlegen(int projektId, const QString &bezeichnung,
                           const QString &kabeltyp, int aderzahl,
                           double querschnittMm2, int grafikElementId,
                           const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO kabel (projekt_id, bezeichnung, kabeltyp, aderzahl,
                           querschnitt_mm2, grafik_element_id, von_ort, nach_ort)
        VALUES (:pid, :bez, :typ, :anz, :qs, :geid, :von, :nach)
    )");
    q.bindValue(":pid",  projektId);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":geid", grafikElementId > 0 ? grafikElementId : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAnlegen fehlgeschlagen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ============================================================
// kabelAderZuordnen
// Legt eine kabel_ader-Zeile an (oder aktualisiert sie falls
// ader_nr für dieses Kabel bereits vorhanden).
// ============================================================
bool Database::kabelAderZuordnen(int kabelId, int aderNr,
                                 const QString &farbe,
                                 const QString &farbe2,
                                 const QString &bezeichnung,
                                 int verbindungId,
                                 int kabellinieGrafikElementId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id FROM kabel_ader WHERE kabel_id=:kid AND ader_nr=:nr");
    q.bindValue(":kid", kabelId);
    q.bindValue(":nr",  aderNr);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAderZuordnen SELECT:" << q.lastError().text();
        return false;
    }
    if (q.next()) {
        int existingId = q.value(0).toInt();
        QSqlQuery upd;
        upd.prepare(R"(
            UPDATE kabel_ader SET farbe=:f, farbe2=:f2, bezeichnung=:b, verbindung_id=:vid,
                                  kabellinie_grafik_element_id=:lgeid
            WHERE id=:id
        )");
        upd.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        upd.bindValue(":f2",    farbe2.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe2);
        upd.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        upd.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":id",    existingId);
        if (!upd.exec()) {
            qCWarning(lcDb) << "kabelAderZuordnen UPDATE:" << upd.lastError().text();
            return false;
        }
    } else {
        QSqlQuery ins;
        ins.prepare(R"(
            INSERT INTO kabel_ader (kabel_id, ader_nr, farbe, farbe2, bezeichnung,
                                   verbindung_id, kabellinie_grafik_element_id)
            VALUES (:kid, :nr, :f, :f2, :b, :vid, :lgeid)
        )");
        ins.bindValue(":kid",   kabelId);
        ins.bindValue(":nr",    aderNr);
        ins.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        ins.bindValue(":f2",    farbe2.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe2);
        ins.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        ins.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        ins.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        if (!ins.exec()) {
            qCWarning(lcDb) << "kabelAderZuordnen INSERT:" << ins.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// kabelAderLinieSynchronisieren
// KABEL-ADERFARBE-PROPAGATION-03: kabel_ader für EINE Kabellinie mit ihren
// aktuell tatsächlichen Kreuzungen abgleichen. s. Database.h für Details.
// ============================================================
bool Database::kabelAderLinieSynchronisieren(int kabelId, int kabellinieGrafikElementId,
                                             const QVariantList &aktive)
{
    if (kabelId <= 0 || kabellinieGrafikElementId <= 0) return false;

    QSet<int> aktiveNrn;
    for (const QVariant &v : aktive)
        aktiveNrn.insert(v.toMap().value(QStringLiteral("aderNr")).toInt());

    // Freigeben: Adern, die bisher dieser Linie zugeordnet waren, jetzt aber
    // nicht mehr in "aktive" auftauchen (Linie verschoben/gekürzt, kreuzt
    // diese Verbindung nicht mehr).
    QSqlQuery sel(m_db);
    sel.prepare(R"(
        SELECT ader_nr FROM kabel_ader
        WHERE kabel_id = :kid AND kabellinie_grafik_element_id = :geid
    )");
    sel.bindValue(":kid",  kabelId);
    sel.bindValue(":geid", kabellinieGrafikElementId);
    if (!sel.exec()) {
        qCWarning(lcDb) << "kabelAderLinieSynchronisieren SELECT:" << sel.lastError().text();
        return false;
    }
    QList<int> alteNrn;
    while (sel.next()) alteNrn.append(sel.value(0).toInt());

    for (int nr : alteNrn) {
        if (aktiveNrn.contains(nr)) continue;
        QSqlQuery upd(m_db);
        upd.prepare(R"(
            UPDATE kabel_ader SET verbindung_id = NULL, kabellinie_grafik_element_id = NULL
            WHERE kabel_id = :kid AND ader_nr = :nr
        )");
        upd.bindValue(":kid", kabelId);
        upd.bindValue(":nr",  nr);
        if (!upd.exec())
            qCWarning(lcDb) << "kabelAderLinieSynchronisieren Freigabe:" << upd.lastError().text();
    }

    // Aktive Zuordnungen schreiben (Update-oder-Insert wie kabelAderZuordnen()).
    for (const QVariant &v : aktive) {
        QVariantMap m = v.toMap();
        kabelAderZuordnen(kabelId, m.value(QStringLiteral("aderNr")).toInt(),
                           m.value(QStringLiteral("farbe")).toString(),
                           m.value(QStringLiteral("farbe2")).toString(),
                           m.value(QStringLiteral("bezeichnung")).toString(),
                           m.value(QStringLiteral("verbindungId")).toInt(),
                           kabellinieGrafikElementId);
    }
    return true;
}

// ============================================================
// KABEL-ADERFARBE-PROPAGATION-04: seitenübergreifende Ader-Poolung.
// Kreuzungs-Geometrie 1:1 an pdfLeitungenSammeln() (Database_PDF.cpp)
// angelehnt — Stabiler-Punkt-Walk + Segment-Adjazenz aus
// verbindung_segment/verbindung statt Live-QML-Netzgraph, da diese
// Funktion auch für gerade nicht offene Seiten arbeiten muss. Damit
// bereits DREI Kopien derselben Kern-Logik (QML: CanvasNetzberechnung.qml/
// CanvasGeometrie.qml, PDF: Database_PDF.cpp, hier) — bewusste
// Design-Entscheidung statt eines gemeinsamen Moduls, s. Konzeptdatei
// 05_leitungen_kabel.md §6.5.3/§6.5.4 für die Abwägung. Muss bei
// Änderungen an einer der drei Kopien mit den anderen zwei synchron
// gehalten werden.
// ============================================================
namespace {

struct KaSymElement {
    QString     symbolId;
    double      x1 = 0, y1 = 0, x2 = 0, y2 = 0;
    double      rotation = 0;
    bool        spiegelX = false, spiegelY = false;
    QJsonObject extraDaten;
};

const QSet<QString> &kaRoutingSymbolTypen()
{
    static const QSet<QString> s = { QStringLiteral("winkel"), QStringLiteral("treffpunkt"),
                                      QStringLiteral("treffpunkt_l"), QStringLiteral("aderdefinition") };
    return s;
}

// 1:1-Port von pinWeltPos() (SymbolDefinitionModel.cpp) / pdfPinWeltPos()
// (Database_PDF.cpp) — muss synchron gehalten werden.
QPointF kaPinWeltPos(double x1, double y1, double x2, double y2,
                      double rotation, bool spiegelX, bool spiegelY,
                      double pinX, double pinY)
{
    const double sw = x2 - x1, sh = y2 - y1;
    const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
    double cx = (pinX - 0.5) * std::abs(sw);
    double cy = (pinY - 0.5) * std::abs(sh);
    if (spiegelX) cx = -cx;
    if (spiegelY) cy = -cy;
    const double rot = rotation * M_PI / 180.0;
    return { scx + cx * std::cos(rot) - cy * std::sin(rot),
             scy + cx * std::sin(rot) + cy * std::cos(rot) };
}

// 1:1-Port von pdfStabilerPunktSchluessel().
QString kaStabilerPunktSchluessel(int elIdx, const QString &pinName,
                                   const QVector<KaSymElement> &els,
                                   const QVector<KaSymElement> &geraetekaesten)
{
    if (elIdx < 0 || elIdx >= els.size()) return {};
    const KaSymElement &el  = els[elIdx];
    const QString      &sid = el.symbolId;

    if (sid == QLatin1String("geraeteanschluss")) {
        QString ank = el.extraDaten.value(QStringLiteral("anschlusskennzeichnung")).toString();
        if (ank.isEmpty()) return {};
        double cx = (el.x1 + el.x2) / 2.0, cy = (el.y1 + el.y2) / 2.0;
        const KaSymElement *best = nullptr;
        double bestA = std::numeric_limits<double>::infinity();
        for (const KaSymElement &gk : geraetekaesten) {
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

// 1:1-Port von pdfNaechsterStabilerPunkt().
QString kaNaechsterStabilerPunkt(int elIdx, int vonIdx, const QString &pinName,
                                  const QHash<int, QVector<QPair<int, QString>>> &adj,
                                  const QVector<KaSymElement> &els,
                                  const QVector<KaSymElement> &geraetekaesten,
                                  int tiefe)
{
    if (tiefe <= 0 || elIdx < 0) return {};
    QString stabil = kaStabilerPunktSchluessel(elIdx, pinName, els, geraetekaesten);
    if (!stabil.isEmpty()) return stabil;
    if (elIdx >= els.size() || !kaRoutingSymbolTypen().contains(els[elIdx].symbolId)) return {};
    auto it = adj.find(elIdx);
    if (it == adj.end()) return {};
    for (const auto &nb : it.value()) {
        if (nb.first != vonIdx)
            return kaNaechsterStabilerPunkt(nb.first, elIdx, nb.second, adj, els, geraetekaesten, tiefe - 1);
    }
    return {};
}

struct KaRawSeg { double x1, y1, x2, y2; int verbindungId; QString potenzial; };

// Alle für die Kreuzungs-/Ader-Schlüssel-Berechnung nötigen Daten EINER Seite.
struct KaSeitenDaten {
    QVector<KaRawSeg>     raw;
    QVector<int>          segElA, segElB;
    QVector<QString>      segPinA, segPinB;
    QHash<int, QVector<QPair<int, QString>>> adj;
    QVector<KaSymElement> els, geraetekaesten;
    QHash<int, QString>   aderKeyCache;

    QString aderKeyFuerSeg(int segIdx)
    {
        auto it = aderKeyCache.find(segIdx);
        if (it != aderKeyCache.end()) return it.value();
        QString seiteA = kaNaechsterStabilerPunkt(segElA[segIdx], segElB[segIdx], segPinA[segIdx],
                                                    adj, els, geraetekaesten, 20);
        QString seiteB = kaNaechsterStabilerPunkt(segElB[segIdx], segElA[segIdx], segPinB[segIdx],
                                                    adj, els, geraetekaesten, 20);
        QStringList teile;
        if (!seiteA.isEmpty()) teile << seiteA;
        if (!seiteB.isEmpty()) teile << seiteB;
        teile.sort();
        QString key = teile.join(QStringLiteral("|"));
        aderKeyCache[segIdx] = key;
        return key;
    }
};

bool kaSeiteLaden(const QSqlDatabase &db, int seiteId, KaSeitenDaten &out)
{
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT vs.punkte, vs.verbindung_id, v.potenzial
        FROM verbindung_segment vs
        JOIN verbindung v ON vs.verbindung_id = v.id
        WHERE vs.seite_id = :sid
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) return false;
    while (q.next()) {
        QJsonDocument doc = QJsonDocument::fromJson(q.value(0).toString().toUtf8());
        if (!doc.isArray() || doc.array().size() < 2) continue;
        QJsonArray arr = doc.array();
        out.raw.append({ arr[0].toObject()["x"].toDouble(), arr[0].toObject()["y"].toDouble(),
                          arr[1].toObject()["x"].toDouble(), arr[1].toObject()["y"].toDouble(),
                          q.value(1).toInt(), q.value(2).toString() });
    }
    const int n = out.raw.size();
    if (n == 0) return true;

    QSqlQuery eq(db);
    eq.prepare(R"(SELECT symbol_id, x1, y1, x2, y2, rotation, spiegel_x, spiegel_y, extra_daten
                  FROM grafik_element WHERE seite_id = :sid AND typ = 'symbol')");
    eq.bindValue(":sid", seiteId);
    if (eq.exec()) {
        while (eq.next()) {
            KaSymElement e;
            e.symbolId = eq.value(0).toString();
            e.x1 = eq.value(1).toDouble(); e.y1 = eq.value(2).toDouble();
            e.x2 = eq.value(3).toDouble(); e.y2 = eq.value(4).toDouble();
            e.rotation = eq.value(5).toDouble();
            e.spiegelX = eq.value(6).toBool(); e.spiegelY = eq.value(7).toBool();
            e.extraDaten = QJsonDocument::fromJson(eq.value(8).toString().toUtf8()).object();
            out.els.append(e);
        }
    }
    QSqlQuery gq(db);
    gq.prepare(R"(SELECT x1, y1, x2, y2, extra_daten FROM grafik_element
                  WHERE seite_id = :sid AND typ = 'geraetekasten')");
    gq.bindValue(":sid", seiteId);
    if (gq.exec()) {
        while (gq.next()) {
            KaSymElement gk;
            gk.x1 = gq.value(0).toDouble(); gk.y1 = gq.value(1).toDouble();
            gk.x2 = gq.value(2).toDouble(); gk.y2 = gq.value(3).toDouble();
            gk.extraDaten = QJsonDocument::fromJson(gq.value(4).toString().toUtf8()).object();
            out.geraetekaesten.append(gk);
        }
    }

    QSet<QString> symbolIds;
    for (const KaSymElement &e : out.els) symbolIds.insert(e.symbolId);
    QHash<QString, QVector<QPair<QString, QPointF>>> pinDefs;
    if (!symbolIds.isEmpty()) {
        QStringList idList;
        for (const QString &s : symbolIds) idList << QStringLiteral("'%1'").arg(s);
        QSqlQuery pq(db);
        pq.exec(QStringLiteral("SELECT symbol_id, name, x, y FROM symbol_pin WHERE symbol_id IN (%1)")
                .arg(idList.join(',')));
        while (pq.next())
            pinDefs[pq.value(0).toString()].append({ pq.value(1).toString(),
                QPointF(pq.value(2).toDouble(), pq.value(3).toDouble()) });
    }

    struct ElPin { int elIdx; QString pinName; QPointF pos; };
    QVector<ElPin> elPins;
    for (int ei = 0; ei < out.els.size(); ei++) {
        const KaSymElement &e = out.els[ei];
        for (const auto &pd : pinDefs.value(e.symbolId)) {
            QPointF w = kaPinWeltPos(e.x1, e.y1, e.x2, e.y2, e.rotation, e.spiegelX, e.spiegelY,
                                      pd.second.x(), pd.second.y());
            elPins.append({ ei, pd.first, w });
        }
    }

    const double PIN_TOL2 = 2.0;
    auto matchPin = [&](double px, double py) -> QPair<int, QString> {
        for (const ElPin &ep : elPins)
            if (std::hypot(px - ep.pos.x(), py - ep.pos.y()) < PIN_TOL2)
                return { ep.elIdx, ep.pinName };
        return { -1, QString() };
    };
    out.segElA.resize(n); out.segElB.resize(n);
    out.segPinA.resize(n); out.segPinB.resize(n);
    for (int i = 0; i < n; i++) {
        auto a = matchPin(out.raw[i].x1, out.raw[i].y1);
        auto b = matchPin(out.raw[i].x2, out.raw[i].y2);
        out.segElA[i] = a.first;  out.segPinA[i] = a.second;
        out.segElB[i] = b.first;  out.segPinB[i] = b.second;
    }
    for (int i = 0; i < n; i++) {
        if (out.segElA[i] >= 0 && out.segElB[i] >= 0) {
            out.adj[out.segElA[i]].append({ out.segElB[i], out.segPinB[i] });
            out.adj[out.segElB[i]].append({ out.segElA[i], out.segPinA[i] });
        }
    }
    return true;
}

// Eine Kreuzung einer Kabellinie mit einer Verbindung dieser Seite.
struct KaKreuzung {
    double  t;
    QString aderKey;
    int     verbindungId;
};

// Kreuzungen EINER Kabellinie mit den Segmenten ihrer Seite, sortiert nach
// Position entlang der Linie (t). 1:1-Port der Schnitt-Erkennung in
// pdfLeitungenSammeln()/kabelSchnittNetzeBerechnen() (CanvasGeometrie.qml).
QVector<KaKreuzung> kaKreuzungenBerechnen(double kx1, double ky1, double kx2, double ky2,
                                           KaSeitenDaten &sd)
{
    QVector<KaKreuzung> result;
    double kDxW = kx2 - kx1, kDyW = ky2 - ky1;
    double kLenW = std::hypot(kDxW, kDyW);
    if (kLenW < 0.5) return result;

    QSet<QString> gesehen;
    for (int i = 0; i < sd.raw.size(); i++) {
        const QString &pot = sd.raw[i].potenzial;
        if (!pot.isEmpty() && gesehen.contains(pot)) continue;
        double dax = sd.raw[i].x2 - sd.raw[i].x1, day = sd.raw[i].y2 - sd.raw[i].y1;
        double D = kDxW * day - kDyW * dax;
        if (std::abs(D) < 0.001) continue;
        double t = ((sd.raw[i].x1 - kx1) * day - (sd.raw[i].y1 - ky1) * dax) / D;
        double s = ((sd.raw[i].x1 - kx1) * kDyW - (sd.raw[i].y1 - ky1) * kDxW) / D;
        if (t >= -0.005 && t <= 1.005 && s >= -0.005 && s <= 1.005) {
            result.append({ std::clamp(t, 0.0, 1.0), sd.aderKeyFuerSeg(i), sd.raw[i].verbindungId });
            if (!pot.isEmpty()) gesehen.insert(pot);
        }
    }
    std::sort(result.begin(), result.end(),
              [](const KaKreuzung &a, const KaKreuzung &b) { return a.t < b.t; });
    return result;
}

} // namespace

bool Database::kabelAderProjektweitSynchronisieren(int kabelId)
{
    if (kabelId <= 0) return false;

    // Alle Kabellinien dieses Kabels über alle Seiten, in stabiler
    // Reihenfolge (wie kabelAlleLinienLaden()) — bestimmt, welche Linie bei
    // der Poolung zuerst die niedrigen Adernummern bekommt.
    struct KlZeile {
        int         geid = 0;
        int         seiteId = 0;
        double      x1 = 0, y1 = 0, x2 = 0, y2 = 0;
        QJsonObject extraDaten;
    };
    QVector<KlZeile> linien;
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ge.id, ge.seite_id, ge.x1, ge.y1, ge.x2, ge.y2, ge.extra_daten
            FROM grafik_element ge
            WHERE ge.typ = 'kabellinie'
              AND ge.kabel_id = :kid
            ORDER BY ge.seite_id, ge.sortierung
        )");
        q.bindValue(":kid", kabelId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderProjektweitSynchronisieren SELECT Linien:" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            KlZeile kl;
            kl.geid    = q.value(0).toInt();
            kl.seiteId = q.value(1).toInt();
            kl.x1 = q.value(2).toDouble(); kl.y1 = q.value(3).toDouble();
            kl.x2 = q.value(4).toDouble(); kl.y2 = q.value(5).toDouble();
            kl.extraDaten = QJsonDocument::fromJson(q.value(6).toString().toUtf8()).object();
            linien.append(kl);
        }
    }
    if (linien.isEmpty()) return true;

    // Roster (Adernummer → Farbe/Bezeichnung) — aus der ersten Linie, deren
    // extra_daten.adern nicht leer ist (alle Linien desselben Kabels tragen
    // denselben Roster, s. §6.4).
    QJsonArray roster;
    for (const KlZeile &kl : linien) {
        QJsonArray a = kl.extraDaten.value(QStringLiteral("adern")).toArray();
        if (!a.isEmpty()) { roster = a; break; }
    }
    if (roster.isEmpty()) return true;   // kein Kabeltyp zugewiesen, nichts zu tun
    const int aderzahl = roster.size();

    // Seiten-Daten nur einmal je Seite laden (mehrere Linien können auf
    // derselben Seite liegen).
    QHash<int, KaSeitenDaten> seiten;

    // Kreuzungen aller Linien einsammeln, in Linien-Reihenfolge (s.o.), pro
    // Linie nach Position entlang der Linie sortiert. Explizite
    // aderZuordnung wird PRO LINIE (eigener aderKey-Namensraum) ausgewertet.
    struct KaEintrag {
        int     linienIdx;
        int     verbindungId;
        QString farbe, farbe2, bezeichnung;
        int     explizitWert = -1;   // -1 = keine explizite Zuordnung, 0 = "keine Ader"
    };
    QVector<KaEintrag> alle;

    for (int li = 0; li < linien.size(); li++) {
        const KlZeile &kl = linien[li];
        if (!seiten.contains(kl.seiteId)) {
            KaSeitenDaten sd;
            kaSeiteLaden(m_db, kl.seiteId, sd);
            seiten.insert(kl.seiteId, sd);
        }
        KaSeitenDaten &sd = seiten[kl.seiteId];
        QVector<KaKreuzung> schnitte = kaKreuzungenBerechnen(kl.x1, kl.y1, kl.x2, kl.y2, sd);
        QJsonObject aderZuordnung = kl.extraDaten.value(QStringLiteral("aderZuordnung")).toObject();

        for (const KaKreuzung &sc : schnitte) {
            KaEintrag e;
            e.linienIdx    = li;
            e.verbindungId = sc.verbindungId;
            if (!sc.aderKey.isEmpty() && aderZuordnung.contains(sc.aderKey))
                e.explizitWert = aderZuordnung.value(sc.aderKey).toInt(-1);
            alle.append(e);
        }
    }
    if (alle.isEmpty()) return true;

    // KABEL-UEBERARBEITUNG-01/PROPAGATION-06: dieselbe Verbindung kann von
    // MEHREREN Kabellinien-Segmenten gekreuzt werden (z.B. der Kabeltrunk
    // oberhalb UND unterhalb eines durchleitenden Symbols wie eines
    // Schützes — elektrisch derselbe Punkt, nur auf zwei Linien-Abschnitte
    // verteilt gezeichnet, s. §6.5.4-Screenshot "W321 → +1 Linie" zweimal).
    // Ohne Deduplizierung hätte jede Linie unabhängig einen eigenen
    // Pool-Slot für dieselbe Verbindung konsumiert (Nutzer-Bugreport: 6
    // vergebene Adern für nur 3 tatsächliche Kreuzungspunkte, echte
    // .backup-Prüfung zeigte identische verbindung_id-Tripel unter zwei
    // verschiedenen kabellinie_grafik_element_id). Repräsentant = erstes
    // Vorkommen in Linien-Reihenfolge; nur EIN Eintrag pro verbindungId
    // (>0) nimmt an Pass 1/2 teil, das Ergebnis wird danach auf alle
    // Duplikate übertragen. verbindungId<=0 (kein aufgelöstes Netz) wird
    // nie zusammengefasst, jeder solche Eintrag bleibt sein eigener
    // Repräsentant.
    QHash<int, int> repIdxFuerVerbindung;   // verbindungId → Index in alle (Repräsentant)
    QVector<int>    repIdx;                 // an Pass 1/2 teilnehmende Indizes
    for (int i = 0; i < alle.size(); i++) {
        int vid = alle[i].verbindungId;
        if (vid <= 0) { repIdx.append(i); continue; }
        auto it = repIdxFuerVerbindung.constFind(vid);
        if (it == repIdxFuerVerbindung.constEnd()) {
            repIdxFuerVerbindung.insert(vid, i);
            repIdx.append(i);
        } else if (alle[i].explizitWert >= 0 && alle[it.value()].explizitWert < 0) {
            // Ein später gefundenes Duplikat hat eine explizite Zuordnung,
            // der bisherige Repräsentant nicht — übernehmen.
            alle[it.value()].explizitWert = alle[i].explizitWert;
        }
    }

    QVector<bool> belegt(aderzahl + 1, false);   // Index 1..aderzahl
    QVector<int>  aderNrJeEintrag(alle.size(), 0);   // 0 = noch offen, -1 = explizit "keine Ader"

    // Pass 1: explizite Zuordnungen reservieren (nur Repräsentanten).
    for (int ri = 0; ri < repIdx.size(); ri++) {
        int i = repIdx[ri];
        int z = alle[i].explizitWert;
        if (z < 0) continue;
        if (z == 0) { aderNrJeEintrag[i] = -1; continue; }
        if (z >= 1 && z <= aderzahl && !belegt[z]) {
            aderNrJeEintrag[i] = z;
            belegt[z] = true;
        }
        // Kollidierende explizite Zuordnung (z bereits belegt) fällt auf
        // den Positions-Fallback in Pass 2 zurück statt verworfen zu werden.
    }

    // Pass 2: übrige Repräsentanten bekommen fortlaufend die nächste über
    // das GANZE Kabel noch freie Adernummer — genau das verhindert die
    // doppelte Vergabe aus dem Bugreport (vorher: jede Linie zählte
    // unabhängig bei 1 neu los).
    int naechsteFrei = 1;
    for (int ri = 0; ri < repIdx.size(); ri++) {
        int i = repIdx[ri];
        if (aderNrJeEintrag[i] != 0) continue;
        while (naechsteFrei <= aderzahl && belegt[naechsteFrei]) naechsteFrei++;
        if (naechsteFrei > aderzahl) break;   // keine Adern mehr frei
        aderNrJeEintrag[i] = naechsteFrei;
        belegt[naechsteFrei] = true;
    }

    // Ergebnis der Repräsentanten auf alle Duplikate derselben verbindungId
    // übertragen, damit jede beteiligte Linie densel­ben Kreuzungspunkt mit
    // derselben Adernummer zeigt.
    for (int i = 0; i < alle.size(); i++) {
        int vid = alle[i].verbindungId;
        if (vid <= 0) continue;
        int rIdx = repIdxFuerVerbindung.value(vid);
        if (rIdx != i) aderNrJeEintrag[i] = aderNrJeEintrag[rIdx];
    }

    // Farbe/Bezeichnung je vergebener Adernummer aus dem Roster auflösen.
    for (int i = 0; i < alle.size(); i++) {
        int nr = aderNrJeEintrag[i];
        if (nr <= 0) continue;
        for (int ai = 0; ai < roster.size(); ai++) {
            QJsonObject ao = roster.at(ai).toObject();
            int rn = ao.contains(QStringLiteral("aderNr")) ? ao.value(QStringLiteral("aderNr")).toInt()
                                                             : (ai + 1);
            if (rn == nr) {
                alle[i].farbe       = ao.value(QStringLiteral("farbe")).toString();
                alle[i].farbe2      = ao.value(QStringLiteral("farbe2")).toString();
                alle[i].bezeichnung = ao.value(QStringLiteral("bezeichnung")).toString();
                break;
            }
        }
    }

    // Pro Linie die "aktive"-Liste bauen und über die bestehende
    // kabelAderLinieSynchronisieren() persistieren (Freigabe nicht mehr
    // zutreffender Adern inklusive).
    QVector<QVariantList> aktiveJeLinie(linien.size());
    for (int i = 0; i < alle.size(); i++) {
        int nr = aderNrJeEintrag[i];
        if (nr <= 0) continue;
        QVariantMap m;
        m[QStringLiteral("aderNr")]       = nr;
        m[QStringLiteral("farbe")]        = alle[i].farbe;
        m[QStringLiteral("farbe2")]       = alle[i].farbe2;
        m[QStringLiteral("bezeichnung")]  = alle[i].bezeichnung;
        m[QStringLiteral("verbindungId")] = alle[i].verbindungId;
        aktiveJeLinie[alle[i].linienIdx].append(m);
    }
    for (int li = 0; li < linien.size(); li++)
        kabelAderLinieSynchronisieren(kabelId, linien[li].geid, aktiveJeLinie[li]);

    return true;
}

// ============================================================
// kabelLinieDetails
// Lädt Kabelmetadaten + Adern für ein grafik_element.
// ============================================================
QVariantMap Database::kabelLinieDetails(int grafikElementId)
{
    QVariantMap result;
    if (grafikElementId <= 0) return result;

    // Kabel über die kabel_id-FK des Grafikelements suchen (KABEL-
    // UEBERARBEITUNG-01 Punkt 3, vorher json_extract auf extra_daten).
    // Funktioniert auch für nicht-primäre Linien eines Kabels (M9).
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.grafik_element_id, k.bauteil_kabel_id, k.von_ort, k.nach_ort
        FROM kabel k
        WHERE k.id = (SELECT ge.kabel_id FROM grafik_element ge WHERE ge.id = :geid)
        LIMIT 1
    )");
    q.bindValue(":geid", grafikElementId);
    if (!q.exec() || !q.next())
        return result;

    int kabelId = q.value(0).toInt();
    result[QStringLiteral("id")]              = kabelId;
    result[QStringLiteral("bezeichnung")]     = q.value(1).toString();
    result[QStringLiteral("kabeltyp")]        = q.value(2).toString();
    result[QStringLiteral("aderzahl")]        = q.value(3).toInt();
    result[QStringLiteral("querschnittMm2")]  = q.value(4).toDouble();
    result[QStringLiteral("grafikElementId")] = q.value(5).toInt();
    result[QStringLiteral("bauteilKabelId")]  = q.value(6).toInt();
    result[QStringLiteral("vonOrt")]          = q.value(7).toString();
    result[QStringLiteral("nachOrt")]         = q.value(8).toString();

    QSqlQuery qa;
    qa.prepare(R"(
        SELECT ader_nr, farbe, farbe2, bezeichnung, verbindung_id, kabellinie_grafik_element_id
        FROM kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
    )");
    qa.bindValue(":kid", kabelId);
    QVariantList adern;
    if (qa.exec()) {
        while (qa.next()) {
            QVariantMap ader;
            ader[QStringLiteral("aderNr")]                      = qa.value(0).toInt();
            ader[QStringLiteral("farbe")]                       = qa.value(1).toString();
            ader[QStringLiteral("farbe2")]                      = qa.value(2).toString();
            ader[QStringLiteral("bezeichnung")]                 = qa.value(3).toString();
            ader[QStringLiteral("verbindungId")]                = qa.value(4).toInt();
            ader[QStringLiteral("kabellinieGrafikElementId")]   = qa.value(5).toInt();
            adern.append(ader);
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelListe
// Alle Kabel eines Projekts – für den Kabel-Editor / Kabelliste.
// ============================================================
QVariantList Database::kabelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, bezeichnung, kabeltyp, aderzahl, querschnitt_mm2,
               laenge_m, von_ort, nach_ort, grafik_element_id, bauteil_kabel_id
        FROM kabel WHERE projekt_id = :pid ORDER BY bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q.value(7).toString();
        k[QStringLiteral("grafikElementId")]= q.value(8).toInt();
        k[QStringLiteral("bauteilKabelId")] = q.value(9).toInt();
        result.append(k);
    }
    return result;
}

// ============================================================
// kabelListeMitPos
// Wie kabelListe, aber mit Seite und Mittelpunktposition der primären Kabellinie.
// ============================================================
QVariantList Database::kabelListeMitPos(int projektId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               COALESCE(ge.seite_id, 0),
               COALESCE(s.blattnummer, ''),
               COALESCE(s.bezeichnung, ''),
               COALESCE((ge.x1 + ge.x2) / 2.0, 0.0),
               COALESCE((ge.y1 + ge.y2) / 2.0, 0.0)
        FROM kabel k
        LEFT JOIN grafik_element ge ON ge.id = k.grafik_element_id
        LEFT JOIN seite s ON s.id = ge.seite_id
        WHERE k.projekt_id = :pid
        ORDER BY k.bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelListeMitPos:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]             = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")]    = q.value(1).toString();
        m[QStringLiteral("kabeltyp")]       = q.value(2).toString();
        m[QStringLiteral("aderzahl")]       = q.value(3).toInt();
        m[QStringLiteral("querschnittMm2")] = q.value(4).toDouble();
        m[QStringLiteral("seiteId")]        = q.value(5).toInt();
        m[QStringLiteral("blattnr")]        = q.value(6).toString();
        m[QStringLiteral("seiteBez")]       = q.value(7).toString();
        m[QStringLiteral("weltX")]          = q.value(8).toDouble();
        m[QStringLiteral("weltY")]          = q.value(9).toDouble();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabellinienMitPos
// Alle kabellinie-Grafik-Elemente eines Kabels mit Seite und Mittelpunkt.
// ============================================================
QVariantList Database::kabellinienMitPos(int kabelId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.id, ge.seite_id,
               COALESCE(s.blattnummer, ''),
               COALESCE(s.bezeichnung, ''),
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        WHERE ge.typ = 'kabellinie'
          AND ge.kabel_id = :kid
        ORDER BY s.blattnummer, ge.id
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabellinienMitPos:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("grafikElementId")] = q.value(0).toInt();
        m[QStringLiteral("seiteId")]         = q.value(1).toInt();
        m[QStringLiteral("blattnr")]         = q.value(2).toString();
        m[QStringLiteral("seiteBez")]        = q.value(3).toString();
        m[QStringLiteral("weltX")]           = q.value(4).toDouble();
        m[QStringLiteral("weltY")]           = q.value(5).toDouble();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabelListeAufgeschluesselt
// Alle Kabel eines Projekts mit ihren Ader-Unterzeilen.
// Zwei Queries: (1) Kabel + Linienanzahl, (2) alle Adern mit Seite + Netz.
// ============================================================
QVariantList Database::kabelListeAufgeschluesselt(int projektId)
{
    // ─── Pass 1: Kabel laden ────────────────────────────────
    QVariantList kabel;
    QHash<int, int> kabelIdx;  // kabelId → Index in kabel

    QSqlQuery q1;
    q1.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.laenge_m, k.von_ort, k.nach_ort,
               COUNT(DISTINCT ka.kabellinie_grafik_element_id) AS linien_anzahl
        FROM kabel k
        LEFT JOIN kabel_ader ka ON ka.kabel_id = k.id
                                AND ka.kabellinie_grafik_element_id IS NOT NULL
        WHERE k.projekt_id = :pid
        GROUP BY k.id
        ORDER BY k.bezeichnung
    )");
    q1.bindValue(":pid", projektId);
    if (!q1.exec()) {
        qCWarning(lcDb) << "kabelListeAufgeschluesselt (kabel):" << q1.lastError().text();
        return kabel;
    }
    while (q1.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q1.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q1.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q1.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q1.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q1.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q1.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q1.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q1.value(7).toString();
        k[QStringLiteral("linienAnzahl")]   = q1.value(8).toInt();
        k[QStringLiteral("adern")]          = QVariantList();
        kabelIdx[q1.value(0).toInt()]       = kabel.size();
        kabel.append(k);
    }

    // ─── Pass 2: Adern laden (alle Kabel des Projekts, ein Query) ──
    QSqlQuery q2;
    q2.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, COALESCE(ka.farbe, ''), COALESCE(ka.farbe2, ''),
               COALESCE(ka.bezeichnung, ''),
               COALESCE(s.blattnummer, ''), COALESCE(s.bezeichnung, ''),
               COALESCE(v.bezeichnung, ''),
               COALESCE(ka.von_gerat_pin, ''), COALESCE(ka.nach_gerat_pin, ''),
               COALESCE(ge.seite_id, 0),
               COALESCE((ge.x1 + ge.x2) / 2.0, 0.0),
               COALESCE((ge.y1 + ge.y2) / 2.0, 0.0)
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        LEFT JOIN grafik_element ge ON ge.id = ka.kabellinie_grafik_element_id
        LEFT JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN verbindung v ON v.id = ka.verbindung_id
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q2.bindValue(":pid", projektId);
    if (!q2.exec()) {
        qCWarning(lcDb) << "kabelListeAufgeschluesselt (adern):" << q2.lastError().text();
        return kabel;
    }
    while (q2.next()) {
        int kId = q2.value(0).toInt();
        if (!kabelIdx.contains(kId)) continue;
        QVariantMap a;
        a[QStringLiteral("nr")]               = q2.value(1).toInt();
        a[QStringLiteral("farbe")]            = q2.value(2).toString();
        a[QStringLiteral("farbe2")]           = q2.value(3).toString();
        a[QStringLiteral("bezeichnung")]      = q2.value(4).toString();
        a[QStringLiteral("blattnummer")]      = q2.value(5).toString();
        a[QStringLiteral("seitenBez")]        = q2.value(6).toString();
        a[QStringLiteral("netz")]             = q2.value(7).toString();
        a[QStringLiteral("vonGeratPin")]      = q2.value(8).toString();
        a[QStringLiteral("nachGeratPin")]     = q2.value(9).toString();
        a[QStringLiteral("seiteId")]          = q2.value(10).toInt();
        a[QStringLiteral("weltX")]            = q2.value(11).toDouble();
        a[QStringLiteral("weltY")]            = q2.value(12).toDouble();
        int idx = kabelIdx[kId];
        QVariantMap kMap = kabel[idx].toMap();
        QVariantList adern = kMap[QStringLiteral("adern")].toList();
        adern.append(a);
        kMap[QStringLiteral("adern")] = adern;
        kabel[idx] = kMap;
    }
    return kabel;
}

// ============================================================
// kabelMetaAktualisieren
// Aktualisiert Bezeichnung, Typ, Aderzahl, Querschnitt eines
// bestehenden Kabel-Datensatzes (z. B. nach EigenschaftenPanel-Änderung).
//
// KABEL-UEBERARBEITUNG-01 Punkt 2: die kabel-Tabelle ist der alleinige
// Owner dieser Felder — rollt die neuen Werte deshalb zusätzlich auf ALLE
// Kabellinien-Grafikelemente dieses Kabels aus (über die echte kabel_id-FK
// aus Punkt 3), nicht nur auf die eine gerade im EigenschaftenPanel
// bearbeitete Linie. Vorher konnten kabeltyp/aderzahl/querschnittMm2/
// bezeichnung zwischen der kabel-Tabelle und den einzelnen
// grafik_element.extra_daten auseinanderdriften (Bestandsaufnahme
// §6.5.5, Punkt 2) — z. B. bekam eine über "bestehendes Kabel" verknüpfte
// zweite Linie nie mit, wenn der Kabeltyp später an der ersten Linie
// geändert wurde.
// ============================================================
bool Database::kabelMetaAktualisieren(int kabelId, const QString &bezeichnung,
                                       const QString &kabeltyp, int aderzahl,
                                       double querschnittMm2,
                                       const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE kabel SET bezeichnung=:bez, kabeltyp=:typ, aderzahl=:anz,
                         querschnitt_mm2=:qs, von_ort=:von, nach_ort=:nach
        WHERE id = :id
    )");
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelMetaAktualisieren:" << q.lastError().text();
        return false;
    }

    QSqlQuery qLinien(m_db);
    qLinien.prepare(R"(
        UPDATE grafik_element
        SET extra_daten = json_set(extra_daten,
            '$.bezeichnung',    :bez,
            '$.kabeltyp',       :typ,
            '$.aderzahl',       :anz,
            '$.querschnittMm2', :qs,
            '$.vonOrt',         :von,
            '$.nachOrt',        :nach)
        WHERE kabel_id = :kid
    )");
    qLinien.bindValue(":bez",  bezeichnung);
    qLinien.bindValue(":typ",  kabeltyp);
    qLinien.bindValue(":anz",  aderzahl);
    qLinien.bindValue(":qs",   querschnittMm2);
    qLinien.bindValue(":von",  vonOrt);
    qLinien.bindValue(":nach", nachOrt);
    qLinien.bindValue(":kid",  kabelId);
    if (!qLinien.exec())
        qCWarning(lcDb) << "kabelMetaAktualisieren Linien-Sync:" << qLinien.lastError().text();

    return true;
}

// ============================================================
// kabelAderListeMitVerbindung
// Gibt alle kabel_adern eines Projekts mit ihrer verbindung_id zurück –
// benötigt für den Verdrahtungsweg-Algorithmus (M11) in QML.
// ============================================================
QVariantList Database::kabelAderListeMitVerbindung(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, ka.verbindung_id,
               COALESCE(ka.kabellinie_grafik_element_id, 0)
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        WHERE ka.verbindung_id IS NOT NULL AND ka.verbindung_id > 0
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAderListeMitVerbindung:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap a;
        a[QStringLiteral("kabelId")]                   = q.value(0).toInt();
        a[QStringLiteral("aderNr")]                    = q.value(1).toInt();
        a[QStringLiteral("verbindungId")]              = q.value(2).toInt();
        a[QStringLiteral("kabellinieGrafikElementId")] = q.value(3).toInt();
        result.append(a);
    }
    return result;
}

// ============================================================
// kabelAderEndpunkteBerechnenUndSpeichern
// Berechnet von_gerat_pin / nach_gerat_pin für alle kabel_adern des Projekts
// rein aus der DB (ohne Canvas). Nutzt verbindung_segment-Endpunkte und
// sucht geometrisch benachbarte Endpunkt-Symbole (geraeteanschluss,
// klemme_anschluss, potenzial, isoliert_gelegte_ader). Speichert direkt.
// ============================================================
bool Database::kabelAderEndpunkteBerechnenUndSpeichern(int projektId)
{
    // ── 1. Adern mit verbindung_id und Seite der Kabellinie ────────
    struct AderInfo { int kabelId, aderNr, verbId, seiteId; };
    QVector<AderInfo> adern;
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ka.kabel_id, ka.ader_nr, ka.verbindung_id, ge.seite_id
            FROM kabel_ader ka
            JOIN kabel k  ON k.id  = ka.kabel_id
                          AND k.projekt_id = :pid
            JOIN grafik_element ge ON ge.id = ka.kabellinie_grafik_element_id
            WHERE ka.verbindung_id          > 0
              AND ka.kabellinie_grafik_element_id > 0
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (adern):" << q.lastError().text();
            return false;
        }
        while (q.next())
            adern.append({q.value(0).toInt(), q.value(1).toInt(),
                          q.value(2).toInt(), q.value(3).toInt()});
    }
    if (adern.isEmpty()) return true;

    // ── 2. Segment-Punkte aller relevanten Verbindungen ───────────
    // Schlüssel: (verbindungId << 32) | seiteId
    QHash<qint64, QVector<QPointF>> segPunkte;
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT vs.verbindung_id, vs.seite_id,
                   CAST(json_extract(vs.punkte,'$[0].x') AS REAL),
                   CAST(json_extract(vs.punkte,'$[0].y') AS REAL),
                   CAST(json_extract(vs.punkte,'$[1].x') AS REAL),
                   CAST(json_extract(vs.punkte,'$[1].y') AS REAL)
            FROM verbindung_segment vs
            JOIN verbindung v ON v.id = vs.verbindung_id
                              AND v.projekt_id = :pid
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (segmente):" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            qint64 key = ((qint64)q.value(0).toInt() << 32) | (quint32)q.value(1).toInt();
            segPunkte[key].append({q.value(2).toDouble(), q.value(3).toDouble()});
            segPunkte[key].append({q.value(4).toDouble(), q.value(5).toDouble()});
        }
    }

    // ── 3. Endpunkt-Elemente nach Seite ───────────────────────────
    // KAB-VN-01: Pin-Weltposition statt Symbol-Bbox-Zentrum verwenden –
    // identische Formel wie in Database_DRC.cpp (D-05/D-06) und
    // SchaltplanCanvas.qml. Die vier Endpunkt-Symbole haben ihren (einzigen)
    // Pin jeweils an einer Bbox-Kante, nicht im Zentrum (z.B.
    // geraeteanschluss: symbol_pin x=1, y=0.5 → rechter Rand,
    // klemme_anschluss: x=0.5, y=0 → oberer Rand) – bei Default-Größe
    // (8×8) liegt der Pin damit ~4 Einheiten vom Zentrum entfernt, also
    // außerhalb der bisherigen 3-Einheiten-Toleranz. Das bisherige
    // Zentrum-Matching schlug dadurch im Regelfall fehl, nicht nur in
    // Randfällen.
    struct EndEl { int geId; QString symbolId; double cx, cy, wx, wy; QJsonObject extra; };
    QHash<int, QVector<EndEl>> endEls; // seiteId → []
    QHash<QString, QVector<QPointF>> pinDefs; // symbol_id → [(x,y) normiert 0..1]
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ge.id, ge.seite_id, ge.symbol_id,
                   ge.x1, ge.y1, ge.x2, ge.y2,
                   ge.rotation, ge.spiegel_x, ge.spiegel_y,
                   COALESCE(ge.extra_daten, '{}')
            FROM grafik_element ge
            JOIN seite s ON s.id = ge.seite_id AND s.projekt_id = :pid
            WHERE ge.symbol_id IN ('geraeteanschluss','klemme_anschluss',
                                   'potenzial','isoliert_gelegte_ader')
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (endels):" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            const int     geId  = q.value(0).toInt();
            const int     sid   = q.value(1).toInt();
            const QString symId = q.value(2).toString();
            const double  x1    = q.value(3).toDouble();
            const double  y1    = q.value(4).toDouble();
            const double  x2    = q.value(5).toDouble();
            const double  y2    = q.value(6).toDouble();
            const double  rad   = q.value(7).toDouble() * M_PI / 180.0;
            const bool    spX   = q.value(8).toInt() != 0;
            const bool    spY   = q.value(9).toInt() != 0;
            auto doc = QJsonDocument::fromJson(q.value(10).toString().toUtf8());
            const QJsonObject extra = doc.isObject() ? doc.object() : QJsonObject{};

            if (!pinDefs.contains(symId)) {
                QVector<QPointF> pins;
                QSqlQuery pq(m_db);
                pq.prepare("SELECT x, y FROM symbol_pin WHERE symbol_id = :sid");
                pq.bindValue(":sid", symId);
                if (pq.exec())
                    while (pq.next())
                        pins.append({pq.value(0).toDouble(), pq.value(1).toDouble()});
                pinDefs[symId] = pins;
            }

            const double sw   = x2 - x1, sh = y2 - y1;
            const double scx  = x1 + sw / 2.0, scy = y1 + sh / 2.0;
            const double cosR = std::cos(rad), sinR = std::sin(rad);

            for (const QPointF &pin : pinDefs.value(symId)) {
                double cx = (pin.x() - 0.5) * std::abs(sw);
                double cy = (pin.y() - 0.5) * std::abs(sh);
                if (spX) cx = -cx;
                if (spY) cy = -cy;

                EndEl el;
                el.geId     = geId;
                el.symbolId = symId;
                el.cx       = scx;
                el.cy       = scy;
                el.wx       = scx + cx * cosR - cy * sinR;
                el.wy       = scy + cx * sinR + cy * cosR;
                el.extra    = extra;
                endEls[sid].append(el);
            }
        }
    }

    // ── 4. Gerätekasten nach Seite (für geraeteanschluss BMK) ─────
    struct GkEl { double x1, y1, x2, y2; QString bmk; };
    QHash<int, QVector<GkEl>> gkMap; // seiteId → []
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT ge.seite_id, ge.x1, ge.y1, ge.x2, ge.y2,
                   COALESCE(json_extract(ge.extra_daten,'$.bmk'), '')
            FROM grafik_element ge
            JOIN seite s ON s.id = ge.seite_id AND s.projekt_id = :pid
            WHERE ge.typ = 'geraetekasten'
        )");
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBerechnen (gk):" << q.lastError().text();
            return false;
        }
        while (q.next()) {
            int sid = q.value(0).toInt();
            GkEl gk{ q.value(1).toDouble(), q.value(2).toDouble(),
                     q.value(3).toDouble(), q.value(4).toDouble(),
                     q.value(5).toString() };
            gkMap[sid].append(gk);
        }
    }

    // ── 5. Verbindungs-Bezeichnungen (für potenzial-Label) ────────
    QHash<int, QString> verbBez;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, COALESCE(bezeichnung,'') FROM verbindung WHERE projekt_id = :pid");
        q.bindValue(":pid", projektId);
        if (q.exec())
            while (q.next())
                verbBez[q.value(0).toInt()] = q.value(1).toString();
    }

    // ── Hilfsfunktion: Endpunkt-String formatieren ─────────────────
    auto formatEndpunkt = [&](const EndEl &el, int seiteId, int verbId) -> QString {
        if (el.symbolId == QLatin1String("geraeteanschluss")) {
            const QString ank = el.extra[QStringLiteral("anschlussKennzeichnung")].toString();
            const GkEl *best  = nullptr;
            double bestArea   = std::numeric_limits<double>::max();
            for (const GkEl &gk : gkMap.value(seiteId)) {
                double xMin = std::min(gk.x1,gk.x2), xMax = std::max(gk.x1,gk.x2);
                double yMin = std::min(gk.y1,gk.y2), yMax = std::max(gk.y1,gk.y2);
                if (el.cx >= xMin && el.cx <= xMax && el.cy >= yMin && el.cy <= yMax) {
                    double a = (xMax-xMin)*(yMax-yMin);
                    if (a < bestArea) { bestArea = a; best = &gk; }
                }
            }
            const QString bmk = best ? best->bmk : QString{};
            return bmk.isEmpty() ? ank : (bmk + QLatin1Char(':') + ank);
        }
        if (el.symbolId == QLatin1String("klemme_anschluss")) {
            const QString abez = el.extra[QStringLiteral("anschlussBezeichnung")].toString();
            const QString bmk  = el.extra[QStringLiteral("bmk")].toString();
            return bmk.isEmpty() ? abez : (bmk + QLatin1Char(':') + abez);
        }
        if (el.symbolId == QLatin1String("potenzial")) {
            const QString sn = el.extra[QStringLiteral("signalname")].toString();
            const QString bz = verbBez.value(verbId);
            return bz.isEmpty() ? sn : bz;
        }
        if (el.symbolId == QLatin1String("isoliert_gelegte_ader"))
            return QStringLiteral("isoliert");
        return {};
    };

    // ── 6. Matching: Segment-Punkte ↔ Pin-Weltpositionen ─────────
    // Toleranz 0.5 (identisch zu D-05/D-06) – Pin-Weltposition und
    // Segment-Endpunkt sollten exakt übereinanderliegen, kein Bbox-Abstand
    // mehr zu kompensieren.
    constexpr double kPinMatchEps = 0.5;
    QVariantList ergebnisse;

    for (const AderInfo &ad : adern) {
        qint64 key = ((qint64)ad.verbId << 32) | (quint32)ad.seiteId;
        const QVector<QPointF> &punkte = segPunkte.value(key);
        if (punkte.isEmpty()) continue;

        const QVector<EndEl> &els = endEls.value(ad.seiteId);
        QString von, nach;
        int vonGeId = -1;

        for (const QPointF &pt : punkte) {
            for (const EndEl &el : els) {
                if (std::abs(el.wx - pt.x()) > kPinMatchEps || std::abs(el.wy - pt.y()) > kPinMatchEps)
                    continue;
                if (von.isEmpty()) {
                    von     = formatEndpunkt(el, ad.seiteId, ad.verbId);
                    vonGeId = el.geId;
                } else if (el.geId != vonGeId && nach.isEmpty()) {
                    nach = formatEndpunkt(el, ad.seiteId, ad.verbId);
                }
                if (!von.isEmpty() && !nach.isEmpty()) break;
            }
            if (!von.isEmpty() && !nach.isEmpty()) break;
        }

        ergebnisse.append(QVariantMap{
            { QStringLiteral("kabelId"), ad.kabelId },
            { QStringLiteral("aderNr"),  ad.aderNr  },
            { QStringLiteral("von"),     von         },
            { QStringLiteral("nach"),    nach         },
        });
    }

    return kabelAderEndpunkteBulkSetzen(projektId, ergebnisse);
}

// ============================================================
// kabelAderEndpunkteBulkSetzen
// Speichert Von/Nach-Gerät:Pin für eine Liste von kabel_adern.
// adern: [{kabelId, aderNr, von, nach}]
// ============================================================
bool Database::kabelAderEndpunkteBulkSetzen(int projektId, const QVariantList &adern)
{
    if (adern.isEmpty()) return true;
    if (!m_db.transaction()) {
        qCWarning(lcDb) << "kabelAderEndpunkteBulkSetzen: Transaktion:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE kabel_ader SET von_gerat_pin = :von, nach_gerat_pin = :nach
        WHERE kabel_id = :kid AND ader_nr = :nr
          AND EXISTS (SELECT 1 FROM kabel WHERE id = :kid2 AND projekt_id = :pid)
    )");
    for (const QVariant &av : adern) {
        const QVariantMap a = av.toMap();
        const QString von  = a.value(QStringLiteral("von")).toString();
        const QString nach = a.value(QStringLiteral("nach")).toString();
        q.bindValue(":von",  von.isEmpty()  ? QVariant(QMetaType::fromType<QString>()) : von);
        q.bindValue(":nach", nach.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : nach);
        q.bindValue(":kid",  a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":kid2", a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":nr",   a.value(QStringLiteral("aderNr")).toInt());
        q.bindValue(":pid",  projektId);
        if (!q.exec()) {
            qCWarning(lcDb) << "kabelAderEndpunkteBulkSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    if (!m_db.commit()) {
        qCWarning(lcDb) << "kabelAderEndpunkteBulkSetzen commit:" << m_db.lastError().text();
        m_db.rollback();
        return false;
    }
    return true;
}

// ============================================================
// kabelLoeschen
// Löscht Kabel + Adern. Das grafik_element selbst wird von QML
// gelöscht (grafikSpeichern); ON DELETE SET NULL sorgt dafür,
// dass kabel.grafik_element_id auf NULL gesetzt wird falls das
// Element zuerst gelöscht wird.
//
// KABEL-VERWAIST-01: kabel_ader.kabel_id hat kein ON DELETE CASCADE
// (anders als z.B. ibn_kabel.kabel_id) — bei aktivem
// PRAGMA foreign_keys=ON scheiterte "DELETE FROM kabel" bisher
// stillschweigend an jeder noch vorhandenen Ader-Zeile (der QML-
// Aufrufer in CanvasAktionenHandler.qml prüft den Rückgabewert
// nicht), das Kabel blieb dauerhaft als Datenleiche zurück. Adern
// jetzt zuerst explizit gelöscht.
// ============================================================
bool Database::kabelLoeschen(int kabelId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM kabel_ader WHERE kabel_id = :id");
    q.bindValue(":id", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelLoeschen (Adern):" << q.lastError().text();
        return false;
    }
    q.prepare("DELETE FROM kabel WHERE id = :id");
    q.bindValue(":id", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// bauteilKabelAdernLaden
// Vollständige Ader-Liste eines Kabeltyps (inkl. ader_nr, nummer,
// bezeichnung) — Grundlage für den Live-Nachschlag der Litzendaten
// in der Konfkabel-Pin-Zuordnung (§9.3), da diese Felder nicht
// dupliziert am Kontakt/Pin gespeichert werden.
// ============================================================
QVariantList Database::bauteilKabelAdernLaden(int kabelId) const
{
    QVariantList result;
    if (kabelId < 0) return result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ader_nr, farbe, farbe2, nummer, bezeichnung, querschnitt_mm2
        FROM bibliothek.bauteil_kabel_ader
        WHERE kabel_id = :kid
        ORDER BY ader_nr
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "bauteilKabelAdernLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap a;
        a[QStringLiteral("aderNr")]        = q.value(0).toInt();
        a[QStringLiteral("farbe")]         = q.value(1).toString();
        a[QStringLiteral("farbe2")]        = q.value(2).toString();
        a[QStringLiteral("nummer")]        = q.value(3).toString();
        a[QStringLiteral("bezeichnung")]   = q.value(4).toString();
        a[QStringLiteral("querschnittMm2")]= q.value(5).toDouble();
        result.append(a);
    }
    return result;
}

// ============================================================
// bauteilKabelListe
// Alle Kabel-Bibliothekseinträge für den Picker-Dialog.
// Gibt [{id, bauteilId, bezeichnung, kabeltyp, aderzahl,
//        querschnittMm2, adern:[{farbe,querschnittMm2}]}] zurück.
// ============================================================
QVariantList Database::bauteilKabelListe()
{
    QVariantList result;
    {
        QSqlQuery cnt;
        cnt.exec("SELECT COUNT(*) FROM bibliothek.bauteil_kabel");
        if (cnt.next())
            qCDebug(lcDb) << "bauteilKabelListe: bauteil_kabel Zeilen=" << cnt.value(0).toInt();
        else
            qCWarning(lcDb) << "bauteilKabelListe: COUNT Fehler:" << cnt.lastError().text();
    }
    QSqlQuery q(m_db);
    if (!q.exec(R"(
        SELECT bk.id, bk.bauteil_id, b.bezeichnung, bk.kabeltyp,
               COUNT(ba.id) AS aderzahl,
               MAX(ba.querschnitt_mm2) AS quer
        FROM bibliothek.bauteil_kabel bk
        JOIN bibliothek.bauteil b ON b.id = bk.bauteil_id
        LEFT JOIN bibliothek.bauteil_kabel_ader ba ON ba.kabel_id = bk.id
        GROUP BY bk.id
        ORDER BY b.bezeichnung, bk.kabeltyp
    )")) {
        qCWarning(lcDb) << "bauteilKabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        int bkId = q.value(0).toInt();
        k[QStringLiteral("id")]             = bkId;
        k[QStringLiteral("bauteilId")]      = q.value(1).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(3).toString();
        k[QStringLiteral("aderzahl")]       = q.value(4).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(5).toDouble();
        // Aderfarben für Farbvorschau laden
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT farbe, farbe2, querschnitt_mm2 FROM bibliothek.bauteil_kabel_ader
            WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bkId);
        QVariantList adern;
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("farbe")]          = qa.value(0).toString();
                a[QStringLiteral("farbe2")]         = qa.value(1).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(2).toDouble();
                adern.append(a);
            }
        }
        k[QStringLiteral("adern")] = adern;
        result.append(k);
    }
    qCDebug(lcDb) << "bauteilKabelListe: Einträge=" << result.size();
    return result;
}

// ============================================================
// kabelBauteilKabelSetzen
// Weist einem Kabel (kabelId, nicht einer einzelnen Linie) ein
// Bauteil-Kabel zu (bauteilKabelId > 0) oder hebt die Zuweisung auf
// (bauteilKabelId <= 0). Bei Zuweisung werden kabeltyp/aderzahl/
// querschnitt_mm2 aus dem Bauteil-Kabel übernommen (können manuell
// überschrieben werden). Gibt die aktualisierten Metadaten zurück.
//
// KABEL-UEBERARBEITUNG-01 Punkt 2: der Ader-Roster (adern[], Farbe/
// Bezeichnung je Adernummer) kommt ausschließlich aus der Kabeldefinition
// hier — dieses Kabel ist also bereits der alleinige Owner. Der Roster
// wird jetzt zusätzlich auf ALLE Kabellinien-Segmente dieses Kabels
// ausgerollt (über die kabel_id-FK aus Punkt 3), nicht mehr nur auf die
// eine Linie, die den Picker gerade geöffnet hat — vorher bekam eine über
// "bestehendes Kabel" verknüpfte zweite Linie den Roster nur beim
// eigenen Zeichnen mit, nie bei einer späteren Änderung an einer anderen
// Linie desselben Kabels.
// ============================================================
QVariantMap Database::kabelBauteilKabelSetzen(int kabelId, int bauteilKabelId)
{
    QVariantMap result;
    QString neuerTyp;
    int     neueAderzahl = 0;
    double  neuerQuer    = 0.0;

    if (bauteilKabelId > 0) {
        QSqlQuery qbk;
        qbk.prepare(R"(
            SELECT bk.kabeltyp, COUNT(ba.id), MAX(ba.querschnitt_mm2)
            FROM bibliothek.bauteil_kabel bk
            LEFT JOIN bibliothek.bauteil_kabel_ader ba ON ba.kabel_id = bk.id
            WHERE bk.id = :id GROUP BY bk.id
        )");
        qbk.bindValue(":id", bauteilKabelId);
        if (qbk.exec() && qbk.next()) {
            neuerTyp     = qbk.value(0).toString();
            neueAderzahl = qbk.value(1).toInt();
            neuerQuer    = qbk.value(2).toDouble();
        }
    }

    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE kabel SET bauteil_kabel_id=:bkid, kabeltyp=:typ,
               aderzahl=:anz, querschnitt_mm2=:qs
        WHERE id = :id
    )");
    q.bindValue(":bkid", bauteilKabelId > 0 ? QVariant(bauteilKabelId) : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":typ",  neuerTyp.isEmpty()  ? QVariant(QMetaType(QMetaType::QString)) : neuerTyp);
    q.bindValue(":anz",  neueAderzahl > 0    ? neueAderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   neuerQuer > 0       ? neuerQuer    : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelBauteilKabelSetzen:" << q.lastError().text();
        return result;
    }
    result[QStringLiteral("kabeltyp")]       = neuerTyp;
    result[QStringLiteral("aderzahl")]       = neueAderzahl;
    result[QStringLiteral("querschnittMm2")] = neuerQuer;
    result[QStringLiteral("bauteilKabelId")] = bauteilKabelId > 0 ? bauteilKabelId : 0;

    // Aderliste für Canvas-Schnittpunkt-Beschriftung
    QVariantList adern;
    if (bauteilKabelId > 0) {
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT ader_nr, farbe, farbe2, bezeichnung, querschnitt_mm2
            FROM bibliothek.bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bauteilKabelId);
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("aderNr")]         = qa.value(0).toInt();
                a[QStringLiteral("farbe")]          = qa.value(1).toString();
                a[QStringLiteral("farbe2")]         = qa.value(2).toString();
                a[QStringLiteral("bezeichnung")]    = qa.value(3).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(4).toDouble();
                adern.append(a);
            }
        }
    }
    result[QStringLiteral("adern")] = adern;

    // Roster auf ALLE Kabellinien-Segmente dieses Kabels ausrollen (s.
    // Funktionskommentar oben, Punkt 2).
    {
        QJsonArray adernArr;
        for (const QVariant &av : adern)
            adernArr.append(QJsonObject::fromVariantMap(av.toMap()));
        QString adernJson = QString::fromUtf8(QJsonDocument(adernArr).toJson(QJsonDocument::Compact));

        QSqlQuery qLinien(m_db);
        qLinien.prepare(R"(
            UPDATE grafik_element
            SET extra_daten = json_set(extra_daten, '$.adern', json(:adern))
            WHERE kabel_id = :kid
        )");
        qLinien.bindValue(":adern", adernJson);
        qLinien.bindValue(":kid",   kabelId);
        if (!qLinien.exec())
            qCWarning(lcDb) << "kabelBauteilKabelSetzen Roster-Sync:" << qLinien.lastError().text();
    }

    return result;
}

// ============================================================
// kabelAlleLinienLaden
// Alle Kabellinie-Grafikelemente eines Kabels (alle Seiten).
// ============================================================
QVariantList Database::kabelAlleLinienLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ge.id, ge.seite_id, s.bezeichnung,
               COUNT(ka.id) AS ader_anzahl
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN kabel_ader ka ON ka.kabellinie_grafik_element_id = ge.id
        WHERE ge.typ = 'kabellinie'
          AND ge.kabel_id = :kid
        GROUP BY ge.id
        ORDER BY ge.seite_id, ge.sortierung
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAlleLinienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("grafikElementId")]   = q.value(0).toInt();
        m[QStringLiteral("seiteId")]           = q.value(1).toInt();
        m[QStringLiteral("seiteBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("aderAnzahl")]        = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabelFreieAderLaden
// Adern eines Kabels die keiner Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelFreieAderLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ader_nr, farbe, farbe2, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabel_id = :kid AND kabellinie_grafik_element_id IS NULL
        ORDER BY ader_nr
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelFreieAderLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("farbe2")]      = q.value(2).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(3).toString();
        ader[QStringLiteral("verbindungId")]= q.value(4).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// kabelAlleAderLaden
// KABEL-ADERFARBE-PROPAGATION-04: alle kabel_ader-Zeilen eines Kabels,
// zugeordnet und frei. s. Database.h für Details.
// ============================================================
QVariantList Database::kabelAlleAderLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ader_nr, farbe, farbe2, bezeichnung, verbindung_id, kabellinie_grafik_element_id
        FROM kabel_ader
        WHERE kabel_id = :kid
        ORDER BY ader_nr
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAlleAderLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]                    = q.value(0).toInt();
        ader[QStringLiteral("farbe")]                     = q.value(1).toString();
        ader[QStringLiteral("farbe2")]                    = q.value(2).toString();
        ader[QStringLiteral("bezeichnung")]                = q.value(3).toString();
        ader[QStringLiteral("verbindungId")]               = q.value(4).toInt();
        ader[QStringLiteral("kabellinieGrafikElementId")]  = q.value(5).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// kabelAderFuerLinieLaden
// Adern die einer bestimmten Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelAderFuerLinieLaden(int kabellinieGrafikElementId)
{
    QVariantList result;
    if (kabellinieGrafikElementId <= 0) return result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT ader_nr, farbe, farbe2, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabellinie_grafik_element_id = :geid
        ORDER BY ader_nr
    )");
    q.bindValue(":geid", kabellinieGrafikElementId);
    if (!q.exec()) {
        qCWarning(lcDb) << "kabelAderFuerLinieLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("farbe2")]      = q.value(2).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(3).toString();
        ader[QStringLiteral("verbindungId")]= q.value(4).toInt();
        result.append(ader);
    }
    return result;
}

