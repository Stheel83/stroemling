#include "KlemmeModel.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

// ============================================================
// FarbDefinitionModel
// ============================================================

FarbDefinitionModel::FarbDefinitionModel(QObject *parent)
    : QAbstractListModel(parent)
{
    laden();
}

void FarbDefinitionModel::laden()
{
    beginResetModel();
    m_farben.clear();

    QSqlQuery q;
    q.exec("SELECT id, COALESCE(hex_wert,''), bezeichnung, ist_standard "
           "FROM farb_definition ORDER BY sortierung, bezeichnung");
    while (q.next()) {
        FarbEintrag f;
        f.id          = q.value(0).toInt();
        f.hexWert     = q.value(1).toString();
        f.bezeichnung = q.value(2).toString();
        f.istStandard = q.value(3).toInt() != 0;
        m_farben.append(f);
    }

    endResetModel();
}

int FarbDefinitionModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_farben.size();
}

QVariant FarbDefinitionModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_farben.size())
        return {};

    const FarbEintrag &f = m_farben.at(index.row());
    switch (role) {
    case IdRole:          return f.id;
    case HexWertRole:     return f.hexWert;
    case BezeichnungRole: return f.bezeichnung;
    case IstStandardRole: return f.istStandard;
    default:              return {};
    }
}

QHash<int, QByteArray> FarbDefinitionModel::roleNames() const
{
    return {
        { IdRole,          "farbId"      },
        { HexWertRole,     "hexWert"     },
        { BezeichnungRole, "bezeichnung" },
        { IstStandardRole, "istStandard" },
    };
}

// ============================================================
// KlemmeModel
// ============================================================

KlemmeModel::KlemmeModel(QObject *parent)
    : QObject(parent)
{
}

void KlemmeModel::laden(int bauteilId)
{
    m_bauteilId  = bauteilId;
    m_klemmeId   = -1;
    m_klemme     = {};
    m_querschnitte.clear();
    m_bruecken.clear();

    if (bauteilId < 0) {
        emit klemmeGeladen();
        return;
    }

    QSqlQuery q;
    q.prepare("SELECT id, COALESCE(norm,''), anschluss_typ, "
              "ebenen_anzahl, punkte_seite_a, punkte_seite_b, "
              "fuss_kontakt_pe, stegbruecke_faehig, "
              "COALESCE(breite_mm, 0.0), COALESCE(gehaeuse_farbe_id, -1), "
              "COALESCE(bemerkung,'') "
              "FROM bauteil_klemme WHERE bauteil_id = :bid LIMIT 1");
    q.bindValue(":bid", bauteilId);

    if (q.exec() && q.next()) {
        m_klemmeId = q.value(0).toInt();
        m_klemme["klemmeId"]        = m_klemmeId;
        m_klemme["norm"]            = q.value(1).toString();
        m_klemme["anschlussTyp"]    = q.value(2).toString();
        m_klemme["ebenenAnzahl"]    = q.value(3).toInt();
        m_klemme["punkteSeitenA"]   = q.value(4).toInt();
        m_klemme["punkteSeitenB"]   = q.value(5).toInt();
        m_klemme["fussKontaktPe"]   = q.value(6).toInt() != 0;
        m_klemme["stegbrueckeFaehig"] = q.value(7).toInt() != 0;
        m_klemme["breiteMm"]        = q.value(8).toDouble();
        m_klemme["gehaeuseFarbeId"] = q.value(9).toInt();
        m_klemme["bemerkung"]       = q.value(10).toString();

        ladeQuerschnitte();
        ladeBruecken();
    }

    emit klemmeGeladen();
}

int KlemmeModel::anlegen(int bauteilId)
{
    QSqlQuery q;
    q.prepare("INSERT INTO bauteil_klemme "
              "(bauteil_id, anschluss_typ, ebenen_anzahl, punkte_seite_a, punkte_seite_b) "
              "VALUES (:bid, 'schraube', 1, 1, 1)");
    q.bindValue(":bid", bauteilId);
    if (!q.exec()) {
        qWarning() << "KlemmeModel::anlegen:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden(bauteilId);
    return newId;
}

bool KlemmeModel::speichern(const QVariantMap &daten)
{
    if (m_klemmeId < 0) return false;

    QSqlQuery q;
    q.prepare("UPDATE bauteil_klemme SET "
              "norm = :norm, anschluss_typ = :typ, "
              "ebenen_anzahl = :eb, punkte_seite_a = :pa, punkte_seite_b = :pb, "
              "fuss_kontakt_pe = :pe, stegbruecke_faehig = :steg, "
              "breite_mm = :bm, gehaeuse_farbe_id = :fid, bemerkung = :bem "
              "WHERE id = :id");
    q.bindValue(":norm", daten["norm"].toString().isEmpty()
                         ? QVariant() : daten["norm"]);
    q.bindValue(":typ",  daten["anschlussTyp"].toString());
    q.bindValue(":eb",   daten["ebenenAnzahl"].toInt());
    q.bindValue(":pa",   daten["punkteSeitenA"].toInt());
    q.bindValue(":pb",   daten["punkteSeitenB"].toInt());
    q.bindValue(":pe",   daten["fussKontaktPe"].toBool() ? 1 : 0);
    q.bindValue(":steg", daten["stegbrueckeFaehig"].toBool() ? 1 : 0);
    q.bindValue(":bm",   daten["breiteMm"].toDouble() > 0
                         ? daten["breiteMm"] : QVariant());
    int fid = daten["gehaeuseFarbeId"].toInt();
    q.bindValue(":fid",  fid > 0 ? fid : QVariant());
    q.bindValue(":bem",  daten["bemerkung"].toString());
    q.bindValue(":id",   m_klemmeId);

    if (!q.exec()) {
        qWarning() << "KlemmeModel::speichern:" << q.lastError().text();
        return false;
    }

    // PE-Fußkontakt-Brücke automatisch verwalten:
    // unterste Ebene (ebenen_anzahl) ↔ PE-Fußkontakt.
    bool peFuss   = daten["fussKontaktPe"].toBool();
    int  ebAnzahl = daten["ebenenAnzahl"].toInt();
    if (peFuss) {
        QSqlQuery qpe;
        qpe.prepare("INSERT OR IGNORE INTO bauteil_klemme_bruecke "
                    "(klemme_id, von_ebene, nach_ebene, ist_pe_fuss) "
                    "VALUES (:kid, :eb, :eb, 1)");
        qpe.bindValue(":kid", m_klemmeId);
        qpe.bindValue(":eb",  ebAnzahl > 0 ? ebAnzahl : 1);
        qpe.exec();
    } else {
        QSqlQuery qpe;
        qpe.prepare("DELETE FROM bauteil_klemme_bruecke "
                    "WHERE klemme_id = :kid AND ist_pe_fuss = 1");
        qpe.bindValue(":kid", m_klemmeId);
        qpe.exec();
    }

    laden(m_bauteilId);
    return true;
}

bool KlemmeModel::loeschen()
{
    if (m_klemmeId < 0) return false;

    QSqlQuery q;
    // Abhängige Daten zuerst löschen (kein CASCADE im Schema)
    q.prepare("DELETE FROM bauteil_klemme_eigenschaft WHERE klemme_id = :id");
    q.bindValue(":id", m_klemmeId); q.exec();

    q.prepare("DELETE FROM bauteil_klemme_bruecke WHERE klemme_id = :id");
    q.bindValue(":id", m_klemmeId); q.exec();

    q.prepare("DELETE FROM bauteil_klemme_querschnitt WHERE klemme_id = :id");
    q.bindValue(":id", m_klemmeId); q.exec();

    q.prepare("DELETE FROM bauteil_klemme WHERE id = :id");
    q.bindValue(":id", m_klemmeId);
    if (!q.exec()) {
        qWarning() << "KlemmeModel::loeschen:" << q.lastError().text();
        return false;
    }
    laden(m_bauteilId);
    return true;
}

void KlemmeModel::ladeQuerschnitte()
{
    m_querschnitte.clear();
    QSqlQuery q;
    q.prepare("SELECT id, adertyp, min_mm2, max_mm2 "
              "FROM bauteil_klemme_querschnitt WHERE klemme_id = :kid "
              "ORDER BY adertyp");
    q.bindValue(":kid", m_klemmeId);
    if (!q.exec()) return;

    while (q.next()) {
        QVariantMap m;
        m["id"]      = q.value(0).toInt();
        m["adertyp"] = q.value(1).toString();
        m["minMm2"]  = q.value(2).toDouble();
        m["maxMm2"]  = q.value(3).toDouble();
        m_querschnitte.append(m);
    }
}

void KlemmeModel::ladeBruecken()
{
    m_bruecken.clear();
    QSqlQuery q;
    q.prepare("SELECT id, von_ebene, nach_ebene, ist_pe_fuss "
              "FROM bauteil_klemme_bruecke WHERE klemme_id = :kid "
              "ORDER BY von_ebene, nach_ebene");
    q.bindValue(":kid", m_klemmeId);
    if (!q.exec()) return;

    while (q.next()) {
        QVariantMap m;
        m["id"]        = q.value(0).toInt();
        m["vonEbene"]  = q.value(1).toInt();
        m["nachEbene"] = q.value(2).toInt();
        m["istPeFuss"] = q.value(3).toInt() != 0;
        m_bruecken.append(m);
    }
}

bool KlemmeModel::querschnittSetzen(const QString &adertyp, double min, double max)
{
    if (m_klemmeId < 0) return false;

    QSqlQuery q;
    // UPSERT: update falls vorhanden, sonst insert
    q.prepare("SELECT id FROM bauteil_klemme_querschnitt "
              "WHERE klemme_id = :kid AND adertyp = :typ");
    q.bindValue(":kid", m_klemmeId);
    q.bindValue(":typ", adertyp);

    if (q.exec() && q.next()) {
        int eid = q.value(0).toInt();
        q.prepare("UPDATE bauteil_klemme_querschnitt "
                  "SET min_mm2 = :min, max_mm2 = :max WHERE id = :id");
        q.bindValue(":min", min); q.bindValue(":max", max); q.bindValue(":id", eid);
    } else {
        q.prepare("INSERT INTO bauteil_klemme_querschnitt "
                  "(klemme_id, adertyp, min_mm2, max_mm2) VALUES (:kid, :typ, :min, :max)");
        q.bindValue(":kid", m_klemmeId); q.bindValue(":typ", adertyp);
        q.bindValue(":min", min); q.bindValue(":max", max);
    }

    if (!q.exec()) {
        qWarning() << "querschnittSetzen:" << q.lastError().text();
        return false;
    }
    ladeQuerschnitte();
    emit klemmeGeladen();
    return true;
}

bool KlemmeModel::querschnittLoeschen(const QString &adertyp)
{
    if (m_klemmeId < 0) return false;

    QSqlQuery q;
    q.prepare("DELETE FROM bauteil_klemme_querschnitt "
              "WHERE klemme_id = :kid AND adertyp = :typ");
    q.bindValue(":kid", m_klemmeId);
    q.bindValue(":typ", adertyp);
    if (!q.exec()) {
        qWarning() << "querschnittLoeschen:" << q.lastError().text();
        return false;
    }
    ladeQuerschnitte();
    emit klemmeGeladen();
    return true;
}

bool KlemmeModel::brueckeAnlegen(int vonEbene, int nachEbene)
{
    if (m_klemmeId < 0) return false;

    // Doppelte Einträge verhindern
    QSqlQuery q;
    q.prepare("SELECT id FROM bauteil_klemme_bruecke "
              "WHERE klemme_id = :kid AND von_ebene = :v AND nach_ebene = :n");
    q.bindValue(":kid", m_klemmeId);
    q.bindValue(":v",   vonEbene);
    q.bindValue(":n",   nachEbene);
    if (q.exec() && q.next()) return true; // bereits vorhanden

    q.prepare("INSERT INTO bauteil_klemme_bruecke (klemme_id, von_ebene, nach_ebene) "
              "VALUES (:kid, :v, :n)");
    q.bindValue(":kid", m_klemmeId);
    q.bindValue(":v",   vonEbene);
    q.bindValue(":n",   nachEbene);
    if (!q.exec()) {
        qWarning() << "brueckeAnlegen:" << q.lastError().text();
        return false;
    }
    ladeBruecken();
    emit klemmeGeladen();
    return true;
}

bool KlemmeModel::brueckeLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM bauteil_klemme_bruecke WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "brueckeLoeschen:" << q.lastError().text();
        return false;
    }
    ladeBruecken();
    emit klemmeGeladen();
    return true;
}

QVariantList KlemmeModel::anschluesse() const
{
    QVariantList result;
    if (!hatKlemme()) return result;

    int  ebenen = m_klemme["ebenenAnzahl"].toInt();
    int  pA     = m_klemme["punkteSeitenA"].toInt();
    int  pB     = m_klemme["punkteSeitenB"].toInt();
    bool pe     = m_klemme["fussKontaktPe"].toBool();

    for (int e = 1; e <= ebenen; ++e) {
        int idx = 1;
        for (int a = 0; a < pA; ++a, ++idx) {
            QVariantMap anschluss;
            anschluss["bezeichnung"] = QString("%1.%2").arg(e).arg(idx);
            anschluss["seite"]       = "A";
            anschluss["ebene"]       = e;
            result.append(anschluss);
        }
        for (int b = 0; b < pB; ++b, ++idx) {
            QVariantMap anschluss;
            anschluss["bezeichnung"] = QString("%1.%2").arg(e).arg(idx);
            anschluss["seite"]       = "B";
            anschluss["ebene"]       = e;
            result.append(anschluss);
        }
    }

    if (pe) {
        QVariantMap anschluss;
        anschluss["bezeichnung"] = "PE";
        anschluss["seite"]       = QString::fromUtf8("Fu\xc3\x9f");
        anschluss["ebene"]       = "–";
        result.append(anschluss);
    }

    return result;
}

QVariantMap KlemmeModel::klemmeDetailsHolen(int klemmeId, const QString &anschlussBezeichnung) const
{
    QVariantMap result;
    result["ok"] = false;

    QSqlQuery q;
    q.prepare("SELECT COALESCE(norm,''), anschluss_typ, ebenen_anzahl, "
              "punkte_seite_a, punkte_seite_b, fuss_kontakt_pe, "
              "stegbruecke_faehig, COALESCE(breite_mm, 0.0) "
              "FROM bauteil_klemme WHERE id = :id");
    q.bindValue(":id", klemmeId);
    if (!q.exec() || !q.next()) return result;

    result["ok"]                = true;
    result["norm"]              = q.value(0).toString();
    result["anschlussTyp"]      = q.value(1).toString();
    int  ebenenAnzahl           = q.value(2).toInt();
    int  pktA                   = q.value(3).toInt();
    int  pktB                   = q.value(4).toInt();
    bool peFuss                 = q.value(5).toInt() != 0;
    result["ebenenAnzahl"]      = ebenenAnzahl;
    result["punkteSeitenA"]     = pktA;
    result["punkteSeitenB"]     = pktB;
    result["fussKontaktPe"]     = peFuss;
    result["stegbrueckeFaehig"] = q.value(6).toInt() != 0;
    result["breiteMm"]          = q.value(7).toDouble();

    // Interne Ebenenbrücken (für Vorschau-Rendering)
    QSqlQuery qB;
    qB.prepare("SELECT von_ebene, nach_ebene FROM bauteil_klemme_bruecke WHERE klemme_id = :id ORDER BY id");
    qB.bindValue(":id", klemmeId);
    QVariantList bruecken;
    if (qB.exec()) {
        while (qB.next()) {
            QVariantMap br;
            br["vonEbene"]  = qB.value(0).toInt();
            br["nachEbene"] = qB.value(1).toInt();
            bruecken.append(br);
        }
    }
    result["bruecken"] = bruecken;

    // Querschnitte
    QSqlQuery qQ;
    qQ.prepare("SELECT adertyp, min_mm2, max_mm2 FROM bauteil_klemme_querschnitt "
               "WHERE klemme_id = :id ORDER BY id");
    qQ.bindValue(":id", klemmeId);
    QVariantList querschnitte;
    if (qQ.exec()) {
        while (qQ.next()) {
            QVariantMap qs;
            qs["adertyp"] = qQ.value(0).toString();
            qs["minMm2"]  = qQ.value(1).toDouble();
            qs["maxMm2"]  = qQ.value(2).toDouble();
            querschnitte.append(qs);
        }
    }
    result["querschnitte"] = querschnitte;

    // Anschluss-Seite + Ebene aus Bezeichnung ableiten (gleiche Logik wie anschluesse())
    result["anschlussSeite"] = "";
    result["anschlussEbene"] = QVariant();

    if (!anschlussBezeichnung.isEmpty()) {
        bool found = false;
        for (int e = 1; e <= ebenenAnzahl && !found; ++e) {
            int idx = 1;
            for (int a = 0; a < pktA && !found; ++a, ++idx) {
                if (QString("%1.%2").arg(e).arg(idx) == anschlussBezeichnung) {
                    result["anschlussSeite"] = "A";
                    result["anschlussEbene"] = e;
                    found = true;
                }
            }
            for (int b = 0; b < pktB && !found; ++b, ++idx) {
                if (QString("%1.%2").arg(e).arg(idx) == anschlussBezeichnung) {
                    result["anschlussSeite"] = "B";
                    result["anschlussEbene"] = e;
                    found = true;
                }
            }
        }
        if (!found && peFuss && anschlussBezeichnung == QLatin1String("PE")) {
            result["anschlussSeite"] = QString::fromUtf8("Fu\xc3\x9f");
            result["anschlussEbene"] = 0;
        }
    }

    return result;
}
