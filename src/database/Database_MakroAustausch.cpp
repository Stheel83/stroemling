// ============================================================
// Database_MakroAustausch.cpp – Austausch der Makro-Bibliothek als JSON-Bündel "stroemling-makros" (S3)
//
// Gleiche Leitlinien wie beim Bauteil- und Vorlagen-Austausch: die uid (makro.uid) ist die Identität, nie still überschreiben
// (erst analysieren, dann Entscheidungen), vor dem Import eine Sicherung der makros.db, alles in einer Transaktion.
// Gleichheit über einen Inhalts-Hash (Name, Beschreibung, Kategorie, Kastengröße und alle Elemente), nicht über die Version.
// ============================================================
#include "Database.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace {

constexpr auto kFormat = "stroemling-makros";
constexpr int  kFormatVersion = 1;

// Spalten von makro_element in fester Reihenfolge (ohne id/makro_id)
const QStringList kElementSpalten = {
    "typ", "rel_x1", "rel_y1", "rel_x2", "rel_y2", "extra_daten", "symbol_key", "sortierung", "rotation", "spiegel_x", "spiegel_y",
    "strich_farbe", "strich_breite", "strich_art", "fuell", "fuell_farbe", "fuell_opazitaet", "opazitaet", "ecken_radius" };

struct MakroInhalt {
    QString     uid, name, beschreibung, kategorie;
    double      breite = 100, hoehe = 100;
    int         version = 1;
    QJsonArray  elemente;     // je Element ein QJsonObject mit kElementSpalten
};

QString inhaltsHash(const MakroInhalt &m)
{
    QByteArray b = m.name.toUtf8() + '|' + m.beschreibung.toUtf8() + '|' + m.kategorie.toUtf8() + '|'
                   + QByteArray::number(m.breite, 'f', 3) + '|' + QByteArray::number(m.hoehe, 'f', 3) + '\n';
    for (const QJsonValue &e : m.elemente)
        b += QJsonDocument(e.toObject()).toJson(QJsonDocument::Compact) + '\n';   // Objekt-Schlüssel sind sortiert → deterministisch
    return QString::fromLatin1(QCryptographicHash::hash(b, QCryptographicHash::Sha1).toHex());
}

QJsonObject elementAusQuery(const QSqlQuery &q, int ab)
{
    QJsonObject o;
    for (int i = 0; i < kElementSpalten.size(); ++i) {
        const QVariant v = q.value(ab + i);
        o.insert(kElementSpalten.at(i), v.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue::fromVariant(v));
    }
    return o;
}

bool makroLesen(QSqlDatabase &db, const QString &uid, MakroInhalt &m)
{
    QSqlQuery q(db);
    q.prepare("SELECT id, uid, name, COALESCE(beschreibung,''), COALESCE(kategorie,''), kasten_breite, kasten_hoehe, version "
              "FROM makro WHERE uid = :u");
    q.bindValue(":u", uid);
    if (!q.exec() || !q.next()) return false;
    const int id = q.value(0).toInt();
    m.uid = q.value(1).toString(); m.name = q.value(2).toString(); m.beschreibung = q.value(3).toString();
    m.kategorie = q.value(4).toString(); m.breite = q.value(5).toDouble(); m.hoehe = q.value(6).toDouble();
    m.version = q.value(7).toInt();
    QSqlQuery qe(db);
    qe.prepare(QStringLiteral("SELECT %1 FROM makro_element WHERE makro_id = :m ORDER BY sortierung, id").arg(kElementSpalten.join(", ")));
    qe.bindValue(":m", id);
    if (!qe.exec()) return false;
    while (qe.next()) m.elemente.append(elementAusQuery(qe, 0));
    return true;
}

MakroInhalt inhaltAusJson(const QJsonObject &o)
{
    MakroInhalt m;
    m.uid = o.value("uid").toString().trimmed();
    m.name = o.value("name").toString();
    m.beschreibung = o.value("beschreibung").toString();
    m.kategorie = o.value("kategorie").toString();
    m.breite = o.value("kasten_breite").toDouble(100);
    m.hoehe = o.value("kasten_hoehe").toDouble(100);
    m.version = o.value("version").toInt(1);
    m.elemente = o.value("elemente").toArray();
    return m;
}

QString buendelLesen(const QString &pfad, QJsonObject *root)
{
    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly)) return QStringLiteral("Datei nicht lesbar: %1").arg(f.errorString());
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return QStringLiteral("Keine gültige JSON-Datei (%1).").arg(err.errorString());
    *root = doc.object();
    if (root->value("format").toString() != QLatin1String(kFormat))
        return QStringLiteral("Kein Makro-Bündel (Format „%1“ erwartet).").arg(kFormat);
    if (root->value("format_version").toInt() != kFormatVersion)
        return QStringLiteral("Dieses Bündel hat ein Format (Version %1), das diese Version nicht kennt.").arg(root->value("format_version").toInt());
    if (!root->value("makros").isArray()) return QStringLiteral("Das Bündel enthält keine Makroliste.");
    return {};
}

} // namespace

QString Database::makrosSichern(const QString &anlass)
{
    if (!m_makroDb.isOpen()) return {};
    const QString ordner = QFileInfo(m_makroPfad).absolutePath() + QStringLiteral("/backups");
    QDir().mkpath(ordner);
    const QString ziel = ordner + QStringLiteral("/makros_%1_%2.db").arg(anlass,
                             QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss_zzz")));
    QString maskiert = ziel;
    maskiert.replace(QLatin1Char('\''), QStringLiteral("''"));
    QSqlQuery q(m_makroDb);
    if (QFileInfo::exists(ziel) || !q.exec(QStringLiteral("VACUUM INTO '%1'").arg(maskiert))) {
        qCWarning(lcDb) << "Makro-Sicherung nicht angelegt:" << q.lastError().text() << ziel;
        return {};
    }
    return ziel;
}

QVariantMap Database::makrosExportieren(const QString &pfad, const QStringList &uids)
{
    QVariantMap erg { { "ok", false }, { "anzahl", 0 } };
    if (!m_makroDb.isOpen()) { erg["fehler"] = QStringLiteral("Die Makro-Bibliothek ist nicht verfügbar."); return erg; }
    if (pfad.trimmed().isEmpty()) { erg["fehler"] = QStringLiteral("Kein Zielpfad angegeben."); return erg; }
    if (QFileInfo::exists(pfad)) { erg["fehler"] = QStringLiteral("Die Datei existiert bereits – bitte einen anderen Namen wählen."); return erg; }

    QStringList alle;
    {
        QSqlQuery q(m_makroDb);
        if (q.exec("SELECT uid FROM makro ORDER BY kategorie, name COLLATE NOCASE"))
            while (q.next()) alle << q.value(0).toString();
    }
    const QStringList auswahl = uids.isEmpty() ? alle : uids;
    QJsonArray arr;
    for (const QString &uid : auswahl) {
        MakroInhalt m;
        if (!makroLesen(m_makroDb, uid, m)) continue;
        arr.append(QJsonObject { { "uid", m.uid }, { "name", m.name }, { "beschreibung", m.beschreibung }, { "kategorie", m.kategorie },
                                 { "kasten_breite", m.breite }, { "kasten_hoehe", m.hoehe }, { "version", m.version },
                                 { "elemente", m.elemente } });
    }
    if (arr.isEmpty()) { erg["fehler"] = QStringLiteral("Es gibt keine Makros zum Exportieren."); return erg; }
    const QJsonObject root { { "format", QString::fromLatin1(kFormat) }, { "format_version", kFormatVersion },
                             { "exportiert_am", QDateTime::currentDateTimeUtc().toString(Qt::ISODate) }, { "makros", arr } };
    QSaveFile f(pfad);
    if (!f.open(QIODevice::WriteOnly)) { erg["fehler"] = QStringLiteral("Datei nicht schreibbar: %1").arg(f.errorString()); return erg; }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!f.commit()) { erg["fehler"] = QStringLiteral("Schreiben fehlgeschlagen: %1").arg(f.errorString()); return erg; }
    erg["ok"] = true;
    erg["anzahl"] = int(arr.size());
    return erg;
}

QVariantMap Database::makrosImportAnalysieren(const QString &pfad)
{
    QVariantMap erg { { "ok", false } };
    if (!m_makroDb.isOpen()) { erg["fehler"] = QStringLiteral("Die Makro-Bibliothek ist nicht verfügbar."); return erg; }
    QJsonObject root;
    if (const QString f = buendelLesen(pfad, &root); !f.isEmpty()) { erg["fehler"] = f; return erg; }

    QVariantList eintraege;
    int neu = 0, gleich = 0, abweichend = 0;
    QSet<QString> gesehen;
    for (const QJsonValue &v : root.value("makros").toArray()) {
        const MakroInhalt inh = inhaltAusJson(v.toObject());
        if (inh.uid.isEmpty() || gesehen.contains(inh.uid)) continue;
        gesehen.insert(inh.uid);
        QVariantMap e { { "uid", inh.uid }, { "name", inh.name }, { "art", inh.kategorie }, { "bundleVersion", inh.version },
                        { "elemente", int(inh.elemente.size()) } };
        MakroInhalt lokal;
        if (!makroLesen(m_makroDb, inh.uid, lokal)) {
            e["status"] = QStringLiteral("neu");
            e["vorschlag"] = QStringLiteral("anlegen");
            e["aktionen"] = QStringList { "anlegen", "ueberspringen" };
            ++neu;
        } else {
            e["lokaleVersion"] = lokal.version;
            e["lokalerName"] = lokal.name;
            if (inhaltsHash(lokal) == inhaltsHash(inh)) {
                e["status"] = QStringLiteral("gleich");
                e["vorschlag"] = QStringLiteral("ueberspringen");
                e["aktionen"] = QStringList { "ueberspringen" };
                ++gleich;
            } else {
                e["status"] = QStringLiteral("abweichend");
                e["vorschlag"] = inh.version > lokal.version ? QStringLiteral("ersetzen") : QStringLiteral("ueberspringen");
                e["aktionen"] = QStringList { "ersetzen", "kopie", "ueberspringen" };
                ++abweichend;
            }
        }
        eintraege << e;
    }
    if (eintraege.isEmpty()) { erg["fehler"] = QStringLiteral("Das Bündel enthält keine Makros."); return erg; }
    erg["ok"] = true;
    erg["eintraege"] = eintraege;
    erg["anzahlNeu"] = neu; erg["anzahlGleich"] = gleich; erg["anzahlAbweichend"] = abweichend;
    return erg;
}

QVariantMap Database::makrosImportAusfuehren(const QString &pfad, const QVariantMap &entscheidungen)
{
    QVariantMap erg { { "ok", false } };
    const QVariantMap analyse = makrosImportAnalysieren(pfad);
    if (!analyse.value("ok").toBool()) { erg["fehler"] = analyse.value("fehler"); return erg; }
    QJsonObject root;
    buendelLesen(pfad, &root);
    QHash<QString, QJsonObject> nachUid;
    for (const QJsonValue &v : root.value("makros").toArray()) nachUid.insert(v.toObject().value("uid").toString().trimmed(), v.toObject());

    erg["sicherung"] = makrosSichern(QStringLiteral("vor_import"));
    if (!m_makroDb.transaction()) { erg["fehler"] = QStringLiteral("Transaktion konnte nicht gestartet werden."); return erg; }
    int angelegt = 0, ersetzt = 0, kopien = 0, uebersprungen = 0;
    bool fehler = false;

    const auto schreiben = [&](const QString &uid, const MakroInhalt &m, int version, bool neuAnlegen) {
        QSqlQuery q(m_makroDb);
        if (neuAnlegen) {
            q.prepare("INSERT INTO makro (uid, name, beschreibung, kategorie, kasten_breite, kasten_hoehe, version, geaendert_am) "
                      "VALUES (:uid,:n,:b,:k,:w,:h,:v,datetime('now'))");
        } else {
            q.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k, kasten_breite=:w, kasten_hoehe=:h, version=:v, "
                      "geaendert_am=datetime('now') WHERE uid=:uid");
        }
        q.bindValue(":uid", uid); q.bindValue(":n", m.name); q.bindValue(":b", m.beschreibung); q.bindValue(":k", m.kategorie);
        q.bindValue(":w", m.breite); q.bindValue(":h", m.hoehe); q.bindValue(":v", version);
        if (!q.exec()) { qCWarning(lcDb) << "makrosImport:" << q.lastError().text(); return false; }
        QSqlQuery sel(m_makroDb);
        sel.prepare("SELECT id FROM makro WHERE uid = :u");
        sel.bindValue(":u", uid);
        if (!sel.exec() || !sel.next()) return false;
        const int mid = sel.value(0).toInt();
        QSqlQuery qd(m_makroDb);
        qd.prepare("DELETE FROM makro_element WHERE makro_id = :m");
        qd.bindValue(":m", mid);
        if (!qd.exec()) return false;
        QStringList platz;
        for (int i = 0; i < kElementSpalten.size(); ++i) platz << QStringLiteral(":c%1").arg(i);
        const QString sql = QStringLiteral("INSERT INTO makro_element (makro_id, %1) VALUES (:mid, %2)").arg(kElementSpalten.join(", "), platz.join(", "));
        for (const QJsonValue &ev : m.elemente) {
            const QJsonObject eo = ev.toObject();
            QSqlQuery qi(m_makroDb);
            qi.prepare(sql);
            qi.bindValue(":mid", mid);
            for (int i = 0; i < kElementSpalten.size(); ++i) {
                const QJsonValue jv = eo.value(kElementSpalten.at(i));
                qi.bindValue(platz.at(i), jv.isNull() || jv.isUndefined() ? QVariant() : jv.toVariant());
            }
            if (!qi.exec()) { qCWarning(lcDb) << "makrosImport Element:" << qi.lastError().text(); return false; }
        }
        return true;
    };

    for (const QVariant &ev : analyse.value("eintraege").toList()) {
        const QVariantMap e = ev.toMap();
        const QString uid = e.value("uid").toString();
        QString aktion = entscheidungen.value(uid, e.value("vorschlag")).toString();
        if (!e.value("aktionen").toStringList().contains(aktion)) aktion = QStringLiteral("ueberspringen");
        const MakroInhalt inh = inhaltAusJson(nachUid.value(uid));
        bool ok = true;
        if (aktion == QLatin1String("anlegen")) {
            ok = schreiben(uid, inh, qMax(1, inh.version), true);
            ++angelegt;
        } else if (aktion == QLatin1String("ersetzen")) {
            ok = schreiben(uid, inh, qMax(e.value("lokaleVersion").toInt(), inh.version) + 1, false);
            ++ersetzt;
        } else if (aktion == QLatin1String("kopie")) {
            MakroInhalt k = inh;
            k.name = inh.name + QStringLiteral(" (Import)");
            ok = schreiben(QUuid::createUuid().toString(QUuid::WithoutBraces), k, 1, true);
            ++kopien;
        } else {
            ++uebersprungen;
        }
        if (!ok) { fehler = true; break; }
    }
    if (fehler) {
        m_makroDb.rollback();
        erg["fehler"] = QStringLiteral("Der Import ist fehlgeschlagen; es wurde nichts verändert.");
        return erg;
    }
    if (!m_makroDb.commit()) { erg["fehler"] = QStringLiteral("Der Import konnte nicht abgeschlossen werden."); return erg; }
    erg["ok"] = true;
    erg["angelegt"] = angelegt; erg["ersetzt"] = ersetzt; erg["kopien"] = kopien; erg["uebersprungen"] = uebersprungen;
    return erg;
}
