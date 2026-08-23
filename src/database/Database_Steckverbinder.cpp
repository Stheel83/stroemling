#include "Database.h"
#include "Database_CsvHelfer.h"
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
               ge.id,
               a.kuerzel,
               o.kuerzel,
               COALESCE(a.anlage_uebergeordnet, ''),
               COALESCE(o.standort_uebergeordnet, ''),
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra,
               ge.seite_id,
               (ge.x1 + ge.x2) / 2.0,
               (ge.y1 + ge.y2) / 2.0
        FROM grafik_element ge
        JOIN seite  s ON s.id = ge.seite_id
        JOIN ort    o ON o.id = s.ort_id
        JOIN anlage a ON a.id = o.anlage_id
        JOIN bibliothek.bauteil b ON b.id = CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER)
        JOIN bibliothek.steckverbinder_typ sv ON sv.bauteil_id = b.id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'geraetekasten'
          AND CAST(json_extract(ge.extra_daten, '$.bauteil_id') AS INTEGER) > 0
        ORDER BY a.kuerzel, o.kuerzel,
                 COALESCE(json_extract(ge.extra_daten, '$.bmk'), ''),
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

        QString anlageKz = q.value(15).toString();
        QString ortKz    = q.value(16).toString();
        QString anlageUO = q.value(17).toString();
        QString ortUO    = q.value(18).toString();
        strukturkastenOverrideAnwenden(q.value(19).toString(), anlageKz, ortKz, anlageUO, ortUO);
        m["anlageKz"] = anlageKz;
        m["ortKz"]    = ortKz;
        m["anlageUO"] = anlageUO;
        m["ortUO"]    = ortUO;
        m["seiteId"]  = q.value(20).toInt();
        m["weltX"]    = q.value(21).toDouble();
        m["weltY"]    = q.value(22).toDouble();
        liste.append(m);
    }
    return liste;
}

// ── steckverbinderlisteCsvSpeichern ─────────────────────────────────────────
bool Database::steckverbinderlisteCsvSpeichern(int projektId, const QString &pfad) const
{
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "steckverbinderlisteCsvSpeichern"))
        return false;
    out << "BMK;Bezeichnung;Bauteil/Typ;Hersteller;Artikelnr.;Polzahl;IP gesteckt;IP getrennt;Kodierung;Verriegelung;Geschirmt;Anlage;Ort;Seite\n";
    auto q = CsvHelfer::escapeBedarf;
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
            << q(row["anlageKz"].toString())      << u';'
            << q(row["ortKz"].toString())         << u';'
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
            ge2.x1, ge2.y1, ge2.x2, ge2.y2,
            a.kuerzel,
            o.kuerzel,
            COALESCE(a.anlage_uebergeordnet, ''),
            COALESCE(o.standort_uebergeordnet, ''),
            (SELECT sk.extra_daten
             FROM grafik_element sk
             WHERE sk.seite_id = gk.seite_id
               AND sk.typ = 'strukturkasten'
               AND (gk.x1 + gk.x2) / 2.0 >= sk.x1
               AND (gk.x1 + gk.x2) / 2.0 <= sk.x2
               AND (gk.y1 + gk.y2) / 2.0 >= sk.y1
               AND (gk.y1 + gk.y2) / 2.0 <= sk.y2
             ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
             LIMIT 1) AS sk_extra
        FROM grafik_element gk
        JOIN seite  s  ON s.id  = gk.seite_id
        JOIN ort    o  ON o.id  = s.ort_id
        JOIN anlage a  ON a.id  = o.anlage_id
        JOIN bibliothek.bauteil b ON b.id  = CAST(json_extract(gk.extra_daten, '$.bauteil_id') AS INTEGER)
        JOIN bibliothek.steckverbinder_typ sv ON sv.bauteil_id = b.id
        JOIN grafik_element ge2 ON ge2.seite_id = gk.seite_id
          AND ge2.typ IN ('stecker', 'buchse', 'geraeteanschluss')
          AND (ge2.x1 + ge2.x2) / 2.0 BETWEEN gk.x1 AND gk.x2
          AND (ge2.y1 + ge2.y2) / 2.0 BETWEEN gk.y1 AND gk.y2
        WHERE a.projekt_id = :pid
          AND gk.typ = 'geraetekasten'
          AND CAST(json_extract(gk.extra_daten, '$.bauteil_id') AS INTEGER) > 0
        ORDER BY a.kuerzel, o.kuerzel,
                 COALESCE(json_extract(gk.extra_daten, '$.bmk'), ''),
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
            QString anlageKz = q.value(19).toString();
            QString ortKz    = q.value(20).toString();
            QString anlageUO = q.value(21).toString();
            QString ortUO    = q.value(22).toString();
            strukturkastenOverrideAnwenden(q.value(23).toString(), anlageKz, ortKz, anlageUO, ortUO);

            QVariantMap h;
            h[QStringLiteral("typ")]        = QStringLiteral("gehaeuse");
            h[QStringLiteral("bmk")]        = gkBmk;
            h[QStringLiteral("gkBez")]      = gkBez;
            h[QStringLiteral("bauteilBez")] = bauteilBez;
            h[QStringLiteral("polzahl")]    = polzahl;
            h[QStringLiteral("geschirmt")]  = geschirmt;
            h[QStringLiteral("blattnr")]    = blattnr;
            h[QStringLiteral("anlageKz")]   = anlageKz;
            h[QStringLiteral("ortKz")]      = ortKz;
            h[QStringLiteral("anlageUO")]   = anlageUO;
            h[QStringLiteral("ortUO")]      = ortUO;
            h[QStringLiteral("seiteId")]    = seiteId;
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
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "steckverbinderBelegungsplanCsvSpeichern"))
        return false;
    out << "GK-BMK;Typ;Symbol-BMK;Pin;Signal;Aderfarbe;Querschnitt mm²;Seite\n";
    auto q = CsvHelfer::escapeBedarf;
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
               COALESCE(b.artikelnummer,''), sv.polzahl, COALESCE(sv.montageform,'')
        FROM bibliothek.bauteil b
        JOIN bibliothek.steckverbinder_typ sv ON sv.bauteil_id = b.id
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
        m["montageform"]  = q.value(5).toString();
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
               verriegelung, hat_schirmkontakt, geschirmt, montageform
        FROM bibliothek.steckverbinder_typ WHERE bauteil_id = :bid
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
    m["montageform"]     = q.value(8).toString();
    return m;
}

// ── steckverbinderTypSpeichern ───────────────────────────────────────────────
// INSERT OR REPLACE des steckverbinder_typ-Datensatzes.
// Gibt die id zurück (>0) oder -1 bei Fehler.
int Database::steckverbinderTypSpeichern(int bauteilId, int polzahl,
    const QString &ipGetrennt, const QString &ipGesteckt,
    const QString &kodierung, const QString &verriegelung,
    bool hatSchirmkontakt, bool geschirmt, const QString &montageform)
{
    QSqlQuery sel(m_db);
    sel.prepare("SELECT id FROM bibliothek.steckverbinder_typ WHERE bauteil_id = :bid");
    sel.bindValue(":bid", bauteilId);
    if (!sel.exec()) {
        qCWarning(lcDb) << "steckverbinderTypSpeichern SELECT:" << sel.lastError().text();
        return -1;
    }

    QSqlQuery q(m_db);
    if (sel.next()) {
        int existingId = sel.value(0).toInt();
        q.prepare(R"(
            UPDATE bibliothek.steckverbinder_typ
            SET polzahl=:pz, ip_getrennt=:ipg, ip_gesteckt=:ipgs,
                kodierung=:kod, verriegelung=:ver,
                hat_schirmkontakt=:hsk, geschirmt=:gsch, montageform=:mf
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
        q.bindValue(":mf",  montageform.isEmpty() ? QVariant() : montageform);
        if (!q.exec()) {
            qCWarning(lcDb) << "steckverbinderTypSpeichern UPDATE:" << q.lastError().text();
            return -1;
        }
        return existingId;
    } else {
        q.prepare(R"(
            INSERT INTO bibliothek.steckverbinder_typ
                (bauteil_id, polzahl, ip_getrennt, ip_gesteckt,
                 kodierung, verriegelung, hat_schirmkontakt, geschirmt, montageform)
            VALUES (:bid, :pz, :ipg, :ipgs, :kod, :ver, :hsk, :gsch, :mf)
        )");
        q.bindValue(":bid", bauteilId);
        q.bindValue(":pz",  polzahl > 0 ? polzahl : QVariant());
        q.bindValue(":ipg", ipGetrennt.isEmpty()  ? QVariant() : ipGetrennt);
        q.bindValue(":ipgs",ipGesteckt.isEmpty()  ? QVariant() : ipGesteckt);
        q.bindValue(":kod", kodierung.isEmpty()   ? QVariant() : kodierung);
        q.bindValue(":ver", verriegelung.isEmpty()? QVariant() : verriegelung);
        q.bindValue(":hsk", hatSchirmkontakt ? 1 : 0);
        q.bindValue(":gsch",geschirmt ? 1 : 0);
        q.bindValue(":mf",  montageform.isEmpty() ? QVariant() : montageform);
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
    q.prepare("DELETE FROM bibliothek.steckverbinder_typ WHERE bauteil_id = :bid");
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
        FROM bibliothek.steckverbinder_kabeleinf
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
        INSERT INTO bibliothek.steckverbinder_kabeleinf (steckverbinder_typ_id, einf_nr)
        VALUES (:tid,
            (SELECT COALESCE(MAX(einf_nr), 0) + 1
             FROM bibliothek.steckverbinder_kabeleinf WHERE steckverbinder_typ_id = :tid2))
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
        UPDATE bibliothek.steckverbinder_kabeleinf
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
    q.prepare("DELETE FROM bibliothek.steckverbinder_kabeleinf WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderKableinfLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderPositionenLaden ────────────────────────────────────────────
// Lädt alle Positionen eines Steckverbinder-Typs inkl. Anzeige-Daten aus dem
// verknüpften Kontakt-Typ (Neukonzeption Jul 2026, ersetzt steckverbinder_kontakt_typ).
QVariantList Database::steckverbinderPositionenLaden(int steckverbinderTypId) const
{
    QVariantList liste;
    if (steckverbinderTypId < 0) return liste;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT sp.id, sp.position_nr, sp.ist_schirmkontakt, sp.kontakt_typ_id,
               COALESCE(b.bezeichnung,''), kt.geschlecht,
               COALESCE(kt.kontaktgroesse,0), COALESCE(kt.verbindungstechnik,'')
        FROM bibliothek.steckverbinder_position sp
        JOIN bibliothek.kontakt_typ kt ON kt.id = sp.kontakt_typ_id
        JOIN bibliothek.bauteil b      ON b.id  = kt.bauteil_id
        WHERE sp.steckverbinder_typ_id = :tid
        ORDER BY sp.position_nr
    )");
    q.bindValue(":tid", steckverbinderTypId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderPositionenLaden:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]                 = q.value(0).toInt();
        m["positionNr"]         = q.value(1).toInt();
        m["istSchirmkontakt"]   = q.value(2).toInt() != 0;
        m["kontaktTypId"]       = q.value(3).toInt();
        m["bezeichnung"]        = q.value(4).toString();
        m["geschlecht"]         = q.value(5).toString();
        m["kontaktgroesse"]     = q.value(6).toDouble();
        m["verbindungstechnik"] = q.value(7).toString();
        liste.append(m);
    }
    return liste;
}

// ── steckverbinderPositionHinzufuegen ───────────────────────────────────────
// Fügt eine neue Position hinzu, verknüpft mit dem gewählten Kontakt-Typ.
// position_nr wird fortlaufend vergeben (kein Umsortieren in Phase 1).
int Database::steckverbinderPositionHinzufuegen(int steckverbinderTypId, int kontaktTypId)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO bibliothek.steckverbinder_position (steckverbinder_typ_id, position_nr, kontakt_typ_id)
        VALUES (:tid,
            (SELECT COALESCE(MAX(position_nr), 0) + 1
             FROM bibliothek.steckverbinder_position WHERE steckverbinder_typ_id = :tid2),
            :ktid)
    )");
    q.bindValue(":tid",  steckverbinderTypId);
    q.bindValue(":tid2", steckverbinderTypId);
    q.bindValue(":ktid", kontaktTypId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderPositionHinzufuegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ── steckverbinderPositionSchirmkontaktSetzen ───────────────────────────────
bool Database::steckverbinderPositionSchirmkontaktSetzen(int positionId, bool istSchirmkontakt)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE bibliothek.steckverbinder_position SET ist_schirmkontakt=:isk WHERE id=:id");
    q.bindValue(":isk", istSchirmkontakt ? 1 : 0);
    q.bindValue(":id",  positionId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderPositionSchirmkontaktSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderPositionKontaktTypAendern ─────────────────────────────────
// Tauscht den verknüpften Kontakt-Typ einer bestehenden Position (⇄-Button im Editor).
bool Database::steckverbinderPositionKontaktTypAendern(int positionId, int neuerKontaktTypId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE bibliothek.steckverbinder_position SET kontakt_typ_id=:ktid WHERE id=:id");
    q.bindValue(":ktid", neuerKontaktTypId);
    q.bindValue(":id",   positionId);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderPositionKontaktTypAendern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderPositionLoeschen ──────────────────────────────────────────
// Entfernt nur die Position (Verknüpfung), nicht den referenzierten Kontakt-Typ-Bauteil.
bool Database::steckverbinderPositionLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM bibliothek.steckverbinder_position WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "steckverbinderPositionLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── steckverbinderPositionIstPlatziert ──────────────────────────────────────
// Prüft, ob für eine Position bereits ein verknüpftes Kontakt-Symbol
// (stecker/buchse, platziermodus="verknuepft") auf irgendeiner Seite
// des Projekts existiert (Neukonzeption Jul 2026, → §8.2.1).
bool Database::steckverbinderPositionIstPlatziert(int positionId) const
{
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT COUNT(*) FROM grafik_element"
        " WHERE symbol_id IN ('stecker','buchse')"
        "   AND CAST(json_extract(extra_daten,'$.positionId') AS INTEGER) = :pid");
    q.bindValue(":pid", positionId);
    if (q.exec() && q.next())
        return q.value(0).toInt() > 0;
    return false;
}

// ── steckverbinderPositionDetails ───────────────────────────────────────────
// Anzeige-Daten einer einzelnen Position für das EP eines verknüpft
// platzierten Kontakt-Symbols (→ §8.3).
QVariantMap Database::steckverbinderPositionDetails(int positionId) const
{
    QVariantMap m;
    if (positionId < 0) return m;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT sp.position_nr, sp.ist_schirmkontakt,
               COALESCE(b.bezeichnung,''), kt.geschlecht,
               COALESCE(kt.kontaktgroesse,0), COALESCE(kt.verbindungstechnik,'')
        FROM bibliothek.steckverbinder_position sp
        JOIN bibliothek.kontakt_typ kt ON kt.id = sp.kontakt_typ_id
        JOIN bibliothek.bauteil b      ON b.id  = kt.bauteil_id
        WHERE sp.id = :pid
    )");
    q.bindValue(":pid", positionId);
    if (!q.exec() || !q.next()) return m;
    m["positionNr"]         = q.value(0).toInt();
    m["istSchirmkontakt"]   = q.value(1).toInt() != 0;
    m["bezeichnung"]        = q.value(2).toString();
    m["geschlecht"]         = q.value(3).toString();
    m["kontaktgroesse"]     = q.value(4).toDouble();
    m["verbindungstechnik"] = q.value(5).toString();
    return m;
}

// ── steckverbinderGegenstelleLaden ──────────────────────────────────────────
// Löst die Gegenstelle einer Position über die Partner-Verknüpfung des
// Gerätekastens auf (§8.3/§10.3): eigene position_nr → partnerGeraetekastenId
// → Position mit gleicher Nummer im dortigen Steckverbinder-Typ (Standard-1:1)
// → platziert? Seite/Blattnr, sonst nur "istPlatziert:false"; existiert die
// Position im Partner-Typ gar nicht (z.B. abweichende Polzahl): "keineGegenstelle".
QVariantMap Database::steckverbinderGegenstelleLaden(int geraetekastenId, int positionNr) const
{
    QVariantMap m;
    m["hatPartner"] = false;
    if (geraetekastenId < 0 || positionNr < 0) return m;

    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT CAST(json_extract(extra_daten, '$.partnerGeraetekastenId') AS INTEGER)
        FROM grafik_element WHERE id = :id
    )");
    q.bindValue(":id", geraetekastenId);
    if (!q.exec() || !q.next()) return m;
    const int partnerGkId = q.value(0).toInt();
    if (partnerGkId <= 0) return m;
    m["hatPartner"] = true;

    QSqlQuery pq(m_db);
    pq.prepare(R"(
        SELECT COALESCE(json_extract(extra_daten, '$.bmk'), ''),
               COALESCE(CAST(json_extract(extra_daten, '$.bauteil_id') AS INTEGER), 0)
        FROM grafik_element WHERE id = :id
    )");
    pq.bindValue(":id", partnerGkId);
    if (!pq.exec() || !pq.next()) return m;
    m["partnerBmk"] = pq.value(0).toString();
    const int partnerBauteilId = pq.value(1).toInt();

    if (partnerBauteilId <= 0) {
        m["keineGegenstelle"] = true;
        return m;
    }

    const QVariantMap partnerTyp = steckverbinderTypLaden(partnerBauteilId);
    if (partnerTyp.isEmpty() || partnerTyp.value("id").toInt() <= 0) {
        m["keineGegenstelle"] = true;
        return m;
    }

    QSqlQuery posq(m_db);
    posq.prepare(R"(
        SELECT id FROM bibliothek.steckverbinder_position
        WHERE steckverbinder_typ_id = :tid AND position_nr = :pnr
    )");
    posq.bindValue(":tid", partnerTyp.value("id").toInt());
    posq.bindValue(":pnr", positionNr);
    if (!posq.exec() || !posq.next()) {
        m["keineGegenstelle"] = true;
        return m;
    }
    const int partnerPositionId = posq.value(0).toInt();
    m["partnerPositionId"] = partnerPositionId;

    const bool platziert = steckverbinderPositionIstPlatziert(partnerPositionId);
    m["istPlatziert"] = platziert;
    if (!platziert) return m;

    QSqlQuery locq(m_db);
    locq.prepare(R"(
        SELECT s.blattnummer, s.bezeichnung
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        WHERE ge.symbol_id IN ('stecker','buchse')
          AND CAST(json_extract(ge.extra_daten,'$.positionId') AS INTEGER) = :pid
        LIMIT 1
    )");
    locq.bindValue(":pid", partnerPositionId);
    if (locq.exec() && locq.next()) {
        m["blattnr"]  = locq.value(0).toString();
        m["seiteBez"] = locq.value(1).toString();
    }
    return m;
}

// ── konfkabelLaden ───────────────────────────────────────────────────────────
QVariantMap Database::konfkabelLaden(int bauteilId) const
{
    QVariantMap m;
    if (bauteilId < 0) return m;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT kk.id, kk.bauteil_kabel_id, kk.stecker_a_bauteil_id,
               kk.stecker_b_bauteil_id, COALESCE(kk.laenge_m, 0),
               COALESCE(bka.kabeltyp, ''), COALESCE(bsa.bezeichnung, ''),
               COALESCE(bsb.bezeichnung, '')
        FROM bibliothek.konfektioniertes_kabel kk
        LEFT JOIN bibliothek.bauteil_kabel bka ON bka.id = kk.bauteil_kabel_id
        LEFT JOIN bibliothek.bauteil bsa        ON bsa.id = kk.stecker_a_bauteil_id
        LEFT JOIN bibliothek.bauteil bsb        ON bsb.id = kk.stecker_b_bauteil_id
        WHERE kk.bauteil_id = :bid
    )");
    q.bindValue(":bid", bauteilId);
    if (!q.exec() || !q.next()) return m;
    m["id"]                 = q.value(0).toInt();
    m["bauteilKabelId"]     = q.value(1).toInt();
    m["steckerABauteilId"]  = q.value(2).toInt();
    m["steckerBBauteilId"]  = q.value(3).toInt();
    m["laengeM"]            = q.value(4).toDouble();
    m["kabelTyp"]           = q.value(5).toString();
    m["steckerABez"]        = q.value(6).toString();
    m["steckerBBez"]        = q.value(7).toString();
    return m;
}

// ── konfkabelSpeichern ───────────────────────────────────────────────────────
int Database::konfkabelSpeichern(int bauteilId, int bauteilKabelId,
    int steckerABauteilId, int steckerBBauteilId, double laengeM)
{
    QSqlQuery sel(m_db);
    sel.prepare("SELECT id FROM bibliothek.konfektioniertes_kabel WHERE bauteil_id = :bid");
    sel.bindValue(":bid", bauteilId);
    if (!sel.exec()) {
        qCWarning(lcDb) << "konfkabelSpeichern SELECT:" << sel.lastError().text();
        return -1;
    }

    QSqlQuery q(m_db);
    if (sel.next()) {
        int existingId = sel.value(0).toInt();
        q.prepare(R"(
            UPDATE bibliothek.konfektioniertes_kabel
            SET bauteil_kabel_id=:bkid, stecker_a_bauteil_id=:said,
                stecker_b_bauteil_id=:sbid, laenge_m=:lm
            WHERE id=:id
        )");
        q.bindValue(":id",   existingId);
        q.bindValue(":bkid", bauteilKabelId > 0   ? bauteilKabelId   : QVariant());
        q.bindValue(":said", steckerABauteilId > 0 ? steckerABauteilId : QVariant());
        q.bindValue(":sbid", steckerBBauteilId > 0 ? steckerBBauteilId : QVariant());
        q.bindValue(":lm",   laengeM > 0 ? laengeM : QVariant());
        if (!q.exec()) {
            qCWarning(lcDb) << "konfkabelSpeichern UPDATE:" << q.lastError().text();
            return -1;
        }
        return existingId;
    } else {
        q.prepare(R"(
            INSERT INTO bibliothek.konfektioniertes_kabel
                (bauteil_id, bauteil_kabel_id, stecker_a_bauteil_id,
                 stecker_b_bauteil_id, laenge_m)
            VALUES (:bid, :bkid, :said, :sbid, :lm)
        )");
        q.bindValue(":bid",  bauteilId);
        q.bindValue(":bkid", bauteilKabelId > 0   ? bauteilKabelId   : QVariant());
        q.bindValue(":said", steckerABauteilId > 0 ? steckerABauteilId : QVariant());
        q.bindValue(":sbid", steckerBBauteilId > 0 ? steckerBBauteilId : QVariant());
        q.bindValue(":lm",   laengeM > 0 ? laengeM : QVariant());
        if (!q.exec()) {
            qCWarning(lcDb) << "konfkabelSpeichern INSERT:" << q.lastError().text();
            return -1;
        }
        return q.lastInsertId().toInt();
    }
}

// ── konfkabelLoeschen ────────────────────────────────────────────────────────
bool Database::konfkabelLoeschen(int bauteilId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM bibliothek.konfektioniertes_kabel WHERE bauteil_id = :bid");
    q.bindValue(":bid", bauteilId);
    if (!q.exec()) {
        qCWarning(lcDb) << "konfkabelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── konfkabelPinZuordnungLaden ──────────────────────────────────────────────
// Ader-zu-Pin-Zuordnungen einer Seite (A/B) eines Konfkabels. Farbe/Nummer/
// Bezeichnung/Querschnitt der Litze werden NICHT dupliziert gespeichert,
// sondern live über ader_nr aus bauteil_kabel_ader nachgeschlagen (§9.3).
QVariantList Database::konfkabelPinZuordnungLaden(int konfkabelId, const QString &seite) const
{
    QVariantList liste;
    if (konfkabelId < 0) return liste;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT z.id, z.ader_nr, z.pin_nr,
               COALESCE(a.farbe,''), COALESCE(a.nummer,''),
               COALESCE(a.bezeichnung,''), COALESCE(a.querschnitt_mm2,0)
        FROM bibliothek.konfkabel_pin_zuordnung z
        JOIN bibliothek.konfektioniertes_kabel kk ON kk.id = z.konfkabel_id
        LEFT JOIN bibliothek.bauteil_kabel_ader a
               ON a.kabel_id = kk.bauteil_kabel_id AND a.ader_nr = z.ader_nr
        WHERE z.konfkabel_id = :kid AND z.seite = :seite
        ORDER BY z.pin_nr, z.ader_nr
    )");
    q.bindValue(":kid", konfkabelId);
    q.bindValue(":seite", seite);
    if (!q.exec()) {
        qCWarning(lcDb) << "konfkabelPinZuordnungLaden:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]             = q.value(0).toInt();
        m["aderNr"]         = q.value(1).toInt();
        m["pinNr"]          = q.value(2).toInt();
        m["aderFarbe"]      = q.value(3).toString();
        m["aderNummer"]     = q.value(4).toString();
        m["aderBezeichnung"]= q.value(5).toString();
        m["aderQuerschnitt"]= q.value(6).toDouble();
        liste.append(m);
    }
    return liste;
}

// ── konfkabelPinZuordnen ─────────────────────────────────────────────────────
// Ordnet eine Ader (ader_nr) einer Pin-Nummer auf einer Seite zu. Eine Ader
// kann pro Seite nur einem Pin zugeordnet sein (UNIQUE-Constraint) — ein
// erneuter Aufruf mit derselben Ader ändert die Zuordnung (INSERT OR REPLACE).
// Mehrere Adern auf demselben Pin sind zulässig (Mehrfachbelegung, §5.2/§10.2).
int Database::konfkabelPinZuordnen(int konfkabelId, const QString &seite, int aderNr, int pinNr)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT OR REPLACE INTO bibliothek.konfkabel_pin_zuordnung
            (konfkabel_id, seite, ader_nr, pin_nr)
        VALUES (:kid, :seite, :ader, :pin)
    )");
    q.bindValue(":kid",   konfkabelId);
    q.bindValue(":seite", seite);
    q.bindValue(":ader",  aderNr);
    q.bindValue(":pin",   pinNr);
    if (!q.exec()) {
        qCWarning(lcDb) << "konfkabelPinZuordnen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ── konfkabelPinZuordnungLoeschen ───────────────────────────────────────────
bool Database::konfkabelPinZuordnungLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM bibliothek.konfkabel_pin_zuordnung WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcDb) << "konfkabelPinZuordnungLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}
