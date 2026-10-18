#include "Database.h"
#include <QDateTime>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSqlError>
#include <QSqlQuery>

// VERT-03 (konzept/features/55 §4.2): Overlay-Export einer IBN-Kopie. Das Overlay enthaelt nur
// IBN-Daten im Bereich der Kopie; die Schluessel sind fachlich (Anlage, Ort, Seite, BMK bzw.
// Kabelbezeichnung), nie lokale IDs.

QVariantMap Database::ibnOverlayExportieren(const QString &zielPfad)
{
    auto fehler = [](const QString &t) { return QVariantMap{ { "ok", false }, { "fehler", t } }; };
    if (!m_projektOffen)  return fehler(tr("Kein Projekt geöffnet."));
    if (!m_istIbnKopie)   return fehler(tr("Ein Overlay kann nur aus einer IBN-Kopie exportiert werden."));

    QString kopieUuid, kopieName;
    QVariantList bereich;
    int durchgang = 1, revision = 0;
    {
        QSqlQuery q(m_db);
        if (!q.exec("SELECT kopie_uuid, kopie_name, kopie_bereich, kopie_durchgang_nr, haupt_revision "
                    "FROM projekt ORDER BY id DESC LIMIT 1") || !q.next())
            return fehler(tr("Projektdaten nicht lesbar."));
        kopieUuid = q.value(0).toString();
        kopieName = q.value(1).toString();
        bereich   = QJsonDocument::fromJson(q.value(2).toString().toUtf8()).array().toVariantList();
        durchgang = q.value(3).toInt();
        revision  = q.value(4).toInt();
    }

    QJsonArray bmArr, kabelArr;

    QSqlQuery qb(m_db);
    if (!qb.exec(R"(
        SELECT ibn.id, ibn.bmk, ibn.status, ibn.geprueft_von, ibn.geprueft_am, ibn.notiz,
               ibn.bauteil_id, COALESCE(ibn.geaendert_am, '') AS geaendert_am,
               a.kuerzel AS a_kz, o.kuerzel AS o_kz, s.blattnummer AS blatt
        FROM inbetriebnahme ibn
        JOIN seite  s ON ibn.seite_id = s.id
        JOIN ort    o ON s.ort_id     = o.id
        JOIN anlage a ON o.anlage_id  = a.id
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ibn.bmk
    )"))
        return fehler(tr("IBN-Daten nicht lesbar: %1").arg(qb.lastError().text()));
    while (qb.next()) {
        const QString a = qb.value("a_kz").toString(), o = qb.value("o_kz").toString(),
                      s = qb.value("blatt").toString();
        if (!ibnBereichPasst(bereich, a, o, s)) continue;
        const QVariantList felder = ibnFeldwerteLaden(qb.value("id").toInt());
        bool hatWerte = false;
        for (const QVariant &f : felder)
            if (!f.toMap().value("wert").toString().isEmpty()) { hatWerte = true; break; }
        const bool leer = qb.value("status").toString() == "offen"
            && qb.value("geprueft_von").toString().isEmpty() && qb.value("geprueft_am").toString().isEmpty()
            && qb.value("notiz").toString().isEmpty() && !hatWerte;
        if (leer) continue;
        QJsonArray fa;
        for (const QVariant &f : felder)
            fa.append(QJsonObject{ { "feldname", f.toMap().value("feldname").toString() },
                                   { "wert",     f.toMap().value("wert").toString()     } });
        bmArr.append(QJsonObject{
            { "anlage", a }, { "ort", o }, { "seite", s }, { "bmk", qb.value("bmk").toString() },
            { "status", qb.value("status").toString() },
            { "geprueftVon", qb.value("geprueft_von").toString() },
            { "geprueftAm", qb.value("geprueft_am").toString() },
            { "notiz", qb.value("notiz").toString() },
            { "bauteilId", qb.value("bauteil_id").toString() },
            { "geaendertAm", qb.value("geaendert_am").toString() },
            { "felder", fa } });
    }

    QSqlQuery qk(m_db);
    if (!qk.exec(R"(
        SELECT k.bezeichnung, ib.status, ib.geprueft_von, ib.geprueft_am, ib.notiz,
               COALESCE(ib.geaendert_am, '') AS geaendert_am,
               COALESCE(a.kuerzel, '') AS a_kz, COALESCE(o.kuerzel, '') AS o_kz,
               COALESCE(s.blattnummer, '') AS blatt
        FROM ibn_kabel ib
        JOIN kabel k ON k.id = ib.kabel_id
        LEFT JOIN grafik_element ge ON ge.id = k.grafik_element_id
        LEFT JOIN seite  s ON s.id = ge.seite_id
        LEFT JOIN ort    o ON o.id = s.ort_id
        LEFT JOIN anlage a ON a.id = o.anlage_id
        ORDER BY k.bezeichnung
    )"))
        return fehler(tr("Kabel-IBN-Daten nicht lesbar: %1").arg(qk.lastError().text()));
    while (qk.next()) {
        const QString a = qk.value("a_kz").toString(), o = qk.value("o_kz").toString(),
                      s = qk.value("blatt").toString();
        const bool ohneSeite = s.isEmpty();
        if (ohneSeite ? !bereich.isEmpty() : !ibnBereichPasst(bereich, a, o, s)) continue;
        if (qk.value("status").toString() == "offen" && qk.value("geprueft_von").toString().isEmpty()
            && qk.value("geprueft_am").toString().isEmpty() && qk.value("notiz").toString().isEmpty())
            continue;
        kabelArr.append(QJsonObject{
            { "bezeichnung", qk.value("bezeichnung").toString() },
            { "anlage", a }, { "ort", o }, { "seite", s },
            { "status", qk.value("status").toString() },
            { "geprueftVon", qk.value("geprueft_von").toString() },
            { "geprueftAm", qk.value("geprueft_am").toString() },
            { "notiz", qk.value("notiz").toString() },
            { "geaendertAm", qk.value("geaendert_am").toString() } });
    }

    const QJsonObject doc{
        { "format",        QStringLiteral("stroemling-ibn-overlay") },
        { "version",       1 },
        { "kopieUuid",     kopieUuid },
        { "kopieName",     kopieName },
        { "hauptRevision", revision },
        { "durchgangNr",   durchgang },
        { "bereich",       QJsonArray::fromVariantList(bereich) },
        { "exportiertAm",  QDateTime::currentDateTimeUtc().toString(Qt::ISODate) },
        { "betriebsmittel", bmArr },
        { "kabel",          kabelArr },
    };

    QString pfad = zielPfad.trimmed();
    if (pfad.isEmpty()) {
        QString basis = m_db.databaseName();
        if (basis.endsWith(QStringLiteral(".strl"))) basis.chop(5);
        pfad = basis + QStringLiteral(".strl-overlay");
    }
    QSaveFile f(pfad);
    if (!f.open(QIODevice::WriteOnly))
        return fehler(tr("Datei nicht schreibbar: %1").arg(pfad));
    f.write(QJsonDocument(doc).toJson(QJsonDocument::Indented));
    if (!f.commit())
        return fehler(tr("Datei konnte nicht geschrieben werden: %1").arg(pfad));

    qCInfo(lcDb) << "Overlay exportiert:" << pfad << bmArr.size() << "BM," << kabelArr.size() << "Kabel";
    return { { "ok", true }, { "pfad", pfad },
             { "anzahlBm", bmArr.size() }, { "anzahlKabel", kabelArr.size() } };
}
