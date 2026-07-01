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
    return {
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
    };
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
        { "wechsler",        "Wechsler",                "kontakte",       "IEC,ANSI", 3 },
        { "taster_no",       "Taster (NO)",             "kontakte",       "IEC,ANSI", 2 },
        { "taster_nc",       "Taster NC",               "kontakte",       "IEC,ANSI", 2 },
        { "not_halt",        "Not-Halt (NC)",           "kontakte",       "IEC,ANSI", 2 },
        // Schutzgeräte
        { "sicherung",       "Sicherung",               "schutz",         "IEC,ANSI", 2 },
        { "lss",             "Leitungsschutzschalter",  "schutz",         "IEC",      2 },
        { "fi",              "FI-Schutzschalter",       "schutz",         "IEC",      2 },
        { "bimetall_nc",     "Bimetall-Kontakt (NC)",   "schutz",         "IEC,ANSI", 2 },
        // Antriebe
        { "motor",           "Motor",                   "antriebe",       "IEC,ANSI", 2 },
        { "spule",           "Spule / Relais",          "antriebe",       "IEC",      2 },
        { "spule_ansi",      "Coil / Relay",            "antriebe",       "ANSI",     2 },
        { "trafo",           "Transformator",           "antriebe",       "IEC,ANSI", 4 },
        // Passive Bauelemente
        { "widerstand_iec",  "Widerstand",              "passive",        "IEC",      2 },
        { "widerstand_ansi", "Resistor",                "passive",        "ANSI",     2 },
        { "kondensator",     "Kondensator",             "passive",        "IEC,ANSI", 2 },
        { "diode",           "Diode",                   "passive",        "IEC,ANSI", 2 },
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
