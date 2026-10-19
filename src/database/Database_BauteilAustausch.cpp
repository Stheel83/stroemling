// BIB-IMPORT-01: Austausch der Bauteil-Bibliothek zwischen Rechnern (JSON-Bündel "stroemling-bauteile").
// Konzept: konzept/features/56_bauteil_austausch.md. Leitlinien: UIDs sind unveränderlich (Zusammenführen = Alias),
// nie still überschreiben (erst analysieren, dann Entscheidungen des Nutzers), Referenzen im Bündel nur über UID.
#include "Database.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSet>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QUuid>
#include <functional>

namespace {

constexpr auto kFormat = "stroemling-bauteile";
constexpr int kFormatVersion = 1;

using Zusatz = std::function<QVariantMap(const QJsonObject &)>;

QStringList spaltenVon(QSqlDatabase &db, const QString &tabelle)
{
    QStringList s;
    QSqlQuery q(db);
    if (q.exec(QStringLiteral("PRAGMA table_info(%1)").arg(tabelle))) {
        while (q.next())
            s << q.value(1).toString();
    }
    return s;
}

// Zeile → JSON (alle Spalten außer den ausgeschlossenen)
QJsonObject zeileAlsJson(const QSqlRecord &rec, const QSet<QString> &aus)
{
    QJsonObject o;
    for (int i = 0; i < rec.count(); ++i) {
        const QString name = rec.fieldName(i);
        if (aus.contains(name))
            continue;
        const QVariant v = rec.value(i);
        o.insert(name, v.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue::fromVariant(v));
    }
    return o;
}

QJsonArray zeilen(QSqlDatabase &db, const QString &sql, const QVariant &bind, const QSet<QString> &aus,
                  const std::function<void(QJsonObject &, const QSqlRecord &)> &anreichern = nullptr)
{
    QJsonArray a;
    QSqlQuery q(db);
    q.prepare(sql);
    q.addBindValue(bind);
    if (q.exec()) {
        while (q.next()) {
            QJsonObject o = zeileAlsJson(q.record(), aus);
            if (anreichern)
                anreichern(o, q.record());
            a.append(o);
        }
    }
    return a;
}

QString uidVon(QSqlDatabase &db, int bauteilId)
{
    QSqlQuery q(db);
    q.prepare("SELECT uid FROM bauteil WHERE id = ?");
    q.addBindValue(bauteilId);
    return (q.exec() && q.next()) ? q.value(0).toString() : QString();
}

// Verweis auf eine Zeile einer Untertyp-Tabelle eines ANDEREN Bauteils: (UID des Eigentümers, Index unter dessen Zeilen)
QJsonObject verweisAuf(QSqlDatabase &db, const QString &tabelle, int zeilenId)
{
    QJsonObject o;
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT bauteil_id FROM %1 WHERE id = ?").arg(tabelle));
    q.addBindValue(zeilenId);
    if (!q.exec() || !q.next())
        return o;
    const int besitzer = q.value(0).toInt();
    QSqlQuery l(db);
    l.prepare(QStringLiteral("SELECT id FROM %1 WHERE bauteil_id = ? ORDER BY id").arg(tabelle));
    l.addBindValue(besitzer);
    int idx = 0;
    if (l.exec()) {
        while (l.next()) {
            if (l.value(0).toInt() == zeilenId)
                break;
            ++idx;
        }
    }
    o.insert("bauteil_uid", uidVon(db, besitzer));
    o.insert("idx", idx);
    return o;
}

// n-te Zeile (nach id) der Untertyp-Tabelle eines Bauteils; -1 wenn es sie nicht gibt
int zeilenIdAm(QSqlDatabase &db, const QString &tabelle, int bauteilId, int idx)
{
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT id FROM %1 WHERE bauteil_id = ? ORDER BY id LIMIT 1 OFFSET ?").arg(tabelle));
    q.addBindValue(bauteilId);
    q.addBindValue(idx);
    return (q.exec() && q.next()) ? q.value(0).toInt() : -1;
}

QStringList kategoriePfad(QSqlDatabase &db, int kategorieId)
{
    QStringList teile;
    QSet<int> besucht;
    int id = kategorieId;
    while (id > 0 && !besucht.contains(id)) {
        besucht.insert(id);
        QSqlQuery q(db);
        q.prepare("SELECT name, parent_id FROM bauteil_kategorie WHERE id = ?");
        q.addBindValue(id);
        if (!q.exec() || !q.next())
            break;
        teile.prepend(q.value(0).toString());
        id = q.value(1).toInt();
    }
    return teile;
}

// Bauteil samt aller Untertypen als JSON-Objekt (ohne lokale IDs; Querverweise über UID)
QJsonObject bauteilAlsObjekt(QSqlDatabase &db, int bauteilId)
{
    QJsonObject teil;
    QSqlQuery q(db);
    q.prepare("SELECT * FROM bauteil WHERE id = ?");
    q.addBindValue(bauteilId);
    if (!q.exec() || !q.next())
        return teil;
    const QSqlRecord rec = q.record();
    teil.insert("uid", rec.value("uid").toString());
    QJsonArray pfad;
    for (const QString &n : kategoriePfad(db, rec.value("kategorie_id").toInt()))
        pfad.append(n);
    teil.insert("kategorie", pfad);
    teil.insert("felder", zeileAlsJson(rec, { "id", "uid", "kategorie_id", "fuer_seed_vormerken", "ist_system" }));

    // Kabeltypen mit Adern und Paaren
    {
        QJsonArray kabel;
        QSqlQuery k(db);
        k.prepare("SELECT * FROM bauteil_kabel WHERE bauteil_id = ? ORDER BY id");
        k.addBindValue(bauteilId);
        if (k.exec()) {
            while (k.next()) {
                QJsonObject o = zeileAlsJson(k.record(), { "id", "bauteil_id" });
                const int kid = k.value("id").toInt();
                o.insert("adern", zeilen(db, "SELECT * FROM bauteil_kabel_ader WHERE kabel_id = ? ORDER BY ader_nr, id", kid, { "id", "kabel_id" }));
                o.insert("paare", zeilen(db, "SELECT * FROM bauteil_kabel_paar WHERE kabel_id = ? ORDER BY paar_nr, id", kid, { "id", "kabel_id" }));
                kabel.append(o);
            }
        }
        teil.insert("kabel", kabel);
    }
    // Klemmen (Gehäusefarbe über die Bezeichnung)
    {
        QJsonArray klemmen;
        QSqlQuery k(db);
        k.prepare("SELECT * FROM bauteil_klemme WHERE bauteil_id = ? ORDER BY id");
        k.addBindValue(bauteilId);
        if (k.exec()) {
            while (k.next()) {
                QJsonObject o = zeileAlsJson(k.record(), { "id", "bauteil_id", "gehaeuse_farbe_id" });
                const int kid = k.value("id").toInt();
                QSqlQuery f(db);
                f.prepare("SELECT bezeichnung FROM farb_definition WHERE id = ?");
                f.addBindValue(k.value("gehaeuse_farbe_id"));
                o.insert("gehaeuse_farbe", (f.exec() && f.next()) ? QJsonValue(f.value(0).toString()) : QJsonValue(QJsonValue::Null));
                o.insert("querschnitte", zeilen(db, "SELECT * FROM bauteil_klemme_querschnitt WHERE klemme_id = ? ORDER BY adertyp, min_mm2, id", kid, { "id", "klemme_id" }));
                o.insert("bruecken", zeilen(db, "SELECT * FROM bauteil_klemme_bruecke WHERE klemme_id = ? ORDER BY von_ebene, nach_ebene, id", kid, { "id", "klemme_id" }));
                o.insert("eigenschaften", zeilen(db, "SELECT * FROM bauteil_klemme_eigenschaft WHERE klemme_id = ? ORDER BY schluessel, id", kid, { "id", "klemme_id" }));
                klemmen.append(o);
            }
        }
        teil.insert("klemme", klemmen);
    }
    teil.insert("kontakte", zeilen(db, "SELECT * FROM bauteil_kontakt WHERE bauteil_id = ? ORDER BY id", bauteilId, { "id", "bauteil_id" }));
    teil.insert("kontakt_typen", zeilen(db, "SELECT * FROM kontakt_typ WHERE bauteil_id = ? ORDER BY id", bauteilId, { "id", "bauteil_id" }));

    // Steckverbinder: Kabeleinführungen und Positionen (Kontakttyp über Verweis auf das Eigentümer-Bauteil)
    {
        QJsonArray sv;
        QSqlQuery s(db);
        s.prepare("SELECT * FROM steckverbinder_typ WHERE bauteil_id = ? ORDER BY id");
        s.addBindValue(bauteilId);
        if (s.exec()) {
            while (s.next()) {
                QJsonObject o = zeileAlsJson(s.record(), { "id", "bauteil_id" });
                const int sid = s.value("id").toInt();
                o.insert("kabeleinf", zeilen(db, "SELECT * FROM steckverbinder_kabeleinf WHERE steckverbinder_typ_id = ? ORDER BY einf_nr, id", sid,
                                             { "id", "steckverbinder_typ_id" }));
                o.insert("positionen", zeilen(db, "SELECT * FROM steckverbinder_position WHERE steckverbinder_typ_id = ? ORDER BY position_nr, id", sid,
                                              { "id", "steckverbinder_typ_id", "kontakt_typ_id" },
                                              [&](QJsonObject &z, const QSqlRecord &r) { z.insert("kontakt_typ", verweisAuf(db, "kontakt_typ", r.value("kontakt_typ_id").toInt())); }));
                sv.append(o);
            }
        }
        teil.insert("steckverbinder", sv);
    }
    // Konfektionierte Kabel: Kabeltyp und Stecker über UID
    {
        QJsonArray kk;
        QSqlQuery k(db);
        k.prepare("SELECT * FROM konfektioniertes_kabel WHERE bauteil_id = ? ORDER BY id");
        k.addBindValue(bauteilId);
        if (k.exec()) {
            while (k.next()) {
                QJsonObject o = zeileAlsJson(k.record(), { "id", "bauteil_id", "bauteil_kabel_id", "stecker_a_bauteil_id", "stecker_b_bauteil_id" });
                o.insert("kabel", k.value("bauteil_kabel_id").isNull() ? QJsonObject() : verweisAuf(db, "bauteil_kabel", k.value("bauteil_kabel_id").toInt()));
                o.insert("stecker_a_uid", k.value("stecker_a_bauteil_id").isNull() ? QString() : uidVon(db, k.value("stecker_a_bauteil_id").toInt()));
                o.insert("stecker_b_uid", k.value("stecker_b_bauteil_id").isNull() ? QString() : uidVon(db, k.value("stecker_b_bauteil_id").toInt()));
                o.insert("pins", zeilen(db, "SELECT * FROM konfkabel_pin_zuordnung WHERE konfkabel_id = ? ORDER BY seite, ader_nr, id", k.value("id").toInt(),
                                        { "id", "konfkabel_id" }));
                kk.append(o);
            }
        }
        teil.insert("konfektioniert", kk);
    }
    return teil;
}

// Inhalts-Hash: gleiche Bauteile haben unabhängig von UID und lokalen IDs denselben Hash
QString inhaltsHash(QJsonObject teil)
{
    teil.remove("uid");
    return QString::fromLatin1(QCryptographicHash::hash(QJsonDocument(teil).toJson(QJsonDocument::Compact),
                                                          QCryptographicHash::Sha256).toHex());
}

QVariant alsVariant(const QJsonValue &v)
{
    return v.isNull() || v.isUndefined() ? QVariant() : v.toVariant();
}

// Fügt eine Zeile ein: skalare Felder von `obj`, soweit es die Spalte lokal gibt, plus feste Werte. Gibt die neue ID zurück.
int zeileEinfuegen(QSqlDatabase &db, const QString &tabelle, const QJsonObject &obj, const QVariantMap &fest, const QStringList &lokaleSpalten)
{
    QStringList cols;
    QVariantList werte;
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        if (it.value().isArray() || it.value().isObject() || !lokaleSpalten.contains(it.key()) || fest.contains(it.key()) || it.key() == "id")
            continue;
        cols << it.key();
        werte << alsVariant(it.value());
    }
    for (auto it = fest.constBegin(); it != fest.constEnd(); ++it) {
        cols << it.key();
        werte << it.value();
    }
    QSqlQuery q(db);
    QStringList platz;
    for (int i = 0; i < cols.size(); ++i)
        platz << QStringLiteral("?");
    q.prepare(QStringLiteral("INSERT INTO %1 (%2) VALUES (%3)").arg(tabelle, cols.join(','), platz.join(',')));
    for (const QVariant &v : werte)
        q.addBindValue(v);
    return q.exec() ? q.lastInsertId().toInt() : -1;
}

bool zeileAktualisieren(QSqlDatabase &db, const QString &tabelle, int id, const QJsonObject &obj, const QVariantMap &fest, const QStringList &lokaleSpalten)
{
    QStringList sets;
    QVariantList werte;
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        if (it.value().isArray() || it.value().isObject() || !lokaleSpalten.contains(it.key()) || fest.contains(it.key()) || it.key() == "id")
            continue;
        sets << it.key() + QStringLiteral(" = ?");
        werte << alsVariant(it.value());
    }
    for (auto it = fest.constBegin(); it != fest.constEnd(); ++it) {
        sets << it.key() + QStringLiteral(" = ?");
        werte << it.value();
    }
    if (sets.isEmpty())
        return true;
    QSqlQuery q(db);
    q.prepare(QStringLiteral("UPDATE %1 SET %2 WHERE id = ?").arg(tabelle, sets.join(", ")));
    for (const QVariant &v : werte)
        q.addBindValue(v);
    q.addBindValue(id);
    return q.exec();
}

// Gleicht die Kindzeilen einer Tabelle in POSITION an: die n-te vorhandene Zeile wird aktualisiert (ihre ID bleibt, Projekte
// können darauf zeigen), überzählige vorhandene werden gelöscht, fehlende eingefügt. `kinder` verarbeitet je Zeile deren Unterzeilen.
void synchronisiere(QSqlDatabase &db, const QString &tabelle, const QString &fk, int elternId, const QJsonArray &soll,
                    const std::function<void(int, const QJsonObject &)> &kinder, const Zusatz &zusatz, QStringList &warnungen,
                    const std::function<void(int)> &vorLoeschen = nullptr)
{
    const QStringList cols = spaltenVon(db, tabelle);
    QList<int> vorhanden;
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT id FROM %1 WHERE %2 = ? ORDER BY id").arg(tabelle, fk));
    q.addBindValue(elternId);
    if (q.exec()) {
        while (q.next())
            vorhanden << q.value(0).toInt();
    }
    for (int i = 0; i < soll.size(); ++i) {
        const QJsonObject zeile = soll.at(i).toObject();
        QVariantMap fest = zusatz ? zusatz(zeile) : QVariantMap();
        int id;
        if (i < vorhanden.size()) {
            id = vorhanden.at(i);
            if (!zeileAktualisieren(db, tabelle, id, zeile, fest, cols))
                warnungen << QStringLiteral("%1: Zeile konnte nicht aktualisiert werden").arg(tabelle);
        } else {
            fest.insert(fk, elternId);
            id = zeileEinfuegen(db, tabelle, zeile, fest, cols);
            if (id < 0) {
                warnungen << QStringLiteral("%1: Zeile konnte nicht angelegt werden").arg(tabelle);
                continue;
            }
        }
        if (kinder)
            kinder(id, zeile);
    }
    for (int i = soll.size(); i < vorhanden.size(); ++i) {
        if (vorLoeschen)
            vorLoeschen(vorhanden.at(i));
        QSqlQuery d(db);
        d.prepare(QStringLiteral("DELETE FROM %1 WHERE id = ?").arg(tabelle));
        d.addBindValue(vorhanden.at(i));
        if (!d.exec())   // z. B. weil ein konfektioniertes Kabel noch darauf verweist – lokal behalten, nicht abbrechen
            warnungen << QStringLiteral("%1: überzählige lokale Zeile bleibt bestehen (%2)").arg(tabelle, d.lastError().text());
    }
}

int kategorieSicherstellen(QSqlDatabase &db, const QJsonArray &pfad)
{
    int parent = 0;
    for (const QJsonValue &v : pfad) {
        const QString name = v.toString();
        if (name.isEmpty())
            continue;
        QSqlQuery q(db);
        q.prepare(parent > 0 ? "SELECT id FROM bauteil_kategorie WHERE name = ? AND parent_id = ?"
                             : "SELECT id FROM bauteil_kategorie WHERE name = ? AND parent_id IS NULL");
        q.addBindValue(name);
        if (parent > 0)
            q.addBindValue(parent);
        if (q.exec() && q.next()) {
            parent = q.value(0).toInt();
            continue;
        }
        QSqlQuery i(db);
        i.prepare("INSERT INTO bauteil_kategorie (name, parent_id) VALUES (?, ?)");
        i.addBindValue(name);
        i.addBindValue(parent > 0 ? QVariant(parent) : QVariant());
        if (!i.exec())
            return parent > 0 ? parent : -1;
        parent = i.lastInsertId().toInt();
    }
    return parent > 0 ? parent : -1;
}

int farbeSicherstellen(QSqlDatabase &db, const QString &bezeichnung, const QHash<QString, QJsonObject> &farben)
{
    if (bezeichnung.isEmpty())
        return -1;
    QSqlQuery q(db);
    q.prepare("SELECT id FROM farb_definition WHERE bezeichnung = ? LIMIT 1");
    q.addBindValue(bezeichnung);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    const QJsonObject f = farben.value(bezeichnung);
    QSqlQuery i(db);
    i.prepare("INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) VALUES (?, ?, ?, ?)");
    i.addBindValue(f.value("hex_wert").toString());
    i.addBindValue(bezeichnung);
    i.addBindValue(0);   // importierte Farben sind keine Standardfarben
    i.addBindValue(f.value("sortierung").toInt(500));
    return i.exec() ? i.lastInsertId().toInt() : -1;
}

// Schreibt ein Bauteil (aktualisiert die Felder und gleicht alle Untertypen in Position an), ohne Querverweise zu anderen Bauteilen
bool bauteilSchreiben(QSqlDatabase &db, int bauteilId, const QJsonObject &teil, const QHash<QString, QJsonObject> &farben, QStringList &warnungen,
                      const QString &bezeichnungSuffix = QString())
{
    QJsonObject felder = teil.value("felder").toObject();
    if (!bezeichnungSuffix.isEmpty())
        felder.insert("bezeichnung", felder.value("bezeichnung").toString() + bezeichnungSuffix);
    QVariantMap fest;
    const int kat = kategorieSicherstellen(db, teil.value("kategorie").toArray());
    fest.insert("kategorie_id", kat > 0 ? QVariant(kat) : QVariant());
    if (!zeileAktualisieren(db, "bauteil", bauteilId, felder, fest, spaltenVon(db, "bauteil")))
        return false;

    // Kabel → Adern, Paare
    synchronisiere(db, "bauteil_kabel", "bauteil_id", bauteilId, teil.value("kabel").toArray(),
        [&](int kid, const QJsonObject &z) {
            synchronisiere(db, "bauteil_kabel_ader", "kabel_id", kid, z.value("adern").toArray(), nullptr, nullptr, warnungen);
            synchronisiere(db, "bauteil_kabel_paar", "kabel_id", kid, z.value("paare").toArray(), nullptr, nullptr, warnungen);
        }, nullptr, warnungen);
    // Klemmen → Querschnitte, Brücken, Eigenschaften (ohne CASCADE: Kinder vor dem Löschen der Klemme entfernen)
    synchronisiere(db, "bauteil_klemme", "bauteil_id", bauteilId, teil.value("klemme").toArray(),
        [&](int kid, const QJsonObject &z) {
            synchronisiere(db, "bauteil_klemme_querschnitt", "klemme_id", kid, z.value("querschnitte").toArray(), nullptr, nullptr, warnungen);
            synchronisiere(db, "bauteil_klemme_bruecke", "klemme_id", kid, z.value("bruecken").toArray(), nullptr, nullptr, warnungen);
            synchronisiere(db, "bauteil_klemme_eigenschaft", "klemme_id", kid, z.value("eigenschaften").toArray(), nullptr, nullptr, warnungen);
        },
        [&](const QJsonObject &z) {
            const int farbe = farbeSicherstellen(db, z.value("gehaeuse_farbe").toString(), farben);
            return QVariantMap { { "gehaeuse_farbe_id", farbe > 0 ? QVariant(farbe) : QVariant() } };
        }, warnungen,
        [&](int klemmeId) {
            for (const char *t : { "bauteil_klemme_querschnitt", "bauteil_klemme_bruecke", "bauteil_klemme_eigenschaft" }) {
                QSqlQuery d(db);
                d.prepare(QStringLiteral("DELETE FROM %1 WHERE klemme_id = ?").arg(QLatin1String(t)));
                d.addBindValue(klemmeId);
                d.exec();
            }
        });
    synchronisiere(db, "bauteil_kontakt", "bauteil_id", bauteilId, teil.value("kontakte").toArray(), nullptr, nullptr, warnungen);
    synchronisiere(db, "kontakt_typ", "bauteil_id", bauteilId, teil.value("kontakt_typen").toArray(), nullptr, nullptr, warnungen);
    // Steckverbinder → Kabeleinführungen (Positionen folgen im zweiten Durchlauf)
    synchronisiere(db, "steckverbinder_typ", "bauteil_id", bauteilId, teil.value("steckverbinder").toArray(),
        [&](int sid, const QJsonObject &z) {
            synchronisiere(db, "steckverbinder_kabeleinf", "steckverbinder_typ_id", sid, z.value("kabeleinf").toArray(), nullptr, nullptr, warnungen);
        }, nullptr, warnungen);
    return true;
}

// Zweiter Durchlauf: Querverweise auf andere Bauteile (über UID/Alias auflösen)
void querverweiseSchreiben(Database &self, QSqlDatabase &db, int bauteilId, const QJsonObject &teil, QStringList &warnungen)
{
    const QString name = teil.value("felder").toObject().value("bezeichnung").toString();
    // Steckverbinder-Positionen
    {
        QSqlQuery q(db);
        q.prepare("SELECT id FROM steckverbinder_typ WHERE bauteil_id = ? ORDER BY id");
        q.addBindValue(bauteilId);
        QList<int> svIds;
        if (q.exec())
            while (q.next())
                svIds << q.value(0).toInt();
        const QJsonArray svSoll = teil.value("steckverbinder").toArray();
        for (int i = 0; i < svSoll.size() && i < svIds.size(); ++i) {
            QJsonArray positionen;
            for (const QJsonValue &pv : svSoll.at(i).toObject().value("positionen").toArray()) {
                const QJsonObject p = pv.toObject();
                const QJsonObject ref = p.value("kontakt_typ").toObject();
                const int besitzer = self.bauteilIdFuerUid(ref.value("bauteil_uid").toString());
                const int ktId = besitzer > 0 ? zeilenIdAm(db, "kontakt_typ", besitzer, ref.value("idx").toInt()) : -1;
                if (ktId < 0) {
                    warnungen << QStringLiteral("%1: Steckverbinder-Position %2 – Kontakttyp nicht auflösbar, übersprungen")
                                     .arg(name).arg(p.value("position_nr").toInt());
                    continue;
                }
                QJsonObject np = p;
                np.insert("kontakt_typ_id", ktId);
                positionen.append(np);
            }
            synchronisiere(db, "steckverbinder_position", "steckverbinder_typ_id", svIds.at(i), positionen, nullptr, nullptr, warnungen);
        }
    }
    // Konfektionierte Kabel
    synchronisiere(db, "konfektioniertes_kabel", "bauteil_id", bauteilId, teil.value("konfektioniert").toArray(),
        [&](int kid, const QJsonObject &z) {
            synchronisiere(db, "konfkabel_pin_zuordnung", "konfkabel_id", kid, z.value("pins").toArray(), nullptr, nullptr, warnungen);
        },
        [&](const QJsonObject &z) {
            const auto aufloesen = [&](const QString &uid, const QString &was) {
                if (uid.isEmpty())
                    return QVariant();
                const int id = self.bauteilIdFuerUid(uid);
                if (id < 0)
                    warnungen << QStringLiteral("%1: %2 (UID %3) ist lokal nicht vorhanden").arg(name, was, uid.left(8));
                return id > 0 ? QVariant(id) : QVariant();
            };
            QVariant kabelId;
            const QJsonObject ref = z.value("kabel").toObject();
            if (!ref.isEmpty()) {
                const int besitzer = self.bauteilIdFuerUid(ref.value("bauteil_uid").toString());
                const int id = besitzer > 0 ? zeilenIdAm(db, "bauteil_kabel", besitzer, ref.value("idx").toInt()) : -1;
                if (id < 0)
                    warnungen << QStringLiteral("%1: Kabeltyp des konfektionierten Kabels nicht auflösbar").arg(name);
                else
                    kabelId = id;
            }
            return QVariantMap { { "bauteil_kabel_id", kabelId },
                                 { "stecker_a_bauteil_id", aufloesen(z.value("stecker_a_uid").toString(), QStringLiteral("Stecker A")) },
                                 { "stecker_b_bauteil_id", aufloesen(z.value("stecker_b_uid").toString(), QStringLiteral("Stecker B")) } };
        }, warnungen);
}

struct Buendel
{
    bool ok = false;
    QString fehler;
    QJsonArray bauteile;
    QHash<QString, QJsonObject> farben;
};

Buendel buendelLesen(const QString &pfad)
{
    Buendel b;
    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly)) {
        b.fehler = QStringLiteral("Datei nicht lesbar: %1").arg(pfad);
        return b;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        b.fehler = QStringLiteral("Keine gültige JSON-Datei (%1)").arg(err.errorString());
        return b;
    }
    const QJsonObject o = doc.object();
    if (o.value("format").toString() != QLatin1String(kFormat)) {
        b.fehler = QStringLiteral("Das ist kein Bauteil-Bündel von Strömling (Format „%1“)").arg(o.value("format").toString());
        return b;
    }
    if (o.value("version").toInt() > kFormatVersion) {
        b.fehler = QStringLiteral("Das Bündel stammt aus einer neueren Strömling-Version (Format %1, bekannt: %2). Bitte Strömling aktualisieren.")
                       .arg(o.value("version").toInt()).arg(kFormatVersion);
        return b;
    }
    b.bauteile = o.value("bauteile").toArray();
    for (const QJsonValue &fv : o.value("farben").toArray())
        b.farben.insert(fv.toObject().value("bezeichnung").toString(), fv.toObject());
    b.ok = true;
    return b;
}

QString typVon(const QJsonObject &t)
{
    if (!t.value("konfektioniert").toArray().isEmpty()) return QStringLiteral("Konfektioniertes Kabel");
    if (!t.value("kabel").toArray().isEmpty())          return QStringLiteral("Kabel");
    if (!t.value("klemme").toArray().isEmpty())         return QStringLiteral("Klemme");
    if (!t.value("steckverbinder").toArray().isEmpty()) return QStringLiteral("Steckverbinder");
    if (!t.value("kontakte").toArray().isEmpty())       return QStringLiteral("Gerät mit Kontakten");
    return QStringLiteral("Bauteil");
}

QStringList aktionenFuer(const QString &status)
{
    if (status == "neu")      return { "anlegen", "ueberspringen" };
    if (status == "gleich")   return { "ueberspringen" };
    if (status == "abweichend") return { "ueberspringen", "ueberschreiben", "kopie" };
    if (status == "gleicherInhalt") return { "verknuepfen", "anlegen", "ueberspringen" };
    return { "anlegen", "verknuepfen", "ueberspringen" };   // aehnlich
}

QString vorschlagFuer(const QString &status)
{
    if (status == "neu")                return QStringLiteral("anlegen");
    if (status == "gleich")             return QStringLiteral("ueberspringen");
    if (status == "abweichend")         return QStringLiteral("ueberspringen");   // lokal behalten, nie stilles Überschreiben
    if (status == "gleicherInhalt")     return QStringLiteral("verknuepfen");
    return QStringLiteral("anlegen");                                              // aehnlich
}

} // namespace

// ---------------------------------------------------------------------------------------------------------------
QVariantMap Database::bauteileExportieren(const QString &pfad, bool mitSystem)
{
    QVariantMap erg { { "ok", false }, { "anzahl", 0 }, { "fehler", QString() } };
    if (!m_bibliothekDb.isOpen()) {
        erg["fehler"] = QStringLiteral("Bibliothek nicht geöffnet");
        return erg;
    }
    QSqlQuery q(m_bibliothekDb);
    if (!q.exec(QStringLiteral("SELECT id FROM bauteil %1 ORDER BY bezeichnung COLLATE NOCASE, id")
                    .arg(mitSystem ? QString() : QStringLiteral("WHERE ist_system = 0")))) {
        erg["fehler"] = q.lastError().text();
        return erg;
    }
    QList<int> ids;
    while (q.next())
        ids << q.value(0).toInt();

    QJsonArray bauteile;
    QSet<QString> farbNamen;
    for (int id : ids) {
        const QJsonObject o = bauteilAlsObjekt(m_bibliothekDb, id);
        if (o.value("uid").toString().isEmpty())
            continue;   // sollte nach BIB-UID-01 nicht vorkommen
        for (const QJsonValue &k : o.value("klemme").toArray()) {
            const QString f = k.toObject().value("gehaeuse_farbe").toString();
            if (!f.isEmpty())
                farbNamen.insert(f);
        }
        bauteile.append(o);
    }
    QJsonArray farben;
    for (const QString &n : farbNamen) {
        QSqlQuery f(m_bibliothekDb);
        f.prepare("SELECT hex_wert, ist_standard, sortierung FROM farb_definition WHERE bezeichnung = ? LIMIT 1");
        f.addBindValue(n);
        if (f.exec() && f.next())
            farben.append(QJsonObject { { "bezeichnung", n }, { "hex_wert", f.value(0).toString() },
                                        { "ist_standard", f.value(1).toInt() }, { "sortierung", f.value(2).toInt() } });
    }
    const QJsonObject wurzel {
        { "format", QString::fromLatin1(kFormat) }, { "version", kFormatVersion },
        { "exportiert_am", QDateTime::currentDateTimeUtc().toString(Qt::ISODate) },
        { "farben", farben }, { "bauteile", bauteile },
    };
    QSaveFile datei(pfad);
    if (!datei.open(QIODevice::WriteOnly)) {
        erg["fehler"] = QStringLiteral("Datei nicht schreibbar: %1").arg(datei.errorString());
        return erg;
    }
    datei.write(QJsonDocument(wurzel).toJson(QJsonDocument::Indented));
    if (!datei.commit()) {
        erg["fehler"] = QStringLiteral("Schreiben fehlgeschlagen: %1").arg(datei.errorString());
        return erg;
    }
    erg["ok"] = true;
    erg["anzahl"] = bauteile.size();
    return erg;
}

QVariantMap Database::bauteileImportAnalysieren(const QString &pfad)
{
    QVariantMap erg { { "ok", false }, { "fehler", QString() }, { "eintraege", QVariantList() } };
    if (!m_bibliothekDb.isOpen()) {
        erg["fehler"] = QStringLiteral("Bibliothek nicht geöffnet");
        return erg;
    }
    const Buendel b = buendelLesen(pfad);
    if (!b.ok) {
        erg["fehler"] = b.fehler;
        return erg;
    }

    // Lokale Hashes und Bezeichnungen nur bei Bedarf bilden
    QHash<QString, int> lokaleHashes;
    QHash<QString, int> lokaleNamen;
    bool lokalesIndexiert = false;
    const auto indexieren = [&]() {
        if (lokalesIndexiert)
            return;
        lokalesIndexiert = true;
        QSqlQuery q(m_bibliothekDb);
        if (q.exec("SELECT id, bezeichnung FROM bauteil ORDER BY id")) {
            while (q.next()) {
                const int id = q.value(0).toInt();
                lokaleHashes.insert(inhaltsHash(bauteilAlsObjekt(m_bibliothekDb, id)), id);
                lokaleNamen.insert(q.value(1).toString().trimmed().toLower(), id);
            }
        }
    };
    const auto lokaleBezeichnung = [&](int id) {
        QSqlQuery q(m_bibliothekDb);
        q.prepare("SELECT bezeichnung FROM bauteil WHERE id = ?");
        q.addBindValue(id);
        return (q.exec() && q.next()) ? q.value(0).toString() : QString();
    };

    QVariantList eintraege;
    QHash<QString, int> zaehler;
    for (const QJsonValue &v : b.bauteile) {
        const QJsonObject t = v.toObject();
        const QString uid = t.value("uid").toString();
        if (uid.isEmpty())
            continue;
        const QJsonObject f = t.value("felder").toObject();
        const QString hash = inhaltsHash(t);
        QString status;
        int lokalId = bauteilIdFuerUid(uid);
        if (lokalId > 0) {
            status = (inhaltsHash(bauteilAlsObjekt(m_bibliothekDb, lokalId)) == hash) ? QStringLiteral("gleich") : QStringLiteral("abweichend");
        } else {
            indexieren();
            if (lokaleHashes.contains(hash)) {
                status = QStringLiteral("gleicherInhalt");
                lokalId = lokaleHashes.value(hash);
            } else if (lokaleNamen.contains(f.value("bezeichnung").toString().trimmed().toLower())) {
                status = QStringLiteral("aehnlich");
                lokalId = lokaleNamen.value(f.value("bezeichnung").toString().trimmed().toLower());
            } else {
                status = QStringLiteral("neu");
            }
        }
        zaehler[status]++;
        QStringList kategorie;
        for (const QJsonValue &k : t.value("kategorie").toArray())
            kategorie << k.toString();
        eintraege.append(QVariantMap {
            { "uid", uid }, { "bezeichnung", f.value("bezeichnung").toString() }, { "hersteller", f.value("hersteller").toString() },
            { "artikelnummer", f.value("artikelnummer").toString() }, { "typ", typVon(t) }, { "kategorie", kategorie.join(QStringLiteral(" › ")) },
            { "status", status }, { "lokalId", lokalId > 0 ? lokalId : -1 },
            { "lokaleBezeichnung", lokalId > 0 ? lokaleBezeichnung(lokalId) : QString() },
            { "vorschlag", vorschlagFuer(status) }, { "aktionen", aktionenFuer(status) } });
    }
    erg["ok"] = true;
    erg["eintraege"] = eintraege;
    erg["anzahlNeu"] = zaehler.value("neu");
    erg["anzahlGleich"] = zaehler.value("gleich");
    erg["anzahlAbweichend"] = zaehler.value("abweichend");
    erg["anzahlGleicherInhalt"] = zaehler.value("gleicherInhalt");
    erg["anzahlAehnlich"] = zaehler.value("aehnlich");
    return erg;
}

QVariantMap Database::bauteileImportAusfuehren(const QString &pfad, const QVariantMap &entscheidungen)
{
    QVariantMap erg { { "ok", false }, { "fehler", QString() }, { "angelegt", 0 }, { "ueberschrieben", 0 }, { "verknuepft", 0 },
                      { "kopien", 0 }, { "uebersprungen", 0 }, { "warnungen", QStringList() }, { "sicherung", QString() } };
    if (!m_bibliothekDb.isOpen()) {
        erg["fehler"] = QStringLiteral("Bibliothek nicht geöffnet");
        return erg;
    }
    const QVariantMap analyse = bauteileImportAnalysieren(pfad);
    if (!analyse.value("ok").toBool()) {
        erg["fehler"] = analyse.value("fehler");
        return erg;
    }
    const Buendel b = buendelLesen(pfad);

    // Aktion je Eintrag bestimmen (nur zulässige; sonst der Vorschlag)
    struct Plan { QJsonObject teil; QString aktion; int lokalId; };
    QList<Plan> plan;
    {
        QHash<QString, QJsonObject> nachUid;
        for (const QJsonValue &v : b.bauteile)
            nachUid.insert(v.toObject().value("uid").toString(), v.toObject());
        for (const QVariant &ev : analyse.value("eintraege").toList()) {
            const QVariantMap e = ev.toMap();
            QString aktion = entscheidungen.value(e.value("uid").toString()).toString();
            if (!e.value("aktionen").toStringList().contains(aktion))
                aktion = e.value("vorschlag").toString();
            plan.append({ nachUid.value(e.value("uid").toString()), aktion, e.value("lokalId").toInt() });
        }
    }

    erg["sicherung"] = bibliothekSichern(QStringLiteral("vor_import"));
    if (!m_bibliothekDb.transaction()) {
        erg["fehler"] = QStringLiteral("Transaktion konnte nicht gestartet werden");
        return erg;
    }
    QStringList warnungen;
    QList<QPair<int, QJsonObject>> fuerQuerverweise;   // (lokale ID, Bauteil) – zweiter Durchlauf
    int angelegt = 0, ueberschrieben = 0, verknuepft = 0, kopien = 0, uebersprungen = 0;
    bool fehlerAufgetreten = false;

    for (const Plan &p : plan) {
        const QString uid = p.teil.value("uid").toString();
        const QString name = p.teil.value("felder").toObject().value("bezeichnung").toString();
        if (p.aktion == QLatin1String("ueberspringen")) {
            ++uebersprungen;
        } else if (p.aktion == QLatin1String("verknuepfen")) {
            QSqlQuery a(m_bibliothekDb);
            a.prepare("INSERT OR IGNORE INTO bauteil_alias (alias_uid, bauteil_id) VALUES (?, ?)");
            a.addBindValue(uid);
            a.addBindValue(p.lokalId);
            if (p.lokalId > 0 && a.exec())
                ++verknuepft;
            else {
                warnungen << QStringLiteral("%1: Verknüpfung nicht möglich").arg(name);
                ++uebersprungen;
            }
        } else if (p.aktion == QLatin1String("ueberschreiben") && p.lokalId > 0) {
            if (bauteilSchreiben(m_bibliothekDb, p.lokalId, p.teil, b.farben, warnungen)) {
                fuerQuerverweise.append({ p.lokalId, p.teil });
                ++ueberschrieben;
            } else {
                fehlerAufgetreten = true;
                break;
            }
        } else {   // anlegen | kopie
            const bool alsKopie = p.aktion == QLatin1String("kopie");
            QSqlQuery i(m_bibliothekDb);
            i.prepare("INSERT INTO bauteil (bezeichnung, uid, ist_system) VALUES (?, ?, 0)");
            i.addBindValue(name);
            i.addBindValue(alsKopie ? QStringLiteral("") : uid);   // Kopie: leer = der Trigger vergibt eine neue lokale UID (NULL wäre unzulässig); sonst Identität des Bündels erhalten
            if (!i.exec()) {
                warnungen << QStringLiteral("%1: konnte nicht angelegt werden (%2)").arg(name, i.lastError().text());
                fehlerAufgetreten = true;
                break;
            }
            const int neuId = i.lastInsertId().toInt();
            if (!bauteilSchreiben(m_bibliothekDb, neuId, p.teil, b.farben, warnungen, alsKopie ? QStringLiteral(" (Import)") : QString())) {
                fehlerAufgetreten = true;
                break;
            }
            fuerQuerverweise.append({ neuId, p.teil });
            alsKopie ? ++kopien : ++angelegt;
        }
    }
    if (!fehlerAufgetreten) {
        for (const auto &qv : fuerQuerverweise)
            querverweiseSchreiben(*this, m_bibliothekDb, qv.first, qv.second, warnungen);
    }
    if (fehlerAufgetreten || !m_bibliothekDb.commit()) {
        m_bibliothekDb.rollback();
        erg["fehler"] = warnungen.isEmpty() ? QStringLiteral("Import fehlgeschlagen – nichts wurde verändert") : warnungen.last();
        erg["warnungen"] = warnungen;
        return erg;
    }
    erg["ok"] = true;
    erg["angelegt"] = angelegt;
    erg["ueberschrieben"] = ueberschrieben;
    erg["verknuepft"] = verknuepft;
    erg["kopien"] = kopien;
    erg["uebersprungen"] = uebersprungen;
    erg["warnungen"] = warnungen;
    return erg;
}
