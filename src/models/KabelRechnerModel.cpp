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

    if (m_material == 1)
        warnungen << tr("Aluminium: Norm-Mindestquerschnitt 10 mm². Kleinere Al-Querschnitte sind nicht zulässig.");

    // ── 1. Spannungsfall ──────────────────────────────────────────────────────
    const double duMax  = spannung * m_duMaxProzent / 100.0;
    const double aDU_raw = (faktor * m_laenge * m_strom * cosPhi_eff) / (gamma * duMax);
    const double aDU_norm = naechsterNormquerschnitt(aDU_raw);
    const double duProzent = (faktor * m_laenge * m_strom * cosPhi_eff)
                             / (gamma * aDU_norm * spannung) * 100.0;

    QVariantMap spannungsfallMap;
    spannungsfallMap["aktiv"]      = true;
    spannungsfallMap["mindestText"]= formatQ(aDU_norm);
    spannungsfallMap["kenngroesse"]= QString("ΔU = %1 %")
                                        .arg(formatN(duProzent, 1));
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
    if (aThermisch < 0.0) {
        aThermisch = normReihe.back();
        double Ir50 = referenzstrom(m_material, normReihe.back(), m_verlegeart);
        IzBeiMin = (Ir50 > 0.0) ? Ir50 * fTemp * fGroup : 0.0;
        warnungen << tr("Thermik: 50 mm² reicht für den angegebenen Strom nicht aus.");
    }

    QVariantMap thermikMap;
    thermikMap["aktiv"]       = true;
    thermikMap["mindestText"] = formatQ(aThermisch);
    thermikMap["kenngroesse"] = QString("I_z = %1 A").arg(formatN(IzBeiMin, 1));
    thermikMap["ok"]          = (IzBeiMin >= m_strom - 1e-6);

    // ── 3. Abschaltbedingung (nur AC) ─────────────────────────────────────────
    const bool abschaltAktiv = (m_betriebsart != 2);
    double aAbschalt = 0.0;
    double IkBeiMin  = 0.0;
    bool   abschaltOk = true;

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
            warnungen << tr("Abschaltbedingung: Netznachbildung zu hochohmig für das gewählte Schutzorgan.");
        } else {
            const double aMin = (2.0 * m_laenge) / (gamma * rMax);
            aAbschalt = naechsterNormquerschnitt(aMin);
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
        kurzschlussMap["mindestText"] = formatQ(aAbschalt);
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

    // Praxisrichtwert I/6 (Cu, B2)
    const double aPraxis     = m_strom / 6.0;
    const double aPraxisNorm = naechsterNormquerschnitt(aPraxis);

    QVariantMap praxisMap;
    praxisMap["formel"] = QString("I / 6  =  %1 / 6  ≈  %2 mm²   →   %3")
                              .arg(formatN(m_strom, 0))
                              .arg(formatN(aPraxis, 1))
                              .arg(formatQ(aPraxisNorm));
    praxisMap["querschnittText"] = formatQ(aPraxisNorm);
    praxisMap["stimmtUeberein"]  = (std::abs(aPraxisNorm - aFinalNorm) < 1e-6);

    // Zusammenfassung für die Empfehlung
    static const QStringList verlegeartNamen = {"A1","A2","B1","B2","C","D1","D2","E","F"};
    const QString verlegeartStr = (m_verlegeart >= 0 && m_verlegeart < 9)
                                   ? verlegeartNamen[m_verlegeart] : "?";
    const QString materialStr   = (m_material == 0) ? tr("Kupfer") : tr("Aluminium");
    const QString baStr         = (m_betriebsart == 0) ? tr("AC einphasig")
                                : (m_betriebsart == 1) ? tr("Drehstrom") : "DC";
    const QString zusammenfassung = materialStr + " · " + verlegeartStr
                                  + " · " + baStr
                                  + " · " + formatN(spannung, 0) + " V";

    m_ergebnis["gueltig"]         = true;
    m_ergebnis["querschnittMm2"]  = aFinalNorm;
    m_ergebnis["querschnittText"] = formatQ(aFinalNorm);
    m_ergebnis["zusammenfassung"] = zusammenfassung;
    m_ergebnis["spannungsfall"]   = spannungsfallMap;
    m_ergebnis["thermik"]         = thermikMap;
    m_ergebnis["kurzschluss"]     = kurzschlussMap;
    m_ergebnis["praxis"]          = praxisMap;
    m_ergebnis["warnungen"]       = warnungen;

    m_ergebnisGueltig = true;
    emit ergebnisGeaendert();
}

// ─── Schnellberechnung ────────────────────────────────────────────────────────

void KabelRechnerModel::berechnenSchnell()
{
    m_ergebnis.clear();
    m_ergebnisGueltig = false;

    if (m_strom <= 0.0 || m_laenge <= 0.0) {
        emit ergebnisGeaendert();
        return;
    }

    // Daumenregel I/6 (gilt streng nur für Cu, B2)
    const double aPraxis     = m_strom / 6.0;
    const double aPraxisNorm = naechsterNormquerschnitt(aPraxis);

    const double gamma    = (m_material == 0) ? gammaCu : gammaAl;
    const double spannung = 230.0; // Standardannahme für Schnellmodus
    const double duMax    = spannung * m_duMaxProzent / 100.0;

    // Maximale Leitungslänge beim ermittelten Querschnitt bei 3 % Spannungsfall
    // L_max = (γ · A · ΔU_max) / (2 · I)
    const double lMax = (gamma * aPraxisNorm * duMax) / (2.0 * m_strom);
    const bool   lOk  = (m_laenge <= lMax + 1e-6);

    QStringList warnungen;
    warnungen << tr("⚡ Schnellmodus: Richtwert für Cu, B2, 230 V AC. Für sicherheitsrelevante Anwendungen Genaumodus verwenden.");
    if (!lOk)
        warnungen << QString(tr("Leitungslänge %1 m überschreitet L_max von %2 m bei %3 % Spannungsfall."))
                       .arg(formatN(m_laenge, 0))
                       .arg(formatN(lMax, 0))
                       .arg(formatN(m_duMaxProzent, 0));
    if (m_material == 1)
        warnungen << tr("Daumenregel I/6 gilt für Kupfer. Für Aluminium Genaumodus verwenden.");

    QVariantMap praxisMap;
    praxisMap["formel"] = QString("I / 6  =  %1 / 6  ≈  %2 mm²   →   %3")
                              .arg(formatN(m_strom, 0))
                              .arg(formatN(aPraxis, 1))
                              .arg(formatQ(aPraxisNorm));
    praxisMap["querschnittText"] = formatQ(aPraxisNorm);
    praxisMap["lMaxText"]        = formatN(lMax, 0) + " m";
    praxisMap["lOk"]             = lOk;
    praxisMap["stimmtUeberein"]  = true; // kein Vergleich im Schnellmodus

    const QString materialStr   = (m_material == 0) ? tr("Kupfer") : tr("Aluminium");
    const QString zusammenfassung = materialStr + " · "
                                  + tr("Standardannahmen (B2, 230 V AC)");

    QVariantMap inaktiv;
    inaktiv["aktiv"] = false;

    m_ergebnis["gueltig"]         = true;
    m_ergebnis["querschnittMm2"]  = aPraxisNorm;
    m_ergebnis["querschnittText"] = formatQ(aPraxisNorm);
    m_ergebnis["zusammenfassung"] = zusammenfassung;
    m_ergebnis["spannungsfall"]   = inaktiv;
    m_ergebnis["thermik"]         = inaktiv;
    m_ergebnis["kurzschluss"]     = inaktiv;
    m_ergebnis["praxis"]          = praxisMap;
    m_ergebnis["warnungen"]       = warnungen;

    m_ergebnisGueltig = true;
    emit ergebnisGeaendert();
}
