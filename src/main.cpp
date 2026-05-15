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
};

#include "main.moc"

int main(int argc, char *argv[])
{
    // Log-Datei öffnen bevor QGuiApplication läuft (Qt-eigene Frühwarnungen landen sonst nicht rein)
    // Pfad: neben dem Binary (im Build-Ordner, gleiche Stelle wie die DB).
    QString logPath = QString::fromLocal8Bit(argv[0]);
    logPath = logPath.left(logPath.lastIndexOf('/') + 1) + "stroemling.log";
    s_logFile.setFileName(logPath);
    if (!s_logFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        fputs("stroemling: Log-Datei konnte nicht geöffnet werden\n", stderr);
    qInstallMessageHandler(logMessageHandler);

    qInfo() << "=== Strömling gestartet" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << "===";

    QGuiApplication app(argc, argv);
    app.setOrganizationName("stroemling");
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

    // Entwicklungsphase: Datenbankdatei liegt neben dem Binary im Build-Ordner.
    // Vor dem stabilen Release auf AppDataLocation umstellen.
    QString dbPath = QCoreApplication::applicationDirPath() + "/stroemling.db";

    // Datenbankverbindung aufbauen
    Database db;
    if (!db.open(dbPath)) {
        qCritical() << "Datenbank konnte nicht geöffnet werden:" << db.lastError();
        return 1;
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

    // Hauptfenster laden
    engine.loadFromModule("stroemling", "Main");

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "QML konnte nicht geladen werden.";
        return 1;
    }

    return app.exec();
}
