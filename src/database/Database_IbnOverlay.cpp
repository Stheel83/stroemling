#include "Database.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
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


// ── Import (VERT-04) ─────────────────────────────────────────────────────────

namespace {
QVariantMap zustandVon(const QString &status, const QString &von, const QString &am,
                       const QString &notiz, const QString &bauteilId, const QString &geaendert,
                       const QVariantList &felder)
{
    return { { "status", status }, { "geprueftVon", von }, { "geprueftAm", am }, { "notiz", notiz },
             { "bauteilId", bauteilId }, { "geaendertAm", geaendert }, { "felder", felder } };
}

QVariantMap feldMap(const QVariantList &felder)
{
    QVariantMap m;
    for (const QVariant &f : felder) {
        const QString w = f.toMap().value("wert").toString();
        if (!w.isEmpty()) m.insert(f.toMap().value("feldname").toString(), w);
    }
    return m;
}

bool zustandGleich(const QVariantMap &a, const QVariantMap &b, bool mitBauteilId)
{
    for (const char *k : { "status", "geprueftVon", "geprueftAm", "notiz" })
        if (a.value(k).toString() != b.value(k).toString()) return false;
    if (mitBauteilId && a.value("bauteilId").toString() != b.value("bauteilId").toString()) return false;
    return feldMap(a.value("felder").toList()) == feldMap(b.value("felder").toList());
}

bool zustandLeer(const QVariantMap &z)
{
    return z.value("status").toString() == "offen" && z.value("geprueftVon").toString().isEmpty()
        && z.value("geprueftAm").toString().isEmpty() && z.value("notiz").toString().isEmpty()
        && feldMap(z.value("felder").toList()).isEmpty();
}
} // namespace

QVariantMap Database::ibnOverlayAnalysieren(const QString &pfad)
{
    auto fehler = [](const QString &t) { return QVariantMap{ { "ok", false }, { "fehler", t } }; };
    if (!m_projektOffen)     return fehler(tr("Kein Projekt geöffnet."));
    if (m_istIbnKopie)       return fehler(tr("Overlays werden in der Hauptkopie importiert, nicht in einer IBN-Kopie."));
    if (m_schreibgeschuetzt) return fehler(tr("Das Projekt ist schreibgeschützt."));

    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly)) return fehler(tr("Datei nicht lesbar: %1").arg(pfad));
    const QJsonObject doc = QJsonDocument::fromJson(f.readAll()).object();
    f.close();
    if (doc.value("format").toString() != QLatin1String("stroemling-ibn-overlay"))
        return fehler(tr("Das ist keine Strömling-IBN-Overlay-Datei."));
    if (doc.value("version").toInt() != 1)
        return fehler(tr("Unbekannte Overlay-Version %1.").arg(doc.value("version").toInt()));

    int projektId = 0, hauptRevision = 0;
    {
        QSqlQuery q(m_db);
        if (!q.exec("SELECT id, haupt_revision FROM projekt ORDER BY id DESC LIMIT 1") || !q.next())
            return fehler(tr("Projektdaten nicht lesbar."));
        projektId = q.value(0).toInt();
        hauptRevision = q.value(1).toInt();
    }

    // Kopie im Register
    const QString uuid = doc.value("kopieUuid").toString();
    QVariantMap kopie;
    QString kopieErstellt;
    QVariantList kopieBereich;
    for (const QVariant &v : ibnKopieRegisterLaden(projektId))
        if (v.toMap().value("kopieUuid").toString() == uuid) {
            kopie = v.toMap();
            kopieErstellt = kopie.value("erstelltAm").toString();
            kopieBereich  = kopie.value("bereich").toList();
        }
    if (kopie.isEmpty())
        return fehler(tr("Diese Kopie steht nicht im Kopien-Register dieses Projekts – das Overlay gehört zu einem anderen Projekt."));

    const int aktuellerDurchgang = ibnAktuellerDurchgang(projektId);
    if (doc.value("durchgangNr").toInt() != aktuellerDurchgang)
        return fehler(tr("Das Overlay gehört zu Prüfdurchgang %1, aktuell ist Durchgang %2. Overlays aus abgeschlossenen Durchgängen werden nicht importiert.")
                          .arg(doc.value("durchgangNr").toInt()).arg(aktuellerDurchgang));

    QStringList warnungen;
    if (kopie.value("veraltet").toBool() || doc.value("hauptRevision").toInt() < hauptRevision)
        warnungen << tr("Die Kopie ist veraltet: der Schaltplan wurde nach ihrer Erstellung geändert. Einträge, die nicht mehr zuzuordnen sind, werden aufgelistet.");
    if (kopie.value("status").toString() == "eingesammelt")
        warnungen << tr("Diese Kopie wurde bereits eingesammelt – ein erneuter Import überschreibt nur abweichende Stände nach Rückfrage.");
    if (kopie.value("status").toString() == "verworfen")
        warnungen << tr("Diese Kopie war als verworfen markiert und gilt nach dem Import als eingesammelt.");

    QVariantList uebernehmen, konflikte, nichtZuordenbar, ausserhalb;
    int unveraendert = 0;

    auto seiteAufloesen = [&](const QString &a, const QString &o, const QString &s, QString &grund) {
        QSqlQuery q(m_db);
        q.prepare("SELECT s.id FROM seite s JOIN ort o ON s.ort_id = o.id JOIN anlage a ON o.anlage_id = a.id "
                  "WHERE a.projekt_id = :pid AND a.kuerzel = :a AND o.kuerzel = :o AND s.blattnummer = :s");
        q.bindValue(":pid", projektId); q.bindValue(":a", a); q.bindValue(":o", o); q.bindValue(":s", s);
        int id = -1, n = 0;
        if (q.exec()) while (q.next()) { id = q.value(0).toInt(); ++n; }
        if (n == 0) grund = tr("Seite nicht gefunden");
        else if (n > 1) grund = tr("Seitenschlüssel mehrdeutig");
        return n == 1 ? id : -1;
    };

    auto einsortieren = [&](const QString &typ, const QString &key, const QString &label,
                            const QVariantMap &haupt, bool hauptExistiert, const QVariantMap &nutzdaten,
                            const QVariantMap &kopieZustand) {
        const QString kopieGeaendert = kopieZustand.value("geaendertAm").toString();
        if (kopieGeaendert.isEmpty() || kopieGeaendert < kopieErstellt) { ++unveraendert; return; }
        const bool mitBt = (typ == "bm");
        if (hauptExistiert && zustandGleich(haupt, kopieZustand, mitBt)) { ++unveraendert; return; }
        const QString hauptGeaendert = haupt.value("geaendertAm").toString();
        const bool hauptGeaendertSeitKopie = hauptExistiert && !zustandLeer(haupt)
            && !hauptGeaendert.isEmpty() && hauptGeaendert >= kopieErstellt;
        QVariantMap eintrag = nutzdaten;
        eintrag.insert("key", key); eintrag.insert("typ", typ); eintrag.insert("label", label);
        if (hauptGeaendertSeitKopie) {
            eintrag.insert("haupt", haupt);
            eintrag.insert("kopie", kopieZustand);
            konflikte.append(eintrag);
        } else {
            uebernehmen.append(eintrag);
        }
    };

    // Betriebsmittel
    const QJsonArray bmArr = doc.value("betriebsmittel").toArray();
    for (const QJsonValue &v : bmArr) {
        const QJsonObject e = v.toObject();
        const QString a = e.value("anlage").toString(), o = e.value("ort").toString(),
                      s = e.value("seite").toString(), bmk = e.value("bmk").toString();
        const QString label = QStringLiteral("%1 / %2 / Blatt %3 / %4").arg(a, o, s, bmk);
        const QString key = QStringLiteral("bm|%1|%2|%3|%4").arg(a, o, s, bmk);

        QString grund;
        const int seiteId = seiteAufloesen(a, o, s, grund);
        if (seiteId < 0) { nichtZuordenbar.append(QVariantMap{ { "label", label }, { "grund", grund } }); continue; }
        QSqlQuery qe(m_db);
        qe.prepare("SELECT COUNT(*) FROM grafik_element WHERE seite_id = :sid AND typ = 'symbol' "
                   "AND json_extract(extra_daten, '$.bmk') = :bmk");
        qe.bindValue(":sid", seiteId); qe.bindValue(":bmk", bmk);
        if (!qe.exec() || !qe.next() || qe.value(0).toInt() == 0) {
            nichtZuordenbar.append(QVariantMap{ { "label", label },
                { "grund", tr("BMK steht nicht (mehr) auf dieser Seite") } });
            continue;
        }
        if (!kopieBereich.isEmpty() && !ibnBereichPasst(kopieBereich, a, o, s)) {
            ausserhalb.append(QVariantMap{ { "label", label }, { "key", key } });
            continue;
        }

        QVariantList kf;
        for (const QJsonValue &fv : e.value("felder").toArray())
            kf.append(QVariantMap{ { "feldname", fv.toObject().value("feldname").toString() },
                                   { "wert",     fv.toObject().value("wert").toString() } });
        const QVariantMap kz = zustandVon(e.value("status").toString(), e.value("geprueftVon").toString(),
            e.value("geprueftAm").toString(), e.value("notiz").toString(), e.value("bauteilId").toString(),
            e.value("geaendertAm").toString(), kf);

        QVariantMap haupt; bool existiert = false;
        QSqlQuery qh(m_db);
        qh.prepare("SELECT id, status, geprueft_von, geprueft_am, notiz, bauteil_id, COALESCE(geaendert_am, '') "
                   "FROM inbetriebnahme WHERE seite_id = :sid AND bmk = :bmk");
        qh.bindValue(":sid", seiteId); qh.bindValue(":bmk", bmk);
        if (qh.exec() && qh.next()) {
            existiert = true;
            haupt = zustandVon(qh.value(1).toString(), qh.value(2).toString(), qh.value(3).toString(),
                               qh.value(4).toString(), qh.value(5).toString(), qh.value(6).toString(),
                               ibnFeldwerteLaden(qh.value(0).toInt()));
        }
        QVariantMap nutz = kz;
        nutz.insert("seiteId", seiteId); nutz.insert("bmk", bmk);
        einsortieren("bm", key, label, haupt, existiert, nutz, kz);
    }

    // Kabel
    for (const QJsonValue &v : doc.value("kabel").toArray()) {
        const QJsonObject e = v.toObject();
        const QString bez = e.value("bezeichnung").toString();
        const QString label = QStringLiteral("Kabel %1").arg(bez);
        const QString key = QStringLiteral("kabel|%1").arg(bez);
        QSqlQuery qk(m_db);
        qk.prepare("SELECT id FROM kabel WHERE projekt_id = :pid AND bezeichnung = :b");
        qk.bindValue(":pid", projektId); qk.bindValue(":b", bez);
        int kabelId = -1, n = 0;
        if (qk.exec()) while (qk.next()) { kabelId = qk.value(0).toInt(); ++n; }
        if (n != 1) {
            nichtZuordenbar.append(QVariantMap{ { "label", label },
                { "grund", n == 0 ? tr("Kabel nicht gefunden") : tr("Kabelbezeichnung mehrdeutig") } });
            continue;
        }
        const QString a = e.value("anlage").toString(), o = e.value("ort").toString(), s = e.value("seite").toString();
        if (!kopieBereich.isEmpty() && !s.isEmpty() && !ibnBereichPasst(kopieBereich, a, o, s)) {
            ausserhalb.append(QVariantMap{ { "label", label }, { "key", key } });
            continue;
        }
        const QVariantMap kz = zustandVon(e.value("status").toString(), e.value("geprueftVon").toString(),
            e.value("geprueftAm").toString(), e.value("notiz").toString(), QString(),
            e.value("geaendertAm").toString(), {});
        QVariantMap haupt; bool existiert = false;
        QSqlQuery qh(m_db);
        qh.prepare("SELECT status, geprueft_von, geprueft_am, notiz, COALESCE(geaendert_am, '') "
                   "FROM ibn_kabel WHERE kabel_id = :kid");
        qh.bindValue(":kid", kabelId);
        if (qh.exec() && qh.next()) {
            existiert = true;
            haupt = zustandVon(qh.value(0).toString(), qh.value(1).toString(), qh.value(2).toString(),
                               qh.value(3).toString(), QString(), qh.value(4).toString(), {});
        }
        QVariantMap nutz = kz;
        nutz.insert("kabelId", kabelId);
        einsortieren("kabel", key, label, haupt, existiert, nutz, kz);
    }

    return { { "ok", true }, { "durchgangNr", aktuellerDurchgang },
             { "kopie", kopie }, { "warnungen", warnungen },
             { "anzahlBm", bmArr.size() }, { "anzahlKabel", doc.value("kabel").toArray().size() },
             { "uebernehmen", uebernehmen }, { "unveraendert", unveraendert },
             { "konflikte", konflikte }, { "nichtZuordenbar", nichtZuordenbar },
             { "ausserhalbBereich", ausserhalb }, { "kopieUuid", uuid },
             { "durchgangImOverlay", doc.value("durchgangNr").toInt() } };
}

QVariantMap Database::ibnOverlayPruefen(const QString &pfad)
{
    QVariantMap a = ibnOverlayAnalysieren(pfad);
    if (!a.value("ok").toBool()) return a;
    a.insert("uebernehmen", a.value("uebernehmen").toList().size());   // Nutzdaten nicht nach QML
    return a;
}

QVariantMap Database::ibnOverlayImportieren(const QString &pfad, const QVariantMap &entscheidungen,
                                            bool ausserhalbZulassen)
{
    QVariantMap a = ibnOverlayAnalysieren(pfad);
    if (!a.value("ok").toBool()) return a;
    auto fehler = [](const QString &t) { return QVariantMap{ { "ok", false }, { "fehler", t } }; };

    int projektId = 0;
    { QSqlQuery q(m_db); if (q.exec("SELECT id FROM projekt ORDER BY id DESC LIMIT 1") && q.next()) projektId = q.value(0).toInt(); }
    const int durchgang = a.value("durchgangNr").toInt();

    QVariantList anwenden = a.value("uebernehmen").toList();
    int konfliktKopie = 0, konfliktHaupt = 0;
    for (const QVariant &v : a.value("konflikte").toList()) {
        QVariantMap k = v.toMap();
        if (entscheidungen.value(k.value("key").toString(), "haupt").toString() == "kopie") {
            anwenden.append(k);   // k traegt bereits die Nutzdaten der Kopie
            ++konfliktKopie;
        } else {
            ++konfliktHaupt;
        }
    }
    if (ausserhalbZulassen && !a.value("ausserhalbBereich").toList().isEmpty())
        qCInfo(lcDb) << "Overlay-Import: Eintraege ausserhalb des Bereichs werden in dieser Fassung nicht uebernommen";

    if (!m_db.transaction()) return fehler(tr("Transaktion konnte nicht gestartet werden."));
    bool ok = true;
    int uebernommen = 0;
    for (const QVariant &v : anwenden) {
        const QVariantMap e = v.toMap();
        if (e.value("typ").toString() == "bm") {
            const int sid = e.value("seiteId").toInt();
            const QString bmk = e.value("bmk").toString();
            ok = ibnEintragSpeichern(projektId, sid, bmk, e.value("status").toString(), e.value("notiz").toString(),
                                     e.value("bauteilId").toString(), e.value("geprueftVon").toString(),
                                     e.value("geprueftAm").toString());
            if (ok) {
                const int id = ibnEintragFuerBmk(sid, bmk).value("ibnId").toInt();
                ok = ibnFeldwerteAktualisieren(id, e.value("felder").toList());
                QSqlQuery qd(m_db);
                qd.prepare("UPDATE inbetriebnahme SET durchgang_nr = :d WHERE id = :id");
                qd.bindValue(":d", durchgang); qd.bindValue(":id", id);
                ok = ok && qd.exec();
            }
        } else {
            const int kid = e.value("kabelId").toInt();
            ok = ibnKabelSpeichern(projektId, kid, e.value("status").toString(), e.value("notiz").toString(),
                                   e.value("geprueftVon").toString(), e.value("geprueftAm").toString());
            QSqlQuery qd(m_db);
            qd.prepare("UPDATE ibn_kabel SET durchgang_nr = :d WHERE kabel_id = :id");
            qd.bindValue(":d", durchgang); qd.bindValue(":id", kid);
            ok = ok && qd.exec();
        }
        if (!ok) break;
        ++uebernommen;
    }
    if (!ok) {
        m_db.rollback();
        return fehler(tr("Import fehlgeschlagen – es wurde nichts geändert."));
    }
    if (!m_db.commit()) { m_db.rollback(); return fehler(tr("Commit fehlgeschlagen.")); }

    ibnKopieEingesammeltMarkieren(a.value("kopieUuid").toString());
    qCInfo(lcDb) << "Overlay importiert:" << pfad << uebernommen << "Eintraege";
    return { { "ok", true }, { "uebernommen", uebernommen }, { "konfliktKopie", konfliktKopie },
             { "konfliktHaupt", konfliktHaupt }, { "unveraendert", a.value("unveraendert") },
             { "nichtZuordenbar", a.value("nichtZuordenbar") },
             { "ausserhalbBereich", a.value("ausserhalbBereich") } };
}

QVariantList Database::ibnOverlayDateienFinden()
{
    QVariantList liste;
    if (!m_projektOffen) return liste;
    const QDir ordner(QFileInfo(m_db.databaseName()).absolutePath() + "/ibn_kopien");
    const QFileInfoList dateien = ordner.entryInfoList({ "*.strl-overlay" }, QDir::Files, QDir::Time);
    for (const QFileInfo &fi : dateien)
        liste.append(QVariantMap{ { "pfad", fi.absoluteFilePath() }, { "name", fi.fileName() },
                                  { "geaendert", fi.lastModified().toString("dd.MM.yyyy HH:mm") } });
    return liste;
}
