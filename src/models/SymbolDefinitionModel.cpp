#include "SymbolDefinitionModel.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

SymbolDefinitionModel::SymbolDefinitionModel(QObject *parent)
    : QObject(parent)
{
}

// ── Lesemethoden ────────────────────────────────────────────────────────────

QVariantList SymbolDefinitionModel::primitiveFuerSymbol(const QString &symbolId) const
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id,
               typ,
               x1, y1, x2, y2, x3, y3,
               radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
               text_inhalt, schrift_relativ, schrift_fett,
               text_align, text_baseline, linienart
        FROM symbol_primitiv
        WHERE symbol_id = :sym
        ORDER BY reihenfolge
    )");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qWarning() << "primitiveFuerSymbol:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]                    = q.value(0).toInt();
        m["typ"]                   = q.value(1).toString();
        m["x1"]                    = q.value(2).toDouble();
        m["y1"]                    = q.value(3).toDouble();
        m["x2"]                    = q.value(4).toDouble();
        m["y2"]                    = q.value(5).toDouble();
        m["x3"]                    = q.value(6).toDouble();
        m["y3"]                    = q.value(7).toDouble();
        m["radius"]                = q.value(8).toDouble();
        m["winkel_von"]            = q.value(9).toDouble();
        m["winkel_bis"]            = q.value(10).toDouble();
        m["bogen_gegen_uhrzeiger"] = q.value(11).toInt() != 0;
        m["text_inhalt"]           = q.value(12).toString();
        m["schrift_relativ"]       = q.value(13).toDouble();
        m["schrift_fett"]          = q.value(14).toInt() != 0;
        m["text_align"]            = q.value(15).toString();
        m["text_baseline"]         = q.value(16).toString();
        m["linienart"]             = q.value(17).toString();
        result.append(m);
    }
    return result;
}

bool SymbolDefinitionModel::hatPrimitive(const QString &symbolId) const
{
    QSqlQuery q;
    q.prepare("SELECT 1 FROM symbol_definition WHERE id = :sym LIMIT 1");
    q.bindValue(":sym", symbolId);
    if (q.exec() && q.next())
        return true;
    return false;
}

QVariantList SymbolDefinitionModel::pinsForSymbol(const QString &symbolId) const
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, name, x, y, offen_x, offen_y, signaltyp, kontext
        FROM symbol_pin
        WHERE symbol_id = :sym
    )");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qWarning() << "pinsForSymbol:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap offen;
        offen["x"] = q.value(4).toDouble();
        offen["y"] = q.value(5).toDouble();

        QVariantMap m;
        m["id"]        = q.value(0).toInt();
        m["name"]      = q.value(1).toString();
        m["x"]         = q.value(2).toDouble();
        m["y"]         = q.value(3).toDouble();
        m["offen"]     = offen;
        m["offenX"]    = q.value(4).toDouble();
        m["offenY"]    = q.value(5).toDouble();
        m["signaltyp"] = q.value(6).toString();
        m["kontext"]   = q.value(7).toString();
        result.append(m);
    }
    return result;
}

QString SymbolDefinitionModel::rolleForSymbol(const QString &symbolId) const
{
    QSqlQuery q;
    q.prepare("SELECT rolle FROM symbol_definition WHERE id = :sym LIMIT 1");
    q.bindValue(":sym", symbolId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("durchleiter");
}

QVariantMap SymbolDefinitionModel::symbolInfo(const QString &symbolId) const
{
    QSqlQuery q;
    q.prepare("SELECT name, kategorie, groesse_raster, rolle, ist_builtin FROM symbol_definition WHERE id = :id LIMIT 1");
    q.bindValue(":id", symbolId);
    if (q.exec() && q.next()) {
        QVariantMap m;
        m["name"]           = q.value(0).toString();
        m["kategorie"]      = q.value(1).toString();
        m["groesse_raster"] = q.value(2).toInt();
        m["rolle"]          = q.value(3).toString();
        m["ist_builtin"]    = q.value(4).toInt() != 0;
        return m;
    }
    return {};
}

QVariantList SymbolDefinitionModel::alleSymbole() const
{
    QVariantList result;
    QSqlQuery q("SELECT id, name, kategorie, groesse_raster, rolle, ist_builtin FROM symbol_definition ORDER BY ist_builtin DESC, kategorie, name");
    while (q.next()) {
        QVariantMap m;
        m["id"]             = q.value(0).toString();
        m["name"]           = q.value(1).toString();
        m["kategorie"]      = q.value(2).toString();
        m["groesse_raster"] = q.value(3).toInt();
        m["rolle"]          = q.value(4).toString();
        m["ist_builtin"]    = q.value(5).toInt() != 0;
        result.append(m);
    }
    return result;
}

// ── Schreibmethoden ─────────────────────────────────────────────────────────

bool SymbolDefinitionModel::symbolAnlegen(const QString &id, const QString &name,
                                           const QString &kategorie, int groesse,
                                           const QString &rolle)
{
    QSqlQuery q;
    q.prepare("INSERT INTO symbol_definition (id, name, kategorie, groesse_raster, rolle, ist_builtin) VALUES (:id, :name, :kat, :gr, :rolle, 0)");
    q.bindValue(":id",    id);
    q.bindValue(":name",  name);
    q.bindValue(":kat",   kategorie);
    q.bindValue(":gr",    groesse);
    q.bindValue(":rolle", rolle);
    if (!q.exec()) {
        qWarning() << "symbolAnlegen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool SymbolDefinitionModel::symbolAktualisieren(const QString &id, const QString &name,
                                                  const QString &kategorie, int groesse,
                                                  const QString &rolle)
{
    QSqlQuery q;
    q.prepare("UPDATE symbol_definition SET name=:name, kategorie=:kat, groesse_raster=:gr, rolle=:rolle WHERE id=:id AND ist_builtin=0");
    q.bindValue(":name",  name);
    q.bindValue(":kat",   kategorie);
    q.bindValue(":gr",    groesse);
    q.bindValue(":rolle", rolle);
    q.bindValue(":id",    id);
    if (!q.exec()) {
        qWarning() << "symbolAktualisieren:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool SymbolDefinitionModel::symbolLoeschen(const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM symbol_definition WHERE id=:id AND ist_builtin=0");
    q.bindValue(":id", symbolId);
    if (!q.exec()) {
        qWarning() << "symbolLoeschen:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

int SymbolDefinitionModel::primitivHinzufuegen(const QString &symbolId, const QVariantMap &daten)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO symbol_primitiv
            (symbol_id, reihenfolge, typ,
             x1, y1, x2, y2, x3, y3,
             radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
             text_inhalt, schrift_relativ, schrift_fett,
             text_align, text_baseline, linienart)
        VALUES
            (:sym, :reihe, :typ,
             :x1, :y1, :x2, :y2, :x3, :y3,
             :rad, :wvon, :wbis, :ccw,
             :ti, :sr, :sf,
             :ta, :tb, :la)
    )");
    q.bindValue(":sym",   symbolId);
    q.bindValue(":reihe", daten.value("reihenfolge", 0));
    q.bindValue(":typ",   daten.value("typ", "linie"));
    q.bindValue(":x1",    daten.value("x1", 0.0));
    q.bindValue(":y1",    daten.value("y1", 0.0));
    q.bindValue(":x2",    daten.value("x2", 0.0));
    q.bindValue(":y2",    daten.value("y2", 0.0));
    q.bindValue(":x3",    daten.value("x3", 0.0));
    q.bindValue(":y3",    daten.value("y3", 0.0));
    q.bindValue(":rad",   daten.value("radius", 0.0));
    q.bindValue(":wvon",  daten.value("winkel_von", 0.0));
    q.bindValue(":wbis",  daten.value("winkel_bis", 360.0));
    q.bindValue(":ccw",   daten.value("bogen_gegen_uhrzeiger", false).toBool() ? 1 : 0);
    q.bindValue(":ti",    daten.value("text_inhalt", ""));
    q.bindValue(":sr",    daten.value("schrift_relativ", 0.15));
    q.bindValue(":sf",    daten.value("schrift_fett", false).toBool() ? 1 : 0);
    q.bindValue(":ta",    daten.value("text_align", "center"));
    q.bindValue(":tb",    daten.value("text_baseline", "middle"));
    q.bindValue(":la",    daten.value("linienart", "solid"));
    if (!q.exec()) {
        qWarning() << "primitivHinzufuegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool SymbolDefinitionModel::primitivAlleLoeschen(const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM symbol_primitiv WHERE symbol_id = :sym");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qWarning() << "primitivAlleLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

int SymbolDefinitionModel::pinHinzufuegen(const QString &symbolId, const QVariantMap &daten)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, kontext)
        VALUES (:sym, :name, :x, :y, :ox, :oy, :sig, :ctx)
    )");
    q.bindValue(":sym",  symbolId);
    q.bindValue(":name", daten.value("name", ""));
    q.bindValue(":x",    daten.value("x", 0.0));
    q.bindValue(":y",    daten.value("y", 0.5));
    q.bindValue(":ox",   daten.value("offenX", -1.0));
    q.bindValue(":oy",   daten.value("offenY", 0.0));
    q.bindValue(":sig",  daten.value("signaltyp", "neutral"));
    q.bindValue(":ctx",  daten.value("kontext", ""));
    if (!q.exec()) {
        qWarning() << "pinHinzufuegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool SymbolDefinitionModel::pinAlleLoeschen(const QString &symbolId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM symbol_pin WHERE symbol_id = :sym");
    q.bindValue(":sym", symbolId);
    if (!q.exec()) {
        qWarning() << "pinAlleLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}
