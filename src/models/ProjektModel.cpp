#include "ProjektModel.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

ProjektModel::ProjektModel(QObject *parent)
    : QAbstractListModel(parent)
{
    laden();
}

int ProjektModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_projekte.size();
}

QVariant ProjektModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_projekte.size())
        return {};

    const Projekt &p = m_projekte.at(index.row());

    switch (role) {
    case IdRole:             return p.id;
    case NameRole:           return p.name;
    case ProjektnummerRole:  return p.projektnummer;
    case AuftraggeberRole:   return p.auftraggeber;
    case AuftragnahmerRole:  return p.auftragnehmer;
    case BearbeiterRole:     return p.bearbeiter;
    case StatusRole:         return p.status;
    case ErstelltAmRole:     return p.erstellt_am;
    case BemerkungRole:      return p.bemerkung;
    default:                 return {};
    }
}

QHash<int, QByteArray> ProjektModel::roleNames() const
{
    // Diese Namen kannst du direkt in QML als model.name, model.status usw. verwenden
    return {
        { IdRole,             "projektId"    },
        { NameRole,           "name"         },
        { ProjektnummerRole,  "projektnummer"},
        { AuftraggeberRole,   "auftraggeber" },
        { AuftragnahmerRole,  "auftragnehmer"},
        { BearbeiterRole,     "bearbeiter"   },
        { StatusRole,         "status"       },
        { ErstelltAmRole,     "erstelltAm"   },
        { BemerkungRole,      "bemerkung"    }
    };
}

void ProjektModel::laden()
{
    beginResetModel();
    m_projekte.clear();

    QSqlQuery q;
    q.exec("SELECT id, name, projektnummer, "
           "COALESCE(auftraggeber,''), COALESCE(auftragnehmer,''), COALESCE(bearbeiter,''), "
           "status, erstellt_am, COALESCE(bemerkung,'') "
           "FROM projekt ORDER BY name");

    while (q.next()) {
        m_projekte.append({
            q.value(0).toInt(),
            q.value(1).toString(),
            q.value(2).toString(),
            q.value(3).toString(),
            q.value(4).toString(),
            q.value(5).toString(),
            q.value(6).toString(),
            q.value(7).toString(),
            q.value(8).toString()
        });
    }

    endResetModel();
    qInfo() << "Projekte geladen:" << m_projekte.size();
}

int ProjektModel::anlegen(const QString &name,
                           const QString &projektnummer,
                           const QString &bemerkung)
{
    QSqlQuery q;
    q.prepare("INSERT INTO projekt (name, projektnummer, bemerkung) "
              "VALUES (:name, :projektnummer, :bemerkung)");
    q.bindValue(":name",          name);
    q.bindValue(":projektnummer", projektnummer);
    q.bindValue(":bemerkung",     bemerkung);

    if (!q.exec()) {
        qWarning() << "Projekt anlegen fehlgeschlagen:" << q.lastError().text();
        return -1;
    }

    int neueId = q.lastInsertId().toInt();
    laden(); // Liste aktualisieren
    return neueId;
}

bool ProjektModel::loeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM projekt WHERE id = :id");
    q.bindValue(":id", id);

    if (!q.exec()) {
        qWarning() << "Projekt löschen fehlgeschlagen:" << q.lastError().text();
        return false;
    }

    laden();
    return true;
}
