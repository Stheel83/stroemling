#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <vector>

struct GrafikElement {
    int     id              = 0;
    QString typ;
    double  x1              = 0.0;
    double  y1              = 0.0;
    double  x2              = 0.0;
    double  y2              = 0.0;
    QString strichFarbe;
    double  strichBreite    = 0.35;
    QString strichArt;
    bool    fuell           = false;
    QString fuellFarbe;
    double  fuellOpazitaet  = 0.3;
    double  opazitaet       = 1.0;
    double  eckenRadius     = 0.0;
    QString symbolId;
    int     rotation        = 0;
    bool    spiegelX        = false;
    bool    spiegelY        = false;
    QVariantList punkte;
    QString textInhalt;
    QString textAusrichtung;
    bool    textEinpassen   = false;
    QString bildDaten;
    bool    proportional     = false;
    double  ausschnittLinks  = 0.0;
    double  ausschnittRechts = 0.0;
    double  ausschnittOben   = 0.0;
    double  ausschnittUnten  = 0.0;
    QVariantMap extraDaten;
    int     betriebsmittelId = 0;
    int     gruppeId         = -1;

    QVariantMap toVariantMap() const;
};

class ElementeModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(int anzahl READ anzahl NOTIFY geaendert)
public:
    explicit ElementeModel(QObject *parent = nullptr);

    Q_INVOKABLE void         laden(int seiteId);
    Q_INVOKABLE void         fromVariantList(const QVariantList &liste);
    Q_INVOKABLE void         leeren();
    Q_INVOKABLE QVariantList snapshot() const;
    Q_INVOKABLE QVariantMap  element(int idx) const;
    Q_INVOKABLE int          anzahl()   const;
    Q_INVOKABLE int          elementBeiPosition(double vpX, double vpY,
                                                double zoom, double worldX, double worldY) const;

    Q_INVOKABLE void eigenschaftSetzen(int idx, const QString &key, const QVariant &value);
    Q_INVOKABLE void elementAktualisieren(int idx, const QVariantMap &felder);

    // ── Gruppen ───────────────────────────────────────────────
    Q_INVOKABLE int          gruppeErstellen(const QVariantList &indizes);
    Q_INVOKABLE void         gruppeAufloesen(int gruppeId);
    Q_INVOKABLE QVariantList gruppenMitglieder(int gruppeId) const;
    Q_INVOKABLE int          gruppeVonElement(int idx) const;

    Q_PROPERTY(bool undoMoeglich READ undoMoeglich NOTIFY geaendert)
    Q_PROPERTY(bool redoMoeglich READ redoMoeglich NOTIFY geaendert)
    Q_PROPERTY(int  undoAnzahl  READ undoAnzahl  NOTIFY geaendert)
    Q_PROPERTY(int  redoAnzahl  READ redoAnzahl  NOTIFY geaendert)

    Q_INVOKABLE void undoCheckpoint();
    Q_INVOKABLE void undoCheckpointFromSnapshot(const QVariantList &snapshot);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE bool undoMoeglich() const;
    Q_INVOKABLE bool redoMoeglich() const;
    Q_INVOKABLE int  undoAnzahl()  const;
    Q_INVOKABLE int  redoAnzahl()  const;

signals:
    void geaendert();

private:
    static std::vector<GrafikElement> parseVariantList(const QVariantList &liste);
    void invalidateSnapshotCache();

    std::vector<GrafikElement>              m_elemente;
    std::vector<std::vector<GrafikElement>> m_undoStack;
    std::vector<std::vector<GrafikElement>> m_redoStack;

    mutable QVariantList m_snapshotCache;
    mutable bool         m_snapshotDirty = true;
};
