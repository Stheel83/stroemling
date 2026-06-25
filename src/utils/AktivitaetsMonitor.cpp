#include "AktivitaetsMonitor.h"
#include <QGuiApplication>

AktivitaetsMonitor::AktivitaetsMonitor(QObject* parent) : QObject(parent)
{
    QGuiApplication::instance()->installEventFilter(this);
}

bool AktivitaetsMonitor::eventFilter(QObject* /*obj*/, QEvent* event)
{
    switch (event->type()) {
        case QEvent::MouseMove:
        case QEvent::MouseButtonPress:
        case QEvent::KeyPress:
        case QEvent::Wheel:
            emit aktivitaet();
            break;
        default:
            break;
    }
    return false; // Ereignisse nie verbrauchen
}
