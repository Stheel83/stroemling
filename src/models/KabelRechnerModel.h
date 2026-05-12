#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>

// ============================================================
// KabelRechnerModel – Kabelquerschnitt-Rechner
//
// Berechnungslogik (Spannungsfall, Thermik, Kurzschluss) nach
// VDE 0298-4 für AC einphasig, Drehstrom und DC.
// Lookup-Tabellen in src/utils/KabelTabellen.h.
// Keine Datenbankanbindung – Eingaben und Ergebnisse nur im RAM.
// ============================================================

class KabelRechnerModel : public QObject
{
    Q_OBJECT

    // ── Eingaben ──────────────────────────────────────────────────────────────
    // betriebsart: 0 = AC einphasig, 1 = Drehstrom, 2 = DC
    Q_PROPERTY(int    betriebsart      READ betriebsart      WRITE setBetriebsart      NOTIFY eingabeGeaendert)
    Q_PROPERTY(double strom            READ strom            WRITE setStrom            NOTIFY eingabeGeaendert)
    Q_PROPERTY(double spannung         READ spannung         WRITE setSpannung         NOTIFY eingabeGeaendert)
    Q_PROPERTY(double cosPhi           READ cosPhi           WRITE setCosPhi           NOTIFY eingabeGeaendert)
    Q_PROPERTY(double laenge           READ laenge           WRITE setLaenge           NOTIFY eingabeGeaendert)
    // material: 0 = Kupfer, 1 = Aluminium
    Q_PROPERTY(int    material         READ material         WRITE setMaterial         NOTIFY eingabeGeaendert)
    // verlegeart: 0..8 = A1, A2, B1, B2, C, D1, D2, E, F
    Q_PROPERTY(int    verlegeart       READ verlegeart       WRITE setVerlegeart       NOTIFY eingabeGeaendert)
    Q_PROPERTY(double temperatur       READ temperatur       WRITE setTemperatur       NOTIFY eingabeGeaendert)
    // haefung: 0 = 1 Leitung, 1 = 2, 2 = 3, 3 = 4, 4 = 5, 5 = 6+
    Q_PROPERTY(int    haefung          READ haefung          WRITE setHaefung          NOTIFY eingabeGeaendert)
    // schutzOrganTyp: 0 = B, 1 = C, 2 = D
    Q_PROPERTY(int    schutzOrganTyp   READ schutzOrganTyp   WRITE setSchutzOrganTyp   NOTIFY eingabeGeaendert)
    Q_PROPERTY(double schutzOrganStrom READ schutzOrganStrom WRITE setSchutzOrganStrom NOTIFY eingabeGeaendert)
    // maximaler Spannungsfall in % (Standard: 3 %)
    Q_PROPERTY(double duMaxProzent     READ duMaxProzent     WRITE setDuMaxProzent     NOTIFY eingabeGeaendert)

    // ── Ergebnis ──────────────────────────────────────────────────────────────
    Q_PROPERTY(bool        ergebnisGueltig READ ergebnisGueltig NOTIFY ergebnisGeaendert)
    Q_PROPERTY(QVariantMap ergebnis        READ ergebnis        NOTIFY ergebnisGeaendert)

public:
    explicit KabelRechnerModel(QObject *parent = nullptr);

    int    betriebsart()      const { return m_betriebsart; }
    double strom()            const { return m_strom; }
    double spannung()         const { return m_spannung; }
    double cosPhi()           const { return m_cosPhi; }
    double laenge()           const { return m_laenge; }
    int    material()         const { return m_material; }
    int    verlegeart()       const { return m_verlegeart; }
    double temperatur()       const { return m_temperatur; }
    int    haefung()          const { return m_haefung; }
    int    schutzOrganTyp()   const { return m_schutzOrganTyp; }
    double schutzOrganStrom() const { return m_schutzOrganStrom; }
    double duMaxProzent()     const { return m_duMaxProzent; }

    bool        ergebnisGueltig() const { return m_ergebnisGueltig; }
    QVariantMap ergebnis()        const { return m_ergebnis; }

    void setBetriebsart(int v)        { if (m_betriebsart != v)      { m_betriebsart = v;      emit eingabeGeaendert(); } }
    void setStrom(double v)           { if (m_strom != v)            { m_strom = v;            emit eingabeGeaendert(); } }
    void setSpannung(double v)        { if (m_spannung != v)         { m_spannung = v;          emit eingabeGeaendert(); } }
    void setCosPhi(double v)          { if (m_cosPhi != v)           { m_cosPhi = v;            emit eingabeGeaendert(); } }
    void setLaenge(double v)          { if (m_laenge != v)           { m_laenge = v;            emit eingabeGeaendert(); } }
    void setMaterial(int v)           { if (m_material != v)         { m_material = v;          emit eingabeGeaendert(); } }
    void setVerlegeart(int v)         { if (m_verlegeart != v)       { m_verlegeart = v;        emit eingabeGeaendert(); } }
    void setTemperatur(double v)      { if (m_temperatur != v)       { m_temperatur = v;        emit eingabeGeaendert(); } }
    void setHaefung(int v)            { if (m_haefung != v)          { m_haefung = v;           emit eingabeGeaendert(); } }
    void setSchutzOrganTyp(int v)     { if (m_schutzOrganTyp != v)   { m_schutzOrganTyp = v;   emit eingabeGeaendert(); } }
    void setSchutzOrganStrom(double v){ if (m_schutzOrganStrom != v) { m_schutzOrganStrom = v; emit eingabeGeaendert(); } }
    void setDuMaxProzent(double v)    { if (m_duMaxProzent != v)     { m_duMaxProzent = v;      emit eingabeGeaendert(); } }

    // Genauberechnung: alle drei Kriterien (Spannungsfall, Thermik, Kurzschluss)
    Q_INVOKABLE void berechnen();

    // Schnellberechnung: Daumenregel I/6 (Cu, B2, 230 V AC)
    Q_INVOKABLE void berechnenSchnell();

signals:
    void eingabeGeaendert();
    void ergebnisGeaendert();

private:
    int    m_betriebsart      = 0;
    double m_strom            = 0.0;
    double m_spannung         = 230.0;
    double m_cosPhi           = 1.0;
    double m_laenge           = 0.0;
    int    m_material         = 0;
    int    m_verlegeart       = 3;    // B2
    double m_temperatur       = 30.0;
    int    m_haefung          = 0;
    int    m_schutzOrganTyp   = 1;    // C
    double m_schutzOrganStrom = 16.0;
    double m_duMaxProzent     = 3.0;

    bool        m_ergebnisGueltig = false;
    QVariantMap m_ergebnis;

    QString formatQ(double mm2) const;
    QString formatN(double val, int dez) const;
};
