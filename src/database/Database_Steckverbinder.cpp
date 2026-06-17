#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QUrl>

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
