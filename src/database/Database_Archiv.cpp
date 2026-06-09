#include "Database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <QStringConverter>

// ── Verzeichnis rekursiv kopieren (interner Helfer) ──────────────────────────
static void kopierVerzeichnis(const QString &von, const QString &nach)
{
    QDir().mkpath(nach);
    QDirIterator it(von, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        QString rel = QDir(von).relativeFilePath(it.filePath());
        QString dst = nach + "/" + rel;
        QDir().mkpath(QFileInfo(dst).absolutePath());
        QFile::remove(dst);
        QFile::copy(it.filePath(), dst);
    }
}

// ── Komplettarchiv-Export (BACKUP-01 Ebene 2) ───────────────────────────────
// Struktur im Zielordner:
//   manifest.json       — Metadaten + Projektliste
//   wiki_export.json    — Wiki-Sicherung (JSON, für menschenlesbaren Merge)
//   makros.db           — Makro-Bibliothek (VACUUM INTO)
//   wiki.db             — Wiki-Datenbank (VACUUM INTO)
//   wiki_blobs/         — Wiki-Anhänge (rekursive Kopie)
//   projekte/           — Kopien aller bekannten .strl-Projektdateien
// ────────────────────────────────────────────────────────────────────────────
QVariantMap Database::komplettarchivExportieren(const QString &zielOrdner)
{
    QString ziel = QUrl(zielOrdner).isLocalFile() ? QUrl(zielOrdner).toLocalFile() : zielOrdner;
    if (!QDir().mkpath(ziel))
        return {{"erfolg", false}, {"meldung", QStringLiteral("Zielordner konnte nicht erstellt werden")}};

    // 1a. Wiki als JSON exportieren (menschenlesbarer Fallback)
    QString wikiJsonPfad = ziel + QStringLiteral("/wiki_export.json");
    bool wikiJsonOk = wikiExportJson(wikiJsonPfad);

    // 1b. makros.db per VACUUM INTO sichern
    bool makroDbOk = false;
    if (m_makroDb.isOpen()) {
        QString zielPfad = ziel + QStringLiteral("/makros.db");
        QString esc = zielPfad; esc.replace("'", "''");
        QSqlQuery q(m_makroDb);
        makroDbOk = q.exec(QString("VACUUM INTO '%1'").arg(esc));
        if (!makroDbOk)
            qCWarning(lcDb) << "komplettarchivExportieren makros.db:" << q.lastError().text();
    }

    // 1c. wiki.db per VACUUM INTO sichern
    bool wikiDbOk = false;
    if (m_wikiDb.isOpen()) {
        QString zielPfad = ziel + QStringLiteral("/wiki.db");
        QString esc = zielPfad; esc.replace("'", "''");
        QSqlQuery q(m_wikiDb);
        wikiDbOk = q.exec(QString("VACUUM INTO '%1'").arg(esc));
        if (!wikiDbOk)
            qCWarning(lcDb) << "komplettarchivExportieren wiki.db:" << q.lastError().text();
    }

    // 1d. wiki_blobs/ rekursiv kopieren
    if (m_launcherDb.isOpen()) {
        QString blobsSrc = QFileInfo(m_launcherDb.databaseName()).absolutePath() + "/wiki_blobs";
        if (QDir(blobsSrc).exists())
            kopierVerzeichnis(blobsSrc, ziel + "/wiki_blobs");
    }

    // 2. Bekannte Projektdateien kopieren
    QString projOrdner = ziel + QStringLiteral("/projekte");
    if (!QDir().mkpath(projOrdner))
        return {{"erfolg", false}, {"meldung", QStringLiteral("Projektordner konnte nicht erstellt werden")}};

    int projekteAnzahl = 0;
    QJsonArray projekteListe;

    QSqlQuery q(m_launcherDb);
    if (q.exec("SELECT pfad, name FROM zuletzt_geoeffnet ORDER BY geoeffnet_am DESC")) {
        while (q.next()) {
            QString pfad = q.value(0).toString();
            QString name = q.value(1).toString();
            if (!QFile::exists(pfad)) continue;

            QString dateiName = QFileInfo(pfad).fileName();
            QString zielPfad  = projOrdner + "/" + dateiName;
            if (QFile::exists(zielPfad)) {
                QString stem = QFileInfo(dateiName).baseName();
                dateiName = stem + "_" + QString::number(projekteAnzahl + 1) + ".strl";
                zielPfad  = projOrdner + "/" + dateiName;
            }
            if (QFile::copy(pfad, zielPfad)) {
                projekteAnzahl++;
                projekteListe.append(QJsonObject{
                    {QStringLiteral("name"),         name},
                    {QStringLiteral("datei"),        dateiName},
                    {QStringLiteral("originalPfad"), pfad}
                });
            } else {
                qCWarning(lcDb) << "komplettarchivExportieren: Projektkopie fehlgeschlagen:" << pfad;
            }
        }
    }

    // 3. manifest.json schreiben (Version 2)
    QJsonObject manifest{
        {QStringLiteral("stroemling_backup_version"), 2},
        {QStringLiteral("exportiert_am"),   QDateTime::currentDateTime().toString(Qt::ISODate)},
        {QStringLiteral("makros_db"),        makroDbOk},
        {QStringLiteral("wiki_db"),          wikiDbOk},
        {QStringLiteral("wiki_json"),        wikiJsonOk},
        {QStringLiteral("projekte"),         projekteListe}
    };
    QFile mf(ziel + QStringLiteral("/manifest.json"));
    if (mf.open(QIODevice::WriteOnly | QIODevice::Text))
        mf.write(QJsonDocument(manifest).toJson(QJsonDocument::Indented));

    QString meldung = QString("%1 Projekt(e)").arg(projekteAnzahl);
    if (makroDbOk) meldung += ", Makros";
    if (wikiDbOk)  meldung += ", Wiki";
    meldung += QStringLiteral(" gesichert");

    qCInfo(lcDb) << "komplettarchivExportieren:" << projekteAnzahl << "Projekt(e),"
            << "makros=" << makroDbOk << "wiki=" << wikiDbOk << "→" << ziel;
    return {
        {QStringLiteral("erfolg"),         true},
        {QStringLiteral("projekteAnzahl"), projekteAnzahl},
        {QStringLiteral("makroDbOk"),      makroDbOk},
        {QStringLiteral("wikiDbOk"),       wikiDbOk},
        {QStringLiteral("meldung"),        meldung}
    };
}

// ── Komplettarchiv-Import (BACKUP-01 Ebene 2) ───────────────────────────────
// 1. makros.db + wiki.db + wiki_blobs/ → _pendingrestore/ (angewendet beim nächsten Start)
// 2. Wiki-JSON merge (sofort, für schnellen Zugriff ohne Neustart)
// 3. .strl-Projektdateien → dataDir/importierte_projekte/ + in zuletzt_geoeffnet eintragen
// ────────────────────────────────────────────────────────────────────────────
QVariantMap Database::komplettarchivImportieren(const QString &quellOrdner)
{
    QString quelle = QUrl(quellOrdner).isLocalFile() ? QUrl(quellOrdner).toLocalFile() : quellOrdner;

    // manifest.json lesen
    QFile mf(quelle + QStringLiteral("/manifest.json"));
    if (!mf.open(QIODevice::ReadOnly))
        return {{"erfolg", false}, {"meldung", QStringLiteral("manifest.json nicht gefunden – kein gültiges Archiv")}};

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(mf.readAll(), &err);
    if (doc.isNull() || !doc.isObject())
        return {{"erfolg", false}, {"meldung", QStringLiteral("Ungültiges Archiv: ") + err.errorString()}};

    QJsonObject root = doc.object();
    int backupVer = root.value(QStringLiteral("stroemling_backup_version")).toInt();
    if (backupVer != 2)
        return {{"erfolg", false}, {"meldung", QStringLiteral("Unbekannte Archiv-Version (erwartet v2)")}};

    if (!m_launcherDb.isOpen())
        return {{"erfolg", false}, {"meldung", QStringLiteral("Launcher-DB nicht geöffnet")}};

    QString dataDir    = QFileInfo(m_launcherDb.databaseName()).absolutePath();
    QString pendingDir = dataDir + QStringLiteral("/_pendingrestore");
    QDir().mkpath(pendingDir);

    // 1. DB-Dateien für Neustart-Wiederherstellung vorbereiten
    bool makroDbGeplant = false, wikiDbGeplant = false;
    for (const auto &[dateiname, geplant] :
         std::initializer_list<std::pair<QString, bool*>>{
             {"makros.db", &makroDbGeplant},
             {"wiki.db",   &wikiDbGeplant}}) {
        QString src = quelle + "/" + dateiname;
        if (QFile::exists(src)) {
            QString dst = pendingDir + "/" + dateiname;
            QFile::remove(dst);
            *geplant = QFile::copy(src, dst);
        }
    }

    // wiki_blobs/ kopieren (in _pendingrestore, wird beim Start verschoben)
    QString blobsSrc = quelle + "/wiki_blobs";
    if (QDir(blobsSrc).exists())
        kopierVerzeichnis(blobsSrc, pendingDir + "/wiki_blobs");

    // 2. Wiki-JSON sofort mergen (Artikel bleiben ohne Neustart zugänglich)
    bool wikiJsonOk = false;
    QString wikiJsonPfad = quelle + QStringLiteral("/wiki_export.json");
    if (QFile::exists(wikiJsonPfad))
        wikiJsonOk = wikiImportJson(wikiJsonPfad, true);

    // 3. Projektdateien nach dataDir/importierte_projekte/ kopieren
    int projekteAnzahl = 0;
    QJsonArray projekteListe = root.value(QStringLiteral("projekte")).toArray();
    QString projSrcOrdner   = quelle + QStringLiteral("/projekte");
    QString projZielOrdner  = dataDir + QStringLiteral("/importierte_projekte");
    QDir().mkpath(projZielOrdner);

    for (const QJsonValue &v : projekteListe) {
        QJsonObject pj    = v.toObject();
        QString dateiName = pj.value(QStringLiteral("datei")).toString();
        QString name      = pj.value(QStringLiteral("name")).toString();
        QString srcPfad   = projSrcOrdner + "/" + dateiName;

        if (!QFile::exists(srcPfad)) {
            qCWarning(lcDb) << "komplettarchivImportieren: Projektdatei fehlt:" << srcPfad;
            continue;
        }

        // Zieldatei bestimmen, Konflikt auflösen
        QString zielPfad = projZielOrdner + "/" + dateiName;
        if (QFile::exists(zielPfad)) {
            QString stem = QFileInfo(dateiName).baseName();
            zielPfad = projZielOrdner + "/" + stem
                       + "_importiert_" + QString::number(projekteAnzahl + 1) + ".strl";
        }
        if (!QFile::copy(srcPfad, zielPfad)) continue;

        QSqlQuery q(m_launcherDb);
        q.prepare(R"(
            INSERT INTO zuletzt_geoeffnet (pfad, name, geoeffnet_am)
            VALUES (:p, :n, datetime('now'))
            ON CONFLICT(pfad) DO UPDATE SET name=excluded.name, geoeffnet_am=excluded.geoeffnet_am
        )");
        q.bindValue(":p", zielPfad);
        q.bindValue(":n", name);
        if (q.exec()) projekteAnzahl++;
    }

    QString meldung = QString("%1 Projekt(e) importiert").arg(projekteAnzahl);
    if (makroDbGeplant || wikiDbGeplant)
        meldung += QStringLiteral(" · Makros/Wiki werden beim nächsten Start wiederhergestellt");

    qCInfo(lcDb) << "komplettarchivImportieren:" << projekteAnzahl << "Projekt(e)"
            << "makroPending=" << makroDbGeplant << "wikiPending=" << wikiDbGeplant;
    return {
        {QStringLiteral("erfolg"),          true},
        {QStringLiteral("projekteAnzahl"),  projekteAnzahl},
        {QStringLiteral("makroDbGeplant"),  makroDbGeplant},
        {QStringLiteral("wikiDbGeplant"),   wikiDbGeplant},
        {QStringLiteral("wikiJsonOk"),      wikiJsonOk},
        {QStringLiteral("neustartNoetig"),  makroDbGeplant || wikiDbGeplant},
        {QStringLiteral("meldung"),         meldung}
    };
}

// ============================================================
// CSV-Import Bauteilkatalog (M7)
// ============================================================

static QList<QStringList> parseCsvRows(const QString &pfad, QChar &trenn)
{
    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    f.close();

    QStringList lines = content.split('\n');
    if (lines.isEmpty()) return {};

    // Trennzeichen aus erster Zeile ermitteln
    QString first = lines.first();
    trenn = (first.count(';') >= first.count(',')) ? ';' : ',';

    QList<QStringList> result;
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;

        QStringList row;
        bool inQuotes = false;
        QString field;
        for (int i = 0; i < line.length(); i++) {
            QChar c = line[i];
            if (c == '"') {
                if (inQuotes && i + 1 < line.length() && line[i + 1] == '"') {
                    field += '"'; ++i;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c == trenn && !inQuotes) {
                row.append(field.trimmed());
                field.clear();
            } else {
                field += c;
            }
        }
        row.append(field.trimmed());
        result.append(row);
    }
    return result;
}

QStringList Database::csvKopfzeile(const QString &pfad)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    return rows.isEmpty() ? QStringList() : rows.first();
}

QVariantList Database::csvVorschau(const QString &pfad, int maxZeilen)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    QVariantList result;
    for (int i = 1; i < rows.size() && result.size() < maxZeilen; i++) {
        QVariantList row;
        for (const QString &s : rows[i]) row.append(s);
        result.append(QVariant(row));
    }
    return result;
}

int Database::csvBauteileImportieren(const QString &pfad, int kategorieId,
                                      const QVariantMap &mapping)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    if (rows.size() < 2) return 0;

    static const QStringList numericFelder = {
        "preis_eur", "spannung_v", "strom_a", "leistung_w"
    };
    static const QStringList erlaubteFelder = {
        "bezeichnung", "hersteller", "artikelnummer", "artikelnummer_2",
        "lieferant", "bestellnummer", "preis_eur", "spannung_v",
        "strom_a", "leistung_w", "schutzart", "norm", "bmk_vorlage", "bemerkung"
    };

    QStringList dbFelder;
    QStringList bindVars;
    QList<int>  colIndizes;
    for (auto it = mapping.begin(); it != mapping.end(); ++it) {
        const QString &feld = it.key();
        int colIdx = it.value().toInt();
        if (colIdx < 0 || !erlaubteFelder.contains(feld)) continue;
        dbFelder   << feld;
        bindVars   << (":" + feld);
        colIndizes << colIdx;
    }
    if (!dbFelder.contains("bezeichnung")) return -1;

    QString sql = QString("INSERT INTO bauteil (kategorie_id, %1) VALUES (:katId, %2)")
                      .arg(dbFelder.join(", "), bindVars.join(", "));

    if (!m_db.transaction()) {
        qCWarning(lcDb) << "csvBauteileImportieren: transaction fehlgeschlagen";
        return 0;
    }
    QSqlQuery q(m_db);
    int count = 0;
    for (int row = 1; row < rows.size(); row++) {
        const QStringList &cols = rows[row];
        q.prepare(sql);
        q.bindValue(":katId", kategorieId > 0 ? QVariant(kategorieId) : QVariant());
        for (int f = 0; f < dbFelder.size(); f++) {
            int     ci  = colIndizes[f];
            QString val = (ci < cols.size()) ? cols[ci] : QString();
            if (numericFelder.contains(dbFelder[f])) {
                bool ok;
                double d = QString(val).replace(',', '.').toDouble(&ok);
                q.bindValue(":" + dbFelder[f], (ok && !val.isEmpty()) ? QVariant(d) : QVariant());
            } else {
                q.bindValue(":" + dbFelder[f], val.isEmpty() ? QVariant() : QVariant(val));
            }
        }
        if (q.exec()) ++count;
        else qCWarning(lcDb) << "csvBauteileImportieren Zeile" << row << ":" << q.lastError().text();
    }
    m_db.commit();
    return count;
}
