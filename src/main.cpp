#include "logging.h"
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
#include <QIcon>
#include <QClipboard>
#include <QMimeData>
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
#include "MeldungManager.h"
#include "rosi/RosiManager.h"
#include "utils/AktivitaetsMonitor.h"

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

    // COPY-CROSS-01: System-Zwischenablage für Cross-Projekt Copy/Paste.
    // Eigener MIME-Typ statt Klartext, damit einfuegen() zuverlässig
    // erkennt, ob überhaupt Strömling-Elemente auf der Zwischenablage
    // liegen (und nicht z.B. Text aus einer anderen App).
    static constexpr auto kZwischenablageMime = "application/x-stroemling-elemente";

    Q_INVOKABLE void systemZwischenablageSchreiben(const QString &json) {
        auto *mime = new QMimeData();
        mime->setData(QString::fromLatin1(kZwischenablageMime), json.toUtf8());
        QGuiApplication::clipboard()->setMimeData(mime);
    }

    Q_INVOKABLE QString systemZwischenablageLesen() {
        const QMimeData *mime = QGuiApplication::clipboard()->mimeData();
        if (!mime || !mime->hasFormat(QString::fromLatin1(kZwischenablageMime)))
            return QString();
        return QString::fromUtf8(mime->data(QString::fromLatin1(kZwischenablageMime)));
    }
};

#include "main.moc"

// Hilfsfunktion: Dateien + Unterordner von altPfad nach neuPfad kopieren
#ifdef Q_OS_LINUX
static void _kopiereAppDaten(const QString &altPfad, const QString &neuPfad)
{
    QDir().mkpath(neuPfad);
    for (const QString &name : {
             "stroemling.db", "stroemling.db-shm", "stroemling.db-wal",
             "wiki.db",       "wiki.db-shm",       "wiki.db-wal",
             "makros.db",     "makros.db-shm",     "makros.db-wal"}) {
        QString src = altPfad + "/" + name;
        if (!QFile::exists(src)) continue;
        QFile::remove(neuPfad + "/" + name);
        if (QFile::copy(src, neuPfad + "/" + name))
            qCInfo(lcApp) << "  kopiert:" << name;
        else
            qCWarning(lcApp) << "  Fehler beim Kopieren:" << name;
    }
    for (const QString &sub : { "wiki_blobs", "backups" }) {
        QDir srcDir(altPfad + "/" + sub);
        if (!srcDir.exists()) continue;
        QString dstSub = neuPfad + "/" + sub;
        QDir().mkpath(dstSub);
        for (const QString &f : srcDir.entryList(QDir::Files)) {
            QFile::remove(dstSub + "/" + f);
            QFile::copy(srcDir.absoluteFilePath(f), dstSub + "/" + f);
        }
        qCInfo(lcApp) << " " << sub << "kopiert";
    }
}

// Migration 1: stroemling/Strömling Design → Strömling Design
// (Entfernung des alten OrganizationName-Unterordners)
static void datenVerzeichnisMigrieren()
{
    QString home    = QDir::homePath();
    QString altPfad = home + "/.local/share/stroemling/Strömling Design";
    QString neuPfad = home + "/.local/share/Strömling Design";
    if (!QDir(altPfad).exists()) return;
    QString neuDb = neuPfad + "/stroemling.db";
    if (QFile::exists(neuDb) && QFileInfo(neuDb).size() > 0) return;

    qCInfo(lcApp) << "Datenmigration (1/2):" << altPfad << "->" << neuPfad;
    _kopiereAppDaten(altPfad, neuPfad);

    QString altConf = home + "/.config/stroemling/Strömling Design.conf";
    QString neuConf = home + "/.config/Strömling Design.conf";
    if (QFile::exists(altConf) && !QFile::exists(neuConf))
        QFile::copy(altConf, neuConf);
}

// Migration 2: Strömling Design → Stroemling_Design
// (ö→oe, Leerzeichen→Unterstrich für Dateisystem-Kompatibilität)
static void datenpfadNormalisieren()
{
    QString home    = QDir::homePath();
    QString altPfad = home + "/.local/share/Strömling Design";
    QString neuPfad = home + "/.local/share/Stroemling_Design";
    if (!QDir(altPfad).exists()) return;
    QString neuDb = neuPfad + "/stroemling.db";
    if (QFile::exists(neuDb) && QFileInfo(neuDb).size() > 0) return;

    qCInfo(lcApp) << "Datenmigration (2/2):" << altPfad << "->" << neuPfad;
    _kopiereAppDaten(altPfad, neuPfad);

    QString altConf = home + "/.config/Strömling Design.conf";
    QString neuConf = home + "/.config/Stroemling_Design.conf";
    if (QFile::exists(altConf) && !QFile::exists(neuConf))
        QFile::copy(altConf, neuConf);
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

    qCInfo(lcApp) << "=== Strömling gestartet" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << "===";

#ifdef Q_OS_WIN
    // Auf Windows: single-threaded Render-Loop damit QSqlQuery in Canvas.onPaint
    // die Datenbankverbindung des Haupt-Threads nutzen kann.
    // Fusion-Style explizit setzen, da der native Windows-Style nicht vollständig deployed wird.
    qputenv("QSG_RENDER_LOOP", "basic");
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
#endif

#ifdef Q_OS_LINUX
    datenVerzeichnisMigrieren();   // stroemling/… → Strömling Design
    datenpfadNormalisieren();      // Strömling Design → Stroemling_Design
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName("Stroemling_Design");
    app.setApplicationDisplayName("Strömling Design");
    app.setWindowIcon(QIcon(":/assets/stroemling_icon.png"));

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

    // App-Datenverzeichnis: Linux: ~/.local/share/Stroemling_Design/
    //                       Windows: %LOCALAPPDATA%\Stroemling_Design\
    // Log-Datei bleibt neben dem Binary (Debug-Output, kein Nutzerdaten-Ordner).
    QString dataDir      = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dataDir);
    QString launcherPath    = dataDir + "/stroemling.db";  // Launcher-DB (nur zuletzt_geoeffnet)
    QString wikiPath        = dataDir + "/wiki.db";
    QString makroPath       = dataDir + "/makros.db";       // Makro-Bibliothek (projektübergreifend)
    QString bibliothekPath  = dataDir + "/bibliothek.db";   // Bauteil-Bibliothek (projektübergreifend)

    // Datenbankverbindungen aufbauen
    Database db;
    if (!db.openLauncher(launcherPath)) {
        qCCritical(lcApp) << "Launcher-DB konnte nicht geöffnet werden:" << db.lastError();
        return 1;
    }
    if (!db.openWiki(wikiPath)) {
        qCCritical(lcApp) << "Wiki-Datenbank konnte nicht geöffnet werden:" << db.lastError();
        return 1;
    }
    if (!db.openMakro(makroPath)) {
        qCCritical(lcApp) << "Makro-DB konnte nicht geöffnet werden:" << db.lastError();
        return 1;
    }
    if (!db.openBibliothek(bibliothekPath)) {
        qCCritical(lcApp) << "Bibliothek-DB konnte nicht geöffnet werden:" << db.lastError();
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
    MeldungManager               meldungManager;
    RosiManager                  rosiManager;
    AktivitaetsMonitor           aktivitaetsMonitor;
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
    engine.rootContext()->setContextProperty("meldungManager",       &meldungManager);
    engine.rootContext()->setContextProperty("rosiManager",           &rosiManager);
    engine.rootContext()->setContextProperty("aktivitaetsMonitor",   &aktivitaetsMonitor);
    engine.rootContext()->setContextProperty("elementeModel1",       &elementeModel1);
    engine.rootContext()->setContextProperty("elementeModel2",       &elementeModel2);
    engine.rootContext()->setContextProperty("elementeModel3",       &elementeModel3);
    engine.rootContext()->setContextProperty("elementeModel4",       &elementeModel4);
    engine.rootContext()->setContextProperty("buildDatum",           QString(BUILD_DATE));
    engine.rootContext()->setContextProperty("appVersion",            QString(APP_VERSION));

    // Hauptfenster laden
    engine.loadFromModule("stroemling", "Main");

    if (engine.rootObjects().isEmpty()) {
        qCCritical(lcApp) << "QML konnte nicht geladen werden.";
        return 1;
    }

    return app.exec();
}
