#pragma once
#include <QObject>

// Globaler Toast-Kanal für nicht-blockierende Erfolgs-/Info-Meldungen
// (z.B. "PDF gespeichert"), Anzeige unten rechts analog zum Achievement-Toast.
class MeldungManager : public QObject
{
    Q_OBJECT

public:
    explicit MeldungManager(QObject *parent = nullptr);

    Q_INVOKABLE void zeigen(const QString &text, bool erfolg = true);

signals:
    void meldungAnzuzeigen(const QString &text, bool erfolg);
};
