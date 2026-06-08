#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTranslator>
#include <QLocale>
#include <QSettings>
#include <QProcess>
#include <QObject>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QMutex>
#include <QMutexLocker>
#include <QtGlobal>
#include <QStandardPaths>
#include <QDir>
#include <cstdio>

#include "database/Database.h"
#include "models/ProjektModel.h"
#include "models/SeitenModel.h"
#include "models/BauteilModel.h"
#include "models/KlemmeModel.h"
#include "models/KlemmenreihenModel.h"
#include "models/KabelModel.h"
#include "models/SymbolDefinitionModel.h"
#include "models/KabelRechnerModel.h"
#include "canvas/ElementeModel.h"
#include "achievements/AchievementManager.h"

// ── Log-Handler ───────────────────────────────────────────────
static QFile    s_logFile;
static QMutex   s_logMutex;

static void logMessageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg)
{
    const char *label;
    switch (type) {
        case QtDebugMsg:    label = "DBG"; break;
        case QtInfoMsg:     label = "INF"; break;
        case QtWarningMsg:  label = "WRN"; break;
        case QtCriticalMsg: label = "CRT"; break;
        case QtFatalMsg:    label = "FAT"; break;
        default:            label = "???"; break;
    }

    QString line = QDateTime::currentDateTime().toString("hh:mm:ss.zzz")
                   + " [" + label + "] " + msg + '\n';

    {
        QMutexLocker lock(&s_logMutex);
        if (s_logFile.isOpen()) {
            s_logFile.write(line.toUtf8());
            s_logFile.flush();
        }
    }
    // Stderr erhalten damit journalctl weiterhin funktioniert
    fputs(qPrintable(line), stderr);

    if (type == QtFatalMsg)
        abort();
    (void)ctx;
}

class AppHelper : public QObject {
    Q_OBJECT
public:
    explicit AppHelper(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void restart() {
        QProcess::startDetached(QCoreApplication::applicationFilePath(),
                                QCoreApplication::arguments());
        QCoreApplication::quit();
    }

    Q_INVOKABLE void neueInstanzMitProjekt(const QString &pfad) {
        QProcess::startDetached(QCoreApplication::applicationFilePath(), {pfad});
    }
};

#include "main.moc"

// Einmalige Datenmigration: stroemling/Strömling Design → Strömling Design
// Notwendig weil setOrganizationName("stroemling") entfernt wurde.
// Nur auf Linux relevant – der alte Pfad existiert auf Windows nicht.
#ifdef Q_OS_LINUX
static void datenVerzeichnisMigrieren()
{
    QString home    = QDir::homePath();
    QString altPfad = home + "/.local/share/stroemling/Strömling Design";
    QString neuPfad = home + "/.local/share/Strömling Design";

    if (!QDir(altPfad).exists()) return;

    // Nur migrieren wenn die neue Launcher-DB leer / noch nicht vorhanden ist
    QString neuDb = neuPfad + "/stroemling.db";
    if (QFile::exists(neuDb) && QFileInfo(neuDb).size() > 0) return;

    qInfo() << "Einmalige Datenmigration:" << altPfad << "->" << neuPfad;
    QDir().mkpath(neuPfad);

    // Datenbank-Dateien inkl. WAL
    for (const QString &name : {
             "stroemling.db", "stroemling.db-shm", "stroemling.db-wal",
             "wiki.db",       "wiki.db-shm",       "wiki.db-wal",
             "makros.db",     "makros.db-shm",     "makros.db-wal"}) {
        QString src = altPfad + "/" + name;
        if (!QFile::exists(src)) continue;
        QFile::remove(neuPfad + "/" + name);
        if (QFile::copy(src, neuPfad + "/" + name))
            qInfo() << "  kopiert:" << name;
        else
            qWarning() << "  Fehler beim Kopieren:" << name;
    }

    // Wiki-Blobs
    QDir blobSrc(altPfad + "/wiki_blobs");
    if (blobSrc.exists()) {
        QString blobDest = neuPfad + "/wiki_blobs";
        QDir().mkpath(blobDest);
        for (const QString &f : blobSrc.entryList(QDir::Files)) {
            QFile::remove(blobDest + "/" + f);
            QFile::copy(blobSrc.absoluteFilePath(f), blobDest + "/" + f);
        }
        qInfo() << "  wiki_blobs kopiert:" << blobSrc.entryList(QDir::Files).size() << "Dateien";
    }

    // Backups
    QDir backupSrc(altPfad + "/backups");
    if (backupSrc.exists()) {
        QString backupDest = neuPfad + "/backups";
        QDir().mkpath(backupDest);
        for (const QString &f : backupSrc.entryList(QDir::Files)) {
            QFile::remove(backupDest + "/" + f);
            QFile::copy(backupSrc.absoluteFilePath(f), backupDest + "/" + f);
        }
        qInfo() << "  backups kopiert:" << backupSrc.entryList(QDir::Files).size() << "Dateien";
    }

    qInfo() << "Migration abgeschlossen. Altes Verzeichnis kann manuell geloescht werden:" << altPfad;

    // QSettings-Config migrieren: ~/.config/stroemling/ → ~/.config/
    QString altConf = QDir::homePath() + "/.config/stroemling/Strömling Design.conf";
    QString neuConf = QDir::homePath() + "/.config/Strömling Design.conf";
    if (QFile::exists(altConf) && !QFile::exists(neuConf)) {
        if (QFile::copy(altConf, neuConf))
            qInfo() << "  QSettings migriert:" << neuConf;
        else
            qWarning() << "  QSettings-Migration fehlgeschlagen";
    }
}
#endif // Q_OS_LINUX

int main(int argc, char *argv[])
{
    // Log-Datei öffnen bevor QGuiApplication läuft (Qt-eigene Frühwarnungen landen sonst nicht rein)
    // Pfad: neben dem Binary (im Build-Ordner, gleiche Stelle wie die DB).
    QString exePath = QString::fromLocal8Bit(argv[0]);
    int lastSep = qMax(exePath.lastIndexOf(QLatin1Char('/')), exePath.lastIndexOf(QLatin1Char('\\')));
    QString logPath = (lastSep >= 0 ? exePath.left(lastSep + 1) : QString()) + QLatin1String("stroemling.log");
    s_logFile.setFileName(logPath);
    if (!s_logFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        fputs("stroemling: Log-Datei konnte nicht geöffnet werden\n", stderr);
    qInstallMessageHandler(logMessageHandler);

    qInfo() << "=== Strömling gestartet" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << "===";

#ifdef Q_OS_WIN
    // Auf Windows: single-threaded Render-Loop damit QSqlQuery in Canvas.onPaint
    // die Datenbankverbindung des Haupt-Threads nutzen kann.
    // Fusion-Style explizit setzen, da der native Windows-Style nicht vollständig deployed wird.
    qputenv("QSG_RENDER_LOOP", "basic");
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
#endif

#ifdef Q_OS_LINUX
    // Einmalige Migration: war früher unter ~/.local/share/stroemling/Strömling Design/
    // Jetzt: ~/.local/share/Strömling Design/ (kein OrganizationName mehr)
    datenVerzeichnisMigrieren();
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName("Strömling Design");

    // Gespeicherte Sprache laden (gesetzt vom QML-Sprachpicker)
    QSettings settings;
    QString savedLanguage = settings.value("i18n/language", "system").toString();

    QTranslator translator;
    if (savedLanguage != "system" && savedLanguage != "de") {
        translator.load(":/i18n/stroemling_" + savedLanguage);
        app.installTranslator(&translator);
    } else if (savedLanguage == "system") {
        for (const QString &locale : QLocale::system().uiLanguages()) {
            if (translator.load(":/i18n/stroemling_" + QLocale(locale).name())) {
                app.installTranslator(&translator);
                break;
            }
        }
    }
    // savedLanguage == "de": kein Translator nötig, Quellsprache ist Deutsch

    // App-Datenverzeichnis: Linux: ~/.local/share/Strömling Design/
    //                       Windows: %LOCALAPPDATA%\Strömling Design\
    // Log-Datei bleibt neben dem Binary (Debug-Output, kein Nutzerdaten-Ordner).
    QString dataDir      = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dataDir);
    QString launcherPath = dataDir + "/stroemling.db";  // Launcher-DB (nur zuletzt_geoeffnet)
    QString wikiPath     = dataDir + "/wiki.db";
    QString makroPath    = dataDir + "/makros.db";       // Makro-Bibliothek (projektübergreifend)

    // Datenbankverbindungen aufbauen
    Database db;
    if (!db.openLauncher(launcherPath)) {
        qCritical() << "Launcher-DB konnte nicht geöffnet werden:" << db.lastError();
        return 1;
    }
    if (!db.openWiki(wikiPath)) {
        qCritical() << "Wiki-Datenbank konnte nicht geöffnet werden:" << db.lastError();
        return 1;
    }
    if (!db.openMakro(makroPath)) {
        qCritical() << "Makro-DB konnte nicht geöffnet werden:" << db.lastError();
        return 1;
    }

    // BACKUP-01 Ebene 1: einmal täglich makros.db + wiki.db sichern
    db.datenbankAutobackup();

    // Startprojekt: per Kommandozeilenargument (neue Instanz) oder zuletzt geöffnet
    {
        QString startPfad;
        const QStringList args = app.arguments();
        if (args.size() > 1 && QFile::exists(args.at(1)))
            startPfad = args.at(1);
        else {
            QVariantList recent = db.zuletzGeoeffnete();
            if (!recent.isEmpty())
                startPfad = recent.first().toMap().value("pfad").toString();
        }
        if (!startPfad.isEmpty())
            db.openProjekt(startPfad);
    }

    // Models anlegen
    ProjektModel           projektModel;
    SeitenModel            seitenModel;
    BauteilKategorieModel  kategorieModel;
    BauteilListModel       bauteilModel;
    FarbDefinitionModel     farbModel;
    KlemmeModel             klemmeModel;
    KlemmenleistenModel     klemmenleistenModel;
    KlemmenreiheModel           klemmenreiheModel;
    KabelModel                  kabelModel;
    SymbolDefinitionModel       symbolDefinitionModel;
    KabelRechnerModel           kabelRechnerModel;
    AppHelper                   appHelper;
    AchievementManager          achievementManager;
    ElementeModel               elementeModel1;
    ElementeModel               elementeModel2;
    ElementeModel               elementeModel3;   // IBN-Canvas
    ElementeModel               elementeModel4;   // Fehlersuch-Canvas

    // QML Engine starten
    QQmlApplicationEngine engine;

    // Models als Kontext-Properties registrieren
    engine.rootContext()->setContextProperty("projektModel",   &projektModel);
    engine.rootContext()->setContextProperty("seitenModel",    &seitenModel);
    engine.rootContext()->setContextProperty("kategorieModel", &kategorieModel);
    engine.rootContext()->setContextProperty("bauteilModel",   &bauteilModel);
    engine.rootContext()->setContextProperty("farbModel",      &farbModel);
    engine.rootContext()->setContextProperty("klemmeModel",           &klemmeModel);
    engine.rootContext()->setContextProperty("klemmenleistenModel",   &klemmenleistenModel);
    engine.rootContext()->setContextProperty("klemmenreiheModel",     &klemmenreiheModel);
    engine.rootContext()->setContextProperty("kabelModel",            &kabelModel);
    engine.rootContext()->setContextProperty("db",                    &db);
    engine.rootContext()->setContextProperty("symbolDefinitionModel", &symbolDefinitionModel);
    engine.rootContext()->setContextProperty("kabelRechnerModel",    &kabelRechnerModel);
    engine.rootContext()->setContextProperty("appHelper",            &appHelper);
    engine.rootContext()->setContextProperty("achievementManager",   &achievementManager);
    engine.rootContext()->setContextProperty("elementeModel1",       &elementeModel1);
    engine.rootContext()->setContextProperty("elementeModel2",       &elementeModel2);
    engine.rootContext()->setContextProperty("elementeModel3",       &elementeModel3);
    engine.rootContext()->setContextProperty("elementeModel4",       &elementeModel4);
    engine.rootContext()->setContextProperty("buildDatum",           QString(BUILD_DATE));
    engine.rootContext()->setContextProperty("appVersion",            QString(APP_VERSION));

    // Hauptfenster laden
    engine.loadFromModule("stroemling", "Main");

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "QML konnte nicht geladen werden.";
        return 1;
    }

    return app.exec();
}
