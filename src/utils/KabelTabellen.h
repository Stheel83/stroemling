#pragma once
#include <array>
#include <cmath>
#include <utility>

// ============================================================
// KabelTabellen – normative Lookup-Tabellen nach VDE 0298-4
//
// Alle Werte für PVC-isolierte Leitungen (max. 70 °C Leitertemperatur),
// 3 belastete Adern (Drehstrom; 2 Adern: belastbarkeitCu2), Referenzumgebungstemperatur 30 °C.
// Quelle: VDE 0298-4:2013-06 (entspricht IEC 60364-5-52)
//
// Änderungen bei Normrevision sind bewusste, nachvollziehbare
// Codeänderungen (Git-History).
// ============================================================

namespace KabelTabellen {

// ─── Normquerschnitte ─────────────────────────────────────────────────────────
constexpr std::array<double, 9> normReihe = {1.5, 2.5, 4.0, 6.0, 10.0, 16.0, 25.0, 35.0, 50.0};

// Kleinsten Normquerschnitt ≥ wert zurückgeben. Liegt wert > 50 mm², wird 50 zurückgegeben.
inline double naechsterNormquerschnitt(double wert) {
    for (double q : normReihe)
        if (q >= wert - 1e-9) return q;
    return normReihe.back();
}

// ─── Leitfähigkeit ────────────────────────────────────────────────────────────
constexpr double gammaCu = 56.0; // m/(Ω·mm²)
constexpr double gammaAl = 36.0; // m/(Ω·mm²)

// ─── Verlegeart-Indizes ───────────────────────────────────────────────────────
// A1=0  A2=1  B1=2  B2=3  C=4  D=5  E=6  F=7  G=8  (DIN VDE 0298-4:2023: nur ein D)

// ─── Belastbarkeitstabelle Kupfer ─────────────────────────────────────────────
// [Querschnitt-Idx][Verlegeart-Idx]
// Zeilen: 1,5 / 2,5 / 4 / 6 / 10 / 16 / 25 / 35 / 50 mm²
// VDE 0298-4 Tabelle A.52-1 / A.52-2 (Auszug, 3 belastete Adern, 30 °C)
// Okt 2026 (KABELRECHNER-UEBER-TABELLE-01): Spalten A1, B2 und E gegen
// Tabellenbuch (DIN VDE 0298-4:03-08, Werte für 25 °C, ×0,94 auf 30 °C
// umgerechnet) und ABB-Auszug korrigiert. A2, B1, C waren bereits stimmig.
// F: einadrige Kabel in Luft mit Berührung (Bündel/Dreieck, konservativ gegenüber
// Flachlage); das Buch tabelliert F erst ab 25 mm² (0,0 = nicht anwendbar).
// G: einadrige Kabel mit Abstand (konservativ: senkrecht übereinander), ab 25 mm².
// D: Werte stammen aus der früheren Spalte D2 (die Spalte D1 entfiel, die Norm kennt
// nur ein D) und sind NICHT gegen die Norm geprüft; ebenso die Aluminium-Tabelle
// (dort F/G nicht hinterlegt = 0,0).
constexpr double belastbarkeitCu[9][9] = {
    //  A1     A2     B1     B2     C      D      E      F      G
    {  13.5,  13.0,  15.5,  15.0,  17.5,  18.0,  18.5,   0.0,   0.0 }, // 1,5 mm²
    {  18.0,  17.5,  21.0,  20.0,  24.0,  24.0,  25.0,   0.0,   0.0 }, // 2,5 mm²
    {  24.0,  23.0,  28.0,  27.0,  32.0,  31.0,  34.0,   0.0,   0.0 }, // 4,0 mm²
    {  31.0,  29.0,  36.0,  34.0,  41.0,  39.0,  43.0,   0.0,   0.0 }, // 6,0 mm²
    {  42.0,  39.0,  50.0,  46.0,  57.0,  52.0,  60.0,   0.0,   0.0 }, // 10   mm²
    {  56.0,  52.0,  68.0,  62.0,  76.0,  67.0,  80.0,   0.0,   0.0 }, // 16   mm²
    {  73.0,  68.0,  89.0,  80.0,  96.0,  86.0, 101.0, 110.0, 130.0 }, // 25   mm²
    {  89.0,  83.0, 110.0,  99.0, 119.0, 103.0, 126.0, 137.0, 162.0 }, // 35   mm²
    { 108.0,  99.0, 134.0, 118.0, 144.0, 122.0, 153.0, 167.0, 197.0 }, // 50   mm²
};

// ─── Belastbarkeitstabelle Kupfer, 2 belastete Adern ──────────────────────────
// Gilt für AC einphasig (L + N) und DC. Quelle: Tabellenbuch (DIN VDE 0298-4:03-08, Werte für
// 25 °C) ÷ 1,06 auf 30 °C umgerechnet und auf 0,5 A ABGERUNDET (konservativ, das Buch
// rundet selbst). 0,0 = nicht tabelliert → referenzstrom() fällt auf die 3-Adern-Werte
// zurück (immer zulässig, da kleiner): betrifft D, G (nur 3 Adern im Buch), F < 25 mm²
// und die Aluminium-Tabelle.
constexpr double belastbarkeitCu2[9][9] = {
    //  A1     A2     B1     B2     C      D      E      F      G
    {  15.5,  15.5,  17.0,  16.5,  19.5,   0.0,  21.5,   0.0,   0.0 }, // 1,5 mm²
    {  19.5,  18.0,  23.5,  22.5,  27.0,   0.0,  30.0,   0.0,   0.0 }, // 2,5 mm²
    {  26.0,  25.0,  32.0,  30.0,  35.5,   0.0,  39.5,   0.0,   0.0 }, // 4,0 mm²
    {  33.5,  32.0,  40.5,  37.5,  46.0,   0.0,  50.5,   0.0,   0.0 }, // 6,0 mm²
    {  46.0,  43.0,  56.5,  51.5,  63.0,   0.0,  69.5,   0.0,   0.0 }, // 10   mm²
    {  61.0,  56.5,  76.0,  68.5,  84.5,   0.0,  94.0,   0.0,   0.0 }, // 16   mm²
    {  80.0,  75.0, 100.5,  89.5, 112.0,   0.0, 118.5, 131.0,   0.0 }, // 25   mm²
    {  99.0,  92.0, 125.0, 111.0, 137.5,   0.0, 148.0, 162.0,   0.0 }, // 35   mm²
    { 118.5, 110.0, 150.5, 133.0, 167.5,   0.0, 180.0, 196.0,   0.0 }, // 50   mm²
};

// ─── Belastbarkeitstabelle Aluminium ──────────────────────────────────────────
// 0,0 = nicht anwendbar (Norm schreibt Cu vor für diese Querschnitte)
// VDE 0298-4 Tabelle A.52-3 / A.52-4 (Auszug, 3 belastete Adern)
constexpr double belastbarkeitAl[9][9] = {
    //  A1     A2     B1     B2     C      D      E      F      G
    {    0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 1,5 mm²
    {    0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 2,5 mm²
    {    0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 4,0 mm²
    {    0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 6,0 mm²
    {  31.0,  30.0,  38.0,  37.0,  44.0,  40.0,  47.0,   0.0,   0.0 }, // 10   mm²
    {  42.0,  40.0,  52.0,  51.0,  59.0,  53.0,  63.0,   0.0,   0.0 }, // 16   mm²
    {  54.0,  52.0,  68.0,  64.0,  74.0,  67.0,  83.0,   0.0,   0.0 }, // 25   mm²
    {  66.0,  64.0,  84.0,  80.0,  92.0,  82.0, 102.0,   0.0,   0.0 }, // 35   mm²
    {  80.0,  77.0, 103.0,  97.0, 111.0,  97.0, 124.0,   0.0,   0.0 }, // 50   mm²
};

// ─── Temperaturfaktor f_temp ──────────────────────────────────────────────────
// PVC-Isolierung (70 °C Leitertemperatur), Referenz 30 °C.
// Lineare Interpolation zwischen Stützstellen.
// VDE 0298-4 Tabelle A.52-14
inline double temperaturfaktor(double tempC) {
    constexpr std::array<std::pair<double, double>, 11> tbl = {{
        { 10.0, 1.22 }, { 15.0, 1.17 }, { 20.0, 1.12 }, { 25.0, 1.06 },
        { 30.0, 1.00 }, { 35.0, 0.94 }, { 40.0, 0.87 }, { 45.0, 0.79 },
        { 50.0, 0.71 }, { 55.0, 0.61 }, { 60.0, 0.50 }
    }};
    if (tempC <= tbl.front().first) return tbl.front().second;
    if (tempC >= tbl.back().first)  return tbl.back().second;
    for (size_t i = 1; i < tbl.size(); ++i) {
        if (tempC <= tbl[i].first) {
            double t = (tempC - tbl[i - 1].first) / (tbl[i].first - tbl[i - 1].first);
            return tbl[i - 1].second + t * (tbl[i].second - tbl[i - 1].second);
        }
    }
    return 1.0;
}

// ─── Häufungsfaktor f_group ───────────────────────────────────────────────────
// haefungIdx: 0 = 1 Leitung, 1 = 2, 2 = 3, 3 = 4, 4 = 5, 5 = 6+
// VDE 0298-4 Tabelle A.52-17 (Verlegung in einer Schicht)
inline double haefungsfaktor(int haefungIdx) {
    constexpr double faktoren[] = { 1.00, 0.80, 0.70, 0.65, 0.60, 0.57 };
    if (haefungIdx < 0) return 1.00;
    if (haefungIdx > 5) return 0.52;
    return faktoren[haefungIdx];
}

// ─── Tabellenwert I_r auslesen ────────────────────────────────────────────────
// material: 0 = Kupfer, 1 = Aluminium
// querschnittMm2: muss ein exakter Normquerschnitt aus normReihe sein
// verlegeartIdx: 0..8 = A1..G
// belasteteAdern: 2 (AC einphasig, DC) oder 3 (Drehstrom)
// Gibt 0,0 zurück wenn nicht anwendbar (z. B. Al < 10 mm²)
inline double referenzstrom(int material, double querschnittMm2, int verlegeartIdx,
                            int belasteteAdern = 3) {
    if (verlegeartIdx < 0 || verlegeartIdx > 8) return 0.0;
    for (int i = 0; i < 9; ++i) {
        if (std::abs(normReihe[i] - querschnittMm2) < 1e-6) {
            const double wert3 = (material == 0) ? belastbarkeitCu[i][verlegeartIdx]
                                                 : belastbarkeitAl[i][verlegeartIdx];
            if (belasteteAdern == 2 && material == 0 && wert3 > 0.0) {
                const double wert2 = belastbarkeitCu2[i][verlegeartIdx];
                if (wert2 > 0.0) return wert2;
            }
            return wert3;   // 3 belastete Adern bzw. Rückfall (konservativ)
        }
    }
    return 0.0;
}

} // namespace KabelTabellen
