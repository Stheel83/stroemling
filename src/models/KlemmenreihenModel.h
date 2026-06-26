#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

// ============================================================
// KlemmenleistenModel – Liste der Klemmenleisten eines Projekts
// ============================================================

class KlemmenleistenModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int projektId READ projektId NOTIFY geladen)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        BezeichnungRole,
        AusrichtungRole,
        BmkKurzRole,
        AnzahlKlemmenRole,
        GesamtBreiteMmRole
    };

    explicit KlemmenleistenModel(QObject *parent = nullptr);

    int      rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int projektId() const { return m_projektId; }

    Q_INVOKABLE void laden(int projektId);
    Q_INVOKABLE int  anlegen(int projektId, const QString &bezeichnung);
    Q_INVOKABLE bool loeschen(int id);
    Q_INVOKABLE bool umbenennen(int id, const QString &bezeichnung);
    Q_INVOKABLE void beispielLeistenAnlegen(int projektId);
    Q_INVOKABLE int  duplizieren(int id);

signals:
    void geladen();

private:
    struct Eintrag {
        int     id;
        QString bezeichnung;
        QString ausrichtung;
        QString bmkKurz;
        int     anzahlKlemmen;
        double  gesamtBreiteMm;
    };

    int           m_projektId = -1;
    QList<Eintrag> m_leisten;
};

// ============================================================
// KlemmenreiheModel – eine Leiste + ihre Klemmen-Instanzen
// ============================================================

class KlemmenreiheModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool        hatLeiste    READ hatLeiste    NOTIFY leisteGeladen)
    Q_PROPERTY(QVariantMap leiste       READ leiste       NOTIFY leisteGeladen)
    Q_PROPERTY(QVariantList klemmen     READ klemmen      NOTIFY leisteGeladen)
    Q_PROPERTY(QVariantList stegbruecken READ stegbruecken NOTIFY leisteGeladen)

public:
    explicit KlemmenreiheModel(QObject *parent = nullptr);

    bool         hatLeiste()     const { return m_leisteId >= 0; }
    QVariantMap  leiste()        const { return m_leiste; }
    QVariantList klemmen()       const { return m_klemmen; }
    QVariantList stegbruecken()  const { return m_stegbruecken; }

    Q_INVOKABLE void laden(int leisteId);
    Q_INVOKABLE bool leisteAktualisieren(const QVariantMap &daten);

    // Klemmen-Instanzen verwalten
    Q_INVOKABLE int  klemmeAnlegen(int bauteilId);
    Q_INVOKABLE bool klemmeLoeschen(int klemmeId);
    Q_INVOKABLE int  klemmeKopieren(int klemmeId);
    Q_INVOKABLE bool klemmeSchieben(int klemmeId, int richtung); // -1 = hoch, +1 = runter

    // Klemmen-Nummer ändern
    Q_INVOKABLE bool klemmeNummerSetzen(int klemmeId, const QString &nummer);

    // Bauteil zuweisen oder entfernen (bauteilId=0 → NULL)
    Q_INVOKABLE bool klemmeBauteilSetzen(int klemmeId, int bauteilId);

    // Mehrere Klemmen auf dasselbe Bauteil setzen (bauteilId=0 → NULL).
    Q_INVOKABLE bool klemmeMehrfachBauteilSetzen(const QVariantList &ids, int bauteilId);

    // Mehrere Klemmen fortlaufend nummerieren (Reihenfolge wie ids, beginnend bei start).
    Q_INVOKABLE bool klemmeMehrfachNummerieren(const QVariantList &ids, int start);

    // Klemmen-Bauteile für Suchdialog (nur Bauteile mit bauteil_klemme-Eintrag)
    Q_INVOKABLE QVariantList klemmeBauteileHolen(const QString &suchtext) const;

    // bauteilKlemmeId in grafik_element.extra_daten für alle platzierten Anschlüsse
    // dieser Leiste auf den aktuellen Wert synchronisieren.
    // Gibt die Anzahl aktualisierter Elemente zurück, -1 bei Fehler.
    Q_INVOKABLE int  leisteKanvasAktualisieren();

    // Stegbrücken verwalten
    Q_INVOKABLE int  stegbrueckeAnlegen(int ebene, int vonKlemmeId, int bisKlemmeId);
    Q_INVOKABLE bool stegbrueckeLoeschen(int id);
    Q_INVOKABLE bool stegbrueckePotenzialSetzen(int id, const QString &potenzialText);

signals:
    void leisteGeladen();

private:
    void ladeKlemmen();
    void ladeStegbruecken();
    QString pruefUeberlappung(int ebene, int vonKlemmeId, int bisKlemmeId, int skipId = -1) const;

    int          m_leisteId = -1;
    QVariantMap  m_leiste;
    QVariantList m_klemmen;
    QVariantList m_stegbruecken;
};
