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
#include <QImageReader>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <algorithm>

// Logo-Datei lesen: max. 5 MB, MIME aus der Endung. Gemeinsam für Projekt-, Kunden- und Vorlagen-Logo.
static bool logoDateiLesen(const QString &pfad, QByteArray &data, QString &mime, const char *wer)
{
    QUrl url(pfad);
    const QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;
    QFileInfo info(localPath);
    if (!info.exists()) { qCWarning(lcDb) << wer << ": Datei nicht gefunden:" << localPath; return false; }
    if (info.size() > 5 * 1024 * 1024) { qCWarning(lcDb) << wer << ": Datei zu groß"; return false; }
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) { qCWarning(lcDb) << wer << ": Öffnen fehlgeschlagen"; return false; }
    data = file.readAll();
    file.close();
    const QString suffix = info.suffix().toLower();
    mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg") || suffix == QLatin1String("jpeg")) mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))  mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))  mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("webp")) mime = QStringLiteral("image/webp");
    return true;
}

// Data-URL + Seitenverhältnis (Breite/Höhe) in die Datenmap; leere Bilddaten tun nichts.
static void logoInMap(QVariantMap &m, const QString &urlKey, const QString &aspektKey,
                      QByteArray data, const QString &mime)
{
    if (data.isEmpty() || mime.isEmpty()) return;
    m[urlKey] = QStringLiteral("data:") + mime + QStringLiteral(";base64,") + QString::fromLatin1(data.toBase64());
    QBuffer buf(&data);
    buf.open(QIODevice::ReadOnly);
    const QSize sz = QImageReader(&buf).size();
    if (sz.isValid() && sz.height() > 0) m[aspektKey] = double(sz.width()) / sz.height();
}

QVariantMap Database::seiteBasisDaten(int seiteId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT blattnummer, COALESCE(bezeichnung,'') FROM seite WHERE id = :id");
    q.bindValue(":id", seiteId);
    if (!q.exec() || !q.next()) return {};
    QVariantMap m;
    m[QStringLiteral("blattnummer")] = q.value(0).toString();
    m[QStringLiteral("bezeichnung")] = q.value(1).toString();
    return m;
}

// ============================================================
// normblattDatenLaden / normblattAnzeigenSetzen
// ============================================================
QVariantMap Database::normblattDatenLaden(int seiteId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT s.blattnummer, s.bezeichnung, a.kuerzel AS anlage_kuerzel, o.kuerzel AS ort_kuerzel,
               s.breite_mm, s.hoehe_mm, s.normblatt_anzeigen,
               s.hintergrund_farbe, s.aussen_overlay, s.titelblatt_vorlage,
               s.revision_status, s.revision_kennung, s.in_doku_pdf, s.infostreifen, s.infostreifen_ausrichtung,
               s.normblatt_position, s.normblatt_format, s.normblatt_ausrichtung, s.normblatt_rahmen,
               p.name         AS projekt_name,
               p.projektnummer,
               p.auftraggeber,
               p.auftragnehmer,
               p.bearbeiter,
               p.norm,
               p.werk,
               p.abteilung,
               p.erstellt_am,
               COALESCE(s.rand_links_mm,  nv.rand_links_mm,  20) AS rand_links_mm,
               COALESCE(s.rand_rechts_mm, nv.rand_rechts_mm, 10) AS rand_rechts_mm,
               COALESCE(s.rand_oben_mm,   nv.rand_oben_mm,   10) AS rand_oben_mm,
               COALESCE(s.rand_unten_mm,  nv.rand_unten_mm,  10) AS rand_unten_mm,
               COALESCE(a.anlage_uebergeordnet, '')   AS anlage_uo,
               COALESCE(o.standort_uebergeordnet, '') AS ort_uo
        FROM seite s
        JOIN ort     o  ON s.ort_id      = o.id
        JOIN anlage  a  ON o.anlage_id   = a.id
        JOIN projekt p  ON a.projekt_id  = p.id
        LEFT JOIN normblatt_vorlage nv ON s.normblatt_id = nv.id
        WHERE s.id = :sid
    )");
    q.bindValue(":sid", seiteId);

    QVariantMap m;
    if (!q.exec() || !q.next()) {
        qCWarning(lcDb) << "normblattDatenLaden:" << q.lastError().text();
        return m;
    }
    m[QStringLiteral("blattnummer")]      = q.value("blattnummer");
    m[QStringLiteral("bezeichnung")]      = q.value("bezeichnung");
    m[QStringLiteral("anlageKuerzel")]    = q.value("anlage_kuerzel");
    m[QStringLiteral("ortKuerzel")]       = q.value("ort_kuerzel");
    m[QStringLiteral("anlageUO")]         = q.value("anlage_uo");
    m[QStringLiteral("ortUO")]            = q.value("ort_uo");
    m[QStringLiteral("breiteMm")]         = q.value("breite_mm");
    m[QStringLiteral("hoeheMm")]          = q.value("hoehe_mm");
    m[QStringLiteral("normblattAnzeigen")] = q.value("normblatt_anzeigen");
    m[QStringLiteral("hintergrundFarbe")] = q.value("hintergrund_farbe");
    m[QStringLiteral("aussenOverlay")]    = q.value("aussen_overlay");
    m[QStringLiteral("titelblattVorlage")] = q.value("titelblatt_vorlage");
    m[QStringLiteral("revisionStatus")]   = q.value("revision_status");
    m[QStringLiteral("inDokuPdf")]        = q.value("in_doku_pdf");
    m[QStringLiteral("revisionKennung")]  = q.value("revision_kennung");
    m[QStringLiteral("projektName")]      = q.value("projekt_name");
    m[QStringLiteral("projektnummer")]    = q.value("projektnummer");
    m[QStringLiteral("auftraggeber")]     = q.value("auftraggeber");
    m[QStringLiteral("auftragnehmer")]    = q.value("auftragnehmer");
    m[QStringLiteral("bearbeiter")]       = q.value("bearbeiter");
    m[QStringLiteral("norm")]             = q.value("norm");
    m[QStringLiteral("werk")]             = q.value("werk");
    m[QStringLiteral("abteilung")]        = q.value("abteilung");

    // Logos als Data-URL — separater Query damit der BLOB-Join nicht bei jeder Seite lädt.
    // kundenLogo = Kunden-Logo des Projekts (Feldtyp logo_kunde); logo = Logo der Vorlage (unten).
    {
        QSqlQuery ql(m_db);
        ql.prepare(R"(
            SELECT p.kunden_logo_data, p.kunden_logo_mime
            FROM seite s
            JOIN ort o ON s.ort_id = o.id
            JOIN anlage a ON o.anlage_id = a.id
            JOIN projekt p ON a.projekt_id = p.id
            WHERE s.id = :sid
        )");
        ql.bindValue(":sid", seiteId);
        if (ql.exec() && ql.next()) {
            logoInMap(m, QStringLiteral("kundenLogoDataUrl"), QStringLiteral("kundenLogoAspekt"),
                      ql.value(0).toByteArray(), ql.value(1).toString());
        }
    }
    // Logo der zugewiesenen Vorlage (Bearbeiter-Logo, Feldtyp logo)
    {
        QSqlQuery qv(m_db);
        qv.prepare(R"(SELECT nv.logo_data, nv.logo_mime FROM seite s
                      JOIN normblatt_vorlage nv ON nv.id = s.normblatt_id
                      WHERE s.id = :sid AND nv.logo_data IS NOT NULL)");
        qv.bindValue(":sid", seiteId);
        if (qv.exec() && qv.next()) {
            logoInMap(m, QStringLiteral("logoDataUrl"), QStringLiteral("logoAspekt"),
                      qv.value(0).toByteArray(), qv.value(1).toString());
        }
    }
    // Normblatt-Lage (N-02)
    {
        const QString fm = q.value("normblatt_format").toString();
        const QSizeF fmt = infostreifenFormatMm(fm, 0, 0);
        m[QStringLiteral("normblattPosition")]    = q.value("normblatt_position");
        m[QStringLiteral("normblattFormat")]      = fm;
        m[QStringLiteral("normblattAusrichtung")] = q.value("normblatt_ausrichtung");
        m[QStringLiteral("normblattRahmen")]      = q.value("normblatt_rahmen").toInt() != 0;
        m[QStringLiteral("normblattFormatBreiteMm")] = fmt.width();
        m[QStringLiteral("normblattFormatHoeheMm")]  = fmt.height();
        m[QStringLiteral("ohneRahmen")]           = q.value("normblatt_rahmen").toInt() == 0;
    }
    // Infostreifen (INFOSTREIFEN-02/03): Modus/Format immer, die Vorlage nur auf Seiten ohne Schriftfeld
    {
        const QString modus = q.value("infostreifen").toString();
        const QSizeF fmt = infostreifenFormatMm(modus, q.value("breite_mm").toDouble(), q.value("hoehe_mm").toDouble());
        m[QStringLiteral("infostreifenModus")]       = modus;
        m[QStringLiteral("infostreifenAusrichtung")] = q.value("infostreifen_ausrichtung").toString();
        m[QStringLiteral("infostreifenBreiteMm")]    = fmt.width();
        m[QStringLiteral("infostreifenHoeheMm")]     = fmt.height();
        if (!q.value("normblatt_anzeigen").toBool() && modus != QLatin1String("aus"))
            m[QStringLiteral("infostreifen")] = infostreifenLaden(seiteId);
    }
    m[QStringLiteral("erstelltAm")]       = q.value("erstellt_am");
    m[QStringLiteral("randLinksMm")]      = q.value("rand_links_mm");
    m[QStringLiteral("randRechtsMm")]     = q.value("rand_rechts_mm");
    m[QStringLiteral("randObenMm")]       = q.value("rand_oben_mm");
    m[QStringLiteral("randUntenMm")]      = q.value("rand_unten_mm");

    // Benutzerdefinierte Felder laden (nur wenn normblatt_id gesetzt)
    {
        QSqlQuery qnid;
        qnid.prepare("SELECT normblatt_id FROM seite WHERE id = :sid");
        qnid.bindValue(":sid", seiteId);
        if (qnid.exec() && qnid.next()) {
            QVariant normblattId = qnid.value(0);
            if (!normblattId.isNull() && normblattId.toInt() > 0) {
                m[QStringLiteral("normblattVorlageId")] = normblattId;
                m[QStringLiteral("felder")] = normblattFelderLaden(normblattId.toInt());
            }
        }
    }

    return m;
}

bool Database::normblattEinstellungenSetzen(int seiteId, bool anzeigen,
                                             const QString &hintergrundFarbe,
                                             bool aussenOverlay,
                                             const QString &titelblattVorlage,
                                             int normblattId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(UPDATE seite SET
        normblatt_anzeigen = :an,
        hintergrund_farbe  = :hf,
        aussen_overlay     = :ao,
        titelblatt_vorlage = :tv,
        normblatt_id       = :nid
        WHERE id = :sid)");
    q.bindValue(":an",  anzeigen ? 1 : 0);
    q.bindValue(":hf",  hintergrundFarbe);
    q.bindValue(":ao",  aussenOverlay ? 1 : 0);
    q.bindValue(":tv",  titelblattVorlage.isEmpty() ? QStringLiteral("din6771") : titelblattVorlage);
    q.bindValue(":nid", normblattId > 0 ? QVariant(normblattId) : QVariant());
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattEinstellungenSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// Format-Flaeche des Infostreifens je Modus (mm). (0,0) = auto (kleinstes passendes DIN-Format, s. infostreifenFlaecheMm),
// canvas (Groesse folgt den Elementen) bzw. aus. INFOSTREIFEN-03 / NORMBLATT-DYNAMISCH-01 N-01
QSizeF Database::infostreifenFormatMm(const QString &modus, double seiteBreiteMm, double seiteHoeheMm)
{
    if (modus == QLatin1String("a4")) return {297.0, 210.0};
    if (modus == QLatin1String("a3")) return {420.0, 297.0};
    if (modus == QLatin1String("a2")) return {594.0, 420.0};
    if (modus == QLatin1String("a1")) return {841.0, 594.0};
    if (modus == QLatin1String("a0")) return {1189.0, 841.0};
    Q_UNUSED(seiteBreiteMm); Q_UNUSED(seiteHoeheMm);
    return {0.0, 0.0};   // auto, canvas, aus
}

bool Database::seiteInfostreifenSetzen(int seiteId, const QString &modus, const QString &ausrichtung)
{
    static const QStringList erlaubt = {"auto", "a4", "a3", "a2", "a1", "a0", "canvas", "aus"};
    if (!erlaubt.contains(modus) || (ausrichtung != QLatin1String("links") && ausrichtung != QLatin1String("rechts"))) {
        qCWarning(lcDb) << "seiteInfostreifenSetzen: ungueltige Werte" << modus << ausrichtung;
        return false;
    }
    QSqlQuery q(m_db);
    q.prepare("UPDATE seite SET infostreifen = :m, infostreifen_ausrichtung = :a WHERE id = :sid");
    q.bindValue(":m", modus);
    q.bindValue(":a", ausrichtung);
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "seiteInfostreifenSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::seiteNormblattLageSetzen(int seiteId, const QString &position, const QString &format,
                                        const QString &ausrichtung, bool rahmen)
{
    static const QStringList formate = {"auto", "a4", "a3", "a2", "a1", "a0", "canvas"};
    if ((position != QLatin1String("fest") && position != QLatin1String("inhalt")) || !formate.contains(format)
        || (ausrichtung != QLatin1String("links") && ausrichtung != QLatin1String("rechts"))) {
        qCWarning(lcDb) << "seiteNormblattLageSetzen: ungueltige Werte" << position << format << ausrichtung;
        return false;
    }
    QSqlQuery q(m_db);
    q.prepare("UPDATE seite SET normblatt_position = :p, normblatt_format = :f, normblatt_ausrichtung = :a, "
              "normblatt_rahmen = :r WHERE id = :sid");
    q.bindValue(":p", position); q.bindValue(":f", format); q.bindValue(":a", ausrichtung);
    q.bindValue(":r", rahmen ? 1 : 0); q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "seiteNormblattLageSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

namespace {
// Bounding-Box der Elemente einer Seite in mm (x1,y1,x2,y2 / 4) – gleiche Definition wie drawNormblatt() im Canvas
bool elementeBoxMm(const QSqlDatabase &db, int seiteId, QRectF &box)
{
    QSqlQuery q(db);
    q.prepare(R"(SELECT MIN(MIN(x1,x2)), MIN(MIN(y1,y2)), MAX(MAX(x1,x2)), MAX(MAX(y1,y2)), COUNT(*)
                 FROM grafik_element WHERE seite_id = :sid)");
    q.bindValue(":sid", seiteId);
    if (!q.exec() || !q.next() || q.value(4).toInt() == 0) return false;
    box = QRectF(QPointF(q.value(0).toDouble() / 4.0, q.value(1).toDouble() / 4.0),
                 QPointF(q.value(2).toDouble() / 4.0, q.value(3).toDouble() / 4.0));
    return true;
}
} // namespace

bool Database::infostreifenElementeZuGross(int seiteId, const QString &modus)
{
    if (modus == QLatin1String("auto") || modus == QLatin1String("canvas") || modus == QLatin1String("aus")) return false;
    QSqlQuery q(m_db);
    q.prepare("SELECT breite_mm, hoehe_mm FROM seite WHERE id = :sid");
    q.bindValue(":sid", seiteId);
    if (!q.exec() || !q.next()) return false;
    const QSizeF fmt = infostreifenFormatMm(modus, q.value(0).toDouble(), q.value(1).toDouble());
    QRectF box;
    if (!elementeBoxMm(m_db, seiteId, box)) return false;
    return box.width() + 30.0 > fmt.width() + 0.01 || box.height() + 30.0 > fmt.height() + 0.01;
}

// Format-Flaeche des Infostreifens (Seitenkoordinaten, mm); ungueltiges Rechteck = keine Flaeche (aus / keine Elemente).
QRectF Database::infostreifenFlaecheMm(int seiteId, const QVariantMap &nb)
{
    const QString modus = nb.value("infostreifenModus").toString();
    if (modus == QLatin1String("aus")) return {};
    QRectF box;
    if (!elementeBoxMm(m_db, seiteId, box)) return {};
    const double rand = 15.0;
    QSizeF fmt(nb.value("infostreifenBreiteMm").toDouble(), nb.value("infostreifenHoeheMm").toDouble());
    if (fmt.width() <= 0 || fmt.height() <= 0) {
        // auto: kleinstes DIN-Format quer (A4...A0), in das Box + Rand passt; passt keins oder canvas: Box + Rand, min. A4 breit
        const double nb_ = box.width() + 2 * rand, nh_ = box.height() + 2 * rand;
        static const QSizeF dinFormate[] = {{297, 210}, {420, 297}, {594, 420}, {841, 594}, {1189, 841}};
        fmt = QSizeF(qMax(297.0, nb_), nh_);
        if (modus == QLatin1String("auto")) {
            for (const QSizeF &f : dinFormate)
                if (f.width() >= nb_ && f.height() >= nh_) { fmt = f; break; }
        }
    }
    const double unten = box.bottom() + rand;
    const bool rechts = nb.value("infostreifenAusrichtung").toString() == QLatin1String("rechts");
    const double links = rechts ? box.right() + rand - fmt.width() : box.left() - rand;
    return QRectF(links, unten - fmt.height(), fmt.width(), fmt.height());
}

// Hoehe des Schriftfelds der eingebauten Vorlagen (mm); entspricht pdfNormblattRendern()/drawNormblatt()
static double normblattSchriftfeldHoeheMm(const QString &vorlage)
{
    if (vorlage == QLatin1String("kompakt")) return 2 * 8.0;
    if (vorlage == QLatin1String("rahmen"))  return 0.0;
    return 3 * 13.0;   // din6771
}

// Flaeche des Blatts bei Position "inhalt" (N-02, Konzept 54 §3.1). Ränder = Papierrand → Rahmen, P = Abstand Inhalt → Rahmen.
static QRectF normblattFlaecheBerechnen(const QRectF &box, const QSizeF &fmtVorgabe, const QString &format,
                                        const QString &ausrichtung, double sf, double rl, double rr, double ro, double ru)
{
    const double P = 10.0;
    const double needW = box.width() + 2 * P + rl + rr;
    const double needH = box.height() + 2 * P + sf + ro + ru;
    QSizeF fmt = fmtVorgabe;
    if (fmt.width() <= 0 || fmt.height() <= 0) {
        static const QSizeF din[] = {{297, 210}, {420, 297}, {594, 420}, {841, 594}, {1189, 841}};
        fmt = QSizeF(qMax(297.0, needW), needH);
        if (format == QLatin1String("auto")) {
            for (const QSizeF &f : din)
                if (f.width() >= needW && f.height() >= needH) { fmt = f; break; }
        }
    }
    const double rahmenUnten = box.bottom() + P + sf;
    const double rahmenLinks = ausrichtung == QLatin1String("rechts") ? box.right() + P - (fmt.width() - rl - rr)
                                                                       : box.left() - P;
    return QRectF(rahmenLinks - rl, rahmenUnten + ru - fmt.height(), fmt.width(), fmt.height());
}

QRectF Database::normblattFlaecheMm(int seiteId, const QVariantMap &nb)
{
    if (nb.value("normblattPosition").toString() != QLatin1String("inhalt")) return {};
    if (!nb.value("felder").toList().isEmpty()) return {};   // eigene Vorlage: nur Position fest (bis N-03)
    QRectF box;
    if (!elementeBoxMm(m_db, seiteId, box)) return {};
    return normblattFlaecheBerechnen(box,
        QSizeF(nb.value("normblattFormatBreiteMm").toDouble(), nb.value("normblattFormatHoeheMm").toDouble()),
        nb.value("normblattFormat").toString(), nb.value("normblattAusrichtung").toString(),
        normblattSchriftfeldHoeheMm(nb.value("titelblattVorlage").toString()),
        nb.value("randLinksMm").toDouble(), nb.value("randRechtsMm").toDouble(),
        nb.value("randObenMm").toDouble(),  nb.value("randUntenMm").toDouble());
}

bool Database::normblattInhaltZuGross(int seiteId, const QString &format, const QString &vorlage)
{
    const QSizeF fmt = infostreifenFormatMm(format, 0, 0);
    if (fmt.width() <= 0) return false;   // auto/canvas passen sich an
    const QVariantMap nb = normblattDatenLaden(seiteId);
    QRectF box;
    if (!elementeBoxMm(m_db, seiteId, box)) return false;
    const double sf = normblattSchriftfeldHoeheMm(vorlage);
    const double needW = box.width()  + 20.0 + nb.value("randLinksMm").toDouble() + nb.value("randRechtsMm").toDouble();
    const double needH = box.height() + 20.0 + sf + nb.value("randObenMm").toDouble() + nb.value("randUntenMm").toDouble();
    return needW > fmt.width() + 0.01 || needH > fmt.height() + 0.01;
}

bool Database::seiteInDokuPdfSetzen(int seiteId, bool inDokuPdf)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE seite SET in_doku_pdf = :v WHERE id = :sid");
    q.bindValue(":v",   inDokuPdf ? 1 : 0);
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "seiteInDokuPdfSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// seiteRevision*
// ============================================================

bool Database::seiteRevisionSetzen(int seiteId, const QString &status, const QString &kennung)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE seite SET revision_status = :st, revision_kennung = :kn WHERE id = :sid");
    q.bindValue(":st",  status);
    q.bindValue(":kn",  kennung);
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qCWarning(lcDb) << "seiteRevisionSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// normblattVorlagen* / normblattFelder*
// ============================================================

QVariantList Database::normblattVorlagenListe()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, name, beschreibung, ist_standard, breite_mm, hoehe_mm, "
                "rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm, art, "
                "(logo_data IS NOT NULL) AS hat_logo, COALESCE(bibliothek_uid,'') AS bib_uid "
                "FROM normblatt_vorlage ORDER BY name")) {
        qCWarning(lcDb) << "normblattVorlagenListe:" << q.lastError().text();
        return {};
    }
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]           = q.value("id");
        m[QStringLiteral("name")]         = q.value("name");
        m[QStringLiteral("beschreibung")] = q.value("beschreibung");
        m[QStringLiteral("istStandard")]  = q.value("ist_standard");
        m[QStringLiteral("breiteMm")]     = q.value("breite_mm");
        m[QStringLiteral("hoeheMm")]      = q.value("hoehe_mm");
        m[QStringLiteral("randLinksMm")]  = q.value("rand_links_mm");
        m[QStringLiteral("randRechtsMm")] = q.value("rand_rechts_mm");
        m[QStringLiteral("randObenMm")]   = q.value("rand_oben_mm");
        m[QStringLiteral("randUntenMm")]  = q.value("rand_unten_mm");
        m[QStringLiteral("art")]          = q.value("art");
        m[QStringLiteral("hatLogo")]      = q.value("hat_logo").toInt() != 0;
        m[QStringLiteral("bibliothekUid")] = q.value("bib_uid");
        result.append(m);
    }
    return result;
}

int Database::normblattVorlageSpeichern(const QVariantMap &v)
{
    QSqlQuery q(m_db);
    if (v.value(QStringLiteral("id")).toInt() > 0) {
        q.prepare(R"(UPDATE normblatt_vorlage SET
            name           = :name,
            beschreibung   = :beschr,
            breite_mm      = :bMm,
            hoehe_mm       = :hMm,
            rand_links_mm  = :rl,
            rand_rechts_mm = :rr,
            rand_oben_mm   = :ro,
            rand_unten_mm  = :ru,
            art            = COALESCE(:art, art)
            WHERE id = :id)");
        q.bindValue(":id",    v.value(QStringLiteral("id")));
    } else {
        q.prepare(R"(INSERT INTO normblatt_vorlage
            (name, beschreibung, breite_mm, hoehe_mm,
             rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm, art)
            VALUES (:name, :beschr, :bMm, :hMm, :rl, :rr, :ro, :ru, COALESCE(:art, 'schriftfeld')))");
    }
    q.bindValue(":name",   v.value(QStringLiteral("name")));
    q.bindValue(":beschr", v.value(QStringLiteral("beschreibung")));
    q.bindValue(":bMm",    v.value(QStringLiteral("breiteMm"),    297.0));
    q.bindValue(":hMm",    v.value(QStringLiteral("hoeheMm"),     210.0));
    q.bindValue(":rl",     v.value(QStringLiteral("randLinksMm"),  20.0));
    q.bindValue(":rr",     v.value(QStringLiteral("randRechtsMm"), 10.0));
    q.bindValue(":ro",     v.value(QStringLiteral("randObenMm"),   10.0));
    q.bindValue(":ru",     v.value(QStringLiteral("randUntenMm"),  10.0));
    q.bindValue(":art",    v.contains(QStringLiteral("art")) ? v.value(QStringLiteral("art"))
                                                              : QVariant(QMetaType(QMetaType::QString)));
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattVorlageSpeichern:" << q.lastError().text();
        return -1;
    }
    if (v.value(QStringLiteral("id")).toInt() > 0)
        return v.value(QStringLiteral("id")).toInt();
    return q.lastInsertId().toInt();
}

bool Database::normblattVorlageLoeschen(int vorlageId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM normblatt_vorlage WHERE id = :id");
    q.bindValue(":id", vorlageId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattVorlageLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::normblattVorlageLogoSpeichern(int vorlageId, const QString &pfad)
{
    QByteArray data; QString mime;
    if (!logoDateiLesen(pfad, data, mime, "normblattVorlageLogoSpeichern")) return false;
    QSqlQuery q(m_db);
    q.prepare("UPDATE normblatt_vorlage SET logo_data = :d, logo_mime = :m WHERE id = :id");
    q.bindValue(":d", data);
    q.bindValue(":m", mime);
    q.bindValue(":id", vorlageId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattVorlageLogoSpeichern:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool Database::normblattVorlageLogoLoeschen(int vorlageId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE normblatt_vorlage SET logo_data = NULL, logo_mime = NULL WHERE id = :id");
    q.bindValue(":id", vorlageId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattVorlageLogoLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// Daten für ein Deckblatt aus einer Vorlage der Art 'deckblatt' (BLATTVORLAGEN-01b). Gleiche Schlüssel
// wie normblattDatenLaden(), damit pdfNormblattRendern() beides zeichnen kann. vorlageId <= 0:
// erste Deckblattvorlage (ist_standard zuerst). Leere Map = keine Vorlage vorhanden.
QVariantMap Database::deckblattDatenLaden(int projektId, int vorlageId, const QString &titelzusatz, bool mitLogo)
{
    QSqlQuery qv(m_db);
    if (vorlageId > 0) {
        qv.prepare("SELECT id, breite_mm, hoehe_mm, logo_data, logo_mime FROM normblatt_vorlage WHERE id = :id");
        qv.bindValue(":id", vorlageId);
    } else {
        qv.prepare("SELECT id, breite_mm, hoehe_mm, logo_data, logo_mime FROM normblatt_vorlage "
                   "WHERE art = 'deckblatt' ORDER BY ist_standard DESC, id LIMIT 1");
    }
    if (!qv.exec() || !qv.next()) return {};
    const int vid = qv.value(0).toInt();

    QVariantMap m;
    m[QStringLiteral("breiteMm")]   = qv.value(1);
    m[QStringLiteral("hoeheMm")]    = qv.value(2);
    m[QStringLiteral("ohneRahmen")] = true;
    m[QStringLiteral("felder")]     = normblattFelderLaden(vid);
    m[QStringLiteral("titelzusatz")] = titelzusatz;

    QSqlQuery qp(m_db);
    qp.prepare("SELECT name, projektnummer, auftraggeber, auftragnehmer, bearbeiter, werk, abteilung, norm, erstellt_am "
               "FROM projekt WHERE id = :pid");
    qp.bindValue(":pid", projektId);
    if (qp.exec() && qp.next()) {
        m[QStringLiteral("projektName")]   = qp.value(0);
        m[QStringLiteral("projektnummer")] = qp.value(1);
        m[QStringLiteral("auftraggeber")]  = qp.value(2);
        m[QStringLiteral("auftragnehmer")] = qp.value(3);
        m[QStringLiteral("bearbeiter")]    = qp.value(4);
        m[QStringLiteral("werk")]          = qp.value(5);
        m[QStringLiteral("abteilung")]     = qp.value(6);
        m[QStringLiteral("norm")]          = qp.value(7);
        m[QStringLiteral("erstelltAm")]    = qp.value(8);
    }
    if (mitLogo) {
        // logo: Logo der Vorlage; logo_kunde: Kunden-Logo des Projekts
        logoInMap(m, QStringLiteral("logoDataUrl"), QStringLiteral("logoAspekt"),
                  qv.value(3).toByteArray(), qv.value(4).toString());
        QSqlQuery ql(m_db);
        ql.prepare("SELECT kunden_logo_data, kunden_logo_mime FROM projekt WHERE id = :pid");
        ql.bindValue(":pid", projektId);
        if (ql.exec() && ql.next())
            logoInMap(m, QStringLiteral("kundenLogoDataUrl"), QStringLiteral("kundenLogoAspekt"),
                      ql.value(0).toByteArray(), ql.value(1).toString());
    }
    return m;
}

QVariantMap Database::infostreifenLaden(int seiteId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT nv.id, nv.breite_mm, nv.hoehe_mm, nv.logo_data, nv.logo_mime
        FROM seite s
        JOIN ort o ON s.ort_id = o.id
        JOIN anlage a ON o.anlage_id = a.id
        JOIN projekt p ON a.projekt_id = p.id
        JOIN normblatt_vorlage nv ON nv.art = 'infostreifen'
        WHERE s.id = :sid
        ORDER BY (nv.id = p.infostreifen_vorlage_id) DESC, nv.ist_standard DESC, nv.id
        LIMIT 1)");
    q.bindValue(":sid", seiteId);
    if (!q.exec() || !q.next()) return {};
    QVariantMap m;
    m[QStringLiteral("breiteMm")] = q.value(1);
    m[QStringLiteral("hoeheMm")]  = q.value(2);
    m[QStringLiteral("felder")]   = normblattFelderLaden(q.value(0).toInt());
    logoInMap(m, QStringLiteral("logoDataUrl"), QStringLiteral("logoAspekt"),
              q.value(3).toByteArray(), q.value(4).toString());
    return m;
}

int Database::projektInfostreifenVorlageId()
{
    QSqlQuery q(m_db);
    if (q.exec("SELECT COALESCE(infostreifen_vorlage_id, 0) FROM projekt ORDER BY id DESC LIMIT 1") && q.next())
        return q.value(0).toInt();
    return 0;
}

bool Database::projektInfostreifenVorlageSetzen(int vorlageId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET infostreifen_vorlage_id = :v WHERE id = (SELECT id FROM projekt ORDER BY id DESC LIMIT 1)");
    q.bindValue(":v", vorlageId > 0 ? QVariant(vorlageId) : QVariant());
    if (!q.exec()) {
        qCWarning(lcDb) << "projektInfostreifenVorlageSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::normblattFelderLaden(int vorlageId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(SELECT id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm,
                        label, inhalt, quelle_spalte,
                        schriftgroesse, fett, rahmen, reihenfolge
                 FROM normblatt_feld
                 WHERE vorlage_id = :vid
                 ORDER BY reihenfolge, id)");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattFelderLaden:" << q.lastError().text();
        return {};
    }
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]            = q.value("id");
        m[QStringLiteral("feldtyp")]       = q.value("feldtyp");
        m[QStringLiteral("xMm")]           = q.value("x_mm");
        m[QStringLiteral("yMm")]           = q.value("y_mm");
        m[QStringLiteral("breiteMm")]      = q.value("breite_mm");
        m[QStringLiteral("hoeheMm")]       = q.value("hoehe_mm");
        m[QStringLiteral("label")]         = q.value("label");
        m[QStringLiteral("inhalt")]        = q.value("inhalt");
        m[QStringLiteral("quelleSpalte")]  = q.value("quelle_spalte");
        m[QStringLiteral("schriftgroesse")]= q.value("schriftgroesse");
        m[QStringLiteral("fett")]          = q.value("fett");
        m[QStringLiteral("rahmen")]        = q.value("rahmen");
        m[QStringLiteral("reihenfolge")]   = q.value("reihenfolge");
        result.append(m);
    }
    return result;
}

bool Database::normblattFelderSpeichern(int vorlageId, const QVariantList &felder)
{
    if (!m_db.transaction()) {
        qCWarning(lcDb) << "normblattFelderSpeichern: Transaction fehlgeschlagen";
        return false;
    }
    if (!normblattFelderSchreiben(vorlageId, felder)) {
        m_db.rollback();
        return false;
    }
    m_db.commit();
    return true;
}

// Felder einer Vorlage ersetzen – ohne eigene Transaktion (Aufrufer klammert, z.B. Bibliotheks-Übernahme).
bool Database::normblattFelderSchreiben(int vorlageId, const QVariantList &felder)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM normblatt_feld WHERE vorlage_id = :vid");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattFelderSpeichern DELETE:" << q.lastError().text();
        return false;
    }
    q.prepare(R"(INSERT INTO normblatt_feld
        (vorlage_id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm,
         label, inhalt, quelle_spalte, schriftgroesse, fett, rahmen, reihenfolge)
        VALUES (:vid, :ft, :x, :y, :b, :h, :lbl, :inh, :qs, :sg, :fett, :rahmen, :rei))");
    for (int i = 0; i < felder.size(); ++i) {
        const QVariantMap f = felder[i].toMap();
        q.bindValue(":vid",    vorlageId);
        q.bindValue(":ft",     f.value(QStringLiteral("feldtyp"), QStringLiteral("fest")));
        q.bindValue(":x",      f.value(QStringLiteral("xMm"), 0.0));
        q.bindValue(":y",      f.value(QStringLiteral("yMm"), 0.0));
        q.bindValue(":b",      f.value(QStringLiteral("breiteMm"), 50.0));
        q.bindValue(":h",      f.value(QStringLiteral("hoeheMm"), 13.0));
        q.bindValue(":lbl",    f.value(QStringLiteral("label")));
        q.bindValue(":inh",    f.value(QStringLiteral("inhalt")));
        q.bindValue(":qs",     f.value(QStringLiteral("quelleSpalte")));
        q.bindValue(":sg",     f.value(QStringLiteral("schriftgroesse"), 3.5));
        q.bindValue(":fett",   f.value(QStringLiteral("fett"), 0));
        q.bindValue(":rahmen", f.value(QStringLiteral("rahmen"), 1));
        q.bindValue(":rei",    i);
        if (!q.exec()) {
            qCWarning(lcDb) << "normblattFelderSpeichern INSERT:" << q.lastError().text();
            return false;
        }
    }
    return true;
}

bool Database::projektMetaSpeichern(int projektId,
                                     const QString &name,
                                     const QString &projektnummer,
                                     const QString &auftraggeber,
                                     const QString &auftragnehmer,
                                     const QString &bearbeiter)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET name = :name, projektnummer = :nr, "
              "auftraggeber = :ag, auftragnehmer = :an, bearbeiter = :be "
              "WHERE id = :id");
    q.bindValue(":name", name);
    q.bindValue(":nr",   projektnummer);
    q.bindValue(":ag",   auftraggeber);
    q.bindValue(":an",   auftragnehmer);
    q.bindValue(":be",   bearbeiter);
    q.bindValue(":id",   projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "projektMetaSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// Kunden-Logo je Projekt (BLATTVORLAGEN-02): Feldtyp logo_kunde in Blattvorlagen
bool Database::projektKundenLogoSpeichern(int projektId, const QString &pfad)
{
    QByteArray data; QString mime;
    if (!logoDateiLesen(pfad, data, mime, "projektKundenLogoSpeichern")) return false;
    QImage probe;
    if (!probe.loadFromData(data)) { qCWarning(lcDb) << "projektKundenLogoSpeichern: kein Bild"; return false; }
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET kunden_logo_data = :d, kunden_logo_mime = :m WHERE id = :id");
    q.bindValue(":d",  data);
    q.bindValue(":m",  mime);
    q.bindValue(":id", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "projektKundenLogoSpeichern:" << q.lastError().text(); return false; }
    return q.numRowsAffected() > 0;
}

QString Database::projektKundenLogoDataUrl(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT kunden_logo_data, kunden_logo_mime FROM projekt WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec() || !q.next()) return {};
    QByteArray data = q.value(0).toByteArray();
    QString    mime = q.value(1).toString();
    if (data.isEmpty() || mime.isEmpty()) return {};
    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

bool Database::projektKundenLogoLoeschen(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET kunden_logo_data = NULL, kunden_logo_mime = NULL WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "projektKundenLogoLoeschen:" << q.lastError().text(); return false; }
    return true;
}

// ============================================================
// seiteDuplizieren
// Kopiert eine Seite inkl. aller Grafik-Elemente.
// Gibt die neue seiteId zurück (-1 bei Fehler).
// ============================================================
int Database::seiteDuplizieren(int seiteId)
{
    if (!m_projektOffen) return -1;

    // Quelldaten der Seite lesen
    QSqlQuery qs(m_db);
    qs.prepare("SELECT ort_id, blattnummer, bezeichnung, seitentyp, "
               "       normblatt_anzeigen, normblatt_id, "
               "       rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm, "
               "       breite_mm, hoehe_mm, ausrichtung, in_doku_pdf "
               "FROM seite WHERE id = :sid");
    qs.bindValue(":sid", seiteId);
    if (!qs.exec() || !qs.next()) {
        qCWarning(lcDb) << "seiteDuplizieren: Seite nicht gefunden:" << seiteId;
        return -1;
    }

    QString neueBlattnummer = qs.value(1).toString() + "-K";
    QString neueBezeichnung = qs.value(2).toString() + " (Kopie)";

    if (!m_db.transaction()) return -1;

    // Neue Seite anlegen
    QSqlQuery qi(m_db);
    qi.prepare(R"(
        INSERT INTO seite (ort_id, blattnummer, bezeichnung, seitentyp,
                           normblatt_anzeigen, normblatt_id,
                           rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm,
                           breite_mm, hoehe_mm, ausrichtung, in_doku_pdf)
        VALUES (:oid,:bn,:bez,:st,:na,:nv,:rl,:rr,:ro,:ru,:bw,:bh,:aus,:idp)
    )");
    qi.bindValue(":oid",  qs.value(0));
    qi.bindValue(":bn",   neueBlattnummer);
    qi.bindValue(":bez",  neueBezeichnung);
    qi.bindValue(":st",   qs.value(3));
    qi.bindValue(":na",   qs.value(4));
    qi.bindValue(":nv",   qs.value(5));
    qi.bindValue(":rl",   qs.value(6));
    qi.bindValue(":rr",   qs.value(7));
    qi.bindValue(":ro",   qs.value(8));
    qi.bindValue(":ru",   qs.value(9));
    qi.bindValue(":bw",   qs.value(10));
    qi.bindValue(":bh",   qs.value(11));
    qi.bindValue(":aus",  qs.value(12));
    qi.bindValue(":idp",  qs.value(13));
    if (!qi.exec()) {
        qCWarning(lcDb) << "seiteDuplizieren: neue Seite anlegen:" << qi.lastError().text();
        m_db.rollback();
        return -1;
    }
    int neueSeiteId = qi.lastInsertId().toInt();

    // Alle Grafik-Elemente kopieren
    QSqlQuery qe(m_db);
    qe.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
             sortierung, symbol_id, rotation, spiegel_x, spiegel_y,
             extra_daten, gruppe_id)
        SELECT :nsid, typ, x1, y1, x2, y2,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
               sortierung, symbol_id, rotation, spiegel_x, spiegel_y,
               extra_daten, NULL
        FROM grafik_element WHERE seite_id = :osid
    )");
    qe.bindValue(":nsid", neueSeiteId);
    qe.bindValue(":osid", seiteId);
    if (!qe.exec()) {
        qCWarning(lcDb) << "seiteDuplizieren: Elemente kopieren:" << qe.lastError().text();
        m_db.rollback();
        return -1;
    }

    if (!m_db.commit()) { m_db.rollback(); return -1; }
    return neueSeiteId;
}

