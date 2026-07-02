#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QJsonDocument>
#include <QJsonObject>

// ============================================================
// elementeFuerExportSanitisieren (COPY-CROSS-01)
// Bereitet kopierte Elemente für den Export über die System-Zwischenablage
// vor: betriebsmittel_id wird als bauteilSnapshot in extra_daten eingebettet
// (wiederverwendet _bauteilSnapshotErzeugen aus Database_Makro.cpp), da die
// numerische ID im Zielprojekt/-instanz nicht existiert. betriebsmittelId
// selbst bleibt im Element stehen – harmlos, wird beim Import überschrieben,
// spart eine Fallunterscheidung für den Same-Project-Pfad.
//
// klemme_anschluss-Geist-Konvertierung (KLEMME-DUP-01) läuft bereits
// generisch beim Einfügen in CanvasAktionenHandler.qml
// (_duplizierAnzahlPlatzieren) und braucht hier keine Behandlung.
//
// Bekannte, bewusst nicht gelöste Lücke (identisch zum Makro-Feature):
// kabellinie.extraDaten.kabelId und geraetekasten/strukturkasten.
// extraDaten.ort_id werden nicht saniert und können im Zielprojekt auf
// nicht existierende Zeilen zeigen.
// ============================================================
QVariantList Database::elementeFuerExportSanitisieren(const QVariantList &elemente)
{
    QVariantList ergebnis;
    ergebnis.reserve(elemente.size());

    for (const QVariant &elV : elemente) {
        QVariantMap el = elV.toMap();
        const int betriebsmittelId = el.value(QStringLiteral("betriebsmittelId")).toInt();

        const QJsonObject snap = _bauteilSnapshotErzeugen(betriebsmittelId);
        if (!snap.isEmpty()) {
            QVariantMap extraDaten = el.value(QStringLiteral("extraDaten")).toMap();
            extraDaten[QStringLiteral("bauteilSnapshot")] = snap.toVariantMap();
            el[QStringLiteral("extraDaten")] = extraDaten;
        }
        ergebnis.append(el);
    }
    return ergebnis;
}

// ============================================================
// elementeFuerImportSanitisieren (COPY-CROSS-01)
// Kehrseite: beim Einfügen aus einem ANDEREN Projekt wird bauteilSnapshot
// aufgelöst (Bauteil in bibliothek.db finden/anlegen, betriebsmittel im
// Zielprojekt neu anlegen – wiederverwendet
// _betriebsmittelAusSnapshotAnlegenOderFinden aus Database_Makro.cpp),
// betriebsmittelId entsprechend ersetzt.
// ============================================================
QVariantList Database::elementeFuerImportSanitisieren(const QVariantList &elemente, int seiteId)
{
    QVariantList ergebnis;
    ergebnis.reserve(elemente.size());

    int projektId = -1;
    {
        QSqlQuery qs(m_db);
        qs.prepare("SELECT projekt_id FROM seite WHERE id = :sid");
        qs.bindValue(":sid", seiteId);
        if (qs.exec() && qs.next()) projektId = qs.value(0).toInt();
    }

    for (const QVariant &elV : elemente) {
        QVariantMap el = elV.toMap();
        QVariantMap extraDaten = el.value(QStringLiteral("extraDaten")).toMap();

        if (extraDaten.contains(QStringLiteral("bauteilSnapshot"))) {
            const QJsonObject snap = QJsonObject::fromVariantMap(
                extraDaten.value(QStringLiteral("bauteilSnapshot")).toMap());
            const QString bmk       = extraDaten.value(QStringLiteral("bmk")).toString();
            const QString symbolKey = el.value(QStringLiteral("symbolId")).toString();

            const QVariant bmId = _betriebsmittelAusSnapshotAnlegenOderFinden(
                snap, bmk, symbolKey, projektId);

            el[QStringLiteral("betriebsmittelId")] = bmId.isValid() ? bmId : QVariant(0);
            extraDaten.remove(QStringLiteral("bauteilSnapshot"));
            el[QStringLiteral("extraDaten")] = extraDaten;
        }
        ergebnis.append(el);
    }
    return ergebnis;
}
