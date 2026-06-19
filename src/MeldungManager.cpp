#include "MeldungManager.h"

MeldungManager::MeldungManager(QObject *parent) : QObject(parent) {}

void MeldungManager::zeigen(const QString &text, bool erfolg)
{
    emit meldungAnzuzeigen(text, erfolg);
}
