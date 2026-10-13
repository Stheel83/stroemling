// SPS-EXPORT-02: frei konfigurierbarer CSV-Export der SPS/PLS-Adressliste.
// Der Anwender wählt Spalten (Reihenfolge, Titel), Filter und Format selbst;
// Strömling kennt keine Hersteller-Formate (nicht verifizierbar), liefert aber
// alle nötigen Daten, damit sich ein Zielformat nachbilden lässt.
// Konfiguration als JSON (Vorlagen liegen global in den App-Einstellungen, QML):
//   { spalten:[{feld,titel,wert?}], trennzeichen, dezimal, kopfzeile, bom,
//     anfuehrung:"immer"|"bei_bedarf",
//     filter:{ system:"", rack:"", signal:"", belegung:"alle|mit_element|ohne_element",
//              anlage:"", ort:"" },
//     schemata:{ "AI":{spalten:[{feld,titel,wert?}]}, "DI":{…} },   // SPS-EXPORT-04
//     ausgabe:"einzeln"|"eine_datei" }
// "spalten" ist das Standard-Schema; eine Signalart (DI/DO/AI/AO) ohne eigenes Schema
// fällt darauf zurück. "einzeln" schreibt je verwendetem Schema eine CSV (_<Schema>).
// Je Schema (Standard und schemata[X]) zusätzlich: leere_ausblenden:bool (Spalten ohne jeden Wert
// entfallen), sortierung:[{feld,absteigend}] (natürliche Sortierung, leere Werte zuletzt);
// je Spalte optional prefix/suffix (nur bei nicht leerem Wert).
// Spalte feld:"fest": konstanter Text; {feldschlüssel} darin wird durch den Feldwert
// ersetzt (SPS-EXPORT-05, nur Export – wird beim Import nicht zurückgelesen).
#include "Database.h"
#include "Database_CsvHelfer.h"
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QPdfWriter>
#include "PdfRenderer.h"
#include <QCollator>
#include <QHash>
#include <QMultiHash>
#include <QPointF>
#include <cmath>
#include <algorithm>
#include <QMap>
#include <QRegularExpression>
#include <QSet>
#include <QSqlQuery>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextStream>

namespace {

struct FeldDef { const char *key; const char *titel; const char *gruppe; bool standard; };

// Reihenfolge = Standard-Spaltenreihenfolge; Titel der Standard-Felder entsprechen
// dem Kopf der bisherigen festen I/O-Liste (SPS-EXPORT-01).
const FeldDef kFelder[] = {
    {"system",           "System",            "Ort",       true },
    {"rack",             "Rack",              "Ort",       true },
    {"slot",             "Slot",              "Ort",       true },
    {"kanal",            "Kanal",             "Ort",       true },
    {"kanal_absolut",    "Kanal absolut",     "Ort",       false},
    {"rack_slot_kanal",  "Rack.Slot.Kanal",   "Ort",       false},
    {"rack_bezeichnung", "Rack-Bezeichnung",  "Ort",       false},
    {"hersteller",       "Hersteller",        "Ort",       false},
    {"baugruppe",        "Baugruppe",         "Hardware",  true },
    {"baugruppen_typ",   "Baugruppen-Typ",    "Hardware",  true },
    {"artikel_nr",       "Artikel-Nr.",       "Hardware",  false},
    {"signal",           "Signal",            "Hardware",  true },
    {"analog_digital",   "Analog/Digital",    "Hardware",  false},
    {"richtung",         "Richtung",          "Hardware",  false},
    {"baugruppen_bereich","Baugruppen-Adressbereich","Hardware", false},
    {"adresse",          "Adresse",           "Adresse",   true },
    {"datentyp",         "Datentyp",          "Adresse",   true },
    {"adresse_iec",      "IEC-Adresse",       "Adresse",   false},
    {"adress_typ",       "Adress-Typ",        "Adresse",   false},
    {"byte_nr",          "Byte",              "Adresse",   false},
    {"bit_nr",           "Bit",               "Adresse",   false},
    {"variablenname",    "Variable / Tag",    "Signal",    true },
    {"kommentar",        "Kommentar",         "Signal",    true },
    {"einheit",          "Einheit",           "Signal",    true },
    {"bereich_min",      "Bereich Min",       "Signal",    true },
    {"bereich_max",      "Bereich Max",       "Signal",    true },
    {"alarm_ll",         "Alarm LL",          "Signal",    true },
    {"alarm_lo",         "Alarm LO",          "Signal",    true },
    {"alarm_hi",         "Alarm HI",          "Signal",    true },
    {"alarm_hh",         "Alarm HH",          "Signal",    true },
    {"protokoll",        "Protokoll",         "Signal",    true },
    {"hart_adresse",     "HART-Adresse",      "Signal",    false},
    {"spannweite",       "Spannweite",        "Signal",    false},
    {"alarm_vorhanden",  "Alarm vorhanden",   "Signal",    false},
    {"bmk",              "BMK",               "Schaltplan",true },
    {"seite_blatt",      "Seite",             "Schaltplan",true },
    {"seite_name",       "Seitenbezeichnung", "Schaltplan",true },
    {"gegenstelle_bmk",  "Gegenstelle BMK",   "Verdrahtung",false},
    {"gegenstelle_anschluss","Gegenstelle Anschluss","Verdrahtung",false},
    {"gegenstelle_bauteil","Gegenstelle Bauteil","Verdrahtung",false},
    {"gegenstelle_artikel","Gegenstelle Artikel-Nr.","Verdrahtung",false},
    {"klemme",           "Klemme",            "Verdrahtung",false},
    {"kabel",            "Kabel",             "Verdrahtung",false},
    {"ader",             "Ader",              "Verdrahtung",false},
    {"anlage",           "Anlage",            "Schaltplan",false},
    {"ort",              "Ort (Einbauort)",   "Schaltplan",false},
    {"freitext1",        "Freitext 1",        "Schaltplan",false},
    {"freitext2",        "Freitext 2",        "Schaltplan",false},
    {"fest",             "Text / Platzhalter","Sonstiges", false},
};

const FeldDef *feldDef(const QString &key)
{
    for (const FeldDef &f : kFelder)
        if (key == QLatin1String(f.key)) return &f;
    return nullptr;
}

QString zahl(const QVariant &v, const QString &dezimal)
{
    if (v.isNull() || !v.isValid()) return QString();
    QString s = QString::number(v.toDouble(), 'g', 10);
    if (dezimal != QLatin1String(".")) s.replace(QLatin1Char('.'), dezimal);
    return s;
}

QString signalArt(const QVariantMap &k)
{
    const QString adressTyp = k["adress_typ"].toString();
    if (k["baugruppe_id"].isNull()) return adressTyp;
    QString s = k["baugruppe_typ"].toString().toUpper();
    if (s == QLatin1String("DIO")) s = (adressTyp == QLatin1String("A")) ? QStringLiteral("DO") : QStringLiteral("DI");
    if (s == QLatin1String("AIO")) s = (adressTyp == QLatin1String("A")) ? QStringLiteral("AO") : QStringLiteral("AI");
    return s;
}

// Felder, die nur Ableitungen/Schaltplan-Bezug sind und beim Import nicht gesetzt werden können.
bool feldImportierbar(const QString &key)
{
    static const QSet<QString> nein = {
        "bmk", "seite_blatt", "seite_name", "fest", "anlage", "ort", "freitext1", "freitext2",
        "adresse_iec", "richtung", "analog_digital", "rack_slot_kanal", "kanal_absolut",
        "baugruppen_bereich", "alarm_vorhanden", "spannweite",
        "gegenstelle_bmk", "gegenstelle_anschluss", "gegenstelle_bauteil", "gegenstelle_artikel",
        "klemme", "kabel", "ader"};
    return !nein.contains(key);
}

bool istEingangTyp(const QString &t) { return t == QLatin1String("E") || t == QLatin1String("I"); }
bool istAusgangTyp(const QString &t) { return t == QLatin1String("A") || t == QLatin1String("Q"); }

// %IX0.0 / %QW4 / %MD10 – gleiche Fallunterscheidung wie die interne Adressanzeige
QString iecAdresse(const QVariantMap &k)
{
    if (k["system_typ"].toString() == QLatin1String("PLS")) return QString();
    const QString t = k["adress_typ"].toString();
    QString bereich;
    if (istEingangTyp(t)) bereich = QStringLiteral("I");
    else if (istAusgangTyp(t)) bereich = QStringLiteral("Q");
    else if (t == QLatin1String("M")) bereich = QStringLiteral("M");
    else return QString();   // Zeit-/Zähler-Nummern haben in IEC keine Direktadresse
    const QString dt = k["datentyp"].toString();
    const int byteNr = k["byte_nr"].toInt();
    if (dt == QLatin1String("BYTE"))  return QStringLiteral("%%1B%2").arg(bereich).arg(byteNr);
    if (dt == QLatin1String("WORD"))  return QStringLiteral("%%1W%2").arg(bereich).arg(byteNr);
    if (dt == QLatin1String("DWORD")) return QStringLiteral("%%1D%2").arg(bereich).arg(byteNr);
    return QStringLiteral("%%1X%2.%3").arg(bereich).arg(byteNr).arg(k["bit_nr"].toInt());
}

QString feldWert(const QString &key, const QVariantMap &k, const QString &dezimal, const QString &fest);

// {feld}-Platzhalter im festen Text; unbekannte Schlüssel bleiben unverändert stehen.
QString platzhalterErsetzen(const QString &text, const QVariantMap &k, const QString &dezimal)
{
    if (!text.contains(QLatin1Char('{'))) return text;
    static const QRegularExpression re(QStringLiteral("\\{([a-z0-9_]+)\\}"));
    QString out;
    qsizetype pos = 0;
    QRegularExpressionMatchIterator it = re.globalMatch(text);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        out += text.mid(pos, m.capturedStart() - pos);
        const QString key = m.captured(1);
        if (key != QLatin1String("fest") && feldDef(key)) out += feldWert(key, k, dezimal, QString());
        else out += m.captured(0);
        pos = m.capturedEnd();
    }
    out += text.mid(pos);
    return out;
}

QString feldWert(const QString &key, const QVariantMap &k, const QString &dezimal, const QString &fest)
{
    const bool hatBg = !k["baugruppe_id"].isNull();
    const bool pls   = k["system_typ"].toString() == QLatin1String("PLS");
    if (key == "system")           return hatBg ? k["system_typ"].toString() : QString();
    if (key == "rack")             return hatBg ? k["rack_nr"].toString() : QString();
    if (key == "rack_bezeichnung") return k["rack_bezeichnung"].toString();
    if (key == "hersteller")       return k["hersteller"].toString();
    if (key == "slot")             return hatBg ? k["slot"].toString() : QString();
    if (key == "kanal")            return k["kanal_nr"].isNull() ? QString() : QString::number(k["kanal_nr"].toInt() + 1);
    if (key == "baugruppe")        return k["baugruppe_bezeichnung"].toString();
    if (key == "baugruppen_typ")   return k["baugruppe_typ"].toString();
    if (key == "artikel_nr")       return k["artikel_nr"].toString();
    if (key == "signal")           return signalArt(k);
    if (key == "adresse")          return k["adresse"].toString();
    if (key == "datentyp")         return k["datentyp"].toString();
    if (key == "adress_typ")       return k["adress_typ"].toString();
    if (key == "byte_nr")          return pls ? QString() : k["byte_nr"].toString();
    if (key == "bit_nr")           return (pls || k["datentyp"].toString() != QLatin1String("BOOL")) ? QString() : k["bit_nr"].toString();
    if (key == "variablenname")    return k["variablenname"].toString();
    if (key == "kommentar")        return k["kommentar"].toString();
    if (key == "einheit")          return k["pls_einheit"].toString();
    if (key == "bereich_min")      return zahl(k["pls_bereich_min"], dezimal);
    if (key == "bereich_max")      return zahl(k["pls_bereich_max"], dezimal);
    if (key == "alarm_ll")         return zahl(k["pls_alarm_ll"], dezimal);
    if (key == "alarm_lo")         return zahl(k["pls_alarm_lo"], dezimal);
    if (key == "alarm_hi")         return zahl(k["pls_alarm_hi"], dezimal);
    if (key == "alarm_hh")         return zahl(k["pls_alarm_hh"], dezimal);
    if (key == "protokoll")        return k["pls_protokoll"].toString();
    if (key == "hart_adresse")     return k["pls_hart_adresse"].isNull() ? QString() : k["pls_hart_adresse"].toString();
    if (key == "bmk") {
        const QByteArray ed = k["element_extra_daten"].toString().toUtf8();
        return ed.isEmpty() ? QString() : QJsonDocument::fromJson(ed).object().value("bmk").toString();
    }
    if (key == "seite_blatt")      return k["seite_blatt"].toString();
    if (key == "seite_name")       return k["seite_name"].toString();
    if (key == "adresse_iec")      return iecAdresse(k);
    if (key == "richtung") {
        const QString sig = signalArt(k);
        if (sig == QLatin1String("DI") || sig == QLatin1String("AI") || istEingangTyp(sig)) return QStringLiteral("Eingang");
        if (sig == QLatin1String("DO") || sig == QLatin1String("AO") || istAusgangTyp(sig)) return QStringLiteral("Ausgang");
        return QString();
    }
    if (key == "analog_digital") {
        const QString sig = signalArt(k);
        if (sig == QLatin1String("AI") || sig == QLatin1String("AO")) return QStringLiteral("analog");
        if (sig == QLatin1String("DI") || sig == QLatin1String("DO")) return QStringLiteral("digital");
        return QString();
    }
    if (key == "rack_slot_kanal") {
        if (!hatBg || k["kanal_nr"].isNull()) return QString();
        return QStringLiteral("R%1.S%2.K%3").arg(k["rack_nr"].toInt()).arg(k["slot"].toInt()).arg(k["kanal_nr"].toInt() + 1);
    }
    if (key == "kanal_absolut")    return k["_kanal_absolut"].toString();
    if (key == "baugruppen_bereich") return k["_baugruppen_bereich"].toString();
    if (key == "alarm_vorhanden") {
        for (const char *f : {"pls_alarm_ll", "pls_alarm_lo", "pls_alarm_hi", "pls_alarm_hh"})
            if (!k[QLatin1String(f)].isNull()) return QStringLiteral("ja");
        return QStringLiteral("nein");
    }
    if (key == "spannweite") {
        if (k["pls_bereich_min"].isNull() || k["pls_bereich_max"].isNull()) return QString();
        return zahl(k["pls_bereich_max"].toDouble() - k["pls_bereich_min"].toDouble(), dezimal);
    }
    if (key == "gegenstelle_bmk" || key == "gegenstelle_anschluss" || key == "gegenstelle_bauteil"
        || key == "gegenstelle_artikel" || key == "klemme" || key == "kabel" || key == "ader")
        return k["_vw_" + key].toString();
    if (key == "anlage")           return k["anlage_kuerzel"].toString();
    if (key == "ort")              return k["ort_kuerzel"].toString();
    if (key == "freitext1" || key == "freitext2") {
        const QByteArray ed = k["element_extra_daten"].toString().toUtf8();
        return ed.isEmpty() ? QString() : QJsonDocument::fromJson(ed).object().value(key).toString();
    }
    if (key == "fest")             return platzhalterErsetzen(fest, k, dezimal);
    return QString();
}

QString csvFeld(const QString &s, const QString &trenn, bool immer)
{
    const bool noetig = s.contains(QLatin1Char('"')) || s.contains(QLatin1Char('\n'))
                        || s.contains(QLatin1Char('\r')) || (!trenn.isEmpty() && s.contains(trenn));
    if (!immer && !noetig) return s;
    return QLatin1Char('"') + QString(s).replace(QLatin1Char('"'), QLatin1String("\"\"")) + QLatin1Char('"');
}

} // namespace

QVariantList Database::spsExportFeldKatalog()
{
    QVariantList r;
    for (const FeldDef &f : kFelder) {
        QVariantMap m;
        m["feld"]     = QString::fromLatin1(f.key);
        m["titel"]    = QString::fromUtf8(f.titel);
        m["gruppe"]   = QString::fromUtf8(f.gruppe);
        m["standard"] = f.standard;
        m["importierbar"] = feldImportierbar(QString::fromLatin1(f.key));
        r.append(m);
    }
    return r;
}

QString Database::spsExportStandardKonfig()
{
    QJsonArray spalten;
    for (const FeldDef &f : kFelder) {
        if (!f.standard) continue;
        spalten.append(QJsonObject{{"feld", QString::fromLatin1(f.key)},
                                   {"titel", QString::fromUtf8(f.titel)}});
    }
    QJsonObject k;
    k["spalten"]      = spalten;
    k["trennzeichen"] = QStringLiteral(";");
    k["dezimal"]      = QStringLiteral(",");
    k["kopfzeile"]    = true;
    k["bom"]          = true;
    k["anfuehrung"]   = QStringLiteral("immer");
    k["filter"]       = QJsonObject{{"system", ""}, {"rack", ""}, {"signal", ""}, {"belegung", "alle"}};
    k["schemata"]     = QJsonObject();
    k["ausgabe"]      = QStringLiteral("einzeln");
    return QString::fromUtf8(QJsonDocument(k).toJson(QJsonDocument::Compact));
}

QStringList Database::spsExportSchemaIrrelevanteFelder(const QString &signal)
{
    const QString s = signal.toUpper();
    const QStringList alarme = {"alarm_ll", "alarm_lo", "alarm_hi", "alarm_hh"};
    if (s == QLatin1String("DI") || s == QLatin1String("DO"))
        return QStringList{"einheit", "bereich_min", "bereich_max", "protokoll", "hart_adresse"} + alarme;
    if (s == QLatin1String("AI") || s == QLatin1String("AO"))
        return alarme;
    return {};
}

QVariantMap Database::spsExportFilterWerte(int projektId)
{
    QSet<QString> anlagen, orte;
    for (const QVariant &kv : spsKanalListe(projektId)) {
        const QVariantMap k = kv.toMap();
        if (!k["anlage_kuerzel"].toString().isEmpty()) anlagen.insert(k["anlage_kuerzel"].toString());
        if (!k["ort_kuerzel"].toString().isEmpty())    orte.insert(k["ort_kuerzel"].toString());
    }
    QStringList a(anlagen.begin(), anlagen.end()), o(orte.begin(), orte.end());
    a.sort(); o.sort();
    QVariantMap r;
    r["anlagen"] = a;
    r["orte"]    = o;
    return r;
}

// Verdrahtung je Kanal (SPS-EXPORT-06): Gegenstelle, Klemme, Kabel/Ader – nur, wenn eindeutig.
// Grundlage sind die gespeicherten Netze (verbindung/verbindung_segment, geometrischer Pin-Abgleich
// wie bei der Mikrocontroller-Pinbelegung). Eindeutig heißt: das Signalpin des Kanal-Elements liegt
// an genau einem Netz, und im Netz gibt es genau ein anderes Gerät (bzw. genau eine Klemme, genau
// eine Kabelader). Bei Verzweigung bleibt das jeweilige Feld leer.
QHash<int, QVariantMap> Database::spsVerdrahtungJeKanal(int projektId, const QVariantList &kanaele)
{
    QHash<int, QVariantMap> ergebnis;

    QHash<int, int> elementZuKanal;   // grafik_element_id → sps_kanal.id
    for (const QVariant &kv : kanaele) {
        const QVariantMap kn = kv.toMap();
        if (!kn["grafik_element_id"].isNull()) elementZuKanal.insert(kn["grafik_element_id"].toInt(), kn["id"].toInt());
    }
    if (elementZuKanal.isEmpty()) return ergebnis;

    static const QSet<QString> hilfs = {
        "winkel", "treffpunkt", "treffpunkt_l", "unterbrechung", "querverweis", "aderdefinition"};
    static const QSet<QString> signalPins = {"input_digital", "output_digital", "input_analog", "output_analog"};

    struct PinDef { double x, y; QString name, signaltyp; };
    QHash<QString, QList<PinDef>> pinCache;
    auto pinsVon = [&](const QString &symId) -> const QList<PinDef> & {
        if (!pinCache.contains(symId)) {
            QList<PinDef> l;
            QSqlQuery pQ(m_db);
            pQ.prepare("SELECT x, y, name, signaltyp FROM symbol_pin WHERE symbol_id = :s ORDER BY id");
            pQ.bindValue(":s", symId);
            if (pQ.exec())
                while (pQ.next()) l.push_back({pQ.value(0).toDouble(), pQ.value(1).toDouble(),
                                               pQ.value(2).toString(), pQ.value(3).toString()});
            pinCache.insert(symId, l);
        }
        return pinCache[symId];
    };

    struct NetPin {
        int elementId = 0, klemmeId = 0, bauteilId = 0, betriebsmittelId = 0;
        QString bmk, pin;
    };
    QMap<int, QList<NetPin>> netMitglieder;     // verbindung_id → Pins (alle Seiten)
    QHash<int, QSet<int>> kanalNetze;           // Kanal-Element → Netze seines Signalpins

    QList<int> seiten;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT s.id FROM seite s JOIN ort o ON o.id = s.ort_id "
                  "JOIN anlage a ON a.id = o.anlage_id WHERE a.projekt_id = :p ORDER BY s.id");
        q.bindValue(":p", projektId);
        if (q.exec()) while (q.next()) seiten.append(q.value(0).toInt());
    }
    const double eps = 0.5;
    for (int seiteId : seiten) {
        QMap<int, QList<QPointF>> segPunkte;
        {
            QSqlQuery vq(m_db);
            vq.prepare("SELECT vs.verbindung_id, vs.punkte FROM verbindung_segment vs "
                       "JOIN verbindung v ON v.id = vs.verbindung_id WHERE vs.seite_id = :s AND v.projekt_id = :p");
            vq.bindValue(":s", seiteId);
            vq.bindValue(":p", projektId);
            if (vq.exec()) {
                while (vq.next()) {
                    const QJsonArray pts = QJsonDocument::fromJson(vq.value(1).toString().toUtf8()).array();
                    for (const QJsonValue &pv : pts) {
                        const QJsonObject o = pv.toObject();
                        segPunkte[vq.value(0).toInt()].append(QPointF(o["x"].toDouble(), o["y"].toDouble()));
                    }
                }
            }
        }
        if (segPunkte.isEmpty()) continue;

        QSqlQuery symQ(m_db);
        symQ.prepare("SELECT id, symbol_id, x1, y1, x2, y2, rotation, spiegel_x, spiegel_y, extra_daten, betriebsmittel_id "
                     "FROM grafik_element WHERE seite_id = :s AND typ = 'symbol' ORDER BY id");
        symQ.bindValue(":s", seiteId);
        if (!symQ.exec()) continue;
        while (symQ.next()) {
            const QString symId = symQ.value(1).toString();
            if (hilfs.contains(symId)) continue;
            const int elId = symQ.value(0).toInt();
            const double x1 = symQ.value(2).toDouble(), y1 = symQ.value(3).toDouble();
            const double x2 = symQ.value(4).toDouble(), y2 = symQ.value(5).toDouble();
            const double rad = symQ.value(6).toInt() * M_PI / 180.0;
            const bool spX = symQ.value(7).toInt() != 0, spY = symQ.value(8).toInt() != 0;
            const QJsonObject ext = QJsonDocument::fromJson(symQ.value(9).toString().toUtf8()).object();
            const double sw = x2 - x1, sh = y2 - y1;
            const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
            const double cosR = std::cos(rad), sinR = std::sin(rad);
            const QString anschluss = ext.value("anschlussBezeichnung").toString();

            for (const PinDef &p : pinsVon(symId)) {
                double cx = (p.x - 0.5) * std::abs(sw);
                double cy = (p.y - 0.5) * std::abs(sh);
                if (spX) cx = -cx;
                if (spY) cy = -cy;
                const double wx = scx + cx * cosR - cy * sinR;
                const double wy = scy + cx * sinR + cy * cosR;
                int netz = -1;
                for (auto it = segPunkte.constBegin(); it != segPunkte.constEnd() && netz < 0; ++it)
                    for (const QPointF &pt : it.value())
                        if (std::abs(pt.x() - wx) < eps && std::abs(pt.y() - wy) < eps) { netz = it.key(); break; }
                if (netz < 0) continue;

                NetPin np;
                np.elementId = elId;
                np.bmk = ext.value("bmk").toString();
                np.pin = anschluss.isEmpty() ? p.name : anschluss;
                np.klemmeId = ext.value("klemmeId").toInt();
                np.bauteilId = ext.value("bauteil_id").toInt();
                np.betriebsmittelId = symQ.value(10).toInt();
                netMitglieder[netz].append(np);
                if (elementZuKanal.contains(elId) && signalPins.contains(p.signaltyp))
                    kanalNetze[elId].insert(netz);
            }
        }
    }

    // Klemmenbezeichnung "Leiste:Nummer"
    QHash<int, QString> klemmenLabel;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT k.id, COALESCE(l.bezeichnung,''), k.nummer FROM klemme k "
                  "JOIN klemmenleiste l ON l.id = k.klemmenleiste_id WHERE l.projekt_id = :p");
        q.bindValue(":p", projektId);
        if (q.exec()) while (q.next()) {
            const QString leiste = q.value(1).toString(), nr = q.value(2).toString();
            klemmenLabel.insert(q.value(0).toInt(), leiste.isEmpty() ? nr : leiste + QLatin1Char(':') + nr);
        }
    }
    // Kabeladern je Netz
    QMultiHash<int, QVariantMap> aderJeNetz;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT ka.verbindung_id, k.bezeichnung, ka.ader_nr, COALESCE(ka.farbe,''), COALESCE(ka.farbe2,'') "
                  "FROM kabel_ader ka JOIN kabel k ON k.id = ka.kabel_id "
                  "WHERE k.projekt_id = :p AND ka.verbindung_id IS NOT NULL");
        q.bindValue(":p", projektId);
        if (q.exec()) while (q.next()) {
            QVariantMap a;
            a["kabel"] = q.value(1).toString();
            QString nr = QString::number(q.value(2).toInt());
            const QString f1 = q.value(3).toString(), f2 = q.value(4).toString();
            if (!f1.isEmpty()) nr += QStringLiteral(" (") + f1 + (f2.isEmpty() ? QString() : QLatin1Char('/') + f2) + QLatin1Char(')');
            a["ader"] = nr;
            aderJeNetz.insert(q.value(0).toInt(), a);
        }
    }

    for (auto it = kanalNetze.constBegin(); it != kanalNetze.constEnd(); ++it) {
        if (it.value().size() != 1) continue;               // Signalpin an keinem/mehreren Netzen
        const int netz = *it.value().begin();
        const int elId = it.key();
        QVariantMap r;

        QHash<int, QList<NetPin>> geraete;   // elementId → Pins
        QSet<int> klemmen;
        for (const NetPin &np : netMitglieder.value(netz)) {
            if (np.elementId == elId) continue;
            if (np.klemmeId > 0) klemmen.insert(np.klemmeId);
            else geraete[np.elementId].append(np);
        }
        if (geraete.size() == 1) {
            const QList<NetPin> pins = geraete.constBegin().value();
            const NetPin &np = pins.first();
            r["_vw_gegenstelle_bmk"] = np.bmk;
            if (pins.size() == 1) r["_vw_gegenstelle_anschluss"] = np.pin;
            int bauteilId = np.bauteilId;
            if (bauteilId <= 0 && np.betriebsmittelId > 0) {
                QSqlQuery q(m_db);
                q.prepare("SELECT COALESCE(bauteil_id,0) FROM betriebsmittel WHERE id = :id");
                q.bindValue(":id", np.betriebsmittelId);
                if (q.exec() && q.next()) bauteilId = q.value(0).toInt();
            }
            if (bauteilId > 0) {
                QSqlQuery q(m_db);
                q.prepare("SELECT COALESCE(bezeichnung,''), COALESCE(artikelnummer,'') FROM bibliothek.bauteil WHERE id = :id");
                q.bindValue(":id", bauteilId);
                if (q.exec() && q.next()) {
                    r["_vw_gegenstelle_bauteil"]  = q.value(0).toString();
                    r["_vw_gegenstelle_artikel"] = q.value(1).toString();
                }
            }
        }
        if (klemmen.size() == 1) r["_vw_klemme"] = klemmenLabel.value(*klemmen.begin());
        const QList<QVariantMap> adern = aderJeNetz.values(netz);
        if (adern.size() == 1) {
            r["_vw_kabel"] = adern.first()["kabel"];
            r["_vw_ader"]  = adern.first()["ader"];
        }
        if (!r.isEmpty()) ergebnis.insert(elementZuKanal.value(elId), r);
    }
    return ergebnis;
}

// Gemeinsame Datenaufbereitung für CSV und PDF: je Schema Spaltentitel + Zeilen als reine
// Zellentexte (Dezimalzeichen bereits angewendet), Filter angewendet.
bool Database::spsExportGruppen(int projektId, const QString &konfigJson,
                                QList<SpsExportGruppe> &gruppen, QString &fehler)
{
    QJsonParseError pe;
    const QJsonObject k = QJsonDocument::fromJson(konfigJson.toUtf8(), &pe).object();
    if (pe.error != QJsonParseError::NoError || k.isEmpty()) {
        fehler = QStringLiteral("Ungültige Export-Konfiguration");
        return false;
    }

    struct Spalte { QString feld, titel, fest, prefix, suffix; };
    struct SortKey { QString feld; bool absteigend = false; };
    struct Schema { QVector<Spalte> spalten; bool leereAus = false; QVector<SortKey> sort; };

    auto schemaLesen = [](const QJsonObject &o) {
        Schema sc;
        for (const QJsonValue &v : o.value("spalten").toArray()) {
            const QJsonObject c = v.toObject();
            const QString feld = c.value("feld").toString();
            const FeldDef *d = feldDef(feld);
            if (!d) continue;
            sc.spalten.append({feld, c.contains("titel") ? c.value("titel").toString() : QString::fromUtf8(d->titel),
                               c.value("wert").toString(), c.value("prefix").toString(), c.value("suffix").toString()});
        }
        sc.leereAus = o.value("leere_ausblenden").toBool(false);
        for (const QJsonValue &v : o.value("sortierung").toArray()) {
            const QJsonObject c = v.toObject();
            if (feldDef(c.value("feld").toString()))
                sc.sort.append({c.value("feld").toString(), c.value("absteigend").toBool(false)});
        }
        return sc;
    };

    const QString standard = QStringLiteral("Standard");
    QMap<QString, Schema> schemata;   // Schlüssel "Standard" + Signalarten mit eigenem Schema
    schemata[standard] = schemaLesen(k);
    if (schemata[standard].spalten.isEmpty()) {
        fehler = QStringLiteral("Keine Spalte ausgewählt");
        return false;
    }
    const QJsonObject eigene = k.value("schemata").toObject();
    for (auto it = eigene.begin(); it != eigene.end(); ++it) {
        const QString key = it.key().toUpper();
        if (key == standard.toUpper()) continue;
        const Schema sc = schemaLesen(it.value().toObject());
        if (sc.spalten.isEmpty()) {
            fehler = QStringLiteral("Schema %1: keine Spalte ausgewählt").arg(key);
            return false;
        }
        schemata[key] = sc;
    }

    const QString dezimal = k.value("dezimal").toString(QStringLiteral(","));
    const QJsonObject f = k.value("filter").toObject();
    const QString fSystem   = f.value("system").toString();
    const QString fRack     = f.value("rack").toString();
    const QString fSignal   = f.value("signal").toString().toUpper();
    const QString fBelegung = f.value("belegung").toString(QStringLiteral("alle"));
    const QString fAnlage   = f.value("anlage").toString();
    const QString fOrt      = f.value("ort").toString();

    const QVariantList alleKanaele = spsKanalListe(projektId);

    // Verdrahtung nur berechnen, wenn ein Schema ein Feld daraus (Spalte, Sortierung, Platzhalter) braucht
    static const QStringList vwFelder = {"gegenstelle_bmk", "gegenstelle_anschluss", "gegenstelle_bauteil",
                                          "gegenstelle_artikel", "klemme", "kabel", "ader"};
    bool braucheVerdrahtung = false;
    for (const Schema &sc : schemata) {
        for (const Spalte &s : sc.spalten) {
            for (const QString &vf : vwFelder)
                if (s.feld == vf || (s.feld == QLatin1String("fest") && s.fest.contains(QLatin1Char('{') + vf + QLatin1Char('}'))))
                    braucheVerdrahtung = true;
        }
        for (const SortKey &sk : sc.sort) if (vwFelder.contains(sk.feld)) braucheVerdrahtung = true;
    }
    const QHash<int, QVariantMap> verdrahtung = braucheVerdrahtung ? spsVerdrahtungJeKanal(projektId, alleKanaele)
                                                                   : QHash<int, QVariantMap>();

    // Kanal absolut: Kanäle aller E/A-Baugruppen im Rack mit kleinerem Slot + eigener Kanal (1-basiert)
    QHash<int, int> kanalOffset;   // baugruppe_id → Offset
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT b.id, b.rack_id, b.slot, b.typ, b.kanaele FROM sps_baugruppe b "
                  "JOIN sps_rack r ON r.id = b.rack_id WHERE r.projekt_id = :pid "
                  "ORDER BY b.rack_id, b.slot, b.id");
        q.bindValue(":pid", projektId);
        if (q.exec()) {
            int letztesRack = -1, summe = 0;
            while (q.next()) {
                if (q.value(1).toInt() != letztesRack) { letztesRack = q.value(1).toInt(); summe = 0; }
                kanalOffset[q.value(0).toInt()] = summe;
                static const QSet<QString> ioTypen = {"DI", "DO", "AI", "AO", "DIO", "AIO"};
                if (ioTypen.contains(q.value(3).toString().toUpper())) summe += q.value(4).toInt();
            }
        }
    }
    // Adressbereich je Baugruppe (belegte Kanäle): SPS je Adress-Typ "E0.0–E1.7", PLS "K1–K8"
    QHash<int, QString> bereichJeBg;
    {
        struct MinMax { qint64 minKey = 0, maxKey = 0; QString minLabel, maxLabel; bool leer = true; };
        QHash<int, QMap<QString, MinMax>> je;
        for (const QVariant &kv : alleKanaele) {
            const QVariantMap kn = kv.toMap();
            if (kn["baugruppe_id"].isNull()) continue;
            const bool pls = kn["system_typ"].toString() == QLatin1String("PLS");
            if (pls && kn["kanal_nr"].isNull()) continue;
            const qint64 key = pls ? kn["kanal_nr"].toInt()
                                   : qint64(kn["byte_nr"].toInt()) * 8 + qMax(0, kn["bit_nr"].toInt());
            const QString label = pls ? QStringLiteral("K%1").arg(kn["kanal_nr"].toInt() + 1) : kn["adresse"].toString();
            MinMax &mm = je[kn["baugruppe_id"].toInt()][pls ? QString() : kn["adress_typ"].toString()];
            if (mm.leer || key < mm.minKey) { mm.minKey = key; mm.minLabel = label; }
            if (mm.leer || key > mm.maxKey) { mm.maxKey = key; mm.maxLabel = label; }
            mm.leer = false;
        }
        for (auto bi = je.begin(); bi != je.end(); ++bi) {
            QStringList teile;
            for (auto ti = bi.value().begin(); ti != bi.value().end(); ++ti)
                teile << (ti.value().minLabel == ti.value().maxLabel
                              ? ti.value().minLabel
                              : ti.value().minLabel + QStringLiteral("–") + ti.value().maxLabel);
            bereichJeBg[bi.key()] = teile.join(QStringLiteral(" / "));
        }
    }

    // 1) Kanäle filtern und einem Schema zuordnen (Kanal-Maps mit Hilfsschlüsseln anreichern)
    QMap<QString, QList<QVariantMap>> kanaeleJeSchema;
    for (const QVariant &kv : alleKanaele) {
        QVariantMap kanal = kv.toMap();
        const bool hatBg = !kanal["baugruppe_id"].isNull();
        if (hatBg) {
            const int bgId = kanal["baugruppe_id"].toInt();
            if (!kanal["kanal_nr"].isNull() && kanalOffset.contains(bgId))
                kanal["_kanal_absolut"] = QString::number(kanalOffset[bgId] + kanal["kanal_nr"].toInt() + 1);
            kanal["_baugruppen_bereich"] = bereichJeBg.value(bgId);
        }
        if (!fSystem.isEmpty() && (!hatBg || kanal["system_typ"].toString() != fSystem)) continue;
        if (!fRack.isEmpty() && (!hatBg || kanal["rack_nr"].toString() != fRack)) continue;
        if (!fAnlage.isEmpty() && kanal["anlage_kuerzel"].toString() != fAnlage) continue;
        if (!fOrt.isEmpty() && kanal["ort_kuerzel"].toString() != fOrt) continue;
        const QString signal = signalArt(kanal).toUpper();
        if (!fSignal.isEmpty() && signal != fSignal) continue;
        const bool hatElement = !kanal["grafik_element_id"].isNull();
        if (fBelegung == QLatin1String("mit_element") && !hatElement) continue;
        if (fBelegung == QLatin1String("ohne_element") && hatElement) continue;

        const QVariantMap vw = verdrahtung.value(kanal["id"].toInt());
        for (auto it = vw.constBegin(); it != vw.constEnd(); ++it) kanal.insert(it.key(), it.value());

        kanaeleJeSchema[schemata.contains(signal) ? signal : standard].append(kanal);
    }

    // 2) je Schema sortieren, Zellen bilden, leere Spalten ausblenden
    QStringList reihenfolge = {standard, "DI", "DO", "AI", "AO"};
    for (auto it = kanaeleJeSchema.begin(); it != kanaeleJeSchema.end(); ++it)
        if (!reihenfolge.contains(it.key())) reihenfolge << it.key();

    QCollator coll;
    coll.setNumericMode(true);
    coll.setCaseSensitivity(Qt::CaseInsensitive);

    gruppen.clear();
    for (const QString &schemaKey : reihenfolge) {
        if (!kanaeleJeSchema.contains(schemaKey)) continue;
        const Schema &sc = schemata[schemaKey];
        QList<QVariantMap> kanaele = kanaeleJeSchema[schemaKey];

        if (!sc.sort.isEmpty()) {
            std::stable_sort(kanaele.begin(), kanaele.end(), [&](const QVariantMap &a, const QVariantMap &b) {
                for (const SortKey &sk : sc.sort) {
                    const QString va = feldWert(sk.feld, a, QStringLiteral("."), QString());
                    const QString vb = feldWert(sk.feld, b, QStringLiteral("."), QString());
                    if (va.isEmpty() != vb.isEmpty()) return vb.isEmpty();   // leere Werte immer zuletzt
                    const int c = coll.compare(va, vb);
                    if (c != 0) return sk.absteigend ? c > 0 : c < 0;
                }
                return false;
            });
        }

        QStringList titel;
        for (const Spalte &s : sc.spalten) titel << s.titel;
        QList<QStringList> zeilen;
        for (const QVariantMap &kanal : kanaele) {
            QStringList zeile;
            for (const Spalte &s : sc.spalten) {
                QString v = feldWert(s.feld, kanal, dezimal, s.fest);
                if (!v.isEmpty()) v = s.prefix + v + s.suffix;
                zeile << v;
            }
            zeilen.append(zeile);
        }
        if (sc.leereAus && sc.spalten.size() > 1) {
            QList<int> behalten;
            for (int c = 0; c < sc.spalten.size(); ++c) {
                bool belegt = false;
                for (const QStringList &z : zeilen) if (!z[c].isEmpty()) { belegt = true; break; }
                if (belegt) behalten << c;
            }
            if (behalten.isEmpty()) behalten << 0;   // mindestens eine Spalte bleibt
            QStringList t2;
            for (int c : behalten) t2 << titel[c];
            QList<QStringList> z2;
            for (const QStringList &z : zeilen) {
                QStringList n;
                for (int c : behalten) n << z[c];
                z2.append(n);
            }
            titel = t2;
            zeilen = z2;
        }
        SpsExportGruppe g;
        g.schema = schemaKey;
        g.titel = titel;
        g.zeilen = zeilen;
        gruppen.append(g);
    }
    // Nichts exportierbar: leere Standard-Gruppe, damit Kopfzeile/Vorschau weiterhin 0 Zeilen zeigen
    if (gruppen.isEmpty()) {
        SpsExportGruppe g;
        g.schema = standard;
        for (const Spalte &s : schemata[standard].spalten) g.titel << s.titel;
        gruppen.append(g);
    }
    return true;
}

QVariantMap Database::spsExportErzeugen(int projektId, const QString &konfigJson, int maxZeilen)
{
    QVariantMap res;
    res["text"] = QString();
    res["zeilen"] = 0;
    res["fehler"] = QString();
    res["gruppen"] = QVariantList();

    QList<SpsExportGruppe> gruppen;
    QString fehler;
    if (!spsExportGruppen(projektId, konfigJson, gruppen, fehler)) {
        res["fehler"] = fehler;
        return res;
    }

    const QJsonObject k = QJsonDocument::fromJson(konfigJson.toUtf8()).object();
    QString trenn = k.value("trennzeichen").toString(QStringLiteral(";"));
    if (trenn == QLatin1String("\\t")) trenn = QStringLiteral("\t");
    if (trenn.isEmpty()) trenn = QStringLiteral(";");
    const bool immer = k.value("anfuehrung").toString(QStringLiteral("immer")) != QLatin1String("bei_bedarf");
    const bool kopf  = k.value("kopfzeile").toBool(true);

    auto zeileZuCsv = [&](const QStringList &z) {
        QStringList out;
        for (const QString &c : z) out << csvFeld(c, trenn, immer);
        return out.join(trenn);
    };

    QStringList abschnitte;
    QVariantList gruppenListe;
    int gesamt = 0;
    for (const SpsExportGruppe &g : gruppen) {
        QStringList zeilen;
        if (kopf) zeilen << zeileZuCsv(g.titel);
        for (int i = 0; i < g.zeilen.size(); ++i) {
            if (maxZeilen >= 0 && i >= maxZeilen) break;
            zeilen << zeileZuCsv(g.zeilen[i]);
        }
        const QString text = zeilen.join(QLatin1Char('\n')) + QLatin1Char('\n');
        abschnitte << text;
        gesamt += g.zeilen.size();
        QVariantMap gm;
        gm["schema"] = g.schema;
        gm["zeilen"] = g.zeilen.size();
        gm["text"]   = text;
        gruppenListe.append(gm);
    }
    res["text"]    = abschnitte.join(QLatin1Char('\n'));   // Leerzeile zwischen den Abschnitten
    res["zeilen"]  = gesamt;
    res["gruppen"] = gruppenListe;
    return res;
}

bool Database::spsExportPdfSpeichern(int projektId, const QString &projektName,
                                     const QString &pfad, const QString &konfigJson)
{
    QList<SpsExportGruppe> gruppen;
    QString fehler;
    if (!spsExportGruppen(projektId, konfigJson, gruppen, fehler)) {
        qCWarning(lcDb) << "spsExportPdfSpeichern:" << fehler;
        return false;
    }
    // Ein Schema: wie bisher (Listen-PDF-Aufbau). Mehrere: eine Tabelle je Schema in einem Dokument.
    if (gruppen.size() == 1) {
        QVariantList zeilen;
        for (const QStringList &z : gruppen[0].zeilen) zeilen.append(QVariant(z));
        return listePdfSpeichern(QStringLiteral("SPS/PLS – I/O-Liste"), projektName, gruppen[0].titel, zeilen, pfad);
    }
    QString lokal = CsvHelfer::lokalerPfad(pfad);
    QPdfWriter writer(lokal);
    writer.setCreator(QStringLiteral("Stroemling Design"));
    writer.setTitle(QStringLiteral("SPS/PLS – I/O-Liste"));
    writer.setPageLayout(pdfTabellenSeitenLayout());
    QPainter painter(&writer);
    if (!painter.isActive()) {
        qCWarning(lcDb) << "spsExportPdfSpeichern: QPainter konnte nicht gestartet werden";
        return false;
    }
    for (int i = 0; i < gruppen.size(); ++i) {
        QVariantList zeilen;
        for (const QStringList &z : gruppen[i].zeilen) zeilen.append(QVariant(z));
        pdfTabelleRendern(painter, writer,
                          QStringLiteral("SPS/PLS – I/O-Liste (%1)").arg(gruppen[i].schema),
                          projektName, gruppen[i].titel, zeilen, i > 0);
    }
    painter.end();
    return QFile::exists(lokal);
}

QVariantMap Database::spsExportVorschau(int projektId, const QString &konfigJson, int maxZeilen)
{
    return spsExportErzeugen(projektId, konfigJson, maxZeilen);
}

bool Database::spsExportCsvSpeichern(int projektId, const QString &pfad, const QString &konfigJson)
{
    const QVariantMap erg = spsExportErzeugen(projektId, konfigJson, -1);
    if (!erg["fehler"].toString().isEmpty()) {
        qCWarning(lcDb) << "spsExportCsvSpeichern:" << erg["fehler"].toString();
        return false;
    }
    const QJsonObject k = QJsonDocument::fromJson(konfigJson.toUtf8()).object();
    const bool bom = k.value("bom").toBool(true);
    const QVariantList gruppen = erg["gruppen"].toList();
    const bool einzeln = gruppen.size() > 1
                         && k.value("ausgabe").toString(QStringLiteral("einzeln")) != QLatin1String("eine_datei");

    auto schreiben = [&](const QString &zielPfad, const QString &text) {
        QFile file(CsvHelfer::lokalerPfad(zielPfad));
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            qCWarning(lcDb) << "spsExportCsvSpeichern: kann nicht öffnen:" << file.fileName();
            return false;
        }
        QTextStream out(&file);
        out.setEncoding(QStringConverter::Utf8);
        if (bom) out << "\xEF\xBB\xBF";
        out << text;
        file.close();
        qCInfo(lcDb) << "SPS/PLS-Export gespeichert:" << file.fileName();
        return true;
    };

    if (!einzeln) return schreiben(pfad, erg["text"].toString());

    // Eine Datei je Schema: <Name>_<Schema>.<Endung>
    const QFileInfo fi(CsvHelfer::lokalerPfad(pfad));
    const QString endung = fi.suffix().isEmpty() ? QString() : QStringLiteral(".") + fi.suffix();
    for (const QVariant &gv : gruppen) {
        const QVariantMap g = gv.toMap();
        const QString ziel = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName()
                             + QLatin1Char('_') + g["schema"].toString() + endung;
        if (!schreiben(ziel, g["text"].toString())) return false;
    }
    return true;
}
