#pragma once

#include <QObject>
#include <QList>
#include <QSizeF>
#include <QSqlDatabase>
#include <QSqlError>
#include <QString>
#include <QVariantMap>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonArray>
#include "logging.h"

// Database kümmert sich um:
//   - Verbindung zur SQLite-Datei aufbauen
//   - Schema versioniert anlegen (schema_version-Tabelle)
//   - Bei Versionsänderung: alles löschen + neu aufbauen
//   - Wird einmal in main.cpp erstellt und dann weitergegeben

class QPainter;
class QPdfWriter;

class QTimer;

class Database : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool         projektOffen    READ projektOffen       NOTIFY projektOffenChanged)
    Q_PROPERTY(QString      projektPfad     READ projektPfad        NOTIFY projektOffenChanged)
    Q_PROPERTY(QString      projektOrdner   READ projektOrdner      NOTIFY projektOffenChanged)
    Q_PROPERTY(QVariantList bekannteProjecte READ bekannteProjecteLaden NOTIFY registryGeaendert)
    Q_PROPERTY(QString      makroPfad       READ makroPfad          CONSTANT)
    Q_PROPERTY(QString      wikiPfad        READ wikiPfad           CONSTANT)
    // VERT-01: Projekt von einer anderen Sitzung gesperrt -> nur lesen
    Q_PROPERTY(bool         schreibgeschuetzt READ schreibgeschuetzt NOTIFY schreibschutzChanged)
    Q_PROPERTY(QVariantMap  sperreInfo      READ sperreInfo         NOTIFY schreibschutzChanged)
    // VERT-02: Datei ist eine IBN-Kopie / Schaltplan ist gesperrt (Kopie oder ausgegebene Kopien)
    Q_PROPERTY(bool         istIbnKopie     READ istIbnKopie        NOTIFY ibnKopieChanged)
    Q_PROPERTY(bool         schaltplanGesperrt READ schaltplanGesperrt NOTIFY ibnKopieChanged)
    Q_PROPERTY(int          offeneKopien    READ offeneKopien       NOTIFY ibnKopieChanged)
    Q_PROPERTY(bool         schaltplanOverrideAktiv READ schaltplanOverrideAktiv NOTIFY ibnKopieChanged)
    Q_PROPERTY(QString      ibnKopieName    READ ibnKopieName       NOTIFY ibnKopieChanged)

public:
    // Baseline-Version des Migrations-Systems. Neue Schemaänderungen kommen
    // als inkrementelle Migration in alleMigrationen(). Bei einem Migrations-
    // Squash (keine Produktivdatenbanken) wird diese Konstante auf die nächste
    // freie Versionsnummer erhöht und alleMigrationen() auf den neuen Baseline-
    // Eintrag zurückgesetzt.
    static const int BASELINE_VERSION        = 56;
    static const int CURRENT_SCHEMA_VERSION  = 129;
    static const int WIKI_SCHEMA_VERSION     = 16;
    static const int BIBLIOTHEK_SCHEMA_VERSION = 12;
    // Tabellenzahl in schema.sql – muss synchron zu BASELINE_VERSION bleiben.
    // Wenn schema.sql neue Tabellen bekommt: diesen Wert + BASELINE_VERSION erhöhen.
    // schema_migration selbst zählt mit (wird vor createSchema() angelegt, überlebt
    // dropAllTables() unangetastet) – daher 32 Tabellen aus schema.sql + 1.
    static const int BASELINE_TABLE_COUNT   = 33;

    explicit Database(QObject *parent = nullptr);
    ~Database() override;

    // VERT-01: Sperrdatei (konzept/features/55 §3)
    static const int SPERRE_VERALTET_STUNDEN = 24;
    bool        schreibgeschuetzt() const { return m_schreibgeschuetzt; }
    QVariantMap sperreInfo()        const { return m_sperreInfo; }   // {rechner, benutzer, zeit}
    bool istIbnKopie()        const { return m_istIbnKopie; }
    bool schaltplanGesperrt() const;
    int  offeneKopien()       const { return m_offeneKopien; }
    bool schaltplanOverrideAktiv() const { return m_schaltplanOverride && m_offeneKopien > 0; }
    QString ibnKopieName()    const { return m_ibnKopieName; }
    static QString     sperrDateiPfad(const QString &projektPfad);
    static QVariantMap sperreLesen(const QString &lockPfad);
    static bool        sperreVeraltet(const QVariantMap &info,
                                      const QDateTime &jetzt = QDateTime::currentDateTimeUtc());

    // Launcher-DB öffnen (stroemling.db – nur zuletzt-geöffnet-Liste + Wiki-DB-Pfad)
    bool openLauncher(const QString &path);

    // Bibliothek-DB öffnen (bibliothek.db – projektübergreifende Bauteil-Bibliothek)
    bool openBibliothek(const QString &path);

    // BIB-UID-01: stabile UID eines mitgelieferten (ist_system) Bauteils. Deterministisch (UUIDv5 aus der Bezeichnung),
    // damit dasselbe Standardteil auf jedem Rechner dieselbe UID hat. Der Namespace darf sich nie ändern.
    static QString bauteilSystemUid(const QString &bezeichnung);

    // ── Bauteil-Austausch (BIB-IMPORT-01, s. konzept/features/56_bauteil_austausch.md) ──────────────────────────
    // Exportiert die Bauteil-Bibliothek als JSON-Bündel "stroemling-bauteile". Rückgabe: {ok, anzahl, fehler}.
    Q_INVOKABLE QVariantMap bauteileExportieren(const QString &pfad, bool mitSystem);
    // Liest ein Bündel und vergleicht es mit der lokalen Bibliothek, ohne etwas zu ändern.
    // Rückgabe: {ok, fehler, eintraege:[{uid, bezeichnung, hersteller, artikelnummer, typ, kategorie, status,
    //            lokalId, lokaleBezeichnung, vorschlag, aktionen}], anzahlNeu, anzahlGleich, ...}
    Q_INVOKABLE QVariantMap bauteileImportAnalysieren(const QString &pfad);
    // Führt die Entscheidungen aus (uid → aktion: anlegen|ueberschreiben|kopie|verknuepfen|ueberspringen; fehlend = Vorschlag).
    // Alles in einer Transaktion; vorher Sicherung der bibliothek.db. Rückgabe: {ok, fehler, angelegt, ueberschrieben, ...}.
    Q_INVOKABLE QVariantMap bauteileImportAusfuehren(const QString &pfad, const QVariantMap &entscheidungen);
    // Lokale Bauteil-ID zu einer UID (eigene UID oder Alias aus einem Import); -1 wenn unbekannt.
    int bauteilIdFuerUid(const QString &uid) const;
    // Sicherung der bibliothek.db (VACUUM INTO nach backups/); leer bei Fehler, sonst der Pfad.
    QString bibliothekSichern(const QString &anlass);

    // ── Stabile Bauteil-Bezüge (BIB-REF-01, konzept/features/56_bauteil_austausch.md §4) ──────────────────────────
    // Gleicht die ID-Verweise des Projekts mit der lokalen Bibliothek über die UID ab: stimmt die UID zu einer ID nicht mehr,
    // wird der Verweis (bei schreiben=true) auf die lokale ID desselben Bauteils umgeschrieben; nicht Auflösbares wird nur gemeldet.
    // Rückgabe: {angepasst, fehlend:[{name, uid}], unsicher:[{name, uid, lokalerName}], nichtAngepasst}.
    Q_INVOKABLE QVariantMap bauteilBezuegePruefen(bool schreiben);
    // Hält die UID der aktuell benutzten Verweise im Projekt fest (nur wenn sich etwas ändert; nie in schreibgeschützten Projekten/IBN-Kopien).
    Q_INVOKABLE bool bauteilBezuegeAktualisieren();

    // Projektdatei öffnen (existierende .stroemling-Datei)
    Q_INVOKABLE bool openProjekt(const QString &path);

    // Neue Projektdatei anlegen und öffnen
    Q_INVOKABLE bool    createProjekt(const QString &path, const QString &projektName);
    // GIT-00: Ordner-pro-Projekt
    Q_INVOKABLE QString standardProjektOrdner() const;

    // GIT-01: Git-Integration
    Q_INVOKABLE bool         gitVerfuegbar() const;
    Q_INVOKABLE bool         snapshotErstellen(const QString &ordner);
    Q_INVOKABLE void         gitProjektInit(const QString &ordner);
    Q_INVOKABLE void         gitAutoCommit(const QString &ordner, const QString &nachricht);
    Q_INVOKABLE QVariantList gitLog(const QString &ordner);
    Q_INVOKABLE bool         gitCheckout(const QString &ordner, const QString &hash);
    // GIT-02: Remote / Cloud
    Q_INVOKABLE QString      gitRemoteUrl(const QString &ordner) const;
    Q_INVOKABLE void         gitRemoteSetzen(const QString &ordner, const QString &url);

    // Aktuelles Projekt schließen
    Q_INVOKABLE void closeProjekt();

    // Aktuelles Projekt als kompakte Kopie exportieren (VACUUM INTO)
    Q_INVOKABLE bool projektExportieren(const QString &destPfad);
    // BACKUP-OEFFNEN-01
    Q_INVOKABLE QVariantList projektBackups() const;
    Q_INVOKABLE QString backupWiederherstellen(const QString &backupPfad);
    Q_INVOKABLE QString letzterBackupOrdner() const;

    // Ist gerade eine Projektdatei geöffnet?
    bool    projektOffen()  const { return m_projektOffen; }
    QString projektPfad()   const;
    QString projektOrdner() const;

    // Zuletzt geöffnete Projekte (max. 10, nur existierende Dateien)
    Q_INVOKABLE QVariantList zuletzGeoeffnete() const;

    // Alle bekannten Projekte aus der Registry (für ProjectTree)
    Q_INVOKABLE QVariantList bekannteProjecteLaden() const;

    // Projekt aus Registry entfernen (löscht NICHT die Datei)
    Q_INVOKABLE bool projektAusRegistryEntfernen(const QString &pfad);

    // Projektdatei löschen + Launcher-Eintrag entfernen
    Q_INVOKABLE bool projektLoeschen(const QString &pfad);

    // Metadaten des ersten (einzigen) Projekts in der aktuellen DB
    Q_INVOKABLE QVariantMap ersteProjektInfo() const;

    // Projektmetadaten speichern (Name, Nummer, AG, AN, Bearbeiter, Werk, Abteilung, Norm)
    Q_INVOKABLE bool projektMetaDatenSpeichern(const QString &name,
                                               const QString &nummer,
                                               const QString &auftraggeber,
                                               const QString &auftragnehmer,
                                               const QString &bearbeiter,
                                               const QString &werk,
                                               const QString &abteilung,
                                               const QString &norm);

    // Hauptdatenbank öffnen oder neu anlegen (legacy – ruft openProjekt auf)
    bool open(const QString &path);

    // Wiki-Datenbank öffnen (separate Datei, überlebt Schema-Upgrades)
    bool openWiki(const QString &path);

    // Vorlagen-Bibliothek (vorlagen.db, projektübergreifend) – BLATTVORLAGEN-03
    bool openVorlagen(const QString &path);
    QString vorlagenPfad() const { return m_vorlagenPfad; }

    // Makro-Datenbank öffnen (projektübergreifend, separate Datei)
    bool openMakro(const QString &path);

    // Pfade der Hilfsdatenbanken (für UI-Anzeige)
    QString makroPfad() const { return m_makroPfad; }
    QString wikiPfad()  const { return m_wikiPfad; }

    // Verbindungen schließen
    void close();

    // Ist die Verbindung offen?
    bool isOpen() const;

    // Letzter Fehler (für Debugging)
    QString lastError() const;

Q_SIGNALS:
    void projektOffenChanged();
    void schreibschutzChanged();
    void ibnKopieChanged();
    void sperreVerweigert(const QString &text);   // VERT-02c: Toast-Text fuer verweigerte Aktionen
    void bauteilBezuegeGeprueft(const QVariantMap &ergebnis);   // BIB-REF-01: Ergebnis des Bezugsabgleichs beim Öffnen (nur wenn etwas angepasst wurde oder fehlt)
    void registryGeaendert();
    void dbFehler(const QString &meldung);
    // Wie dbFehler, aber der Dialog bietet zusätzlich "Backup-Ordner öffnen" an (BACKUP-OEFFNEN-01)
    void dbFehlerMitBackup(const QString &meldung);

public:
    // Grafikelemente einer Seite laden (gibt QVariantList aus QVariantMaps zurück)
    Q_INVOKABLE QVariantList grafikLaden(int seiteId);

    // Alle Grafikelemente einer Seite ersetzen (Transaktion, Delete + Insert)
    Q_INVOKABLE bool grafikSpeichern(int seiteId, const QVariantList &elemente);
    // Zähler, der bei jedem erfolgreichen grafikSpeichern() steigt. Die Listenansicht
    // vergleicht ihn mit dem Stand der letzten Von/Nach-Berechnung (KABEL-VONNACH-AUTO-01).
    Q_INVOKABLE int grafikAenderungszaehler() const { return m_grafikAenderungszaehler; }

    // Alle Symbole für eine gegebene Norm zurückgeben ("IEC" oder "ANSI")
    Q_INVOKABLE QVariantList symboleNachNorm(const QString &norm);

    // Favoritenstatus eines Symbols setzen
    Q_INVOKABLE bool symbolFavoritSetzen(int symbolId, bool favorit);

    // Pfade und Meta-Infos aller Datenbanken zurückgeben (für Einstellungen-Ansicht)
    Q_INVOKABLE QVariantMap datenbankInfos() const;

    // Norm eines Projekts lesen / schreiben
    Q_INVOKABLE QString projektNormLaden(int projektId);
    Q_INVOKABLE bool    projektNormSpeichern(int projektId, const QString &norm);

    // Canvas-Hintergrundfarbe eines Projekts lesen / schreiben
    Q_INVOKABLE QString projektHintergrundLaden(int projektId);
    Q_INVOKABLE bool    projektHintergrundSpeichern(int projektId, const QString &farbe);

    // Zuletzt in der Symbolpalette verwendete Symbol-Codes (LRU, max. 8) lesen / schreiben
    Q_INVOKABLE QStringList projektZuletztVerwendeteSymbole(int projektId);
    Q_INVOKABLE bool         projektZuletztVerwendeteSymboleSpeichern(int projektId, const QStringList &codes);

    // Nächste freie BMK-Nummer für ein Präfix ermitteln.
    // Durchsucht alle grafik_element.extra_daten im Projekt nach vorhandenen
    // BMK-Werten mit diesem Präfix und gibt die nächste freie Nummer zurück.
    // Beispiel: Präfix "-K", bestehende "-K1" und "-K2" → gibt "-K3" zurück.
    Q_INVOKABLE QString naechsteBmkNummer(int projektId, const QString &praefix);

    // Alle Seiten eines Projekts als flache Liste zurückgeben.
    // Gibt [{id, blattnummer, bezeichnung}] zurück – für den Querverweis-Seitenpicker.
    Q_INVOKABLE QVariantList alleSeitenFlach(int projektId);

    // Spotlight-Einträge: BMKs + platzierte Kabel für die Kommando-Palette.
    // Gibt [{kategorie, label, info, seiteId, blattnummer, seiteBez, cx, cy, elementId}] zurück.
    Q_INVOKABLE QVariantList spotlightEintraege(int projektId);

    // Alle Querverweis-Elemente eines Projekts liefern (seitenübergreifend).
    // Gibt [{seiteId, blattnummer, seitenBezeichnung, signalname, richtung,
    //        suchmodus, x1, y1, anlageKuerzel, ortKuerzel}] zurück.
    Q_INVOKABLE QVariantList querverweiseLadenProjekt(int projektId);

    // Stückliste: alle platzierten Symbole mit BMK, Freitexten, Seite.
    // Gibt [{bmk, symbolId, freitext1, freitext2, seite, anlagekz, ortkz}] zurück.
    Q_INVOKABLE QVariantList stueckliste(int projektId);

    // Bestellliste: Bauteile mit vorhandener bauteil_id-Verknüpfung, nach
    // Bauteil gruppiert mit Menge/Einheit/Summe. Vier Quellen: Klemmen, Kabel,
    // Kontaktspiegel-Geräte (v1, BESTELLLISTE-01) sowie seit BESTELLLISTE-02
    // beliebige platzierte Symbole mit generischer Bauteil-Zuordnung im EP
    // (grafik_element.extra_daten.bauteil_id, s. EpBauteilZuordnungSection.qml).
    // Kontaktspiegel-Geräte sind davon ausgenommen (eigener Pfad, sonst
    // Doppelzählung).
    // Gibt [{bauteilId, bezeichnung, hersteller, artikelnummer, bestellnummer,
    //        lieferant, preisEur, menge, einheit, summeEur}] zurück.
    Q_INVOKABLE QVariantList bestellliste(int projektId);

    // Alle Bauteile der Bibliothek für den generischen Symbol-Bauteil-Picker
    // (BESTELLLISTE-02) – keine Kategorie-Einschränkung, anders als die
    // Klemmen-/Kabel-/Steckverbinder-spezifischen Picker-Listen.
    // Gibt [{id, bezeichnung, hersteller, artikelnummer}] zurück.
    Q_INVOKABLE QVariantList bauteilAlleFuerPicker() const;

    // Querverweisliste: alle Querverweis-Symbole mit Signalname, Richtung, Seite, Zielseite.
    // Gibt [{signalname, richtung, seite, zielSeite}] zurück.
    Q_INVOKABLE QVariantList querverweisListe(int projektId);

    // Aderliste: alle Aderdefinitionspunkte mit Bezeichnung, Farbe, Querschnitt, Länge, Seite.
    // Gibt [{bezeichnung, aderfarbe, querschnittMm2, laengeM, seite, anlageKz, ortKz}] zurück.
    Q_INVOKABLE QVariantList aderliste(int projektId);

    // Adersummenliste (ADERSUMME-01, LISTEN-IDEEN-01): aderliste()-Einträge
    // gruppiert nach Aderfarbe+Aderfarbe2+Querschnitt, Längen aufsummiert,
    // mit Anzahl je Gruppe. jeAnlageOrt=true gruppiert zusätzlich nach
    // (überschriebener) Anlage/Ort – dann zusätzlich anlageKz/ortKz je Zeile.
    // Gibt [{aderfarbe, aderfarbe2, querschnittMm2, anzahl, laengeGesamtM,
    //        (anlageKz, ortKz)}] zurück.
    Q_INVOKABLE QVariantList aderSummenliste(int projektId, bool jeAnlageOrt = false);

    // Erkannte Auto-Verbindungen (als Netze) in verbindung/verbindung_segment speichern.
    // netze: [{netKey, bezeichnung, signaltyp, farbe, querschnitt,
    //           segmente:[{x1,y1,x2,y2}], querverweise:[{vonSeiteId,nachSeiteId,...}]}]
    Q_INVOKABLE bool verbindungenSynchronisieren(int seiteId, int projektId, const QVariantList &netze);

    // Fehlersuchmodus: Zielseite + Position für einen Querverweis-Sprung.
    // qvElementId: grafik_element.id des Querverweis-Symbols auf vonSeiteId.
    // Gibt { nachSeiteId: int, zielX: real, zielY: real } zurück.
    Q_INVOKABLE QVariantMap fehlersuchQuerverweisZiel(int vonSeiteId, int qvElementId);

    // Verbindungsannotation (Bezeichnung, Aderfarbe, Querschnitt) eines Netzes aktualisieren.
    Q_INVOKABLE bool verbindungAktualisieren(int verbindungId, const QString &bezeichnung,
                                             const QString &farbe, double querschnitt);

    // Gespeicherte Verbindungsannotationen für eine Seite laden.
    // Gibt [{netKey, verbindungId, bezeichnung, farbe, querschnitt_mm2, signaltyp}] zurück.
    Q_INVOKABLE QVariantList verbindungAnnotationenLaden(int seiteId);

    // Alle Verbindungen eines Projekts für Potenzial-Nummerierung.
    // Gibt [{id, bezeichnung, signaltyp}] zurück.
    Q_INVOKABLE QVariantList verbindungenProjektLaden(int projektId);

    // Nächste freie Potenzialbezeichnung nach Schema (praefix + laufende Nummer).
    Q_INVOKABLE QString naechsteFreiePotenzialNummer(int projektId, const QString &praefix,
                                                     int start, int schrittweite);

    // Mehrere Verbindungsbezeichnungen in einer Transaktion setzen.
    // zuweisungen: [{id (int), bezeichnung (string)}]
    Q_INVOKABLE bool verbindungenBulkBezeichnungSetzen(int projektId,
                                                       const QVariantList &zuweisungen);

    // Bilddatei einlesen und als Base64-Data-URL zurückgeben.
    // Intern werden die Rohdaten verwendet; die Data-URL dient nur der QML-Anzeige.
    // Gibt "error:<Meldung>" zurück falls Datei nicht lesbar oder > maxBytes.
    Q_INVOKABLE QString bildAlsDataUrl(const QString &pfad,
                                       qint64 maxBytes = 5LL * 1024 * 1024);

    // Betriebsmittel-Verknüpfung
    Q_INVOKABLE QVariantList betriebsmittelListe(int projektId);
    Q_INVOKABLE int          betriebsmittelAnlegen(int projektId,
                                                    const QString &kz,
                                                    const QString &bezeichnung,
                                                    int bauteilId = -1);
    Q_INVOKABLE bool         grafikElementVerknuepfen(int elementId, int betriebsmittelId);
    Q_INVOKABLE bool         grafikElementEntknuepfen(int elementId);
    Q_INVOKABLE QVariantList betriebsmittelMitglieder(int betriebsmittelId);
    Q_INVOKABLE QVariantList betriebsmittelMitgliederMitPos(int betriebsmittelId) const;
    Q_INVOKABLE QString      betriebsmittelKz(int betriebsmittelId);
    Q_INVOKABLE QVariantMap  betriebsmittelInfo(int betriebsmittelId);
    Q_INVOKABLE bool         betriebsmittelHauptfunktionSetzen(int betriebsmittelId, int elementId);
    Q_INVOKABLE bool         betriebsmittelKzSetzen(int betriebsmittelId, const QString& neuKz);
    Q_INVOKABLE bool         betriebsmittelOrtSetzen(int betriebsmittelId, int ortId);
    Q_INVOKABLE bool         betriebsmittelBmkSynchronisieren(int betriebsmittelId);
    Q_INVOKABLE bool         grafikElementExtraMergeSetzen(int elementId, const QVariantMap& updates);
    Q_INVOKABLE QVariantList betriebsmittelHfListe(int projektId);
    Q_INVOKABLE int          letzteGrafikElementId(int seiteId) const;

    // Kontaktbelegung (Schütz/Relais – ein Eintrag pro Kontakt/Gruppe)
    Q_INVOKABLE QVariantList bauteilKontaktListe(int bauteilId) const;
    Q_INVOKABLE int          bauteilKontaktHinzufuegen(int bauteilId, const QString &symbolId,
                                                        const QString &bezeichnung,
                                                        const QString &pinBez);
    Q_INVOKABLE bool         bauteilKontaktAktualisieren(int id, const QString &symbolId,
                                                          const QString &bezeichnung,
                                                          const QString &pinBez);
    Q_INVOKABLE bool         bauteilKontaktLoeschen(int id);
    Q_INVOKABLE int          betriebsmittelBauteilId(int betriebsmittelId) const;

    // Steckverbinderliste + Belegungsplan (für ListenAnsicht)
    Q_INVOKABLE QVariantList steckverbinderListe(int projektId) const;
    Q_INVOKABLE bool         steckverbinderlisteCsvSpeichern(int projektId, const QString &pfad) const;
    Q_INVOKABLE QVariantList steckverbinderBelegungsplan(int projektId) const;
    Q_INVOKABLE bool         steckverbinderBelegungsplanCsvSpeichern(int projektId, const QString &pfad) const;

    // Steckverbinder-Bibliothek (steckverbinder_typ / _kabeleinf / _kontakt_typ)
    Q_INVOKABLE QVariantMap  steckverbinderTypLaden(int bauteilId) const;
    Q_INVOKABLE QVariantList steckverbinderBausteineListe() const;
    Q_INVOKABLE int          steckverbinderTypSpeichern(int bauteilId, int polzahl,
                                 const QString &ipGetrennt, const QString &ipGesteckt,
                                 const QString &kodierung, const QString &verriegelung,
                                 bool hatSchirmkontakt, bool geschirmt,
                                 const QString &montageform = QString());
    Q_INVOKABLE bool         steckverbinderTypLoeschen(int bauteilId);

    Q_INVOKABLE QVariantList steckverbinderKableinfLaden(int steckverbinderTypId) const;
    Q_INVOKABLE int          steckverbinderKableinfHinzufuegen(int steckverbinderTypId);
    Q_INVOKABLE bool         steckverbinderKableinfAktualisieren(int id, double aussenMin,
                                 double aussenMax, const QString &einfTyp,
                                 const QString &zugentlastung);
    Q_INVOKABLE bool         steckverbinderKableinfLoeschen(int id);

    // Steckverbinder-Positionen (ersetzt steckverbinder_kontakt_typ, Neukonzeption Jul 2026 —
    // verknüpft eine Pin-Nummer im Gehäuse mit einem wiederverwendbaren Kontakt-Typ)
    Q_INVOKABLE QVariantList steckverbinderPositionenLaden(int steckverbinderTypId) const;
    Q_INVOKABLE int          steckverbinderPositionHinzufuegen(int steckverbinderTypId, int kontaktTypId);
    Q_INVOKABLE bool         steckverbinderPositionSchirmkontaktSetzen(int positionId, bool istSchirmkontakt);
    Q_INVOKABLE bool         steckverbinderPositionKontaktTypAendern(int positionId, int neuerKontaktTypId);
    Q_INVOKABLE bool         steckverbinderPositionLoeschen(int id);
    Q_INVOKABLE bool         steckverbinderPositionIstPlatziert(int positionId) const;
    Q_INVOKABLE QVariantMap  steckverbinderPositionDetails(int positionId) const;

    // Gegenstelle einer Position über die Partner-Verknüpfung des Gerätekastens
    // auflösen (§8.3/§10.3, Standard-1:1-Positionsabgleich über position_nr).
    Q_INVOKABLE QVariantMap  steckverbinderGegenstelleLaden(int geraetekastenId, int positionNr) const;

    // Kontakt-Typ (Bibliothek, wiederverwendbarer Stift/Buchse-Katalogeintrag,
    // Neukonzeption Jul 2026 — konzept/features/45_steckverbinder.md §3.1/§5)
    Q_INVOKABLE QVariantMap  kontaktTypLaden(int bauteilId) const;
    Q_INVOKABLE QVariantList kontaktTypListe(const QString &geschlechtFilter = QString()) const;
    Q_INVOKABLE int          kontaktTypSpeichern(int bauteilId, const QString &geschlecht,
                                 double kontaktgroesse,
                                 double querschnittSteckseiteMin, double querschnittSteckseiteMax,
                                 double querschnittKabelMin, double querschnittKabelMax,
                                 double nennstromA, double nennspannungV,
                                 const QString &verbindungstechnik);

    // Konfektioniertes Kabel (Bauteil-Typ mit Steckern an einem oder beiden Enden)
    Q_INVOKABLE QVariantMap  konfkabelLaden(int bauteilId) const;
    Q_INVOKABLE int          konfkabelSpeichern(int bauteilId, int bauteilKabelId,
                                 int steckerABauteilId, int steckerBBauteilId, double laengeM);
    Q_INVOKABLE bool         konfkabelLoeschen(int bauteilId);

    // Ader-zu-Pin-Zuordnung am konfektionierten Kabel (§9.3) — Farbe/Querschnitt/
    // Bezeichnung werden nicht dupliziert, sondern per ader_nr live aus
    // bauteil_kabel_ader nachgeschlagen (siehe bauteilKabelAdernLaden()).
    Q_INVOKABLE QVariantList konfkabelPinZuordnungLaden(int konfkabelId, const QString &seite) const;
    Q_INVOKABLE int          konfkabelPinZuordnen(int konfkabelId, const QString &seite,
                                 int aderNr, int pinNr);
    Q_INVOKABLE bool         konfkabelPinZuordnungLoeschen(int id);

    // Klemmenplan: alle Klemmen aller Leisten, mit Gruppen-Headern.
    // Gibt abwechselnd {typ:"leiste",...} und {typ:"klemme",...} zurück.
    Q_INVOKABLE QVariantList klemmenplan(int projektId);

    // Klemmenplan als CSV-Datei speichern (UTF-8 mit BOM, Semikolon-getrennt).
    Q_INVOKABLE bool klemmenplanCsvSpeichern(int projektId, const QString &pfad);

    // CSV-Export der übrigen Listen (UTF-8 mit BOM, Semikolon-getrennt).
    Q_INVOKABLE bool stuecklisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool querverweislisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool aderlisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool aderSummenlisteCsvSpeichern(int projektId, const QString &pfad, bool jeAnlageOrt = false);
    Q_INVOKABLE bool kabellisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool bestellisteCsvSpeichern(int projektId, const QString &pfad);

    // Generischer PDF-Export für Listen (LISTEN-IDEEN-01): baut eine
    // einfache Tabelle (Titel, optional Projektname, Kopfzeile, Zeilen) als
    // Querformat-PDF. spalten = Kopfzeilentexte, zeilen = Liste von Zeilen,
    // jede Zeile eine Liste von Zellentexten (gleiche Länge wie spalten).
    // Formatierung/Datenauswahl (inkl. aktiver Filter/Sortierung) übernimmt
    // die aufrufende QML-Seite, damit ein PDF exakt das zeigt was am
    // Bildschirm sichtbar ist.
    // DOKU-PDF-05: Zellenaufbereitung der Listen für PDF-Ausgaben (eine Abbildung für Listen-Tabs und
    // Dokumentations-PDF). liste = Id aus listenPdfKatalog(); zeilen = Rohzeilen wie von den
    // Datenfunktionen geliefert (ggf. gefiltert/sortiert). Rückgabe {titel, spalten, zeilen}, leer bei
    // unbekannter Liste. optionen: {jeAnlageOrt} nur für "adersummenliste".
    Q_INVOKABLE QVariantList listenPdfKatalog();                       // [{id, titel}]
    Q_INVOKABLE QVariantMap  listenPdfTabelle(const QString &liste, const QVariantList &zeilen,
                                              const QVariantMap &optionen = QVariantMap());
    // Wie listenPdfTabelle, aber mit den ungefilterten Rohzeilen des Projekts (Standardansicht).
    Q_INVOKABLE QVariantMap listenPdfStandard(int projektId, const QString &liste,
                                              const QVariantMap &optionen = QVariantMap());

    Q_INVOKABLE bool listePdfSpeichern(const QString &titel, const QString &projektName,
                                        const QStringList &spalten, const QVariantList &zeilen,
                                        const QString &pfad);

    // Normblatt: alle Daten einer Seite für Canvas-Rendering laden.
    // Gibt {blattnummer, bezeichnung, anlageKuerzel, ortKuerzel, breiteMm, hoeheMm,
    //       normblattAnzeigen, hintergrundFarbe, aussenOverlay, titelblattVorlage,
    //       projektName, projektnummer, auftraggeber, auftragnehmer,
    //       bearbeiter, norm, erstelltAm, randLinksMm, randRechtsMm, randObenMm, randUntenMm} zurück.
    Q_INVOKABLE QVariantMap seiteBasisDaten(int seiteId);
    Q_INVOKABLE QVariantMap normblattDatenLaden(int seiteId);

    // Normblatt-Einstellungen für eine Seite speichern.
    // normblattId=-1 → kein benutzerdefiniertes Normblatt (titelblattVorlage greift).
    // DOKU-PDF-01: Seite im Dokumentations-PDF (Schaltplan-Abschnitt) enthalten?
    // Lesen über normblattDatenLaden()["inDokuPdf"].
    Q_INVOKABLE bool seiteInDokuPdfSetzen(int seiteId, bool inDokuPdf);
    // Normblatt je Seite (N-02): position fest|inhalt, format auto|a4..a0|canvas, ausrichtung links|rechts, rahmen
    Q_INVOKABLE bool seiteNormblattLageSetzen(int seiteId, const QString &position, const QString &format,
                                              const QString &ausrichtung, bool rahmen);
    // true, wenn die Elemente (+ Abstand, Ränder, Schriftfeld) nicht in das feste Format passen (Position "inhalt")
    Q_INVOKABLE bool normblattInhaltZuGross(int seiteId, const QString &format, const QString &vorlage);

    Q_INVOKABLE bool normblattEinstellungenSetzen(int seiteId, bool anzeigen,
                                                  const QString &hintergrundFarbe,
                                                  bool aussenOverlay,
                                                  const QString &titelblattVorlage,
                                                  int normblattId = -1);

    // Revisionsstatus einer Seite setzen (status: '', 'entwurf', 'freigegeben', 'veraltet')
    Q_INVOKABLE bool seiteRevisionSetzen(int seiteId, const QString &status, const QString &kennung);

    // Seite mit allen Grafik-Elementen duplizieren; gibt neue seiteId zurück (-1 bei Fehler)
    Q_INVOKABLE int seiteDuplizieren(int seiteId);

    // Normblatt-Vorlagen (projektübergreifend)
    Q_INVOKABLE QVariantList normblattVorlagenListe();
    Q_INVOKABLE int          normblattVorlageSpeichern(const QVariantMap &vorlage);
    Q_INVOKABLE bool         normblattVorlageLoeschen(int vorlageId);

    // Felder einer Vorlage laden / als Ganzes ersetzen (DELETE + INSERT in Transaction)
    // Logo der Vorlage (Bearbeiter-Logo, hat Vorrang vor dem Projekt-Logo) – BLATTVORLAGEN-01b
    Q_INVOKABLE bool         normblattVorlageLogoSpeichern(int vorlageId, const QString &pfad);
    Q_INVOKABLE bool         normblattVorlageLogoLoeschen(int vorlageId);
    // Vorlagen-Bibliothek: Quelle app-weiter Vorlagen; das Projekt hält immer eine eigene Kopie.
    // [{uid,name,beschreibung,art,breiteMm,hoeheMm,version,geaendertAm,hatLogo,felder,imProjekt(id|0)}]
    Q_INVOKABLE QVariantList vorlagenBibliothekListe();
    // Projektvorlage in die Bibliothek legen (neu, oder die verknüpfte Bibliotheksvorlage aktualisieren). Gibt uid zurück.
    Q_INVOKABLE QString      vorlageInBibliothekSpeichern(int vorlageId);
    // Bibliotheksvorlage als neue Projektvorlage übernehmen (-1 bei Fehler / schon im Projekt)
    Q_INVOKABLE int          vorlageAusBibliothekUebernehmen(const QString &uid);
    // Projektvorlage mit dem Stand der Bibliothek überschreiben (Name bleibt)
    Q_INVOKABLE bool         vorlageAusBibliothekAktualisieren(int vorlageId);
    // {status: lokal|aktuell|bibliothekNeuer|lokalGeaendert|beides|bibliothekFehlt, bibliothekName, bibliothekVersion, projektVersion}
    Q_INVOKABLE QVariantMap  vorlageBibliothekStatus(int vorlageId);
    Q_INVOKABLE bool         vorlageAusBibliothekLoeschen(const QString &uid);
    // ── Vorlagen-Austausch (S2, Strömling Manager M-11b): JSON-Bündel "stroemling-blattvorlagen" Version 1 ──────────
    // Exportiert Bibliotheksvorlagen (uids leer = alle) samt Logo. Rückgabe: {ok, anzahl, fehler}.
    Q_INVOKABLE QVariantMap vorlagenExportieren(const QString &pfad, const QStringList &uids);
    // Liest ein Bündel und vergleicht es mit der Vorlagen-Bibliothek, ohne etwas zu ändern. Rückgabe: {ok, fehler,
    // eintraege:[{uid, name, art, status: neu|gleich|abweichend, bundleVersion, lokaleVersion, lokalerName, vorschlag, aktionen}],
    // anzahlNeu, anzahlGleich, anzahlAbweichend}. Der Vergleich geht über den Inhalts-Hash (nicht Name/Beschreibung).
    Q_INVOKABLE QVariantMap vorlagenImportAnalysieren(const QString &pfad);
    // Führt die Entscheidungen aus (uid → anlegen|ersetzen|kopie|ueberspringen; fehlend = Vorschlag). Eine Transaktion,
    // vorher Sicherung der vorlagen.db. "ersetzen" setzt die Version über beide Stände, damit Projekte "Bibliothek neuer" sehen.
    Q_INVOKABLE QVariantMap vorlagenImportAusfuehren(const QString &pfad, const QVariantMap &entscheidungen);
    QString vorlagenSichern(const QString &anlass);
    // Daten fürs Deckblatt im Dokumentations-PDF; leere Map = keine Deckblattvorlage
    QVariantMap deckblattDatenLaden(int projektId, int vorlageId, const QString &titelzusatz, bool mitLogo);
    // Blattformat je Format-Modus in mm; (0,0) = auto/canvas (Groesse folgt den Elementen)
    static QSizeF blattFormatMm(const QString &modus, double seiteBreiteMm, double seiteHoeheMm);
    Q_INVOKABLE QVariantList normblattFelderLaden(int vorlageId);
    Q_INVOKABLE bool         normblattFelderSpeichern(int vorlageId, const QVariantList &felder);

    // ── Inbetriebnahme-Modus ─────────────────────────────────────
    // Alle BM mit BMK für ein Projekt laden; seiteId=-1 = alle Seiten.
    Q_INVOKABLE QVariantList ibnListeLaden(int projektId, int seiteId = -1);

    // IBN-Prüfumfang (konzept/features/55 §9, IBN-UMF-01): ausgeschlossene Kategorien/Symbole (und „Kabel nicht prüfen“) je Projekt.
    // Einträge: {art: "kategorie"|"symbol"|"kabel", schluessel}. Keine Einträge = alles wird geprüft.
    Q_INVOKABLE QVariantList ibnUmfangLaden(int projektId);
    // Ersetzt den Umfang vollständig. Nur in der Hauptkopie und ohne ausgegebene Kopien (Kopien erben ihn und dürfen ihn nicht ändern); ungültige Einträge → false, nichts geändert.
    Q_INVOKABLE bool         ibnUmfangSetzen(int projektId, const QVariantList &ausgeschlossen);
    // Für den Dialog: {kabelPruefen, kabelAnzahl, kategorien: [{kategorie, anzahl, ausgeschlossen, symbole: [{symbolId, name, anzahl, ausgeschlossen}]}]}
    // `anzahl` = verschiedene (Seite, BMK) unabhängig vom Ausschluss; Kategorie "" = Symbole ohne Kategorie (nur einzeln abwählbar).
    Q_INVOKABLE QVariantMap  ibnUmfangUebersicht(int projektId);

    // IBN-Eintrag für ein einzelnes BM (EP-Abschnitt, read-only).
    // Gibt {ibnId, status, bauteilId, geprueftVon, geprueftAm, notiz, symbolKategorie, felder}
    // oder leere Map zurück wenn kein Datensatz vorhanden.
    Q_INVOKABLE QVariantMap ibnEintragFuerBmk(int seiteId, const QString &bmk);

    // IBN-Eintrag speichern (INSERT OR UPDATE, Schlüssel: seiteId+bmk).
    Q_INVOKABLE bool ibnEintragSpeichern(int projektId, int seiteId,
                                         const QString &bmk,
                                         const QString &status,
                                         const QString &notiz,
                                         const QString &bauteilId,
                                         const QString &geprueftVon,
                                         const QString &geprueftAm);

    // Status eines einzelnen BM-Eintrags schnell aktualisieren.
    Q_INVOKABLE bool ibnStatusSetzen(int seiteId, const QString &bmk, const QString &status);

    // IBN-Feldvorlagen für eine Symbolkategorie laden.
    // Gibt [{id, feldname, label, feldtyp, optionen, einheit, pflichtfeld, reihenfolge}] zurück.
    Q_INVOKABLE QVariantList ibnFeldvorlagenLaden(const QString &symbolKategorie);

    // Alle IBN-Feldvorlagen laden (System + Benutzer) für den Feldeditor.
    // Gibt [{id, symbolKategorie, feldname, label, feldtyp, optionen, einheit,
    //        pflichtfeld, reihenfolge, erstelltVon}] zurück.
    Q_INVOKABLE QVariantList ibnAlleVorlagenLaden();

    // Alle bekannten IBN-Symbolkategorien (für ComboBox im Feldeditor).
    Q_INVOKABLE QVariantList ibnAlleKategorienLaden();

    // Benutzerdefiniertes Feld anlegen (erstellt_von = 'user').
    Q_INVOKABLE bool ibnFeldVorlageSpeichern(const QString &symbolKategorie,
                                              const QString &feldname,
                                              const QString &label,
                                              const QString &feldtyp,
                                              const QString &optionen,
                                              const QString &einheit,
                                              bool pflichtfeld);

    // Benutzerdefiniertes Feld löschen (nur erstellt_von = 'user' erlaubt).
    Q_INVOKABLE bool ibnFeldVorlageLoeschen(int id);

    // Feld innerhalb seiner symbol_kategorie umsortieren (IBN-05 Drag & Drop).
    // Gilt für System- und Nutzerfelder gleichermaßen – Reihenfolge ist reine
    // Anzeigepräferenz, unabhängig vom Bearbeiten/Löschen-Schreibschutz.
    Q_INVOKABLE bool ibnFeldVorlageUmordnen(int id, int neuerIndex);

    // Alle Gerätekästen des Projekts mit Seite + Mittelpunkt (für Seitenbaum).
    Q_INVOKABLE QVariantList geraetekastenListeMitPos(int projektId) const;

    // Alle Gerätekästen mit gegebenem BMK (für EP-Abschnitt "Weitere Kästen").
    Q_INVOKABLE QVariantList geraetekastenNachBmk(int projektId, const QString &bmk) const;

    // bauteil_id in extra_daten eines Gerätekasten-Elements setzen (bauteilId<=0 = entfernen).
    Q_INVOKABLE bool geraetekastenBauteilSetzen(int grafikElementId, int bauteilId);

    // Partner-Verknüpfung zwischen zwei Gerätekästen (Steckerpaar, §10.3) — symmetrisch:
    // A→B setzt automatisch auch B→A, ein vorheriger Partner auf beiden Seiten wird
    // aufgelöst (1:1-Beziehung). partnerGeraetekastenId liegt in extra_daten, kein neues Table.
    Q_INVOKABLE bool geraetekastenPartnerSetzen(int grafikElementId, int partnerGrafikElementId);
    Q_INVOKABLE bool geraetekastenPartnerAufheben(int grafikElementId);

    // Benutzerdefiniertes Feld aktualisieren (nur label, feldtyp, optionen, einheit, pflicht).
    Q_INVOKABLE bool ibnFeldVorlageAktualisieren(int id,
                                                  const QString &label,
                                                  const QString &feldtyp,
                                                  const QString &optionen,
                                                  const QString &einheit,
                                                  bool pflichtfeld);

    // Prüfprotokoll als PDF exportieren.
    // seiteId=-1 = alle Seiten des Projekts.
    Q_INVOKABLE bool ibnProtokollPdfSpeichern(int projektId, int seiteId,
                                               const QString &pfad);

    // Feldwerte eines IBN-Eintrags laden (alle gespeicherten Messwerte).
    // Gibt [{feldname, wert}] zurück.
    Q_INVOKABLE QVariantList ibnFeldwerteLaden(int inbetriebnahmeId);

    // Feldwerte eines IBN-Eintrags speichern (Upsert pro Feld).
    // felder: [{feldname, wert}]
    Q_INVOKABLE bool ibnFeldwerteAktualisieren(int inbetriebnahmeId,
                                                const QVariantList &felder);

    // Alle Kabel eines Projekts mit IBN-Status laden.
    // Gibt [{kabelId, bezeichnung, kabeltyp, aderzahl, querschnittMm2, laengeM,
    //        vonOrt, nachOrt, grafikElementId, status, notiz, geprueftVon, geprueftAm}] zurück.
    Q_INVOKABLE QVariantList ibnKabelListeLaden(int projektId);

    // Kabel-IBN-Eintrag speichern (INSERT OR UPDATE, Schlüssel: kabelId).
    Q_INVOKABLE bool ibnKabelSpeichern(int projektId, int kabelId,
                                       const QString &status,
                                       const QString &notiz,
                                       const QString &geprueftVon,
                                       const QString &geprueftAm);

    // Status eines Kabels schnell aktualisieren.
    Q_INVOKABLE bool ibnKabelStatusSetzen(int kabelId, const QString &status);

    // ── IBN-Pruefdurchgaenge (VERT-00, konzept/features/55 §8) ──
    // Hoechste Durchgangsnummer des Projekts (legt Durchgang 1 an, falls noetig).
    Q_INVOKABLE int ibnAktuellerDurchgang(int projektId);
    // Alle Durchgaenge, neuester zuerst: [{nr, bezeichnung, art, datum, faelligAm, bereich, erstelltAm, archiviert}]
    Q_INVOKABLE QVariantList ibnDurchgaengeLaden(int projektId);
    // Neuer Durchgang: archiviert die Staende im Bereich ([{anlage, ort, seite}], leer = ganzes Projekt)
    // in ibn_historie und setzt sie auf "offen" zurueck. Feldwerte bleiben nur bei werteVorbelegen.
    // Gibt die neue Nummer zurueck, -1 bei Fehler (Transaktion zurueckgerollt), -2 solange Kopien
    // ausgegeben sind, -3 in einer IBN-Kopie.
    Q_INVOKABLE int ibnDurchgangAnlegen(int projektId, const QString &bezeichnung,
                                        const QString &art, const QString &datum,
                                        const QString &faelligAm, const QVariantList &bereich,
                                        bool werteVorbelegen);
    // Archivierte Staende eines BM / Kabels, neuester Durchgang zuerst:
    // [{durchgangNr, durchgangBez, status, geprueftVon, geprueftAm, notiz, bauteilId, felder, archiviertAm}]
    Q_INVOKABLE QVariantList ibnHistorieFuerBmk(int seiteId, const QString &bmk);
    Q_INVOKABLE QVariantList ibnHistorieFuerKabel(int kabelId);

    // ── IBN-Kopien (VERT-02, konzept/features/55 §4.1a) ──
    // Register der Hauptkopie: [{id, kopieUuid, name, erstelltAm, hauptRevision, durchgangNr,
    //                            bereich, status, eingesammeltAm, dateiname, veraltet}], neueste zuerst
    Q_INVOKABLE QVariantList ibnKopieRegisterLaden(int projektId);
    // Warnungen vor dem Erstellen (doppelte Seitenschluessel, Bereichsueberlappung, selbst Kopie)
    Q_INVOKABLE QStringList  ibnKopiePruefen(int projektId, const QVariantList &bereich);
    // Kopie erstellen (VACUUM INTO + Markierung); zielOrdner leer = <Projektordner>/ibn_kopien.
    // Gibt {ok, pfad, kopieUuid, kopieId} oder {ok:false, fehler} zurueck.
    Q_INVOKABLE QVariantMap  ibnKopieErstellen(int projektId, const QString &name,
                                               const QVariantList &bereich,
                                               const QString &zielOrdner = QString());
    // 'verworfen' / 'ausgegeben' (Rueckgaengig); eingesammelte Kopien bleiben unveraendert
    Q_INVOKABLE bool ibnKopieStatusSetzen(int kopieId, const QString &status);
    // Vom Overlay-Import benutzt (VERT-04)
    bool ibnKopieEingesammeltMarkieren(const QString &kopieUuid);
    // Schaltplan trotz ausgegebener Kopien freigeben: erhoeht haupt_revision (Kopien gelten als
    // veraltet). Gibt die neue Revision zurueck, -1 wenn nicht moeglich/noetig.
    Q_INVOKABLE int ibnSchaltplanOverride();

    // ── Overlay (VERT-03, konzept/features/55 §4.2) ──
    // Nur in einer IBN-Kopie: schreibt die IBN-Staende im Bereich der Kopie als JSON
    // (<kopie>.strl-overlay neben der Kopie, oder zielPfad). Gibt {ok, pfad, anzahlBm, anzahlKabel}
    // oder {ok:false, fehler} zurueck.
    Q_INVOKABLE QVariantMap ibnOverlayExportieren(const QString &zielPfad = QString());
    // Stand des Overlay-Exports in einer IBN-Kopie: {istKopie, exportiertAm, aenderungenSeither,
    // ausserhalb (Eintraege ausserhalb des Kopie-Bereichs, nicht exportierbar), gesamt}
    Q_INVOKABLE QVariantMap ibnOverlayStatus();
    // In einer IBN-Kopie duerfen nur Eintraege im Bereich der Kopie bearbeitet werden
    // (in der Hauptkopie immer true).
    Q_INVOKABLE bool ibnImBereich(int seiteId);
    Q_INVOKABLE bool ibnKabelImBereich(int kabelId);
    // ── Overlay-Import (VERT-04, konzept/features/55 §4.3), nur in der Hauptkopie ──
    // Analyse ohne Schreiben: {ok, fehler, kopie{id,name,status,veraltet}, warnungen[],
    //   anzahlBm, anzahlKabel, uebernehmen, unveraendert, konflikte[{key,typ,label,haupt{..},kopie{..}}],
    //   nichtZuordenbar[{label,grund}], ausserhalbBereich[{label}]}
    Q_INVOKABLE QVariantMap ibnOverlayPruefen(const QString &pfad);
    // Import: entscheidungen = {key: "kopie"|"haupt"} fuer Konflikte (fehlend = "haupt");
    // ausserhalbZulassen uebernimmt auch Eintraege ausserhalb des Kopie-Bereichs.
    // Markiert die Kopie als eingesammelt. Gibt {ok, fehler, uebernommen, uebersprungen, nichtZuordenbar[]}.
    Q_INVOKABLE QVariantMap ibnOverlayImportieren(const QString &pfad, const QVariantMap &entscheidungen,
                                                  bool ausserhalbZulassen = false);
    // *.strl-overlay im Standardordner <Projektordner>/ibn_kopien: [{pfad, name, geaendert}]
    Q_INVOKABLE QVariantList ibnOverlayDateienFinden();
    // Bereichsfilter (Liste von {anlage, ort, seite}; leer = ganzes Projekt)
    static bool ibnBereichPasst(const QVariantList &bereich, const QString &anlage,
                                const QString &ort, const QString &seite);

    // Projekt-Metadaten (Schriftfeld-Felder) speichern.
    Q_INVOKABLE bool projektMetaSpeichern(int projektId,
                                          const QString &name,
                                          const QString &projektnummer,
                                          const QString &auftraggeber,
                                          const QString &auftragnehmer,
                                          const QString &bearbeiter);

    // Kunden-Logo je Projekt (Feldtyp logo_kunde) – BLATTVORLAGEN-02
    Q_INVOKABLE bool    projektKundenLogoSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE QString projektKundenLogoDataUrl(int projektId);
    Q_INVOKABLE bool    projektKundenLogoLoeschen(int projektId);

    // Klemmen einer Klemmenleiste für den Bauteil-Bereich im Seitenbaum.
    // Gibt [{id, nummer, sortierung, bauteilId, bauteilKlemmeId, bezeichnung, leisteBmk}] zurück.
    Q_INVOKABLE QVariantList klemmenFuerLeiste(int leisteId) const;

    // Anschlüsse eines Bauteil-Klemmen-Eintrags für den Seitenbaum.
    // Gibt [{bezeichnung, seite, ebene}] zurück – berechnet aus bauteil_klemme-Feldern.
    Q_INVOKABLE QVariantList anschluesseFuerKlemme(int bauteilId) const;

    // Bereits platzierte klemme_anschluss-Elemente (projektübergreifend in dieser DB).
    Q_INVOKABLE QVariantList platzierteKlemmenAnschluesse() const;
    Q_INVOKABLE bool         klemmeAnschlussIstPlatziert(int klemmeId, const QString &anschlussBezeichnung) const;
    Q_INVOKABLE QVariantMap  klemmeAnschlussPosition(int klemmeId, const QString &anschlussBezeichnung) const;
    // Leisten-Info für eine Klemme (für Seitenbaum-Navigation vom Canvas).
    // Gibt {leisteId, bezeichnung, bmkKurz} zurück, leere Map wenn nicht gefunden.
    Q_INVOKABLE QVariantMap  leisteInfoFuerKlemme(int klemmeId) const;
    // Alle Klemmen-IDs je Stegbrücke im Projekt (für Potenzialverfolgung KLEMME-NET-01).
    // Gibt [{stegId, ebene, klemmeIds:[id,...]}] zurück.
    Q_INVOKABLE QVariantList klemmenStegbrueckenGruppen(int projektId) const;
    // Interne Ebenen-Brücken aller platzierten Klemmen im Projekt (bauteil_klemme_bruecke).
    // Gibt [{klemmeId, vonEbene, nachEbene}] zurück (ist_pe_fuss-Einträge ausgeschlossen).
    Q_INVOKABLE QVariantList klemmenInterneBruecken(int projektId) const;
    // Alle klemme_anschluss-Platzierungen im Projekt (alle Seiten).
    // Gibt [{seiteId, klemmeId, anschlussBezeichnung}] zurück.
    Q_INVOKABLE QVariantList klemmenAnschlussAlleSeiten(int projektId) const;

    // Klemmlistenauszug: Von/Nach je Anschluss mit Verbindungsdaten (KLISTE-01).
    // Gibt flache Liste: "leiste", "steg", "anschluss"-Zeilen.
    Q_INVOKABLE QVariantList klemmlistenauszug(int projektId);
    Q_INVOKABLE bool         klemmlistenauszugCsvSpeichern(int projektId, const QString &pfad);

    // Kabeldefinitionslinie – neues Kabel anlegen und grafik_element verknüpfen.
    // Gibt die neue kabel-ID zurück (>0) oder -1 bei Fehler.
    Q_INVOKABLE int kabelAnlegen(int projektId, const QString &bezeichnung,
                                 const QString &kabeltyp, int aderzahl,
                                 double querschnittMm2, int grafikElementId,
                                 const QString &vonOrt = QString(),
                                 const QString &nachOrt = QString());

    // Ader einem Kabel zuordnen: verbindung_id + ggf. Kabellinie-Grafikelement zu kabel_ader schreiben.
    // Legt eine neue kabel_ader-Zeile an oder aktualisiert eine bestehende.
    // kabellinieGrafikElementId = 0 → kabellinie_grafik_element_id bleibt unverändert / NULL.
    // aderKey (KABEL-UEBERARBEITUNG-01/PROPAGATION-07): der lokale NETZ-02-
    // Schlüssel des konkreten Kreuzungspunkts (nicht das ganze elektrische
    // Netz) — auf jeder Kontaktseite liegt physisch eine andere Ader, auch
    // wenn beide Seiten dieselbe verbindung_id (Potenzial) teilen. Optional
    // mit Default "" für bestehende QML-Aufrufer (AderKreuzungPicker/
    // AderzuordnungDialog, aktuell deaktiviert), die ihn (noch) nicht
    // mitgeben.
    Q_INVOKABLE bool kabelAderZuordnen(int kabelId, int aderNr,
                                       const QString &farbe,
                                       const QString &farbe2,
                                       const QString &bezeichnung,
                                       int verbindungId,
                                       int kabellinieGrafikElementId = 0,
                                       const QString &aderKey = QString());

    // KABEL-ADERFARBE-PROPAGATION-03: hält kabel_ader für EINE Kabellinie
    // synchron mit ihren tatsächlich aktuellen Kreuzungen (aufgerufen aus
    // CanvasCacheHandler.qml::kabelAderSynchronisieren() bei jedem
    // grafikSpeichernJetzt()). "aktive" = die von
    // CanvasGeometrie.qml::kabelAktiveAderZuordnungen() berechneten,
    // gerade wirklich zutreffenden Zuordnungen dieser Linie
    // ([{aderNr, farbe, farbe2, bezeichnung, verbindungId}, ...]).
    // Adern, die bisher dieser Linie zugeordnet waren, aber nicht mehr in
    // "aktive" auftauchen (Linie verschoben, kreuzt nichts mehr), werden
    // freigegeben (kabellinie_grafik_element_id/verbindung_id → NULL,
    // Zeile bleibt für kabelFreieAderLaden() bestehen). kabel_ader ist
    // kabelId+aderNr-eindeutig (nicht pro Linie) — ein Kabel kann nur an
    // EINER Stelle je Ader tatsächlich angeschlossen sein.
    Q_INVOKABLE bool kabelAderLinieSynchronisieren(int kabelId, int kabellinieGrafikElementId,
                                                   const QVariantList &aktive);

    // KABEL-ADERFARBE-PROPAGATION-04: seitenübergreifende Ader-Poolung für
    // EIN Kabel. Sammelt alle Kabellinie-Grafikelemente dieser kabelId über
    // ALLE Seiten (nicht nur die gerade offene), berechnet pro Seite deren
    // Kreuzungen mit den dort bereits persistierten Verbindungen
    // (verbindung/verbindung_segment — 1:1 dieselbe Geometrie- und
    // Stabiler-Punkt-Logik wie pdfLeitungenSammeln() in Database_PDF.cpp),
    // löst explizite aderZuordnung-Einträge zuerst auf, danach (KABEL-
    // ADERKEY-DUPLIKAT-01) bereits für denselben aderKey persistierte
    // Adernummern (Stabilität über mehrere Resyncs hinweg — sonst bekäme
    // ein unveränderter Kreuzungspunkt bei jedem Resync eine neue Nummer,
    // während die alte Zeile als Leiche liegen bleibt), und vergibt erst
    // für wirklich neue Kreuzungen fortlaufend die nächste über das GANZE
    // Kabel noch freie Adernummer (statt pro Linie unabhängig bei 1 neu zu
    // zählen — verhindert die doppelte Ader-Vergabe bei mehrseitigen
    // Kabeln). Persistiert je Linie über die bestehende
    // kabelAderLinieSynchronisieren(), räumt danach verwaiste
    // Duplikat-Zeilen auf (gleicher aderKey wie eine noch verlinkte Zeile).
    // Aufgerufen aus CanvasCacheHandler.qml::kabelAderSynchronisieren() bei
    // jedem grafikSpeichernJetzt(), für jede kabelId der gerade gespeicherten
    // Seite.
    Q_INVOKABLE bool kabelAderProjektweitSynchronisieren(int kabelId);

    // Kabeldetails + Adern für das EigenschaftenPanel laden.
    // Sucht das Kabel über grafik_element.kabel_id (KABEL-UEBERARBEITUNG-01
    // Punkt 3, vorher json_extract auf extra_daten).
    // Gibt {id, bezeichnung, kabeltyp, aderzahl, querschnittMm2, grafikElementId,
    //       vonOrt, nachOrt, bauteilKabelId,
    //       adern:[{aderNr, farbe, farbe2, bezeichnung, verbindungId, kabellinieGrafikElementId}]} zurück.
    Q_INVOKABLE QVariantMap kabelLinieDetails(int grafikElementId);

    // Alle Kabellinie-Grafikelemente eines Kabels (für KABEL-LINIEN-Abschnitt im EP).
    // Gibt [{grafikElementId, seiteId, seiteBezeichnung, blattnummer, weltX, weltY,
    //       aderVon, aderBis, aderAnzahl}] zurück, sortiert nach kleinster
    // zugeordneter Adernnummer (aderVon).
    Q_INVOKABLE QVariantList kabelAlleLinienLaden(int kabelId);

    // Adern eines Kabels, die aktuell an KEINER Kabellinie wirklich anliegen
    // (Roster minus tatsächlich zugeordnete Adern, s. Database_Kabel.cpp für
    // Details/Korrekturhistorie). Für KABEL-ADERN-Abschnitt im EP.
    // Gibt [{aderNr, farbe, farbe2, bezeichnung}] zurück.
    Q_INVOKABLE QVariantList kabelFreieAderLaden(int kabelId);

    // KABEL-ADERFARBE-PROPAGATION-04: alle kabel_ader-Zeilen eines Kabels,
    // zugeordnet UND frei (anders als kabelFreieAderLaden/
    // kabelAderFuerLinieLaden, die je nur eine Teilmenge liefern). Für den
    // gecachten kabelId→aderKey→Ader-Lookup (PROPAGATION-07: lokaler
    // Schlüssel statt verbindung_id, s. kabelAderZuordnen()), den Canvas-
    // Rendering/EP-Anzeige als Vorrang vor dem lokalen Positions-Fallback
    // nutzen. Gibt [{aderNr, farbe, farbe2, bezeichnung, verbindungId,
    //        kabellinieGrafikElementId, aderKey}] zurück.
    Q_INVOKABLE QVariantList kabelAlleAderLaden(int kabelId);

    // Adern einer Kabellinie (für KABEL-ADERN-Abschnitt im EP).
    // Gibt [{aderNr, farbe, farbe2, bezeichnung, verbindungId}] zurück.
    Q_INVOKABLE QVariantList kabelAderFuerLinieLaden(int kabellinieGrafikElementId);

    // Alle Kabel eines Projekts für die Kabelliste.
    // Gibt [{id, bezeichnung, kabeltyp, aderzahl, querschnittMm2, laengeM,
    //        vonOrt, nachOrt, grafik_element_id, bauteilKabelId}] zurück.
    // KABEL-BAUTEIL-BMK-UEBERNAHME-01: bauteilKabelId ergänzt, damit
    // KabellinieDialog.qml beim BMK-Auto-Erkennen eines bestehenden Kabels
    // auch dessen Bauteil-Kabel-Verknüpfung übernehmen kann.
    Q_INVOKABLE QVariantList kabelListe(int projektId);

    // Wie kabelListe, aber mit seiteId, blattnr, seiteBez, weltX, weltY der primären Kabellinie.
    Q_INVOKABLE QVariantList kabelListeMitPos(int projektId) const;

    // Alle Kabellinien eines Kabels mit Seite und Mittelpunktposition.
    Q_INVOKABLE QVariantList kabellinienMitPos(int kabelId) const;

    // Alle Kabel eines Projekts mit Ader-Unterzeilen für die zweistufige Kabelliste.
    // Gibt [{id, bezeichnung, kabeltyp, aderzahl, querschnittMm2, laengeM, vonOrt, nachOrt,
    //        linienAnzahl, adern:[{nr, farbe, farbe2, bezeichnung, blattnummer, seitenBezeichnung, netz}]}] zurück.
    Q_INVOKABLE QVariantList kabelListeAufgeschluesselt(int projektId);

    // Kabel-Metadaten aktualisieren (nach Änderung im EigenschaftenPanel).
    Q_INVOKABLE bool kabelMetaAktualisieren(int kabelId, const QString &bezeichnung,
                                            const QString &kabeltyp, int aderzahl,
                                            double querschnittMm2,
                                            const QString &vonOrt = QString(),
                                            const QString &nachOrt = QString());

    // Alle kabel_adern eines Projekts mit verbindung_id für Verdrahtungsweg-Berechnung.
    // Gibt [{kabelId, aderNr, verbindungId, kabellinieGrafikElementId}] zurück.
    Q_INVOKABLE QVariantList kabelAderListeMitVerbindung(int projektId);
    // Seiten (IDs), auf denen Kabellinien verdrahteter Adern liegen (Von/Nach-Berechnung aller Seiten)
    Q_INVOKABLE QVariantList kabelSeitenIds(int projektId);


    // Von/Nach-Gerät:Pin-Endpunkte für eine Liste kabel_adern speichern (Bulk-Update).
    // adern: [{kabelId, aderNr, von, nach}]
    Q_INVOKABLE bool kabelAderEndpunkteBulkSetzen(int projektId, const QVariantList &adern);

    // Von/Nach-Endpunkte für alle kabel_adern eines Projekts aus der DB berechnen und speichern.
    // Läuft ohne Canvas; nutzt verbindung_segment + grafik_element für geometrisches Matching.
    Q_INVOKABLE bool kabelAderEndpunkteBerechnenUndSpeichern(int projektId);

    // Kabel samt Adern und grafik_element löschen (wird beim Löschen der Kabellinie gerufen).
    Q_INVOKABLE bool kabelLoeschen(int kabelId);

    // Alle Bauteil-Kabel aus der Bibliothek für den Picker-Dialog.
    // Gibt [{id, bauteilId, bezeichnung, kabeltyp, aderzahl, querschnittMm2,
    //        adern:[{farbe, farbe2, querschnittMm2}]}] zurück.
    Q_INVOKABLE QVariantList bauteilKabelListe();

    // Vollständige Ader-Liste eines Kabeltyps (inkl. ader_nr, nummer, bezeichnung) —
    // Grundlage für den Live-Nachschlag der Litzendaten in der Konfkabel-Pin-Zuordnung
    // (konzept/features/45_steckverbinder.md §9.3).
    Q_INVOKABLE QVariantList bauteilKabelAdernLaden(int kabelId) const;

    // Bauteil-Kabel einer Kabellinie zuweisen (bauteilKabelId > 0) oder aufheben (0).
    // Kopiert bei Zuweisung: kabeltyp, aderzahl, querschnitt_mm2 aus bauteil_kabel.
    // Gibt die neuen Metadaten als Map zurück (kabeltyp, aderzahl, querschnittMm2).
    Q_INVOKABLE QVariantMap kabelBauteilKabelSetzen(int kabelId, int bauteilKabelId);

    // ── Makros ───────────────────────────────────────────────────────────────
    // Makrokasten-Inhalt sammeln und als Makro speichern.
    // grafikElementId = ID des Makrokasten-Elements.
    // Gibt makro.id zurück (>0) oder -1 bei Fehler.
    Q_INVOKABLE int makroSpeichern(int grafikElementId, int seiteId);

    // Alle Makros für die Seitenleiste.
    // Gibt [{id, name, beschreibung, kategorie, elementAnzahl}] zurück.
    Q_INVOKABLE QVariantList makroListe();

    // Makro-Elemente als normierte Koordinaten für die Vorschau (read-only).
    // Gibt [{typ, x1, y1, x2, y2}] zurück.
    Q_INVOKABLE QVariantList makroElementeVorschau(int makroId);

    // Makro auf einer Seite einfügen.
    // offsetX/Y: Einfügepunkt = obere linke Ecke des Makrokastens.
    // Gibt die IDs der neu angelegten grafik_element-Einträge zurück.
    Q_INVOKABLE QVariantList makroElementeEinfuegen(int makroId, int seiteId,
                                                     double offsetX, double offsetY);

    // Makro löschen (makro_element per CASCADE).
    Q_INVOKABLE bool makroLoeschen(int makroId);
    // ── Makro-Austausch (S3, Strömling Manager M-11b): JSON-Bündel "stroemling-makros" Version 1 ──────────────────
    // Gleiche Bedienung wie der Vorlagen-Austausch; Identität = makro.uid (seit S3), Gleichheit über Inhalts-Hash.
    Q_INVOKABLE QVariantMap makrosExportieren(const QString &pfad, const QStringList &uids);
    Q_INVOKABLE QVariantMap makrosImportAnalysieren(const QString &pfad);
    // Aktionen je uid: anlegen|ersetzen|kopie|ueberspringen; eine Transaktion, vorher Sicherung der makros.db
    Q_INVOKABLE QVariantMap makrosImportAusfuehren(const QString &pfad, const QVariantMap &entscheidungen);
    QString makrosSichern(const QString &anlass);

    // Makro-Metadaten (Name, Beschreibung, Kategorie) aktualisieren.
    Q_INVOKABLE bool makroMetaAktualisieren(int makroId, const QString &name,
                                             const QString &beschreibung,
                                             const QString &kategorie);

    // ── Zwischenablage (COPY-CROSS-01) ──────────────────────────────────────
    // Bereitet kopierte Elemente für den Export über die System-Zwischenablage
    // vor: betriebsmittel_id-Verknüpfungen werden als bauteilSnapshot in
    // extra_daten eingebettet (wie bei Makros), da die numerische ID im
    // Zielprojekt/-instanz nicht existiert. klemme_anschluss-Geist-Konvertierung
    // läuft bereits generisch beim Einfügen (CanvasAktionenHandler.qml,
    // _duplizierAnzahlPlatzieren) und braucht hier keine Behandlung.
    Q_INVOKABLE QVariantList elementeFuerExportSanitisieren(const QVariantList &elemente);

    // Kehrseite beim Einfügen aus einem ANDEREN Projekt: bauteilSnapshot wird
    // aufgelöst (Bauteil in bibliothek.db finden/anlegen, betriebsmittel im
    // Zielprojekt neu anlegen), betriebsmittel_id entsprechend ersetzt.
    Q_INVOKABLE QVariantList elementeFuerImportSanitisieren(const QVariantList &elemente, int seiteId);

    // ── Wiki ─────────────────────────────────────────────────────────────────
    // Kategorien
    Q_INVOKABLE QVariantList wikiAlleKategorien();
    Q_INVOKABLE int          wikiKategorieAnlegen(const QString &name, const QString &beschreibung);
    Q_INVOKABLE bool         wikiKategorieUmbenennen(int id, const QString &name, const QString &beschreibung);
    Q_INVOKABLE bool         wikiKategorieLoeschen(int id);
    Q_INVOKABLE bool         wikiKategorieSortierungSetzen(int id, int sortierung);

    // Artikel
    Q_INVOKABLE QVariantList wikiArtikelFuerKategorie(int kategorieId);
    Q_INVOKABLE QVariantMap  wikiArtikelLaden(int id);
    Q_INVOKABLE int          wikiArtikelAnlegen(int kategorieId, const QString &titel);
    Q_INVOKABLE bool         wikiArtikelSpeichern(int id, const QString &titel,
                                                   const QString &inhalt, const QString &tags);
    Q_INVOKABLE bool         wikiArtikelLoeschen(int id);

    // Bilder
    Q_INVOKABLE QVariantList wikiBilderFuerArtikel(int artikelId);
    Q_INVOKABLE int          wikiBildHinzufuegen(int artikelId, const QString &pfad);
    Q_INVOKABLE bool         wikiBildLoeschen(int id);
    Q_INVOKABLE QString      wikiBildAlsTempDatei(int id);

    // Volltext-Suche (FTS5)
    Q_INVOKABLE QVariantList wikiSuchen(const QString &suchbegriff);

    // Export / Import (klassisch)
    Q_INVOKABLE bool wikiExportJson(const QString &pfad);
    Q_INVOKABLE bool wikiImportJson(const QString &pfad, bool mergeMode);

    // Bundle-System (TB-2)
    // Spielt ein Bundle ein (Datei- oder Qt-Ressourcenpfad).
    // Gibt {erfolg, neu, aktualisiert, uebersprungen, meldung} zurück.
    Q_INVOKABLE QVariantMap wikiBundleAnwenden(const QString &pfad);
    // Exportiert gewählte Kategorien als Bundle-JSON.
    Q_INVOKABLE bool wikiBundleExportieren(const QString &pfad,
                                            const QString &kennung,
                                            const QString &titel,
                                            int version,
                                            const QVariantList &kategorieIds);
    // Setzt von_nutzer_geaendert = 0 für einen Bundle-Artikel (erzwingt Update beim nächsten Import).
    Q_INVOKABLE bool wikiBundleArtikelZuruecksetzen(int id);
    // Gibt alle aktiven Bundles zurück: [{kennung, version}]
    Q_INVOKABLE QVariantList wikiBundleAktiveListe();

    // ── SPS/PLS-Integration ──────────────────────────────────────────────────
    // Rack (Hardware-Einheit: ein S7-300-Baugruppenträger oder ein PLS-Rack)
    Q_INVOKABLE QVariantList spsRackListe(int projektId);
    Q_INVOKABLE int          spsRackAnlegen(int projektId, int rackNr,
                                             const QString &systemTyp,
                                             const QString &bezeichnung,
                                             const QString &hersteller);
    Q_INVOKABLE bool         spsRackAktualisieren(int id, int rackNr,
                                                   const QString &systemTyp,
                                                   const QString &bezeichnung,
                                                   const QString &beschreibung,
                                                   const QString &hersteller);
    Q_INVOKABLE bool         spsRackLoeschen(int id);

    // Baugruppe (Steckbaugruppe / I/O-Modul in einem Slot)
    Q_INVOKABLE QVariantList spsBaugruppeListe(int rackId);
    Q_INVOKABLE int          spsBaugruppeAnlegen(int rackId, int slot,
                                                  const QString &typ,
                                                  const QString &bezeichnung,
                                                  int kanaele, int adressByteStart);
    Q_INVOKABLE bool         spsBaugruppeAktualisieren(int id, int slot,
                                                        const QString &typ,
                                                        const QString &bezeichnung,
                                                        const QString &artikelNr,
                                                        int kanaele,
                                                        const QString &datentypStandard,
                                                        int adressByteStart,
                                                        const QString &kommentar);
    Q_INVOKABLE bool         spsBaugruppeLoeschen(int id);
    Q_INVOKABLE bool         spsBaugruppeBetriebsmittelSetzen(int baugruppeId, int betriebsmittelId);

    // Kanal (einzelner I/O-Punkt / SPS-Variable / PLS-Messpunkt)
    // Gibt [{id, adresse, adress_typ, byte_nr, bit_nr, datentyp, variablenname, kommentar,
    //         baugruppe_id, rack_id, system_typ, rack_nr, slot, kanal_nr,
    //         grafik_element_id, pls_einheit, pls_bereich_min, pls_bereich_max,
    //         pls_alarm_ll, pls_alarm_lo, pls_alarm_hi, pls_alarm_hh,
    //         pls_hart_adresse, pls_protokoll}] zurück.
    Q_INVOKABLE QVariantList spsKanalListe(int projektId);
    Q_INVOKABLE QVariantList spsKanalListeFuerBaugruppe(int baugruppeId);
    Q_INVOKABLE int          spsKanalAnlegen(int projektId, int baugruppeId, int kanalNr,
                                              const QString &adressTyp, int byteNr, int bitNr,
                                              const QString &datentyp,
                                              const QString &variablenname,
                                              const QString &kommentar);
    // felder: adress_typ, byte_nr, bit_nr, datentyp, variablenname, kommentar,
    //          pls_einheit, pls_bereich_min, pls_bereich_max,
    //          pls_alarm_ll, pls_alarm_lo, pls_alarm_hi, pls_alarm_hh,
    //          pls_hart_adresse, pls_protokoll  (fehlende Keys bleiben unverändert)
    Q_INVOKABLE bool         spsKanalAktualisieren(int id, const QVariantMap &felder);
    Q_INVOKABLE bool         spsKanalLoeschen(int id);

    // Formatierte Adresse: SPS → "E0.0", PLS → "R1 S3 K12"
    Q_INVOKABLE QString      spsKanalAdresse(int kanalId);

    // Canvas-Element ↔ Kanal verknüpfen / trennen
    Q_INVOKABLE bool         spsKanalElementZuweisen(int kanalId, int elementId);
    Q_INVOKABLE bool         spsKanalElementEntfernen(int kanalId);

    // Kanal-Info für ein Canvas-Element (leer wenn keiner zugewiesen)
    Q_INVOKABLE QVariantMap  spsKanalFuerElement(int elementId);

    // Vollständige I/O-Liste für Export/Anzeige
    Q_INVOKABLE QVariantList spsIOListe(int projektId);

    // I/O-Liste als CSV mit der Standard-Konfiguration (UTF-8 mit BOM, Semikolon-getrennt)
    Q_INVOKABLE bool         spsIOListeCsvSpeichern(int projektId, const QString &pfad);

    // SPS-EXPORT-02: frei konfigurierbarer CSV-Export (Database_SpsExport.cpp).
    // konfigJson: {spalten:[{feld,titel,wert?}], trennzeichen, dezimal, kopfzeile, bom,
    //              anfuehrung:"immer"|"bei_bedarf", filter:{system,rack,signal,belegung}}
    Q_INVOKABLE QVariantList spsExportFeldKatalog();    // [{feld, titel, gruppe, standard}]
    Q_INVOKABLE QString      spsExportStandardKonfig(); // JSON
    // SPS-EXPORT-04: Feldschlüssel, die für eine Signalart (DI/DO/AI/AO) nicht sinnvoll sind –
    // Vorschlag beim Anlegen eines eigenen Schemas. Konfig kann zusätzlich
    // schemata:{"AI":{spalten:[…]}}, ausgabe:"einzeln"|"eine_datei" enthalten.
    Q_INVOKABLE QStringList  spsExportSchemaIrrelevanteFelder(const QString &signal);
    // SPS-EXPORT-05: vorhandene Anlagen-/Ort-Kürzel der Kanäle mit Schaltplan-Element (Filterauswahl)
    // → {anlagen:[kuerzel], orte:[kuerzel]}
    Q_INVOKABLE QVariantMap  spsExportFilterWerte(int projektId);
    // {text (alle Schemata, Abschnitte durch Leerzeile), zeilen (Gesamtzahl nach Filter), fehler,
    //  gruppen:[{schema, zeilen, text}]}; maxZeilen < 0 = alle (je Schema begrenzt)
    Q_INVOKABLE QVariantMap  spsExportVorschau(int projektId, const QString &konfigJson, int maxZeilen);
    Q_INVOKABLE bool         spsExportCsvSpeichern(int projektId, const QString &pfad,
                                                   const QString &konfigJson);
    // ── CSV-Import (SPS-IMPORT-01, Database_SpsImport.cpp) ──────────────────
    // Datei lesen: {fehler, trennzeichen, kopf[], zeilen, beispiel[[..]], vorschlag[] (Feld je Spalte)}
    Q_INVOKABLE QVariantMap  spsImportLesen(const QString &pfad);
    // Trockenlauf bzw. Ausführung (eine Transaktion). konfigJson s. Database_SpsImport.cpp.
    // Bericht: {fehler, neueRacks, neueBaugruppen, neueKanaele, aktualisiert, uebersprungen,
    //           fehlerhaft, zeilenGesamt, meldungen:[{zeile,text,fehler}], ausgefuehrt,
    //           kanalVorschau:[{zeile,system,adresse,variable,aktion(neu|update|abweichung|skip),detail}], abweichend,
    //           racksNeu:[rack_nr], racksBetroffen:[rack_nr]}
    Q_INVOKABLE QVariantMap  spsImportPruefen(int projektId, const QString &pfad, const QString &konfigJson);
    Q_INVOKABLE QVariantMap  spsImportAusfuehren(int projektId, const QString &pfad, const QString &konfigJson);

    // PDF (SPS-EXPORT-03): gleiche Spalten/Filter/Reihenfolge wie das CSV, Aufbau über
    // listePdfSpeichern(); Trennzeichen/Anführung/BOM/Kopfzeile-Option gelten nur für CSV.
    Q_INVOKABLE bool         spsExportPdfSpeichern(int projektId, const QString &projektName,
                                                   const QString &pfad, const QString &konfigJson);

    // Element-IDs mit SPS-Konflikt (Canvas-Markierung): Element mit mehr als einem
    // Kanal ODER Element, dessen Kanal eine Adresse mit einem anderen Kanal teilt
    // (SPS-INTEGRITAET-01, Geltungsbereich der Adresse: je Rack).
    Q_INVOKABLE QVariantList spsKonfliktElementIds(int projektId);

    // Vorab-Prüfung für die Dialoge: kollidiert diese Adresse mit einem anderen Kanal?
    // ausschlussId = der gerade bearbeitete Kanal (0 beim Anlegen).
    // Rückgabe: {} wenn frei, sonst {kanalId, adresse, variablenname}.
    Q_INVOKABLE QVariantMap  spsKanalKonflikt(int projektId, int baugruppeId, int kanalNr,
                                               const QString &adressTyp, int byteNr, int bitNr,
                                               const QString &datentyp, int ausschlussId);

    // ── Mikrokontroller-Pinbelegung (MCU-PINBELEGUNG-01, Database_Mikrocontroller.cpp) ──
    // Eine Zeile je Board-Pin × angeschlossenem Pin (freie Pins: eine Zeile mit istFrei).
    // [{elementId, boardBmk, boardName, pin, netz, verbundenBmk, verbundenSymbol, verbundenPin,
    //   istFrei, defineName, defineWert, seiteId, blattnr, seiteBez, weltX, weltY}]
    Q_INVOKABLE QVariantList mikrocontrollerPinbelegung(int projektId);
    // #define-Block je Board (Textausgabe zum Kopieren in den Sketch)
    Q_INVOKABLE QString      mikrocontrollerCode(int projektId);
    Q_INVOKABLE bool         mikrocontrollerPinbelegungCsvSpeichern(int projektId, const QString &pfad);

    // ── DRC (Design Rule Check) ──────────────────────────────────────────────
    // Gibt alle BMK-Werte zurück, die im Projekt mehrfach vorkommen.
    // Rückgabe: [{bmk, anzahl, ids:[...]}]
    Q_INVOKABLE QVariantList drcDoppelteBmk(int projektId);
    // Gibt Symbole zurück, die ein BMK benötigen aber keines haben.
    // Rückgabe: [{elementId, symbolId, seiteId, seiteName}]
    Q_INVOKABLE QVariantList drcSymboleOhneBmk(int projektId);
    // D-13 (NKZ-05): automatisch vergebene, vom Nutzer noch nicht bestaetigte Platzhalter-BMKs.
    // Rückgabe: [{elementId, symbolId, seiteId, seiteName, bmk}]
    Q_INVOKABLE QVariantList drcUnbestaetigtesPlatzhalterBmk(int projektId);
    // Gibt Seiten zurück, die keine Bezeichnung haben.
    // Rückgabe: [{seiteId, blattnummer}]
    Q_INVOKABLE QVariantList drcSeitenOhneBezeichnung(int projektId);
    // Gibt Kabeladern zurück, bei denen Von- oder Nach-Anschluss fehlt.
    // Rückgabe: [{aderId, aderNr, aderBez, kabelName, wasFehlt}]
    Q_INVOKABLE QVariantList drcKabeladernOhneAnschluss(int projektId);
    // D-05: Pins die keine Leitung berühren (alle Seiten des Projekts).
    // Rückgabe: [{elementId, symbolId, pinName, seiteId, seiteName}]
    Q_INVOKABLE QVariantList drcUnverbundenePins(int projektId);
    // D-06: Leitungsenden die weder einen Pin noch ein anderes Leitungsende treffen.
    // Rückgabe: [{elementId, seiteId, seiteName, endpunkt}]
    Q_INVOKABLE QVariantList drcLeitungsenden(int projektId);
    // D-07: Netze mit Signaltyp-Konflikt (z.B. phase + steuer direkt verbunden).
    // Rückgabe: [{verbindungId, name, potenzial}]
    Q_INVOKABLE QVariantList drcPotenzialkonflikte(int projektId);
    // D-08: Netze auf denen mehr als eine Quelle (Ausgang) liegt.
    // Rückgabe: [{verbindungId, name, quellenAnzahl, seiteNamen}]
    Q_INVOKABLE QVariantList drcParallelQuellen(int projektId);
    // D-09: Klemmenanschluss-Geister (KLEMME-DUP-01/Makro-Fall) – noch nicht
    // zu einer echten Klemme hochgestuft.
    // Rückgabe: [{elementId, seiteId, seiteName, anschlussBezeichnung, bmk}]
    Q_INVOKABLE QVariantList drcKlemmeGeister(int projektId);
    // D-11 (SCH-02): Schirm-Element dessen Anschlusspunkt keine Leitung berührt.
    // D-10 ist für die künftige Litzenfarbe-Abweichungsprüfung reserviert
    // (KONFKABEL-01), daher hier D-11.
    // Rückgabe: [{elementId, seiteId, seiteName, bezeichnung}]
    Q_INVOKABLE QVariantList drcSchirmOhneAnschluss(int projektId);
    // D-12 (KABEL-VERWAIST-01): Kabel-Datensatz ohne jedes Kabellinie-Grafikelement.
    // Rückgabe: [{kabelId, kabelName}]
    Q_INVOKABLE QVariantList drcKabelOhneKabellinie(int projektId);
    // S1: Ergebnis des letzten DRC-Laufs je Projekt speichern (nur der letzte Lauf, Migration 179).
    // proTyp = {befundTyp: anzahl}; die Gesamtzahl wird daraus gebildet.
    Q_INVOKABLE bool drcLaufSpeichern(int projektId, const QVariantMap &proTyp);
    // {vorhanden, zeitpunkt (UTC), anzahlBefunde, details: {typ: anzahl}}; vorhanden=false, wenn noch nie geprüft wurde
    Q_INVOKABLE QVariantMap drcLetzterLauf(int projektId);
    // D-14 (SPS-INTEGRITAET-01): SPS/PLS-Prüfungen. Jeder Befund trägt ein Feld `art`:
    // rack_nr_doppelt, slot_doppelt, adresse_doppelt, adresse_ausserhalb,
    // kanal_ohne_baugruppe, element_mehrere_kanaele, kanal_typ_passt_nicht,
    // kanal_ohne_element, symbol_ohne_kanal, pls_grenzen.
    // Gemeinsame Felder: {art, adresse, tag, detail, elementId, seiteId, seiteName}
    Q_INVOKABLE QVariantList drcSpsPruefung(int projektId);

    // ── Canvas PDF-Export (L16) ──────────────────────────────────────────────
    // Alle Seiten eines Projekts als mehrseitiges Vektor-PDF exportieren.
    // pfad: lokaler Dateipfad oder file://-URL.
    // DOKU-PDF-02: Dokumentations-PDF aus Abschnitten (schaltplan, sps_io) in einem Writer.
    // optionenJson: { mitNormblatt, seiteIds?, abschnitte:[{typ, konfig?}] },
    // Beschreibung in konzept/features/51_dokumentations_pdf.md §4.
    Q_INVOKABLE bool dokuPdfExportieren(int projektId, const QString &pfad, const QString &optionenJson);
    // Seiten des Projekts für den Export-Dialog: [{id, anlage, ort, blatt, bezeichnung, inDokuPdf}]
    Q_INVOKABLE QVariantList dokuPdfSeitenListe(int projektId);
    // Existenzprüfung für Export-Überschreibwarnungen (akzeptiert lokalen Pfad oder file://-URL).
    Q_INVOKABLE bool dateiExistiert(const QString &pfad) const;

    // ── Datensicherung / Komplettarchiv (BACKUP-01) ─────────────────────────
    // Ebene 1: Auto-Backup beim App-Start – makros.db + wiki.db → backups/,
    //          einmal täglich, max. 7 rotierende Dateien.
    Q_INVOKABLE QVariantMap datenbankAutobackup();
    // Ebene 2: Manueller Vollexport (alle DBs + wiki_blobs + .strl-Dateien).
    Q_INVOKABLE QVariantMap komplettarchivExportieren(const QString &zielOrdner);
    // Importiert ein Komplettarchiv: DBs → _pendingrestore/ (Neustart nötig),
    //   Wiki (JSON-merge sofort), .strl-Kopien → dataDir/importierte_projekte/.
    Q_INVOKABLE QVariantMap komplettarchivImportieren(const QString &quellOrdner);

    // ── CSV-Import Bauteilkatalog (M7) ──────────────────────────
    Q_INVOKABLE QStringList  csvKopfzeile(const QString &pfad);
    Q_INVOKABLE QVariantList csvVorschau(const QString &pfad, int maxZeilen = 3);
    Q_INVOKABLE int          csvBauteileImportieren(const QString &pfad, int kategorieId,
                                                    const QVariantMap &mapping);
    Q_INVOKABLE QVariantList bauteilAlleKategorienFlach();

private:
    // DOKU-PDF-01: Schaltplan-Abschnitt des PDF-Exports (Database_PDF.cpp)
    int    pdfSchaltplanSeitenRendern(QPainter &painter, QPdfWriter &writer, const QList<int> &seiteIds,
                                      bool mitNormblatt,
                                      bool ersteSeiteNeu);
    QSizeF pdfSchaltplanSeitenGroesseMm(int seiteId, bool mitNormblatt);
    // Blatt-Flaeche (mm) des Normblatts bei Position "inhalt"; ungueltig = Position fest / keine Elemente
    QRectF normblattFlaecheMm(int seiteId, const QVariantMap &nb);
    QList<int> dokuPdfSeitenIds(int projektId);

    // Version prüfen; bei Mismatch alle Objekte löschen + neu erstellen
    bool checkAndApplySchema();

    // Inkrementelle Migration ausführen (Liste von SQL-Statements)
    bool applyMigrationStatements(const QStringList &statements);

    // DB sichern via VACUUM INTO (funktioniert auch bei offener WAL-Verbindung).
    // verbindungsName: "" = Haupt-DB, "stroemling_wiki" = Wiki-DB.
    bool erstelleBackup(const QString &verbindungsName, const QString &prefix, int version);
    // VERT-01
    void sperreErwerben(const QString &projektPfad);
    bool sperreSchreiben();
    void sperreHerzschlag();
    void sperreFreigeben();
    bool verdrahtungGesperrt(bool melden, const QString &was);   // VERT-02c
    bool projektdatenGesperrt(bool melden, const QString &was);
    QVariantMap ibnOverlayAnalysieren(const QString &pfad);
    bool ibnOverlaySammeln(QJsonArray &bm, QJsonArray &kabel, int &ausserhalb, QString &fehlerText);
    QVariantList m_kopieBereich;   // Bereich der IBN-Kopie (leer = ganzes Projekt)   // VERT-04, enthaelt die Nutzdaten
    void ibnKopieStatusAktualisieren();   // VERT-02: m_istIbnKopie / m_offeneKopien neu lesen
    bool m_istIbnKopie = false;
    int  m_offeneKopien = 0;
    bool m_schaltplanOverride = false;    // nur diese Sitzung
    QString m_ibnKopieName;
    bool        m_schreibgeschuetzt = false;
    QVariantMap m_sperreInfo;
    QString     m_sperrePfad;       // leer = wir halten keine Sperre
    QString     m_sperreSitzung;    // eindeutige ID dieser Programminstanz
    QTimer     *m_sperreTimer = nullptr;

    QString m_letzterOeffnenPfad;  // Pfad des letzten openProjekt()-Versuchs (auch bei Fehlschlag)

    // Alle Views und Tabellen in FK-sicherer Reihenfolge löschen (nur Baseline-Migration)
    bool dropAllTables();

    // Alle Tabellen und Views anlegen – nur von Baseline-Migration aufgerufen
    bool createSchema();

    // Eingebauten Symbol-Katalog befüllen (immer nach Schema-Aufbau)
    bool seedSymbolKatalog();

    // Eingebaute Symbole als Primitiv-Daten in symbol_definition/symbol_primitiv/symbol_pin eintragen
    bool seedBuiltinSymbolDefinitionen();

    // IBN-Feldvorlagen (Systemfelder) nach Schema-Aufbau befüllen
    bool seedIbnFeldvorlagen();

    // 6 repräsentative Klemmen-Bauteile (Durchgang/PE/N/Doppelstock/Trenn)
    bool seedStandardKlemmen();
    // BIB-UID-01: UID der Seed-Bauteile (ist_system=1) auf den deterministischen Wert bringen (idempotent)
    bool bauteilUidsAbgleichen();

    // Nutzer-eigene Bauteile aus src/database/bauteile_nutzer.sql (Klemmen, Kabel …)
    bool seedNutzerBauteile();

    // Wiki-Starter-Kategorien anlegen (einmalig nach frischem Wiki-Schema-Aufbau)
    bool seedWikiStarterInhalte();

    // Bibliothek-Schema prüfen und ggf. anlegen (analog checkAndApplyWikiSchema)
    bool checkAndApplyBibliothekSchema();

    // Wiki-Schema prüfen und ggf. anlegen (analog checkAndApplySchema)
    bool checkAndApplyWikiSchema();

    // Wiki-Tabellen in wiki.db anlegen
    bool createWikiSchema();

    // Migration v77: grafik_element.bild_daten (BLOB) → Dateien in m_grafikBilderDir.
    // Idempotent (PRAGMA table_info-Check), läuft auch bei frischen DBs sauber durch.
    bool migriereGrafikBilderAufDateien();

    // Pfad + Name eines geöffneten Projekts in die zuletzt_geoeffnet-Tabelle eintragen
    void zuletzGeoeffnetEintragen(const QString &path, const QString &name);

    // Projekt in bekannte_projekte registrieren / aktualisieren
    void bekannteProjecteEintragen(const QString &pfad, const QString &name, const QString &nummer);

    // Blob-Dateien eines Artikels löschen (vor CASCADE-DELETE aufrufen)
    void wikiBlobDateienLoeschenFuerArtikel(int artikelId);
    // Blob-Dateien aller Nutzer-Artikel löschen (vor Replace-Import)
    void wikiBlobDateienAlleNutzerArtikelLoeschen();

    // Strukturkasten-extra_daten (sk_extra-Spalte der Korrelations-Subquery)
    // parsen: überschreibt anlageKz/ortKz falls im Strukturkasten gesetzt
    // (= bzw. +), liefert anlageUO/ortUO (== bzw. ++, übergeordnete Ebenen).
    static void strukturkastenOverrideAnwenden(const QString &skExtraDaten,
                                                QString &anlageKz, QString &ortKz,
                                                QString &anlageUO, QString &ortUO);

    // Betriebsmittel-Snapshot (bezeichnung/hersteller/artikelnummer aus
    // bibliothek.bauteil) für den Export in projektunabhängige Formate
    // (Makro-Bibliothek, Zwischenablage). Leeres Objekt wenn nicht gefunden.
    QJsonObject _bauteilSnapshotErzeugen(int betriebsmittelId);

    // Kehrseite: aus einem Bauteil-Snapshot ein betriebsmittel im Zielprojekt
    // finden (Artikelnummer-Match) oder neu anlegen. Legt bei Bedarf auch den
    // bauteil-Eintrag in der geteilten bibliothek.db an. Gibt die neue
    // betriebsmittel_id zurück (QVariant() bei leerem Snapshot/Fehler).
    QVariant _betriebsmittelAusSnapshotAnlegenOderFinden(const QJsonObject &snap,
                                                           const QString &bmk,
                                                           const QString &symbolKey,
                                                           int projektId);

    // SPS-KANAL-KOMMENTAR-SYNC-01 + SPS-KANAL-TAG-SYNC-01: Kanal-Variablenname
    // (Tag) und -Kommentar in die Freitext-Zeilen (extra_daten.freitext1/2)
    // des verknüpften grafik_element übernehmen, damit beide nur an einer
    // Stelle (Kanal) gepflegt werden müssen.
    void _spsKanalFelderInsElementUebernehmen(int kanalId);
    QVariantMap spsExportErzeugen(int projektId, const QString &konfigJson, int maxZeilen);
    QVariantMap spsImportPlanen(int projektId, const QString &pfad, const QString &konfigJson,
                                bool ausfuehren);
    // SPS-EXPORT-04: Zeilen je Schema (Standard + eigene Schemata je Signalart), Reihenfolge fest.
    struct SpsExportGruppe {
        QString              schema;   // "Standard" | "DI" | "DO" | "AI" | "AO" | …
        QStringList          titel;
        QList<QStringList>   zeilen;
    };
    // SPS-EXPORT-06: Gegenstelle/Klemme/Kabel/Ader je sps_kanal.id, nur wenn eindeutig (Schlüssel "_vw_<feld>")
    QHash<int, QVariantMap> spsVerdrahtungJeKanal(int projektId, const QVariantList &kanaele);
    bool spsExportGruppen(int projektId, const QString &konfigJson,
                          QList<SpsExportGruppe> &gruppen, QString &fehler);

    QSqlDatabase m_db;
    int          m_grafikAenderungszaehler = 0;
    QSqlDatabase m_wikiDb;
    QSqlDatabase m_makroDb;
    QSqlDatabase m_vorlagenDb;
    QString      m_vorlagenPfad;
    bool normblattFelderSchreiben(int vorlageId, const QVariantList &felder);
    bool bibliothekVorlageLesen(const QString &uid, QVariantMap &kopf, QVariantList &felder,
                                QByteArray &logo, QString &logoMime);
    QSqlDatabase m_launcherDb;
    QSqlDatabase m_bibliothekDb;
    bool         m_projektOffen  = false;
    bool         m_fts5Verfuegbar = false;
    QString      m_wikiBlobDir;
    QString      m_wikiPfad;
    QString      m_makroPfad;
    QString      m_bibliothekPfad;
    QString      m_grafikBilderDir;  // <Projektordner>/bilder – Canvas-Bild-BLOBs als Dateien
};
