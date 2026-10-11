// Gemeinsame Adress-Logik für SPS/PLS-Kanäle (SPS-INTEGRITAET-01):
// Überlappungsprüfung, Bereichsberechnung und Adress-Konflikte. Wird von
// Database_SPS.cpp (Anlegen/Ändern, Konflikt-Menge für den Canvas) und
// Database_DRC.cpp (D-14) gemeinsam genutzt, damit beide dieselbe Definition
// von „Konflikt" verwenden.
//
// Geltungsbereich einer Adresse (Entscheidung SPS-INTEGRITAET-01):
//  - SPS: je Rack. Racks sind unabhängige Adressräume (mehrere Stationen im
//    selben Projekt dürfen jeweils E0.0 haben). Kanäle ohne Baugruppe
//    (M/T/Z) bilden den gemeinsamen Bereich „ohne Rack".
//  - PLS: ein Kanal ist über Baugruppe + Kanal-Nr. + Richtung identifiziert.
#pragma once

#include <QString>
#include <QVector>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <algorithm>

namespace SpsAdressen {

struct Kanal {
    int     id          = 0;
    int     baugruppeId = 0;   // 0 = keine Baugruppe
    int     rackId      = 0;   // 0 = kein Rack
    bool    pls         = false;
    QString adressTyp;
    int     byteNr      = 0;
    int     bitNr       = 0;
    QString datentyp;
    int     kanalNr     = -1;  // -1 = nicht gesetzt
};

// Belegte Bytes eines Datentyps; BOOL belegt ein einzelnes Bit.
inline int bytes(const QString &datentyp)
{
    if (datentyp == QLatin1String("BYTE"))  return 1;
    if (datentyp == QLatin1String("WORD") || datentyp == QLatin1String("INT")) return 2;
    if (datentyp == QLatin1String("DWORD") || datentyp == QLatin1String("DINT")
        || datentyp == QLatin1String("REAL")) return 4;
    return 0;   // BOOL
}

inline bool ueberlappen(const Kanal &a, const Kanal &b)
{
    if (a.id != 0 && a.id == b.id) return false;
    if (a.rackId != b.rackId) return false;
    // PLS: Kanal-Nr. je Baugruppe, die Richtung (E/A) ist dort kein Teil der Identität.
    if (a.pls || b.pls) {
        return a.pls && b.pls && a.baugruppeId == b.baugruppeId
               && a.kanalNr >= 0 && a.kanalNr == b.kanalNr;
    }
    if (a.adressTyp != b.adressTyp) return false;
    const int na = bytes(a.datentyp), nb = bytes(b.datentyp);
    if (na == 0 && nb == 0)
        return a.byteNr == b.byteNr && a.bitNr == b.bitNr;
    const int aEnde = a.byteNr + std::max(na, 1) - 1;
    const int bEnde = b.byteNr + std::max(nb, 1) - 1;
    return a.byteNr <= bEnde && b.byteNr <= aEnde;
}

// Alle Kanäle des Projekts (mit Rack/System aus der Baugruppe).
inline QVector<Kanal> laden(const QSqlDatabase &db, int projektId)
{
    QVector<Kanal> r;
    QSqlQuery q(db);
    q.prepare("SELECT sk.id, sk.baugruppe_id, sb.rack_id, sr.system_typ, sk.adress_typ, "
              "sk.byte_nr, sk.bit_nr, sk.datentyp, sk.kanal_nr "
              "FROM sps_kanal sk "
              "LEFT JOIN sps_baugruppe sb ON sb.id = sk.baugruppe_id "
              "LEFT JOIN sps_rack sr ON sr.id = sb.rack_id "
              "WHERE sk.projekt_id = :pid ORDER BY sk.id");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return r;
    while (q.next()) {
        Kanal k;
        k.id          = q.value(0).toInt();
        k.baugruppeId = q.value(1).isNull() ? 0 : q.value(1).toInt();
        k.rackId      = q.value(2).isNull() ? 0 : q.value(2).toInt();
        k.pls         = q.value(3).toString() == QLatin1String("PLS");
        k.adressTyp   = q.value(4).toString();
        k.byteNr      = q.value(5).toInt();
        k.bitNr       = q.value(6).toInt();
        k.datentyp    = q.value(7).toString();
        k.kanalNr     = q.value(8).isNull() ? -1 : q.value(8).toInt();
        r.append(k);
    }
    return r;
}

// Rack-/System-Zuordnung einer Baugruppe in einen Kanal eintragen.
inline void baugruppeAufloesen(const QSqlDatabase &db, Kanal &k)
{
    k.rackId = 0; k.pls = false;
    if (k.baugruppeId <= 0) return;
    QSqlQuery q(db);
    q.prepare("SELECT sb.rack_id, sr.system_typ FROM sps_baugruppe sb "
              "JOIN sps_rack sr ON sr.id = sb.rack_id WHERE sb.id = :id");
    q.bindValue(":id", k.baugruppeId);
    if (q.exec() && q.next()) {
        k.rackId = q.value(0).toInt();
        k.pls    = q.value(1).toString() == QLatin1String("PLS");
    }
}

// Von einer SPS-Baugruppe belegter Byte-Bereich (nur E/A-Kanäle mit
// Startbyte). Liefert false, wenn für den Typ kein Bereich definiert ist.
// Gleiche Aufteilung wie das Auto-Anlegen in SpsAnsicht.qml: digital 1 Bit je
// Kanal, analog 2 Byte je Kanal, DIO/AIO je zur Hälfte Eingang/Ausgang.
inline bool bereich(const QString &bgTyp, int kanaele, int startByte, const QString &adressTyp,
                    int &von, int &bis)
{
    const bool dual   = (bgTyp == QLatin1String("DIO") || bgTyp == QLatin1String("AIO"));
    const bool analog = (bgTyp == QLatin1String("AI") || bgTyp == QLatin1String("AO")
                         || bgTyp == QLatin1String("AIO"));
    const bool digital = (bgTyp == QLatin1String("DI") || bgTyp == QLatin1String("DO")
                          || bgTyp == QLatin1String("DIO"));
    if (!analog && !digital) return false;
    int n = kanaele;
    if (dual) n = (adressTyp == QLatin1String("A")) ? kanaele / 2 : (kanaele + 1) / 2;
    if (n <= 0) return false;
    const int laenge = analog ? n * 2 : (n + 7) / 8;
    von = startByte;
    bis = startByte + laenge - 1;
    return true;
}

} // namespace SpsAdressen
