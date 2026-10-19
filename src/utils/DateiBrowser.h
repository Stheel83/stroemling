#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>

// Hilfsobjekt für den eigenen Dateiwähler (qml/components/DateiWaehlerDialog.qml). Der native FileDialog fällt im AppImage
// aus; dieser Wähler listet Ordner selbst auf. Nur lesend – legt nichts an und verändert nichts.
class DateiBrowser : public QObject
{
    Q_OBJECT
public:
    explicit DateiBrowser(QObject *parent = nullptr) : QObject(parent) {}

    // Inhalt eines Ordners: zuerst Unterordner, dann Dateien (nach Name, ohne Groß-/Kleinschreibung), keine versteckten Einträge.
    // `endungen` (z. B. [".json"]) filtert nur die Dateien, Ordner bleiben immer sichtbar; leer = alle Dateien.
    // Je Eintrag: {name, pfad, istOrdner, groesse (Text), geaendert (Text)}. Unlesbarer/fehlender Ordner → leere Liste.
    Q_INVOKABLE QVariantList inhalt(const QString &ordner, const QStringList &endungen = {}) const;
    // Übergeordneter Ordner ("/" bleibt "/").
    Q_INVOKABLE QString eltern(const QString &ordner) const;
    // Macht aus einer Eingabe (auch "~", "file://…", Dateipfad oder nicht vorhandener Pfad) einen existierenden Ordner:
    // Datei → ihr Ordner, sonst der nächste vorhandene Vorfahre, zuletzt der Heimordner.
    Q_INVOKABLE QString ordnerVon(const QString &eingabe) const;
    Q_INVOKABLE QString dateiname(const QString &pfad) const;
    Q_INVOKABLE QString verbinde(const QString &ordner, const QString &name) const;
    Q_INVOKABLE bool dateiExistiert(const QString &pfad) const;
};
