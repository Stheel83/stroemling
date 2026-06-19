#pragma once
#include <QObject>
#include <QVariantList>
#include <QList>
#include <QDateTime>

// Globaler Toast-Kanal für nicht-blockierende Erfolgs-/Info-Meldungen
// (z.B. "PDF gespeichert"), Anzeige unten rechts analog zum Achievement-Toast.
// Historie nur im RAM (keine DB-Persistenz) – überlebt keinen Neustart, das
// ist gewollt: Toast-Inhalte sind Wegwerf-Infos, kein Audit-Log.
class MeldungManager : public QObject
{
    Q_OBJECT

public:
    explicit MeldungManager(QObject *parent = nullptr);

    Q_INVOKABLE void         zeigen(const QString &text, bool erfolg = true);
    Q_INVOKABLE QVariantList historie() const;

signals:
    void meldungAnzuzeigen(const QString &text, bool erfolg);

private:
    struct Eintrag {
        QString   text;
        bool      erfolg;
        QDateTime zeitpunkt;
    };

    static constexpr int kMaxHistorie = 50;

    QList<Eintrag> m_historie;
};
