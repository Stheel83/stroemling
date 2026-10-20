// ============================================================
// Database_Vorlagen.cpp – app-weite Bibliothek der Blattvorlagen (BLATTVORLAGEN-03)
//
// vorlagen.db im App-Datenverzeichnis (projektübergreifend, wie makros.db). Die Projektdatei hält
// immer ihre eigene Kopie der Vorlage (normblatt_vorlage/normblatt_feld); die Bibliothek ist nur
// die Quelle. Verknüpfung über normblatt_vorlage.bibliothek_uid; bibliothek_version/-hash merken den
// Stand beim letzten Abgleich, damit "Bibliothek neuer" und "lokal geändert" unterscheidbar sind.
// Kein stilles Überschreiben: Aktualisieren/Speichern sind ausdrückliche Aktionen.
// ============================================================
#include "Database.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace {

struct VorlagenInhalt {
    QString     name, beschreibung, art, logoMime;
    double      breite = 297, hoehe = 210, rl = 20, rr = 10, ro = 10, ru = 10;
    QByteArray  logo;
    QVariantList felder;   // Schlüssel wie normblattFelderLaden()
};

// Inhalts-Hash: Maße, Art, Logo und alle Felder – nicht Name/Beschreibung (Umbenennen ist keine Änderung).
QString inhaltsHash(const VorlagenInhalt &v)
{
    QByteArray b;
    auto num = [](double d) { return QByteArray::number(d, 'f', 3); };
    b += v.art.toUtf8() + '|' + num(v.breite) + '|' + num(v.hoehe) + '|' + num(v.rl) + '|' + num(v.rr)
       + '|' + num(v.ro) + '|' + num(v.ru) + '|' + QCryptographicHash::hash(v.logo, QCryptographicHash::Sha1).toHex()
       + '|' + v.logoMime.toUtf8() + '\n';
    for (const QVariant &fv : v.felder) {
        const QVariantMap f = fv.toMap();
        b += f.value("feldtyp").toString().toUtf8() + '|' + num(f.value("xMm").toDouble()) + '|'
           + num(f.value("yMm").toDouble()) + '|' + num(f.value("breiteMm").toDouble()) + '|'
           + num(f.value("hoeheMm").toDouble()) + '|' + f.value("label").toString().toUtf8() + '|'
           + f.value("inhalt").toString().toUtf8() + '|' + f.value("quelleSpalte").toString().toUtf8() + '|'
           + num(f.value("schriftgroesse").toDouble()) + '|' + QByteArray::number(f.value("fett").toInt()) + '|'
           + QByteArray::number(f.value("rahmen").toInt()) + '\n';
    }
    return QString::fromLatin1(QCryptographicHash::hash(b, QCryptographicHash::Sha1).toHex());
}

} // namespace

bool Database::openVorlagen(const QString &path)
{
    m_vorlagenPfad = path;
    m_vorlagenDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_vorlagen");
    m_vorlagenDb.setDatabaseName(path);
    if (!m_vorlagenDb.open()) {
        qCWarning(lcDb) << "Vorlagen-DB konnte nicht geöffnet werden:" << m_vorlagenDb.lastError().text();
        return false;
    }
    QSqlQuery q(m_vorlagenDb);
    q.exec("PRAGMA journal_mode = WAL");
    q.exec("PRAGMA busy_timeout = 5000");
    q.exec("PRAGMA foreign_keys = ON");
    const bool ok =
        q.exec(R"(CREATE TABLE IF NOT EXISTS bvorlage (
            id            INTEGER PRIMARY KEY,
            uid           TEXT    NOT NULL UNIQUE,
            name          TEXT    NOT NULL,
            beschreibung  TEXT    DEFAULT '',
            art           TEXT    NOT NULL DEFAULT 'schriftfeld',
            breite_mm     REAL    NOT NULL DEFAULT 297,
            hoehe_mm      REAL    NOT NULL DEFAULT 210,
            rand_links_mm REAL    DEFAULT 20,
            rand_rechts_mm REAL   DEFAULT 10,
            rand_oben_mm  REAL    DEFAULT 10,
            rand_unten_mm REAL    DEFAULT 10,
            logo_data     BLOB,
            logo_mime     TEXT,
            version       INTEGER NOT NULL DEFAULT 1,
            geaendert_am  TEXT    DEFAULT (datetime('now'))
        ))")
        && q.exec(R"(CREATE TABLE IF NOT EXISTS bvorlage_feld (
            id             INTEGER PRIMARY KEY,
            vorlage_id     INTEGER NOT NULL REFERENCES bvorlage(id) ON DELETE CASCADE,
            feldtyp        TEXT NOT NULL DEFAULT 'fest',
            x_mm           REAL NOT NULL DEFAULT 0,
            y_mm           REAL NOT NULL DEFAULT 0,
            breite_mm      REAL NOT NULL DEFAULT 50,
            hoehe_mm       REAL NOT NULL DEFAULT 13,
            label          TEXT,
            inhalt         TEXT,
            quelle_spalte  TEXT,
            schriftgroesse REAL DEFAULT 3.5,
            fett           INTEGER DEFAULT 0,
            rahmen         INTEGER DEFAULT 1,
            reihenfolge    INTEGER DEFAULT 0
        ))");
    if (!ok) {
        qCWarning(lcDb) << "Vorlagen-DB Schema:" << q.lastError().text();
        return false;
    }
    qCInfo(lcDb) << "Vorlagen-DB geöffnet:" << path;
    return true;
}

// ── interne Helfer ───────────────────────────────────────────

// Projektvorlage lesen (Kopf, Felder, Logo). false, wenn nicht vorhanden.
static bool projektVorlageLesen(Database *self, QSqlDatabase &db, int id, VorlagenInhalt &v,
                                QString &uid, int &version, QString &hash)
{
    Q_UNUSED(self);
    QSqlQuery q(db);
    q.prepare("SELECT name, COALESCE(beschreibung,''), art, breite_mm, hoehe_mm, rand_links_mm, rand_rechts_mm, "
              "rand_oben_mm, rand_unten_mm, logo_data, COALESCE(logo_mime,''), COALESCE(bibliothek_uid,''), "
              "COALESCE(bibliothek_version,0), COALESCE(bibliothek_hash,'') FROM normblatt_vorlage WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec() || !q.next()) return false;
    v.name = q.value(0).toString();      v.beschreibung = q.value(1).toString();
    v.art  = q.value(2).toString();
    if (v.art == QLatin1String("infostreifen")) v.art = QStringLiteral("schriftfeld");   // N-03: Streifen ist ein Schriftfeld
    v.breite = q.value(3).toDouble();    v.hoehe = q.value(4).toDouble();
    v.rl = q.value(5).toDouble();        v.rr = q.value(6).toDouble();
    v.ro = q.value(7).toDouble();        v.ru = q.value(8).toDouble();
    v.logo = q.value(9).toByteArray();   v.logoMime = q.value(10).toString();
    uid = q.value(11).toString();        version = q.value(12).toInt();
    hash = q.value(13).toString();
    return true;
}

bool Database::bibliothekVorlageLesen(const QString &uid, QVariantMap &kopf, QVariantList &felder,
                                      QByteArray &logo, QString &logoMime)
{
    QSqlQuery q(m_vorlagenDb);
    q.prepare("SELECT id, name, COALESCE(beschreibung,''), art, breite_mm, hoehe_mm, rand_links_mm, rand_rechts_mm, "
              "rand_oben_mm, rand_unten_mm, logo_data, COALESCE(logo_mime,''), version, COALESCE(geaendert_am,'') "
              "FROM bvorlage WHERE uid = :uid");
    q.bindValue(":uid", uid);
    if (!q.exec() || !q.next()) return false;
    const int id = q.value(0).toInt();
    kopf["name"] = q.value(1); kopf["beschreibung"] = q.value(2); kopf["art"] = q.value(3);
    kopf["breiteMm"] = q.value(4); kopf["hoeheMm"] = q.value(5);
    kopf["randLinksMm"] = q.value(6); kopf["randRechtsMm"] = q.value(7);
    kopf["randObenMm"] = q.value(8); kopf["randUntenMm"] = q.value(9);
    logo = q.value(10).toByteArray(); logoMime = q.value(11).toString();
    kopf["version"] = q.value(12); kopf["geaendertAm"] = q.value(13);
    felder.clear();
    QSqlQuery qf(m_vorlagenDb);
    qf.prepare("SELECT feldtyp, x_mm, y_mm, breite_mm, hoehe_mm, COALESCE(label,''), COALESCE(inhalt,''), "
               "COALESCE(quelle_spalte,''), schriftgroesse, fett, rahmen, reihenfolge "
               "FROM bvorlage_feld WHERE vorlage_id = :v ORDER BY reihenfolge, id");
    qf.bindValue(":v", id);
    if (!qf.exec()) return false;
    while (qf.next()) {
        QVariantMap f;
        f["feldtyp"] = qf.value(0); f["xMm"] = qf.value(1); f["yMm"] = qf.value(2);
        f["breiteMm"] = qf.value(3); f["hoeheMm"] = qf.value(4); f["label"] = qf.value(5);
        f["inhalt"] = qf.value(6); f["quelleSpalte"] = qf.value(7); f["schriftgroesse"] = qf.value(8);
        f["fett"] = qf.value(9); f["rahmen"] = qf.value(10); f["reihenfolge"] = qf.value(11);
        felder << f;
    }
    return true;
}

static VorlagenInhalt inhaltAusBibliothek(const QVariantMap &k, const QVariantList &felder,
                                          const QByteArray &logo, const QString &mime)
{
    VorlagenInhalt v;
    v.art = k.value("art").toString();
    if (v.art == QLatin1String("infostreifen")) v.art = QStringLiteral("schriftfeld");
    v.breite = k.value("breiteMm").toDouble(); v.hoehe = k.value("hoeheMm").toDouble();
    v.rl = k.value("randLinksMm").toDouble();  v.rr = k.value("randRechtsMm").toDouble();
    v.ro = k.value("randObenMm").toDouble();   v.ru = k.value("randUntenMm").toDouble();
    v.logo = logo; v.logoMime = mime; v.felder = felder;
    return v;
}

// ── öffentliche API ──────────────────────────────────────────

QVariantList Database::vorlagenBibliothekListe()
{
    QVariantList res;
    if (!m_vorlagenDb.isOpen()) return res;
    // uid → Projektvorlage (falls schon übernommen)
    QHash<QString, int> imProjekt;
    if (m_projektOffen) {
        QSqlQuery qp(m_db);
        if (qp.exec("SELECT id, bibliothek_uid FROM normblatt_vorlage WHERE bibliothek_uid IS NOT NULL"))
            while (qp.next()) imProjekt.insert(qp.value(1).toString(), qp.value(0).toInt());
    }
    QSqlQuery q(m_vorlagenDb);
    if (!q.exec("SELECT uid, name, COALESCE(beschreibung,''), art, breite_mm, hoehe_mm, version, "
                "COALESCE(geaendert_am,''), (logo_data IS NOT NULL), "
                "(SELECT COUNT(*) FROM bvorlage_feld f WHERE f.vorlage_id = bvorlage.id) "
                "FROM bvorlage ORDER BY art, name COLLATE NOCASE")) {
        qCWarning(lcDb) << "vorlagenBibliothekListe:" << q.lastError().text();
        return res;
    }
    while (q.next()) {
        QVariantMap m;
        m["uid"] = q.value(0); m["name"] = q.value(1); m["beschreibung"] = q.value(2); m["art"] = q.value(3);
        m["breiteMm"] = q.value(4); m["hoeheMm"] = q.value(5); m["version"] = q.value(6);
        m["geaendertAm"] = q.value(7); m["hatLogo"] = q.value(8).toInt() != 0; m["felder"] = q.value(9);
        m["imProjekt"] = imProjekt.value(q.value(0).toString(), 0);
        res << m;
    }
    return res;
}

QString Database::vorlageInBibliothekSpeichern(int vorlageId)
{
    if (!m_vorlagenDb.isOpen() || !m_projektOffen) return {};
    VorlagenInhalt v; QString uid, hash; int version = 0;
    if (!projektVorlageLesen(this, m_db, vorlageId, v, uid, version, hash)) return {};
    v.felder = normblattFelderLaden(vorlageId);

    // Vorhandene Bibliotheksvorlage aktualisieren, sonst neu anlegen
    int bibId = 0, bibVersion = 0;
    if (!uid.isEmpty()) {
        QSqlQuery q(m_vorlagenDb);
        q.prepare("SELECT id, version FROM bvorlage WHERE uid = :u");
        q.bindValue(":u", uid);
        if (q.exec() && q.next()) { bibId = q.value(0).toInt(); bibVersion = q.value(1).toInt(); }
    }
    if (bibId == 0) uid = QUuid::createUuid().toString(QUuid::WithoutBraces);

    if (!m_vorlagenDb.transaction()) return {};
    QSqlQuery q(m_vorlagenDb);
    bool ok;
    if (bibId > 0) {
        q.prepare("UPDATE bvorlage SET name=:n, beschreibung=:b, art=:a, breite_mm=:bm, hoehe_mm=:hm, "
                  "rand_links_mm=:rl, rand_rechts_mm=:rr, rand_oben_mm=:ro, rand_unten_mm=:ru, logo_data=:ld, "
                  "logo_mime=:lm, version=:ver, geaendert_am=datetime('now') WHERE id=:id");
        q.bindValue(":id", bibId);
        q.bindValue(":ver", bibVersion + 1);
    } else {
        q.prepare("INSERT INTO bvorlage (uid, name, beschreibung, art, breite_mm, hoehe_mm, rand_links_mm, "
                  "rand_rechts_mm, rand_oben_mm, rand_unten_mm, logo_data, logo_mime, version) "
                  "VALUES (:uid,:n,:b,:a,:bm,:hm,:rl,:rr,:ro,:ru,:ld,:lm,1)");
        q.bindValue(":uid", uid);
    }
    q.bindValue(":n", v.name); q.bindValue(":b", v.beschreibung); q.bindValue(":a", v.art);
    q.bindValue(":bm", v.breite); q.bindValue(":hm", v.hoehe);
    q.bindValue(":rl", v.rl); q.bindValue(":rr", v.rr); q.bindValue(":ro", v.ro); q.bindValue(":ru", v.ru);
    q.bindValue(":ld", v.logo.isEmpty() ? QVariant(QMetaType(QMetaType::QByteArray)) : QVariant(v.logo));
    q.bindValue(":lm", v.logoMime);
    ok = q.exec();
    const int bid = bibId > 0 ? bibId : q.lastInsertId().toInt();
    if (ok) {
        QSqlQuery qd(m_vorlagenDb);
        qd.prepare("DELETE FROM bvorlage_feld WHERE vorlage_id = :v");
        qd.bindValue(":v", bid);
        ok = qd.exec();
    }
    for (int i = 0; ok && i < v.felder.size(); ++i) {
        const QVariantMap f = v.felder[i].toMap();
        QSqlQuery qi(m_vorlagenDb);
        qi.prepare("INSERT INTO bvorlage_feld (vorlage_id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm, label, inhalt, "
                   "quelle_spalte, schriftgroesse, fett, rahmen, reihenfolge) "
                   "VALUES (:v,:t,:x,:y,:b,:h,:l,:i,:q,:sg,:f,:r,:o)");
        qi.bindValue(":v", bid); qi.bindValue(":t", f.value("feldtyp")); qi.bindValue(":x", f.value("xMm"));
        qi.bindValue(":y", f.value("yMm")); qi.bindValue(":b", f.value("breiteMm")); qi.bindValue(":h", f.value("hoeheMm"));
        qi.bindValue(":l", f.value("label")); qi.bindValue(":i", f.value("inhalt"));
        qi.bindValue(":q", f.value("quelleSpalte")); qi.bindValue(":sg", f.value("schriftgroesse"));
        qi.bindValue(":f", f.value("fett")); qi.bindValue(":r", f.value("rahmen")); qi.bindValue(":o", i);
        ok = qi.exec();
    }
    if (!ok) {
        qCWarning(lcDb) << "vorlageInBibliothekSpeichern:" << q.lastError().text();
        m_vorlagenDb.rollback();
        return {};
    }
    if (!m_vorlagenDb.commit()) return {};

    // Projektseite: Verknüpfung + Abgleichstand merken
    QSqlQuery qp(m_db);
    qp.prepare("UPDATE normblatt_vorlage SET bibliothek_uid=:u, bibliothek_version=:v, bibliothek_hash=:h WHERE id=:id");
    qp.bindValue(":u", uid); qp.bindValue(":v", bibId > 0 ? bibVersion + 1 : 1);
    qp.bindValue(":h", inhaltsHash(v)); qp.bindValue(":id", vorlageId);
    if (!qp.exec()) {
        qCWarning(lcDb) << "vorlageInBibliothekSpeichern (Projekt):" << qp.lastError().text();
        return {};
    }
    return uid;
}

int Database::vorlageAusBibliothekUebernehmen(const QString &uid)
{
    if (!m_vorlagenDb.isOpen() || !m_projektOffen) return -1;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT 1 FROM normblatt_vorlage WHERE bibliothek_uid = :u");
        q.bindValue(":u", uid);
        if (q.exec() && q.next()) {
            qCWarning(lcDb) << "vorlageAusBibliothekUebernehmen: bereits im Projekt, bitte aktualisieren";
            return -1;
        }
    }
    QVariantMap k; QVariantList felder; QByteArray logo; QString mime;
    if (!bibliothekVorlageLesen(uid, k, felder, logo, mime)) return -1;
    const VorlagenInhalt inh = inhaltAusBibliothek(k, felder, logo, mime);

    if (!m_db.transaction()) return -1;
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO normblatt_vorlage (name, beschreibung, ist_standard, breite_mm, hoehe_mm, rand_links_mm, "
              "rand_rechts_mm, rand_oben_mm, rand_unten_mm, art, logo_data, logo_mime, bibliothek_uid, "
              "bibliothek_version, bibliothek_hash) VALUES (:n,:b,0,:bm,:hm,:rl,:rr,:ro,:ru,:a,:ld,:lm,:u,:v,:h)");
    q.bindValue(":n", k.value("name")); q.bindValue(":b", k.value("beschreibung"));
    q.bindValue(":bm", inh.breite); q.bindValue(":hm", inh.hoehe);
    q.bindValue(":rl", inh.rl); q.bindValue(":rr", inh.rr); q.bindValue(":ro", inh.ro); q.bindValue(":ru", inh.ru);
    q.bindValue(":a", inh.art);
    q.bindValue(":ld", logo.isEmpty() ? QVariant(QMetaType(QMetaType::QByteArray)) : QVariant(logo));
    q.bindValue(":lm", mime.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : QVariant(mime));
    q.bindValue(":u", uid); q.bindValue(":v", k.value("version")); q.bindValue(":h", inhaltsHash(inh));
    if (!q.exec()) {
        qCWarning(lcDb) << "vorlageAusBibliothekUebernehmen:" << q.lastError().text();
        m_db.rollback();
        return -1;
    }
    const int vid = q.lastInsertId().toInt();
    if (!normblattFelderSchreiben(vid, felder)) {
        m_db.rollback();
        return -1;
    }
    if (!m_db.commit()) return -1;
    return vid;
}

bool Database::vorlageAusBibliothekAktualisieren(int vorlageId)
{
    if (!m_vorlagenDb.isOpen() || !m_projektOffen) return false;
    VorlagenInhalt lokal; QString uid, hash; int version = 0;
    if (!projektVorlageLesen(this, m_db, vorlageId, lokal, uid, version, hash) || uid.isEmpty()) return false;
    QVariantMap k; QVariantList felder; QByteArray logo; QString mime;
    if (!bibliothekVorlageLesen(uid, k, felder, logo, mime)) return false;
    const VorlagenInhalt inh = inhaltAusBibliothek(k, felder, logo, mime);

    if (!m_db.transaction()) return false;
    QSqlQuery q(m_db);
    // Name bleibt lokal (Umbenennen im Projekt ist erlaubt); alles andere kommt aus der Bibliothek
    q.prepare("UPDATE normblatt_vorlage SET breite_mm=:bm, hoehe_mm=:hm, rand_links_mm=:rl, rand_rechts_mm=:rr, "
              "rand_oben_mm=:ro, rand_unten_mm=:ru, art=:a, logo_data=:ld, logo_mime=:lm, "
              "bibliothek_version=:v, bibliothek_hash=:h WHERE id=:id");
    q.bindValue(":bm", inh.breite); q.bindValue(":hm", inh.hoehe);
    q.bindValue(":rl", inh.rl); q.bindValue(":rr", inh.rr); q.bindValue(":ro", inh.ro); q.bindValue(":ru", inh.ru);
    q.bindValue(":a", inh.art);
    q.bindValue(":ld", logo.isEmpty() ? QVariant(QMetaType(QMetaType::QByteArray)) : QVariant(logo));
    q.bindValue(":lm", mime.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : QVariant(mime));
    q.bindValue(":v", k.value("version")); q.bindValue(":h", inhaltsHash(inh)); q.bindValue(":id", vorlageId);
    if (!q.exec() || !normblattFelderSchreiben(vorlageId, felder)) {
        qCWarning(lcDb) << "vorlageAusBibliothekAktualisieren:" << q.lastError().text();
        m_db.rollback();
        return false;
    }
    return m_db.commit();
}

QVariantMap Database::vorlageBibliothekStatus(int vorlageId)
{
    QVariantMap res{{"status", QStringLiteral("lokal")}};
    if (!m_projektOffen) return res;
    VorlagenInhalt v; QString uid, hash; int version = 0;
    if (!projektVorlageLesen(this, m_db, vorlageId, v, uid, version, hash) || uid.isEmpty()) return res;
    v.felder = normblattFelderLaden(vorlageId);
    const bool lokalGeaendert = inhaltsHash(v) != hash;

    QVariantMap k; QVariantList f; QByteArray logo; QString mime;
    if (!m_vorlagenDb.isOpen() || !bibliothekVorlageLesen(uid, k, f, logo, mime)) {
        res["status"] = QStringLiteral("bibliothekFehlt");
        return res;
    }
    res["bibliothekName"]    = k.value("name");
    res["bibliothekVersion"] = k.value("version");
    res["projektVersion"]    = version;
    const bool bibNeuer = k.value("version").toInt() > version;
    res["status"] = bibNeuer && lokalGeaendert ? "beides"
                  : bibNeuer                   ? "bibliothekNeuer"
                  : lokalGeaendert             ? "lokalGeaendert"
                                               : "aktuell";
    return res;
}

bool Database::vorlageAusBibliothekLoeschen(const QString &uid)
{
    if (!m_vorlagenDb.isOpen()) return false;
    QSqlQuery q(m_vorlagenDb);
    q.prepare("DELETE FROM bvorlage WHERE uid = :u");
    q.bindValue(":u", uid);
    return q.exec() && q.numRowsAffected() > 0;
}

// ============================================================
// Vorlagen-Austausch (S2): JSON-Bündel "stroemling-blattvorlagen"
// Leitlinien wie beim Bauteil-Austausch: uid ist die Identität, nie still überschreiben (erst analysieren, dann
// Entscheidungen), vor dem Import eine Sicherung. Gleichheit über den Inhalts-Hash, nicht über Name/Version.
// ============================================================
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace {

constexpr auto kVorlagenFormat = "stroemling-blattvorlagen";
constexpr int  kVorlagenFormatVersion = 1;

QJsonObject feldAlsJson(const QVariantMap &f)
{
    return QJsonObject {
        { "feldtyp", f.value("feldtyp").toString() }, { "x_mm", f.value("xMm").toDouble() }, { "y_mm", f.value("yMm").toDouble() },
        { "breite_mm", f.value("breiteMm").toDouble() }, { "hoehe_mm", f.value("hoeheMm").toDouble() },
        { "label", f.value("label").toString() }, { "inhalt", f.value("inhalt").toString() },
        { "quelle_spalte", f.value("quelleSpalte").toString() }, { "schriftgroesse", f.value("schriftgroesse").toDouble() },
        { "fett", f.value("fett").toInt() }, { "rahmen", f.value("rahmen").toInt() }, { "reihenfolge", f.value("reihenfolge").toInt() } };
}

QVariantMap feldAusJson(const QJsonObject &o)
{
    return QVariantMap {
        { "feldtyp", o.value("feldtyp").toString(QStringLiteral("fest")) }, { "xMm", o.value("x_mm").toDouble() },
        { "yMm", o.value("y_mm").toDouble() }, { "breiteMm", o.value("breite_mm").toDouble(50) },
        { "hoeheMm", o.value("hoehe_mm").toDouble(13) }, { "label", o.value("label").toString() },
        { "inhalt", o.value("inhalt").toString() }, { "quelleSpalte", o.value("quelle_spalte").toString() },
        { "schriftgroesse", o.value("schriftgroesse").toDouble(3.5) }, { "fett", o.value("fett").toInt() },
        { "rahmen", o.value("rahmen").toInt(1) }, { "reihenfolge", o.value("reihenfolge").toInt() } };
}

VorlagenInhalt inhaltAusJson(const QJsonObject &o)
{
    VorlagenInhalt v;
    v.name = o.value("name").toString();
    v.beschreibung = o.value("beschreibung").toString();
    v.art = o.value("art").toString(QStringLiteral("schriftfeld"));
    if (v.art == QLatin1String("infostreifen")) v.art = QStringLiteral("schriftfeld");
    v.breite = o.value("breite_mm").toDouble(297); v.hoehe = o.value("hoehe_mm").toDouble(210);
    v.rl = o.value("rand_links_mm").toDouble(20);   v.rr = o.value("rand_rechts_mm").toDouble(10);
    v.ro = o.value("rand_oben_mm").toDouble(10);    v.ru = o.value("rand_unten_mm").toDouble(10);
    v.logoMime = o.value("logo_mime").toString();
    v.logo = QByteArray::fromBase64(o.value("logo_base64").toString().toLatin1());
    const QJsonArray fa = o.value("felder").toArray();
    for (const QJsonValue &fv : fa) v.felder << feldAusJson(fv.toObject());
    return v;
}

// Bündel lesen und prüfen. Rückgabe: Fehlertext (leer = ok), *root gefüllt.
QString vorlagenBuendelLesen(const QString &pfad, QJsonObject *root)
{
    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly)) return QStringLiteral("Datei nicht lesbar: %1").arg(f.errorString());
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return QStringLiteral("Keine gültige JSON-Datei (%1).").arg(err.errorString());
    *root = doc.object();
    if (root->value("format").toString() != QLatin1String(kVorlagenFormat))
        return QStringLiteral("Kein Blattvorlagen-Bündel (Format „%1“ erwartet).").arg(kVorlagenFormat);
    if (root->value("format_version").toInt() != kVorlagenFormatVersion)
        return QStringLiteral("Dieses Bündel hat ein Format (Version %1), das diese Version nicht kennt.").arg(root->value("format_version").toInt());
    if (!root->value("vorlagen").isArray()) return QStringLiteral("Das Bündel enthält keine Vorlagenliste.");
    return {};
}

} // namespace

QString Database::vorlagenSichern(const QString &anlass)
{
    if (!m_vorlagenDb.isOpen()) return {};
    const QString ordner = QFileInfo(m_vorlagenPfad).absolutePath() + QStringLiteral("/backups");
    QDir().mkpath(ordner);
    const QString ziel = ordner + QStringLiteral("/vorlagen_%1_%2.db").arg(anlass,
                             QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss_zzz")));
    QString maskiert = ziel;
    maskiert.replace(QLatin1Char('\''), QStringLiteral("''"));
    QSqlQuery q(m_vorlagenDb);
    if (QFileInfo::exists(ziel) || !q.exec(QStringLiteral("VACUUM INTO '%1'").arg(maskiert))) {
        qCWarning(lcDb) << "Vorlagen-Sicherung nicht angelegt:" << q.lastError().text() << ziel;
        return {};
    }
    return ziel;
}

QVariantMap Database::vorlagenExportieren(const QString &pfad, const QStringList &uids)
{
    QVariantMap erg { { "ok", false }, { "anzahl", 0 } };
    if (!m_vorlagenDb.isOpen()) { erg["fehler"] = QStringLiteral("Die Vorlagen-Bibliothek ist nicht verfügbar."); return erg; }
    if (pfad.trimmed().isEmpty()) { erg["fehler"] = QStringLiteral("Kein Zielpfad angegeben."); return erg; }
    if (QFileInfo::exists(pfad)) { erg["fehler"] = QStringLiteral("Die Datei existiert bereits – bitte einen anderen Namen wählen."); return erg; }

    QStringList alle;
    {
        QSqlQuery q(m_vorlagenDb);
        if (q.exec("SELECT uid FROM bvorlage ORDER BY art, name COLLATE NOCASE"))
            while (q.next()) alle << q.value(0).toString();
    }
    const QStringList auswahl = uids.isEmpty() ? alle : uids;
    QJsonArray arr;
    for (const QString &uid : auswahl) {
        QVariantMap k; QVariantList felder; QByteArray logo; QString mime;
        if (!bibliothekVorlageLesen(uid, k, felder, logo, mime)) continue;
        QJsonArray fa;
        for (const QVariant &f : felder) fa.append(feldAlsJson(f.toMap()));
        QJsonObject o {
            { "uid", uid }, { "name", k.value("name").toString() }, { "beschreibung", k.value("beschreibung").toString() },
            { "art", k.value("art").toString() }, { "breite_mm", k.value("breiteMm").toDouble() }, { "hoehe_mm", k.value("hoeheMm").toDouble() },
            { "rand_links_mm", k.value("randLinksMm").toDouble() }, { "rand_rechts_mm", k.value("randRechtsMm").toDouble() },
            { "rand_oben_mm", k.value("randObenMm").toDouble() }, { "rand_unten_mm", k.value("randUntenMm").toDouble() },
            { "version", k.value("version").toInt() }, { "geaendert_am", k.value("geaendertAm").toString() },
            { "logo_mime", mime }, { "logo_base64", QString::fromLatin1(logo.toBase64()) }, { "felder", fa } };
        arr.append(o);
    }
    if (arr.isEmpty()) { erg["fehler"] = QStringLiteral("Es gibt keine Vorlagen zum Exportieren."); return erg; }
    const QJsonObject root {
        { "format", QString::fromLatin1(kVorlagenFormat) }, { "format_version", kVorlagenFormatVersion },
        { "exportiert_am", QDateTime::currentDateTimeUtc().toString(Qt::ISODate) }, { "vorlagen", arr } };
    QSaveFile f(pfad);
    if (!f.open(QIODevice::WriteOnly)) { erg["fehler"] = QStringLiteral("Datei nicht schreibbar: %1").arg(f.errorString()); return erg; }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!f.commit()) { erg["fehler"] = QStringLiteral("Schreiben fehlgeschlagen: %1").arg(f.errorString()); return erg; }
    erg["ok"] = true;
    erg["anzahl"] = int(arr.size());
    return erg;
}

QVariantMap Database::vorlagenImportAnalysieren(const QString &pfad)
{
    QVariantMap erg { { "ok", false } };
    if (!m_vorlagenDb.isOpen()) { erg["fehler"] = QStringLiteral("Die Vorlagen-Bibliothek ist nicht verfügbar."); return erg; }
    QJsonObject root;
    if (const QString f = vorlagenBuendelLesen(pfad, &root); !f.isEmpty()) { erg["fehler"] = f; return erg; }

    QVariantList eintraege;
    int neu = 0, gleich = 0, abweichend = 0;
    QSet<QString> gesehen;
    for (const QJsonValue &v : root.value("vorlagen").toArray()) {
        const QJsonObject o = v.toObject();
        const QString uid = o.value("uid").toString().trimmed();
        if (uid.isEmpty() || gesehen.contains(uid)) continue;
        gesehen.insert(uid);
        const VorlagenInhalt inh = inhaltAusJson(o);
        QVariantMap e { { "uid", uid }, { "name", inh.name }, { "art", inh.art }, { "bundleVersion", o.value("version").toInt() },
                        { "felder", int(inh.felder.size()) } };
        QVariantMap k; QVariantList felder; QByteArray logo; QString mime;
        if (!bibliothekVorlageLesen(uid, k, felder, logo, mime)) {
            e["status"] = QStringLiteral("neu");
            e["vorschlag"] = QStringLiteral("anlegen");
            e["aktionen"] = QStringList { "anlegen", "ueberspringen" };
            ++neu;
        } else {
            const VorlagenInhalt lokal = inhaltAusBibliothek(k, felder, logo, mime);
            e["lokaleVersion"] = k.value("version").toInt();
            e["lokalerName"] = k.value("name").toString();
            if (inhaltsHash(lokal) == inhaltsHash(inh)) {
                e["status"] = QStringLiteral("gleich");
                e["vorschlag"] = QStringLiteral("ueberspringen");
                e["aktionen"] = QStringList { "ueberspringen" };
                ++gleich;
            } else {
                e["status"] = QStringLiteral("abweichend");
                // Neuere Bündelversion: ersetzen ist naheliegend; sonst nicht still überschreiben
                e["vorschlag"] = o.value("version").toInt() > k.value("version").toInt() ? QStringLiteral("ersetzen") : QStringLiteral("ueberspringen");
                e["aktionen"] = QStringList { "ersetzen", "kopie", "ueberspringen" };
                ++abweichend;
            }
        }
        eintraege << e;
    }
    if (eintraege.isEmpty()) { erg["fehler"] = QStringLiteral("Das Bündel enthält keine Vorlagen."); return erg; }
    erg["ok"] = true;
    erg["eintraege"] = eintraege;
    erg["anzahlNeu"] = neu; erg["anzahlGleich"] = gleich; erg["anzahlAbweichend"] = abweichend;
    return erg;
}

QVariantMap Database::vorlagenImportAusfuehren(const QString &pfad, const QVariantMap &entscheidungen)
{
    QVariantMap erg { { "ok", false } };
    const QVariantMap analyse = vorlagenImportAnalysieren(pfad);
    if (!analyse.value("ok").toBool()) { erg["fehler"] = analyse.value("fehler"); return erg; }
    QJsonObject root;
    vorlagenBuendelLesen(pfad, &root);
    QHash<QString, QJsonObject> nachUid;
    for (const QJsonValue &v : root.value("vorlagen").toArray()) nachUid.insert(v.toObject().value("uid").toString().trimmed(), v.toObject());

    erg["sicherung"] = vorlagenSichern(QStringLiteral("vor_import"));
    if (!m_vorlagenDb.transaction()) { erg["fehler"] = QStringLiteral("Transaktion konnte nicht gestartet werden."); return erg; }
    int angelegt = 0, ersetzt = 0, kopien = 0, uebersprungen = 0;
    bool fehler = false;

    // Schreibt eine Vorlage (neu mit uid, oder ersetzt die bestehende); Version wie angegeben
    const auto schreiben = [&](const QString &uid, const VorlagenInhalt &v, int version, bool neuAnlegen) {
        QSqlQuery q(m_vorlagenDb);
        if (neuAnlegen) {
            q.prepare("INSERT INTO bvorlage (uid, name, beschreibung, art, breite_mm, hoehe_mm, rand_links_mm, rand_rechts_mm, "
                      "rand_oben_mm, rand_unten_mm, logo_data, logo_mime, version) VALUES (:uid,:n,:b,:a,:bm,:hm,:rl,:rr,:ro,:ru,:ld,:lm,:ver)");
            q.bindValue(":uid", uid);
        } else {
            q.prepare("UPDATE bvorlage SET name=:n, beschreibung=:b, art=:a, breite_mm=:bm, hoehe_mm=:hm, rand_links_mm=:rl, "
                      "rand_rechts_mm=:rr, rand_oben_mm=:ro, rand_unten_mm=:ru, logo_data=:ld, logo_mime=:lm, version=:ver, "
                      "geaendert_am=datetime('now') WHERE uid=:uid");
            q.bindValue(":uid", uid);
        }
        q.bindValue(":n", v.name); q.bindValue(":b", v.beschreibung); q.bindValue(":a", v.art);
        q.bindValue(":bm", v.breite); q.bindValue(":hm", v.hoehe);
        q.bindValue(":rl", v.rl); q.bindValue(":rr", v.rr); q.bindValue(":ro", v.ro); q.bindValue(":ru", v.ru);
        q.bindValue(":ld", v.logo.isEmpty() ? QVariant(QMetaType(QMetaType::QByteArray)) : QVariant(v.logo));
        q.bindValue(":lm", v.logoMime); q.bindValue(":ver", version);
        if (!q.exec()) { qCWarning(lcDb) << "vorlagenImport:" << q.lastError().text(); return false; }
        QSqlQuery sel(m_vorlagenDb);
        sel.prepare("SELECT id FROM bvorlage WHERE uid = :u");
        sel.bindValue(":u", uid);
        if (!sel.exec() || !sel.next()) return false;
        const int bid = sel.value(0).toInt();
        QSqlQuery qd(m_vorlagenDb);
        qd.prepare("DELETE FROM bvorlage_feld WHERE vorlage_id = :v");
        qd.bindValue(":v", bid);
        if (!qd.exec()) return false;
        for (int i = 0; i < v.felder.size(); ++i) {
            const QVariantMap f = v.felder[i].toMap();
            QSqlQuery qi(m_vorlagenDb);
            qi.prepare("INSERT INTO bvorlage_feld (vorlage_id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm, label, inhalt, "
                       "quelle_spalte, schriftgroesse, fett, rahmen, reihenfolge) VALUES (:v,:t,:x,:y,:b,:h,:l,:i,:q,:sg,:f,:r,:o)");
            qi.bindValue(":v", bid); qi.bindValue(":t", f.value("feldtyp")); qi.bindValue(":x", f.value("xMm"));
            qi.bindValue(":y", f.value("yMm")); qi.bindValue(":b", f.value("breiteMm")); qi.bindValue(":h", f.value("hoeheMm"));
            qi.bindValue(":l", f.value("label")); qi.bindValue(":i", f.value("inhalt"));
            qi.bindValue(":q", f.value("quelleSpalte")); qi.bindValue(":sg", f.value("schriftgroesse"));
            qi.bindValue(":f", f.value("fett")); qi.bindValue(":r", f.value("rahmen")); qi.bindValue(":o", i);
            if (!qi.exec()) return false;
        }
        return true;
    };

    for (const QVariant &ev : analyse.value("eintraege").toList()) {
        const QVariantMap e = ev.toMap();
        const QString uid = e.value("uid").toString();
        QString aktion = entscheidungen.value(uid, e.value("vorschlag")).toString();
        if (!e.value("aktionen").toStringList().contains(aktion)) aktion = QStringLiteral("ueberspringen");
        const VorlagenInhalt inh = inhaltAusJson(nachUid.value(uid));
        bool ok = true;
        if (aktion == QLatin1String("anlegen")) {
            ok = schreiben(uid, inh, qMax(1, e.value("bundleVersion").toInt()), true);
            ++angelegt;
        } else if (aktion == QLatin1String("ersetzen")) {
            ok = schreiben(uid, inh, qMax(e.value("lokaleVersion").toInt(), e.value("bundleVersion").toInt()) + 1, false);
            ++ersetzt;
        } else if (aktion == QLatin1String("kopie")) {
            VorlagenInhalt k = inh;
            k.name = inh.name + QStringLiteral(" (Import)");
            ok = schreiben(QUuid::createUuid().toString(QUuid::WithoutBraces), k, 1, true);
            ++kopien;
        } else {
            ++uebersprungen;
        }
        if (!ok) { fehler = true; break; }
    }
    if (fehler) {
        m_vorlagenDb.rollback();
        erg["fehler"] = QStringLiteral("Der Import ist fehlgeschlagen; es wurde nichts verändert.");
        return erg;
    }
    if (!m_vorlagenDb.commit()) { erg["fehler"] = QStringLiteral("Der Import konnte nicht abgeschlossen werden."); return erg; }
    erg["ok"] = true;
    erg["angelegt"] = angelegt; erg["ersetzt"] = ersetzt; erg["kopien"] = kopien; erg["uebersprungen"] = uebersprungen;
    return erg;
}
