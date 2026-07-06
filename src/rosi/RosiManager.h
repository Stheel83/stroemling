#pragma once
#include <QObject>
#include <QTimer>
#include <QString>
#include <QStringList>
#include <QDate>

// Maskottchen-Assistentin "Rosi Röhrenaal" (Klippy-Hommage), siehe
// konzept/features/48_rosi_roehrenaal.md. Zählt aktive Nutzungsminuten
// (eigener 60s-Timer, kein Idle-Tracking wie der Fun-Modus) und entscheidet
// rein zufallsgesteuert wann sie auftaucht. Persistenz in der Tabelle
// rosi_zustand der Launcher-DB ("stroemling_launcher"), analog
// AchievementManager/achievement_zaehler. Globaler Ein/Aus-Schalter liegt
// bewusst in QSettings (Kategorie "rosi", Schlüssel "aktiviert"), nicht in
// der DB — Einstellungs-Charakter statt Beziehungs-Zähler.
class RosiManager : public QObject
{
    Q_OBJECT

public:
    explicit RosiManager(QObject *parent = nullptr);

    // Aus der Sprechblase aufgerufen: sperrt Erscheinen bis morgen 00:00.
    Q_INVOKABLE void nervNicht();

    // Aus den Einstellungen aufgerufen ("Jetzt testen"): löst eine kurze
    // Vorwarnung + Auftritt aus, ohne den normalen Rhythmus (Zähler in
    // rosi_zustand) zu beeinflussen — analog zum Fun-Modus-Testknopf.
    Q_INVOKABLE void jetztTesten();

signals:
    void auftauchen(const QString &text);
    void postkarteAngekommen(const QString &text);
    // Feuert einmalig 2-7 (echte/simulierte) Minuten vor dem Auftritt, damit
    // die Rohröffnung in QML langsam einfaden kann. sekunden = verbleibende
    // Zeit bis zum Auftritt, für die Dauer der Einfaden-Animation.
    void vorwarnung(int sekunden);
    // ROSI-11/ROSI-13: Urlaub bzw. Krankheitstag — Rohröffnung bleibt auf
    // Grundopazität, statt zu verschwinden, und zeigt den übergebenen Text
    // permanent an (kein Auftritt, kein Klick-Ziel). Nur eines von beiden
    // kann aktiv sein (Krankheit wird nur gewürfelt, wenn kein Urlaub läuft).
    void abwesenheitAnzeigen(const QString &text);
    void abwesenheitVerstecken();

private:
    void _tick();
    void _pruefeUrlaubStart();
    bool _urlaubsblockFuerHeute(const QDate &heute, QDate &von, QDate &bisInklusive);
    void _pruefeKrankheit();
    void _pruefeAbwesenheit();
    void _pruefePostkarte();
    void _pruefeAuftritt(int nutzungsminuten);
    QString _spruchWaehlen(int erschienenAnzahl);
    int _vorwarnMinutenSicherstellen();

    qint64 _zaehlerGet(const QString &schluessel) const;
    void   _zaehlerSet(const QString &schluessel, qint64 wert);
    int    _zaehlerInc(const QString &schluessel, int um);

    static QString _zufall(const QStringList &pool);
    static qint64  _heuteAlsZahl();

    static QStringList _poolErstkontakt();
    static QStringList _poolA_Begruessung();
    static QStringList _poolB_Kommentar();
    static QStringList _poolC_Tipp();
    static QStringList _poolD_UrlaubRueckkehr();
    static QStringList _poolD2_Urlaubsgeschichten();
    static QStringList _poolE_Besuch();
    static QStringList _poolF_PauseTrinken();
    static QStringList _poolG_Auswanderung();
    static QStringList _poolH_Postkarte();
    static QStringList _poolI_Jugendwoerter();
    static QStringList _poolJ_Krankheiten();
    static QStringList _reiseziele();
    static QStringList _poolD3_Reisesprache(int zielId);

    QTimer  m_timer;
    bool    m_vorwarnungAktiv = false;
    QString m_letzteAbwesenheitAnzeige;
};
