#include "logging.h"
#include "RosiManager.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QSettings>
#include <QDateTime>
#include <QDate>
#include <QRandomGenerator>
#include <algorithm>

namespace {
constexpr int  kErstAuftrittMinuten        = 15;
constexpr int  kWiederkehrMinMin           = 45;
constexpr int  kWiederkehrMinMax           = 90;
constexpr int  kUrlaubsgeschichtenStart    = 3;
constexpr int  kUrlaubsspracheChanceStart  = 70;
constexpr int  kUrlaubsspracheAbnahmeMin   = 15;
constexpr int  kUrlaubsspracheAbnahmeMax   = 20;
constexpr int  kBesuchChanceProzent        = 5;
constexpr double kUrlaubChanceProStart       = 0.015; // 1,5 % außerhalb des Sommers
constexpr double kUrlaubChanceSommerProStart = 0.04;  // 4 % Juni–August
constexpr int  kVorwarnMinutenMin          = 2;
constexpr int  kVorwarnMinutenMax          = 7;
constexpr int  kTestVorwarnSekunden        = 3;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sprüche-Pools (hardcoded, siehe konzept/features/48_rosi_roehrenaal.md §5)
// ─────────────────────────────────────────────────────────────────────────────
QStringList RosiManager::_poolErstkontakt()
{
    return {
        "Hallo! Ick bin Rosi, deine neue Nachbarin aus der Röhre da unten.",
        "Na, erschrocken? Bin Rosi, schwimm hier schon ewig rum.",
    };
}

QStringList RosiManager::_poolA_Begruessung()
{
    return {
        "Hallo!", "Ja, Tach auch!", "Hi!", "Moin!", "Hallöle!",
        "Juten Tach, der Herr, die Dame!", "Na? Wieder am Ackern?",
        "Schön, dass de wieder da bist!", "Lange nicht jesehen, wa?",
    };
}

QStringList RosiManager::_poolB_Kommentar()
{
    return {
        "Janz jenau, so macht man dat.",
        "Immer locker bleiben, is nur'n Schaltplan.",
        "Strom fließt, Kaffee sollte auch.",
        "Bei mir unten is es feucht, aber jemütlich.",
        "Sach mal, biste eigentlich schon lange dabei?",
    };
}

QStringList RosiManager::_poolC_Tipp()
{
    return {
        "Wusstest du? Strg+M öffnet die Minimap.",
        "Tipp: F1 zeigt dir alle Tastenkürzel.",
        "Im DRC-Panel siehst du alle Fehler auf einen Blick.",
        "Rechtsklick auf'n Symbol macht's Eigenschaften-Panel direkt auf.",
    };
}

QStringList RosiManager::_poolD_UrlaubRueckkehr()
{
    return {
        "War weg, Kollegin im Klärwerk besuchen.",
        "Bin wieder da! Drei Wochen Nordsee, jetzt riech ich nach Salzwasser.",
        "Sorry, war off — Röhrenaale brauchen auch mal Urlaub.",
        "Bin wieder da, war jut, aber meine Röhre hier hat mir doch jefehlt.",
    };
}

QStringList RosiManager::_poolD2_Urlaubsgeschichten()
{
    return {
        "Weeste, in Spanien hab ick'n Wels kennenjelernt, der hatte 'n Schnurrbart dicker als meiner.",
        "Sach ick dir, die Wellen da unten, voll der Trubel, hab kaum geschlafen.",
        "War auch kurz bei meiner Tante im Hafenbecken, die erzählt immer noch dieselben Geschichten.",
        "Hab Muscheln jesammelt, lieg jetzt irgendwo in meiner Röhre rum.",
    };
}

QStringList RosiManager::_poolE_Besuch()
{
    return {
        "Hier is meine Cousine Aalfriede zu Besuch, sie grüßt!",
        "Mein Kumpel Stichling schaut grade vorbei, der wollt nur winken.",
    };
}

QStringList RosiManager::_poolF_PauseTrinken()
{
    return {
        "Mach mal ne Pause, sonst kriegste viereckige Augen.",
        "Trink mal'n Schlückchen.",
        "Meine Röhre is schon janz trocken, trink ma' wat.",
        "Gut jeölt is halb jewonnen.",
        "Wann hast du das letzte Mal wat jetrunken, hä?",
    };
}

QStringList RosiManager::_poolG_Auswanderung()
{
    return {
        "Ick überlege ja auszuwandern... aber wat mach ick ohne meine Röhre hier?",
        "Manchmal denk ick, ick zieh nach Spanien — dann krieg ick wieder Schiss vor der Bürokratie da.",
        "Hab schon Koffer jepackt... ne, lass ma, hier is doch janz jemütlich.",
    };
}

QStringList RosiManager::_poolH_Postkarte()
{
    return {
        "Bin jut angekommen! Sonne, Sand, een kühles Bier. Mehr später.",
        "Hier is dufte, Party läuft, Wasser is warm — meld mich wieder.",
        "Alles bestens, mach mir hier 'n schönen Tag, bis bald!",
    };
}

QStringList RosiManager::_poolI_Jugendwoerter()
{
    return {
        "Krass.", "67.", "Digga.", "Cringe.", "Sheesh.", "Aura.", "Slay.",
        "Hammer!", "Endgeil!", "Läuft bei dir.", "Alles klar, Digga.", "Yolo!", "Mega!",
    };
}

QStringList RosiManager::_reiseziele()
{
    return { "Spanien", "Italien", "Mallorca", "Türkei", "Nordsee/Ostsee", "England", "Frankreich" };
}

QStringList RosiManager::_poolD3_Reisesprache(int zielId)
{
    switch (zielId) {
        case 0: return { "¡Hola!", "Gracias.", "¡Qué calor!" };                 // Spanien
        case 1: return { "Ciao!", "Bellissimo.", "Mamma mia." };                // Italien
        case 2: return { "Zicke zacke, Hoi Hoi Hoi!", "Sauf doch eener mit!" }; // Mallorca (Ballermann-Joke statt Spanisch)
        case 3: return { "Merhaba!", "Çok güzel." };                            // Türkei
        case 4: return { "Moin moin!", "Dat is schön hier." };                  // Nordsee/Ostsee (Plattdeutsch-Joke)
        case 5: return { "Cheers!", "Lovely, innit?" };                         // England
        case 6: return { "Oh là là!", "Merci beaucoup." };                      // Frankreich
        default: return {};
    }
}

// ─────────────────────────────────────────────────────────────────────────────
QString RosiManager::_zufall(const QStringList &pool)
{
    if (pool.isEmpty()) return QString();
    return pool.at(QRandomGenerator::global()->bounded(pool.size()));
}

// ─────────────────────────────────────────────────────────────────────────────
RosiManager::RosiManager(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &RosiManager::_tick);
    m_timer.start();

    _vielleichtUrlaubStarten();
}

void RosiManager::_tick()
{
    QSettings settings;
    if (!settings.value(QStringLiteral("rosi/aktiviert"), true).toBool())
        return;

    const int minuten = _zaehlerInc("nutzungsminuten_gesamt", 1);
    _pruefePostkarte();
    _pruefeAuftritt(minuten);
}

// Einmal pro App-Start: kleine Zufallschance auf einen Urlaubsbeginn.
// In den Sommermonaten (Juni–August) höhere Chance + längere Dauer.
void RosiManager::_vielleichtUrlaubStarten()
{
    const qint64 jetzt = QDateTime::currentSecsSinceEpoch();
    if (_zaehlerGet("urlaub_bis") > jetzt) return; // schon im Urlaub

    const int monat = QDate::currentDate().month();
    const bool sommer = (monat >= 6 && monat <= 8);
    const double chance = sommer ? kUrlaubChanceSommerProStart : kUrlaubChanceProStart;

    if (QRandomGenerator::global()->generateDouble() >= chance) return; // kein Urlaub diesmal

    const int tageMin = sommer ? 7  : 2;
    const int tageMax = sommer ? 21 : 7;
    const int tage    = QRandomGenerator::global()->bounded(tageMin, tageMax + 1);

    const qint64 bis            = jetzt + qint64(tage) * 86400;
    const qint64 postkartenZeit = jetzt + (bis - jetzt) / 2;

    _zaehlerSet("urlaub_bis",                  bis);
    _zaehlerSet("urlaub_postkarte_gesendet",   0);
    _zaehlerSet("urlaub_postkarte_zeitpunkt",  postkartenZeit);
    _zaehlerSet("urlaub_ziel_id",              QRandomGenerator::global()->bounded(_reiseziele().size()));
    // Wird beim ersten möglichen Auftritt NACH Ablauf von urlaub_bis konsumiert –
    // bis dahin bleibt das Flag einfach "ausstehend", unabhängig davon wie lange
    // der Urlaub noch dauert.
    _zaehlerSet("urlaub_gerade_zurueck",       1);

    qCInfo(lcApp) << "Rosi: Urlaub gestartet, zurück am"
                  << QDateTime::fromSecsSinceEpoch(bis).toString(Qt::ISODate);
}

// Etwa zur Hälfte der Urlaubsdauer: einmalige Postkarte statt Auftritt.
void RosiManager::_pruefePostkarte()
{
    const qint64 urlaubBis = _zaehlerGet("urlaub_bis");
    if (urlaubBis <= 0) return;
    if (_zaehlerGet("urlaub_postkarte_gesendet") == 1) return;

    const qint64 zeitpunkt = _zaehlerGet("urlaub_postkarte_zeitpunkt");
    if (zeitpunkt <= 0) return;

    if (QDateTime::currentSecsSinceEpoch() < zeitpunkt) return;

    _zaehlerSet("urlaub_postkarte_gesendet", 1);
    emit postkarteAngekommen(_zufall(_poolH_Postkarte()));
}

// Stellt sicher, dass für den aktuellen Wiederkehr-Zyklus ein zufälliger
// Vorwarn-Vorlauf (2-7 Min) feststeht. Wird auf 0 zurückgesetzt, sobald der
// zugehörige Auftritt stattgefunden hat — der nächste Aufruf würfelt dann neu.
int RosiManager::_vorwarnMinutenSicherstellen()
{
    int v = static_cast<int>(_zaehlerGet("vorwarn_minuten"));
    if (v < kVorwarnMinutenMin || v > kVorwarnMinutenMax) {
        v = QRandomGenerator::global()->bounded(kVorwarnMinutenMin, kVorwarnMinutenMax + 1);
        _zaehlerSet("vorwarn_minuten", v);
    }
    return v;
}

void RosiManager::_pruefeAuftritt(int nutzungsminuten)
{
    const qint64 jetzt = QDateTime::currentSecsSinceEpoch();
    const int erschienenAnzahl = static_cast<int>(_zaehlerGet("erschienen_anzahl"));
    const qint64 schwelle = erschienenAnzahl == 0
        ? kErstAuftrittMinuten
        : _zaehlerGet("naechste_erscheinung_ab_minute");

    if (jetzt < _zaehlerGet("naechste_erscheinung_nicht_vor")) return;
    if (jetzt < _zaehlerGet("urlaub_bis")) return;

    // Vorwarnung: Rohröffnung fadet 2-7 Min vor dem Auftritt langsam ein,
    // damit sich der Nutzer auf Rosi einstellen kann (konzept §4/§6).
    const int vorwarnMinuten = _vorwarnMinutenSicherstellen();
    const qint64 vorwarnSchwelle = schwelle - vorwarnMinuten;
    if (!m_vorwarnungAktiv && nutzungsminuten >= vorwarnSchwelle && nutzungsminuten < schwelle) {
        m_vorwarnungAktiv = true;
        emit vorwarnung(static_cast<int>((schwelle - nutzungsminuten) * 60));
    }

    if (nutzungsminuten < schwelle) return;

    const QString text = _spruchWaehlen(erschienenAnzahl);

    const int intervall = QRandomGenerator::global()->bounded(kWiederkehrMinMin, kWiederkehrMinMax + 1);
    _zaehlerSet("naechste_erscheinung_ab_minute", nutzungsminuten + intervall);
    _zaehlerSet("erschienen_anzahl", erschienenAnzahl + 1);
    _zaehlerSet("vorwarn_minuten", 0); // nächster Zyklus würfelt neu (s.o.)
    m_vorwarnungAktiv = false;

    emit auftauchen(text);
}

QString RosiManager::_spruchWaehlen(int erschienenAnzahl)
{
    if (erschienenAnzahl == 0)
        return _zufall(_poolErstkontakt());

    if (_zaehlerGet("urlaub_gerade_zurueck") == 1) {
        _zaehlerSet("urlaub_gerade_zurueck", 0);
        _zaehlerSet("urlaubsgeschichten_uebrig", kUrlaubsgeschichtenStart);
        _zaehlerSet("urlaubssprache_chance", kUrlaubsspracheChanceStart);
        return _zufall(_poolD_UrlaubRueckkehr());
    }

    QString basis;
    const int geschichtenUebrig = static_cast<int>(_zaehlerGet("urlaubsgeschichten_uebrig"));

    if (geschichtenUebrig > 0 && QRandomGenerator::global()->bounded(100) < 50) {
        _zaehlerSet("urlaubsgeschichten_uebrig", geschichtenUebrig - 1);
        basis = _zufall(_poolD2_Urlaubsgeschichten());
    } else if (QRandomGenerator::global()->bounded(100) < kBesuchChanceProzent) {
        basis = _zufall(_poolE_Besuch());
    } else {
        const QList<QStringList> pools = {
            _poolA_Begruessung(), _poolB_Kommentar(), _poolC_Tipp(),
            _poolF_PauseTrinken(), _poolG_Auswanderung(), _poolI_Jugendwoerter(),
        };
        basis = _zufall(pools.at(QRandomGenerator::global()->bounded(pools.size())));
    }

    // Reisesprache-Versuche klingen über mehrere Auftritte ab (siehe §4 im Konzept).
    const int spracheChance = static_cast<int>(_zaehlerGet("urlaubssprache_chance"));
    if (spracheChance > 0) {
        if (QRandomGenerator::global()->bounded(100) < spracheChance) {
            const int zielId = static_cast<int>(_zaehlerGet("urlaub_ziel_id"));
            const QStringList woerter = _poolD3_Reisesprache(zielId);
            if (!woerter.isEmpty())
                basis += "  " + _zufall(woerter);
        }
        const int abnahme = QRandomGenerator::global()->bounded(kUrlaubsspracheAbnahmeMin, kUrlaubsspracheAbnahmeMax + 1);
        _zaehlerSet("urlaubssprache_chance", std::max(0, spracheChance - abnahme));
    }

    return basis;
}

void RosiManager::nervNicht()
{
    const QDateTime morgen(QDate::currentDate().addDays(1), QTime(0, 0));
    _zaehlerSet("naechste_erscheinung_nicht_vor", morgen.toSecsSinceEpoch());
}

// Stateless Testtrigger (analog Fun-Modus "Jetzt testen") — verändert keine
// rosi_zustand-Zähler, zeigt nur eine kurze Vorwarnung + einen Auftritt.
void RosiManager::jetztTesten()
{
    emit vorwarnung(kTestVorwarnSekunden);
    QTimer::singleShot(kTestVorwarnSekunden * 1000, this, [this]() {
        emit auftauchen(_zufall(_poolA_Begruessung()));
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistenz – Tabelle rosi_zustand in der Launcher-DB (analog achievement_zaehler)
// ─────────────────────────────────────────────────────────────────────────────
qint64 RosiManager::_zaehlerGet(const QString &schluessel) const
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return 0;

    QSqlQuery q(db);
    q.prepare("SELECT wert FROM rosi_zustand WHERE schluessel = ?");
    q.addBindValue(schluessel);
    if (q.exec() && q.next())
        return q.value(0).toLongLong();
    return 0;
}

void RosiManager::_zaehlerSet(const QString &schluessel, qint64 wert)
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return;

    QSqlQuery q(db);
    q.prepare("INSERT INTO rosi_zustand (schluessel, wert) VALUES (?, ?) "
              "ON CONFLICT(schluessel) DO UPDATE SET wert = ?");
    q.addBindValue(schluessel);
    q.addBindValue(wert);
    q.addBindValue(wert);
    if (!q.exec())
        qCWarning(lcApp) << "Rosi: Zustand speichern fehlgeschlagen:" << q.lastError().text();
}

int RosiManager::_zaehlerInc(const QString &schluessel, int um)
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return 0;

    QSqlQuery q(db);
    q.prepare("INSERT INTO rosi_zustand (schluessel, wert) VALUES (?, ?) "
              "ON CONFLICT(schluessel) DO UPDATE SET wert = wert + ?");
    q.addBindValue(schluessel);
    q.addBindValue(um);
    q.addBindValue(um);
    q.exec();

    return static_cast<int>(_zaehlerGet(schluessel));
}
