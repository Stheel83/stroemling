#include "KabelRechnerModel.h"
#include "../utils/KabelTabellen.h"

#include <QLocale>
#include <algorithm>
#include <cmath>

using namespace KabelTabellen;

KabelRechnerModel::KabelRechnerModel(QObject *parent)
    : QObject(parent)
{}

// ─── Formatierung ─────────────────────────────────────────────────────────────

QString KabelRechnerModel::formatQ(double mm2) const
{
    QLocale de(QLocale::German);
    // Ganzzahlige Querschnitte ohne Nachkommastelle (10, 16, 25 …)
    if (std::fmod(mm2, 1.0) < 1e-6)
        return de.toString(static_cast<int>(mm2)) + " mm²";
    return de.toString(mm2, 'f', 1) + " mm²";
}

QString KabelRechnerModel::formatN(double val, int dez) const
{
    return QLocale(QLocale::German).toString(val, 'f', dez);
}

// ─── Genauberechnung ──────────────────────────────────────────────────────────

void KabelRechnerModel::berechnen()
{
    m_ergebnis.clear();
    m_ergebnisGueltig = false;

    if (m_strom <= 0.0 || m_laenge <= 0.0) {
        emit ergebnisGeaendert();
        return;
    }

    QStringList warnungen;
    const double gamma = (m_material == 0) ? gammaCu : gammaAl;

    // Betriebsart-Parameter
    // DC: cosφ = 1; Faktor für Spannungsfall: 2 bei AC-einphasig/DC, √3 bei Drehstrom
    const double cosPhi_eff = (m_betriebsart == 2) ? 1.0 : m_cosPhi;
    const double faktor     = (m_betriebsart == 1) ? std::sqrt(3.0) : 2.0;
    const double spannung   = m_spannung;

    if (m_betriebsart == 2)
        warnungen << tr("DC-Betrieb: Schutzorgan auf DC-Lichtbogenlöschung prüfen (z. B. IEC 60947-2).");

    // Al hat für F/G keine hinterlegten Belastbarkeiten → Thermik nicht bewertbar.
    // Dann nur diese eine Meldung (Empfehlungskarte), nicht zusätzlich „reicht nicht".
    const bool thermFehlt = (m_material == 1 && m_verlegeart >= 7);

    if (m_material == 1)
        warnungen << tr("Aluminium: Norm-Mindestquerschnitt 10 mm². Kleinere Al-Querschnitte sind nicht zulässig.");

    // Größter Tabellenquerschnitt: Anforderungen darüber lassen sich mit den
    // hinterlegten Tabellen nicht mehr als Normquerschnitt ausdrücken.
    const double tabMax = normReihe.back();
    // Mindestquerschnitt für die Detailzeile: oberhalb der Tabelle den echten
    // (aufgerundeten) Bedarf zeigen statt den auf tabMax abgeschnittenen Wert.
    auto mindestAnzeige = [&](double raw) {
        if (raw > tabMax + 1e-9)
            return QString("≈ %1 (> %2)").arg(formatQ(std::ceil(raw))).arg(formatQ(tabMax));
        return formatQ(naechsterNormquerschnitt(raw));
    };
    QStringList ueberGruende; // Kriterien, die über die Tabelle hinausgehen

    // ── 1. Spannungsfall ──────────────────────────────────────────────────────
    const double duMax  = spannung * m_duMaxProzent / 100.0;
    const double aDU_raw = (faktor * m_laenge * m_strom * cosPhi_eff) / (gamma * duMax);
    const double aDU_norm = naechsterNormquerschnitt(aDU_raw);
    const double duProzent = (faktor * m_laenge * m_strom * cosPhi_eff)
                             / (gamma * aDU_norm * spannung) * 100.0;

    const bool duUeber = (aDU_raw > tabMax + 1e-9);
    if (duUeber) {
        ueberGruende << tr("Spannungsfall: ΔU ≤ %1 % verlangt ≈ %2")
                            .arg(formatN(m_duMaxProzent, 1))
                            .arg(formatQ(std::ceil(aDU_raw)));
        warnungen << tr("Spannungsfall: Für ΔU ≤ %1 % wären ≈ %2 nötig – Leitung kürzen, "
                        "ΔU-Grenze prüfen oder Spannung erhöhen.")
                         .arg(formatN(m_duMaxProzent, 1))
                         .arg(formatQ(std::ceil(aDU_raw)));
    }

    QVariantMap spannungsfallMap;
    spannungsfallMap["aktiv"]      = true;
    spannungsfallMap["mindestText"]= mindestAnzeige(aDU_raw);
    spannungsfallMap["kenngroesse"]= duUeber
        ? QString("ΔU = %1 % bei %2").arg(formatN(duProzent, 1)).arg(formatQ(aDU_norm))
        : QString("ΔU = %1 %").arg(formatN(duProzent, 1));
    spannungsfallMap["ok"]         = (duProzent <= m_duMaxProzent + 1e-6);

    // ── 2. Thermik ────────────────────────────────────────────────────────────
    if (m_temperatur < 10.0 || m_temperatur > 60.0)
        warnungen << tr("Umgebungstemperatur außerhalb des Tabellenbereichs (10– 60 °C).");

    const double fTemp  = temperaturfaktor(m_temperatur);
    const double fGroup = haefungsfaktor(m_haefung);

    double aThermisch = -1.0;
    double IzBeiMin   = 0.0;
    for (double q : normReihe) {
        double Ir = referenzstrom(m_material, q, m_verlegeart);
        if (Ir <= 0.0) continue; // nicht anwendbar (z. B. Al < 10 mm²)
        double Iz = Ir * fTemp * fGroup;
        if (Iz >= m_strom - 1e-6) {
            aThermisch = q;
            IzBeiMin   = Iz;
            break;
        }
    }
    const bool thermUeber = (aThermisch < 0.0) && !thermFehlt;
    if (aThermisch < 0.0) {
        aThermisch = normReihe.back();
        double Ir50 = referenzstrom(m_material, normReihe.back(), m_verlegeart);
        IzBeiMin = (Ir50 > 0.0) ? Ir50 * fTemp * fGroup : 0.0;
    }
    if (thermUeber) {
        warnungen << tr("Thermik: %1 reicht für den angegebenen Strom nicht aus – "
                        "größerer Querschnitt oder Parallelverlegung nötig.").arg(formatQ(tabMax));
        ueberGruende << tr("Thermik: I_z = %1 A bei %2 < I_b = %3 A")
                            .arg(formatN(IzBeiMin, 0)).arg(formatQ(tabMax)).arg(formatN(m_strom, 0));
    }

    QVariantMap thermikMap;
    thermikMap["aktiv"]       = true;
    thermikMap["mindestText"] = thermUeber ? QString("> %1").arg(formatQ(tabMax))
                                           : formatQ(aThermisch);
    thermikMap["kenngroesse"] = thermUeber
        ? QString("I_z = %1 A bei %2").arg(formatN(IzBeiMin, 1)).arg(formatQ(tabMax))
        : QString("I_z = %1 A").arg(formatN(IzBeiMin, 1));
    thermikMap["ok"]          = (IzBeiMin >= m_strom - 1e-6);
    if (thermFehlt) {
        thermikMap["mindestText"] = "—";
        thermikMap["kenngroesse"] = tr("nicht hinterlegt");
        thermikMap["ok"]          = false;
        ueberGruende << tr("Aluminium: Für Verlegeart F/G sind keine Belastbarkeitswerte hinterlegt – "
                           "Thermik nicht bewertbar.");
    }

    // ── 3. Abschaltbedingung (nur AC) ─────────────────────────────────────────
    const bool abschaltAktiv = (m_betriebsart != 2);
    double aAbschalt = 0.0;
    double IkBeiMin  = 0.0;
    bool   abschaltOk = true;
    bool   abschUeber = false;
    QString abschMindest;

    if (abschaltAktiv && m_schutzOrganStrom > 0.0) {
        // B=5×I_n, C=10×I_n, D=20×I_n
        const int charFaktor = (m_schutzOrganTyp == 0) ? 5 : (m_schutzOrganTyp == 1) ? 10 : 20;
        const double rNetz      = 0.3; // Ω, Normwert nach VDE 0100-410
        const double IkBenötigt = charFaktor * m_schutzOrganStrom;

        // Mindest-Querschnitt aus Bedingung I_k >= I_k_benötigt analytisch:
        // A >= 2·L / (γ · (U/I_k_ben - R_netz))
        const double rMax = spannung / IkBenötigt - rNetz;
        if (rMax <= 0.0) {
            aAbschalt = normReihe.back();
            abschaltOk = false;
            abschUeber = true;
            abschMindest = QString("> %1").arg(formatQ(tabMax));
            ueberGruende << tr("Abschaltbedingung: mit der angenommenen Netzimpedanz nicht erreichbar");
            warnungen << tr("Abschaltbedingung: Netznachbildung zu hochohmig für das gewählte Schutzorgan.");
        } else {
            const double aMin = (2.0 * m_laenge) / (gamma * rMax);
            aAbschalt = naechsterNormquerschnitt(aMin);
            abschMindest = mindestAnzeige(aMin);
            if (aMin > tabMax + 1e-9) {
                abschUeber = true;
                ueberGruende << tr("Abschaltbedingung: verlangt ≈ %1").arg(formatQ(std::ceil(aMin)));
            }
            const double rL = (2.0 * m_laenge) / (gamma * aAbschalt);
            IkBeiMin = spannung / (rL + rNetz);
            abschaltOk = (IkBeiMin >= IkBenötigt - 1e-6);
            if (!abschaltOk)
                warnungen << tr("Abschaltbedingung nicht erfüllt: I_k zu gering. Querschnitt erhöhen oder Netzimpedanz prüfen.");
        }
    }

    QVariantMap kurzschlussMap;
    kurzschlussMap["aktiv"] = abschaltAktiv;
    if (abschaltAktiv) {
        kurzschlussMap["mindestText"] = abschMindest.isEmpty() ? formatQ(aAbschalt) : abschMindest;
        kurzschlussMap["kenngroesse"] = QString("I_k = %1 A").arg(formatN(IkBeiMin, 0));
        kurzschlussMap["ok"]          = abschaltOk;
    } else {
        kurzschlussMap["mindestText"] = "—";
        kurzschlussMap["kenngroesse"] = tr("nur AC");
        kurzschlussMap["ok"]          = true;
    }

    // ── 4. Gesamtergebnis ─────────────────────────────────────────────────────
    const double aFinalRaw  = std::max({aDU_raw, aThermisch, aAbschalt});
    const double aFinalNorm = naechsterNormquerschnitt(aFinalRaw);
    // Mindestens ein Kriterium verlangt mehr als der größte Tabellenquerschnitt →
    // keine Empfehlung, sondern ausdrücklich „kein Normquerschnitt ausreichend".
    const bool ueberTabelle = duUeber || thermUeber || abschUeber || thermFehlt;

    // Praxisrichtwert I/6 (Cu, B2)
    const double aPraxis     = m_strom / 6.0;
    const double aPraxisNorm = naechsterNormquerschnitt(aPraxis);

    QVariantMap praxisMap;
    praxisMap["formel"] = QString("I / 6  =  %1 / 6  ≈  %2 mm²   →   %3")
                              .arg(formatN(m_strom, 0))
                              .arg(formatN(aPraxis, 1))
                              .arg(formatQ(aPraxisNorm));
    praxisMap["querschnittText"] = formatQ(aPraxisNorm);
    praxisMap["stimmtUeberein"]  = !ueberTabelle && (std::abs(aPraxisNorm - aFinalNorm) < 1e-6);

    // Zusammenfassung für die Empfehlung
    static const QStringList verlegeartNamen = {"A1","A2","B1","B2","C","D","E","F","G"};
    const QString verlegeartStr = (m_verlegeart >= 0 && m_verlegeart < 9)
                                   ? verlegeartNamen[m_verlegeart] : "?";
    const QString materialStr   = (m_material == 0) ? tr("Kupfer") : tr("Aluminium");
    const QString baStr         = (m_betriebsart == 0) ? tr("AC einphasig")
                                : (m_betriebsart == 1) ? tr("Drehstrom") : "DC";
    const QString zusammenfassung = materialStr + " · " + verlegeartStr
                                  + " · " + baStr
                                  + " · " + formatN(spannung, 0) + " V";

    m_ergebnis["gueltig"]         = true;
    m_ergebnis["ueberTabelle"]    = ueberTabelle;
    m_ergebnis["ueberTabelleGrund"] = ueberGruende.join("\n");
    m_ergebnis["querschnittMm2"]  = ueberTabelle ? 0.0 : aFinalNorm;
    m_ergebnis["thermikFehlt"]    = thermFehlt;
    m_ergebnis["querschnittText"] = thermFehlt ? QString("—")
                                  : ueberTabelle ? QString("> %1").arg(formatQ(tabMax))
                                                 : formatQ(aFinalNorm);
    m_ergebnis["zusammenfassung"] = zusammenfassung;
    m_ergebnis["spannungsfall"]   = spannungsfallMap;
    m_ergebnis["thermik"]         = thermikMap;
    m_ergebnis["kurzschluss"]     = kurzschlussMap;
    m_ergebnis["praxis"]          = praxisMap;
    m_ergebnis["warnungen"]       = warnungen;

    m_ergebnisGueltig = true;
    emit ergebnisGeaendert();
}

// ─── Anwendungsfall-Vorlagen ──────────────────────────────────────────────────

QVariantList KabelRechnerModel::vorlagen() const
{
    // Praxisübliche Ausgangswerte für typische Stromkreise. Die Vorlage füllt nur die
    // Eingabefelder; Querschnitt/Prüfung kommen immer aus berechnen(). Länge ist eine
    // typische Annahme und im Rechner anzupassen.
    // Indizes: betriebsart 0=AC 1=Drehstrom 2=DC · verlegeart 0..8=A1..G (3=B2, 4=C)
    //          schutzOrganTyp 0=B 1=C 2=D
    struct V {
        const char *name; int betriebsart; double spannung; double strom; double cosPhi;
        double laenge; double duMax; int verlegeart; int typ; double inSchutz;
    };
    // Motoren: Nennstrom 4-poliger Normmotor 400 V, cos φ ≈ 0,85 (Volllast); LS-Charakteristik D
    // wegen Anlaufstrom. Richtwerte – bei realem Motor Typenschild (I_N, cos φ) eintragen.
    static const V tabelle[] = {
        { QT_TR_NOOP("Lichtkreis (10 A)"),            0, 230.0, 10.0, 1.00, 20.0, 3.0, 3, 0, 10.0 },
        { QT_TR_NOOP("Steckdosenkreis (16 A)"),       0, 230.0, 16.0, 1.00, 25.0, 3.0, 3, 0, 16.0 },
        { QT_TR_NOOP("Herd / Backofen (3~, 16 A)"),   1, 400.0, 16.0, 1.00, 15.0, 3.0, 3, 0, 16.0 },
        { QT_TR_NOOP("Durchlauferhitzer (3~, 32 A)"), 1, 400.0, 32.0, 1.00, 15.0, 3.0, 3, 0, 32.0 },
        { QT_TR_NOOP("Wallbox 11 kW (3~, 16 A)"),     1, 400.0, 16.0, 1.00, 20.0, 3.0, 3, 1, 16.0 },
        { QT_TR_NOOP("Bordnetz 12 V DC (10 A)"),      2,  12.0, 10.0, 1.00,  5.0, 3.0, 4, 0, 10.0 },
        { QT_TR_NOOP("Drehstrommotor 0,75 kW (1,9 A)"), 1, 400.0,  1.9, 0.85, 20.0, 3.0, 4, 2,  4.0 },
        { QT_TR_NOOP("Drehstrommotor 2,2 kW (4,7 A)"),  1, 400.0,  4.7, 0.85, 20.0, 3.0, 4, 2,  6.0 },
        { QT_TR_NOOP("Drehstrommotor 5,5 kW (11 A)"),   1, 400.0, 11.0, 0.85, 20.0, 3.0, 4, 2, 16.0 },
        { QT_TR_NOOP("Drehstrommotor 11 kW (21 A)"),    1, 400.0, 21.0, 0.85, 20.0, 3.0, 4, 2, 25.0 },
        { QT_TR_NOOP("Drehstrommotor 22 kW (41 A)"),    1, 400.0, 41.0, 0.85, 20.0, 3.0, 4, 2, 50.0 },
    };

    QVariantList liste;
    for (const V &v : tabelle) {
        QVariantMap m;
        m["name"]             = tr(v.name);
        m["betriebsart"]      = v.betriebsart;
        m["spannung"]         = v.spannung;
        m["strom"]            = v.strom;
        m["cosPhi"]           = v.cosPhi;
        m["laenge"]           = v.laenge;
        m["duMaxProzent"]     = v.duMax;
        m["verlegeart"]       = v.verlegeart;
        m["schutzOrganTyp"]   = v.typ;
        m["schutzOrganStrom"] = v.inSchutz;
        liste << m;
    }
    return liste;
}
