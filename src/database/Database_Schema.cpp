#include "Database.h"
#include <cmath>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QTextStream>
#include <QUrl>
#include <QDateTime>
#include <QPrinter>
#include <QTextDocument>
#include <QPdfWriter>
#include <QPainter>
#include <QPen>
#include <QFont>
#include <QFontMetricsF>
#include <QColor>
#include <QPolygonF>
#include <QPageSize>
#include <QPageLayout>
#include <algorithm>



// ============================================================
// Migrations-Katalog
// Jede Migration hat eine aufsteigende Versionsnummer, eine
// kurze Beschreibung und eine Liste von SQL-Statements.
// Die Baseline-Version (BASELINE_VERSION) wird von
// checkAndApplySchema() speziell behandelt: dropAllTables()
// + createSchema() + Seeds. Statements-Liste bleibt leer.
//
// Bei einem Squash (keine Produktivdaten): BASELINE_VERSION
// erhöhen, alle alten Einträge entfernen, neuen Baseline-
// Eintrag hier eintragen. Dev-DBs werden beim nächsten
// Start automatisch neu aufgebaut.
// ============================================================
struct SchemaMigration {
    int         version;
    QString     beschreibung;
    QStringList statements;
};

static QList<SchemaMigration> alleMigrationen()
{
    // Reihenfolge im Quelltext ist nicht zwingend aufsteigend (siehe v84/v85) –
    // checkAndApplySchema() iteriert aber in Listenreihenfolge, daher hier
    // einmalig nach Versionsnummer sortieren.
    QList<SchemaMigration> migrationen = {
        // Squash v40-v51: alle Tabellen + Spalten sind in createSchema() enthalten.
        // Dev-DBs < v52 werden beim ersten Start neu aufgebaut (dropAllTables + createSchema).
        { 52, "Baseline v52 – Schema konsolidiert (v40-v51 gefaltet)", {} },

        // Baseline v53: createSchema() liest jetzt schema.sql (statt Inline-C++).
        // schema.sql enthält vollständiges Schema inkl. gruppe_id, revision-Spalten, SPS-Tabellen.
        // Dev-DBs bei v52 werden neu aufgebaut (dropAllTables + createSchema aus schema.sql).
        { 53, "Baseline v53 – Schema in schema.sql, SPS/Revision/Gruppe vollständig", {} },

        // B9: Brückengleichrichter (passive, IEC-Raute 32x32mm) + sensor_temp-Absicherung.
        // INSERT OR IGNORE: sicher falls symbol_definition/pin/primitiv schon vorhanden.
        { 54, "B9 – Brückengleichrichter-Symbol + sensor_temp-Absicherung", {
            // sensor_temp (PT100) – falls DB vor dessen Aufnahme in symbole.sql angelegt wurde
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sensor_temp', 'Temperatursensor (PT100)', 'Sensoren', 16, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sensor_temp', '1', 0, 0.5, -1, 0, 'neutral'), ('sensor_temp', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sensor_temp', 0, 'rechteck', 0.1, 0.1, 0.9, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_temp', 1, 'linie', 0, 0.5, 0.1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_temp', 2, 'linie', 0.9, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_temp', 3, 'text', 0.5, 0.35, 0, 0, 0, 0, 0, 0, 0, 0, 'PT', 0.22, 1, 'center', 'middle', 'solid'), ('sensor_temp', 4, 'text', 0.5, 0.65, 0, 0, 0, 0, 0, 0, 0, 0, '100', 0.18, 0, 'center', 'middle', 'solid'))",
            // Brückengleichrichter
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('brueckengleichrichter', 'Brückengleichrichter', 'Passive', 32, 32, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('brueckengleichrichter', '~1', 0, 0.5, -1, 0, 'power'), ('brueckengleichrichter', '~2', 1, 0.5, 1, 0, 'power'), ('brueckengleichrichter', '+', 0.5, 0, 0, -1, 'power'), ('brueckengleichrichter', '-', 0.5, 1, 0, 1, 'power'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('brueckengleichrichter', 0, 'linie', 0.15, 0.5, 0.5, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 1, 'linie', 0.5, 0.15, 0.85, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 2, 'linie', 0.85, 0.5, 0.5, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 3, 'linie', 0.5, 0.85, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 4, 'linie', 0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 5, 'linie', 0.85, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 6, 'linie', 0.5, 0, 0.5, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 7, 'linie', 0.5, 0.85, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 8, 'text', 0.5, 0.3, 0, 0, 0, 0, 0, 0, 0, 0, '+', 0.18, 1, 'center', 'middle', 'solid'), ('brueckengleichrichter', 9, 'text', 0.5, 0.7, 0, 0, 0, 0, 0, 0, 0, 0, '-', 0.18, 1, 'center', 'middle', 'solid'))",
        }},

        // Geräteanschluss + Potenzialpunkt: 16x16mm → 8x8mm, Kreis-Radius 0.22→0.25
        // (Proportionen nach Nutzer-Vorlage: Kreis berührt linke Kante und Mittelpunkt exakt)
        { 55, "Geraeteanschluss + Potenzial: 16x16mm auf 8x8mm verkleinert", {
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='geraeteanschluss' AND ist_builtin=1)",
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='potenzial'        AND ist_builtin=1)",
            R"(UPDATE symbol_primitiv SET x1=0.25, radius=0.25 WHERE symbol_id='geraeteanschluss' AND reihenfolge=1)",
            R"(UPDATE symbol_primitiv SET x1=0.25, radius=0.25 WHERE symbol_id='potenzial'        AND reihenfolge=1)",
        }},
        { 56, "Winkel: 16x16mm auf 8x8mm verkleinert", {
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='winkel' AND ist_builtin=1)",
        }},

        // Standard-Klemmen-Bibliothek: 6 repräsentative Typen (Seed-Daten).
        // INSERT ... SELECT ... WHERE NOT EXISTS: idempotent, lässt vorhandene Einträge unberührt.
        { 57, "Standard-Klemmen-Bibliothek seeden (6 Typen)", {
            // ── bauteil ──────────────────────────────────────────────────────────
            R"(INSERT INTO bauteil (bezeichnung,norm,bemerkung) SELECT 'Durchgangsklemme 2,5mm²','IEC 60947-7-1','Standard-Klemme' WHERE NOT EXISTS(SELECT 1 FROM bauteil WHERE bezeichnung='Durchgangsklemme 2,5mm²'))",
            R"(INSERT INTO bauteil (bezeichnung,norm,bemerkung) SELECT 'Durchgangsklemme 4mm²','IEC 60947-7-1','Standard-Klemme' WHERE NOT EXISTS(SELECT 1 FROM bauteil WHERE bezeichnung='Durchgangsklemme 4mm²'))",
            R"(INSERT INTO bauteil (bezeichnung,norm,bemerkung) SELECT 'PE-Klemme 2,5mm²','IEC 60947-7-1','Standard-Klemme' WHERE NOT EXISTS(SELECT 1 FROM bauteil WHERE bezeichnung='PE-Klemme 2,5mm²'))",
            R"(INSERT INTO bauteil (bezeichnung,norm,bemerkung) SELECT 'N-Klemme 2,5mm²','IEC 60947-7-1','Standard-Klemme' WHERE NOT EXISTS(SELECT 1 FROM bauteil WHERE bezeichnung='N-Klemme 2,5mm²'))",
            R"(INSERT INTO bauteil (bezeichnung,norm,bemerkung) SELECT 'Doppelstockklemme 2,5mm²','IEC 60947-7-1','Standard-Klemme' WHERE NOT EXISTS(SELECT 1 FROM bauteil WHERE bezeichnung='Doppelstockklemme 2,5mm²'))",
            R"(INSERT INTO bauteil (bezeichnung,norm,bemerkung) SELECT 'Trennklemme 2,5mm²','IEC 60947-7-1','Standard-Klemme' WHERE NOT EXISTS(SELECT 1 FROM bauteil WHERE bezeichnung='Trennklemme 2,5mm²'))",
            // ── bauteil_klemme ───────────────────────────────────────────────────
            R"(INSERT INTO bauteil_klemme(bauteil_id,norm,anschluss_typ,ebenen_anzahl,punkte_seite_a,punkte_seite_b,fuss_kontakt_pe,stegbruecke_faehig,breite_mm,gehaeuse_farbe_id) SELECT b.id,'IEC 60947-7-1','schraube',1,1,1,0,1,5.2,(SELECT id FROM farb_definition WHERE hex_wert='#808080' AND ist_standard=1 LIMIT 1) FROM bauteil b WHERE b.bezeichnung='Durchgangsklemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id))",
            R"(INSERT INTO bauteil_klemme(bauteil_id,norm,anschluss_typ,ebenen_anzahl,punkte_seite_a,punkte_seite_b,fuss_kontakt_pe,stegbruecke_faehig,breite_mm,gehaeuse_farbe_id) SELECT b.id,'IEC 60947-7-1','feder',1,1,1,0,1,6.0,(SELECT id FROM farb_definition WHERE hex_wert='#808080' AND ist_standard=1 LIMIT 1) FROM bauteil b WHERE b.bezeichnung='Durchgangsklemme 4mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id))",
            R"(INSERT INTO bauteil_klemme(bauteil_id,norm,anschluss_typ,ebenen_anzahl,punkte_seite_a,punkte_seite_b,fuss_kontakt_pe,stegbruecke_faehig,breite_mm,gehaeuse_farbe_id) SELECT b.id,'IEC 60947-7-1','schraube',1,1,1,1,0,5.2,(SELECT id FROM farb_definition WHERE hex_wert='#88AA00' AND ist_standard=1 LIMIT 1) FROM bauteil b WHERE b.bezeichnung='PE-Klemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id))",
            R"(INSERT INTO bauteil_klemme(bauteil_id,norm,anschluss_typ,ebenen_anzahl,punkte_seite_a,punkte_seite_b,fuss_kontakt_pe,stegbruecke_faehig,breite_mm,gehaeuse_farbe_id) SELECT b.id,'IEC 60947-7-1','schraube',1,1,1,0,1,5.2,(SELECT id FROM farb_definition WHERE hex_wert='#0000CC' AND ist_standard=1 LIMIT 1) FROM bauteil b WHERE b.bezeichnung='N-Klemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id))",
            R"(INSERT INTO bauteil_klemme(bauteil_id,norm,anschluss_typ,ebenen_anzahl,punkte_seite_a,punkte_seite_b,fuss_kontakt_pe,stegbruecke_faehig,breite_mm,gehaeuse_farbe_id) SELECT b.id,'IEC 60947-7-1','schraube',2,1,1,0,1,5.5,(SELECT id FROM farb_definition WHERE hex_wert='#808080' AND ist_standard=1 LIMIT 1) FROM bauteil b WHERE b.bezeichnung='Doppelstockklemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id))",
            R"(INSERT INTO bauteil_klemme(bauteil_id,norm,anschluss_typ,ebenen_anzahl,punkte_seite_a,punkte_seite_b,fuss_kontakt_pe,stegbruecke_faehig,breite_mm,gehaeuse_farbe_id) SELECT b.id,'IEC 60947-7-1','schraube',1,1,1,0,0,5.8,(SELECT id FROM farb_definition WHERE hex_wert='#FF8800' AND ist_standard=1 LIMIT 1) FROM bauteil b WHERE b.bezeichnung='Trennklemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id))",
            // ── bauteil_klemme_querschnitt (alle 4 Adertypen pro Klemme, 1 Statement) ──
            R"(INSERT INTO bauteil_klemme_querschnitt(klemme_id,adertyp,min_mm2,max_mm2) SELECT bk.id,q.t,q.mn,q.mx FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,(SELECT 'starr' t,0.2 mn,2.5 mx UNION ALL SELECT 'flexibel',0.2,2.5 UNION ALL SELECT 'aenh_blank',0.25,2.5 UNION ALL SELECT 'aenh_isoliert',0.25,1.5) q WHERE b.bezeichnung='Durchgangsklemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id))",
            R"(INSERT INTO bauteil_klemme_querschnitt(klemme_id,adertyp,min_mm2,max_mm2) SELECT bk.id,q.t,q.mn,q.mx FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,(SELECT 'starr' t,0.5 mn,4.0 mx UNION ALL SELECT 'flexibel',0.5,4.0 UNION ALL SELECT 'aenh_blank',0.5,4.0 UNION ALL SELECT 'aenh_isoliert',0.5,2.5) q WHERE b.bezeichnung='Durchgangsklemme 4mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id))",
            R"(INSERT INTO bauteil_klemme_querschnitt(klemme_id,adertyp,min_mm2,max_mm2) SELECT bk.id,q.t,q.mn,q.mx FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,(SELECT 'starr' t,0.2 mn,2.5 mx UNION ALL SELECT 'flexibel',0.2,2.5 UNION ALL SELECT 'aenh_blank',0.25,2.5 UNION ALL SELECT 'aenh_isoliert',0.25,1.5) q WHERE b.bezeichnung='PE-Klemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id))",
            R"(INSERT INTO bauteil_klemme_querschnitt(klemme_id,adertyp,min_mm2,max_mm2) SELECT bk.id,q.t,q.mn,q.mx FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,(SELECT 'starr' t,0.2 mn,2.5 mx UNION ALL SELECT 'flexibel',0.2,2.5 UNION ALL SELECT 'aenh_blank',0.25,2.5 UNION ALL SELECT 'aenh_isoliert',0.25,1.5) q WHERE b.bezeichnung='N-Klemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id))",
            R"(INSERT INTO bauteil_klemme_querschnitt(klemme_id,adertyp,min_mm2,max_mm2) SELECT bk.id,q.t,q.mn,q.mx FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,(SELECT 'starr' t,0.2 mn,2.5 mx UNION ALL SELECT 'flexibel',0.2,2.5 UNION ALL SELECT 'aenh_blank',0.25,2.5 UNION ALL SELECT 'aenh_isoliert',0.25,1.5) q WHERE b.bezeichnung='Doppelstockklemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id))",
            R"(INSERT INTO bauteil_klemme_querschnitt(klemme_id,adertyp,min_mm2,max_mm2) SELECT bk.id,q.t,q.mn,q.mx FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,(SELECT 'starr' t,0.2 mn,2.5 mx UNION ALL SELECT 'flexibel',0.2,2.5 UNION ALL SELECT 'aenh_blank',0.25,2.5 UNION ALL SELECT 'aenh_isoliert',0.25,1.5) q WHERE b.bezeichnung='Trennklemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id))",
            // ── PE-Klemme: Fußkontakt-Brücke ────────────────────────────────────
            R"(INSERT INTO bauteil_klemme_bruecke(klemme_id,von_ebene,nach_ebene,ist_pe_fuss) SELECT bk.id,1,1,1 FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='PE-Klemme 2,5mm²' AND NOT EXISTS(SELECT 1 FROM bauteil_klemme_bruecke WHERE klemme_id=bk.id AND ist_pe_fuss=1))",
        }},
        // klemme_anschluss: 16x16mm → 8x8mm, Linie kürzer, Kreis größer (proportional)
        { 58, "klemme_anschluss: 16x16mm auf 8x8mm verkleinert", {
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='klemme_anschluss' AND ist_builtin=1)",
            R"(UPDATE symbol_primitiv SET y2=0.25 WHERE symbol_id='klemme_anschluss' AND reihenfolge=0)",
            R"(UPDATE symbol_primitiv SET radius=0.25 WHERE symbol_id='klemme_anschluss' AND reihenfolge=1)",
        }},

        // IBN-Feldvorlagen: Messtechnik-Kategorien (Temp, Druck, Füllstand, Grenzwert,
        //                   Frequenzumrichter, Sanftanlauf, Durchfluss)
        { 59, "IBN-Felder: Messtechnik + Antriebstechnik Kategorien", {
            // ── Temperatursensor ──────────────────────────────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'temperatursensor','sensortyp','Sensortyp','auswahl','PT100,PT1000,Thermoelement Typ K,Thermoelement Typ J,NTC,Bimetall','',1,1,'system' UNION ALL SELECT 'temperatursensor','messbereich_min','Messbereich min (°C)','zahl','','°C',0,2,'system' UNION ALL SELECT 'temperatursensor','messbereich_max','Messbereich max (°C)','zahl','','°C',0,3,'system' UNION ALL SELECT 'temperatursensor','ausgangssignal','Ausgangssignal','auswahl','4-20mA,0-10V,2-10V,Widerstand,digital','',0,4,'system' UNION ALL SELECT 'temperatursensor','istwert','Istwert bei IBN (°C)','zahl','','°C',0,5,'system' UNION ALL SELECT 'temperatursensor','kalibriert','Kalibriert','boolean','','',0,6,'system' UNION ALL SELECT 'temperatursensor','bemerkung','Bemerkung','text','','',0,7,'system')",
            // ── Drucksensor ──────────────────────────────────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'drucksensor','messprinzip','Messprinzip','auswahl','Piezoresistiv,Kapazitiv,Piezoelektrisch,Differenzdruck','',0,1,'system' UNION ALL SELECT 'drucksensor','messbereich_min','Messbereich min (bar)','zahl','','bar',0,2,'system' UNION ALL SELECT 'drucksensor','messbereich_max','Messbereich max (bar)','zahl','','bar',1,3,'system' UNION ALL SELECT 'drucksensor','prozessanschluss','Prozessanschluss','text','','',0,4,'system' UNION ALL SELECT 'drucksensor','ausgangssignal','Ausgangssignal','auswahl','4-20mA,0-10V,2-10V,0-20mA,HART','',0,5,'system' UNION ALL SELECT 'drucksensor','istwert','Istwert bei IBN (bar)','zahl','','bar',0,6,'system' UNION ALL SELECT 'drucksensor','kalibriert','Kalibriert','boolean','','',0,7,'system' UNION ALL SELECT 'drucksensor','bemerkung','Bemerkung','text','','',0,8,'system')",
            // ── Füllstandssensor ─────────────────────────────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'fuellstandssensor','messprinzip','Messprinzip','auswahl','Ultraschall,Radar,Schwimmer,Hydrostatisch,Leitfähigkeit,Kapazitiv','',1,1,'system' UNION ALL SELECT 'fuellstandssensor','messbereich_min','Messbereich min (m)','zahl','','m',0,2,'system' UNION ALL SELECT 'fuellstandssensor','messbereich_max','Messbereich max (m)','zahl','','m',0,3,'system' UNION ALL SELECT 'fuellstandssensor','ausgangssignal','Ausgangssignal','auswahl','4-20mA,0-10V,2-10V,HART,digital','',0,4,'system' UNION ALL SELECT 'fuellstandssensor','istwert','Istwert bei IBN (%)','zahl','','%',0,5,'system' UNION ALL SELECT 'fuellstandssensor','kalibriert','Kalibriert','boolean','','',0,6,'system' UNION ALL SELECT 'fuellstandssensor','bemerkung','Bemerkung','text','','',0,7,'system')",
            // ── Grenzwertschalter (Hoch-/Niedrigalarm) ───────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'grenzwertschalter','schaltgroesse','Schaltgröße','auswahl','Temperatur,Druck,Füllstand,Durchfluss,Strom,Spannung,Drehzahl','',1,1,'system' UNION ALL SELECT 'grenzwertschalter','schaltpunkt_hoch','Schaltpunkt Hoch','zahl','','',0,2,'system' UNION ALL SELECT 'grenzwertschalter','schaltpunkt_niedrig','Schaltpunkt Niedrig','zahl','','',0,3,'system' UNION ALL SELECT 'grenzwertschalter','einheit_schaltpunkt','Einheit Schaltpunkt','text','','',0,4,'system' UNION ALL SELECT 'grenzwertschalter','hysterese','Hysterese','zahl','','',0,5,'system' UNION ALL SELECT 'grenzwertschalter','schaltfunktion','Schaltfunktion','auswahl','Öffner (NC),Schließer (NO),Wechsler','',0,6,'system' UNION ALL SELECT 'grenzwertschalter','auslosung_geprueft','Auslösung geprüft','boolean','','',0,7,'system' UNION ALL SELECT 'grenzwertschalter','bemerkung','Bemerkung','text','','',0,8,'system')",
            // ── Frequenzumrichter ────────────────────────────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'frequenzumrichter','nennleistung','Nennleistung (kW)','zahl','','kW',1,1,'system' UNION ALL SELECT 'frequenzumrichter','nennstrom','Nennstrom Motor (A)','zahl','','A',1,2,'system' UNION ALL SELECT 'frequenzumrichter','nennspannung','Nennspannung (V)','zahl','','V',1,3,'system' UNION ALL SELECT 'frequenzumrichter','max_frequenz','Max. Ausgangsfrequenz (Hz)','zahl','','Hz',0,4,'system' UNION ALL SELECT 'frequenzumrichter','min_frequenz','Min. Frequenz (Hz)','zahl','','Hz',0,5,'system' UNION ALL SELECT 'frequenzumrichter','rampe_hochlauf','Rampenzeit Hochlauf (s)','zahl','','s',0,6,'system' UNION ALL SELECT 'frequenzumrichter','rampe_ruecklauf','Rampenzeit Rücklauf (s)','zahl','','s',0,7,'system' UNION ALL SELECT 'frequenzumrichter','steuerart','Steuerart','auswahl','U/f,FOC,DTC,Sensorlos','',0,8,'system' UNION ALL SELECT 'frequenzumrichter','motorschutz_a','Motorschutz eingestellt (A)','zahl','','A',0,9,'system' UNION ALL SELECT 'frequenzumrichter','drehrichtung','Drehrichtung geprüft','boolean','','',0,10,'system' UNION ALL SELECT 'frequenzumrichter','isolationswiderstand','Isolationswiderstand (MΩ)','zahl','','MΩ',0,11,'system' UNION ALL SELECT 'frequenzumrichter','emv_filter','EMV-Filter verbaut','boolean','','',0,12,'system' UNION ALL SELECT 'frequenzumrichter','bremswiderstand','Bremswiderstand verbaut','boolean','','',0,13,'system' UNION ALL SELECT 'frequenzumrichter','bemerkung','Bemerkung','text','','',0,14,'system')",
            // ── Sanftanlauf ──────────────────────────────────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'sanftanlauf','nennleistung','Nennleistung (kW)','zahl','','kW',1,1,'system' UNION ALL SELECT 'sanftanlauf','nennstrom','Nennstrom (A)','zahl','','A',1,2,'system' UNION ALL SELECT 'sanftanlauf','nennspannung','Nennspannung (V)','zahl','','V',1,3,'system' UNION ALL SELECT 'sanftanlauf','anlaufstrom','Anlaufstrombegrenzung (%In)','zahl','','%In',0,4,'system' UNION ALL SELECT 'sanftanlauf','anlaufzeit','Anlaufzeit (s)','zahl','','s',0,5,'system' UNION ALL SELECT 'sanftanlauf','stoppzeit','Stoppzeit (s)','zahl','','s',0,6,'system' UNION ALL SELECT 'sanftanlauf','bypass_schuetz','Bypass-Schütz verbaut','boolean','','',0,7,'system' UNION ALL SELECT 'sanftanlauf','drehrichtung','Drehrichtung geprüft','boolean','','',0,8,'system' UNION ALL SELECT 'sanftanlauf','isolationswiderstand','Isolationswiderstand (MΩ)','zahl','','MΩ',0,9,'system' UNION ALL SELECT 'sanftanlauf','bemerkung','Bemerkung','text','','',0,10,'system')",
            // ── Durchflussmesser ─────────────────────────────────────────────────
            R"(INSERT OR IGNORE INTO ibn_feldvorlage (symbol_kategorie,feldname,label,feldtyp,optionen,einheit,pflichtfeld,reihenfolge,erstellt_von) SELECT 'durchflussmesser','messprinzip','Messprinzip','auswahl','Magnetisch-induktiv,Ultraschall,Corioliskraft,Wirbelzähler,Differenzdruck,Thermisch','',1,1,'system' UNION ALL SELECT 'durchflussmesser','nennweite_dn','Nennweite DN (mm)','zahl','','mm',0,2,'system' UNION ALL SELECT 'durchflussmesser','messbereich_max','Messbereich max','zahl','','m³/h',0,3,'system' UNION ALL SELECT 'durchflussmesser','ausgangssignal','Ausgangssignal','auswahl','4-20mA,0-10V,Pulsausgang,HART,Feldbus','',0,4,'system' UNION ALL SELECT 'durchflussmesser','istwert','Istwert bei IBN','zahl','','m³/h',0,5,'system' UNION ALL SELECT 'durchflussmesser','kalibriert','Kalibriert','boolean','','',0,6,'system' UNION ALL SELECT 'durchflussmesser','bemerkung','Bemerkung','text','','',0,7,'system')",
            // ── Symbol → Kategorie-Mappings ──────────────────────────────────────
            R"(UPDATE symbol_definition SET ibn_kategorie='temperatursensor' WHERE id='sensor_temp')",
            R"(UPDATE symbol_definition SET ibn_kategorie='drucksensor'      WHERE id='sensor_druck')",
        }},

        { 60, "bauteil: url_hersteller + url_datenblatt", {
            R"(ALTER TABLE bauteil ADD COLUMN url_hersteller TEXT)",
            R"(ALTER TABLE bauteil ADD COLUMN url_datenblatt TEXT)",
        }},
        { 61, "Winkel: 8x8mm auf 4x4mm verkleinert (= 1 Rastereinheit)", {
            R"(UPDATE symbol_definition SET breite_mm=4, hoehe_mm=4 WHERE id='winkel' AND ist_builtin=1)",
        }},
        { 62, "klemme_anschluss: Doppelkreis (innerer Kreis r=0.12 als zweites Primitiv)", {
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('klemme_anschluss', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.12, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",
        }},
        { 63, "farb_definition: Transparent / farblos als Gehaeuse- und Aderfarbe", {
            R"(INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) SELECT 'transparent','Transparent / farblos',1,0 WHERE NOT EXISTS (SELECT 1 FROM farb_definition WHERE hex_wert='transparent'))",
        }},
        { 64, "Winkel: symbole.sql-Seed-Fix 8x8mm auf 4x4mm (Baseline-Seed hatte alten Wert)", {
            R"(UPDATE symbol_definition SET breite_mm=4, hoehe_mm=4 WHERE id='winkel' AND ist_builtin=1)",
        }},
        { 65, "bauteil: hauptfunktion_symbol_id – Symbolzuweisung für einfache Geräte (Lampe, Motor …)", {
            R"(ALTER TABLE bauteil ADD COLUMN hauptfunktion_symbol_id TEXT REFERENCES symbol_definition(id) ON DELETE SET NULL)",
        }},
        { 66, "bauteil_klemme: anschluss_typ vereinheitlicht (feder/kaefig/push_in statt federklemme/kaefigklemme/stecker)", {
            R"(UPDATE bauteil_klemme SET anschluss_typ='feder'   WHERE anschluss_typ='federklemme')",
            R"(UPDATE bauteil_klemme SET anschluss_typ='kaefig'  WHERE anschluss_typ='kaefigklemme')",
            R"(UPDATE bauteil_klemme SET anschluss_typ='schraube' WHERE anschluss_typ='stecker')",
        }},
        { 67, "betriebsmittel: bauteil_id; neue Tabelle bauteil_anschluss (Kontaktbezeichnungen für Schütz/Relais)", {
            R"(ALTER TABLE betriebsmittel ADD COLUMN bauteil_id INTEGER REFERENCES bauteil(id) ON DELETE SET NULL)",
            R"(CREATE TABLE IF NOT EXISTS bauteil_anschluss (
                id                    INTEGER PRIMARY KEY,
                bauteil_id            INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
                symbol_id             TEXT    NOT NULL,
                pin_name              TEXT    NOT NULL,
                anschluss_bezeichnung TEXT    NOT NULL
            ))",
        }},
        { 68, "spule-Symbol: A1 oben / A2 unten (vertikal statt horizontal)", {
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=32 WHERE id='spule')",
            R"(UPDATE symbol_pin SET x=0.5, y=0, offen_x=0, offen_y=-1 WHERE symbol_id='spule' AND name='A1')",
            R"(UPDATE symbol_pin SET x=0.5, y=1, offen_x=0, offen_y=1  WHERE symbol_id='spule' AND name='A2')",
            R"(UPDATE symbol_primitiv SET x1=0.5, y1=0,   x2=0.5, y2=0.2 WHERE symbol_id='spule' AND reihenfolge=0)",
            R"(UPDATE symbol_primitiv SET x1=0.5, y1=0.8, x2=0.5, y2=1   WHERE symbol_id='spule' AND reihenfolge=1)",
            R"(UPDATE symbol_primitiv SET x1=0.24, y1=0.2, x2=0.76, y2=0.8 WHERE symbol_id='spule' AND reihenfolge=2)",
        }},
        { 69, "spule-Symbol: quadratisch 16x16mm, Rechteck volle Breite (wie Nutzer-Kopie)", {
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='spule')",
            R"(UPDATE symbol_primitiv SET x1=0.5, y1=0,    x2=0.5, y2=0.25 WHERE symbol_id='spule' AND reihenfolge=0)",
            R"(UPDATE symbol_primitiv SET x1=0.5, y1=0.75, x2=0.5, y2=1    WHERE symbol_id='spule' AND reihenfolge=1)",
            R"(UPDATE symbol_primitiv SET x1=0.0, y1=0.25, x2=1.0, y2=0.75 WHERE symbol_id='spule' AND reihenfolge=2)",
        }},
        { 70, "symbol_definition: bmk_seite-Spalte; spule bekommt 'vertikal' (BMK links statt oben)", {
            R"(ALTER TABLE symbol_definition ADD COLUMN bmk_seite TEXT NOT NULL DEFAULT 'auto')",
            R"(UPDATE symbol_definition SET bmk_seite = 'vertikal' WHERE id = 'spule')",
        }},
        { 71, "bauteil_anschluss → bauteil_kontakt (Bezeichnung + pin_bez JSON pro Kontakt)", {
            R"(DROP TABLE IF EXISTS bauteil_anschluss)",
            R"(CREATE TABLE IF NOT EXISTS bauteil_kontakt (
                id         INTEGER PRIMARY KEY,
                bauteil_id INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
                symbol_id  TEXT    NOT NULL,
                bezeichnung TEXT   NOT NULL DEFAULT '',
                pin_bez    TEXT    NOT NULL DEFAULT '{}'
            ))",
        }},
        { 72, "isoliert_gelegte_ader-Symbol: abgerundete Aderspitze (wie Nutzer-Kopie)", {
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='isoliert_gelegte_ader')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
                ('isoliert_gelegte_ader', 0, 'linie', 0,       0.5,     0.65625, 0.5,     0, 0, 0,                    0,                  0,                  0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
                ('isoliert_gelegte_ader', 1, 'bogen', 0.6875,  0.4375,  0,       0,       0, 0, 0.069877124296868431, 206.56505117707798, 116.56505117707799, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
                ('isoliert_gelegte_ader', 2, 'bogen', 0.53125, 0.46875, 0,       0,       0, 0, 0.15625,              180,                180,                0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
                ('isoliert_gelegte_ader', 3, 'linie', 0.5,     0.46875, 0.40625, 0.46875, 0, 0, 0,                    0,                  0,                  0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
                ('isoliert_gelegte_ader', 4, 'bogen', 0.46875, 0.25,    0,       0,       0, 0, 0.22097086912079608,  45,                 81.869897645844034, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",
        }},
        { 73, "ard_uno/ard_nano/ard_mega: Hoehe auf Vielfaches von 8mm vergroessert (ARD-GRID-02)", {
            // Neu platzierte Symbole snappen mit ihrem Mittelpunkt aufs 4mm-Raster
            // (SchaltplanCanvas.symbolVorschauErstellen: x1 = wx - defW/2). Damit
            // auch alle Pins exakt auf dem Raster landen, muss die halbe Hoehe
            // ebenfalls ein Vielfaches von 4mm sein, d.h. die Hoehe ein Vielfaches
            // von 8mm. Bisher 60/60/84mm (Vielfache von 4, aber nicht von 8) →
            // jetzt 64/64/88mm (1 zusaetzliche Raster-Einheit Rand unten).
            R"(UPDATE symbol_definition SET hoehe_mm=64 WHERE id='ard_uno'  AND ist_builtin=1)",
            R"(UPDATE symbol_definition SET hoehe_mm=64 WHERE id='ard_nano' AND ist_builtin=1)",
            R"(UPDATE symbol_definition SET hoehe_mm=88 WHERE id='ard_mega' AND ist_builtin=1)",
            R"(DELETE FROM symbol_pin WHERE symbol_id IN ('ard_uno','ard_nano','ard_mega'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
                ('ard_uno', 'D0',  0, 0.0625, -1, 0, 'neutral'),
                ('ard_uno', 'D1',  0, 0.1250, -1, 0, 'neutral'),
                ('ard_uno', 'D2',  0, 0.1875, -1, 0, 'neutral'),
                ('ard_uno', 'D3',  0, 0.2500, -1, 0, 'neutral'),
                ('ard_uno', 'D4',  0, 0.3125, -1, 0, 'neutral'),
                ('ard_uno', 'D5',  0, 0.3750, -1, 0, 'neutral'),
                ('ard_uno', 'D6',  0, 0.4375, -1, 0, 'neutral'),
                ('ard_uno', 'D7',  0, 0.5000, -1, 0, 'neutral'),
                ('ard_uno', 'D8',  0, 0.5625, -1, 0, 'neutral'),
                ('ard_uno', 'D9',  0, 0.6250, -1, 0, 'neutral'),
                ('ard_uno', 'D10', 0, 0.6875, -1, 0, 'neutral'),
                ('ard_uno', 'D11', 0, 0.7500, -1, 0, 'neutral'),
                ('ard_uno', 'D12', 0, 0.8125, -1, 0, 'neutral'),
                ('ard_uno', 'D13', 0, 0.8750, -1, 0, 'neutral'),
                ('ard_uno', 'RST',  1, 0.0625, 1, 0, 'neutral'),
                ('ard_uno', '3V3',  1, 0.1250, 1, 0, 'neutral'),
                ('ard_uno', '5V',   1, 0.1875, 1, 0, 'neutral'),
                ('ard_uno', 'GND',  1, 0.2500, 1, 0, 'neutral'),
                ('ard_uno', 'GND2', 1, 0.3125, 1, 0, 'neutral'),
                ('ard_uno', 'Vin',  1, 0.3750, 1, 0, 'neutral'),
                ('ard_uno', 'A0',   1, 0.5000, 1, 0, 'neutral'),
                ('ard_uno', 'A1',   1, 0.5625, 1, 0, 'neutral'),
                ('ard_uno', 'A2',   1, 0.6250, 1, 0, 'neutral'),
                ('ard_uno', 'A3',   1, 0.6875, 1, 0, 'neutral'),
                ('ard_uno', 'A4',   1, 0.7500, 1, 0, 'neutral'),
                ('ard_uno', 'A5',   1, 0.8125, 1, 0, 'neutral'),
                ('ard_uno', 'AREF', 1, 0.8750, 1, 0, 'neutral'),
                ('ard_nano', 'D0',  0, 0.0625, -1, 0, 'neutral'),
                ('ard_nano', 'D1',  0, 0.1250, -1, 0, 'neutral'),
                ('ard_nano', 'D2',  0, 0.1875, -1, 0, 'neutral'),
                ('ard_nano', 'D3',  0, 0.2500, -1, 0, 'neutral'),
                ('ard_nano', 'D4',  0, 0.3125, -1, 0, 'neutral'),
                ('ard_nano', 'D5',  0, 0.3750, -1, 0, 'neutral'),
                ('ard_nano', 'D6',  0, 0.4375, -1, 0, 'neutral'),
                ('ard_nano', 'D7',  0, 0.5000, -1, 0, 'neutral'),
                ('ard_nano', 'D8',  0, 0.5625, -1, 0, 'neutral'),
                ('ard_nano', 'D9',  0, 0.6250, -1, 0, 'neutral'),
                ('ard_nano', 'D10', 0, 0.6875, -1, 0, 'neutral'),
                ('ard_nano', 'D11', 0, 0.7500, -1, 0, 'neutral'),
                ('ard_nano', 'D12', 0, 0.8125, -1, 0, 'neutral'),
                ('ard_nano', 'D13', 0, 0.8750, -1, 0, 'neutral'),
                ('ard_nano', 'RST',  1, 0.0625, 1, 0, 'neutral'),
                ('ard_nano', '3V3',  1, 0.1250, 1, 0, 'neutral'),
                ('ard_nano', '5V',   1, 0.1875, 1, 0, 'neutral'),
                ('ard_nano', 'GND',  1, 0.2500, 1, 0, 'neutral'),
                ('ard_nano', 'GND2', 1, 0.3125, 1, 0, 'neutral'),
                ('ard_nano', 'Vin',  1, 0.3750, 1, 0, 'neutral'),
                ('ard_nano', 'A0',   1, 0.4375, 1, 0, 'neutral'),
                ('ard_nano', 'A1',   1, 0.5000, 1, 0, 'neutral'),
                ('ard_nano', 'A2',   1, 0.5625, 1, 0, 'neutral'),
                ('ard_nano', 'A3',   1, 0.6250, 1, 0, 'neutral'),
                ('ard_nano', 'A4',   1, 0.6875, 1, 0, 'neutral'),
                ('ard_nano', 'A5',   1, 0.7500, 1, 0, 'neutral'),
                ('ard_nano', 'A6',   1, 0.8125, 1, 0, 'neutral'),
                ('ard_nano', 'A7',   1, 0.8750, 1, 0, 'neutral'),
                ('ard_mega', 'D0',  0, 0.0455, -1, 0, 'neutral'),
                ('ard_mega', 'D1',  0, 0.0909, -1, 0, 'neutral'),
                ('ard_mega', 'D2',  0, 0.1364, -1, 0, 'neutral'),
                ('ard_mega', 'D3',  0, 0.1818, -1, 0, 'neutral'),
                ('ard_mega', 'D4',  0, 0.2273, -1, 0, 'neutral'),
                ('ard_mega', 'D5',  0, 0.2727, -1, 0, 'neutral'),
                ('ard_mega', 'D6',  0, 0.3182, -1, 0, 'neutral'),
                ('ard_mega', 'D7',  0, 0.3636, -1, 0, 'neutral'),
                ('ard_mega', 'D8',  0, 0.4091, -1, 0, 'neutral'),
                ('ard_mega', 'D9',  0, 0.4545, -1, 0, 'neutral'),
                ('ard_mega', 'D10', 0, 0.5000, -1, 0, 'neutral'),
                ('ard_mega', 'D11', 0, 0.5455, -1, 0, 'neutral'),
                ('ard_mega', 'D12', 0, 0.5909, -1, 0, 'neutral'),
                ('ard_mega', 'D13', 0, 0.6364, -1, 0, 'neutral'),
                ('ard_mega', 'D14', 0, 0.6818, -1, 0, 'neutral'),
                ('ard_mega', 'D15', 0, 0.7273, -1, 0, 'neutral'),
                ('ard_mega', 'D16', 0, 0.7727, -1, 0, 'neutral'),
                ('ard_mega', 'D17', 0, 0.8182, -1, 0, 'neutral'),
                ('ard_mega', 'D18', 0, 0.8636, -1, 0, 'neutral'),
                ('ard_mega', 'D19', 0, 0.9091, -1, 0, 'neutral'),
                ('ard_mega', 'RST',  1, 0.0455, 1, 0, 'neutral'),
                ('ard_mega', '5V',   1, 0.0909, 1, 0, 'neutral'),
                ('ard_mega', '3V3',  1, 0.1364, 1, 0, 'neutral'),
                ('ard_mega', 'GND',  1, 0.1818, 1, 0, 'neutral'),
                ('ard_mega', 'GND2', 1, 0.2273, 1, 0, 'neutral'),
                ('ard_mega', 'Vin',  1, 0.2727, 1, 0, 'neutral'),
                ('ard_mega', 'A0',   1, 0.3182, 1, 0, 'neutral'),
                ('ard_mega', 'A1',   1, 0.3636, 1, 0, 'neutral'),
                ('ard_mega', 'A2',   1, 0.4091, 1, 0, 'neutral'),
                ('ard_mega', 'A3',   1, 0.4545, 1, 0, 'neutral'),
                ('ard_mega', 'A4',   1, 0.5000, 1, 0, 'neutral'),
                ('ard_mega', 'A5',   1, 0.5455, 1, 0, 'neutral'),
                ('ard_mega', 'A6',   1, 0.5909, 1, 0, 'neutral'),
                ('ard_mega', 'A7',   1, 0.6364, 1, 0, 'neutral'),
                ('ard_mega', 'A8',   1, 0.6818, 1, 0, 'neutral'),
                ('ard_mega', 'A9',   1, 0.7273, 1, 0, 'neutral'),
                ('ard_mega', 'A10',  1, 0.7727, 1, 0, 'neutral'),
                ('ard_mega', 'A11',  1, 0.8182, 1, 0, 'neutral'),
                ('ard_mega', 'A12',  1, 0.8636, 1, 0, 'neutral'),
                ('ard_mega', 'A13',  1, 0.9091, 1, 0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id IN ('ard_uno','ard_nano','ard_mega'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
                ('ard_uno',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,      0.5,   0, 'center', 'middle', 'solid'),
                ('ard_uno',  1, 'text',     0.5,  0.4031, 0,  0,    0, 0, 0, 0, 0, 0, 'Arduino', 0.055, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  2, 'text',     0.5,  0.5156, 0,  0,    0, 0, 0, 0, 0, 0, 'UNO',     0.09,  1, 'center', 'middle', 'solid'),
                ('ard_uno',  3, 'linie', 0, 0.0625, 0.15, 0.0625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  4, 'linie', 0, 0.1250, 0.15, 0.1250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  5, 'linie', 0, 0.1875, 0.15, 0.1875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  6, 'linie', 0, 0.2500, 0.15, 0.2500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  7, 'linie', 0, 0.3125, 0.15, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  8, 'linie', 0, 0.3750, 0.15, 0.3750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno',  9, 'linie', 0, 0.4375, 0.15, 0.4375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 10, 'linie', 0, 0.5000, 0.15, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 11, 'linie', 0, 0.5625, 0.15, 0.5625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 12, 'linie', 0, 0.6250, 0.15, 0.6250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 13, 'linie', 0, 0.6875, 0.15, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 14, 'linie', 0, 0.7500, 0.15, 0.7500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 15, 'linie', 0, 0.8125, 0.15, 0.8125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 16, 'linie', 0, 0.8750, 0.15, 0.8750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 17, 'linie', 0.85, 0.0625, 1.0, 0.0625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 18, 'linie', 0.85, 0.1250, 1.0, 0.1250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 19, 'linie', 0.85, 0.1875, 1.0, 0.1875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 20, 'linie', 0.85, 0.2500, 1.0, 0.2500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 21, 'linie', 0.85, 0.3125, 1.0, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 22, 'linie', 0.85, 0.3750, 1.0, 0.3750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 23, 'linie', 0.85, 0.5000, 1.0, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 24, 'linie', 0.85, 0.5625, 1.0, 0.5625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 25, 'linie', 0.85, 0.6250, 1.0, 0.6250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 26, 'linie', 0.85, 0.6875, 1.0, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 27, 'linie', 0.85, 0.7500, 1.0, 0.7500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 28, 'linie', 0.85, 0.8125, 1.0, 0.8125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_uno', 29, 'linie', 0.85, 0.8750, 1.0, 0.8750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,      0.5,   0, 'center', 'middle', 'solid'),
                ('ard_nano',  1, 'text',     0.5,  0.4031, 0,  0,    0, 0, 0, 0, 0, 0, 'Arduino', 0.055, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  2, 'text',     0.5,  0.5156, 0,  0,    0, 0, 0, 0, 0, 0, 'NANO',    0.09,  1, 'center', 'middle', 'solid'),
                ('ard_nano',  3, 'linie', 0, 0.0625, 0.15, 0.0625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  4, 'linie', 0, 0.1250, 0.15, 0.1250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  5, 'linie', 0, 0.1875, 0.15, 0.1875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  6, 'linie', 0, 0.2500, 0.15, 0.2500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  7, 'linie', 0, 0.3125, 0.15, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  8, 'linie', 0, 0.3750, 0.15, 0.3750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano',  9, 'linie', 0, 0.4375, 0.15, 0.4375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 10, 'linie', 0, 0.5000, 0.15, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 11, 'linie', 0, 0.5625, 0.15, 0.5625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 12, 'linie', 0, 0.6250, 0.15, 0.6250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 13, 'linie', 0, 0.6875, 0.15, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 14, 'linie', 0, 0.7500, 0.15, 0.7500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 15, 'linie', 0, 0.8125, 0.15, 0.8125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 16, 'linie', 0, 0.8750, 0.15, 0.8750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 17, 'linie', 0.85, 0.0625, 1.0, 0.0625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 18, 'linie', 0.85, 0.1250, 1.0, 0.1250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 19, 'linie', 0.85, 0.1875, 1.0, 0.1875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 20, 'linie', 0.85, 0.2500, 1.0, 0.2500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 21, 'linie', 0.85, 0.3125, 1.0, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 22, 'linie', 0.85, 0.3750, 1.0, 0.3750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 23, 'linie', 0.85, 0.4375, 1.0, 0.4375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 24, 'linie', 0.85, 0.5000, 1.0, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 25, 'linie', 0.85, 0.5625, 1.0, 0.5625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 26, 'linie', 0.85, 0.6250, 1.0, 0.6250, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 27, 'linie', 0.85, 0.6875, 1.0, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 28, 'linie', 0.85, 0.7500, 1.0, 0.7500, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 29, 'linie', 0.85, 0.8125, 1.0, 0.8125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_nano', 30, 'linie', 0.85, 0.8750, 1.0, 0.8750, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,      0.5,   0, 'center', 'middle', 'solid'),
                ('ard_mega',  1, 'text',     0.5,  0.42,   0,  0,    0, 0, 0, 0, 0, 0, 'Arduino', 0.055, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  2, 'text',     0.5,  0.5155, 0,  0,    0, 0, 0, 0, 0, 0, 'MEGA',    0.075, 1, 'center', 'middle', 'solid'),
                ('ard_mega',  3, 'linie', 0, 0.0455, 0.15, 0.0455, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  4, 'linie', 0, 0.0909, 0.15, 0.0909, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  5, 'linie', 0, 0.1364, 0.15, 0.1364, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  6, 'linie', 0, 0.1818, 0.15, 0.1818, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  7, 'linie', 0, 0.2273, 0.15, 0.2273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  8, 'linie', 0, 0.2727, 0.15, 0.2727, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega',  9, 'linie', 0, 0.3182, 0.15, 0.3182, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 10, 'linie', 0, 0.3636, 0.15, 0.3636, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 11, 'linie', 0, 0.4091, 0.15, 0.4091, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 12, 'linie', 0, 0.4545, 0.15, 0.4545, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 13, 'linie', 0, 0.5000, 0.15, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 14, 'linie', 0, 0.5455, 0.15, 0.5455, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 15, 'linie', 0, 0.5909, 0.15, 0.5909, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 16, 'linie', 0, 0.6364, 0.15, 0.6364, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 17, 'linie', 0, 0.6818, 0.15, 0.6818, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 18, 'linie', 0, 0.7273, 0.15, 0.7273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 19, 'linie', 0, 0.7727, 0.15, 0.7727, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 20, 'linie', 0, 0.8182, 0.15, 0.8182, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 21, 'linie', 0, 0.8636, 0.15, 0.8636, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 22, 'linie', 0, 0.9091, 0.15, 0.9091, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 23, 'linie', 0.85, 0.0455, 1.0, 0.0455, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 24, 'linie', 0.85, 0.0909, 1.0, 0.0909, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 25, 'linie', 0.85, 0.1364, 1.0, 0.1364, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 26, 'linie', 0.85, 0.1818, 1.0, 0.1818, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 27, 'linie', 0.85, 0.2273, 1.0, 0.2273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 28, 'linie', 0.85, 0.2727, 1.0, 0.2727, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 29, 'linie', 0.85, 0.3182, 1.0, 0.3182, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 30, 'linie', 0.85, 0.3636, 1.0, 0.3636, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 31, 'linie', 0.85, 0.4091, 1.0, 0.4091, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 32, 'linie', 0.85, 0.4545, 1.0, 0.4545, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 33, 'linie', 0.85, 0.5000, 1.0, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 34, 'linie', 0.85, 0.5455, 1.0, 0.5455, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 35, 'linie', 0.85, 0.5909, 1.0, 0.5909, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 36, 'linie', 0.85, 0.6364, 1.0, 0.6364, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 37, 'linie', 0.85, 0.6818, 1.0, 0.6818, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 38, 'linie', 0.85, 0.7273, 1.0, 0.7273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 39, 'linie', 0.85, 0.7727, 1.0, 0.7727, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 40, 'linie', 0.85, 0.8182, 1.0, 0.8182, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 41, 'linie', 0.85, 0.8636, 1.0, 0.8636, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
                ('ard_mega', 42, 'linie', 0.85, 0.9091, 1.0, 0.9091, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 74, "ard_hcsr04: Hoehe auf Vielfaches von 8mm vergroessert (ARD-GRID-03)", {
            // Gleicher Root-Cause wie ARD-GRID-02: Mittelpunkt-Snap aufs 4mm-Raster.
            // 20mm ist kein Vielfaches von 8mm → 24mm (3×8mm).
            // Pin-Positionen bleiben an absolut gleicher mm-Position (4/8/12/16mm),
            // normierte y-Werte aendern sich durch groesseren Nenner: k/(N+2) statt k/(N+1).
            R"(UPDATE symbol_definition SET hoehe_mm=24 WHERE id='ard_hcsr04' AND ist_builtin=1)",
            R"(UPDATE symbol_pin SET y=0.1667 WHERE symbol_id='ard_hcsr04' AND name='VCC')",
            R"(UPDATE symbol_pin SET y=0.3333 WHERE symbol_id='ard_hcsr04' AND name='TRIG')",
            R"(UPDATE symbol_pin SET y=0.5000 WHERE symbol_id='ard_hcsr04' AND name='ECHO')",
            R"(UPDATE symbol_pin SET y=0.6667 WHERE symbol_id='ard_hcsr04' AND name='GND')",
            R"(UPDATE symbol_primitiv SET y1=0.1667, y2=0.1667 WHERE symbol_id='ard_hcsr04' AND reihenfolge=2)",
            R"(UPDATE symbol_primitiv SET y1=0.3333, y2=0.3333 WHERE symbol_id='ard_hcsr04' AND reihenfolge=3)",
            R"(UPDATE symbol_primitiv SET y1=0.5000, y2=0.5000 WHERE symbol_id='ard_hcsr04' AND reihenfolge=4)",
            R"(UPDATE symbol_primitiv SET y1=0.6667, y2=0.6667 WHERE symbol_id='ard_hcsr04' AND reihenfolge=5)",
            R"(UPDATE symbol_primitiv SET y1=0.1667 WHERE symbol_id='ard_hcsr04' AND reihenfolge=6)",
            R"(UPDATE symbol_primitiv SET y1=0.3333 WHERE symbol_id='ard_hcsr04' AND reihenfolge=7)",
            R"(UPDATE symbol_primitiv SET y1=0.5000 WHERE symbol_id='ard_hcsr04' AND reihenfolge=8)",
            R"(UPDATE symbol_primitiv SET y1=0.6667 WHERE symbol_id='ard_hcsr04' AND reihenfolge=9)",
        }},
        { 75, "Steckverbinder-Bibliothek: steckverbinder_typ / _kabeleinf / _kontakt_typ", {
            R"(CREATE TABLE IF NOT EXISTS steckverbinder_typ (
                id                  INTEGER PRIMARY KEY,
                bauteil_id          INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
                polzahl             INTEGER,
                ip_getrennt         TEXT,
                ip_gesteckt         TEXT,
                kodierung           TEXT,
                verriegelung        TEXT,
                hat_schirmkontakt   INTEGER DEFAULT 0,
                geschirmt           INTEGER DEFAULT 0
            ))",
            R"(CREATE TABLE IF NOT EXISTS steckverbinder_kabeleinf (
                id                      INTEGER PRIMARY KEY,
                steckverbinder_typ_id   INTEGER NOT NULL REFERENCES steckverbinder_typ(id) ON DELETE CASCADE,
                einf_nr                 INTEGER NOT NULL DEFAULT 1,
                aussen_min_mm           REAL,
                aussen_max_mm           REAL,
                einf_typ                TEXT,
                zugentlastung           TEXT
            ))",
            R"(CREATE TABLE IF NOT EXISTS steckverbinder_kontakt_typ (
                id                      INTEGER PRIMARY KEY,
                steckverbinder_typ_id   INTEGER NOT NULL REFERENCES steckverbinder_typ(id) ON DELETE CASCADE,
                position_nr             INTEGER NOT NULL,
                ist_schirmkontakt       INTEGER DEFAULT 0,
                kontaktgroesse          TEXT,
                querschnitt_kabel_min   REAL,
                querschnitt_kabel_max   REAL,
                nennstrom_a             REAL,
                nennspannung_v          REAL,
                verbindungstechnik      TEXT
            ))",
        }},

        // NKZ-02b: anlage_uebergeordnet (==) / standort_uebergeordnet (++) projektweit
        // direkt an Anlage/Ort statt nur über Strukturkasten pro Seite. Analog zu
        // klemmenleiste.anlage_uebergeordnet/standort_uebergeordnet (bereits seit Klemmenreihen-Feature).
        // seite_kennzeichen-View korrigiert: nutzte bisher nie beschriebene seite.anlage_kuerzel/
        // ort_kuerzel-Spalten statt der echten ort/anlage-Verknüpfung (toter Code, war unbenutzt).
        { 76, "anlage/ort: anlage_uebergeordnet/standort_uebergeordnet (==/++ projektweit); seite_kennzeichen-View korrigiert", {
            R"(ALTER TABLE anlage ADD COLUMN anlage_uebergeordnet TEXT)",
            R"(ALTER TABLE ort ADD COLUMN standort_uebergeordnet TEXT)",
            R"(DROP VIEW IF EXISTS seite_kennzeichen)",
            R"(CREATE VIEW seite_kennzeichen AS
                SELECT s.id, s.bezeichnung, s.blattnummer, s.seitentyp,
                       s.breite_mm, s.hoehe_mm, s.sortierung, s.parent_id,
                       COALESCE('==' || a.anlage_uebergeordnet, '') ||
                       COALESCE('++' || o.standort_uebergeordnet, '') ||
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       '/' || s.blattnummer AS vollkennzeichen
                FROM seite s
                LEFT JOIN ort o ON s.ort_id = o.id
                LEFT JOIN anlage a ON o.anlage_id = a.id)",
        }},

        // D-02: Canvas-Bilder (grafik_element.bild_daten, BLOB) verdoppelten bei jedem
        // Speichern (DELETE+INSERT aller Elemente) die vollen Bild-Bytes und bliesen
        // jeden Git-Auto-Commit auf. Auslagerung in Dateien (m_grafikBilderDir/<hash>.<ext>),
        // analog zum Wiki-Vorbild (wiki_bild.daten → blob_pfad, Schema v11). Leere
        // statements-Liste: läuft über den Sonderfall migriereGrafikBilderAufDateien()
        // in der Dispatch-Schleife unten (braucht Datei-I/O, nicht reines SQL).
        { 77, "Canvas-Bilder (grafik_element.bild_daten) aus BLOB in bilder/-Dateien ausgelagert", {} },

        // Tote BLOB-Spalten ohne jegliche Code-Referenz – beim D-02-Blast-Radius-Check gefunden.
        { 78, "Tote BLOB-Spalten gedroppt (normblatt_vorlage.logo_data, bauteil.bild_data)", {
            R"(ALTER TABLE normblatt_vorlage DROP COLUMN logo_data)",
            R"(ALTER TABLE bauteil DROP COLUMN bild_data)",
        }},

        // SCHRIFT-STRICH-01: Schriftgröße (Text/Notiz) missbrauchte bislang strich_breite
        // (Strichstärke). Wird jetzt in extra_daten.schriftgroesse gespeichert. Bestehende
        // Text/Notiz-Elemente einmalig migrieren, damit ihre bisherige Schriftgröße optisch
        // erhalten bleibt (idempotent über die IS NULL-Bedingung).
        { 79, "Schriftgröße (Text/Notiz) von strich_breite nach extra_daten.schriftgroesse migriert", {
            R"(UPDATE grafik_element
               SET extra_daten = json_set(COALESCE(extra_daten, '{}'), '$.schriftgroesse', strich_breite)
               WHERE typ IN ('text', 'notiz')
                 AND json_extract(COALESCE(extra_daten, '{}'), '$.schriftgroesse') IS NULL)",
        }},

        // ARCH-01: Bauteil-Tabellen in projektübergreifende bibliothek.db ausgelagert.
        // betriebsmittel/klemme/kabel werden neu gebaut (FK-Constraints zu Bauteil-Tabellen
        // entfernt); danach alle bauteil*- und steckverbinder*-Tabellen gedroppt.
        { 80, "ARCH-01: bauteil*-Tabellen aus Projekt-DB in bibliothek.db ausgelagert", {
            // Läuft mit PRAGMA foreign_keys = OFF (checkAndApplySchema setzt es vor der
            // Transaktion zurück) → DROP TABLE der Parents trotz Child-Rows möglich.
            // legacy_alter_table = ON → ALTER TABLE RENAME validiert keine Views
            // (betriebsmittel_bmk bleibt erhalten, zeigt nach Rename auf neue Tabelle).
            R"(PRAGMA legacy_alter_table = ON)",
            // betriebsmittel: bauteil_id INTEGER (kein FK zu bauteil mehr)
            R"(CREATE TABLE betriebsmittel_new (
                id                      INTEGER PRIMARY KEY,
                projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
                bauteil_id              INTEGER,
                symbol_code             TEXT,
                anlage_uebergeordnet    TEXT,
                standort_uebergeordnet  TEXT,
                funktion                TEXT,
                einbauort               TEXT,
                betriebsmittel_kz       TEXT NOT NULL,
                bezeichnung             TEXT,
                bemerkung               TEXT,
                haupt_element_id        INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
            ))",
            R"(INSERT INTO betriebsmittel_new SELECT * FROM betriebsmittel)",
            R"(DROP TABLE betriebsmittel)",
            R"(ALTER TABLE betriebsmittel_new RENAME TO betriebsmittel)",
            // klemme: bauteil_id INTEGER (kein FK zu bauteil mehr)
            R"(CREATE TABLE klemme_new (
                id               INTEGER PRIMARY KEY,
                klemmenleiste_id INTEGER NOT NULL REFERENCES klemmenleiste(id),
                bauteil_id       INTEGER,
                nummer           TEXT NOT NULL DEFAULT '',
                sortierung       INTEGER DEFAULT 0,
                bemerkung        TEXT
            ))",
            R"(INSERT INTO klemme_new SELECT * FROM klemme)",
            R"(DROP TABLE klemme)",
            R"(ALTER TABLE klemme_new RENAME TO klemme)",
            // kabel: bauteil_kabel_id INTEGER (kein FK zu bauteil_kabel mehr)
            R"(CREATE TABLE kabel_new (
                id                INTEGER PRIMARY KEY,
                projekt_id        INTEGER NOT NULL REFERENCES projekt(id),
                bezeichnung       TEXT NOT NULL,
                kabeltyp          TEXT,
                aderzahl          INTEGER,
                querschnitt_mm2   REAL,
                laenge_m          REAL,
                farbe_mantel      TEXT,
                von_ort           TEXT,
                nach_ort          TEXT,
                bemerkung         TEXT,
                bauteil_kabel_id  INTEGER,
                grafik_element_id INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
            ))",
            R"(INSERT INTO kabel_new SELECT * FROM kabel)",
            R"(DROP TABLE kabel)",
            R"(ALTER TABLE kabel_new RENAME TO kabel)",
            R"(PRAGMA legacy_alter_table = OFF)",
            // Alle Bauteil-Tabellen aus dem Projekt droppen (in Abhängigkeitsreihenfolge)
            R"(DROP TABLE IF EXISTS bauteil_kontakt)",
            R"(DROP TABLE IF EXISTS bauteil_anschluss)",
            R"(DROP TABLE IF EXISTS bauteil_klemme_eigenschaft)",
            R"(DROP TABLE IF EXISTS bauteil_klemme_bruecke)",
            R"(DROP TABLE IF EXISTS bauteil_klemme_querschnitt)",
            R"(DROP TABLE IF EXISTS bauteil_klemme)",
            R"(DROP TABLE IF EXISTS bauteil_kabel_paar)",
            R"(DROP TABLE IF EXISTS bauteil_kabel_ader)",
            R"(DROP TABLE IF EXISTS bauteil_kabel)",
            R"(DROP TABLE IF EXISTS steckverbinder_kabeleinf)",
            R"(DROP TABLE IF EXISTS steckverbinder_kontakt_typ)",
            R"(DROP TABLE IF EXISTS steckverbinder_typ)",
            R"(DROP TABLE IF EXISTS bauteil)",
            R"(DROP TABLE IF EXISTS farb_definition)",
            R"(DROP TABLE IF EXISTS bauteil_kategorie)",
        }},
        { 81, "klemmenleiste: highlight_override-Spalte (NULL=global, 0=aus, 1=ein)", {
            R"(ALTER TABLE klemmenleiste ADD COLUMN highlight_override INTEGER)",
        }},
        { 83, "betriebsmittel: funktion/einbauort/anlage_uo/standort_uo entfernen, ort_id FK ergaenzen; betriebsmittel_bmk View auf anlage/ort umstellen", {
            R"(DROP VIEW betriebsmittel_bmk)",
            R"(ALTER TABLE betriebsmittel DROP COLUMN anlage_uebergeordnet)",
            R"(ALTER TABLE betriebsmittel DROP COLUMN standort_uebergeordnet)",
            R"(ALTER TABLE betriebsmittel DROP COLUMN funktion)",
            R"(ALTER TABLE betriebsmittel DROP COLUMN einbauort)",
            R"(ALTER TABLE betriebsmittel ADD COLUMN ort_id INTEGER REFERENCES ort(id))",
            R"(CREATE VIEW betriebsmittel_bmk AS
                SELECT b.id, b.betriebsmittel_kz, b.projekt_id,
                       COALESCE('==' || a.anlage_uebergeordnet, '') ||
                       COALESCE('++' || o.standort_uebergeordnet, '') ||
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       '-' || b.betriebsmittel_kz AS bmk_vollstaendig,
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       '-' || b.betriebsmittel_kz AS bmk_kurz
                FROM betriebsmittel b
                LEFT JOIN ort o ON o.id = b.ort_id
                LEFT JOIN anlage a ON a.id = o.anlage_id)",
        }},
        { 82, "klemmenleiste: anlage_uebergeordnet/standort_uebergeordnet entfernen; klemmenleiste_bmk View auf anlage/ort-Tabellen umstellen", {
            R"(DROP VIEW klemmenleiste_bmk)",
            R"(ALTER TABLE klemmenleiste DROP COLUMN anlage_uebergeordnet)",
            R"(ALTER TABLE klemmenleiste DROP COLUMN standort_uebergeordnet)",
            R"(CREATE VIEW klemmenleiste_bmk AS
                SELECT kl.id, kl.bezeichnung, kl.projekt_id,
                       COALESCE('==' || a.anlage_uebergeordnet, '') ||
                       COALESCE('++' || o.standort_uebergeordnet, '') ||
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       '-' || kl.bezeichnung AS bmk_vollstaendig,
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       '-' || kl.bezeichnung AS bmk_kurz
                FROM klemmenleiste kl
                LEFT JOIN ort o ON o.id = kl.ort_id
                LEFT JOIN anlage a ON a.id = o.anlage_id)",
        }},
        { 85, "klemmenleiste_bmk: doppeltes Minus entfernt (geraet_kuerzel enthält führendes Minus aus GK-BMK)", {
            R"(DROP VIEW klemmenleiste_bmk)",
            R"(CREATE VIEW klemmenleiste_bmk AS
                SELECT kl.id, kl.bezeichnung, kl.projekt_id,
                       COALESCE('==' || a.anlage_uebergeordnet, '') ||
                       COALESCE('++' || o.standort_uebergeordnet, '') ||
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       COALESCE(kl.geraet_kuerzel,'') ||
                       '-' || kl.bezeichnung AS bmk_vollstaendig,
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       COALESCE(kl.geraet_kuerzel,'') ||
                       '-' || kl.bezeichnung AS bmk_kurz
                FROM klemmenleiste kl
                LEFT JOIN ort o ON o.id = kl.ort_id
                LEFT JOIN anlage a ON a.id = o.anlage_id)",
        }},
        { 84, "klemmenleiste: geraet_kuerzel-Spalte; klemmenleiste_bmk View mit optionalem Geraetepraefixes (-GK-Leiste)", {
            R"(ALTER TABLE klemmenleiste ADD COLUMN geraet_kuerzel TEXT DEFAULT '')",
            R"(DROP VIEW klemmenleiste_bmk)",
            R"(CREATE VIEW klemmenleiste_bmk AS
                SELECT kl.id, kl.bezeichnung, kl.projekt_id,
                       COALESCE('==' || a.anlage_uebergeordnet, '') ||
                       COALESCE('++' || o.standort_uebergeordnet, '') ||
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       COALESCE(kl.geraet_kuerzel,'') ||
                       '-' || kl.bezeichnung AS bmk_vollstaendig,
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       COALESCE(kl.geraet_kuerzel,'') ||
                       '-' || kl.bezeichnung AS bmk_kurz
                FROM klemmenleiste kl
                LEFT JOIN ort o ON o.id = kl.ort_id
                LEFT JOIN anlage a ON a.id = o.anlage_id)",
        }},
        { 86, "symbol_pin: knoten_gruppe fuer Mehrpol-Bauteile mit galvanisch getrennten Pins (NETZ-MEHRPOL-01)", {
            R"(ALTER TABLE symbol_pin ADD COLUMN knoten_gruppe INTEGER NOT NULL DEFAULT 0)",
            R"(UPDATE symbol_pin SET knoten_gruppe = 0 WHERE symbol_id = 'motor' AND name = 'U')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'motor' AND name = 'V')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'motor' AND name = 'W')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 0 WHERE symbol_id = 'trafo' AND name = '1')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'trafo' AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'trafo' AND name = '3')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 3 WHERE symbol_id = 'trafo' AND name = '4')",
        }},
        { 87, "sicherung: Aufbau vereinfacht (durchgehende Linie statt zwei Segmente, wie in 'Kopie von Sicherung' im Symboleditor erprobt)", {
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung', 0, 'linie', 0, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung', 1, 'rechteck', 0.25, 0.21, 0.75, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 88, "motor_dc: neues Symbol Gleichstrommotor (Permanentmagnet)", {
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('motor_dc', 'Gleichstrommotor', 'Antriebe', 32, 16, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('motor_dc', 'A1', 0, 0.5, -1, 0, 'power', 0), ('motor_dc', 'A2', 1, 0.5, 1, 0, 'power', 1))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('motor_dc', 0, 'linie', 0, 0.5, 0.2, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('motor_dc', 1, 'linie', 0.8, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('motor_dc', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('motor_dc', 3, 'text', 0.5, 0.40, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.28, 1, 'center', 'middle', 'solid'), ('motor_dc', 4, 'linie', 0.36, 0.585, 0.64, 0.585, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('motor_dc', 5, 'linie', 0.36, 0.65, 0.64, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'dash'))",
        }},
        { 89, "NETZ-MEHRPOL-02 Teil A: knoten_gruppe fuer uebrige 2-4-Pin-Verbraucher-Symbole", {
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'lampe'           AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'hupe'            AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'summer'          AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'widerstand_iec'  AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'widerstand_ansi' AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'kondensator'     AND name = '-')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'spule'           AND name = 'A2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'spule_ansi'      AND name = '2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'brueckengleichrichter' AND name = '~2')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'brueckengleichrichter' AND name = '+')",
            R"(UPDATE symbol_pin SET knoten_gruppe = 3 WHERE symbol_id = 'brueckengleichrichter' AND name = '-')",
        }},
        { 90, "motor_dc: fehlenden Eintrag in der (separaten, legacy) symbol-Tabelle nachgetragen — SymbolPalette.qml listet Symbole ueber diese Tabelle (db.symboleNachNorm), nicht ueber symbol_definition", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('motor_dc', 'Gleichstrommotor', 'antriebe', 'IEC,ANSI', 2))",
        }},
        { 91, "netzteil: neues Symbol (1-phasig, frei beschreibbare Ein-/Ausgangsspannung ueber Pin-Bezeichnungen)", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('netzteil', 'Netzteil', 'antriebe', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('netzteil', 'Netzteil', 'Antriebe', 32, 32, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('netzteil', 'L', 0, 0.25, -1, 0, 'power', 0), ('netzteil', 'N', 0, 0.75, -1, 0, 'power', 1), ('netzteil', '+', 1, 0.25, 1, 0, 'power', 2), ('netzteil', '-', 1, 0.75, 1, 0, 'power', 3))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('netzteil', 0, 'rechteck', 0.15, 0.15, 0.85, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 1, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 2, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 3, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 4, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 92, "netzteil: Pin-Signaltypen korrigiert (N/+/- waren fälschlich alle 'power' statt n/dc_plus/dc_minus)", {
            R"(UPDATE symbol_pin SET signaltyp = 'n'        WHERE symbol_id = 'netzteil' AND name = 'N')",
            R"(UPDATE symbol_pin SET signaltyp = 'dc_plus'  WHERE symbol_id = 'netzteil' AND name = '+')",
            R"(UPDATE symbol_pin SET signaltyp = 'dc_minus' WHERE symbol_id = 'netzteil' AND name = '-')",
        }},
        { 93, "symbol_pin.rolle: Rolle je Pin statt nur je Symbol (NETZTEIL-ROLLE-01) – netzteil-Ausgang (+/-) wird zur Quelle, Eingang (L/N) bleibt Verbraucher", {
            R"(ALTER TABLE symbol_pin ADD COLUMN rolle TEXT NOT NULL DEFAULT '')",
            R"(UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'netzteil' AND name IN ('L', 'N'))",
            R"(UPDATE symbol_pin SET rolle = 'quelle'      WHERE symbol_id = 'netzteil' AND name IN ('+', '-'))",
        }},
        { 94, "kabel_ader: farbe2 fuer echte Zweifarbigkeit (PE, DIN-47100-Bifarben) – GNYE-Sonderfall entfaellt zugunsten farbe=GN/farbe2=YE", {
            R"(ALTER TABLE kabel_ader ADD COLUMN farbe2 TEXT)",
            R"(UPDATE kabel_ader SET farbe2 = 'YE', farbe = 'GN' WHERE farbe = 'GNYE')",
        }},
        { 95, "Neue Symbole sensor_niveau (Niveauschalter/Schwimmer) und zeitschaltuhr (Zeitschaltuhr)", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('sensor_niveau', 'Niveauschalter (Schwimmer)', 'sensoren', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sensor_niveau', 'Niveauschalter (Schwimmer)', 'Sensoren', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sensor_niveau', 'L+', 0, 0.25, -1, 0, 'power'), ('sensor_niveau', 'M', 0, 0.75, -1, 0, 'power'), ('sensor_niveau', 'Q', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sensor_niveau', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 1, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 2, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 3, 'linie', 0.85, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 4, 'text', 0.5, 0.22, 0, 0, 0, 0, 0, 0, 0, 0, 'NIV', 0.16, 1, 'center', 'middle', 'solid'), ('sensor_niveau', 5, 'kreis_offen', 0.5, 0.42, 0, 0, 0, 0, 0.12, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 6, 'linie', 0.5, 0.54, 0.5, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 7, 'bogen', 0.36, 0.78, 0, 0, 0, 0, 0.10, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sensor_niveau', 8, 'bogen', 0.64, 0.78, 0, 0, 0, 0, 0.10, 0, 180, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET ibn_kategorie = 'fuellstandssensor' WHERE id = 'sensor_niveau')",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('zeitschaltuhr', 'Zeitschaltuhr', 'kontakte', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('zeitschaltuhr', 'Zeitschaltuhr', 'Kontakte', 32, 16, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('zeitschaltuhr', '1', 0, 0.5, -1, 0, 'neutral'), ('zeitschaltuhr', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zeitschaltuhr', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zeitschaltuhr', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zeitschaltuhr', 3, 'kreis_offen', 0.5, 0.17, 0, 0, 0, 0, 0.12, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zeitschaltuhr', 4, 'linie', 0.5, 0.17, 0.5, 0.09, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zeitschaltuhr', 5, 'linie', 0.5, 0.17, 0.58, 0.12, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 96, "Vier neue Erdungszeichen nach EN 60617 (02-15-01 bis 02-15-04): erde_allgemein, funktionserdung, schutzerdung, masse_gehaeuse", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('erde_allgemein', 'Erde (allgemein)', 'erdung', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('funktionserdung', 'Funktionserdung', 'erdung', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('schutzerdung', 'Schutzerdung', 'erdung', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('masse_gehaeuse', 'Masse, Gehäuse', 'erdung', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('erde_allgemein', 'Erde (allgemein)', 'Erdung', 16, 22, 'quelle', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('funktionserdung', 'Funktionserdung', 'Erdung', 24, 18, 'quelle', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('schutzerdung', 'Schutzerdung', 'Erdung', 24, 24, 'quelle', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('masse_gehaeuse', 'Masse, Gehäuse', 'Erdung', 18, 20, 'quelle', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('erde_allgemein', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('funktionserdung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schutzerdung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('masse_gehaeuse', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('erde_allgemein', 0, 'linie', 0.5, 0, 0.5, 0.73, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('erde_allgemein', 1, 'linie', 0.06, 0.75, 0.94, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('erde_allgemein', 2, 'linie', 0.20, 0.86, 0.80, 0.86, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('erde_allgemein', 3, 'linie', 0.34, 0.97, 0.66, 0.97, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('funktionserdung', 0, 'linie', 0.5, 0, 0.5, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 1, 'bogen', 0.5, 1.0, 0, 0, 0, 0, 0.5, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 2, 'linie', 0.16, 0.66, 0.86, 0.66, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 3, 'linie', 0.28, 0.81, 0.74, 0.81, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 4, 'linie', 0.39, 0.96, 0.63, 0.96, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schutzerdung', 0, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.5, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schutzerdung', 1, 'linie', 0.5, 0.15, 0.5, 0.61, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schutzerdung', 2, 'linie', 0.15, 0.62, 0.85, 0.62, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schutzerdung', 3, 'linie', 0.26, 0.73, 0.74, 0.73, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schutzerdung', 4, 'linie', 0.37, 0.84, 0.63, 0.84, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('masse_gehaeuse', 0, 'linie', 0.5, 0, 0.5, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 1, 'linie', 0.11, 0.80, 0.89, 0.80, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 2, 'linie', 0.11, 0.83, 0.00, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 3, 'linie', 0.50, 0.83, 0.39, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 4, 'linie', 0.89, 0.83, 0.78, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 97, "Fuenf neue Sicherungssymbole: sicherung_netzseitig, nh_sicherung, sicherungsschalter, sicherungstrennschalter, sicherungslasttrennschalter", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('sicherung_netzseitig', 'Sicherung mit netzseitiger Kennzeichnung', 'schutz', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('nh_sicherung', 'NH-Sicherung', 'schutz', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('sicherungsschalter', 'Sicherungsschalter', 'schutz', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('sicherungstrennschalter', 'Sicherungstrennschalter', 'schutz', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('sicherungslasttrennschalter', 'Sicherungslasttrennschalter', 'schutz', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sicherung_netzseitig', 'Sicherung mit netzseitiger Kennzeichnung', 'Schutz', 32, 16, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('nh_sicherung', 'NH-Sicherung', 'Schutz', 32, 16, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sicherungsschalter', 'Sicherungsschalter', 'Schutz', 36, 24, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sicherungstrennschalter', 'Sicherungstrennschalter', 'Schutz', 36, 24, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('sicherungslasttrennschalter', 'Sicherungslasttrennschalter', 'Schutz', 36, 24, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung_netzseitig', '1', 0, 0.5, -1, 0, 'neutral'), ('sicherung_netzseitig', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('nh_sicherung', '1', 0, 0.5, -1, 0, 'neutral'), ('nh_sicherung', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungsschalter', '1', 0, 0.5, -1, 0, 'neutral'), ('sicherungsschalter', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungstrennschalter', '1', 0, 0.5, -1, 0, 'neutral'), ('sicherungstrennschalter', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungslasttrennschalter', '1', 0, 0.5, -1, 0, 'neutral'), ('sicherungslasttrennschalter', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 0, 'linie', 0, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung_netzseitig', 1, 'rechteck', 0.25, 0.21, 0.75, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung_netzseitig', 2, 'dreieck_gefuellt', 0.575, 0.21, 0.75, 0.21, 0.75, 0.79, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung_netzseitig', 3, 'dreieck_gefuellt', 0.575, 0.21, 0.75, 0.79, 0.575, 0.79, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 0, 'linie', 0, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 1, 'linie', 0.20, 0.21, 0.20, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 2, 'rechteck', 0.25, 0.21, 0.75, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 3, 'linie', 0.80, 0.21, 0.80, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 1, 'linie', 0.28, 0.5, 0.62, 0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 2, 'linie', 0.62, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 7, 'linie', 0.696, 0.222, 0.807, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 1, 'linie', 0.28, 0.5, 0.62, 0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 2, 'linie', 0.62, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 7, 'linie', 0.696, 0.222, 0.807, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 8, 'linie', 0.696, 0.222, 0.696, 0.055, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 1, 'linie', 0.28, 0.5, 0.62, 0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 2, 'linie', 0.62, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 7, 'linie', 0.696, 0.222, 0.807, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 8, 'kreis_offen', 0.696, 0.130, 0, 0, 0, 0, 0.044, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 98, "Wischkontakte (Betaetigung/Rueckfall/Beide) + voreilende/nacheilende Schliesser/Oeffner", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wischkontakt_betaetigung', 'Wischkontakt (bei Betätigung)', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wischkontakt_rueckfall', 'Wischkontakt (bei Rückfall)', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wischkontakt_beide', 'Wischkontakt (bei Betätigung+Rückfall)', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('schliesser_voreilend', 'Voreilender Schließer', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('schliesser_nacheilend', 'Nacheilender Schließer', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('oeffner_voreilend', 'Voreilender Öffner', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('oeffner_nacheilend', 'Nacheilender Öffner', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wischkontakt_betaetigung', 'Wischkontakt (bei Betätigung)', 'Kontakte', 10, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wischkontakt_rueckfall', 'Wischkontakt (bei Rückfall)', 'Kontakte', 10, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wischkontakt_beide', 'Wischkontakt (bei Betätigung+Rückfall)', 'Kontakte', 10, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('schliesser_voreilend', 'Voreilender Schließer', 'Kontakte', 12, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('schliesser_nacheilend', 'Nacheilender Schließer', 'Kontakte', 12, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('oeffner_voreilend', 'Voreilender Öffner', 'Kontakte', 12, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('oeffner_nacheilend', 'Nacheilender Öffner', 'Kontakte', 12, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_betaetigung', '1', 0.74, 0, 0, -1, 'neutral'), ('wischkontakt_betaetigung', '2', 0.74, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_rueckfall', '1', 0.74, 0, 0, -1, 'neutral'), ('wischkontakt_rueckfall', '2', 0.74, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_beide', '1', 0.74, 0, 0, -1, 'neutral'), ('wischkontakt_beide', '2', 0.74, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser_voreilend', '1', 0.35, 0, 0, -1, 'neutral'), ('schliesser_voreilend', '2', 0.65, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser_nacheilend', '1', 0.65, 0, 0, -1, 'neutral'), ('schliesser_nacheilend', '2', 0.35, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('oeffner_voreilend', '1', 0.35, 0, 0, -1, 'neutral'), ('oeffner_voreilend', '2', 0.65, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('oeffner_nacheilend', '1', 0.65, 0, 0, -1, 'neutral'), ('oeffner_nacheilend', '2', 0.35, 1, 0, 1, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_betaetigung', 0, 'linie', 0.74, 0, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_betaetigung', 1, 'linie', 0.0, 0.26, 0.74, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_betaetigung', 2, 'linie', 0.74, 0.78, 0.74, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_betaetigung', 3, 'linie', 0.48, 0.16, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_rueckfall', 0, 'linie', 0.74, 0, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_rueckfall', 1, 'linie', 0.0, 0.26, 0.74, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_rueckfall', 2, 'linie', 0.74, 0.78, 0.74, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_rueckfall', 3, 'linie', 1.0, 0.16, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 0, 'linie', 0.74, 0, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 1, 'linie', 0.0, 0.26, 0.74, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 2, 'linie', 0.74, 0.78, 0.74, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 3, 'linie', 0.48, 0.16, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 4, 'linie', 1.0, 0.16, 0.74, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_voreilend', 0, 'linie', 0.35, 0, 0.35, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 1, 'linie', 0.35, 0.15, 0.15, 0.30, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 2, 'linie', 0.15, 0.30, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 3, 'linie', 0.65, 0.75, 0.65, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 4, 'linie', 0.55, 0.02, 0.55, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_nacheilend', 0, 'linie', 0.65, 0, 0.15, 0.70, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_nacheilend', 1, 'linie', 0.15, 0.70, 0.35, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_nacheilend', 2, 'linie', 0.35, 0.85, 0.35, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_nacheilend', 3, 'linie', 0.45, 0.75, 0.45, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner_voreilend', 0, 'linie', 0.35, 0, 0.35, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_voreilend', 1, 'linie', 0.35, 0.15, 0.15, 0.30, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_voreilend', 2, 'linie', 0.15, 0.30, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_voreilend', 3, 'linie', 0.65, 0.75, 0.65, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_voreilend', 4, 'linie', 0.55, 0.02, 0.55, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_voreilend', 5, 'linie', 0.35, 0.15, 0.55, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner_nacheilend', 0, 'linie', 0.65, 0, 0.15, 0.70, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 1, 'linie', 0.15, 0.70, 0.35, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 2, 'linie', 0.35, 0.85, 0.35, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 3, 'linie', 0.45, 0.75, 0.45, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 4, 'linie', 0.35, 0.85, 0.45, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET bmk_seite = 'vertikal' WHERE id IN ('wischkontakt_betaetigung', 'wischkontakt_rueckfall', 'wischkontakt_beide', 'schliesser_voreilend', 'schliesser_nacheilend', 'oeffner_voreilend', 'oeffner_nacheilend'))",
        }},
        { 99, "Symbolkorrekturen aus Nutzer-Testprojekt uebernommen: Sicherung-Familie (Trenn-/Lastschaltmarkierung an den Kontaktspalt statt frei schwebend, Betaetigungsstrich beim reinen Schalter entfernt) + Wischkontakte (Spindel auf x=0.5 zentriert, Breite 10->16mm)", {
            R"(DELETE FROM symbol_primitiv WHERE symbol_id IN ('sicherung', 'sicherung_netzseitig', 'nh_sicherung', 'sicherungsschalter', 'sicherungstrennschalter', 'sicherungslasttrennschalter', 'wischkontakt_betaetigung', 'wischkontakt_rueckfall', 'wischkontakt_beide'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung', 0, 'linie', 0, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung', 1, 'rechteck', 0.25, 0.21, 0.75, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 0, 'linie', 0, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung_netzseitig', 1, 'rechteck', 0.25, 0.21, 0.75, 0.79, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung_netzseitig', 2, 'dreieck_gefuellt', 0.575, 0.21, 0.75, 0.21, 0.75, 0.79, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherung_netzseitig', 3, 'dreieck_gefuellt', 0.575, 0.21, 0.75, 0.79, 0.575, 0.79, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 0, 'linie', 0, 0.5, 0.203125, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 1, 'linie', 0.203125, 0.21875, 0.203125, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 2, 'rechteck', 0.25, 0.21875, 0.75, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 3, 'linie', 0.796875, 0.21875, 0.796875, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 4, 'linie', 0.796875, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('nh_sicherung', 5, 'linie', 0.25, 0.5, 0.75, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 1, 'linie', 0.28, 0.5, 0.62, 0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 2, 'linie', 0.652777777777778, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungsschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 1, 'linie', 0.28, 0.5, 0.62, 0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 2, 'linie', 0.638888888888889, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungstrennschalter', 7, 'linie', 0.638888888888889, 0.5625, 0.638888888888889, 0.4375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 1, 'linie', 0.28, 0.5, 0.62, 0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 2, 'linie', 0.694444444444444, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 7, 'kreis_offen', 0.666666666666667, 0.5, 0, 0, 0, 0, 0.0277777777777778, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sicherungslasttrennschalter', 8, 'linie', 0.694444444444444, 0.458333333333333, 0.694444444444444, 0.541666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_betaetigung', 0, 'linie', 0.5, 0, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_betaetigung', 1, 'linie', 0.0, 0.265625, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_betaetigung', 2, 'linie', 0.5, 0.78125, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_betaetigung', 3, 'linie', 0.25, 0.15625, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_rueckfall', 0, 'linie', 0.5, 0, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_rueckfall', 1, 'linie', 0.0, 0.265625, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_rueckfall', 2, 'linie', 0.5, 0.78125, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_rueckfall', 3, 'linie', 0.75, 0.15625, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 0, 'linie', 0.5, 0, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 1, 'linie', 0.0, 0.265625, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 2, 'linie', 0.5, 0.78125, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 3, 'linie', 0.21875, 0.15625, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wischkontakt_beide', 4, 'linie', 0.75, 0.15625, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16 WHERE id IN ('wischkontakt_betaetigung', 'wischkontakt_rueckfall', 'wischkontakt_beide'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id IN ('wischkontakt_betaetigung', 'wischkontakt_rueckfall', 'wischkontakt_beide'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_betaetigung', '1', 0.5, 0, 0, -1, 'neutral'), ('wischkontakt_betaetigung', '2', 0.5, 1, 0, 1, 'neutral'), ('wischkontakt_rueckfall', '1', 0.5, 0, 0, -1, 'neutral'), ('wischkontakt_rueckfall', '2', 0.5, 1, 0, 1, 'neutral'), ('wischkontakt_beide', '1', 0.5, 0, 0, -1, 'neutral'), ('wischkontakt_beide', '2', 0.5, 1, 0, 1, 'neutral'))",
        }},
        // Alte Default-Strichstärke 1.5mm auf DIN-gerechte 0.35mm gesenkt (Grafik-/Symbol-Elemente
        // erschienen im PDF-Export nach dem 4x-Skalierungsfix, s. Commit 945c313, deutlich zu kräftig).
        // Nur Zeilen mit dem alten Default treffen, individuell gesetzte Werte bleiben unangetastet.
        { 100, "Default-Strichstaerke bestehender Elemente 1.5mm->0.35mm (nur wo noch Alt-Default gesetzt)", {
            R"(UPDATE grafik_element SET strich_breite = 0.35 WHERE strich_breite = 1.5)",
        }},
        // funktionserdung/masse_gehaeuse: einzelne Projekte (unter anderem "Pokeströms
        // Aquarium") tragen noch die alte, VOR dem SYM-BILDVORLAGE-01-Fix eingefrorene
        // Geometrie (masse_gehaeuse z.B. als 3-Strahlen-Fächer statt der per Pixel-
        // vermessung korrigierten parallelen Schraffur, s. 18_debugging.md). Migration 96
        // selbst enthält schon die korrekte Geometrie - dieser Schritt zieht bereits
        // migrierte Projekte, deren symbol_primitiv-Zeilen unabhängig davon eingefroren
        // wurden, einmalig auf denselben (unveränderten) Stand nach. Reiner Idempotenz-
        // Fix, keine Design-Änderung.
        { 101, "funktionserdung/masse_gehaeuse: auf Migration-96-Geometrie nachgezogen (einzelne Projekte hatten eingefrorene Vor-Fix-Geometrie)", {
            R"(DELETE FROM symbol_primitiv WHERE symbol_id IN ('funktionserdung', 'masse_gehaeuse'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('funktionserdung', 0, 'linie', 0.5, 0, 0.5, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 1, 'bogen', 0.5, 1.0, 0, 0, 0, 0, 0.5, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 2, 'linie', 0.16, 0.66, 0.86, 0.66, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 3, 'linie', 0.28, 0.81, 0.74, 0.81, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('funktionserdung', 4, 'linie', 0.39, 0.96, 0.63, 0.96, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('masse_gehaeuse', 0, 'linie', 0.5, 0, 0.5, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 1, 'linie', 0.11, 0.80, 0.89, 0.80, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 2, 'linie', 0.11, 0.83, 0.00, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 3, 'linie', 0.50, 0.83, 0.39, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('masse_gehaeuse', 4, 'linie', 0.89, 0.83, 0.78, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 102, "Neue Kategorie 'Installation' (Elektroinstallation): ausschalter, wechselschalter, serienschalter, taster_beleuchtet, kreuzschalter", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('ausschalter', 'Ausschalter', 'installation', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wechselschalter', 'Wechselschalter', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('serienschalter', 'Serienschalter', 'installation', 'IEC', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('taster_beleuchtet', 'Taster (beleuchtet)', 'installation', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kreuzschalter', 'Kreuzschalter', 'installation', 'IEC', 4))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('ausschalter', 'Ausschalter', 'Installation', 32, 16, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wechselschalter', 'Wechselschalter', 'Installation', 32, 16, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('serienschalter', 'Serienschalter', 'Installation', 32, 32, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('taster_beleuchtet', 'Taster (beleuchtet)', 'Installation', 32, 24, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kreuzschalter', 'Kreuzschalter', 'Installation', 32, 24, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ausschalter', '1', 0, 0.5, -1, 0, 'neutral'), ('ausschalter', '2', 1, 0.5, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechselschalter', '1', 0, 0.5, -1, 0, 'neutral'), ('wechselschalter', '2', 1, 0.25, 1, 0, 'neutral'), ('wechselschalter', '3', 1, 0.75, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('serienschalter', '1', 0, 0.25, -1, 0, 'neutral'), ('serienschalter', '2', 1, 0.25, 1, 0, 'neutral'), ('serienschalter', '3', 0, 0.75, -1, 0, 'neutral'), ('serienschalter', '4', 1, 0.75, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_beleuchtet', '1', 0, 0.667, -1, 0, 'neutral'), ('taster_beleuchtet', '2', 1, 0.667, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kreuzschalter', '1', 0, 0.25, -1, 0, 'neutral'), ('kreuzschalter', '2', 0, 0.75, -1, 0, 'neutral'), ('kreuzschalter', '3', 1, 0.25, 1, 0, 'neutral'), ('kreuzschalter', '4', 1, 0.75, 1, 0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ausschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ausschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ausschalter', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechselschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechselschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechselschalter', 2, 'linie', 0.7, 0.25, 0.7, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechselschalter', 3, 'linie', 0.7, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechselschalter', 4, 'linie', 0.7, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 0, 'linie', 0, 0.25, 0.3, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('serienschalter', 1, 'linie', 0.3, 0.25, 0.75, 0.125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('serienschalter', 2, 'linie', 0.7, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('serienschalter', 3, 'linie', 0, 0.75, 0.3, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('serienschalter', 4, 'linie', 0.3, 0.75, 0.75, 0.625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('serienschalter', 5, 'linie', 0.7, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('serienschalter', 6, 'linie', 0.5, 0.05, 0.5, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'dash'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 0, 'linie', 0, 0.667, 0.3, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 1, 'linie', 0.3, 0.667, 0.75, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 2, 'linie', 0.7, 0.667, 1, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 3, 'linie', 0.5, 0.427, 0.5, 0.573, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 4, 'linie', 0.35, 0.427, 0.65, 0.427, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 5, 'linie', 0.5, 0.287, 0.5, 0.427, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 6, 'kreis_offen', 0.5, 0.167, 0, 0, 0, 0, 0.09, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 7, 'linie', 0.42, 0.107, 0.58, 0.227, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('taster_beleuchtet', 8, 'linie', 0.42, 0.227, 0.58, 0.107, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 0, 'linie', 0, 0.25, 0.3, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kreuzschalter', 1, 'linie', 0, 0.75, 0.3, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kreuzschalter', 2, 'linie', 0.7, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kreuzschalter', 3, 'linie', 0.7, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kreuzschalter', 4, 'rechteck', 0.3, 0.15, 0.7, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kreuzschalter', 5, 'linie', 0.3, 0.25, 0.7, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kreuzschalter', 6, 'linie', 0.3, 0.75, 0.7, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 103, "SYM-ERWEITERUNG-01 Teil 2: Steckdosen (Schuko/Schalter/Feuchtraum/CEE16), Stromzaehler, Rauchmelder, Bewegungsmelder, Daemmerungsschalter, Ueberspannungsschutz, Rollladenmotor/-schalter", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('steckdose_schuko', 'Steckdose (Schuko)', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('steckdose_schalter', 'Steckdose mit Schalter', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('steckdose_feuchtraum', 'Feuchtraum-/Außensteckdose', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('steckdose_cee16', 'CEE-Steckdose (16A)', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('zaehler', 'Stromzähler (kWh)', 'installation', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('rauchmelder', 'Rauchmelder', 'installation', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('bewegungsmelder', 'Bewegungsmelder', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('daemmerungsschalter', 'Dämmerungsschalter', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('ueberspannungsschutz', 'Überspannungsschutz (SPD)', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('rollladenmotor', 'Rollladenmotor', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('rollladenschalter', 'Rollladenschalter (Auf/Ab)', 'installation', 'IEC', 3))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('steckdose_schuko', 'Steckdose (Schuko)', 'Installation', 24, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('steckdose_schalter', 'Steckdose mit Schalter', 'Installation', 24, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('steckdose_feuchtraum', 'Feuchtraum-/Außensteckdose', 'Installation', 24, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('steckdose_cee16', 'CEE-Steckdose (16A)', 'Installation', 24, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('zaehler', 'Stromzähler (kWh)', 'Installation', 24, 24, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('rauchmelder', 'Rauchmelder', 'Installation', 24, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('bewegungsmelder', 'Bewegungsmelder', 'Installation', 28, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('daemmerungsschalter', 'Dämmerungsschalter', 'Installation', 28, 28, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('ueberspannungsschutz', 'Überspannungsschutz (SPD)', 'Installation', 32, 28, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('rollladenmotor', 'Rollladenmotor', 'Installation', 32, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('rollladenschalter', 'Rollladenschalter (Auf/Ab)', 'Installation', 32, 16, 'durchleiter', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('steckdose_schuko', 'L', 0, 0.3, -1, 0, 'power', 0), ('steckdose_schuko', 'N', 0, 0.6, -1, 0, 'n', 1), ('steckdose_schuko', 'PE', 0.55, 1.0, 0, 1, 'pe', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('steckdose_schalter', 'L', 0, 0.3, -1, 0, 'power', 0), ('steckdose_schalter', 'N', 0, 0.6, -1, 0, 'n', 1), ('steckdose_schalter', 'PE', 0.55, 1.0, 0, 1, 'pe', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('steckdose_feuchtraum', 'L', 0, 0.3, -1, 0, 'power', 0), ('steckdose_feuchtraum', 'N', 0, 0.6, -1, 0, 'n', 1), ('steckdose_feuchtraum', 'PE', 0.55, 1.0, 0, 1, 'pe', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('steckdose_cee16', 'L', 0, 0.3, -1, 0, 'power', 0), ('steckdose_cee16', 'N', 0, 0.6, -1, 0, 'n', 1), ('steckdose_cee16', 'PE', 0.55, 1.0, 0, 1, 'pe', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('zaehler', '1', 0, 0.5, -1, 0, 'power', 0), ('zaehler', '2', 1, 0.5, 1, 0, 'power', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('rauchmelder', '1', 0, 0.5, -1, 0, 'power', 0), ('rauchmelder', '2', 1, 0.5, 1, 0, 'n', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('bewegungsmelder', 'L', 0, 0.3, -1, 0, 'power', 0), ('bewegungsmelder', 'N', 0, 0.6, -1, 0, 'n', 1), ('bewegungsmelder', 'Q', 1, 0.45, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('daemmerungsschalter', 'L', 0, 0.4, -1, 0, 'power', 0), ('daemmerungsschalter', 'N', 0, 0.7, -1, 0, 'n', 1), ('daemmerungsschalter', 'Q', 1, 0.55, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('ueberspannungsschutz', '1', 0, 0.4, -1, 0, 'power', 0), ('ueberspannungsschutz', '2', 1, 0.4, 1, 0, 'power', 0), ('ueberspannungsschutz', 'PE', 0.5, 1.0, 0, 1, 'pe', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('rollladenmotor', 'Auf', 0, 0.25, -1, 0, 'power', 0), ('rollladenmotor', 'N', 0, 0.5, -1, 0, 'n', 1), ('rollladenmotor', 'Ab', 0, 0.75, -1, 0, 'power', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('rollladenschalter', '1', 0, 0.5, -1, 0, 'neutral', 0), ('rollladenschalter', '2', 1, 0.25, 1, 0, 'neutral', 0), ('rollladenschalter', '3', 1, 0.75, 1, 0, 'neutral', 0))",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'bewegungsmelder' AND name = 'Q')",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'daemmerungsschalter' AND name = 'Q')",
            R"(UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'ueberspannungsschutz' AND name = 'PE')",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('steckdose_schuko', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schuko', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schuko', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schuko', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schuko', 4, 'linie', 0.45, 0.28, 0.45, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schuko', 5, 'linie', 0.65, 0.28, 0.65, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('steckdose_schalter', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schalter', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schalter', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schalter', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schalter', 4, 'linie', 0.45, 0.28, 0.45, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schalter', 5, 'linie', 0.65, 0.28, 0.65, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_schalter', 6, 'linie', 0.11, 0.36, 0.18, 0.24, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('steckdose_feuchtraum', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_feuchtraum', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_feuchtraum', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_feuchtraum', 3, 'rechteck', 0.08, 0.03, 0.98, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_feuchtraum', 4, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_feuchtraum', 5, 'linie', 0.45, 0.28, 0.45, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_feuchtraum', 6, 'linie', 0.65, 0.28, 0.65, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('steckdose_cee16', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 4, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 5, 'kreis_gefuellt', 0.55, 0.34, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 6, 'kreis_gefuellt', 0.47, 0.52, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('steckdose_cee16', 7, 'kreis_gefuellt', 0.63, 0.52, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zaehler', 0, 'linie', 0, 0.5, 0.22, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zaehler', 1, 'linie', 0.78, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zaehler', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('zaehler', 3, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'kWh', 0.16, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rauchmelder', 0, 'linie', 0, 0.5, 0.22, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rauchmelder', 1, 'linie', 0.78, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rauchmelder', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rauchmelder', 3, 'kreis_gefuellt', 0.5, 0.42, 0, 0, 0, 0, 0.05, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rauchmelder', 4, 'linie', 0.5, 0.42, 0.4, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rauchmelder', 5, 'linie', 0.5, 0.42, 0.5, 0.24, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rauchmelder', 6, 'linie', 0.5, 0.42, 0.6, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bewegungsmelder', 0, 'linie', 0, 0.3, 0.3676, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('bewegungsmelder', 1, 'linie', 0, 0.6, 0.3676, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('bewegungsmelder', 2, 'linie', 0.84, 0.45, 1, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('bewegungsmelder', 3, 'kreis_offen', 0.58, 0.45, 0, 0, 0, 0, 0.26, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('bewegungsmelder', 4, 'linie', 0.58, 0.71, 0.46, 0.92, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('bewegungsmelder', 5, 'linie', 0.58, 0.71, 0.7, 0.92, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('bewegungsmelder', 6, 'linie', 0.46, 0.92, 0.7, 0.92, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('daemmerungsschalter', 0, 'linie', 0, 0.4, 0.3627, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 1, 'linie', 0, 0.7, 0.3627, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 2, 'linie', 0.79, 0.55, 1, 0.55, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 3, 'kreis_offen', 0.55, 0.55, 0, 0, 0, 0, 0.24, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 4, 'linie', 0.95, 0.15, 0.72, 0.38, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 5, 'linie', 0.72, 0.38, 0.8, 0.34, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 6, 'linie', 0.72, 0.38, 0.76, 0.46, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 7, 'linie', 0.8, 0.05, 0.632, 0.324, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 8, 'linie', 0.632, 0.324, 0.7, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('daemmerungsschalter', 9, 'linie', 0.632, 0.324, 0.66, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 0, 'linie', 0, 0.4, 0.25, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ueberspannungsschutz', 1, 'linie', 0.75, 0.4, 1, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ueberspannungsschutz', 2, 'rechteck', 0.25, 0.28, 0.75, 0.52, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ueberspannungsschutz', 3, 'linie', 0.5, 0.52, 0.5, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ueberspannungsschutz', 4, 'linie', 0.32, 0.46, 0.68, 0.34, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ueberspannungsschutz', 5, 'linie', 0.5, 0.85, 0.44, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ueberspannungsschutz', 6, 'linie', 0.5, 0.85, 0.56, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenmotor', 0, 'linie', 0, 0.25, 0.524, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenmotor', 1, 'linie', 0, 0.5, 0.37, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenmotor', 2, 'linie', 0, 0.75, 0.524, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenmotor', 3, 'kreis_offen', 0.65, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenmotor', 4, 'text', 0.65, 0.46, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.2, 1, 'center', 'middle', 'solid'), ('rollladenmotor', 5, 'text', 0.65, 0.62, 0, 0, 0, 0, 0, 0, 0, 0, '1~', 0.14, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenschalter', 2, 'linie', 0.7, 0.25, 0.7, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenschalter', 3, 'linie', 0.7, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('rollladenschalter', 4, 'linie', 0.7, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 104, "SYM-ERWEITERUNG-01 Prioritaet 2: KFZ+Motorrad (Zuendschloss, Lichtschalter, Seitenstaenderschalter, Kupplungsschalter, Bremslichtschalter, Anlasser, Gluehkerze, Scheinwerfer, Blinkerrelais, Scheibenwischermotor, Lambdasonde, Steuergeraet/ECU, CDI-Zuendbox, Kombiinstrument, Sicherungskasten, Zuendspule)", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_zuendschloss', 'Zündschloss', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_lichtschalter', 'Lichtschalter', 'kfz', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_seitenstaenderschalter', 'Seitenständerschalter', 'kfz', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_kupplungsschalter', 'Kupplungsschalter', 'kfz', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_bremslichtschalter', 'Bremslichtschalter', 'kfz', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_anlasser', 'Anlasser (Starter)', 'kfz', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_gluehkerze', 'Glühkerze', 'kfz', 'IEC,ANSI', 1))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_scheinwerfer', 'Scheinwerfer (Abblend/Fern)', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_blinkerrelais', 'Blinkerrelais', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_scheibenwischermotor', 'Scheibenwischermotor', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_lambdasonde', 'Lambdasonde', 'kfz', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_steuergeraet', 'Steuergerät (ECU)', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_cdi', 'CDI-Zündbox', 'kfz', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_kombiinstrument', 'Kombiinstrument', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_sicherungskasten', 'Sicherungskasten', 'kfz', 'IEC,ANSI', 5))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kfz_zuendspule', 'Zündspule', 'kfz', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_zuendschloss', 'Zündschloss', 'KFZ', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_lichtschalter', 'Lichtschalter', 'KFZ', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_seitenstaenderschalter', 'Seitenständerschalter', 'KFZ', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_kupplungsschalter', 'Kupplungsschalter', 'KFZ', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_bremslichtschalter', 'Bremslichtschalter', 'KFZ', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_anlasser', 'Anlasser (Starter)', 'KFZ', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_gluehkerze', 'Glühkerze', 'KFZ', 24, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_scheinwerfer', 'Scheinwerfer (Abblend/Fern)', 'KFZ', 32, 24, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_blinkerrelais', 'Blinkerrelais', 'KFZ', 32, 24, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_scheibenwischermotor', 'Scheibenwischermotor', 'KFZ', 36, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_lambdasonde', 'Lambdasonde', 'KFZ', 16, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_steuergeraet', 'Steuergerät (ECU)', 'KFZ', 32, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_cdi', 'CDI-Zündbox', 'KFZ', 32, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_kombiinstrument', 'Kombiinstrument', 'KFZ', 40, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_sicherungskasten', 'Sicherungskasten', 'KFZ', 40, 48, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('kfz_zuendspule', 'Zündspule', 'KFZ', 32, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_zuendschloss', '30', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_zuendschloss', '15', 1, 0.25, 1, 0, 'neutral', 0), ('kfz_zuendschloss', '50', 1, 0.75, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_lichtschalter', '1', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_lichtschalter', '2', 1, 0.5, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_seitenstaenderschalter', '1', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_seitenstaenderschalter', '2', 1, 0.5, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_kupplungsschalter', '1', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_kupplungsschalter', '2', 1, 0.5, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_bremslichtschalter', '1', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_bremslichtschalter', '2', 1, 0.5, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_anlasser', '50', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_anlasser', '30', 1, 0.5, 1, 0, 'neutral', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_gluehkerze', '1', 0, 0.5, -1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_scheinwerfer', '31', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_scheinwerfer', '56b', 1, 0.25, 1, 0, 'neutral', 1), ('kfz_scheinwerfer', '56a', 1, 0.75, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_blinkerrelais', '49', 0, 0.3, -1, 0, 'neutral', 0), ('kfz_blinkerrelais', '49a', 1, 0.3, 1, 0, 'neutral', 1), ('kfz_blinkerrelais', '31', 0.5, 1.0, 0, 1, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_scheibenwischermotor', '31', 0, 0.2, -1, 0, 'neutral', 0), ('kfz_scheibenwischermotor', '53', 0, 0.5, -1, 0, 'neutral', 1), ('kfz_scheibenwischermotor', '53b', 0, 0.8, -1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_lambdasonde', '1', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_lambdasonde', '2', 1, 0.5, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_steuergeraet', '30', 0, 0.25, -1, 0, 'neutral', 0), ('kfz_steuergeraet', '31', 0, 0.75, -1, 0, 'neutral', 1), ('kfz_steuergeraet', 'Signal', 1, 0.5, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_cdi', '30', 0, 0.25, -1, 0, 'neutral', 0), ('kfz_cdi', '31', 0, 0.75, -1, 0, 'neutral', 1), ('kfz_cdi', 'Impuls', 1, 0.25, 1, 0, 'neutral', 2), ('kfz_cdi', '4', 1, 0.75, 1, 0, 'neutral', 3))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_kombiinstrument', '30', 0, 0.25, -1, 0, 'neutral', 0), ('kfz_kombiinstrument', '31', 0, 0.75, -1, 0, 'neutral', 1), ('kfz_kombiinstrument', 'Signal', 1, 0.5, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_sicherungskasten', '30', 0, 0.5, -1, 0, 'neutral', 0), ('kfz_sicherungskasten', 'F1', 1, 0.15, 1, 0, 'neutral', 1), ('kfz_sicherungskasten', 'F2', 1, 0.383, 1, 0, 'neutral', 2), ('kfz_sicherungskasten', 'F3', 1, 0.617, 1, 0, 'neutral', 3), ('kfz_sicherungskasten', 'F4', 1, 0.85, 1, 0, 'neutral', 4))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_zuendspule', '15', 0, 0.25, -1, 0, 'neutral', 0), ('kfz_zuendspule', '1', 0, 0.75, -1, 0, 'neutral', 1), ('kfz_zuendspule', '4', 1, 0.5, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_zuendschloss', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendschloss', 1, 'linie', 0.3, 0.5, 0.75, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendschloss', 2, 'linie', 0.7, 0.25, 0.7, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendschloss', 3, 'linie', 0.7, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendschloss', 4, 'linie', 0.7, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_lichtschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_lichtschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_lichtschalter', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_seitenstaenderschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_seitenstaenderschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_seitenstaenderschalter', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_kupplungsschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kupplungsschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kupplungsschalter', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_bremslichtschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_bremslichtschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_bremslichtschalter', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_anlasser', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_anlasser', 1, 'linie', 0.72, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_anlasser', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_anlasser', 3, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.35, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_gluehkerze', 0, 'linie', 0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 1, 'rechteck', 0.15, 0.25, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 2, 'linie', 0.22, 0.35, 0.30, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 3, 'linie', 0.30, 0.65, 0.38, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 4, 'linie', 0.38, 0.35, 0.46, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 5, 'linie', 0.46, 0.65, 0.54, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 6, 'linie', 0.65, 0.4, 0.78, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 7, 'linie', 0.65, 0.55, 0.80, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_gluehkerze', 8, 'linie', 0.65, 0.7, 0.78, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_scheinwerfer', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 1, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.2, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 2, 'linie', 0.4, 0.4, 0.6, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 3, 'linie', 0.4, 0.6, 0.6, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 4, 'linie', 0.7, 0.5, 0.85, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 5, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 6, 'linie', 0.7, 0.5, 0.85, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheinwerfer', 7, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_blinkerrelais', 0, 'linie', 0, 0.3, 0.15, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 1, 'linie', 0.85, 0.3, 1, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 2, 'linie', 0.5, 0.6, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 3, 'rechteck', 0.15, 0.15, 0.85, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 4, 'linie', 0.25, 0.45, 0.35, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 5, 'linie', 0.35, 0.45, 0.35, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 6, 'linie', 0.35, 0.3, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 7, 'linie', 0.5, 0.3, 0.5, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 8, 'linie', 0.5, 0.45, 0.65, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 9, 'linie', 0.65, 0.45, 0.65, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_blinkerrelais', 10, 'linie', 0.65, 0.3, 0.75, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_scheibenwischermotor', 0, 'linie', 0, 0.2, 0.35, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheibenwischermotor', 1, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheibenwischermotor', 2, 'linie', 0, 0.8, 0.35, 0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheibenwischermotor', 3, 'kreis_offen', 0.65, 0.5, 0, 0, 0, 0, 0.32, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_scheibenwischermotor', 4, 'text', 0.65, 0.46, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.28, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_lambdasonde', 0, 'rechteck', 0.1, 0.1, 0.9, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_lambdasonde', 1, 'linie', 0, 0.5, 0.1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_lambdasonde', 2, 'linie', 0.9, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_lambdasonde', 3, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'O2', 0.32, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_steuergeraet', 0, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 1, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 2, 'linie', 0.85, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 3, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 4, 'linie', 0.3, 0.3, 0.3, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 5, 'linie', 0.45, 0.3, 0.45, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 6, 'linie', 0.6, 0.3, 0.6, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_steuergeraet', 7, 'text', 0.5, 0.65, 0, 0, 0, 0, 0, 0, 0, 0, 'ECU', 0.16, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_cdi', 0, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 1, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 2, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 3, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 4, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 5, 'linie', 0.4, 0.35, 0.4, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 6, 'linie', 0.6, 0.35, 0.6, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 7, 'text', 0.5, 0.78, 0, 0, 0, 0, 0, 0, 0, 0, 'CDI', 0.14, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_kombiinstrument', 0, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kombiinstrument', 1, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kombiinstrument', 2, 'linie', 0.85, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kombiinstrument', 3, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kombiinstrument', 4, 'bogen', 0.5, 0.6, 0, 0, 0, 0, 0.22, 200, 340, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kombiinstrument', 5, 'linie', 0.5, 0.6, 0.62, 0.42, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_kombiinstrument', 6, 'kreis_gefuellt', 0.5, 0.6, 0, 0, 0, 0, 0.03, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_sicherungskasten', 0, 'linie', 0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 1, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 2, 'linie', 0.85, 0.15, 1, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 3, 'linie', 0.85, 0.383, 1, 0.383, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 4, 'linie', 0.85, 0.617, 1, 0.617, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 5, 'linie', 0.85, 0.85, 1, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 6, 'rechteck', 0.3, 0.1, 0.7, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 7, 'rechteck', 0.3, 0.333, 0.7, 0.433, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 8, 'rechteck', 0.3, 0.567, 0.7, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_sicherungskasten', 9, 'rechteck', 0.3, 0.8, 0.7, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_zuendspule', 0, 'linie', 0, 0.25, 0.3, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendspule', 1, 'linie', 0, 0.75, 0.3, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendspule', 2, 'linie', 0.7, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendspule', 3, 'kreis_offen', 0.3, 0.5, 0, 0, 0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendspule', 4, 'kreis_offen', 0.7, 0.5, 0, 0, 0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendspule', 5, 'linie', 0.48, 0.275, 0.48, 0.725, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_zuendspule', 6, 'linie', 0.52, 0.275, 0.52, 0.725, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 105, "SYM-ERWEITERUNG-01 Prioritaet 3: Waermepumpe (Umwaelzpumpe, Mischer-Stellantrieb, Heizstab, WP-Regler, SG-Ready-Schnittstelle)", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wp_umwaelzpumpe', 'Umwälzpumpe', 'waermepumpe', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wp_mischer', 'Mischer-Stellantrieb', 'waermepumpe', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wp_heizstab', 'Heizstab (Zusatzheizer)', 'waermepumpe', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wp_regler', 'Wärmepumpen-Regler', 'waermepumpe', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wp_sgready', 'SG-Ready-Schnittstelle', 'waermepumpe', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wp_umwaelzpumpe', 'Umwälzpumpe', 'Wärmepumpe', 32, 16, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wp_mischer', 'Mischer-Stellantrieb', 'Wärmepumpe', 32, 32, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wp_heizstab', 'Heizstab (Zusatzheizer)', 'Wärmepumpe', 32, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wp_regler', 'Wärmepumpen-Regler', 'Wärmepumpe', 32, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('wp_sgready', 'SG-Ready-Schnittstelle', 'Wärmepumpe', 32, 24, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('wp_umwaelzpumpe', 'L', 0, 0.5, -1, 0, 'power', 0), ('wp_umwaelzpumpe', 'N', 1, 0.5, 1, 0, 'n', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('wp_mischer', '1', 0, 0.2, -1, 0, 'neutral', 0), ('wp_mischer', 'AUF', 0, 0.45, -1, 0, 'neutral', 1), ('wp_mischer', 'ZU', 0, 0.7, -1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('wp_heizstab', '1', 0, 0.5, -1, 0, 'power', 0), ('wp_heizstab', '2', 1, 0.5, 1, 0, 'power', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('wp_regler', '30', 0, 0.25, -1, 0, 'power', 0), ('wp_regler', '31', 0, 0.75, -1, 0, 'n', 1), ('wp_regler', 'Bus', 1, 0.5, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('wp_sgready', '1', 0, 0.5, -1, 0, 'neutral', 0), ('wp_sgready', 'SG1', 1, 0.25, 1, 0, 'neutral', 1), ('wp_sgready', 'SG2', 1, 0.75, 1, 0, 'neutral', 2))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wp_umwaelzpumpe', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_umwaelzpumpe', 1, 'linie', 0.72, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_umwaelzpumpe', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_umwaelzpumpe', 3, 'text', 0.5, 0.42, 0, 0, 0, 0, 0, 0, 0, 0, 'P', 0.3, 1, 'center', 'middle', 'solid'), ('wp_umwaelzpumpe', 4, 'text', 0.5, 0.62, 0, 0, 0, 0, 0, 0, 0, 0, '1~', 0.16, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wp_mischer', 0, 'linie', 0, 0.2, 0.25, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 1, 'linie', 0, 0.45, 0.25, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 2, 'linie', 0, 0.7, 0.25, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 3, 'kreis_offen', 0.5, 0.35, 0, 0, 0, 0, 0.2, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 4, 'text', 0.5, 0.35, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.28, 1, 'center', 'middle', 'solid'), ('wp_mischer', 5, 'linie', 0.5, 0.55, 0.5, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 6, 'linie', 0.32, 0.68, 0.68, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 7, 'linie', 0.32, 0.68, 0.5, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_mischer', 8, 'linie', 0.68, 0.68, 0.5, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wp_heizstab', 0, 'linie', 0, 0.5, 0.2, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 1, 'linie', 0.8, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 2, 'rechteck', 0.2, 0.35, 0.8, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 3, 'linie', 0.35, 0.30, 0.40, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 4, 'linie', 0.50, 0.30, 0.55, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 5, 'linie', 0.65, 0.30, 0.70, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wp_regler', 0, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 1, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 2, 'linie', 0.85, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 3, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 4, 'bogen', 0.5, 0.55, 0, 0, 0, 0, 0.2, 200, 340, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 5, 'linie', 0.5, 0.55, 0.6, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 6, 'kreis_gefuellt', 0.5, 0.55, 0, 0, 0, 0, 0.03, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_regler', 7, 'text', 0.5, 0.78, 0, 0, 0, 0, 0, 0, 0, 0, 'WP', 0.16, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wp_sgready', 0, 'linie', 0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 1, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 2, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 3, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 4, 'linie', 0.3, 0.25, 0.45, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 5, 'linie', 0.55, 0.25, 0.7, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 6, 'linie', 0.3, 0.75, 0.45, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 7, 'linie', 0.55, 0.75, 0.7, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_sgready', 8, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'SG', 0.18, 1, 'center', 'middle', 'solid'))",
        }},
        { 106, "SYM-ERWEITERUNG-01 Prioritaet 4: Caravan (Aufbaubatterie, Trennrelais, Ladebooster, Solarladeregler, Solarpanel, Wechselrichter, Landanschluss, Wasserpumpe, Absorberkuehlschrank, Anhaengerstecker 13-polig)", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_batterie', 'Aufbaubatterie 12V', 'caravan', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_trennrelais', 'Batterie-Trennrelais', 'caravan', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_ladebooster', 'DC/DC-Ladebooster', 'caravan', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_solarladeregler', 'Solarladeregler (MPPT)', 'caravan', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_solarpanel', 'Solarmodul (PV-Panel)', 'caravan', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_wechselrichter', 'Wechselrichter 12V→230V', 'caravan', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_landanschluss', 'Landstromanschluss (CEE-Einspeisesteckdose)', 'caravan', 'IEC,ANSI', 3))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_wasserpumpe', 'Frischwasserpumpe 12V', 'caravan', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_kuehlschrank', 'Absorberkühlschrank (12V/230V/Gas)', 'caravan', 'IEC,ANSI', 4))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('caravan_anhaengerstecker_13', 'Anhänger-Steckdose (13-polig)', 'caravan', 'IEC,ANSI', 13))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_batterie', 'Aufbaubatterie 12V', 'Caravan', 32, 16, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_trennrelais', 'Batterie-Trennrelais', 'Caravan', 32, 48, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_ladebooster', 'DC/DC-Ladebooster', 'Caravan', 32, 32, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_solarladeregler', 'Solarladeregler (MPPT)', 'Caravan', 32, 32, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_solarpanel', 'Solarmodul (PV-Panel)', 'Caravan', 32, 32, 'quelle', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_wechselrichter', 'Wechselrichter 12V→230V', 'Caravan', 32, 32, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_landanschluss', 'Landstromanschluss (CEE-Einspeisesteckdose)', 'Caravan', 24, 24, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_wasserpumpe', 'Frischwasserpumpe 12V', 'Caravan', 32, 16, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_kuehlschrank', 'Absorberkühlschrank (12V/230V/Gas)', 'Caravan', 40, 48, 'verbraucher', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES ('caravan_anhaengerstecker_13', 'Anhänger-Steckdose (13-polig)', 'Caravan', 32, 112, 'variabel', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_batterie', '+', 0, 0.5, -1, 0, 'neutral', 0), ('caravan_batterie', '-', 1, 0.5, 1, 0, 'neutral', 0))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_trennrelais', '85', 0, 0.25, -1, 0, 'neutral', 0), ('caravan_trennrelais', '86', 1, 0.25, 1, 0, 'neutral', 1), ('caravan_trennrelais', '30', 0, 0.75, -1, 0, 'neutral', 2), ('caravan_trennrelais', '87', 1, 0.75, 1, 0, 'neutral', 3))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_ladebooster', 'IN+', 0, 0.25, -1, 0, 'dc_plus', 0), ('caravan_ladebooster', 'IN-', 0, 0.75, -1, 0, 'dc_minus', 1), ('caravan_ladebooster', 'OUT+', 1, 0.25, 1, 0, 'dc_plus', 2), ('caravan_ladebooster', 'OUT-', 1, 0.75, 1, 0, 'dc_minus', 3))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_solarladeregler', 'PV+', 0, 0.25, -1, 0, 'dc_plus', 0), ('caravan_solarladeregler', 'PV-', 0, 0.75, -1, 0, 'dc_minus', 1), ('caravan_solarladeregler', 'BAT+', 1, 0.25, 1, 0, 'dc_plus', 2), ('caravan_solarladeregler', 'BAT-', 1, 0.75, 1, 0, 'dc_minus', 3))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_solarpanel', '+', 0.3, 1, 0, 1, 'dc_plus', 0), ('caravan_solarpanel', '-', 0.7, 1, 0, 1, 'dc_minus', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_wechselrichter', 'DC+', 0, 0.25, -1, 0, 'dc_plus', 0), ('caravan_wechselrichter', 'DC-', 0, 0.75, -1, 0, 'dc_minus', 1), ('caravan_wechselrichter', 'L', 1, 0.25, 1, 0, 'power', 2), ('caravan_wechselrichter', 'N', 1, 0.75, 1, 0, 'n', 3))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_landanschluss', 'L', 0, 0.3, -1, 0, 'power', 0), ('caravan_landanschluss', 'N', 0, 0.6, -1, 0, 'n', 1), ('caravan_landanschluss', 'PE', 0.55, 1, 0, 1, 'pe', 2))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_wasserpumpe', '+', 0, 0.5, -1, 0, 'dc_plus', 0), ('caravan_wasserpumpe', '-', 1, 0.5, 1, 0, 'dc_minus', 1))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_kuehlschrank', '12V+', 0, 0.15, -1, 0, 'dc_plus', 0), ('caravan_kuehlschrank', '12V-', 0, 0.383, -1, 0, 'dc_minus', 1), ('caravan_kuehlschrank', 'L', 0, 0.617, -1, 0, 'power', 2), ('caravan_kuehlschrank', 'N', 0, 0.85, -1, 0, 'n', 3))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('caravan_anhaengerstecker_13', '1', 0, 0.0714, -1, 0, 'neutral', 0), ('caravan_anhaengerstecker_13', '2', 0, 0.1429, -1, 0, 'neutral', 1), ('caravan_anhaengerstecker_13', '3', 0, 0.2143, -1, 0, 'neutral', 2), ('caravan_anhaengerstecker_13', '4', 0, 0.2857, -1, 0, 'neutral', 3), ('caravan_anhaengerstecker_13', '5', 0, 0.3571, -1, 0, 'neutral', 4), ('caravan_anhaengerstecker_13', '6', 0, 0.4286, -1, 0, 'neutral', 5), ('caravan_anhaengerstecker_13', '7', 0, 0.5, -1, 0, 'neutral', 6), ('caravan_anhaengerstecker_13', '8', 0, 0.5714, -1, 0, 'neutral', 7), ('caravan_anhaengerstecker_13', '9', 0, 0.6429, -1, 0, 'neutral', 8), ('caravan_anhaengerstecker_13', '10', 0, 0.7143, -1, 0, 'neutral', 9), ('caravan_anhaengerstecker_13', '11', 0, 0.7857, -1, 0, 'neutral', 10), ('caravan_anhaengerstecker_13', '12', 0, 0.8571, -1, 0, 'neutral', 11), ('caravan_anhaengerstecker_13', '13', 0, 0.9286, -1, 0, 'neutral', 12))",
            R"(UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'caravan_ladebooster' AND name IN ('IN+', 'IN-'))",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'caravan_ladebooster' AND name IN ('OUT+', 'OUT-'))",
            R"(UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'caravan_solarladeregler' AND name IN ('PV+', 'PV-'))",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'caravan_solarladeregler' AND name IN ('BAT+', 'BAT-'))",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'caravan_solarpanel' AND name IN ('+', '-'))",
            R"(UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'caravan_wechselrichter' AND name IN ('DC+', 'DC-'))",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'caravan_wechselrichter' AND name IN ('L', 'N'))",
            R"(UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'caravan_landanschluss' AND name IN ('L', 'N', 'PE'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_batterie', 0, 'linie', 0, 0.5, 0.25, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_batterie', 1, 'linie', 0.25, 0.1, 0.25, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_batterie', 2, 'linie', 0.42, 0.3, 0.42, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_batterie', 3, 'linie', 0.58, 0.1, 0.58, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_batterie', 4, 'linie', 0.75, 0.3, 0.75, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_batterie', 5, 'linie', 0.75, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_trennrelais', 0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_trennrelais', 1, 'linie', 0.15, 0.5, 0.85, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_trennrelais', 2, 'text', 0.5, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 'Spule', 0.1, 0, 'center', 'middle', 'solid'), ('caravan_trennrelais', 3, 'text', 0.5, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, 'TR', 0.14, 1, 'center', 'middle', 'solid'), ('caravan_trennrelais', 4, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_trennrelais', 5, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_trennrelais', 6, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_trennrelais', 7, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_ladebooster', 0, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_ladebooster', 1, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_ladebooster', 2, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_ladebooster', 3, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_ladebooster', 4, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_ladebooster', 5, 'text', 0.5, 0.42, 0, 0, 0, 0, 0, 0, 0, 0, 'B2B', 0.16, 1, 'center', 'middle', 'solid'), ('caravan_ladebooster', 6, 'text', 0.5, 0.63, 0, 0, 0, 0, 0, 0, 0, 0, 'DC/DC', 0.1, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_solarladeregler', 0, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarladeregler', 1, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarladeregler', 2, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarladeregler', 3, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarladeregler', 4, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarladeregler', 5, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'MPPT', 0.15, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_solarpanel', 0, 'rechteck', 0.1, 0.15, 0.9, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarpanel', 1, 'linie', 0.37, 0.15, 0.37, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarpanel', 2, 'linie', 0.63, 0.15, 0.63, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarpanel', 3, 'linie', 0.1, 0.5, 0.9, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarpanel', 4, 'linie', 0.3, 0.85, 0.3, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_solarpanel', 5, 'linie', 0.7, 0.85, 0.7, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_wechselrichter', 0, 'rechteck', 0.15, 0.15, 0.85, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wechselrichter', 1, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wechselrichter', 2, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wechselrichter', 3, 'linie', 0.85, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wechselrichter', 4, 'linie', 0.85, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wechselrichter', 5, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'INV', 0.15, 1, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_landanschluss', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 2, 'linie', 0.55, 0.75, 0.55, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 4, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 5, 'kreis_gefuellt', 0.55, 0.34, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 6, 'kreis_gefuellt', 0.47, 0.52, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_landanschluss', 7, 'kreis_gefuellt', 0.63, 0.52, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_wasserpumpe', 0, 'linie', 0, 0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wasserpumpe', 1, 'linie', 0.72, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wasserpumpe', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_wasserpumpe', 3, 'text', 0.5, 0.42, 0, 0, 0, 0, 0, 0, 0, 0, 'P', 0.3, 1, 'center', 'middle', 'solid'), ('caravan_wasserpumpe', 4, 'text', 0.5, 0.62, 0, 0, 0, 0, 0, 0, 0, 0, '12V', 0.13, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_kuehlschrank', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 1, 'linie', 0, 0.15, 0.15, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 2, 'linie', 0, 0.383, 0.15, 0.383, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 3, 'linie', 0, 0.617, 0.15, 0.617, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 4, 'linie', 0, 0.85, 0.15, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 5, 'text', 0.5, 0.22, 0, 0, 0, 0, 0, 0, 0, 0, 'ABS', 0.15, 1, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 6, 'text', 0.5, 0.42, 0, 0, 0, 0, 0, 0, 0, 0, '12V', 0.1, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 7, 'text', 0.5, 0.55, 0, 0, 0, 0, 0, 0, 0, 0, '230V', 0.1, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 8, 'text', 0.5, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, 'GAS', 0.12, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_anhaengerstecker_13', 0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 1, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, '13-pol', 0.055, 1, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 2, 'linie', 0, 0.0714, 0.15, 0.0714, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 3, 'linie', 0, 0.1429, 0.15, 0.1429, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 4, 'linie', 0, 0.2143, 0.15, 0.2143, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 5, 'linie', 0, 0.2857, 0.15, 0.2857, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 6, 'linie', 0, 0.3571, 0.15, 0.3571, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 7, 'linie', 0, 0.4286, 0.15, 0.4286, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 8, 'linie', 0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 9, 'linie', 0, 0.5714, 0.15, 0.5714, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 10, 'linie', 0, 0.6429, 0.15, 0.6429, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 11, 'linie', 0, 0.7143, 0.15, 0.7143, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 12, 'linie', 0, 0.7857, 0.15, 0.7857, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 13, 'linie', 0, 0.8571, 0.15, 0.8571, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_anhaengerstecker_13', 14, 'linie', 0, 0.9286, 0.15, 0.9286, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 107, "BMK-DOPPEL-MINUS-01: betriebsmittel_bmk-View haengte bedingungslos ein weiteres '-' vor betriebsmittel_kz, obwohl die Spalte das Minus bereits enthaelt (EP-Feld setzt es beim Speichern) - analog zum in Migration 85 behobenen Bug bei klemmenleiste_bmk, hier aber vergessen. Bestehende Werte normalisiert, View korrigiert, betroffene Canvas-Elemente neu synchronisiert.", {
            R"(UPDATE betriebsmittel SET betriebsmittel_kz = '-' || LTRIM(betriebsmittel_kz, '-') WHERE betriebsmittel_kz LIKE '--%')",
            R"(DROP VIEW betriebsmittel_bmk)",
            R"(CREATE VIEW betriebsmittel_bmk AS
                SELECT b.id, b.betriebsmittel_kz, b.projekt_id,
                       COALESCE('==' || a.anlage_uebergeordnet, '') ||
                       COALESCE('++' || o.standort_uebergeordnet, '') ||
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       b.betriebsmittel_kz AS bmk_vollstaendig,
                       COALESCE('=' || a.kuerzel, '') ||
                       COALESCE('+' || o.kuerzel, '') ||
                       b.betriebsmittel_kz AS bmk_kurz
                FROM betriebsmittel b
                LEFT JOIN ort o ON o.id = b.ort_id
                LEFT JOIN anlage a ON a.id = o.anlage_id)",
            R"(UPDATE grafik_element
                SET extra_daten = json_set(COALESCE(extra_daten, '{}'), '$.bmk',
                    (SELECT bmk_vollstaendig FROM betriebsmittel_bmk WHERE id = grafik_element.betriebsmittel_id))
                WHERE betriebsmittel_id IN (SELECT id FROM betriebsmittel_bmk))",
        }},
        { 108, "SYMBOL-GROESSE-01 Teil 1: Kontakte/Schutz-Batch, 13 sauber skalierende Symbole auf EPLAN-Referenzmasse korrigiert (Bounding-Box-Korrektur, symbol_primitiv unveraendert da normiert 0..1 - Details konzept/features/symbolgroessen_audit.md). Sicherung/Sicherung_netzseitig/nh_sicherung/taster_no/taster_nc/not_halt/bimetall_nc/sicherungsschalter-Familie bewusst zurueckgestellt, dort wuerde naive Skalierung die Geometrie sichtbar verzerren - eigener Folgeschritt mit Primitiv-Rework.", {
            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 4 WHERE id = 'schliesser')",
            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 4 WHERE id = 'oeffner')",
            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 4 WHERE id = 'wechsler')",
            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 4 WHERE id = 'lss')",
            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 4 WHERE id = 'fi')",
            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 4 WHERE id = 'zeitschaltuhr')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'wischkontakt_betaetigung')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'wischkontakt_rueckfall')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'wischkontakt_beide')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'schliesser_voreilend')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'schliesser_nacheilend')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'oeffner_voreilend')",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12 WHERE id = 'oeffner_nacheilend')",
        }},
        { 109, "SYMBOL-VERTIKAL-01: Kontakte/Schutz/Passive/Installation-Familie (25 Symbole) auf vertikale 0-Grad-Ausrichtung gedreht (Nutzerwunsch, analog EPLAN-Konvention). Reine 90-Grad-Koordinatentransformation der bestehenden Geometrie (x,y)->(1-y,x), Breite/Hoehe getauscht, Radius auf neue Breite umskaliert, Bogenwinkel +90 Grad - vorab per Matplotlib-Vergleichsgrafik fuer alle 25 Symbole verifiziert. bmk_seite=vertikal gesetzt. Verbindungen-Kategorie (winkel/treffpunkt/querverweis/aderdefinition/klemme_anschluss/isoliert_gelegte_ader) und Anschluesse-Kategorie (klemme/stecker/buchse) bewusst nicht mitgedreht - Routing-/Anschluss-Hilfselemente ohne Geraete-Charakter. Details konzept/features/04_symbolsystem.md §15.", {
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'schliesser')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'schliesser')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'schliesser')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'oeffner')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'oeffner')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('oeffner', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('oeffner', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'oeffner')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner', 3, 'linie', 0.5, 0.7, 0.8, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'wechsler')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'wechsler')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechsler', 'K', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechsler', 'NO', 0.75, 1, 0, 1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechsler', 'NC', 0.25, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'wechsler')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler', 1, 'linie', 0.5, 0.3, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler', 2, 'linie', 0.75, 0.7, 0.55, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler', 3, 'linie', 0.75, 0.7, 0.75, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler', 4, 'linie', 0.25, 0.7, 0.25, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'sicherung')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherung')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung', 0, 'linie', 0.5, 0, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung', 1, 'rechteck', 0.79, 0.25, 0.21, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'lss')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'lss')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('lss', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('lss', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'lss')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 3, 'rechteck', 0.89, 0.43, 0.75, 0.57, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 4, 'linie', 0.75, 0.5, 0.54, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'fi')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'fi')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('fi', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('fi', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'fi')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 3, 'rechteck', 0.89, 0.43, 0.75, 0.57, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 4, 'linie', 0.75, 0.5, 0.54, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 5, 'bogen', 0.18, 0.435, 0, 0, 0, 0, 0.195, 270, 90, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('fi', 6, 'bogen', 0.18, 0.565, 0, 0, 0, 0, 0.195, 90, 270, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'diode')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'diode')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('diode', 'A', 0.5, 0, 0, -1, 'power'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('diode', 'K', 0.5, 1, 0, 1, 'power'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'diode')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 0, 'linie', 0.5, 0, 0.5, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 1, 'linie', 0.5, 0.68, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 2, 'linie', 0.88, 0.28, 0.12, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 3, 'linie', 0.88, 0.28, 0.5, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 4, 'linie', 0.12, 0.28, 0.5, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 5, 'linie', 0.88, 0.68, 0.12, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'taster_no')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'taster_no')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_no', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_no', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'taster_no')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_no', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_no', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_no', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_no', 3, 'linie', 0.86, 0.5, 0.64, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_no', 4, 'linie', 0.86, 0.35, 0.86, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'taster_nc')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'taster_nc')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_nc', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_nc', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'taster_nc')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_nc', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_nc', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_nc', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_nc', 3, 'linie', 0.5, 0.7, 0.8, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_nc', 4, 'linie', 0.86, 0.5, 0.64, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_nc', 5, 'linie', 0.86, 0.35, 0.86, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'not_halt')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'not_halt')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('not_halt', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('not_halt', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'not_halt')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 3, 'linie', 0.5, 0.7, 0.8, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 4, 'linie', 0.82, 0.5, 0.67, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 5, 'linie', 0.67, 0.33, 0.67, 0.67, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('not_halt', 6, 'bogen', 0.82, 0.5, 0, 0, 0, 0, 0.26, 270, 90, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'bimetall_nc')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'bimetall_nc')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('bimetall_nc', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('bimetall_nc', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'bimetall_nc')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 3, 'linie', 0.5, 0.7, 0.8, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 4, 'linie', 0.88, 0.38, 0.88, 0.62, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 5, 'linie', 0.88, 0.62, 0.76, 0.38, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 6, 'linie', 0.76, 0.38, 0.76, 0.62, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('bimetall_nc', 7, 'linie', 0.76, 0.5, 0.62, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 4, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'zeitschaltuhr')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'zeitschaltuhr')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('zeitschaltuhr', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('zeitschaltuhr', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'zeitschaltuhr')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 3, 'kreis_offen', 0.83, 0.5, 0, 0, 0, 0, 0.36, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 4, 'linie', 0.83, 0.5, 0.91, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zeitschaltuhr', 5, 'linie', 0.83, 0.5, 0.88, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'sicherung_netzseitig')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherung_netzseitig')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung_netzseitig', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung_netzseitig', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherung_netzseitig')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 0, 'linie', 0.5, 0, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 1, 'rechteck', 0.79, 0.25, 0.21, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 2, 'dreieck_gefuellt', 0.79, 0.575, 0.79, 0.75, 0.21, 0.75, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 3, 'dreieck_gefuellt', 0.79, 0.575, 0.21, 0.75, 0.21, 0.575, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'nh_sicherung')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'nh_sicherung')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('nh_sicherung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('nh_sicherung', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'nh_sicherung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 0, 'linie', 0.5, 0, 0.5, 0.203125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 1, 'linie', 0.78125, 0.203125, 0.21875, 0.203125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 2, 'rechteck', 0.78125, 0.25, 0.21875, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 3, 'linie', 0.78125, 0.796875, 0.21875, 0.796875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 4, 'linie', 0.5, 0.796875, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 5, 'linie', 0.5, 0.25, 0.5, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 24, hoehe_mm = 36, bmk_seite = 'vertikal' WHERE id = 'sicherungsschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherungsschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungsschalter', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungsschalter', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherungsschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 0, 'linie', 0.5, 0, 0.5, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 1, 'linie', 0.5, 0.28, 0.727, 0.62, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 2, 'linie', 0.5, 0.652778, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 3, 'linie', 0.641, 0.32, 0.777, 0.524, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 4, 'linie', 0.45, 0.376, 0.586, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 5, 'linie', 0.641, 0.32, 0.45, 0.376, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungsschalter', 6, 'linie', 0.777, 0.524, 0.586, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 24, hoehe_mm = 36, bmk_seite = 'vertikal' WHERE id = 'sicherungstrennschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherungstrennschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungstrennschalter', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungstrennschalter', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherungstrennschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 0, 'linie', 0.5, 0, 0.5, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 1, 'linie', 0.5, 0.28, 0.727, 0.62, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 2, 'linie', 0.5, 0.638889, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 3, 'linie', 0.641, 0.32, 0.777, 0.524, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 4, 'linie', 0.45, 0.376, 0.586, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 5, 'linie', 0.641, 0.32, 0.45, 0.376, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 6, 'linie', 0.777, 0.524, 0.586, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungstrennschalter', 7, 'linie', 0.4375, 0.638889, 0.5625, 0.638889, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 24, hoehe_mm = 36, bmk_seite = 'vertikal' WHERE id = 'sicherungslasttrennschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherungslasttrennschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungslasttrennschalter', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherungslasttrennschalter', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherungslasttrennschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 0, 'linie', 0.5, 0, 0.5, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 1, 'linie', 0.5, 0.28, 0.727, 0.62, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 2, 'linie', 0.5, 0.694444, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 3, 'linie', 0.641, 0.32, 0.777, 0.524, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 4, 'linie', 0.45, 0.376, 0.586, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 5, 'linie', 0.641, 0.32, 0.45, 0.376, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 6, 'linie', 0.777, 0.524, 0.586, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 7, 'kreis_offen', 0.5, 0.666667, 0, 0, 0, 0, 0.041667, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherungslasttrennschalter', 8, 'linie', 0.541667, 0.694444, 0.458333, 0.694444, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'ausschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'ausschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ausschalter', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ausschalter', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'ausschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ausschalter', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ausschalter', 1, 'linie', 0.5, 0.3, 0.75, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ausschalter', 2, 'linie', 0.5, 0.7, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'wechselschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'wechselschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechselschalter', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechselschalter', '2', 0.75, 1, 0, 1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechselschalter', '3', 0.25, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'wechselschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechselschalter', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechselschalter', 1, 'linie', 0.5, 0.3, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechselschalter', 2, 'linie', 0.75, 0.7, 0.55, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechselschalter', 3, 'linie', 0.75, 0.7, 0.75, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechselschalter', 4, 'linie', 0.25, 0.7, 0.25, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 32, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'serienschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'serienschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('serienschalter', '1', 0.75, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('serienschalter', '2', 0.75, 1, 0, 1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('serienschalter', '3', 0.25, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('serienschalter', '4', 0.25, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'serienschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 0, 'linie', 0.75, 0, 0.75, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 1, 'linie', 0.75, 0.3, 0.875, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 2, 'linie', 0.75, 0.7, 0.75, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 3, 'linie', 0.25, 0, 0.25, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 4, 'linie', 0.25, 0.3, 0.375, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 5, 'linie', 0.25, 0.7, 0.25, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('serienschalter', 6, 'linie', 0.95, 0.5, 0.05, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'dash'))",
            R"(UPDATE symbol_definition SET breite_mm = 24, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'taster_beleuchtet')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'taster_beleuchtet')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_beleuchtet', '1', 0.333, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_beleuchtet', '2', 0.333, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'taster_beleuchtet')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 0, 'linie', 0.333, 0, 0.333, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 1, 'linie', 0.333, 0.3, 0.5, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 2, 'linie', 0.333, 0.7, 0.333, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 3, 'linie', 0.573, 0.5, 0.427, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 4, 'linie', 0.573, 0.35, 0.573, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 5, 'linie', 0.713, 0.5, 0.573, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 6, 'kreis_offen', 0.833, 0.5, 0, 0, 0, 0, 0.12, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 7, 'linie', 0.893, 0.42, 0.773, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('taster_beleuchtet', 8, 'linie', 0.773, 0.42, 0.893, 0.58, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 24, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'kreuzschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'kreuzschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kreuzschalter', '1', 0.75, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kreuzschalter', '2', 0.25, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kreuzschalter', '3', 0.75, 1, 0, 1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kreuzschalter', '4', 0.25, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'kreuzschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 0, 'linie', 0.75, 0, 0.75, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 1, 'linie', 0.25, 0, 0.25, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 2, 'linie', 0.75, 0.7, 0.75, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 3, 'linie', 0.25, 0.7, 0.25, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 4, 'rechteck', 0.85, 0.3, 0.15, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 5, 'linie', 0.75, 0.3, 0.25, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kreuzschalter', 6, 'linie', 0.25, 0.3, 0.75, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 24, hoehe_mm = 24, bmk_seite = 'vertikal' WHERE id = 'zaehler')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'zaehler')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('zaehler', '1', 0.5, 0, 0, -1, 'power'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('zaehler', '2', 0.5, 1, 0, 1, 'power'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'zaehler')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zaehler', 0, 'linie', 0.5, 0, 0.5, 0.22, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zaehler', 1, 'linie', 0.5, 0.78, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zaehler', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('zaehler', 3, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'kWh', 0.16, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 28, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'ueberspannungsschutz')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'ueberspannungsschutz')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ueberspannungsschutz', '1', 0.6, 0, 0, -1, 'power'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ueberspannungsschutz', '2', 0.6, 1, 0, 1, 'power'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ueberspannungsschutz', 'PE', 0, 0.5, -1, 0, 'pe'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'ueberspannungsschutz')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 0, 'linie', 0.6, 0, 0.6, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 1, 'linie', 0.6, 0.75, 0.6, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 2, 'rechteck', 0.72, 0.25, 0.48, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 3, 'linie', 0.48, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 4, 'linie', 0.54, 0.32, 0.66, 0.68, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 5, 'linie', 0.15, 0.5, 0.22, 0.44, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ueberspannungsschutz', 6, 'linie', 0.15, 0.5, 0.22, 0.56, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 16, hoehe_mm = 32, bmk_seite = 'vertikal' WHERE id = 'rollladenschalter')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'rollladenschalter')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('rollladenschalter', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('rollladenschalter', '2', 0.75, 1, 0, 1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('rollladenschalter', '3', 0.25, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'rollladenschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenschalter', 0, 'linie', 0.5, 0, 0.5, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenschalter', 1, 'linie', 0.5, 0.3, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenschalter', 2, 'linie', 0.75, 0.7, 0.55, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenschalter', 3, 'linie', 0.75, 0.7, 0.75, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('rollladenschalter', 4, 'linie', 0.25, 0.7, 0.25, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'ueberspannungsschutz' AND name = 'PE')",
            R"(UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'ueberspannungsschutz' AND name = 'PE')",
        }},
        { 110, "SYM-KOPIE-STRESSTEST-01: schliesser/schliesser_nacheilend/schliesser_voreilend nach Nutzer-Kopien im Projekt Stresstest ueberarbeitet - Kontaktdiagonale nach links statt rechts gezogen. Auf Nutzerwunsch 1:1 uebernommen inkl. verlorener Pin-Versatz-Differenzierung zwischen voreilend/nacheilend (Nutzer: braucht den Versatz nicht, kann Symbole so gut unterscheiden) sowie schliesser_voreilend auf 8mm verbreitert (bewusst asymmetrisch zu schliesser_nacheilend, das bei 4mm bleibt). Details konzept/features/04_symbolsystem.md §17.", {
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'schliesser')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'schliesser')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser', 0, 'linie', 0.5, 0, 0.5, 0.291666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser', 1, 'linie', 0, 0.25, 0.5, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser', 2, 'linie', 0.5, 0.708333333333333, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'schliesser_nacheilend')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser_nacheilend', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser_nacheilend', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'schliesser_nacheilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_nacheilend', 0, 'linie', 0, 0.25, 0.5, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_nacheilend', 1, 'linie', 0, 0.25, 0.25, 0.225, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_nacheilend', 2, 'linie', 0.5, 0, 0.5, 0.291666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_nacheilend', 3, 'linie', 0.5, 0.708333333333333, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(UPDATE symbol_definition SET breite_mm = 8 WHERE id = 'schliesser_voreilend')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'schliesser_voreilend')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser_voreilend', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schliesser_voreilend', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'schliesser_voreilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_voreilend', 0, 'linie', 0.25, 0.25, 0.5, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_voreilend', 1, 'linie', 0.125, 0.283333333333333, 0.25, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_voreilend', 2, 'linie', 0.5, 0, 0.5, 0.291666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_voreilend', 3, 'linie', 0.5, 0.708333333333333, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 111, "SYM-KOPIE-STRESSTEST-02: sicherung/nh_sicherung/sicherung_netzseitig/lss/schutzerdung/diode nach Nutzer-Kopien im Projekt Stresstest ueberarbeitet (Primitiv-Rework Teil 2 der Schutz-Symbole, konzept/features/symbolgroessen_audit.md), plus zwei neue Nutzer-Symbole led/ventil uebernommen. sicherung/nh_sicherung/sicherung_netzseitig 16x32mm->8x16mm, lss komplett neu gezeichnet 4x12mm->12x12mm mit asymmetrischem Pin (x=0.667), schutzerdung 24x24mm->8x12mm, diode 16x32mm->8x16mm (dabei A/K-Pinreihenfolge vom Nutzer vertauscht). 1:1 uebernommen inkl. eines entarteten Bogens in lss (Start-/Endwinkel beide 180 Grad) und einer Nullpunkt-Linie - auf Nutzerwunsch unveraendert belassen. led/ventil als neue Built-in-Symbole (Kategorie Passive/Antriebe) inkl. symbol-Tabellen-Eintrag fuer die Palette.", {
            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 16 WHERE id = 'sicherung')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherung')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung', 0, 'linie', 0.5, 0, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung', 1, 'rechteck', 0.75, 0.25, 0.25, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 16 WHERE id = 'nh_sicherung')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'nh_sicherung')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('nh_sicherung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('nh_sicherung', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'nh_sicherung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 0, 'linie', 0.5, 0, 0.5, 0.21875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 1, 'linie', 0.75, 0.21875, 0.25, 0.21875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 2, 'rechteck', 0.75, 0.25, 0.25, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 3, 'linie', 0.75, 0.78125, 0.25, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 4, 'linie', 0.5, 0.78125, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('nh_sicherung', 5, 'linie', 0.5, 0.25, 0.5, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 16 WHERE id = 'sicherung_netzseitig')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'sicherung_netzseitig')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung_netzseitig', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('sicherung_netzseitig', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'sicherung_netzseitig')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 0, 'linie', 0.5, 0, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 1, 'rechteck', 0.75, 0.25, 0.25, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sicherung_netzseitig', 2, 'rechteck_gefuellt', 0.25, 0.25, 0.75, 0.375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 12, hoehe_mm = 12 WHERE id = 'lss')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'lss')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('lss', '1', 0.666666666666667, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('lss', '2', 0.666666666666667, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'lss')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 0, 'linie', 0.666666666666667, 0, 0.666666666666667, 0.291666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 1, 'linie', 0.416666666666667, 0.25, 0.666666666666667, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 2, 'linie', 0.666666666666667, 0.708333333333333, 0.666666666666667, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 3, 'bogen', 0.25, 0.5, 0, 0, 0, 0, 0.0625, 180, 180, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 4, 'linie', 0.75, 0.5, 0.75, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 5, 'linie', 0.476666666666667, 0.365833333333333, 0.375, 0.416666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 6, 'linie', 0.291666666666667, 0.458333333333333, 0.208333333333333, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 7, 'linie', 0.291666666666667, 0.458333333333333, 0.25, 0.375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 8, 'linie', 0.25, 0.375, 0.333333333333333, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 9, 'linie', 0.333333333333333, 0.333333333333333, 0.375, 0.416666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 10, 'linie', 0.25, 0.583333333333333, 0.333333333333333, 0.541666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 11, 'linie', 0.416666666666667, 0.5, 0.525, 0.445833333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lss', 12, 'bogen', 0.374166666666667, 0.520833333333333, 0, 0, 0, 0, 0.0458333333333333, 153.434948822922, 333.434948822922, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 12 WHERE id = 'schutzerdung')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'schutzerdung')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schutzerdung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'schutzerdung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schutzerdung', 0, 'kreis_offen', 0.5, 0.625, 0, 0, 0, 0, 0.5, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schutzerdung', 1, 'linie', 0.5, 0, 0.5, 0.625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schutzerdung', 2, 'linie', 0.125, 0.625, 0.875, 0.625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schutzerdung', 3, 'linie', 0.25, 0.708333333333333, 0.75, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schutzerdung', 4, 'linie', 0.375, 0.791666666666667, 0.625, 0.791666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 16 WHERE id = 'diode')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'diode')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('diode', 'K', 0.5, 0, 0, -1, 'power'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('diode', 'A', 0.5, 1, 0, 1, 'power'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'diode')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 0, 'linie', 0.5, 0, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 1, 'linie', 0.875, 0.291666666666667, 0.125, 0.291666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 2, 'linie', 0.5, 0.291666666666667, 0.125, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 3, 'linie', 0.5, 0.291666666666667, 0.875, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('diode', 4, 'linie', 0.875, 0.708333333333333, 0.125, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('led', 'LED', 'passive', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('led', 'LED', 'Passive', 8, 12, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('led', 'K', 0.5, 0, 0, -1, 'power'), ('led', 'A', 0.5, 1, 0, 1, 'power'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('led', 0, 'linie', 0.5, 0, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 1, 'linie', 0.875, 0.291666666666667, 0.125, 0.291666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 2, 'linie', 0.5, 0.291666666666667, 0.125, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 3, 'linie', 0.5, 0.291666666666667, 0.875, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 4, 'linie', 0.875, 0.708333333333333, 0.125, 0.708333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 5, 'linie', 0.125, 0.416666666666667, 0.25, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 6, 'linie', 0.1875, 0.375, 0.3125, 0.458333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 7, 'linie', 0.125, 0.416666666666667, 0.125, 0.458333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 8, 'linie', 0.125, 0.416666666666667, 0.1875, 0.416666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 9, 'linie', 0.1875, 0.375, 0.25, 0.375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('led', 10, 'linie', 0.1875, 0.375, 0.1875, 0.416666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('ventil', 'Ventil', 'antriebe', 'IEC,ANSI', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('ventil', 'Ventil', 'Antriebe', 16, 12, 'verbraucher', 1, 'vertikal'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ventil', 'A1', 0.25, 0, 0, -1, 'power'), ('ventil', 'A2', 0.25, 1, 0, 1, 'power'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('ventil', 0, 'linie', 0.25, 0, 0.25, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 1, 'linie', 0.25, 0.666666666666667, 0.25, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 2, 'rechteck', 0, 0.333333333333333, 0.5, 0.666666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 3, 'linie', 0.5, 0.5, 0.59375, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 4, 'linie', 0.6875, 0.208333333333333, 0.8125, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 5, 'linie', 0.71875, 0.5, 0.8125, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 6, 'linie', 0.8125, 0.5, 0.6875, 0.791666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 7, 'linie', 0.8125, 0.5, 0.9375, 0.208333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 8, 'linie', 0.9375, 0.208333333333333, 0.6875, 0.208333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 9, 'linie', 0.8125, 0.5, 0.9375, 0.791666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('ventil', 10, 'linie', 0.6875, 0.791666666666667, 0.9375, 0.791666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 112, "SYM-KOPIE-STRESSTEST-03: wischkontakt_betaetigung/_rueckfall/_beide (Kontakte) und widerstand_iec/kondensator (Passive) nach Nutzer-Kopien im Projekt Goerke ueberarbeitet. Wischkontakt-Familie 4x12mm->8x12mm (Detailgeometrie neu gezeichnet). widerstand_iec/kondensator waren bisher horizontal und nie Teil von SYMBOL-VERTIKAL-01 - jetzt analog dazu auf vertikal gedreht + auf 8x12mm verkleinert (vorher 32x16mm). Dabei bewusst NICHT 1:1 aus der Kopie uebernommen: knoten_gruppe=1 auf dem zweiten Pin (widerstand_iec '2', kondensator '-') aus NETZ-MEHRPOL-02 blieb erhalten, obwohl die Kopie im Symboleditor (dort kein editierbares Feld) implizit auf den Default 0 zurueckfiel - sonst waeren beide Pins wieder als derselbe Netzberechnungs-Knoten behandelt worden, exakt der vor NETZ-MEHRPOL-02 behobene Fehler.", {
            R"(UPDATE symbol_definition SET breite_mm = 8 WHERE id = 'wischkontakt_betaetigung')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'wischkontakt_betaetigung')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_betaetigung', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_betaetigung', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'wischkontakt_betaetigung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_betaetigung', 0, 'linie', 0.5, 0, 0.5, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_betaetigung', 1, 'linie', 0.25, 0.291666666666667, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_betaetigung', 2, 'linie', 0.5, 0.78125, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_betaetigung', 3, 'linie', 0.375, 0.25, 0.5, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8 WHERE id = 'wischkontakt_beide')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'wischkontakt_beide')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_beide', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_beide', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'wischkontakt_beide')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 0, 'linie', 0.5, 0, 0.5, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 1, 'linie', 0.25, 0.291666666666667, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 2, 'linie', 0.5, 0.78125, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 3, 'linie', 0.375, 0.25, 0.5, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_beide', 4, 'linie', 0.5, 0.333333333333333, 0.625, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8 WHERE id = 'wischkontakt_rueckfall')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'wischkontakt_rueckfall')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_rueckfall', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wischkontakt_rueckfall', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'wischkontakt_rueckfall')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_rueckfall', 0, 'linie', 0.5, 0, 0.5, 0.333333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_rueckfall', 1, 'linie', 0.25, 0.291666666666667, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_rueckfall', 2, 'linie', 0.5, 0.78125, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wischkontakt_rueckfall', 3, 'linie', 0.5, 0.333333333333333, 0.625, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'widerstand_iec')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'widerstand_iec')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('widerstand_iec', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('widerstand_iec', '2', 0.5, 1, 0, 1, 'neutral'))",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'widerstand_iec' AND name = '2')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'widerstand_iec')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('widerstand_iec', 0, 'rechteck', 0.3125, 0.25, 0.6875, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('widerstand_iec', 1, 'linie', 0.5, 0, 0.5, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('widerstand_iec', 2, 'linie', 0.5, 0.75, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            R"(UPDATE symbol_definition SET breite_mm = 8, hoehe_mm = 12, bmk_seite = 'vertikal' WHERE id = 'kondensator')",
            R"(DELETE FROM symbol_pin WHERE symbol_id = 'kondensator')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kondensator', '+', 0.5, 0, 0, -1, 'power'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kondensator', '-', 0.5, 1, 0, 1, 'power'))",
            R"(UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'kondensator' AND name = '-')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id = 'kondensator')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kondensator', 0, 'linie', 0.1875, 0.583333333333333, 0.8125, 0.583333333333333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kondensator', 1, 'linie', 0.8125, 0.416666666666667, 0.1875, 0.416666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kondensator', 2, 'linie', 0.5, 0, 0.5, 0.416666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kondensator', 3, 'linie', 0.5, 0.583333333333333, 0.5, 1, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",
        }},
        { 113, "SYM-LOESCH-MARKIERUNG-01: neue Spalte symbol_definition.markiert_loeschen (Entwicklungsphase-Werkzeug) - Nutzer markiert Symbole (auch built-in) in der Palette per Rechtsklick zum Loeschen, Claude wertet die Markierung dann per SQL aus und entfernt die Symbole inkl. Seed-Eintraegen auf Zuruf. Reine Merker-Spalte, kein automatisches Loeschen.", {
            R"(ALTER TABLE symbol_definition ADD COLUMN markiert_loeschen INTEGER NOT NULL DEFAULT 0)",
        }},
        { 114, "SYM-KOPIE-VON-01: neue Spalte symbol_definition.kopie_von_id (Entwicklungsphase-Werkzeug) - wird beim ersten Speichern einer per 'Als Vorlage kopieren' erzeugten Kopie automatisch auf die Quell-Symbol-ID gesetzt. Ersetzt die bisherige informelle Konvention (Namenspraefix 'Kopie von'/ID-Praefix 'kopie_von_*', s. SYM-KOPIE-STRESSTEST-01/02/03), damit Claude offene Nutzer-Kopien fuer den Seed-Sync per SQL findet statt Projekte manuell durchsuchen zu muessen.", {
            R"(ALTER TABLE symbol_definition ADD COLUMN kopie_von_id TEXT)",
        }},
        { 115, "SYM-LOESCH-MARKIERUNG-01/SYM-KOPIE-VON-01 erster Praxis-Durchlauf (Projekt Goerke): 'ausschalter'/'caravan_batterie' per Nutzer-Markierung geloescht (samt Legacy-symbol-Tabelle); 'erde_allgemein' 16x22mm->8x8mm und 'wp_heizstab' 32x24mm->8x4mm nach Nutzer-Kopien 'kopie_von_erde_allgemein'/'kopie_von_heizstab_zusatzheizer' ueberarbeitet, Kopien danach entfernt.", {
            // erde_allgemein <- kopie_von_erde_allgemein (Pins unveraendert, nur Groesse+Geometrie)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='erde_allgemein')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='erde_allgemein')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('erde_allgemein', '1', 0.5, 0, 0, -1, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='erde_allgemein')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('erde_allgemein', 0, 'linie', 0.5, 0.0, 0.5, 0.375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('erde_allgemein', 1, 'linie', 0.0625, 0.375, 0.9375, 0.375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('erde_allgemein', 2, 'linie', 0.1875, 0.625, 0.8125, 0.625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('erde_allgemein', 3, 'linie', 0.3125, 0.875, 0.6875, 0.875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // wp_heizstab <- kopie_von_heizstab_zusatzheizer (Pins unveraendert, nur Groesse+Geometrie)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=4 WHERE id='wp_heizstab')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='wp_heizstab')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wp_heizstab', '1', 0, 0.5, -1, 0, 'power'), ('wp_heizstab', '2', 1, 0.5, 1, 0, 'power'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='wp_heizstab')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wp_heizstab', 0, 'linie', 0.0, 0.5, 0.1875, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 1, 'linie', 0.8125, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 2, 'rechteck', 0.1875, 0.25, 0.8125, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 3, 'linie', 0.3125, 0.5, 0.3125, 0.375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 4, 'linie', 0.5, 0.3, 0.55, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wp_heizstab', 5, 'linie', 0.65, 0.3, 0.7, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // Werkstatt-Kopien nach Uebernahme entfernen
            R"(DELETE FROM symbol_definition WHERE id IN ('kopie_von_erde_allgemein', 'kopie_von_heizstab_zusatzheizer'))",

            // Vom Nutzer per Loeschmarkierung markierte built-in-Symbole entfernen
            // (Cascade auf symbol_pin/symbol_primitiv via ON DELETE CASCADE)
            R"(DELETE FROM symbol WHERE code IN ('ausschalter', 'caravan_batterie'))",
            R"(DELETE FROM symbol_definition WHERE id IN ('ausschalter', 'caravan_batterie'))",
        }},
        { 116, "SYM-KOPIE-VON-01 zweiter Sync-Durchlauf (Projekt Goerke, 'eigene Symbole' durchsucht): 10 weitere Nutzer-Kopien uebernommen (caravan_kuehlschrank, sps_ai_4, sps_ai_8, brueckengleichrichter, kfz_cdi, motor, netzteil, querverweis, spule, trafo - reine Groessenkorrekturen bis auf motor (Pins links->oben gedreht, per Nutzerbestaetigung) und spule (Pin A2 Signaltyp power->n, per Nutzerbestaetigung). netzteil: Pin-rolle (quelle/verbraucher, NETZTEIL-ROLLE-01) bewusst NICHT aus der Kopie uebernommen, da der Symboleditor dafuer kein Feld hat und der Wert beim Kopieren implizit auf leer zurueckfiel - analog zum vor SE-KNOTENGRUPPE-01 behobenen knoten_gruppe-Verlust. Zusaetzlich 5 bereits laengst in Migration 112 uebernommene Karteileichen-Kopien geloescht (kondensator/widerstand_iec/wischkontakt_betaetigung/_beide/_rueckfall - geometrisch 1:1 identisch mit den Originalen, nie aufgeraeumt).", {
            // caravan_kuehlschrank <- kopie_von_absorberkuehlschrank_12v_230v_gas
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=20 WHERE id='caravan_kuehlschrank')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='caravan_kuehlschrank')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('caravan_kuehlschrank', '12V+', 0, 0.2, -1, 0, 'dc_plus'), ('caravan_kuehlschrank', '12V-', 0, 0.4, -1, 0, 'dc_minus'), ('caravan_kuehlschrank', 'L', 0, 0.6, -1, 0, 'power'), ('caravan_kuehlschrank', 'N', 0, 0.8, -1, 0, 'n'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='caravan_kuehlschrank')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('caravan_kuehlschrank', 0, 'rechteck', 0.15625, 0.05, 0.84375, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 1, 'linie', 0.0, 0.2, 0.15625, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 2, 'linie', 0.0, 0.4, 0.15625, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 3, 'linie', 0.0, 0.6, 0.15625, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 4, 'linie', 0.0, 0.8, 0.15625, 0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 5, 'text', 0.5, 0.22, 0, 0, 0, 0, 0, 0, 0, 0, 'ABS', 0.15, 1, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 6, 'text', 0.5, 0.42, 0, 0, 0, 0, 0, 0, 0, 0, '12V', 0.1, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 7, 'text', 0.5, 0.55, 0, 0, 0, 0, 0, 0, 0, 0, '230V', 0.1, 0, 'center', 'middle', 'solid'), ('caravan_kuehlschrank', 8, 'text', 0.5, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, 'GAS', 0.12, 0, 'center', 'middle', 'solid'))",

            // sps_ai_4 <- kopie_von_ai_baugruppe_4_kanal (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=12, hoehe_mm=20 WHERE id='sps_ai_4')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='sps_ai_4')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sps_ai_4', 0, 'rechteck', 0.16666666666666666, 0.025, 0.83333333333333337, 0.975, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_4', 1, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'AI 4', 0.1, 1, 'center', 'middle', 'solid'), ('sps_ai_4', 2, 'linie', 0.0, 0.2, 0.16666666666666666, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_4', 3, 'linie', 0.0, 0.4, 0.16666666666666666, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_4', 4, 'linie', 0.0, 0.6, 0.16666666666666666, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_4', 5, 'linie', 0.0, 0.8, 0.16666666666666666, 0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // sps_ai_8 <- kopie_von_ai_baugruppe_8_kanal (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=36 WHERE id='sps_ai_8')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='sps_ai_8')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('sps_ai_8', 0, 'rechteck', 0.15625, 0.013888888888888888, 0.84375, 0.98611111111111116, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 1, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'AI 8', 0.08, 1, 'center', 'middle', 'solid'), ('sps_ai_8', 2, 'linie', 0.0, 0.1111111111111111, 0.15625, 0.1111111111111111, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 3, 'linie', 0.0, 0.22222222222222221, 0.15625, 0.22222222222222221, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 4, 'linie', 0.0, 0.33333333333333332, 0.15625, 0.33333333333333332, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 5, 'linie', 0.0, 0.44444444444444442, 0.15625, 0.44444444444444442, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 6, 'linie', 0.0, 0.55555555555555558, 0.15625, 0.55555555555555558, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 7, 'linie', 0.0, 0.66666666666666663, 0.15625, 0.66666666666666663, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 8, 'linie', 0.0, 0.77777777777777779, 0.15625, 0.77777777777777779, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('sps_ai_8', 9, 'linie', 0.0, 0.88888888888888884, 0.15625, 0.88888888888888884, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // brueckengleichrichter <- kopie_von_brueckengleichrichter (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='brueckengleichrichter')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='brueckengleichrichter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('brueckengleichrichter', 0, 'linie', 0.15, 0.5, 0.5, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 1, 'linie', 0.5, 0.15, 0.85, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 2, 'linie', 0.85, 0.5, 0.5, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 3, 'linie', 0.5, 0.85, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 4, 'linie', 0.0, 0.5, 0.15, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 5, 'linie', 0.85, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 6, 'linie', 0.5, 0.0, 0.5, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 7, 'linie', 0.5, 0.85, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('brueckengleichrichter', 8, 'text', 0.5, 0.3, 0, 0, 0, 0, 0, 0, 0, 0, '+', 0.18, 1, 'center', 'middle', 'solid'), ('brueckengleichrichter', 9, 'text', 0.5, 0.7, 0, 0, 0, 0, 0, 0, 0, 0, '-', 0.18, 1, 'center', 'middle', 'solid'))",

            // kfz_cdi <- kopie_von_cdi_zuendbox (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='kfz_cdi')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='kfz_cdi')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('kfz_cdi', 0, 'linie', 0.0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 1, 'linie', 0.0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 2, 'linie', 0.85, 0.25, 1.0, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 3, 'linie', 0.85, 0.75, 1.0, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 4, 'rechteck', 0.15, 0.1, 0.85, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 5, 'linie', 0.4, 0.35, 0.4, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 6, 'linie', 0.6, 0.35, 0.6, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('kfz_cdi', 7, 'text', 0.5, 0.78, 0, 0, 0, 0, 0, 0, 0, 0, 'CDI', 0.14, 1, 'center', 'middle', 'solid'))",

            // motor <- kopie_von_motor (Pins per Nutzerbestaetigung von links auf oben gedreht)
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=12 WHERE id='motor')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='motor')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('motor', 'U', 0.25, 0, 0, -1, 'power'), ('motor', 'V', 0.5, 0, 0, -1, 'power'), ('motor', 'W', 0.75, 0, 0, -1, 'power'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='motor')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('motor', 0, 'kreis_offen', 0.5, 0.625, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('motor', 1, 'text', 0.5, 0.54166666666666663, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.2, 1, 'center', 'middle', 'solid'), ('motor', 2, 'text', 0.5, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, '3~', 0.14, 0, 'center', 'middle', 'solid'), ('motor', 3, 'linie', 0.25, 0.45833333333333332, 0.25, 0, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'), ('motor', 4, 'linie', 0.5, 0.25, 0.5, 0, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'), ('motor', 5, 'linie', 0.75, 0.45833333333333332, 0.75, 0, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",

            // netzteil <- kopie_von_netzteil (nur Groesse+Primitive; Pin-Positionen identisch, rolle-Spalte
            // bewusst NICHT aus der Kopie uebernommen - Symboleditor hat dafuer kein Feld, Kopie hatte sie leer)
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='netzteil')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='netzteil')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('netzteil', 0, 'rechteck', 0.15625, 0.15625, 0.84375, 0.84375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 1, 'linie', 0.0, 0.25, 0.15625, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 2, 'linie', 0.0, 0.75, 0.15625, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 3, 'linie', 0.84375, 0.25, 1.0, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('netzteil', 4, 'linie', 0.84375, 0.75, 1.0, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // querverweis <- kopie_von_querverweis (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='querverweis')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='querverweis')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('querverweis', 0, 'linie', 0.0, 0.5, 0.5, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('querverweis', 1, 'dreieck_gefuellt', 0.5, 0.35, 1.0, 0.5, 0.5, 0.65, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // spule <- kopie_von_spule_relais (Pin A2 Signaltyp per Nutzerbestaetigung power->n)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=12 WHERE id='spule')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='spule')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('spule', 'A1', 0.5, 0, 0, -1, 'power'), ('spule', 'A2', 0.5, 1, 0, 1, 'n'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='spule')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('spule', 0, 'linie', 0.5, 0.0, 0.5, 0.33333333333333332, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('spule', 1, 'linie', 0.5, 0.66666666666666663, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('spule', 2, 'rechteck', 0.0, 0.33333333333333332, 1.0, 0.66666666666666663, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",

            // trafo <- kopie_von_transformator (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='trafo')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='trafo')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('trafo', 0, 'linie', 0.0, 0.25, 0.3, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 1, 'linie', 0.0, 0.75, 0.3, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 2, 'linie', 0.7, 0.25, 1.0, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 3, 'linie', 0.7, 0.75, 1.0, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 4, 'kreis_offen', 0.3, 0.5, 0, 0, 0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 5, 'kreis_offen', 0.7, 0.5, 0, 0, 0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 6, 'linie', 0.48, 0.275, 0.48, 0.725, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('trafo', 7, 'linie', 0.52, 0.275, 0.52, 0.725, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // Alle Werkstatt-Kopien entfernen: 10 uebernommene + 5 laengst-obsolete Karteileichen
            R"(DELETE FROM symbol_definition WHERE id IN (
                'kopie_von_absorberkuehlschrank_12v_230v_gas', 'kopie_von_ai_baugruppe_4_kanal',
                'kopie_von_ai_baugruppe_8_kanal', 'kopie_von_brueckengleichrichter', 'kopie_von_cdi_zuendbox',
                'kopie_von_motor', 'kopie_von_netzteil', 'kopie_von_querverweis', 'kopie_von_spule_relais',
                'kopie_von_transformator', 'kopie_von_kondensator', 'kopie_von_widerstand_iec',
                'kopie_von_wischkontakt_bei_betaetigung', 'kopie_von_kopie_von_wischkontakt_bei_betaetigung',
                'kopie_von_kopie_von_wischkontakt_bei_betaetigung_rueckfall'
            ))",
        }},
        { 117, "SYM-KOPIE-VON-01 dritter Sync-Durchlauf (Projekt Goerke): 3 weitere Nutzer-Kopien uebernommen - reine Massenkorrekturen ohne Geometrie-/Pin-Aenderung (treffpunkt/treffpunkt_l 16x16mm->8x8mm, motor 16x12mm->32x24mm). Treffpunkt/Treffpunkt_L behalten bewusst ihre von normalen Symbolen abweichenden Pin-Positionen auf Kanten-Mittelpunkten statt Bbox-Ecken bei (s. 05_leitungen_kabel.md) - unveraendert aus der Kopie uebernommen.", {
            // treffpunkt <- kopie_von_treffpunkt_t (nur Groesse, Pins/Primitive unveraendert)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='treffpunkt')",

            // treffpunkt_l <- kopie_von_treffpunkt_l (nur Groesse, Pins/Primitive unveraendert)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='treffpunkt_l')",

            // motor <- kopie_von_motor (nur Groesse, Pins/Primitive unveraendert)
            R"(UPDATE symbol_definition SET breite_mm=32, hoehe_mm=24 WHERE id='motor')",

            // Werkstatt-Kopien nach Uebernahme entfernen
            R"(DELETE FROM symbol_definition WHERE id IN ('kopie_von_treffpunkt_t', 'kopie_von_treffpunkt_l', 'kopie_von_motor'))",
        }},
        { 118, "SYM-KOPIE-VON-01 vierter Sync-Durchlauf (Projekt Goerke): 23 Nutzer-Kopien uebernommen - 13 reine Massenkorrekturen, 4 Anschluss-Symbole (stecker/buchse/klemme/lampe) mit Pins von eingerueckt auf echte Kanten korrigiert, oeffner + die Voreilend/Nacheilend-Kontaktfamilie (oeffner_nacheilend/schliesser_nacheilend/schliesser_voreilend) neu gezeichnet und auf 4x8mm vereinheitlicht (Zuordnung ueber die vom Nutzer vergebenen Namen, da die kopie_von_id-Kette durch mehrfaches Editor-internes Kopieren nicht direkt auf die echten Originale zeigt), wechsler auf die schmale Kopie-Geometrie korrigiert und in 'Wechsler schmal' umbenannt, neues Symbol wechsler_breit ('Wechsler', 8x8mm) aus der zweiten, breiteren Kopie ergaenzt (Nutzerbestaetigung per AskUserQuestion). Zusaetzlich 5 vom Nutzer zur Loeschung markierte, nirgends platzierte built-in-Symbole entfernt (spule_ansi, widerstand_ansi, wechselschalter, kfz_lichtschalter, kfz_kupplungsschalter).", {
            // --- Gruppe A: reine Massenkorrekturen (Pins/Primitive unveraendert) ---
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=56 WHERE id='caravan_anhaengerstecker_13')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=20 WHERE id='sps_ao_4')",
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='kfz_batterie')",
            R"(UPDATE symbol_definition SET breite_mm=12, hoehe_mm=16 WHERE id='caravan_trennrelais')",
            R"(UPDATE symbol_definition SET breite_mm=12, hoehe_mm=20 WHERE id='sps_cpu')",
            R"(UPDATE symbol_definition SET breite_mm=12, hoehe_mm=8 WHERE id='kfz_gluehkerze')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=8 WHERE id='caravan_wasserpumpe')",
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='isoliert_gelegte_ader')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=68 WHERE id='sps_do_16')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=36 WHERE id='sps_do_8')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=12 WHERE id='funktionserdung')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=8 WHERE id='hupe')",
            R"(UPDATE symbol_definition SET breite_mm=20, hoehe_mm=16 WHERE id='kfz_kombiinstrument')",

            // --- Gruppe B: Anschluss-Symbole, Pins auf echte Kanten korrigiert ---
            // stecker <- kopie_von_stecker
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='stecker')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='stecker')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('stecker', '1', 0.0, 0.5, -1.0, 0.0, 'neutral'), ('stecker', '2', 0.5, 0.5, 1.0, 0.0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='stecker')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('stecker', 0, 'linie', 0.0, 0.5, 0.1875, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('stecker', 1, 'rechteck', 0.1875, 0.4375, 0.5, 0.5625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // buchse <- kopie_von_buchse
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='buchse')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='buchse')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('buchse', '1', 0.0, 0.5, -1.0, 0.0, 'neutral'), ('buchse', '2', 0.5, 0.5, 1.0, 0.0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='buchse')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('buchse', 0, 'linie', 0.0, 0.5, 0.5, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('buchse', 1, 'bogen', 0.625, 0.5, 0, 0, 0, 0, 0.125, 90, 270, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // klemme <- kopie_von_klemme
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='klemme')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='klemme')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('klemme', '1', 0.0, 0.5, -1.0, 0.0, 'neutral'), ('klemme', '2', 1.0, 0.5, 1.0, 0.0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='klemme')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('klemme', 0, 'linie', 0.0, 0.5, 0.375, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('klemme', 1, 'linie', 0.625, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('klemme', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.125, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // lampe <- kopie_von_lampe
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='lampe')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='lampe')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('lampe', '1', 0.0, 0.5, -1.0, 0.0, 'neutral'), ('lampe', '2', 1.0, 0.5, 1.0, 0.0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='lampe')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('lampe', 0, 'linie', 0.0, 0.5, 0.23125, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('lampe', 1, 'linie', 0.76875, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('lampe', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.2675, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('lampe', 3, 'linie', 0.3125, 0.3125, 0.6875, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('lampe', 4, 'linie', 0.3125, 0.6875, 0.6875, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // --- Gruppe C: oeffner + Voreilend/Nacheilend-Kontaktfamilie (Zuordnung ueber Namen, s. Beschreibung oben) ---
            // oeffner <- kopie_von_oeffner_nc (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=4, hoehe_mm=8 WHERE id='oeffner')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner', 0, 'linie', 0.5, 0.0, 0.5, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner', 1, 'linie', 0.25, 0.25, 0.5, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner', 2, 'linie', 0.5, 0.6875, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner', 3, 'linie', 0.25, 0.3125, 0.5, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'))",

            // oeffner_nacheilend <- kopie_von_nacheilender_oeffner_nc (Pins UND Primitive geaendert - Geometrie komplett neu gezeichnet, an oeffner angeglichen)
            R"(UPDATE symbol_definition SET breite_mm=4, hoehe_mm=8 WHERE id='oeffner_nacheilend')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='oeffner_nacheilend')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('oeffner_nacheilend', '1', 0.5, 0.0, 0.0, -1.0, 'neutral'), ('oeffner_nacheilend', '2', 0.5, 1.0, 0.0, 1.0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner_nacheilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('oeffner_nacheilend', 0, 'linie', 0.5, 0.0, 0.5, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 1, 'linie', 0.25, 0.25, 0.5, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 2, 'linie', 0.5, 0.6875, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 3, 'linie', 0.25, 0.3125, 0.5, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('oeffner_nacheilend', 4, 'linie', 0.25, 0.25, 0.375, 0.2325, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",

            // schliesser_nacheilend <- kopie_von_kopie_von_nacheilender_oeffner_nc (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=4, hoehe_mm=8 WHERE id='schliesser_nacheilend')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='schliesser_nacheilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_nacheilend', 0, 'linie', 0.5, 0.0, 0.5, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_nacheilend', 1, 'linie', 0.25, 0.25, 0.5, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_nacheilend', 2, 'linie', 0.5, 0.6875, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_nacheilend', 3, 'linie', 0.25, 0.25, 0.375, 0.2325, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",

            // schliesser_voreilend <- kopie_von_voreilender_schliesser_no (Pins unveraendert, nur Groesse+Primitive)
            R"(UPDATE symbol_definition SET breite_mm=4, hoehe_mm=8 WHERE id='schliesser_voreilend')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='schliesser_voreilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('schliesser_voreilend', 0, 'linie', 0.5, 0.0, 0.5, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 1, 'linie', 0.25, 0.25, 0.5, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 2, 'linie', 0.5, 0.6875, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('schliesser_voreilend', 3, 'linie', 0.075, 0.28125, 0.25, 0.25, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",

            // --- Gruppe D: Wechsler-Aufspaltung (Nutzerbestaetigung per AskUserQuestion) ---
            // wechsler <- kopie_von_wechsler, umbenannt in "Wechsler schmal" (bisherige 4x12mm-Geometrie war die schmale Variante)
            R"(UPDATE symbol_definition SET name='Wechsler schmal', breite_mm=4, hoehe_mm=8 WHERE id='wechsler')",
            R"(UPDATE symbol SET name='Wechsler schmal' WHERE code='wechsler')",
            R"(DELETE FROM symbol_pin WHERE symbol_id='wechsler')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechsler', 'K', 1.0, 1.0, 0.0, 1.0, 'neutral'), ('wechsler', 'NO', 1.0, 0.0, 0.0, -1.0, 'neutral'), ('wechsler', 'NC', 0.0, 0.0, 0.0, -1.0, 'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='wechsler')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler', 0, 'linie', 1.0, 0.0, 1.0, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler', 1, 'linie', 0.25, 0.25, 1.0, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler', 2, 'linie', 0.0, 0.0, 0.0, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler', 3, 'linie', 1.0, 0.6875, 1.0, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler', 4, 'linie', 0.0, 0.3125, 0.5, 0.3125, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",

            // wechsler_breit (neu) <- kopie_von_kopie_von_wechsler_schmal, die breitere zweite Variante
            R"(INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('wechsler_breit', 'Wechsler', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechsler_breit', 'K', 0.5, 1.0, 0.0, 1.0, 'neutral'), ('wechsler_breit', 'NO', 1.0, 0.0, 0.0, -1.0, 'neutral'), ('wechsler_breit', 'NC', 0.0, 0.0, 0.0, -1.0, 'neutral'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES ('wechsler_breit', 0, 'linie', 1.0, 0.0, 1.0, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler_breit', 1, 'linie', 0.25, 0.25, 0.5, 0.6875, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler_breit', 2, 'linie', 0.0, 0.0, 0.0, 0.3125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler_breit', 3, 'linie', 0.5, 0.6875, 0.5, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'), ('wechsler_breit', 4, 'linie', 0.0, 0.3125, 0.375, 0.3125, 0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wechsler_breit', 'Wechsler', 'kontakte', 'IEC,ANSI', 3))",

            // --- Werkstatt-Kopien nach Uebernahme entfernen ---
            R"(DELETE FROM symbol_definition WHERE id IN (
                'kopie_von_anhaenger_steckdose_13_polig', 'kopie_von_ao_baugruppe_4_kanal', 'kopie_von_batterie_12v',
                'kopie_von_batterie_trennrelais', 'kopie_von_stecker', 'kopie_von_buchse', 'kopie_von_cpu_baugruppe',
                'kopie_von_gluehkerze', 'kopie_von_frischwasserpumpe_12v', 'kopie_von_isoliert_gelegte_ader',
                'kopie_von_do_baugruppe_16_kanal', 'kopie_von_do_baugruppe_8_kanal', 'kopie_von_funktionserdung',
                'kopie_von_hupe_klingel', 'kopie_von_klemme', 'kopie_von_kombiinstrument', 'kopie_von_lampe',
                'kopie_von_oeffner_nc', 'kopie_von_nacheilender_oeffner_nc', 'kopie_von_kopie_von_nacheilender_oeffner_nc',
                'kopie_von_voreilender_schliesser_no', 'kopie_von_wechsler', 'kopie_von_kopie_von_wechsler_schmal'
            ))",

            // --- Vom Nutzer per Loeschmarkierung markierte built-in-Symbole entfernen (0 platzierte Instanzen) ---
            R"(DELETE FROM symbol WHERE code IN ('spule_ansi', 'widerstand_ansi', 'wechselschalter', 'kfz_lichtschalter', 'kfz_kupplungsschalter'))",
            R"(DELETE FROM symbol_definition WHERE id IN ('spule_ansi', 'widerstand_ansi', 'wechselschalter', 'kfz_lichtschalter', 'kfz_kupplungsschalter'))",
        }},
        { 119, "SYM-KOPIE-VON-01 fuenfter Sync-Durchlauf (Projekt Goerke): unterbrechung 16x16mm->8x8mm uebernommen (reine Massenkorrektur, Pins/Primitive unveraendert - unterbrechung hat wie aderdefinition grundsaetzlich keine Pins). Im Zuge dessen echten Bug in autoVerbindungenBerechnen() (SymbolDefinitionModel.cpp) behoben: die Sperrelement-Erkennung fuer die automatische Rasterverbindungs-Vorschlagslogik pruefte hart auf die Symbol-ID 'unterbrechung' statt auf rolle='trenner' - jede Symboleditor-Kopie von 'unterbrechung' (neue, andere ID) wurde dadurch nie als Blockierer erkannt und die automatische Verbindungsvorschau lief einfach durch die Kopie hindurch, obwohl deren rolle-Spalte korrekt 'trenner' mitkopiert wurde. Vom Nutzer beim Testen der eigenen Kopie bemerkt.", {
            // unterbrechung <- kopie_von_unterbrechung (nur Groesse, Pins/Primitive unveraendert)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='unterbrechung')",

            // Werkstatt-Kopie nach Uebernahme entfernen
            R"(DELETE FROM symbol_definition WHERE id='kopie_von_unterbrechung')",
        }},
        { 120, "SE-ROTATION-01: symbol_primitiv.rotation-Spalte (Grad, Default 0) - freie Rotation von rechteck/rechteck_gefuellt/text-Primitiven im Symboleditor, unabhaengig von der 90-Grad-Ausrichtung ganzer platzierter Symbole.", {
            R"(ALTER TABLE symbol_primitiv ADD COLUMN rotation REAL NOT NULL DEFAULT 0)",
        }},
        { 121, "SYM-KOPIE-VON-01 sechster Sync-Durchlauf (Projekt Goerke): 8 Nutzer-Kopien uebernommen. oeffner reine Massenkorrektur 4x8mm->8x8mm (Pins/Primitive unveraendert). oeffner_nacheilend/schliesser_nacheilend/schliesser_voreilend je 4x8mm->8x8mm mit leicht angepasster Diagonalmarkierung. schliesser 4x12mm->8x8mm mit verkuerzter Diagonale. sicherungslasttrennschalter 24x36mm->8x12mm komplett neu gezeichnet (Zickzack-Linien ersetzt durch ein rotiertes Rechteck, nutzt SE-ROTATION-01). kfz_sicherungskasten 40x48mm->16x20mm proportional skaliert (Primitive+Pins). oeffner_voreilend 4x12mm->8x8mm komplett neu gezeichnet, altes asymmetrisches Design durch einheitliches Design im Stil der uebrigen Oeffner/Schliesser-Familie ersetzt - Zuordnung ueber den vom Nutzer vergebenen Namen ('Kopie von Voreilender Oeffner'), da kopie_von_id der Werkstatt-Kopie (mehrfaches Editor-internes '⧉ Kopie') nur auf eine andere, ebenfalls noch offene Zwischenkopie zeigte statt auf das echte Original - Anlass fuer KOPIE-KETTE-01 (SymbolDefinitionModel::symbolAnlegen() loest die kopie_von_id-Kette jetzt automatisch bis zum Wurzel-Original auf, symboleMitKopieVon() erkennt zusaetzlich Name/Ziel-Abweichungen wie diese). Zusaetzlich 3 vom Nutzer zur Loeschung markierte, nirgends platzierte built-in-Symbole entfernt (rollladenschalter, kfz_seitenstaenderschalter, kfz_bremslichtschalter).", {
            // oeffner <- kopie_von_oeffner_nc (reine Massenkorrektur, Pins/Primitive unveraendert)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='oeffner')",

            // oeffner_nacheilend <- kopie_von_nacheilender_oeffner (Groesse + Diagonalmarkierung leicht angepasst)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='oeffner_nacheilend')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner_nacheilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('oeffner_nacheilend',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',3,'linie',0.25,0.3125,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',4,'linie',0.25,0.25,0.375,0.2,0.0,0.0,0.0,0.0,360.0,0,NULL,0.15,0,'center','middle','solid',0.0))",

            // schliesser <- kopie_von_schliesser_no (Groesse + verkuerzte Diagonale)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='schliesser')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='schliesser')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('schliesser',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser',1,'linie',0.25,0.25,0.5,0.70833333333333304,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser',2,'linie',0.5,0.70833333333333304,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            // schliesser_nacheilend <- kopie_von_nacheilender_schliesser (Groesse + Diagonalmarkierung leicht angepasst)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='schliesser_nacheilend')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='schliesser_nacheilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('schliesser_nacheilend',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser_nacheilend',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser_nacheilend',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser_nacheilend',3,'linie',0.25,0.25,0.375,0.2,0.0,0.0,0.0,0.0,360.0,0,NULL,0.15,0,'center','middle','solid',0.0))",

            // schliesser_voreilend <- kopie_von_voreilender_schliesser (Groesse + Diagonalmarkierung deutlich verschoben)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='schliesser_voreilend')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='schliesser_voreilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('schliesser_voreilend',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser_voreilend',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser_voreilend',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser_voreilend',3,'linie',0.125,0.3125,0.25,0.25,0.0,0.0,0.0,0.0,360.0,0,NULL,0.15,0,'center','middle','solid',0.0))",

            // sicherungslasttrennschalter <- kopie_von_sicherungslasttrennschalter (komplett neu gezeichnet: rotiertes Rechteck statt Zickzack-Linien)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=12 WHERE id='sicherungslasttrennschalter')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='sicherungslasttrennschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('sicherungslasttrennschalter',0,'linie',0.5,0.0,0.5,0.29166666666666669,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungslasttrennschalter',1,'linie',0.1875,0.33333333333333332,0.5,0.66666666666666663,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungslasttrennschalter',2,'linie',0.5,0.66666666666666663,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungslasttrennschalter',3,'kreis_offen',0.5,0.33333333333333332,0.0,0.0,0.0,0.0,0.0625,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungslasttrennschalter',4,'linie',0.5625,0.29166666666666669,0.4375,0.29166666666666669,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungslasttrennschalter',5,'rechteck',0.25,0.41666666666666669,0.4375,0.58333333333333337,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',147.0))",

            // kfz_sicherungskasten <- kopie_von_sicherungskasten (proportional skaliert: Primitive + Pins)
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=20 WHERE id='kfz_sicherungskasten')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='kfz_sicherungskasten')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('kfz_sicherungskasten',0,'linie',0.0,0.4,0.15625,0.4,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',1,'rechteck',0.15625,0.075,0.84375,0.925,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',2,'linie',0.84375,0.2,1.0,0.2,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',3,'linie',0.84375,0.4,1.0,0.4,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',4,'linie',0.84375,0.6,1.0,0.6,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',5,'linie',0.84375,0.8,1.0,0.8,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',6,'rechteck',0.3125,0.15,0.6875,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',7,'rechteck',0.3125,0.35,0.6875,0.45,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',8,'rechteck',0.3125,0.55,0.6875,0.65,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('kfz_sicherungskasten',9,'rechteck',0.3125,0.75,0.6875,0.85,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='kfz_sicherungskasten')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES ('kfz_sicherungskasten','30',0.0,0.4,-1.0,0.0,'neutral',0), ('kfz_sicherungskasten','F1',1.0,0.2,1.0,0.0,'neutral',1), ('kfz_sicherungskasten','F2',1.0,0.4,1.0,0.0,'neutral',2), ('kfz_sicherungskasten','F3',1.0,0.6,1.0,0.0,'neutral',3), ('kfz_sicherungskasten','F4',1.0,0.8,1.0,0.0,'neutral',4))",

            // oeffner_voreilend <- kopie_von_kopie_von_nacheilender_oeffner (Zuordnung ueber Namen, s. Beschreibung oben; komplett neu gezeichnet im Stil der uebrigen Familie)
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='oeffner_voreilend')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner_voreilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('oeffner_voreilend',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',3,'linie',0.25,0.3125,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',4,'linie',0.125,0.3125,0.25,0.25,0.0,0.0,0.0,0.0,360.0,0,NULL,0.15,0,'center','middle','solid',0.0))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='oeffner_voreilend')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('oeffner_voreilend','1',0.5,0.0,0.0,-1.0,'neutral'), ('oeffner_voreilend','2',0.5,1.0,0.0,1.0,'neutral'))",

            // --- Werkstatt-Kopien nach Uebernahme entfernen ---
            R"(DELETE FROM symbol_definition WHERE id IN (
                'kopie_von_oeffner_nc', 'kopie_von_nacheilender_oeffner', 'kopie_von_schliesser_no',
                'kopie_von_nacheilender_schliesser', 'kopie_von_voreilender_schliesser',
                'kopie_von_sicherungslasttrennschalter', 'kopie_von_sicherungskasten',
                'kopie_von_kopie_von_nacheilender_oeffner'
            ))",

            // --- Vom Nutzer per Loeschmarkierung markierte built-in-Symbole entfernen (0 platzierte Instanzen) ---
            R"(DELETE FROM symbol WHERE code IN ('rollladenschalter', 'kfz_seitenstaenderschalter', 'kfz_bremslichtschalter'))",
            R"(DELETE FROM symbol_definition WHERE id IN ('rollladenschalter', 'kfz_seitenstaenderschalter', 'kfz_bremslichtschalter'))",
        }},
        { 122, "PIN-LABEL-SCHRIFTGROESSE-01: neue Spalte symbol_definition.pin_schrift_mm (REAL, Default 2.0) - symbolweite Schriftgroesse fuer Pin-Beschriftungen im Canvas/PDF-Export, im Symboleditor editierbar. Ersetzt die bisher fest codierte 2.0mm-Konstante in CanvasRenderHandler.qml/Database_PDF.cpp, damit eng bestueckte Symbole (Arduino, SPS-Baugruppen im 4mm-Pin-Raster) eine kleinere Schrift bekommen koennen als Symbole mit wenigen, weit auseinanderstehenden Pins.", {
            R"(ALTER TABLE symbol_definition ADD COLUMN pin_schrift_mm REAL NOT NULL DEFAULT 2.0)",
        }},
        { 123, "SYM-KOPIE-VON-01 siebter Sync-Durchlauf (Projekt Goerke): Gruppe A - 9 reine Massenkorrekturen (Pins unveraendert, nur Groesse+Primitive): caravan_ladebooster/caravan_solarladeregler/caravan_solarpanel/caravan_wechselrichter je 32x32mm->16x16mm, funktionserdung/masse_gehaeuse/taster_nc/taster_no je ->8x8mm, diode 8x16mm->8x12mm. Gruppe B - 10 neue Symbole 'Uebersichtsschaltplan'-Familie (Kategorie Installation, 8x8mm, 1 Pin, Vorlage schalter_allgemein_uebersicht): ausschalter_einpolig_uebersicht, ausschalter_zweipolig_uebersicht, zeitschalter_einpolig_uebersicht, schalter_kontrolleuchte_uebersicht, kreuzschalter_einpolig_uebersicht, wechselschalter_einpolig_uebersicht, serienschalter_einpolig_uebersicht, taster_mit_leuchte_uebersicht, taster_uebersicht, schalter_allgemein_uebersicht selbst. Kreuzschalter/Wechselschalter vom Nutzer nach Rueckfrage vertauscht (Werkstatt-ID 'kreuzschalter2_...' war der echte Kreuzschalter, 'kreuzschalter_...' der echte Wechselschalter - ID-Praefix liess sich im Editor nicht mehr aendern). Gruppe C - 4 neue Symbole 'Betaetigungsarten' (Kategorie Kontakte, 8x8mm, 2 Pins, Vorlage schliesser): beruehrungsempfindlicher_schalter, druckschalter_taster, handbetaetigter_schalter, naeherungsempfindlicher_schalter. Gruppe D - 1 vom Nutzer als fehlerhafte Dopplung identifizierte Werkstatt-Kopie geloescht (kopie_von_kopie_von_taster_no_beleuchtet, keine Uebernahme). Dabei nebenbei einen Dual-Bookkeeping-Bug aus Migration 121 gefunden und in seedSymbolKatalog() behoben: rollladenschalter/kfz_seitenstaenderschalter/kfz_bremslichtschalter waren dort aus der Legacy-symbol-Tabellen-Hardcodeliste nicht entfernt worden, obwohl Migration 121 sie bereits aus symbol_definition/symbole.sql geloescht hatte - haette bei jedem neuen Projekt Karteileichen in der Paletten-Kategorieliste hinterlassen (symbol-Eintrag ohne zugehoerige symbol_definition). Gleichzeitig die 14 neuen Symbole aus Gruppe B/C in seedSymbolKatalog() ergaenzt.", {
            // ══════ Gruppe A: reine Massenkorrekturen (Pins unveraendert) ══════
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='caravan_ladebooster')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='caravan_ladebooster')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('caravan_ladebooster',0,'linie',0.0,0.25,0.15,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_ladebooster',1,'linie',0.0,0.75,0.15,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_ladebooster',2,'linie',0.85,0.25,1.0,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_ladebooster',3,'linie',0.85,0.75,1.0,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_ladebooster',4,'rechteck',0.15,0.1,0.85,0.9,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_ladebooster',5,'text',0.5,0.42,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0,'B2B',0.16,1,'center','middle','solid',0.0), ('caravan_ladebooster',6,'text',0.5,0.63,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0,'DC/DC',0.1,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='caravan_solarladeregler')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='caravan_solarladeregler')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('caravan_solarladeregler',0,'linie',0.0,0.25,0.15,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarladeregler',1,'linie',0.0,0.75,0.15,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarladeregler',2,'linie',0.85,0.25,1.0,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarladeregler',3,'linie',0.85,0.75,1.0,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarladeregler',4,'rechteck',0.15,0.1,0.85,0.9,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarladeregler',5,'text',0.5,0.5,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0,'MPPT',0.15,1,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='caravan_solarpanel')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='caravan_solarpanel')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('caravan_solarpanel',0,'rechteck',0.1,0.15,0.9,0.85,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarpanel',1,'linie',0.37,0.15,0.37,0.85,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarpanel',2,'linie',0.63,0.15,0.63,0.85,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarpanel',3,'linie',0.1,0.5,0.9,0.5,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarpanel',4,'linie',0.3,0.85,0.3,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_solarpanel',5,'linie',0.7,0.85,0.7,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='caravan_wechselrichter')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='caravan_wechselrichter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('caravan_wechselrichter',0,'rechteck',0.15,0.15,0.85,0.85,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_wechselrichter',1,'linie',0.0,0.25,0.15,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_wechselrichter',2,'linie',0.0,0.75,0.15,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_wechselrichter',3,'linie',0.85,0.25,1.0,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_wechselrichter',4,'linie',0.85,0.75,1.0,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('caravan_wechselrichter',5,'text',0.5,0.5,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0,'INV',0.15,1,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='funktionserdung')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='funktionserdung')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('funktionserdung',0,'linie',0.5,0.0,0.5,0.65,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('funktionserdung',1,'bogen',0.5,1.0,0.0,0.0,0.0,0.0,0.5,180.0,360.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('funktionserdung',2,'linie',0.16,0.66,0.86,0.66,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('funktionserdung',3,'linie',0.28,0.81,0.74,0.81,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('funktionserdung',4,'linie',0.39,0.96,0.63,0.96,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='masse_gehaeuse')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='masse_gehaeuse')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('masse_gehaeuse',0,'linie',0.5,0.0,0.5,0.8125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('masse_gehaeuse',1,'linie',0.125,0.8125,0.875,0.8125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('masse_gehaeuse',2,'linie',0.125,0.8125,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('masse_gehaeuse',3,'linie',0.5,0.8125,0.375,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('masse_gehaeuse',4,'linie',0.875,0.8125,0.75,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='taster_nc')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='taster_nc')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('taster_nc',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_nc',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_nc',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_nc',3,'linie',0.25,0.3125,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_nc',4,'linie',0.3925,0.5,0.125,0.5,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_nc',5,'linie',0.125,0.375,0.125,0.625,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=8 WHERE id='taster_no')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='taster_no')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('taster_no',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_no',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_no',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_no',3,'linie',0.3925,0.5,0.125,0.5,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('taster_no',4,'linie',0.125,0.375,0.125,0.625,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=12 WHERE id='diode')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='diode')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('diode',0,'linie',0.5,0.0,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('diode',1,'linie',0.875,0.291666666666667,0.125,0.291666666666667,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('diode',2,'linie',0.5,0.291666666666667,0.125,0.708333333333333,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('diode',3,'linie',0.5,0.291666666666667,0.875,0.708333333333333,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('diode',4,'linie',0.875,0.708333333333333,0.125,0.708333333333333,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            // ══════ Kreuzschalter/Wechselschalter-Vertauschung: alte lokale
            // 'kreuzschalter_einpolig_uebersicht' (enthaelt in Wahrheit die
            // Wechselschalter-Geometrie) zuerst entfernen, damit die ID frei
            // fuer den echten Kreuzschalter (aus 'kreuzschalter2_...') wird ══════
            R"(DELETE FROM symbol_definition WHERE id='kreuzschalter_einpolig_uebersicht')",

            // ══════ Gruppe B: neue Symbole 'Uebersichtsschaltplan' (Installation, 8x8mm, 1 Pin) ══════
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('schalter_allgemein_uebersicht', 'Schalter allgemein Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('schalter_allgemein_uebersicht', 'Schalter allgemein Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schalter_allgemein_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('schalter_allgemein_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('schalter_allgemein_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('ausschalter_einpolig_uebersicht', 'Ausschalter einpolig Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('ausschalter_einpolig_uebersicht', 'Ausschalter einpolig Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ausschalter_einpolig_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('ausschalter_einpolig_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('ausschalter_einpolig_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('ausschalter_einpolig_uebersicht',2,'linie',0.8125,0.1875,0.875,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('ausschalter_zweipolig_uebersicht', 'Ausschalter zweipolig Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('ausschalter_zweipolig_uebersicht', 'Ausschalter zweipolig Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ausschalter_zweipolig_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('ausschalter_zweipolig_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('ausschalter_zweipolig_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('ausschalter_zweipolig_uebersicht',2,'linie',0.8125,0.1875,0.875,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('ausschalter_zweipolig_uebersicht',3,'linie',0.75,0.25,0.8125,0.3125,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('zeitschalter_einpolig_uebersicht', 'Zeitschalter einpolig Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('zeitschalter_einpolig_uebersicht', 'Zeitschalter einpolig Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('zeitschalter_einpolig_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('zeitschalter_einpolig_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('zeitschalter_einpolig_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('zeitschalter_einpolig_uebersicht',2,'linie',0.8125,0.1875,0.875,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('zeitschalter_einpolig_uebersicht',3,'linie',0.8125,0.375,0.8125,0.5625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('zeitschalter_einpolig_uebersicht',4,'linie',0.75,0.4375,0.8125,0.375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('zeitschalter_einpolig_uebersicht',5,'linie',0.875,0.4375,0.8125,0.375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('schalter_kontrolleuchte_uebersicht', 'Schalter mit Kontrolleuchte Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('schalter_kontrolleuchte_uebersicht', 'Schalter mit Kontrolleuchte Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('schalter_kontrolleuchte_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('schalter_kontrolleuchte_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('schalter_kontrolleuchte_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('schalter_kontrolleuchte_uebersicht',2,'linie',0.375,0.375,0.625,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('schalter_kontrolleuchte_uebersicht',3,'linie',0.625,0.375,0.375,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('kreuzschalter_einpolig_uebersicht', 'Kreuzschalter einpolig Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('kreuzschalter_einpolig_uebersicht', 'Kreuzschalter einpolig Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('kreuzschalter_einpolig_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('kreuzschalter_einpolig_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',2,'linie',0.8125,0.1875,0.875,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',3,'linie',0.375,0.625,0.1875,0.8125,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',4,'linie',0.1875,0.8125,0.125,0.75,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',5,'linie',0.1875,0.1875,0.375,0.375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',6,'linie',0.625,0.625,0.8125,0.8125,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',7,'linie',0.8125,0.8125,0.875,0.75,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('kreuzschalter_einpolig_uebersicht',8,'linie',0.1875,0.1875,0.125,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('wechselschalter_einpolig_uebersicht', 'Wechselschalter einpolig Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('wechselschalter_einpolig_uebersicht', 'Wechselschalter einpolig Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wechselschalter_einpolig_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('wechselschalter_einpolig_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('wechselschalter_einpolig_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('wechselschalter_einpolig_uebersicht',2,'linie',0.8125,0.1875,0.875,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('wechselschalter_einpolig_uebersicht',3,'linie',0.375,0.625,0.1875,0.8125,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('wechselschalter_einpolig_uebersicht',4,'linie',0.1875,0.8125,0.125,0.75,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('serienschalter_einpolig_uebersicht', 'Serienschalter einpolig Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('serienschalter_einpolig_uebersicht', 'Serienschalter einpolig Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('serienschalter_einpolig_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('serienschalter_einpolig_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('serienschalter_einpolig_uebersicht',1,'linie',0.625,0.375,0.8125,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('serienschalter_einpolig_uebersicht',2,'linie',0.8125,0.1875,0.875,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('serienschalter_einpolig_uebersicht',3,'linie',0.375,0.375,0.1875,0.1875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('serienschalter_einpolig_uebersicht',4,'linie',0.1875,0.1875,0.125,0.25,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('taster_mit_leuchte_uebersicht', 'Taster mit Leuchte Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('taster_mit_leuchte_uebersicht', 'Taster mit Leuchte Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_mit_leuchte_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('taster_mit_leuchte_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('taster_mit_leuchte_uebersicht',1,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.13975424859373686,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('taster_mit_leuchte_uebersicht',2,'linie',0.40625,0.40625,0.59375,0.59375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('taster_mit_leuchte_uebersicht',3,'linie',0.59375,0.40625,0.40625,0.59375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('taster_uebersicht', 'Taster Übersicht', 'installation', 'IEC', 1))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('taster_uebersicht', 'Taster Übersicht', 'Installation', 8, 8, 'durchleiter', 1, 'auto'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('taster_uebersicht', 'P1', 0.5, 0.3125, 0.0, -1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('taster_uebersicht',0,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.17125,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('taster_uebersicht',1,'kreis_offen',0.5,0.5,0.0,0.0,0.0,0.0,0.13975424859373686,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            // ══════ Gruppe C: neue Symbole 'Betaetigungsarten' (Kontakte, 8x8mm, 2 Pins) ══════
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('beruehrungsempfindlicher_schalter', 'Berührungsempfindlicher Schalter', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('beruehrungsempfindlicher_schalter', 'Berührungsempfindlicher Schalter', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('beruehrungsempfindlicher_schalter', '1', 1.0, 0.0, 0.0, -1.0, 'neutral'), ('beruehrungsempfindlicher_schalter', '2', 1.0, 1.0, 0.0, 1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('beruehrungsempfindlicher_schalter',0,'linie',1.0,0.0,1.0,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('beruehrungsempfindlicher_schalter',1,'linie',0.75,0.25,1.0,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('beruehrungsempfindlicher_schalter',2,'linie',1.0,0.6875,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('beruehrungsempfindlicher_schalter',3,'linie',0.875,0.5,0.625,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('beruehrungsempfindlicher_schalter',4,'linie',0.25,0.375,0.25,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('beruehrungsempfindlicher_schalter',5,'linie',0.5,0.375,0.5,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('beruehrungsempfindlicher_schalter',6,'rechteck',0.1875,0.3125,0.5625,0.6875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',45.0), ('beruehrungsempfindlicher_schalter',7,'linie',0.125,0.375,0.125,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('druckschalter_taster', 'Druckschalter, Taster', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('druckschalter_taster', 'Druckschalter, Taster', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('druckschalter_taster', '1', 0.5, 0.0, 0.0, -1.0, 'neutral'), ('druckschalter_taster', '2', 0.5, 1.0, 0.0, 1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('druckschalter_taster',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('druckschalter_taster',1,'linie',0.25,0.25,0.5,0.70833333333333304,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('druckschalter_taster',2,'linie',0.5,0.70833333333333304,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('druckschalter_taster',3,'linie',0.375,0.5,0.125,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('druckschalter_taster',4,'linie',0.125,0.375,0.125,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('druckschalter_taster',5,'linie',0.125,0.375,0.1875,0.375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('druckschalter_taster',6,'linie',0.125,0.625,0.1875,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('handbetaetigter_schalter', 'Handbetätigter Schalter', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('handbetaetigter_schalter', 'Handbetätigter Schalter', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('handbetaetigter_schalter', '1', 0.5, 0.0, 0.0, -1.0, 'neutral'), ('handbetaetigter_schalter', '2', 0.5, 1.0, 0.0, 1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('handbetaetigter_schalter',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('handbetaetigter_schalter',1,'linie',0.25,0.25,0.5,0.70833333333333304,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('handbetaetigter_schalter',2,'linie',0.5,0.70833333333333304,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('handbetaetigter_schalter',3,'linie',0.375,0.5,0.125,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('handbetaetigter_schalter',4,'linie',0.125,0.375,0.125,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('naeherungsempfindlicher_schalter', 'Näherungsempfindlicher Schalter', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('naeherungsempfindlicher_schalter', 'Näherungsempfindlicher Schalter', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('naeherungsempfindlicher_schalter', '1', 1.0, 0.0, 0.0, -1.0, 'neutral'), ('naeherungsempfindlicher_schalter', '2', 1.0, 1.0, 0.0, 1.0, 'neutral'))",
            R"(INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('naeherungsempfindlicher_schalter',0,'linie',1.0,0.0,1.0,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('naeherungsempfindlicher_schalter',1,'linie',0.75,0.25,1.0,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('naeherungsempfindlicher_schalter',2,'linie',1.0,0.6875,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('naeherungsempfindlicher_schalter',3,'linie',0.875,0.5,0.625,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('naeherungsempfindlicher_schalter',4,'linie',0.25,0.375,0.25,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('naeherungsempfindlicher_schalter',5,'linie',0.5,0.375,0.5,0.625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('naeherungsempfindlicher_schalter',6,'rechteck',0.1875,0.3125,0.5625,0.6875,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',45.0))",

            // ══════ Werkstatt-Kopien nach Uebernahme entfernen (Gruppe A + restliche Gruppe B-Quellen) ══════
            R"(DELETE FROM symbol_definition WHERE id IN (
                'kopie_von_dc_dc_ladebooster', 'kopie_von_solarladeregler_mppt', 'kopie_von_solarmodul_pv_panel',
                'kopie_von_wechselrichter_12v_230v', 'kopie_von_funktionserdung', 'kopie_von_masse_gehaeuse',
                'kopie_von_taster_nc', 'kopie_von_taster_no', 'kopie_von_diode',
                'kopie_von_ausschalter_einpolig_uebersicht', 'kopie_von_schalter_allgemein_uebersicht',
                'kreuzschalter2_einpolig_uebersicht'
            ))",

            // ══════ Gruppe D: fehlerhafte Dopplung (Nutzerbestaetigung: "wohl falsch und somit doppelt") ══════
            R"(DELETE FROM symbol_definition WHERE id='kopie_von_kopie_von_taster_no_beleuchtet')",
        }},
        { 124, "SYM-KOPIE-VON-01 siebter Sync-Durchlauf, Nachtrag (Projekt Goerke): 10 der 14 in Migration 123 neu eingefuehrten Symbole hatten in Goerke selbst bereits eine gleichnamige lokale ist_builtin=0-Zeile (der Nutzer hatte sie dort ohne Werkstatt-Praefix direkt unter der finalen ID angelegt) - INSERT OR IGNORE griff deshalb nicht und liess sie dort faelschlich unter 'Eigene Symbole' stehen, obwohl sie jetzt echte Built-ins sind. Betroffen: schalter_allgemein_uebersicht, ausschalter_einpolig_uebersicht, ausschalter_zweipolig_uebersicht, serienschalter_einpolig_uebersicht, taster_mit_leuchte_uebersicht, taster_uebersicht, beruehrungsempfindlicher_schalter, druckschalter_taster, handbetaetigter_schalter, naeherungsempfindlicher_schalter. Direkt auf ist_builtin=1 gesetzt und die (jetzt ueberholte) kopie_von_id-Werkstattmarkierung geloescht - Geometrie/Groesse bereits korrekt, keine weitere Aenderung noetig.", {
            R"(UPDATE symbol_definition SET ist_builtin=1, kopie_von_id=NULL WHERE id IN (
                'schalter_allgemein_uebersicht', 'ausschalter_einpolig_uebersicht', 'ausschalter_zweipolig_uebersicht',
                'serienschalter_einpolig_uebersicht', 'taster_mit_leuchte_uebersicht', 'taster_uebersicht',
                'beruehrungsempfindlicher_schalter', 'druckschalter_taster', 'handbetaetigter_schalter',
                'naeherungsempfindlicher_schalter'
            ))",
        }},
        { 125, "SYMBOL-DUALITAET-01-TEST-01: neuer Konsistenztest (tst_migrationen.cpp) deckte auf, dass 'brueckengleichrichter' (seit Migration 75/B9) nie einen Eintrag in der Legacy-symbol-Tabelle bekam - Symbol war seither in der Palette fuer JEDES Projekt unsichtbar, obwohl Rendering/Pins/Primitive korrekt waren. seedSymbolKatalog() fuer neue Projekte direkt ergaenzt, hier zusaetzlich fuer Bestandsprojekte nachgetragen.", {
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('brueckengleichrichter', 'Brückengleichrichter', 'passive', 'IEC,ANSI', 4))",
        }},
        { 126, "SYMBOLPALETTE-VERBESSERUNG-01: neue Spalte projekt.zuletzt_verwendete_symbole (TEXT, kommagetrennte Symbol-Codes, Default leer) - macht die 'Zuletzt verwendet'-Liste der Symbolpalette projektgebunden persistent statt nur sitzungsbasiert (bisher ging sie bei jedem App-Neustart verloren).", {
            R"(ALTER TABLE projekt ADD COLUMN zuletzt_verwendete_symbole TEXT NOT NULL DEFAULT '')",
        }},
        { 127, "SYM-KOPIE-VON-01 achter Sync-Durchlauf (Projekt Goerke): Gruppe A - 4 reine Massenkorrekturen (Pins/Primitive unveraendert): zaehler 24x24mm->16x16mm, wp_regler 32x32mm->16x16mm, wp_sgready 32x24mm->12x8mm, wp_umwaelzpumpe 32x16mm->16x8mm. Gruppe A2 - 2 Groessenkorrekturen mit proportional neupositionierten Primitiven/Pins (Aspektverhaeltnis-Aenderung): wp_mischer 32x32mm->16x16mm, ueberspannungsschutz 28x32mm->16x20mm. Gruppe B - 4 Geometrie-Redesigns bei gleicher 8x8mm-Groesse, Diagonale/Unterbrechungs-/Voreil-Markierung einheitlich von links auf rechts gespiegelt (schliesser zusaetzlich nur Diagonalen-Endpunkt normalisiert): schliesser, oeffner, oeffner_nacheilend, oeffner_voreilend. Gruppe C - sicherungsschalter 24x36mm->8x12mm komplett neu gezeichnet (Zickzack-Linien ersetzt durch rotiertes Rechteck, analog sicherungslasttrennschalter aus Migration 121). Gruppe D - 4 neue Symbole 'Verzoegerte Kontakte' (Kategorie Kontakte, 8x8mm, 2 Pins, Vorlage oeffner/schliesser): anzugsverzoegerter_oeffner_nc, abfallverzoegerter_oeffner_nc, anzugsverzoegerter_schliesser_no, abfallverzoegerter_schliesser_no - konsequente Umsetzung der in Punkt 3 von 04_symbolsystem.md dokumentierten Jul-2026-Entscheidung, zeit_an/zeit_ab als eigenstaendige IEC-Symbole statt als entfernte Checkbox-Modifier zu fuehren. Beim Sync einen Tippfehler in ID+Name einer der vier Werkstatt-Neuanlagen korrigiert (abffallverzoegerter_oeffner_nc -> abfallverzoegerter_oeffner_nc, 'Abffallverzoegerter' -> 'Abfallverzoegerter'). SEED-DUPLIKAT-01 (unabhaengiger Bugfix, waehrend dieser Sitzung entdeckt): Migration 123 hatte fuer die 14 damals neuen Symbole INSERT OR IGNORE auf symbol_pin/symbol_primitiv genutzt - beide Tabellen haben nur eine autoincrement id als PK, wodurch bei den 10 Symbolen, die in Goerke schon lokal existierten, Pins/Primitive dupliziert wurden (Rendering unauffaellig, da deckungsgleich; SQL-Export/Hit-Test/Stueckliste betroffen). Generischer Dedup-Fix (behaelt pro Symbol nur die erste Zeile je reihenfolge/name) direkt mitgezogen.", {
            // ══════ Gruppe A: reine Massenkorrekturen (Pins/Primitive unveraendert) ══════
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='zaehler')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='wp_regler')",
            R"(UPDATE symbol_definition SET breite_mm=12, hoehe_mm=8 WHERE id='wp_sgready')",
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=8 WHERE id='wp_umwaelzpumpe')",

            // ══════ Gruppe A2: Groesse + proportional neupositionierte Primitive/Pins ══════
            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=16 WHERE id='wp_mischer')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='wp_mischer')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('wp_mischer',0,'linie',0.0,0.25,0.25,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',1,'linie',0.0,0.5,0.25,0.5,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',2,'linie',0.0,0.75,0.25,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',3,'kreis_offen',0.5,0.35,0.0,0.0,0.0,0.0,0.2,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',4,'text',0.5,0.35,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0,'M',0.28,1,'center','middle','solid',0.0), ('wp_mischer',5,'linie',0.5,0.55,0.5,0.68,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',6,'linie',0.32,0.68,0.68,0.68,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',7,'linie',0.32,0.68,0.5,0.95,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('wp_mischer',8,'linie',0.68,0.68,0.5,0.95,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='wp_mischer')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('wp_mischer','1',0.0,0.25,-1.0,0.0,'neutral'), ('wp_mischer','AUF',0.0,0.5,-1.0,0.0,'neutral'), ('wp_mischer','ZU',0.0,0.75,-1.0,0.0,'neutral'))",

            R"(UPDATE symbol_definition SET breite_mm=16, hoehe_mm=20 WHERE id='ueberspannungsschutz')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='ueberspannungsschutz')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('ueberspannungsschutz',0,'linie',0.5,0.0,0.5,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('ueberspannungsschutz',1,'linie',0.5,0.75,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('ueberspannungsschutz',2,'rechteck',0.625,0.25,0.375,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('ueberspannungsschutz',3,'linie',0.375,0.5,0.0,0.5,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('ueberspannungsschutz',4,'linie',0.4375,0.3,0.5625,0.65,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('ueberspannungsschutz',5,'linie',0.0,0.5,0.0625,0.45,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('ueberspannungsschutz',6,'linie',0.0,0.5,0.0625,0.55,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='ueberspannungsschutz')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('ueberspannungsschutz','1',0.5,0.0,0.0,-1.0,'power'), ('ueberspannungsschutz','2',0.5,1.0,0.0,1.0,'power'), ('ueberspannungsschutz','PE',0.0,0.5,-1.0,0.0,'pe'))",

            // ══════ Gruppe B: Geometrie-Redesign, Groesse bleibt 8x8mm ══════
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='schliesser')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('schliesser',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('schliesser',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('oeffner',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner',1,'linie',0.75,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner',3,'linie',0.5,0.3125,0.75,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0))",

            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner_nacheilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('oeffner_nacheilend',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',1,'linie',0.75,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',3,'linie',0.5,0.3125,0.75,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_nacheilend',4,'linie',0.75,0.25,0.625,0.1875,0.0,0.0,0.0,0.0,360.0,0,NULL,0.15,0,'center','middle','solid',0.0))",

            R"(DELETE FROM symbol_primitiv WHERE symbol_id='oeffner_voreilend')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('oeffner_voreilend',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',1,'linie',0.75,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',3,'linie',0.5,0.3125,0.75,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('oeffner_voreilend',4,'linie',0.875,0.3125,0.75,0.25,0.0,0.0,0.0,0.0,360.0,0,NULL,0.15,0,'center','middle','solid',0.0))",

            // ══════ Gruppe C: Komplett-Redesign inkl. Groesse ══════
            R"(UPDATE symbol_definition SET breite_mm=8, hoehe_mm=12 WHERE id='sicherungsschalter')",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='sicherungsschalter')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('sicherungsschalter',0,'linie',0.5,0.0,0.5,0.33333333333333332,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungsschalter',1,'linie',0.25,0.33333333333333332,0.5,0.66666666666666663,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungsschalter',2,'linie',0.5,0.66666666666666663,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('sicherungsschalter',3,'rechteck',0.25,0.375,0.4375,0.58333333333333337,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',154.0))",

            // ══════ Gruppe D: 4 neue Symbole 'Verzoegerte Kontakte' (Kontakte, 8x8mm, 2 Pins) ══════
            // anzugsverzoegerter_oeffner_nc/anzugsverzoegerter_schliesser_no/abfallverzoegerter_schliesser_no lagen in Goerke
            // bereits lokal unter der finalen ID (ist_builtin=0, kein kopie_von_id) - INSERT OR IGNORE (PK-sicher) fuer
            // symbol_definition, aber DELETE+INSERT statt INSERT OR IGNORE fuer symbol_pin/symbol_primitiv: diese Tabellen
            // haben nur eine autoincrement id als PK, "OR IGNORE" findet dort nie einen Konflikt und wuerde Zeilen
            // duplizieren (exakt der SEED-DUPLIKAT-01-Bug weiter unten in diesem Migrationseintrag).
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('anzugsverzoegerter_oeffner_nc', 'Anzugsverzögerter Öffner (NC)', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='anzugsverzoegerter_oeffner_nc')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('anzugsverzoegerter_oeffner_nc','1',0.5,0.0,0.0,-1.0,'neutral'), ('anzugsverzoegerter_oeffner_nc','2',0.5,1.0,0.0,1.0,'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='anzugsverzoegerter_oeffner_nc')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('anzugsverzoegerter_oeffner_nc',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_oeffner_nc',1,'linie',0.75,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_oeffner_nc',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_oeffner_nc',3,'linie',0.5,0.3125,0.75,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_oeffner_nc',4,'linie',0.1875,0.5625,0.56875,0.5625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugsverzoegerter_oeffner_nc',5,'bogen',0.1875,0.5,0.0,0.0,0.0,0.0,0.125,90.0,270.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugsverzoegerter_oeffner_nc',6,'linie',0.1875,0.4375,0.64125,0.4375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('anzugsverzoegerter_schliesser_no', 'Anzugsverzögerter Schließer (NO)', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='anzugsverzoegerter_schliesser_no')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('anzugsverzoegerter_schliesser_no','1',0.5,0.0,0.0,-1.0,'neutral'), ('anzugsverzoegerter_schliesser_no','2',0.5,1.0,0.0,1.0,'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='anzugsverzoegerter_schliesser_no')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('anzugsverzoegerter_schliesser_no',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_schliesser_no',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_schliesser_no',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugsverzoegerter_schliesser_no',3,'linie',0.3125,0.375,0.1875,0.375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugsverzoegerter_schliesser_no',4,'linie',0.375,0.5,0.1875,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugsverzoegerter_schliesser_no',5,'bogen',0.1875,0.4375,0.0,0.0,0.0,0.0,0.125,90.0,270.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('abfallverzoegerter_schliesser_no', 'Abfallverzögerter Schließer (NO)', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='abfallverzoegerter_schliesser_no')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('abfallverzoegerter_schliesser_no','1',0.5,0.0,0.0,-1.0,'neutral'), ('abfallverzoegerter_schliesser_no','2',0.5,1.0,0.0,1.0,'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='abfallverzoegerter_schliesser_no')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('abfallverzoegerter_schliesser_no',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_schliesser_no',1,'linie',0.25,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_schliesser_no',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_schliesser_no',3,'linie',0.3125,0.375,0.1875,0.375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('abfallverzoegerter_schliesser_no',4,'linie',0.375,0.5,0.1875,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('abfallverzoegerter_schliesser_no',5,'bogen',0.0625,0.4375,0.0,0.0,0.0,0.0,0.125,270.0,90.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET ist_builtin=1, kopie_von_id=NULL WHERE id IN ('anzugsverzoegerter_oeffner_nc', 'anzugsverzoegerter_schliesser_no', 'abfallverzoegerter_schliesser_no') AND ist_builtin=0)",

            // ── Tippfehler-Korrektur: 'abffallverzoegerter_oeffner_nc' (Werkstatt-ID+Name mit doppeltem f)
            // -> 'abfallverzoegerter_oeffner_nc'. Alte Zeile zuerst entfernen (cascadiert Pins/Primitive in
            // Goerke selbst), dann sauber unter der korrekten ID neu anlegen (kein Duplikat-Risiko, da die
            // ID zuvor per DELETE frei gemacht wurde).
            R"(DELETE FROM symbol_definition WHERE id='abffallverzoegerter_oeffner_nc')",
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('abfallverzoegerter_oeffner_nc', 'Abfallverzögerter Öffner (NC)', 'Kontakte', 8, 8, 'durchleiter', 1, 'vertikal'))",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('abfallverzoegerter_oeffner_nc','1',0.5,0.0,0.0,-1.0,'neutral'), ('abfallverzoegerter_oeffner_nc','2',0.5,1.0,0.0,1.0,'neutral'))",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('abfallverzoegerter_oeffner_nc',0,'linie',0.5,0.0,0.5,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_oeffner_nc',1,'linie',0.75,0.25,0.5,0.6875,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_oeffner_nc',2,'linie',0.5,0.6875,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_oeffner_nc',3,'linie',0.5,0.3125,0.75,0.3125,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('abfallverzoegerter_oeffner_nc',4,'linie',0.1875,0.5625,0.56875,0.5625,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('abfallverzoegerter_oeffner_nc',5,'linie',0.1875,0.4375,0.64125,0.4375,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('abfallverzoegerter_oeffner_nc',6,'bogen',0.0625,0.5,0.0,0.0,0.0,0.0,0.125,270.0,90.0,0,'',0.15,0,'center','middle','solid',0.0))",

            // ── Legacy-symbol-Tabelle (Paletten-Kategorieliste) ──
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('anzugsverzoegerter_oeffner_nc', 'Anzugsverzögerter Öffner (NC)', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('abfallverzoegerter_oeffner_nc', 'Abfallverzögerter Öffner (NC)', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('anzugsverzoegerter_schliesser_no', 'Anzugsverzögerter Schließer (NO)', 'kontakte', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('abfallverzoegerter_schliesser_no', 'Abfallverzögerter Schließer (NO)', 'kontakte', 'IEC', 2))",

            // ══════ SEED-DUPLIKAT-01 (echter, unabhaengiger Bugfix, waehrend dieser Sync-Sitzung entdeckt):
            // Migration 123 nutzte fuer die 14 damals neuen 'Uebersichtsschaltplan'/'Betaetigungsarten'-Symbole
            // INSERT OR IGNORE auf symbol_pin/symbol_primitiv. Diese beiden Tabellen haben nur eine autoincrement
            // id als Primary Key - "OR IGNORE" findet dort nie einen Konflikt (anders als bei symbol_definition,
            // dessen PK die Text-ID ist) und fuegt bei Datenbanken, die eine der Ziel-IDs bereits lokal besassen
            // (in Goerke betraf das 10 der 14 Symbole, s. Migration 124), Pins/Primitive ein zweites Mal ein.
            // Rendering blieb dadurch unauffaellig (beide Kopien liegen exakt uebereinander), aber SQL-Export,
            // Editor-Hit-Test und Stueckliste sahen doppelte Geometrie. Generischer Fix: pro (symbol_id,
            // reihenfolge) bzw. (symbol_id, name) nur die jeweils erste (niedrigste id) Zeile behalten - deckt
            // Goerke ab und jede andere Datenbank mit demselben historischen Migrationspfad. ══════
            R"(DELETE FROM symbol_primitiv WHERE id NOT IN (
                SELECT MIN(id) FROM symbol_primitiv GROUP BY symbol_id, reihenfolge
            ))",
            R"(DELETE FROM symbol_pin WHERE id NOT IN (
                SELECT MIN(id) FROM symbol_pin GROUP BY symbol_id, name
            ))",

            // ── Werkstatt-Kopien nach Uebernahme entfernen ──
            R"(DELETE FROM symbol_definition WHERE id IN (
                'kopie_von_stromzaehler_kwh', 'kopie_von_waermepumpen_regler', 'kopie_von_mischer_stellantrieb',
                'kopie_von_sg_ready_schnittstelle', 'kopie_von_umwaelzpumpe', 'kopie_von_ueberspannungsschutz_spd',
                'kopie_von_sicherungsschalter', 'kopie_von_schliesser_no', 'kopie_von_oeffner_nc',
                'kopie_von_nacheilender_oeffner', 'kopie_von_voreilender_oeffner'
            ))",
        }},
        { 128, "SYM-KOPIE-VON-01 neunter Sync-Durchlauf (Projekt Goerke): Gruppe A - 3 neue Symbole 'Verzoegerte Spulen/Relais' (Kategorie Antriebe, Vorlage spule): rueckfallverzoegerte_spule_relais (12x12mm, gefuellter Kurzschlussring), anzugverzoegerte_spule_relais (12x12mm, offener Ring mit Diagonalkreuz), thermo_spule_relais (8x12mm, Stufen-Symbol fuer Thermoelement). Gruppe B - 1 neues Symbol 'heizelement' (Kategorie Passive, 8x12mm, Vorlage widerstand_iec, Widerstandsrechteck + Zickzack-Heizwendel-Andeutung). Gruppe C - 'kopie_von_anlasser_starter' war byte-identisch mit kfz_anlasser (folgenlose Werkstattkopie, per Nutzerbestaetigung nur geloescht, keine Uebernahme noetig). Gruppe D - kfz_zuendschloss vom Nutzer zur Loeschung markiert, 0 platzierte Instanzen, entfernt (built-in-Definition stammt aus einer frueheren Migration und bleibt dort unveraendert stehen, wird hier per neuer Migration wieder ausgetragen - keine Aenderung an alten Migrationen).", {
            // ══════ Gruppe A: 3 neue Symbole 'Verzoegerte Spulen/Relais' (Antriebe, Vorlage spule) ══════
            // Alle drei lagen in Goerke bereits lokal unter der finalen ID (ist_builtin=0, kopie_von_id=spule) -
            // INSERT OR IGNORE fuer symbol_definition (Text-PK, sicher), aber DELETE+INSERT statt INSERT OR IGNORE
            // fuer symbol_pin/symbol_primitiv (Lehre aus SEED-DUPLIKAT-01, s. Migration 127).
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('rueckfallverzoegerte_spule_relais', 'Rückfallverzögerte Spule / Relais', 'Antriebe', 12, 12, 'verbraucher', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='rueckfallverzoegerte_spule_relais')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('rueckfallverzoegerte_spule_relais','A1',0.66666666666666663,0.0,0.0,-1.0,'power'), ('rueckfallverzoegerte_spule_relais','A2',0.66666666666666663,1.0,0.0,1.0,'n'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='rueckfallverzoegerte_spule_relais')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('rueckfallverzoegerte_spule_relais',0,'linie',0.66666666666666663,0.0,0.66666666666666663,0.33333333333333332,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('rueckfallverzoegerte_spule_relais',1,'linie',0.66666666666666663,0.66666666666666663,0.66666666666666663,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('rueckfallverzoegerte_spule_relais',2,'rechteck',0.33333333333333332,0.33333333333333332,1.0,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('rueckfallverzoegerte_spule_relais',3,'rechteck_gefuellt',0.16666666666666666,0.33333333333333332,0.33333333333333332,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('anzugverzoegerte_spule_relais', 'Anzugverzögerte Spule / Relais', 'Antriebe', 12, 12, 'verbraucher', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='anzugverzoegerte_spule_relais')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('anzugverzoegerte_spule_relais','A1',0.66666666666666663,0.0,0.0,-1.0,'power'), ('anzugverzoegerte_spule_relais','A2',0.66666666666666663,1.0,0.0,1.0,'n'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='anzugverzoegerte_spule_relais')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('anzugverzoegerte_spule_relais',0,'linie',0.66666666666666663,0.0,0.66666666666666663,0.33333333333333332,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugverzoegerte_spule_relais',1,'linie',0.66666666666666663,0.66666666666666663,0.66666666666666663,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('anzugverzoegerte_spule_relais',2,'rechteck',0.33333333333333332,0.33333333333333332,1.0,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugverzoegerte_spule_relais',3,'rechteck',0.16666666666666666,0.33333333333333332,0.33333333333333332,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugverzoegerte_spule_relais',4,'linie',0.16666666666666666,0.33333333333333332,0.33333333333333332,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('anzugverzoegerte_spule_relais',5,'linie',0.33333333333333332,0.33333333333333332,0.16666666666666666,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('thermo_spule_relais', 'Thermo Spule / Relais', 'Antriebe', 8, 12, 'verbraucher', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='thermo_spule_relais')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('thermo_spule_relais','A1',0.5,0.0,0.0,-1.0,'power'), ('thermo_spule_relais','A2',0.5,1.0,0.0,1.0,'n'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='thermo_spule_relais')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('thermo_spule_relais',0,'linie',0.5,0.0,0.5,0.33333333333333332,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('thermo_spule_relais',1,'linie',0.5,0.66666666666666663,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('thermo_spule_relais',2,'rechteck',0.0,0.33333333333333332,1.0,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('thermo_spule_relais',3,'linie',0.5,0.33333333333333332,0.5,0.41666666666666669,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('thermo_spule_relais',4,'linie',0.5,0.41666666666666669,0.75,0.41666666666666669,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('thermo_spule_relais',5,'linie',0.75,0.41666666666666669,0.75,0.58333333333333337,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('thermo_spule_relais',6,'linie',0.75,0.58333333333333337,0.5,0.58333333333333337,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('thermo_spule_relais',7,'linie',0.5,0.58333333333333337,0.5,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",

            R"(UPDATE symbol_definition SET ist_builtin=1, kopie_von_id=NULL WHERE id IN ('rueckfallverzoegerte_spule_relais', 'anzugverzoegerte_spule_relais', 'thermo_spule_relais') AND ist_builtin=0)",

            // ══════ Gruppe B: neues Symbol 'heizelement' (Passive, Vorlage widerstand_iec) ══════
            R"(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite) VALUES ('heizelement', 'Heizelement', 'Passive', 8, 12, 'verbraucher', 1, 'vertikal'))",
            R"(DELETE FROM symbol_pin WHERE symbol_id='heizelement')",
            R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ('heizelement','1',0.5,0.0,0.0,-1.0,'neutral'), ('heizelement','2',0.5,1.0,0.0,1.0,'neutral'))",
            R"(DELETE FROM symbol_primitiv WHERE symbol_id='heizelement')",
            R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ('heizelement',0,'rechteck',0.3125,0.25,0.6875,0.75,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('heizelement',1,'linie',0.5,0.0,0.5,0.25,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('heizelement',2,'linie',0.5,0.75,0.5,1.0,0.0,0.0,0.0,0.0,0.0,0,NULL,0.5,0,'center','middle','solid',0.0), ('heizelement',3,'linie',0.3125,0.33333333333333332,0.6875,0.33333333333333332,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('heizelement',4,'linie',0.6875,0.41666666666666669,0.3125,0.41666666666666669,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('heizelement',5,'linie',0.3125,0.5,0.6875,0.5,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('heizelement',6,'linie',0.6875,0.58333333333333337,0.3125,0.58333333333333337,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0), ('heizelement',7,'linie',0.6875,0.66666666666666663,0.3125,0.66666666666666663,0.0,0.0,0.0,0.0,360.0,0,'',0.15,0,'center','middle','solid',0.0))",
            R"(UPDATE symbol_definition SET ist_builtin=1, kopie_von_id=NULL WHERE id='heizelement' AND ist_builtin=0)",

            // ── Legacy-symbol-Tabelle (Paletten-Kategorieliste) ──
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('rueckfallverzoegerte_spule_relais', 'Rückfallverzögerte Spule / Relais', 'antriebe', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('anzugverzoegerte_spule_relais', 'Anzugverzögerte Spule / Relais', 'antriebe', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('thermo_spule_relais', 'Thermo Spule / Relais', 'antriebe', 'IEC', 2))",
            R"(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES ('heizelement', 'Heizelement', 'passive', 'IEC', 2))",

            // ══════ Gruppe C: folgenlose Werkstattkopie entfernen (byte-identisch mit kfz_anlasser) ══════
            R"(DELETE FROM symbol_definition WHERE id='kopie_von_anlasser_starter')",

            // ══════ Gruppe D: kfz_zuendschloss auf Nutzerwunsch entfernen (0 platzierte Instanzen) ══════
            R"(DELETE FROM symbol WHERE code='kfz_zuendschloss')",
            R"(DELETE FROM symbol_definition WHERE id='kfz_zuendschloss')",
        }},
        { 129, "SPS-KANAL-BETRIEBSMITTEL-01: sps_baugruppe.betriebsmittel_id fuer Verknuepfung mit platzierter Kartenintanz (Hardware-Tab weiss dadurch, welche Karte wo/mit welcher BMK platziert ist).", {
            R"(ALTER TABLE sps_baugruppe ADD COLUMN betriebsmittel_id INTEGER REFERENCES betriebsmittel(id))",
        }},
    };
    std::sort(migrationen.begin(), migrationen.end(),
              [](const SchemaMigration &a, const SchemaMigration &b) { return a.version < b.version; });
    return migrationen;
}


// ============================================================
// checkAndApplySchema
// Inkrementelles Migrations-System: liest den höchsten
// angewendeten Versions-Eintrag aus schema_migration und
// führt alle ausstehenden Migrationen in Reihenfolge aus.
//
// Übergangslogik: existiert die alte schema_version-Tabelle
// mit v=40, wird v40 als bereits angewendet übernommen ohne
// Rebuild.
// ============================================================
bool Database::checkAndApplySchema()
{
    // schema_migration-Tabelle sicherstellen (außerhalb jeder Transaktion)
    {
        QSqlQuery q(m_db);
        if (!q.exec(
            "CREATE TABLE IF NOT EXISTS schema_migration ("
            "    version       INTEGER PRIMARY KEY,"
            "    beschreibung  TEXT    NOT NULL,"
            "    angewendet_am TEXT    NOT NULL DEFAULT (datetime('now'))"
            ")")) {
            qCWarning(lcDb) << "schema_migration anlegen:" << q.lastError().text();
            return false;
        }
    }

    // Aktuelle Version ermitteln
    int currentVersion = 0;
    {
        QSqlQuery q(m_db);
        bool leer = true;
        if (q.exec("SELECT COUNT(*) FROM schema_migration") && q.next())
            leer = (q.value(0).toInt() == 0);

        if (leer) {
            // Übergang: alte schema_version-Tabelle prüfen
            QSqlQuery sv;
            if (sv.exec("SELECT version FROM schema_version LIMIT 1") && sv.next()
                    && sv.value(0).toInt() == BASELINE_VERSION) {
                QSqlQuery ins;
                ins.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :b)");
                ins.bindValue(":v", BASELINE_VERSION);
                ins.bindValue(":b", QString("Baseline v%1 – übernommen aus schema_version").arg(BASELINE_VERSION));
                ins.exec();
                currentVersion = BASELINE_VERSION;
                qCInfo(lcDb) << "schema_migration: Übergang schema_version → v" << BASELINE_VERSION;
            }
        } else {
            if (q.exec("SELECT COALESCE(MAX(version), 0) FROM schema_migration") && q.next())
                currentVersion = q.value(0).toInt();
        }
    }

    // Downgrade-Schutz: Die Datei wurde mit einer neueren Strömling-Version gespeichert
    // als diese Binary kennt. Migrationen sind rein additiv (ADD COLUMN, CREATE TABLE) -
    // stillschweigendes Weiterarbeiten mit einem unbekannten Schema kann zu inkonsistenten
    // Daten fuehren, deshalb hier hart abbrechen statt weiterzumachen.
    {
        int hoechsteBekannteVersion = BASELINE_VERSION;
        for (const SchemaMigration &mig : alleMigrationen())
            if (mig.version > hoechsteBekannteVersion)
                hoechsteBekannteVersion = mig.version;

        if (currentVersion > hoechsteBekannteVersion) {
            qCWarning(lcDb) << "Datenbank-Version" << currentVersion
                             << "ist neuer als die bekannte Version" << hoechsteBekannteVersion;
            emit dbFehler(QString(
                "Diese Datei wurde mit einer neueren Strömling-Version gespeichert "
                "(Schema v%1, diese Programmversion kennt bis v%2). Bitte Strömling "
                "aktualisieren, bevor diese Datei geöffnet wird.")
                .arg(currentVersion).arg(hoechsteBekannteVersion));
            return false;
        }
    }

    // Backup erstellen wenn Migrationen ausstehen
    {
        const auto &migrationen = alleMigrationen();
        bool hatAusstehende = std::any_of(migrationen.begin(), migrationen.end(),
            [currentVersion](const SchemaMigration &m){ return m.version > currentVersion; });
        if (hatAusstehende)
            erstelleBackup("", "stroemling", currentVersion);
    }

    // Ausstehende Migrationen anwenden
    for (const SchemaMigration &mig : alleMigrationen()) {
        if (mig.version <= currentVersion) continue;

        qCInfo(lcDb) << "Wende Migration" << mig.version << "an:" << mig.beschreibung;

        // Migrationen die Tabellen mit FK-abhängigen Children rebuilden müssen:
        // PRAGMA foreign_keys darf nur außerhalb einer Transaktion geändert werden.
        const bool brauchtFkAus = (mig.version == 80);
        if (brauchtFkAus) {
            QSqlQuery q(m_db);
            q.exec("PRAGMA foreign_keys = OFF");
        }

        if (!m_db.transaction()) {
            if (brauchtFkAus) { QSqlQuery q(m_db); q.exec("PRAGMA foreign_keys = ON"); }
            qCWarning(lcDb) << "Transaktion fehlgeschlagen:" << m_db.lastError().text();
            return false;
        }

        bool ok = false;
        if (mig.version == BASELINE_VERSION) {
            // Baseline: vollständiger Neuaufbau (Bauteil-Seeds jetzt in checkAndApplyBibliothekSchema)
            ok = dropAllTables() && createSchema()
                 && seedSymbolKatalog() && seedBuiltinSymbolDefinitionen()
                 && seedIbnFeldvorlagen();
        } else if (mig.version == 77) {
            // D-02: braucht Datei-I/O (Bild-Bytes auslagern) – nicht über reines SQL möglich.
            ok = migriereGrafikBilderAufDateien();
        } else {
            ok = applyMigrationStatements(mig.statements);
        }

        if (!ok) {
            m_db.rollback();
            if (brauchtFkAus) { QSqlQuery q(m_db); q.exec("PRAGMA foreign_keys = ON"); }
            emit dbFehler(QString("Migration v%1 fehlgeschlagen. Die Datenbank wurde nicht verändert "
                                  "(Backup vorhanden).").arg(mig.version));
            return false;
        }

        QSqlQuery ins;
        ins.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :b)");
        ins.bindValue(":v", mig.version);
        ins.bindValue(":b", mig.beschreibung);
        if (!ins.exec()) {
            qCWarning(lcDb) << "schema_migration schreiben:" << ins.lastError().text();
            m_db.rollback();
            if (brauchtFkAus) { QSqlQuery q(m_db); q.exec("PRAGMA foreign_keys = ON"); }
            return false;
        }

        if (!m_db.commit()) {
            qCWarning(lcDb) << "Commit fehlgeschlagen:" << m_db.lastError().text();
            m_db.rollback();
            if (brauchtFkAus) { QSqlQuery q(m_db); q.exec("PRAGMA foreign_keys = ON"); }
            return false;
        }

        if (brauchtFkAus) {
            QSqlQuery q(m_db);
            q.exec("PRAGMA foreign_keys = ON");
        }

        qCInfo(lcDb) << "Migration" << mig.version << "erfolgreich angewendet.";
        currentVersion = mig.version;
    }

    qCInfo(lcDb) << "Hauptdatenbank auf Schema-Version" << currentVersion;
    return true;
}

bool Database::applyMigrationStatements(const QStringList &statements)
{
    QSqlQuery q(m_db);
    for (const QString &stmt : statements) {
        if (stmt.trimmed().isEmpty()) continue;
        if (!q.exec(stmt)) {
            // ALTER TABLE ADD COLUMN wird von SQLite auto-committed und kann
            // nicht zurückgerollt werden. Wenn die Spalte bereits existiert
            // (Absturz nach DDL aber vor schema_migration-Commit), gilt die
            // Migration als erfolgreich angewendet.
            bool isAddColumn = stmt.trimmed().toUpper().contains("ADD COLUMN");
            bool isDupCol    = q.lastError().databaseText().toLower()
                                .contains("duplicate column name");
            if (isAddColumn && isDupCol) {
                qCInfo(lcDb) << "ADD COLUMN bereits vorhanden (idempotent):" << stmt.left(120);
                continue;
            }

            // DROP COLUMN ist idempotent: bei einer frisch aus schema.sql
            // erzeugten DB fehlt die Spalte ggf. schon von Anfang an.
            bool isDropColumn = stmt.trimmed().toUpper().contains("DROP COLUMN");
            bool isNoSuchCol  = q.lastError().databaseText().toLower()
                                .contains("no such column");
            if (isDropColumn && isNoSuchCol) {
                qCInfo(lcDb) << "DROP COLUMN bereits entfernt (idempotent):" << stmt.left(120);
                continue;
            }
            qCWarning(lcDb) << "Migration-Statement fehlgeschlagen:" << q.lastError().text();
            qCWarning(lcDb) << "Statement:" << stmt.left(200);
            return false;
        }
    }
    return true;
}

// ============================================================
// erstelleBackup
// Kopiert dbPfad nach <dataDir>/backups/<prefix>_v<version>_<datum>.db.
// Hält maximal 5 Backups je Prefix (älteste werden gelöscht).
// Wird vor jeder ausstehenden Migration aufgerufen.
// ============================================================
bool Database::erstelleBackup(const QString &verbindungsName, const QString &prefix, int version)
{
    QSqlDatabase db = verbindungsName.isEmpty()
                      ? m_db
                      : QSqlDatabase::database(verbindungsName);

    QString dbPfad = db.databaseName();
    QFileInfo fi(dbPfad);
    if (!fi.exists()) return true;  // Neuinstallation – nichts zu sichern

    QString backupDir = fi.absolutePath() + "/backups";
    if (!QDir().mkpath(backupDir)) {
        qCWarning(lcDb) << "Backup-Verzeichnis konnte nicht angelegt werden:" << backupDir;
        return false;
    }

    QString datum = QDate::currentDate().toString("yyyy-MM-dd");
    QString backupPfad = backupDir + "/" + prefix + "_v" + QString::number(version)
                         + "_" + datum + ".db";

    // Kollision: Uhrzeit ergänzen, notfalls Sekunden
    if (QFile::exists(backupPfad)) {
        QString zeit = QTime::currentTime().toString("HHmmss");
        backupPfad = backupDir + "/" + prefix + "_v" + QString::number(version)
                     + "_" + datum + "_" + zeit + ".db";
    }

    // VACUUM INTO erzeugt eine saubere Kopie einer offenen SQLite-DB (WAL-sicher)
    QString escaped = backupPfad;
    escaped.replace("'", "''");
    QSqlQuery q(db);
    if (!q.exec("VACUUM INTO '" + escaped + "'")) {
        qCWarning(lcDb) << "Backup fehlgeschlagen:" << backupPfad << q.lastError().text();
        return false;
    }
    qCInfo(lcDb) << "Backup erstellt:" << backupPfad;

    // Älteste Backups löschen wenn mehr als 5 vorhanden
    QDir bd(backupDir);
    QStringList backups = bd.entryList({ prefix + "_v*.db" }, QDir::Files, QDir::Name);
    while (backups.size() > 5) {
        QString alt = backups.takeFirst();
        if (bd.remove(alt))
            qCInfo(lcDb) << "Altes Backup gelöscht:" << alt;
    }

    return true;
}

// ============================================================
// dropAllTables
// Views zuerst, dann Tabellen in FK-sicherer Reihenfolge
// (abhängige Tabellen vor den referenzierten).
// ============================================================
bool Database::dropAllTables()
{
    // Foreign Keys während des Drops deaktivieren – SQLite ignoriert
    // FK-Constraints bei DDL ohnehin, aber sicherheitshalber.
    QSqlQuery q(m_db);
    q.exec("PRAGMA foreign_keys = OFF");

    const QStringList views = {
        "klemmenleiste_bmk",
        "betriebsmittel_bmk",
        "seite_kennzeichen"
    };
    const QStringList tables = {
        // abhängige Tabellen zuerst
        "sps_kanal",
        "sps_baugruppe",
        "sps_rack",
        "ibn_feldwert",
        "ibn_feldvorlage",
        "inbetriebnahme",
        "ibn_kabel",
        "klemme_anschluss",
        "klemme_stegbruecke",
        "klemme",
        "klemmenleiste",
        "bauteil_kabel_paar",
        "bauteil_kabel_ader",
        "bauteil_kabel",
        "kabel_ader",
        "kabel",
        "querverweis",
        "verbindung_segment",
        "verbindung",
        "leiter",
        "grafik_element",
        "betriebsmittel",
        "steckverbinder_kontakt_typ",
        "steckverbinder_kabeleinf",
        "steckverbinder_typ",
        "bauteil_klemme_eigenschaft",
        "bauteil_klemme_bruecke",
        "bauteil_klemme_querschnitt",
        "bauteil_klemme",
        "farb_definition",
        "bauteil",
        "bauteil_kategorie",
        "symbol_pin",
        "symbol_primitiv",
        "symbol_definition",
        "symbol_textfeld",
        "symbol_anschluss",
        "symbol",
        "seite",
        "ort",
        "anlage",
        "changelog",
        "normblatt_feld",
        "normblatt_vorlage",
        "projekt",
        "schema_version"   // alte Tabelle – wird beim ersten Rebuild entfernt
    };

    for (const QString &v : views) {
        if (!q.exec("DROP VIEW IF EXISTS " + v)) {
            qCWarning(lcDb) << "View löschen fehlgeschlagen:" << v << q.lastError().text();
            return false;
        }
    }
    for (const QString &t : tables) {
        if (!q.exec("DROP TABLE IF EXISTS " + t)) {
            qCWarning(lcDb) << "Tabelle löschen fehlgeschlagen:" << t << q.lastError().text();
            return false;
        }
    }

    q.exec("PRAGMA foreign_keys = ON");
    return true;
}

// ============================================================
// createSchema
// Legt alle Tabellen und Views an. Wird nur nach dropAllTables
// aufgerufen – deshalb kein IF NOT EXISTS.
// ============================================================
bool Database::createSchema()
{
    QFile f(QStringLiteral(":/database/schema.sql"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "createSchema: schema.sql nicht gefunden (:/database/schema.sql)";
        return false;
    }
    const QString sql = QString::fromUtf8(f.readAll());
    f.close();

    QStringList cleanLines;
    for (const QString &line : sql.split(QLatin1Char('\n'))) {
        if (!line.trimmed().startsWith(QLatin1String("--")))
            cleanLines << line;
    }

    QSqlQuery q(m_db);
    const QStringList statements = cleanLines.join(QLatin1Char('\n')).split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (const QString &raw : statements) {
        const QString stmt = raw.trimmed();
        if (stmt.isEmpty()) continue;
        if (!q.exec(stmt)) {
            qCWarning(lcDb) << "createSchema:" << q.lastError().text()
                       << "\nStatement:" << stmt.left(120);
            return false;
        }
    }

    qCInfo(lcDb) << "Schema aus schema.sql geladen.";

    // Tabellenzahl prüfen: wenn schema.sql neue Tabellen bekommt, muss
    // BASELINE_TABLE_COUNT (und BASELINE_VERSION) in Database.h mitsynchronisiert werden.
    // Weichen sie ab, würde eine Baseline-Migration fehlschlagen oder Spalten doppelt anlegen.
    QSqlQuery cnt(m_db);
    if (cnt.exec("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
            && cnt.next()) {
        const int actual = cnt.value(0).toInt();
        if (actual != BASELINE_TABLE_COUNT) {
            qCCritical(lcDb) << "DV-03: schema.sql hat" << actual << "Tabellen, erwartet"
                        << BASELINE_TABLE_COUNT << "– BASELINE_TABLE_COUNT und"
                        << "BASELINE_VERSION in Database.h aktualisieren!";
        }
    }

    return true;
}


// ============================================================
// seedSymbolKatalog
// Befüllt die symbol-Tabelle mit dem eingebauten Symbol-Katalog.
// norm: "IEC", "ANSI" oder "IEC,ANSI" (instr-kompatibel).
// ============================================================
bool Database::seedSymbolKatalog()
{
    struct Sym {
        QString code; QString name; QString kat; QString norm; int anschluesse;
    };
    const QList<Sym> symbole = {
        // Kontakte
        { "schliesser",      "Schließer (NO)",          "kontakte",       "IEC,ANSI", 2 },
        { "oeffner",         "Öffner (NC)",             "kontakte",       "IEC,ANSI", 2 },
        { "wechsler",        "Wechsler schmal",         "kontakte",       "IEC,ANSI", 3 },
        { "wechsler_breit",  "Wechsler",                "kontakte",       "IEC,ANSI", 3 },
        { "taster_no",       "Taster (NO)",             "kontakte",       "IEC,ANSI", 2 },
        { "taster_nc",       "Taster NC",               "kontakte",       "IEC,ANSI", 2 },
        { "not_halt",        "Not-Halt (NC)",           "kontakte",       "IEC,ANSI", 2 },
        { "zeitschaltuhr",   "Zeitschaltuhr",           "kontakte",       "IEC,ANSI", 2 },
        { "wischkontakt_betaetigung", "Wischkontakt (bei Betätigung)",         "kontakte", "IEC", 2 },
        { "wischkontakt_rueckfall",   "Wischkontakt (bei Rückfall)",           "kontakte", "IEC", 2 },
        { "wischkontakt_beide",       "Wischkontakt (bei Betätigung+Rückfall)","kontakte", "IEC", 2 },
        { "schliesser_voreilend",     "Voreilender Schließer",                 "kontakte", "IEC", 2 },
        { "schliesser_nacheilend",    "Nacheilender Schließer",                "kontakte", "IEC", 2 },
        { "oeffner_voreilend",        "Voreilender Öffner",                    "kontakte", "IEC", 2 },
        { "oeffner_nacheilend",       "Nacheilender Öffner",                   "kontakte", "IEC", 2 },
        // Betätigungsarten-Familie (SYM-KOPIE-VON-01 siebter Sync-Durchlauf, Schema v123)
        { "beruehrungsempfindlicher_schalter", "Berührungsempfindlicher Schalter", "kontakte", "IEC", 2 },
        { "druckschalter_taster",              "Druckschalter, Taster",            "kontakte", "IEC", 2 },
        { "handbetaetigter_schalter",          "Handbetätigter Schalter",          "kontakte", "IEC", 2 },
        { "naeherungsempfindlicher_schalter",  "Näherungsempfindlicher Schalter",  "kontakte", "IEC", 2 },
        // Verzoegerte Kontakte (SYM-KOPIE-VON-01 achter Sync-Durchlauf, Schema v127)
        { "anzugsverzoegerter_oeffner_nc",     "Anzugsverzögerter Öffner (NC)",    "kontakte", "IEC", 2 },
        { "abfallverzoegerter_oeffner_nc",     "Abfallverzögerter Öffner (NC)",    "kontakte", "IEC", 2 },
        { "anzugsverzoegerter_schliesser_no",  "Anzugsverzögerter Schließer (NO)", "kontakte", "IEC", 2 },
        { "abfallverzoegerter_schliesser_no",  "Abfallverzögerter Schließer (NO)", "kontakte", "IEC", 2 },
        // Schutzgeräte
        { "sicherung",       "Sicherung",               "schutz",         "IEC,ANSI", 2 },
        { "lss",             "Leitungsschutzschalter",  "schutz",         "IEC",      2 },
        { "fi",              "FI-Schutzschalter",       "schutz",         "IEC",      2 },
        { "bimetall_nc",     "Bimetall-Kontakt (NC)",   "schutz",         "IEC,ANSI", 2 },
        // Antriebe
        { "motor",           "Motor",                   "antriebe",       "IEC,ANSI", 2 },
        { "motor_dc",        "Gleichstrommotor",        "antriebe",       "IEC,ANSI", 2 },
        { "spule",           "Spule / Relais",          "antriebe",       "IEC",      2 },
        { "rueckfallverzoegerte_spule_relais", "Rückfallverzögerte Spule / Relais", "antriebe", "IEC", 2 },
        { "anzugverzoegerte_spule_relais",     "Anzugverzögerte Spule / Relais",    "antriebe", "IEC", 2 },
        { "thermo_spule_relais",               "Thermo Spule / Relais",             "antriebe", "IEC", 2 },
        { "trafo",           "Transformator",           "antriebe",       "IEC,ANSI", 4 },
        { "netzteil",        "Netzteil",                "antriebe",       "IEC,ANSI", 4 },
        { "ventil",          "Ventil",                  "antriebe",       "IEC,ANSI", 2 },
        // Passive Bauelemente
        { "widerstand_iec",  "Widerstand",              "passive",        "IEC",      2 },
        { "heizelement",     "Heizelement",             "passive",        "IEC",      2 },
        { "kondensator",     "Kondensator",             "passive",        "IEC,ANSI", 2 },
        { "diode",           "Diode",                   "passive",        "IEC,ANSI", 2 },
        { "led",             "LED",                     "passive",        "IEC,ANSI", 2 },
        { "brueckengleichrichter", "Brückengleichrichter", "passive",      "IEC,ANSI", 4 },
        // Signalgeräte
        { "lampe",           "Lampe",                   "signalgeraete",  "IEC,ANSI", 2 },
        { "hupe",            "Hupe / Klingel",          "signalgeraete",  "IEC,ANSI", 2 },
        { "summer",          "Summer",                  "signalgeraete",  "IEC,ANSI", 2 },
        // Klemmen & Verbinder
        { "klemme",          "Klemme",                  "klemmen",        "IEC,ANSI", 2 },
        { "stecker",         "Stecker",                 "klemmen",        "IEC,ANSI", 2 },
        { "buchse",          "Buchse",                  "klemmen",        "IEC,ANSI", 2 },
        // SPS/PLS-Baugruppen
        { "sps_di_8",  "DI-Baugruppe 8-Kanal",     "sps_pls", "IEC,ANSI", 8  },
        { "sps_di_16", "DI-Baugruppe 16-Kanal",    "sps_pls", "IEC,ANSI", 16 },
        { "sps_do_8",  "DO-Baugruppe 8-Kanal",     "sps_pls", "IEC,ANSI", 8  },
        { "sps_do_16", "DO-Baugruppe 16-Kanal",    "sps_pls", "IEC,ANSI", 16 },
        { "sps_ai_4",  "AI-Baugruppe 4-Kanal",     "sps_pls", "IEC,ANSI", 4  },
        { "sps_ai_8",  "AI-Baugruppe 8-Kanal",     "sps_pls", "IEC,ANSI", 8  },
        { "sps_ao_4",  "AO-Baugruppe 4-Kanal",     "sps_pls", "IEC,ANSI", 4  },
        { "sps_cpu",   "CPU-Baugruppe",            "sps_pls", "IEC,ANSI", 2  },
        { "pls_ai_8",  "PLS AI-Baugruppe 8-Kanal", "sps_pls", "IEC,ANSI", 8  },
        { "pls_ao_4",  "PLS AO-Baugruppe 4-Kanal", "sps_pls", "IEC,ANSI", 4  },
        // KFZ-Elektrik
        { "kfz_sicherung",    "Flachstecksicherung",       "kfz", "IEC,ANSI", 2 },
        { "kfz_relais_4",     "KFZ-Relais 4-polig",        "kfz", "IEC,ANSI", 4 },
        { "kfz_relais_5",     "KFZ-Relais 5-polig",        "kfz", "IEC,ANSI", 5 },
        { "kfz_masse",        "Fahrzeugmasse (GND)",        "kfz", "IEC,ANSI", 1 },
        { "kfz_batterie",     "Batterie 12V",               "kfz", "IEC,ANSI", 2 },
        { "kfz_lichtmaschine","Lichtmaschine (Generator)",  "kfz", "IEC,ANSI", 2 },
        { "kfz_stecker_2",    "KFZ-Stecker 2-polig",        "kfz", "IEC,ANSI", 2 },
        { "kfz_stecker_3",    "KFZ-Stecker 3-polig",        "kfz", "IEC,ANSI", 3 },
        { "kfz_stecker_4",    "KFZ-Stecker 4-polig",        "kfz", "IEC,ANSI", 4 },
        // KFZ + Motorrad, Teil 2 (SYM-ERWEITERUNG-01 Prioritaet 2)
        { "kfz_anlasser",              "Anlasser (Starter)",          "kfz", "IEC,ANSI", 2 },
        { "kfz_gluehkerze",            "Glühkerze",                   "kfz", "IEC,ANSI", 1 },
        { "kfz_scheinwerfer",          "Scheinwerfer (Abblend/Fern)", "kfz", "IEC,ANSI", 3 },
        { "kfz_blinkerrelais",         "Blinkerrelais",               "kfz", "IEC,ANSI", 3 },
        { "kfz_scheibenwischermotor",  "Scheibenwischermotor",        "kfz", "IEC,ANSI", 3 },
        { "kfz_lambdasonde",           "Lambdasonde",                 "kfz", "IEC,ANSI", 2 },
        { "kfz_steuergeraet",          "Steuergerät (ECU)",           "kfz", "IEC,ANSI", 3 },
        { "kfz_cdi",                   "CDI-Zündbox",                 "kfz", "IEC,ANSI", 4 },
        { "kfz_kombiinstrument",       "Kombiinstrument",             "kfz", "IEC,ANSI", 3 },
        { "kfz_sicherungskasten",      "Sicherungskasten",            "kfz", "IEC,ANSI", 5 },
        { "kfz_zuendspule",            "Zündspule",                   "kfz", "IEC,ANSI", 3 },
        // Waermepumpe (SYM-ERWEITERUNG-01 Prioritaet 3)
        { "wp_umwaelzpumpe", "Umwälzpumpe",             "waermepumpe", "IEC,ANSI", 2 },
        { "wp_mischer",      "Mischer-Stellantrieb",    "waermepumpe", "IEC,ANSI", 3 },
        { "wp_heizstab",     "Heizstab (Zusatzheizer)", "waermepumpe", "IEC,ANSI", 2 },
        { "wp_regler",       "Wärmepumpen-Regler",      "waermepumpe", "IEC,ANSI", 3 },
        { "wp_sgready",      "SG-Ready-Schnittstelle",  "waermepumpe", "IEC,ANSI", 3 },
        // Caravan (SYM-ERWEITERUNG-01 Prioritaet 4)
        { "caravan_trennrelais",         "Batterie-Trennrelais",                        "caravan", "IEC,ANSI", 4  },
        { "caravan_ladebooster",         "DC/DC-Ladebooster",                           "caravan", "IEC,ANSI", 4  },
        { "caravan_solarladeregler",     "Solarladeregler (MPPT)",                      "caravan", "IEC,ANSI", 4  },
        { "caravan_solarpanel",          "Solarmodul (PV-Panel)",                       "caravan", "IEC,ANSI", 2  },
        { "caravan_wechselrichter",      "Wechselrichter 12V→230V",                     "caravan", "IEC,ANSI", 4  },
        { "caravan_landanschluss",       "Landstromanschluss (CEE-Einspeisesteckdose)", "caravan", "IEC,ANSI", 3  },
        { "caravan_wasserpumpe",         "Frischwasserpumpe 12V",                       "caravan", "IEC,ANSI", 2  },
        { "caravan_kuehlschrank",        "Absorberkühlschrank (12V/230V/Gas)",          "caravan", "IEC,ANSI", 4  },
        { "caravan_anhaengerstecker_13", "Anhänger-Steckdose (13-polig)",               "caravan", "IEC,ANSI", 13 },
        // Arduino
        { "ard_uno",    "Arduino UNO",    "arduino", "IEC,ANSI", 27 },
        { "ard_nano",   "Arduino Nano",   "arduino", "IEC,ANSI", 28 },
        { "ard_mega",   "Arduino Mega",   "arduino", "IEC,ANSI", 40 },
        { "ard_dht",    "DHT Sensor",     "arduino", "IEC,ANSI",  3 },
        { "ard_hcsr04", "HC-SR04 Sensor", "arduino", "IEC,ANSI",  4 },
        { "ard_pir",    "PIR Sensor",     "arduino", "IEC,ANSI",  3 },
        // Sensoren
        { "sensor_induktiv",   "Induktiver Näherungsschalter",  "sensoren", "IEC,ANSI", 3 },
        { "sensor_kapazitiv",  "Kapazitiver Näherungsschalter", "sensoren", "IEC,ANSI", 3 },
        { "sensor_optisch",    "Optischer Sensor",              "sensoren", "IEC,ANSI", 3 },
        { "sensor_ultraschall","Ultraschallsensor",             "sensoren", "IEC,ANSI", 3 },
        { "sensor_druck",      "Drucksensor",                   "sensoren", "IEC,ANSI", 3 },
        { "sensor_temp",       "Temperatursensor (PT100)",       "sensoren", "IEC,ANSI", 2 },
        { "sensor_niveau",     "Niveauschalter (Schwimmer)",     "sensoren", "IEC,ANSI", 3 },
        // Erdung (EN 60617, 02-15-01 bis 02-15-04)
        { "erde_allgemein",  "Erde (allgemein)",  "erdung", "IEC", 1 },
        { "funktionserdung", "Funktionserdung",   "erdung", "IEC", 1 },
        { "schutzerdung",    "Schutzerdung",      "erdung", "IEC", 1 },
        { "masse_gehaeuse",  "Masse, Gehäuse",    "erdung", "IEC", 1 },
        // Sicherungen (Schutz)
        { "sicherung_netzseitig",        "Sicherung mit netzseitiger Kennzeichnung", "schutz", "IEC", 2 },
        { "nh_sicherung",                "NH-Sicherung",                            "schutz", "IEC", 2 },
        { "sicherungsschalter",          "Sicherungsschalter",                      "schutz", "IEC", 2 },
        { "sicherungstrennschalter",     "Sicherungstrennschalter",                 "schutz", "IEC", 2 },
        { "sicherungslasttrennschalter", "Sicherungslasttrennschalter",             "schutz", "IEC", 2 },
        // Elektroinstallation
        { "serienschalter",    "Serienschalter",      "installation", "IEC", 4 },
        { "taster_beleuchtet", "Taster (beleuchtet)", "installation", "IEC", 2 },
        { "kreuzschalter",     "Kreuzschalter",       "installation", "IEC", 4 },
        { "steckdose_schuko",      "Steckdose (Schuko)",              "installation", "IEC", 3 },
        { "steckdose_schalter",    "Steckdose mit Schalter",          "installation", "IEC", 3 },
        { "steckdose_feuchtraum",  "Feuchtraum-/Außensteckdose",      "installation", "IEC", 3 },
        { "steckdose_cee16",       "CEE-Steckdose (16A)",             "installation", "IEC", 3 },
        { "zaehler",               "Stromzähler (kWh)",               "installation", "IEC", 2 },
        { "rauchmelder",           "Rauchmelder",                     "installation", "IEC", 2 },
        { "bewegungsmelder",       "Bewegungsmelder",                 "installation", "IEC", 3 },
        { "daemmerungsschalter",   "Dämmerungsschalter",              "installation", "IEC", 3 },
        { "ueberspannungsschutz",  "Überspannungsschutz (SPD)",       "installation", "IEC", 3 },
        { "rollladenmotor",        "Rollladenmotor",                  "installation", "IEC", 3 },
        // Übersichtsschaltplan-Familie (SYM-KOPIE-VON-01 siebter Sync-Durchlauf, Schema v123)
        { "schalter_allgemein_uebersicht",   "Schalter allgemein Übersicht",           "installation", "IEC", 1 },
        { "ausschalter_einpolig_uebersicht", "Ausschalter einpolig Übersicht",         "installation", "IEC", 1 },
        { "ausschalter_zweipolig_uebersicht","Ausschalter zweipolig Übersicht",        "installation", "IEC", 1 },
        { "zeitschalter_einpolig_uebersicht","Zeitschalter einpolig Übersicht",        "installation", "IEC", 1 },
        { "schalter_kontrolleuchte_uebersicht","Schalter mit Kontrolleuchte Übersicht","installation", "IEC", 1 },
        { "kreuzschalter_einpolig_uebersicht","Kreuzschalter einpolig Übersicht",      "installation", "IEC", 1 },
        { "wechselschalter_einpolig_uebersicht","Wechselschalter einpolig Übersicht",  "installation", "IEC", 1 },
        { "serienschalter_einpolig_uebersicht","Serienschalter einpolig Übersicht",    "installation", "IEC", 1 },
        { "taster_mit_leuchte_uebersicht",   "Taster mit Leuchte Übersicht",           "installation", "IEC", 1 },
        { "taster_uebersicht",               "Taster Übersicht",                       "installation", "IEC", 1 },
    };

    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO symbol (code, name, kategorie_pfad, norm, anschluesse)
        VALUES (:code, :name, :kat, :norm, :anschl)
    )");

    for (const Sym &s : symbole) {
        q.bindValue(":code",   s.code);
        q.bindValue(":name",   s.name);
        q.bindValue(":kat",    s.kat);
        q.bindValue(":norm",   s.norm);
        q.bindValue(":anschl", s.anschluesse);
        if (!q.exec()) {
            qCWarning(lcDb) << "seedSymbolKatalog:" << s.code << q.lastError().text();
            return false;
        }
    }


    qCInfo(lcDb) << "Symbol-Katalog befüllt:" << symbole.size() << "Symbole.";
    return true;
}

// ============================================================
// seedStandardKlemmen
// Legt 6 repräsentative Klemmen-Bauteile an (Durchgang, PE, N,
// Doppelstock, Trenn). Läuft innerhalb der Baseline-Transaktion.
// ============================================================
bool Database::seedStandardKlemmen()
{
    // Farb-ID anhand Hex-Wert aus farb_definition holen
    auto farbId = [this](const QString &hex) -> QVariant {
        QSqlQuery q(m_bibliothekDb);
        q.prepare("SELECT id FROM farb_definition WHERE hex_wert = :hex AND ist_standard = 1 LIMIT 1");
        q.bindValue(":hex", hex);
        if (q.exec() && q.next()) return q.value(0);
        return QVariant();
    };

    struct KlemmTyp {
        QString bez;
        QString anschlussTyp;
        int     ebenen;
        bool    peFuss;
        bool    stegFaehig;
        double  breiteMm;
        QString farbHex;
        // Querschnitte: starr, flex, blank, isoliert
        double starrMin, starrMax;
        double flexMin,  flexMax;
        double blankMin, blankMax;
        double isoMin,   isoMax;
    };

    const QList<KlemmTyp> typen = {
        { "Durchgangsklemme 2,5mm²", "schraube", 1, false, true,  5.2, "#808080", 0.2,2.5, 0.2,2.5, 0.25,2.5, 0.25,1.5 },
        { "Durchgangsklemme 4mm²",   "feder",    1, false, true,  6.0, "#808080", 0.5,4.0, 0.5,4.0, 0.5, 4.0, 0.5, 2.5 },
        { "PE-Klemme 2,5mm²",        "schraube", 1, true,  false, 5.2, "#88AA00", 0.2,2.5, 0.2,2.5, 0.25,2.5, 0.25,1.5 },
        { "N-Klemme 2,5mm²",         "schraube", 1, false, true,  5.2, "#0000CC", 0.2,2.5, 0.2,2.5, 0.25,2.5, 0.25,1.5 },
        { "Doppelstockklemme 2,5mm²","schraube", 2, false, true,  5.5, "#808080", 0.2,2.5, 0.2,2.5, 0.25,2.5, 0.25,1.5 },
        { "Trennklemme 2,5mm²",      "schraube", 1, false, false, 5.8, "#FF8800", 0.2,2.5, 0.2,2.5, 0.25,2.5, 0.25,1.5 },
    };

    for (const KlemmTyp &t : typen) {
        // Idempotenz-Guard: bereits vorhandene Standard-Klemme nicht erneut anlegen
        // (analog seedNutzerBauteile() – verhindert Duplikate bei jedem erneuten
        // Durchlauf von checkAndApplyBibliothekSchema())
        QSqlQuery qexist(m_bibliothekDb);
        qexist.prepare("SELECT 1 FROM bauteil WHERE bezeichnung = :bez LIMIT 1");
        qexist.bindValue(":bez", t.bez);
        if (qexist.exec() && qexist.next()) continue;

        QSqlQuery qb(m_bibliothekDb);
        qb.prepare("INSERT INTO bauteil (bezeichnung, norm, bemerkung) "
                   "VALUES (:bez, :norm, :bem)");
        qb.bindValue(":bez",  t.bez);
        qb.bindValue(":norm", QString("IEC 60947-7-1"));
        qb.bindValue(":bem",  QString("Standard-Klemme"));
        if (!qb.exec()) {
            qCWarning(lcDb) << "seedStandardKlemmen bauteil:" << t.bez << qb.lastError().text();
            return false;
        }
        int bId = qb.lastInsertId().toInt();

        QSqlQuery qk(m_bibliothekDb);
        qk.prepare("INSERT INTO bauteil_klemme "
                   "(bauteil_id, norm, anschluss_typ, ebenen_anzahl, punkte_seite_a, punkte_seite_b, "
                   " fuss_kontakt_pe, stegbruecke_faehig, breite_mm, gehaeuse_farbe_id) "
                   "VALUES (:bid, :norm, :typ, :eb, 1, 1, :pe, :steg, :br, :fid)");
        qk.bindValue(":bid",  bId);
        qk.bindValue(":norm", QString("IEC 60947-7-1"));
        qk.bindValue(":typ",  t.anschlussTyp);
        qk.bindValue(":eb",   t.ebenen);
        qk.bindValue(":pe",   t.peFuss ? 1 : 0);
        qk.bindValue(":steg", t.stegFaehig ? 1 : 0);
        qk.bindValue(":br",   t.breiteMm);
        qk.bindValue(":fid",  farbId(t.farbHex));
        if (!qk.exec()) {
            qCWarning(lcDb) << "seedStandardKlemmen bauteil_klemme:" << t.bez << qk.lastError().text();
            return false;
        }
        int kId = qk.lastInsertId().toInt();

        struct QS { QString typ; double min; double max; };
        const QList<QS> qs = {
            { "starr",         t.starrMin, t.starrMax },
            { "flexibel",      t.flexMin,  t.flexMax  },
            { "aenh_blank",    t.blankMin, t.blankMax },
            { "aenh_isoliert", t.isoMin,   t.isoMax   },
        };
        QSqlQuery qq(m_bibliothekDb);
        qq.prepare("INSERT INTO bauteil_klemme_querschnitt (klemme_id, adertyp, min_mm2, max_mm2) "
                   "VALUES (:kid, :typ, :min, :max)");
        for (const QS &s : qs) {
            qq.bindValue(":kid", kId);
            qq.bindValue(":typ", s.typ);
            qq.bindValue(":min", s.min);
            qq.bindValue(":max", s.max);
            if (!qq.exec()) {
                qCWarning(lcDb) << "seedStandardKlemmen querschnitt:" << t.bez << s.typ << qq.lastError().text();
                return false;
            }
        }

        if (t.peFuss) {
            QSqlQuery qbr(m_bibliothekDb);
            qbr.prepare("INSERT INTO bauteil_klemme_bruecke "
                        "(klemme_id, von_ebene, nach_ebene, ist_pe_fuss) VALUES (:kid, 1, 1, 1)");
            qbr.bindValue(":kid", kId);
            if (!qbr.exec())
                qCWarning(lcDb) << "seedStandardKlemmen bruecke PE:" << t.bez << qbr.lastError().text();
        }
    }

    qCInfo(lcDb) << "Standard-Klemmen geseedet: 6 Typen.";
    return true;
}

// ============================================================
// seedBuiltinSymbolDefinitionen
// Liest src/database/symbole.sql als Qt-Ressource ein und führt
// alle darin enthaltenen INSERT-Statements aus.
// Läuft innerhalb der äußeren Transaktion von initDatabase().
// ============================================================
bool Database::seedBuiltinSymbolDefinitionen()
{
    QFile f(QStringLiteral(":/database/symbole.sql"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "seedBuiltinSymbolDefinitionen: symbole.sql nicht gefunden (:/database/symbole.sql)";
        return false;
    }
    const QString sql = QString::fromUtf8(f.readAll());
    f.close();

    // Kommentarzeilen entfernen, damit kein Statement nach dem Semikolon-Split
    // fälschlicherweise mit "--" beginnt und übersprungen wird.
    QStringList cleanLines;
    for (const QString &line : sql.split(QLatin1Char('\n'))) {
        if (!line.trimmed().startsWith(QLatin1String("--")))
            cleanLines << line;
    }
    const QString cleanSql = cleanLines.join(QLatin1Char('\n'));

    QSqlQuery q(m_db);
    const QStringList statements = cleanSql.split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (const QString &raw : statements) {
        const QString stmt = raw.trimmed();
        if (stmt.isEmpty())
            continue;
        if (!q.exec(stmt)) {
            qCWarning(lcDb) << "seedBuiltinSymbolDefinitionen:" << q.lastError().text()
                       << "\nStatement:" << stmt.left(120);
            return false;
        }
    }

    qCInfo(lcDb) << "Builtin-Symboldefinitionen aus symbole.sql geladen.";
    return true;
}

// seedNutzerBauteile
// Liest src/database/bauteile_nutzer.sql als Qt-Ressource ein und führt
// alle darin enthaltenen INSERT-Statements aus.
// Die Datei enthält projektübergreifende Bauteil-Seeds (Klemmen, Kabel …),
// die bei jedem neuen Projekt einmalig angelegt werden.
// Alle Statements sind idempotent (WHERE NOT EXISTS-Guard auf Bezeichnung).
// ============================================================
bool Database::seedNutzerBauteile()
{
    QFile f(QStringLiteral(":/database/bauteile_nutzer.sql"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(lcDb) << "seedNutzerBauteile: bauteile_nutzer.sql nicht gefunden";
        return false;
    }
    const QString sql = QString::fromUtf8(f.readAll());
    f.close();

    QStringList cleanLines;
    for (const QString &line : sql.split(QLatin1Char('\n'))) {
        if (!line.trimmed().startsWith(QLatin1String("--")))
            cleanLines << line;
    }
    const QString cleanSql = cleanLines.join(QLatin1Char('\n'));

    QSqlQuery q(m_bibliothekDb);
    const QStringList statements = cleanSql.split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (const QString &raw : statements) {
        const QString stmt = raw.trimmed();
        if (stmt.isEmpty())
            continue;
        if (!q.exec(stmt)) {
            qCWarning(lcDb) << "seedNutzerBauteile:" << q.lastError().text()
                            << "\nStatement:" << stmt.left(120);
            return false;
        }
    }

    qCInfo(lcDb) << "Nutzer-Bauteile aus bauteile_nutzer.sql geladen.";
    return true;
}
