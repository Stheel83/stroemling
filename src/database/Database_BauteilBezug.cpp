// BIB-REF-01: stabile Bauteil-Bezüge. Projekte verweisen per rechnerlokaler ID auf die bibliothek.db; die Tabelle bauteil_bezug
// hält fest, welche UID ein Verweis zuletzt hatte, damit er in einer anderen Bibliothek über die UID wiedergefunden wird.
// Konzept: konzept/features/56_bauteil_austausch.md §4.
#include "Database.h"

#include <QHash>
#include <QPair>
#include <QSet>
#include <QSqlQuery>

namespace {

const QString kBauteil = QStringLiteral("bauteil");
const QString kKabel   = QStringLiteral("kabel");

using Schluessel = QPair<QString, int>;   // (art, ref_id)

struct Gegenstelle
{
    QString uid;
    QString bezeichnung;
    bool operator==(const Gegenstelle &o) const { return uid == o.uid && bezeichnung == o.bezeichnung; }
};

QString inListe(const QList<int> &ids)
{
    QStringList s;
    for (int i : ids)
        s << QString::number(i);
    return s.join(QLatin1Char(','));
}

// "CASE spalte WHEN alt THEN neu … END" (ein Statement, damit sich vertauschende IDs nicht kollidieren)
QString caseAusdruck(const QString &spalte, const QHash<int, int> &umbau)
{
    QString s = QStringLiteral("CASE %1").arg(spalte);
    for (auto it = umbau.constBegin(); it != umbau.constEnd(); ++it)
        s += QStringLiteral(" WHEN %1 THEN %2").arg(it.key()).arg(it.value());
    return s + QStringLiteral(" END");
}

} // namespace

// Alle im Projekt benutzten Verweise auf die Bibliothek (art, ref_id)
static QSet<Schluessel> aktuelleVerweise(QSqlDatabase &db)
{
    QSet<Schluessel> v;
    const auto sammle = [&](const QString &art, const QString &sql) {
        QSqlQuery q(db);
        if (q.exec(sql)) {
            while (q.next()) {
                const int id = q.value(0).toInt();
                if (id > 0)
                    v.insert({ art, id });
            }
        }
    };
    sammle(kBauteil, "SELECT DISTINCT bauteil_id FROM betriebsmittel WHERE bauteil_id IS NOT NULL");
    sammle(kBauteil, "SELECT DISTINCT bauteil_id FROM klemme WHERE bauteil_id IS NOT NULL");
    sammle(kBauteil, "SELECT DISTINCT CAST(json_extract(extra_daten, '$.bauteil_id') AS INTEGER) FROM grafik_element "
                     "WHERE json_valid(extra_daten) AND CAST(json_extract(extra_daten, '$.bauteil_id') AS INTEGER) > 0");
    sammle(kKabel, "SELECT DISTINCT bauteil_kabel_id FROM kabel WHERE bauteil_kabel_id IS NOT NULL");
    return v;
}

// Lokales Bauteil zu einem Verweis (leer, wenn es die ID in der lokalen Bibliothek nicht gibt)
static Gegenstelle lokaleGegenstelle(QSqlDatabase &db, const QString &art, int ref)
{
    QSqlQuery q(db);
    if (art == kKabel)
        q.prepare("SELECT b.uid, b.bezeichnung FROM bibliothek.bauteil_kabel k JOIN bibliothek.bauteil b ON b.id = k.bauteil_id WHERE k.id = ?");
    else
        q.prepare("SELECT uid, bezeichnung FROM bibliothek.bauteil WHERE id = ?");
    q.addBindValue(ref);
    if (q.exec() && q.next())
        return { q.value(0).toString(), q.value(1).toString() };
    return {};
}

QVariantMap Database::bauteilBezuegePruefen(bool schreiben)
{
    QVariantMap erg { { "angepasst", 0 }, { "fehlend", QVariantList() }, { "unsicher", QVariantList() }, { "nichtAngepasst", 0 } };
    if (!m_projektOffen || !m_db.isOpen() || !m_bibliothekDb.isOpen())
        return erg;

    struct Bezug { QString art; int ref; QString uid; QString name; };
    QList<Bezug> bezuege;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT art, ref_id, uid, bezeichnung FROM bauteil_bezug")) {
            while (q.next())
                bezuege.append({ q.value(0).toString(), q.value(1).toInt(), q.value(2).toString(), q.value(3).toString() });
        }
    }

    QHash<int, int> umbauBauteil, umbauKabel;
    QVariantList fehlend, unsicher;
    int nichtAngepasst = 0;
    for (const Bezug &b : bezuege) {
        if (b.uid.isEmpty())
            continue;
        const Gegenstelle lokal = lokaleGegenstelle(m_db, b.art, b.ref);
        if (!lokal.uid.isEmpty() && lokal.uid == b.uid)
            continue;                                   // stimmt: derselbe Bauteil wie beim letzten Mal
        // Die gemerkte UID (eigene UID oder Alias) in der lokalen Bibliothek suchen
        const int ziel = bauteilIdFuerUid(b.uid);
        int neuRef = -1;
        if (ziel > 0) {
            if (b.art == kKabel) {
                QSqlQuery q(m_db);
                q.prepare("SELECT id FROM bibliothek.bauteil_kabel WHERE bauteil_id = ? ORDER BY id LIMIT 1");
                q.addBindValue(ziel);
                if (q.exec() && q.next())
                    neuRef = q.value(0).toInt();
            } else {
                neuRef = ziel;
            }
        }
        if (neuRef > 0 && neuRef != b.ref) {
            if (schreiben)
                (b.art == kKabel ? umbauKabel : umbauBauteil).insert(b.ref, neuRef);
            else
                ++nichtAngepasst;
        } else if (neuRef <= 0) {
            QVariantMap m { { "name", b.name }, { "uid", b.uid }, { "lokalerName", lokal.bezeichnung } };
            (lokal.uid.isEmpty() ? fehlend : unsicher).append(m);
        }
    }

    int angepasst = 0;
    if (!umbauBauteil.isEmpty() || !umbauKabel.isEmpty()) {
        if (m_db.transaction()) {
            bool ok = true;
            const auto ausfuehren = [&](const QString &sql) {
                QSqlQuery q(m_db);
                if (!q.exec(sql)) {
                    qCWarning(lcDb) << "bauteilBezuegePruefen:" << q.lastError().text() << sql.left(80);
                    ok = false;
                }
            };
            if (!umbauBauteil.isEmpty()) {
                const QString alt = inListe(umbauBauteil.keys());
                ausfuehren(QStringLiteral("UPDATE betriebsmittel SET bauteil_id = %1 WHERE bauteil_id IN (%2)")
                               .arg(caseAusdruck("bauteil_id", umbauBauteil), alt));
                ausfuehren(QStringLiteral("UPDATE klemme SET bauteil_id = %1 WHERE bauteil_id IN (%2)")
                               .arg(caseAusdruck("bauteil_id", umbauBauteil), alt));
                const QString jsonId = QStringLiteral("CAST(json_extract(extra_daten, '$.bauteil_id') AS INTEGER)");
                ausfuehren(QStringLiteral("UPDATE grafik_element SET extra_daten = json_set(extra_daten, '$.bauteil_id', %1) "
                                          "WHERE json_valid(extra_daten) AND %2 IN (%3)")
                               .arg(caseAusdruck(jsonId, umbauBauteil), jsonId, alt));
            }
            if (!umbauKabel.isEmpty())
                ausfuehren(QStringLiteral("UPDATE kabel SET bauteil_kabel_id = %1 WHERE bauteil_kabel_id IN (%2)")
                               .arg(caseAusdruck("bauteil_kabel_id", umbauKabel), inListe(umbauKabel.keys())));
            if (ok && m_db.commit()) {
                angepasst = umbauBauteil.size() + umbauKabel.size();
            } else {
                m_db.rollback();
                nichtAngepasst += umbauBauteil.size() + umbauKabel.size();
            }
        } else {
            nichtAngepasst += umbauBauteil.size() + umbauKabel.size();
        }
    }
    erg["angepasst"] = angepasst;
    erg["fehlend"] = fehlend;
    erg["unsicher"] = unsicher;
    erg["nichtAngepasst"] = nichtAngepasst;
    return erg;
}

bool Database::bauteilBezuegeAktualisieren()
{
    if (!m_projektOffen || !m_db.isOpen() || !m_bibliothekDb.isOpen() || m_schreibgeschuetzt || m_istIbnKopie)
        return false;

    QHash<Schluessel, Gegenstelle> vorher;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT art, ref_id, uid, bezeichnung FROM bauteil_bezug")) {
            while (q.next())
                vorher.insert({ q.value(0).toString(), q.value(1).toInt() }, { q.value(2).toString(), q.value(3).toString() });
        }
    }
    QHash<Schluessel, Gegenstelle> neu;
    for (const Schluessel &s : aktuelleVerweise(m_db)) {
        const Gegenstelle lokal = lokaleGegenstelle(m_db, s.first, s.second);
        const auto p = vorher.constFind(s);
        if (p == vorher.constEnd()) {
            if (!lokal.uid.isEmpty())
                neu.insert(s, lokal);                   // erste Beobachtung: es gilt der Stand der lokalen Bibliothek
        } else if (!lokal.uid.isEmpty() && lokal.uid == p->uid) {
            neu.insert(s, lokal);                       // unverändert (Bezeichnung nachziehen)
        } else {
            neu.insert(s, *p);                          // abweichend/fehlend: erwartete UID NICHT überschreiben (sonst ginge das Wissen verloren)
        }
    }
    if (neu == vorher)
        return true;   // nichts zu schreiben – die Datei bleibt unangetastet (Änderungsstempel!)

    if (!m_db.transaction())
        return false;
    QSqlQuery d(m_db);
    bool ok = d.exec("DELETE FROM bauteil_bezug");
    for (auto it = neu.constBegin(); ok && it != neu.constEnd(); ++it) {
        QSqlQuery i(m_db);
        i.prepare("INSERT INTO bauteil_bezug (art, ref_id, uid, bezeichnung) VALUES (?, ?, ?, ?)");
        i.addBindValue(it.key().first);
        i.addBindValue(it.key().second);
        i.addBindValue(it.value().uid);
        i.addBindValue(it.value().bezeichnung);
        ok = i.exec();
    }
    if (!ok || !m_db.commit()) {
        m_db.rollback();
        qCWarning(lcDb) << "bauteilBezuegeAktualisieren fehlgeschlagen";
        return false;
    }
    return true;
}
