// SPS-EXPORT-02: frei konfigurierbarer CSV-Export der SPS/PLS-Adressliste.
// Der Anwender wählt Spalten (Reihenfolge, Titel), Filter und Format selbst;
// Strömling kennt keine Hersteller-Formate (nicht verifizierbar), liefert aber
// alle nötigen Daten, damit sich ein Zielformat nachbilden lässt.
// Konfiguration als JSON (Vorlagen liegen global in den App-Einstellungen, QML):
//   { spalten:[{feld,titel,wert?}], trennzeichen, dezimal, kopfzeile, bom,
//     anfuehrung:"immer"|"bei_bedarf",
//     filter:{ system:"", rack:"", signal:"", belegung:"alle|mit_element|ohne_element" } }
#include "Database.h"
#include "Database_CsvHelfer.h"
#include <QFile>
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
    {"rack_bezeichnung", "Rack-Bezeichnung",  "Ort",       false},
    {"hersteller",       "Hersteller",        "Ort",       false},
    {"baugruppe",        "Baugruppe",         "Hardware",  true },
    {"baugruppen_typ",   "Baugruppen-Typ",    "Hardware",  true },
    {"artikel_nr",       "Artikel-Nr.",       "Hardware",  false},
    {"signal",           "Signal",            "Hardware",  true },
    {"adresse",          "Adresse",           "Adresse",   true },
    {"datentyp",         "Datentyp",          "Adresse",   true },
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
    {"bmk",              "BMK",               "Schaltplan",true },
    {"seite_blatt",      "Seite",             "Schaltplan",true },
    {"seite_name",       "Seitenbezeichnung", "Schaltplan",true },
    {"fest",             "Fester Text",       "Sonstiges", false},
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
    if (key == "fest")             return fest;
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
    return QString::fromUtf8(QJsonDocument(k).toJson(QJsonDocument::Compact));
}

// Gemeinsame Datenaufbereitung für CSV und PDF: Spaltentitel + Zeilen als reine
// Zellentexte (Dezimalzeichen bereits angewendet), Filter angewendet.
bool Database::spsExportZeilen(int projektId, const QString &konfigJson, QStringList &titel,
                               QList<QStringList> &zeilen, QString &fehler)
{
    QJsonParseError pe;
    const QJsonObject k = QJsonDocument::fromJson(konfigJson.toUtf8(), &pe).object();
    if (pe.error != QJsonParseError::NoError || k.isEmpty()) {
        fehler = QStringLiteral("Ungültige Export-Konfiguration");
        return false;
    }

    struct Spalte { QString feld, titel, fest; };
    QVector<Spalte> spalten;
    for (const QJsonValue &v : k.value("spalten").toArray()) {
        const QJsonObject o = v.toObject();
        const QString feld = o.value("feld").toString();
        const FeldDef *d = feldDef(feld);
        if (!d) continue;
        spalten.append({feld, o.contains("titel") ? o.value("titel").toString() : QString::fromUtf8(d->titel),
                        o.value("wert").toString()});
    }
    if (spalten.isEmpty()) {
        fehler = QStringLiteral("Keine Spalte ausgewählt");
        return false;
    }
    for (const Spalte &s : spalten) titel << s.titel;

    const QString dezimal = k.value("dezimal").toString(QStringLiteral(","));
    const QJsonObject f = k.value("filter").toObject();
    const QString fSystem   = f.value("system").toString();
    const QString fRack     = f.value("rack").toString();
    const QString fSignal   = f.value("signal").toString().toUpper();
    const QString fBelegung = f.value("belegung").toString(QStringLiteral("alle"));

    for (const QVariant &kv : spsKanalListe(projektId)) {
        const QVariantMap kanal = kv.toMap();
        const bool hatBg = !kanal["baugruppe_id"].isNull();
        if (!fSystem.isEmpty() && (!hatBg || kanal["system_typ"].toString() != fSystem)) continue;
        if (!fRack.isEmpty() && (!hatBg || kanal["rack_nr"].toString() != fRack)) continue;
        if (!fSignal.isEmpty() && signalArt(kanal).toUpper() != fSignal) continue;
        const bool hatElement = !kanal["grafik_element_id"].isNull();
        if (fBelegung == QLatin1String("mit_element") && !hatElement) continue;
        if (fBelegung == QLatin1String("ohne_element") && hatElement) continue;

        QStringList zeile;
        for (const Spalte &s : spalten)
            zeile << feldWert(s.feld, kanal, dezimal, s.fest);
        zeilen.append(zeile);
    }
    return true;
}

QVariantMap Database::spsExportErzeugen(int projektId, const QString &konfigJson, int maxZeilen)
{
    QVariantMap res;
    res["text"] = QString();
    res["zeilen"] = 0;
    res["fehler"] = QString();

    QStringList titel;
    QList<QStringList> daten;
    QString fehler;
    if (!spsExportZeilen(projektId, konfigJson, titel, daten, fehler)) {
        res["fehler"] = fehler;
        return res;
    }

    const QJsonObject k = QJsonDocument::fromJson(konfigJson.toUtf8()).object();
    QString trenn = k.value("trennzeichen").toString(QStringLiteral(";"));
    if (trenn == QLatin1String("\\t")) trenn = QStringLiteral("\t");
    if (trenn.isEmpty()) trenn = QStringLiteral(";");
    const bool immer = k.value("anfuehrung").toString(QStringLiteral("immer")) != QLatin1String("bei_bedarf");

    auto zeileZuCsv = [&](const QStringList &z) {
        QStringList out;
        for (const QString &c : z) out << csvFeld(c, trenn, immer);
        return out.join(trenn);
    };

    QStringList zeilen;
    if (k.value("kopfzeile").toBool(true)) zeilen << zeileZuCsv(titel);
    for (int i = 0; i < daten.size(); ++i) {
        if (maxZeilen >= 0 && i >= maxZeilen) break;
        zeilen << zeileZuCsv(daten[i]);
    }
    res["text"]   = zeilen.join(QLatin1Char('\n')) + QLatin1Char('\n');
    res["zeilen"] = daten.size();
    return res;
}

bool Database::spsExportPdfSpeichern(int projektId, const QString &projektName,
                                     const QString &pfad, const QString &konfigJson)
{
    QStringList titel;
    QList<QStringList> daten;
    QString fehler;
    if (!spsExportZeilen(projektId, konfigJson, titel, daten, fehler)) {
        qCWarning(lcDb) << "spsExportPdfSpeichern:" << fehler;
        return false;
    }
    QVariantList zeilen;
    for (const QStringList &z : daten) zeilen.append(QVariant(z));
    return listePdfSpeichern(QStringLiteral("SPS/PLS – I/O-Liste"), projektName, titel, zeilen, pfad);
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
    QFile file(CsvHelfer::lokalerPfad(pfad));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "spsExportCsvSpeichern: kann nicht öffnen:" << file.fileName();
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    if (QJsonDocument::fromJson(konfigJson.toUtf8()).object().value("bom").toBool(true))
        out << "\xEF\xBB\xBF";
    out << erg["text"].toString();
    file.close();
    qCInfo(lcDb) << "SPS/PLS-Export gespeichert:" << file.fileName() << "(" << erg["zeilen"].toInt() << "Zeilen)";
    return true;
}
