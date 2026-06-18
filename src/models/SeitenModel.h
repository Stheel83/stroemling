#pragma once
#include <QAbstractItemModel>
#include <QList>
#include <QString>
#include <QVariant>

// ============================================================
// Datenstrukturen für den Seitenbaum
// ============================================================

struct SeiteEintrag {
    int     id;
    int     parentId;       // seite.parent_id (0 = keine Unterseite)
    int     ortId;
    QString blattnummer;
    QString bezeichnung;
    QString seitentyp;
    int     sortierung;
    double  rasterMm  = 4.0;
    bool    rastend   = true;
    double  breiteMm     = 297.0;
    double  hoeheMm      = 210.0;
    double  randLinksMm  = 20.0;
    double  randRechtsMm = 10.0;
    double  randObenMm   = 10.0;
    double  randUntenMm  = 10.0;
};

struct OrtEintrag {
    int     id;
    int     anlageId;
    QString kuerzel;
    QString bezeichnung;
    QString standortUebergeordnet;  // ++ : übergeordneter Ort, projektweit (NKZ-02b)
    int     sortierung;
    QList<SeiteEintrag> seiten;
};

struct AnlageEintrag {
    int     id;
    int     projektId;
    QString kuerzel;
    QString bezeichnung;
    QString anlageUebergeordnet;  // == : übergeordnete Anlage, projektweit (NKZ-02b)
    int     sortierung;
    QList<OrtEintrag> orte;
};

// ============================================================
// Interner Baumknoten
// ============================================================
// Jeder Knoten kennt seinen Elternknoten und seinen Typ.
// Typ 0 = Anlage, Typ 1 = Ort, Typ 2 = Seite

struct BaumKnoten {
    enum Typ { Anlage = 0, Ort = 1, Seite = 2 };

    Typ          typ;
    int          index;         // Index in der jeweiligen Eltern-Liste
    BaumKnoten  *eltern;        // nullptr = Wurzel

    // Zeiger auf Quelldaten
    AnlageEintrag *anlage = nullptr;
    OrtEintrag    *ort    = nullptr;
    SeiteEintrag  *seite  = nullptr;

    QList<BaumKnoten *> kinder;

    ~BaumKnoten() { qDeleteAll(kinder); }
};

// ============================================================
// SeitenModel – QAbstractItemModel für den Seitenbaum
// ============================================================
// Hierarchie: Anlage → Ort → Seite
//
// In QML:
//   TreeView {
//       model: seitenModel
//       delegate: ...
//   }
//
// Rollen:
//   bezeichnung  – lesbarer Name
//   kuerzel      – Kürzel (nur Anlage/Ort)
//   blattnummer  – Blattnummer (nur Seite)
//   seitentyp    – schaltplan | klemmenplan | ...
//   knotenTyp    – 0=Anlage 1=Ort 2=Seite
//   itemId       – Datenbank-ID des Eintrags

class SeitenModel : public QAbstractItemModel
{
    Q_OBJECT

public:
    enum Roles {
        BezeichnungRole = Qt::UserRole + 1,
        KuerzelRole,
        BlattnummerRole,
        SeitentypRole,
        KnotenTypRole,
        ItemIdRole,
        RohBezeichnungRole,
        BreiteMmRole,
        HoeheMmRole,
        RandLinksMmRole,
        RandRechtsMmRole,
        RandObenMmRole,
        RandUntenMmRole,
        OrtIdRole,
        SortierungRole,
        UebergeordnetRole   // Anlage: anlageUebergeordnet (==), Ort: standortUebergeordnet (++)
    };

    explicit SeitenModel(QObject *parent = nullptr);
    ~SeitenModel() override;

    // QAbstractItemModel Pflichtmethoden
    QModelIndex   index(int row, int column,
                        const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex   parent(const QModelIndex &child) const override;
    int           rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int           columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant      data(const QModelIndex &index,
                       int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // --------------------------------------------------------
    // Aus QML aufrufbare Methoden
    // --------------------------------------------------------

    // Seitenbaum für ein Projekt laden
    Q_INVOKABLE void laden(int projektId);

    // Anlage anlegen  → gibt neue ID zurück (-1 = Fehler)
    Q_INVOKABLE int anlageAnlegen(int projektId,
                                   const QString &kuerzel,
                                   const QString &bezeichnung,
                                   const QString &anlageUebergeordnet = QString());

    // Ort anlegen
    Q_INVOKABLE int ortAnlegen(int anlageId,
                                const QString &kuerzel,
                                const QString &bezeichnung,
                                const QString &standortUebergeordnet = QString());

    // Seite anlegen
    Q_INVOKABLE int seiteAnlegen(int ortId,
                                  const QString &blattnummer,
                                  const QString &bezeichnung,
                                  const QString &seitentyp    = "schaltplan",
                                  double breiteMm    = 297.0,
                                  double hoeheMm     = 210.0,
                                  double randLinksMm = 20.0,
                                  double randRechtsMm= 10.0,
                                  double randObenMm  = 10.0,
                                  double randUntenMm = 10.0);

    // Eintrag löschen (Anlage, Ort oder Seite je nach Typ)
    Q_INVOKABLE bool loeschen(int knotenTyp, int id);

    // Einträge bearbeiten
    Q_INVOKABLE bool anlageBearbeiten(int id, const QString &kuerzel, const QString &bezeichnung,
                                       const QString &anlageUebergeordnet = QString());
    Q_INVOKABLE bool ortBearbeiten(int id, const QString &kuerzel, const QString &bezeichnung,
                                    const QString &standortUebergeordnet = QString());
    Q_INVOKABLE bool seiteBearbeiten(int id, const QString &blattnummer,
                                      const QString &bezeichnung, const QString &seitentyp,
                                      double breiteMm, double hoeheMm,
                                      double randLinksMm, double randRechtsMm,
                                      double randObenMm,  double randUntenMm);

    // Einträge verschieben (Elternknoten wechseln)
    Q_INVOKABLE bool seiteVerschieben(int seiteId, int neuerOrtId);
    Q_INVOKABLE bool ortVerschieben(int ortId, int neueAnlageId);

    // Manuelle Reihenfolge innerhalb des Orts
    Q_INVOKABLE bool seiteHoch(int seiteId);
    Q_INVOKABLE bool seiteRunter(int seiteId);
    Q_INVOKABLE bool seiteUmordnen(int seiteId, int neuerIndex);

    // Raster-Einstellungen pro Seite
    Q_INVOKABLE double seiteRasterMm(int seiteId) const;
    Q_INVOKABLE bool   seiteRastend(int seiteId) const;
    Q_INVOKABLE bool   seiteRasterSpeichern(int seiteId, double rasterMm, bool rastend);

    // Hilfslisten für Verschieben-Dialoge
    Q_INVOKABLE QVariantList anlagenListe() const;
    Q_INVOKABLE QVariantList orteListe(int anlageId) const;

private:
    void baumAufbauen();
    void baumLeeren();

    int                   m_projektId = -1;
    QList<AnlageEintrag>  m_anlagen;
    BaumKnoten           *m_wurzel = nullptr;   // unsichtbarer Wurzelknoten
};
