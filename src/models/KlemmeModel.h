#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

// ============================================================
// FarbDefinitionModel – Dropdown-Liste der Gehäusefarben
// ============================================================

struct FarbEintrag {
    int     id;
    QString hexWert;
    QString bezeichnung;
    bool    istStandard;
};

class FarbDefinitionModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        HexWertRole,
        BezeichnungRole,
        IstStandardRole
    };

    explicit FarbDefinitionModel(QObject *parent = nullptr);

    int      rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void laden();

private:
    QList<FarbEintrag> m_farben;
};

// ============================================================
// KlemmeModel – Klemmen-Physik für einen Bauteil-Eintrag
// ============================================================
// Verwaltet bauteil_klemme + abhängige Tabellen für eine
// Bauteil-ID. Wird geladen wenn ein Bauteil ausgewählt wird.
// ============================================================

class KlemmeModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool        hatKlemme   READ hatKlemme   NOTIFY klemmeGeladen)
    Q_PROPERTY(QVariantMap klemme      READ klemme      NOTIFY klemmeGeladen)
    Q_PROPERTY(QVariantList querschnitte READ querschnitte NOTIFY klemmeGeladen)
    Q_PROPERTY(QVariantList bruecken   READ bruecken    NOTIFY klemmeGeladen)
    Q_PROPERTY(QVariantList anschluesse READ anschluesse NOTIFY klemmeGeladen)

public:
    explicit KlemmeModel(QObject *parent = nullptr);

    // Lädt Klemmen-Daten für bauteilId (oder setzt hatKlemme=false)
    Q_INVOKABLE void laden(int bauteilId);

    // Legt einen neuen bauteil_klemme-Eintrag an – gibt klemmeId zurück
    Q_INVOKABLE int anlegen(int bauteilId);

    // Speichert alle Felder der aktuellen Klemme
    Q_INVOKABLE bool speichern(const QVariantMap &daten);

    // Querschnitte
    Q_INVOKABLE bool querschnittSetzen(const QString &adertyp, double min, double max);
    Q_INVOKABLE bool querschnittLoeschen(const QString &adertyp);

    // Interne Ebenenverbindungen (Brücken)
    Q_INVOKABLE bool brueckeAnlegen(int vonEbene, int nachEbene);
    Q_INVOKABLE bool brueckeLoeschen(int id);

    // Read-only Lesezugriff für das EigenschaftenPanel (keine Zustandsänderung)
    // Gibt Klemmen-Details + Anschluss-Seite/-Ebene zurück ohne den aktuellen
    // Zustand des Modells zu verändern.
    Q_INVOKABLE QVariantMap klemmeDetailsHolen(int klemmeId, const QString &anschlussBezeichnung) const;

    bool         hatKlemme()    const { return m_klemmeId >= 0; }
    QVariantMap  klemme()       const { return m_klemme; }
    QVariantList querschnitte() const { return m_querschnitte; }
    QVariantList bruecken()     const { return m_bruecken; }
    QVariantList anschluesse()  const;

signals:
    void klemmeGeladen();

private:
    void ladeQuerschnitte();
    void ladeBruecken();

    int          m_bauteilId   = -1;
    int          m_klemmeId    = -1;
    QVariantMap  m_klemme;
    QVariantList m_querschnitte;
    QVariantList m_bruecken;
};
