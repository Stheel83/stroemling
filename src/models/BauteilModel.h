#pragma once
#include <QAbstractListModel>
#include <QList>
#include <QString>

// ============================================================
// Datenstrukturen
// ============================================================

struct KategorieEintrag {
    int     id;
    int     parentId;
    QString name;
    int     sortierung;
    int     tiefe;      // berechnet beim Laden (für Einrückung in QML)
};

struct BauteilEintrag {
    int     id;
    int     kategorieId;
    QString bezeichnung;
    QString hersteller;
    QString artikelnummer;
    QString lieferant;
    double  preisEur;
    double  spannungV;
    double  stromA;
    double  leistungW;
    QString bemerkung;
    QString urlHersteller;
    QString urlDatenblatt;
    bool    istKlemme;
    bool    istKabel;
    QString kabeltyp;
};

// ============================================================
// BauteilKategorieModel – flach geladener Kategoriebaum
// ============================================================
// Kategorien werden per DFS-Durchlauf in Reihenfolge geladen.
// Die Tiefe (tiefe-Rolle) wird für Einrückung in QML genutzt.

class BauteilKategorieModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        KategorieIdRole = Qt::UserRole + 1,
        NameRole,
        ParentIdRole,
        TiefeRole,
        HatKinderRole
    };

    explicit BauteilKategorieModel(QObject *parent = nullptr);

    int      rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void laden();
    Q_INVOKABLE int  anlegen(int parentId, const QString &name);
    Q_INVOKABLE bool bearbeiten(int id, const QString &name);
    Q_INVOKABLE bool loeschen(int id);

private:
    void traversieren(int parentId, int tiefe,
                      const QList<KategorieEintrag> &alle);

    QList<KategorieEintrag> m_kategorien;
};

// ============================================================
// BauteilListModel – Bauteile einer Kategorie
// ============================================================

class BauteilListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        BauteilIdRole = Qt::UserRole + 1,
        KategorieIdRole,
        BezeichnungRole,
        HerstellerRole,
        ArtikelnummerRole,
        LieferantRole,
        PreisEurRole,
        SpannungVRole,
        StromARole,
        LeistungWRole,
        BemerkungRole,
        UrlHerstellerRole,
        UrlDatenblattRole,
        IstKlemmeRole,
        IstKabelRole,
        KabeltypRole
    };

    explicit BauteilListModel(QObject *parent = nullptr);

    int      rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void laden(int kategorieId);               // -1 = alle
    Q_INVOKABLE void aktualisieren();                     // Neu laden ohne Filter zu ändern
    Q_INVOKABLE void suchen(const QString &text);         // Suchtext setzen + neu laden
    Q_INVOKABLE void setNurKlemmen(bool nurKlemmen);      // Filter: nur Klemmen-Bauteile
    Q_INVOKABLE void setNurKabel(bool nurKabel);          // Filter: nur Kabel-Bauteile
    Q_INVOKABLE int  anlegen(int kategorieId,
                              const QString &bezeichnung,
                              const QString &hersteller,
                              const QString &artikelnummer,
                              const QString &lieferant,
                              double preisEur,
                              double spannungV,
                              double stromA,
                              double leistungW,
                              const QString &bemerkung,
                              const QString &urlHersteller = QString(),
                              const QString &urlDatenblatt = QString());
    Q_INVOKABLE bool bearbeiten(int id,
                                 const QString &bezeichnung,
                                 const QString &hersteller,
                                 const QString &artikelnummer,
                                 const QString &lieferant,
                                 double preisEur,
                                 double spannungV,
                                 double stromA,
                                 double leistungW,
                                 const QString &bemerkung,
                                 const QString &urlHersteller = QString(),
                                 const QString &urlDatenblatt = QString());
    Q_INVOKABLE bool loeschen(int id);
    Q_INVOKABLE QVariantMap bauteilNachId(int id) const;
    Q_INVOKABLE bool bauteilTitelSpeichern(int id, const QString &bezeichnung,
                                            const QString &hersteller, const QString &artikelnummer);

    Q_PROPERTY(int  aktiveKategorieId READ aktiveKategorieId NOTIFY aktiveKategorieIdChanged)
    Q_PROPERTY(bool nurKlemmen        READ nurKlemmen        NOTIFY aktiveKategorieIdChanged)
    Q_PROPERTY(bool nurKabel          READ nurKabel          NOTIFY aktiveKategorieIdChanged)
    int  aktiveKategorieId() const { return m_aktiveKategorieId; }
    bool nurKlemmen()        const { return m_nurKlemmen; }
    bool nurKabel()          const { return m_nurKabel; }

signals:
    void aktiveKategorieIdChanged();

private:
    void ladenIntern();
    QList<BauteilEintrag> m_bauteile;
    int                   m_aktiveKategorieId = -1;
    QString               m_suchtext;
    bool                  m_nurKlemmen        = false;
    bool                  m_nurKabel          = false;
};
