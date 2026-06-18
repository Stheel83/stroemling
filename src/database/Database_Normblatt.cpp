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
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <algorithm>

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
               s.revision_status, s.revision_kennung,
               p.name         AS projekt_name,
               p.projektnummer,
               p.auftraggeber,
               p.auftragnehmer,
               p.bearbeiter,
               p.norm,
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
    m[QStringLiteral("revisionKennung")]  = q.value("revision_kennung");
    m[QStringLiteral("projektName")]      = q.value("projekt_name");
    m[QStringLiteral("projektnummer")]    = q.value("projektnummer");
    m[QStringLiteral("auftraggeber")]     = q.value("auftraggeber");
    m[QStringLiteral("auftragnehmer")]    = q.value("auftragnehmer");
    m[QStringLiteral("bearbeiter")]       = q.value("bearbeiter");
    m[QStringLiteral("norm")]             = q.value("norm");

    // Logo als Data-URL — separater Query damit der BLOB-Join nicht bei jeder
    // Seite lädt wenn kein Logo gesetzt ist.
    {
        QSqlQuery ql;
        ql.prepare(R"(
            SELECT p.logo_data, p.logo_mime
            FROM seite s
            JOIN ort o ON s.ort_id = o.id
            JOIN anlage a ON o.anlage_id = a.id
            JOIN projekt p ON a.projekt_id = p.id
            WHERE s.id = :sid AND p.logo_data IS NOT NULL
        )");
        ql.bindValue(":sid", seiteId);
        if (ql.exec() && ql.next()) {
            QByteArray logoData = ql.value(0).toByteArray();
            QString    logoMime = ql.value(1).toString();
            if (!logoData.isEmpty() && !logoMime.isEmpty())
                m[QStringLiteral("logoDataUrl")] = QStringLiteral("data:") + logoMime
                    + QStringLiteral(";base64,") + QString::fromLatin1(logoData.toBase64());
        }
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
                "rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm "
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
            rand_unten_mm  = :ru
            WHERE id = :id)");
        q.bindValue(":id",    v.value(QStringLiteral("id")));
    } else {
        q.prepare(R"(INSERT INTO normblatt_vorlage
            (name, beschreibung, breite_mm, hoehe_mm,
             rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm)
            VALUES (:name, :beschr, :bMm, :hMm, :rl, :rr, :ro, :ru))");
    }
    q.bindValue(":name",   v.value(QStringLiteral("name")));
    q.bindValue(":beschr", v.value(QStringLiteral("beschreibung")));
    q.bindValue(":bMm",    v.value(QStringLiteral("breiteMm"),    297.0));
    q.bindValue(":hMm",    v.value(QStringLiteral("hoeheMm"),     210.0));
    q.bindValue(":rl",     v.value(QStringLiteral("randLinksMm"),  20.0));
    q.bindValue(":rr",     v.value(QStringLiteral("randRechtsMm"), 10.0));
    q.bindValue(":ro",     v.value(QStringLiteral("randObenMm"),   10.0));
    q.bindValue(":ru",     v.value(QStringLiteral("randUntenMm"),  10.0));
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
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM normblatt_feld WHERE vorlage_id = :vid");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qCWarning(lcDb) << "normblattFelderSpeichern DELETE:" << q.lastError().text();
        m_db.rollback();
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
            m_db.rollback();
            return false;
        }
    }
    m_db.commit();
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

bool Database::projektLogoSpeichern(int projektId, const QString &pfad)
{
    QUrl url(pfad);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;

    QFileInfo info(localPath);
    if (!info.exists()) { qCWarning(lcDb) << "projektLogoSpeichern: Datei nicht gefunden:" << localPath; return false; }
    if (info.size() > 5 * 1024 * 1024) { qCWarning(lcDb) << "projektLogoSpeichern: Datei zu groß"; return false; }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) { qCWarning(lcDb) << "projektLogoSpeichern: Öffnen fehlgeschlagen"; return false; }
    QByteArray data = file.readAll();
    file.close();

    QString suffix = info.suffix().toLower();
    QString mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg") || suffix == QLatin1String("jpeg")) mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))  mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))  mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("webp")) mime = QStringLiteral("image/webp");

    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET logo_data = :d, logo_mime = :m WHERE id = :id");
    q.bindValue(":d",  data);
    q.bindValue(":m",  mime);
    q.bindValue(":id", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "projektLogoSpeichern:" << q.lastError().text(); return false; }
    return true;
}

QString Database::projektLogoDataUrl(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT logo_data, logo_mime FROM projekt WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec() || !q.next()) return {};
    QByteArray data = q.value(0).toByteArray();
    QString    mime = q.value(1).toString();
    if (data.isEmpty() || mime.isEmpty()) return {};
    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

bool Database::projektLogoLoeschen(int projektId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE projekt SET logo_data = NULL, logo_mime = NULL WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "projektLogoLoeschen:" << q.lastError().text(); return false; }
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
               "       breite_mm, hoehe_mm, ausrichtung "
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
                           breite_mm, hoehe_mm, ausrichtung)
        VALUES (:oid,:bn,:bez,:st,:na,:nv,:rl,:rr,:ro,:ru,:bw,:bh,:aus)
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

