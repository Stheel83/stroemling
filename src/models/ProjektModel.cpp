#include "logging.h"
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
    qCInfo(lcModel) << "Projekte geladen:" << m_projekte.size();
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
        qCWarning(lcModel) << "Projekt anlegen fehlgeschlagen:" << q.lastError().text();
        return -1;
    }

    int neueId = q.lastInsertId().toInt();
    laden(); // Liste aktualisieren
    return neueId;
}

bool ProjektModel::loeschen(int projektId)
{
    auto db = QSqlDatabase::database();

    // FK-Constraints temporär deaktivieren: mehrere Tabellen referenzieren
    // projekt(id) ohne ON DELETE CASCADE (changelog, anlage, betriebsmittel,
    // verbindung, kabel, klemmenleiste, leiter). Wir räumen sie manuell in
    // der richtigen Reihenfolge ab.
    QSqlQuery fk(db);
    fk.exec("PRAGMA foreign_keys = OFF");

    if (!db.transaction()) {
        fk.exec("PRAGMA foreign_keys = ON");
        qCWarning(lcModel) << "ProjektModel::loeschen: Transaktion fehlgeschlagen";
        return false;
    }

    auto del = [&](const char *sql) -> bool {
        QSqlQuery q(db);
        q.prepare(QString::fromUtf8(sql));
        q.bindValue(":id", projektId);
        if (!q.exec()) {
            qCWarning(lcModel) << "ProjektModel::loeschen:" << sql << q.lastError().text();
            return false;
        }
        return true;
    };

    bool ok = true;

    // 1. Klemmen-Unterebene
    ok &= del("DELETE FROM klemme_anschluss WHERE klemme_id IN "
              "(SELECT k.id FROM klemme k "
              " JOIN klemmenleiste kl ON k.klemmenleiste_id = kl.id "
              " WHERE kl.projekt_id = :id)");
    ok &= del("DELETE FROM klemme_stegbruecke WHERE klemmenleiste_id IN "
              "(SELECT id FROM klemmenleiste WHERE projekt_id = :id)");
    ok &= del("DELETE FROM klemme WHERE klemmenleiste_id IN "
              "(SELECT id FROM klemmenleiste WHERE projekt_id = :id)");
    ok &= del("DELETE FROM klemmenleiste WHERE projekt_id = :id");

    // 2. Verbindungs-Unterebene
    ok &= del("DELETE FROM leiter WHERE projekt_id = :id");
    ok &= del("DELETE FROM querverweis WHERE verbindung_id IN "
              "(SELECT id FROM verbindung WHERE projekt_id = :id)");
    ok &= del("DELETE FROM verbindung_segment WHERE verbindung_id IN "
              "(SELECT id FROM verbindung WHERE projekt_id = :id)");

    // 3. Kabel-Unterebene
    ok &= del("DELETE FROM kabel_ader WHERE kabel_id IN "
              "(SELECT id FROM kabel WHERE projekt_id = :id)");
    ok &= del("DELETE FROM kabel WHERE projekt_id = :id");

    // 4. Restliche direkte Projekt-Referenzen
    ok &= del("DELETE FROM verbindung    WHERE projekt_id = :id");
    ok &= del("DELETE FROM betriebsmittel WHERE projekt_id = :id");
    ok &= del("DELETE FROM changelog     WHERE projekt_id = :id");

    // 5. Seitenbaum (anlage→ort→seite→grafik_element)
    ok &= del("DELETE FROM grafik_element WHERE seite_id IN "
              "(SELECT s.id FROM seite s "
              " JOIN ort o ON s.ort_id = o.id "
              " JOIN anlage a ON o.anlage_id = a.id "
              " WHERE a.projekt_id = :id)");
    ok &= del("DELETE FROM seite WHERE ort_id IN "
              "(SELECT o.id FROM ort o "
              " JOIN anlage a ON o.anlage_id = a.id "
              " WHERE a.projekt_id = :id)");
    ok &= del("DELETE FROM ort WHERE anlage_id IN "
              "(SELECT id FROM anlage WHERE projekt_id = :id)");
    ok &= del("DELETE FROM anlage WHERE projekt_id = :id");

    // 6. Projekt selbst
    ok &= del("DELETE FROM projekt WHERE id = :id");

    if (ok)
        db.commit();
    else
        db.rollback();

    fk.exec("PRAGMA foreign_keys = ON");

    if (!ok) {
        qCWarning(lcModel) << "ProjektModel::loeschen: Rollback für Projekt" << projektId;
        return false;
    }

    laden();
    return true;
}
