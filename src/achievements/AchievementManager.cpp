#include "logging.h"
#include "AchievementManager.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDateTime>
#include <QDebug>
#include <QRandomGenerator>
#include <algorithm>

// ─────────────────────────────────────────────────────────────────────────────
// Achievement-Katalog (hardcoded – bleibt für den Nutzer unsichtbar)
// ─────────────────────────────────────────────────────────────────────────────
QList<AchievementManager::Def> AchievementManager::_katalog()
{
    return {
        // Erste Schritte
        { "WILLKOMMEN",          "Willkommen an Bord",       "Du hast die App gestartet. Das war der schwerste Schritt." },
        { "ERSTES_BAUTEIL",      "Pionier",                  "Bauteil Nummer 1. Die Legende beginnt." },
        { "ERSTES_KABEL",        "Verbunden",                "Erste Verbindung gezogen. Strom fließt (theoretisch)." },
        { "ERSTE_SEITE",         "Seitenweise",              "Neue Seite angelegt. Mehr Platz für mehr Chaos." },

        // Fleißarbeit
        { "KABELSALAT",          "Kabelsalat",               "50 Kabel. Hoffentlich weißt du noch was wo hingeht." },
        { "BAUTEILFLUT",         "Bauteilflut",              "100 Bauteile. Zählst du noch mit?" },
        { "KLEMMEN_KOENIG",      "Klemmen-König",            "Erste Klemmenreihe. Du weißt jetzt was andere nicht wissen." },
        { "SCHALTPLAN_KOMPLEX",  "Schaltplanarchitekt",      "Über 50 Elemente auf einer Seite. Das druckt man besser A0." },

        // Frech & Diagnostisch
        { "REISSWOLF",           "Reißwolf",                 "20 Elemente in Folge gelöscht. Schlechter Tag?" },
        { "TOTALSCHADEN",        "Totalschaden",             "Alles gelöscht. Neustart der Seele." },
        { "UNDO_JUNKIE",         "Undo-Junkie",              "Ctrl+Z 15x nacheinander. Lass es sein." },
        { "PERFEKTIONIST",       "Perfektionist",            "Ein Bauteil 10x rotiert. Irgendwann passt es schon." },
        { "ZOOMMANIE",           "Zoommanie",                "25x rein-raus-rein-raus. Alles gut da oben?" },

        // Entdecker
        { "FUN_MODUS",           "Stromling gefunden",       "Du hast den Fun-Modus entdeckt. Wir reden nicht darüber." },
        { "WIKI_LESER",          "Wissensdurst",             "Du hast das Wiki geöffnet. Respekt." },
        { "ALLE_PANELS",         "Neugierling",              "Alle Panels mindestens einmal geöffnet. Du kennst dich jetzt aus." },
        { "DRC_FIRST",           "Fehlersucher",             "Ersten DRC durchgeführt. Es gibt keine fehlerfreien Schaltplane – nur ungeprüfte." },
        { "SYMBOL_EDITOR",       "Künstler",                 "Symboleditor geöffnet. Das macht nicht jeder." },

        // Wiki-Redaktion
        { "WIKI_ERSTER_ARTIKEL", "Chefredakteur",            "Ersten Wiki-Artikel angelegt. Das Wissen gehört der Welt." },
        { "WIKI_FLEISSIG",       "Vielschreiber",            "5 Wiki-Artikel. Du bist das interne Wikipedia." },
        { "WIKI_ENZYKLOPAEDIE",  "Enzyklopädist",            "10 Wiki-Artikel. Bitte schreib auch mal Schaltplane." },
        { "WIKI_NEUE_SEITE",     "Seitenarchitekt",          "Neue Wiki-Kategorie angelegt. Ordnung im Chaos." },
        { "WIKI_BEARBEITET",     "Korrektiv",                "Wiki-Artikel bearbeitet. Perfektion ist ein Prozess." },
        { "WIKI_BUNDLE",         "Bundle-Meister",           "Erstes Wiki-Bundle exportiert. Das verdient Applaus." },

        // PDF & Ausgabe
        { "PDF_FIRST",           "Auf Papier",               "Erstes PDF erzeugt. Irgendwo existiert das jetzt für immer." },
        { "PDF_DICKES_DING",     "Schwergewicht",            "PDF mit 5+ Seiten. Das nennt man Dokumentation." },
        { "PDF_MARATHON",        "Druckerei",                "5 PDFs erzeugt. Hoffentlich nicht alle ausgedruckt." },

        // Inbetriebnahme
        { "IBN_FIRST",           "Inbetriebnahme-Rookie",   "IBN-Modus erstmals geöffnet. Jetzt wird's ernst." },
        { "IBN_ERSTES_GRUEN",    "Grünes Licht",             "Erstes Element auf grün gesetzt. Der Anfang vom Ende der Fehlersuche." },
        { "IBN_ZEHN_GRUEN",      "Auf Kurs",                 "10 Elemente geprüft. Läuft." },
        { "IBN_ALLES_GRUEN",     "Alles im grünen Bereich",  "Alle Elemente einer Seite geprüft und grün. Selten, aber schön." },
        { "IBN_MESSWERT",        "Messtechniker",            "Ersten Messwert eingetragen. Zahlen lügen nicht (meistens)." },
        { "IBN_PROTOKOLL",       "Protokollant",             "Prüfprotokoll erzeugt. Für die Nachwelt." },

        // Fehlersuche (DRC)
        { "DRC_ERSTER_FEHLER",   "Tatortbesichtigung",       "Ersten DRC-Fehler gefunden. Schau nicht so überrascht." },
        { "DRC_CLEAN",           "Weißes Blatt",             "DRC ohne Fehler. Entweder sehr gut oder sehr wenig drauf." },
        { "DRC_VIELE_FEHLER",    "Fundgrube",                "10+ Fehler in einem Lauf. Das ist kein Schaltplan, das ist ein Rätsel." },
        { "DRC_ALLE_BEHOBEN",    "Aufgeräumt",               "Alle DRC-Fehler behoben, nächster Lauf sauber. Respekt." },
        { "DRC_FLEISSIG",        "Qualitätswächter",         "5x DRC gelaufen. Du prüfst mehr als die meisten." },

        // Zeitchallenges
        { "SPEED_PLACER",        "Schnellplacer",            "10 Bauteile in 60 Sekunden. Effizienz ist eine Tugend." },
        { "MARATHON",            "Marathon-Entwickler",      "2 Stunden Session. Hast du auch getrunken?" },
        { "MORGENMUFFEL",        "Morgenmuffel",             "Vor 7 Uhr arbeiten. Das ist Hingabe (oder Schlafmangel)." },
        { "NACHTFALTER",         "Nachtfalter",              "Nach Mitternacht. Der Schaltplan wartet nicht." },
        { "WOCHENEND_HELD",      "Wochenend-Held",           "Samstag oder Sonntag. Die anderen schlafen noch." },

        // Zufalls-Achievements
        { "GLUECKSPILZ",         "Glückspilz",               "Manchmal passiert es einfach. Kein Grund, keinen Grund." },
        { "KOSMISCH",            "Kosmischer Zufall",        "Du warst zur richtigen Zeit am richtigen Ort. Warum auch nicht." },
        { "GEHEIMTUER",          "Geheime Tür",              "Da war etwas. Oder nicht. Oder doch." },

        // Strömlinge
        { "POKESTROEM",          "Pokestrom-Fan",            "Du hast Pokestrom entdeckt. Er war schon immer da." },
        { "STROMLING_SAMMLER",   "Sammler",                  "Alle Strömlinge im Fun-Modus gesehen." },
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Konstruktor – freigeschaltete IDs aus DB laden
// ─────────────────────────────────────────────────────────────────────────────
AchievementManager::AchievementManager(QObject *parent)
    : QObject(parent)
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return;

    QSqlQuery q(db);
    if (q.exec("SELECT id FROM achievement_errungen")) {
        while (q.next())
            _cache.insert(q.value(0).toString());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interne Hilfsfunktionen
// ─────────────────────────────────────────────────────────────────────────────
bool AchievementManager::_hat(const QString &id) const
{
    return _cache.contains(id);
}

void AchievementManager::_freischalten(const QString &id)
{
    if (_hat(id)) return;

    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return;

    QSqlQuery q(db);
    q.prepare("INSERT OR IGNORE INTO achievement_errungen (id, freigeschaltet_am) VALUES (?, ?)");
    q.addBindValue(id);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec()) {
        qCWarning(lcApp) << "Achievement speichern fehlgeschlagen:" << q.lastError().text();
        return;
    }

    _cache.insert(id);

    // Katalog nach Titel/Beschreibung durchsuchen
    for (const auto &def : _katalog()) {
        if (def.id == id) {
            qCInfo(lcApp) << "Achievement freigeschaltet:" << id << def.titel;
            emit achievementFreigeschaltet(id, def.titel, def.beschreibung);
            return;
        }
    }
}

int AchievementManager::_zaehlerInc(const QString &key, int um)
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return 0;

    QSqlQuery q(db);
    q.prepare("INSERT INTO achievement_zaehler (schluessel, wert) VALUES (?, ?) "
              "ON CONFLICT(schluessel) DO UPDATE SET wert = wert + ?");
    q.addBindValue(key);
    q.addBindValue(um);
    q.addBindValue(um);
    q.exec();

    return _zaehlerGet(key);
}

int AchievementManager::_zaehlerGet(const QString &key) const
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return 0;

    QSqlQuery q(db);
    q.prepare("SELECT wert FROM achievement_zaehler WHERE schluessel = ?");
    q.addBindValue(key);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    return 0;
}

void AchievementManager::_pruefePanels()
{
    if (_hat("ALLE_PANELS")) return;
    if (_stats.wikiGeoeffnet && _stats.symEdGeoeffnet &&
        _stats.kabelrGeoeffnet && _stats.ibnGeoeffnet && _stats.drcGeoeffnet)
        _freischalten("ALLE_PANELS");
}

void AchievementManager::_pruefeMarathon()
{
    if (_hat("MARATHON")) return;
    qint64 minuten = _stats.start.secsTo(QDateTime::currentDateTime()) / 60;
    if (minuten >= 120)
        _freischalten("MARATHON");
}

void AchievementManager::_resetNichtLoeschSequenz()
{
    _stats.geloeschteInFolge = 0;
}

void AchievementManager::_resetNichtUndoSequenz()
{
    _stats.undosInFolge = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// erreichte() – Liste für das Panel
// ─────────────────────────────────────────────────────────────────────────────
QVariantList AchievementManager::erreichte() const
{
    auto db = QSqlDatabase::database("stroemling_launcher");
    if (!db.isOpen()) return {};

    QSqlQuery q(db);
    if (!q.exec("SELECT id, freigeschaltet_am FROM achievement_errungen ORDER BY freigeschaltet_am DESC"))
        return {};

    // Katalog als Lookup aufbauen
    QHash<QString, Def> lookup;
    for (const auto &d : _katalog())
        lookup[d.id] = d;

    QVariantList result;
    while (q.next()) {
        QString id = q.value(0).toString();
        qint64  ts = q.value(1).toLongLong();
        if (!lookup.contains(id)) continue;

        const auto &d = lookup[id];
        QVariantMap m;
        m["id"]          = id;
        m["titel"]       = d.titel;
        m["beschreibung"] = d.beschreibung;
        m["datum"]       = QDateTime::fromSecsSinceEpoch(ts).toString("dd.MM.yyyy HH:mm");
        result.append(m);
    }
    return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// ereignis() – zentraler Einstiegspunkt
// ─────────────────────────────────────────────────────────────────────────────
void AchievementManager::ereignis(const QString &typ, const QVariantMap &kontext)
{
    _pruefeMarathon();

    // ── App-Start ────────────────────────────────────────────────────────────
    if (typ == "app_start") {
        int starts = _zaehlerInc("app_starts");

        if (starts == 1)
            _freischalten("WILLKOMMEN");

        QTime t = QTime::currentTime();
        int h   = t.hour();
        if (h >= 5 && h < 7)  _freischalten("MORGENMUFFEL");
        if (h == 0 || h == 1) _freischalten("NACHTFALTER");

        int dow = QDate::currentDate().dayOfWeek();
        if (dow == 6 || dow == 7) _freischalten("WOCHENEND_HELD");

        // KOSMISCH: 0,8% nach dem 10. Start
        if (starts >= 10 && QRandomGenerator::global()->bounded(1000) < 8)
            _freischalten("KOSMISCH");
    }

    // ── Element platziert ────────────────────────────────────────────────────
    else if (typ == "element_platziert") {
        _resetNichtLoeschSequenz();
        _resetNichtUndoSequenz();
        _stats.rotInFolge = 0;

        _stats.platzierteElemente++;
        qint64 now = QDateTime::currentSecsSinceEpoch();
        _stats.platzTs.append(now);
        // Nur Timestamps der letzten 60s behalten
        while (!_stats.platzTs.isEmpty() && now - _stats.platzTs.first() > 60)
            _stats.platzTs.removeFirst();

        if (_stats.platzierteElemente == 1)
            _freischalten("ERSTES_BAUTEIL");

        int total = _zaehlerInc("platzierte_elemente");
        if (total >= 100) _freischalten("BAUTEILFLUT");

        if (_stats.platzTs.size() >= 10) _freischalten("SPEED_PLACER");

        int aufSeite = kontext.value("elementeAufSeite", 0).toInt();
        if (aufSeite >= 50) _freischalten("SCHALTPLAN_KOMPLEX");
    }

    // ── Kabel gezogen ────────────────────────────────────────────────────────
    else if (typ == "kabel_gezogen") {
        _resetNichtLoeschSequenz();
        _resetNichtUndoSequenz();

        _stats.gezogeneKabel++;
        if (_stats.gezogeneKabel == 1)
            _freischalten("ERSTES_KABEL");

        int total = _zaehlerInc("gezogene_kabel");
        if (total >= 50) _freischalten("KABELSALAT");

        // GLUECKSPILZ: 1,5% ab dem 50. Kabel
        if (total >= 50 && QRandomGenerator::global()->bounded(1000) < 15)
            _freischalten("GLUECKSPILZ");
    }

    // ── Element gelöscht ─────────────────────────────────────────────────────
    else if (typ == "element_geloescht") {
        _resetNichtUndoSequenz();
        _stats.rotInFolge = 0;

        _stats.geloeschteInFolge += kontext.value("anzahl", 1).toInt();
        if (_stats.geloeschteInFolge >= 20) _freischalten("REISSWOLF");

        bool seiteWar = kontext.value("seiteWar", 0).toInt() > 5;
        bool seiteJetzt = kontext.value("seiteJetzt", -1).toInt() == 0;
        if (seiteWar && seiteJetzt) _freischalten("TOTALSCHADEN");
    }

    // ── Undo ─────────────────────────────────────────────────────────────────
    else if (typ == "undo") {
        _resetNichtLoeschSequenz();
        _stats.rotInFolge = 0;

        _stats.undosInFolge++;
        if (_stats.undosInFolge >= 15) _freischalten("UNDO_JUNKIE");
    }

    // ── Rotation ─────────────────────────────────────────────────────────────
    else if (typ == "element_rotiert") {
        _resetNichtLoeschSequenz();
        _resetNichtUndoSequenz();

        int elemId = kontext.value("elemId", -1).toInt();
        if (elemId != _stats.rotElemId) {
            _stats.rotInFolge = 0;
            _stats.rotElemId  = elemId;
        }
        _stats.rotInFolge++;
        if (_stats.rotInFolge >= 10) _freischalten("PERFEKTIONIST");
    }

    // ── Zoom ─────────────────────────────────────────────────────────────────
    else if (typ == "zoom") {
        qint64 now = QDateTime::currentSecsSinceEpoch();
        _stats.zoomTs.append(now);
        while (!_stats.zoomTs.isEmpty() && now - _stats.zoomTs.first() > 60)
            _stats.zoomTs.removeFirst();
        if (_stats.zoomTs.size() >= 25) _freischalten("ZOOMMANIE");
    }

    // ── Seite erstellt ───────────────────────────────────────────────────────
    else if (typ == "seite_erstellt") {
        _freischalten("ERSTE_SEITE");
    }

    // ── Klemmenreihe erstellt ────────────────────────────────────────────────
    else if (typ == "klemmenreihe_erstellt") {
        _freischalten("KLEMMEN_KOENIG");
    }

    // ── Wiki geöffnet ────────────────────────────────────────────────────────
    else if (typ == "wiki_geoeffnet") {
        if (!_stats.wikiGeoeffnet) {
            _stats.wikiGeoeffnet = true;
            _freischalten("WIKI_LESER");
        }
        _pruefePanels();
    }

    // ── Wiki-Artikel angelegt ────────────────────────────────────────────────
    else if (typ == "wiki_artikel_erstellt") {
        int total = _zaehlerInc("wiki_artikel");
        if (total == 1)  _freischalten("WIKI_ERSTER_ARTIKEL");
        if (total >= 5)  _freischalten("WIKI_FLEISSIG");
        if (total >= 10) _freischalten("WIKI_ENZYKLOPAEDIE");
    }

    // ── Wiki-Kategorie angelegt ──────────────────────────────────────────────
    else if (typ == "wiki_kategorie_erstellt") {
        _freischalten("WIKI_NEUE_SEITE");
    }

    // ── Wiki-Artikel bearbeitet ──────────────────────────────────────────────
    else if (typ == "wiki_artikel_bearbeitet") {
        _freischalten("WIKI_BEARBEITET");
    }

    // ── Wiki-Bundle exportiert ───────────────────────────────────────────────
    else if (typ == "wiki_bundle_exportiert") {
        _freischalten("WIKI_BUNDLE");
    }

    // ── DRC ausgeführt ───────────────────────────────────────────────────────
    else if (typ == "drc_ausgefuehrt") {
        if (!_stats.drcGeoeffnet) {
            _stats.drcGeoeffnet = true;
            _pruefePanels();
        }
        int fehler = kontext.value("fehlerAnzahl", 0).toInt();
        int laeufe = _zaehlerInc("drc_laeufe");

        _freischalten("DRC_FIRST");
        if (fehler > 0)  _freischalten("DRC_ERSTER_FEHLER");
        if (fehler == 0) _freischalten("DRC_CLEAN");
        if (fehler >= 10) _freischalten("DRC_VIELE_FEHLER");
        if (fehler == 0 && _stats.drcLetzterFehler > 0) _freischalten("DRC_ALLE_BEHOBEN");
        if (laeufe >= 5) _freischalten("DRC_FLEISSIG");

        _stats.drcLetzterFehler = fehler;
    }

    // ── PDF exportiert ───────────────────────────────────────────────────────
    else if (typ == "pdf_exportiert") {
        int seiten = kontext.value("seitenAnzahl", 1).toInt();
        int total  = _zaehlerInc("pdf_exporte");

        _freischalten("PDF_FIRST");
        if (seiten >= 5) _freischalten("PDF_DICKES_DING");
        if (total >= 5)  _freischalten("PDF_MARATHON");
    }

    // ── IBN geöffnet ─────────────────────────────────────────────────────────
    else if (typ == "ibn_geoeffnet") {
        if (!_stats.ibnGeoeffnet) {
            _stats.ibnGeoeffnet = true;
            _freischalten("IBN_FIRST");
            _pruefePanels();
        }
    }

    // ── IBN Element auf grün gesetzt ─────────────────────────────────────────
    else if (typ == "ibn_element_gruen") {
        int total = _zaehlerInc("ibn_gruen");
        _freischalten("IBN_ERSTES_GRUEN");
        if (total >= 10) _freischalten("IBN_ZEHN_GRUEN");

        int aufSeite = kontext.value("elementeAufSeite", 0).toInt();
        int gruen    = kontext.value("gruenAufSeite",    0).toInt();
        if (aufSeite >= 5 && gruen >= aufSeite)
            _freischalten("IBN_ALLES_GRUEN");
    }

    // ── IBN Messwert eingetragen ──────────────────────────────────────────────
    else if (typ == "ibn_messwert") {
        _freischalten("IBN_MESSWERT");
    }

    // ── IBN Protokoll exportiert ──────────────────────────────────────────────
    else if (typ == "ibn_protokoll") {
        _freischalten("IBN_PROTOKOLL");
    }

    // ── Fun-Modus ─────────────────────────────────────────────────────────────
    else if (typ == "fun_modus") {
        _freischalten("FUN_MODUS");
    }

    // ── Fun-Modus Szenario ────────────────────────────────────────────────────
    else if (typ == "fun_modus_szenario") {
        QString szenario = kontext.value("szenario", "").toString().toLower();
        if (szenario.contains("pokestroem") || szenario.contains("pokestrom"))
            _freischalten("POKESTROEM");

        int gesehen = _zaehlerInc("fun_szenarien_" + szenario, 1);
        Q_UNUSED(gesehen)
        // STROMLING_SAMMLER: alle 8 Szenarien gesehen
        if (_zaehlerGet("fun_szenarien_unique") >= 8)
            _freischalten("STROMLING_SAMMLER");
    }

    // ── Symbol-Editor geöffnet ────────────────────────────────────────────────
    else if (typ == "symbol_editor_geoeffnet") {
        if (!_stats.symEdGeoeffnet) {
            _stats.symEdGeoeffnet = true;
            _freischalten("SYMBOL_EDITOR");
        }
        _stats.symEdOeffnungen++;
        _pruefePanels();

        // GEHEIMTUER: 3% ab 5. Öffnung
        if (_stats.symEdOeffnungen >= 5 && QRandomGenerator::global()->bounded(100) < 3)
            _freischalten("GEHEIMTUER");
    }

    // ── Kabelrechner geöffnet ─────────────────────────────────────────────────
    else if (typ == "kabelrechner_geoeffnet") {
        if (!_stats.kabelrGeoeffnet) {
            _stats.kabelrGeoeffnet = true;
            _pruefePanels();
        }
    }
}
