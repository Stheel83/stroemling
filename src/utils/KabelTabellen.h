#pragma once
#include <array>
#include <cmath>
#include <utility>

// ============================================================
// KabelTabellen – normative Lookup-Tabellen nach VDE 0298-4
//
// Alle Werte für PVC-isolierte Leitungen (max. 70 °C Leitertemperatur),
// 3 belastete Adern, Referenzumgebungstemperatur 30 °C.
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
// A1=0  A2=1  B1=2  B2=3  C=4  D1=5  D2=6  E=7  F=8

// ─── Belastbarkeitstabelle Kupfer ─────────────────────────────────────────────
// [Querschnitt-Idx][Verlegeart-Idx]
// Zeilen: 1,5 / 2,5 / 4 / 6 / 10 / 16 / 25 / 35 / 50 mm²
// VDE 0298-4 Tabelle A.52-1 / A.52-2 (Auszug, 3 belastete Adern)
constexpr double belastbarkeitCu[9][9] = {
    //  A1     A2     B1     B2     C      D1     D2     E      F
    {  13.0,  13.0,  15.5,  15.5,  17.5,  22.0,  18.0,  19.0,  19.0 }, // 1,5 mm²
    {  17.5,  17.5,  21.0,  21.0,  24.0,  29.0,  24.0,  26.0,  26.0 }, // 2,5 mm²
    {  23.0,  23.0,  28.0,  28.0,  32.0,  38.0,  31.0,  35.0,  35.0 }, // 4,0 mm²
    {  29.0,  29.0,  36.0,  36.0,  41.0,  47.0,  39.0,  45.0,  45.0 }, // 6,0 mm²
    {  40.0,  39.0,  50.0,  49.0,  57.0,  63.0,  52.0,  61.0,  61.0 }, // 10   mm²
    {  54.0,  52.0,  68.0,  66.0,  76.0,  81.0,  67.0,  81.0,  81.0 }, // 16   mm²
    {  70.0,  68.0,  89.0,  83.0,  96.0, 103.0,  86.0, 106.0, 106.0 }, // 25   mm²
    {  86.0,  83.0, 110.0, 103.0, 119.0, 125.0, 103.0, 131.0, 131.0 }, // 35   mm²
    { 104.0,  99.0, 134.0, 125.0, 144.0, 148.0, 122.0, 158.0, 158.0 }, // 50   mm²
};

// ─── Belastbarkeitstabelle Aluminium ──────────────────────────────────────────
// 0,0 = nicht anwendbar (Norm schreibt Cu vor für diese Querschnitte)
// VDE 0298-4 Tabelle A.52-3 / A.52-4 (Auszug, 3 belastete Adern)
constexpr double belastbarkeitAl[9][9] = {
    //  A1     A2     B1     B2     C      D1     D2     E      F
    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 1,5 mm²
    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 2,5 mm²
    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 4,0 mm²
    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 }, // 6,0 mm²
    {  31.0,  30.0,  38.0,  37.0,  44.0,  49.0,  40.0,  47.0,  47.0 }, // 10   mm²
    {  42.0,  40.0,  52.0,  51.0,  59.0,  63.0,  53.0,  63.0,  63.0 }, // 16   mm²
    {  54.0,  52.0,  68.0,  64.0,  74.0,  81.0,  67.0,  83.0,  83.0 }, // 25   mm²
    {  66.0,  64.0,  84.0,  80.0,  92.0,  98.0,  82.0, 102.0, 102.0 }, // 35   mm²
    {  80.0,  77.0, 103.0,  97.0, 111.0, 116.0,  97.0, 124.0, 124.0 }, // 50   mm²
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
// verlegeartIdx: 0..8 = A1..F
// Gibt 0,0 zurück wenn nicht anwendbar (z. B. Al < 10 mm²)
inline double referenzstrom(int material, double querschnittMm2, int verlegeartIdx) {
    if (verlegeartIdx < 0 || verlegeartIdx > 8) return 0.0;
    for (int i = 0; i < 9; ++i) {
        if (std::abs(normReihe[i] - querschnittMm2) < 1e-6) {
            return (material == 0) ? belastbarkeitCu[i][verlegeartIdx]
                                   : belastbarkeitAl[i][verlegeartIdx];
        }
    }
    return 0.0;
}

} // namespace KabelTabellen
