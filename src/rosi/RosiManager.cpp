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
constexpr int  kVorwarnMinutenMin          = 2;
constexpr int  kVorwarnMinutenMax          = 7;
constexpr int  kTestVorwarnSekunden        = 3;
constexpr double kKrankChanceProTag        = 0.03; // 3 % pro Kalendertag, nur außerhalb des Urlaubs (ROSI-13)

// Fester Jahres-Urlaubskalender (ROSI-10, konzept §4): 30 Werktage, verteilt
// auf 3 Wochen Sommer (Fenster-Startdatum jährlich gewürfelt) + 2 Wochen
// Weihnachten (fix) + 1 Woche Herbst (fix) — je volle Kalenderwoche zählen
// pauschal 5 Werktage, unabhängig vom tatsächlichen Wochentag.
constexpr int kSommerDauerTage      = 21; // 3 Wochen
constexpr int kWeihnachtDauerTage   = 14; // 2 Wochen
constexpr int kHerbstDauerTage      = 7;  // 1 Woche
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

QStringList RosiManager::_poolJ_Krankheiten()
{
    return {
        "Schuppenkater", "Flossenzerrung", "Kiemenkratzen", "Schwimmblasenschwindel",
        "Röhrenkoller", "Aalglatt ausgerutscht", "Salzwassermangel",
        "Kaffeesatz in den Kiemen", "Berlinerisch verschluckt",
        "Trübes Wasser im Kopf", "Schluckauf vom Plankton",
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

qint64 RosiManager::_heuteAlsZahl()
{
    const QDate heute = QDate::currentDate();
    return heute.year() * 10000LL + heute.month() * 100 + heute.day();
}

// ─────────────────────────────────────────────────────────────────────────────
RosiManager::RosiManager(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &RosiManager::_tick);
    m_timer.start();

    // Kalenderzustand (Urlaub/Krankheit) läuft unabhängig vom Ein/Aus-Schalter
    // weiter (analog zur bisherigen Urlaubs-Zufallslogik) — nur die sichtbare
    // Anzeige respektiert den Schalter.
    _pruefeUrlaubStart();
    _pruefeKrankheit();

    QSettings settings;
    if (settings.value(QStringLiteral("rosi/aktiviert"), true).toBool())
        _pruefeAbwesenheit();
}

void RosiManager::_tick()
{
    _pruefeUrlaubStart();
    _pruefeKrankheit();

    QSettings settings;
    if (!settings.value(QStringLiteral("rosi/aktiviert"), true).toBool())
        return;

    _pruefeAbwesenheit();

    const int minuten = _zaehlerInc("nutzungsminuten_gesamt", 1);
    _pruefePostkarte();
    _pruefeAuftritt(minuten);
}

// Fester Jahres-Urlaubskalender (ROSI-10): prüft, ob "heute" in einen der drei
// Blöcke fällt, und setzt urlaub_von/urlaub_bis, sobald ein neuer Block
// beginnt. Der Guard "schon im Urlaub" verhindert Mehrfachauslösung während
// eines laufenden Blocks; funktioniert auch, wenn die App erst mitten in
// einem Block gestartet wird (kein verpasster Urlaub durch Programm-Pause).
bool RosiManager::_urlaubsblockFuerHeute(const QDate &heute, QDate &von, QDate &bisInklusive)
{
    const int jahr = heute.year();

    // Weihnachtsurlaub: fix 22.12. – 04.01., blockübergreifend zum Jahreswechsel.
    const QDate weihnachtVonDiesesJahr(jahr, 12, 22);
    if (heute >= weihnachtVonDiesesJahr) {
        von = weihnachtVonDiesesJahr;
        bisInklusive = weihnachtVonDiesesJahr.addDays(kWeihnachtDauerTage - 1);
        return true;
    }
    const QDate weihnachtVonVorjahr(jahr - 1, 12, 22);
    const QDate weihnachtBisDiesesJahr = weihnachtVonVorjahr.addDays(kWeihnachtDauerTage - 1);
    if (heute <= weihnachtBisDiesesJahr) {
        von = weihnachtVonVorjahr;
        bisInklusive = weihnachtBisDiesesJahr;
        return true;
    }

    // Herbsturlaub: fix rund um 3. Oktober, 1 Woche.
    const QDate herbstVon(jahr, 9, 29);
    const QDate herbstBis = herbstVon.addDays(kHerbstDauerTage - 1);
    if (heute >= herbstVon && heute <= herbstBis) {
        von = herbstVon;
        bisInklusive = herbstBis;
        return true;
    }

    // Sommerurlaub: 3 Wochen, Startdatum einmal pro Jahr im Fenster
    // 15.07.–10.08. gewürfelt (spätester Start, damit die 3 Wochen noch vor
    // Ende August enden), danach für den Rest des Jahres unverändert.
    if (_zaehlerGet("urlaub_sommerwoche_jahr") != jahr) {
        const QDate fensterVon(jahr, 7, 15);
        const QDate fensterSpaetesterStart(jahr, 8, 10);
        const int spanTage = fensterVon.daysTo(fensterSpaetesterStart);
        const QDate start = fensterVon.addDays(QRandomGenerator::global()->bounded(spanTage + 1));
        _zaehlerSet("urlaub_sommerwoche_jahr", jahr);
        _zaehlerSet("urlaub_sommerwoche_start", QDateTime(start, QTime(0, 0)).toSecsSinceEpoch());
    }
    const QDate sommerVon = QDateTime::fromSecsSinceEpoch(_zaehlerGet("urlaub_sommerwoche_start")).date();
    const QDate sommerBis = sommerVon.addDays(kSommerDauerTage - 1);
    if (heute >= sommerVon && heute <= sommerBis) {
        von = sommerVon;
        bisInklusive = sommerBis;
        return true;
    }

    return false;
}

void RosiManager::_pruefeUrlaubStart()
{
    const qint64 jetzt = QDateTime::currentSecsSinceEpoch();
    if (_zaehlerGet("urlaub_bis") > jetzt) return; // schon im Urlaub

    QDate von, bisInklusive;
    if (!_urlaubsblockFuerHeute(QDate::currentDate(), von, bisInklusive)) return; // heute kein Urlaubsblock

    const qint64 vonTs = QDateTime(von, QTime(0, 0)).toSecsSinceEpoch();
    const qint64 bisTs = QDateTime(bisInklusive.addDays(1), QTime(0, 0)).toSecsSinceEpoch(); // exklusiv

    _zaehlerSet("urlaub_von", vonTs);
    _zaehlerSet("urlaub_bis", bisTs);
    _zaehlerSet("urlaub_postkarten_gesendet_anzahl", 0);
    _zaehlerSet("urlaub_ziel_id", QRandomGenerator::global()->bounded(_reiseziele().size()));
    // Wird beim ersten möglichen Auftritt NACH Ablauf von urlaub_bis konsumiert –
    // bis dahin bleibt das Flag einfach "ausstehend", unabhängig davon wie lange
    // der Urlaub noch dauert.
    _zaehlerSet("urlaub_gerade_zurueck", 1);

    qCInfo(lcApp) << "Rosi: Urlaub gestartet (" << von.toString(Qt::ISODate) << "bis"
                  << bisInklusive.toString(Qt::ISODate) << "), zurück am"
                  << QDateTime::fromSecsSinceEpoch(bisTs).toString(Qt::ISODate);
}

// Witzige Krankentage (ROSI-13): einmal pro Kalendertag gewürfelt (Guard über
// letzter_krankheitswuerfel_tag), nur wenn kein Urlaub aktiv ist. Bei Treffer
// ist sie genau für den Rest des heutigen Tages krank.
void RosiManager::_pruefeKrankheit()
{
    const qint64 heuteInt = _heuteAlsZahl();
    if (_zaehlerGet("letzter_krankheitswuerfel_tag") == heuteInt) return; // heute schon gewürfelt
    _zaehlerSet("letzter_krankheitswuerfel_tag", heuteInt);

    if (_zaehlerGet("urlaub_bis") > QDateTime::currentSecsSinceEpoch()) return; // im Urlaub wird nicht gewürfelt

    if (QRandomGenerator::global()->generateDouble() >= kKrankChanceProTag) return; // kein Treffer heute

    const QStringList krankheiten = _poolJ_Krankheiten();
    const int grundId = QRandomGenerator::global()->bounded(krankheiten.size());
    _zaehlerSet("krank_grund_id", grundId);
    _zaehlerSet("krank_bis", QDateTime(QDate::currentDate().addDays(1), QTime(0, 0)).toSecsSinceEpoch());

    qCInfo(lcApp) << "Rosi: krank heute -" << krankheiten.at(grundId);
}

// ROSI-11/ROSI-13: meldet QML, ob gerade die permanente Urlaubs- bzw.
// Kranktags-Anzeige an der Röhre gezeigt werden soll, und mit welchem Text.
// Emittiert nur bei einer tatsächlichen Änderung (Start/Ende), nicht bei
// jedem Tick erneut.
void RosiManager::_pruefeAbwesenheit()
{
    const qint64 jetzt      = QDateTime::currentSecsSinceEpoch();
    const qint64 urlaubBis  = _zaehlerGet("urlaub_bis");
    const qint64 krankBis   = _zaehlerGet("krank_bis");

    QString text;
    if (urlaubBis > jetzt) {
        const QDate von          = QDateTime::fromSecsSinceEpoch(_zaehlerGet("urlaub_von")).date();
        const QDate bisInklusive = QDateTime::fromSecsSinceEpoch(urlaubBis).date().addDays(-1);
        text = QStringLiteral("im Urlaub von %1 bis %2.")
                   .arg(von.toString("dd.MM."), bisInklusive.toString("dd.MM."));
    } else if (krankBis > jetzt) {
        const QStringList krankheiten = _poolJ_Krankheiten();
        const int grundId = static_cast<int>(_zaehlerGet("krank_grund_id"));
        const QString grund = (grundId >= 0 && grundId < krankheiten.size())
                                   ? krankheiten.at(grundId)
                                   : QStringLiteral("Wehwehchen");
        text = QStringLiteral("krank: %1 – morgen wieder da").arg(grund);
    }

    if (text == m_letzteAbwesenheitAnzeige) return;
    m_letzteAbwesenheitAnzeige = text;

    if (text.isEmpty())
        emit abwesenheitVerstecken();
    else
        emit abwesenheitAnzeigen(text);
}

// Postkarte/Nachricht aus dem Urlaub (ROSI-12): alle 7 Tage statt einmalig.
void RosiManager::_pruefePostkarte()
{
    const qint64 urlaubVon = _zaehlerGet("urlaub_von");
    const qint64 urlaubBis = _zaehlerGet("urlaub_bis");
    if (urlaubBis <= 0 || urlaubVon <= 0) return;

    const qint64 jetzt = QDateTime::currentSecsSinceEpoch();
    if (jetzt >= urlaubBis) return; // Urlaub schon vorbei

    const int gesendet = static_cast<int>(_zaehlerGet("urlaub_postkarten_gesendet_anzahl"));
    const qint64 vergangeneTage  = (jetzt - urlaubVon) / 86400;
    const qint64 naechsteFaellig = 7LL * (gesendet + 1);

    if (vergangeneTage < naechsteFaellig) return;

    _zaehlerSet("urlaub_postkarten_gesendet_anzahl", gesendet + 1);
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
    if (jetzt < _zaehlerGet("krank_bis")) return;

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
    if (erschienenAnzahl == 0) {
        _zaehlerSet("letzter_gruss_tag", _heuteAlsZahl());
        return _zufall(_poolErstkontakt());
    }

    if (_zaehlerGet("urlaub_gerade_zurueck") == 1) {
        _zaehlerSet("urlaub_gerade_zurueck", 0);
        _zaehlerSet("urlaubsgeschichten_uebrig", kUrlaubsgeschichtenStart);
        _zaehlerSet("urlaubssprache_chance", kUrlaubsspracheChanceStart);
        _zaehlerSet("letzter_gruss_tag", _heuteAlsZahl());
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
        // ROSI-09: Pool A (Begrüßung) nur im Kandidatenkreis, wenn heute noch
        // nicht begrüßt wurde — wird sie tatsächlich gezogen, gilt der Tag
        // als "begrüßt" und Pool A fällt für den Rest des Tages raus.
        const bool schonBegruesst = _zaehlerGet("letzter_gruss_tag") == _heuteAlsZahl();

        QList<QStringList> pools;
        if (!schonBegruesst) pools.append(_poolA_Begruessung());
        pools.append(_poolB_Kommentar());
        pools.append(_poolC_Tipp());
        pools.append(_poolF_PauseTrinken());
        pools.append(_poolG_Auswanderung());
        pools.append(_poolI_Jugendwoerter());

        const int idx = QRandomGenerator::global()->bounded(pools.size());
        basis = _zufall(pools.at(idx));
        if (!schonBegruesst && idx == 0)
            _zaehlerSet("letzter_gruss_tag", _heuteAlsZahl());
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
