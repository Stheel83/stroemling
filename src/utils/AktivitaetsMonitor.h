#pragma once
#include <QObject>
#include <QEvent>

// Globaler Event-Filter: erkennt jede Nutzeraktion (Maus, Tastatur, Scrollrad)
// und sendet das Signal aktivitaet(). Wird für Fun-Modus Idle-Detection genutzt.
class AktivitaetsMonitor : public QObject {
    Q_OBJECT
public:
    explicit AktivitaetsMonitor(QObject* parent = nullptr);

protected:
    bool eventFilter(QObject* obj, QEvent* event) override;

signals:
    void aktivitaet();
};
