#include "logging.h"
#include "KlemmenreihenModel.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

// ============================================================
// KlemmenleistenModel
// ============================================================

KlemmenleistenModel::KlemmenleistenModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void KlemmenleistenModel::laden(int projektId)
{
    beginResetModel();
    m_projektId = projektId;
    m_leisten.clear();

    if (projektId < 0) {
        endResetModel();
        emit geladen();
        return;
    }

    QSqlQuery q;
    q.prepare(
        "SELECT kl.id, kl.bezeichnung, kl.ausrichtung, "
        "COALESCE(klb.bmk_kurz, '-' || kl.bezeichnung) AS bmk_kurz, "
        "COUNT(k.id) AS anz, "
        "COALESCE(SUM(bk.breite_mm), 0) AS gesamt_mm "
        "FROM klemmenleiste kl "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "LEFT JOIN klemme k ON k.klemmenleiste_id = kl.id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "WHERE kl.projekt_id = :pid "
        "GROUP BY kl.id "
        "ORDER BY kl.bezeichnung"
    );
    q.bindValue(":pid", projektId);

    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenleistenModel::laden:" << q.lastError().text();
        endResetModel();
        emit geladen();
        return;
    }

    while (q.next()) {
        Eintrag e;
        e.id             = q.value(0).toInt();
        e.bezeichnung    = q.value(1).toString();
        e.ausrichtung    = q.value(2).toString();
        e.bmkKurz        = q.value(3).toString();
        e.anzahlKlemmen  = q.value(4).toInt();
        e.gesamtBreiteMm = q.value(5).toDouble();
        m_leisten.append(e);
    }

    endResetModel();
    emit geladen();
}

int KlemmenleistenModel::anlegen(int projektId, const QString &bezeichnung)
{
    QSqlQuery q;
    q.prepare("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (:pid, :bez)");
    q.bindValue(":pid", projektId);
    q.bindValue(":bez", bezeichnung.trimmed());
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenleistenModel::anlegen:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden(projektId);
    return newId;
}

void KlemmenleistenModel::beispielLeistenAnlegen(int projektId)
{
    auto bauteilIdFuer = [](const QString &bez) -> int {
        QSqlQuery q;
        q.prepare("SELECT id FROM bauteil WHERE bezeichnung = :bez LIMIT 1");
        q.bindValue(":bez", bez);
        if (q.exec() && q.next()) return q.value(0).toInt();
        return -1;
    };

    int idDurch = bauteilIdFuer("Durchgangsklemme 2,5mm²");
    int idPE    = bauteilIdFuer("PE-Klemme 2,5mm²");
    if (idDurch < 0 || idPE < 0) {
        qCWarning(lcModel) << "beispielLeistenAnlegen: Seed-Klemmen nicht gefunden";
        return;
    }

    QSqlQuery q;
    q.prepare("INSERT INTO klemmenleiste (projekt_id, bezeichnung) VALUES (:pid, :bez)");
    q.bindValue(":pid", projektId);
    q.bindValue(":bez", QString("X1"));
    if (!q.exec()) {
        qCWarning(lcModel) << "beispielLeistenAnlegen: klemmenleiste" << q.lastError().text();
        return;
    }
    int leisteId = q.lastInsertId().toInt();

    struct Eintrag { int bId; QString nr; };
    const QList<Eintrag> eintraege = {
        { idDurch, "1" }, { idDurch, "2" }, { idDurch, "3" },
        { idDurch, "4" }, { idDurch, "5" }, { idPE,    "PE" }
    };

    QSqlQuery qi;
    qi.prepare("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) "
               "VALUES (:lid, :bid, :nr, :sort)");
    for (int i = 0; i < eintraege.size(); ++i) {
        qi.bindValue(":lid",  leisteId);
        qi.bindValue(":bid",  eintraege[i].bId);
        qi.bindValue(":nr",   eintraege[i].nr);
        qi.bindValue(":sort", i + 1);
        if (!qi.exec())
            qCWarning(lcModel) << "beispielLeistenAnlegen klemme" << eintraege[i].nr << qi.lastError().text();
    }

    laden(projektId);
}

bool KlemmenleistenModel::loeschen(int id)
{
    // Klemmen-Instanzen zuerst löschen
    QSqlQuery q;
    q.prepare("DELETE FROM klemme WHERE klemmenleiste_id = :id");
    q.bindValue(":id", id); q.exec();

    q.prepare("DELETE FROM klemmenleiste WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenleistenModel::loeschen:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool KlemmenleistenModel::umbenennen(int id, const QString &bezeichnung)
{
    QSqlQuery q;
    q.prepare("UPDATE klemmenleiste SET bezeichnung = :bez WHERE id = :id");
    q.bindValue(":bez", bezeichnung.trimmed());
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenleistenModel::umbenennen:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

int KlemmenleistenModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_leisten.size();
}

QVariant KlemmenleistenModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_leisten.size()) return {};
    const Eintrag &e = m_leisten.at(index.row());
    switch (role) {
    case IdRole:             return e.id;
    case BezeichnungRole:    return e.bezeichnung;
    case AusrichtungRole:    return e.ausrichtung;
    case BmkKurzRole:        return e.bmkKurz;
    case AnzahlKlemmenRole:  return e.anzahlKlemmen;
    case GesamtBreiteMmRole: return e.gesamtBreiteMm;
    default:                 return {};
    }
}

QHash<int, QByteArray> KlemmenleistenModel::roleNames() const
{
    return {
        { IdRole,             "leisteId"       },
        { BezeichnungRole,    "bezeichnung"    },
        { AusrichtungRole,    "ausrichtung"    },
        { BmkKurzRole,        "bmkKurz"        },
        { AnzahlKlemmenRole,  "anzahlKlemmen"  },
        { GesamtBreiteMmRole, "gesamtBreiteMm" },
    };
}

// ============================================================
// KlemmenreiheModel
// ============================================================

KlemmenreiheModel::KlemmenreiheModel(QObject *parent)
    : QObject(parent)
{
}

void KlemmenreiheModel::laden(int leisteId)
{
    m_leisteId = leisteId;
    m_leiste   = {};
    m_klemmen.clear();

    if (leisteId < 0) {
        emit leisteGeladen();
        return;
    }

    QSqlQuery q;
    q.prepare(
        "SELECT kl.id, kl.bezeichnung, kl.ausrichtung, "
        "COALESCE(kl.anlage_uebergeordnet,''), "
        "COALESCE(kl.standort_uebergeordnet,''), "
        "COALESCE(kl.bemerkung,''), kl.projekt_id, "
        "COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung), "
        "COALESCE(klb.bmk_kurz, '-' || kl.bezeichnung) "
        "FROM klemmenleiste kl "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "WHERE kl.id = :id"
    );
    q.bindValue(":id", leisteId);

    if (!q.exec() || !q.next()) {
        qCWarning(lcModel) << "KlemmenreiheModel::laden – Leiste nicht gefunden:" << leisteId;
        emit leisteGeladen();
        return;
    }

    m_leiste["leisteId"]              = q.value(0).toInt();
    m_leiste["bezeichnung"]           = q.value(1).toString();
    m_leiste["ausrichtung"]           = q.value(2).toString();
    m_leiste["anlageUebergeordnet"]   = q.value(3).toString();
    m_leiste["standortUebergeordnet"] = q.value(4).toString();
    m_leiste["bemerkung"]             = q.value(5).toString();
    m_leiste["projektId"]             = q.value(6).toInt();
    m_leiste["bmkVollstaendig"]       = q.value(7).toString();
    m_leiste["bmkKurz"]               = q.value(8).toString();

    ladeKlemmen();
    emit leisteGeladen();
}

void KlemmenreiheModel::ladeStegbruecken()
{
    m_stegbruecken.clear();
    if (m_leisteId < 0) return;

    QSqlQuery q;
    q.prepare(
        "SELECT ks.id, ks.ebene, ks.von_klemme_id, ks.bis_klemme_id, "
        "COALESCE(ks.potenzial_text,''), ks.hat_konflikt, COALESCE(ks.konflikt_text,''), "
        "kv.nummer AS von_nr, kb.nummer AS bis_nr "
        "FROM klemme_stegbruecke ks "
        "JOIN klemme kv ON kv.id = ks.von_klemme_id "
        "JOIN klemme kb ON kb.id = ks.bis_klemme_id "
        "WHERE ks.klemmenleiste_id = :lid "
        "ORDER BY ks.ebene, kv.sortierung"
    );
    q.bindValue(":lid", m_leisteId);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::ladeStegbruecken:" << q.lastError().text();
        return;
    }

    // Klemme-ID → Index-Mapping aufbauen
    QHash<int, int> klemmeIdx;
    for (int i = 0; i < m_klemmen.size(); ++i)
        klemmeIdx[m_klemmen[i].toMap()["klemmeId"].toInt()] = i;

    while (q.next()) {
        QVariantMap s;
        s["stegId"]        = q.value(0).toInt();
        s["ebene"]         = q.value(1).toInt();
        s["vonKlemmeId"]   = q.value(2).toInt();
        s["bisKlemmeId"]   = q.value(3).toInt();
        s["potenzialText"] = q.value(4).toString();
        s["hatKonflikt"]   = q.value(5).toInt() != 0;
        s["konfliktText"]  = q.value(6).toString();
        s["vonNummer"]     = q.value(7).toString();
        s["bisNummer"]     = q.value(8).toString();
        s["vonIdx"]        = klemmeIdx.value(q.value(2).toInt(), -1);
        s["bisIdx"]        = klemmeIdx.value(q.value(3).toInt(), -1);
        m_stegbruecken.append(s);
    }
}

QString KlemmenreiheModel::pruefUeberlappung(int ebene, int vonKlemmeId, int bisKlemmeId, int skipId) const
{
    // Sortierung der von/bis-Klemmen herausfinden
    int vonSort = -1, bisSort = -1;
    for (const QVariant &v : m_klemmen) {
        QVariantMap k = v.toMap();
        if (k["klemmeId"].toInt() == vonKlemmeId) vonSort = k["sortierung"].toInt();
        if (k["klemmeId"].toInt() == bisKlemmeId) bisSort = k["sortierung"].toInt();
    }
    if (vonSort < 0 || bisSort < 0) return {};
    if (vonSort > bisSort) qSwap(vonSort, bisSort);

    // Bereits vorhandene Stegbrücken auf gleicher Ebene prüfen
    for (const QVariant &v : m_stegbruecken) {
        QVariantMap s = v.toMap();
        if (s["ebene"].toInt() != ebene) continue;
        if (skipId >= 0 && s["stegId"].toInt() == skipId) continue;

        int eVonSort = -1, eBisSort = -1;
        for (const QVariant &kv : m_klemmen) {
            QVariantMap k = kv.toMap();
            if (k["klemmeId"].toInt() == s["vonKlemmeId"].toInt()) eVonSort = k["sortierung"].toInt();
            if (k["klemmeId"].toInt() == s["bisKlemmeId"].toInt()) eBisSort = k["sortierung"].toInt();
        }
        if (eVonSort < 0 || eBisSort < 0) continue;
        if (eVonSort > eBisSort) qSwap(eVonSort, eBisSort);

        // Überlappung: [vonSort..bisSort] ∩ [eVonSort..eBisSort] != {}
        if (vonSort <= eBisSort && eVonSort <= bisSort) {
            return QString("Überlappung mit bestehender Stegbrücke Eb.%1 K%2–K%3")
                .arg(ebene).arg(s["vonNummer"].toString()).arg(s["bisNummer"].toString());
        }
    }
    return {};
}

void KlemmenreiheModel::ladeKlemmen()
{
    m_klemmen.clear();

    QSqlQuery q;
    q.prepare(
        "SELECT k.id, k.bauteil_id, k.nummer, k.sortierung, "
        "COALESCE(b.bezeichnung,''), COALESCE(bk.anschluss_typ,''), "
        "COALESCE(bk.breite_mm, 0.0), bk.id AS bauteilKlemmeId, "
        "(SELECT GROUP_CONCAT("
        "    CASE bkq.adertyp "
        "        WHEN 'starr'         THEN 'Starr' "
        "        WHEN 'flexibel'      THEN 'Flexibel' "
        "        WHEN 'aenh_blank'    THEN 'AEH blank' "
        "        WHEN 'aenh_isoliert' THEN 'AEH iso.' "
        "        ELSE bkq.adertyp END "
        "    || ': ' || bkq.min_mm2 || '\xe2\x80\x93' || bkq.max_mm2 || ' mm\xc2\xb2', ', ') "
        " FROM bauteil_klemme_querschnitt bkq WHERE bkq.klemme_id = bk.id) "
        "FROM klemme k "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "WHERE k.klemmenleiste_id = :lid "
        "ORDER BY k.sortierung, k.id"
    );
    q.bindValue(":lid", m_leisteId);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::ladeKlemmen:" << q.lastError().text();
        return;
    }

    while (q.next()) {
        QVariantMap k;
        k["klemmeId"]        = q.value(0).toInt();
        k["bauteilId"]       = q.value(1).toInt();
        k["nummer"]          = q.value(2).toString();
        k["sortierung"]      = q.value(3).toInt();
        k["bauteilName"]     = q.value(4).toString();
        k["anschlussTyp"]    = q.value(5).toString();
        k["breiteMm"]        = q.value(6).toDouble();
        k["bauteilKlemmeId"] = q.value(7).toInt();
        k["querschnitteText"]= q.value(8).toString();
        m_klemmen.append(k);
    }
    ladeStegbruecken();
}

bool KlemmenreiheModel::leisteAktualisieren(const QVariantMap &daten)
{
    if (m_leisteId < 0) return false;

    QSqlQuery q;
    q.prepare(
        "UPDATE klemmenleiste SET "
        "bezeichnung = :bez, ausrichtung = :aus, "
        "anlage_uebergeordnet = :auo, standort_uebergeordnet = :suo, "
        "bemerkung = :bem "
        "WHERE id = :id"
    );
    q.bindValue(":bez", daten["bezeichnung"].toString());
    q.bindValue(":aus", daten["ausrichtung"].toString());
    QString auo = daten["anlageUebergeordnet"].toString();
    QString suo = daten["standortUebergeordnet"].toString();
    q.bindValue(":auo", auo.isEmpty() ? QVariant() : auo);
    q.bindValue(":suo", suo.isEmpty() ? QVariant() : suo);
    q.bindValue(":bem", daten["bemerkung"].toString());
    q.bindValue(":id",  m_leisteId);

    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::leisteAktualisieren:" << q.lastError().text();
        return false;
    }
    laden(m_leisteId);
    return true;
}

int KlemmenreiheModel::klemmeAnlegen(int bauteilId)
{
    if (m_leisteId < 0) return -1;

    // Nächste Sortierung bestimmen
    QSqlQuery q;
    q.prepare("SELECT COALESCE(MAX(sortierung), 0) + 1 FROM klemme WHERE klemmenleiste_id = :lid");
    q.bindValue(":lid", m_leisteId);
    int nextSort = (q.exec() && q.next()) ? q.value(0).toInt() : 1;

    // Nächste Nummer bestimmen (numerisch, lückenlos)
    q.prepare("SELECT COALESCE(MAX(CAST(nummer AS INTEGER)), 0) + 1 "
              "FROM klemme WHERE klemmenleiste_id = :lid");
    q.bindValue(":lid", m_leisteId);
    QString nextNr = QString::number((q.exec() && q.next()) ? q.value(0).toInt() : 1);

    q.prepare("INSERT INTO klemme (klemmenleiste_id, bauteil_id, nummer, sortierung) "
              "VALUES (:lid, :bid, :nr, :srt)");
    q.bindValue(":lid", m_leisteId);
    q.bindValue(":bid", bauteilId > 0 ? bauteilId : QVariant());
    q.bindValue(":nr",  nextNr);
    q.bindValue(":srt", nextSort);

    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::klemmeAnlegen:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    ladeKlemmen();
    emit leisteGeladen();
    return newId;
}

bool KlemmenreiheModel::klemmeLoeschen(int klemmeId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM klemme WHERE id = :id");
    q.bindValue(":id", klemmeId);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::klemmeLoeschen:" << q.lastError().text();
        return false;
    }
    ladeKlemmen();
    emit leisteGeladen();
    return true;
}

bool KlemmenreiheModel::klemmeSchieben(int klemmeId, int richtung)
{
    // Alle Klemmen laden und den Index der zu verschiebenden Klemme finden
    int idx = -1;
    for (int i = 0; i < m_klemmen.size(); ++i) {
        if (m_klemmen[i].toMap()["klemmeId"].toInt() == klemmeId) {
            idx = i; break;
        }
    }
    if (idx < 0) return false;

    int tauschIdx = idx + richtung;
    if (tauschIdx < 0 || tauschIdx >= m_klemmen.size()) return false;

    int sortA = m_klemmen[idx].toMap()["sortierung"].toInt();
    int sortB = m_klemmen[tauschIdx].toMap()["sortierung"].toInt();
    int idB   = m_klemmen[tauschIdx].toMap()["klemmeId"].toInt();

    // Sortierungen tauschen – temp. Wert um Unique-Constraint-Probleme zu umgehen
    QSqlQuery q;
    q.prepare("UPDATE klemme SET sortierung = -999 WHERE id = :id");
    q.bindValue(":id", klemmeId); q.exec();

    q.prepare("UPDATE klemme SET sortierung = :s WHERE id = :id");
    q.bindValue(":s", sortA); q.bindValue(":id", idB); q.exec();

    q.prepare("UPDATE klemme SET sortierung = :s WHERE id = :id");
    q.bindValue(":s", sortB); q.bindValue(":id", klemmeId); q.exec();

    ladeKlemmen();
    emit leisteGeladen();
    return true;
}

bool KlemmenreiheModel::klemmeNummerSetzen(int klemmeId, const QString &nummer)
{
    QSqlQuery q;
    q.prepare("UPDATE klemme SET nummer = :nr WHERE id = :id");
    q.bindValue(":nr", nummer);
    q.bindValue(":id", klemmeId);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::klemmeNummerSetzen:" << q.lastError().text();
        return false;
    }
    ladeKlemmen();
    emit leisteGeladen();
    return true;
}

bool KlemmenreiheModel::klemmeBauteilSetzen(int klemmeId, int bauteilId)
{
    QSqlQuery q;
    q.prepare("UPDATE klemme SET bauteil_id = :bid WHERE id = :id");
    q.bindValue(":bid", bauteilId > 0 ? QVariant(bauteilId) : QVariant());
    q.bindValue(":id",  klemmeId);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::klemmeBauteilSetzen:" << q.lastError().text();
        return false;
    }
    ladeKlemmen();
    emit leisteGeladen();
    return true;
}

bool KlemmenreiheModel::klemmeMehrfachBauteilSetzen(const QVariantList &ids, int bauteilId)
{
    if (ids.isEmpty() || m_leisteId < 0) return false;
    QVariant bid = bauteilId > 0 ? QVariant(bauteilId) : QVariant();
    bool ok = true;
    for (const QVariant &v : ids) {
        QSqlQuery q;
        q.prepare("UPDATE klemme SET bauteil_id = :bid WHERE id = :id");
        q.bindValue(":bid", bid);
        q.bindValue(":id",  v.toInt());
        if (!q.exec()) { qCWarning(lcModel) << "klemmeMehrfachBauteilSetzen:" << q.lastError().text(); ok = false; }
    }
    ladeKlemmen();
    emit leisteGeladen();
    return ok;
}

bool KlemmenreiheModel::klemmeMehrfachNummerieren(const QVariantList &ids, int start)
{
    if (ids.isEmpty() || m_leisteId < 0) return false;
    bool ok = true;
    int  num = start;
    for (const QVariant &v : ids) {
        QSqlQuery q;
        q.prepare("UPDATE klemme SET nummer = :nr WHERE id = :id");
        q.bindValue(":nr", QString::number(num++));
        q.bindValue(":id", v.toInt());
        if (!q.exec()) { qCWarning(lcModel) << "klemmeMehrfachNummerieren:" << q.lastError().text(); ok = false; }
    }
    ladeKlemmen();
    emit leisteGeladen();
    return ok;
}

QVariantList KlemmenreiheModel::klemmeBauteileHolen(const QString &suchtext) const
{
    QVariantList liste;
    QString such = suchtext.trimmed();

    QString sql =
        "SELECT b.id, b.bezeichnung, COALESCE(b.hersteller,''), "
        "COALESCE(bk.anschluss_typ,''), COALESCE(bk.breite_mm, 0.0) "
        "FROM bauteil b "
        "INNER JOIN bauteil_klemme bk ON bk.bauteil_id = b.id ";
    if (!such.isEmpty())
        sql += "WHERE LOWER(b.bezeichnung || ' ' || COALESCE(b.hersteller,'')) LIKE LOWER(:s) ";
    sql += "ORDER BY b.bezeichnung LIMIT 100";

    QSqlQuery q;
    q.prepare(sql);
    if (!such.isEmpty())
        q.bindValue(":s", "%" + such + "%");

    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::klemmeBauteileHolen:" << q.lastError().text();
        return liste;
    }

    while (q.next()) {
        QVariantMap m;
        m["bauteilId"]    = q.value(0).toInt();
        m["bezeichnung"]  = q.value(1).toString();
        m["hersteller"]   = q.value(2).toString();
        m["anschlussTyp"] = q.value(3).toString();
        m["breiteMm"]     = q.value(4).toDouble();
        liste.append(m);
    }
    return liste;
}

int KlemmenreiheModel::stegbrueckeAnlegen(int ebene, int vonKlemmeId, int bisKlemmeId)
{
    if (m_leisteId < 0) return -1;

    // Von/Bis normieren (kleinere Sortierung = von)
    int vonSort = -1, bisSort = -1;
    for (const QVariant &v : m_klemmen) {
        QVariantMap k = v.toMap();
        if (k["klemmeId"].toInt() == vonKlemmeId) vonSort = k["sortierung"].toInt();
        if (k["klemmeId"].toInt() == bisKlemmeId) bisSort = k["sortierung"].toInt();
    }
    if (vonSort < 0 || bisSort < 0) return -1;
    if (vonSort > bisSort) qSwap(vonKlemmeId, bisKlemmeId);

    // Überlappungscheck (m_stegbruecken muss aktuell sein)
    QString konflikt = pruefUeberlappung(ebene, vonKlemmeId, bisKlemmeId);

    QSqlQuery q;
    q.prepare(
        "INSERT INTO klemme_stegbruecke "
        "(klemmenleiste_id, ebene, von_klemme_id, bis_klemme_id, hat_konflikt, konflikt_text) "
        "VALUES (:lid, :eb, :von, :bis, :hk, :kt)"
    );
    q.bindValue(":lid", m_leisteId);
    q.bindValue(":eb",  ebene);
    q.bindValue(":von", vonKlemmeId);
    q.bindValue(":bis", bisKlemmeId);
    q.bindValue(":hk",  konflikt.isEmpty() ? 0 : 1);
    q.bindValue(":kt",  konflikt.isEmpty() ? QVariant() : konflikt);

    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::stegbrueckeAnlegen:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    ladeStegbruecken();
    emit leisteGeladen();
    return newId;
}

bool KlemmenreiheModel::stegbrueckeLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM klemme_stegbruecke WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::stegbrueckeLoeschen:" << q.lastError().text();
        return false;
    }
    ladeStegbruecken();
    emit leisteGeladen();
    return true;
}

bool KlemmenreiheModel::stegbrueckePotenzialSetzen(int id, const QString &potenzialText)
{
    QSqlQuery q;
    q.prepare("UPDATE klemme_stegbruecke SET potenzial_text = :pt WHERE id = :id");
    q.bindValue(":pt", potenzialText.trimmed().isEmpty() ? QVariant() : potenzialText.trimmed());
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "KlemmenreiheModel::stegbrueckePotenzialSetzen:" << q.lastError().text();
        return false;
    }
    ladeStegbruecken();
    emit leisteGeladen();
    return true;
}
