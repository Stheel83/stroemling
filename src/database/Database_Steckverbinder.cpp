#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <cmath>

// ── steckverbinderListe ──────────────────────────────────────────────────────
// Alle Gerätekästen des Projekts mit verknüpftem Steckverbinder-Bauteil,
// für die Steckverbinderliste in der ListenAnsicht.
QVariantList Database::steckverbinderListe(int projektId) const
{
    QVariantList liste;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
               COALESCE(json_extract(ge.extra_daten, '$.bezeichnung'), ''),
               COALESCE(b.bezeichnung, ''),
               COALESCE(b.hersteller, ''),
               COALESCE(b.artikelnummer, ''),
               COALESCE(sv.polzahl, 0),
               COALESCE(sv.ip_gesteckt, ''),
               COALESCE(sv.ip_getrennt, ''),
               COALESCE(sv.kodierung, ''),
               COALESCE(sv.verriegelung, ''),
               sv.geschirmt,
               sv.hat_schirmkontakt,
               s.blattnummer,
               COALESCE(s.bezeichnung, ''),
               ge.id
        FROM grafik_element ge
        JOIN seite  s ON s.id = ge.seite_id
        JOIN ort    o ON o.id = s.ort_id
        JOIN anlage a ON a.id = o.anlage_id
        JOIN bauteil b ON b.id = CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER)
        JOIN steckverbinder_typ sv ON sv.bauteil_id = b.id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'geraetekasten'
          AND CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER) > 0
        ORDER BY COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
                 s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderListe:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["bmk"]             = q.value(0).toString();
        m["gkBezeichnung"]   = q.value(1).toString();
        m["bauteilBez"]      = q.value(2).toString();
        m["hersteller"]      = q.value(3).toString();
        m["artikelnummer"]   = q.value(4).toString();
        m["polzahl"]         = q.value(5).toInt();
        m["ipGesteckt"]      = q.value(6).toString();
        m["ipGetrennt"]      = q.value(7).toString();
        m["kodierung"]       = q.value(8).toString();
        m["verriegelung"]    = q.value(9).toString();
        m["geschirmt"]       = q.value(10).toInt() != 0;
        m["hatSchirmkontakt"]= q.value(11).toInt() != 0;
        m["blattnr"]         = q.value(12).toString();
        m["seiteBez"]        = q.value(13).toString();
        m["grafikElementId"] = q.value(14).toInt();
        liste.append(m);
    }
    return liste;
}

// ── steckverbinderlisteCsvSpeichern ─────────────────────────────────────────
bool Database::steckverbinderlisteCsvSpeichern(int projektId, const QString &pfad) const
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "steckverbinderlisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "BMK;Bezeichnung;Bauteil/Typ;Hersteller;Artikelnr.;Polzahl;IP gesteckt;IP getrennt;Kodierung;Verriegelung;Geschirmt;Seite\n";
    auto q = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : steckverbinderListe(projektId)) {
        const QVariantMap row = v.toMap();
        out << q(row["bmk"].toString())          << u';'
            << q(row["gkBezeichnung"].toString()) << u';'
            << q(row["bauteilBez"].toString())    << u';'
            << q(row["hersteller"].toString())    << u';'
            << q(row["artikelnummer"].toString()) << u';'
            << row["polzahl"].toInt()             << u';'
            << q(row["ipGesteckt"].toString())    << u';'
            << q(row["ipGetrennt"].toString())    << u';'
            << q(row["kodierung"].toString())     << u';'
            << q(row["verriegelung"].toString())  << u';'
            << (row["geschirmt"].toBool() ? "Ja" : "Nein") << u';'
            << q(row["blattnr"].toString())       << u'\n';
    }
    return true;
}

// ── steckverbinderBelegungsplan ──────────────────────────────────────────────
// Liefert eine gemischte Liste für die Belegungsplan-Ansicht:
//   {typ:"gehaeuse", bmk, gkBez, bauteilBez, polzahl, geschirmt, blattnr}
//   {typ:"kontakt",  gkBmk, kontaktTyp, kontaktBmk, kontaktBez,
//                    signalBez, signalFarbe, querschnitt, blattnr}
// Grundlage: Geometrische Enthaltung (Mittelpunkt des Symbols im GK-Rahmen).
// Signalzuordnung: verbindung_segment-Endpunkte nahe der Pin-1-Weltposition.
QVariantList Database::steckverbinderBelegungsplan(int projektId) const
{
    QVariantList result;

    // Alle GKs mit Steckverbinder-Bauteil + enthaltene Kontaktsymbole
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT
            gk.id,
            COALESCE(json_extract(gk.extra_daten, '$.bmk'), ''),
            COALESCE(json_extract(gk.extra_daten, '$.bezeichnung'), ''),
            gk.seite_id,
            COALESCE(b.bezeichnung, ''),
            COALESCE(sv.polzahl, 0),
            sv.geschirmt,
            s.blattnummer,
            ge2.id,
            ge2.typ,
            COALESCE(json_extract(ge2.extra_daten, '$.bmk'), ''),
            COALESCE(json_extract(ge2.extra_daten, '$.pinBez'), ''),
            ge2.rotation,
            ge2.spiegel_x,
            ge2.spiegel_y,
            ge2.x1, ge2.y1, ge2.x2, ge2.y2
        FROM grafik_element gk
        JOIN seite  s  ON s.id  = gk.seite_id
        JOIN ort    o  ON o.id  = s.ort_id
        JOIN anlage a  ON a.id  = o.anlage_id
        JOIN bauteil b ON b.id  = CAST(json_extract(gk.extra_daten, '$.bauteil_id') AS INTEGER)
        JOIN steckverbinder_typ sv ON sv.bauteil_id = b.id
        JOIN grafik_element ge2 ON ge2.seite_id = gk.seite_id
          AND ge2.typ IN ('stecker', 'buchse', 'geraeteanschluss')
          AND (ge2.x1 + ge2.x2) / 2.0 BETWEEN gk.x1 AND gk.x2
          AND (ge2.y1 + ge2.y2) / 2.0 BETWEEN gk.y1 AND gk.y2
        WHERE a.projekt_id = :pid
          AND gk.typ = 'geraetekasten'
          AND CAST(json_extract(gk.extra_daten, '$.bauteil_id') AS INTEGER) > 0
        ORDER BY COALESCE(json_extract(gk.extra_daten, '$.bmk'), ''),
                 gk.id,
                 ge2.typ,
                 COALESCE(json_extract(ge2.extra_daten, '$.bmk'), '')
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderBelegungsplan:" << q.lastError().text();
        return result;
    }

    // Signal-Abfrage (vorbereitet, pro Kontakt wiederverwendet)
    QSqlQuery sigQ(m_db);
    sigQ.prepare(R"(
        SELECT v.bezeichnung, v.farbe, v.querschnitt_mm2
        FROM verbindung v
        JOIN verbindung_segment vs ON vs.verbindung_id = v.id
        WHERE vs.seite_id = :sid
          AND (
              (ABS(json_extract(vs.punkte, '$[0].x') - :px) < 0.5
               AND ABS(json_extract(vs.punkte, '$[0].y') - :py) < 0.5)
              OR
              (ABS(json_extract(vs.punkte, '$[1].x') - :px) < 0.5
               AND ABS(json_extract(vs.punkte, '$[1].y') - :py) < 0.5)
          )
        ORDER BY v.bezeichnung
        LIMIT 1
    )");

    int lastGkId = -1;
    QString lastGkBmk;

    while (q.next()) {
        const int     gkId       = q.value(0).toInt();
        const QString gkBmk      = q.value(1).toString();
        const QString gkBez      = q.value(2).toString();
        const int     seiteId    = q.value(3).toInt();
        const QString bauteilBez = q.value(4).toString();
        const int     polzahl    = q.value(5).toInt();
        const bool    geschirmt  = q.value(6).toInt() != 0;
        const QString blattnr    = q.value(7).toString();

        const QString kontaktTyp = q.value(9).toString();
        const QString kontaktBmk = q.value(10).toString();
        const QString pinBezJson = q.value(11).toString();
        const double  rotation   = q.value(12).toDouble();
        const bool    spiegelX   = q.value(13).toInt() != 0;
        const bool    spiegelY   = q.value(14).toInt() != 0;
        const double  kx1 = q.value(15).toDouble(), ky1 = q.value(16).toDouble();
        const double  kx2 = q.value(17).toDouble(), ky2 = q.value(18).toDouble();

        // Gehäuse-Kopfzeile bei GK-Wechsel
        if (gkId != lastGkId) {
            QVariantMap h;
            h[QStringLiteral("typ")]        = QStringLiteral("gehaeuse");
            h[QStringLiteral("bmk")]        = gkBmk;
            h[QStringLiteral("gkBez")]      = gkBez;
            h[QStringLiteral("bauteilBez")] = bauteilBez;
            h[QStringLiteral("polzahl")]    = polzahl;
            h[QStringLiteral("geschirmt")]  = geschirmt;
            h[QStringLiteral("blattnr")]    = blattnr;
            result.append(h);
            lastGkId  = gkId;
            lastGkBmk = gkBmk;
        }

        // Kontaktbezeichnung aus pinBez["1"] (Verdrahtungsseite)
        QString kontaktBez = QStringLiteral("1");
        if (!pinBezJson.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(pinBezJson.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                const QString v = doc.object()[QStringLiteral("1")].toString();
                if (!v.isEmpty()) kontaktBez = v;
            }
        }

        // Weltposition von Pin 1 (Verdrahtungsseite)
        // stecker/buchse: (0.25, 0.5) · geraeteanschluss: (1.0, 0.5)
        const double pin1x = (kontaktTyp == QLatin1String("geraeteanschluss")) ? 1.0 : 0.25;
        const double sw = kx2 - kx1, sh = ky2 - ky1;
        double cx = (pin1x - 0.5) * std::abs(sw);
        double cy = 0.0; // pin1y = 0.5 → cy = 0
        if (spiegelX) cx = -cx;
        if (spiegelY) cy = -cy;
        const double rot = rotation * M_PI / 180.0;
        const double worldX = (kx1 + sw / 2.0) + cx * std::cos(rot) - cy * std::sin(rot);
        const double worldY = (ky1 + sh / 2.0) + cx * std::sin(rot) + cy * std::cos(rot);

        // Signal an dieser Position
        QString signalBez, signalFarbe;
        double  querschnitt = 0.0;
        sigQ.bindValue(QStringLiteral(":sid"), seiteId);
        sigQ.bindValue(QStringLiteral(":px"),  worldX);
        sigQ.bindValue(QStringLiteral(":py"),  worldY);
        if (sigQ.exec() && sigQ.next()) {
            signalBez   = sigQ.value(0).toString();
            signalFarbe = sigQ.value(1).toString();
            querschnitt = sigQ.value(2).toDouble();
        }

        QVariantMap k;
        k[QStringLiteral("typ")]         = QStringLiteral("kontakt");
        k[QStringLiteral("gkBmk")]       = lastGkBmk;
        k[QStringLiteral("kontaktTyp")]  = kontaktTyp;
        k[QStringLiteral("kontaktBmk")]  = kontaktBmk;
        k[QStringLiteral("kontaktBez")]  = kontaktBez;
        k[QStringLiteral("signalBez")]   = signalBez;
        k[QStringLiteral("signalFarbe")] = signalFarbe;
        k[QStringLiteral("querschnitt")] = querschnitt;
        k[QStringLiteral("blattnr")]     = blattnr;
        result.append(k);
    }
    return result;
}

// ── steckverbinderBelegungsplanCsvSpeichern ──────────────────────────────────
bool Database::steckverbinderBelegungsplanCsvSpeichern(int projektId, const QString &pfad) const
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "steckverbinderBelegungsplanCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "GK-BMK;Typ;Symbol-BMK;Pin;Signal;Aderfarbe;Querschnitt mm²;Seite\n";
    auto q = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    QString currentGkBmk;
    for (const QVariant &v : steckverbinderBelegungsplan(projektId)) {
        const QVariantMap row = v.toMap();
        if (row[QStringLiteral("typ")] == QLatin1String("gehaeuse")) {
            currentGkBmk = row[QStringLiteral("bmk")].toString();
        } else {
            const double qs = row[QStringLiteral("querschnitt")].toDouble();
            out << q(currentGkBmk)                                   << u';'
                << q(row[QStringLiteral("kontaktTyp")].toString())   << u';'
                << q(row[QStringLiteral("kontaktBmk")].toString())   << u';'
                << q(row[QStringLiteral("kontaktBez")].toString())   << u';'
                << q(row[QStringLiteral("signalBez")].toString())    << u';'
                << q(row[QStringLiteral("signalFarbe")].toString())  << u';'
                << (qs > 0 ? QString::number(qs) : QString())        << u';'
                << q(row[QStringLiteral("blattnr")].toString())      << u'\n';
        }
    }
    return true;
}

// ── steckverbinderBausteineListe ─────────────────────────────────────────────
// Alle Bauteile mit einem steckverbinder_typ-Eintrag (für den EP-Picker).
QVariantList Database::steckverbinderBausteineListe() const
{
    QVariantList liste;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT b.id, COALESCE(b.bezeichnung,''), COALESCE(b.hersteller,''),
               COALESCE(b.artikelnummer,''), sv.polzahl
        FROM bauteil b
        JOIN steckverbinder_typ sv ON sv.bauteil_id = b.id
        ORDER BY b.bezeichnung COLLATE NOCASE
    )");
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderBausteineListe:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0).toInt();
        m["bezeichnung"]  = q.value(1).toString();
        m["hersteller"]   = q.value(2).toString();
        m["artikelnummer"]= q.value(3).toString();
        m["polzahl"]      = q.value(4).toInt();
        liste.append(m);
    }
    return liste;
}

// ── steckverbinderTypLaden ───────────────────────────────────────────────────
// Lädt den steckverbinder_typ-Datensatz für ein Bauteil.
// Gibt eine leere Map zurück wenn kein Eintrag vorhanden.
QVariantMap Database::steckverbinderTypLaden(int bauteilId) const
{
    QVariantMap m;
    if (bauteilId < 0) return m;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, polzahl, ip_getrennt, ip_gesteckt, kodierung,
               verriegelung, hat_schirmkontakt, geschirmt
        FROM steckverbinder_typ WHERE bauteil_id = :bid
    )");
    q.bindValue(":bid", bauteilId);
    if (!q.exec() || !q.next()) return m;
    m["id"]              = q.value(0).toInt();
    m["polzahl"]         = q.value(1).toInt();
    m["ipGetrennt"]      = q.value(2).toString();
    m["ipGesteckt"]      = q.value(3).toString();
    m["kodierung"]       = q.value(4).toString();
    m["verriegelung"]    = q.value(5).toString();
    m["hatSchirmkontakt"] = q.value(6).toInt() != 0;
    m["geschirmt"]       = q.value(7).toInt() != 0;
    return m;
}

// ── steckverbinderTypSpeichern ───────────────────────────────────────────────
// INSERT OR REPLACE des steckverbinder_typ-Datensatzes.
// Gibt die id zurück (>0) oder -1 bei Fehler.
int Database::steckverbinderTypSpeichern(int bauteilId, int polzahl,
    const QString &ipGetrennt, const QString &ipGesteckt,
    const QString &kodierung, const QString &verriegelung,
    bool hatSchirmkontakt, bool geschirmt)
{
    QSqlQuery sel(m_db);
    sel.prepare("SELECT id FROM steckverbinder_typ WHERE bauteil_id = :bid");
    sel.bindValue(":bid", bauteilId);
    if (!sel.exec()) {
        qCWarning(lcDb) << "steckverbinderTypSpeichern SELECT:" << sel.lastError().text();
        return -1;
    }

    QSqlQuery q(m_db);
    if (sel.next()) {
        int existingId = sel.value(0).toInt();
        q.prepare(R"(
            UPDATE steckverbinder_typ
            SET polzahl=:pz, ip_getrennt=:ipg, ip_gesteckt=:ipgs,
                kodierung=:kod, verriegelung=:ver,
                hat_schirmkontakt=:hsk, geschirmt=:gsch
            WHERE id=:id
        )");
        q.bindValue(":id",  existingId);
        q.bindValue(":pz",  polzahl > 0 ? polzahl : QVariant());
        q.bindValue(":ipg", ipGetrennt.isEmpty()  ? QVariant() : ipGetrennt);
        q.bindValue(":ipgs",ipGesteckt.isEmpty()  ? QVariant() : ipGesteckt);
        q.bindValue(":kod", kodierung.isEmpty()   ? QVariant() : kodierung);
        q.bindValue(":ver", verriegelung.isEmpty()? QVariant() : verriegelung);
        q.bindValue(":hsk", hatSchirmkontakt ? 1 : 0);
        q.bindValue(":gsch",geschirmt ? 1 : 0);
        if (!q.exec()) {
            qCWarning(lcDb) << "steckverbinderTypSpeichern UPDATE:" << q.lastError().text();
            return -1;
        }
        return existingId;
    } else {
        q.prepare(R"(
            INSERT INTO steckverbinder_typ
                (bauteil_id, polzahl, ip_getrennt, ip_gesteckt,
                 kodierung, verriegelung, hat_schirmkontakt, geschirmt)
            VALUES (:bid, :pz, :ipg, :ipgs, :kod, :ver, :hsk, :gsch)
        )");
        q.bindValue(":bid", bauteilId);
        q.bindValue(":pz",  polzahl > 0 ? polzahl : QVariant());
        q.bindValue(":ipg", ipGetrennt.isEmpty()  ? QVariant() : ipGetrennt);
        q.bindValue(":ipgs",ipGesteckt.isEmpty()  ? QVariant() : ipGesteckt);
        q.bindValue(":kod", kodierung.isEmpty()   ? QVariant() : kodierung);
        q.bindValue(":ver", verriegelung.isEmpty()? QVariant() : verriegelung);
        q.bindValue(":hsk", hatSchirmkontakt ? 1 : 0);
        q.bindValue(":gsch",geschirmt ? 1 : 0);
        if (!q.exec()) {
            qCWarning(lcDb) << "steckverbinderTypSpeichern INSERT:" << q.lastError().text();
            return -1;
        }
        return q.lastInsertId().toInt();
    }
}

// ── steckverbinderTypLoeschen ────────────────────────────────────────────────
bool Database::steckverbinderTypLoeschen(int bauteilId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM steckverbinder_typ WHERE bauteil_id = :bid");
    q.bindValue(":bid", bauteilId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderTypLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderKableinfLaden ──────────────────────────────────────────────
QVariantList Database::steckverbinderKableinfLaden(int steckverbinderTypId) const
{
    QVariantList liste;
    if (steckverbinderTypId < 0) return liste;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, einf_nr, aussen_min_mm, aussen_max_mm, einf_typ, zugentlastung
        FROM steckverbinder_kabeleinf
        WHERE steckverbinder_typ_id = :tid
        ORDER BY einf_nr
    )");
    q.bindValue(":tid", steckverbinderTypId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKableinfLaden:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0).toInt();
        m["einfNr"]       = q.value(1).toInt();
        m["aussenMin"]    = q.value(2).toDouble();
        m["aussenMax"]    = q.value(3).toDouble();
        m["einfTyp"]      = q.value(4).toString();
        m["zugentlastung"]= q.value(5).toString();
        liste.append(m);
    }
    return liste;
}

// ── steckverbinderKableinfHinzufuegen ───────────────────────────────────────
int Database::steckverbinderKableinfHinzufuegen(int steckverbinderTypId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO steckverbinder_kabeleinf (steckverbinder_typ_id, einf_nr)
        VALUES (:tid,
            (SELECT COALESCE(MAX(einf_nr), 0) + 1
             FROM steckverbinder_kabeleinf WHERE steckverbinder_typ_id = :tid2))
    )");
    q.bindValue(":tid",  steckverbinderTypId);
    q.bindValue(":tid2", steckverbinderTypId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKableinfHinzufuegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ── steckverbinderKableinfAktualisieren ─────────────────────────────────────
bool Database::steckverbinderKableinfAktualisieren(int id, double aussenMin, double aussenMax,
                                                    const QString &einfTyp, const QString &zugentlastung)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE steckverbinder_kabeleinf
        SET aussen_min_mm=:amin, aussen_max_mm=:amax,
            einf_typ=:ety, zugentlastung=:zug
        WHERE id=:id
    )");
    q.bindValue(":amin", aussenMin > 0 ? aussenMin : QVariant());
    q.bindValue(":amax", aussenMax > 0 ? aussenMax : QVariant());
    q.bindValue(":ety",  einfTyp.isEmpty()      ? QVariant() : einfTyp);
    q.bindValue(":zug",  zugentlastung.isEmpty() ? QVariant() : zugentlastung);
    q.bindValue(":id",   id);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKableinfAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderKableinfLoeschen ──────────────────────────────────────────
bool Database::steckverbinderKableinfLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM steckverbinder_kabeleinf WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKableinfLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderKontaktLaden ───────────────────────────────────────────────
QVariantList Database::steckverbinderKontaktLaden(int steckverbinderTypId) const
{
    QVariantList liste;
    if (steckverbinderTypId < 0) return liste;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, position_nr, ist_schirmkontakt, kontaktgroesse,
               querschnitt_kabel_min, querschnitt_kabel_max,
               nennstrom_a, nennspannung_v, verbindungstechnik
        FROM steckverbinder_kontakt_typ
        WHERE steckverbinder_typ_id = :tid
        ORDER BY position_nr
    )");
    q.bindValue(":tid", steckverbinderTypId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKontaktLaden:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]               = q.value(0).toInt();
        m["positionNr"]       = q.value(1).toInt();
        m["istSchirmkontakt"] = q.value(2).toInt() != 0;
        m["kontaktgroesse"]   = q.value(3).toString();
        m["qsMin"]            = q.value(4).toDouble();
        m["qsMax"]            = q.value(5).toDouble();
        m["nennstrom"]        = q.value(6).toDouble();
        m["nennspannung"]     = q.value(7).toDouble();
        m["verbindungstechnik"]= q.value(8).toString();
        liste.append(m);
    }
    return liste;
}

// ── steckverbinderKontaktHinzufuegen ────────────────────────────────────────
int Database::steckverbinderKontaktHinzufuegen(int steckverbinderTypId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO steckverbinder_kontakt_typ (steckverbinder_typ_id, position_nr)
        VALUES (:tid,
            (SELECT COALESCE(MAX(position_nr), 0) + 1
             FROM steckverbinder_kontakt_typ WHERE steckverbinder_typ_id = :tid2))
    )");
    q.bindValue(":tid",  steckverbinderTypId);
    q.bindValue(":tid2", steckverbinderTypId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKontaktHinzufuegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ── steckverbinderKontaktAktualisieren ──────────────────────────────────────
bool Database::steckverbinderKontaktAktualisieren(int id, bool istSchirmkontakt,
    const QString &kontaktgroesse, double qsMin, double qsMax,
    double nennstrom, double nennspannung, const QString &verbindungstechnik)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE steckverbinder_kontakt_typ
        SET ist_schirmkontakt=:isk, kontaktgroesse=:kg,
            querschnitt_kabel_min=:qmin, querschnitt_kabel_max=:qmax,
            nennstrom_a=:ns, nennspannung_v=:nv, verbindungstechnik=:vt
        WHERE id=:id
    )");
    q.bindValue(":isk",  istSchirmkontakt ? 1 : 0);
    q.bindValue(":kg",   kontaktgroesse.isEmpty() ? QVariant() : kontaktgroesse);
    q.bindValue(":qmin", qsMin > 0 ? qsMin : QVariant());
    q.bindValue(":qmax", qsMax > 0 ? qsMax : QVariant());
    q.bindValue(":ns",   nennstrom > 0 ? nennstrom : QVariant());
    q.bindValue(":nv",   nennspannung > 0 ? nennspannung : QVariant());
    q.bindValue(":vt",   verbindungstechnik.isEmpty() ? QVariant() : verbindungstechnik);
    q.bindValue(":id",   id);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKontaktAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderKontaktLoeschen ───────────────────────────────────────────
bool Database::steckverbinderKontaktLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM steckverbinder_kontakt_typ WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKontaktLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}
