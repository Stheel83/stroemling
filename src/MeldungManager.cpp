#include "MeldungManager.h"

MeldungManager::MeldungManager(QObject *parent) : QObject(parent) {}

void MeldungManager::zeigen(const QString &text, bool erfolg)
{
    m_historie.prepend({text, erfolg, QDateTime::currentDateTime()});
    while (m_historie.size() > kMaxHistorie)
        m_historie.removeLast();

    emit meldungAnzuzeigen(text, erfolg);
}

QVariantList MeldungManager::historie() const
{
    QVariantList result;
    for (const auto &e : m_historie) {
        QVariantMap m;
        m["text"]   = e.text;
        m["erfolg"] = e.erfolg;
        m["datum"]  = e.zeitpunkt.toString("dd.MM. hh:mm");
        result.append(m);
    }
    return result;
}
