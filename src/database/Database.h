#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QSqlError>
#include <QString>

// Database kümmert sich um:
//   - Verbindung zur SQLite-Datei aufbauen
//   - Schema versioniert anlegen (schema_version-Tabelle)
//   - Bei Versionsänderung: alles löschen + neu aufbauen
//   - Wird einmal in main.cpp erstellt und dann weitergegeben

class Database : public QObject
{
    Q_OBJECT

public:
    // Aktuelle Schema-Version. Erhöhen wenn sich Tabellenstruktur ändert.
    // Beim Start: stimmt DB-Version nicht überein → alle Tabellen drop + recreate.
    static const int SCHEMA_VERSION = 39;

    explicit Database(QObject *parent = nullptr);

    // Datenbankdatei öffnen oder neu anlegen
    bool open(const QString &path);

    // Verbindung schließen
    void close();

    // Ist die Verbindung offen?
    bool isOpen() const;

    // Letzter Fehler (für Debugging)
    QString lastError() const;

    // Grafikelemente einer Seite laden (gibt QVariantList aus QVariantMaps zurück)
    Q_INVOKABLE QVariantList grafikLaden(int seiteId);

    // Alle Grafikelemente einer Seite ersetzen (Transaktion, Delete + Insert)
    Q_INVOKABLE bool grafikSpeichern(int seiteId, const QVariantList &elemente);

    // Alle Symbole für eine gegebene Norm zurückgeben ("IEC" oder "ANSI")
    Q_INVOKABLE QVariantList symboleNachNorm(const QString &norm);

    // Favoritenstatus eines Symbols setzen
    Q_INVOKABLE bool symbolFavoritSetzen(int symbolId, bool favorit);

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
                                                    const QString &bezeichnung);
    Q_INVOKABLE bool         grafikElementVerknuepfen(int elementId, int betriebsmittelId);
    Q_INVOKABLE bool         grafikElementEntknuepfen(int elementId);
    Q_INVOKABLE QVariantList betriebsmittelMitglieder(int betriebsmittelId);
    Q_INVOKABLE QString      betriebsmittelKz(int betriebsmittelId);
    Q_INVOKABLE QVariantMap  betriebsmittelInfo(int betriebsmittelId);
    Q_INVOKABLE bool         betriebsmittelHauptfunktionSetzen(int betriebsmittelId, int elementId);
    Q_INVOKABLE bool         betriebsmittelBmkSynchronisieren(int betriebsmittelId);
    Q_INVOKABLE QVariantList betriebsmittelHfListe(int projektId);

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

private:
    // Version prüfen; bei Mismatch alle Objekte löschen + neu erstellen
    bool checkAndApplySchema();

    // Alle Views und Tabellen in FK-sicherer Reihenfolge löschen
    bool dropAllTables();

    // Alle Tabellen und Views anlegen (ohne IF NOT EXISTS)
    bool createSchema();

    // Eingebauten Symbol-Katalog befüllen (immer nach Schema-Aufbau)
    bool seedSymbolKatalog();

    // Eingebaute Symbole als Primitiv-Daten in symbol_definition/symbol_primitiv/symbol_pin eintragen
    bool seedBuiltinSymbolDefinitionen();

    // Beispieldaten einfügen (einmalig nach frischem Schema-Aufbau)
    bool seedExampleData();

    // IBN-Feldvorlagen (Systemfelder) nach Schema-Aufbau befüllen
    bool seedIbnFeldvorlagen();

    QSqlDatabase m_db;
};
