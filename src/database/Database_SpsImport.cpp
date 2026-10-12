// SPS-IMPORT-01: CSV-Import von SPS/PLS-Adresslisten (Bestandsanlagen).
// Gegenstück zum konfigurierbaren Export (Database_SpsExport.cpp): der Anwender ordnet
// die CSV-Spalten den Feldern zu (Auto-Erkennung über die Spaltentitel, damit eigene
// Exporte ohne Zuordnung zurückgelesen werden), Strömling legt fehlende Racks/Baugruppen
// an und Kanäle neu an bzw. füllt vorhandene auf. Zuerst wird ein Plan erstellt
// (Trockenlauf = Vorschau), danach in einer Transaktion ausgeführt – beide Wege
// benutzen dieselbe Planung, damit Vorschau und Ergebnis nicht auseinanderlaufen.
//
// Konfiguration (JSON):
//   { trennzeichen:""|";"|","|"\t"|"|", kopfzeile:true, dezimal:",",
//     spalten:["rack","slot",...,""],             // je CSV-Spalte ein Feld oder ""
//     systemStandard:"PLS"|"SPS",                 // wenn keine System-Spalte/bekanntes Rack
//     vorhandene:"ueberspringen"|"auffuellen"|"ueberschreiben",
//     hardwareAnlegen:true }
#include "Database.h"
#include "Database_SpsAdressen.h"
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QMap>
#include <algorithm>

namespace {

// ── CSV ───────────────────────────────────────────────────────────
QChar trennErkennen(const QString &text)
{
    const QString kandidaten = QStringLiteral(";,\t|");
    int zaehler[4] = {0, 0, 0, 0};
    bool inQuote = false;
    for (const QChar c : text) {
        if (c == u'"') inQuote = !inQuote;
        else if (!inQuote && (c == u'\n' || c == u'\r')) break;
        else if (!inQuote) {
            const int i = kandidaten.indexOf(c);
            if (i >= 0) ++zaehler[i];
        }
    }
    int best = 0;
    for (int i = 1; i < 4; ++i) if (zaehler[i] > zaehler[best]) best = i;
    return zaehler[best] > 0 ? kandidaten[best] : QChar(u';');
}

QList<QStringList> csvParsen(const QString &t, QChar d)
{
    QList<QStringList> rows;
    QStringList row;
    QString feld;
    bool inQuote = false, feldGesetzt = false;
    auto feldEnde = [&]() { row << feld; feld.clear(); feldGesetzt = false; };
    auto zeileEnde = [&]() {
        feldEnde();
        bool leer = true;
        for (const QString &s : row) if (!s.trimmed().isEmpty()) { leer = false; break; }
        if (!leer) rows << row;
        row.clear();
    };
    for (int i = 0; i < t.size(); ++i) {
        const QChar c = t[i];
        if (inQuote) {
            if (c == u'"') {
                if (i + 1 < t.size() && t[i + 1] == u'"') { feld += u'"'; ++i; }
                else inQuote = false;
            } else feld += c;
        } else if (c == u'"' && !feldGesetzt) { inQuote = true; feldGesetzt = true; }
        else if (c == d) feldEnde();
        else if (c == u'\n') zeileEnde();
        else if (c == u'\r') { if (i + 1 < t.size() && t[i + 1] == u'\n') ++i; zeileEnde(); }
        else { feld += c; feldGesetzt = true; }
    }
    if (feldGesetzt || !feld.isEmpty() || !row.isEmpty()) zeileEnde();
    return rows;
}

bool dateiLesen(const QString &pfad, QString &text, QString &fehler)
{
    QString lokal = QUrl(pfad).toLocalFile();
    if (lokal.isEmpty()) lokal = pfad;
    QFile f(lokal);
    if (!f.open(QIODevice::ReadOnly)) { fehler = QStringLiteral("Datei kann nicht geöffnet werden"); return false; }
    QByteArray b = f.readAll();
    if (b.startsWith("\xEF\xBB\xBF")) b.remove(0, 3);
    text = QString::fromUtf8(b);
    if (text.contains(QChar(0xFFFD))) text = QString::fromLatin1(b);   // Windows-Export (Latin-1/CP1252)
    return true;
}

QString norm(const QString &s)
{
    QString r;
    for (const QChar c : s.toLower()) if (c.isLetterOrNumber()) r += c;
    return r;
}

// Auto-Zuordnung Spaltentitel → Feld (Katalogtitel, Feldschlüssel und gängige Namen)
QString feldVorschlag(const QString &kopf, const QVariantList &katalog)
{
    const QString n = norm(kopf);
    if (n.isEmpty()) return QString();
    for (const QVariant &kv : katalog) {
        const QVariantMap k = kv.toMap();
        if (norm(k["titel"].toString()) == n || norm(k["feld"].toString()) == n)
            return k["feld"].toString();
    }
    static const QMap<QString, QString> alias = {
        {"tag", "variablenname"}, {"variable", "variablenname"}, {"variablenname", "variablenname"},
        {"symbol", "variablenname"}, {"bezeichnung", "variablenname"}, {"name", "variablenname"},
        {"beschreibung", "kommentar"}, {"comment", "kommentar"}, {"bemerkung", "kommentar"},
        {"unit", "einheit"}, {"channel", "kanal"}, {"kanalnr", "kanal"}, {"address", "adresse"},
        {"racknr", "rack"}, {"steckplatz", "slot"}, {"baugruppentyp", "baugruppen_typ"},
        {"typ", "signal"}, {"artikelnr", "artikel_nr"}, {"artikelnummer", "artikel_nr"},
        {"min", "bereich_min"}, {"max", "bereich_max"}, {"bereichmin", "bereich_min"},
        {"bereichmax", "bereich_max"}, {"ll", "alarm_ll"}, {"lo", "alarm_lo"},
        {"hi", "alarm_hi"}, {"hh", "alarm_hh"}, {"hart", "hart_adresse"},
    };
    return alias.value(n);
}

// ── Adressen ──────────────────────────────────────────────────────
// SPS (Siemens-/IEC-Schreibweise): E0.0, A1.3, M10.5, EW64, MD200, %IX0.0, %QW4, %MW100, T5
bool spsAdresseParsen(const QString &roh, QString &typ, QString &datentyp, int &byteNr, int &bitNr)
{
    const QString a = roh.trimmed().toUpper();
    auto typAbbilden = [](QChar c) -> QString {
        if (c == u'I' || c == u'E') return QStringLiteral("E");
        if (c == u'Q' || c == u'A') return QStringLiteral("A");
        return QString(c);
    };
    static const QRegularExpression iec(QStringLiteral("^%([IQM])([XBWD])(\\d+)(?:\\.(\\d))?$"));
    static const QRegularExpression sie(QStringLiteral("^([EAMIQ])([BWD])?(\\d+)(?:\\.(\\d))?$"));
    static const QRegularExpression tz(QStringLiteral("^([TZ])(\\d+)$"));

    QRegularExpressionMatch m = iec.match(a);
    if (m.hasMatch()) {
        typ = typAbbilden(m.captured(1)[0]);
        const QChar g = m.captured(2)[0];
        byteNr = m.captured(3).toInt();
        if (g == u'X') {
            if (m.captured(4).isEmpty()) return false;
            datentyp = QStringLiteral("BOOL"); bitNr = m.captured(4).toInt();
        } else {
            datentyp = g == u'B' ? QStringLiteral("BYTE") : g == u'W' ? QStringLiteral("WORD") : QStringLiteral("DWORD");
            bitNr = -1;
        }
        return true;
    }
    m = sie.match(a);
    if (m.hasMatch()) {
        typ = typAbbilden(m.captured(1)[0]);
        byteNr = m.captured(3).toInt();
        if (!m.captured(2).isEmpty()) {
            const QChar g = m.captured(2)[0];
            datentyp = g == u'B' ? QStringLiteral("BYTE") : g == u'W' ? QStringLiteral("WORD") : QStringLiteral("DWORD");
            bitNr = -1;
        } else {
            if (m.captured(4).isEmpty()) return false;   // "E0" ohne Bit/Größe ist mehrdeutig
            datentyp = QStringLiteral("BOOL"); bitNr = m.captured(4).toInt();
        }
        return true;
    }
    m = tz.match(a);
    if (m.hasMatch()) {
        typ = m.captured(1); datentyp = QStringLiteral("BOOL"); byteNr = m.captured(2).toInt(); bitNr = 0;
        return true;
    }
    return false;
}

// PLS: "R1 S3 K12", "R1/S3/K12" (K 1-basiert)
bool plsAdresseParsen(const QString &roh, int &rack, int &slot, int &kanal)
{
    static const QRegularExpression re(QStringLiteral("^R(\\d+)[\\s/\\-]+S(\\d+)[\\s/\\-]+K(\\d+)$"),
                                       QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = re.match(roh.trimmed());
    if (!m.hasMatch()) return false;
    rack = m.captured(1).toInt(); slot = m.captured(2).toInt(); kanal = m.captured(3).toInt();
    return true;
}

const QSet<QString> kDatentypen = {"BOOL", "BYTE", "WORD", "DWORD", "REAL", "INT", "DINT"};
const QSet<QString> kBgTypen    = {"CPU", "PS", "DI", "DO", "DIO", "AI", "AO", "AIO", "CP", "FM", "andere"};

bool istIo(const QString &t) { return t == "DI" || t == "DO" || t == "AI" || t == "AO"; }

struct Zeile {
    int     nr = 0;                 // Datenzeile (1-basiert, ohne Kopfzeile)
    QString system;                 // leer = noch offen
    int     rackNr = 0;
    bool    hatSlot = false;
    int     slot = 0;
    int     kanalNr = -1;           // 0-basiert, -1 = unbekannt
    QString rackBez, hersteller, bgBez, bgTyp, artikel, signal;
    QString adressTyp, datentyp;
    int     byteNr = 0, bitNr = 0;
    bool    hatAdresse = false;     // SPS-Byte/Bit/Typ bekannt
    QVariantMap felder;             // sps_kanal-Felder (variablenname, kommentar, pls_*)
};

} // namespace

// ═════════════════════════════════════════════════════════════════
QVariantMap Database::spsImportLesen(const QString &pfad)
{
    QVariantMap r;
    QString text, fehler;
    if (!dateiLesen(pfad, text, fehler)) { r["fehler"] = fehler; return r; }
    const QChar d = trennErkennen(text);
    const QList<QStringList> rows = csvParsen(text, d);
    if (rows.isEmpty()) { r["fehler"] = QStringLiteral("Datei ist leer"); return r; }

    const QVariantList kat = spsExportFeldKatalog();
    QStringList vorschlag;
    for (const QString &h : rows[0]) vorschlag << feldVorschlag(h, kat);

    QVariantList beispiel;
    for (int i = 1; i < rows.size() && i <= 5; ++i) beispiel.append(QVariant(rows[i]));

    r["fehler"]       = QString();
    r["trennzeichen"] = d == u'\t' ? QStringLiteral("\t") : QString(d);
    r["kopf"]         = rows[0];
    r["zeilen"]       = rows.size() - 1;
    r["beispiel"]     = beispiel;
    r["vorschlag"]    = vorschlag;
    return r;
}

// Gemeinsame Planung für Trockenlauf und Ausführung. ausfuehren=false schreibt nichts.
QVariantMap Database::spsImportPlanen(int projektId, const QString &pfad, const QString &konfigJson,
                                      bool ausfuehren)
{
    QVariantMap bericht;
    QVariantList meldungen;
    int nFehler = 0;
    auto meldung = [&](int zeile, const QString &text, bool fehler) {
        if (fehler) ++nFehler;
        if (meldungen.size() < 300) {
            QVariantMap m; m["zeile"] = zeile; m["text"] = text; m["fehler"] = fehler;
            meldungen.append(m);
        }
    };
    auto abbruch = [&](const QString &f) {
        bericht["fehler"] = f;
        return bericht;
    };
    bericht["fehler"] = QString();

    const QJsonObject k = QJsonDocument::fromJson(konfigJson.toUtf8()).object();
    if (k.isEmpty()) return abbruch(QStringLiteral("Ungültige Import-Konfiguration"));

    QString text, fehler;
    if (!dateiLesen(pfad, text, fehler)) return abbruch(fehler);
    QString trennStr = k.value("trennzeichen").toString();
    QChar d = trennStr.isEmpty() ? trennErkennen(text) : trennStr[0];
    const QList<QStringList> rows = csvParsen(text, d);
    if (rows.isEmpty()) return abbruch(QStringLiteral("Datei ist leer"));

    const bool kopf = k.value("kopfzeile").toBool(true);
    const QString dezimal = k.value("dezimal").toString(QStringLiteral(","));
    const QString sysStd  = k.value("systemStandard").toString(QStringLiteral("PLS")) == QLatin1String("SPS")
                            ? QStringLiteral("SPS") : QStringLiteral("PLS");
    const QString modus   = k.value("vorhandene").toString(QStringLiteral("auffuellen"));
    const bool hwAnlegen  = k.value("hardwareAnlegen").toBool(true);

    QStringList spalten;
    for (const QJsonValue &v : k.value("spalten").toArray()) spalten << v.toString();
    if (spalten.isEmpty()) return abbruch(QStringLiteral("Keine Spaltenzuordnung"));

    // ── Bestand ──
    struct RackBest { int id; QString system; };
    struct BgBest   { int id; QString typ, bez, artikel; int kanaele, start; };
    QMap<int, RackBest> racksBest;                    // rack_nr → ...
    QMap<QPair<int,int>, BgBest> bgBest;              // (rack_nr, slot) → ...
    for (const QVariant &rv : spsRackListe(projektId)) {
        const QVariantMap rm = rv.toMap();
        racksBest[rm["rack_nr"].toInt()] = {rm["id"].toInt(), rm["system_typ"].toString()};
        for (const QVariant &bv : spsBaugruppeListe(rm["id"].toInt())) {
            const QVariantMap bm = bv.toMap();
            bgBest[{rm["rack_nr"].toInt(), bm["slot"].toInt()}] =
                {bm["id"].toInt(), bm["typ"].toString(), bm["bezeichnung"].toString(),
                 bm["artikel_nr"].toString(), bm["kanaele"].toInt(), bm["adress_byte_start"].toInt()};
        }
    }
    const QVariantList kanalBest = spsKanalListe(projektId);

    // ── Zeilen parsen ──
    auto feldIdx = [&](const QString &feld) { return spalten.indexOf(feld); };
    auto zelle = [&](const QStringList &row, const QString &feld) {
        const int i = feldIdx(feld);
        return (i >= 0 && i < row.size()) ? row[i].trimmed() : QString();
    };
    auto zahlParsen = [&](QString s, bool &ok) {
        s.remove(QLatin1Char(' '));
        if (dezimal == QLatin1String(",")) s.replace(QLatin1Char(','), QLatin1Char('.'));
        return s.toDouble(&ok);
    };

    QList<Zeile> zeilen;
    const int start = kopf ? 1 : 0;
    for (int ri = start; ri < rows.size(); ++ri) {
        const QStringList &row = rows[ri];
        Zeile z;
        z.nr = ri - start + 1;
        bool zeileOk = true;
        auto fehlerZ = [&](const QString &t) { meldung(z.nr, t, true); zeileOk = false; };

        // Rack / System
        z.system = zelle(row, "system").toUpper();
        if (z.system != "SPS" && z.system != "PLS") z.system.clear();
        const QString adrRoh = zelle(row, "adresse");
        int pr = 0, ps = 0, pk = 0;
        const bool plsAdr = !adrRoh.isEmpty() && plsAdresseParsen(adrRoh, pr, ps, pk);
        if (z.system.isEmpty() && plsAdr) z.system = QStringLiteral("PLS");

        const QString rackStr = zelle(row, "rack");
        if (!rackStr.isEmpty()) {
            bool ok = false; z.rackNr = rackStr.toInt(&ok);
            if (!ok) { fehlerZ(QStringLiteral("Rack \"%1\" ist keine Zahl").arg(rackStr)); continue; }
        } else if (plsAdr) z.rackNr = pr;
        if (z.system.isEmpty()) z.system = racksBest.contains(z.rackNr) ? racksBest[z.rackNr].system : sysStd;

        // Slot / Kanal
        const QString slotStr = zelle(row, "slot");
        if (!slotStr.isEmpty()) {
            bool ok = false; z.slot = slotStr.toInt(&ok); z.hatSlot = ok;
            if (!ok) { fehlerZ(QStringLiteral("Slot \"%1\" ist keine Zahl").arg(slotStr)); continue; }
        } else if (plsAdr) { z.slot = ps; z.hatSlot = true; }
        const QString kanalStr = zelle(row, "kanal");
        if (!kanalStr.isEmpty()) {
            bool ok = false; const int kn = kanalStr.toInt(&ok);
            if (!ok || kn < 1) { fehlerZ(QStringLiteral("Kanal \"%1\" ist keine Zahl ≥ 1").arg(kanalStr)); continue; }
            z.kanalNr = kn - 1;
        } else if (plsAdr) z.kanalNr = pk - 1;

        // SPS-Adresse
        z.adressTyp = zelle(row, "adress_typ").toUpper();
        if (z.adressTyp == "I") z.adressTyp = "E";
        if (z.adressTyp == "Q") z.adressTyp = "A";
        z.datentyp  = zelle(row, "datentyp").toUpper();
        if (!z.datentyp.isEmpty() && !kDatentypen.contains(z.datentyp)) {
            meldung(z.nr, QStringLiteral("Unbekannter Datentyp \"%1\" ignoriert").arg(z.datentyp), false);
            z.datentyp.clear();
        }
        if (z.system == "SPS") {
            QString t, dt; int by = 0, bi = 0;
            if (!adrRoh.isEmpty() && spsAdresseParsen(adrRoh, t, dt, by, bi)) {
                if (z.adressTyp.isEmpty()) z.adressTyp = t;
                if (z.datentyp.isEmpty())  z.datentyp = dt;
                z.byteNr = by; z.bitNr = bi; z.hatAdresse = true;
            }
            const QString byteS = zelle(row, "byte_nr"), bitS = zelle(row, "bit_nr");
            if (!byteS.isEmpty()) {
                bool ok = false; z.byteNr = byteS.toInt(&ok);
                if (!ok) { fehlerZ(QStringLiteral("Byte \"%1\" ist keine Zahl").arg(byteS)); continue; }
                z.hatAdresse = true;
                z.bitNr = -1;
            }
            if (!bitS.isEmpty()) {
                bool ok = false; z.bitNr = bitS.toInt(&ok);
                if (!ok) { fehlerZ(QStringLiteral("Bit \"%1\" ist keine Zahl").arg(bitS)); continue; }
            }
            if (z.datentyp.isEmpty() && z.hatAdresse) z.datentyp = z.bitNr >= 0 ? QStringLiteral("BOOL") : QStringLiteral("WORD");
            if (z.hatAdresse && z.datentyp == "BOOL" && z.bitNr < 0) z.bitNr = 0;
        } else {
            if (z.datentyp.isEmpty()) z.datentyp = QStringLiteral("REAL");
        }

        // Typen / Bezeichnungen
        z.bgTyp = zelle(row, "baugruppen_typ");
        if (!z.bgTyp.isEmpty()) {
            z.bgTyp = z.bgTyp.toUpper() == "ANDERE" ? QStringLiteral("andere") : z.bgTyp.toUpper();
            if (!kBgTypen.contains(z.bgTyp)) {
                meldung(z.nr, QStringLiteral("Unbekannter Baugruppen-Typ \"%1\" ignoriert").arg(z.bgTyp), false);
                z.bgTyp.clear();
            }
        }
        z.signal    = zelle(row, "signal").toUpper();
        if (!istIo(z.signal)) z.signal.clear();
        z.bgBez     = zelle(row, "baugruppe");
        z.artikel   = zelle(row, "artikel_nr");
        z.rackBez   = zelle(row, "rack_bezeichnung");
        z.hersteller = zelle(row, "hersteller");

        // Kanalfelder
        auto textFeld = [&](const QString &feld, const QString &dbFeld) {
            const QString s = zelle(row, feld);
            if (!s.isEmpty()) z.felder[dbFeld] = s;
        };
        textFeld("variablenname", "variablenname");
        textFeld("kommentar", "kommentar");
        textFeld("einheit", "pls_einheit");
        textFeld("protokoll", "pls_protokoll");
        const QList<QPair<QString, QString>> zahlen = {
            {"bereich_min", "pls_bereich_min"}, {"bereich_max", "pls_bereich_max"},
            {"alarm_ll", "pls_alarm_ll"}, {"alarm_lo", "pls_alarm_lo"},
            {"alarm_hi", "pls_alarm_hi"}, {"alarm_hh", "pls_alarm_hh"}};
        for (const auto &p : zahlen) {
            const QString s = zelle(row, p.first);
            if (s.isEmpty()) continue;
            bool ok = false; const double v = zahlParsen(s, ok);
            if (ok) z.felder[p.second] = v;
            else meldung(z.nr, QStringLiteral("Zahlenwert \"%1\" (%2) ignoriert").arg(s, p.first), false);
        }
        const QString hart = zelle(row, "hart_adresse");
        if (!hart.isEmpty()) { bool ok = false; const int h = hart.toInt(&ok); if (ok) z.felder["pls_hart_adresse"] = h; }

        // Mindestangaben
        if (z.system == "PLS") {
            if (!z.hatSlot) { fehlerZ(QStringLiteral("PLS-Kanal ohne Slot")); continue; }
            if (z.kanalNr < 0) { fehlerZ(QStringLiteral("PLS-Kanal ohne Kanal-Nr.")); continue; }
        } else {
            if (!z.hatAdresse) { fehlerZ(QStringLiteral("SPS-Adresse fehlt oder nicht lesbar (\"%1\")").arg(adrRoh)); continue; }
            if (z.adressTyp.isEmpty()) { fehlerZ(QStringLiteral("SPS-Adress-Typ (E/A/M/T/Z) fehlt")); continue; }
            const bool ioTyp = z.adressTyp == "E" || z.adressTyp == "A";
            if (ioTyp && !z.hatSlot) {
                // E/A-Kanal ohne Slot: keine Baugruppe zuordenbar → ohne Baugruppe anlegen
                meldung(z.nr, QStringLiteral("Kein Slot – Kanal wird ohne Baugruppe angelegt"), false);
            }
        }
        if (zeileOk) zeilen.append(z);
    }

    // ── Planung ──
    struct RackPlan { int nr; QString system, bez, hersteller; int id; bool neu; };
    struct BgPlan   { int rackNr, slot; QString bez, artikel, typ; QSet<QString> sigs; QString explTyp;
                      int kanaele = 0, start = -1, id; bool neu; };
    struct KanalPlan { Zeile z; int bgIdx = -1; int existId = 0; QString aktion; };   // neu|aufUpdate

    QMap<int, RackPlan> racksPlan;
    QMap<QPair<int,int>, int> bgIndex;
    QList<BgPlan> bgs;
    QList<KanalPlan> kanaele;
    QList<SpsAdressen::Kanal> bekannt = SpsAdressen::laden(m_db, projektId);
    QMap<int, QVariantMap> kanalById;
    for (const QVariant &kv : kanalBest) kanalById[kv.toMap()["id"].toInt()] = kv.toMap();
    int synthId = -1000;
    QMap<int, int> rackSynth;           // rack_nr → synthetische rackId für neue Racks
    QMap<int, int> bgSynth;             // bgs-Index → synthetische baugruppeId

    int nNeuK = 0, nUpd = 0, nSkip = 0, nAbw = 0;

    // Kanal-Vorschau für die Oberfläche: je CSV-Zeile die geplante Aktion (neu/update/skip)
    QVariantList kanalVorschau;
    auto feldTitel = [](const QString &f) -> QString {
        static const QMap<QString, QString> m = {
            {"variablenname", "Variable"}, {"kommentar", "Kommentar"},
            {"pls_einheit", "Einheit"}, {"pls_protokoll", "Protokoll"},
            {"pls_bereich_min", "Bereich Min"}, {"pls_bereich_max", "Bereich Max"},
            {"pls_alarm_ll", "Alarm LL"}, {"pls_alarm_lo", "Alarm LO"},
            {"pls_alarm_hi", "Alarm HI"}, {"pls_alarm_hh", "Alarm HH"},
            {"pls_hart_adresse", "HART-Adresse"}};
        return m.value(f, f);
    };
    auto vorschau = [&](const Zeile &z, const QString &aktion, const QString &detail) {
        QString adr;
        if (z.system == "PLS" || z.adressTyp.isEmpty())
            adr = QStringLiteral("R%1 S%2 K%3").arg(z.rackNr).arg(z.hatSlot ? z.slot : 0)
                      .arg(z.kanalNr >= 0 ? z.kanalNr + 1 : 0);
        else
            adr = z.adressTyp + QLatin1Char(' ') + QString::number(z.byteNr)
                  + (z.bitNr >= 0 ? QStringLiteral(".%1").arg(z.bitNr) : QString());
        QVariantMap v;
        v["zeile"]  = z.nr;
        v["system"] = z.system;
        v["adresse"] = adr;
        v["variable"] = z.felder.value("variablenname").toString();
        v["aktion"] = aktion;
        v["detail"] = detail;
        kanalVorschau.append(v);
    };

    auto signalVon = [&](const Zeile &z) -> QString {
        if (!z.signal.isEmpty()) return z.signal;
        if (z.bgTyp == "DI" || z.bgTyp == "DO" || z.bgTyp == "AI" || z.bgTyp == "AO") return z.bgTyp;
        const bool bo = z.datentyp == "BOOL";
        if (z.system == "SPS") {
            if (z.adressTyp != "E" && z.adressTyp != "A") return QString();
            return bo ? (z.adressTyp == "E" ? "DI" : "DO") : (z.adressTyp == "E" ? "AI" : "AO");
        }
        return bo ? QStringLiteral("DI") : QStringLiteral("AI");
    };

    for (Zeile z : zeilen) {
        // Rack
        if (!racksPlan.contains(z.rackNr)) {
            RackPlan rp{z.rackNr, z.system, z.rackBez, z.hersteller, 0, false};
            if (racksBest.contains(z.rackNr)) { rp.id = racksBest[z.rackNr].id; rp.system = racksBest[z.rackNr].system; }
            else if (!hwAnlegen) {
                meldung(z.nr, QStringLiteral("Rack %1 existiert nicht (Hardware-Anlegen aus)").arg(z.rackNr), true);
                continue;
            } else { rp.neu = true; rp.id = 0; rackSynth[z.rackNr] = synthId--; }
            racksPlan[z.rackNr] = rp;
        }
        const RackPlan &rp = racksPlan[z.rackNr];
        if (rp.system != z.system) {
            meldung(z.nr, QStringLiteral("Rack %1 ist %2 – Zeile als %2 gewertet").arg(z.rackNr).arg(rp.system), false);
            z.system = rp.system;
            if (z.system == "PLS" && (z.kanalNr < 0 || !z.hatSlot)) {
                meldung(z.nr, QStringLiteral("PLS-Rack, aber Slot/Kanal fehlen"), true); continue;
            }
            if (z.system == "SPS" && !z.hatAdresse) {
                meldung(z.nr, QStringLiteral("SPS-Rack, aber Adresse fehlt"), true); continue;
            }
        }
        const int rackId = rp.neu ? rackSynth[z.rackNr] : rp.id;

        // Baugruppe
        int bi = -1;
        const bool ioKanal = z.system == "PLS" || z.adressTyp == "E" || z.adressTyp == "A";
        if (z.hatSlot && ioKanal) {
            const QPair<int,int> key{z.rackNr, z.slot};
            if (!bgIndex.contains(key)) {
                BgPlan bp; bp.rackNr = z.rackNr; bp.slot = z.slot; bp.bez = z.bgBez; bp.artikel = z.artikel;
                if (bgBest.contains(key)) {
                    bp.id = bgBest[key].id; bp.neu = false; bp.typ = bgBest[key].typ;
                    bp.kanaele = bgBest[key].kanaele; bp.start = bgBest[key].start;
                } else if (!hwAnlegen) {
                    meldung(z.nr, QStringLiteral("Baugruppe R%1 S%2 existiert nicht (Hardware-Anlegen aus)").arg(z.rackNr).arg(z.slot), true);
                    continue;
                } else { bp.id = 0; bp.neu = true; }
                bgIndex[key] = bgs.size();
                bgSynth[bgs.size()] = bp.neu ? synthId-- : bp.id;
                bgs.append(bp);
            }
            bi = bgIndex[key];
            BgPlan &bp = bgs[bi];
            if (bp.neu) {
                if (bp.bez.isEmpty()) bp.bez = z.bgBez;
                if (bp.artikel.isEmpty()) bp.artikel = z.artikel;
                if (!z.bgTyp.isEmpty() && bp.explTyp.isEmpty()) bp.explTyp = z.bgTyp;
                const QString s = signalVon(z);
                if (!s.isEmpty()) bp.sigs.insert(s);
            }
        }
        const int bgId = bi >= 0 ? bgSynth[bi] : 0;

        // Adress-Kanal für die Konfliktprüfung
        SpsAdressen::Kanal c;
        c.id = 0; c.baugruppeId = bgId; c.rackId = bi >= 0 ? rackId : 0;
        c.pls = z.system == "PLS";
        c.adressTyp = z.adressTyp; c.byteNr = z.byteNr; c.bitNr = z.bitNr; c.datentyp = z.datentyp;
        c.kanalNr = z.kanalNr;
        // Kanäle ohne Slot: PLS nicht möglich (oben geprüft); SPS-Merker etc. im Bereich "ohne Rack"

        if (c.pls || z.adressTyp.isEmpty() == false) {
            // Gleiche Identität im Bestand/Plan?
            int exakt = -1, ueberlapp = -1;
            for (int j = 0; j < bekannt.size(); ++j) {
                if (!SpsAdressen::ueberlappen(c, bekannt[j])) continue;
                const SpsAdressen::Kanal &o = bekannt[j];
                const bool gleich = c.pls ? (o.baugruppeId == c.baugruppeId && o.kanalNr == c.kanalNr)
                                          : (o.adressTyp == c.adressTyp && o.byteNr == c.byteNr
                                             && o.bitNr == c.bitNr && o.datentyp == c.datentyp);
                if (gleich) { exakt = j; break; }
                if (ueberlapp < 0) ueberlapp = j;
            }
            if (exakt >= 0) {
                const int oid = bekannt[exakt].id;
                if (oid <= 0) { meldung(z.nr, QStringLiteral("Adresse kommt in der CSV doppelt vor"), true); continue; }
                // vorhandener Kanal → je nach Modus
                if (modus == "ueberspringen") {
                    ++nSkip;
                    vorschau(z, QStringLiteral("skip"), QStringLiteral("vorhanden – wird übersprungen"));
                    continue;
                }
                const QVariantMap kb = kanalById.value(oid);
                QVariantMap aenderung;
                QStringList abweichungen;   // Modus "auffuellen": Wert im Programm vorhanden, CSV weicht ab
                for (auto it = z.felder.constBegin(); it != z.felder.constEnd(); ++it) {
                    const QVariant alt = kb.value(it.key());
                    const bool altLeer = alt.isNull() || !alt.isValid() || alt.toString().isEmpty();
                    if (modus == "auffuellen" && !altLeer) {
                        if (alt.toString() != it.value().toString())
                            abweichungen << QStringLiteral("%1: Programm \"%2\" ≠ CSV \"%3\"")
                                                .arg(feldTitel(it.key()), alt.toString(), it.value().toString());
                        continue;
                    }
                    if (alt.toString() == it.value().toString()) continue;
                    aenderung[it.key()] = it.value();
                }
                const QString abwText = abweichungen.isEmpty() ? QString()
                    : QStringLiteral("CSV weicht ab, wird im Modus \"Nur leere Felder auffüllen\" nicht übernommen – %1")
                          .arg(abweichungen.join(QStringLiteral("; ")));
                if (aenderung.isEmpty()) {
                    ++nSkip;
                    if (!abweichungen.isEmpty()) {
                        ++nAbw;
                        vorschau(z, QStringLiteral("abweichung"), abwText);
                    } else {
                        vorschau(z, QStringLiteral("skip"), QStringLiteral("unverändert"));
                    }
                    continue;
                }
                {
                    QStringList d;
                    for (auto it = aenderung.constBegin(); it != aenderung.constEnd(); ++it) {
                        const QString alt = kb.value(it.key()).toString();
                        d << QStringLiteral("%1: %2 → %3").arg(feldTitel(it.key()),
                                 alt.isEmpty() ? QStringLiteral("(leer)") : alt, it.value().toString());
                    }
                    if (!abwText.isEmpty()) { d << abwText; ++nAbw; }
                    vorschau(z, QStringLiteral("update"), d.join(QStringLiteral("; ")));
                }
                KanalPlan kp; kp.z = z; kp.z.felder = aenderung; kp.existId = oid; kp.aktion = "update";
                kanaele.append(kp);
                ++nUpd;
                continue;
            }
            if (ueberlapp >= 0) {
                meldung(z.nr, QStringLiteral("Adresse überlappt mit einem vorhandenen Kanal (Adresse bereits belegt)"), true);
                continue;
            }
        }

        vorschau(z, QStringLiteral("neu"), QString());
        KanalPlan kp; kp.z = z; kp.bgIdx = bi; kp.aktion = "neu";
        kanaele.append(kp);
        SpsAdressen::Kanal merk = c;
        merk.id = -(kanaele.size());          // negativ: stammt aus der CSV
        bekannt.append(merk);
        ++nNeuK;
        if (bi >= 0) {
            BgPlan &bp = bgs[bi];
            if (bp.neu || true) {
                bp.kanaele = std::max(bp.kanaele, z.system == "PLS" ? z.kanalNr + 1 : 0);
                if (z.system != "PLS") {
                    // Kanalzahl bei SPS = Anzahl importierter E/A-Kanäle der Baugruppe (wird unten gezählt)
                    if (bp.start < 0 || z.byteNr < bp.start) if (bp.neu) bp.start = z.byteNr;
                }
            }
        }
    }

    // SPS-Kanalzahl je neuer Baugruppe: Anzahl der Kanalzeilen
    {
        QMap<int, int> proBg;
        for (const KanalPlan &kp : kanaele)
            if (kp.aktion == "neu" && kp.bgIdx >= 0 && kp.z.system != "PLS") ++proBg[kp.bgIdx];
        for (auto it = proBg.constBegin(); it != proBg.constEnd(); ++it)
            bgs[it.key()].kanaele = std::max(bgs[it.key()].kanaele, it.value());
    }

    // Baugruppen-Typ je neuer Baugruppe bestimmen
    QStringList typHinweise;
    for (int i = 0; i < bgs.size(); ++i) {
        BgPlan &bp = bgs[i];
        if (!bp.neu) continue;
        if (!bp.explTyp.isEmpty()) bp.typ = bp.explTyp;
        else if (bp.sigs.size() == 1) bp.typ = *bp.sigs.begin();
        else if (bp.sigs == QSet<QString>{"DI", "DO"}) bp.typ = "DIO";
        else if (bp.sigs == QSet<QString>{"AI", "AO"}) bp.typ = "AIO";
        else if (bp.sigs.isEmpty()) bp.typ = "andere";
        else {
            QStringList s = bp.sigs.values(); std::sort(s.begin(), s.end());
            bp.typ = s.first();
            typHinweise << QStringLiteral("R%1 S%2: gemischte Signal-Arten (%3) – als %4 angelegt")
                               .arg(bp.rackNr).arg(bp.slot).arg(s.join("/")).arg(bp.typ);
        }
        if (bp.bez.isEmpty()) bp.bez = QStringLiteral("%1 Slot %2").arg(bp.typ).arg(bp.slot);
    }
    for (const QString &t : typHinweise) meldung(0, t, false);

    int nNeuR = 0, nNeuB = 0;
    for (const RackPlan &rp : racksPlan) if (rp.neu) ++nNeuR;
    for (const BgPlan &bp : bgs) if (bp.neu) ++nNeuB;

    bericht["neueRacks"]        = nNeuR;
    bericht["neueBaugruppen"]   = nNeuB;
    bericht["neueKanaele"]      = nNeuK;
    bericht["aktualisiert"]     = nUpd;
    bericht["uebersprungen"]    = nSkip;
    bericht["abweichend"]       = nAbw;
    bericht["fehlerhaft"]       = nFehler;
    bericht["zeilenGesamt"]     = zeilen.size() + 0;
    bericht["meldungen"]        = meldungen;
    bericht["kanalVorschau"]    = kanalVorschau;
    bericht["ausgefuehrt"]      = false;
    {
        // Rack-Nummern für die Oberfläche: neu angelegt / von Kanalimport oder Update betroffen
        QSet<int> neu, betr;
        for (const RackPlan &rp : racksPlan) if (rp.neu) neu.insert(rp.nr);
        for (const KanalPlan &kp : kanaele) betr.insert(kp.z.rackNr);
        QList<int> n = neu.values(), b = betr.values();
        std::sort(n.begin(), n.end());
        std::sort(b.begin(), b.end());
        QVariantList nl, bl;
        for (int v : n) nl << v;
        for (int v : b) bl << v;
        bericht["racksNeu"]       = nl;
        bericht["racksBetroffen"] = bl;
    }

    if (!ausfuehren) return bericht;
    if (nNeuR + nNeuB + nNeuK + nUpd == 0) return bericht;

    // ── Ausführung (eine Transaktion) ──
    if (!m_db.transaction()) { bericht["fehler"] = QStringLiteral("Transaktion nicht möglich"); return bericht; }
    bool ok = true;
    QString fehlerA;

    QMap<int, int> rackId;      // rack_nr → echte id
    for (auto it = racksPlan.constBegin(); it != racksPlan.constEnd() && ok; ++it) {
        const RackPlan &rp = it.value();
        if (!rp.neu) { rackId[rp.nr] = rp.id; continue; }
        const int id = spsRackAnlegen(projektId, rp.nr, rp.system,
                                      rp.bez.isEmpty() ? QStringLiteral("Rack %1").arg(rp.nr) : rp.bez,
                                      rp.hersteller);
        if (id <= 0) { ok = false; fehlerA = QStringLiteral("Rack %1 konnte nicht angelegt werden").arg(rp.nr); break; }
        rackId[rp.nr] = id;
    }
    QVector<int> bgReal(bgs.size(), 0);
    for (int i = 0; i < bgs.size() && ok; ++i) {
        const BgPlan &bp = bgs[i];
        if (!bp.neu) {
            bgReal[i] = bp.id;
            // Kanalzahl nur erhöhen (nie verkleinern)
            const BgBest &b = bgBest[{bp.rackNr, bp.slot}];
            if (bp.kanaele > b.kanaele)
                spsBaugruppeAktualisieren(b.id, bp.slot, b.typ, b.bez, b.artikel, bp.kanaele, "BOOL", b.start, "");
            continue;
        }
        const int id = spsBaugruppeAnlegen(rackId[bp.rackNr], bp.slot, bp.typ, bp.bez,
                                           std::max(bp.kanaele, 1), std::max(bp.start, 0));
        if (id <= 0) { ok = false; fehlerA = QStringLiteral("Baugruppe R%1 S%2 konnte nicht angelegt werden").arg(bp.rackNr).arg(bp.slot); break; }
        if (!bp.artikel.isEmpty())
            spsBaugruppeAktualisieren(id, bp.slot, bp.typ, bp.bez, bp.artikel, std::max(bp.kanaele, 1), "BOOL",
                                      std::max(bp.start, 0), "");
        bgReal[i] = id;
    }

    // SPS-Kanalnummern je Baugruppe fortlaufend (je Richtung nach Byte/Bit), falls nicht angegeben
    QMap<QPair<int, QString>, QList<int>> nummerierung;   // (bgIdx, E/A) → Kanalplan-Indizes
    for (int i = 0; i < kanaele.size(); ++i) {
        const KanalPlan &kp = kanaele[i];
        if (kp.aktion == "neu" && kp.bgIdx >= 0 && kp.z.system != "PLS" && kp.z.kanalNr < 0)
            nummerierung[{kp.bgIdx, kp.z.adressTyp}].append(i);
    }
    for (auto it = nummerierung.begin(); it != nummerierung.end(); ++it) {
        QList<int> &l = it.value();
        std::sort(l.begin(), l.end(), [&](int a, int b) {
            const Zeile &x = kanaele[a].z, &y = kanaele[b].z;
            return x.byteNr != y.byteNr ? x.byteNr < y.byteNr : x.bitNr < y.bitNr;
        });
        // Start hinter den vorhandenen Kanälen derselben Baugruppe/Richtung
        int offset = 0;
        const BgPlan &bp = bgs[it.key().first];
        if (!bp.neu) {
            for (const QVariant &kv : kanalBest) {
                const QVariantMap km = kv.toMap();
                if (km["baugruppe_id"].toInt() == bp.id && km["adress_typ"].toString() == it.key().second
                    && !km["kanal_nr"].isNull())
                    offset = std::max(offset, km["kanal_nr"].toInt() + 1);
            }
        }
        for (int n = 0; n < l.size(); ++n) kanaele[l[n]].z.kanalNr = offset + n;
    }

    for (const KanalPlan &kp : kanaele) {
        if (!ok) break;
        if (kp.aktion == "update") {
            if (!spsKanalAktualisieren(kp.existId, kp.z.felder)) {
                ok = false; fehlerA = QStringLiteral("Zeile %1: Kanal konnte nicht aktualisiert werden").arg(kp.z.nr);
            }
            continue;
        }
        const Zeile &z = kp.z;
        QString typ = z.adressTyp, dty = z.datentyp;
        if (z.system == "PLS") {
            QString s = z.signal;
            if (s.isEmpty() && kp.bgIdx >= 0) s = bgs[kp.bgIdx].typ;
            typ = (s == "AO" || s == "DO") ? "A" : "E";
        }
        const int bgId = kp.bgIdx >= 0 ? bgReal[kp.bgIdx] : 0;
        const int id = spsKanalAnlegen(projektId, bgId, z.kanalNr, typ,
                                       z.system == "PLS" ? 0 : z.byteNr, z.system == "PLS" ? 0 : z.bitNr, dty,
                                       z.felder.value("variablenname").toString(),
                                       z.felder.value("kommentar").toString());
        if (id <= 0) { ok = false; fehlerA = QStringLiteral("Zeile %1: Kanal konnte nicht angelegt werden (Adresse belegt?)").arg(z.nr); break; }
        QVariantMap rest = z.felder;
        rest.remove("variablenname"); rest.remove("kommentar");
        if (!rest.isEmpty() && !spsKanalAktualisieren(id, rest)) {
            ok = false; fehlerA = QStringLiteral("Zeile %1: Kanalfelder konnten nicht gespeichert werden").arg(z.nr);
        }
    }

    if (!ok) {
        m_db.rollback();
        bericht["fehler"] = fehlerA + QStringLiteral(" – nichts wurde importiert");
        return bericht;
    }
    if (!m_db.commit()) { m_db.rollback(); bericht["fehler"] = QStringLiteral("Commit fehlgeschlagen"); return bericht; }
    bericht["ausgefuehrt"] = true;
    qCInfo(lcDb) << "SPS-Import:" << nNeuR << "Racks," << nNeuB << "Baugruppen," << nNeuK << "Kanäle neu,"
                 << nUpd << "aktualisiert";
    return bericht;
}

QVariantMap Database::spsImportPruefen(int projektId, const QString &pfad, const QString &konfigJson)
{
    return spsImportPlanen(projektId, pfad, konfigJson, false);
}

QVariantMap Database::spsImportAusfuehren(int projektId, const QString &pfad, const QString &konfigJson)
{
    return spsImportPlanen(projektId, pfad, konfigJson, true);
}
