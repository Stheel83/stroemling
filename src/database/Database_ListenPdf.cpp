// ============================================================
// Database_ListenPdf.cpp – Zellenaufbereitung der Listen für PDF-Ausgaben (DOKU-PDF-05).
// Einzige Abbildung "Rohzeile -> PDF-Zellen": die Listen-Tabs rufen sie mit ihren gefilterten/
// sortierten Zeilen, das Dokumentations-PDF mit den ungefilterten (Standardansicht).
// ============================================================
#include "Database.h"

#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

namespace {

struct ListenInfo { const char *id; const char *titel; };
const ListenInfo kListen[] = {
    {"stueckliste",       QT_TR_NOOP("Stückliste")},
    {"bestellliste",      QT_TR_NOOP("Bestellliste")},
    {"kabelliste",        QT_TR_NOOP("Kabelliste")},
    {"aderliste",         QT_TR_NOOP("Aderliste")},
    {"adersummenliste",   QT_TR_NOOP("Adersummenliste")},
    {"klemmenplan",       QT_TR_NOOP("Klemmenplan")},
    {"klemmlistenauszug", QT_TR_NOOP("Klemmlistenauszug")},
    {"steckverbinder",    QT_TR_NOOP("Steckverbinder")},
    {"belegungsplan",     QT_TR_NOOP("Belegungsplan")},
    {"pinbelegung",       QT_TR_NOOP("Pinbelegung Mikrokontroller")},
    {"querverweise",      QT_TR_NOOP("Querverweisliste")},
};

// JS-nahe Zahlenausgabe (1.5 -> "1.5", 10 -> "10")
QString zahl(double v) { return QString::number(v, 'g', 12); }
QString fest(double v, int n) { return QString::number(v, 'f', n); }

QString s(const QVariantMap &m, const char *k) { return m.value(QLatin1String(k)).toString(); }
double  d(const QVariantMap &m, const char *k) { return m.value(QLatin1String(k)).toDouble(); }
bool    b(const QVariantMap &m, const char *k) { return m.value(QLatin1String(k)).toBool(); }

QString farbe(const QString &f1, const QString &f2)
{
    return f1.isEmpty() ? QString() : (f2.isEmpty() ? f1 : f1 + QLatin1Char('/') + f2);
}

QString oderStrich(const QString &v) { return v.isEmpty() ? QStringLiteral("–") : v; }

}  // namespace

QVariantList Database::listenPdfKatalog()
{
    QVariantList res;
    for (const ListenInfo &li : kListen) {
        QVariantMap m;
        m["id"]    = QString::fromLatin1(li.id);
        m["titel"] = tr(li.titel);
        res.append(m);
    }
    return res;
}

QVariantMap Database::listenPdfTabelle(const QString &liste, const QVariantList &zeilen, const QVariantMap &optionen)
{
    QStringList spalten;
    QList<QStringList> out;
    QString titel;
    for (const ListenInfo &li : kListen)
        if (liste == QLatin1String(li.id)) titel = tr(li.titel);
    if (titel.isEmpty()) return {};

    auto strukturSpalten = [&]() { return QStringList{QStringLiteral("==Anlage"), QStringLiteral("++Ort"),
                                                      QStringLiteral("=Anlage"), QStringLiteral("+Ort")}; };

    if (liste == QLatin1String("stueckliste")) {
        spalten = QStringList{tr("BMK"), tr("Typ"), tr("Freitext 1"), tr("Freitext 2"), tr("Seite")} + strukturSpalten();
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            out.append({s(r,"bmk"), s(r,"symbolId"), s(r,"freitext1"), s(r,"freitext2"), s(r,"seite"),
                        s(r,"anlageUO"), s(r,"ortUO"), s(r,"anlageKz"), s(r,"ortKz")});
        }
    } else if (liste == QLatin1String("querverweise")) {
        spalten = {tr("Signalname"), tr("Richtung"), tr("Seite"), tr("Zielseite")};
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            out.append({s(r,"signalname"), s(r,"richtung"), s(r,"seite"), s(r,"zielSeite")});
        }
    } else if (liste == QLatin1String("aderliste")) {
        spalten = QStringList{tr("Bezeichnung"), tr("Aderfarbe"), tr("Querschnitt"), tr("Länge (m)"), tr("Seite")}
                  + strukturSpalten();
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            const QString f = farbe(s(r,"aderfarbe"), s(r,"aderfarbe2"));
            out.append({s(r,"bezeichnung"), oderStrich(f),
                        d(r,"querschnittMm2") > 0 ? zahl(d(r,"querschnittMm2")) + QStringLiteral(" mm²") : QStringLiteral("–"),
                        d(r,"laengeM") > 0 ? zahl(d(r,"laengeM")) + QStringLiteral(" m") : QStringLiteral("–"),
                        s(r,"seite"), s(r,"anlageUO"), s(r,"ortUO"), s(r,"anlageKz"), s(r,"ortKz")});
        }
    } else if (liste == QLatin1String("adersummenliste")) {
        const bool jeAO = optionen.value(QStringLiteral("jeAnlageOrt")).toBool();
        if (jeAO) spalten = {tr("Anlage"), tr("Ort")};
        spalten += QStringList{tr("Aderfarbe"), tr("Querschnitt"), tr("Anzahl"), tr("Gesamtlänge")};
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            QStringList z;
            if (jeAO) z << s(r,"anlageKz") << s(r,"ortKz");
            z << oderStrich(farbe(s(r,"aderfarbe"), s(r,"aderfarbe2")))
              << (d(r,"querschnittMm2") > 0 ? zahl(d(r,"querschnittMm2")) + QStringLiteral(" mm²") : QStringLiteral("–"))
              << s(r,"anzahl")
              << (d(r,"laengeGesamtM") > 0 ? fest(d(r,"laengeGesamtM"), 2) + QStringLiteral(" m") : QStringLiteral("–"));
            out.append(z);
        }
    } else if (liste == QLatin1String("bestellliste")) {
        spalten = {tr("Bezeichnung"), tr("Hersteller"), tr("Artikelnr."), tr("Bestellnr."), tr("Lieferant"),
                   tr("Menge"), tr("Einzelpreis EUR"), tr("Summe EUR")};
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            const QString einheit = s(r,"einheit");
            out.append({s(r,"bezeichnung"), s(r,"hersteller"), s(r,"artikelnummer"), s(r,"bestellnummer"),
                        s(r,"lieferant"),
                        (einheit == QLatin1String("Stk") ? fest(d(r,"menge"), 0) : fest(d(r,"menge"), 2))
                            + QLatin1Char(' ') + einheit,
                        d(r,"preisEur") > 0 ? fest(d(r,"preisEur"), 2) : QStringLiteral("–"),
                        d(r,"summeEur") > 0 ? fest(d(r,"summeEur"), 2) : QStringLiteral("–")});
        }
    } else if (liste == QLatin1String("kabelliste")) {
        spalten = {tr("Bezeichnung"), tr("Kabeltyp"), tr("Adern"), tr("mm²"), tr("Länge (m)"),
                   tr("Von-Ort"), tr("Nach-Ort"), tr("Linien")};
        auto komma = [](double v) { return zahl(v).replace(QLatin1Char('.'), QLatin1Char(',')); };
        for (const QVariant &v : zeilen) {
            const QVariantMap k = v.toMap();
            out.append({oderStrich(s(k,"bezeichnung")), oderStrich(s(k,"kabeltyp")),
                        d(k,"aderzahl") > 0 ? zahl(d(k,"aderzahl")) : QStringLiteral("–"),
                        d(k,"querschnittMm2") > 0 ? komma(d(k,"querschnittMm2")) : QStringLiteral("–"),
                        d(k,"laengeM") > 0 ? komma(d(k,"laengeM")) + QStringLiteral(" m") : QStringLiteral("–"),
                        oderStrich(s(k,"vonOrt")), oderStrich(s(k,"nachOrt")),
                        d(k,"linienAnzahl") > 0 ? zahl(d(k,"linienAnzahl")) : QStringLiteral("–")});
        }
    } else if (liste == QLatin1String("klemmenplan")) {
        spalten = {tr("Leiste"), tr("Nr."), tr("Bauteil"), tr("Typ"), tr("Querschnitt"), tr("Farbe"),
                   tr("Potenzial"), tr("Ort")};
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            if (s(r,"typ") != QLatin1String("klemme")) continue;
            out.append({s(r,"leisteBmk"), s(r,"nummer"), s(r,"bauteilBez"), s(r,"anschlussTyp"),
                        s(r,"querschnitt"), s(r,"farbeBez"), s(r,"potenzial"), s(r,"ortKz")});
        }
    } else if (liste == QLatin1String("klemmlistenauszug")) {
        spalten = {tr("Leiste"), tr("Nr."), tr("Von-Anschl."), tr("Von-Verbindung"), tr("Von-Seite"),
                   tr("Von-Aderfarbe"), tr("Nach-Anschl."), tr("Nach-Verbindung"), tr("Nach-Seite"),
                   tr("Nach-Aderfarbe"), tr("Querschnitt"), tr("Farbe")};
        QString leiste;
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            const QString typ = s(r,"typ");
            if (typ == QLatin1String("leiste")) { leiste = s(r,"bmk"); continue; }
            if (typ != QLatin1String("anschluss")) continue;
            const QString vonF  = s(r,"vonAderFarbe")  + (s(r,"vonAderFarbe2").isEmpty()  ? QString() : "/" + s(r,"vonAderFarbe2"));
            const QString nachF = s(r,"nachAderFarbe") + (s(r,"nachAderFarbe2").isEmpty() ? QString() : "/" + s(r,"nachAderFarbe2"));
            const bool vonPl = b(r,"vonPlatziert"), nachPl = b(r,"nachPlatziert");
            out.append({leiste, s(r,"klemmeNr"), s(r,"anschlussVon"),
                        vonPl  ? (s(r,"vonVerbBez").isEmpty()  ? tr("(offen)") : s(r,"vonVerbBez"))  : QString(),
                        vonPl  ? s(r,"vonBlattnummer")  : QString(), vonF,
                        s(r,"anschlussNach"),
                        nachPl ? (s(r,"nachVerbBez").isEmpty() ? tr("(offen)") : s(r,"nachVerbBez")) : QString(),
                        nachPl ? s(r,"nachBlattnummer") : QString(), nachF,
                        s(r,"querschnitt"), s(r,"farbeBez")});
        }
    } else if (liste == QLatin1String("steckverbinder")) {
        spalten = QStringList{tr("BMK"), tr("Bezeichnung"), tr("Bauteil/Typ"), tr("Hersteller"), tr("Polzahl"),
                              tr("IP gesteckt"), tr("Kodierung"), tr("Geschirmt"), tr("Seite")} + strukturSpalten();
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            out.append({s(r,"bmk"), s(r,"gkBezeichnung"), s(r,"bauteilBez"), s(r,"hersteller"),
                        d(r,"polzahl") > 0 ? zahl(d(r,"polzahl")) + tr("-pol") : QString(),
                        s(r,"ipGesteckt"), s(r,"kodierung"), b(r,"geschirmt") ? QStringLiteral("SH") : QStringLiteral("–"),
                        s(r,"blattnr"), s(r,"anlageUO"), s(r,"ortUO"), s(r,"anlageKz"), s(r,"ortKz")});
        }
    } else if (liste == QLatin1String("belegungsplan")) {
        spalten = {tr("GK-BMK"), tr("Typ"), tr("Symbol-BMK"), tr("Pin"), tr("Signal"), tr("Aderfarbe"),
                   tr("Querschnitt mm²"), tr("Seite")};
        QString gkBmk;
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            if (s(r,"typ") == QLatin1String("gehaeuse")) { gkBmk = s(r,"bmk"); continue; }
            const double qs = d(r,"querschnitt");
            out.append({gkBmk, s(r,"kontaktTyp"), s(r,"kontaktBmk"), s(r,"kontaktBez"), s(r,"signalBez"),
                        s(r,"signalFarbe"), qs > 0 ? zahl(qs) : QString(), s(r,"blattnr")});
        }
    } else if (liste == QLatin1String("pinbelegung")) {
        spalten = {tr("Board-BMK"), tr("Board"), tr("Pin"), tr("Netz"), tr("Verbunden mit"), tr("Bauteil"),
                   tr("Anschluss"), tr("#define"), tr("Wert"), tr("Seite")};
        for (const QVariant &v : zeilen) {
            const QVariantMap r = v.toMap();
            out.append({s(r,"boardBmk"), s(r,"boardName"), s(r,"pin"), s(r,"netz"),
                        b(r,"istFrei") ? tr("(frei)") : s(r,"verbundenBmk"),
                        s(r,"verbundenSymbol"), s(r,"verbundenPin"), s(r,"defineName"), s(r,"defineWert"),
                        s(r,"blattnr")});
        }
    }

    QVariantList zeilenOut;
    for (const QStringList &z : out) zeilenOut.append(QVariant(z));
    QVariantMap res;
    res["titel"]   = titel;
    res["spalten"] = spalten;
    res["zeilen"]  = zeilenOut;
    return res;
}

QVariantMap Database::listenPdfStandard(int projektId, const QString &liste, const QVariantMap &optionen)
{
    QVariantList roh;
    if      (liste == QLatin1String("stueckliste"))       roh = stueckliste(projektId);
    else if (liste == QLatin1String("bestellliste"))      roh = bestellliste(projektId);
    else if (liste == QLatin1String("kabelliste"))        roh = kabelListeAufgeschluesselt(projektId);
    else if (liste == QLatin1String("aderliste"))         roh = aderliste(projektId);
    else if (liste == QLatin1String("adersummenliste"))
        roh = aderSummenliste(projektId, optionen.value(QStringLiteral("jeAnlageOrt")).toBool());
    else if (liste == QLatin1String("klemmenplan"))       roh = klemmenplan(projektId);
    else if (liste == QLatin1String("klemmlistenauszug")) roh = klemmlistenauszug(projektId);
    else if (liste == QLatin1String("steckverbinder"))    roh = steckverbinderListe(projektId);
    else if (liste == QLatin1String("belegungsplan"))     roh = steckverbinderBelegungsplan(projektId);
    else if (liste == QLatin1String("pinbelegung"))       roh = mikrocontrollerPinbelegung(projektId);
    else if (liste == QLatin1String("querverweise"))      roh = querverweisListe(projektId);
    else return {};
    return listenPdfTabelle(liste, roh, optionen);
}
