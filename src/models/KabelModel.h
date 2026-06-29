#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

// ============================================================
// KabelModel – Kabel-Bibliothekseintrag eines Bauteils
//
// Lädt und verwaltet die kabelspezifischen Daten (bauteil_kabel,
// bauteil_kabel_ader, bauteil_kabel_paar) für ein gegebenes bauteil_id.
// Analog zu KlemmenreiheModel für Klemmen-Bibliothekseinträge.
// ============================================================

class KabelModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool         hatKabel   READ hatKabel   NOTIFY geladen)
    Q_PROPERTY(QVariantMap  stammdaten READ stammdaten NOTIFY geladen)
    Q_PROPERTY(QVariantList adern      READ adern      NOTIFY geladen)
    Q_PROPERTY(QVariantList paare      READ paare      NOTIFY geladen)

public:
    explicit KabelModel(QObject *parent = nullptr);

    bool         hatKabel()   const { return m_kabelId >= 0; }
    QVariantMap  stammdaten() const { return m_stammdaten; }
    QVariantList adern()      const { return m_adern; }
    QVariantList paare()      const { return m_paare; }

    // Kabel-Datensatz für ein Bauteil laden (bauteilId = bauteil.id).
    // Legt keinen DB-Eintrag an – hatKabel() bleibt false wenn noch keiner existiert.
    Q_INVOKABLE void laden(int bauteilId);

    // Stammdaten anlegen (erstes Mal) oder aktualisieren.
    // Felder: kabeltyp, geschirmt, paarweise_verdrillt,
    //         aussenmantel_farbe, aussenmantel_mm, material_leiter, material_isolierung
    Q_INVOKABLE bool stammdatenSpeichern(const QVariantMap &daten);

    // Kabel-Eintrag vollständig löschen (inkl. aller Adern und Paare via CASCADE).
    Q_INVOKABLE bool kabelLoeschen();

    // Ader hinzufügen (ader_nr wird automatisch als MAX+1 vergeben).
    Q_INVOKABLE int  aderAnlegen();

    // Ader löschen.
    Q_INVOKABLE bool aderLoeschen(int aderId);

    // Ader-Felder aktualisieren.
    // Felder: farbe, nummer, bezeichnung, querschnitt_mm2
    Q_INVOKABLE bool aderAktualisieren(int aderId, const QVariantMap &daten);

    // Ader verschieben (richtung: -1 = hoch / +1 = runter).
    Q_INVOKABLE bool aderSchieben(int aderId, int richtung);

    // Mehrere Adern auf einmal aktualisieren.
    // Nur nicht-leere Felder in daten werden gesetzt: "farbe", "bezeichnung", "querschnitt_mm2".
    Q_INVOKABLE bool aderMehrfachAktualisieren(const QVariantList &ids, const QVariantMap &daten);

    // Paar anlegen (nur sinnvoll wenn paarweise_verdrillt = true).
    // paar_nr wird automatisch als MAX+1 vergeben.
    Q_INVOKABLE int  paarAnlegen(int aderA, int aderB);

    // Paar löschen.
    Q_INVOKABLE bool paarLoeschen(int paarId);

    // Paar-Ader-Zuordnung aktualisieren.
    Q_INVOKABLE bool paarAktualisieren(int paarId, int aderA, int aderB);

signals:
    void geladen();
    void kanvasGeaendert();

private:
    void ladeAdern();
    void ladePaare();
    void aktualisiereKanvasBauteilKabel();

    int          m_bauteilId = -1;
    int          m_kabelId   = -1;
    QVariantMap  m_stammdaten;
    QVariantList m_adern;
    QVariantList m_paare;
};
