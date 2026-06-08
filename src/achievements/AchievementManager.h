#pragma once
#include <QObject>
#include <QSet>
#include <QList>
#include <QDateTime>
#include <QVariantList>
#include <QVariantMap>

class AchievementManager : public QObject
{
    Q_OBJECT

public:
    explicit AchievementManager(QObject *parent = nullptr);

    // Haupt-API: aus QML oder C++ aufrufen
    Q_INVOKABLE void         ereignis(const QString &typ, const QVariantMap &kontext = {});
    Q_INVOKABLE QVariantList erreichte() const;

signals:
    void achievementFreigeschaltet(const QString &id,
                                   const QString &titel,
                                   const QString &beschreibung);

private:
    struct Def {
        QString id;
        QString titel;
        QString beschreibung;
    };

    struct Stats {
        QDateTime start        = QDateTime::currentDateTime();
        int  platzierteElemente = 0;
        int  gezogeneKabel      = 0;
        int  geloeschteInFolge  = 0;
        int  undosInFolge       = 0;
        int  rotInFolge         = 0;
        int  rotElemId          = -1;
        QList<qint64> zoomTs;
        QList<qint64> platzTs;
        bool wikiGeoeffnet      = false;
        bool symEdGeoeffnet     = false;
        bool kabelrGeoeffnet    = false;
        bool ibnGeoeffnet       = false;
        bool drcGeoeffnet       = false;
        int  symEdOeffnungen    = 0;
        int  drcLetzterFehler   = -1; // fehlerAnzahl des letzten DRC-Laufs
    };

    static QList<Def> _katalog();

    bool _hat(const QString &id) const;
    void _freischalten(const QString &id);
    int  _zaehlerInc(const QString &key, int um = 1);
    int  _zaehlerGet(const QString &key) const;

    void _pruefePanels();
    void _pruefeMarathon();
    void _resetNichtLoeschSequenz();
    void _resetNichtUndoSequenz();

    QSet<QString> _cache;   // freigeschaltete IDs (schneller Lookup)
    Stats         _stats;
};
