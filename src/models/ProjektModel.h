#pragma once

#include <QAbstractListModel>
#include <QList>

// Einzelnes Projekt als Datenstruktur
struct Projekt {
    int     id;
    QString name;
    QString projektnummer;
    QString auftraggeber;
    QString auftragnehmer;
    QString bearbeiter;
    QString status;
    QString erstellt_am;
    QString bemerkung;
};

// ProjektModel macht die Projektliste für QML verfügbar.
//
// In QML verwendest du es so:
//
//   ListView {
//       model: projektModel
//       delegate: Text { text: model.name }
//   }
//
// Die "Roles" bestimmen welche Felder QML kennt.

class ProjektModel : public QAbstractListModel
{
    Q_OBJECT

public:
    // Roles = Spaltennamen die QML per model.xyz ansprechen kann
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ProjektnummerRole,
        AuftraggeberRole,
        AuftragnahmerRole,
        BearbeiterRole,
        StatusRole,
        ErstelltAmRole,
        BemerkungRole
    };

    explicit ProjektModel(QObject *parent = nullptr);

    // Pflichtmethoden für QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Daten neu aus DB laden
    Q_INVOKABLE void laden();

    // Neues Projekt anlegen, gibt neue ID zurück
    Q_INVOKABLE int anlegen(const QString &name,
                             const QString &projektnummer = {},
                             const QString &bemerkung = {});

    // Projekt löschen
    Q_INVOKABLE bool loeschen(int id);

private:
    QList<Projekt> m_projekte;
};
