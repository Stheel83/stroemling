#include "Database.h"
#include <cmath>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <algorithm>

QVariantList Database::wikiAlleKategorien()
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name");
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0);
        m["name"]         = q.value(1);
        m["beschreibung"] = q.value(2);
        m["sortierung"]   = q.value(3);
        result << m;
    }
    return result;
}

int Database::wikiKategorieAnlegen(const QString &name, const QString &beschreibung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("INSERT INTO wiki_kategorie (name, beschreibung) VALUES (:n, :b)");
    q.bindValue(":n", name);
    q.bindValue(":b", beschreibung);
    if (!q.exec()) {
        qWarning() << "wikiKategorieAnlegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiKategorieUmbenennen(int id, const QString &name, const QString &beschreibung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_kategorie SET name = :n, beschreibung = :b WHERE id = :id");
    q.bindValue(":n",   name);
    q.bindValue(":b",   beschreibung);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qWarning() << "wikiKategorieUmbenennen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiKategorieLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_kategorie WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiKategorieLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiKategorieSortierungSetzen(int id, int sortierung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_kategorie SET sortierung = :s WHERE id = :id");
    q.bindValue(":s",  sortierung);
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiKategorieSortierungSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Wiki – Artikel
// ============================================================
QVariantList Database::wikiArtikelFuerKategorie(int kategorieId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, titel, tags, geaendert_am, ist_system, bundle_kennung, von_nutzer_geaendert FROM wiki_artikel WHERE kategorie_id = :kid ORDER BY titel");
    q.bindValue(":kid", kategorieId);
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]                 = q.value(0);
        m["titel"]              = q.value(1);
        m["tags"]               = q.value(2);
        m["geaendertAm"]        = q.value(3);
        m["istSystem"]          = q.value(4);
        m["bundleKennung"]      = q.value(5);
        m["vonNutzerGeaendert"] = q.value(6);
        result << m;
    }
    return result;
}

QVariantMap Database::wikiArtikelLaden(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, kategorie_id, titel, inhalt, tags, ist_system, bundle_kennung, von_nutzer_geaendert, erstellt_am, geaendert_am FROM wiki_artikel WHERE id = :id");
    q.bindValue(":id", id);
    QVariantMap m;
    if (!q.exec() || !q.next()) return m;
    m["id"]                 = q.value(0);
    m["kategorieId"]        = q.value(1);
    m["titel"]              = q.value(2);
    m["inhalt"]             = q.value(3);
    m["tags"]               = q.value(4);
    m["istSystem"]          = q.value(5);
    m["bundleKennung"]      = q.value(6);
    m["vonNutzerGeaendert"] = q.value(7);
    m["erstelltAm"]         = q.value(8);
    m["geaendertAm"]        = q.value(9);
    return m;
}

int Database::wikiArtikelAnlegen(int kategorieId, const QString &titel)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("INSERT INTO wiki_artikel (kategorie_id, titel) VALUES (:kid, :t)");
    q.bindValue(":kid", kategorieId);
    q.bindValue(":t",   titel);
    if (!q.exec()) {
        qWarning() << "wikiArtikelAnlegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiArtikelSpeichern(int id, const QString &titel,
                                     const QString &inhalt, const QString &tags)
{
    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        UPDATE wiki_artikel
        SET titel = :t, inhalt = :i, tags = :tags,
            geaendert_am = datetime('now')
        WHERE id = :id
    )");
    q.bindValue(":t",    titel);
    q.bindValue(":i",    inhalt);
    q.bindValue(":tags", tags);
    q.bindValue(":id",   id);
    if (!q.exec()) {
        qWarning() << "wikiArtikelSpeichern:" << q.lastError().text();
        return false;
    }
    // Wenn es ein Bundle-Artikel ist, Nutzer-Änderung markieren
    QSqlQuery flag(m_wikiDb);
    flag.prepare("UPDATE wiki_artikel SET von_nutzer_geaendert = 1 WHERE id = :id AND bundle_kennung IS NOT NULL");
    flag.bindValue(":id", id);
    flag.exec();
    return true;
}

bool Database::wikiArtikelLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_artikel WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiArtikelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Wiki – Bilder
// ============================================================
QVariantList Database::wikiBilderFuerArtikel(int artikelId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, dateiname, mime_typ, beschreibung, sortierung FROM wiki_bild WHERE artikel_id = :aid ORDER BY sortierung, id");
    q.bindValue(":aid", artikelId);
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0);
        m["dateiname"]    = q.value(1);
        m["mimeTyp"]      = q.value(2);
        m["beschreibung"] = q.value(3);
        m["sortierung"]   = q.value(4);
        result << m;
    }
    return result;
}

int Database::wikiBildHinzufuegen(int artikelId, const QString &pfad)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QImage img(localPfad);
    if (img.isNull()) {
        qWarning() << "wikiBildHinzufuegen: Bild nicht lesbar:" << localPfad;
        return -1;
    }
    if (img.width() > 1920)
        img = img.scaledToWidth(1920, Qt::SmoothTransformation);

    QByteArray daten;
    QBuffer buf(&daten);
    buf.open(QIODevice::WriteOnly);
    const QString ext = QFileInfo(localPfad).suffix().toLower();
    const QByteArray fmt = (ext == "png") ? "PNG" : "JPEG";
    img.save(&buf, fmt.constData(), 85);

    const QString mimeTyp   = (ext == "png") ? "image/png" : "image/jpeg";
    const QString dateiname = QFileInfo(localPfad).fileName();

    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, sortierung)
        VALUES (:aid, :fn, :mime, :daten,
                (SELECT COALESCE(MAX(sortierung), 0) + 1 FROM wiki_bild WHERE artikel_id = :aid2))
    )");
    q.bindValue(":aid",   artikelId);
    q.bindValue(":fn",    dateiname);
    q.bindValue(":mime",  mimeTyp);
    q.bindValue(":daten", daten);
    q.bindValue(":aid2",  artikelId);
    if (!q.exec()) {
        qWarning() << "wikiBildHinzufuegen INSERT:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiBildLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiBildLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

QString Database::wikiBildAlsTempDatei(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT daten, mime_typ FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec() || !q.next()) return {};

    const QByteArray daten = q.value(0).toByteArray();
    const QString mimeTyp  = q.value(1).toString();
    const QString ext      = mimeTyp.contains("png") ? ".png" : ".jpg";
    const QString tmpPfad  = QDir::tempPath() + "/stroemling_wiki_" + QString::number(id) + ext;

    QFile f(tmpPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "wikiBildAlsTempDatei: Datei nicht schreibbar:" << tmpPfad;
        return {};
    }
    f.write(daten);
    return tmpPfad;
}

// ============================================================
// Wiki – Volltext-Suche (FTS5)
// ============================================================
QVariantList Database::wikiSuchen(const QString &suchbegriff)
{
    if (suchbegriff.trimmed().isEmpty()) return {};

    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        SELECT wa.id, wa.kategorie_id, wa.titel, wa.tags,
               snippet(wiki_suche, 1, '<b>', '</b>', '…', 20) AS snippet
        FROM wiki_suche
        JOIN wiki_artikel wa ON wa.id = wiki_suche.rowid
        WHERE wiki_suche MATCH :q
        ORDER BY rank
    )");
    q.bindValue(":q", suchbegriff + "*");

    QVariantList result;
    if (!q.exec()) {
        qWarning() << "wikiSuchen:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]          = q.value(0);
        m["kategorieId"] = q.value(1);
        m["titel"]       = q.value(2);
        m["tags"]        = q.value(3);
        m["snippet"]     = q.value(4);
        result << m;
    }
    return result;
}

// ============================================================
// Wiki – Export / Import (JSON)
// ============================================================
bool Database::wikiExportJson(const QString &pfad)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    // Kategorien
    QJsonArray kategorienArr;
    QSqlQuery qKat(m_wikiDb);
    if (!qKat.exec("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name")) {
        qWarning() << "wikiExportJson kategorien:" << qKat.lastError().text();
        return false;
    }
    while (qKat.next()) {
        QJsonObject o;
        o["id"]           = qKat.value(0).toInt();
        o["name"]         = qKat.value(1).toString();
        o["beschreibung"] = qKat.value(2).toString();
        o["sortierung"]   = qKat.value(3).toInt();
        kategorienArr.append(o);
    }

    // Nur Nutzer-Artikel (ist_system = 0)
    QJsonArray artikelArr;
    QSqlQuery qArt(m_wikiDb);
    if (!qArt.exec(R"(
        SELECT wa.id, wa.kategorie_id, wk.name, wa.titel, wa.inhalt, wa.tags
        FROM wiki_artikel wa
        JOIN wiki_kategorie wk ON wk.id = wa.kategorie_id
        WHERE wa.ist_system = 0
        ORDER BY wk.sortierung, wk.name, wa.titel
    )")) {
        qWarning() << "wikiExportJson artikel:" << qArt.lastError().text();
        return false;
    }
    while (qArt.next()) {
        QJsonObject o;
        o["id"]             = qArt.value(0).toInt();
        o["kategorie_id"]   = qArt.value(1).toInt();
        o["kategorie_name"] = qArt.value(2).toString();
        o["titel"]          = qArt.value(3).toString();
        o["inhalt"]         = qArt.value(4).toString();
        o["tags"]           = qArt.value(5).toString();
        artikelArr.append(o);
    }

    // Bilder der exportierten Artikel
    QJsonArray bilderArr;
    QSqlQuery qBild(m_wikiDb);
    if (!qBild.exec(R"(
        SELECT wb.id, wb.artikel_id, wb.dateiname, wb.mime_typ, wb.daten, wb.beschreibung, wb.sortierung
        FROM wiki_bild wb
        JOIN wiki_artikel wa ON wa.id = wb.artikel_id
        WHERE wa.ist_system = 0
        ORDER BY wb.artikel_id, wb.sortierung, wb.id
    )")) {
        qWarning() << "wikiExportJson bilder:" << qBild.lastError().text();
        return false;
    }
    while (qBild.next()) {
        QJsonObject o;
        o["id"]           = qBild.value(0).toInt();
        o["artikel_id"]   = qBild.value(1).toInt();
        o["dateiname"]    = qBild.value(2).toString();
        o["mime_typ"]     = qBild.value(3).toString();
        o["daten_base64"] = QString::fromLatin1(qBild.value(4).toByteArray().toBase64());
        o["beschreibung"] = qBild.value(5).toString();
        o["sortierung"]   = qBild.value(6).toInt();
        bilderArr.append(o);
    }

    QJsonObject root;
    root["wiki_export_version"] = 1;
    root["exportiert_am"]       = QDateTime::currentDateTime().toString(Qt::ISODate);
    root["kategorien"]          = kategorienArr;
    root["artikel"]             = artikelArr;
    root["bilder"]              = bilderArr;

    QFile f(localPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "wikiExportJson: Datei nicht schreibbar:" << localPfad;
        return false;
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    qInfo() << "Wiki exportiert:" << localPfad << "-" << artikelArr.size() << "Artikel";
    return true;
}

bool Database::wikiImportJson(const QString &pfad, bool mergeMode)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QFile f(localPfad);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "wikiImportJson: Datei nicht lesbar:" << localPfad;
        return false;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (doc.isNull()) {
        qWarning() << "wikiImportJson: JSON-Fehler:" << err.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root["wiki_export_version"].toInt() != 1) {
        qWarning() << "wikiImportJson: Unbekannte Export-Version:" << root["wiki_export_version"].toInt();
        return false;
    }

    if (!m_wikiDb.transaction()) {
        qWarning() << "wikiImportJson: Transaktion fehlgeschlagen";
        return false;
    }

    // Replace-Modus: alle Nutzer-Artikel löschen (Bilder cascaden automatisch)
    if (!mergeMode) {
        QSqlQuery del(m_wikiDb);
        if (!del.exec("DELETE FROM wiki_artikel WHERE ist_system = 0")) {
            qWarning() << "wikiImportJson replace:" << del.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    // Kategorien: vorhandene nach Name finden oder neu anlegen; old-ID → new-ID Map
    QMap<int, int> katIdMap;
    const QJsonArray katArr = root["kategorien"].toArray();
    for (const QJsonValue &v : katArr) {
        const QJsonObject o = v.toObject();
        const int    oldId  = o["id"].toInt();
        const QString name  = o["name"].toString();

        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        find.bindValue(":n", name);
        if (find.exec() && find.next()) {
            katIdMap[oldId] = find.value(0).toInt();
        } else {
            QSqlQuery ins(m_wikiDb);
            ins.prepare("INSERT INTO wiki_kategorie (name, beschreibung, sortierung) VALUES (:n, :b, :s)");
            ins.bindValue(":n", name);
            ins.bindValue(":b", o["beschreibung"].toString());
            ins.bindValue(":s", o["sortierung"].toInt());
            if (!ins.exec()) {
                qWarning() << "wikiImportJson Kategorie anlegen:" << ins.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
            katIdMap[oldId] = ins.lastInsertId().toInt();
        }
    }

    // Artikel einfügen; old-Art-ID → new-Art-ID Map für Bild-Zuordnung
    QMap<int, int> artIdMap;
    const QJsonArray artArr = root["artikel"].toArray();
    for (const QJsonValue &v : artArr) {
        const QJsonObject o   = v.toObject();
        const int oldArtId    = o["id"].toInt();
        const int oldKatId    = o["kategorie_id"].toInt();
        const QString katName = o["kategorie_name"].toString();

        int newKatId = katIdMap.value(oldKatId, -1);
        if (newKatId < 0) {
            // Kategorie nicht im Export enthalten – nach Name suchen
            QSqlQuery find(m_wikiDb);
            find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
            find.bindValue(":n", katName);
            if (find.exec() && find.next()) {
                newKatId = find.value(0).toInt();
                katIdMap[oldKatId] = newKatId;
            } else {
                QSqlQuery ins(m_wikiDb);
                ins.prepare("INSERT INTO wiki_kategorie (name) VALUES (:n)");
                ins.bindValue(":n", katName);
                if (!ins.exec()) { m_wikiDb.rollback(); return false; }
                newKatId = ins.lastInsertId().toInt();
                katIdMap[oldKatId] = newKatId;
            }
        }

        QSqlQuery ins(m_wikiDb);
        ins.prepare(R"(
            INSERT INTO wiki_artikel (kategorie_id, titel, inhalt, tags, ist_system)
            VALUES (:kid, :t, :i, :tags, 0)
        )");
        ins.bindValue(":kid",  newKatId);
        ins.bindValue(":t",    o["titel"].toString());
        ins.bindValue(":i",    o["inhalt"].toString());
        ins.bindValue(":tags", o["tags"].toString());
        if (!ins.exec()) {
            qWarning() << "wikiImportJson Artikel einfügen:" << ins.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
        artIdMap[oldArtId] = ins.lastInsertId().toInt();
    }

    // Bilder einfügen
    const QJsonArray bildArr = root["bilder"].toArray();
    for (const QJsonValue &v : bildArr) {
        const QJsonObject o = v.toObject();
        const int newArtId  = artIdMap.value(o["artikel_id"].toInt(), -1);
        if (newArtId < 0) continue;

        QSqlQuery ins(m_wikiDb);
        ins.prepare(R"(
            INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, beschreibung, sortierung)
            VALUES (:aid, :fn, :mime, :daten, :beschr, :sort)
        )");
        ins.bindValue(":aid",   newArtId);
        ins.bindValue(":fn",    o["dateiname"].toString());
        ins.bindValue(":mime",  o["mime_typ"].toString());
        ins.bindValue(":daten", QByteArray::fromBase64(o["daten_base64"].toString().toLatin1()));
        ins.bindValue(":beschr", o["beschreibung"].toString());
        ins.bindValue(":sort",  o["sortierung"].toInt());
        if (!ins.exec()) {
            qWarning() << "wikiImportJson Bild einfügen:" << ins.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        qWarning() << "wikiImportJson commit:" << m_wikiDb.lastError().text();
        return false;
    }
    qInfo() << "Wiki importiert:" << artArr.size() << "Artikel"
            << (mergeMode ? "(Merge)" : "(Replace)");
    return true;
}

// ============================================================
// wikiBundleAnwenden
// Spielt ein Bundle (Datei oder Qt-Ressource) ein.
// Gibt {erfolg, neu, aktualisiert, uebersprungen, meldung} zurück.
// ============================================================
QVariantMap Database::wikiBundleAnwenden(const QString &pfad)
{
    QVariantMap result;
    result["erfolg"]        = false;
    result["neu"]           = 0;
    result["aktualisiert"]  = 0;
    result["uebersprungen"] = 0;
    result["meldung"]       = QString();

    // Pfad normalisieren: file:// → lokaler Pfad; qrc:/ → :/
    QString localPfad = pfad;
    if (QUrl(pfad).isLocalFile())
        localPfad = QUrl(pfad).toLocalFile();
    else if (localPfad.startsWith("qrc:/"))
        localPfad = localPfad.mid(3);

    QFile f(localPfad);
    if (!f.open(QIODevice::ReadOnly)) {
        result["meldung"] = QString("Datei nicht lesbar: %1").arg(localPfad);
        qWarning() << "wikiBundleAnwenden:" << result["meldung"].toString();
        return result;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (doc.isNull()) {
        result["meldung"] = QString("JSON-Fehler: %1").arg(err.errorString());
        qWarning() << "wikiBundleAnwenden:" << result["meldung"].toString();
        return result;
    }
    const QJsonObject root = doc.object();
    if (root["wiki_export_version"].toInt() != 1) {
        result["meldung"] = QString("Unbekannte Export-Version: %1").arg(root["wiki_export_version"].toInt());
        return result;
    }
    const QString kennung       = root["bundle_kennung"].toString();
    const int     bundleVersion = root["bundle_version"].toInt();
    if (kennung.isEmpty()) {
        result["meldung"] = "Bundle hat keine Kennung (bundle_kennung fehlt) – nutze Wiki-Import statt Bundle-Import";
        return result;
    }

    // Versionsprüfung gegen wiki_meta
    {
        QSqlQuery vq(m_wikiDb);
        vq.prepare("SELECT wert FROM wiki_meta WHERE schluessel = :s");
        vq.bindValue(":s", "bundle_version_" + kennung);
        if (vq.exec() && vq.next()) {
            const int gespeichert = vq.value(0).toString().toInt();
            if (bundleVersion <= gespeichert) {
                result["erfolg"]  = true;
                result["meldung"] = QString("Bereits aktuell (v%1)").arg(gespeichert);
                return result;
            }
        }
    }

    if (!m_wikiDb.transaction()) {
        result["meldung"] = "Transaktion fehlgeschlagen";
        return result;
    }

    int neuCount = 0, aktCount = 0, skipCount = 0;

    // Kategorien: nach Name finden oder neu anlegen
    QMap<int, int> katIdMap;
    for (const QJsonValue &v : root["kategorien"].toArray()) {
        const QJsonObject o  = v.toObject();
        const int    oldId   = o["id"].toInt();
        const QString name   = o["name"].toString();
        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        find.bindValue(":n", name);
        if (find.exec() && find.next()) {
            katIdMap[oldId] = find.value(0).toInt();
        } else {
            QSqlQuery ins(m_wikiDb);
            ins.prepare("INSERT INTO wiki_kategorie (name, beschreibung, sortierung) VALUES (:n, :b, :s)");
            ins.bindValue(":n", name);
            ins.bindValue(":b", o["beschreibung"].toString());
            ins.bindValue(":s", o["sortierung"].toInt());
            if (!ins.exec()) {
                m_wikiDb.rollback();
                result["meldung"] = "Kategorie anlegen: " + ins.lastError().text();
                return result;
            }
            katIdMap[oldId] = ins.lastInsertId().toInt();
        }
    }

    // Bilder nach bundle-lokaler Artikel-ID gruppieren
    QMap<int, QList<QJsonObject>> bilderNachArtId;
    for (const QJsonValue &v : root["bilder"].toArray())
        bilderNachArtId[v.toObject()["artikel_id"].toInt()].append(v.toObject());

    // Artikel einfügen / aktualisieren / überspringen
    for (const QJsonValue &v : root["artikel"].toArray()) {
        const QJsonObject o   = v.toObject();
        const int  oldArtId   = o["id"].toInt();
        const int  oldKatId   = o["kategorie_id"].toInt();
        const QString katName = o["kategorie_name"].toString();
        const QString titel   = o["titel"].toString();
        const QString inhalt  = o["inhalt"].toString();
        const QString tags    = o["tags"].toString();

        // Kategorie-ID auflösen (Fallback über Name)
        int newKatId = katIdMap.value(oldKatId, -1);
        if (newKatId < 0) {
            QSqlQuery find(m_wikiDb);
            find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
            find.bindValue(":n", katName);
            if (find.exec() && find.next()) {
                newKatId = find.value(0).toInt();
                katIdMap[oldKatId] = newKatId;
            } else {
                QSqlQuery ins(m_wikiDb);
                ins.prepare("INSERT INTO wiki_kategorie (name) VALUES (:n)");
                ins.bindValue(":n", katName);
                if (!ins.exec()) { m_wikiDb.rollback(); result["meldung"] = "Kategorie (Fallback): " + ins.lastError().text(); return result; }
                newKatId = ins.lastInsertId().toInt();
                katIdMap[oldKatId] = newKatId;
            }
        }

        // Vorhandenen Artikel suchen
        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id, von_nutzer_geaendert FROM wiki_artikel WHERE bundle_kennung = :bk AND titel = :t");
        find.bindValue(":bk", kennung);
        find.bindValue(":t",  titel);

        auto _bilderEinfuegen = [&](int artDbId, const QString &inhaltVorlage) -> QString {
            QMap<int, int> bildIdMap;
            for (const QJsonObject &b : bilderNachArtId.value(oldArtId)) {
                QSqlQuery bIns(m_wikiDb);
                bIns.prepare(R"(
                    INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, beschreibung, sortierung)
                    VALUES (:aid, :fn, :mime, :daten, :beschr, :sort)
                )");
                bIns.bindValue(":aid",   artDbId);
                bIns.bindValue(":fn",    b["dateiname"].toString());
                bIns.bindValue(":mime",  b["mime_typ"].toString());
                bIns.bindValue(":daten", QByteArray::fromBase64(b["daten_base64"].toString().toLatin1()));
                bIns.bindValue(":beschr", b["beschreibung"].toString());
                bIns.bindValue(":sort",  b["sortierung"].toInt());
                if (bIns.exec())
                    bildIdMap[b["id"].toInt()] = bIns.lastInsertId().toInt();
            }
            // wiki://bild/{bundle-lokal} → wiki://bild/{db-id}
            QString inhaltRemap = inhaltVorlage;
            for (auto it = bildIdMap.cbegin(); it != bildIdMap.cend(); ++it)
                inhaltRemap.replace(
                    QString("wiki://bild/%1").arg(it.key()),
                    QString("wiki://bild/%1").arg(it.value())
                );
            return inhaltRemap;
        };

        if (find.exec() && find.next()) {
            const int existingId          = find.value(0).toInt();
            const int vonNutzerGeaendert  = find.value(1).toInt();
            if (vonNutzerGeaendert == 1) {
                skipCount++;
            } else {
                // Bilder löschen (cascaden würde nicht, da kein ON DELETE CASCADE für UPDATE)
                QSqlQuery delBilder(m_wikiDb);
                delBilder.prepare("DELETE FROM wiki_bild WHERE artikel_id = :aid");
                delBilder.bindValue(":aid", existingId);
                delBilder.exec();

                const QString inhaltRemap = _bilderEinfuegen(existingId, inhalt);
                QSqlQuery upd(m_wikiDb);
                upd.prepare(R"(
                    UPDATE wiki_artikel
                    SET titel = :t, inhalt = :i, tags = :tags,
                        kategorie_id = :kid, geaendert_am = datetime('now')
                    WHERE id = :id
                )");
                upd.bindValue(":t",   titel);
                upd.bindValue(":i",   inhaltRemap);
                upd.bindValue(":tags", tags);
                upd.bindValue(":kid", newKatId);
                upd.bindValue(":id",  existingId);
                if (!upd.exec()) {
                    m_wikiDb.rollback();
                    result["meldung"] = "UPDATE: " + upd.lastError().text();
                    return result;
                }
                // Inhalt mit remappten IDs zurückschreiben
                if (inhaltRemap != inhalt) {
                    QSqlQuery updInhalt(m_wikiDb);
                    updInhalt.prepare("UPDATE wiki_artikel SET inhalt = :i WHERE id = :id");
                    updInhalt.bindValue(":i",  inhaltRemap);
                    updInhalt.bindValue(":id", existingId);
                    updInhalt.exec();
                }
                aktCount++;
            }
        } else {
            // Neu anlegen
            QSqlQuery ins(m_wikiDb);
            ins.prepare(R"(
                INSERT INTO wiki_artikel (kategorie_id, titel, inhalt, tags, bundle_kennung, ist_system)
                VALUES (:kid, :t, :i, :tags, :bk, 0)
            )");
            ins.bindValue(":kid",  newKatId);
            ins.bindValue(":t",    titel);
            ins.bindValue(":i",    inhalt);
            ins.bindValue(":tags", tags);
            ins.bindValue(":bk",   kennung);
            if (!ins.exec()) {
                m_wikiDb.rollback();
                result["meldung"] = "INSERT: " + ins.lastError().text();
                return result;
            }
            const int newArtId    = ins.lastInsertId().toInt();
            const QString inhaltRemap = _bilderEinfuegen(newArtId, inhalt);
            if (inhaltRemap != inhalt) {
                QSqlQuery updInhalt(m_wikiDb);
                updInhalt.prepare("UPDATE wiki_artikel SET inhalt = :i WHERE id = :id");
                updInhalt.bindValue(":i",  inhaltRemap);
                updInhalt.bindValue(":id", newArtId);
                updInhalt.exec();
            }
            neuCount++;
        }
    }

    // Bundle-Version speichern
    {
        QSqlQuery upsert(m_wikiDb);
        upsert.prepare("INSERT OR REPLACE INTO wiki_meta (schluessel, wert) VALUES (:s, :v)");
        upsert.bindValue(":s", "bundle_version_" + kennung);
        upsert.bindValue(":v", QString::number(bundleVersion));
        upsert.exec();
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        result["meldung"] = "Commit fehlgeschlagen";
        return result;
    }

    result["erfolg"]        = true;
    result["neu"]           = neuCount;
    result["aktualisiert"]  = aktCount;
    result["uebersprungen"] = skipCount;
    result["meldung"]       = QString("%1 neu, %2 aktualisiert, %3 übersprungen")
                                .arg(neuCount).arg(aktCount).arg(skipCount);
    qInfo() << "wikiBundleAnwenden" << kennung << "v" << bundleVersion << "–" << result["meldung"].toString();
    return result;
}

// ============================================================
// wikiBundleExportieren
// ============================================================
bool Database::wikiBundleExportieren(const QString &pfad, const QString &kennung,
                                      const QString &titel, int version,
                                      const QVariantList &kategorieIds)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QSet<int> katIdSet;
    for (const QVariant &v : kategorieIds)
        katIdSet.insert(v.toInt());

    // Kategorien
    QJsonArray kategorienArr;
    QSqlQuery qKat(m_wikiDb);
    if (!qKat.exec("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name"))
        return false;
    while (qKat.next()) {
        if (!katIdSet.contains(qKat.value(0).toInt())) continue;
        QJsonObject o;
        o["id"]           = qKat.value(0).toInt();
        o["name"]         = qKat.value(1).toString();
        o["beschreibung"] = qKat.value(2).toString();
        o["sortierung"]   = qKat.value(3).toInt();
        kategorienArr.append(o);
    }

    // Artikel (keine ist_system=1)
    QJsonArray artikelArr;
    QSet<int> exportArtIds;
    QSqlQuery qArt(m_wikiDb);
    if (!qArt.exec(R"(
        SELECT wa.id, wa.kategorie_id, wk.name, wa.titel, wa.inhalt, wa.tags
        FROM wiki_artikel wa JOIN wiki_kategorie wk ON wk.id = wa.kategorie_id
        WHERE wa.ist_system = 0
        ORDER BY wk.sortierung, wk.name, wa.titel
    )")) return false;
    while (qArt.next()) {
        if (!katIdSet.contains(qArt.value(1).toInt())) continue;
        QJsonObject o;
        o["id"]             = qArt.value(0).toInt();
        o["kategorie_id"]   = qArt.value(1).toInt();
        o["kategorie_name"] = qArt.value(2).toString();
        o["titel"]          = qArt.value(3).toString();
        o["inhalt"]         = qArt.value(4).toString();
        o["tags"]           = qArt.value(5).toString();
        artikelArr.append(o);
        exportArtIds.insert(qArt.value(0).toInt());
    }

    // Bilder der exportierten Artikel
    QJsonArray bilderArr;
    QSqlQuery qBild(m_wikiDb);
    if (!qBild.exec(R"(
        SELECT wb.id, wb.artikel_id, wb.dateiname, wb.mime_typ, wb.daten, wb.beschreibung, wb.sortierung
        FROM wiki_bild wb JOIN wiki_artikel wa ON wa.id = wb.artikel_id
        WHERE wa.ist_system = 0
        ORDER BY wb.artikel_id, wb.sortierung, wb.id
    )")) return false;
    while (qBild.next()) {
        if (!exportArtIds.contains(qBild.value(1).toInt())) continue;
        QJsonObject o;
        o["id"]           = qBild.value(0).toInt();
        o["artikel_id"]   = qBild.value(1).toInt();
        o["dateiname"]    = qBild.value(2).toString();
        o["mime_typ"]     = qBild.value(3).toString();
        o["daten_base64"] = QString::fromLatin1(qBild.value(4).toByteArray().toBase64());
        o["beschreibung"] = qBild.value(5).toString();
        o["sortierung"]   = qBild.value(6).toInt();
        bilderArr.append(o);
    }

    QJsonObject rootObj;
    rootObj["wiki_export_version"] = 1;
    rootObj["bundle_kennung"]      = kennung;
    rootObj["bundle_version"]      = version;
    rootObj["bundle_titel"]        = titel;
    rootObj["exportiert_am"]       = QDateTime::currentDateTime().toString(Qt::ISODate);
    rootObj["kategorien"]          = kategorienArr;
    rootObj["artikel"]             = artikelArr;
    rootObj["bilder"]              = bilderArr;

    QFile f(localPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "wikiBundleExportieren: nicht schreibbar:" << localPfad;
        return false;
    }
    f.write(QJsonDocument(rootObj).toJson());
    qInfo() << "wikiBundleExportieren:" << kennung << "v" << version
            << artikelArr.size() << "Artikel, Pfad:" << localPfad;
    return true;
}

// ============================================================
// wikiBundleArtikelZuruecksetzen / wikiBundleAktiveListe
// ============================================================
bool Database::wikiBundleArtikelZuruecksetzen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_artikel SET von_nutzer_geaendert = 0 WHERE id = :id AND bundle_kennung IS NOT NULL");
    q.bindValue(":id", id);
    return q.exec();
}

QVariantList Database::wikiBundleAktiveListe()
{
    QSqlQuery q(m_wikiDb);
    q.exec("SELECT schluessel, wert FROM wiki_meta WHERE schluessel LIKE 'bundle_version_%' ORDER BY schluessel");
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m["kennung"] = q.value(0).toString().mid(QString("bundle_version_").length());
        m["version"] = q.value(1).toString().toInt();
        result << m;
    }
    return result;
}

// ============================================================
// seedWikiStarterInhalte
// Legt System-Kategorien und -Artikel an (INSERT OR IGNORE –
// idempotent, bestehende Nutzer-Inhalte bleiben unberührt).
// ============================================================
bool Database::seedWikiStarterInhalte()
{
    struct Artikel {
        QString titel;
        QString inhalt;
        QString tags;
    };
    struct Kategorie {
        QString name;
        QString beschreibung;
        int sortierung;
        bool istSystem;          // true → Artikel werden mit ist_system=1 gepflegt
        QList<Artikel> artikel;
    };

    const QList<Kategorie> kategorien = {
        {
            "Bedienhinweise",
            "Grundlegende Bedienung von Strömling Design",
            1,
            true,
            {
                {
                    "Programmübersicht",
                    R"(# Programmübersicht

Strömling Design ist in mehrere Arbeitsbereiche aufgeteilt, zwischen denen
du über die **Seitenleiste links** wechselst.

## Arbeitsbereiche

| Symbol | Bereich | Funktion |
|--------|---------|----------|
| 📐 | Schaltplan | Schaltpläne zeichnen, Verbindungen ziehen |
| 🔧 | Symbole | Eigene Schaltsymbole erstellen und bearbeiten |
| 📋 | Normblatt | Schriftfeld-Vorlagen gestalten |
| ✅ | IBN | Inbetriebnahme-Prüfprotokoll |
| ⚡ | Kabelrechner | Leitungsquerschnitt nach VDE berechnen |
| 📊 | Listen | Kabel-, Klemmen- und Stücklisten |
| 📖 | Wiki | Persönliche Erfahrungen und Notizen |

## Grundprinzip

- **Links:** Seitenbaum (Projektseiten) oder Navigationsleiste
- **Mitte:** Arbeitsbereich / Zeichenfläche
- **Rechts:** Eigenschaftenpanel – zeigt die Eigenschaften des gewählten Elements
)",
                    "übersicht navigation sidebar"
                },
                {
                    "Schaltplan – Erste Schritte",
                    R"(# Schaltplan – Erste Schritte

## Projekt anlegen

1. Beim Programmstart wird automatisch ein leeres Projekt geöffnet.
2. Im **Seitenbaum links** siehst du alle Seiten des Projekts.
3. Über das **+**-Symbol im Seitenbaum fügst du neue Seiten hinzu.

## Zeichenfläche

Die Zeichenfläche arbeitet mit einem **Raster** (Standardeinheit: Werkeeinheiten, WE).

- **Zoomen:** Mausrad
- **Verschieben:** Mittlere Maustaste gedrückt halten und ziehen
- **Auswählen:** Linksklick auf ein Element

## Elemente platzieren

1. Im **Eigenschaftenpanel rechts** (oder über Tastenkürzel) Werkzeug wählen.
2. Linksklick auf die Zeichenfläche → Element wird platziert.
3. Element anklicken → Eigenschaften erscheinen im Panel rechts.

## Verbindungen ziehen

1. Verbindungswerkzeug aktivieren.
2. Klick auf den Startpunkt (Pin eines Symbols oder freier Punkt).
3. Klick auf den Endpunkt – die Verbindung wird automatisch geroutet.
4. Kreuzungen mit Leitungen aus **anderen Netzen** werden automatisch
   als Lücke dargestellt.
)",
                    "schaltplan seite projekt zeichenfläche verbindung"
                },
                {
                    "Symbole platzieren und bearbeiten",
                    R"(# Symbole platzieren und bearbeiten

## Symbol aus der Bibliothek platzieren

1. Im **Schaltplan-Werkzeugbereich** das Symbol-Werkzeug wählen.
2. Aus der Symbol-Palette das gewünschte Symbol anklicken.
3. Auf die Zeichenfläche klicken → Symbol wird platziert.
4. Im **Eigenschaftenpanel** kannst du Betriebsmittelkennzeichen (BMK),
   Beschriftung und weitere Eigenschaften setzen.

## Symbol drehen

- Platziertes Symbol anklicken → im Eigenschaftenpanel die **Rotation** ändern
  (0°, 90°, 180°, 270°).

## Eigene Symbole erstellen

1. Seitenleiste → **Symbole** (🔧).
2. **Neues Symbol** anlegen, Namen und Größe festlegen.
3. Mit den Zeichenwerkzeugen (Linien, Kreise, Bögen, Text) das Symbol zeichnen.
4. **Pins** definieren: Position und Bezeichnung für jeden Anschlusspunkt.
5. Speichern – das Symbol steht danach im Schaltplan zur Verfügung.
)",
                    "symbol platzieren bibliothek pin rotation BMK"
                },
                {
                    "Kabelrechner",
                    R"(# Kabelrechner

Der Kabelrechner berechnet den **Mindestquerschnitt** einer Leitung nach VDE.

## Eingaben

| Feld | Bedeutung |
|------|-----------|
| Strom (A) | Betriebsstrom der Leitung |
| Länge (m) | einfache Leitungslänge |
| Spannung (V) | Nennspannung (typisch 230 V oder 400 V) |
| cos φ | Leistungsfaktor (1,0 für ohmsche Last) |
| Verlegeart | Freie Luft, Rohr, Wand usw. |
| Häufung | Anzahl gebündelter Leitungen |

## Ergebnis

Der Rechner gibt den **empfohlenen Querschnitt** in mm² aus und zeigt
den berechneten Spannungsfall.

> **Hinweis:** Das Ergebnis ersetzt keine normgerechte Planung nach
> DIN VDE 0100. Bei sicherheitsrelevanten Anlagen immer einen
> Fachplaner hinzuziehen.
)",
                    "kabel querschnitt VDE berechnung strom"
                },
                {
                    "IBN – Inbetriebnahme",
                    R"(# IBN – Inbetriebnahme

Der IBN-Modus dient zur **strukturierten Prüfung und Dokumentation**
von Schaltanlagen vor der Inbetriebnahme.

## Ablauf

1. Seitenleiste → **IBN** (✅).
2. Die platzierten **Betriebsmittel** aus dem Schaltplan werden automatisch
   als Prüfpositionen aufgelistet.
3. Für jedes Betriebsmittel können **Messwerte** (Spannung, Strom,
   Widerstand usw.) eingetragen werden.
4. Felder mit **Soll-Werten** zeigen farblich an, ob der Messwert
   im zulässigen Bereich liegt.

## Feldvorlagen

Über **Feldvorlagen** lässt sich definieren, welche Messwerte für
welchen Betriebsmitteltyp erfasst werden. So hat z. B. ein Motor
andere Prüffelder als eine Leuchte.

## Prüfprotokoll

Das ausgefüllte IBN-Protokoll kann als Liste exportiert werden
(Listen-Ansicht → IBN-Tab).
)",
                    "inbetriebnahme prüfung messwert protokoll IBN"
                },
                {
                    "Versionierung mit Git",
                    R"(# Versionierung mit Git

Strömling-Projekte sind eigenständige **SQLite-Dateien** (`.strl`).
Da alle Daten in einer einzigen Datei stecken, funktioniert Git als
Versionsverwaltung ohne jede Konfiguration in der App.

## Einrichten (einmalig)

```bash
# Projektordner anlegen und als Git-Repo initialisieren
mkdir ~/Projekte/Schaltschrank-A
cd ~/Projekte/Schaltschrank-A
git init

# .gitignore anlegen (optional, aber empfohlen)
echo "*.db-wal" >  .gitignore
echo "*.db-shm" >> .gitignore
git add .gitignore
git commit -m "Repo initialisiert"
```

Danach das Projekt in diesem Ordner anlegen oder die `.strl`-Datei
dorthin kopieren (📂 → **Projekt öffnen**).

## Täglicher Workflow

```bash
# Nach einer Arbeitssitzung
git add schaltschrank_a.strl
git commit -m "Hauptstromkreis: Schütze K1–K3 verdrahtet"

# Verlauf anzeigen
git log --oneline

# Auf Stand vor 3 Commits zurückgehen (nur lesen, nicht überschreiben)
git show HEAD~3:schaltschrank_a.strl > alt.strl
```

## Was Git kann und was nicht

| ✅ Funktioniert | ❌ Funktioniert nicht |
|---|---|
| Vollständige Versionshistorie | Lesbares `git diff` (Binärdatei) |
| Wiederherstellung beliebiger Stände | Zeilenweises Mergen zweier Versionen |
| Branching (z. B. Varianten A/B) | Automatische Konfliktauflösung |
| Backup auf GitHub/Gitea/lokalem Server | |

## Tipps

- **Sinnvolle Commit-Nachrichten** helfen später: lieber
  *„Steuerstromkreis Schütz K2 korrigiert"* als *„Update"*.
- **Vor größeren Umstrukturierungen** einen Commit machen – so kann
  man jederzeit zum Ausgangszustand zurück.
- **Projekt exportieren** (⬆-Button in der Projektliste) erzeugt eine
  kompakte, saubere Kopie – ideal für Archivierung oder Weitergabe.
- Mehrere Varianten eines Projekts: einfach **Branches** nutzen:
  ```bash
  git checkout -b variante-drehstrom
  # ... Änderungen ...
  git checkout main   # zurück zur Hauptvariante
  ```
)",
                    "git versionierung backup revision history"
                },
                {
                    "Lizenz & Open Source",
                    R"(# Lizenz & Open Source

Strömling Design ist **freie Software** – der Quellcode ist öffentlich
einsehbar und das Programm darf frei genutzt, geteilt und verbessert werden.

## Lizenz: GNU GPL v3

Das Programm steht unter der **GNU General Public License Version 3** (GPL-3.0-or-later).

Das bedeutet in Kurzform:

- Du darfst das Programm **kostenlos nutzen** – privat, in Bildungseinrichtungen,
  in Vereinen, in Forschung und Lehre.
- Du darfst das Programm **weitergeben** und **verändern** –
  unter denselben Lizenzbedingungen.
- Der **Quellcode** muss immer zugänglich bleiben.
- **Zukünftige Versionen** von Strömling Design werden ebenfalls Open Source bleiben.

Den vollständigen Lizenztext findest du unter:
https://www.gnu.org/licenses/gpl-3.0.txt

## Spenden

Strömling Design wird in der Freizeit entwickelt.
Wenn dir das Programm nützt und du die Weiterentwicklung unterstützen möchtest,
freue ich mich über eine freiwillige Spende.

## Mitmachen

Fehler gefunden? Verbesserungsidee? Eigene Symbole oder Inhalte beigesteuert?
Beiträge sind herzlich willkommen – schau auf die Projektseite.

## Was ist Open Source – und was nicht?

Der **Quellcode** von Strömling Design steht unter GPL-3.0 und ist öffentlich einsehbar.

Die **Konzeptdateien** (Designentscheidungen, Roadmap, Debugging-Notizen im
Verzeichnis `konzept/`) sind persönliche Arbeitsunterlagen des Projektinhabers
und werden **nicht** veröffentlicht. Das sind seine kleinen Schätze.

## Keine Garantie

Das Programm wird so bereitgestellt, wie es ist, **ohne Garantie** –
so wie es die GPL vorschreibt. Für den produktiven Einsatz in
sicherheitsrelevanten Anlagen liegt die Verantwortung beim Anwender.
)",
                    "lizenz open source GPL frei kostenlos spende"
                },
                {
                    "Über dieses Projekt",
                    R"(# Über dieses Projekt

## Projektinhaber

**Stephan Theelke**

## Entstehung

Strömling Design wurde am **08.04.2026** gestartet.

Im Berufsalltag arbeite ich täglich mit **EPLAN P8 Electric** — einem
professionellen E-CAD-Tool, das keine Linux-Version hat und für den
Privatgebrauch nicht in Frage kommt. Privat nutze ich ausschließlich
Linux (openSUSE mit KDE), und ich wollte ein Tool, das unter Linux läuft
und meinen persönlichen Anforderungen entspricht. **QElectroTech** kannte
ich, aber auch das entsprach nicht meinen Vorstellungen — also habe ich
angefangen, selbst etwas zu bauen.

## Der Name

Den Begriff **„Strömlinge"** kenne ich noch aus meiner Lehrzeit, irgendwo
um die Jahrtausendwende herum. In der Elektrowelt kennt jeder das Bild:
der kleine Strom, der durch die Leitung fließt. Jetzt konnte ich den
Begriff endlich mal in einem eigenen Projekt verwenden.

## KI-Unterstützung

Dieses Projekt wurde offen und transparent mit Unterstützung von
KI-Werkzeugen entwickelt:

| Werkzeug | Aufgabe |
|---|---|
| **Claude Code** (Anthropic) | Code, Architektur, Konzepte |
| **ChatGPT / DALL-E** (OpenAI) | Strömlinge-Charakterbilder |

Die Projektidee stammt vom Projektinhaber — Konzepte und Quellcode
wurden gemeinsam mit KI erarbeitet.

## Warum Open Source?

Ich wollte testen, wie weit ich mit KI-Unterstützung ein Programm nach
meinen eigenen Vorstellungen bauen kann. Open Source deshalb, damit
andere das Projekt leicht aufgreifen, forken oder weiterführen können —
ohne auf mich angewiesen zu sein.

Ob es für E-Techniker fachlich taugt, wird sich im Test mit Kollegen zeigen.

## Was ist öffentlich – was bleibt privat?

Der **Quellcode** ist Open Source (GPL-3.0).
Die **Konzeptdateien** – Designentscheidungen, Roadmap, Debugging-Notizen –
sind persönliche Arbeitsunterlagen und werden nicht veröffentlicht.
)",
                    "entstehung projekt KI claude chatgpt open source geschichte"
                }
            }
        },
        {
            "Altbestand – West",
            "Installationen nach westdeutscher Norm (VDE), Übergangsperioden, Klassische Nullung",
            10,
            false,
            {
                { "Klassische Nullung – Grundlagen", "", "klassische nullung VDE altbestand" },
                { "Klassische Nullung – Verbotsdaten nach VDE", "", "klassische nullung verbot datum" },
                { "Kuriositäten: 3-adrig verdrahtet, aber KN angeklemmt", "", "klassische nullung kuriosum" }
            }
        },
        {
            "Altbestand – Ost",
            "Installationen nach DDR-Norm TGL, Besonderheiten, Aluminium-Leitungen",
            20,
            false,
            {
                { "Aluminium-Leitungen nach DDR-Norm TGL", "", "aluminium TGL DDR altbestand" },
                { "DDR-Farbnormen und TGL-Querschnitte", "", "farbnorm TGL DDR querschnitt" }
            }
        },
        {
            "Aderendhülsen",
            "Typen, Farbtabellen, Crimp-Technik, häufige Fehler",
            30,
            false,
            {
                { "Querschnitt–Farb–Größentabelle", "", "aderendhülse querschnitt farbe tabelle" }
            }
        },
        {
            "Kuriositäten",
            "Ungewöhnliche Fundsachen aus der Praxis",
            40,
            false,
            {}
        },
        {
            "Strömlinge",
            "Das Maskottchen-System von Strömling Design – ein Charakter pro Leitertyp",
            50,
            true,
            {
                {
                    "Strömlinge – Überblick",
                    R"(# Die Strömlinge

Die Strömlinge sind das lebendige Maskottchen-System von Strömling Design.
Jeder Strömling repräsentiert einen **elektrischen Leitertyp**, ein **Signal**
oder einen **Systemzustand** – erkennbar an Farbe, Körpermerkmalen und Persönlichkeit.

## Grundformen

### Form A – Runder Fisch (Standard-Strömling)
- Runder, leicht plumper Fischkörper
- **Glühbirnen als Ohren** (leuchtend, charakterspezifisch eingefärbt)
- **Fluoreszierende Leiterbahnen** auf dem Körper (PCB-Stil)
- Schielende oder eigenartige Augen – jeder hat seinen eigenen Blick

### Form B – Aalförmig (Leitungs-Strömling)
- Langer, schlanker, gewundener Körper (Sinuswelle)
- **Stecker-/Buchsenenden** an Kopf und Schwanz
- **Aderstreifen** in Normfarben längs am Körper

## Familien

| Familie | Charaktere | Norm |
|---|---|---|
| Netzleiter | Brauno (L1), Schwärzchen (L2), Grausel (L3), Blaubertha (N), Erdikus (PE) | IEC 60446 |
| Leitung & Kabelbrücke | Linus (Kabelbrücke) + Farbvarianten | DIN VDE 0293 |
| Signale & Bus | Impulsino (Signal), Datinchen (Bus) | – |
| Schutz & Isolierung | Isolus (Dunkleosteus-Panzerfish) | IEC Klasse II |
| Fehlerzustände | Krizzo (Kurzschluss), Errinka (Fehler), Fusia (Überlast), Stoppius (Not-Aus) | – |
)",
                    "strömling maskottchen übersicht charakter"
                },
                {
                    "Schwärzchen – Systemfisch L2",
                    R"(# Schwärzchen – Systemfisch // Phase 2

Schwärzchen ist der **coole** unter den drei Außenleitern.
Er repräsentiert den **Außenleiter L2** (schwarz) nach IEC 60446 / DIN VDE 0293.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Schwarz |
| **Körperfarbe** | Tiefes Anthrazit / Schwarz mit leichtem Blauschimmer |
| **Leiterbahnen** | Neongrün, scharf kontraststark |
| **Glühbirnen** | Kaltweißes LED-Licht, minimal |
| **Augen** | Leicht schmale Augen, cooler Blick |

## Persönlichkeit

Ruhig, cool, etwas mysteriös. *Läuft einfach.*
Macht keine großen Worte. Sein Blick sagt: er hat das schon tausendmal gemacht.

## Norm-Referenz

- **Farbe:** Schwarz (L2) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Außenleiter in Drehstromnetzen (400 V / 50 Hz)
- **Körper-Hex:** `#1A1A2E` · **Leiterbahnen-Hex:** `#39FF14`
)",
                    "schwärzchen L2 außenleiter netzleiter IEC schwarz"
                },
                {
                    "Impulsino – Signal",
                    R"(# Impulsino – der hyperaktive Signalströmling

Impulsino repräsentiert das **digitale Steuersignal** – er *ist* der Impuls.
Orange wie die DIN-Signalfarbe, nie still.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Farbe** | Signal-Orange |
| **Leiterbahnen** | Rechteckwellen-Puls-Trace (nur rechte Winkel) |
| **Glühbirnen** | Blinkt rhythmisch – eine an, eine aus |
| **Augen** | Aufmerksam, wach, leicht zappelig |

## Persönlichkeit

Quirlig, immer in Bewegung, hyperaktiv. Liebt hohe Frequenzen.
*„ON! OFF! ON! OFF! Das ist mein Leben!"*

## Im Programm

Impulsino begleitet den **Fun-Modus** als Bonus-Charakter –
er bounced als hyperaktiver Botschafter über den Canvas, pulsiert periodisch.

- **Körper-Hex:** `#FF6B00` · **Leiterbahnen-Hex:** `#FF9E40`
)",
                    "impulsino signal impuls digital orange funmodus"
                },
                {
                    "Isolus – Schutz & Isolierung",
                    R"(# Isolus – der Uralte Wächter

> *„Seit dem Devon bewacht er die Grenze. Sein Knochenkiefer hat noch jeden
> Lichtbogen weggeknappt."*

Isolus ist der **Wächter der Isolierung**. Inspiriert vom **Dunkleosteus** –
dem gepanzerten Urhai des Devon-Zeitalters. Er steht zwischen den
spannungsführenden Leitern und allem, was sie nicht berühren soll.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Grundform** | Dunkleosteus: breiter Panzerkopf, massiver Körper |
| **Körperfarbe** | Tiefschwarz mit mattgelbem Sicherheitsstreifen |
| **Panzer** | Überlappende Knochenplatten mit **☐☐**-Symbol (IEC Klasse II) |
| **Ohren** | Keine Glühbirnen – Isolator-Porzellanglocken |
| **Augen** | Tief versenkt, schmal, uralt blickend |

## Zustände

| Zustand | Aussehen | Bedeutung |
|---|---|---|
| **Intakt** | Glatte Platten, Kiefer geschlossen | Isolation in Ordnung |
| **Beansprucht** | Feine Risse, schmalere Augen | Isolationswiderstand sinkt |
| **Beschädigt** | Platten gesprungen, Kiefer halb offen | Isolationsfehler – Eingriff nötig |
| **Gefallen** | Am Boden, Platten aufgebrochen | Isolationsversagen |

## Beziehungen

- **Feind:** Krizzo (Kurzschluss) – versucht die Panzerplatten zu durchbrechen
- **Verbündeter:** Erdikus (PE) – steht still hinter Isolus, sagt nichts, ist einfach da
- **Verbündeter:** Stoppius (Not-Aus) – gemeinsam die letzte Verteidigungslinie

## Im Programm

Isolus erscheint in der **Wiki-Artikelliste** als Wächter, wenn noch keine Artikel angelegt sind.
)",
                    "isolus isolation schutz dunkleosteus panzer IEC klasse II"
                },
                {
                    "Brauno – Außenleiter L1",
                    R"(# Brauno – Außenleiter L1

Brauno repräsentiert den **Außenleiter L1** (braun) nach IEC 60446 / DIN VDE 0293.
Er ist der Erste unter den Netzleitern – solide, zuverlässig, trägt die Last.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Braun |
| **Körperfarbe** | Warmes Schokoladenbraun `#7B3F1E` |
| **Leiterbahnen** | Kupferfarbig-golden `#D4A520`, Sinuswelle |
| **Glühbirnen** | Bernstein-orange, warm leuchtend |
| **Augen** | Selbstbewusst geradeaus – der Erste, der Anführer |

## Persönlichkeit

Solide, etwas ernst. *Trägt die Last – kein Drama, einfach da.*
Brust raus, leicht stolz. Hat den Anführer-Anspruch verinnerlicht.

## Norm-Referenz

- **Farbe:** Braun (L1) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Erster Außenleiter in Drehstromnetzen (400 V / 50 Hz)
)",
                    "brauno L1 außenleiter netzleiter IEC braun"
                },
                {
                    "Blaubertha – Neutralleiter N",
                    R"(# Blaubertha – Neutralleiter N

Blaubertha repräsentiert den **Neutralleiter N** (blau) nach IEC 60446.
Sie hofft inständig, nie wirklich gebraucht zu werden – und ist
dennoch absolut zuverlässig, wenn es darauf ankommt.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Blau |
| **Körperfarbe** | IEC-Blau `#0057A8` |
| **Leiterbahnen** | Dunkelblau `#003580`, geschlossene Schleifen (Rückstromweg) |
| **Glühbirnen** | Blasses Blau, kaum leuchtend – im Fehlerfall: leuchtet rot |
| **Augen** | Weit geöffnet, leicht ängstlich – immer bereit |

## Persönlichkeit

Ruhig, ausgeglichen. *Der Rückgeber.* Mag Ordnung. Etwas ängstlich –
hofft, nie wirklich belastet zu werden, doch wenn doch, dann perfekt.

## Norm-Referenz

- **Farbe:** Blau (N) nach IEC 60446 und DIN VDE 0293
- **Besonderheit:** Im Normalbetrieb kein Strom → Glühbirnen fast dunkel
)",
                    "blaubertha N neutralleiter netzleiter IEC blau rückleiter"
                },
                {
                    "Grausel – Außenleiter L3",
                    R"(# Grausel – Außenleiter L3

Grausel repräsentiert den **Außenleiter L3** (grau) nach IEC 60446.
Pragmatisch, unauffällig – macht einfach ihren Job, ohne Aufhebens.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Grau |
| **Körperfarbe** | Metallisches Neutralgrau `#6B6B6B` |
| **Leiterbahnen** | Hellblau-silbern `#A8D8EA`, diagonal-ungeordnet |
| **Glühbirnen** | Silbrig-weiß, diskret leuchtend |
| **Augen** | Leicht müde – den Dritten-Platz kennt man, akzeptiert ihn |

## Persönlichkeit

Die Erfahrene. *Hat alles schon gesehen.* Entspannte Pose, leicht hängend –
macht ihren Job ruhig und fehlerfrei, ohne je die Aufmerksamkeit zu suchen.

## Norm-Referenz

- **Farbe:** Grau (L3) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Dritter Außenleiter in Drehstromnetzen (400 V / 50 Hz)
)",
                    "grausel L3 außenleiter netzleiter IEC grau"
                },
                {
                    "Erdikus – Schutzleiter PE",
                    R"(# Erdikus – Schutzleiter PE

Erdikus repräsentiert den **Schutzleiter PE** (grün-gelb) nach IEC 60446.
Der ewige Bodyguard. Stoisch, wortlos, geht nirgendwo hin.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Grün-Gelb (zweifarbig, alternierend) |
| **Körperfarbe** | Diagonale Streifen: Grün `#4CAF50` / Gelb `#FFD700` |
| **Leiterbahnen** | Grün `#2E7D32` mit gelben Via-Punkten |
| **Glühbirnen** | Eine grün, eine gelb – zweifarbig |
| **Augen** | Entspannt, geerdet, schläfrig – der Ruhepol |
| **Besonderheit** | Erdungssymbol ⏚ als Tattoo auf dem Bauch |

## Persönlichkeit

*Stoisch. Absolut zuverlässig. Spricht wenig.* Breit aufgestellt, solide,
geht nirgendwo hin. Der Stille, der alles auffängt, wenn es wirklich drauf ankommt.

## Norm-Referenz

- **Farbe:** Grün-Gelb (PE) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Schutzleiter – fängt Fehlerströme auf, schützt vor Berührungsspannung
- **Verbündeter:** Isolus – beide schützen das System, ohne viele Worte
)",
                    "erdikus PE schutzleiter netzleiter IEC grün gelb erde"
                },
                {
                    "Datinchen – Kommunikation",
                    R"(# Datinchen – Kommunikation & Bus

Datinchen repräsentiert das **Kommunikationssignal** – Bus, Feldbus,
Differenzsignal (RS-485, CAN, Ethernet). Sie weiß mehr als alle anderen
und hält alles zusammen.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Farbe** | Tiefviolett `#7B2FBE` |
| **Leiterbahnen** | Doppelte Traces `#C084FC` – Differenzpaar-Symbol |
| **Ohren** | Keine Glühbirnen – stattdessen zwei kleine Antennen |
| **Augen** | Klug, leicht verschmitzt – weiß mehr als alle anderen |

## Persönlichkeit

Kommunikativ, redselig, verbindet alle.
*„Ich sage immer das erste und das letzte Wort."*
Der soziale Knotenpunkt – ohne Datinchen weiß die linke Hand nicht,
was die rechte tut.

## Norm-Referenz

- Differenzpaar-Signalübertragung (RS-485, CAN, Profibus, EtherCAT)
- Zwei parallele Traces = differenzielles Signal
- **Antennen** statt Glühbirnen: drahtlose Variante möglich
)",
                    "datinchen kommunikation bus signal CAN RS485 lila violett"
                },
                {
                    "Pokeström",
                    R"(# Pokeström – das Maskottchen

Pokeström ist der erste Strömling – die Urform des Charakter-Systems.
Er ist nicht an einen bestimmten Leitertyp gebunden, sondern steht für
**Strömling Design** als Ganzes.

## Erkennungsmerkmale

- Runder, pausbackiger Fischkörper
- **Zwei leuchtende Glühbirnen** als Ohren (gelb, warm)
- **Fluoreszierende Leiterbahnen** – PCB-Stil
- **Schielende Augen** – der typische Pokeström-Blick

## Im Programm

- **Startbildschirm:** Pokeström schwimmt von links nach rechts, wenn kein Projekt offen ist
- **Bauteilbibliothek:** erscheint als Platzhalter, wenn noch keine Bauteile angelegt sind

## Ursprung

Die erste Skizze entstand auf einem Whiteboard: ein Fisch, der ein ET-Symbol
(Kondensator) in der Flosse hält – und der Gedanke war: *„Was wäre, wenn jedes
elektrische Bauteil seinen eigenen Fisch-Charakter hätte?"*
)",
                    "pokeström maskottchen startbildschirm fisch charakter"
                }
            }
        },
        {
            "Tester",
            "Testanleitungen und Rückmeldungen von Programmtestern",
            60,
            false,
            {
                {
                    "Testanleitung – Strömling Design",
                    R"(# Testanleitung – Strömling Design

Danke fürs Testen! Diese Seite beschreibt, welche Bereiche geprüft werden sollen
und wie du deine Beobachtungen festhalten kannst.

**Ziel:** Fehler finden, Unklarheiten melden, Verbesserungsvorschläge einbringen.
Du kannst diese Seite direkt bearbeiten – deine Einträge bleiben beim nächsten
Programmstart erhalten.

---

## 1. Projekt anlegen und öffnen

- [ ] Neues Projekt anlegen (Startbildschirm → „Neu")
- [ ] Projekt benennen und speichern
- [ ] Projekt schließen und wieder öffnen
- [ ] Projekt exportieren (Menü → Exportieren)

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 2. Schaltplan-Canvas

- [ ] Neue Seite anlegen
- [ ] Symbol aus der Symbolpalette auf den Canvas ziehen
- [ ] Symbol verschieben, löschen (Entf-Taste)
- [ ] Zoom mit Mausrad, Pan mit mittlerer Maustaste oder Leertaste + Ziehen
- [ ] Verbindungslinie zwischen zwei Symbolen ziehen
- [ ] Kabelbrücke anlegen
- [ ] Beschriftung / BMK im Eigenschaftenpanel eingeben
- [ ] Rückgängig / Wiederholen (Strg+Z / Strg+Y)
- [ ] Mehrfachauswahl mit Strg+Klick oder Gummiband-Selektion

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 3. Eigenschaftenpanel (rechts)

- [ ] Bauteil anklicken → Eigenschaften erscheinen rechts
- [ ] Betriebsmittelkennzeichen (BMK) eingeben
- [ ] Farbe ändern (falls verfügbar)
- [ ] Mehrfachauswahl → Mehfachauswahl-Sektion erscheint
- [ ] Kabelverbindung auswählen → Leitungseigenschaften erscheinen

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 4. Symboleditor

- [ ] Symboleditor öffnen (Sidebar)
- [ ] Bestehendes Symbol auswählen und bearbeiten
- [ ] Neues Symbol anlegen
- [ ] Pin hinzufügen, beschriften
- [ ] Symbol speichern, im Canvas verwenden

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 5. Bauteilbibliothek

- [ ] Bauteilbibliothek öffnen
- [ ] Neues Bauteil anlegen
- [ ] Kabeldefinition für ein Bauteil anlegen
- [ ] Bauteil im Schaltplan platzieren

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 6. Klemmen und Klemmenreihen

- [ ] Klemmenreihe anlegen
- [ ] Klemme hinzufügen
- [ ] Klemme auf Schaltplanseite platzieren
- [ ] Klemmenplan in den Listen prüfen

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 7. Inbetriebnahme (IBN)

- [ ] IBN-Ansicht öffnen
- [ ] Betriebsmittel prüfen (Haken setzen)
- [ ] Messwert erfassen
- [ ] Prüfprotokoll exportieren (PDF)

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 8. Kabelrechner

- [ ] Kabelrechner öffnen
- [ ] Werte eingeben (Spannung, Strom, Länge)
- [ ] Querschnitt berechnen lassen
- [ ] Ergebnis prüfen (plausibel?)

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 9. Listen (Stückliste, Kabelliste, Querverweise)

- [ ] Stückliste öffnen und prüfen
- [ ] Kabelliste prüfen
- [ ] Aderliste prüfen
- [ ] Klemmenplan prüfen
- [ ] CSV-Export testen

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 10. Wiki

- [ ] Wiki öffnen
- [ ] Artikel lesen
- [ ] Neuen Artikel anlegen
- [ ] Bild hochladen
- [ ] Volltextsuche verwenden
- [ ] Artikel exportieren / importieren

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 11. Einstellungen

- [ ] Einstellungen öffnen
- [ ] Theme wechseln (Hell / Dunkel / System)
- [ ] Sprache prüfen
- [ ] Strömlinge-Sektion anschauen 😊

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 12. Fun-Modus

- [ ] Fun-Modus aktivieren (Tastenkombination, falls bekannt)
- [ ] Verschiedene Szenarien abwarten
- [ ] Impulsino beobachten
- [ ] Fun-Modus deaktivieren

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## Allgemeine Beobachtungen

### Was funktioniert besonders gut?
*(hier eintragen)*

### Was ist verwirrend oder unklar?
*(hier eintragen)*

### Wünsche / Ideen für Verbesserungen?
*(hier eintragen)*

### Systeminfo
- Betriebssystem: *(z.B. Ubuntu 24.04 / Windows 11 / macOS 14)*
- Qt-Version: *(falls bekannt)*
- Datum des Tests: *(TT.MM.JJJJ)*
- Tester: *(Name oder Pseudonym)*
)",
                    "tester testanleitung feedback checkliste"
                }
            }
        }
    };

    QSqlQuery qKat(m_wikiDb), qKatId(m_wikiDb), qArtIns(m_wikiDb), qArtUpd(m_wikiDb);
    qKat.prepare(R"(
        INSERT OR IGNORE INTO wiki_kategorie (name, beschreibung, sortierung)
        VALUES (:name, :beschr, :sort)
    )");
    // Artikel neu anlegen, falls noch nicht vorhanden
    qArtIns.prepare(R"(
        INSERT OR IGNORE INTO wiki_artikel (kategorie_id, titel, inhalt, tags, ist_system)
        SELECT :kid, :titel, :inhalt, :tags, :sys
        WHERE NOT EXISTS (
            SELECT 1 FROM wiki_artikel WHERE kategorie_id = :kid2 AND titel = :titel2
        )
    )");
    // System-Artikel: Inhalt bei jeder Migration aktualisieren
    qArtUpd.prepare(R"(
        UPDATE wiki_artikel SET inhalt = :inhalt, tags = :tags
        WHERE kategorie_id = :kid AND titel = :titel AND ist_system = 1
    )");

    for (const Kategorie &kat : kategorien) {
        qKat.bindValue(":name",  kat.name);
        qKat.bindValue(":beschr", kat.beschreibung);
        qKat.bindValue(":sort",  kat.sortierung);
        if (!qKat.exec()) {
            qWarning() << "seedWikiStarterInhalte Kategorie:" << qKat.lastError().text();
            return false;
        }

        qKatId.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        qKatId.bindValue(":n", kat.name);
        qKatId.exec();
        if (!qKatId.next()) continue;
        const int katId = qKatId.value(0).toInt();

        for (const Artikel &art : kat.artikel) {
            qArtIns.bindValue(":kid",    katId);
            qArtIns.bindValue(":kid2",   katId);
            qArtIns.bindValue(":titel",  art.titel);
            qArtIns.bindValue(":titel2", art.titel);
            qArtIns.bindValue(":inhalt", art.inhalt);
            qArtIns.bindValue(":tags",   art.tags);
            qArtIns.bindValue(":sys",    kat.istSystem ? 1 : 0);
            if (!qArtIns.exec()) {
                qWarning() << "seedWikiStarterInhalte Artikel insert:" << qArtIns.lastError().text();
                return false;
            }
            if (kat.istSystem) {
                qArtUpd.bindValue(":kid",    katId);
                qArtUpd.bindValue(":titel",  art.titel);
                qArtUpd.bindValue(":inhalt", art.inhalt);
                qArtUpd.bindValue(":tags",   art.tags);
                if (!qArtUpd.exec()) {
                    qWarning() << "seedWikiStarterInhalte Artikel update:" << qArtUpd.lastError().text();
                    return false;
                }
            }
        }
    }

    // ── Strömlinge: Bilder aus QRC-Ressourcen einmalig einsamen ──────────
    auto seedBild = [&](const QString &artikelTitel, const QString &qrcPfad,
                        const QString &dateiname) {
        QSqlQuery qId(m_wikiDb);
        qId.prepare("SELECT id FROM wiki_artikel WHERE titel = :t");
        qId.bindValue(":t", artikelTitel);
        if (!qId.exec() || !qId.next()) return;
        const int artId = qId.value(0).toInt();

        QSqlQuery qCount(m_wikiDb);
        qCount.prepare("SELECT COUNT(*) FROM wiki_bild WHERE artikel_id = :aid");
        qCount.bindValue(":aid", artId);
        if (!qCount.exec() || !qCount.next() || qCount.value(0).toInt() > 0) return;

        QFile f(qrcPfad);
        if (!f.open(QIODevice::ReadOnly)) {
            qWarning() << "seedBild: Datei nicht gefunden:" << qrcPfad;
            return;
        }
        const QByteArray daten = f.readAll();
        f.close();
        if (daten.isEmpty()) return;

        QSqlQuery qIns(m_wikiDb);
        qIns.prepare(R"(
            INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, sortierung)
            VALUES (:aid, :fn, 'image/png', :d, 1)
        )");
        qIns.bindValue(":aid", artId);
        qIns.bindValue(":fn",  dateiname);
        qIns.bindValue(":d",   daten);
        if (!qIns.exec())
            qWarning() << "seedBild INSERT:" << qIns.lastError().text();
    };

    seedBild("Schwärzchen – Systemfisch L2",  ":/assets/schwaerzchen_sheet.png",    "schwaerzchen_sheet.png");
    seedBild("Impulsino – Signal",             ":/assets/impulsino_uebersicht.png", "impulsino_uebersicht.png");
    seedBild("Isolus – Schutz & Isolierung",   ":/assets/isolus.png",               "isolus.png");
    seedBild("Pokeström",                       ":/assets/pokestroem_cee.png",       "pokestroem_cee.png");
    seedBild("Brauno – Außenleiter L1",         ":/assets/brauno_uebersicht.png",    "brauno_uebersicht.png");
    seedBild("Blaubertha – Neutralleiter N",    ":/assets/blaubertha_uebersicht.png","blaubertha_uebersicht.png");
    seedBild("Grausel – Außenleiter L3",        ":/assets/grausel_uebersicht.png",   "grausel_uebersicht.png");
    seedBild("Erdikus – Schutzleiter PE",       ":/assets/erdikus_uebersicht.png",   "erdikus_uebersicht.png");
    seedBild("Datinchen – Kommunikation",       ":/assets/datinchen_uebersicht.png", "datinchen_uebersicht.png");

    return true;
}

// ============================================================
// SPS/PLS-Integration
// ============================================================

// --- Rack ---

