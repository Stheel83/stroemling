#include "Database.h"
#include "Database_CsvHelfer.h"
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

QVariantList Database::spsRackListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, rack_nr, system_typ, bezeichnung, beschreibung, hersteller, sortierung "
              "FROM sps_rack WHERE projekt_id = :pid ORDER BY sortierung, rack_nr");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "spsRackListe:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0).toInt();
        m["rack_nr"]      = q.value(1).toInt();
        m["system_typ"]   = q.value(2).toString();
        m["bezeichnung"]  = q.value(3).toString();
        m["beschreibung"] = q.value(4).toString();
        m["hersteller"]   = q.value(5).toString();
        m["sortierung"]   = q.value(6).toInt();
        result.append(m);
    }
    return result;
}

int Database::spsRackAnlegen(int projektId, int rackNr, const QString &systemTyp,
                              const QString &bezeichnung, const QString &hersteller)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO sps_rack (projekt_id, rack_nr, system_typ, bezeichnung, hersteller) "
              "VALUES (:pid, :nr, :typ, :bez, :her)");
    q.bindValue(":pid", projektId);
    q.bindValue(":nr",  rackNr);
    q.bindValue(":typ", systemTyp);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":her", hersteller);
    if (!q.exec()) { qCWarning(lcDb) << "spsRackAnlegen:" << q.lastError().text(); return -1; }
    return q.lastInsertId().toInt();
}

bool Database::spsRackAktualisieren(int id, int rackNr, const QString &systemTyp,
                                     const QString &bezeichnung, const QString &beschreibung,
                                     const QString &hersteller)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sps_rack SET rack_nr=:nr, system_typ=:typ, bezeichnung=:bez, "
              "beschreibung=:desc, hersteller=:her WHERE id=:id");
    q.bindValue(":nr",   rackNr);
    q.bindValue(":typ",  systemTyp);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":desc", beschreibung);
    q.bindValue(":her",  hersteller);
    q.bindValue(":id",   id);
    if (!q.exec()) { qCWarning(lcDb) << "spsRackAktualisieren:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsRackLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM sps_rack WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) { qCWarning(lcDb) << "spsRackLoeschen:" << q.lastError().text(); return false; }
    return true;
}

// --- Baugruppe ---

QVariantList Database::spsBaugruppeListe(int rackId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT b.id, b.rack_id, b.slot, b.typ, b.bezeichnung, b.artikel_nr, b.kanaele, "
              "b.datentyp_standard, b.adress_byte_start, b.kommentar, b.betriebsmittel_id, "
              "bm.betriebsmittel_kz "
              "FROM sps_baugruppe b LEFT JOIN betriebsmittel bm ON bm.id = b.betriebsmittel_id "
              "WHERE b.rack_id = :rid ORDER BY b.slot");
    q.bindValue(":rid", rackId);
    if (!q.exec()) { qCWarning(lcDb) << "spsBaugruppeListe:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap m;
        m["id"]                = q.value(0).toInt();
        m["rack_id"]           = q.value(1).toInt();
        m["slot"]              = q.value(2).toInt();
        m["typ"]               = q.value(3).toString();
        m["bezeichnung"]       = q.value(4).toString();
        m["artikel_nr"]        = q.value(5).toString();
        m["kanaele"]           = q.value(6).toInt();
        m["datentyp_standard"] = q.value(7).toString();
        m["adress_byte_start"] = q.value(8).toInt();
        m["kommentar"]         = q.value(9).toString();
        m["betriebsmittel_id"] = q.value(10).isNull() ? 0 : q.value(10).toInt();
        m["betriebsmittel_kz"] = q.value(11).toString();
        result.append(m);
    }
    return result;
}

int Database::spsBaugruppeAnlegen(int rackId, int slot, const QString &typ,
                                   const QString &bezeichnung, int kanaele, int adressByteStart)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO sps_baugruppe (rack_id, slot, typ, bezeichnung, kanaele, adress_byte_start) "
              "VALUES (:rid, :slot, :typ, :bez, :kan, :abs)");
    q.bindValue(":rid",  rackId);
    q.bindValue(":slot", slot);
    q.bindValue(":typ",  typ);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":kan",  kanaele);
    q.bindValue(":abs",  adressByteStart);
    if (!q.exec()) { qCWarning(lcDb) << "spsBaugruppeAnlegen:" << q.lastError().text(); return -1; }
    return q.lastInsertId().toInt();
}

bool Database::spsBaugruppeAktualisieren(int id, int slot, const QString &typ,
                                          const QString &bezeichnung, const QString &artikelNr,
                                          int kanaele, const QString &datentypStandard,
                                          int adressByteStart, const QString &kommentar)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sps_baugruppe SET slot=:slot, typ=:typ, bezeichnung=:bez, artikel_nr=:art, "
              "kanaele=:kan, datentyp_standard=:dts, adress_byte_start=:abs, kommentar=:kom "
              "WHERE id=:id");
    q.bindValue(":slot", slot);
    q.bindValue(":typ",  typ);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":art",  artikelNr);
    q.bindValue(":kan",  kanaele);
    q.bindValue(":dts",  datentypStandard);
    q.bindValue(":abs",  adressByteStart);
    q.bindValue(":kom",  kommentar);
    q.bindValue(":id",   id);
    if (!q.exec()) { qCWarning(lcDb) << "spsBaugruppeAktualisieren:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsBaugruppeBetriebsmittelSetzen(int baugruppeId, int betriebsmittelId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sps_baugruppe SET betriebsmittel_id=:bid WHERE id=:id");
    q.bindValue(":bid", betriebsmittelId > 0 ? QVariant(betriebsmittelId) : QVariant(QMetaType::fromType<int>()));
    q.bindValue(":id",  baugruppeId);
    if (!q.exec()) { qCWarning(lcDb) << "spsBaugruppeBetriebsmittelSetzen:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsBaugruppeLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM sps_baugruppe WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) { qCWarning(lcDb) << "spsBaugruppeLoeschen:" << q.lastError().text(); return false; }
    return true;
}

// --- Kanal ---

static QString _spsAdresseFormatieren(const QString &systemTyp, int rackNr, int slot,
                                       int kanalNr, const QString &adressTyp,
                                       int byteNr, int bitNr, const QString &datentyp)
{
    if (systemTyp == QLatin1String("PLS")) {
        return QStringLiteral("R%1 S%2 K%3").arg(rackNr).arg(slot).arg(kanalNr + 1);
    }
    if (datentyp == QLatin1String("BYTE"))  return QStringLiteral("%1B%2").arg(adressTyp).arg(byteNr);
    if (datentyp == QLatin1String("WORD"))  return QStringLiteral("%1W%2").arg(adressTyp).arg(byteNr);
    if (datentyp == QLatin1String("DWORD")) return QStringLiteral("%1D%2").arg(adressTyp).arg(byteNr);
    return QStringLiteral("%1%2.%3").arg(adressTyp).arg(byteNr).arg(bitNr);
}

static const QLatin1String _spsKanalSelectBase(
    "SELECT sk.id, sk.projekt_id, sk.baugruppe_id, sk.kanal_nr, "
    "sk.adress_typ, sk.byte_nr, sk.bit_nr, sk.datentyp, "
    "sk.variablenname, sk.kommentar, sk.grafik_element_id, "
    "sk.pls_einheit, sk.pls_bereich_min, sk.pls_bereich_max, "
    "sk.pls_alarm_ll, sk.pls_alarm_lo, sk.pls_alarm_hi, sk.pls_alarm_hh, "
    "sk.pls_hart_adresse, sk.pls_protokoll, "
    "sr.id AS rack_id, sr.rack_nr, sr.system_typ, sb.slot, "
    "ge.extra_daten AS element_extra_daten, se.name AS seite_name "
    "FROM sps_kanal sk "
    "LEFT JOIN sps_baugruppe  sb ON sb.id = sk.baugruppe_id "
    "LEFT JOIN sps_rack       sr ON sr.id = sb.rack_id "
    "LEFT JOIN grafik_element ge ON ge.id = sk.grafik_element_id "
    "LEFT JOIN seite          se ON se.id = ge.seite_id ");

static QVariantMap _spsKanalRow(QSqlQuery &q)
{
    QVariantMap m;
    m["id"]                = q.value(0).toInt();
    m["projekt_id"]        = q.value(1).toInt();
    m["baugruppe_id"]      = q.value(2).isNull() ? QVariant() : q.value(2).toInt();
    m["kanal_nr"]          = q.value(3).isNull() ? QVariant() : q.value(3).toInt();
    m["adress_typ"]        = q.value(4).toString();
    m["byte_nr"]           = q.value(5).toInt();
    m["bit_nr"]            = q.value(6).toInt();
    m["datentyp"]          = q.value(7).toString();
    m["variablenname"]     = q.value(8).toString();
    m["kommentar"]         = q.value(9).toString();
    m["grafik_element_id"] = q.value(10).isNull() ? QVariant() : q.value(10).toInt();
    m["pls_einheit"]       = q.value(11).isNull() ? QVariant() : q.value(11).toString();
    m["pls_bereich_min"]   = q.value(12).isNull() ? QVariant() : q.value(12).toDouble();
    m["pls_bereich_max"]   = q.value(13).isNull() ? QVariant() : q.value(13).toDouble();
    m["pls_alarm_ll"]      = q.value(14).isNull() ? QVariant() : q.value(14).toDouble();
    m["pls_alarm_lo"]      = q.value(15).isNull() ? QVariant() : q.value(15).toDouble();
    m["pls_alarm_hi"]      = q.value(16).isNull() ? QVariant() : q.value(16).toDouble();
    m["pls_alarm_hh"]      = q.value(17).isNull() ? QVariant() : q.value(17).toDouble();
    m["pls_hart_adresse"]  = q.value(18).isNull() ? QVariant() : q.value(18).toInt();
    m["pls_protokoll"]     = q.value(19).isNull() ? QVariant() : q.value(19).toString();
    m["rack_id"]           = q.value(20).isNull() ? QVariant() : q.value(20).toInt();
    m["rack_nr"]           = q.value(21).isNull() ? QVariant() : q.value(21).toInt();
    m["system_typ"]             = q.value(22).isNull() ? QStringLiteral("SPS") : q.value(22).toString();
    m["slot"]                   = q.value(23).isNull() ? QVariant() : q.value(23).toInt();
    m["element_extra_daten"]    = q.value(24).isNull() ? QVariant() : q.value(24).toString();
    m["seite_name"]             = q.value(25).isNull() ? QVariant() : q.value(25).toString();
    // Formatierte Adresse berechnen
    int rackNr  = q.value(21).isNull() ? 0 : q.value(21).toInt();
    int slot    = q.value(23).isNull() ? 0 : q.value(23).toInt();
    int kanalNr = q.value(3).isNull()  ? 0 : q.value(3).toInt();
    m["adresse"] = _spsAdresseFormatieren(m["system_typ"].toString(), rackNr, slot, kanalNr,
                                           m["adress_typ"].toString(),
                                           m["byte_nr"].toInt(), m["bit_nr"].toInt(),
                                           m["datentyp"].toString());
    return m;
}

QVariantList Database::spsKanalListe(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(QString(_spsKanalSelectBase)
              + "WHERE sk.projekt_id = :pid "
                "ORDER BY sr.rack_nr, sb.slot, sk.kanal_nr, sk.adress_typ, sk.byte_nr, sk.bit_nr");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalListe:" << q.lastError().text(); return result; }
    while (q.next()) result.append(_spsKanalRow(q));
    return result;
}

QVariantList Database::spsKanalListeFuerBaugruppe(int baugruppeId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(QString(_spsKanalSelectBase)
              + "WHERE sk.baugruppe_id = :bid ORDER BY sk.kanal_nr, sk.byte_nr, sk.bit_nr");
    q.bindValue(":bid", baugruppeId);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalListeFuerBaugruppe:" << q.lastError().text(); return result; }
    while (q.next()) result.append(_spsKanalRow(q));
    return result;
}

int Database::spsKanalAnlegen(int projektId, int baugruppeId, int kanalNr,
                               const QString &adressTyp, int byteNr, int bitNr,
                               const QString &datentyp, const QString &variablenname,
                               const QString &kommentar)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO sps_kanal "
              "(projekt_id, baugruppe_id, kanal_nr, adress_typ, byte_nr, bit_nr, "
              " datentyp, variablenname, kommentar) "
              "VALUES (:pid, :bid, :knr, :typ, :byt, :bit, :dty, :var, :kom)");
    q.bindValue(":pid", projektId);
    q.bindValue(":bid", baugruppeId > 0 ? QVariant(baugruppeId) : QVariant());
    q.bindValue(":knr", kanalNr >= 0    ? QVariant(kanalNr)     : QVariant());
    q.bindValue(":typ", adressTyp);
    q.bindValue(":byt", byteNr);
    q.bindValue(":bit", bitNr);
    q.bindValue(":dty", datentyp);
    q.bindValue(":var", variablenname);
    q.bindValue(":kom", kommentar);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalAnlegen:" << q.lastError().text(); return -1; }
    return q.lastInsertId().toInt();
}

bool Database::spsKanalAktualisieren(int id, const QVariantMap &felder)
{
    if (felder.isEmpty()) return true;

    QStringList setClauses;
    QVariantMap bv;
    const QStringList textFelder = {"adress_typ","datentyp","variablenname","kommentar",
                                     "pls_einheit","pls_protokoll"};
    const QStringList intFelder  = {"byte_nr","bit_nr","kanal_nr","pls_hart_adresse"};
    const QStringList realFelder = {"pls_bereich_min","pls_bereich_max",
                                     "pls_alarm_ll","pls_alarm_lo","pls_alarm_hi","pls_alarm_hh"};

    for (const QString &f : textFelder) {
        if (felder.contains(f)) {
            setClauses << (f + QStringLiteral("=:") + f);
            bv[f] = felder[f].isNull() ? QVariant() : felder[f].toString();
        }
    }
    for (const QString &f : intFelder) {
        if (felder.contains(f)) {
            setClauses << (f + QStringLiteral("=:") + f);
            bv[f] = felder[f].isNull() ? QVariant() : felder[f].toInt();
        }
    }
    for (const QString &f : realFelder) {
        if (felder.contains(f)) {
            setClauses << (f + QStringLiteral("=:") + f);
            bv[f] = felder[f].isNull() ? QVariant() : felder[f].toDouble();
        }
    }
    if (setClauses.isEmpty()) return true;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE sps_kanal SET %1 WHERE id=:id").arg(setClauses.join(",")));
    for (auto it = bv.constBegin(); it != bv.constEnd(); ++it)
        q.bindValue(QStringLiteral(":") + it.key(), it.value());
    q.bindValue(":id", id);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalAktualisieren:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsKanalLoeschen(int id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM sps_kanal WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalLoeschen:" << q.lastError().text(); return false; }
    return true;
}

QString Database::spsKanalAdresse(int kanalId)
{
    QSqlQuery q(m_db);
    q.prepare(QString(_spsKanalSelectBase) + "WHERE sk.id = :id");
    q.bindValue(":id", kanalId);
    if (!q.exec() || !q.next()) return QString();
    return _spsKanalRow(q)["adresse"].toString();
}

bool Database::spsKanalElementZuweisen(int kanalId, int elementId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sps_kanal SET grafik_element_id=:eid WHERE id=:id");
    q.bindValue(":eid", elementId);
    q.bindValue(":id",  kanalId);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalElementZuweisen:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsKanalElementEntfernen(int kanalId)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sps_kanal SET grafik_element_id=NULL WHERE id=:id");
    q.bindValue(":id", kanalId);
    if (!q.exec()) { qCWarning(lcDb) << "spsKanalElementEntfernen:" << q.lastError().text(); return false; }
    return true;
}

QVariantMap Database::spsKanalFuerElement(int elementId)
{
    QSqlQuery q(m_db);
    q.prepare(QString(_spsKanalSelectBase) + "WHERE sk.grafik_element_id = :eid");
    q.bindValue(":eid", elementId);
    if (!q.exec() || !q.next()) return {};
    return _spsKanalRow(q);
}

QVariantList Database::spsIOListe(int projektId)
{
    return spsKanalListe(projektId);
}

bool Database::spsIOListeCsvSpeichern(int projektId, const QString &pfad)
{
    QVariantList kanaele = spsIOListe(projektId);
    QFile file;
    QTextStream out;
    if (!CsvHelfer::dateiOeffnenMitBom(pfad, file, out, "spsIOListeCsvSpeichern"))
        return false;
    out << "\"Adresse\";\"System\";\"Typ\";\"Variable / Tag\";\"Kommentar\";"
           "\"Einheit\";\"Bereich Min\";\"Bereich Max\";"
           "\"Alarm LL\";\"Alarm LO\";\"Alarm HI\";\"Alarm HH\";"
           "\"Protokoll\";\"Element-ID\"\n";

    auto csv = CsvHelfer::escapeImmer;

    for (const QVariant &kv : kanaele) {
        QVariantMap k = kv.toMap();
        out << '"' << csv(k["adresse"])          << "\";";
        out << '"' << csv(k["system_typ"])        << "\";";
        out << '"' << csv(k["adress_typ"])        << "\";";
        out << '"' << csv(k["variablenname"])     << "\";";
        out << '"' << csv(k["kommentar"])         << "\";";
        out << '"' << csv(k["pls_einheit"])       << "\";";
        out << '"' << csv(k["pls_bereich_min"])   << "\";";
        out << '"' << csv(k["pls_bereich_max"])   << "\";";
        out << '"' << csv(k["pls_alarm_ll"])      << "\";";
        out << '"' << csv(k["pls_alarm_lo"])      << "\";";
        out << '"' << csv(k["pls_alarm_hi"])      << "\";";
        out << '"' << csv(k["pls_alarm_hh"])      << "\";";
        out << '"' << csv(k["pls_protokoll"])     << "\";";
        out << '"' << csv(k["grafik_element_id"]) << "\"\n";
    }
    file.close();
    qCInfo(lcDb) << "SPS/PLS I/O-Liste exportiert:" << file.fileName() << "(" << kanaele.size() << "Kanäle)";
    return true;
}

QVariantList Database::spsKonfliktElementIds(int projektId)
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT grafik_element_id FROM sps_kanal "
              "WHERE projekt_id = :pid AND grafik_element_id IS NOT NULL "
              "GROUP BY grafik_element_id HAVING COUNT(*) > 1");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qCWarning(lcDb) << "spsKonfliktElementIds:" << q.lastError().text(); return result; }
    while (q.next()) result.append(q.value(0).toInt());
    return result;
}

// ============================================================
// Canvas PDF-Export (L16)
// ============================================================

// ── Hilfsfunktionen (file-scope) ────────────────────────────

