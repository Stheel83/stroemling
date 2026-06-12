#include "logging.h"
#include "BauteilModel.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

// ============================================================
// BauteilKategorieModel
// ============================================================

BauteilKategorieModel::BauteilKategorieModel(QObject *parent)
    : QAbstractListModel(parent)
{
    laden();
}

void BauteilKategorieModel::traversieren(int parentId, int tiefe,
                                          const QList<KategorieEintrag> &alle)
{
    for (const KategorieEintrag &k : alle) {
        if (k.parentId == parentId) {
            KategorieEintrag entry = k;
            entry.tiefe = tiefe;
            m_kategorien.append(entry);
            traversieren(k.id, tiefe + 1, alle);
        }
    }
}

void BauteilKategorieModel::laden()
{
    beginResetModel();
    m_kategorien.clear();

    QList<KategorieEintrag> alle;
    QSqlQuery q;
    q.exec("SELECT id, COALESCE(parent_id, -1), name, sortierung "
           "FROM bauteil_kategorie ORDER BY sortierung, name");
    while (q.next()) {
        KategorieEintrag k;
        k.id         = q.value(0).toInt();
        k.parentId   = q.value(1).toInt();
        k.name       = q.value(2).toString();
        k.sortierung = q.value(3).toInt();
        k.tiefe      = 0;
        alle.append(k);
    }

    traversieren(-1, 0, alle);
    endResetModel();
}

int BauteilKategorieModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_kategorien.size();
}

QVariant BauteilKategorieModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_kategorien.size())
        return {};

    const KategorieEintrag &k = m_kategorien.at(index.row());

    switch (role) {
    case KategorieIdRole: return k.id;
    case NameRole:        return k.name;
    case ParentIdRole:    return k.parentId;
    case TiefeRole:       return k.tiefe;
    case HatKinderRole: {
        for (const KategorieEintrag &other : m_kategorien)
            if (other.parentId == k.id) return true;
        return false;
    }
    default: return {};
    }
}

QHash<int, QByteArray> BauteilKategorieModel::roleNames() const
{
    return {
        { KategorieIdRole, "kategorieId" },
        { NameRole,        "name"        },
        { ParentIdRole,    "parentId"    },
        { TiefeRole,       "tiefe"       },
        { HatKinderRole,   "hatKinder"   },
    };
}

int BauteilKategorieModel::anlegen(int parentId, const QString &name)
{
    QSqlQuery q;
    if (parentId < 0) {
        q.prepare("INSERT INTO bauteil_kategorie (name) VALUES (:name)");
    } else {
        q.prepare("INSERT INTO bauteil_kategorie (name, parent_id) VALUES (:name, :pid)");
        q.bindValue(":pid", parentId);
    }
    q.bindValue(":name", name);
    if (!q.exec()) {
        qCWarning(lcModel) << "Kategorie anlegen Fehler:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden();
    return newId;
}

bool BauteilKategorieModel::bearbeiten(int id, const QString &name)
{
    QSqlQuery q;
    q.prepare("UPDATE bauteil_kategorie SET name = :name WHERE id = :id");
    q.bindValue(":name", name);
    q.bindValue(":id",   id);
    if (!q.exec()) {
        qCWarning(lcModel) << "Kategorie bearbeiten Fehler:" << q.lastError().text();
        return false;
    }
    laden();
    return true;
}

bool BauteilKategorieModel::loeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM bauteil_kategorie WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "Kategorie löschen Fehler:" << q.lastError().text();
        return false;
    }
    laden();
    return true;
}

// ============================================================
// BauteilListModel
// ============================================================

BauteilListModel::BauteilListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void BauteilListModel::laden(int kategorieId)
{
    m_aktiveKategorieId = kategorieId;
    m_suchtext.clear();
    ladenIntern();
}

void BauteilListModel::aktualisieren()
{
    ladenIntern();
}

void BauteilListModel::suchen(const QString &text)
{
    m_suchtext = text.trimmed();
    ladenIntern();
}

void BauteilListModel::setNurKlemmen(bool nurKlemmen)
{
    m_nurKlemmen = nurKlemmen;
    ladenIntern();
}

void BauteilListModel::setNurKabel(bool nurKabel)
{
    m_nurKabel = nurKabel;
    ladenIntern();
}

void BauteilListModel::ladenIntern()
{
    beginResetModel();
    m_bauteile.clear();

    const QString basis =
        "SELECT b.id, COALESCE(b.kategorie_id,-1), b.bezeichnung, "
        "COALESCE(b.hersteller,''), COALESCE(b.artikelnummer,''), "
        "COALESCE(b.lieferant,''), COALESCE(b.preis_eur,0), "
        "COALESCE(b.spannung_v,0), COALESCE(b.strom_a,0), "
        "COALESCE(b.leistung_w,0), COALESCE(b.bemerkung,''), "
        "COALESCE(b.url_hersteller,''), COALESCE(b.url_datenblatt,''), "
        "CASE WHEN k.id IS NOT NULL THEN 1 ELSE 0 END, "
        "CASE WHEN ka.id IS NOT NULL THEN 1 ELSE 0 END, "
        "COALESCE(ka.kabeltyp,''), "
        "COALESCE(b.hauptfunktion_symbol_id,'') "
        "FROM bauteil b "
        "LEFT JOIN bauteil_klemme k  ON k.bauteil_id  = b.id "
        "LEFT JOIN bauteil_kabel  ka ON ka.bauteil_id = b.id ";

    QString where;
    if (m_nurKlemmen)           where += "k.id IS NOT NULL ";
    if (m_nurKabel) {
        if (!where.isEmpty()) where += "AND ";
        where += "ka.id IS NOT NULL ";
    }
    if (m_aktiveKategorieId >= 0) {
        if (!where.isEmpty()) where += "AND ";
        where += "b.kategorie_id = :kid ";
    }
    if (!m_suchtext.isEmpty()) {
        if (!where.isEmpty()) where += "AND ";
        where += "(b.bezeichnung LIKE :s OR b.hersteller LIKE :s OR b.artikelnummer LIKE :s) ";
    }
    const QString sql = basis + (where.isEmpty() ? "" : "WHERE " + where) + "ORDER BY b.bezeichnung";

    QSqlQuery q;
    q.prepare(sql);
    if (m_aktiveKategorieId >= 0) q.bindValue(":kid", m_aktiveKategorieId);
    if (!m_suchtext.isEmpty())    q.bindValue(":s",   "%" + m_suchtext + "%");
    q.exec();

    while (q.next()) {
        BauteilEintrag b;
        b.id            = q.value(0).toInt();
        b.kategorieId   = q.value(1).toInt();
        b.bezeichnung   = q.value(2).toString();
        b.hersteller    = q.value(3).toString();
        b.artikelnummer = q.value(4).toString();
        b.lieferant     = q.value(5).toString();
        b.preisEur      = q.value(6).toDouble();
        b.spannungV     = q.value(7).toDouble();
        b.stromA        = q.value(8).toDouble();
        b.leistungW     = q.value(9).toDouble();
        b.bemerkung      = q.value(10).toString();
        b.urlHersteller  = q.value(11).toString();
        b.urlDatenblatt  = q.value(12).toString();
        b.istKlemme               = q.value(13).toInt() != 0;
        b.istKabel                = q.value(14).toInt() != 0;
        b.kabeltyp                = q.value(15).toString();
        b.hauptfunktionSymbolId   = q.value(16).toString();
        m_bauteile.append(b);
    }

    endResetModel();
    emit aktiveKategorieIdChanged();
}

int BauteilListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_bauteile.size();
}

QVariant BauteilListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_bauteile.size())
        return {};

    const BauteilEintrag &b = m_bauteile.at(index.row());

    switch (role) {
    case BauteilIdRole:     return b.id;
    case KategorieIdRole:   return b.kategorieId;
    case BezeichnungRole:   return b.bezeichnung;
    case HerstellerRole:    return b.hersteller;
    case ArtikelnummerRole: return b.artikelnummer;
    case LieferantRole:     return b.lieferant;
    case PreisEurRole:      return b.preisEur;
    case SpannungVRole:     return b.spannungV;
    case StromARole:        return b.stromA;
    case LeistungWRole:     return b.leistungW;
    case BemerkungRole:      return b.bemerkung;
    case UrlHerstellerRole:  return b.urlHersteller;
    case UrlDatenblattRole:  return b.urlDatenblatt;
    case IstKlemmeRole:             return b.istKlemme;
    case IstKabelRole:              return b.istKabel;
    case KabeltypRole:              return b.kabeltyp;
    case HauptfunktionSymbolIdRole: return b.hauptfunktionSymbolId;
    default:                        return {};
    }
}

QHash<int, QByteArray> BauteilListModel::roleNames() const
{
    return {
        { BauteilIdRole,     "bauteilId"     },
        { KategorieIdRole,   "kategorieId"   },
        { BezeichnungRole,   "bezeichnung"   },
        { HerstellerRole,    "hersteller"    },
        { ArtikelnummerRole, "artikelnummer" },
        { LieferantRole,     "lieferant"     },
        { PreisEurRole,      "preisEur"      },
        { SpannungVRole,     "spannungV"     },
        { StromARole,        "stromA"        },
        { LeistungWRole,     "leistungW"     },
        { BemerkungRole,      "bemerkung"      },
        { UrlHerstellerRole,  "urlHersteller"  },
        { UrlDatenblattRole,  "urlDatenblatt"  },
        { IstKlemmeRole,             "istKlemme"              },
        { IstKabelRole,              "istKabel"               },
        { KabeltypRole,              "kabeltyp"               },
        { HauptfunktionSymbolIdRole, "hauptfunktionSymbolId"  },
    };
}

int BauteilListModel::anlegen(int kategorieId, const QString &bezeichnung,
                               const QString &hersteller, const QString &artikelnummer,
                               const QString &lieferant, double preisEur,
                               double spannungV, double stromA, double leistungW,
                               const QString &bemerkung,
                               const QString &urlHersteller, const QString &urlDatenblatt)
{
    QSqlQuery q;
    q.prepare("INSERT INTO bauteil "
              "(kategorie_id, bezeichnung, hersteller, artikelnummer, lieferant, "
              " preis_eur, spannung_v, strom_a, leistung_w, bemerkung, url_hersteller, url_datenblatt) "
              "VALUES (:kid, :bez, :her, :art, :lief, :preis, :u, :i, :p, :bem, :uh, :ud)");
    q.bindValue(":kid",   kategorieId < 0 ? QVariant() : kategorieId);
    q.bindValue(":bez",   bezeichnung);
    q.bindValue(":her",   hersteller);
    q.bindValue(":art",   artikelnummer);
    q.bindValue(":lief",  lieferant);
    q.bindValue(":preis", preisEur > 0 ? preisEur : QVariant());
    q.bindValue(":u",     spannungV > 0 ? spannungV : QVariant());
    q.bindValue(":i",     stromA > 0 ? stromA : QVariant());
    q.bindValue(":p",     leistungW > 0 ? leistungW : QVariant());
    q.bindValue(":bem",   bemerkung);
    q.bindValue(":uh",    urlHersteller);
    q.bindValue(":ud",    urlDatenblatt);
    if (!q.exec()) {
        qCWarning(lcModel) << "Bauteil anlegen Fehler:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden(m_aktiveKategorieId);
    return newId;
}

bool BauteilListModel::bearbeiten(int id, const QString &bezeichnung,
                                   const QString &hersteller, const QString &artikelnummer,
                                   const QString &lieferant, double preisEur,
                                   double spannungV, double stromA, double leistungW,
                                   const QString &bemerkung,
                                   const QString &urlHersteller, const QString &urlDatenblatt)
{
    QSqlQuery q;
    q.prepare("UPDATE bauteil SET "
              "bezeichnung = :bez, hersteller = :her, artikelnummer = :art, "
              "lieferant = :lief, preis_eur = :preis, spannung_v = :u, "
              "strom_a = :i, leistung_w = :p, bemerkung = :bem, "
              "url_hersteller = :uh, url_datenblatt = :ud "
              "WHERE id = :id");
    q.bindValue(":bez",   bezeichnung);
    q.bindValue(":her",   hersteller);
    q.bindValue(":art",   artikelnummer);
    q.bindValue(":lief",  lieferant);
    q.bindValue(":preis", preisEur > 0 ? preisEur : QVariant());
    q.bindValue(":u",     spannungV > 0 ? spannungV : QVariant());
    q.bindValue(":i",     stromA > 0 ? stromA : QVariant());
    q.bindValue(":p",     leistungW > 0 ? leistungW : QVariant());
    q.bindValue(":bem",   bemerkung);
    q.bindValue(":uh",    urlHersteller);
    q.bindValue(":ud",    urlDatenblatt);
    q.bindValue(":id",    id);
    if (!q.exec()) {
        qCWarning(lcModel) << "Bauteil bearbeiten Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_aktiveKategorieId);
    return true;
}

bool BauteilListModel::loeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM bauteil WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "Bauteil löschen Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_aktiveKategorieId);
    return true;
}

QVariantMap BauteilListModel::bauteilNachId(int id) const
{
    QVariantMap m;
    if (id < 0) return m;
    QSqlQuery q;
    q.prepare("SELECT bezeichnung, COALESCE(hersteller,''), COALESCE(artikelnummer,''), "
              "COALESCE(lieferant,''), COALESCE(preis_eur,0), COALESCE(spannung_v,0), "
              "COALESCE(strom_a,0), COALESCE(leistung_w,0), COALESCE(bemerkung,''), "
              "COALESCE(url_hersteller,''), COALESCE(url_datenblatt,'') "
              "FROM bauteil WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec() || !q.next()) return m;
    m["bezeichnung"]   = q.value(0).toString();
    m["hersteller"]    = q.value(1).toString();
    m["artikelnummer"] = q.value(2).toString();
    m["lieferant"]     = q.value(3).toString();
    m["preisEur"]      = q.value(4).toDouble();
    m["spannungV"]     = q.value(5).toDouble();
    m["stromA"]        = q.value(6).toDouble();
    m["leistungW"]     = q.value(7).toDouble();
    m["bemerkung"]     = q.value(8).toString();
    m["urlHersteller"] = q.value(9).toString();
    m["urlDatenblatt"] = q.value(10).toString();
    return m;
}

bool BauteilListModel::bauteilTitelSpeichern(int id, const QString &bezeichnung,
                                              const QString &hersteller, const QString &artikelnummer)
{
    QSqlQuery q;
    q.prepare("UPDATE bauteil SET bezeichnung=:b, hersteller=:h, artikelnummer=:a WHERE id=:id");
    q.bindValue(":b",  bezeichnung);
    q.bindValue(":h",  hersteller);
    q.bindValue(":a",  artikelnummer);
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "bauteilTitelSpeichern Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_aktiveKategorieId);
    return true;
}

bool BauteilListModel::symbolSpeichern(int id, const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("UPDATE bauteil SET hauptfunktion_symbol_id = :sid WHERE id = :id");
    q.bindValue(":sid", symbolId.isEmpty() ? QVariant() : symbolId);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qCWarning(lcModel) << "symbolSpeichern Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_aktiveKategorieId);
    return true;
}

QVariantList BauteilListModel::bauteileWithSymbol() const
{
    QSqlQuery q;
    q.prepare("SELECT id, bezeichnung, hauptfunktion_symbol_id "
              "FROM bauteil "
              "WHERE hauptfunktion_symbol_id IS NOT NULL AND hauptfunktion_symbol_id != '' "
              "ORDER BY bezeichnung COLLATE NOCASE");
    QVariantList liste;
    if (!q.exec()) {
        qCWarning(lcModel) << "bauteileWithSymbol Fehler:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["bauteilId"]   = q.value(0).toInt();
        m["bezeichnung"] = q.value(1).toString();
        m["symbolId"]    = q.value(2).toString();
        liste.append(m);
    }
    return liste;
}
