#include "logging.h"
#include "SeitenModel.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <algorithm>

// Natural Sort: vergleicht Strings so dass "2" < "10" (nicht lexikografisch)
static bool naturalLessThan(const QString &a, const QString &b)
{
    int ia = 0, ib = 0;
    while (ia < a.size() && ib < b.size()) {
        bool aNum = a[ia].isDigit();
        bool bNum = b[ib].isDigit();
        if (aNum && bNum) {
            // Führende Nullen überspringen, dann als Zahl vergleichen
            int startA = ia, startB = ib;
            while (ia < a.size() && a[ia].isDigit()) ++ia;
            while (ib < b.size() && b[ib].isDigit()) ++ib;
            QString na = a.mid(startA, ia - startA);
            QString nb = b.mid(startB, ib - startB);
            if (na.size() != nb.size()) return na.size() < nb.size();
            if (na != nb) return na < nb;
        } else {
            QChar ca = a[ia].toLower();
            QChar cb = b[ib].toLower();
            if (ca != cb) return ca < cb;
            ++ia; ++ib;
        }
    }
    return a.size() < b.size();
}

// ============================================================
// Konstruktor / Destruktor
// ============================================================

SeitenModel::SeitenModel(QObject *parent)
    : QAbstractItemModel(parent)
{
    m_wurzel = new BaumKnoten();
    m_wurzel->typ    = BaumKnoten::Anlage;
    m_wurzel->index  = 0;
    m_wurzel->eltern = nullptr;
}

SeitenModel::~SeitenModel()
{
    delete m_wurzel;
}

// ============================================================
// Baum aufbauen / leeren
// ============================================================

void SeitenModel::baumLeeren()
{
    qDeleteAll(m_wurzel->kinder);
    m_wurzel->kinder.clear();
    m_anlagen.clear();
}

void SeitenModel::baumAufbauen()
{
    // -- Anlagen laden --
    QSqlQuery q;
    q.prepare("SELECT id, projekt_id, kuerzel, bezeichnung, sortierung, "
              "COALESCE(anlage_uebergeordnet,'') "
              "FROM anlage WHERE projekt_id = :pid ORDER BY sortierung, id");
    q.bindValue(":pid", m_projektId);
    q.exec();

    while (q.next()) {
        AnlageEintrag a;
        a.id         = q.value(0).toInt();
        a.projektId  = q.value(1).toInt();
        a.kuerzel    = q.value(2).toString();
        a.bezeichnung= q.value(3).toString();
        a.sortierung = q.value(4).toInt();
        a.anlageUebergeordnet = q.value(5).toString();

        // -- Orte für diese Anlage laden --
        QSqlQuery qo;
        qo.prepare("SELECT id, anlage_id, kuerzel, bezeichnung, sortierung, "
                   "COALESCE(standort_uebergeordnet,'') "
                   "FROM ort WHERE anlage_id = :aid ORDER BY sortierung, id");
        qo.bindValue(":aid", a.id);
        qo.exec();

        while (qo.next()) {
            OrtEintrag o;
            o.id         = qo.value(0).toInt();
            o.anlageId   = qo.value(1).toInt();
            o.kuerzel    = qo.value(2).toString();
            o.bezeichnung= qo.value(3).toString();
            o.sortierung = qo.value(4).toInt();
            o.standortUebergeordnet = qo.value(5).toString();

            // -- Seiten für diesen Ort laden --
            QSqlQuery qs;
            qs.prepare("SELECT id, ort_id, COALESCE(parent_id,0), blattnummer, "
                       "COALESCE(bezeichnung,''), COALESCE(seitentyp,'schaltplan'), sortierung, "
                       "COALESCE(raster_mm,4.0), COALESCE(rastend,1), "
                       "COALESCE(breite_mm,297.0), COALESCE(hoehe_mm,210.0), "
                       "COALESCE(rand_links_mm,20.0), COALESCE(rand_rechts_mm,10.0), "
                       "COALESCE(rand_oben_mm,10.0), COALESCE(rand_unten_mm,10.0) "
                       "FROM seite WHERE ort_id = :oid ORDER BY sortierung, id");
            qs.bindValue(":oid", o.id);
            qs.exec();

            while (qs.next()) {
                SeiteEintrag s;
                s.id          = qs.value(0).toInt();
                s.ortId       = qs.value(1).toInt();
                s.parentId    = qs.value(2).toInt();
                s.blattnummer = qs.value(3).toString();
                s.bezeichnung = qs.value(4).toString();
                s.seitentyp   = qs.value(5).toString();
                s.sortierung  = qs.value(6).toInt();
                s.rasterMm    = qs.value(7).toDouble();
                s.rastend     = qs.value(8).toBool();
                s.breiteMm     = qs.value(9).toDouble();
                s.hoeheMm      = qs.value(10).toDouble();
                s.randLinksMm  = qs.value(11).toDouble();
                s.randRechtsMm = qs.value(12).toDouble();
                s.randObenMm   = qs.value(13).toDouble();
                s.randUntenMm  = qs.value(14).toDouble();
                o.seiten.append(s);
            }
            // Natural Sort nach Blattnummer (sortierung als primärer Schlüssel)
            std::stable_sort(o.seiten.begin(), o.seiten.end(),
                [](const SeiteEintrag &a, const SeiteEintrag &b) {
                    if (a.sortierung != b.sortierung) return a.sortierung < b.sortierung;
                    return naturalLessThan(a.blattnummer, b.blattnummer);
                });
            a.orte.append(o);
        }
        m_anlagen.append(a);
    }

    // -- Baumknoten aufbauen --
    for (int ai = 0; ai < m_anlagen.size(); ++ai) {
        BaumKnoten *anlageKnoten = new BaumKnoten();
        anlageKnoten->typ    = BaumKnoten::Anlage;
        anlageKnoten->index  = ai;
        anlageKnoten->eltern = m_wurzel;
        anlageKnoten->anlage = &m_anlagen[ai];

        for (int oi = 0; oi < m_anlagen[ai].orte.size(); ++oi) {
            BaumKnoten *ortKnoten = new BaumKnoten();
            ortKnoten->typ    = BaumKnoten::Ort;
            ortKnoten->index  = oi;
            ortKnoten->eltern = anlageKnoten;
            ortKnoten->ort    = &m_anlagen[ai].orte[oi];

            for (int si = 0; si < m_anlagen[ai].orte[oi].seiten.size(); ++si) {
                BaumKnoten *seiteKnoten = new BaumKnoten();
                seiteKnoten->typ    = BaumKnoten::Seite;
                seiteKnoten->index  = si;
                seiteKnoten->eltern = ortKnoten;
                seiteKnoten->seite  = &m_anlagen[ai].orte[oi].seiten[si];
                ortKnoten->kinder.append(seiteKnoten);
            }
            anlageKnoten->kinder.append(ortKnoten);
        }
        m_wurzel->kinder.append(anlageKnoten);
    }
}

// ============================================================
// QAbstractItemModel Pflichtmethoden
// ============================================================

QModelIndex SeitenModel::index(int row, int column, const QModelIndex &parent) const
{
    if (!hasIndex(row, column, parent))
        return {};

    BaumKnoten *elternKnoten = parent.isValid()
        ? static_cast<BaumKnoten *>(parent.internalPointer())
        : m_wurzel;

    if (row < elternKnoten->kinder.size())
        return createIndex(row, column, elternKnoten->kinder[row]);

    return {};
}

QModelIndex SeitenModel::parent(const QModelIndex &child) const
{
    if (!child.isValid())
        return {};

    BaumKnoten *knoten       = static_cast<BaumKnoten *>(child.internalPointer());
    BaumKnoten *elternKnoten = knoten->eltern;

    if (elternKnoten == m_wurzel)
        return {};

    return createIndex(elternKnoten->index, 0, elternKnoten);
}

int SeitenModel::rowCount(const QModelIndex &parent) const
{
    BaumKnoten *knoten = parent.isValid()
        ? static_cast<BaumKnoten *>(parent.internalPointer())
        : m_wurzel;
    return knoten->kinder.size();
}

int SeitenModel::columnCount(const QModelIndex &) const
{
    return 1;
}

QVariant SeitenModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    BaumKnoten *knoten = static_cast<BaumKnoten *>(index.internalPointer());

    switch (role) {
    case Qt::DisplayRole:
    case BezeichnungRole:
        if (knoten->typ == BaumKnoten::Anlage)
            return QString("=%1  %2").arg(knoten->anlage->kuerzel, knoten->anlage->bezeichnung);
        if (knoten->typ == BaumKnoten::Ort)
            return QString("+%1  %2").arg(knoten->ort->kuerzel, knoten->ort->bezeichnung);
        if (knoten->typ == BaumKnoten::Seite) {
            QString bez = knoten->seite->bezeichnung;
            return bez.isEmpty()
                ? knoten->seite->blattnummer
                : QString("%1  %2").arg(knoten->seite->blattnummer, bez);
        }
        break;

    case KuerzelRole:
        if (knoten->typ == BaumKnoten::Anlage) return knoten->anlage->kuerzel;
        if (knoten->typ == BaumKnoten::Ort)    return knoten->ort->kuerzel;
        return {};

    case BlattnummerRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->blattnummer;
        return {};

    case SeitentypRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->seitentyp;
        return {};

    case KnotenTypRole:
        return static_cast<int>(knoten->typ);

    case ItemIdRole:
        if (knoten->typ == BaumKnoten::Anlage) return knoten->anlage->id;
        if (knoten->typ == BaumKnoten::Ort)    return knoten->ort->id;
        if (knoten->typ == BaumKnoten::Seite)  return knoten->seite->id;
        break;

    case RohBezeichnungRole:
        if (knoten->typ == BaumKnoten::Anlage) return knoten->anlage->bezeichnung;
        if (knoten->typ == BaumKnoten::Ort)    return knoten->ort->bezeichnung;
        if (knoten->typ == BaumKnoten::Seite)  return knoten->seite->bezeichnung;
        break;

    case BreiteMmRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->breiteMm;
        return {};

    case HoeheMmRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->hoeheMm;
        return {};

    case RandLinksMmRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->randLinksMm;
        return {};
    case RandRechtsMmRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->randRechtsMm;
        return {};
    case RandObenMmRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->randObenMm;
        return {};
    case RandUntenMmRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->randUntenMm;
        return {};

    case OrtIdRole:
        if (knoten->typ == BaumKnoten::Seite) return knoten->seite->ortId;
        return {};

    case SortierungRole:
        if (knoten->typ == BaumKnoten::Anlage) return knoten->anlage->sortierung;
        if (knoten->typ == BaumKnoten::Ort)    return knoten->ort->sortierung;
        if (knoten->typ == BaumKnoten::Seite)  return knoten->seite->sortierung;
        return {};

    case UebergeordnetRole:
        if (knoten->typ == BaumKnoten::Anlage) return knoten->anlage->anlageUebergeordnet;
        if (knoten->typ == BaumKnoten::Ort)    return knoten->ort->standortUebergeordnet;
        return {};
    }
    return {};
}

QHash<int, QByteArray> SeitenModel::roleNames() const
{
    return {
        { BezeichnungRole,    "bezeichnung"    },
        { KuerzelRole,        "kuerzel"        },
        { BlattnummerRole,    "blattnummer"    },
        { SeitentypRole,      "seitentyp"      },
        { KnotenTypRole,      "knotenTyp"      },
        { ItemIdRole,         "itemId"         },
        { RohBezeichnungRole, "rohBezeichnung" },
        { BreiteMmRole,       "breiteMm"       },
        { HoeheMmRole,        "hoeheMm"        },
        { RandLinksMmRole,    "randLinksMm"    },
        { RandRechtsMmRole,   "randRechtsMm"   },
        { RandObenMmRole,     "randObenMm"     },
        { RandUntenMmRole,    "randUntenMm"    },
        { OrtIdRole,          "ortId"          },
        { SortierungRole,     "sortierung"     },
        { UebergeordnetRole,  "uebergeordnet"  },
    };
}

// ============================================================
// Aus QML aufrufbare Methoden
// ============================================================

void SeitenModel::laden(int projektId)
{
    beginResetModel();
    m_projektId = projektId;
    baumLeeren();
    if (projektId >= 0)
        baumAufbauen();
    endResetModel();
}

int SeitenModel::anlageAnlegen(int projektId, const QString &kuerzel, const QString &bezeichnung,
                                const QString &anlageUebergeordnet)
{
    QSqlQuery q;
    q.prepare("INSERT INTO anlage (projekt_id, kuerzel, bezeichnung, anlage_uebergeordnet) "
              "VALUES (:pid, :kz, :bez, :auo)");
    q.bindValue(":pid", projektId);
    q.bindValue(":kz",  kuerzel);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":auo", anlageUebergeordnet.isEmpty() ? QVariant() : anlageUebergeordnet);
    if (!q.exec()) {
        qCWarning(lcModel) << "anlageAnlegen Fehler:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden(m_projektId);
    return newId;
}

int SeitenModel::ortAnlegen(int anlageId, const QString &kuerzel, const QString &bezeichnung,
                             const QString &standortUebergeordnet)
{
    QSqlQuery q;
    q.prepare("INSERT INTO ort (anlage_id, kuerzel, bezeichnung, standort_uebergeordnet) "
              "VALUES (:aid, :kz, :bez, :suo)");
    q.bindValue(":aid", anlageId);
    q.bindValue(":kz",  kuerzel);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":suo", standortUebergeordnet.isEmpty() ? QVariant() : standortUebergeordnet);
    if (!q.exec()) {
        qCWarning(lcModel) << "ortAnlegen Fehler:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden(m_projektId);
    return newId;
}

int SeitenModel::seiteAnlegen(int ortId, const QString &blattnummer,
                               const QString &bezeichnung, const QString &seitentyp,
                               double breiteMm, double hoeheMm,
                               double randLinksMm, double randRechtsMm,
                               double randObenMm,  double randUntenMm)
{
    QSqlQuery qMax;
    qMax.prepare("SELECT COALESCE(MAX(sortierung), 0) + 1 FROM seite WHERE ort_id = :oid");
    qMax.bindValue(":oid", ortId);
    qMax.exec(); qMax.next();
    int nextSort = qMax.value(0).toInt();

    QSqlQuery q;
    q.prepare("INSERT INTO seite (ort_id, blattnummer, bezeichnung, seitentyp, sortierung, "
              "breite_mm, hoehe_mm, rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm) "
              "VALUES (:oid, :blatt, :bez, :typ, :sort, :b, :h, :rl, :rr, :ro, :ru)");
    q.bindValue(":oid",   ortId);
    q.bindValue(":blatt", blattnummer);
    q.bindValue(":bez",   bezeichnung);
    q.bindValue(":typ",   seitentyp);
    q.bindValue(":sort",  nextSort);
    q.bindValue(":b",     breiteMm);
    q.bindValue(":h",     hoeheMm);
    q.bindValue(":rl",    randLinksMm);
    q.bindValue(":rr",    randRechtsMm);
    q.bindValue(":ro",    randObenMm);
    q.bindValue(":ru",    randUntenMm);
    if (!q.exec()) {
        qCWarning(lcModel) << "seiteAnlegen Fehler:" << q.lastError().text();
        return -1;
    }
    int newId = q.lastInsertId().toInt();
    laden(m_projektId);
    return newId;
}

bool SeitenModel::loeschen(int knotenTyp, int id)
{
    // Bei Seiten zuerst alle Grafikelemente explizit löschen.
    // Das ist ein Fallback für ältere DB-Schemata ohne ON DELETE CASCADE –
    // bei neuen Schemas übernimmt CASCADE dasselbe.
    if (knotenTyp == BaumKnoten::Seite) {
        QSqlQuery del;
        del.prepare("DELETE FROM grafik_element WHERE seite_id = :id");
        del.bindValue(":id", id);
        if (!del.exec())
            qCWarning(lcModel) << "loeschen: grafik_element bereinigen fehlgeschlagen:" << del.lastError().text();
    }

    QSqlQuery q;
    QString tabelle;
    switch (knotenTyp) {
    case BaumKnoten::Anlage: tabelle = "anlage"; break;
    case BaumKnoten::Ort:    tabelle = "ort";    break;
    case BaumKnoten::Seite:  tabelle = "seite";  break;
    default: return false;
    }
    q.prepare(QString("DELETE FROM %1 WHERE id = :id").arg(tabelle));
    q.bindValue(":id", id);
    if (!q.exec()) {
        qCWarning(lcModel) << "loeschen Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool SeitenModel::anlageBearbeiten(int id, const QString &kuerzel, const QString &bezeichnung,
                                    const QString &anlageUebergeordnet)
{
    QSqlQuery q;
    q.prepare("UPDATE anlage SET kuerzel = :kz, bezeichnung = :bez, "
              "anlage_uebergeordnet = :auo WHERE id = :id");
    q.bindValue(":kz",  kuerzel);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":auo", anlageUebergeordnet.isEmpty() ? QVariant() : anlageUebergeordnet);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qCWarning(lcModel) << "anlageBearbeiten Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool SeitenModel::ortBearbeiten(int id, const QString &kuerzel, const QString &bezeichnung,
                                 const QString &standortUebergeordnet)
{
    QSqlQuery q;
    q.prepare("UPDATE ort SET kuerzel = :kz, bezeichnung = :bez, "
              "standort_uebergeordnet = :suo WHERE id = :id");
    q.bindValue(":kz",  kuerzel);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":suo", standortUebergeordnet.isEmpty() ? QVariant() : standortUebergeordnet);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qCWarning(lcModel) << "ortBearbeiten Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool SeitenModel::seiteBearbeiten(int id, const QString &blattnummer,
                                   const QString &bezeichnung, const QString &seitentyp,
                                   double breiteMm, double hoeheMm,
                                   double randLinksMm, double randRechtsMm,
                                   double randObenMm,  double randUntenMm)
{
    QSqlQuery q;
    q.prepare("UPDATE seite SET blattnummer = :blatt, bezeichnung = :bez, seitentyp = :typ, "
              "breite_mm = :b, hoehe_mm = :h, "
              "rand_links_mm = :rl, rand_rechts_mm = :rr, "
              "rand_oben_mm = :ro, rand_unten_mm = :ru WHERE id = :id");
    q.bindValue(":blatt", blattnummer);
    q.bindValue(":bez",   bezeichnung);
    q.bindValue(":typ",   seitentyp);
    q.bindValue(":b",     breiteMm);
    q.bindValue(":h",     hoeheMm);
    q.bindValue(":rl",    randLinksMm);
    q.bindValue(":rr",    randRechtsMm);
    q.bindValue(":ro",    randObenMm);
    q.bindValue(":ru",    randUntenMm);
    q.bindValue(":id",    id);
    if (!q.exec()) {
        qCWarning(lcModel) << "seiteBearbeiten Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool SeitenModel::seiteVerschieben(int seiteId, int neuerOrtId)
{
    QSqlQuery q;
    q.prepare("UPDATE seite SET ort_id = :oid WHERE id = :id");
    q.bindValue(":oid", neuerOrtId);
    q.bindValue(":id",  seiteId);
    if (!q.exec()) {
        qCWarning(lcModel) << "seiteVerschieben Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool SeitenModel::ortVerschieben(int ortId, int neueAnlageId)
{
    QSqlQuery q;
    q.prepare("UPDATE ort SET anlage_id = :aid WHERE id = :id");
    q.bindValue(":aid", neueAnlageId);
    q.bindValue(":id",  ortId);
    if (!q.exec()) {
        qCWarning(lcModel) << "ortVerschieben Fehler:" << q.lastError().text();
        return false;
    }
    laden(m_projektId);
    return true;
}

bool SeitenModel::seiteHoch(int seiteId)
{
    // Nutzt die bereits korrekt sortierte In-Memory-Liste statt SQL-Sortierung,
    // damit auch Seiten mit identischem sortierung-Wert (z.B. alle 0) verschoben
    // werden können. Normalisiert alle sortierung-Werte des Orts gleichzeitig.
    for (const auto &a : m_anlagen) {
        for (const auto &o : a.orte) {
            for (int i = 1; i < o.seiten.size(); ++i) {
                if (o.seiten[i].id != seiteId) continue;
                QSqlQuery upd;
                upd.prepare("UPDATE seite SET sortierung = :s WHERE id = :id");
                for (int j = 0; j < o.seiten.size(); ++j) {
                    int newSort = (j == i) ? i - 1 : (j == i - 1) ? i : j;
                    upd.bindValue(":s",  newSort);
                    upd.bindValue(":id", o.seiten[j].id);
                    upd.exec();
                }
                laden(m_projektId);
                return true;
            }
        }
    }
    return false;
}

bool SeitenModel::seiteRunter(int seiteId)
{
    for (const auto &a : m_anlagen) {
        for (const auto &o : a.orte) {
            for (int i = 0; i < o.seiten.size() - 1; ++i) {
                if (o.seiten[i].id != seiteId) continue;
                QSqlQuery upd;
                upd.prepare("UPDATE seite SET sortierung = :s WHERE id = :id");
                for (int j = 0; j < o.seiten.size(); ++j) {
                    int newSort = (j == i) ? i + 1 : (j == i + 1) ? i : j;
                    upd.bindValue(":s",  newSort);
                    upd.bindValue(":id", o.seiten[j].id);
                    upd.exec();
                }
                laden(m_projektId);
                return true;
            }
        }
    }
    return false;
}

bool SeitenModel::seiteUmordnen(int seiteId, int neuerIndex)
{
    for (const auto &a : m_anlagen) {
        for (const auto &o : a.orte) {
            for (int i = 0; i < o.seiten.size(); ++i) {
                if (o.seiten[i].id != seiteId) continue;
                neuerIndex = qBound(0, neuerIndex, o.seiten.size() - 1);
                if (i == neuerIndex) return false;

                QList<int> ids;
                for (const auto &s : o.seiten) ids.append(s.id);
                ids.removeAt(i);
                ids.insert(neuerIndex, seiteId);

                QSqlQuery upd;
                upd.prepare("UPDATE seite SET sortierung = :s WHERE id = :id");
                for (int j = 0; j < ids.size(); ++j) {
                    upd.bindValue(":s",  j);
                    upd.bindValue(":id", ids[j]);
                    upd.exec();
                }
                laden(m_projektId);
                return true;
            }
        }
    }
    return false;
}

double SeitenModel::seiteRasterMm(int seiteId) const
{
    for (const auto &a : m_anlagen)
        for (const auto &o : a.orte)
            for (const auto &s : o.seiten)
                if (s.id == seiteId) return s.rasterMm;
    return 4.0;
}

bool SeitenModel::seiteRastend(int seiteId) const
{
    for (const auto &a : m_anlagen)
        for (const auto &o : a.orte)
            for (const auto &s : o.seiten)
                if (s.id == seiteId) return s.rastend;
    return true;
}

bool SeitenModel::seiteRasterSpeichern(int seiteId, double rasterMm, bool rastend)
{
    QSqlQuery q;
    q.prepare("UPDATE seite SET raster_mm = :mm, rastend = :rs WHERE id = :id");
    q.bindValue(":mm",  rasterMm);
    q.bindValue(":rs",  rastend ? 1 : 0);
    q.bindValue(":id",  seiteId);
    if (!q.exec()) {
        qCWarning(lcModel) << "seiteRasterSpeichern Fehler:" << q.lastError().text();
        return false;
    }
    // In-Memory aktualisieren (kein beginResetModel nötig)
    for (auto &a : m_anlagen)
        for (auto &o : a.orte)
            for (auto &s : o.seiten)
                if (s.id == seiteId) {
                    s.rasterMm = rasterMm;
                    s.rastend  = rastend;
                    return true;
                }
    return true;
}

QVariantList SeitenModel::anlagenListe() const
{
    QVariantList result;
    for (const auto &a : m_anlagen) {
        QVariantMap m;
        m["itemId"] = a.id;
        m["label"]  = QString("=%1  %2").arg(a.kuerzel, a.bezeichnung);
        result.append(m);
    }
    return result;
}

QVariantList SeitenModel::orteListe(int anlageId) const
{
    QVariantList result;
    for (const auto &a : m_anlagen) {
        if (a.id != anlageId) continue;
        for (const auto &o : a.orte) {
            QVariantMap m;
            m["itemId"] = o.id;
            m["label"]  = QString("+%1  %2").arg(o.kuerzel, o.bezeichnung);
            result.append(m);
        }
        break;
    }
    return result;
}

QVariantMap SeitenModel::ortInfo(int ortId) const
{
    QVariantMap m;
    for (const auto &a : m_anlagen) {
        for (const auto &o : a.orte) {
            if (o.id != ortId) continue;
            m["anlageId"]      = a.id;
            m["anlageKuerzel"] = a.kuerzel;
            m["anlageUO"]      = a.anlageUebergeordnet;
            m["ortKuerzel"]    = o.kuerzel;
            m["ortUO"]         = o.standortUebergeordnet;
            return m;
        }
    }
    return m;
}
