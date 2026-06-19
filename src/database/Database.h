#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QSqlError>
#include <QString>
#include "logging.h"

// Database kümmert sich um:
//   - Verbindung zur SQLite-Datei aufbauen
//   - Schema versioniert anlegen (schema_version-Tabelle)
//   - Bei Versionsänderung: alles löschen + neu aufbauen
//   - Wird einmal in main.cpp erstellt und dann weitergegeben

class Database : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool         projektOffen    READ projektOffen       NOTIFY projektOffenChanged)
    Q_PROPERTY(QString      projektPfad     READ projektPfad        NOTIFY projektOffenChanged)
    Q_PROPERTY(QString      projektOrdner   READ projektOrdner      NOTIFY projektOffenChanged)
    Q_PROPERTY(QVariantList bekannteProjecte READ bekannteProjecteLaden NOTIFY registryGeaendert)
    Q_PROPERTY(QString      makroPfad       READ makroPfad          CONSTANT)
    Q_PROPERTY(QString      wikiPfad        READ wikiPfad           CONSTANT)

public:
    // Baseline-Version des Migrations-Systems. Neue Schemaänderungen kommen
    // als inkrementelle Migration in alleMigrationen(). Bei einem Migrations-
    // Squash (keine Produktivdatenbanken) wird diese Konstante auf die nächste
    // freie Versionsnummer erhöht und alleMigrationen() auf den neuen Baseline-
    // Eintrag zurückgesetzt.
    static const int BASELINE_VERSION       = 56;
    static const int CURRENT_SCHEMA_VERSION = 61;
    static const int WIKI_SCHEMA_VERSION    = 12;
    // Tabellenzahl in schema.sql – muss synchron zu BASELINE_VERSION bleiben.
    // Wenn schema.sql neue Tabellen bekommt: diesen Wert + BASELINE_VERSION erhöhen.
    static const int BASELINE_TABLE_COUNT   = 42;

    explicit Database(QObject *parent = nullptr);

    // Launcher-DB öffnen (stroemling.db – nur zuletzt-geöffnet-Liste + Wiki-DB-Pfad)
    bool openLauncher(const QString &path);

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

    // Projektmetadaten speichern (Name, Nummer, AG, AN, Bearbeiter)
    Q_INVOKABLE bool projektMetaDatenSpeichern(const QString &name,
                                               const QString &nummer,
                                               const QString &auftraggeber,
                                               const QString &auftragnehmer,
                                               const QString &bearbeiter);

    // Hauptdatenbank öffnen oder neu anlegen (legacy – ruft openProjekt auf)
    bool open(const QString &path);

    // Wiki-Datenbank öffnen (separate Datei, überlebt Schema-Upgrades)
    bool openWiki(const QString &path);

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
    void registryGeaendert();
    void dbFehler(const QString &meldung);

public:
    // Grafikelemente einer Seite laden (gibt QVariantList aus QVariantMaps zurück)
    Q_INVOKABLE QVariantList grafikLaden(int seiteId);

    // Alle Grafikelemente einer Seite ersetzen (Transaktion, Delete + Insert)
    Q_INVOKABLE bool grafikSpeichern(int seiteId, const QVariantList &elemente);

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
    // Gibt [{seiteId, blattnummer, seitenBezeichnung, signalname, richtung, x1, y1}] zurück.
    Q_INVOKABLE QVariantList querverweiseLadenProjekt(int projektId);

    // Stückliste: alle platzierten Symbole mit BMK, Freitexten, Seite.
    // Gibt [{bmk, symbolId, freitext1, freitext2, seite, anlagekz, ortkz}] zurück.
    Q_INVOKABLE QVariantList stueckliste(int projektId);

    // Querverweisliste: alle Querverweis-Symbole mit Signalname, Richtung, Seite, Zielseite.
    // Gibt [{signalname, richtung, seite, zielSeite}] zurück.
    Q_INVOKABLE QVariantList querverweisListe(int projektId);

    // Aderliste: alle Aderdefinitionspunkte mit Bezeichnung, Farbe, Querschnitt, Länge, Seite.
    // Gibt [{bezeichnung, aderfarbe, querschnittMm2, laengeM, seite, anlageKz, ortKz}] zurück.
    Q_INVOKABLE QVariantList aderliste(int projektId);

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
    Q_INVOKABLE bool         betriebsmittelBmkSynchronisieren(int betriebsmittelId);
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
                                 bool hatSchirmkontakt, bool geschirmt);
    Q_INVOKABLE bool         steckverbinderTypLoeschen(int bauteilId);

    Q_INVOKABLE QVariantList steckverbinderKableinfLaden(int steckverbinderTypId) const;
    Q_INVOKABLE int          steckverbinderKableinfHinzufuegen(int steckverbinderTypId);
    Q_INVOKABLE bool         steckverbinderKableinfAktualisieren(int id, double aussenMin,
                                 double aussenMax, const QString &einfTyp,
                                 const QString &zugentlastung);
    Q_INVOKABLE bool         steckverbinderKableinfLoeschen(int id);

    Q_INVOKABLE QVariantList steckverbinderKontaktLaden(int steckverbinderTypId) const;
    Q_INVOKABLE int          steckverbinderKontaktHinzufuegen(int steckverbinderTypId);
    Q_INVOKABLE bool         steckverbinderKontaktAktualisieren(int id, bool istSchirmkontakt,
                                 const QString &kontaktgroesse, double qsMin, double qsMax,
                                 double nennstrom, double nennspannung,
                                 const QString &verbindungstechnik);
    Q_INVOKABLE bool         steckverbinderKontaktLoeschen(int id);

    // Klemmenplan: alle Klemmen aller Leisten, mit Gruppen-Headern.
    // Gibt abwechselnd {typ:"leiste",...} und {typ:"klemme",...} zurück.
    Q_INVOKABLE QVariantList klemmenplan(int projektId);

    // Klemmenplan als CSV-Datei speichern (UTF-8 mit BOM, Semikolon-getrennt).
    Q_INVOKABLE bool klemmenplanCsvSpeichern(int projektId, const QString &pfad);

    // CSV-Export der übrigen Listen (UTF-8 mit BOM, Semikolon-getrennt).
    Q_INVOKABLE bool stuecklisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool querverweislisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool aderlisteCsvSpeichern(int projektId, const QString &pfad);
    Q_INVOKABLE bool kabellisteCsvSpeichern(int projektId, const QString &pfad);

    // Normblatt: alle Daten einer Seite für Canvas-Rendering laden.
    // Gibt {blattnummer, bezeichnung, anlageKuerzel, ortKuerzel, breiteMm, hoeheMm,
    //       normblattAnzeigen, hintergrundFarbe, aussenOverlay, titelblattVorlage,
    //       projektName, projektnummer, auftraggeber, auftragnehmer,
    //       bearbeiter, norm, erstelltAm, randLinksMm, randRechtsMm, randObenMm, randUntenMm} zurück.
    Q_INVOKABLE QVariantMap seiteBasisDaten(int seiteId);
    Q_INVOKABLE QVariantMap normblattDatenLaden(int seiteId);

    // Normblatt-Einstellungen für eine Seite speichern.
    // normblattId=-1 → kein benutzerdefiniertes Normblatt (titelblattVorlage greift).
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
    Q_INVOKABLE QVariantList normblattFelderLaden(int vorlageId);
    Q_INVOKABLE bool         normblattFelderSpeichern(int vorlageId, const QVariantList &felder);

    // ── Inbetriebnahme-Modus ─────────────────────────────────────
    // Alle BM mit BMK für ein Projekt laden; seiteId=-1 = alle Seiten.
    Q_INVOKABLE QVariantList ibnListeLaden(int projektId, int seiteId = -1);

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

    // Alle Gerätekästen des Projekts mit Seite + Mittelpunkt (für Seitenbaum).
    Q_INVOKABLE QVariantList geraetekastenListeMitPos(int projektId) const;

    // Alle Gerätekästen mit gegebenem BMK (für EP-Abschnitt "Weitere Kästen").
    Q_INVOKABLE QVariantList geraetekastenNachBmk(int projektId, const QString &bmk) const;

    // bauteil_id in extra_daten eines Gerätekasten-Elements setzen (bauteilId<=0 = entfernen).
    Q_INVOKABLE bool geraetekastenBauteilSetzen(int grafikElementId, int bauteilId);

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

    // Projekt-Metadaten (Schriftfeld-Felder) speichern.
    Q_INVOKABLE bool projektMetaSpeichern(int projektId,
                                          const QString &name,
                                          const QString &projektnummer,
                                          const QString &auftraggeber,
                                          const QString &auftragnehmer,
                                          const QString &bearbeiter);

    // Logo eines Projekts aus einer Bilddatei laden und in DB speichern.
    Q_INVOKABLE bool projektLogoSpeichern(int projektId, const QString &pfad);

    // Logo eines Projekts als Base64-Data-URL zurückgeben ("" wenn keines gesetzt).
    Q_INVOKABLE QString projektLogoDataUrl(int projektId);

    // Logo eines Projekts löschen.
    Q_INVOKABLE bool projektLogoLoeschen(int projektId);

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
    Q_INVOKABLE bool kabelAderZuordnen(int kabelId, int aderNr,
                                       const QString &farbe,
                                       const QString &bezeichnung,
                                       int verbindungId,
                                       int kabellinieGrafikElementId = 0);

    // Kabeldetails + Adern für das EigenschaftenPanel laden.
    // Sucht das Kabel über json_extract(extra_daten, '$.kabelId') des Grafikelements.
    // Gibt {id, bezeichnung, kabeltyp, aderzahl, querschnittMm2, grafikElementId,
    //       vonOrt, nachOrt, bauteilKabelId,
    //       adern:[{aderNr, farbe, bezeichnung, verbindungId, kabellinieGrafikElementId}]} zurück.
    Q_INVOKABLE QVariantMap kabelLinieDetails(int grafikElementId);

    // Alle Kabellinie-Grafikelemente eines Kabels (für KABEL-LINIEN-Abschnitt im EP).
    // Gibt [{grafikElementId, seiteId, seiteBezeichnung, aderAnzahl}] zurück.
    Q_INVOKABLE QVariantList kabelAlleLinienLaden(int kabelId);

    // Alle Adern eines Kabels die keiner Kabellinie zugeordnet sind.
    // Gibt [{aderNr, farbe, bezeichnung, verbindungId}] zurück.
    Q_INVOKABLE QVariantList kabelFreieAderLaden(int kabelId);

    // Adern einer Kabellinie (für KABEL-ADERN-Abschnitt im EP).
    // Gibt [{aderNr, farbe, bezeichnung, verbindungId}] zurück.
    Q_INVOKABLE QVariantList kabelAderFuerLinieLaden(int kabellinieGrafikElementId);

    // Alle Kabel eines Projekts für die Kabelliste.
    // Gibt [{id, bezeichnung, kabeltyp, aderzahl, querschnittMm2, laengeM,
    //        vonOrt, nachOrt, grafik_element_id}] zurück.
    Q_INVOKABLE QVariantList kabelListe(int projektId);

    // Wie kabelListe, aber mit seiteId, blattnr, seiteBez, weltX, weltY der primären Kabellinie.
    Q_INVOKABLE QVariantList kabelListeMitPos(int projektId) const;

    // Alle Kabellinien eines Kabels mit Seite und Mittelpunktposition.
    Q_INVOKABLE QVariantList kabellinienMitPos(int kabelId) const;

    // Alle Kabel eines Projekts mit Ader-Unterzeilen für die zweistufige Kabelliste.
    // Gibt [{id, bezeichnung, kabeltyp, aderzahl, querschnittMm2, laengeM, vonOrt, nachOrt,
    //        linienAnzahl, adern:[{nr, farbe, bezeichnung, blattnummer, seitenBezeichnung, netz}]}] zurück.
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
    //        adern:[{farbe, querschnittMm2}]}] zurück.
    Q_INVOKABLE QVariantList bauteilKabelListe();

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

    // Makro-Metadaten (Name, Beschreibung, Kategorie) aktualisieren.
    Q_INVOKABLE bool makroMetaAktualisieren(int makroId, const QString &name,
                                             const QString &beschreibung,
                                             const QString &kategorie);

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

    // I/O-Liste als CSV (UTF-8 mit BOM, Semikolon-getrennt)
    Q_INVOKABLE bool         spsIOListeCsvSpeichern(int projektId, const QString &pfad);

    // Element-IDs die mehr als einem Kanal zugewiesen sind (Adress-Konflikt)
    Q_INVOKABLE QVariantList spsKonfliktElementIds(int projektId);

    // ── DRC (Design Rule Check) ──────────────────────────────────────────────
    // Gibt alle BMK-Werte zurück, die im Projekt mehrfach vorkommen.
    // Rückgabe: [{bmk, anzahl, ids:[...]}]
    Q_INVOKABLE QVariantList drcDoppelteBmk(int projektId);
    // Gibt Symbole zurück, die ein BMK benötigen aber keines haben.
    // Rückgabe: [{elementId, symbolId, seiteId, seiteName}]
    Q_INVOKABLE QVariantList drcSymboleOhneBmk(int projektId);
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

    // ── Canvas PDF-Export (L16) ──────────────────────────────────────────────
    // Alle Seiten eines Projekts als mehrseitiges Vektor-PDF exportieren.
    // pfad: lokaler Dateipfad oder file://-URL.
    Q_INVOKABLE bool canvasPdfExportieren(int projektId, const QString &pfad, bool mitNormblatt = true, bool vollCanvas = false, bool mitInfostreifen = false);
    Q_INVOKABLE bool canvasSeiteExportieren(int seiteId,  const QString &pfad, bool mitNormblatt = true, bool vollCanvas = false, bool mitInfostreifen = false);
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
    // Version prüfen; bei Mismatch alle Objekte löschen + neu erstellen
    bool checkAndApplySchema();

    // Inkrementelle Migration ausführen (Liste von SQL-Statements)
    bool applyMigrationStatements(const QStringList &statements);

    // DB sichern via VACUUM INTO (funktioniert auch bei offener WAL-Verbindung).
    // verbindungsName: "" = Haupt-DB, "stroemling_wiki" = Wiki-DB.
    bool erstelleBackup(const QString &verbindungsName, const QString &prefix, int version);

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

    // Wiki-Starter-Kategorien anlegen (einmalig nach frischem Wiki-Schema-Aufbau)
    bool seedWikiStarterInhalte();

    // Wiki-Schema prüfen und ggf. anlegen (analog checkAndApplySchema)
    bool checkAndApplyWikiSchema();

    // Wiki-Tabellen in wiki.db anlegen
    bool createWikiSchema();

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

    QSqlDatabase m_db;
    QSqlDatabase m_wikiDb;
    QSqlDatabase m_makroDb;
    QSqlDatabase m_launcherDb;
    bool         m_projektOffen  = false;
    bool         m_fts5Verfuegbar = false;
    QString      m_wikiBlobDir;
    QString      m_wikiPfad;
    QString      m_makroPfad;
};
