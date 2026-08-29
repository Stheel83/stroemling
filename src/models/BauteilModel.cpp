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
           "FROM bibliothek.bauteil_kategorie ORDER BY sortierung, name");
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
        q.prepare("INSERT INTO bibliothek.bauteil_kategorie (name) VALUES (:name)");
    } else {
        q.prepare("INSERT INTO bibliothek.bauteil_kategorie (name, parent_id) VALUES (:name, :pid)");
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
    q.prepare("UPDATE bibliothek.bauteil_kategorie SET name = :name WHERE id = :id");
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
    q.prepare("DELETE FROM bibliothek.bauteil_kategorie WHERE id = :id");
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

void BauteilListModel::setNurSteckverbinder(bool nurSteckverb)
{
    m_nurSteckverbinder = nurSteckverb;
    ladenIntern();
}

void BauteilListModel::setNurKonfkabel(bool nurKonfkabel)
{
    m_nurKonfkabel = nurKonfkabel;
    ladenIntern();
}

void BauteilListModel::setNurKontakt(bool nurKontakt)
{
    m_nurKontakt = nurKontakt;
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
        "COALESCE(b.hauptfunktion_symbol_id,''), "
        "CASE WHEN sv.id IS NOT NULL THEN 1 ELSE 0 END, "
        "CASE WHEN kk.id IS NOT NULL THEN 1 ELSE 0 END, "
        "CASE WHEN kt.id IS NOT NULL THEN 1 ELSE 0 END, "
        "COALESCE(b.fuer_seed_vormerken,0), "
        "COALESCE(b.ist_system,0) "
        "FROM bibliothek.bauteil b "
        "LEFT JOIN bibliothek.bauteil_klemme k              ON k.bauteil_id  = b.id "
        "LEFT JOIN bibliothek.bauteil_kabel  ka             ON ka.bauteil_id = b.id "
        "LEFT JOIN bibliothek.steckverbinder_typ sv         ON sv.bauteil_id = b.id "
        "LEFT JOIN bibliothek.konfektioniertes_kabel kk     ON kk.bauteil_id = b.id "
        "LEFT JOIN bibliothek.kontakt_typ kt                ON kt.bauteil_id = b.id ";

    QString where;
    if (m_nurKlemmen)           where += "k.id IS NOT NULL ";
    if (m_nurKabel) {
        if (!where.isEmpty()) where += "AND ";
        where += "ka.id IS NOT NULL ";
    }
    if (m_nurSteckverbinder) {
        if (!where.isEmpty()) where += "AND ";
        where += "sv.id IS NOT NULL ";
    }
    if (m_nurKonfkabel) {
        if (!where.isEmpty()) where += "AND ";
        where += "kk.id IS NOT NULL ";
    }
    if (m_nurKontakt) {
        if (!where.isEmpty()) where += "AND ";
        where += "kt.id IS NOT NULL ";
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
        b.istSteckverbinder       = q.value(17).toInt() != 0;
        b.istKonfkabel            = q.value(18).toInt() != 0;
        b.istKontakt              = q.value(19).toInt() != 0;
        b.fuerSeedVormerken       = q.value(20).toInt() != 0;
        b.istSystem               = q.value(21).toInt() != 0;
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
    case IstSteckverbinderRole:     return b.istSteckverbinder;
    case IstKonfkabelRole:          return b.istKonfkabel;
    case IstKontaktRole:            return b.istKontakt;
    case KabeltypRole:              return b.kabeltyp;
    case HauptfunktionSymbolIdRole: return b.hauptfunktionSymbolId;
    case FuerSeedVormerkenRole:     return b.fuerSeedVormerken;
    case IstSystemRole:             return b.istSystem;
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
        { IstSteckverbinderRole,     "istSteckverbinder"      },
        { IstKonfkabelRole,          "istKonfkabel"           },
        { IstKontaktRole,            "istKontakt"             },
        { KabeltypRole,              "kabeltyp"               },
        { HauptfunktionSymbolIdRole, "hauptfunktionSymbolId"  },
        { FuerSeedVormerkenRole,     "fuerSeedVormerken"      },
        { IstSystemRole,             "istSystem"              },
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
    q.prepare("INSERT INTO bibliothek.bauteil "
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
    q.prepare("UPDATE bibliothek.bauteil SET "
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
    // KLEMME-LOESCH-KASKADE-01 (Aug 2026): bauteil_klemme.bauteil_id hat -
    // anders als bauteil_kabel/steckverbinder_typ/kontakt_typ/
    // konfektioniertes_kabel - kein ON DELETE CASCADE im Schema (SQLite kann
    // eine bestehende FK-Klausel nicht per ALTER TABLE nachziehen, das hätte
    // eine riskante Tabellen-Neuanlage über den gemeinsamen Migrations-
    // Codepfad gebraucht). Ohne dieses manuelle Aufräumen schlägt das DELETE
    // unten bei jedem Klemmen-Bauteil mit "FOREIGN KEY constraint failed"
    // fehl (lautlos, da nur geloggt) und das Bauteil bliebe stehen. Reihen-
    // folge wie im früheren KlemmeModel::loeschen(): erst die Kind-Tabellen
    // von bauteil_klemme, dann bauteil_klemme selbst.
    {
        QSqlQuery qk;
        qk.prepare("SELECT id FROM bibliothek.bauteil_klemme WHERE bauteil_id = :id");
        qk.bindValue(":id", id);
        if (qk.exec() && qk.next()) {
            const int klemmeId = qk.value(0).toInt();
            QSqlQuery qd;
            qd.prepare("DELETE FROM bibliothek.bauteil_klemme_eigenschaft WHERE klemme_id = :kid");
            qd.bindValue(":kid", klemmeId); qd.exec();
            qd.prepare("DELETE FROM bibliothek.bauteil_klemme_bruecke WHERE klemme_id = :kid");
            qd.bindValue(":kid", klemmeId); qd.exec();
            qd.prepare("DELETE FROM bibliothek.bauteil_klemme_querschnitt WHERE klemme_id = :kid");
            qd.bindValue(":kid", klemmeId); qd.exec();
            qd.prepare("DELETE FROM bibliothek.bauteil_klemme WHERE id = :kid");
            qd.bindValue(":kid", klemmeId);
            if (!qd.exec())
                qCWarning(lcModel) << "Bauteil loeschen: bauteil_klemme-Kaskade Fehler:" << qd.lastError().text();
        }
    }

    QSqlQuery q;
    q.prepare("DELETE FROM bibliothek.bauteil WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "Bauteil löschen Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_aktiveKategorieId);
    return true;
}

int BauteilListModel::duplizieren(int bauteilId)
{
    // ── Bauteil-Zeile lesen ──────────────────────────────────────────────────
    QSqlQuery qSrc;
    qSrc.prepare("SELECT kategorie_id, bezeichnung, hersteller, artikelnummer, lieferant, "
                 "preis_eur, spannung_v, strom_a, leistung_w, bemerkung, "
                 "url_hersteller, url_datenblatt "
                 "FROM bibliothek.bauteil WHERE id = :id");
    qSrc.bindValue(":id", bauteilId);
    if (!qSrc.exec() || !qSrc.next()) {
        qCWarning(lcModel) << "duplizieren: Bauteil" << bauteilId << "nicht gefunden";
        return -1;
    }

    const QString neueBezeichnung = qSrc.value(1).toString() + QStringLiteral(" (Kopie)");

    // ── Neue Bauteil-Zeile anlegen ───────────────────────────────────────────
    QSqlQuery qIns;
    qIns.prepare("INSERT INTO bibliothek.bauteil "
                 "(kategorie_id, bezeichnung, hersteller, artikelnummer, lieferant, "
                 " preis_eur, spannung_v, strom_a, leistung_w, bemerkung, url_hersteller, url_datenblatt) "
                 "VALUES (:kid, :bez, :her, :art, :lief, :preis, :u, :i, :p, :bem, :uh, :ud)");
    qIns.bindValue(":kid",   qSrc.value(0));
    qIns.bindValue(":bez",   neueBezeichnung);
    qIns.bindValue(":her",   qSrc.value(2));
    qIns.bindValue(":art",   qSrc.value(3));
    qIns.bindValue(":lief",  qSrc.value(4));
    qIns.bindValue(":preis", qSrc.value(5));
    qIns.bindValue(":u",     qSrc.value(6));
    qIns.bindValue(":i",     qSrc.value(7));
    qIns.bindValue(":p",     qSrc.value(8));
    qIns.bindValue(":bem",   qSrc.value(9));
    qIns.bindValue(":uh",    qSrc.value(10));
    qIns.bindValue(":ud",    qSrc.value(11));
    if (!qIns.exec()) {
        qCWarning(lcModel) << "duplizieren: bauteil INSERT Fehler:" << qIns.lastError().text();
        return -1;
    }
    const int newId = qIns.lastInsertId().toInt();

    // ── Typ: Klemme ──────────────────────────────────────────────────────────
    {
        QSqlQuery qk;
        qk.prepare("SELECT id, norm, anschluss_typ, ebenen_anzahl, punkte_seite_a, punkte_seite_b, "
                   "fuss_kontakt_pe, stegbruecke_faehig, breite_mm, gehaeuse_farbe_id, bemerkung "
                   "FROM bibliothek.bauteil_klemme WHERE bauteil_id = :bid");
        qk.bindValue(":bid", bauteilId);
        if (qk.exec() && qk.next()) {
            const int srcKlemmeId = qk.value(0).toInt();
            QSqlQuery qi;
            qi.prepare("INSERT INTO bibliothek.bauteil_klemme "
                       "(bauteil_id, norm, anschluss_typ, ebenen_anzahl, punkte_seite_a, punkte_seite_b, "
                       " fuss_kontakt_pe, stegbruecke_faehig, breite_mm, gehaeuse_farbe_id, bemerkung) "
                       "VALUES (:bid, :norm, :atyp, :anz, :pa, :pb, :pe, :sb, :br, :gf, :bem)");
            qi.bindValue(":bid",  newId);
            qi.bindValue(":norm", qk.value(1));
            qi.bindValue(":atyp", qk.value(2));
            qi.bindValue(":anz",  qk.value(3));
            qi.bindValue(":pa",   qk.value(4));
            qi.bindValue(":pb",   qk.value(5));
            qi.bindValue(":pe",   qk.value(6));
            qi.bindValue(":sb",   qk.value(7));
            qi.bindValue(":br",   qk.value(8));
            qi.bindValue(":gf",   qk.value(9));
            qi.bindValue(":bem",  qk.value(10));
            if (qi.exec()) {
                const int newKlemmeId = qi.lastInsertId().toInt();
                // Querschnitte
                QSqlQuery qq;
                qq.prepare("SELECT adertyp, min_mm2, max_mm2 FROM bibliothek.bauteil_klemme_querschnitt WHERE klemme_id = :kid");
                qq.bindValue(":kid", srcKlemmeId);
                if (qq.exec()) {
                    while (qq.next()) {
                        QSqlQuery qi2;
                        qi2.prepare("INSERT INTO bibliothek.bauteil_klemme_querschnitt (klemme_id, adertyp, min_mm2, max_mm2) VALUES (:kid, :at, :mn, :mx)");
                        qi2.bindValue(":kid", newKlemmeId);
                        qi2.bindValue(":at",  qq.value(0));
                        qi2.bindValue(":mn",  qq.value(1));
                        qi2.bindValue(":mx",  qq.value(2));
                        qi2.exec();
                    }
                }
                // Brückenebenen
                QSqlQuery qb;
                qb.prepare("SELECT von_ebene, nach_ebene, ist_pe_fuss FROM bibliothek.bauteil_klemme_bruecke WHERE klemme_id = :kid");
                qb.bindValue(":kid", srcKlemmeId);
                if (qb.exec()) {
                    while (qb.next()) {
                        QSqlQuery qi3;
                        qi3.prepare("INSERT INTO bibliothek.bauteil_klemme_bruecke (klemme_id, von_ebene, nach_ebene, ist_pe_fuss) VALUES (:kid, :ve, :ne, :pe)");
                        qi3.bindValue(":kid", newKlemmeId);
                        qi3.bindValue(":ve",  qb.value(0));
                        qi3.bindValue(":ne",  qb.value(1));
                        qi3.bindValue(":pe",  qb.value(2));
                        qi3.exec();
                    }
                }
            }
        }
    }

    // ── Typ: Kabel ───────────────────────────────────────────────────────────
    {
        QSqlQuery qk;
        qk.prepare("SELECT id, kabeltyp, geschirmt, paarweise_verdrillt, aussenmantel_farbe, "
                   "aussenmantel_mm, material_leiter, material_isolierung "
                   "FROM bibliothek.bauteil_kabel WHERE bauteil_id = :bid");
        qk.bindValue(":bid", bauteilId);
        if (qk.exec() && qk.next()) {
            const int srcKabelId = qk.value(0).toInt();
            QSqlQuery qi;
            qi.prepare("INSERT INTO bibliothek.bauteil_kabel "
                       "(bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt, aussenmantel_farbe, "
                       " aussenmantel_mm, material_leiter, material_isolierung) "
                       "VALUES (:bid, :kt, :gs, :pv, :af, :am, :ml, :mi)");
            qi.bindValue(":bid", newId);
            qi.bindValue(":kt",  qk.value(1));
            qi.bindValue(":gs",  qk.value(2));
            qi.bindValue(":pv",  qk.value(3));
            qi.bindValue(":af",  qk.value(4));
            qi.bindValue(":am",  qk.value(5));
            qi.bindValue(":ml",  qk.value(6));
            qi.bindValue(":mi",  qk.value(7));
            if (qi.exec()) {
                const int newKabelId = qi.lastInsertId().toInt();
                // Adern — alte ID → neue ID für Paar-Remap
                QMap<int, int> aderIdMap;
                QSqlQuery qa;
                qa.prepare("SELECT id, ader_nr, farbe, nummer, bezeichnung, querschnitt_mm2 FROM bibliothek.bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr");
                qa.bindValue(":kid", srcKabelId);
                if (qa.exec()) {
                    while (qa.next()) {
                        QSqlQuery qi2;
                        qi2.prepare("INSERT INTO bibliothek.bauteil_kabel_ader (kabel_id, ader_nr, farbe, nummer, bezeichnung, querschnitt_mm2) VALUES (:kid, :nr, :fa, :nu, :bez, :qs)");
                        qi2.bindValue(":kid", newKabelId);
                        qi2.bindValue(":nr",  qa.value(1));
                        qi2.bindValue(":fa",  qa.value(2));
                        qi2.bindValue(":nu",  qa.value(3));
                        qi2.bindValue(":bez", qa.value(4));
                        qi2.bindValue(":qs",  qa.value(5));
                        if (qi2.exec())
                            aderIdMap[qa.value(0).toInt()] = qi2.lastInsertId().toInt();
                    }
                }
                // Paare (Ader-IDs ummappen)
                QSqlQuery qp;
                qp.prepare("SELECT paar_nr, ader_a, ader_b FROM bibliothek.bauteil_kabel_paar WHERE kabel_id = :kid ORDER BY paar_nr");
                qp.bindValue(":kid", srcKabelId);
                if (qp.exec()) {
                    while (qp.next()) {
                        const int na = aderIdMap.value(qp.value(1).toInt(), -1);
                        const int nb = aderIdMap.value(qp.value(2).toInt(), -1);
                        if (na > 0 && nb > 0) {
                            QSqlQuery qi3;
                            qi3.prepare("INSERT INTO bibliothek.bauteil_kabel_paar (kabel_id, paar_nr, ader_a, ader_b) VALUES (:kid, :nr, :a, :b)");
                            qi3.bindValue(":kid", newKabelId);
                            qi3.bindValue(":nr",  qp.value(0));
                            qi3.bindValue(":a",   na);
                            qi3.bindValue(":b",   nb);
                            qi3.exec();
                        }
                    }
                }
            }
        }
    }

    // ── Typ: Steckverbinder ──────────────────────────────────────────────────
    {
        QSqlQuery qsv;
        qsv.prepare("SELECT id, polzahl, ip_getrennt, ip_gesteckt, kodierung, verriegelung, hat_schirmkontakt, geschirmt "
                    "FROM bibliothek.steckverbinder_typ WHERE bauteil_id = :bid");
        qsv.bindValue(":bid", bauteilId);
        if (qsv.exec() && qsv.next()) {
            const int srcSvId = qsv.value(0).toInt();
            QSqlQuery qi;
            qi.prepare("INSERT INTO bibliothek.steckverbinder_typ "
                       "(bauteil_id, polzahl, ip_getrennt, ip_gesteckt, kodierung, verriegelung, hat_schirmkontakt, geschirmt) "
                       "VALUES (:bid, :pz, :igt, :igs, :ko, :vr, :hs, :gs)");
            qi.bindValue(":bid", newId);
            qi.bindValue(":pz",  qsv.value(1));
            qi.bindValue(":igt", qsv.value(2));
            qi.bindValue(":igs", qsv.value(3));
            qi.bindValue(":ko",  qsv.value(4));
            qi.bindValue(":vr",  qsv.value(5));
            qi.bindValue(":hs",  qsv.value(6));
            qi.bindValue(":gs",  qsv.value(7));
            if (qi.exec()) {
                const int newSvId = qi.lastInsertId().toInt();
                // Kabeleinführungen
                QSqlQuery qke;
                qke.prepare("SELECT einf_nr, aussen_min_mm, aussen_max_mm, einf_typ, zugentlastung FROM bibliothek.steckverbinder_kabeleinf WHERE steckverbinder_typ_id = :svid ORDER BY einf_nr");
                qke.bindValue(":svid", srcSvId);
                if (qke.exec()) {
                    while (qke.next()) {
                        QSqlQuery qi2;
                        qi2.prepare("INSERT INTO bibliothek.steckverbinder_kabeleinf (steckverbinder_typ_id, einf_nr, aussen_min_mm, aussen_max_mm, einf_typ, zugentlastung) VALUES (:svid, :nr, :mn, :mx, :et, :ze)");
                        qi2.bindValue(":svid", newSvId);
                        qi2.bindValue(":nr",   qke.value(0));
                        qi2.bindValue(":mn",   qke.value(1));
                        qi2.bindValue(":mx",   qke.value(2));
                        qi2.bindValue(":et",   qke.value(3));
                        qi2.bindValue(":ze",   qke.value(4));
                        qi2.exec();
                    }
                }
                // Positionen (Steckverbinder-Typ ↔ Kontakt-Typ, Neukonzeption Jul 2026) —
                // kontakt_typ_id wird nur referenziert, der Kontakt-Typ-Bauteil selbst
                // wird nicht dupliziert (bleibt wiederverwendetes Bibliotheksobjekt)
                QSqlQuery qkt;
                qkt.prepare("SELECT position_nr, kontakt_typ_id, ist_schirmkontakt FROM bibliothek.steckverbinder_position WHERE steckverbinder_typ_id = :svid ORDER BY position_nr");
                qkt.bindValue(":svid", srcSvId);
                if (qkt.exec()) {
                    while (qkt.next()) {
                        QSqlQuery qi3;
                        qi3.prepare("INSERT INTO bibliothek.steckverbinder_position (steckverbinder_typ_id, position_nr, kontakt_typ_id, ist_schirmkontakt) VALUES (:svid, :pos, :ktid, :sk)");
                        qi3.bindValue(":svid", newSvId);
                        qi3.bindValue(":pos",  qkt.value(0));
                        qi3.bindValue(":ktid", qkt.value(1));
                        qi3.bindValue(":sk",   qkt.value(2));
                        qi3.exec();
                    }
                }
            }
        }
    }

    // ── Typ: Kontakt ─────────────────────────────────────────────────────────
    {
        QSqlQuery qk;
        qk.prepare("SELECT geschlecht, kontaktgroesse, "
                   "querschnitt_steckseite_min, querschnitt_steckseite_max, "
                   "querschnitt_kabel_min, querschnitt_kabel_max, "
                   "nennstrom_a, nennspannung_v, verbindungstechnik "
                   "FROM bibliothek.kontakt_typ WHERE bauteil_id = :bid");
        qk.bindValue(":bid", bauteilId);
        if (qk.exec() && qk.next()) {
            QSqlQuery qi;
            qi.prepare("INSERT INTO bibliothek.kontakt_typ "
                       "(bauteil_id, geschlecht, kontaktgroesse, "
                       " querschnitt_steckseite_min, querschnitt_steckseite_max, "
                       " querschnitt_kabel_min, querschnitt_kabel_max, "
                       " nennstrom_a, nennspannung_v, verbindungstechnik) "
                       "VALUES (:bid, :gs, :kg, :qsmn, :qsmx, :qkmn, :qkmx, :ia, :uv, :vt)");
            qi.bindValue(":bid",  newId);
            qi.bindValue(":gs",   qk.value(0));
            qi.bindValue(":kg",   qk.value(1));
            qi.bindValue(":qsmn", qk.value(2));
            qi.bindValue(":qsmx", qk.value(3));
            qi.bindValue(":qkmn", qk.value(4));
            qi.bindValue(":qkmx", qk.value(5));
            qi.bindValue(":ia",   qk.value(6));
            qi.bindValue(":uv",   qk.value(7));
            qi.bindValue(":vt",   qk.value(8));
            qi.exec();
        }
    }

    laden(m_aktiveKategorieId);
    return newId;
}

QVariantMap BauteilListModel::bauteilNachId(int id) const
{
    QVariantMap m;
    if (id < 0) return m;
    QSqlQuery q;
    q.prepare("SELECT bezeichnung, COALESCE(hersteller,''), COALESCE(artikelnummer,''), "
              "COALESCE(lieferant,''), COALESCE(preis_eur,0), COALESCE(spannung_v,0), "
              "COALESCE(strom_a,0), COALESCE(leistung_w,0), COALESCE(bemerkung,''), "
              "COALESCE(url_hersteller,''), COALESCE(url_datenblatt,''), "
              "COALESCE(ist_system,0) "
              "FROM bibliothek.bauteil WHERE id = :id");
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
    m["istSystem"]     = q.value(11).toInt() != 0;
    return m;
}

bool BauteilListModel::bauteilTitelSpeichern(int id, const QString &bezeichnung,
                                              const QString &hersteller, const QString &artikelnummer)
{
    QSqlQuery q;
    q.prepare("UPDATE bibliothek.bauteil SET bezeichnung=:b, hersteller=:h, artikelnummer=:a WHERE id=:id");
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
    q.prepare("UPDATE bibliothek.bauteil SET hauptfunktion_symbol_id = :sid WHERE id = :id");
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
              "FROM bibliothek.bauteil "
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

bool BauteilListModel::fuerSeedUmschalten(int id)
{
    QSqlQuery q;
    q.prepare("UPDATE bibliothek.bauteil SET fuer_seed_vormerken = 1 - COALESCE(fuer_seed_vormerken,0) WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "fuerSeedUmschalten Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_aktiveKategorieId);
    return true;
}

QVariantList BauteilListModel::bauteileFuerSeed() const
{
    QSqlQuery q;
    q.prepare("SELECT id, bezeichnung, hersteller, artikelnummer "
              "FROM bibliothek.bauteil "
              "WHERE fuer_seed_vormerken = 1 "
              "ORDER BY bezeichnung COLLATE NOCASE");
    QVariantList liste;
    if (!q.exec()) {
        qCWarning(lcModel) << "bauteileFuerSeed Fehler:" << q.lastError().text();
        return liste;
    }
    while (q.next()) {
        QVariantMap m;
        m["bauteilId"]      = q.value(0).toInt();
        m["bezeichnung"]    = q.value(1).toString();
        m["hersteller"]     = q.value(2).toString();
        m["artikelnummer"]  = q.value(3).toString();
        liste.append(m);
    }
    return liste;
}
