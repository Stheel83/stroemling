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
// Version 40 (Baseline) wird von checkAndApplySchema() speziell
// behandelt und ruft dropAllTables() + createSchema() + Seeds.
// ============================================================
struct SchemaMigration {
    int         version;
    QString     beschreibung;
    QStringList statements;
};

static QList<SchemaMigration> alleMigrationen()
{
    return {
        { 40, "Baseline v40 – initiales Schema", {} },
        { 41, "SPS/PLS-Integration: sps_rack, sps_baugruppe, sps_kanal", {
            R"(CREATE TABLE IF NOT EXISTS sps_rack (
                id           INTEGER PRIMARY KEY,
                projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
                rack_nr      INTEGER NOT NULL DEFAULT 0,
                system_typ   TEXT    NOT NULL DEFAULT 'SPS',
                bezeichnung  TEXT    NOT NULL DEFAULT 'Rack 0',
                beschreibung TEXT    NOT NULL DEFAULT '',
                hersteller   TEXT    NOT NULL DEFAULT '',
                sortierung   INTEGER NOT NULL DEFAULT 0,
                UNIQUE(projekt_id, rack_nr)
            ))",
            "CREATE INDEX IF NOT EXISTS idx_sps_rack_projekt ON sps_rack(projekt_id)",
            R"(CREATE TABLE IF NOT EXISTS sps_baugruppe (
                id                INTEGER PRIMARY KEY,
                rack_id           INTEGER NOT NULL REFERENCES sps_rack(id) ON DELETE CASCADE,
                slot              INTEGER NOT NULL DEFAULT 0,
                typ               TEXT    NOT NULL DEFAULT 'DI',
                bezeichnung       TEXT    NOT NULL DEFAULT '',
                artikel_nr        TEXT    NOT NULL DEFAULT '',
                kanaele           INTEGER NOT NULL DEFAULT 8,
                datentyp_standard TEXT    NOT NULL DEFAULT 'BOOL',
                adress_byte_start INTEGER NOT NULL DEFAULT 0,
                kommentar         TEXT    NOT NULL DEFAULT '',
                sortierung        INTEGER NOT NULL DEFAULT 0,
                UNIQUE(rack_id, slot)
            ))",
            "CREATE INDEX IF NOT EXISTS idx_sps_baugruppe_rack ON sps_baugruppe(rack_id)",
            R"(CREATE TABLE IF NOT EXISTS sps_kanal (
                id                INTEGER PRIMARY KEY,
                projekt_id        INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
                baugruppe_id      INTEGER REFERENCES sps_baugruppe(id) ON DELETE SET NULL,
                kanal_nr          INTEGER,
                adress_typ        TEXT    NOT NULL DEFAULT 'E',
                byte_nr           INTEGER NOT NULL DEFAULT 0,
                bit_nr            INTEGER NOT NULL DEFAULT 0,
                datentyp          TEXT    NOT NULL DEFAULT 'BOOL',
                variablenname     TEXT    NOT NULL DEFAULT '',
                kommentar         TEXT    NOT NULL DEFAULT '',
                grafik_element_id INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
                pls_einheit       TEXT,
                pls_bereich_min   REAL,
                pls_bereich_max   REAL,
                pls_alarm_ll      REAL,
                pls_alarm_lo      REAL,
                pls_alarm_hi      REAL,
                pls_alarm_hh      REAL,
                pls_hart_adresse  INTEGER,
                pls_protokoll     TEXT,
                UNIQUE(projekt_id, adress_typ, byte_nr, bit_nr)
            ))",
            "CREATE INDEX IF NOT EXISTS idx_sps_kanal_projekt   ON sps_kanal(projekt_id)",
            "CREATE INDEX IF NOT EXISTS idx_sps_kanal_element   ON sps_kanal(grafik_element_id)",
            "CREATE INDEX IF NOT EXISTS idx_sps_kanal_baugruppe ON sps_kanal(baugruppe_id)"
        }},
        { 42, "SPS/PLS-Symbole: DI/DO/AI/AO-Baugruppen in symbol_definition + symbol-Katalog", {
            R"SQL(INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('sps_di_8',  'DI-Baugruppe 8-Kanal',     'SPS/PLS', 32,  80, 'variabel', 1),
('sps_di_16', 'DI-Baugruppe 16-Kanal',    'SPS/PLS', 32, 128, 'variabel', 1),
('sps_do_8',  'DO-Baugruppe 8-Kanal',     'SPS/PLS', 32,  80, 'variabel', 1),
('sps_do_16', 'DO-Baugruppe 16-Kanal',    'SPS/PLS', 32, 128, 'variabel', 1),
('sps_ai_4',  'AI-Baugruppe 4-Kanal',     'SPS/PLS', 32,  64, 'variabel', 1),
('sps_ai_8',  'AI-Baugruppe 8-Kanal',     'SPS/PLS', 32,  80, 'variabel', 1),
('sps_ao_4',  'AO-Baugruppe 4-Kanal',     'SPS/PLS', 32,  64, 'variabel', 1),
('sps_cpu',   'CPU-Baugruppe',            'SPS/PLS', 32,  48, 'variabel', 1),
('pls_ai_8',  'PLS AI-Baugruppe 8-Kanal', 'SPS/PLS', 32,  80, 'variabel', 1),
('pls_ao_4',  'PLS AO-Baugruppe 4-Kanal', 'SPS/PLS', 32,  64, 'variabel', 1))SQL",
            "DELETE FROM symbol_pin WHERE symbol_id IN ('sps_di_8','sps_di_16','sps_do_8','sps_do_16','sps_ai_4','sps_ai_8','sps_ao_4','sps_cpu','pls_ai_8','pls_ao_4')",
            R"SQL(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('sps_di_8','K0',0,0.111,-1,0,'neutral'),('sps_di_8','K1',0,0.222,-1,0,'neutral'),
('sps_di_8','K2',0,0.333,-1,0,'neutral'),('sps_di_8','K3',0,0.444,-1,0,'neutral'),
('sps_di_8','K4',0,0.556,-1,0,'neutral'),('sps_di_8','K5',0,0.667,-1,0,'neutral'),
('sps_di_8','K6',0,0.778,-1,0,'neutral'),('sps_di_8','K7',0,0.889,-1,0,'neutral'),
('sps_di_16','K0',0,0.059,-1,0,'neutral'),('sps_di_16','K1',0,0.118,-1,0,'neutral'),
('sps_di_16','K2',0,0.176,-1,0,'neutral'),('sps_di_16','K3',0,0.235,-1,0,'neutral'),
('sps_di_16','K4',0,0.294,-1,0,'neutral'),('sps_di_16','K5',0,0.353,-1,0,'neutral'),
('sps_di_16','K6',0,0.412,-1,0,'neutral'),('sps_di_16','K7',0,0.471,-1,0,'neutral'),
('sps_di_16','K8',0,0.529,-1,0,'neutral'),('sps_di_16','K9',0,0.588,-1,0,'neutral'),
('sps_di_16','K10',0,0.647,-1,0,'neutral'),('sps_di_16','K11',0,0.706,-1,0,'neutral'),
('sps_di_16','K12',0,0.765,-1,0,'neutral'),('sps_di_16','K13',0,0.824,-1,0,'neutral'),
('sps_di_16','K14',0,0.882,-1,0,'neutral'),('sps_di_16','K15',0,0.941,-1,0,'neutral'),
('sps_do_8','K0',1,0.111,1,0,'neutral'),('sps_do_8','K1',1,0.222,1,0,'neutral'),
('sps_do_8','K2',1,0.333,1,0,'neutral'),('sps_do_8','K3',1,0.444,1,0,'neutral'),
('sps_do_8','K4',1,0.556,1,0,'neutral'),('sps_do_8','K5',1,0.667,1,0,'neutral'),
('sps_do_8','K6',1,0.778,1,0,'neutral'),('sps_do_8','K7',1,0.889,1,0,'neutral'),
('sps_do_16','K0',1,0.059,1,0,'neutral'),('sps_do_16','K1',1,0.118,1,0,'neutral'),
('sps_do_16','K2',1,0.176,1,0,'neutral'),('sps_do_16','K3',1,0.235,1,0,'neutral'),
('sps_do_16','K4',1,0.294,1,0,'neutral'),('sps_do_16','K5',1,0.353,1,0,'neutral'),
('sps_do_16','K6',1,0.412,1,0,'neutral'),('sps_do_16','K7',1,0.471,1,0,'neutral'),
('sps_do_16','K8',1,0.529,1,0,'neutral'),('sps_do_16','K9',1,0.588,1,0,'neutral'),
('sps_do_16','K10',1,0.647,1,0,'neutral'),('sps_do_16','K11',1,0.706,1,0,'neutral'),
('sps_do_16','K12',1,0.765,1,0,'neutral'),('sps_do_16','K13',1,0.824,1,0,'neutral'),
('sps_do_16','K14',1,0.882,1,0,'neutral'),('sps_do_16','K15',1,0.941,1,0,'neutral'),
('sps_ai_4','K0',0,0.2,-1,0,'neutral'),('sps_ai_4','K1',0,0.4,-1,0,'neutral'),
('sps_ai_4','K2',0,0.6,-1,0,'neutral'),('sps_ai_4','K3',0,0.8,-1,0,'neutral'),
('sps_ai_8','K0',0,0.111,-1,0,'neutral'),('sps_ai_8','K1',0,0.222,-1,0,'neutral'),
('sps_ai_8','K2',0,0.333,-1,0,'neutral'),('sps_ai_8','K3',0,0.444,-1,0,'neutral'),
('sps_ai_8','K4',0,0.556,-1,0,'neutral'),('sps_ai_8','K5',0,0.667,-1,0,'neutral'),
('sps_ai_8','K6',0,0.778,-1,0,'neutral'),('sps_ai_8','K7',0,0.889,-1,0,'neutral'),
('sps_ao_4','K0',1,0.2,1,0,'neutral'),('sps_ao_4','K1',1,0.4,1,0,'neutral'),
('sps_ao_4','K2',1,0.6,1,0,'neutral'),('sps_ao_4','K3',1,0.8,1,0,'neutral'),
('sps_cpu','DP',0,0.333,-1,0,'neutral'),('sps_cpu','PN',0,0.667,-1,0,'neutral'),
('pls_ai_8','K0',0,0.111,-1,0,'neutral'),('pls_ai_8','K1',0,0.222,-1,0,'neutral'),
('pls_ai_8','K2',0,0.333,-1,0,'neutral'),('pls_ai_8','K3',0,0.444,-1,0,'neutral'),
('pls_ai_8','K4',0,0.556,-1,0,'neutral'),('pls_ai_8','K5',0,0.667,-1,0,'neutral'),
('pls_ai_8','K6',0,0.778,-1,0,'neutral'),('pls_ai_8','K7',0,0.889,-1,0,'neutral'),
('pls_ao_4','K0',1,0.2,1,0,'neutral'),('pls_ao_4','K1',1,0.4,1,0,'neutral'),
('pls_ao_4','K2',1,0.6,1,0,'neutral'),('pls_ao_4','K3',1,0.8,1,0,'neutral'))SQL",
            "DELETE FROM symbol_primitiv WHERE symbol_id IN ('sps_di_8','sps_di_16','sps_do_8','sps_do_16','sps_ai_4','sps_ai_8','sps_ao_4','sps_cpu','pls_ai_8','pls_ao_4')",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('sps_di_8',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'DI 8',0.08,1,'center','middle','solid'),
('sps_di_8',2,'linie',0,0.111,0.15,0.111,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',3,'linie',0,0.222,0.15,0.222,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',4,'linie',0,0.333,0.15,0.333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',5,'linie',0,0.444,0.15,0.444,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',6,'linie',0,0.556,0.15,0.556,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',7,'linie',0,0.667,0.15,0.667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',8,'linie',0,0.778,0.15,0.778,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_8',9,'linie',0,0.889,0.15,0.889,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'))SQL",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('sps_di_16',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'DI 16',0.06,1,'center','middle','solid'),
('sps_di_16',2,'linie',0,0.059,0.15,0.059,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',3,'linie',0,0.118,0.15,0.118,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',4,'linie',0,0.176,0.15,0.176,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',5,'linie',0,0.235,0.15,0.235,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',6,'linie',0,0.294,0.15,0.294,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',7,'linie',0,0.353,0.15,0.353,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',8,'linie',0,0.412,0.15,0.412,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',9,'linie',0,0.471,0.15,0.471,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',10,'linie',0,0.529,0.15,0.529,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',11,'linie',0,0.588,0.15,0.588,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',12,'linie',0,0.647,0.15,0.647,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',13,'linie',0,0.706,0.15,0.706,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',14,'linie',0,0.765,0.15,0.765,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',15,'linie',0,0.824,0.15,0.824,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',16,'linie',0,0.882,0.15,0.882,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_di_16',17,'linie',0,0.941,0.15,0.941,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'))SQL",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('sps_do_8',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'DO 8',0.08,1,'center','middle','solid'),
('sps_do_8',2,'linie',0.85,0.111,1.0,0.111,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',3,'linie',0.85,0.222,1.0,0.222,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',4,'linie',0.85,0.333,1.0,0.333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',5,'linie',0.85,0.444,1.0,0.444,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',6,'linie',0.85,0.556,1.0,0.556,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',7,'linie',0.85,0.667,1.0,0.667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',8,'linie',0.85,0.778,1.0,0.778,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_8',9,'linie',0.85,0.889,1.0,0.889,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'))SQL",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('sps_do_16',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'DO 16',0.06,1,'center','middle','solid'),
('sps_do_16',2,'linie',0.85,0.059,1.0,0.059,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',3,'linie',0.85,0.118,1.0,0.118,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',4,'linie',0.85,0.176,1.0,0.176,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',5,'linie',0.85,0.235,1.0,0.235,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',6,'linie',0.85,0.294,1.0,0.294,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',7,'linie',0.85,0.353,1.0,0.353,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',8,'linie',0.85,0.412,1.0,0.412,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',9,'linie',0.85,0.471,1.0,0.471,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',10,'linie',0.85,0.529,1.0,0.529,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',11,'linie',0.85,0.588,1.0,0.588,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',12,'linie',0.85,0.647,1.0,0.647,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',13,'linie',0.85,0.706,1.0,0.706,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',14,'linie',0.85,0.765,1.0,0.765,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',15,'linie',0.85,0.824,1.0,0.824,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',16,'linie',0.85,0.882,1.0,0.882,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_do_16',17,'linie',0.85,0.941,1.0,0.941,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'))SQL",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('sps_ai_4',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_4',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'AI 4',0.10,1,'center','middle','solid'),
('sps_ai_4',2,'linie',0,0.2,0.15,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_4',3,'linie',0,0.4,0.15,0.4,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_4',4,'linie',0,0.6,0.15,0.6,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_4',5,'linie',0,0.8,0.15,0.8,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'AI 8',0.08,1,'center','middle','solid'),
('sps_ai_8',2,'linie',0,0.111,0.15,0.111,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',3,'linie',0,0.222,0.15,0.222,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',4,'linie',0,0.333,0.15,0.333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',5,'linie',0,0.444,0.15,0.444,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',6,'linie',0,0.556,0.15,0.556,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',7,'linie',0,0.667,0.15,0.667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',8,'linie',0,0.778,0.15,0.778,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ai_8',9,'linie',0,0.889,0.15,0.889,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ao_4',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ao_4',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'AO 4',0.10,1,'center','middle','solid'),
('sps_ao_4',2,'linie',0.85,0.2,1.0,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ao_4',3,'linie',0.85,0.4,1.0,0.4,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ao_4',4,'linie',0.85,0.6,1.0,0.6,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_ao_4',5,'linie',0.85,0.8,1.0,0.8,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_cpu',0,'rechteck',0.1,0.05,0.9,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_cpu',1,'text',0.5,0.35,0,0,0,0,0,0,0,0,'CPU',0.13,1,'center','middle','solid'),
('sps_cpu',2,'text',0.5,0.65,0,0,0,0,0,0,0,0,'SPS',0.10,0,'center','middle','solid'),
('sps_cpu',3,'linie',0,0.333,0.1,0.333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sps_cpu',4,'linie',0,0.667,0.1,0.667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',1,'text',0.5,0.42,0,0,0,0,0,0,0,0,'AI 8',0.08,1,'center','middle','solid'),
('pls_ai_8',2,'text',0.5,0.58,0,0,0,0,0,0,0,0,'PLS',0.06,0,'center','middle','solid'),
('pls_ai_8',3,'linie',0,0.111,0.15,0.111,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',4,'linie',0,0.222,0.15,0.222,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',5,'linie',0,0.333,0.15,0.333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',6,'linie',0,0.444,0.15,0.444,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',7,'linie',0,0.556,0.15,0.556,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',8,'linie',0,0.667,0.15,0.667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',9,'linie',0,0.778,0.15,0.778,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ai_8',10,'linie',0,0.889,0.15,0.889,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ao_4',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ao_4',1,'text',0.5,0.4,0,0,0,0,0,0,0,0,'AO 4',0.10,1,'center','middle','solid'),
('pls_ao_4',2,'text',0.5,0.62,0,0,0,0,0,0,0,0,'PLS',0.08,0,'center','middle','solid'),
('pls_ao_4',3,'linie',0.85,0.2,1.0,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ao_4',4,'linie',0.85,0.4,1.0,0.4,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ao_4',5,'linie',0.85,0.6,1.0,0.6,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('pls_ao_4',6,'linie',0.85,0.8,1.0,0.8,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'))SQL",
            R"SQL(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES
('sps_di_8',  'DI-Baugruppe 8-Kanal',     'sps_pls', 'IEC,ANSI', 8),
('sps_di_16', 'DI-Baugruppe 16-Kanal',    'sps_pls', 'IEC,ANSI', 16),
('sps_do_8',  'DO-Baugruppe 8-Kanal',     'sps_pls', 'IEC,ANSI', 8),
('sps_do_16', 'DO-Baugruppe 16-Kanal',    'sps_pls', 'IEC,ANSI', 16),
('sps_ai_4',  'AI-Baugruppe 4-Kanal',     'sps_pls', 'IEC,ANSI', 4),
('sps_ai_8',  'AI-Baugruppe 8-Kanal',     'sps_pls', 'IEC,ANSI', 8),
('sps_ao_4',  'AO-Baugruppe 4-Kanal',     'sps_pls', 'IEC,ANSI', 4),
('sps_cpu',   'CPU-Baugruppe',            'sps_pls', 'IEC,ANSI', 2),
('pls_ai_8',  'PLS AI-Baugruppe 8-Kanal', 'sps_pls', 'IEC,ANSI', 8),
('pls_ao_4',  'PLS AO-Baugruppe 4-Kanal', 'sps_pls', 'IEC,ANSI', 4))SQL",
        }},
        { 43, "KFZ-Elektrik: 9 Symbole (Sicherung/Relais/Masse/Batterie/LiMa/Stecker) + DIN 72551 Leitungsfarben", {
            R"SQL(INSERT OR IGNORE INTO symbol_definition (id,name,kategorie,breite_mm,hoehe_mm,rolle,ist_builtin) VALUES
('kfz_sicherung',    'Flachstecksicherung',       'KFZ',32,16,'variabel',1),
('kfz_relais_4',     'KFZ-Relais 4-polig',        'KFZ',32,48,'variabel',1),
('kfz_relais_5',     'KFZ-Relais 5-polig',        'KFZ',32,64,'variabel',1),
('kfz_masse',        'Fahrzeugmasse (GND)',        'KFZ',32,16,'variabel',1),
('kfz_batterie',     'Batterie 12V',              'KFZ',32,16,'variabel',1),
('kfz_lichtmaschine','Lichtmaschine (Generator)', 'KFZ',32,16,'variabel',1),
('kfz_stecker_2',    'KFZ-Stecker 2-polig',       'KFZ',32,32,'variabel',1),
('kfz_stecker_3',    'KFZ-Stecker 3-polig',       'KFZ',32,48,'variabel',1),
('kfz_stecker_4',    'KFZ-Stecker 4-polig',       'KFZ',32,64,'variabel',1))SQL",
            "DELETE FROM symbol_pin WHERE symbol_id IN ('kfz_sicherung','kfz_relais_4','kfz_relais_5','kfz_masse','kfz_batterie','kfz_lichtmaschine','kfz_stecker_2','kfz_stecker_3','kfz_stecker_4')",
            R"SQL(INSERT INTO symbol_pin (symbol_id,name,x,y,offen_x,offen_y,signaltyp) VALUES
('kfz_sicherung','A',0,0.5,-1,0,'neutral'),
('kfz_sicherung','B',1,0.5,1,0,'neutral'),
('kfz_relais_4','85',0,0.25,-1,0,'neutral'),
('kfz_relais_4','86',1,0.25,1,0,'neutral'),
('kfz_relais_4','30',0,0.75,-1,0,'neutral'),
('kfz_relais_4','87',1,0.75,1,0,'neutral'),
('kfz_relais_5','85',0,0.2,-1,0,'neutral'),
('kfz_relais_5','86',1,0.2,1,0,'neutral'),
('kfz_relais_5','30',0,0.7,-1,0,'neutral'),
('kfz_relais_5','87',1,0.55,1,0,'neutral'),
('kfz_relais_5','87a',1,0.85,1,0,'neutral'),
('kfz_masse','M',0,0.5,-1,0,'neutral'),
('kfz_batterie','+',0,0.5,-1,0,'neutral'),
('kfz_batterie','-',1,0.5,1,0,'neutral'),
('kfz_lichtmaschine','+',0,0.5,-1,0,'neutral'),
('kfz_lichtmaschine','D+',1,0.5,1,0,'neutral'),
('kfz_stecker_2','1',0,0.33,-1,0,'neutral'),
('kfz_stecker_2','2',0,0.67,-1,0,'neutral'),
('kfz_stecker_3','1',0,0.25,-1,0,'neutral'),
('kfz_stecker_3','2',0,0.5,-1,0,'neutral'),
('kfz_stecker_3','3',0,0.75,-1,0,'neutral'),
('kfz_stecker_4','1',0,0.2,-1,0,'neutral'),
('kfz_stecker_4','2',0,0.4,-1,0,'neutral'),
('kfz_stecker_4','3',0,0.6,-1,0,'neutral'),
('kfz_stecker_4','4',0,0.8,-1,0,'neutral'))SQL",
            "DELETE FROM symbol_primitiv WHERE symbol_id IN ('kfz_sicherung','kfz_relais_4','kfz_relais_5','kfz_masse','kfz_batterie','kfz_lichtmaschine','kfz_stecker_2','kfz_stecker_3','kfz_stecker_4')",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('kfz_sicherung',0,'rechteck',0.15,0.15,0.85,0.85,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_sicherung',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'F',0.40,1,'center','middle','solid'),
('kfz_sicherung',2,'linie',0,0.5,0.15,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_sicherung',3,'linie',0.85,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_4',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_4',1,'linie',0.15,0.5,0.85,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_4',2,'text',0.5,0.25,0,0,0,0,0,0,0,0,'Spule',0.10,0,'center','middle','solid'),
('kfz_relais_4',3,'text',0.5,0.75,0,0,0,0,0,0,0,0,'K4',0.13,1,'center','middle','solid'),
('kfz_relais_4',4,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_4',5,'linie',0.85,0.25,1.0,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_4',6,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_4',7,'linie',0.85,0.75,1.0,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',1,'linie',0.15,0.4,0.85,0.4,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',2,'text',0.5,0.2,0,0,0,0,0,0,0,0,'Spule',0.08,0,'center','middle','solid'),
('kfz_relais_5',3,'text',0.5,0.7,0,0,0,0,0,0,0,0,'K5',0.10,1,'center','middle','solid'),
('kfz_relais_5',4,'linie',0,0.2,0.15,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',5,'linie',0.85,0.2,1.0,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',6,'linie',0,0.7,0.15,0.7,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',7,'linie',0.85,0.55,1.0,0.55,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_relais_5',8,'linie',0.85,0.85,1.0,0.85,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_masse',0,'linie',0,0.5,0.25,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_masse',1,'linie',0.25,0.1,0.25,0.9,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_masse',2,'linie',0.25,0.2,1.0,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_masse',3,'linie',0.25,0.5,0.8,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_masse',4,'linie',0.25,0.8,0.6,0.8,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_batterie',0,'linie',0,0.5,0.25,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_batterie',1,'linie',0.25,0.1,0.25,0.9,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_batterie',2,'linie',0.42,0.3,0.42,0.7,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_batterie',3,'linie',0.58,0.1,0.58,0.9,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_batterie',4,'linie',0.75,0.3,0.75,0.7,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_batterie',5,'linie',0.75,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_lichtmaschine',0,'kreis_offen',0.5,0.5,0,0,0,0,0.22,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_lichtmaschine',1,'text',0.5,0.5,0,0,0,0,0,0,0,0,'G',0.35,1,'center','middle','solid'),
('kfz_lichtmaschine',2,'linie',0,0.5,0.28,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_lichtmaschine',3,'linie',0.72,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_2',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_2',1,'text',0.35,0.33,0,0,0,0,0,0,0,0,'1',0.20,0,'center','middle','solid'),
('kfz_stecker_2',2,'text',0.35,0.67,0,0,0,0,0,0,0,0,'2',0.20,0,'center','middle','solid'),
('kfz_stecker_2',3,'linie',0,0.33,0.15,0.33,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_2',4,'linie',0,0.67,0.15,0.67,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_3',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_3',1,'text',0.35,0.25,0,0,0,0,0,0,0,0,'1',0.13,0,'center','middle','solid'),
('kfz_stecker_3',2,'text',0.35,0.5,0,0,0,0,0,0,0,0,'2',0.13,0,'center','middle','solid'),
('kfz_stecker_3',3,'text',0.35,0.75,0,0,0,0,0,0,0,0,'3',0.13,0,'center','middle','solid'),
('kfz_stecker_3',4,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_3',5,'linie',0,0.5,0.15,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_3',6,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_4',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_4',1,'text',0.35,0.2,0,0,0,0,0,0,0,0,'1',0.10,0,'center','middle','solid'),
('kfz_stecker_4',2,'text',0.35,0.4,0,0,0,0,0,0,0,0,'2',0.10,0,'center','middle','solid'),
('kfz_stecker_4',3,'text',0.35,0.6,0,0,0,0,0,0,0,0,'3',0.10,0,'center','middle','solid'),
('kfz_stecker_4',4,'text',0.35,0.8,0,0,0,0,0,0,0,0,'4',0.10,0,'center','middle','solid'),
('kfz_stecker_4',5,'linie',0,0.2,0.15,0.2,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_4',6,'linie',0,0.4,0.15,0.4,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_4',7,'linie',0,0.6,0.15,0.6,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('kfz_stecker_4',8,'linie',0,0.8,0.15,0.8,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'))SQL",
            R"SQL(INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES
('kfz_sicherung',    'Flachstecksicherung',       'kfz','IEC,ANSI',2),
('kfz_relais_4',     'KFZ-Relais 4-polig',        'kfz','IEC,ANSI',4),
('kfz_relais_5',     'KFZ-Relais 5-polig',        'kfz','IEC,ANSI',5),
('kfz_masse',        'Fahrzeugmasse (GND)',        'kfz','IEC,ANSI',1),
('kfz_batterie',     'Batterie 12V',              'kfz','IEC,ANSI',2),
('kfz_lichtmaschine','Lichtmaschine (Generator)', 'kfz','IEC,ANSI',2),
('kfz_stecker_2',    'KFZ-Stecker 2-polig',       'kfz','IEC,ANSI',2),
('kfz_stecker_3',    'KFZ-Stecker 3-polig',       'kfz','IEC,ANSI',3),
('kfz_stecker_4',    'KFZ-Stecker 4-polig',       'kfz','IEC,ANSI',4))SQL",
            "DELETE FROM farb_definition WHERE bezeichnung LIKE '%DIN 72551%'",

            R"SQL(INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) VALUES
('#CC0000','Rot - DIN 72551 (rt)',     0, 100),
('#222222','Schwarz - DIN 72551 (sw)', 0, 101),
('#FFCC00','Gelb - DIN 72551 (ge)',    0, 102),
('#663300','Braun - DIN 72551 (br)',   0, 103),
('#0044CC','Blau - DIN 72551 (bl)',    0, 104),
('#228B22','Gruen - DIN 72551 (gn)',   0, 105),
('#888888','Grau - DIN 72551 (gr)',    0, 106),
('#EEEEEE','Weiss - DIN 72551 (ws)',   0, 107),
('#8B008B','Violett - DIN 72551 (vi)', 0, 108),
('#FF6600','Orange - DIN 72551 (or)',  0, 109))SQL",
        }},
        { 44, "Arduino: Boards (UNO/Nano/Mega) + Sensoren (DHT/HC-SR04/PIR)", {
            R"SQL(INSERT OR IGNORE INTO symbol_definition (id,name,kategorie,breite_mm,hoehe_mm,rolle,ist_builtin) VALUES
('ard_uno',   'Arduino UNO',    'Arduino',32,60,'variabel',1),
('ard_nano',  'Arduino Nano',   'Arduino',32,60,'variabel',1),
('ard_mega',  'Arduino Mega',   'Arduino',32,84,'variabel',1),
('ard_dht',   'DHT Sensor',     'Arduino',16,16,'variabel',1),
('ard_hcsr04','HC-SR04 Sensor', 'Arduino',16,20,'variabel',1),
('ard_pir',   'PIR Sensor',     'Arduino',16,16,'variabel',1))SQL",
            "DELETE FROM symbol_pin WHERE symbol_id IN ('ard_uno','ard_nano','ard_mega','ard_dht','ard_hcsr04','ard_pir')",
            R"SQL(INSERT INTO symbol_pin (symbol_id,name,x,y,offen_x,offen_y,signaltyp) VALUES
('ard_uno','D0',0,0.0667,-1,0,'neutral'),('ard_uno','D1',0,0.1333,-1,0,'neutral'),
('ard_uno','D2',0,0.2000,-1,0,'neutral'),('ard_uno','D3',0,0.2667,-1,0,'neutral'),
('ard_uno','D4',0,0.3333,-1,0,'neutral'),('ard_uno','D5',0,0.4000,-1,0,'neutral'),
('ard_uno','D6',0,0.4667,-1,0,'neutral'),('ard_uno','D7',0,0.5333,-1,0,'neutral'),
('ard_uno','D8',0,0.6000,-1,0,'neutral'),('ard_uno','D9',0,0.6667,-1,0,'neutral'),
('ard_uno','D10',0,0.7333,-1,0,'neutral'),('ard_uno','D11',0,0.8000,-1,0,'neutral'),
('ard_uno','D12',0,0.8667,-1,0,'neutral'),('ard_uno','D13',0,0.9333,-1,0,'neutral'),
('ard_uno','RST',1,0.0667,1,0,'neutral'),('ard_uno','3V3',1,0.1333,1,0,'neutral'),
('ard_uno','5V',1,0.2000,1,0,'neutral'),('ard_uno','GND',1,0.2667,1,0,'neutral'),
('ard_uno','GND2',1,0.3333,1,0,'neutral'),('ard_uno','Vin',1,0.4000,1,0,'neutral'),
('ard_uno','A0',1,0.5333,1,0,'neutral'),('ard_uno','A1',1,0.6000,1,0,'neutral'),
('ard_uno','A2',1,0.6667,1,0,'neutral'),('ard_uno','A3',1,0.7333,1,0,'neutral'),
('ard_uno','A4',1,0.8000,1,0,'neutral'),('ard_uno','A5',1,0.8667,1,0,'neutral'),
('ard_uno','AREF',1,0.9333,1,0,'neutral'),
('ard_nano','D0',0,0.0667,-1,0,'neutral'),('ard_nano','D1',0,0.1333,-1,0,'neutral'),
('ard_nano','D2',0,0.2000,-1,0,'neutral'),('ard_nano','D3',0,0.2667,-1,0,'neutral'),
('ard_nano','D4',0,0.3333,-1,0,'neutral'),('ard_nano','D5',0,0.4000,-1,0,'neutral'),
('ard_nano','D6',0,0.4667,-1,0,'neutral'),('ard_nano','D7',0,0.5333,-1,0,'neutral'),
('ard_nano','D8',0,0.6000,-1,0,'neutral'),('ard_nano','D9',0,0.6667,-1,0,'neutral'),
('ard_nano','D10',0,0.7333,-1,0,'neutral'),('ard_nano','D11',0,0.8000,-1,0,'neutral'),
('ard_nano','D12',0,0.8667,-1,0,'neutral'),('ard_nano','D13',0,0.9333,-1,0,'neutral'),
('ard_nano','RST',1,0.0667,1,0,'neutral'),('ard_nano','3V3',1,0.1333,1,0,'neutral'),
('ard_nano','5V',1,0.2000,1,0,'neutral'),('ard_nano','GND',1,0.2667,1,0,'neutral'),
('ard_nano','GND2',1,0.3333,1,0,'neutral'),('ard_nano','Vin',1,0.4000,1,0,'neutral'),
('ard_nano','A0',1,0.4667,1,0,'neutral'),('ard_nano','A1',1,0.5333,1,0,'neutral'),
('ard_nano','A2',1,0.6000,1,0,'neutral'),('ard_nano','A3',1,0.6667,1,0,'neutral'),
('ard_nano','A4',1,0.7333,1,0,'neutral'),('ard_nano','A5',1,0.8000,1,0,'neutral'),
('ard_nano','A6',1,0.8667,1,0,'neutral'),('ard_nano','A7',1,0.9333,1,0,'neutral'),
('ard_mega','D0',0,0.0476,-1,0,'neutral'),('ard_mega','D1',0,0.0952,-1,0,'neutral'),
('ard_mega','D2',0,0.1429,-1,0,'neutral'),('ard_mega','D3',0,0.1905,-1,0,'neutral'),
('ard_mega','D4',0,0.2381,-1,0,'neutral'),('ard_mega','D5',0,0.2857,-1,0,'neutral'),
('ard_mega','D6',0,0.3333,-1,0,'neutral'),('ard_mega','D7',0,0.3810,-1,0,'neutral'),
('ard_mega','D8',0,0.4286,-1,0,'neutral'),('ard_mega','D9',0,0.4762,-1,0,'neutral'),
('ard_mega','D10',0,0.5238,-1,0,'neutral'),('ard_mega','D11',0,0.5714,-1,0,'neutral'),
('ard_mega','D12',0,0.6190,-1,0,'neutral'),('ard_mega','D13',0,0.6667,-1,0,'neutral'),
('ard_mega','D14',0,0.7143,-1,0,'neutral'),('ard_mega','D15',0,0.7619,-1,0,'neutral'),
('ard_mega','D16',0,0.8095,-1,0,'neutral'),('ard_mega','D17',0,0.8571,-1,0,'neutral'),
('ard_mega','D18',0,0.9048,-1,0,'neutral'),('ard_mega','D19',0,0.9524,-1,0,'neutral'),
('ard_mega','RST',1,0.0476,1,0,'neutral'),('ard_mega','5V',1,0.0952,1,0,'neutral'),
('ard_mega','3V3',1,0.1429,1,0,'neutral'),('ard_mega','GND',1,0.1905,1,0,'neutral'),
('ard_mega','GND2',1,0.2381,1,0,'neutral'),('ard_mega','Vin',1,0.2857,1,0,'neutral'),
('ard_mega','A0',1,0.3333,1,0,'neutral'),('ard_mega','A1',1,0.3810,1,0,'neutral'),
('ard_mega','A2',1,0.4286,1,0,'neutral'),('ard_mega','A3',1,0.4762,1,0,'neutral'),
('ard_mega','A4',1,0.5238,1,0,'neutral'),('ard_mega','A5',1,0.5714,1,0,'neutral'),
('ard_mega','A6',1,0.6190,1,0,'neutral'),('ard_mega','A7',1,0.6667,1,0,'neutral'),
('ard_mega','A8',1,0.7143,1,0,'neutral'),('ard_mega','A9',1,0.7619,1,0,'neutral'),
('ard_mega','A10',1,0.8095,1,0,'neutral'),('ard_mega','A11',1,0.8571,1,0,'neutral'),
('ard_mega','A12',1,0.9048,1,0,'neutral'),('ard_mega','A13',1,0.9524,1,0,'neutral'),
('ard_dht','VCC',0,0.25,-1,0,'neutral'),('ard_dht','DATA',0,0.50,-1,0,'neutral'),
('ard_dht','GND',0,0.75,-1,0,'neutral'),
('ard_hcsr04','VCC',0,0.20,-1,0,'neutral'),('ard_hcsr04','TRIG',0,0.40,-1,0,'neutral'),
('ard_hcsr04','ECHO',0,0.60,-1,0,'neutral'),('ard_hcsr04','GND',0,0.80,-1,0,'neutral'),
('ard_pir','VCC',0,0.25,-1,0,'neutral'),('ard_pir','OUT',0,0.50,-1,0,'neutral'),
('ard_pir','GND',0,0.75,-1,0,'neutral'))SQL",
            "DELETE FROM symbol_primitiv WHERE symbol_id IN ('ard_uno','ard_nano','ard_mega','ard_dht','ard_hcsr04','ard_pir')",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('ard_uno',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',1,'text',0.5,0.43,0,0,0,0,0,0,0,0,'Arduino',0.055,0,'center','middle','solid'),
('ard_uno',2,'text',0.5,0.55,0,0,0,0,0,0,0,0,'UNO',0.09,1,'center','middle','solid'),
('ard_uno',3,'linie',0,0.0667,0.15,0.0667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',4,'linie',0,0.1333,0.15,0.1333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',5,'linie',0,0.2000,0.15,0.2000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',6,'linie',0,0.2667,0.15,0.2667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',7,'linie',0,0.3333,0.15,0.3333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',8,'linie',0,0.4000,0.15,0.4000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',9,'linie',0,0.4667,0.15,0.4667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',10,'linie',0,0.5333,0.15,0.5333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',11,'linie',0,0.6000,0.15,0.6000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',12,'linie',0,0.6667,0.15,0.6667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',13,'linie',0,0.7333,0.15,0.7333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',14,'linie',0,0.8000,0.15,0.8000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',15,'linie',0,0.8667,0.15,0.8667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',16,'linie',0,0.9333,0.15,0.9333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',17,'linie',0.85,0.0667,1.0,0.0667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',18,'linie',0.85,0.1333,1.0,0.1333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',19,'linie',0.85,0.2000,1.0,0.2000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',20,'linie',0.85,0.2667,1.0,0.2667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',21,'linie',0.85,0.3333,1.0,0.3333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',22,'linie',0.85,0.4000,1.0,0.4000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',23,'linie',0.85,0.5333,1.0,0.5333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',24,'linie',0.85,0.6000,1.0,0.6000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',25,'linie',0.85,0.6667,1.0,0.6667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',26,'linie',0.85,0.7333,1.0,0.7333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',27,'linie',0.85,0.8000,1.0,0.8000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',28,'linie',0.85,0.8667,1.0,0.8667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_uno',29,'linie',0.85,0.9333,1.0,0.9333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',1,'text',0.5,0.43,0,0,0,0,0,0,0,0,'Arduino',0.055,0,'center','middle','solid'),
('ard_nano',2,'text',0.5,0.55,0,0,0,0,0,0,0,0,'NANO',0.09,1,'center','middle','solid'),
('ard_nano',3,'linie',0,0.0667,0.15,0.0667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',4,'linie',0,0.1333,0.15,0.1333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',5,'linie',0,0.2000,0.15,0.2000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',6,'linie',0,0.2667,0.15,0.2667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',7,'linie',0,0.3333,0.15,0.3333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',8,'linie',0,0.4000,0.15,0.4000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',9,'linie',0,0.4667,0.15,0.4667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',10,'linie',0,0.5333,0.15,0.5333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',11,'linie',0,0.6000,0.15,0.6000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',12,'linie',0,0.6667,0.15,0.6667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',13,'linie',0,0.7333,0.15,0.7333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',14,'linie',0,0.8000,0.15,0.8000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',15,'linie',0,0.8667,0.15,0.8667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',16,'linie',0,0.9333,0.15,0.9333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',17,'linie',0.85,0.0667,1.0,0.0667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',18,'linie',0.85,0.1333,1.0,0.1333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',19,'linie',0.85,0.2000,1.0,0.2000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',20,'linie',0.85,0.2667,1.0,0.2667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',21,'linie',0.85,0.3333,1.0,0.3333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',22,'linie',0.85,0.4000,1.0,0.4000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',23,'linie',0.85,0.4667,1.0,0.4667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',24,'linie',0.85,0.5333,1.0,0.5333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',25,'linie',0.85,0.6000,1.0,0.6000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',26,'linie',0.85,0.6667,1.0,0.6667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',27,'linie',0.85,0.7333,1.0,0.7333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',28,'linie',0.85,0.8000,1.0,0.8000,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',29,'linie',0.85,0.8667,1.0,0.8667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_nano',30,'linie',0.85,0.9333,1.0,0.9333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',0,'rechteck',0.15,0.02,0.85,0.98,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',1,'text',0.5,0.44,0,0,0,0,0,0,0,0,'Arduino',0.055,0,'center','middle','solid'),
('ard_mega',2,'text',0.5,0.54,0,0,0,0,0,0,0,0,'MEGA',0.075,1,'center','middle','solid'),
('ard_mega',3,'linie',0,0.0476,0.15,0.0476,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',4,'linie',0,0.0952,0.15,0.0952,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',5,'linie',0,0.1429,0.15,0.1429,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',6,'linie',0,0.1905,0.15,0.1905,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',7,'linie',0,0.2381,0.15,0.2381,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',8,'linie',0,0.2857,0.15,0.2857,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',9,'linie',0,0.3333,0.15,0.3333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',10,'linie',0,0.3810,0.15,0.3810,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',11,'linie',0,0.4286,0.15,0.4286,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',12,'linie',0,0.4762,0.15,0.4762,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',13,'linie',0,0.5238,0.15,0.5238,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',14,'linie',0,0.5714,0.15,0.5714,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',15,'linie',0,0.6190,0.15,0.6190,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',16,'linie',0,0.6667,0.15,0.6667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',17,'linie',0,0.7143,0.15,0.7143,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',18,'linie',0,0.7619,0.15,0.7619,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',19,'linie',0,0.8095,0.15,0.8095,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',20,'linie',0,0.8571,0.15,0.8571,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',21,'linie',0,0.9048,0.15,0.9048,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',22,'linie',0,0.9524,0.15,0.9524,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',23,'linie',0.85,0.0476,1.0,0.0476,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',24,'linie',0.85,0.0952,1.0,0.0952,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',25,'linie',0.85,0.1429,1.0,0.1429,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',26,'linie',0.85,0.1905,1.0,0.1905,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',27,'linie',0.85,0.2381,1.0,0.2381,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',28,'linie',0.85,0.2857,1.0,0.2857,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',29,'linie',0.85,0.3333,1.0,0.3333,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',30,'linie',0.85,0.3810,1.0,0.3810,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',31,'linie',0.85,0.4286,1.0,0.4286,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',32,'linie',0.85,0.4762,1.0,0.4762,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',33,'linie',0.85,0.5238,1.0,0.5238,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',34,'linie',0.85,0.5714,1.0,0.5714,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',35,'linie',0.85,0.6190,1.0,0.6190,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',36,'linie',0.85,0.6667,1.0,0.6667,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',37,'linie',0.85,0.7143,1.0,0.7143,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',38,'linie',0.85,0.7619,1.0,0.7619,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',39,'linie',0.85,0.8095,1.0,0.8095,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',40,'linie',0.85,0.8571,1.0,0.8571,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',41,'linie',0.85,0.9048,1.0,0.9048,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_mega',42,'linie',0.85,0.9524,1.0,0.9524,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_dht',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_dht',1,'text',0.5,0.15,0,0,0,0,0,0,0,0,'DHT',0.15,1,'center','middle','solid'),
('ard_dht',2,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_dht',3,'linie',0,0.50,0.15,0.50,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_dht',4,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_dht',5,'text',0.2,0.25,0,0,0,0,0,0,0,0,'VCC', 0.11,0,'left','middle','solid'),
('ard_dht',6,'text',0.2,0.50,0,0,0,0,0,0,0,0,'DATA',0.11,0,'left','middle','solid'),
('ard_dht',7,'text',0.2,0.75,0,0,0,0,0,0,0,0,'GND', 0.11,0,'left','middle','solid'),
('ard_hcsr04',0,'rechteck',0.15,0.03,0.85,0.97,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_hcsr04',1,'text',0.5,0.12,0,0,0,0,0,0,0,0,'HC-SR04',0.10,1,'center','middle','solid'),
('ard_hcsr04',2,'linie',0,0.20,0.15,0.20,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_hcsr04',3,'linie',0,0.40,0.15,0.40,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_hcsr04',4,'linie',0,0.60,0.15,0.60,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_hcsr04',5,'linie',0,0.80,0.15,0.80,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_hcsr04',6,'text',0.2,0.20,0,0,0,0,0,0,0,0,'VCC', 0.09,0,'left','middle','solid'),
('ard_hcsr04',7,'text',0.2,0.40,0,0,0,0,0,0,0,0,'TRIG',0.09,0,'left','middle','solid'),
('ard_hcsr04',8,'text',0.2,0.60,0,0,0,0,0,0,0,0,'ECHO',0.09,0,'left','middle','solid'),
('ard_hcsr04',9,'text',0.2,0.80,0,0,0,0,0,0,0,0,'GND', 0.09,0,'left','middle','solid'),
('ard_pir',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_pir',1,'text',0.5,0.15,0,0,0,0,0,0,0,0,'PIR',0.15,1,'center','middle','solid'),
('ard_pir',2,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_pir',3,'linie',0,0.50,0.15,0.50,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_pir',4,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('ard_pir',5,'text',0.2,0.25,0,0,0,0,0,0,0,0,'VCC',0.11,0,'left','middle','solid'),
('ard_pir',6,'text',0.2,0.50,0,0,0,0,0,0,0,0,'OUT',0.11,0,'left','middle','solid'),
('ard_pir',7,'text',0.2,0.75,0,0,0,0,0,0,0,0,'GND',0.11,0,'left','middle','solid'))SQL",
            R"SQL(INSERT OR IGNORE INTO symbol (code,name,kategorie_pfad,norm,anschluesse) VALUES
('ard_uno',   'Arduino UNO',    'arduino','IEC,ANSI',27),
('ard_nano',  'Arduino Nano',   'arduino','IEC,ANSI',28),
('ard_mega',  'Arduino Mega',   'arduino','IEC,ANSI',40),
('ard_dht',   'DHT Sensor',     'arduino','IEC,ANSI', 3),
('ard_hcsr04','HC-SR04 Sensor', 'arduino','IEC,ANSI', 4),
('ard_pir',   'PIR Sensor',     'arduino','IEC,ANSI', 3))SQL",
            R"SQL(UPDATE symbol SET norm='IEC,ANSI' WHERE kategorie_pfad='arduino' AND (norm IS NULL OR norm=''))SQL",
        }},
        { 45, "SPS-GRID-01: Pin-Positionen auf 4mm-Raster korrigiert (SPS hoehe_mm, KFZ y-Werte)", {
            // SPS/PLS: hoehe_mm anpassen damit k/(N+1)*hoehe_mm ein Vielfaches von 4mm ergibt
            "UPDATE symbol_definition SET hoehe_mm=72  WHERE id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8')",
            "UPDATE symbol_definition SET hoehe_mm=136 WHERE id IN ('sps_di_16','sps_do_16')",
            "UPDATE symbol_definition SET hoehe_mm=40  WHERE id IN ('sps_ai_4','sps_ao_4','pls_ao_4')",
            // kfz_stecker_2 (32mm): 0.33/0.67 -> 0.25/0.75 (8mm/24mm)
            "UPDATE symbol_pin SET y=0.25 WHERE symbol_id='kfz_stecker_2' AND name='1'",
            "UPDATE symbol_pin SET y=0.75 WHERE symbol_id='kfz_stecker_2' AND name='2'",
            "UPDATE symbol_primitiv SET y1=0.25        WHERE symbol_id='kfz_stecker_2' AND reihenfolge=1",
            "UPDATE symbol_primitiv SET y1=0.75        WHERE symbol_id='kfz_stecker_2' AND reihenfolge=2",
            "UPDATE symbol_primitiv SET y1=0.25,y2=0.25 WHERE symbol_id='kfz_stecker_2' AND reihenfolge=3",
            "UPDATE symbol_primitiv SET y1=0.75,y2=0.75 WHERE symbol_id='kfz_stecker_2' AND reihenfolge=4",
            // kfz_stecker_4 (64mm): 0.2/0.4/0.6/0.8 -> 0.1875/0.375/0.5625/0.75 (12/24/36/48mm)
            "UPDATE symbol_pin SET y=0.1875 WHERE symbol_id='kfz_stecker_4' AND name='1'",
            "UPDATE symbol_pin SET y=0.375  WHERE symbol_id='kfz_stecker_4' AND name='2'",
            "UPDATE symbol_pin SET y=0.5625 WHERE symbol_id='kfz_stecker_4' AND name='3'",
            "UPDATE symbol_pin SET y=0.75   WHERE symbol_id='kfz_stecker_4' AND name='4'",
            "UPDATE symbol_primitiv SET y1=0.1875          WHERE symbol_id='kfz_stecker_4' AND reihenfolge=1",
            "UPDATE symbol_primitiv SET y1=0.375           WHERE symbol_id='kfz_stecker_4' AND reihenfolge=2",
            "UPDATE symbol_primitiv SET y1=0.5625          WHERE symbol_id='kfz_stecker_4' AND reihenfolge=3",
            "UPDATE symbol_primitiv SET y1=0.75            WHERE symbol_id='kfz_stecker_4' AND reihenfolge=4",
            "UPDATE symbol_primitiv SET y1=0.1875,y2=0.1875 WHERE symbol_id='kfz_stecker_4' AND reihenfolge=5",
            "UPDATE symbol_primitiv SET y1=0.375, y2=0.375  WHERE symbol_id='kfz_stecker_4' AND reihenfolge=6",
            "UPDATE symbol_primitiv SET y1=0.5625,y2=0.5625 WHERE symbol_id='kfz_stecker_4' AND reihenfolge=7",
            "UPDATE symbol_primitiv SET y1=0.75,  y2=0.75   WHERE symbol_id='kfz_stecker_4' AND reihenfolge=8",
            // kfz_relais_5 (64mm): Pins auf 4mm-Raster: 85/86=16mm, 87=36mm, 30=44mm, 87a=56mm
            "UPDATE symbol_pin SET y=0.25   WHERE symbol_id='kfz_relais_5' AND name='85'",
            "UPDATE symbol_pin SET y=0.25   WHERE symbol_id='kfz_relais_5' AND name='86'",
            "UPDATE symbol_pin SET y=0.5625 WHERE symbol_id='kfz_relais_5' AND name='87'",
            "UPDATE symbol_pin SET y=0.6875 WHERE symbol_id='kfz_relais_5' AND name='30'",
            "UPDATE symbol_pin SET y=0.875  WHERE symbol_id='kfz_relais_5' AND name='87a'",
            "UPDATE symbol_primitiv SET y1=0.375, y2=0.375   WHERE symbol_id='kfz_relais_5' AND reihenfolge=1",
            "UPDATE symbol_primitiv SET y1=0.1875             WHERE symbol_id='kfz_relais_5' AND reihenfolge=2",
            "UPDATE symbol_primitiv SET y1=0.6875             WHERE symbol_id='kfz_relais_5' AND reihenfolge=3",
            "UPDATE symbol_primitiv SET y1=0.25,  y2=0.25    WHERE symbol_id='kfz_relais_5' AND reihenfolge=4",
            "UPDATE symbol_primitiv SET y1=0.25,  y2=0.25    WHERE symbol_id='kfz_relais_5' AND reihenfolge=5",
            "UPDATE symbol_primitiv SET y1=0.6875,y2=0.6875  WHERE symbol_id='kfz_relais_5' AND reihenfolge=6",
            "UPDATE symbol_primitiv SET y1=0.5625,y2=0.5625  WHERE symbol_id='kfz_relais_5' AND reihenfolge=7",
            "UPDATE symbol_primitiv SET y1=0.875, y2=0.875   WHERE symbol_id='kfz_relais_5' AND reihenfolge=8",
        }},
        { 46, "Sensoren: 6 Industriesensoren (induktiv/kapazitiv/optisch/ultraschall/druck/temp)", {
            R"SQL(INSERT OR IGNORE INTO symbol_definition (id,name,kategorie,breite_mm,hoehe_mm,rolle,ist_builtin) VALUES
('sensor_induktiv',   'Induktiver Näherungsschalter',  'Sensoren',32,16,'variabel',1),
('sensor_kapazitiv',  'Kapazitiver Näherungsschalter', 'Sensoren',32,16,'variabel',1),
('sensor_optisch',    'Optischer Sensor',              'Sensoren',32,16,'variabel',1),
('sensor_ultraschall','Ultraschallsensor',             'Sensoren',32,16,'variabel',1),
('sensor_druck',      'Drucksensor',                   'Sensoren',32,16,'variabel',1),
('sensor_temp',       'Temperatursensor (PT100)',       'Sensoren',16,16,'variabel',1))SQL",
            "DELETE FROM symbol_pin WHERE symbol_id IN ('sensor_induktiv','sensor_kapazitiv','sensor_optisch','sensor_ultraschall','sensor_druck','sensor_temp')",
            R"SQL(INSERT INTO symbol_pin (symbol_id,name,x,y,offen_x,offen_y,signaltyp) VALUES
('sensor_induktiv','L+',0,0.25,-1,0,'power'),('sensor_induktiv','M',0,0.75,-1,0,'power'),('sensor_induktiv','Q',1,0.5,1,0,'neutral'),
('sensor_kapazitiv','L+',0,0.25,-1,0,'power'),('sensor_kapazitiv','M',0,0.75,-1,0,'power'),('sensor_kapazitiv','Q',1,0.5,1,0,'neutral'),
('sensor_optisch','L+',0,0.25,-1,0,'power'),('sensor_optisch','M',0,0.75,-1,0,'power'),('sensor_optisch','Q',1,0.5,1,0,'neutral'),
('sensor_ultraschall','L+',0,0.25,-1,0,'power'),('sensor_ultraschall','M',0,0.75,-1,0,'power'),('sensor_ultraschall','Q',1,0.5,1,0,'neutral'),
('sensor_druck','L+',0,0.25,-1,0,'power'),('sensor_druck','M',0,0.75,-1,0,'power'),('sensor_druck','Q',1,0.5,1,0,'neutral'),
('sensor_temp','1',0,0.5,-1,0,'neutral'),('sensor_temp','2',1,0.5,1,0,'neutral'))SQL",
            "DELETE FROM symbol_primitiv WHERE symbol_id IN ('sensor_induktiv','sensor_kapazitiv','sensor_optisch','sensor_ultraschall','sensor_druck','sensor_temp')",
            R"SQL(INSERT INTO symbol_primitiv (symbol_id,reihenfolge,typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,text_align,text_baseline,linienart) VALUES
('sensor_induktiv',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_induktiv',1,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_induktiv',2,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_induktiv',3,'linie',0.85,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_induktiv',4,'text',0.5,0.22,0,0,0,0,0,0,0,0,'IND',0.16,1,'center','middle','solid'),
('sensor_induktiv',5,'bogen',0.33,0.70,0,0,0,0,0.065,180,360,0,NULL,0.5,0,'center','middle','solid'),
('sensor_induktiv',6,'bogen',0.46,0.70,0,0,0,0,0.065,180,360,0,NULL,0.5,0,'center','middle','solid'),
('sensor_induktiv',7,'bogen',0.59,0.70,0,0,0,0,0.065,180,360,0,NULL,0.5,0,'center','middle','solid'),
('sensor_kapazitiv',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_kapazitiv',1,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_kapazitiv',2,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_kapazitiv',3,'linie',0.85,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_kapazitiv',4,'text',0.5,0.22,0,0,0,0,0,0,0,0,'CAP',0.16,1,'center','middle','solid'),
('sensor_kapazitiv',5,'linie',0.25,0.57,0.75,0.57,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_kapazitiv',6,'linie',0.25,0.71,0.75,0.71,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',1,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',2,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',3,'linie',0.85,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',4,'text',0.5,0.22,0,0,0,0,0,0,0,0,'OPT',0.16,1,'center','middle','solid'),
('sensor_optisch',5,'kreis',0.36,0.67,0,0,0,0,0.06,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',6,'linie',0.43,0.57,0.65,0.47,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',7,'linie',0.43,0.67,0.65,0.67,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_optisch',8,'linie',0.43,0.77,0.65,0.87,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',1,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',2,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',3,'linie',0.85,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',4,'text',0.5,0.22,0,0,0,0,0,0,0,0,'ULT',0.16,1,'center','middle','solid'),
('sensor_ultraschall',5,'bogen',0.50,0.65,0,0,0,0,0.05,270,90,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',6,'bogen',0.47,0.65,0,0,0,0,0.09,270,90,0,NULL,0.5,0,'center','middle','solid'),
('sensor_ultraschall',7,'bogen',0.44,0.65,0,0,0,0,0.13,270,90,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',0,'rechteck',0.15,0.05,0.85,0.95,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',1,'linie',0,0.25,0.15,0.25,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',2,'linie',0,0.75,0.15,0.75,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',3,'linie',0.85,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',4,'text',0.5,0.20,0,0,0,0,0,0,0,0,'DRUCK',0.11,1,'center','middle','solid'),
('sensor_druck',5,'linie',0.50,0.38,0.37,0.80,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',6,'linie',0.50,0.38,0.63,0.80,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_druck',7,'linie',0.37,0.80,0.63,0.80,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_temp',0,'rechteck',0.1,0.1,0.9,0.9,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_temp',1,'linie',0,0.5,0.1,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_temp',2,'linie',0.9,0.5,1.0,0.5,0,0,0,0,0,0,NULL,0.5,0,'center','middle','solid'),
('sensor_temp',3,'text',0.5,0.35,0,0,0,0,0,0,0,0,'PT',0.22,1,'center','middle','solid'),
('sensor_temp',4,'text',0.5,0.65,0,0,0,0,0,0,0,0,'100',0.18,0,'center','middle','solid'))SQL",
            R"SQL(INSERT OR IGNORE INTO symbol (code,name,kategorie_pfad,norm,anschluesse) VALUES
('sensor_induktiv',   'Induktiver Näherungsschalter',  'sensoren','IEC,ANSI',3),
('sensor_kapazitiv',  'Kapazitiver Näherungsschalter', 'sensoren','IEC,ANSI',3),
('sensor_optisch',    'Optischer Sensor',              'sensoren','IEC,ANSI',3),
('sensor_ultraschall','Ultraschallsensor',             'sensoren','IEC,ANSI',3),
('sensor_druck',      'Drucksensor',                   'sensoren','IEC,ANSI',3),
('sensor_temp',       'Temperatursensor (PT100)',       'sensoren','IEC,ANSI',2))SQL",
        }},
        { 47, "D-01: Indices auf häufig gefilterte Spalten", {
            "CREATE INDEX IF NOT EXISTS idx_grafik_element_seite ON grafik_element(seite_id)",
            "CREATE INDEX IF NOT EXISTS idx_verbindung_segment_seite ON verbindung_segment(seite_id)",
        }},
        { 48, "M6: Revisionsmarker / Freigabestempel pro Seite", {
            "ALTER TABLE seite ADD COLUMN revision_status  TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE seite ADD COLUMN revision_kennung TEXT NOT NULL DEFAULT ''",
        }},
    };
}

Database::Database(QObject *parent)
    : QObject(parent)
{
}

bool Database::open(const QString &path)
{
    return openProjekt(path);
}

void Database::close()
{
    m_db.close();
    if (m_wikiDb.isValid())    m_wikiDb.close();
    if (m_launcherDb.isValid()) m_launcherDb.close();
}

// ============================================================
// openLauncher
// Öffnet oder legt die Launcher-DB an (stroemling.db).
// Diese Datei enthält nur die zuletzt_geoeffnet-Tabelle –
// keine Projektdaten.
// ============================================================
bool Database::openLauncher(const QString &path)
{
    m_launcherDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_launcher");
    m_launcherDb.setDatabaseName(path);
    if (!m_launcherDb.open()) {
        qWarning() << "Launcher-DB konnte nicht geöffnet werden:" << m_launcherDb.lastError().text();
        return false;
    }
    {
        QSqlQuery q(m_launcherDb);
        q.exec("PRAGMA journal_mode = WAL");
        if (!q.exec(R"(
            CREATE TABLE IF NOT EXISTS zuletzt_geoeffnet (
                id           INTEGER PRIMARY KEY,
                pfad         TEXT NOT NULL UNIQUE,
                name         TEXT NOT NULL DEFAULT '',
                geoeffnet_am TEXT NOT NULL DEFAULT (datetime('now'))
            )
        )")) {
            qWarning() << "zuletzt_geoeffnet Tabelle:" << q.lastError().text();
        }
    }
    qInfo() << "Launcher-DB geöffnet:" << path;

    // Alte stroemling.db-Pfade (vor R7) als Projekte anbieten.
    // Vor R7: org="Strömling Design", jetzt org="stroemling" → anderer XDG-Pfad.
    // Basis-Verzeichnis ableiten: ein Ebene über dem aktuellen dataDir.
    QString basedir = QFileInfo(path).absolutePath(); // z.B. ~/.local/share/stroemling/Strömling Design
    QDir parentDir(basedir);
    parentDir.cdUp(); // ~/.local/share/stroemling
    parentDir.cdUp(); // ~/.local/share
    const QString altPfad = parentDir.filePath(
        "Strömling Design/Strömling Design/stroemling.db");
    if (QFile::exists(altPfad)) {
        QSqlQuery qCheck(m_launcherDb);
        qCheck.prepare("SELECT COUNT(*) FROM zuletzt_geoeffnet WHERE pfad = :p");
        qCheck.bindValue(":p", altPfad);
        if (qCheck.exec() && qCheck.next() && qCheck.value(0).toInt() == 0) {
            zuletzGeoeffnetEintragen(altPfad, "Bisheriges Projekt (vor R7)");
            qInfo() << "Altes Projekt in zuletzt_geoeffnet eingetragen:" << altPfad;
        }
    }

    return true;
}

// ============================================================
// openProjekt
// Öffnet eine existierende .stroemling-Projektdatei und führt
// ggf. ausstehende Migrationen aus.
// ============================================================
bool Database::openProjekt(const QString &path)
{
    // Bestehende Projektverbindung trennen
    if (m_projektOffen || m_db.isOpen()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        m_projektOffen = false;
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(path);
    if (!m_db.open()) {
        qWarning() << "Projekt konnte nicht geöffnet werden:" << m_db.lastError().text();
        emit projektOffenChanged();
        return false;
    }
    {
        QSqlQuery pragma;
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA busy_timeout = 5000");
        pragma.exec("PRAGMA journal_mode = WAL");
    }

    if (!checkAndApplySchema()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        emit projektOffenChanged();
        return false;
    }

    m_projektOffen = true;

    QString projektName;
    {
        QSqlQuery q;
        if (q.exec("SELECT name FROM projekt LIMIT 1") && q.next())
            projektName = q.value(0).toString();
    }
    if (projektName.isEmpty())
        projektName = QFileInfo(path).baseName();

    zuletzGeoeffnetEintragen(path, projektName);
    qInfo() << "Projekt geöffnet:" << path;
    emit projektOffenChanged();
    return true;
}

// ============================================================
// createProjekt
// Legt eine neue leere Projektdatei an (ohne Beispieldaten).
// ============================================================
bool Database::createProjekt(const QString &path, const QString &projektName)
{
    if (QFile::exists(path)) {
        qWarning() << "Projektdatei existiert bereits:" << path;
        return false;
    }

    // Bestehende Projektverbindung trennen
    if (m_projektOffen || m_db.isOpen()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        m_projektOffen = false;
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(path);
    if (!m_db.open()) {
        qWarning() << "Projektdatei konnte nicht erstellt werden:" << m_db.lastError().text();
        return false;
    }
    {
        QSqlQuery pragma;
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA journal_mode = WAL");
    }

    // schema_migration-Tabelle anlegen (außerhalb der Transaktion)
    {
        QSqlQuery q;
        if (!q.exec("CREATE TABLE IF NOT EXISTS schema_migration ("
                    "version INTEGER PRIMARY KEY, beschreibung TEXT NOT NULL, "
                    "angewendet_am TEXT NOT NULL DEFAULT (datetime('now')))")) {
            qWarning() << "schema_migration für neues Projekt:" << q.lastError().text();
            m_db.close(); m_db = QSqlDatabase();
            QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
            QFile::remove(path);
            return false;
        }
    }

    if (!m_db.transaction()) {
        qWarning() << "Transaktion für neues Projekt fehlgeschlagen";
        m_db.close(); m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        QFile::remove(path);
        return false;
    }

    // Schema + Seeds (inkl. Beispielprojekt für Einsteiger)
    bool ok = createSchema()
           && seedSymbolKatalog()
           && seedBuiltinSymbolDefinitionen()
           && seedIbnFeldvorlagen()
           && seedExampleData();

    if (ok) {
        // Projektzeile mit Nutzernamen anlegen
        QSqlQuery qp;
        qp.prepare("INSERT INTO projekt (name) VALUES (:n)");
        qp.bindValue(":n", projektName.isEmpty() ? QFileInfo(path).baseName() : projektName);
        ok = qp.exec();
        if (!ok)
            qWarning() << "Projekt-Eintrag anlegen:" << qp.lastError().text();
    }

    if (ok) {
        // Baseline-Version eintragen
        QSqlQuery qm;
        qm.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :d)");
        qm.bindValue(":v", BASELINE_VERSION);
        qm.bindValue(":d", QString("Baseline v%1 – neues Projekt").arg(BASELINE_VERSION));
        ok = qm.exec();
    }

    if (!ok || !m_db.commit()) {
        m_db.rollback();
        m_db.close(); m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        QFile::remove(path);
        return false;
    }

    m_projektOffen = true;
    QString name = projektName.isEmpty() ? QFileInfo(path).baseName() : projektName;
    zuletzGeoeffnetEintragen(path, name);
    qInfo() << "Neues Projekt erstellt:" << path;
    emit projektOffenChanged();
    return true;
}

// ============================================================
// closeProjekt
// Schließt die aktuelle Projektdatei.
// ============================================================
void Database::closeProjekt()
{
    if (!m_projektOffen) return;
    m_db.close();
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
    m_projektOffen = false;
    qInfo() << "Projekt geschlossen.";
    emit projektOffenChanged();
}

bool Database::projektExportieren(const QString &destPfad)
{
    const QString localPfad = QUrl(destPfad).isLocalFile() ? QUrl(destPfad).toLocalFile() : destPfad;

    if (!m_projektOffen) {
        qWarning() << "projektExportieren: kein Projekt geöffnet";
        return false;
    }

    // VACUUM INTO schlägt fehl wenn die Zieldatei bereits existiert
    if (QFile::exists(localPfad) && !QFile::remove(localPfad)) {
        qWarning() << "projektExportieren: Zieldatei konnte nicht gelöscht werden:" << localPfad;
        return false;
    }

    QString escaped = localPfad;
    escaped.replace("'", "''");
    QSqlQuery q;
    if (!q.exec("VACUUM INTO '" + escaped + "'")) {
        qWarning() << "projektExportieren:" << q.lastError().text();
        return false;
    }
    qInfo() << "Projekt exportiert nach:" << localPfad;
    return true;
}

QString Database::projektPfad() const
{
    return m_db.isOpen() ? m_db.databaseName() : QString();
}

// ============================================================
// zuletzGeoeffnete
// Gibt die zuletzt geöffneten Projekte aus der Launcher-DB zurück.
// ============================================================
QVariantList Database::zuletzGeoeffnete() const
{
    QVariantList list;
    if (!m_launcherDb.isOpen()) return list;
    QSqlQuery q(m_launcherDb);
    if (!q.exec("SELECT pfad, name, geoeffnet_am FROM zuletzt_geoeffnet "
                "ORDER BY geoeffnet_am DESC LIMIT 10"))
        return list;
    while (q.next()) {
        QString pfad = q.value(0).toString();
        if (QFile::exists(pfad)) {
            list.append(QVariantMap{
                { "pfad",        pfad },
                { "name",        q.value(1).toString() },
                { "geoeffnetAm", q.value(2).toString() },
            });
        }
    }
    return list;
}

// ============================================================
// ersteProjektInfo
// Gibt id + name des ersten Projekts der geöffneten DB zurück.
// ============================================================
QVariantMap Database::ersteProjektInfo() const
{
    QVariantMap m;
    if (!m_projektOffen) return m;
    QSqlQuery q;
    if (q.exec("SELECT id, name FROM projekt LIMIT 1") && q.next()) {
        m["id"]   = q.value(0).toInt();
        m["name"] = q.value(1).toString();
    }
    return m;
}

// ============================================================
// zuletzGeoeffnetEintragen (privat)
// ============================================================
void Database::zuletzGeoeffnetEintragen(const QString &path, const QString &name)
{
    if (!m_launcherDb.isOpen()) return;
    QSqlQuery q(m_launcherDb);
    q.prepare(R"(
        INSERT INTO zuletzt_geoeffnet (pfad, name, geoeffnet_am)
        VALUES (:p, :n, datetime('now'))
        ON CONFLICT(pfad) DO UPDATE SET name = :n, geoeffnet_am = datetime('now')
    )");
    q.bindValue(":p", path);
    q.bindValue(":n", name);
    q.exec();
}

bool Database::openWiki(const QString &path)
{
    m_wikiDb = QSqlDatabase::addDatabase("QSQLITE", "stroemling_wiki");
    m_wikiDb.setDatabaseName(path);
    if (!m_wikiDb.open()) {
        qWarning() << "Wiki-Datenbank konnte nicht geöffnet werden:" << m_wikiDb.lastError().text();
        return false;
    }
    {
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA foreign_keys = ON");
        pragma.exec("PRAGMA journal_mode = WAL");
    }
    qInfo() << "Wiki-Datenbank geöffnet:" << path;
    return checkAndApplyWikiSchema();
}

bool Database::checkAndApplyWikiSchema()
{
    int storedVersion = -1;
    {
        QSqlQuery q(m_wikiDb);
        if (!q.exec("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")) {
            qWarning() << "wiki schema_version anlegen:" << q.lastError().text();
            return false;
        }
        if (q.exec("SELECT version FROM schema_version LIMIT 1") && q.next())
            storedVersion = q.value(0).toInt();
    }

    if (storedVersion == WIKI_SCHEMA_VERSION) {
        qInfo() << "Wiki-Schema bereits auf Version" << WIKI_SCHEMA_VERSION << "– keine Änderung.";
        return true;
    }

    qInfo() << "Wiki-Schema:" << storedVersion << "→" << WIKI_SCHEMA_VERSION;

    // Backup vor Wiki-Migration (nur wenn DB bereits Daten hat)
    if (storedVersion >= 0)
        erstelleBackup("stroemling_wiki", "wiki", storedVersion);

    if (!m_wikiDb.transaction()) {
        qWarning() << "Wiki-Transaktion konnte nicht gestartet werden:" << m_wikiDb.lastError().text();
        return false;
    }

    // Inkrementelle Spalten-Migrationen (einmalig je Version)
    if (storedVersion >= 1 && storedVersion < 3) {
        bool hatIstSystem = false;
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA table_info(wiki_artikel)");
        while (pragma.next()) {
            if (pragma.value(1).toString() == "ist_system") { hatIstSystem = true; break; }
        }
        if (!hatIstSystem) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_artikel ADD COLUMN ist_system INTEGER NOT NULL DEFAULT 0")) {
                qWarning() << "ALTER TABLE wiki_artikel ADD ist_system:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
    }

    if (!createWikiSchema() || !seedWikiStarterInhalte()) {
        m_wikiDb.rollback();
        return false;
    }

    // Alte Zeile löschen, damit LIMIT-1-Abfrage beim nächsten Start korrekt ist
    QSqlQuery del(m_wikiDb);
    del.exec("DELETE FROM schema_version");
    QSqlQuery ins(m_wikiDb);
    ins.prepare("INSERT INTO schema_version (version) VALUES (:v)");
    ins.bindValue(":v", WIKI_SCHEMA_VERSION);
    if (!ins.exec()) {
        qWarning() << "wiki schema_version schreiben:" << ins.lastError().text();
        m_wikiDb.rollback();
        return false;
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        return false;
    }

    qInfo() << "Wiki-Schema v" << WIKI_SCHEMA_VERSION << "erfolgreich angelegt.";
    return true;
}

bool Database::createWikiSchema()
{
    QSqlQuery q(m_wikiDb);

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_kategorie (
            id           INTEGER PRIMARY KEY,
            name         TEXT    NOT NULL UNIQUE,
            beschreibung TEXT    NOT NULL DEFAULT '',
            sortierung   INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler wiki_kategorie:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_artikel (
            id           INTEGER PRIMARY KEY,
            kategorie_id INTEGER NOT NULL REFERENCES wiki_kategorie(id) ON DELETE RESTRICT,
            titel        TEXT    NOT NULL,
            inhalt       TEXT    NOT NULL DEFAULT '',
            tags         TEXT    NOT NULL DEFAULT '',
            ist_system   INTEGER NOT NULL DEFAULT 0,
            erstellt_am  TEXT    NOT NULL DEFAULT (datetime('now')),
            geaendert_am TEXT    NOT NULL DEFAULT (datetime('now'))
        )
    )")) {
        qWarning() << "Fehler wiki_artikel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_bild (
            id           INTEGER PRIMARY KEY,
            artikel_id   INTEGER NOT NULL REFERENCES wiki_artikel(id) ON DELETE CASCADE,
            dateiname    TEXT    NOT NULL,
            mime_typ     TEXT    NOT NULL DEFAULT 'image/jpeg',
            daten        BLOB    NOT NULL,
            beschreibung TEXT    NOT NULL DEFAULT '',
            sortierung   INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler wiki_bild:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE VIRTUAL TABLE IF NOT EXISTS wiki_suche USING fts5(
            titel, inhalt, tags,
            content='wiki_artikel',
            content_rowid='id'
        )
    )")) {
        qWarning() << "Fehler wiki_suche (FTS5):" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TRIGGER IF NOT EXISTS wiki_artikel_ai AFTER INSERT ON wiki_artikel BEGIN
            INSERT INTO wiki_suche(rowid, titel, inhalt, tags)
            VALUES (new.id, new.titel, new.inhalt, new.tags);
        END
    )")) { qWarning() << "Trigger wiki_artikel_ai:" << q.lastError().text(); return false; }

    if (!q.exec(R"(
        CREATE TRIGGER IF NOT EXISTS wiki_artikel_ad AFTER DELETE ON wiki_artikel BEGIN
            INSERT INTO wiki_suche(wiki_suche, rowid, titel, inhalt, tags)
            VALUES ('delete', old.id, old.titel, old.inhalt, old.tags);
        END
    )")) { qWarning() << "Trigger wiki_artikel_ad:" << q.lastError().text(); return false; }

    if (!q.exec(R"(
        CREATE TRIGGER IF NOT EXISTS wiki_artikel_au AFTER UPDATE ON wiki_artikel BEGIN
            INSERT INTO wiki_suche(wiki_suche, rowid, titel, inhalt, tags)
            VALUES ('delete', old.id, old.titel, old.inhalt, old.tags);
            INSERT INTO wiki_suche(rowid, titel, inhalt, tags)
            VALUES (new.id, new.titel, new.inhalt, new.tags);
        END
    )")) { qWarning() << "Trigger wiki_artikel_au:" << q.lastError().text(); return false; }

    return true;
}

bool Database::isOpen() const
{
    return m_db.isOpen();
}

QString Database::lastError() const
{
    return m_db.lastError().text();
}

QVariantMap Database::datenbankInfos() const
{
    QVariantMap m;
    QString projektDatei = m_projektOffen ? m_db.databaseName() : QString();
    QString wikiPfad     = m_wikiDb.isValid() ? m_wikiDb.databaseName() : QString();
    // Backup-Verzeichnis neben der Launcher-DB (App-Datenverzeichnis)
    QString backupDir = m_launcherDb.isOpen()
        ? QFileInfo(m_launcherDb.databaseName()).absolutePath() + "/backups"
        : (!projektDatei.isEmpty() ? QFileInfo(projektDatei).absolutePath() + "/backups" : QString());

    int schemaVersion = 0;
    if (m_projektOffen) {
        QSqlQuery q;
        if (q.exec("SELECT COALESCE(MAX(version),0) FROM schema_migration") && q.next())
            schemaVersion = q.value(0).toInt();
    }

    m["hauptDb"]           = projektDatei;
    m["wikiDb"]            = wikiPfad;
    m["backupDir"]         = backupDir;
    m["schemaVersion"]     = schemaVersion;
    m["wikiSchemaVersion"] = WIKI_SCHEMA_VERSION;
    m["backupAnzahl"]      = backupDir.isEmpty() ? 0 : QDir(backupDir).entryList({"*.db"}, QDir::Files).size();
    return m;
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
        QSqlQuery q;
        if (!q.exec(
            "CREATE TABLE IF NOT EXISTS schema_migration ("
            "    version       INTEGER PRIMARY KEY,"
            "    beschreibung  TEXT    NOT NULL,"
            "    angewendet_am TEXT    NOT NULL DEFAULT (datetime('now'))"
            ")")) {
            qWarning() << "schema_migration anlegen:" << q.lastError().text();
            return false;
        }
    }

    // Aktuelle Version ermitteln
    int currentVersion = 0;
    {
        QSqlQuery q;
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
                qInfo() << "schema_migration: Übergang schema_version → v" << BASELINE_VERSION;
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

        qInfo() << "Wende Migration" << mig.version << "an:" << mig.beschreibung;

        if (!m_db.transaction()) {
            qWarning() << "Transaktion fehlgeschlagen:" << m_db.lastError().text();
            return false;
        }

        bool ok = false;
        if (mig.version == BASELINE_VERSION) {
            // Baseline: vollständiger Neuaufbau
            ok = dropAllTables() && createSchema()
                 && seedSymbolKatalog() && seedBuiltinSymbolDefinitionen()
                 && seedIbnFeldvorlagen() && seedExampleData();
        } else {
            ok = applyMigrationStatements(mig.statements);
        }

        if (!ok) {
            m_db.rollback();
            emit dbFehler(QString("Migration v%1 fehlgeschlagen. Die Datenbank wurde nicht verändert "
                                  "(Backup vorhanden).").arg(mig.version));
            return false;
        }

        QSqlQuery ins;
        ins.prepare("INSERT INTO schema_migration (version, beschreibung) VALUES (:v, :b)");
        ins.bindValue(":v", mig.version);
        ins.bindValue(":b", mig.beschreibung);
        if (!ins.exec()) {
            qWarning() << "schema_migration schreiben:" << ins.lastError().text();
            m_db.rollback();
            return false;
        }

        if (!m_db.commit()) {
            qWarning() << "Commit fehlgeschlagen:" << m_db.lastError().text();
            m_db.rollback();
            return false;
        }

        qInfo() << "Migration" << mig.version << "erfolgreich angewendet.";
        currentVersion = mig.version;
    }

    qInfo() << "Hauptdatenbank auf Schema-Version" << currentVersion;
    return true;
}

bool Database::applyMigrationStatements(const QStringList &statements)
{
    QSqlQuery q;
    for (const QString &stmt : statements) {
        if (stmt.trimmed().isEmpty()) continue;
        if (!q.exec(stmt)) {
            qWarning() << "Migration-Statement fehlgeschlagen:" << q.lastError().text();
            qWarning() << "Statement:" << stmt.left(200);
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
                      ? QSqlDatabase::database()
                      : QSqlDatabase::database(verbindungsName);

    QString dbPfad = db.databaseName();
    QFileInfo fi(dbPfad);
    if (!fi.exists()) return true;  // Neuinstallation – nichts zu sichern

    QString backupDir = fi.absolutePath() + "/backups";
    if (!QDir().mkpath(backupDir)) {
        qWarning() << "Backup-Verzeichnis konnte nicht angelegt werden:" << backupDir;
        return false;
    }

    QString datum = QDate::currentDate().toString("yyyy-MM-dd");
    QString backupPfad = backupDir + "/" + prefix + "_v" + QString::number(version)
                         + "_" + datum + ".db";

    // Zweiter Backup am selben Tag: Uhrzeit ergänzen
    if (QFile::exists(backupPfad)) {
        QString zeit = QTime::currentTime().toString("HHmm");
        backupPfad = backupDir + "/" + prefix + "_v" + QString::number(version)
                     + "_" + datum + "_" + zeit + ".db";
    }

    // VACUUM INTO erzeugt eine saubere Kopie einer offenen SQLite-DB (WAL-sicher)
    QString escaped = backupPfad;
    escaped.replace("'", "''");
    QSqlQuery q(db);
    if (!q.exec("VACUUM INTO '" + escaped + "'")) {
        qWarning() << "Backup fehlgeschlagen:" << backupPfad << q.lastError().text();
        return false;
    }
    qInfo() << "Backup erstellt:" << backupPfad;

    // Älteste Backups löschen wenn mehr als 5 vorhanden
    QDir bd(backupDir);
    QStringList backups = bd.entryList({ prefix + "_v*.db" }, QDir::Files, QDir::Name);
    while (backups.size() > 5) {
        QString alt = backups.takeFirst();
        if (bd.remove(alt))
            qInfo() << "Altes Backup gelöscht:" << alt;
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
    QSqlQuery q;
    q.exec("PRAGMA foreign_keys = OFF");

    const QStringList views = {
        "klemmenleiste_bmk",
        "betriebsmittel_bmk",
        "seite_kennzeichen"
    };
    const QStringList tables = {
        // abhängige Tabellen zuerst
        "ibn_feldwert",
        "ibn_feldvorlage",
        "inbetriebnahme",
        "ibn_kabel",
        "klemme_anschluss",
        "klemme_stegbruecke",
        "klemme",
        "klemmenleiste",
        "makro_element",
        "makro",
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
            qWarning() << "View löschen fehlgeschlagen:" << v << q.lastError().text();
            return false;
        }
    }
    for (const QString &t : tables) {
        if (!q.exec("DROP TABLE IF EXISTS " + t)) {
            qWarning() << "Tabelle löschen fehlgeschlagen:" << t << q.lastError().text();
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
    QSqlQuery q;

    // ----------------------------------------------------------
    // Normblatt Vorlage
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE normblatt_vorlage (
            id              INTEGER PRIMARY KEY,
            name            TEXT NOT NULL,
            beschreibung    TEXT,
            ist_standard    INTEGER DEFAULT 0,
            breite_mm       REAL NOT NULL DEFAULT 297,
            hoehe_mm        REAL NOT NULL DEFAULT 210,
            rand_links_mm   REAL DEFAULT 20,
            rand_rechts_mm  REAL DEFAULT 10,
            rand_oben_mm    REAL DEFAULT 10,
            rand_unten_mm   REAL DEFAULT 10,
            logo_data       BLOB,
            logo_mime       TEXT,
            logo_x_mm       REAL,
            logo_y_mm       REAL,
            logo_breite_mm  REAL,
            logo_hoehe_mm   REAL,
            schriftart      TEXT DEFAULT 'Arial'
        )
    )")) {
        qWarning() << "Fehler normblatt_vorlage:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Normblatt Felder
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE normblatt_feld (
            id             INTEGER PRIMARY KEY,
            vorlage_id     INTEGER NOT NULL REFERENCES normblatt_vorlage(id) ON DELETE CASCADE,
            feldtyp        TEXT NOT NULL DEFAULT 'fest',
            x_mm           REAL NOT NULL DEFAULT 0,
            y_mm           REAL NOT NULL DEFAULT 0,
            breite_mm      REAL NOT NULL DEFAULT 50,
            hoehe_mm       REAL NOT NULL DEFAULT 13,
            label          TEXT,
            inhalt         TEXT,
            quelle_spalte  TEXT,
            schriftgroesse REAL NOT NULL DEFAULT 3.5,
            fett           INTEGER NOT NULL DEFAULT 0,
            rahmen         INTEGER NOT NULL DEFAULT 1,
            reihenfolge    INTEGER NOT NULL DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler normblatt_feld:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Projekt
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE projekt (
            id              INTEGER PRIMARY KEY,
            name            TEXT NOT NULL,
            projektnummer   TEXT,
            auftraggeber    TEXT,
            auftragnehmer   TEXT,
            bearbeiter      TEXT,
            logo_data       BLOB,
            logo_mime       TEXT,
            erstellt_am     TEXT DEFAULT (datetime('now')),
            geaendert_am    TEXT DEFAULT (datetime('now')),
            werk            TEXT,
            abteilung       TEXT,
            normblatt_id    INTEGER REFERENCES normblatt_vorlage(id),
            status          TEXT DEFAULT 'in_bearbeitung',
            bemerkung       TEXT,
            norm                TEXT NOT NULL DEFAULT 'IEC',
            canvas_hintergrund  TEXT NOT NULL DEFAULT '#080f1c'
        )
    )")) {
        qWarning() << "Fehler projekt:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Changelog
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE changelog (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
            version         TEXT NOT NULL,
            datum           TEXT NOT NULL DEFAULT (date('now')),
            autor           TEXT,
            aenderung       TEXT NOT NULL,
            aenderungstyp   TEXT DEFAULT 'aenderung'
        )
    )")) {
        qWarning() << "Fehler changelog:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Seitenbaum
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE anlage (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
            kuerzel         TEXT NOT NULL,
            bezeichnung     TEXT NOT NULL,
            sortierung      INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler anlage:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE ort (
            id              INTEGER PRIMARY KEY,
            anlage_id       INTEGER NOT NULL REFERENCES anlage(id),
            kuerzel         TEXT NOT NULL,
            bezeichnung     TEXT NOT NULL,
            sortierung      INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler ort:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE seite (
            id              INTEGER PRIMARY KEY,
            ort_id          INTEGER REFERENCES ort(id),
            parent_id       INTEGER REFERENCES seite(id),
            werk            TEXT,
            anlage_kuerzel  TEXT,
            ort_kuerzel     TEXT,
            blattnummer     TEXT NOT NULL,
            bezeichnung     TEXT,
            seitentyp       TEXT DEFAULT 'schaltplan',
            breite_mm       REAL DEFAULT 297,
            hoehe_mm        REAL DEFAULT 210,
            rand_links_mm   REAL DEFAULT 20,
            rand_rechts_mm  REAL DEFAULT 10,
            rand_oben_mm    REAL DEFAULT 10,
            rand_unten_mm   REAL DEFAULT 10,
            ausrichtung     TEXT DEFAULT 'quer',
            normblatt_id         INTEGER REFERENCES normblatt_vorlage(id),
            normblatt_anzeigen   INTEGER NOT NULL DEFAULT 0,
            hintergrund_farbe    TEXT    NOT NULL DEFAULT '',
            aussen_overlay       INTEGER NOT NULL DEFAULT 0,
            titelblatt_vorlage   TEXT    NOT NULL DEFAULT 'din6771',
            sortierung           INTEGER DEFAULT 0,
            gesperrt          INTEGER DEFAULT 0,
            bemerkung         TEXT,
            raster_mm         REAL NOT NULL DEFAULT 4.0,
            rastend           INTEGER NOT NULL DEFAULT 1
        )
    )")) {
        qWarning() << "Fehler seite:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Grafik-Elemente (Linie / Rechteck / Kreis / Symbol als Zeichenobjekte)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE grafik_element (
            id              INTEGER PRIMARY KEY,
            seite_id        INTEGER NOT NULL REFERENCES seite(id) ON DELETE CASCADE,
            typ             TEXT NOT NULL,
            x1              REAL NOT NULL DEFAULT 0,
            y1              REAL NOT NULL DEFAULT 0,
            x2              REAL NOT NULL DEFAULT 0,
            y2              REAL NOT NULL DEFAULT 0,
            strich_farbe    TEXT NOT NULL DEFAULT '#4a9eff',
            strich_breite   REAL NOT NULL DEFAULT 1.5,
            strich_art      TEXT NOT NULL DEFAULT 'solid',
            fuell           INTEGER NOT NULL DEFAULT 0,
            fuell_farbe     TEXT NOT NULL DEFAULT '#1a3a6a',
            fuell_opazitaet REAL NOT NULL DEFAULT 0.3,
            opazitaet       REAL NOT NULL DEFAULT 1.0,
            ecken_radius    REAL NOT NULL DEFAULT 0,
            sortierung      INTEGER NOT NULL DEFAULT 0,
            symbol_id       TEXT,
            rotation        INTEGER NOT NULL DEFAULT 0,
            spiegel_x       INTEGER NOT NULL DEFAULT 0,
            spiegel_y       INTEGER NOT NULL DEFAULT 0,
            punkte          TEXT DEFAULT NULL,
            text_inhalt     TEXT DEFAULT NULL,
            text_ausrichtung TEXT DEFAULT 'links',
            text_einpassen  INTEGER NOT NULL DEFAULT 0,
            bild_daten          BLOB DEFAULT NULL,
            bild_mime           TEXT DEFAULT NULL,
            extra_daten         TEXT DEFAULT NULL,
            betriebsmittel_id   INTEGER REFERENCES betriebsmittel(id)
        )
    )")) {
        qWarning() << "Fehler grafik_element:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Symbole (eingebauter Katalog)
    // norm: "IEC", "ANSI" oder "IEC,ANSI" → Abfrage via instr()
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE symbol (
            id              INTEGER PRIMARY KEY,
            code            TEXT NOT NULL UNIQUE,
            name            TEXT NOT NULL,
            kategorie_pfad  TEXT NOT NULL DEFAULT '',
            norm            TEXT NOT NULL DEFAULT 'IEC',
            favorit         INTEGER NOT NULL DEFAULT 0,
            anschluesse     INTEGER DEFAULT 2,
            origin_x        REAL DEFAULT 0,
            origin_y        REAL DEFAULT 0,
            svg_data        TEXT
        )
    )")) {
        qWarning() << "Fehler symbol:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE symbol_anschluss (
            id          INTEGER PRIMARY KEY,
            symbol_id   INTEGER NOT NULL REFERENCES symbol(id),
            bezeichnung TEXT NOT NULL,
            x_pos       REAL,
            y_pos       REAL,
            typ         TEXT,
            richtung    TEXT
        )
    )")) {
        qWarning() << "Fehler symbol_anschluss:" << q.lastError().text();
        return false;
    }

    // Textfelder die auf einem Symbol platziert werden können.
    // Die Werte (z.B. Betriebsmittelkennzeichen, Typ) kommen zur
    // Laufzeit aus der Bauteil-/Betriebsmittelstruktur; hier steht
    // nur wo und wie sie dargestellt werden.
    if (!q.exec(R"(
        CREATE TABLE symbol_textfeld (
            id          INTEGER PRIMARY KEY,
            symbol_id   INTEGER NOT NULL REFERENCES symbol(id),
            feldname    TEXT NOT NULL,
            x           REAL NOT NULL DEFAULT 0,
            y           REAL NOT NULL DEFAULT 0,
            rotation    INTEGER NOT NULL DEFAULT 0,
            ausrichtung TEXT NOT NULL DEFAULT 'links'
        )
    )")) {
        qWarning() << "Fehler symbol_textfeld:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Primitiv-Symbolsystem (Phase A Symboleditor)
    // Alle Symbole als Primitiv-Listen – ersetzt langfristig symbole.js/pinkatalog.js
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE symbol_definition (
            id             TEXT    PRIMARY KEY,
            name           TEXT    NOT NULL,
            kategorie      TEXT,
            breite_mm      INTEGER NOT NULL DEFAULT 16,
            hoehe_mm       INTEGER NOT NULL DEFAULT 16,
            rolle          TEXT    NOT NULL DEFAULT 'durchleiter',
            ist_builtin    INTEGER NOT NULL DEFAULT 0,
            ibn_kategorie  TEXT    NOT NULL DEFAULT ''
        )
    )")) {
        qWarning() << "Fehler symbol_definition:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE symbol_primitiv (
            id                    INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol_id             TEXT    NOT NULL REFERENCES symbol_definition(id) ON DELETE CASCADE,
            reihenfolge           INTEGER NOT NULL DEFAULT 0,
            typ                   TEXT    NOT NULL,
            x1                    REAL,
            y1                    REAL,
            x2                    REAL,
            y2                    REAL,
            x3                    REAL,
            y3                    REAL,
            radius                REAL,
            winkel_von            REAL,
            winkel_bis            REAL,
            bogen_gegen_uhrzeiger INTEGER DEFAULT 0,
            text_inhalt           TEXT,
            schrift_relativ       REAL    DEFAULT 0.5,
            schrift_fett          INTEGER DEFAULT 0,
            text_align            TEXT    DEFAULT 'center',
            text_baseline         TEXT    DEFAULT 'middle',
            linienart             TEXT    DEFAULT 'solid'
        )
    )")) {
        qWarning() << "Fehler symbol_primitiv:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE symbol_pin (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol_id  TEXT    NOT NULL REFERENCES symbol_definition(id) ON DELETE CASCADE,
            name       TEXT    NOT NULL,
            x          REAL    NOT NULL,
            y          REAL    NOT NULL,
            offen_x    REAL    NOT NULL,
            offen_y    REAL    NOT NULL,
            signaltyp  TEXT    NOT NULL DEFAULT 'neutral',
            kontext    TEXT
        )
    )")) {
        qWarning() << "Fehler symbol_pin:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Bauteil-Datenbank
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE bauteil_kategorie (
            id          INTEGER PRIMARY KEY,
            name        TEXT NOT NULL,
            parent_id   INTEGER REFERENCES bauteil_kategorie(id),
            sortierung  INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler bauteil_kategorie:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil (
            id              INTEGER PRIMARY KEY,
            kategorie_id    INTEGER REFERENCES bauteil_kategorie(id),
            bezeichnung     TEXT NOT NULL,
            hersteller      TEXT,
            artikelnummer   TEXT,
            artikelnummer_2 TEXT,
            lieferant       TEXT,
            bestellnummer   TEXT,
            preis_eur       REAL,
            spannung_v      REAL,
            strom_a         REAL,
            leistung_w      REAL,
            schutzart       TEXT,
            norm            TEXT,
            symbol_code     TEXT,
            bmk_vorlage     TEXT,
            bemerkung       TEXT,
            bild_data       BLOB,
            bild_mime       TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Klemmen-Physik (Schema v8) – projektübergreifende Bibliothek
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE farb_definition (
            id           INTEGER PRIMARY KEY,
            hex_wert     TEXT,
            bezeichnung  TEXT NOT NULL,
            ist_standard INTEGER DEFAULT 0,
            sortierung   INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler farb_definition:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme (
            id                 INTEGER PRIMARY KEY,
            bauteil_id         INTEGER NOT NULL REFERENCES bauteil(id),
            norm               TEXT,
            anschluss_typ      TEXT NOT NULL,
            ebenen_anzahl      INTEGER NOT NULL DEFAULT 1,
            punkte_seite_a     INTEGER NOT NULL DEFAULT 1,
            punkte_seite_b     INTEGER NOT NULL DEFAULT 1,
            fuss_kontakt_pe    INTEGER DEFAULT 0,
            stegbruecke_faehig INTEGER DEFAULT 0,
            breite_mm          REAL,
            gehaeuse_farbe_id  INTEGER REFERENCES farb_definition(id),
            bemerkung          TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme_querschnitt (
            id        INTEGER PRIMARY KEY,
            klemme_id INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            adertyp   TEXT NOT NULL,
            min_mm2   REAL NOT NULL,
            max_mm2   REAL NOT NULL
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme_querschnitt:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme_bruecke (
            id          INTEGER PRIMARY KEY,
            klemme_id   INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            von_ebene   INTEGER NOT NULL,
            nach_ebene  INTEGER NOT NULL,
            ist_pe_fuss INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme_bruecke:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_klemme_eigenschaft (
            id           INTEGER PRIMARY KEY,
            klemme_id    INTEGER NOT NULL REFERENCES bauteil_klemme(id),
            schluessel   TEXT NOT NULL,
            wert         TEXT NOT NULL,
            beschreibung TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil_klemme_eigenschaft:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Kabel-Bibliothek (Bauteilkatalog-Erweiterung)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE bauteil_kabel (
            id                  INTEGER PRIMARY KEY,
            bauteil_id          INTEGER NOT NULL REFERENCES bauteil(id) ON DELETE CASCADE,
            kabeltyp            TEXT,
            geschirmt           INTEGER NOT NULL DEFAULT 0,
            paarweise_verdrillt INTEGER NOT NULL DEFAULT 0,
            aussenmantel_farbe  TEXT,
            aussenmantel_mm     REAL,
            material_leiter     TEXT,
            material_isolierung TEXT
        )
    )")) {
        qWarning() << "Fehler bauteil_kabel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_kabel_ader (
            id              INTEGER PRIMARY KEY,
            kabel_id        INTEGER NOT NULL REFERENCES bauteil_kabel(id) ON DELETE CASCADE,
            ader_nr         INTEGER NOT NULL,
            farbe           TEXT,
            nummer          TEXT,
            bezeichnung     TEXT,
            querschnitt_mm2 REAL
        )
    )")) {
        qWarning() << "Fehler bauteil_kabel_ader:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE bauteil_kabel_paar (
            id       INTEGER PRIMARY KEY,
            kabel_id INTEGER NOT NULL REFERENCES bauteil_kabel(id) ON DELETE CASCADE,
            paar_nr  INTEGER NOT NULL,
            ader_a   INTEGER NOT NULL,
            ader_b   INTEGER NOT NULL
        )
    )")) {
        qWarning() << "Fehler bauteil_kabel_paar:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Betriebsmittel
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE betriebsmittel (
            id                      INTEGER PRIMARY KEY,
            projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
            bauteil_id              INTEGER REFERENCES bauteil(id),
            symbol_code             TEXT,
            anlage_uebergeordnet    TEXT,
            standort_uebergeordnet  TEXT,
            funktion                TEXT,
            einbauort               TEXT,
            betriebsmittel_kz       TEXT NOT NULL,
            bezeichnung             TEXT,
            bemerkung               TEXT,
            haupt_element_id        INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
        )
    )")) {
        qWarning() << "Fehler betriebsmittel:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Verbindungen & Querverweise
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE verbindung (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
            bezeichnung     TEXT,
            farbe           TEXT,
            querschnitt_mm2 REAL,
            potenzial       TEXT,
            signaltyp       TEXT NOT NULL DEFAULT 'neutral'
        )
    )")) {
        qWarning() << "Fehler verbindung:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE verbindung_segment (
            id                  INTEGER PRIMARY KEY,
            verbindung_id       INTEGER NOT NULL REFERENCES verbindung(id),
            seite_id            INTEGER NOT NULL REFERENCES seite(id),
            von_anschluss_id    INTEGER,
            nach_anschluss_id   INTEGER,
            punkte              TEXT
        )
    )")) {
        qWarning() << "Fehler verbindung_segment:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE querverweis (
            id                  INTEGER PRIMARY KEY,
            verbindung_id       INTEGER NOT NULL REFERENCES verbindung(id),
            von_seite_id        INTEGER NOT NULL REFERENCES seite(id),
            nach_seite_id       INTEGER NOT NULL REFERENCES seite(id),
            von_bezeichnung     TEXT,
            nach_bezeichnung    TEXT
        )
    )")) {
        qWarning() << "Fehler querverweis:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Kabel
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE kabel (
            id                  INTEGER PRIMARY KEY,
            projekt_id          INTEGER NOT NULL REFERENCES projekt(id),
            bezeichnung         TEXT NOT NULL,
            kabeltyp            TEXT,
            aderzahl            INTEGER,
            querschnitt_mm2     REAL,
            laenge_m            REAL,
            farbe_mantel        TEXT,
            von_ort             TEXT,
            nach_ort            TEXT,
            bemerkung           TEXT,
            bauteil_kabel_id    INTEGER REFERENCES bauteil_kabel(id) ON DELETE SET NULL,
            grafik_element_id   INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
        )
    )")) {
        qWarning() << "Fehler kabel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE kabel_ader (
            id                              INTEGER PRIMARY KEY,
            kabel_id                        INTEGER NOT NULL REFERENCES kabel(id),
            ader_nr                         INTEGER NOT NULL,
            farbe                           TEXT,
            bezeichnung                     TEXT,
            verbindung_id                   INTEGER REFERENCES verbindung(id),
            kabellinie_grafik_element_id    INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
            von_gerat_pin                   TEXT,
            nach_gerat_pin                  TEXT
        )
    )")) {
        qWarning() << "Fehler kabel_ader:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Klemmen
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE klemmenleiste (
            id                      INTEGER PRIMARY KEY,
            projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
            ort_id                  INTEGER REFERENCES ort(id),
            bezeichnung             TEXT NOT NULL,
            ausrichtung             TEXT NOT NULL DEFAULT 'senkrecht',
            anlage_uebergeordnet    TEXT,
            standort_uebergeordnet  TEXT,
            bemerkung               TEXT
        )
    )")) {
        qWarning() << "Fehler klemmenleiste:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE klemme (
            id                  INTEGER PRIMARY KEY,
            klemmenleiste_id    INTEGER NOT NULL REFERENCES klemmenleiste(id),
            bauteil_id          INTEGER REFERENCES bauteil(id),
            nummer              TEXT NOT NULL DEFAULT '',
            sortierung          INTEGER DEFAULT 0,
            bemerkung           TEXT
        )
    )")) {
        qWarning() << "Fehler klemme:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE klemme_stegbruecke (
            id               INTEGER PRIMARY KEY,
            klemmenleiste_id INTEGER NOT NULL REFERENCES klemmenleiste(id),
            ebene            INTEGER NOT NULL DEFAULT 1,
            von_klemme_id    INTEGER NOT NULL REFERENCES klemme(id),
            bis_klemme_id    INTEGER NOT NULL REFERENCES klemme(id),
            verbindung_id    INTEGER REFERENCES verbindung(id),
            potenzial_text   TEXT,
            hat_konflikt     INTEGER DEFAULT 0,
            konflikt_text    TEXT
        )
    )")) {
        qWarning() << "Fehler klemme_stegbruecke:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Leiter (Einzeladern ohne Kabelmantel)
    // Muss vor klemme_anschluss kommen – klemme_anschluss referenziert leiter!
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE leiter (
            id                  INTEGER PRIMARY KEY,
            projekt_id          INTEGER NOT NULL REFERENCES projekt(id),
            verbindung_id       INTEGER REFERENCES verbindung(id),
            bezeichnung         TEXT,
            farbe               TEXT,
            querschnitt_mm2     REAL,
            von_anschluss_id    INTEGER,
            nach_anschluss_id   INTEGER,
            von_freitext        TEXT,
            nach_freitext       TEXT,
            kabel_ader_id       INTEGER REFERENCES kabel_ader(id),
            bemerkung           TEXT
        )
    )")) {
        qWarning() << "Fehler leiter:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE klemme_anschluss (
            id              INTEGER PRIMARY KEY,
            klemme_id       INTEGER NOT NULL REFERENCES klemme(id),
            bezeichnung     TEXT NOT NULL,
            seite           TEXT,
            verbindung_id   INTEGER REFERENCES verbindung(id),
            leiter_id       INTEGER REFERENCES leiter(id),
            sortierung      INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler klemme_anschluss:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Views
    // ----------------------------------------------------------
    if (!q.exec(
        "CREATE VIEW seite_kennzeichen AS "
        "SELECT s.id, s.bezeichnung, s.blattnummer, s.seitentyp, "
        "s.breite_mm, s.hoehe_mm, s.sortierung, s.parent_id, "
        "COALESCE('=' || s.anlage_kuerzel, '') || "
        "COALESCE('+' || s.ort_kuerzel, '') || "
        "'/' || s.blattnummer AS vollkennzeichen FROM seite s"
    )) {
        qWarning() << "Fehler View seite_kennzeichen:" << q.lastError().text();
        return false;
    }

    if (!q.exec(
        "CREATE VIEW betriebsmittel_bmk AS "
        "SELECT id, bezeichnung, "
        "COALESCE('==' || anlage_uebergeordnet, '') || "
        "COALESCE('++' || standort_uebergeordnet, '') || "
        "COALESCE('=' || funktion, '') || "
        "COALESCE('+' || einbauort, '') || "
        "'-' || betriebsmittel_kz AS bmk_vollstaendig, "
        "COALESCE('=' || funktion, '') || "
        "COALESCE('+' || einbauort, '') || "
        "'-' || betriebsmittel_kz AS bmk_kurz "
        "FROM betriebsmittel"
    )) {
        qWarning() << "Fehler View betriebsmittel_bmk:" << q.lastError().text();
        return false;
    }

    if (!q.exec(
        "CREATE VIEW klemmenleiste_bmk AS "
        "SELECT kl.id, kl.bezeichnung, kl.projekt_id, "
        "COALESCE('==' || kl.anlage_uebergeordnet, '') || "
        "COALESCE('++' || kl.standort_uebergeordnet, '') || "
        "COALESCE('=' || a.kuerzel, '') || "
        "COALESCE('+' || o.kuerzel, '') || "
        "'-' || kl.bezeichnung AS bmk_vollstaendig, "
        "COALESCE('=' || a.kuerzel, '') || "
        "COALESCE('+' || o.kuerzel, '') || "
        "'-' || kl.bezeichnung AS bmk_kurz "
        "FROM klemmenleiste kl "
        "LEFT JOIN ort o ON o.id = kl.ort_id "
        "LEFT JOIN anlage a ON a.id = o.anlage_id"
    )) {
        qWarning() << "Fehler View klemmenleiste_bmk:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Makro-Bibliothek (Schema v31)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE makro (
            id            INTEGER PRIMARY KEY,
            name          TEXT    NOT NULL,
            beschreibung  TEXT    DEFAULT '',
            kategorie     TEXT    DEFAULT '',
            kasten_breite REAL    NOT NULL DEFAULT 100,
            kasten_hoehe  REAL    NOT NULL DEFAULT 100,
            erstellt_am   TEXT    DEFAULT (datetime('now'))
        )
    )")) {
        qWarning() << "Fehler makro:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE makro_element (
            id          INTEGER PRIMARY KEY,
            makro_id    INTEGER NOT NULL REFERENCES makro(id) ON DELETE CASCADE,
            typ         TEXT    NOT NULL,
            rel_x1      REAL    NOT NULL,
            rel_y1      REAL    NOT NULL,
            rel_x2      REAL    NOT NULL DEFAULT 0,
            rel_y2      REAL    NOT NULL DEFAULT 0,
            extra_daten TEXT    DEFAULT '{}',
            symbol_key  TEXT    DEFAULT '',
            sortierung  INTEGER DEFAULT 0
        )
    )")) {
        qWarning() << "Fehler makro_element:" << q.lastError().text();
        return false;
    }

    // ----------------------------------------------------------
    // Inbetriebnahme-Modus (Schema v33)
    // ----------------------------------------------------------
    if (!q.exec(R"(
        CREATE TABLE inbetriebnahme (
            id              INTEGER PRIMARY KEY,
            projekt_id      INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
            seite_id        INTEGER REFERENCES seite(id) ON DELETE CASCADE,
            bmk             TEXT    NOT NULL,
            bauteil_id      TEXT    DEFAULT '',
            symbol_kategorie TEXT   DEFAULT '',
            status          TEXT    NOT NULL DEFAULT 'offen',
            geprueft_von    TEXT    DEFAULT '',
            geprueft_am     TEXT    DEFAULT '',
            notiz           TEXT    DEFAULT '',
            erstellt_am     TEXT    DEFAULT (datetime('now')),
            UNIQUE (seite_id, bmk)
        )
    )")) {
        qWarning() << "Fehler inbetriebnahme:" << q.lastError().text();
        return false;
    }

    // Schema v35: Feldvorlagen für kategorieabhängige Messwerte
    if (!q.exec(R"(
        CREATE TABLE ibn_feldvorlage (
            id               INTEGER PRIMARY KEY,
            symbol_kategorie TEXT    NOT NULL,
            feldname         TEXT    NOT NULL,
            label            TEXT    NOT NULL,
            feldtyp          TEXT    NOT NULL DEFAULT 'text',
            optionen         TEXT    DEFAULT '',
            einheit          TEXT    DEFAULT '',
            pflichtfeld      INTEGER NOT NULL DEFAULT 0,
            reihenfolge      INTEGER NOT NULL DEFAULT 0,
            erstellt_von     TEXT    NOT NULL DEFAULT 'system',
            UNIQUE(symbol_kategorie, feldname)
        )
    )")) {
        qWarning() << "Fehler ibn_feldvorlage:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE ibn_feldwert (
            id                INTEGER PRIMARY KEY,
            inbetriebnahme_id INTEGER NOT NULL REFERENCES inbetriebnahme(id) ON DELETE CASCADE,
            feldname          TEXT    NOT NULL,
            wert              TEXT    DEFAULT '',
            UNIQUE(inbetriebnahme_id, feldname)
        )
    )")) {
        qWarning() << "Fehler ibn_feldwert:" << q.lastError().text();
        return false;
    }

    // Schema v34: IBN-Status pro Kabel
    if (!q.exec(R"(
        CREATE TABLE ibn_kabel (
            id           INTEGER PRIMARY KEY,
            projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
            kabel_id     INTEGER NOT NULL REFERENCES kabel(id)   ON DELETE CASCADE,
            status       TEXT    NOT NULL DEFAULT 'offen',
            geprueft_von TEXT    DEFAULT '',
            geprueft_am  TEXT    DEFAULT '',
            notiz        TEXT    DEFAULT '',
            UNIQUE(kabel_id)
        )
    )")) {
        qWarning() << "Fehler ibn_kabel:" << q.lastError().text();
        return false;
    }

    return true;
}

// ============================================================
// seedExampleData
// Füllt die frisch angelegte Datenbank mit einem Beispielprojekt,
// damit die Anwendung beim ersten Start nicht leer ist.
// Wird nur nach dropAllTables + createSchema aufgerufen.
// ============================================================
bool Database::seedExampleData()
{
    // gridPx = gridMm(4) * mmToPx(4) = 16 px
    // Standardsymbol: 8*16 = 128 breit, 4*16 = 64 hoch
    // Verbindungselement (QV): 2*16 = 32 × 32
    constexpr double G = 16.0;   // gridPx
    constexpr double SW = 8*G;   // Symbol-Breite  128
    constexpr double SH = 4*G;   // Symbol-Höhe     64
    constexpr double VW = 2*G;   // Verbindungs-Symbol 32

    auto insertGrafik = [&](int seiteId, int sort,
                             const QString &typ, const QString &symId,
                             double x1, double y1, double x2, double y2,
                             const QString &strichFarbe, double strichBreite,
                             bool fuell, const QString &fuellFarbe, double fuellOp,
                             const QString &extraJson) -> bool
    {
        QSqlQuery qi;
        qi.prepare(R"(
            INSERT INTO grafik_element
                (seite_id, typ, x1, y1, x2, y2,
                 strich_farbe, strich_breite, strich_art,
                 fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
                 sortierung, symbol_id, rotation, spiegel_x, spiegel_y,
                 extra_daten)
            VALUES
                (:sid, :typ, :x1, :y1, :x2, :y2,
                 :sf, :sb, 'solid',
                 :fu, :ff, :fo, 1.0, 0,
                 :sort, :symid, 0, 0, 0,
                 :ed)
        )");
        qi.bindValue(":sid",   seiteId);
        qi.bindValue(":typ",   typ);
        qi.bindValue(":x1",    x1);   qi.bindValue(":y1", y1);
        qi.bindValue(":x2",    x2);   qi.bindValue(":y2", y2);
        qi.bindValue(":sf",    strichFarbe);
        qi.bindValue(":sb",    strichBreite);
        qi.bindValue(":fu",    fuell ? 1 : 0);
        qi.bindValue(":ff",    fuellFarbe);
        qi.bindValue(":fo",    fuellOp);
        qi.bindValue(":sort",  sort);
        qi.bindValue(":symid", symId);
        qi.bindValue(":ed",    extraJson.isEmpty()
                               ? QVariant(QMetaType::fromType<QString>())
                               : QVariant(extraJson));
        if (!qi.exec()) {
            qWarning() << "Seed grafik_element:" << qi.lastError().text();
            return false;
        }
        return true;
    };

    // Helper: BMK + Freitexte als JSON
    auto bmkJson = [](const QString &bmk, const QString &ft1 = {},
                      const QString &ft2 = {}) -> QString {
        return QString(R"({"bmk":"%1","freitext1":"%2","freitext2":"%3"})")
               .arg(bmk, ft1, ft2);
    };

    QSqlQuery q;

    // ----------------------------------------------------------
    // Projekt
    // ----------------------------------------------------------
    q.prepare("INSERT INTO projekt (name, projektnummer, status) "
              "VALUES (:name, :nr, 'in_bearbeitung')");
    q.bindValue(":name", "Beispielprojekt – Stallbeleuchtung");
    q.bindValue(":nr",   "2026-001");
    if (!q.exec()) { qWarning() << "Seed projekt:" << q.lastError().text(); return false; }
    const int projektId = q.lastInsertId().toInt();

    // ----------------------------------------------------------
    // Anlage
    // ----------------------------------------------------------
    q.prepare("INSERT INTO anlage (projekt_id, kuerzel, bezeichnung, sortierung) "
              "VALUES (:pid, 'EG', 'Erdgeschoss', 0)");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qWarning() << "Seed anlage:" << q.lastError().text(); return false; }
    const int anlageId = q.lastInsertId().toInt();

    // ----------------------------------------------------------
    // Ort + Seiten
    // ----------------------------------------------------------
    q.prepare("INSERT INTO ort (anlage_id, kuerzel, bezeichnung, sortierung) "
              "VALUES (:aid, 'KS', 'Kuhstall', 0)");
    q.bindValue(":aid", anlageId);
    if (!q.exec()) { qWarning() << "Seed ort:" << q.lastError().text(); return false; }
    const int ortId = q.lastInsertId().toInt();

    auto insertSeite = [&](const QString &nr, const QString &bez, int sort) -> int {
        QSqlQuery qs;
        qs.prepare("INSERT INTO seite (ort_id, anlage_kuerzel, ort_kuerzel, "
                   "blattnummer, bezeichnung, seitentyp, sortierung) "
                   "VALUES (:oid, 'EG', 'KS', :nr, :bez, 'schaltplan', :sort)");
        qs.bindValue(":oid",  ortId);
        qs.bindValue(":nr",   nr);
        qs.bindValue(":bez",  bez);
        qs.bindValue(":sort", sort);
        if (!qs.exec()) { qWarning() << "Seed seite:" << qs.lastError().text(); return -1; }
        return qs.lastInsertId().toInt();
    };

    const int s1 = insertSeite("001", "Hauptstromkreis", 0);
    const int s2 = insertSeite("002", "Steuerstromkreis", 1);
    const int s3 = insertSeite("003", "Klemmenplan", 2);
    if (s1 < 0 || s2 < 0 || s3 < 0) return false;

    // ----------------------------------------------------------
    // Seite 001 – Hauptstromkreis
    //   Gerätekasten -X1, LSS -Q1, Sicherung -F1, Motor -M1
    //   Querverweis "230V_L1" → Seite 002
    // ----------------------------------------------------------
    // Gerätekasten -X1  (6 × SW breit, 4 × SH hoch)
    if (!insertGrafik(s1, 0, "geraetekasten", {},
                      5*G, 5*G, 5*G + 6*SW, 5*G + 4*SH,
                      "#cc7700", 1.5, true, "#331a00", 0.15,
                      R"({"bmk":"-X1","bezeichnung":"Schaltschrank"})")) return false;

    // LSS -Q1  (oben links im Kasten)
    if (!insertGrafik(s1, 1, "symbol", "lss",
                      6*G, 6*G, 6*G + SW, 6*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-Q1", "Leitungsschutzschalter", "B16A"))) return false;

    // Sicherung -F1  (rechts neben LSS)
    if (!insertGrafik(s1, 2, "symbol", "sicherung",
                      6*G + SW + 2*G, 6*G, 6*G + 2*SW + 2*G, 6*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-F1", "Motorschutzschalter", "1,6-2,5 A"))) return false;

    // Motor -M1  (darunter, mittig)
    if (!insertGrafik(s1, 3, "symbol", "motor",
                      6*G + SW/2, 6*G + SH + 4*G, 6*G + SW/2 + SW, 6*G + 2*SH + 4*G,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-M1", "Kreiselpumpe P1", "0,75 kW / 230V"))) return false;

    // Querverweis "230V_L1" ausgang → Seite 002
    const QString qvAusgangJson =
        QString(R"({"signalname":"230V_L1","richtung":"ausgang","zielSeiteId":%1})").arg(s2);
    if (!insertGrafik(s1, 4, "symbol", "querverweis",
                      5*G, 5*G + 4*SH + 3*G, 5*G + VW, 5*G + 4*SH + 3*G + VW,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      qvAusgangJson)) return false;

    // ----------------------------------------------------------
    // Seite 002 – Steuerstromkreis
    //   Schliesser -K1.1, Spule -K1, Lampe -H1
    //   Querverweis "230V_L1" eingang ← Seite 001
    // ----------------------------------------------------------
    // Schliesser -K1.1
    if (!insertGrafik(s2, 0, "symbol", "schliesser",
                      10*G, 10*G, 10*G + SW, 10*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-K1.1", "Hilfskontakt Schütz"))) return false;

    // Schütz-Spule -K1  (rechts neben Schliesser)
    if (!insertGrafik(s2, 1, "symbol", "spule",
                      10*G + SW + 2*G, 10*G, 10*G + 2*SW + 2*G, 10*G + SH,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-K1", "Schütz Pumpe P1"))) return false;

    // Meldelampe -H1  (in zweiter Reihe)
    if (!insertGrafik(s2, 2, "symbol", "lampe",
                      10*G, 10*G + SH + 4*G, 10*G + SW, 10*G + 2*SH + 4*G,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      bmkJson("-H1", "Betriebsanzeige", "grün"))) return false;

    // Querverweis "230V_L1" eingang ← Seite 001
    const QString qvEingangJson =
        QString(R"({"signalname":"230V_L1","richtung":"eingang","zielSeiteId":%1})").arg(s1);
    if (!insertGrafik(s2, 3, "symbol", "querverweis",
                      10*G, 10*G + 2*SH + 8*G, 10*G + VW, 10*G + 2*SH + 8*G + VW,
                      "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                      qvEingangJson)) return false;

    // ----------------------------------------------------------
    // Seite 003 – Klemmenplan (nur Gerätekasten als Rahmen)
    // ----------------------------------------------------------
    if (!insertGrafik(s3, 0, "geraetekasten", {},
                      5*G, 5*G, 5*G + 10*SW, 5*G + 3*SH,
                      "#cc7700", 1.5, true, "#331a00", 0.15,
                      R"({"bmk":"-X1","bezeichnung":"Klemmenleiste"})")) return false;

    // Klemmen X1:1 … X1:4
    const QStringList kmmBez = { ":1", ":2", ":3", ":4" };
    for (int ki = 0; ki < kmmBez.size(); ++ki) {
        if (!insertGrafik(s3, ki + 1, "symbol", "klemme",
                          6*G + ki * (SW + G), 6*G, 6*G + ki * (SW + G) + SW, 6*G + SH,
                          "#4a9eff", 1.5, false, "#1a3a6a", 0.3,
                          bmkJson("-X1" + kmmBez[ki]))) return false;
    }

    // ----------------------------------------------------------
    // Bauteil-Katalog (Beispieleinträge)
    // ----------------------------------------------------------
    q.prepare("INSERT INTO bauteil_kategorie (name, parent_id, sortierung) "
              "VALUES (:n, NULL, :s)");
    q.bindValue(":n", "Schutzgeräte"); q.bindValue(":s", 0);
    if (!q.exec()) { qWarning() << "Seed kat:" << q.lastError().text(); return false; }
    const int katSchutz = q.lastInsertId().toInt();

    q.bindValue(":n", "Antriebe"); q.bindValue(":s", 1);
    if (!q.exec()) { qWarning() << "Seed kat2:" << q.lastError().text(); return false; }
    const int katAntriebe = q.lastInsertId().toInt();

    q.bindValue(":n", "Schaltgeräte"); q.bindValue(":s", 2);
    if (!q.exec()) { qWarning() << "Seed kat3:" << q.lastError().text(); return false; }
    const int katSchalt = q.lastInsertId().toInt();

    struct BauteilDef {
        int kat; QString bez; QString hersteller; QString artNr;
    };
    const QList<BauteilDef> bauteile = {
        { katSchutz,  "Leitungsschutzschalter B16A", "ABB",       "S201-B16"      },
        { katSchutz,  "Motorschutzschalter 1,6-2,5A","Siemens",   "3RV2011-1CA10" },
        { katAntriebe,"Kreiselpumpe 0,75 kW",         "Grundfos",  "CM3-5 A-R-I"  },
        { katSchalt,  "Schütz 9A 230VAC",             "Siemens",   "3RT2015-1AP01" },
    };
    for (const BauteilDef &b : bauteile) {
        q.prepare("INSERT INTO bauteil (kategorie_id, bezeichnung, hersteller, artikelnummer) "
                  "VALUES (:kid, :bez, :her, :art)");
        q.bindValue(":kid", b.kat);
        q.bindValue(":bez", b.bez);
        q.bindValue(":her", b.hersteller);
        q.bindValue(":art", b.artNr);
        if (!q.exec()) { qWarning() << "Seed bauteil:" << q.lastError().text(); return false; }
    }

    // ----------------------------------------------------------
    // Kabel-Bibliothek (Beispieleinträge)
    // ----------------------------------------------------------
    q.prepare("INSERT INTO bauteil_kategorie (name, parent_id, sortierung) "
              "VALUES (:n, NULL, :s)");
    q.bindValue(":n", "Kabel"); q.bindValue(":s", 3);
    if (!q.exec()) { qWarning() << "Seed kat Kabel:" << q.lastError().text(); return false; }
    const int katKabel = q.lastInsertId().toInt();

    struct KabelDef {
        QString bezeichnung; QString hersteller; QString artNr;
        QString kabeltyp; int geschirmt;
        struct Ader { int nr; QString farbe; QString bez; double quer; };
        QList<Ader> adern;
    };
    const QList<KabelDef> kabelDefs = {
        {
            "NYM-J 3×1,5", "diverse", "NYM-J 3x1,5",
            "NYM-J 3×1,5 mm²", 0,
            { {1,"BN","L",1.5}, {2,"BU","N",1.5}, {3,"GNYE","PE",1.5} }
        },
        {
            "NYM-J 5×1,5", "diverse", "NYM-J 5x1,5",
            "NYM-J 5×1,5 mm²", 0,
            { {1,"BN","L1",1.5}, {2,"BK","L2",1.5}, {3,"GY","L3",1.5},
              {4,"BU","N",1.5},  {5,"GNYE","PE",1.5} }
        },
        {
            "H05VV-F 3G1,5", "diverse", "H05VV-F 3G1,5",
            "H05VV-F 3G1,5 mm²", 0,
            { {1,"BN","L",1.5}, {2,"BU","N",1.5}, {3,"GNYE","PE",1.5} }
        },
        {
            "LIYY 4×0,5", "diverse", "LIYY 4x0,5",
            "LIYY 4×0,5 mm²", 0,
            { {1,"BN","1",0.5}, {2,"WH","2",0.5}, {3,"BU","3",0.5}, {4,"BK","4",0.5} }
        },
        {
            "ÖLFLEX CLASSIC 110 4G1,5", "Lapp", "1119304",
            "ÖLFLEX 110 4G1,5 mm²", 0,
            { {1,"BN","L",1.5}, {2,"BK","L2",1.5}, {3,"GY","L3",1.5}, {4,"GNYE","PE",1.5} }
        },
    };

    for (const KabelDef &kd : kabelDefs) {
        // bauteil anlegen
        q.prepare("INSERT INTO bauteil (kategorie_id, bezeichnung, hersteller, artikelnummer) "
                  "VALUES (:kid, :bez, :her, :art)");
        q.bindValue(":kid", katKabel);
        q.bindValue(":bez", kd.bezeichnung);
        q.bindValue(":her", kd.hersteller);
        q.bindValue(":art", kd.artNr);
        if (!q.exec()) { qWarning() << "Seed bauteil Kabel:" << q.lastError().text(); return false; }
        const int bauteilId = q.lastInsertId().toInt();

        // bauteil_kabel anlegen
        q.prepare("INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt) "
                  "VALUES (:bid, :typ, :gs)");
        q.bindValue(":bid", bauteilId);
        q.bindValue(":typ", kd.kabeltyp);
        q.bindValue(":gs",  kd.geschirmt);
        if (!q.exec()) { qWarning() << "Seed bauteil_kabel:" << q.lastError().text(); return false; }
        const int bkId = q.lastInsertId().toInt();

        // Adern anlegen
        for (const KabelDef::Ader &a : kd.adern) {
            q.prepare("INSERT INTO bauteil_kabel_ader "
                      "(kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2) "
                      "VALUES (:kid, :nr, :f, :bez, :quer)");
            q.bindValue(":kid",  bkId);
            q.bindValue(":nr",   a.nr);
            q.bindValue(":f",    a.farbe);
            q.bindValue(":bez",  a.bez);
            q.bindValue(":quer", a.quer);
            if (!q.exec()) { qWarning() << "Seed bauteil_kabel_ader:" << q.lastError().text(); return false; }
        }
    }

    qInfo() << "Beispieldaten eingefügt (Projekt 'Beispielprojekt – Stallbeleuchtung').";
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

    QSqlQuery q;
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
            qWarning() << "seedSymbolKatalog:" << s.code << q.lastError().text();
            return false;
        }
    }

    qInfo() << "Symbol-Katalog befüllt:" << symbole.size() << "Symbole.";

    // ----------------------------------------------------------
    // Vordefinierte Gehäusefarben (farb_definition, ist_standard=1)
    // ----------------------------------------------------------
    struct Farbe { QString hex; QString bez; int sort; };
    const QList<Farbe> farben = {
        { "#808080", "Grau",                         1 },
        { "#0000CC", "Blau \u2013 N-Leiter (DIN VDE 0100)",          2 },
        { "#66AAFF", "Blau \u2013 Eigensicher (IEC 60079-14)",        3 },
        { "#3366CC", "Blau \u2013 ohne Definition",                   4 },
        { "#88AA00", "Gr\u00fcn-Gelb \u2013 PE (normverpflichtend)",  5 },
        { "#FF8800", "Orange \u2013 Trennstelle / Potenzialgruppe",   6 },
        { "#CC0000", "Rot \u2013 L-Leiter / Sonderkreis",            7 },
        { "#222222", "Schwarz \u2013 L-Leiter (\u00e4ltere Norm)",    8 },
        { "#EEEEEE", "Wei\u00df \u2013 Sonderkreis",                  9 },
        { "#FFCC00", "Gelb \u2013 Sicherheitskreis",                 10 },
        { "#E8D8B0", "Beige \u2013 \u00e4ltere Installation",         11 },
        // DIN 72551 KFZ-Leitungsfarben
        { "#CC0000", "Rot - DIN 72551 (rt)",     100 },
        { "#222222", "Schwarz - DIN 72551 (sw)", 101 },
        { "#FFCC00", "Gelb - DIN 72551 (ge)",    102 },
        { "#663300", "Braun - DIN 72551 (br)",   103 },
        { "#0044CC", "Blau - DIN 72551 (bl)",    104 },
        { "#228B22", "Gruen - DIN 72551 (gn)",   105 },
        { "#888888", "Grau - DIN 72551 (gr)",    106 },
        { "#EEEEEE", "Weiss - DIN 72551 (ws)",   107 },
        { "#8B008B", "Violett - DIN 72551 (vi)", 108 },
        { "#FF6600", "Orange - DIN 72551 (or)",  109 },
    };

    QSqlQuery fq;
    fq.prepare("INSERT INTO farb_definition (hex_wert, bezeichnung, ist_standard, sortierung) "
               "VALUES (:hex, :bez, 1, :sort)");
    for (const Farbe &f : farben) {
        fq.bindValue(":hex",  f.hex);
        fq.bindValue(":bez",  f.bez);
        fq.bindValue(":sort", f.sort);
        if (!fq.exec()) {
            qWarning() << "seedFarbDefinition:" << f.bez << fq.lastError().text();
            return false;
        }
    }
    qInfo() << "Farb-Katalog befüllt:" << farben.size() << "Einträge.";

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
        qWarning() << "seedBuiltinSymbolDefinitionen: symbole.sql nicht gefunden (:/database/symbole.sql)";
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

    QSqlQuery q;
    const QStringList statements = cleanSql.split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (const QString &raw : statements) {
        const QString stmt = raw.trimmed();
        if (stmt.isEmpty())
            continue;
        if (!q.exec(stmt)) {
            qWarning() << "seedBuiltinSymbolDefinitionen:" << q.lastError().text()
                       << "\nStatement:" << stmt.left(120);
            return false;
        }
    }

    qInfo() << "Builtin-Symboldefinitionen aus symbole.sql geladen.";
    return true;
}


// ============================================================
// symboleNachNorm
// Gibt alle Symbole zurück deren norm-Feld die gesuchte Norm enthält.
// ============================================================
QVariantList Database::symboleNachNorm(const QString &norm)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, code, name, kategorie_pfad, norm, favorit, anschluesse
        FROM symbol
        WHERE instr(norm, :n) > 0
        ORDER BY kategorie_pfad, name
    )");
    q.bindValue(":n", norm);
    if (!q.exec()) {
        qWarning() << "symboleNachNorm:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]           = q.value(0).toInt();
        m[QStringLiteral("code")]         = q.value(1).toString();
        m[QStringLiteral("name")]         = q.value(2).toString();
        m[QStringLiteral("kategoriePfad")]= q.value(3).toString();
        m[QStringLiteral("norm")]         = q.value(4).toString();
        m[QStringLiteral("favorit")]      = q.value(5).toInt() != 0;
        m[QStringLiteral("anschluesse")]  = q.value(6).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// symbolFavoritSetzen
// ============================================================
bool Database::symbolFavoritSetzen(int symbolId, bool favorit)
{
    QSqlQuery q;
    q.prepare("UPDATE symbol SET favorit = :fav WHERE id = :id");
    q.bindValue(":fav", favorit ? 1 : 0);
    q.bindValue(":id",  symbolId);
    if (!q.exec()) {
        qWarning() << "symbolFavoritSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// projektNormLaden / projektNormSpeichern
// ============================================================
QString Database::projektNormLaden(int projektId)
{
    QSqlQuery q;
    q.prepare("SELECT norm FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("IEC");
}

bool Database::projektNormSpeichern(int projektId, const QString &norm)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET norm = :norm WHERE id = :pid");
    q.bindValue(":norm", norm);
    q.bindValue(":pid",  projektId);
    if (!q.exec()) {
        qWarning() << "projektNormSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// projektHintergrundLaden / projektHintergrundSpeichern
// ============================================================
QString Database::projektHintergrundLaden(int projektId)
{
    QSqlQuery q;
    q.prepare("SELECT canvas_hintergrund FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("#080f1c");
}

bool Database::projektHintergrundSpeichern(int projektId, const QString &farbe)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET canvas_hintergrund = :farbe WHERE id = :pid");
    q.bindValue(":farbe", farbe);
    q.bindValue(":pid",   projektId);
    if (!q.exec()) {
        qWarning() << "projektHintergrundSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// grafikLaden
// Gibt alle Grafik-Elemente einer Seite als QVariantList zurück.
// Die Maps verwenden dieselben camelCase-Schlüssel wie das QML-Modell.
// ============================================================
QVariantList Database::grafikLaden(int seiteId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, typ, x1, y1, x2, y2,
               strich_farbe, strich_breite, strich_art,
               fuell, fuell_farbe, fuell_opazitaet,
               opazitaet, ecken_radius,
               symbol_id, rotation, spiegel_x, spiegel_y,
               punkte, text_inhalt, text_ausrichtung, text_einpassen,
               bild_daten, bild_mime, extra_daten, betriebsmittel_id
        FROM grafik_element
        WHERE seite_id = :sid
        ORDER BY sortierung
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "grafikLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap el;
        el[QStringLiteral("id")]             = q.value(0).toInt();
        el[QStringLiteral("typ")]            = q.value(1).toString();
        el[QStringLiteral("x1")]             = q.value(2).toDouble();
        el[QStringLiteral("y1")]             = q.value(3).toDouble();
        el[QStringLiteral("x2")]             = q.value(4).toDouble();
        el[QStringLiteral("y2")]             = q.value(5).toDouble();
        el[QStringLiteral("strichFarbe")]    = q.value(6).toString();
        el[QStringLiteral("strichBreite")]   = q.value(7).toDouble();
        el[QStringLiteral("strichArt")]      = q.value(8).toString();
        el[QStringLiteral("fuell")]          = q.value(9).toInt() != 0;
        el[QStringLiteral("fuellFarbe")]     = q.value(10).toString();
        el[QStringLiteral("fuellOpazitaet")] = q.value(11).toDouble();
        el[QStringLiteral("opazitaet")]      = q.value(12).toDouble();
        el[QStringLiteral("eckenRadius")]    = q.value(13).toDouble();
        el[QStringLiteral("symbolId")]       = q.value(14).toString();
        el[QStringLiteral("rotation")]       = q.value(15).toInt();
        el[QStringLiteral("spiegelX")]       = q.value(16).toInt() != 0;
        el[QStringLiteral("spiegelY")]       = q.value(17).toInt() != 0;

        // text_inhalt / text_ausrichtung / text_einpassen (für Text-Elemente)
        QString textInhalt = q.value(19).toString();
        if (!textInhalt.isEmpty())
            el[QStringLiteral("textInhalt")] = textInhalt;
        QString textAusrichtung = q.value(20).toString();
        el[QStringLiteral("textAusrichtung")] = textAusrichtung.isEmpty()
                                                ? QStringLiteral("links") : textAusrichtung;
        el[QStringLiteral("textEinpassen")] = q.value(21).toInt() != 0;

        // bild_daten: BLOB-Bytes + bild_mime → Base64-Data-URL für QML-Canvas
        QByteArray bildBytes = q.value(22).toByteArray();
        if (!bildBytes.isEmpty()) {
            QString bildMime = q.value(23).toString();
            if (bildMime.isEmpty())
                bildMime = QStringLiteral("image/png");
            el[QStringLiteral("bildDaten")] = QStringLiteral("data:") + bildMime
                + QStringLiteral(";base64,")
                + QString::fromLatin1(bildBytes.toBase64());
        }

        // extra_daten: JSON → extraDaten-Map für symbol-spezifische Eigenschaften
        QString extraDatenStr = q.value(24).toString();
        if (!extraDatenStr.isEmpty()) {
            QJsonParseError jsonErr;
            QJsonDocument extraDoc = QJsonDocument::fromJson(extraDatenStr.toUtf8(), &jsonErr);
            if (!jsonErr.error && extraDoc.isObject())
                el[QStringLiteral("extraDaten")] = extraDoc.object().toVariantMap();
        }

        // betriebsmittel_id (Spalte 25) – nullable FK
        if (!q.value(25).isNull())
            el[QStringLiteral("betriebsmittelId")] = q.value(25).toInt();

        // punkte (für Leitung-Elemente als JSON gespeichert)
        QString punkteStr = q.value(18).toString();
        if (!punkteStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(punkteStr.toUtf8(), &err);
            if (!err.error && doc.isArray()) {
                QVariantList punkte;
                for (const QJsonValue &v : doc.array()) {
                    if (v.isObject()) {
                        QVariantMap p;
                        p[QStringLiteral("x")] = v[QStringLiteral("x")].toDouble();
                        p[QStringLiteral("y")] = v[QStringLiteral("y")].toDouble();
                        punkte.append(p);
                    }
                }
                el[QStringLiteral("punkte")] = punkte;
            }
        }

        result.append(el);
    }
    return result;
}

// ============================================================
// grafikSpeichern
// Ersetzt alle Grafik-Elemente einer Seite in einer Transaktion.
// ============================================================
bool Database::grafikSpeichern(int seiteId, const QVariantList &elemente)
{
    if (!m_db.transaction()) {
        auto msg = m_db.lastError().text();
        qWarning() << "grafikSpeichern: Transaktion:" << msg;
        emit dbFehler("Speichern fehlgeschlagen (Transaktion konnte nicht gestartet werden).\n" + msg);
        return false;
    }

    // Kabellinie-Ader-Zuordnungen vor dem DELETE sichern:
    // elementIndex → {kabelId, liste_ader_nummern}
    // Nach dem re-Insert werden die kabellinie_grafik_element_id-Werte wiederhergestellt.
    QMap<int, QPair<int, QList<int>>> kabelLinieAderMap;
    for (int i = 0; i < elemente.size(); i++) {
        const QVariantMap el = elemente.at(i).toMap();
        if (el.value(QStringLiteral("typ")).toString() != QLatin1String("kabellinie")) continue;
        int oldGeid  = el.value(QStringLiteral("id"), 0).toInt();
        if (oldGeid <= 0) continue;
        int kabelId  = el.value(QStringLiteral("extraDaten")).toMap()
                          .value(QStringLiteral("kabelId"), 0).toInt();
        if (kabelId <= 0) continue;
        QSqlQuery qa;
        qa.prepare("SELECT ader_nr FROM kabel_ader WHERE kabel_id=:kid AND kabellinie_grafik_element_id=:geid");
        qa.bindValue(":kid",  kabelId);
        qa.bindValue(":geid", oldGeid);
        QList<int> adern;
        if (qa.exec()) { while (qa.next()) adern.append(qa.value(0).toInt()); }
        if (!adern.isEmpty()) kabelLinieAderMap[i] = qMakePair(kabelId, adern);
    }

    QSqlQuery qDel;
    qDel.prepare("DELETE FROM grafik_element WHERE seite_id = :sid");
    qDel.bindValue(":sid", seiteId);
    if (!qDel.exec()) {
        qWarning() << "grafikSpeichern delete:" << qDel.lastError().text();
        m_db.rollback(); return false;
    }

    QSqlQuery qIns;
    qIns.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet,
             opazitaet, ecken_radius, sortierung,
             symbol_id, rotation, spiegel_x, spiegel_y,
             punkte, text_inhalt, text_ausrichtung, text_einpassen,
             bild_daten, bild_mime, extra_daten, betriebsmittel_id)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             :sf, :sb, :sa, :fu, :ff, :fo, :op, :er, :sort,
             :symid, :rot, :spx, :spy,
             :punkte, :textinhalt, :textausrichtung, :texteinpassen,
             :bilddaten, :bildmime, :extradaten, :bmid)
    )");

    for (int i = 0; i < elemente.size(); i++) {
        const QVariantMap el = elemente.at(i).toMap();
        qIns.bindValue(":sid",  seiteId);
        qIns.bindValue(":typ",  el.value(QStringLiteral("typ")).toString());
        qIns.bindValue(":x1",   el.value(QStringLiteral("x1")).toDouble());
        qIns.bindValue(":y1",   el.value(QStringLiteral("y1")).toDouble());
        qIns.bindValue(":x2",   el.value(QStringLiteral("x2")).toDouble());
        qIns.bindValue(":y2",   el.value(QStringLiteral("y2")).toDouble());
        qIns.bindValue(":sf",   el.value(QStringLiteral("strichFarbe"),    QStringLiteral("#4a9eff")).toString());
        qIns.bindValue(":sb",   el.value(QStringLiteral("strichBreite"),   1.5).toDouble());
        qIns.bindValue(":sa",   el.value(QStringLiteral("strichArt"),      QStringLiteral("solid")).toString());
        qIns.bindValue(":fu",   el.value(QStringLiteral("fuell"),          false).toBool() ? 1 : 0);
        qIns.bindValue(":ff",   el.value(QStringLiteral("fuellFarbe"),     QStringLiteral("#1a3a6a")).toString());
        qIns.bindValue(":fo",   el.value(QStringLiteral("fuellOpazitaet"), 0.3).toDouble());
        qIns.bindValue(":op",   el.value(QStringLiteral("opazitaet"),      1.0).toDouble());
        qIns.bindValue(":er",   el.value(QStringLiteral("eckenRadius"),    0.0).toDouble());
        qIns.bindValue(":sort", i);
        qIns.bindValue(":symid", el.value(QStringLiteral("symbolId")).toString());
        qIns.bindValue(":rot",   el.value(QStringLiteral("rotation"),  0).toInt());
        qIns.bindValue(":spx",   el.value(QStringLiteral("spiegelX"),  false).toBool() ? 1 : 0);
        qIns.bindValue(":spy",   el.value(QStringLiteral("spiegelY"),  false).toBool() ? 1 : 0);

        // text_inhalt / text_ausrichtung / text_einpassen (für Text-Elemente)
        QVariant textInhaltVar = el.value(QStringLiteral("textInhalt"));
        if (textInhaltVar.isValid() && !textInhaltVar.isNull())
            qIns.bindValue(":textinhalt", textInhaltVar.toString());
        else
            qIns.bindValue(":textinhalt", QVariant(QMetaType::fromType<QString>()));
        qIns.bindValue(":textausrichtung",
                       el.value(QStringLiteral("textAusrichtung"), QStringLiteral("links")).toString());
        qIns.bindValue(":texteinpassen",
                       el.value(QStringLiteral("textEinpassen"), false).toBool() ? 1 : 0);

        // punkte als JSON serialisieren (nur für Leitungen)
        QVariant punkteVar = el.value(QStringLiteral("punkte"));
        if (punkteVar.isValid() && !punkteVar.isNull() && punkteVar.canConvert<QVariantList>()) {
            QVariantList punkte = punkteVar.toList();
            QJsonArray arr;
            for (const QVariant &pv : punkte) {
                QVariantMap pm = pv.toMap();
                QJsonObject obj;
                obj[QStringLiteral("x")] = pm.value(QStringLiteral("x")).toDouble();
                obj[QStringLiteral("y")] = pm.value(QStringLiteral("y")).toDouble();
                arr.append(obj);
            }
            qIns.bindValue(":punkte", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
        } else {
            qIns.bindValue(":punkte", QVariant(QMetaType::fromType<QString>()));
        }

        // bild_daten: Data-URL aus QML → BLOB-Bytes + MIME für Datenbank
        QVariant bildDatenVar = el.value(QStringLiteral("bildDaten"));
        if (bildDatenVar.isValid() && !bildDatenVar.isNull()) {
            QString dataUrl = bildDatenVar.toString();
            // Format: "data:<mime>;base64,<daten>"
            if (dataUrl.startsWith(QLatin1String("data:"))) {
                int semiPos   = dataUrl.indexOf(QLatin1Char(';'), 5);
                int commaPos  = dataUrl.indexOf(QLatin1Char(','), semiPos + 1);
                if (semiPos > 0 && commaPos > 0) {
                    QString    mime     = dataUrl.mid(5, semiPos - 5);
                    QByteArray rawBytes = QByteArray::fromBase64(
                                             dataUrl.mid(commaPos + 1).toLatin1());
                    qIns.bindValue(":bilddaten", rawBytes);
                    qIns.bindValue(":bildmime",  mime);
                } else {
                    qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
                    qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
                }
            } else {
                qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
                qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
            }
        } else {
            qIns.bindValue(":bilddaten", QVariant(QMetaType::fromType<QByteArray>()));
            qIns.bindValue(":bildmime",  QVariant(QMetaType::fromType<QString>()));
        }

        // extra_daten: extraDaten-Map als kompaktes JSON serialisieren
        QVariant extraVar = el.value(QStringLiteral("extraDaten"));
        if (extraVar.isValid() && !extraVar.isNull() && extraVar.canConvert<QVariantMap>()) {
            QVariantMap extraMap = extraVar.toMap();
            if (!extraMap.isEmpty()) {
                QJsonObject obj;
                for (auto it = extraMap.constBegin(); it != extraMap.constEnd(); ++it)
                    obj.insert(it.key(), QJsonValue::fromVariant(it.value()));
                qIns.bindValue(":extradaten",
                    QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
            } else {
                qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
            }
        } else {
            qIns.bindValue(":extradaten", QVariant(QMetaType::fromType<QString>()));
        }

        // betriebsmittel_id (nullable FK)
        QVariant bmidVar = el.value(QStringLiteral("betriebsmittelId"));
        if (bmidVar.isValid() && !bmidVar.isNull() && bmidVar.toInt() > 0)
            qIns.bindValue(":bmid", bmidVar.toInt());
        else
            qIns.bindValue(":bmid", QVariant(QMetaType::fromType<int>()));

        if (!qIns.exec()) {
            qWarning() << "grafikSpeichern insert:" << qIns.lastError().text();
            m_db.rollback(); return false;
        }

        // Kabellinie: kabel.grafik_element_id + kabel_ader.kabellinie_grafik_element_id
        // nach re-Insert auf neue ID aktualisieren.
        if (el.value(QStringLiteral("typ")).toString() == QLatin1String("kabellinie")) {
            QVariant extraVar2 = el.value(QStringLiteral("extraDaten"));
            if (extraVar2.isValid() && extraVar2.canConvert<QVariantMap>()) {
                int kabelId = extraVar2.toMap().value(QStringLiteral("kabelId"), 0).toInt();
                if (kabelId > 0) {
                    int newGeid = qIns.lastInsertId().toInt();
                    QSqlQuery upd;
                    upd.prepare("UPDATE kabel SET grafik_element_id = :geid WHERE id = :kid");
                    upd.bindValue(":geid", newGeid);
                    upd.bindValue(":kid",  kabelId);
                    if (!upd.exec())
                        qWarning() << "grafikSpeichern kabel relink:" << upd.lastError().text();

                    // Ader-Linie-Zuordnungen wiederherstellen
                    if (kabelLinieAderMap.contains(i)) {
                        const QList<int> &adern = kabelLinieAderMap[i].second;
                        for (int aderNr : adern) {
                            QSqlQuery upd2;
                            upd2.prepare(R"(
                                UPDATE kabel_ader SET kabellinie_grafik_element_id=:geid
                                WHERE kabel_id=:kid AND ader_nr=:nr
                            )");
                            upd2.bindValue(":geid", newGeid);
                            upd2.bindValue(":kid",  kabelId);
                            upd2.bindValue(":nr",   aderNr);
                            if (!upd2.exec())
                                qWarning() << "grafikSpeichern ader relink:" << upd2.lastError().text();
                        }
                    }
                }
            }
        }
    }

    if (!m_db.commit()) {
        auto msg = m_db.lastError().text();
        qWarning() << "grafikSpeichern commit:" << msg;
        m_db.rollback();
        emit dbFehler("Speichern fehlgeschlagen (Commit nicht möglich). Änderungen dieser Aktion "
                      "wurden zurückgerollt.\n" + msg);
        return false;
    }
    return true;
}

// ============================================================
// bildAlsDataUrl
// Liest eine Bilddatei ein, prüft die Größe und gibt eine
// Base64-Data-URL zurück (z. B. "data:image/png;base64,...").
// Diese Data-URL wird in QML für Canvas-Vorschau und In-Memory-
// Darstellung genutzt. Beim Speichern (grafikSpeichern) wird die
// Data-URL serverseitig dekodiert: MIME und Rohdaten werden getrennt
// als TEXT bzw. BLOB in der Datenbank abgelegt.
// Bei Fehler wird "error:<Meldung>" zurückgegeben.
// ============================================================
QString Database::bildAlsDataUrl(const QString &pfad, qint64 maxBytes)
{
    // URL-Schema entfernen falls übergeben (file:///path → /path)
    QUrl url(pfad);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;

    QFileInfo info(localPath);
    if (!info.exists())
        return QStringLiteral("error:Datei nicht gefunden");

    if (info.size() > maxBytes)
        return QStringLiteral("error:Datei zu groß (max. %1 MB)")
               .arg(maxBytes / (1024 * 1024));

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly))
        return QStringLiteral("error:Datei konnte nicht geöffnet werden");

    QByteArray data = file.readAll();
    file.close();

    // MIME-Typ aus Dateiendung ableiten
    QString suffix = info.suffix().toLower();
    QString mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg")  || suffix == QLatin1String("jpeg"))
        mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))
        mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))
        mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("svg"))
        mime = QStringLiteral("image/svg+xml");
    else if (suffix == QLatin1String("webp"))
        mime = QStringLiteral("image/webp");

    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

// ============================================================
// naechsteBmkNummer
// Durchsucht alle grafik_element.extra_daten im Projekt nach
// vorhandenen BMK-Werten mit dem gegebenen Präfix (z.B. "-K")
// und gibt den ersten freien Wert zurück (z.B. "-K3").
// Präfix muss die Kennbuchstaben enthalten, z.B. "-K", "-M", "-F".
// ============================================================
QString Database::naechsteBmkNummer(int projektId, const QString &praefix)
{
    if (praefix.isEmpty())
        return praefix + QStringLiteral("1");

    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten
        FROM grafik_element ge
        JOIN seite   s ON s.id = ge.seite_id
        JOIN ort     o ON o.id = s.ort_id
        JOIN anlage  a ON a.id = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'symbol'
          AND ge.extra_daten IS NOT NULL
    )");
    q.bindValue(":pid", projektId);

    QSet<int> vorhandene;
    const int praefixLen = praefix.length();

    if (q.exec()) {
        while (q.next()) {
            QString extraStr = q.value(0).toString();
            if (extraStr.isEmpty()) continue;
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (err.error || !doc.isObject()) continue;
            QString bmk = doc.object()[QStringLiteral("bmk")].toString();
            if (bmk.startsWith(praefix) && bmk.length() > praefixLen) {
                bool ok;
                int num = bmk.mid(praefixLen).toInt(&ok);
                if (ok && num > 0) vorhandene.insert(num);
            }
        }
    } else {
        qWarning() << "naechsteBmkNummer:" << q.lastError().text();
    }

    int next = 1;
    while (vorhandene.contains(next)) ++next;
    return praefix + QString::number(next);
}

// ============================================================
// verbindungenSynchronisieren
// Schreibt erkannte Auto-Verbindungen (Netze) in verbindung +
// verbindung_segment. Bestehende Segmente der Seite werden zuerst
// gelöscht; die verbindung-Zeilen (mit Annotation) bleiben erhalten
// und werden per potenzial-Feld (= netKey) wiederverwendet.
// ============================================================
bool Database::verbindungenSynchronisieren(int seiteId, int projektId, const QVariantList &netze)
{
    if (!m_db.transaction()) {
        qWarning() << "verbindungenSynchronisieren: Transaktion:" << m_db.lastError().text();
        return false;
    }

    // 1. Alte Segmente dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM verbindung_segment WHERE seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qWarning() << "verbindungenSynchronisieren del segments:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 2. Alte Querverweise dieser Seite löschen
    {
        QSqlQuery del;
        del.prepare("DELETE FROM querverweis WHERE von_seite_id = :sid");
        del.bindValue(":sid", seiteId);
        if (!del.exec()) {
            qWarning() << "verbindungenSynchronisieren del querverweis:" << del.lastError().text();
            m_db.rollback(); return false;
        }
    }

    // 3. Netze verarbeiten
    for (const QVariant &netVar : netze) {
        const QVariantMap net = netVar.toMap();
        const QString netKey      = net.value(QStringLiteral("netKey")).toString();
        const QString bezeichnung = net.value(QStringLiteral("bezeichnung")).toString();
        const QString signaltyp   = net.value(QStringLiteral("signaltyp"),  QStringLiteral("neutral")).toString();
        const QString farbe       = net.value(QStringLiteral("farbe")).toString();
        const double  querschnitt = net.value(QStringLiteral("querschnitt")).toDouble();

        if (netKey.isEmpty()) continue;

        // Verbindung per netKey (potenzial-Feld) suchen oder anlegen
        int verbId = -1;
        {
            QSqlQuery lookup;
            lookup.prepare("SELECT id FROM verbindung WHERE projekt_id = :pid AND potenzial = :key LIMIT 1");
            lookup.bindValue(":pid", projektId);
            lookup.bindValue(":key", netKey);
            if (lookup.exec() && lookup.next()) {
                verbId = lookup.value(0).toInt();
                // Nur signaltyp aktualisieren; Annotation (bezeichnung, farbe, querschnitt)
                // wird nur durch expliziten Nutzeraktion via verbindungAktualisieren geändert
                QSqlQuery upd;
                upd.prepare("UPDATE verbindung SET signaltyp = :sig WHERE id = :id");
                upd.bindValue(":sig", signaltyp);
                upd.bindValue(":id",  verbId);
                if (!upd.exec()) {
                    qWarning() << "verbindungenSynchronisieren update:" << upd.lastError().text();
                    m_db.rollback(); return false;
                }
            } else {
                QSqlQuery ins;
                ins.prepare(R"(
                    INSERT INTO verbindung (projekt_id, potenzial, bezeichnung, signaltyp, farbe, querschnitt_mm2)
                    VALUES (:pid, :key, :bez, :sig, :farbe, :q)
                )");
                ins.bindValue(":pid",   projektId);
                ins.bindValue(":key",   netKey);
                ins.bindValue(":bez",   bezeichnung.isEmpty()
                                        ? QVariant(QMetaType::fromType<QString>()) : bezeichnung);
                ins.bindValue(":sig",   signaltyp);
                ins.bindValue(":farbe", farbe.isEmpty()
                                        ? QVariant(QMetaType::fromType<QString>()) : farbe);
                ins.bindValue(":q",     querschnitt > 0
                                        ? querschnitt : QVariant(QMetaType::fromType<double>()));
                if (!ins.exec()) {
                    qWarning() << "verbindungenSynchronisieren insert verbindung:" << ins.lastError().text();
                    m_db.rollback(); return false;
                }
                verbId = ins.lastInsertId().toInt();
            }
        }

        // Segmente einfügen
        const QVariantList segmente = net.value(QStringLiteral("segmente")).toList();
        for (const QVariant &segVar : segmente) {
            const QVariantMap seg = segVar.toMap();
            QJsonArray punkte;
            punkte.append(QJsonObject{{ QStringLiteral("x"), seg.value(QStringLiteral("x1")).toDouble() },
                                      { QStringLiteral("y"), seg.value(QStringLiteral("y1")).toDouble() }});
            punkte.append(QJsonObject{{ QStringLiteral("x"), seg.value(QStringLiteral("x2")).toDouble() },
                                      { QStringLiteral("y"), seg.value(QStringLiteral("y2")).toDouble() }});
            QSqlQuery insSeg;
            insSeg.prepare("INSERT INTO verbindung_segment (verbindung_id, seite_id, punkte) VALUES (:vid, :sid, :pt)");
            insSeg.bindValue(":vid", verbId);
            insSeg.bindValue(":sid", seiteId);
            insSeg.bindValue(":pt",  QString::fromUtf8(QJsonDocument(punkte).toJson(QJsonDocument::Compact)));
            if (!insSeg.exec()) {
                qWarning() << "verbindungenSynchronisieren insert segment:" << insSeg.lastError().text();
                m_db.rollback(); return false;
            }
        }

        // Querverweise einfügen
        const QVariantList querverweise = net.value(QStringLiteral("querverweise")).toList();
        for (const QVariant &qvVar : querverweise) {
            const QVariantMap qv = qvVar.toMap();
            QSqlQuery insQv;
            insQv.prepare(R"(
                INSERT INTO querverweis (verbindung_id, von_seite_id, nach_seite_id, von_bezeichnung, nach_bezeichnung)
                VALUES (:vid, :von, :nach, :vonbez, :nachbez)
            )");
            insQv.bindValue(":vid",    verbId);
            insQv.bindValue(":von",    qv.value(QStringLiteral("vonSeiteId")).toInt());
            insQv.bindValue(":nach",   qv.value(QStringLiteral("nachSeiteId")).toInt());
            insQv.bindValue(":vonbez", qv.value(QStringLiteral("vonBezeichnung")).toString());
            insQv.bindValue(":nachbez",qv.value(QStringLiteral("nachBezeichnung")).toString());
            if (!insQv.exec()) {
                qWarning() << "verbindungenSynchronisieren insert querverweis:" << insQv.lastError().text();
                m_db.rollback(); return false;
            }
        }
    }

    if (!m_db.commit()) {
        qWarning() << "verbindungenSynchronisieren commit:" << m_db.lastError().text();
        m_db.rollback(); return false;
    }
    return true;
}

// ============================================================
// verbindungAktualisieren
// Schreibt Bezeichnung, Aderfarbe und Querschnitt einer Verbindung.
// ============================================================
bool Database::verbindungAktualisieren(int verbindungId, const QString &bezeichnung,
                                        const QString &farbe, double querschnitt)
{
    QSqlQuery q;
    q.prepare("UPDATE verbindung SET bezeichnung = :bez, farbe = :farbe, querschnitt_mm2 = :q WHERE id = :id");
    q.bindValue(":bez",   bezeichnung.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : bezeichnung);
    q.bindValue(":farbe", farbe.isEmpty()       ? QVariant(QMetaType::fromType<QString>()) : farbe);
    q.bindValue(":q",     querschnitt > 0       ? querschnitt : QVariant(QMetaType::fromType<double>()));
    q.bindValue(":id",    verbindungId);
    if (!q.exec()) {
        qWarning() << "verbindungAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// verbindungAnnotationenLaden
// Gibt alle Verbindungsannotationen für eine Seite zurück.
// Jede Zeile: {netKey (= potenzial), verbindungId, bezeichnung,
//              farbe, querschnitt_mm2, signaltyp}
// ============================================================
QVariantList Database::verbindungAnnotationenLaden(int seiteId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT v.id, v.potenzial, v.bezeichnung, v.farbe, v.querschnitt_mm2, v.signaltyp
        FROM verbindung_segment vs
        JOIN verbindung v ON v.id = vs.verbindung_id
        WHERE vs.seite_id = :sid
        GROUP BY v.id
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "verbindungAnnotationenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("verbindungId")]   = q.value(0).toInt();
        m[QStringLiteral("netKey")]         = q.value(1).toString();
        m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        m[QStringLiteral("farbe")]          = q.value(3).toString();
        m[QStringLiteral("querschnitt_mm2")]= q.value(4).isNull() ? 0.0 : q.value(4).toDouble();
        m[QStringLiteral("signaltyp")]      = q.value(5).toString();
        result.append(m);
    }
    return result;
}

// ============================================================
// verbindungenProjektLaden
// Alle Verbindungen eines Projekts (für Potenzial-Nummerierung).
// ============================================================
QVariantList Database::verbindungenProjektLaden(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare("SELECT id, bezeichnung, signaltyp FROM verbindung WHERE projekt_id = :pid ORDER BY id");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "verbindungenProjektLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]          = q.value(0).toInt();
        m[QStringLiteral("bezeichnung")] = q.value(1).toString();
        m[QStringLiteral("signaltyp")]   = q.value(2).toString();
        result.append(m);
    }
    return result;
}

// ============================================================
// naechsteFreiePotenzialNummer
// Gibt die nächste freie Bezeichnung nach Schema (praefix + Nummer)
// zurück, die noch nicht in verbindung.bezeichnung vergeben ist.
// ============================================================
QString Database::naechsteFreiePotenzialNummer(int projektId,
                                                const QString &praefix,
                                                int start, int schrittweite)
{
    QSqlQuery q;
    q.prepare("SELECT bezeichnung FROM verbindung WHERE projekt_id = :pid AND bezeichnung IS NOT NULL");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return praefix + QString::number(start);

    QSet<int> verwendet;
    while (q.next()) {
        QString bez = q.value(0).toString();
        if (!bez.startsWith(praefix)) continue;
        QString rest = bez.mid(praefix.length());
        bool ok = false;
        int n = rest.toInt(&ok);
        if (ok) verwendet.insert(n);
    }
    int n = start;
    const int sc = schrittweite > 0 ? schrittweite : 1;
    while (verwendet.contains(n)) n += sc;
    return praefix + QString::number(n);
}

// ============================================================
// verbindungenBulkBezeichnungSetzen
// Setzt in einer Transaktion die Bezeichnung mehrerer Verbindungen.
// zuweisungen: [{id (int), bezeichnung (string)}]
// ============================================================
bool Database::verbindungenBulkBezeichnungSetzen(int projektId, const QVariantList &zuweisungen)
{
    if (zuweisungen.isEmpty()) return true;
    if (!m_db.transaction()) {
        qWarning() << "verbindungenBulkBezeichnungSetzen: transaction:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q;
    q.prepare("UPDATE verbindung SET bezeichnung = :bez WHERE id = :id AND projekt_id = :pid");
    for (const QVariant &var : zuweisungen) {
        QVariantMap m = var.toMap();
        QString bez = m.value(QStringLiteral("bezeichnung")).toString();
        q.bindValue(":bez", bez.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : bez);
        q.bindValue(":id",  m.value(QStringLiteral("id")).toInt());
        q.bindValue(":pid", projektId);
        if (!q.exec()) {
            qWarning() << "verbindungenBulkBezeichnungSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    return m_db.commit();
}

// ============================================================
// alleSeitenFlach
// Gibt alle Seiten eines Projekts als flache Liste zurück.
// Wird im EigenschaftenPanel für den Querverweis-Seitenpicker
// benötigt: [{id, blattnummer, bezeichnung}].
// ============================================================
QVariantList Database::alleSeitenFlach(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT s.id, s.blattnummer, COALESCE(s.bezeichnung, '')
        FROM seite s
        JOIN ort     o ON o.id  = s.ort_id
        JOIN anlage  a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
        ORDER BY s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "alleSeitenFlach:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap s;
        s[QStringLiteral("id")]          = q.value(0).toInt();
        s[QStringLiteral("blattnummer")] = q.value(1).toString();
        s[QStringLiteral("bezeichnung")] = q.value(2).toString();
        result.append(s);
    }
    return result;
}

// ============================================================
// querverweiseLadenProjekt
// Alle Querverweis-Elemente eines Projekts seitenübergreifend.
// Gibt [{seiteId, blattnummer, seitenBezeichnung,
//        signalname, richtung, x1, y1}] zurück.
// ============================================================
QVariantList Database::querverweiseLadenProjekt(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.seite_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS s_bez,
               ge.extra_daten,
               ge.x1, ge.y1,
               COALESCE(a.kuerzel, '') AS anlage_kuerzel,
               COALESCE(o.kuerzel, '') AS ort_kuerzel
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id  = 'querverweis'
        ORDER BY s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "querverweiseLadenProjekt:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seiteId")]           = q.value(0).toInt();
        m[QStringLiteral("blattnummer")]        = q.value(1).toString();
        m[QStringLiteral("seitenBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("x1")]                 = q.value(4).toDouble();
        m[QStringLiteral("y1")]                 = q.value(5).toDouble();
        m[QStringLiteral("anlageKuerzel")]       = q.value(6).toString();
        m[QStringLiteral("ortKuerzel")]          = q.value(7).toString();

        QString signalname, richtung;
        QString extraStr = q.value(3).toString();
        if (!extraStr.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extraStr.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname = obj[QStringLiteral("signalname")].toString();
                richtung   = obj[QStringLiteral("richtung")].toString();
            }
        }
        if (richtung.isEmpty()) richtung = QStringLiteral("ausgang");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;

        result.append(m);
    }
    return result;
}

// ============================================================
// stueckliste
// Alle platzierten Symbole (ohne Verbindungshelfer) mit BMK,
// Freitexten und Seiteninfo für ein Projekt.
// ============================================================
QVariantList Database::stueckliste(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten, ge.symbol_id,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez,
               a.kuerzel AS anlage_kz,
               o.kuerzel AS ort_kz,
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ = 'symbol'
          AND ge.symbol_id NOT IN (
              'winkel','treffpunkt','geraeteanschluss','unterbrechung',
              'querverweis','aderdefinition','potenzial')
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "stueckliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("symbolId")]  = q.value(1).toString();
        m[QStringLiteral("seite")]     = q.value(2).toString();
        m[QStringLiteral("seiteBez")]  = q.value(3).toString();
        m[QStringLiteral("anlageKz")]  = q.value(4).toString();
        m[QStringLiteral("ortKz")]     = q.value(5).toString();

        QString extra = q.value(0).toString();
        QString bmk, ft1, ft2;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bmk = obj[QStringLiteral("bmk")].toString();
                ft1 = obj[QStringLiteral("freitext1")].toString();
                ft2 = obj[QStringLiteral("freitext2")].toString();
            }
        }
        m[QStringLiteral("bmk")]       = bmk;
        m[QStringLiteral("freitext1")] = ft1;
        m[QStringLiteral("freitext2")] = ft2;

        QString skExtra = q.value(6).toString();
        QString anlageUO, ortUO;
        if (!skExtra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(skExtra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                anlageUO = obj[QStringLiteral("anlageUO")].toString();
                ortUO    = obj[QStringLiteral("ortUO")].toString();
                // = und + aus Strukturkasten überschreiben Seitenbaum-Werte
                QString skAnlage = obj[QStringLiteral("anlage")].toString();
                QString skOrt    = obj[QStringLiteral("ort")].toString();
                if (!skAnlage.isEmpty()) m[QStringLiteral("anlageKz")] = skAnlage;
                if (!skOrt.isEmpty())    m[QStringLiteral("ortKz")]    = skOrt;
            }
        }
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        result.append(m);
    }
    return result;
}

// ============================================================
// querverweisListe
// Alle Querverweis-Symbole eines Projekts mit Signalname,
// Richtung, eigener Seite und Zielseite.
// ============================================================
QVariantList Database::querverweisListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten,
               s.blattnummer,
               COALESCE(s.bezeichnung, '') AS seite_bez
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.symbol_id = 'querverweis'
        ORDER BY s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "querverweisListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seite")]    = q.value(1).toString();
        m[QStringLiteral("seiteBez")] = q.value(2).toString();

        QString signalname, richtung;
        int     zielSeiteId = -1;
        QString extra = q.value(0).toString();
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                signalname  = obj[QStringLiteral("signalname")].toString();
                richtung    = obj[QStringLiteral("richtung")].toString();
                zielSeiteId = obj[QStringLiteral("zielSeiteId")].toInt(-1);
            }
        }
        if (richtung.isEmpty()) richtung = QStringLiteral("ausgang");
        m[QStringLiteral("signalname")] = signalname;
        m[QStringLiteral("richtung")]   = richtung;

        QString zielBlatt;
        if (zielSeiteId > 0) {
            QSqlQuery qs;
            qs.prepare("SELECT blattnummer FROM seite WHERE id = :id");
            qs.bindValue(":id", zielSeiteId);
            if (qs.exec() && qs.next())
                zielBlatt = qs.value(0).toString();
        }
        m[QStringLiteral("zielSeite")] = zielBlatt;
        result.append(m);
    }
    return result;
}

// ============================================================
// aderliste
// Alle Aderdefinitionspunkte eines Projekts mit Aderfarbe,
// Querschnitt, Länge, Bezeichnung und Seiteninfo.
// ============================================================
QVariantList Database::aderliste(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.extra_daten,
               s.blattnummer,
               a.kuerzel AS anlage_kz,
               o.kuerzel AS ort_kz,
               (SELECT sk.extra_daten
                FROM grafik_element sk
                WHERE sk.seite_id = ge.seite_id
                  AND sk.typ = 'strukturkasten'
                  AND (ge.x1 + ge.x2) / 2.0 >= sk.x1
                  AND (ge.x1 + ge.x2) / 2.0 <= sk.x2
                  AND (ge.y1 + ge.y2) / 2.0 >= sk.y1
                  AND (ge.y1 + ge.y2) / 2.0 <= sk.y2
                ORDER BY (sk.x2 - sk.x1) * (sk.y2 - sk.y1) ASC
                LIMIT 1) AS sk_extra
        FROM grafik_element ge
        JOIN seite  s ON s.id  = ge.seite_id
        JOIN ort    o ON o.id  = s.ort_id
        JOIN anlage a ON a.id  = o.anlage_id
        WHERE a.projekt_id = :pid
          AND ge.typ       = 'symbol'
          AND ge.symbol_id = 'aderdefinition'
        ORDER BY a.kuerzel, o.kuerzel, s.blattnummer, ge.rowid
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "aderliste:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("seite")]    = q.value(1).toString();
        m[QStringLiteral("anlageKz")] = q.value(2).toString();
        m[QStringLiteral("ortKz")]    = q.value(3).toString();

        QString extra = q.value(0).toString();
        QString bezeichnung, aderfarbe;
        double  querschnitt = 0.0, laenge = 0.0;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                bezeichnung = obj[QStringLiteral("bezeichnung")].toString();
                aderfarbe   = obj[QStringLiteral("aderfarbe")].toString();
                querschnitt = obj[QStringLiteral("querschnitt_mm2")].toDouble(0.0);
                laenge      = obj[QStringLiteral("laenge_m")].toDouble(0.0);
            }
        }
        m[QStringLiteral("bezeichnung")]    = bezeichnung;
        m[QStringLiteral("aderfarbe")]      = aderfarbe;
        m[QStringLiteral("querschnittMm2")] = querschnitt;
        m[QStringLiteral("laengeM")]        = laenge;

        QString skExtra = q.value(4).toString();
        QString anlageUO, ortUO;
        if (!skExtra.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(skExtra.toUtf8(), &err);
            if (!err.error && doc.isObject()) {
                QJsonObject obj = doc.object();
                anlageUO = obj[QStringLiteral("anlageUO")].toString();
                ortUO    = obj[QStringLiteral("ortUO")].toString();
                // = und + aus Strukturkasten überschreiben Seitenbaum-Werte
                QString skAnlage = obj[QStringLiteral("anlage")].toString();
                QString skOrt    = obj[QStringLiteral("ort")].toString();
                if (!skAnlage.isEmpty()) m[QStringLiteral("anlageKz")] = skAnlage;
                if (!skOrt.isEmpty())    m[QStringLiteral("ortKz")]    = skOrt;
            }
        }
        m[QStringLiteral("anlageUO")] = anlageUO;
        m[QStringLiteral("ortUO")]    = ortUO;
        result.append(m);
    }
    return result;
}

// ============================================================
// Betriebsmittel-Verknüpfung
// ============================================================

QVariantList Database::betriebsmittelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT b.id, b.betriebsmittel_kz, b.bezeichnung, "
        "       COUNT(g.id) AS anzahl "
        "FROM betriebsmittel b "
        "LEFT JOIN grafik_element g ON g.betriebsmittel_id = b.id "
        "WHERE b.projekt_id = :pid "
        "GROUP BY b.id ORDER BY b.betriebsmittel_kz");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]             = q.value(0).toInt();
        m[QStringLiteral("kz")]             = q.value(1).toString();
        m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        m[QStringLiteral("anzahl")]         = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

int Database::betriebsmittelAnlegen(int projektId, const QString &kz, const QString &bezeichnung)
{
    QSqlQuery q;
    q.prepare("INSERT INTO betriebsmittel (projekt_id, betriebsmittel_kz, bezeichnung) "
              "VALUES (:pid, :kz, :bez)");
    q.bindValue(":pid", projektId);
    q.bindValue(":kz",  kz);
    q.bindValue(":bez", bezeichnung);
    if (!q.exec()) {
        qWarning() << "betriebsmittelAnlegen Fehler:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::grafikElementVerknuepfen(int elementId, int betriebsmittelId)
{
    QSqlQuery q;
    q.prepare("UPDATE grafik_element SET betriebsmittel_id = :bid WHERE id = :id");
    q.bindValue(":bid", betriebsmittelId);
    q.bindValue(":id",  elementId);
    if (!q.exec()) {
        qWarning() << "grafikElementVerknuepfen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::grafikElementEntknuepfen(int elementId)
{
    // Falls dieses Element Hauptfunktion ist → haupt_element_id freigeben
    QSqlQuery clr;
    clr.prepare("UPDATE betriebsmittel SET haupt_element_id = NULL "
                "WHERE haupt_element_id = :eid");
    clr.bindValue(":eid", elementId);
    clr.exec();

    QSqlQuery q;
    q.prepare("UPDATE grafik_element SET betriebsmittel_id = NULL WHERE id = :id");
    q.bindValue(":id", elementId);
    if (!q.exec()) {
        qWarning() << "grafikElementEntknuepfen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::betriebsmittelMitglieder(int betriebsmittelId)
{
    // haupt_element_id laden um istHauptfunktion zu bestimmen
    int hauptId = 0;
    {
        QSqlQuery hq;
        hq.prepare("SELECT haupt_element_id FROM betriebsmittel WHERE id = :id");
        hq.bindValue(":id", betriebsmittelId);
        if (hq.exec() && hq.next() && !hq.value(0).isNull())
            hauptId = hq.value(0).toInt();
    }

    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT g.id, s.blattnummer, s.bezeichnung, g.extra_daten, g.symbol_id, g.typ "
        "FROM grafik_element g "
        "JOIN seite s ON s.id = g.seite_id "
        "WHERE g.betriebsmittel_id = :bid "
        "ORDER BY s.blattnummer, g.id");
    q.bindValue(":bid", betriebsmittelId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        int gid = q.value(0).toInt();
        m[QStringLiteral("id")]               = gid;
        m[QStringLiteral("blattnummer")]      = q.value(1).toString();
        m[QStringLiteral("seiteBezeichnung")] = q.value(2).toString();
        m[QStringLiteral("symbolId")]         = q.value(4).toString();
        m[QStringLiteral("typ")]              = q.value(5).toString();
        m[QStringLiteral("istHauptfunktion")] = (hauptId > 0 && gid == hauptId);
        QString extra = q.value(3).toString();
        QString bmk;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject())
                bmk = doc.object()[QStringLiteral("bmk")].toString();
        }
        m[QStringLiteral("bmk")] = bmk;
        result.append(m);
    }
    return result;
}

QString Database::betriebsmittelKz(int betriebsmittelId)
{
    QSqlQuery q;
    q.prepare("SELECT betriebsmittel_kz FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return {};
}

QVariantMap Database::betriebsmittelInfo(int betriebsmittelId)
{
    QVariantMap m;
    QSqlQuery q;
    q.prepare("SELECT id, betriebsmittel_kz, bezeichnung, haupt_element_id "
              "FROM betriebsmittel WHERE id = :id");
    q.bindValue(":id", betriebsmittelId);
    if (!q.exec() || !q.next()) return m;
    m[QStringLiteral("id")]             = q.value(0).toInt();
    m[QStringLiteral("kz")]             = q.value(1).toString();
    m[QStringLiteral("bezeichnung")]    = q.value(2).toString();
    m[QStringLiteral("hauptElementId")] = q.value(3).isNull() ? 0 : q.value(3).toInt();
    return m;
}

bool Database::betriebsmittelHauptfunktionSetzen(int betriebsmittelId, int elementId)
{
    QSqlQuery q;
    q.prepare("UPDATE betriebsmittel SET haupt_element_id = :eid WHERE id = :bid");
    q.bindValue(":eid", elementId);
    q.bindValue(":bid", betriebsmittelId);
    if (!q.exec()) {
        qWarning() << "betriebsmittelHauptfunktionSetzen Fehler:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::betriebsmittelBmkSynchronisieren(int betriebsmittelId)
{
    QString kz = betriebsmittelKz(betriebsmittelId);
    if (kz.isEmpty()) return false;

    QSqlQuery sel;
    sel.prepare("SELECT id, extra_daten FROM grafik_element WHERE betriebsmittel_id = :bid");
    sel.bindValue(":bid", betriebsmittelId);
    if (!sel.exec()) return false;

    QSqlQuery upd;
    upd.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    while (sel.next()) {
        int gid = sel.value(0).toInt();
        QString extra = sel.value(1).toString();
        QJsonObject obj;
        if (!extra.isEmpty()) {
            QJsonParseError err;
            auto doc = QJsonDocument::fromJson(extra.toUtf8(), &err);
            if (!err.error && doc.isObject())
                obj = doc.object();
        }
        obj[QStringLiteral("bmk")] = kz;
        upd.bindValue(":ed", QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
        upd.bindValue(":id", gid);
        if (!upd.exec())
            qWarning() << "betriebsmittelBmkSynchronisieren Fehler Element" << gid << upd.lastError().text();
    }
    return true;
}

QVariantList Database::betriebsmittelHfListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT b.id, b.haupt_element_id, s.blattnummer, g.seite_id "
        "FROM betriebsmittel b "
        "JOIN grafik_element g ON g.id = b.haupt_element_id "
        "JOIN seite s ON s.id = g.seite_id "
        "WHERE b.projekt_id = :pid "
        "  AND b.haupt_element_id IS NOT NULL");
    q.bindValue(":pid", projektId);
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("betriebsmittelId")] = q.value(0).toInt();
        m[QStringLiteral("hauptElementId")]   = q.value(1).toInt();
        m[QStringLiteral("blattnummer")]      = q.value(2).toString();
        m[QStringLiteral("seiteId")]          = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// klemmenplan
// ============================================================
QVariantList Database::klemmenplan(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT kl.id, kl.bezeichnung, "
        "COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung), "
        "k.id, k.nummer, k.sortierung, "
        "COALESCE(b.bezeichnung,''), "
        "COALESCE(bk.anschluss_typ,''), "
        "COALESCE(fd.bezeichnung,''), "
        "COALESCE(fd.hex_wert,''), "
        "COALESCE(kl.standort_uebergeordnet,''), "
        "(SELECT MIN(bkq.min_mm2) || '\xe2\x80\x93' || MAX(bkq.max_mm2) || ' mm\xc2\xb2' "
        "   FROM bauteil_klemme_querschnitt bkq WHERE bkq.klemme_id = bk.id), "
        "(SELECT ks.potenzial_text FROM klemme_stegbruecke ks "
        " WHERE ks.klemmenleiste_id = kl.id "
        " AND (ks.von_klemme_id = k.id OR ks.bis_klemme_id = k.id) "
        " AND ks.potenzial_text IS NOT NULL LIMIT 1) "
        "FROM klemmenleiste kl "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "JOIN klemme k ON k.klemmenleiste_id = kl.id "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN farb_definition fd ON fd.id = bk.gehaeuse_farbe_id "
        "WHERE kl.projekt_id = :pid "
        "ORDER BY kl.bezeichnung, k.sortierung, k.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "Database::klemmenplan:" << q.lastError().text();
        return result;
    }

    int lastLeistenId = -1;
    while (q.next()) {
        int leisteId = q.value(0).toInt();

        if (leisteId != lastLeistenId) {
            QVariantMap row;
            row[QStringLiteral("typ")]         = QStringLiteral("leiste");
            row[QStringLiteral("leisteId")]    = leisteId;
            row[QStringLiteral("bezeichnung")] = q.value(1).toString();
            row[QStringLiteral("bmk")]         = q.value(2).toString();
            result.append(row);
            lastLeistenId = leisteId;
        }

        QString typ = q.value(7).toString();
        if      (typ == QLatin1String("schraube"))      typ = QStringLiteral("Schraube");
        else if (typ == QLatin1String("feder"))         typ = QStringLiteral("Feder");
        else if (typ == QLatin1String("push_in"))       typ = QStringLiteral("Push-In");
        else if (typ == QLatin1String("schneidklemme")) typ = QStringLiteral("Schneidklemme");

        QVariantMap row;
        row[QStringLiteral("typ")]          = QStringLiteral("klemme");
        row[QStringLiteral("leisteId")]     = leisteId;
        row[QStringLiteral("leisteBmk")]    = q.value(2).toString();
        row[QStringLiteral("nummer")]       = q.value(4).toString();
        row[QStringLiteral("bauteilBez")]   = q.value(6).toString();
        row[QStringLiteral("anschlussTyp")] = typ;
        row[QStringLiteral("farbeBez")]     = q.value(8).toString();
        row[QStringLiteral("farbeHex")]     = q.value(9).toString();
        row[QStringLiteral("ortKz")]        = q.value(10).toString();
        row[QStringLiteral("querschnitt")]  = q.value(11).isNull() ? QString() : q.value(11).toString();
        row[QStringLiteral("potenzial")]    = q.value(12).isNull() ? QString() : q.value(12).toString();
        result.append(row);
    }
    return result;
}

// ============================================================
// klemmenplanCsvSpeichern
// ============================================================
bool Database::klemmenplanCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "klemmenplanCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";  // UTF-8 BOM für Excel
    out << "Leiste;Nr.;Bauteil;Typ;Querschnitt;Farbe;Potenzial;Ort\n";

    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };

    for (const QVariant &v : klemmenplan(projektId)) {
        const QVariantMap row = v.toMap();
        if (row[QStringLiteral("typ")] != QLatin1String("klemme")) continue;
        out << csvQ(row[QStringLiteral("leisteBmk")].toString())   << u';'
            << csvQ(row[QStringLiteral("nummer")].toString())       << u';'
            << csvQ(row[QStringLiteral("bauteilBez")].toString())   << u';'
            << csvQ(row[QStringLiteral("anschlussTyp")].toString()) << u';'
            << csvQ(row[QStringLiteral("querschnitt")].toString())  << u';'
            << csvQ(row[QStringLiteral("farbeBez")].toString())     << u';'
            << csvQ(row[QStringLiteral("potenzial")].toString())    << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())        << u'\n';
    }
    return true;
}

// ============================================================
// stuecklisteCsvSpeichern
// ============================================================
bool Database::stuecklisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "stuecklisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "BMK;Typ;Freitext 1;Freitext 2;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : stueckliste(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("bmk")].toString())       << u';'
            << csvQ(row[QStringLiteral("symbolId")].toString())  << u';'
            << csvQ(row[QStringLiteral("freitext1")].toString()) << u';'
            << csvQ(row[QStringLiteral("freitext2")].toString()) << u';'
            << csvQ(row[QStringLiteral("seite")].toString())     << u';'
            << csvQ(row[QStringLiteral("anlageUO")].toString())  << u';'
            << csvQ(row[QStringLiteral("ortUO")].toString())     << u';'
            << csvQ(row[QStringLiteral("anlageKz")].toString())  << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())     << u'\n';
    }
    return true;
}

// ============================================================
// querverweislisteCsvSpeichern
// ============================================================
bool Database::querverweislisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "querverweislisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Signalname;Richtung;Seite;Zielseite\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : querverweisListe(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("signalname")].toString()) << u';'
            << csvQ(row[QStringLiteral("richtung")].toString())   << u';'
            << csvQ(row[QStringLiteral("seite")].toString())      << u';'
            << csvQ(row[QStringLiteral("zielSeite")].toString())  << u'\n';
    }
    return true;
}

// ============================================================
// aderlisteCsvSpeichern
// ============================================================
bool Database::aderlisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "aderlisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Bezeichnung;Aderfarbe;Querschnitt mm2;Laenge m;Seite;==Anlage;++Ort;=Anlage;+Ort\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &v : aderliste(projektId)) {
        const QVariantMap row = v.toMap();
        out << csvQ(row[QStringLiteral("bezeichnung")].toString())                          << u';'
            << csvQ(row[QStringLiteral("aderfarbe")].toString())                            << u';'
            << csvQ(row[QStringLiteral("querschnittMm2")].toDouble() > 0
                    ? QString::number(row[QStringLiteral("querschnittMm2")].toDouble()) : QString()) << u';'
            << csvQ(row[QStringLiteral("laengeM")].toDouble() > 0
                    ? QString::number(row[QStringLiteral("laengeM")].toDouble()) : QString())        << u';'
            << csvQ(row[QStringLiteral("seite")].toString())    << u';'
            << csvQ(row[QStringLiteral("anlageUO")].toString()) << u';'
            << csvQ(row[QStringLiteral("ortUO")].toString())    << u';'
            << csvQ(row[QStringLiteral("anlageKz")].toString()) << u';'
            << csvQ(row[QStringLiteral("ortKz")].toString())    << u'\n';
    }
    return true;
}

// ============================================================
// kabellisteCsvSpeichern
// ============================================================
bool Database::kabellisteCsvSpeichern(int projektId, const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "kabellisteCsvSpeichern: kann nicht öffnen:" << localPath;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Kabel-BMK;Kabeltyp;Von-Ort;Nach-Ort;Ader-Nr;Farbe;Bezeichnung;Seite;Netz\n";
    auto csvQ = [](const QString &s) -> QString {
        if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
            return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
        return s;
    };
    for (const QVariant &kv : kabelListeAufgeschluesselt(projektId)) {
        const QVariantMap k = kv.toMap();
        const QString bmk     = k[QStringLiteral("bezeichnung")].toString();
        const QString typ     = k[QStringLiteral("kabeltyp")].toString();
        const QString vonOrt  = k[QStringLiteral("vonOrt")].toString();
        const QString nachOrt = k[QStringLiteral("nachOrt")].toString();
        const QVariantList adern = k[QStringLiteral("adern")].toList();
        if (adern.isEmpty()) {
            // Kabel ohne Adern: eine Zeile nur mit Kabel-Metadaten
            out << csvQ(bmk) << u';' << csvQ(typ) << u';'
                << csvQ(vonOrt) << u';' << csvQ(nachOrt)
                << u";;;;;" << u'\n';
        } else {
            for (const QVariant &av : adern) {
                const QVariantMap a = av.toMap();
                const QString seite = a[QStringLiteral("blattnummer")].toString();
                const QString seiteBez = a[QStringLiteral("seitenBez")].toString();
                const QString seiteSpalte = seite.isEmpty() ? QString()
                    : (seiteBez.isEmpty() ? seite : seite + u' ' + seiteBez);
                out << csvQ(bmk)     << u';'
                    << csvQ(typ)     << u';'
                    << csvQ(vonOrt)  << u';'
                    << csvQ(nachOrt) << u';'
                    << csvQ(QString::number(a[QStringLiteral("nr")].toInt())) << u';'
                    << csvQ(a[QStringLiteral("farbe")].toString())       << u';'
                    << csvQ(a[QStringLiteral("bezeichnung")].toString()) << u';'
                    << csvQ(seiteSpalte)                                  << u';'
                    << csvQ(a[QStringLiteral("netz")].toString())        << u'\n';
            }
        }
    }
    return true;
}

// ============================================================
// seiteBasisDaten – Blattnummer + Bezeichnung für eine Seite
// ============================================================
QVariantMap Database::seiteBasisDaten(int seiteId)
{
    QSqlQuery q;
    q.prepare("SELECT blattnummer, COALESCE(bezeichnung,'') FROM seite WHERE id = :id");
    q.bindValue(":id", seiteId);
    if (!q.exec() || !q.next()) return {};
    QVariantMap m;
    m[QStringLiteral("blattnummer")] = q.value(0).toString();
    m[QStringLiteral("bezeichnung")] = q.value(1).toString();
    return m;
}

// ============================================================
// normblattDatenLaden / normblattAnzeigenSetzen
// ============================================================
QVariantMap Database::normblattDatenLaden(int seiteId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT s.blattnummer, s.bezeichnung, s.anlage_kuerzel, s.ort_kuerzel,
               s.breite_mm, s.hoehe_mm, s.normblatt_anzeigen,
               s.hintergrund_farbe, s.aussen_overlay, s.titelblatt_vorlage,
               s.revision_status, s.revision_kennung,
               p.name         AS projekt_name,
               p.projektnummer,
               p.auftraggeber,
               p.auftragnehmer,
               p.bearbeiter,
               p.norm,
               p.erstellt_am,
               COALESCE(s.rand_links_mm,  nv.rand_links_mm,  20) AS rand_links_mm,
               COALESCE(s.rand_rechts_mm, nv.rand_rechts_mm, 10) AS rand_rechts_mm,
               COALESCE(s.rand_oben_mm,   nv.rand_oben_mm,   10) AS rand_oben_mm,
               COALESCE(s.rand_unten_mm,  nv.rand_unten_mm,  10) AS rand_unten_mm
        FROM seite s
        JOIN ort     o  ON s.ort_id      = o.id
        JOIN anlage  a  ON o.anlage_id   = a.id
        JOIN projekt p  ON a.projekt_id  = p.id
        LEFT JOIN normblatt_vorlage nv ON s.normblatt_id = nv.id
        WHERE s.id = :sid
    )");
    q.bindValue(":sid", seiteId);

    QVariantMap m;
    if (!q.exec() || !q.next()) {
        qWarning() << "normblattDatenLaden:" << q.lastError().text();
        return m;
    }
    m[QStringLiteral("blattnummer")]      = q.value("blattnummer");
    m[QStringLiteral("bezeichnung")]      = q.value("bezeichnung");
    m[QStringLiteral("anlageKuerzel")]    = q.value("anlage_kuerzel");
    m[QStringLiteral("ortKuerzel")]       = q.value("ort_kuerzel");
    m[QStringLiteral("breiteMm")]         = q.value("breite_mm");
    m[QStringLiteral("hoeheMm")]          = q.value("hoehe_mm");
    m[QStringLiteral("normblattAnzeigen")] = q.value("normblatt_anzeigen");
    m[QStringLiteral("hintergrundFarbe")] = q.value("hintergrund_farbe");
    m[QStringLiteral("aussenOverlay")]    = q.value("aussen_overlay");
    m[QStringLiteral("titelblattVorlage")] = q.value("titelblatt_vorlage");
    m[QStringLiteral("revisionStatus")]   = q.value("revision_status");
    m[QStringLiteral("revisionKennung")]  = q.value("revision_kennung");
    m[QStringLiteral("projektName")]      = q.value("projekt_name");
    m[QStringLiteral("projektnummer")]    = q.value("projektnummer");
    m[QStringLiteral("auftraggeber")]     = q.value("auftraggeber");
    m[QStringLiteral("auftragnehmer")]    = q.value("auftragnehmer");
    m[QStringLiteral("bearbeiter")]       = q.value("bearbeiter");
    m[QStringLiteral("norm")]             = q.value("norm");

    // Logo als Data-URL — separater Query damit der BLOB-Join nicht bei jeder
    // Seite lädt wenn kein Logo gesetzt ist.
    {
        QSqlQuery ql;
        ql.prepare(R"(
            SELECT p.logo_data, p.logo_mime
            FROM seite s
            JOIN ort o ON s.ort_id = o.id
            JOIN anlage a ON o.anlage_id = a.id
            JOIN projekt p ON a.projekt_id = p.id
            WHERE s.id = :sid AND p.logo_data IS NOT NULL
        )");
        ql.bindValue(":sid", seiteId);
        if (ql.exec() && ql.next()) {
            QByteArray logoData = ql.value(0).toByteArray();
            QString    logoMime = ql.value(1).toString();
            if (!logoData.isEmpty() && !logoMime.isEmpty())
                m[QStringLiteral("logoDataUrl")] = QStringLiteral("data:") + logoMime
                    + QStringLiteral(";base64,") + QString::fromLatin1(logoData.toBase64());
        }
    }
    m[QStringLiteral("erstelltAm")]       = q.value("erstellt_am");
    m[QStringLiteral("randLinksMm")]      = q.value("rand_links_mm");
    m[QStringLiteral("randRechtsMm")]     = q.value("rand_rechts_mm");
    m[QStringLiteral("randObenMm")]       = q.value("rand_oben_mm");
    m[QStringLiteral("randUntenMm")]      = q.value("rand_unten_mm");

    // Benutzerdefinierte Felder laden (nur wenn normblatt_id gesetzt)
    {
        QSqlQuery qnid;
        qnid.prepare("SELECT normblatt_id FROM seite WHERE id = :sid");
        qnid.bindValue(":sid", seiteId);
        if (qnid.exec() && qnid.next()) {
            QVariant normblattId = qnid.value(0);
            if (!normblattId.isNull() && normblattId.toInt() > 0) {
                m[QStringLiteral("normblattVorlageId")] = normblattId;
                m[QStringLiteral("felder")] = normblattFelderLaden(normblattId.toInt());
            }
        }
    }

    return m;
}

bool Database::normblattEinstellungenSetzen(int seiteId, bool anzeigen,
                                             const QString &hintergrundFarbe,
                                             bool aussenOverlay,
                                             const QString &titelblattVorlage,
                                             int normblattId)
{
    QSqlQuery q;
    q.prepare(R"(UPDATE seite SET
        normblatt_anzeigen = :an,
        hintergrund_farbe  = :hf,
        aussen_overlay     = :ao,
        titelblatt_vorlage = :tv,
        normblatt_id       = :nid
        WHERE id = :sid)");
    q.bindValue(":an",  anzeigen ? 1 : 0);
    q.bindValue(":hf",  hintergrundFarbe);
    q.bindValue(":ao",  aussenOverlay ? 1 : 0);
    q.bindValue(":tv",  titelblattVorlage.isEmpty() ? QStringLiteral("din6771") : titelblattVorlage);
    q.bindValue(":nid", normblattId > 0 ? QVariant(normblattId) : QVariant());
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "normblattEinstellungenSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// seiteRevision*
// ============================================================

bool Database::seiteRevisionSetzen(int seiteId, const QString &status, const QString &kennung)
{
    QSqlQuery q;
    q.prepare("UPDATE seite SET revision_status = :st, revision_kennung = :kn WHERE id = :sid");
    q.bindValue(":st",  status);
    q.bindValue(":kn",  kennung);
    q.bindValue(":sid", seiteId);
    if (!q.exec()) {
        qWarning() << "seiteRevisionSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// normblattVorlagen* / normblattFelder*
// ============================================================

QVariantList Database::normblattVorlagenListe()
{
    QSqlQuery q;
    if (!q.exec("SELECT id, name, beschreibung, ist_standard, breite_mm, hoehe_mm, "
                "rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm "
                "FROM normblatt_vorlage ORDER BY name")) {
        qWarning() << "normblattVorlagenListe:" << q.lastError().text();
        return {};
    }
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]           = q.value("id");
        m[QStringLiteral("name")]         = q.value("name");
        m[QStringLiteral("beschreibung")] = q.value("beschreibung");
        m[QStringLiteral("istStandard")]  = q.value("ist_standard");
        m[QStringLiteral("breiteMm")]     = q.value("breite_mm");
        m[QStringLiteral("hoeheMm")]      = q.value("hoehe_mm");
        m[QStringLiteral("randLinksMm")]  = q.value("rand_links_mm");
        m[QStringLiteral("randRechtsMm")] = q.value("rand_rechts_mm");
        m[QStringLiteral("randObenMm")]   = q.value("rand_oben_mm");
        m[QStringLiteral("randUntenMm")]  = q.value("rand_unten_mm");
        result.append(m);
    }
    return result;
}

int Database::normblattVorlageSpeichern(const QVariantMap &v)
{
    QSqlQuery q;
    if (v.value(QStringLiteral("id")).toInt() > 0) {
        q.prepare(R"(UPDATE normblatt_vorlage SET
            name           = :name,
            beschreibung   = :beschr,
            breite_mm      = :bMm,
            hoehe_mm       = :hMm,
            rand_links_mm  = :rl,
            rand_rechts_mm = :rr,
            rand_oben_mm   = :ro,
            rand_unten_mm  = :ru
            WHERE id = :id)");
        q.bindValue(":id",    v.value(QStringLiteral("id")));
    } else {
        q.prepare(R"(INSERT INTO normblatt_vorlage
            (name, beschreibung, breite_mm, hoehe_mm,
             rand_links_mm, rand_rechts_mm, rand_oben_mm, rand_unten_mm)
            VALUES (:name, :beschr, :bMm, :hMm, :rl, :rr, :ro, :ru))");
    }
    q.bindValue(":name",   v.value(QStringLiteral("name")));
    q.bindValue(":beschr", v.value(QStringLiteral("beschreibung")));
    q.bindValue(":bMm",    v.value(QStringLiteral("breiteMm"),    297.0));
    q.bindValue(":hMm",    v.value(QStringLiteral("hoeheMm"),     210.0));
    q.bindValue(":rl",     v.value(QStringLiteral("randLinksMm"),  20.0));
    q.bindValue(":rr",     v.value(QStringLiteral("randRechtsMm"), 10.0));
    q.bindValue(":ro",     v.value(QStringLiteral("randObenMm"),   10.0));
    q.bindValue(":ru",     v.value(QStringLiteral("randUntenMm"),  10.0));
    if (!q.exec()) {
        qWarning() << "normblattVorlageSpeichern:" << q.lastError().text();
        return -1;
    }
    if (v.value(QStringLiteral("id")).toInt() > 0)
        return v.value(QStringLiteral("id")).toInt();
    return q.lastInsertId().toInt();
}

bool Database::normblattVorlageLoeschen(int vorlageId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM normblatt_vorlage WHERE id = :id");
    q.bindValue(":id", vorlageId);
    if (!q.exec()) {
        qWarning() << "normblattVorlageLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantList Database::normblattFelderLaden(int vorlageId)
{
    QSqlQuery q;
    q.prepare(R"(SELECT id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm,
                        label, inhalt, quelle_spalte,
                        schriftgroesse, fett, rahmen, reihenfolge
                 FROM normblatt_feld
                 WHERE vorlage_id = :vid
                 ORDER BY reihenfolge, id)");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qWarning() << "normblattFelderLaden:" << q.lastError().text();
        return {};
    }
    QVariantList result;
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]            = q.value("id");
        m[QStringLiteral("feldtyp")]       = q.value("feldtyp");
        m[QStringLiteral("xMm")]           = q.value("x_mm");
        m[QStringLiteral("yMm")]           = q.value("y_mm");
        m[QStringLiteral("breiteMm")]      = q.value("breite_mm");
        m[QStringLiteral("hoeheMm")]       = q.value("hoehe_mm");
        m[QStringLiteral("label")]         = q.value("label");
        m[QStringLiteral("inhalt")]        = q.value("inhalt");
        m[QStringLiteral("quelleSpalte")]  = q.value("quelle_spalte");
        m[QStringLiteral("schriftgroesse")]= q.value("schriftgroesse");
        m[QStringLiteral("fett")]          = q.value("fett");
        m[QStringLiteral("rahmen")]        = q.value("rahmen");
        m[QStringLiteral("reihenfolge")]   = q.value("reihenfolge");
        result.append(m);
    }
    return result;
}

bool Database::normblattFelderSpeichern(int vorlageId, const QVariantList &felder)
{
    QSqlDatabase db = QSqlDatabase::database();
    if (!db.transaction()) {
        qWarning() << "normblattFelderSpeichern: Transaction fehlgeschlagen";
        return false;
    }
    QSqlQuery q;
    q.prepare("DELETE FROM normblatt_feld WHERE vorlage_id = :vid");
    q.bindValue(":vid", vorlageId);
    if (!q.exec()) {
        qWarning() << "normblattFelderSpeichern DELETE:" << q.lastError().text();
        db.rollback();
        return false;
    }
    q.prepare(R"(INSERT INTO normblatt_feld
        (vorlage_id, feldtyp, x_mm, y_mm, breite_mm, hoehe_mm,
         label, inhalt, quelle_spalte, schriftgroesse, fett, rahmen, reihenfolge)
        VALUES (:vid, :ft, :x, :y, :b, :h, :lbl, :inh, :qs, :sg, :fett, :rahmen, :rei))");
    for (int i = 0; i < felder.size(); ++i) {
        const QVariantMap f = felder[i].toMap();
        q.bindValue(":vid",    vorlageId);
        q.bindValue(":ft",     f.value(QStringLiteral("feldtyp"), QStringLiteral("fest")));
        q.bindValue(":x",      f.value(QStringLiteral("xMm"), 0.0));
        q.bindValue(":y",      f.value(QStringLiteral("yMm"), 0.0));
        q.bindValue(":b",      f.value(QStringLiteral("breiteMm"), 50.0));
        q.bindValue(":h",      f.value(QStringLiteral("hoeheMm"), 13.0));
        q.bindValue(":lbl",    f.value(QStringLiteral("label")));
        q.bindValue(":inh",    f.value(QStringLiteral("inhalt")));
        q.bindValue(":qs",     f.value(QStringLiteral("quelleSpalte")));
        q.bindValue(":sg",     f.value(QStringLiteral("schriftgroesse"), 3.5));
        q.bindValue(":fett",   f.value(QStringLiteral("fett"), 0));
        q.bindValue(":rahmen", f.value(QStringLiteral("rahmen"), 1));
        q.bindValue(":rei",    i);
        if (!q.exec()) {
            qWarning() << "normblattFelderSpeichern INSERT:" << q.lastError().text();
            db.rollback();
            return false;
        }
    }
    db.commit();
    return true;
}

bool Database::projektMetaSpeichern(int projektId,
                                     const QString &name,
                                     const QString &projektnummer,
                                     const QString &auftraggeber,
                                     const QString &auftragnehmer,
                                     const QString &bearbeiter)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET name = :name, projektnummer = :nr, "
              "auftraggeber = :ag, auftragnehmer = :an, bearbeiter = :be "
              "WHERE id = :id");
    q.bindValue(":name", name);
    q.bindValue(":nr",   projektnummer);
    q.bindValue(":ag",   auftraggeber);
    q.bindValue(":an",   auftragnehmer);
    q.bindValue(":be",   bearbeiter);
    q.bindValue(":id",   projektId);
    if (!q.exec()) {
        qWarning() << "projektMetaSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::projektLogoSpeichern(int projektId, const QString &pfad)
{
    QUrl url(pfad);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : pfad;

    QFileInfo info(localPath);
    if (!info.exists()) { qWarning() << "projektLogoSpeichern: Datei nicht gefunden:" << localPath; return false; }
    if (info.size() > 5 * 1024 * 1024) { qWarning() << "projektLogoSpeichern: Datei zu groß"; return false; }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) { qWarning() << "projektLogoSpeichern: Öffnen fehlgeschlagen"; return false; }
    QByteArray data = file.readAll();
    file.close();

    QString suffix = info.suffix().toLower();
    QString mime = QStringLiteral("image/png");
    if      (suffix == QLatin1String("jpg") || suffix == QLatin1String("jpeg")) mime = QStringLiteral("image/jpeg");
    else if (suffix == QLatin1String("bmp"))  mime = QStringLiteral("image/bmp");
    else if (suffix == QLatin1String("gif"))  mime = QStringLiteral("image/gif");
    else if (suffix == QLatin1String("webp")) mime = QStringLiteral("image/webp");

    QSqlQuery q;
    q.prepare("UPDATE projekt SET logo_data = :d, logo_mime = :m WHERE id = :id");
    q.bindValue(":d",  data);
    q.bindValue(":m",  mime);
    q.bindValue(":id", projektId);
    if (!q.exec()) { qWarning() << "projektLogoSpeichern:" << q.lastError().text(); return false; }
    return true;
}

QString Database::projektLogoDataUrl(int projektId)
{
    QSqlQuery q;
    q.prepare("SELECT logo_data, logo_mime FROM projekt WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec() || !q.next()) return {};
    QByteArray data = q.value(0).toByteArray();
    QString    mime = q.value(1).toString();
    if (data.isEmpty() || mime.isEmpty()) return {};
    return QStringLiteral("data:") + mime + QStringLiteral(";base64,")
           + QString::fromLatin1(data.toBase64());
}

bool Database::projektLogoLoeschen(int projektId)
{
    QSqlQuery q;
    q.prepare("UPDATE projekt SET logo_data = NULL, logo_mime = NULL WHERE id = :id");
    q.bindValue(":id", projektId);
    if (!q.exec()) { qWarning() << "projektLogoLoeschen:" << q.lastError().text(); return false; }
    return true;
}

QVariantList Database::klemmenFuerLeiste(int leisteId) const
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT k.id, k.nummer, k.sortierung, k.bauteil_id, "
        "       bk.id, COALESCE(b.bezeichnung,''), "
        "       COALESCE(klb.bmk_vollstaendig, '-' || kl.bezeichnung) "
        "FROM klemme k "
        "JOIN klemmenleiste kl ON kl.id = k.klemmenleiste_id "
        "LEFT JOIN bauteil b ON b.id = k.bauteil_id "
        "LEFT JOIN bauteil_klemme bk ON bk.bauteil_id = k.bauteil_id "
        "LEFT JOIN klemmenleiste_bmk klb ON klb.id = kl.id "
        "WHERE k.klemmenleiste_id = :lid "
        "ORDER BY k.sortierung, k.id"
    );
    q.bindValue(":lid", leisteId);
    if (!q.exec()) { qWarning() << "klemmenFuerLeiste:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap row;
        row[QStringLiteral("id")]             = q.value(0).toInt();
        row[QStringLiteral("nummer")]         = q.value(1).toString();
        row[QStringLiteral("sortierung")]     = q.value(2).toInt();
        row[QStringLiteral("bauteilId")]      = q.value(3).toInt();
        row[QStringLiteral("bauteilKlemmeId")]= q.value(4).toInt();
        row[QStringLiteral("bezeichnung")]    = q.value(5).toString();
        row[QStringLiteral("leisteBmk")]      = q.value(6).toString();
        result.append(row);
    }
    return result;
}

QVariantList Database::anschluesseFuerKlemme(int bauteilId) const
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(
        "SELECT ebenen_anzahl, punkte_seite_a, punkte_seite_b, fuss_kontakt_pe "
        "FROM bauteil_klemme WHERE bauteil_id = :bid"
    );
    q.bindValue(":bid", bauteilId);
    if (!q.exec() || !q.next()) return result;

    int  ebenen = q.value(0).toInt();
    int  pA     = q.value(1).toInt();
    int  pB     = q.value(2).toInt();
    bool pe     = q.value(3).toInt() != 0;

    for (int e = 1; e <= ebenen; ++e) {
        int idx = 1;
        for (int a = 0; a < pA; ++a, ++idx) {
            QVariantMap anschluss;
            anschluss[QStringLiteral("bezeichnung")] = QString("%1.%2").arg(e).arg(idx);
            anschluss[QStringLiteral("seite")]       = QStringLiteral("A");
            anschluss[QStringLiteral("ebene")]       = e;
            result.append(anschluss);
        }
        for (int b = 0; b < pB; ++b, ++idx) {
            QVariantMap anschluss;
            anschluss[QStringLiteral("bezeichnung")] = QString("%1.%2").arg(e).arg(idx);
            anschluss[QStringLiteral("seite")]       = QStringLiteral("B");
            anschluss[QStringLiteral("ebene")]       = e;
            result.append(anschluss);
        }
    }
    if (pe) {
        QVariantMap anschluss;
        anschluss[QStringLiteral("bezeichnung")] = QStringLiteral("PE");
        anschluss[QStringLiteral("seite")]       = QString::fromUtf8("Fu\xc3\x9f");
        anschluss[QStringLiteral("ebene")]       = QStringLiteral("\xe2\x80\x93");
        result.append(anschluss);
    }
    return result;
}

// ============================================================
// kabelAnlegen
// Legt einen neuen kabel-Datensatz an und verknüpft ihn mit
// dem grafik_element der Kabeldefinitionslinie.
// Gibt die neue kabel-ID zurück oder -1 bei Fehler.
// ============================================================
int Database::kabelAnlegen(int projektId, const QString &bezeichnung,
                           const QString &kabeltyp, int aderzahl,
                           double querschnittMm2, int grafikElementId,
                           const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO kabel (projekt_id, bezeichnung, kabeltyp, aderzahl,
                           querschnitt_mm2, grafik_element_id, von_ort, nach_ort)
        VALUES (:pid, :bez, :typ, :anz, :qs, :geid, :von, :nach)
    )");
    q.bindValue(":pid",  projektId);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":geid", grafikElementId > 0 ? grafikElementId : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    if (!q.exec()) {
        qWarning() << "kabelAnlegen fehlgeschlagen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

// ============================================================
// kabelAderZuordnen
// Legt eine kabel_ader-Zeile an (oder aktualisiert sie falls
// ader_nr für dieses Kabel bereits vorhanden).
// ============================================================
bool Database::kabelAderZuordnen(int kabelId, int aderNr,
                                 const QString &farbe,
                                 const QString &bezeichnung,
                                 int verbindungId,
                                 int kabellinieGrafikElementId)
{
    QSqlQuery q;
    q.prepare("SELECT id FROM kabel_ader WHERE kabel_id=:kid AND ader_nr=:nr");
    q.bindValue(":kid", kabelId);
    q.bindValue(":nr",  aderNr);
    if (!q.exec()) {
        qWarning() << "kabelAderZuordnen SELECT:" << q.lastError().text();
        return false;
    }
    if (q.next()) {
        int existingId = q.value(0).toInt();
        QSqlQuery upd;
        upd.prepare(R"(
            UPDATE kabel_ader SET farbe=:f, bezeichnung=:b, verbindung_id=:vid,
                                  kabellinie_grafik_element_id=:lgeid
            WHERE id=:id
        )");
        upd.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        upd.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        upd.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        upd.bindValue(":id",    existingId);
        if (!upd.exec()) {
            qWarning() << "kabelAderZuordnen UPDATE:" << upd.lastError().text();
            return false;
        }
    } else {
        QSqlQuery ins;
        ins.prepare(R"(
            INSERT INTO kabel_ader (kabel_id, ader_nr, farbe, bezeichnung,
                                   verbindung_id, kabellinie_grafik_element_id)
            VALUES (:kid, :nr, :f, :b, :vid, :lgeid)
        )");
        ins.bindValue(":kid",   kabelId);
        ins.bindValue(":nr",    aderNr);
        ins.bindValue(":f",     farbe.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : farbe);
        ins.bindValue(":b",     bezeichnung.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : bezeichnung);
        ins.bindValue(":vid",   verbindungId > 0 ? verbindungId : QVariant(QMetaType(QMetaType::Int)));
        ins.bindValue(":lgeid", kabellinieGrafikElementId > 0
                                ? kabellinieGrafikElementId : QVariant(QMetaType(QMetaType::Int)));
        if (!ins.exec()) {
            qWarning() << "kabelAderZuordnen INSERT:" << ins.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// kabelLinieDetails
// Lädt Kabelmetadaten + Adern für ein grafik_element.
// ============================================================
QVariantMap Database::kabelLinieDetails(int grafikElementId)
{
    QVariantMap result;
    if (grafikElementId <= 0) return result;

    // Kabel über den kabelId-Eintrag im extra_daten-JSON des Grafikelements suchen.
    // Funktioniert auch für nicht-primäre Linien eines Kabels (M9).
    QSqlQuery q;
    q.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.grafik_element_id, k.bauteil_kabel_id, k.von_ort, k.nach_ort
        FROM kabel k
        WHERE k.id = (
            SELECT CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER)
            FROM grafik_element ge WHERE ge.id = :geid
        )
        LIMIT 1
    )");
    q.bindValue(":geid", grafikElementId);
    if (!q.exec() || !q.next())
        return result;

    int kabelId = q.value(0).toInt();
    result[QStringLiteral("id")]              = kabelId;
    result[QStringLiteral("bezeichnung")]     = q.value(1).toString();
    result[QStringLiteral("kabeltyp")]        = q.value(2).toString();
    result[QStringLiteral("aderzahl")]        = q.value(3).toInt();
    result[QStringLiteral("querschnittMm2")]  = q.value(4).toDouble();
    result[QStringLiteral("grafikElementId")] = q.value(5).toInt();
    result[QStringLiteral("bauteilKabelId")]  = q.value(6).toInt();
    result[QStringLiteral("vonOrt")]          = q.value(7).toString();
    result[QStringLiteral("nachOrt")]         = q.value(8).toString();

    QSqlQuery qa;
    qa.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id, kabellinie_grafik_element_id
        FROM kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
    )");
    qa.bindValue(":kid", kabelId);
    QVariantList adern;
    if (qa.exec()) {
        while (qa.next()) {
            QVariantMap ader;
            ader[QStringLiteral("aderNr")]                      = qa.value(0).toInt();
            ader[QStringLiteral("farbe")]                       = qa.value(1).toString();
            ader[QStringLiteral("bezeichnung")]                 = qa.value(2).toString();
            ader[QStringLiteral("verbindungId")]                = qa.value(3).toInt();
            ader[QStringLiteral("kabellinieGrafikElementId")]   = qa.value(4).toInt();
            adern.append(ader);
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelListe
// Alle Kabel eines Projekts – für den Kabel-Editor / Kabelliste.
// ============================================================
QVariantList Database::kabelListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, bezeichnung, kabeltyp, aderzahl, querschnitt_mm2,
               laenge_m, von_ort, nach_ort, grafik_element_id
        FROM kabel WHERE projekt_id = :pid ORDER BY bezeichnung
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "kabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q.value(7).toString();
        k[QStringLiteral("grafikElementId")]= q.value(8).toInt();
        result.append(k);
    }
    return result;
}

// ============================================================
// kabelListeAufgeschluesselt
// Alle Kabel eines Projekts mit ihren Ader-Unterzeilen.
// Zwei Queries: (1) Kabel + Linienanzahl, (2) alle Adern mit Seite + Netz.
// ============================================================
QVariantList Database::kabelListeAufgeschluesselt(int projektId)
{
    // ─── Pass 1: Kabel laden ────────────────────────────────
    QVariantList kabel;
    QHash<int, int> kabelIdx;  // kabelId → Index in kabel

    QSqlQuery q1;
    q1.prepare(R"(
        SELECT k.id, k.bezeichnung, k.kabeltyp, k.aderzahl, k.querschnitt_mm2,
               k.laenge_m, k.von_ort, k.nach_ort,
               COUNT(DISTINCT ka.kabellinie_grafik_element_id) AS linien_anzahl
        FROM kabel k
        LEFT JOIN kabel_ader ka ON ka.kabel_id = k.id
                                AND ka.kabellinie_grafik_element_id IS NOT NULL
        WHERE k.projekt_id = :pid
        GROUP BY k.id
        ORDER BY k.bezeichnung
    )");
    q1.bindValue(":pid", projektId);
    if (!q1.exec()) {
        qWarning() << "kabelListeAufgeschluesselt (kabel):" << q1.lastError().text();
        return kabel;
    }
    while (q1.next()) {
        QVariantMap k;
        k[QStringLiteral("id")]             = q1.value(0).toInt();
        k[QStringLiteral("bezeichnung")]    = q1.value(1).toString();
        k[QStringLiteral("kabeltyp")]       = q1.value(2).toString();
        k[QStringLiteral("aderzahl")]       = q1.value(3).toInt();
        k[QStringLiteral("querschnittMm2")] = q1.value(4).toDouble();
        k[QStringLiteral("laengeM")]        = q1.value(5).toDouble();
        k[QStringLiteral("vonOrt")]         = q1.value(6).toString();
        k[QStringLiteral("nachOrt")]        = q1.value(7).toString();
        k[QStringLiteral("linienAnzahl")]   = q1.value(8).toInt();
        k[QStringLiteral("adern")]          = QVariantList();
        kabelIdx[q1.value(0).toInt()]       = kabel.size();
        kabel.append(k);
    }

    // ─── Pass 2: Adern laden (alle Kabel des Projekts, ein Query) ──
    QSqlQuery q2;
    q2.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, COALESCE(ka.farbe, ''), COALESCE(ka.bezeichnung, ''),
               COALESCE(s.blattnummer, ''), COALESCE(s.bezeichnung, ''),
               COALESCE(v.bezeichnung, ''),
               COALESCE(ka.von_gerat_pin, ''), COALESCE(ka.nach_gerat_pin, '')
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        LEFT JOIN grafik_element ge ON ge.id = ka.kabellinie_grafik_element_id
        LEFT JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN verbindung v ON v.id = ka.verbindung_id
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q2.bindValue(":pid", projektId);
    if (!q2.exec()) {
        qWarning() << "kabelListeAufgeschluesselt (adern):" << q2.lastError().text();
        return kabel;
    }
    while (q2.next()) {
        int kId = q2.value(0).toInt();
        if (!kabelIdx.contains(kId)) continue;
        QVariantMap a;
        a[QStringLiteral("nr")]               = q2.value(1).toInt();
        a[QStringLiteral("farbe")]            = q2.value(2).toString();
        a[QStringLiteral("bezeichnung")]      = q2.value(3).toString();
        a[QStringLiteral("blattnummer")]      = q2.value(4).toString();
        a[QStringLiteral("seitenBez")]        = q2.value(5).toString();
        a[QStringLiteral("netz")]             = q2.value(6).toString();
        a[QStringLiteral("vonGeratPin")]      = q2.value(7).toString();
        a[QStringLiteral("nachGeratPin")]     = q2.value(8).toString();
        int idx = kabelIdx[kId];
        QVariantMap kMap = kabel[idx].toMap();
        QVariantList adern = kMap[QStringLiteral("adern")].toList();
        adern.append(a);
        kMap[QStringLiteral("adern")] = adern;
        kabel[idx] = kMap;
    }
    return kabel;
}

// ============================================================
// kabelMetaAktualisieren
// Aktualisiert Bezeichnung, Typ, Aderzahl, Querschnitt eines
// bestehenden Kabel-Datensatzes (z. B. nach EigenschaftenPanel-Änderung).
// ============================================================
bool Database::kabelMetaAktualisieren(int kabelId, const QString &bezeichnung,
                                       const QString &kabeltyp, int aderzahl,
                                       double querschnittMm2,
                                       const QString &vonOrt, const QString &nachOrt)
{
    QSqlQuery q;
    q.prepare(R"(
        UPDATE kabel SET bezeichnung=:bez, kabeltyp=:typ, aderzahl=:anz,
                         querschnitt_mm2=:qs, von_ort=:von, nach_ort=:nach
        WHERE id = :id
    )");
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":typ",  kabeltyp.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : kabeltyp);
    q.bindValue(":anz",  aderzahl > 0 ? aderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   querschnittMm2 > 0 ? querschnittMm2 : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":von",  vonOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : vonOrt);
    q.bindValue(":nach", nachOrt.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : nachOrt);
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qWarning() << "kabelMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// kabelAderListeMitVerbindung
// Gibt alle kabel_adern eines Projekts mit ihrer verbindung_id zurück –
// benötigt für den Verdrahtungsweg-Algorithmus (M11) in QML.
// ============================================================
QVariantList Database::kabelAderListeMitVerbindung(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ka.kabel_id, ka.ader_nr, ka.verbindung_id,
               COALESCE(ka.kabellinie_grafik_element_id, 0)
        FROM kabel_ader ka
        JOIN kabel k ON k.id = ka.kabel_id AND k.projekt_id = :pid
        WHERE ka.verbindung_id IS NOT NULL AND ka.verbindung_id > 0
        ORDER BY ka.kabel_id, ka.ader_nr
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "kabelAderListeMitVerbindung:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap a;
        a[QStringLiteral("kabelId")]                   = q.value(0).toInt();
        a[QStringLiteral("aderNr")]                    = q.value(1).toInt();
        a[QStringLiteral("verbindungId")]              = q.value(2).toInt();
        a[QStringLiteral("kabellinieGrafikElementId")] = q.value(3).toInt();
        result.append(a);
    }
    return result;
}

// ============================================================
// kabelAderEndpunkteBulkSetzen
// Speichert Von/Nach-Gerät:Pin für eine Liste von kabel_adern.
// adern: [{kabelId, aderNr, von, nach}]
// ============================================================
bool Database::kabelAderEndpunkteBulkSetzen(int projektId, const QVariantList &adern)
{
    if (adern.isEmpty()) return true;
    if (!m_db.transaction()) {
        qWarning() << "kabelAderEndpunkteBulkSetzen: Transaktion:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q;
    q.prepare(R"(
        UPDATE kabel_ader SET von_gerat_pin = :von, nach_gerat_pin = :nach
        WHERE kabel_id = :kid AND ader_nr = :nr
          AND EXISTS (SELECT 1 FROM kabel WHERE id = :kid2 AND projekt_id = :pid)
    )");
    for (const QVariant &av : adern) {
        const QVariantMap a = av.toMap();
        const QString von  = a.value(QStringLiteral("von")).toString();
        const QString nach = a.value(QStringLiteral("nach")).toString();
        q.bindValue(":von",  von.isEmpty()  ? QVariant(QMetaType::fromType<QString>()) : von);
        q.bindValue(":nach", nach.isEmpty() ? QVariant(QMetaType::fromType<QString>()) : nach);
        q.bindValue(":kid",  a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":kid2", a.value(QStringLiteral("kabelId")).toInt());
        q.bindValue(":nr",   a.value(QStringLiteral("aderNr")).toInt());
        q.bindValue(":pid",  projektId);
        if (!q.exec()) {
            qWarning() << "kabelAderEndpunkteBulkSetzen:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    if (!m_db.commit()) {
        qWarning() << "kabelAderEndpunkteBulkSetzen commit:" << m_db.lastError().text();
        m_db.rollback();
        return false;
    }
    return true;
}

// ============================================================
// kabelLoeschen
// Löscht Kabel + Adern. Das grafik_element selbst wird von QML
// gelöscht (grafikSpeichern); ON DELETE SET NULL sorgt dafür,
// dass kabel.grafik_element_id auf NULL gesetzt wird falls das
// Element zuerst gelöscht wird.
// ============================================================
bool Database::kabelLoeschen(int kabelId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM kabel WHERE id = :id");
    q.bindValue(":id", kabelId);
    if (!q.exec()) {
        qWarning() << "kabelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// bauteilKabelListe
// Alle Kabel-Bibliothekseinträge für den Picker-Dialog.
// Gibt [{id, bauteilId, bezeichnung, kabeltyp, aderzahl,
//        querschnittMm2, adern:[{farbe,querschnittMm2}]}] zurück.
// ============================================================
QVariantList Database::bauteilKabelListe()
{
    QVariantList result;
    {
        QSqlQuery cnt;
        cnt.exec("SELECT COUNT(*) FROM bauteil_kabel");
        if (cnt.next())
            qDebug() << "bauteilKabelListe: bauteil_kabel Zeilen=" << cnt.value(0).toInt();
        else
            qWarning() << "bauteilKabelListe: COUNT Fehler:" << cnt.lastError().text();
    }
    QSqlQuery q;
    if (!q.exec(R"(
        SELECT bk.id, bk.bauteil_id, b.bezeichnung, bk.kabeltyp,
               COUNT(ba.id) AS aderzahl,
               MAX(ba.querschnitt_mm2) AS quer
        FROM bauteil_kabel bk
        JOIN bauteil b ON b.id = bk.bauteil_id
        LEFT JOIN bauteil_kabel_ader ba ON ba.kabel_id = bk.id
        GROUP BY bk.id
        ORDER BY b.bezeichnung, bk.kabeltyp
    )")) {
        qWarning() << "bauteilKabelListe:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap k;
        int bkId = q.value(0).toInt();
        k[QStringLiteral("id")]             = bkId;
        k[QStringLiteral("bauteilId")]      = q.value(1).toInt();
        k[QStringLiteral("bezeichnung")]    = q.value(2).toString();
        k[QStringLiteral("kabeltyp")]       = q.value(3).toString();
        k[QStringLiteral("aderzahl")]       = q.value(4).toInt();
        k[QStringLiteral("querschnittMm2")] = q.value(5).toDouble();
        // Aderfarben für Farbvorschau laden
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT farbe, querschnitt_mm2 FROM bauteil_kabel_ader
            WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bkId);
        QVariantList adern;
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("farbe")]          = qa.value(0).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(1).toDouble();
                adern.append(a);
            }
        }
        k[QStringLiteral("adern")] = adern;
        result.append(k);
    }
    qDebug() << "bauteilKabelListe: Einträge=" << result.size();
    return result;
}

// ============================================================
// kabelBauteilKabelSetzen
// Weist einer Kabellinie ein Bauteil-Kabel zu (bauteilKabelId > 0)
// oder hebt die Zuweisung auf (bauteilKabelId <= 0).
// Bei Zuweisung werden kabeltyp/aderzahl/querschnitt_mm2 aus dem
// Bauteil-Kabel übernommen (können manuell überschrieben werden).
// Gibt die aktualisierten Metadaten zurück.
// ============================================================
QVariantMap Database::kabelBauteilKabelSetzen(int kabelId, int bauteilKabelId)
{
    QVariantMap result;
    QString neuerTyp;
    int     neueAderzahl = 0;
    double  neuerQuer    = 0.0;

    if (bauteilKabelId > 0) {
        QSqlQuery qbk;
        qbk.prepare(R"(
            SELECT bk.kabeltyp, COUNT(ba.id), MAX(ba.querschnitt_mm2)
            FROM bauteil_kabel bk
            LEFT JOIN bauteil_kabel_ader ba ON ba.kabel_id = bk.id
            WHERE bk.id = :id GROUP BY bk.id
        )");
        qbk.bindValue(":id", bauteilKabelId);
        if (qbk.exec() && qbk.next()) {
            neuerTyp     = qbk.value(0).toString();
            neueAderzahl = qbk.value(1).toInt();
            neuerQuer    = qbk.value(2).toDouble();
        }
    }

    QSqlQuery q;
    q.prepare(R"(
        UPDATE kabel SET bauteil_kabel_id=:bkid, kabeltyp=:typ,
               aderzahl=:anz, querschnitt_mm2=:qs
        WHERE id = :id
    )");
    q.bindValue(":bkid", bauteilKabelId > 0 ? QVariant(bauteilKabelId) : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":typ",  neuerTyp.isEmpty()  ? QVariant(QMetaType(QMetaType::QString)) : neuerTyp);
    q.bindValue(":anz",  neueAderzahl > 0    ? neueAderzahl : QVariant(QMetaType(QMetaType::Int)));
    q.bindValue(":qs",   neuerQuer > 0       ? neuerQuer    : QVariant(QMetaType(QMetaType::Double)));
    q.bindValue(":id",   kabelId);
    if (!q.exec()) {
        qWarning() << "kabelBauteilKabelSetzen:" << q.lastError().text();
        return result;
    }
    result[QStringLiteral("kabeltyp")]       = neuerTyp;
    result[QStringLiteral("aderzahl")]       = neueAderzahl;
    result[QStringLiteral("querschnittMm2")] = neuerQuer;
    result[QStringLiteral("bauteilKabelId")] = bauteilKabelId > 0 ? bauteilKabelId : 0;

    // Aderliste für Canvas-Schnittpunkt-Beschriftung
    QVariantList adern;
    if (bauteilKabelId > 0) {
        QSqlQuery qa;
        qa.prepare(R"(
            SELECT ader_nr, farbe, bezeichnung, querschnitt_mm2
            FROM bauteil_kabel_ader WHERE kabel_id = :kid ORDER BY ader_nr
        )");
        qa.bindValue(":kid", bauteilKabelId);
        if (qa.exec()) {
            while (qa.next()) {
                QVariantMap a;
                a[QStringLiteral("aderNr")]         = qa.value(0).toInt();
                a[QStringLiteral("farbe")]          = qa.value(1).toString();
                a[QStringLiteral("bezeichnung")]    = qa.value(2).toString();
                a[QStringLiteral("querschnittMm2")] = qa.value(3).toDouble();
                adern.append(a);
            }
        }
    }
    result[QStringLiteral("adern")] = adern;
    return result;
}

// ============================================================
// kabelAlleLinienLaden
// Alle Kabellinie-Grafikelemente eines Kabels (alle Seiten).
// ============================================================
QVariantList Database::kabelAlleLinienLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ge.id, ge.seite_id, s.bezeichnung,
               COUNT(ka.id) AS ader_anzahl
        FROM grafik_element ge
        JOIN seite s ON s.id = ge.seite_id
        LEFT JOIN kabel_ader ka ON ka.kabellinie_grafik_element_id = ge.id
        WHERE ge.typ = 'kabellinie'
          AND CAST(json_extract(ge.extra_daten, '$.kabelId') AS INTEGER) = :kid
        GROUP BY ge.id
        ORDER BY ge.seite_id, ge.sortierung
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qWarning() << "kabelAlleLinienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("grafikElementId")]   = q.value(0).toInt();
        m[QStringLiteral("seiteId")]           = q.value(1).toInt();
        m[QStringLiteral("seiteBezeichnung")]  = q.value(2).toString();
        m[QStringLiteral("aderAnzahl")]        = q.value(3).toInt();
        result.append(m);
    }
    return result;
}

// ============================================================
// kabelFreieAderLaden
// Adern eines Kabels die keiner Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelFreieAderLaden(int kabelId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabel_id = :kid AND kabellinie_grafik_element_id IS NULL
        ORDER BY ader_nr
    )");
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qWarning() << "kabelFreieAderLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(2).toString();
        ader[QStringLiteral("verbindungId")]= q.value(3).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// kabelAderFuerLinieLaden
// Adern die einer bestimmten Kabellinie zugeordnet sind.
// ============================================================
QVariantList Database::kabelAderFuerLinieLaden(int kabellinieGrafikElementId)
{
    QVariantList result;
    if (kabellinieGrafikElementId <= 0) return result;
    QSqlQuery q;
    q.prepare(R"(
        SELECT ader_nr, farbe, bezeichnung, verbindung_id
        FROM kabel_ader
        WHERE kabellinie_grafik_element_id = :geid
        ORDER BY ader_nr
    )");
    q.bindValue(":geid", kabellinieGrafikElementId);
    if (!q.exec()) {
        qWarning() << "kabelAderFuerLinieLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap ader;
        ader[QStringLiteral("aderNr")]      = q.value(0).toInt();
        ader[QStringLiteral("farbe")]       = q.value(1).toString();
        ader[QStringLiteral("bezeichnung")] = q.value(2).toString();
        ader[QStringLiteral("verbindungId")]= q.value(3).toInt();
        result.append(ader);
    }
    return result;
}

// ============================================================
// makroSpeichern
// Sammelt alle grafik_element innerhalb des Makrokastens
// (Mittelpunkt-Einschlussregel) und schreibt makro + makro_element.
// Gibt makro.id zurück (>0) oder -1 bei Fehler.
// ============================================================
int Database::makroSpeichern(int grafikElementId, int seiteId)
{
    // Makrokasten-Geometrie laden
    QSqlQuery qk;
    qk.prepare("SELECT x1, y1, x2, y2, extra_daten FROM grafik_element WHERE id = :id");
    qk.bindValue(":id", grafikElementId);
    if (!qk.exec() || !qk.next()) {
        qWarning() << "makroSpeichern: Kasten nicht gefunden" << grafikElementId;
        return -1;
    }
    const double kx1 = qk.value(0).toDouble();
    const double ky1 = qk.value(1).toDouble();
    const double kx2 = qk.value(2).toDouble();
    const double ky2 = qk.value(3).toDouble();
    const QString edJson = qk.value(4).toString();

    QJsonDocument edDoc  = QJsonDocument::fromJson(edJson.toUtf8());
    QJsonObject   ed     = edDoc.object();
    const QString name   = ed.value("name").toString("Makro");
    const QString beschr = ed.value("beschreibung").toString();
    const QString kat    = ed.value("kategorie").toString();
    const int existId    = ed.value("makroId").toInt(0);

    const double minX = std::min(kx1, kx2);
    const double minY = std::min(ky1, ky2);
    const double maxX = std::max(kx1, kx2);
    const double maxY = std::max(ky1, ky2);

    QSqlDatabase dbConn = QSqlDatabase::database();
    if (!dbConn.transaction()) {
        qWarning() << "makroSpeichern: transaction fehlgeschlagen";
        return -1;
    }

    int makroId = existId;
    QSqlQuery qm;

    if (makroId > 0) {
        qm.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k, "
                   "kasten_breite=:w, kasten_hoehe=:h WHERE id=:id");
        qm.bindValue(":n",  name);
        qm.bindValue(":b",  beschr);
        qm.bindValue(":k",  kat);
        qm.bindValue(":w",  maxX - minX);
        qm.bindValue(":h",  maxY - minY);
        qm.bindValue(":id", makroId);
        if (!qm.exec()) {
            qWarning() << "makroSpeichern UPDATE makro:" << qm.lastError().text();
            dbConn.rollback(); return -1;
        }
        QSqlQuery qdel;
        qdel.prepare("DELETE FROM makro_element WHERE makro_id = :id");
        qdel.bindValue(":id", makroId);
        if (!qdel.exec()) {
            qWarning() << "makroSpeichern DELETE makro_element:" << qdel.lastError().text();
            dbConn.rollback(); return -1;
        }
    } else {
        qm.prepare("INSERT INTO makro (name, beschreibung, kategorie, kasten_breite, kasten_hoehe) "
                   "VALUES (:n, :b, :k, :w, :h)");
        qm.bindValue(":n",  name);
        qm.bindValue(":b",  beschr);
        qm.bindValue(":k",  kat);
        qm.bindValue(":w",  maxX - minX);
        qm.bindValue(":h",  maxY - minY);
        if (!qm.exec()) {
            qWarning() << "makroSpeichern INSERT makro:" << qm.lastError().text();
            dbConn.rollback(); return -1;
        }
        makroId = qm.lastInsertId().toInt();
    }

    QSqlQuery qe;
    qe.prepare(R"(
        SELECT typ, x1, y1, x2, y2, extra_daten, symbol_id, sortierung
        FROM grafik_element
        WHERE seite_id = :sid
          AND id != :kid
          AND typ != 'makrokasten'
          AND (x1+x2)/2.0 BETWEEN :minx AND :maxx
          AND (y1+y2)/2.0 BETWEEN :miny AND :maxy
        ORDER BY sortierung
    )");
    qe.bindValue(":sid",  seiteId);
    qe.bindValue(":kid",  grafikElementId);
    qe.bindValue(":minx", minX);
    qe.bindValue(":maxx", maxX);
    qe.bindValue(":miny", minY);
    qe.bindValue(":maxy", maxY);
    if (!qe.exec()) {
        qWarning() << "makroSpeichern SELECT elemente:" << qe.lastError().text();
        dbConn.rollback(); return -1;
    }

    QSqlQuery qi;
    qi.prepare(R"(
        INSERT INTO makro_element (makro_id, typ, rel_x1, rel_y1, rel_x2, rel_y2,
                                   extra_daten, symbol_key, sortierung)
        VALUES (:mid, :typ, :rx1, :ry1, :rx2, :ry2, :ed, :sk, :sort)
    )");

    while (qe.next()) {
        qi.bindValue(":mid",  makroId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":rx1",  qe.value(1).toDouble() - minX);
        qi.bindValue(":ry1",  qe.value(2).toDouble() - minY);
        qi.bindValue(":rx2",  qe.value(3).toDouble() - minX);
        qi.bindValue(":ry2",  qe.value(4).toDouble() - minY);
        qi.bindValue(":ed",   qe.value(5));
        qi.bindValue(":sk",   qe.value(6));
        qi.bindValue(":sort", qe.value(7));
        if (!qi.exec()) {
            qWarning() << "makroSpeichern INSERT makro_element:" << qi.lastError().text();
            dbConn.rollback(); return -1;
        }
    }

    // makroId in extra_daten des Kastens zurückschreiben
    ed["makroId"] = makroId;
    QSqlQuery qu;
    qu.prepare("UPDATE grafik_element SET extra_daten = :ed WHERE id = :id");
    qu.bindValue(":ed", QString::fromUtf8(QJsonDocument(ed).toJson(QJsonDocument::Compact)));
    qu.bindValue(":id", grafikElementId);
    if (!qu.exec()) {
        qWarning() << "makroSpeichern UPDATE extra_daten:" << qu.lastError().text();
        dbConn.rollback(); return -1;
    }

    if (!dbConn.commit()) {
        qWarning() << "makroSpeichern: commit fehlgeschlagen";
        return -1;
    }
    return makroId;
}

// ============================================================
// makroListe
// ============================================================
QVariantList Database::makroListe()
{
    QVariantList result;
    QSqlQuery q(R"(
        SELECT m.id, m.name, m.beschreibung, m.kategorie,
               COUNT(me.id) AS element_anzahl
        FROM makro m
        LEFT JOIN makro_element me ON me.makro_id = m.id
        GROUP BY m.id
        ORDER BY m.kategorie, m.name
    )");
    while (q.next()) {
        QVariantMap row;
        row["id"]            = q.value(0).toInt();
        row["name"]          = q.value(1).toString();
        row["beschreibung"]  = q.value(2).toString();
        row["kategorie"]     = q.value(3).toString();
        row["elementAnzahl"] = q.value(4).toInt();
        result.append(row);
    }
    return result;
}

// ============================================================
// makroElementeEinfuegen
// ============================================================
QVariantList Database::makroElementeEinfuegen(int makroId, int seiteId,
                                               double offsetX, double offsetY)
{
    QVariantList newIds;
    QSqlQuery qe;
    qe.prepare(R"(
        SELECT typ, rel_x1, rel_y1, rel_x2, rel_y2, extra_daten, symbol_key, sortierung
        FROM makro_element WHERE makro_id = :mid ORDER BY sortierung
    )");
    qe.bindValue(":mid", makroId);
    if (!qe.exec()) {
        qWarning() << "makroElementeEinfuegen SELECT:" << qe.lastError().text();
        return newIds;
    }

    // Stich- und Füllwerte aus erstem Element ableiten wäre ideal, aber grafik_element
    // speichert diese im extra_daten nicht zuverlässig. Wir lesen sie aus dem Original.
    // Für eine saubere Implementierung: in makro_element auch strich_farbe etc. speichern.
    // Aktuell: Standard-Werte, werden nach Speichern vom grafikSpeichern-Roundtrip überschrieben.
    QSqlDatabase dbConn = QSqlDatabase::database();
    if (!dbConn.transaction()) { qWarning() << "makroElementeEinfuegen: transaction"; return newIds; }

    QSqlQuery qi;
    qi.prepare(R"(
        INSERT INTO grafik_element
            (seite_id, typ, x1, y1, x2, y2,
             strich_farbe, strich_breite, strich_art,
             fuell, fuell_farbe, fuell_opazitaet, opazitaet, ecken_radius,
             sortierung, symbol_id, rotation, spiegel_x, spiegel_y, extra_daten)
        VALUES
            (:sid, :typ, :x1, :y1, :x2, :y2,
             '#4a9eff', 1.5, 'solid',
             0, '#000000', 0.0, 1.0, 0,
             :sort, :sk, 0, 0, 0, :ed)
    )");

    while (qe.next()) {
        qi.bindValue(":sid",  seiteId);
        qi.bindValue(":typ",  qe.value(0).toString());
        qi.bindValue(":x1",   qe.value(1).toDouble() + offsetX);
        qi.bindValue(":y1",   qe.value(2).toDouble() + offsetY);
        qi.bindValue(":x2",   qe.value(3).toDouble() + offsetX);
        qi.bindValue(":y2",   qe.value(4).toDouble() + offsetY);
        qi.bindValue(":ed",   qe.value(5));
        qi.bindValue(":sk",   qe.value(6));
        qi.bindValue(":sort", qe.value(7));
        if (!qi.exec()) {
            qWarning() << "makroElementeEinfuegen INSERT:" << qi.lastError().text();
            dbConn.rollback(); return QVariantList();
        }
        newIds.append(qi.lastInsertId().toInt());
    }

    if (!dbConn.commit()) { qWarning() << "makroElementeEinfuegen: commit"; return QVariantList(); }
    return newIds;
}

// ============================================================
// makroLoeschen
// ============================================================
bool Database::makroLoeschen(int makroId)
{
    QSqlQuery q;
    q.prepare("DELETE FROM makro WHERE id = :id");
    q.bindValue(":id", makroId);
    if (!q.exec()) {
        qWarning() << "makroLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// makroMetaAktualisieren
// ============================================================
bool Database::makroMetaAktualisieren(int makroId, const QString &name,
                                       const QString &beschreibung,
                                       const QString &kategorie)
{
    QSqlQuery q;
    q.prepare("UPDATE makro SET name=:n, beschreibung=:b, kategorie=:k WHERE id=:id");
    q.bindValue(":n",  name);
    q.bindValue(":b",  beschreibung);
    q.bindValue(":k",  kategorie);
    q.bindValue(":id", makroId);
    if (!q.exec()) {
        qWarning() << "makroMetaAktualisieren:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Inbetriebnahme-Modus
// ============================================================
QVariantList Database::ibnListeLaden(int projektId, int seiteId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT
            MIN(ge.id)                                       AS element_id,
            ge.seite_id,
            s.blattnummer,
            COALESCE(s.bezeichnung, '')                      AS seitenbezeichnung,
            json_extract(ge.extra_daten, '$.bmk')            AS bmk,
            COALESCE(ibn.status, 'offen')                    AS status,
            COALESCE(ibn.id, 0)                              AS ibn_id,
            COALESCE(ibn.notiz, '')                          AS notiz,
            COALESCE(ibn.bauteil_id, '')                     AS bauteil_id,
            COALESCE(ibn.geprueft_von, '')                   AS geprueft_von,
            COALESCE(ibn.geprueft_am, '')                    AS geprueft_am,
            MIN(ge.x1)                                       AS x1,
            MIN(ge.y1)                                       AS y1,
            COALESCE(MAX(sd.ibn_kategorie), '')              AS symbol_kategorie
        FROM grafik_element ge
        JOIN seite   s ON ge.seite_id   = s.id
        JOIN ort     o ON s.ort_id      = o.id
        JOIN anlage  a ON o.anlage_id   = a.id
        LEFT JOIN symbol_definition sd ON ge.symbol_id = sd.id
        LEFT JOIN inbetriebnahme ibn
               ON ibn.seite_id = ge.seite_id
              AND ibn.bmk      = json_extract(ge.extra_daten, '$.bmk')
        WHERE a.projekt_id  = :pid
          AND (:sid = -1 OR ge.seite_id = :sid)
          AND ge.typ        = 'symbol'
          AND json_extract(ge.extra_daten, '$.bmk') IS NOT NULL
          AND json_extract(ge.extra_daten, '$.bmk') != ''
        GROUP BY ge.seite_id, json_extract(ge.extra_daten, '$.bmk')
        ORDER BY s.blattnummer, bmk
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":sid", seiteId);

    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnListeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "elementId",        q.value("element_id")      },
            { "seiteId",          q.value("seite_id")        },
            { "blattnummer",      q.value("blattnummer")     },
            { "seitenbezeichnung",q.value("seitenbezeichnung")},
            { "bmk",              q.value("bmk")             },
            { "status",           q.value("status")          },
            { "ibnId",            q.value("ibn_id")          },
            { "notiz",            q.value("notiz")           },
            { "bauteilId",        q.value("bauteil_id")      },
            { "geprueftVon",      q.value("geprueft_von")    },
            { "geprueftAm",       q.value("geprueft_am")     },
            { "x1",               q.value("x1")              },
            { "y1",               q.value("y1")              },
            { "symbolKategorie",  q.value("symbol_kategorie") },
        });
    }
    return result;
}

bool Database::ibnEintragSpeichern(int projektId, int seiteId,
                                    const QString &bmk,
                                    const QString &status,
                                    const QString &notiz,
                                    const QString &bauteilId,
                                    const QString &geprueftVon,
                                    const QString &geprueftAm)
{
    QSqlQuery q;
    // Sicherstellen dass ein Datensatz existiert
    q.prepare(R"(
        INSERT INTO inbetriebnahme (projekt_id, seite_id, bmk, erstellt_am)
        VALUES (:pid, :sid, :bmk, datetime('now'))
        ON CONFLICT(seite_id, bmk) DO NOTHING
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qWarning() << "ibnEintragSpeichern INSERT:" << q.lastError().text();
        return false;
    }

    q.prepare(R"(
        UPDATE inbetriebnahme
        SET status       = :st,
            notiz        = :no,
            bauteil_id   = :bid,
            geprueft_von = :gv,
            geprueft_am  = :ga
        WHERE seite_id = :sid AND bmk = :bmk
    )");
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":bid", bauteilId);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    if (!q.exec()) {
        qWarning() << "ibnEintragSpeichern UPDATE:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnStatusSetzen(int seiteId, const QString &bmk, const QString &status)
{
    QSqlQuery q;
    // Eintrag anlegen falls noch nicht vorhanden (projekt_id wird aus seite abgeleitet)
    q.prepare(R"(
        INSERT INTO inbetriebnahme (projekt_id, seite_id, bmk, status, erstellt_am)
        SELECT a.projekt_id, :sid, :bmk, :st, datetime('now')
        FROM seite s JOIN ort o ON s.ort_id=o.id JOIN anlage a ON o.anlage_id=a.id
        WHERE s.id = :sid
        ON CONFLICT(seite_id, bmk) DO UPDATE SET status = :st
    )");
    q.bindValue(":sid", seiteId);
    q.bindValue(":bmk", bmk);
    q.bindValue(":st",  status);
    if (!q.exec()) {
        qWarning() << "ibnStatusSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── IBN Kabel ────────────────────────────────────────────────────────────

QVariantList Database::ibnKabelListeLaden(int projektId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT k.id              AS kabel_id,
               k.bezeichnung,
               k.kabeltyp,
               k.aderzahl,
               k.querschnitt_mm2,
               k.laenge_m,
               COALESCE(k.von_ort, '')          AS von_ort,
               COALESCE(k.nach_ort, '')         AS nach_ort,
               COALESCE(k.grafik_element_id, 0) AS grafik_element_id,
               COALESCE(ib.status, 'offen')     AS status,
               COALESCE(ib.notiz, '')           AS notiz,
               COALESCE(ib.geprueft_von, '')    AS geprueft_von,
               COALESCE(ib.geprueft_am, '')     AS geprueft_am
        FROM kabel k
        LEFT JOIN ibn_kabel ib ON ib.kabel_id = k.id
        WHERE k.projekt_id = :pid
        ORDER BY k.bezeichnung
    )");
    q.bindValue(":pid", projektId);

    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnKabelListeLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "kabelId",        q.value("kabel_id")        },
            { "bezeichnung",    q.value("bezeichnung")     },
            { "kabeltyp",       q.value("kabeltyp")        },
            { "aderzahl",       q.value("aderzahl")        },
            { "querschnittMm2", q.value("querschnitt_mm2") },
            { "laengeM",        q.value("laenge_m")        },
            { "vonOrt",         q.value("von_ort")         },
            { "nachOrt",        q.value("nach_ort")        },
            { "grafikElementId",q.value("grafik_element_id")},
            { "status",         q.value("status")          },
            { "notiz",          q.value("notiz")           },
            { "geprueftVon",    q.value("geprueft_von")    },
            { "geprueftAm",     q.value("geprueft_am")     },
        });
    }
    return result;
}

bool Database::ibnKabelSpeichern(int projektId, int kabelId,
                                  const QString &status,
                                  const QString &notiz,
                                  const QString &geprueftVon,
                                  const QString &geprueftAm)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_kabel (projekt_id, kabel_id, status, notiz, geprueft_von, geprueft_am)
        VALUES (:pid, :kid, :st, :no, :gv, :ga)
        ON CONFLICT(kabel_id) DO NOTHING
    )");
    q.bindValue(":pid", projektId);
    q.bindValue(":kid", kabelId);
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    if (!q.exec()) {
        qWarning() << "ibnKabelSpeichern INSERT:" << q.lastError().text();
        return false;
    }
    q.prepare(R"(
        UPDATE ibn_kabel
        SET status       = :st,
            notiz        = :no,
            geprueft_von = :gv,
            geprueft_am  = :ga
        WHERE kabel_id = :kid
    )");
    q.bindValue(":st",  status);
    q.bindValue(":no",  notiz);
    q.bindValue(":gv",  geprueftVon);
    q.bindValue(":ga",  geprueftAm);
    q.bindValue(":kid", kabelId);
    if (!q.exec()) {
        qWarning() << "ibnKabelSpeichern UPDATE:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnKabelStatusSetzen(int kabelId, const QString &status)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_kabel (projekt_id, kabel_id, status)
        VALUES ((SELECT projekt_id FROM kabel WHERE id = :kid), :kid, :st)
        ON CONFLICT(kabel_id) DO UPDATE SET status = :st
    )");
    q.bindValue(":kid", kabelId);
    q.bindValue(":st",  status);
    if (!q.exec()) {
        qWarning() << "ibnKabelStatusSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ── IBN Feldvorlagen / Feldwerte ─────────────────────────────────────────────

bool Database::seedIbnFeldvorlagen()
{
    struct Feld {
        QString kategorie, feldname, label, feldtyp, optionen, einheit;
        int pflicht, reihenfolge;
    };
    static const QList<Feld> felder = {
        // Leitungsschutzschalter
        { "leitungsschutzschalter", "nennstrom",       "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "leitungsschutzschalter", "ausloesekurve",    "Auslösekurve",          "auswahl",  "B,C,D", "", 1, 2 },
        { "leitungsschutzschalter", "pole",             "Polzahl",               "auswahl",  "1,2,3,4", "", 1, 3 },
        { "leitungsschutzschalter", "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  0, 4 },
        { "leitungsschutzschalter", "ausschaltvermoegen","Ausschaltvermögen (kA)","zahl",     "", "kA", 0, 5 },
        { "leitungsschutzschalter", "bemerkung",        "Bemerkung",             "text",     "", "",   0, 6 },
        // Sicherung
        { "sicherung",              "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "sicherung",              "sicherungstyp",    "Sicherungstyp",         "auswahl",  "gG,gL,aM,NH", "", 1, 2 },
        { "sicherung",              "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  0, 3 },
        { "sicherung",              "bemerkung",        "Bemerkung",             "text",     "", "",   0, 4 },
        // FI-Schutzschalter
        { "fi_schutzschalter",      "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "fi_schutzschalter",      "fehlerstrom",      "Fehlerstrom (mA)",       "auswahl",  "10,30,100,300", "", 1, 2 },
        { "fi_schutzschalter",      "typ",              "FI-Typ",                "auswahl",  "Typ A,Typ B,Typ F", "", 1, 3 },
        { "fi_schutzschalter",      "pole",             "Polzahl",               "auswahl",  "2,4", "",   1, 4 },
        { "fi_schutzschalter",      "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 5 },
        { "fi_schutzschalter",      "bemerkung",        "Bemerkung",             "text",     "", "",   0, 6 },
        // Motorschutzschalter
        { "motorschutzschalter",    "einstellstrom",    "Einstellstrom (A)",      "zahl",     "", "A",  1, 1 },
        { "motorschutzschalter",    "einstellbereich",  "Einstellbereich (A)",    "text",     "", "A",  0, 2 },
        { "motorschutzschalter",    "klasse",           "Auslöseklasse",         "auswahl",  "10,10A,20,30", "", 0, 3 },
        { "motorschutzschalter",    "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 4 },
        { "motorschutzschalter",    "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Schütz
        { "schuetz",                "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 1 },
        { "schuetz",                "spulenspannung",   "Spulenspannung (V)",     "zahl",     "", "V",  1, 2 },
        { "schuetz",                "spulenfrequenz",   "Spulenfrequenz",        "auswahl",  "DC,50 Hz,60 Hz", "", 0, 3 },
        { "schuetz",                "einschaltdauer",   "Einschaltdauer (%ED)",   "zahl",     "", "%",  0, 4 },
        { "schuetz",                "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
        // Motor
        { "motor",                  "nennleistung",     "Nennleistung (kW)",      "zahl",     "", "kW", 1, 1 },
        { "motor",                  "nennstrom",        "Nennstrom (A)",         "zahl",     "", "A",  1, 2 },
        { "motor",                  "nennspannung",     "Nennspannung (V)",       "zahl",     "", "V",  1, 3 },
        { "motor",                  "drehzahl",         "Nenndrehzahl (U/min)",   "zahl",     "", "U/min", 0, 4 },
        { "motor",                  "cos_phi",          "cos φ",                 "zahl",     "", "",   0, 5 },
        { "motor",                  "drehrichtung",     "Drehrichtung geprüft",  "boolean",  "", "",   0, 6 },
        { "motor",                  "isolationswiderstand","Isolationswiderstand (MΩ)","zahl","","MΩ", 0, 7 },
        { "motor",                  "bemerkung",        "Bemerkung",             "text",     "", "",   0, 8 },
        // Transformator
        { "transformator",          "primaerspannung",  "Primärspannung (V)",     "zahl",     "", "V",  1, 1 },
        { "transformator",          "sekundaerspannung","Sekundärspannung (V)",   "zahl",     "", "V",  1, 2 },
        { "transformator",          "nennleistung",     "Nennleistung (VA)",      "zahl",     "", "VA", 1, 3 },
        { "transformator",          "leerlaufspannung", "Leerlaufspannung (V)",   "zahl",     "", "V",  0, 4 },
        { "transformator",          "bemerkung",        "Bemerkung",             "text",     "", "",   0, 5 },
    };

    QSqlQuery q;
    q.prepare(R"(
        INSERT OR IGNORE INTO ibn_feldvorlage
            (symbol_kategorie, feldname, label, feldtyp, optionen, einheit, pflichtfeld, reihenfolge, erstellt_von)
        VALUES (:kat, :fn, :lbl, :typ, :opt, :ein, :pfl, :rei, 'system')
    )");
    for (const auto &f : felder) {
        q.bindValue(":kat", f.kategorie);
        q.bindValue(":fn",  f.feldname);
        q.bindValue(":lbl", f.label);
        q.bindValue(":typ", f.feldtyp);
        q.bindValue(":opt", f.optionen);
        q.bindValue(":ein", f.einheit);
        q.bindValue(":pfl", f.pflicht);
        q.bindValue(":rei", f.reihenfolge);
        if (!q.exec()) {
            qWarning() << "seedIbnFeldvorlagen:" << q.lastError().text();
            return false;
        }
    }

    // symbol_definition.ibn_kategorie für bekannte Symbole setzen
    struct KatMap { QString symbolId, kategorie; };
    static const QList<KatMap> katMap = {
        { "lss",          "leitungsschutzschalter" },
        { "sicherung",    "sicherung"              },
        { "fi",           "fi_schutzschalter"      },
        { "bimetall_nc",  "motorschutzschalter"    },
        { "spule",        "schuetz"                },
        { "spule_ansi",   "schuetz"                },
        { "motor",        "motor"                  },
        { "trafo",        "transformator"          },
    };
    QSqlQuery qu;
    qu.prepare("UPDATE symbol_definition SET ibn_kategorie = :kat WHERE id = :id");
    for (const auto &km : katMap) {
        qu.bindValue(":kat", km.kategorie);
        qu.bindValue(":id",  km.symbolId);
        if (!qu.exec())
            qWarning() << "seedIbnFeldvorlagen update" << km.symbolId << ":" << qu.lastError().text();
    }
    return true;
}

QVariantList Database::ibnFeldvorlagenLaden(const QString &symbolKategorie)
{
    if (symbolKategorie.isEmpty())
        return {};
    QSqlQuery q;
    q.prepare(R"(
        SELECT feldname, label, feldtyp, optionen, einheit, pflichtfeld
        FROM ibn_feldvorlage
        WHERE symbol_kategorie = :kat
        ORDER BY reihenfolge
    )");
    q.bindValue(":kat", symbolKategorie);
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnFeldvorlagenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "feldname",   q.value("feldname")   },
            { "label",      q.value("label")      },
            { "feldtyp",    q.value("feldtyp")    },
            { "optionen",   q.value("optionen")   },
            { "einheit",    q.value("einheit")    },
            { "pflichtfeld",q.value("pflichtfeld") },
        });
    }
    return result;
}

QVariantList Database::ibnAlleVorlagenLaden()
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT id, symbol_kategorie, feldname, label, feldtyp, optionen,
               einheit, pflichtfeld, reihenfolge, erstellt_von
        FROM ibn_feldvorlage
        ORDER BY symbol_kategorie, reihenfolge, id
    )");
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnAlleVorlagenLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "id",              q.value("id")              },
            { "symbolKategorie", q.value("symbol_kategorie") },
            { "feldname",        q.value("feldname")        },
            { "label",           q.value("label")           },
            { "feldtyp",         q.value("feldtyp")         },
            { "optionen",        q.value("optionen")        },
            { "einheit",         q.value("einheit")         },
            { "pflichtfeld",     q.value("pflichtfeld")     },
            { "reihenfolge",     q.value("reihenfolge")     },
            { "erstelltVon",     q.value("erstellt_von")    },
        });
    }
    return result;
}

QVariantList Database::ibnAlleKategorienLaden()
{
    QSqlQuery q("SELECT DISTINCT symbol_kategorie FROM ibn_feldvorlage ORDER BY symbol_kategorie");
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnAlleKategorienLaden:" << q.lastError().text();
        return result;
    }
    while (q.next())
        result.append(q.value(0));
    return result;
}

bool Database::ibnFeldVorlageSpeichern(const QString &symbolKategorie,
                                        const QString &feldname,
                                        const QString &label,
                                        const QString &feldtyp,
                                        const QString &optionen,
                                        const QString &einheit,
                                        bool pflichtfeld)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_feldvorlage
            (symbol_kategorie, feldname, label, feldtyp, optionen, einheit,
             pflichtfeld, reihenfolge, erstellt_von)
        VALUES (:kat, :fn, :lbl, :typ, :opt, :ein, :pfl,
                (SELECT COALESCE(MAX(reihenfolge), 0) + 1
                 FROM ibn_feldvorlage WHERE symbol_kategorie = :kat2),
                'user')
    )");
    q.bindValue(":kat",  symbolKategorie);
    q.bindValue(":kat2", symbolKategorie);
    q.bindValue(":fn",   feldname);
    q.bindValue(":lbl",  label);
    q.bindValue(":typ",  feldtyp);
    q.bindValue(":opt",  optionen);
    q.bindValue(":ein",  einheit);
    q.bindValue(":pfl",  pflichtfeld ? 1 : 0);
    if (!q.exec()) {
        qWarning() << "ibnFeldVorlageSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::ibnFeldVorlageLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM ibn_feldvorlage WHERE id = :id AND erstellt_von = 'user'");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "ibnFeldVorlageLoeschen:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVariantList Database::ibnFeldwerteLaden(int inbetriebnahmeId)
{
    QSqlQuery q;
    q.prepare(R"(
        SELECT feldname, wert FROM ibn_feldwert
        WHERE inbetriebnahme_id = :id
    )");
    q.bindValue(":id", inbetriebnahmeId);
    QVariantList result;
    if (!q.exec()) {
        qWarning() << "ibnFeldwerteLaden:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        result.append(QVariantMap{
            { "feldname", q.value("feldname") },
            { "wert",     q.value("wert")     },
        });
    }
    return result;
}

bool Database::ibnFeldwerteAktualisieren(int inbetriebnahmeId, const QVariantList &felder)
{
    QSqlQuery q;
    q.prepare(R"(
        INSERT INTO ibn_feldwert (inbetriebnahme_id, feldname, wert)
        VALUES (:id, :fn, :wert)
        ON CONFLICT(inbetriebnahme_id, feldname) DO UPDATE SET wert = :wert
    )");
    for (const auto &f : felder) {
        QVariantMap m = f.toMap();
        q.bindValue(":id",   inbetriebnahmeId);
        q.bindValue(":fn",   m.value("feldname").toString());
        q.bindValue(":wert", m.value("wert").toString());
        if (!q.exec()) {
            qWarning() << "ibnFeldwerteAktualisieren:" << q.lastError().text();
            return false;
        }
    }
    return true;
}

// ============================================================
// ibnProtokollPdfSpeichern
// ============================================================
bool Database::ibnProtokollPdfSpeichern(int projektId, int seiteId,
                                         const QString &pfad)
{
    QString localPath = QUrl(pfad).toLocalFile();
    if (localPath.isEmpty()) localPath = pfad;

    // ── Projektmeta laden ─────────────────────────────────
    QString projektName, projektnummer, auftraggeber, auftragnehmer, bearbeiter;
    {
        QSqlQuery qp;
        qp.prepare("SELECT name, projektnummer, auftraggeber, auftragnehmer, bearbeiter "
                   "FROM projekt WHERE id = :id");
        qp.bindValue(":id", projektId);
        if (qp.exec() && qp.next()) {
            projektName   = qp.value("name").toString();
            projektnummer = qp.value("projektnummer").toString();
            auftraggeber  = qp.value("auftraggeber").toString();
            auftragnehmer = qp.value("auftragnehmer").toString();
            bearbeiter    = qp.value("bearbeiter").toString();
        }
    }

    // ── IBN-Liste laden ───────────────────────────────────
    const QVariantList liste = ibnListeLaden(projektId, seiteId);

    int anzGesamt      = liste.size();
    int anzAbgeschlossen = 0, anzInArbeit = 0, anzOffen = 0;
    for (const QVariant &v : liste) {
        const QString st = v.toMap().value("status").toString();
        if (st == QLatin1String("abgeschlossen")) ++anzAbgeschlossen;
        else if (st == QLatin1String("in_arbeit")) ++anzInArbeit;
        else ++anzOffen;
    }

    // ── HTML aufbauen ─────────────────────────────────────
    auto esc = [](const QString &s) -> QString {
        QString r = s;
        r.replace(u'&', QLatin1String("&amp;"));
        r.replace(u'<', QLatin1String("&lt;"));
        r.replace(u'>', QLatin1String("&gt;"));
        return r;
    };

    auto statusLabel = [](const QString &st) -> QString {
        if (st == QLatin1String("abgeschlossen")) return QStringLiteral("✓ Fertig");
        if (st == QLatin1String("in_arbeit"))     return QStringLiteral("In Arbeit");
        return QStringLiteral("Offen");
    };
    auto statusColor = [](const QString &st) -> QString {
        if (st == QLatin1String("abgeschlossen")) return QStringLiteral("#2a8a4a");
        if (st == QLatin1String("in_arbeit"))     return QStringLiteral("#b08000");
        return QStringLiteral("#666688");
    };

    QString html;
    html.reserve(64 * 1024);
    html += QStringLiteral(R"(<!DOCTYPE html><html><head><meta charset="utf-8">
<style>
  body   { font-family: Arial, Helvetica, sans-serif; font-size: 9pt; color: #222; margin: 0; }
  h1     { font-size: 13pt; color: #1a3560; margin: 0 0 6px 0; }
  .subtitle { font-size: 9pt; color: #555; margin-bottom: 10px; }
  table.meta { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
  table.meta td { padding: 2px 6px; font-size: 8.5pt; }
  table.meta td.lbl { color: #777; width: 130px; }
  .summary { background: #eef2f7; padding: 6px 10px; margin-bottom: 12px;
             font-size: 8.5pt; border-left: 3px solid #1a3560; }
  .bm { border: 1px solid #ccc; padding: 6px 8px; margin-bottom: 6px;
        page-break-inside: avoid; }
  .bm-head { font-size: 10pt; font-weight: bold; }
  .bm-sub  { font-size: 8pt; color: #666; margin: 1px 0 4px 0; }
  table.felder { width: 100%; border-collapse: collapse; margin-top: 3px; }
  table.felder td { padding: 2px 6px; font-size: 8.5pt; vertical-align: top; }
  table.felder td.lbl { color: #666; width: 42%; }
  table.felder tr:nth-child(even) { background: #f7f7f7; }
  .notiz { font-style: italic; color: #555; margin-top: 3px; font-size: 8.5pt; }
  hr  { border: none; border-top: 1px solid #bbb; margin: 14px 0; }
  .sig { margin-top: 30px; }
  .sig table { width: 100%; border-collapse: collapse; }
  .sig td { width: 33%; padding: 4px 8px; border-top: 1px solid #888;
             font-size: 8pt; color: #555; }
</style></head><body>)");

    // Kopfzeile
    html += QStringLiteral("<h1>Prüfprotokoll IBN</h1>");
    html += QStringLiteral("<div class='subtitle'>Erstellt: ")
          + esc(QDateTime::currentDateTime().toString(QStringLiteral("dd.MM.yyyy  hh:mm")))
          + QStringLiteral("</div>");

    // Projektmeta
    html += QStringLiteral("<table class='meta'>");
    auto metaRow = [&](const QString &lbl, const QString &val) {
        if (val.isEmpty()) return;
        html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
              + QStringLiteral("</td><td>") + esc(val) + QStringLiteral("</td></tr>");
    };
    metaRow(QStringLiteral("Projekt"),        projektName);
    metaRow(QStringLiteral("Projektnummer"),  projektnummer);
    metaRow(QStringLiteral("Auftraggeber"),   auftraggeber);
    metaRow(QStringLiteral("Auftragnehmer"),  auftragnehmer);
    metaRow(QStringLiteral("Bearbeiter"),     bearbeiter);
    html += QStringLiteral("</table>");

    // Zusammenfassung
    html += QStringLiteral("<div class='summary'>")
          + QString::number(anzGesamt) + QStringLiteral(" Betriebsmittel gesamt  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#2a8a4a'>") + QString::number(anzAbgeschlossen)
          + QStringLiteral(" Fertig</span>  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#b08000'>") + QString::number(anzInArbeit)
          + QStringLiteral(" In Arbeit</span>  &nbsp;·&nbsp;  ")
          + QStringLiteral("<span style='color:#666688'>") + QString::number(anzOffen)
          + QStringLiteral(" Offen</span>")
          + QStringLiteral("</div>");

    html += QStringLiteral("<hr>");

    // ── BM-Blöcke ─────────────────────────────────────────
    QString lastBlatt;
    for (const QVariant &v : liste) {
        const QVariantMap e   = v.toMap();
        const QString bmk     = e.value("bmk").toString();
        const QString blatt   = e.value("blattnummer").toString();
        const QString seitenBez = e.value("seitenbezeichnung").toString();
        const QString status  = e.value("status").toString();
        const QString notiz   = e.value("notiz").toString();
        const QString bauteilId = e.value("bauteilId").toString();
        const QString geprueftVon = e.value("geprueftVon").toString();
        const QString geprueftAm  = e.value("geprueftAm").toString();
        const QString kat     = e.value("symbolKategorie").toString();
        const int ibnId       = e.value("ibnId").toInt();

        // Seiten-Trennzeile
        if (blatt != lastBlatt) {
            if (!lastBlatt.isEmpty()) html += QStringLiteral("<br>");
            html += QStringLiteral("<div style='font-size:8pt;color:#999;margin-bottom:4px;'>")
                  + QStringLiteral("Blatt ") + esc(blatt);
            if (!seitenBez.isEmpty())
                html += QStringLiteral(" – ") + esc(seitenBez);
            html += QStringLiteral("</div>");
            lastBlatt = blatt;
        }

        html += QStringLiteral("<div class='bm'>");
        html += QStringLiteral("<div class='bm-head'><span style='color:#1a3560'>")
              + esc(bmk) + QStringLiteral("</span>")
              + QStringLiteral("  <span style='color:") + statusColor(status)
              + QStringLiteral(";font-size:9pt'>") + esc(statusLabel(status))
              + QStringLiteral("</span></div>");

        // Blattnummer + Kategorie als Sub-Info
        QString subInfo = QStringLiteral("Blatt ") + esc(blatt);
        if (!kat.isEmpty()) subInfo += QStringLiteral("  ·  ") + esc(kat);
        html += QStringLiteral("<div class='bm-sub'>") + subInfo + QStringLiteral("</div>");

        // Feldwerte-Tabelle
        html += QStringLiteral("<table class='felder'>");

        // Feste Felder (Bauteil-ID, Geprüft von/am)
        auto fRow = [&](const QString &lbl, const QString &val) {
            if (val.isEmpty()) return;
            html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
                  + QStringLiteral("</td><td>") + esc(val) + QStringLiteral("</td></tr>");
        };
        fRow(QStringLiteral("Seriennummer / Bauteil-ID"), bauteilId);
        fRow(QStringLiteral("Geprüft von"),  geprueftVon);
        fRow(QStringLiteral("Datum"),        geprueftAm);

        // Dynamische Felder
        if (!kat.isEmpty() && ibnId > 0) {
            const QVariantList vorlagen = ibnFeldvorlagenLaden(kat);
            const QVariantList werteListe = ibnFeldwerteLaden(ibnId);

            // Werte-Map aufbauen
            QMap<QString, QString> werteMap;
            for (const QVariant &wv : werteListe) {
                const QVariantMap wm = wv.toMap();
                werteMap.insert(wm.value("feldname").toString(),
                                wm.value("wert").toString());
            }

            for (const QVariant &fv : vorlagen) {
                const QVariantMap fm = fv.toMap();
                const QString feldname = fm.value("feldname").toString();
                const QString lbl      = fm.value("label").toString();
                const QString typ      = fm.value("feldtyp").toString();
                QString wert = werteMap.value(feldname);

                if (typ == QLatin1String("boolean"))
                    wert = (wert == QLatin1String("1")) ? QStringLiteral("Ja") : QStringLiteral("Nein");
                if (wert.isEmpty()) wert = QStringLiteral("–");

                html += QStringLiteral("<tr><td class='lbl'>") + esc(lbl)
                      + QStringLiteral("</td><td>") + esc(wert) + QStringLiteral("</td></tr>");
            }
        }

        html += QStringLiteral("</table>");

        if (!notiz.isEmpty())
            html += QStringLiteral("<div class='notiz'>Notiz: ") + esc(notiz)
                  + QStringLiteral("</div>");

        html += QStringLiteral("</div>"); // .bm
    }

    // ── Unterschriftsfeld ─────────────────────────────────
    html += QStringLiteral("<div class='sig'>");
    html += QStringLiteral("<table><tr>"
            "<td>Erstellt von</td>"
            "<td>Geprüft von</td>"
            "<td>Datum / Unterschrift</td>"
            "</tr></table>");
    html += QStringLiteral("</div>");

    html += QStringLiteral("</body></html>");

    // ── In PDF rendern ────────────────────────────────────
    QPrinter printer(QPrinter::HighResolution);
    printer.setOutputFormat(QPrinter::PdfFormat);
    printer.setOutputFileName(localPath);
    printer.setPageSize(QPageSize(QPageSize::A4));
    printer.setPageOrientation(QPageLayout::Portrait);
    printer.setPageMargins(QMarginsF(20, 15, 15, 15), QPageLayout::Millimeter);

    QTextDocument doc;
    doc.setHtml(html);
    doc.print(&printer);

    return QFile::exists(localPath);
}

// ============================================================
// Wiki – Kategorien
// ============================================================
QVariantList Database::wikiAlleKategorien()
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name");
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0);
        m["name"]         = q.value(1);
        m["beschreibung"] = q.value(2);
        m["sortierung"]   = q.value(3);
        result << m;
    }
    return result;
}

int Database::wikiKategorieAnlegen(const QString &name, const QString &beschreibung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("INSERT INTO wiki_kategorie (name, beschreibung) VALUES (:n, :b)");
    q.bindValue(":n", name);
    q.bindValue(":b", beschreibung);
    if (!q.exec()) {
        qWarning() << "wikiKategorieAnlegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiKategorieUmbenennen(int id, const QString &name, const QString &beschreibung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_kategorie SET name = :n, beschreibung = :b WHERE id = :id");
    q.bindValue(":n",   name);
    q.bindValue(":b",   beschreibung);
    q.bindValue(":id",  id);
    if (!q.exec()) {
        qWarning() << "wikiKategorieUmbenennen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiKategorieLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_kategorie WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiKategorieLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiKategorieSortierungSetzen(int id, int sortierung)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("UPDATE wiki_kategorie SET sortierung = :s WHERE id = :id");
    q.bindValue(":s",  sortierung);
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiKategorieSortierungSetzen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Wiki – Artikel
// ============================================================
QVariantList Database::wikiArtikelFuerKategorie(int kategorieId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, titel, tags, geaendert_am, ist_system FROM wiki_artikel WHERE kategorie_id = :kid ORDER BY titel");
    q.bindValue(":kid", kategorieId);
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]          = q.value(0);
        m["titel"]       = q.value(1);
        m["tags"]        = q.value(2);
        m["geaendertAm"] = q.value(3);
        m["istSystem"]   = q.value(4);
        result << m;
    }
    return result;
}

QVariantMap Database::wikiArtikelLaden(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, kategorie_id, titel, inhalt, tags, ist_system, erstellt_am, geaendert_am FROM wiki_artikel WHERE id = :id");
    q.bindValue(":id", id);
    QVariantMap m;
    if (!q.exec() || !q.next()) return m;
    m["id"]          = q.value(0);
    m["kategorieId"] = q.value(1);
    m["titel"]       = q.value(2);
    m["inhalt"]      = q.value(3);
    m["tags"]        = q.value(4);
    m["istSystem"]   = q.value(5);
    m["erstelltAm"]  = q.value(6);
    m["geaendertAm"] = q.value(7);
    return m;
}

int Database::wikiArtikelAnlegen(int kategorieId, const QString &titel)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("INSERT INTO wiki_artikel (kategorie_id, titel) VALUES (:kid, :t)");
    q.bindValue(":kid", kategorieId);
    q.bindValue(":t",   titel);
    if (!q.exec()) {
        qWarning() << "wikiArtikelAnlegen:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiArtikelSpeichern(int id, const QString &titel,
                                     const QString &inhalt, const QString &tags)
{
    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        UPDATE wiki_artikel
        SET titel = :t, inhalt = :i, tags = :tags,
            geaendert_am = datetime('now')
        WHERE id = :id
    )");
    q.bindValue(":t",    titel);
    q.bindValue(":i",    inhalt);
    q.bindValue(":tags", tags);
    q.bindValue(":id",   id);
    if (!q.exec()) {
        qWarning() << "wikiArtikelSpeichern:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::wikiArtikelLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_artikel WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiArtikelLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

// ============================================================
// Wiki – Bilder
// ============================================================
QVariantList Database::wikiBilderFuerArtikel(int artikelId)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT id, dateiname, mime_typ, beschreibung, sortierung FROM wiki_bild WHERE artikel_id = :aid ORDER BY sortierung, id");
    q.bindValue(":aid", artikelId);
    QVariantList result;
    if (!q.exec()) return result;
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0);
        m["dateiname"]    = q.value(1);
        m["mimeTyp"]      = q.value(2);
        m["beschreibung"] = q.value(3);
        m["sortierung"]   = q.value(4);
        result << m;
    }
    return result;
}

int Database::wikiBildHinzufuegen(int artikelId, const QString &pfad)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QImage img(localPfad);
    if (img.isNull()) {
        qWarning() << "wikiBildHinzufuegen: Bild nicht lesbar:" << localPfad;
        return -1;
    }
    if (img.width() > 1920)
        img = img.scaledToWidth(1920, Qt::SmoothTransformation);

    QByteArray daten;
    QBuffer buf(&daten);
    buf.open(QIODevice::WriteOnly);
    const QString ext = QFileInfo(localPfad).suffix().toLower();
    const QByteArray fmt = (ext == "png") ? "PNG" : "JPEG";
    img.save(&buf, fmt.constData(), 85);

    const QString mimeTyp   = (ext == "png") ? "image/png" : "image/jpeg";
    const QString dateiname = QFileInfo(localPfad).fileName();

    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, sortierung)
        VALUES (:aid, :fn, :mime, :daten,
                (SELECT COALESCE(MAX(sortierung), 0) + 1 FROM wiki_bild WHERE artikel_id = :aid2))
    )");
    q.bindValue(":aid",   artikelId);
    q.bindValue(":fn",    dateiname);
    q.bindValue(":mime",  mimeTyp);
    q.bindValue(":daten", daten);
    q.bindValue(":aid2",  artikelId);
    if (!q.exec()) {
        qWarning() << "wikiBildHinzufuegen INSERT:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool Database::wikiBildLoeschen(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("DELETE FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "wikiBildLoeschen:" << q.lastError().text();
        return false;
    }
    return true;
}

QString Database::wikiBildAlsTempDatei(int id)
{
    QSqlQuery q(m_wikiDb);
    q.prepare("SELECT daten, mime_typ FROM wiki_bild WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec() || !q.next()) return {};

    const QByteArray daten = q.value(0).toByteArray();
    const QString mimeTyp  = q.value(1).toString();
    const QString ext      = mimeTyp.contains("png") ? ".png" : ".jpg";
    const QString tmpPfad  = QDir::tempPath() + "/stroemling_wiki_" + QString::number(id) + ext;

    QFile f(tmpPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "wikiBildAlsTempDatei: Datei nicht schreibbar:" << tmpPfad;
        return {};
    }
    f.write(daten);
    return tmpPfad;
}

// ============================================================
// Wiki – Volltext-Suche (FTS5)
// ============================================================
QVariantList Database::wikiSuchen(const QString &suchbegriff)
{
    if (suchbegriff.trimmed().isEmpty()) return {};

    QSqlQuery q(m_wikiDb);
    q.prepare(R"(
        SELECT wa.id, wa.kategorie_id, wa.titel, wa.tags,
               snippet(wiki_suche, 1, '<b>', '</b>', '…', 20) AS snippet
        FROM wiki_suche
        JOIN wiki_artikel wa ON wa.id = wiki_suche.rowid
        WHERE wiki_suche MATCH :q
        ORDER BY rank
    )");
    q.bindValue(":q", suchbegriff + "*");

    QVariantList result;
    if (!q.exec()) {
        qWarning() << "wikiSuchen:" << q.lastError().text();
        return result;
    }
    while (q.next()) {
        QVariantMap m;
        m["id"]          = q.value(0);
        m["kategorieId"] = q.value(1);
        m["titel"]       = q.value(2);
        m["tags"]        = q.value(3);
        m["snippet"]     = q.value(4);
        result << m;
    }
    return result;
}

// ============================================================
// Wiki – Export / Import (JSON)
// ============================================================
bool Database::wikiExportJson(const QString &pfad)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    // Kategorien
    QJsonArray kategorienArr;
    QSqlQuery qKat(m_wikiDb);
    if (!qKat.exec("SELECT id, name, beschreibung, sortierung FROM wiki_kategorie ORDER BY sortierung, name")) {
        qWarning() << "wikiExportJson kategorien:" << qKat.lastError().text();
        return false;
    }
    while (qKat.next()) {
        QJsonObject o;
        o["id"]           = qKat.value(0).toInt();
        o["name"]         = qKat.value(1).toString();
        o["beschreibung"] = qKat.value(2).toString();
        o["sortierung"]   = qKat.value(3).toInt();
        kategorienArr.append(o);
    }

    // Nur Nutzer-Artikel (ist_system = 0)
    QJsonArray artikelArr;
    QSqlQuery qArt(m_wikiDb);
    if (!qArt.exec(R"(
        SELECT wa.id, wa.kategorie_id, wk.name, wa.titel, wa.inhalt, wa.tags
        FROM wiki_artikel wa
        JOIN wiki_kategorie wk ON wk.id = wa.kategorie_id
        WHERE wa.ist_system = 0
        ORDER BY wk.sortierung, wk.name, wa.titel
    )")) {
        qWarning() << "wikiExportJson artikel:" << qArt.lastError().text();
        return false;
    }
    while (qArt.next()) {
        QJsonObject o;
        o["id"]             = qArt.value(0).toInt();
        o["kategorie_id"]   = qArt.value(1).toInt();
        o["kategorie_name"] = qArt.value(2).toString();
        o["titel"]          = qArt.value(3).toString();
        o["inhalt"]         = qArt.value(4).toString();
        o["tags"]           = qArt.value(5).toString();
        artikelArr.append(o);
    }

    // Bilder der exportierten Artikel
    QJsonArray bilderArr;
    QSqlQuery qBild(m_wikiDb);
    if (!qBild.exec(R"(
        SELECT wb.id, wb.artikel_id, wb.dateiname, wb.mime_typ, wb.daten, wb.beschreibung, wb.sortierung
        FROM wiki_bild wb
        JOIN wiki_artikel wa ON wa.id = wb.artikel_id
        WHERE wa.ist_system = 0
        ORDER BY wb.artikel_id, wb.sortierung, wb.id
    )")) {
        qWarning() << "wikiExportJson bilder:" << qBild.lastError().text();
        return false;
    }
    while (qBild.next()) {
        QJsonObject o;
        o["id"]           = qBild.value(0).toInt();
        o["artikel_id"]   = qBild.value(1).toInt();
        o["dateiname"]    = qBild.value(2).toString();
        o["mime_typ"]     = qBild.value(3).toString();
        o["daten_base64"] = QString::fromLatin1(qBild.value(4).toByteArray().toBase64());
        o["beschreibung"] = qBild.value(5).toString();
        o["sortierung"]   = qBild.value(6).toInt();
        bilderArr.append(o);
    }

    QJsonObject root;
    root["wiki_export_version"] = 1;
    root["exportiert_am"]       = QDateTime::currentDateTime().toString(Qt::ISODate);
    root["kategorien"]          = kategorienArr;
    root["artikel"]             = artikelArr;
    root["bilder"]              = bilderArr;

    QFile f(localPfad);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "wikiExportJson: Datei nicht schreibbar:" << localPfad;
        return false;
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    qInfo() << "Wiki exportiert:" << localPfad << "-" << artikelArr.size() << "Artikel";
    return true;
}

bool Database::wikiImportJson(const QString &pfad, bool mergeMode)
{
    const QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QFile f(localPfad);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "wikiImportJson: Datei nicht lesbar:" << localPfad;
        return false;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (doc.isNull()) {
        qWarning() << "wikiImportJson: JSON-Fehler:" << err.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root["wiki_export_version"].toInt() != 1) {
        qWarning() << "wikiImportJson: Unbekannte Export-Version:" << root["wiki_export_version"].toInt();
        return false;
    }

    if (!m_wikiDb.transaction()) {
        qWarning() << "wikiImportJson: Transaktion fehlgeschlagen";
        return false;
    }

    // Replace-Modus: alle Nutzer-Artikel löschen (Bilder cascaden automatisch)
    if (!mergeMode) {
        QSqlQuery del(m_wikiDb);
        if (!del.exec("DELETE FROM wiki_artikel WHERE ist_system = 0")) {
            qWarning() << "wikiImportJson replace:" << del.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    // Kategorien: vorhandene nach Name finden oder neu anlegen; old-ID → new-ID Map
    QMap<int, int> katIdMap;
    const QJsonArray katArr = root["kategorien"].toArray();
    for (const QJsonValue &v : katArr) {
        const QJsonObject o = v.toObject();
        const int    oldId  = o["id"].toInt();
        const QString name  = o["name"].toString();

        QSqlQuery find(m_wikiDb);
        find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        find.bindValue(":n", name);
        if (find.exec() && find.next()) {
            katIdMap[oldId] = find.value(0).toInt();
        } else {
            QSqlQuery ins(m_wikiDb);
            ins.prepare("INSERT INTO wiki_kategorie (name, beschreibung, sortierung) VALUES (:n, :b, :s)");
            ins.bindValue(":n", name);
            ins.bindValue(":b", o["beschreibung"].toString());
            ins.bindValue(":s", o["sortierung"].toInt());
            if (!ins.exec()) {
                qWarning() << "wikiImportJson Kategorie anlegen:" << ins.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
            katIdMap[oldId] = ins.lastInsertId().toInt();
        }
    }

    // Artikel einfügen; old-Art-ID → new-Art-ID Map für Bild-Zuordnung
    QMap<int, int> artIdMap;
    const QJsonArray artArr = root["artikel"].toArray();
    for (const QJsonValue &v : artArr) {
        const QJsonObject o   = v.toObject();
        const int oldArtId    = o["id"].toInt();
        const int oldKatId    = o["kategorie_id"].toInt();
        const QString katName = o["kategorie_name"].toString();

        int newKatId = katIdMap.value(oldKatId, -1);
        if (newKatId < 0) {
            // Kategorie nicht im Export enthalten – nach Name suchen
            QSqlQuery find(m_wikiDb);
            find.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
            find.bindValue(":n", katName);
            if (find.exec() && find.next()) {
                newKatId = find.value(0).toInt();
                katIdMap[oldKatId] = newKatId;
            } else {
                QSqlQuery ins(m_wikiDb);
                ins.prepare("INSERT INTO wiki_kategorie (name) VALUES (:n)");
                ins.bindValue(":n", katName);
                if (!ins.exec()) { m_wikiDb.rollback(); return false; }
                newKatId = ins.lastInsertId().toInt();
                katIdMap[oldKatId] = newKatId;
            }
        }

        QSqlQuery ins(m_wikiDb);
        ins.prepare(R"(
            INSERT INTO wiki_artikel (kategorie_id, titel, inhalt, tags, ist_system)
            VALUES (:kid, :t, :i, :tags, 0)
        )");
        ins.bindValue(":kid",  newKatId);
        ins.bindValue(":t",    o["titel"].toString());
        ins.bindValue(":i",    o["inhalt"].toString());
        ins.bindValue(":tags", o["tags"].toString());
        if (!ins.exec()) {
            qWarning() << "wikiImportJson Artikel einfügen:" << ins.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
        artIdMap[oldArtId] = ins.lastInsertId().toInt();
    }

    // Bilder einfügen
    const QJsonArray bildArr = root["bilder"].toArray();
    for (const QJsonValue &v : bildArr) {
        const QJsonObject o = v.toObject();
        const int newArtId  = artIdMap.value(o["artikel_id"].toInt(), -1);
        if (newArtId < 0) continue;

        QSqlQuery ins(m_wikiDb);
        ins.prepare(R"(
            INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, beschreibung, sortierung)
            VALUES (:aid, :fn, :mime, :daten, :beschr, :sort)
        )");
        ins.bindValue(":aid",   newArtId);
        ins.bindValue(":fn",    o["dateiname"].toString());
        ins.bindValue(":mime",  o["mime_typ"].toString());
        ins.bindValue(":daten", QByteArray::fromBase64(o["daten_base64"].toString().toLatin1()));
        ins.bindValue(":beschr", o["beschreibung"].toString());
        ins.bindValue(":sort",  o["sortierung"].toInt());
        if (!ins.exec()) {
            qWarning() << "wikiImportJson Bild einfügen:" << ins.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    if (!m_wikiDb.commit()) {
        m_wikiDb.rollback();
        qWarning() << "wikiImportJson commit:" << m_wikiDb.lastError().text();
        return false;
    }
    qInfo() << "Wiki importiert:" << artArr.size() << "Artikel"
            << (mergeMode ? "(Merge)" : "(Replace)");
    return true;
}

// ============================================================
// seedWikiStarterInhalte
// Legt System-Kategorien und -Artikel an (INSERT OR IGNORE –
// idempotent, bestehende Nutzer-Inhalte bleiben unberührt).
// ============================================================
bool Database::seedWikiStarterInhalte()
{
    struct Artikel {
        QString titel;
        QString inhalt;
        QString tags;
    };
    struct Kategorie {
        QString name;
        QString beschreibung;
        int sortierung;
        bool istSystem;          // true → Artikel werden mit ist_system=1 gepflegt
        QList<Artikel> artikel;
    };

    const QList<Kategorie> kategorien = {
        {
            "Bedienhinweise",
            "Grundlegende Bedienung von Strömling Design",
            1,
            true,
            {
                {
                    "Programmübersicht",
                    R"(# Programmübersicht

Strömling Design ist in mehrere Arbeitsbereiche aufgeteilt, zwischen denen
du über die **Seitenleiste links** wechselst.

## Arbeitsbereiche

| Symbol | Bereich | Funktion |
|--------|---------|----------|
| 📐 | Schaltplan | Schaltpläne zeichnen, Verbindungen ziehen |
| 🔧 | Symbole | Eigene Schaltsymbole erstellen und bearbeiten |
| 📋 | Normblatt | Schriftfeld-Vorlagen gestalten |
| ✅ | IBN | Inbetriebnahme-Prüfprotokoll |
| ⚡ | Kabelrechner | Leitungsquerschnitt nach VDE berechnen |
| 📊 | Listen | Kabel-, Klemmen- und Stücklisten |
| 📖 | Wiki | Persönliche Erfahrungen und Notizen |

## Grundprinzip

- **Links:** Seitenbaum (Projektseiten) oder Navigationsleiste
- **Mitte:** Arbeitsbereich / Zeichenfläche
- **Rechts:** Eigenschaftenpanel – zeigt die Eigenschaften des gewählten Elements
)",
                    "übersicht navigation sidebar"
                },
                {
                    "Schaltplan – Erste Schritte",
                    R"(# Schaltplan – Erste Schritte

## Projekt anlegen

1. Beim Programmstart wird automatisch ein leeres Projekt geöffnet.
2. Im **Seitenbaum links** siehst du alle Seiten des Projekts.
3. Über das **+**-Symbol im Seitenbaum fügst du neue Seiten hinzu.

## Zeichenfläche

Die Zeichenfläche arbeitet mit einem **Raster** (Standardeinheit: Werkeeinheiten, WE).

- **Zoomen:** Mausrad
- **Verschieben:** Mittlere Maustaste gedrückt halten und ziehen
- **Auswählen:** Linksklick auf ein Element

## Elemente platzieren

1. Im **Eigenschaftenpanel rechts** (oder über Tastenkürzel) Werkzeug wählen.
2. Linksklick auf die Zeichenfläche → Element wird platziert.
3. Element anklicken → Eigenschaften erscheinen im Panel rechts.

## Verbindungen ziehen

1. Verbindungswerkzeug aktivieren.
2. Klick auf den Startpunkt (Pin eines Symbols oder freier Punkt).
3. Klick auf den Endpunkt – die Verbindung wird automatisch geroutet.
4. Kreuzungen mit Leitungen aus **anderen Netzen** werden automatisch
   als Lücke dargestellt.
)",
                    "schaltplan seite projekt zeichenfläche verbindung"
                },
                {
                    "Symbole platzieren und bearbeiten",
                    R"(# Symbole platzieren und bearbeiten

## Symbol aus der Bibliothek platzieren

1. Im **Schaltplan-Werkzeugbereich** das Symbol-Werkzeug wählen.
2. Aus der Symbol-Palette das gewünschte Symbol anklicken.
3. Auf die Zeichenfläche klicken → Symbol wird platziert.
4. Im **Eigenschaftenpanel** kannst du Betriebsmittelkennzeichen (BMK),
   Beschriftung und weitere Eigenschaften setzen.

## Symbol drehen

- Platziertes Symbol anklicken → im Eigenschaftenpanel die **Rotation** ändern
  (0°, 90°, 180°, 270°).

## Eigene Symbole erstellen

1. Seitenleiste → **Symbole** (🔧).
2. **Neues Symbol** anlegen, Namen und Größe festlegen.
3. Mit den Zeichenwerkzeugen (Linien, Kreise, Bögen, Text) das Symbol zeichnen.
4. **Pins** definieren: Position und Bezeichnung für jeden Anschlusspunkt.
5. Speichern – das Symbol steht danach im Schaltplan zur Verfügung.
)",
                    "symbol platzieren bibliothek pin rotation BMK"
                },
                {
                    "Kabelrechner",
                    R"(# Kabelrechner

Der Kabelrechner berechnet den **Mindestquerschnitt** einer Leitung nach VDE.

## Eingaben

| Feld | Bedeutung |
|------|-----------|
| Strom (A) | Betriebsstrom der Leitung |
| Länge (m) | einfache Leitungslänge |
| Spannung (V) | Nennspannung (typisch 230 V oder 400 V) |
| cos φ | Leistungsfaktor (1,0 für ohmsche Last) |
| Verlegeart | Freie Luft, Rohr, Wand usw. |
| Häufung | Anzahl gebündelter Leitungen |

## Ergebnis

Der Rechner gibt den **empfohlenen Querschnitt** in mm² aus und zeigt
den berechneten Spannungsfall.

> **Hinweis:** Das Ergebnis ersetzt keine normgerechte Planung nach
> DIN VDE 0100. Bei sicherheitsrelevanten Anlagen immer einen
> Fachplaner hinzuziehen.
)",
                    "kabel querschnitt VDE berechnung strom"
                },
                {
                    "IBN – Inbetriebnahme",
                    R"(# IBN – Inbetriebnahme

Der IBN-Modus dient zur **strukturierten Prüfung und Dokumentation**
von Schaltanlagen vor der Inbetriebnahme.

## Ablauf

1. Seitenleiste → **IBN** (✅).
2. Die platzierten **Betriebsmittel** aus dem Schaltplan werden automatisch
   als Prüfpositionen aufgelistet.
3. Für jedes Betriebsmittel können **Messwerte** (Spannung, Strom,
   Widerstand usw.) eingetragen werden.
4. Felder mit **Soll-Werten** zeigen farblich an, ob der Messwert
   im zulässigen Bereich liegt.

## Feldvorlagen

Über **Feldvorlagen** lässt sich definieren, welche Messwerte für
welchen Betriebsmitteltyp erfasst werden. So hat z. B. ein Motor
andere Prüffelder als eine Leuchte.

## Prüfprotokoll

Das ausgefüllte IBN-Protokoll kann als Liste exportiert werden
(Listen-Ansicht → IBN-Tab).
)",
                    "inbetriebnahme prüfung messwert protokoll IBN"
                },
                {
                    "Versionierung mit Git",
                    R"(# Versionierung mit Git

Strömling-Projekte sind eigenständige **SQLite-Dateien** (`.stroemling`).
Da alle Daten in einer einzigen Datei stecken, funktioniert Git als
Versionsverwaltung ohne jede Konfiguration in der App.

## Einrichten (einmalig)

```bash
# Projektordner anlegen und als Git-Repo initialisieren
mkdir ~/Projekte/Schaltschrank-A
cd ~/Projekte/Schaltschrank-A
git init

# .gitignore anlegen (optional, aber empfohlen)
echo "*.db-wal" >  .gitignore
echo "*.db-shm" >> .gitignore
git add .gitignore
git commit -m "Repo initialisiert"
```

Danach das Projekt in diesem Ordner anlegen oder die `.stroemling`-Datei
dorthin kopieren (📂 → **Projekt importieren**).

## Täglicher Workflow

```bash
# Nach einer Arbeitssitzung
git add schaltschrank_a.stroemling
git commit -m "Hauptstromkreis: Schütze K1–K3 verdrahtet"

# Verlauf anzeigen
git log --oneline

# Auf Stand vor 3 Commits zurückgehen (nur lesen, nicht überschreiben)
git show HEAD~3:schaltschrank_a.stroemling > alt.stroemling
```

## Was Git kann und was nicht

| ✅ Funktioniert | ❌ Funktioniert nicht |
|---|---|
| Vollständige Versionshistorie | Lesbares `git diff` (Binärdatei) |
| Wiederherstellung beliebiger Stände | Zeilenweises Mergen zweier Versionen |
| Branching (z. B. Varianten A/B) | Automatische Konfliktauflösung |
| Backup auf GitHub/Gitea/lokalem Server | |

## Tipps

- **Sinnvolle Commit-Nachrichten** helfen später: lieber
  *„Steuerstromkreis Schütz K2 korrigiert"* als *„Update"*.
- **Vor größeren Umstrukturierungen** einen Commit machen – so kann
  man jederzeit zum Ausgangszustand zurück.
- **Projekt exportieren** (⬆-Button in der Projektliste) erzeugt eine
  kompakte, saubere Kopie – ideal für Archivierung oder Weitergabe.
- Mehrere Varianten eines Projekts: einfach **Branches** nutzen:
  ```bash
  git checkout -b variante-drehstrom
  # ... Änderungen ...
  git checkout main   # zurück zur Hauptvariante
  ```
)",
                    "git versionierung backup revision history"
                },
                {
                    "Lizenz & Open Source",
                    R"(# Lizenz & Open Source

Strömling Design ist **freie Software** – der Quellcode ist öffentlich
einsehbar und das Programm darf frei genutzt, geteilt und verbessert werden.

## Lizenz: GNU GPL v3

Das Programm steht unter der **GNU General Public License Version 3** (GPL-3.0-or-later).

Das bedeutet in Kurzform:

- Du darfst das Programm **kostenlos nutzen** – privat, in Bildungseinrichtungen,
  in Vereinen, in Forschung und Lehre.
- Du darfst das Programm **weitergeben** und **verändern** –
  unter denselben Lizenzbedingungen.
- Der **Quellcode** muss immer zugänglich bleiben.
- **Zukünftige Versionen** von Strömling Design werden ebenfalls Open Source bleiben.

Den vollständigen Lizenztext findest du unter:
https://www.gnu.org/licenses/gpl-3.0.txt

## Spenden

Strömling Design wird in der Freizeit entwickelt.
Wenn dir das Programm nützt und du die Weiterentwicklung unterstützen möchtest,
freue ich mich über eine freiwillige Spende.

## Mitmachen

Fehler gefunden? Verbesserungsidee? Eigene Symbole oder Inhalte beigesteuert?
Beiträge sind herzlich willkommen – schau auf die Projektseite.

## Keine Garantie

Das Programm wird so bereitgestellt, wie es ist, **ohne Garantie** –
so wie es die GPL vorschreibt. Für den produktiven Einsatz in
sicherheitsrelevanten Anlagen liegt die Verantwortung beim Anwender.
)",
                    "lizenz open source GPL frei kostenlos spende"
                },
                {
                    "Über dieses Projekt",
                    R"(# Über dieses Projekt

## Projektinhaber

**Stephan Theelke**

## Entstehung

Strömling Design wurde am **08.04.2026** gestartet.

Im Berufsalltag arbeite ich mit **EPLAN P8 Electric**, privat hatte ich
**QElectroTech** genutzt. Beides war nicht das, was ich mir für den
Privatgebrauch vorgestellt hatte — also habe ich angefangen, selbst etwas
zu bauen.

## Der Name

Den Begriff **„Strömlinge"** kenne ich noch aus meiner Lehrzeit, irgendwo
um die Jahrtausendwende herum. In der Elektrowelt kennt jeder das Bild:
der kleine Strom, der durch die Leitung fließt. Jetzt konnte ich den
Begriff endlich mal in einem eigenen Projekt verwenden.

## KI-Unterstützung

Dieses Projekt wurde offen und transparent mit Unterstützung von
KI-Werkzeugen entwickelt:

| Werkzeug | Aufgabe |
|---|---|
| **Claude Code** (Anthropic) | Code, Architektur, Konzepte |
| **ChatGPT / DALL-E** (OpenAI) | Strömlinge-Charakterbilder |

Die Projektidee stammt vom Projektinhaber — Konzepte und Quellcode
wurden gemeinsam mit KI erarbeitet.

## Warum Open Source?

Weil ich selbst von Open-Source-Projekten profitiere — und weil ein
Werkzeug für Elektrotechnik der Gemeinschaft gehören sollte, nicht einem
Konzern.
)",
                    "entstehung projekt KI claude chatgpt open source geschichte"
                }
            }
        },
        {
            "Altbestand – West",
            "Installationen nach westdeutscher Norm (VDE), Übergangsperioden, Klassische Nullung",
            10,
            false,
            {
                { "Klassische Nullung – Grundlagen", "", "klassische nullung VDE altbestand" },
                { "Klassische Nullung – Verbotsdaten nach VDE", "", "klassische nullung verbot datum" },
                { "Kuriositäten: 3-adrig verdrahtet, aber KN angeklemmt", "", "klassische nullung kuriosum" }
            }
        },
        {
            "Altbestand – Ost",
            "Installationen nach DDR-Norm TGL, Besonderheiten, Aluminium-Leitungen",
            20,
            false,
            {
                { "Aluminium-Leitungen nach DDR-Norm TGL", "", "aluminium TGL DDR altbestand" },
                { "DDR-Farbnormen und TGL-Querschnitte", "", "farbnorm TGL DDR querschnitt" }
            }
        },
        {
            "Aderendhülsen",
            "Typen, Farbtabellen, Crimp-Technik, häufige Fehler",
            30,
            false,
            {
                { "Querschnitt–Farb–Größentabelle", "", "aderendhülse querschnitt farbe tabelle" }
            }
        },
        {
            "Kuriositäten",
            "Ungewöhnliche Fundsachen aus der Praxis",
            40,
            false,
            {}
        },
        {
            "Strömlinge",
            "Das Maskottchen-System von Strömling Design – ein Charakter pro Leitertyp",
            50,
            true,
            {
                {
                    "Strömlinge – Überblick",
                    R"(# Die Strömlinge

Die Strömlinge sind das lebendige Maskottchen-System von Strömling Design.
Jeder Strömling repräsentiert einen **elektrischen Leitertyp**, ein **Signal**
oder einen **Systemzustand** – erkennbar an Farbe, Körpermerkmalen und Persönlichkeit.

## Grundformen

### Form A – Runder Fisch (Standard-Strömling)
- Runder, leicht plumper Fischkörper
- **Glühbirnen als Ohren** (leuchtend, charakterspezifisch eingefärbt)
- **Fluoreszierende Leiterbahnen** auf dem Körper (PCB-Stil)
- Schielende oder eigenartige Augen – jeder hat seinen eigenen Blick

### Form B – Aalförmig (Leitungs-Strömling)
- Langer, schlanker, gewundener Körper (Sinuswelle)
- **Stecker-/Buchsenenden** an Kopf und Schwanz
- **Aderstreifen** in Normfarben längs am Körper

## Familien

| Familie | Charaktere | Norm |
|---|---|---|
| Netzleiter | Brauno (L1), Schwärzchen (L2), Grausel (L3), Blaubertha (N), Erdikus (PE) | IEC 60446 |
| Leitung & Kabelbrücke | Linus (Kabelbrücke) + Farbvarianten | DIN VDE 0293 |
| Signale & Bus | Impulsino (Signal), Datinchen (Bus) | – |
| Schutz & Isolierung | Isolus (Dunkleosteus-Panzerfish) | IEC Klasse II |
| Fehlerzustände | Krizzo (Kurzschluss), Errinka (Fehler), Fusia (Überlast), Stoppius (Not-Aus) | – |
)",
                    "strömling maskottchen übersicht charakter"
                },
                {
                    "Schwärzchen – Systemfisch L2",
                    R"(# Schwärzchen – Systemfisch // Phase 2

Schwärzchen ist der **coole** unter den drei Außenleitern.
Er repräsentiert den **Außenleiter L2** (schwarz) nach IEC 60446 / DIN VDE 0293.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Schwarz |
| **Körperfarbe** | Tiefes Anthrazit / Schwarz mit leichtem Blauschimmer |
| **Leiterbahnen** | Neongrün, scharf kontraststark |
| **Glühbirnen** | Kaltweißes LED-Licht, minimal |
| **Augen** | Leicht schmale Augen, cooler Blick |

## Persönlichkeit

Ruhig, cool, etwas mysteriös. *Läuft einfach.*
Macht keine großen Worte. Sein Blick sagt: er hat das schon tausendmal gemacht.

## Norm-Referenz

- **Farbe:** Schwarz (L2) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Außenleiter in Drehstromnetzen (400 V / 50 Hz)
- **Körper-Hex:** `#1A1A2E` · **Leiterbahnen-Hex:** `#39FF14`
)",
                    "schwärzchen L2 außenleiter netzleiter IEC schwarz"
                },
                {
                    "Impulsino – Signal",
                    R"(# Impulsino – der hyperaktive Signalströmling

Impulsino repräsentiert das **digitale Steuersignal** – er *ist* der Impuls.
Orange wie die DIN-Signalfarbe, nie still.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Farbe** | Signal-Orange |
| **Leiterbahnen** | Rechteckwellen-Puls-Trace (nur rechte Winkel) |
| **Glühbirnen** | Blinkt rhythmisch – eine an, eine aus |
| **Augen** | Aufmerksam, wach, leicht zappelig |

## Persönlichkeit

Quirlig, immer in Bewegung, hyperaktiv. Liebt hohe Frequenzen.
*„ON! OFF! ON! OFF! Das ist mein Leben!"*

## Im Programm

Impulsino begleitet den **Fun-Modus** als Bonus-Charakter –
er bounced als hyperaktiver Botschafter über den Canvas, pulsiert periodisch.

- **Körper-Hex:** `#FF6B00` · **Leiterbahnen-Hex:** `#FF9E40`
)",
                    "impulsino signal impuls digital orange funmodus"
                },
                {
                    "Isolus – Schutz & Isolierung",
                    R"(# Isolus – der Uralte Wächter

> *„Seit dem Devon bewacht er die Grenze. Sein Knochenkiefer hat noch jeden
> Lichtbogen weggeknappt."*

Isolus ist der **Wächter der Isolierung**. Inspiriert vom **Dunkleosteus** –
dem gepanzerten Urhai des Devon-Zeitalters. Er steht zwischen den
spannungsführenden Leitern und allem, was sie nicht berühren soll.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Grundform** | Dunkleosteus: breiter Panzerkopf, massiver Körper |
| **Körperfarbe** | Tiefschwarz mit mattgelbem Sicherheitsstreifen |
| **Panzer** | Überlappende Knochenplatten mit **☐☐**-Symbol (IEC Klasse II) |
| **Ohren** | Keine Glühbirnen – Isolator-Porzellanglocken |
| **Augen** | Tief versenkt, schmal, uralt blickend |

## Zustände

| Zustand | Aussehen | Bedeutung |
|---|---|---|
| **Intakt** | Glatte Platten, Kiefer geschlossen | Isolation in Ordnung |
| **Beansprucht** | Feine Risse, schmalere Augen | Isolationswiderstand sinkt |
| **Beschädigt** | Platten gesprungen, Kiefer halb offen | Isolationsfehler – Eingriff nötig |
| **Gefallen** | Am Boden, Platten aufgebrochen | Isolationsversagen |

## Beziehungen

- **Feind:** Krizzo (Kurzschluss) – versucht die Panzerplatten zu durchbrechen
- **Verbündeter:** Erdikus (PE) – steht still hinter Isolus, sagt nichts, ist einfach da
- **Verbündeter:** Stoppius (Not-Aus) – gemeinsam die letzte Verteidigungslinie

## Im Programm

Isolus erscheint in der **Wiki-Artikelliste** als Wächter, wenn noch keine Artikel angelegt sind.
)",
                    "isolus isolation schutz dunkleosteus panzer IEC klasse II"
                },
                {
                    "Brauno – Außenleiter L1",
                    R"(# Brauno – Außenleiter L1

Brauno repräsentiert den **Außenleiter L1** (braun) nach IEC 60446 / DIN VDE 0293.
Er ist der Erste unter den Netzleitern – solide, zuverlässig, trägt die Last.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Braun |
| **Körperfarbe** | Warmes Schokoladenbraun `#7B3F1E` |
| **Leiterbahnen** | Kupferfarbig-golden `#D4A520`, Sinuswelle |
| **Glühbirnen** | Bernstein-orange, warm leuchtend |
| **Augen** | Selbstbewusst geradeaus – der Erste, der Anführer |

## Persönlichkeit

Solide, etwas ernst. *Trägt die Last – kein Drama, einfach da.*
Brust raus, leicht stolz. Hat den Anführer-Anspruch verinnerlicht.

## Norm-Referenz

- **Farbe:** Braun (L1) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Erster Außenleiter in Drehstromnetzen (400 V / 50 Hz)
)",
                    "brauno L1 außenleiter netzleiter IEC braun"
                },
                {
                    "Blaubertha – Neutralleiter N",
                    R"(# Blaubertha – Neutralleiter N

Blaubertha repräsentiert den **Neutralleiter N** (blau) nach IEC 60446.
Sie hofft inständig, nie wirklich gebraucht zu werden – und ist
dennoch absolut zuverlässig, wenn es darauf ankommt.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Blau |
| **Körperfarbe** | IEC-Blau `#0057A8` |
| **Leiterbahnen** | Dunkelblau `#003580`, geschlossene Schleifen (Rückstromweg) |
| **Glühbirnen** | Blasses Blau, kaum leuchtend – im Fehlerfall: leuchtet rot |
| **Augen** | Weit geöffnet, leicht ängstlich – immer bereit |

## Persönlichkeit

Ruhig, ausgeglichen. *Der Rückgeber.* Mag Ordnung. Etwas ängstlich –
hofft, nie wirklich belastet zu werden, doch wenn doch, dann perfekt.

## Norm-Referenz

- **Farbe:** Blau (N) nach IEC 60446 und DIN VDE 0293
- **Besonderheit:** Im Normalbetrieb kein Strom → Glühbirnen fast dunkel
)",
                    "blaubertha N neutralleiter netzleiter IEC blau rückleiter"
                },
                {
                    "Grausel – Außenleiter L3",
                    R"(# Grausel – Außenleiter L3

Grausel repräsentiert den **Außenleiter L3** (grau) nach IEC 60446.
Pragmatisch, unauffällig – macht einfach ihren Job, ohne Aufhebens.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Grau |
| **Körperfarbe** | Metallisches Neutralgrau `#6B6B6B` |
| **Leiterbahnen** | Hellblau-silbern `#A8D8EA`, diagonal-ungeordnet |
| **Glühbirnen** | Silbrig-weiß, diskret leuchtend |
| **Augen** | Leicht müde – den Dritten-Platz kennt man, akzeptiert ihn |

## Persönlichkeit

Die Erfahrene. *Hat alles schon gesehen.* Entspannte Pose, leicht hängend –
macht ihren Job ruhig und fehlerfrei, ohne je die Aufmerksamkeit zu suchen.

## Norm-Referenz

- **Farbe:** Grau (L3) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Dritter Außenleiter in Drehstromnetzen (400 V / 50 Hz)
)",
                    "grausel L3 außenleiter netzleiter IEC grau"
                },
                {
                    "Erdikus – Schutzleiter PE",
                    R"(# Erdikus – Schutzleiter PE

Erdikus repräsentiert den **Schutzleiter PE** (grün-gelb) nach IEC 60446.
Der ewige Bodyguard. Stoisch, wortlos, geht nirgendwo hin.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Aderfarbe** | Grün-Gelb (zweifarbig, alternierend) |
| **Körperfarbe** | Diagonale Streifen: Grün `#4CAF50` / Gelb `#FFD700` |
| **Leiterbahnen** | Grün `#2E7D32` mit gelben Via-Punkten |
| **Glühbirnen** | Eine grün, eine gelb – zweifarbig |
| **Augen** | Entspannt, geerdet, schläfrig – der Ruhepol |
| **Besonderheit** | Erdungssymbol ⏚ als Tattoo auf dem Bauch |

## Persönlichkeit

*Stoisch. Absolut zuverlässig. Spricht wenig.* Breit aufgestellt, solide,
geht nirgendwo hin. Der Stille, der alles auffängt, wenn es wirklich drauf ankommt.

## Norm-Referenz

- **Farbe:** Grün-Gelb (PE) nach IEC 60446 und DIN VDE 0293
- **Einsatz:** Schutzleiter – fängt Fehlerströme auf, schützt vor Berührungsspannung
- **Verbündeter:** Isolus – beide schützen das System, ohne viele Worte
)",
                    "erdikus PE schutzleiter netzleiter IEC grün gelb erde"
                },
                {
                    "Datinchen – Kommunikation",
                    R"(# Datinchen – Kommunikation & Bus

Datinchen repräsentiert das **Kommunikationssignal** – Bus, Feldbus,
Differenzsignal (RS-485, CAN, Ethernet). Sie weiß mehr als alle anderen
und hält alles zusammen.

## Merkmale

| Merkmal | Ausprägung |
|---|---|
| **Farbe** | Tiefviolett `#7B2FBE` |
| **Leiterbahnen** | Doppelte Traces `#C084FC` – Differenzpaar-Symbol |
| **Ohren** | Keine Glühbirnen – stattdessen zwei kleine Antennen |
| **Augen** | Klug, leicht verschmitzt – weiß mehr als alle anderen |

## Persönlichkeit

Kommunikativ, redselig, verbindet alle.
*„Ich sage immer das erste und das letzte Wort."*
Der soziale Knotenpunkt – ohne Datinchen weiß die linke Hand nicht,
was die rechte tut.

## Norm-Referenz

- Differenzpaar-Signalübertragung (RS-485, CAN, Profibus, EtherCAT)
- Zwei parallele Traces = differenzielles Signal
- **Antennen** statt Glühbirnen: drahtlose Variante möglich
)",
                    "datinchen kommunikation bus signal CAN RS485 lila violett"
                },
                {
                    "Pokeström",
                    R"(# Pokeström – das Maskottchen

Pokeström ist der erste Strömling – die Urform des Charakter-Systems.
Er ist nicht an einen bestimmten Leitertyp gebunden, sondern steht für
**Strömling Design** als Ganzes.

## Erkennungsmerkmale

- Runder, pausbackiger Fischkörper
- **Zwei leuchtende Glühbirnen** als Ohren (gelb, warm)
- **Fluoreszierende Leiterbahnen** – PCB-Stil
- **Schielende Augen** – der typische Pokeström-Blick

## Im Programm

- **Startbildschirm:** Pokeström schwimmt von links nach rechts, wenn kein Projekt offen ist
- **Bauteilbibliothek:** erscheint als Platzhalter, wenn noch keine Bauteile angelegt sind

## Ursprung

Die erste Skizze entstand auf einem Whiteboard: ein Fisch, der ein ET-Symbol
(Kondensator) in der Flosse hält – und der Gedanke war: *„Was wäre, wenn jedes
elektrische Bauteil seinen eigenen Fisch-Charakter hätte?"*
)",
                    "pokeström maskottchen startbildschirm fisch charakter"
                }
            }
        },
        {
            "Tester",
            "Testanleitungen und Rückmeldungen von Programmtestern",
            60,
            false,
            {
                {
                    "Testanleitung – Strömling Design",
                    R"(# Testanleitung – Strömling Design

Danke fürs Testen! Diese Seite beschreibt, welche Bereiche geprüft werden sollen
und wie du deine Beobachtungen festhalten kannst.

**Ziel:** Fehler finden, Unklarheiten melden, Verbesserungsvorschläge einbringen.
Du kannst diese Seite direkt bearbeiten – deine Einträge bleiben beim nächsten
Programmstart erhalten.

---

## 1. Projekt anlegen und öffnen

- [ ] Neues Projekt anlegen (Startbildschirm → „Neu")
- [ ] Projekt benennen und speichern
- [ ] Projekt schließen und wieder öffnen
- [ ] Projekt exportieren (Menü → Exportieren)

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 2. Schaltplan-Canvas

- [ ] Neue Seite anlegen
- [ ] Symbol aus der Symbolpalette auf den Canvas ziehen
- [ ] Symbol verschieben, löschen (Entf-Taste)
- [ ] Zoom mit Mausrad, Pan mit mittlerer Maustaste oder Leertaste + Ziehen
- [ ] Verbindungslinie zwischen zwei Symbolen ziehen
- [ ] Kabelbrücke anlegen
- [ ] Beschriftung / BMK im Eigenschaftenpanel eingeben
- [ ] Rückgängig / Wiederholen (Strg+Z / Strg+Y)
- [ ] Mehrfachauswahl mit Strg+Klick oder Gummiband-Selektion

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 3. Eigenschaftenpanel (rechts)

- [ ] Bauteil anklicken → Eigenschaften erscheinen rechts
- [ ] Betriebsmittelkennzeichen (BMK) eingeben
- [ ] Farbe ändern (falls verfügbar)
- [ ] Mehrfachauswahl → Mehfachauswahl-Sektion erscheint
- [ ] Kabelverbindung auswählen → Leitungseigenschaften erscheinen

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 4. Symboleditor

- [ ] Symboleditor öffnen (Sidebar)
- [ ] Bestehendes Symbol auswählen und bearbeiten
- [ ] Neues Symbol anlegen
- [ ] Pin hinzufügen, beschriften
- [ ] Symbol speichern, im Canvas verwenden

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 5. Bauteilbibliothek

- [ ] Bauteilbibliothek öffnen
- [ ] Neues Bauteil anlegen
- [ ] Kabeldefinition für ein Bauteil anlegen
- [ ] Bauteil im Schaltplan platzieren

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 6. Klemmen und Klemmenreihen

- [ ] Klemmenreihe anlegen
- [ ] Klemme hinzufügen
- [ ] Klemme auf Schaltplanseite platzieren
- [ ] Klemmenplan in den Listen prüfen

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 7. Inbetriebnahme (IBN)

- [ ] IBN-Ansicht öffnen
- [ ] Betriebsmittel prüfen (Haken setzen)
- [ ] Messwert erfassen
- [ ] Prüfprotokoll exportieren (PDF)

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 8. Kabelrechner

- [ ] Kabelrechner öffnen
- [ ] Werte eingeben (Spannung, Strom, Länge)
- [ ] Querschnitt berechnen lassen
- [ ] Ergebnis prüfen (plausibel?)

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 9. Listen (Stückliste, Kabelliste, Querverweise)

- [ ] Stückliste öffnen und prüfen
- [ ] Kabelliste prüfen
- [ ] Aderliste prüfen
- [ ] Klemmenplan prüfen
- [ ] CSV-Export testen

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 10. Wiki

- [ ] Wiki öffnen
- [ ] Artikel lesen
- [ ] Neuen Artikel anlegen
- [ ] Bild hochladen
- [ ] Volltextsuche verwenden
- [ ] Artikel exportieren / importieren

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 11. Einstellungen

- [ ] Einstellungen öffnen
- [ ] Theme wechseln (Hell / Dunkel / System)
- [ ] Sprache prüfen
- [ ] Strömlinge-Sektion anschauen 😊

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## 12. Fun-Modus

- [ ] Fun-Modus aktivieren (Tastenkombination, falls bekannt)
- [ ] Verschiedene Szenarien abwarten
- [ ] Impulsino beobachten
- [ ] Fun-Modus deaktivieren

**Beobachtungen / Fehler:**
*(hier eintragen)*

---

## Allgemeine Beobachtungen

### Was funktioniert besonders gut?
*(hier eintragen)*

### Was ist verwirrend oder unklar?
*(hier eintragen)*

### Wünsche / Ideen für Verbesserungen?
*(hier eintragen)*

### Systeminfo
- Betriebssystem: *(z.B. Ubuntu 24.04 / Windows 11 / macOS 14)*
- Qt-Version: *(falls bekannt)*
- Datum des Tests: *(TT.MM.JJJJ)*
- Tester: *(Name oder Pseudonym)*
)",
                    "tester testanleitung feedback checkliste"
                }
            }
        }
    };

    QSqlQuery qKat(m_wikiDb), qKatId(m_wikiDb), qArtIns(m_wikiDb), qArtUpd(m_wikiDb);
    qKat.prepare(R"(
        INSERT OR IGNORE INTO wiki_kategorie (name, beschreibung, sortierung)
        VALUES (:name, :beschr, :sort)
    )");
    // Artikel neu anlegen, falls noch nicht vorhanden
    qArtIns.prepare(R"(
        INSERT OR IGNORE INTO wiki_artikel (kategorie_id, titel, inhalt, tags, ist_system)
        SELECT :kid, :titel, :inhalt, :tags, :sys
        WHERE NOT EXISTS (
            SELECT 1 FROM wiki_artikel WHERE kategorie_id = :kid2 AND titel = :titel2
        )
    )");
    // System-Artikel: Inhalt bei jeder Migration aktualisieren
    qArtUpd.prepare(R"(
        UPDATE wiki_artikel SET inhalt = :inhalt, tags = :tags
        WHERE kategorie_id = :kid AND titel = :titel AND ist_system = 1
    )");

    for (const Kategorie &kat : kategorien) {
        qKat.bindValue(":name",  kat.name);
        qKat.bindValue(":beschr", kat.beschreibung);
        qKat.bindValue(":sort",  kat.sortierung);
        if (!qKat.exec()) {
            qWarning() << "seedWikiStarterInhalte Kategorie:" << qKat.lastError().text();
            return false;
        }

        qKatId.prepare("SELECT id FROM wiki_kategorie WHERE name = :n");
        qKatId.bindValue(":n", kat.name);
        qKatId.exec();
        if (!qKatId.next()) continue;
        const int katId = qKatId.value(0).toInt();

        for (const Artikel &art : kat.artikel) {
            qArtIns.bindValue(":kid",    katId);
            qArtIns.bindValue(":kid2",   katId);
            qArtIns.bindValue(":titel",  art.titel);
            qArtIns.bindValue(":titel2", art.titel);
            qArtIns.bindValue(":inhalt", art.inhalt);
            qArtIns.bindValue(":tags",   art.tags);
            qArtIns.bindValue(":sys",    kat.istSystem ? 1 : 0);
            if (!qArtIns.exec()) {
                qWarning() << "seedWikiStarterInhalte Artikel insert:" << qArtIns.lastError().text();
                return false;
            }
            if (kat.istSystem) {
                qArtUpd.bindValue(":kid",    katId);
                qArtUpd.bindValue(":titel",  art.titel);
                qArtUpd.bindValue(":inhalt", art.inhalt);
                qArtUpd.bindValue(":tags",   art.tags);
                if (!qArtUpd.exec()) {
                    qWarning() << "seedWikiStarterInhalte Artikel update:" << qArtUpd.lastError().text();
                    return false;
                }
            }
        }
    }

    // ── Strömlinge: Bilder aus QRC-Ressourcen einmalig einsamen ──────────
    auto seedBild = [&](const QString &artikelTitel, const QString &qrcPfad,
                        const QString &dateiname) {
        QSqlQuery qId(m_wikiDb);
        qId.prepare("SELECT id FROM wiki_artikel WHERE titel = :t");
        qId.bindValue(":t", artikelTitel);
        if (!qId.exec() || !qId.next()) return;
        const int artId = qId.value(0).toInt();

        QSqlQuery qCount(m_wikiDb);
        qCount.prepare("SELECT COUNT(*) FROM wiki_bild WHERE artikel_id = :aid");
        qCount.bindValue(":aid", artId);
        if (!qCount.exec() || !qCount.next() || qCount.value(0).toInt() > 0) return;

        QFile f(qrcPfad);
        if (!f.open(QIODevice::ReadOnly)) {
            qWarning() << "seedBild: Datei nicht gefunden:" << qrcPfad;
            return;
        }
        const QByteArray daten = f.readAll();
        f.close();
        if (daten.isEmpty()) return;

        QSqlQuery qIns(m_wikiDb);
        qIns.prepare(R"(
            INSERT INTO wiki_bild (artikel_id, dateiname, mime_typ, daten, sortierung)
            VALUES (:aid, :fn, 'image/png', :d, 1)
        )");
        qIns.bindValue(":aid", artId);
        qIns.bindValue(":fn",  dateiname);
        qIns.bindValue(":d",   daten);
        if (!qIns.exec())
            qWarning() << "seedBild INSERT:" << qIns.lastError().text();
    };

    seedBild("Schwärzchen – Systemfisch L2",  ":/assets/schwaerzchen_sheet.png",    "schwaerzchen_sheet.png");
    seedBild("Impulsino – Signal",             ":/assets/impulsino_uebersicht.png", "impulsino_uebersicht.png");
    seedBild("Isolus – Schutz & Isolierung",   ":/assets/isolus.png",               "isolus.png");
    seedBild("Pokeström",                       ":/assets/pokestroem_cee.png",       "pokestroem_cee.png");
    seedBild("Brauno – Außenleiter L1",         ":/assets/brauno_uebersicht.png",    "brauno_uebersicht.png");
    seedBild("Blaubertha – Neutralleiter N",    ":/assets/blaubertha_uebersicht.png","blaubertha_uebersicht.png");
    seedBild("Grausel – Außenleiter L3",        ":/assets/grausel_uebersicht.png",   "grausel_uebersicht.png");
    seedBild("Erdikus – Schutzleiter PE",       ":/assets/erdikus_uebersicht.png",   "erdikus_uebersicht.png");
    seedBild("Datinchen – Kommunikation",       ":/assets/datinchen_uebersicht.png", "datinchen_uebersicht.png");

    return true;
}

// ============================================================
// SPS/PLS-Integration
// ============================================================

// --- Rack ---

QVariantList Database::spsRackListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare("SELECT id, rack_nr, system_typ, bezeichnung, beschreibung, hersteller, sortierung "
              "FROM sps_rack WHERE projekt_id = :pid ORDER BY sortierung, rack_nr");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qWarning() << "spsRackListe:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap m;
        m["id"]           = q.value(0).toInt();
        m["rack_nr"]      = q.value(1).toInt();
        m["system_typ"]   = q.value(2).toString();
        m["bezeichnung"]  = q.value(3).toString();
        m["beschreibung"] = q.value(4).toString();
        m["hersteller"]   = q.value(5).toString();
        m["sortierung"]   = q.value(6).toInt();
        result.append(m);
    }
    return result;
}

int Database::spsRackAnlegen(int projektId, int rackNr, const QString &systemTyp,
                              const QString &bezeichnung, const QString &hersteller)
{
    QSqlQuery q;
    q.prepare("INSERT INTO sps_rack (projekt_id, rack_nr, system_typ, bezeichnung, hersteller) "
              "VALUES (:pid, :nr, :typ, :bez, :her)");
    q.bindValue(":pid", projektId);
    q.bindValue(":nr",  rackNr);
    q.bindValue(":typ", systemTyp);
    q.bindValue(":bez", bezeichnung);
    q.bindValue(":her", hersteller);
    if (!q.exec()) { qWarning() << "spsRackAnlegen:" << q.lastError().text(); return -1; }
    return q.lastInsertId().toInt();
}

bool Database::spsRackAktualisieren(int id, int rackNr, const QString &systemTyp,
                                     const QString &bezeichnung, const QString &beschreibung,
                                     const QString &hersteller)
{
    QSqlQuery q;
    q.prepare("UPDATE sps_rack SET rack_nr=:nr, system_typ=:typ, bezeichnung=:bez, "
              "beschreibung=:desc, hersteller=:her WHERE id=:id");
    q.bindValue(":nr",   rackNr);
    q.bindValue(":typ",  systemTyp);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":desc", beschreibung);
    q.bindValue(":her",  hersteller);
    q.bindValue(":id",   id);
    if (!q.exec()) { qWarning() << "spsRackAktualisieren:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsRackLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM sps_rack WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) { qWarning() << "spsRackLoeschen:" << q.lastError().text(); return false; }
    return true;
}

// --- Baugruppe ---

QVariantList Database::spsBaugruppeListe(int rackId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare("SELECT id, rack_id, slot, typ, bezeichnung, artikel_nr, kanaele, "
              "datentyp_standard, adress_byte_start, kommentar "
              "FROM sps_baugruppe WHERE rack_id = :rid ORDER BY slot");
    q.bindValue(":rid", rackId);
    if (!q.exec()) { qWarning() << "spsBaugruppeListe:" << q.lastError().text(); return result; }
    while (q.next()) {
        QVariantMap m;
        m["id"]                = q.value(0).toInt();
        m["rack_id"]           = q.value(1).toInt();
        m["slot"]              = q.value(2).toInt();
        m["typ"]               = q.value(3).toString();
        m["bezeichnung"]       = q.value(4).toString();
        m["artikel_nr"]        = q.value(5).toString();
        m["kanaele"]           = q.value(6).toInt();
        m["datentyp_standard"] = q.value(7).toString();
        m["adress_byte_start"] = q.value(8).toInt();
        m["kommentar"]         = q.value(9).toString();
        result.append(m);
    }
    return result;
}

int Database::spsBaugruppeAnlegen(int rackId, int slot, const QString &typ,
                                   const QString &bezeichnung, int kanaele, int adressByteStart)
{
    QSqlQuery q;
    q.prepare("INSERT INTO sps_baugruppe (rack_id, slot, typ, bezeichnung, kanaele, adress_byte_start) "
              "VALUES (:rid, :slot, :typ, :bez, :kan, :abs)");
    q.bindValue(":rid",  rackId);
    q.bindValue(":slot", slot);
    q.bindValue(":typ",  typ);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":kan",  kanaele);
    q.bindValue(":abs",  adressByteStart);
    if (!q.exec()) { qWarning() << "spsBaugruppeAnlegen:" << q.lastError().text(); return -1; }
    return q.lastInsertId().toInt();
}

bool Database::spsBaugruppeAktualisieren(int id, int slot, const QString &typ,
                                          const QString &bezeichnung, const QString &artikelNr,
                                          int kanaele, const QString &datentypStandard,
                                          int adressByteStart, const QString &kommentar)
{
    QSqlQuery q;
    q.prepare("UPDATE sps_baugruppe SET slot=:slot, typ=:typ, bezeichnung=:bez, artikel_nr=:art, "
              "kanaele=:kan, datentyp_standard=:dts, adress_byte_start=:abs, kommentar=:kom "
              "WHERE id=:id");
    q.bindValue(":slot", slot);
    q.bindValue(":typ",  typ);
    q.bindValue(":bez",  bezeichnung);
    q.bindValue(":art",  artikelNr);
    q.bindValue(":kan",  kanaele);
    q.bindValue(":dts",  datentypStandard);
    q.bindValue(":abs",  adressByteStart);
    q.bindValue(":kom",  kommentar);
    q.bindValue(":id",   id);
    if (!q.exec()) { qWarning() << "spsBaugruppeAktualisieren:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsBaugruppeLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM sps_baugruppe WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) { qWarning() << "spsBaugruppeLoeschen:" << q.lastError().text(); return false; }
    return true;
}

// --- Kanal ---

static QString _spsAdresseFormatieren(const QString &systemTyp, int rackNr, int slot,
                                       int kanalNr, const QString &adressTyp,
                                       int byteNr, int bitNr, const QString &datentyp)
{
    if (systemTyp == QLatin1String("PLS")) {
        return QStringLiteral("R%1 S%2 K%3").arg(rackNr).arg(slot).arg(kanalNr + 1);
    }
    if (datentyp == QLatin1String("BYTE"))  return QStringLiteral("%1B%2").arg(adressTyp).arg(byteNr);
    if (datentyp == QLatin1String("WORD"))  return QStringLiteral("%1W%2").arg(adressTyp).arg(byteNr);
    if (datentyp == QLatin1String("DWORD")) return QStringLiteral("%1D%2").arg(adressTyp).arg(byteNr);
    return QStringLiteral("%1%2.%3").arg(adressTyp).arg(byteNr).arg(bitNr);
}

static const QLatin1String _spsKanalSelectBase(
    "SELECT sk.id, sk.projekt_id, sk.baugruppe_id, sk.kanal_nr, "
    "sk.adress_typ, sk.byte_nr, sk.bit_nr, sk.datentyp, "
    "sk.variablenname, sk.kommentar, sk.grafik_element_id, "
    "sk.pls_einheit, sk.pls_bereich_min, sk.pls_bereich_max, "
    "sk.pls_alarm_ll, sk.pls_alarm_lo, sk.pls_alarm_hi, sk.pls_alarm_hh, "
    "sk.pls_hart_adresse, sk.pls_protokoll, "
    "sr.id AS rack_id, sr.rack_nr, sr.system_typ, sb.slot, "
    "ge.extra_daten AS element_extra_daten, se.name AS seite_name "
    "FROM sps_kanal sk "
    "LEFT JOIN sps_baugruppe  sb ON sb.id = sk.baugruppe_id "
    "LEFT JOIN sps_rack       sr ON sr.id = sb.rack_id "
    "LEFT JOIN grafik_element ge ON ge.id = sk.grafik_element_id "
    "LEFT JOIN seite          se ON se.id = ge.seite_id ");

static QVariantMap _spsKanalRow(QSqlQuery &q)
{
    QVariantMap m;
    m["id"]                = q.value(0).toInt();
    m["projekt_id"]        = q.value(1).toInt();
    m["baugruppe_id"]      = q.value(2).isNull() ? QVariant() : q.value(2).toInt();
    m["kanal_nr"]          = q.value(3).isNull() ? QVariant() : q.value(3).toInt();
    m["adress_typ"]        = q.value(4).toString();
    m["byte_nr"]           = q.value(5).toInt();
    m["bit_nr"]            = q.value(6).toInt();
    m["datentyp"]          = q.value(7).toString();
    m["variablenname"]     = q.value(8).toString();
    m["kommentar"]         = q.value(9).toString();
    m["grafik_element_id"] = q.value(10).isNull() ? QVariant() : q.value(10).toInt();
    m["pls_einheit"]       = q.value(11).isNull() ? QVariant() : q.value(11).toString();
    m["pls_bereich_min"]   = q.value(12).isNull() ? QVariant() : q.value(12).toDouble();
    m["pls_bereich_max"]   = q.value(13).isNull() ? QVariant() : q.value(13).toDouble();
    m["pls_alarm_ll"]      = q.value(14).isNull() ? QVariant() : q.value(14).toDouble();
    m["pls_alarm_lo"]      = q.value(15).isNull() ? QVariant() : q.value(15).toDouble();
    m["pls_alarm_hi"]      = q.value(16).isNull() ? QVariant() : q.value(16).toDouble();
    m["pls_alarm_hh"]      = q.value(17).isNull() ? QVariant() : q.value(17).toDouble();
    m["pls_hart_adresse"]  = q.value(18).isNull() ? QVariant() : q.value(18).toInt();
    m["pls_protokoll"]     = q.value(19).isNull() ? QVariant() : q.value(19).toString();
    m["rack_id"]           = q.value(20).isNull() ? QVariant() : q.value(20).toInt();
    m["rack_nr"]           = q.value(21).isNull() ? QVariant() : q.value(21).toInt();
    m["system_typ"]             = q.value(22).isNull() ? QStringLiteral("SPS") : q.value(22).toString();
    m["slot"]                   = q.value(23).isNull() ? QVariant() : q.value(23).toInt();
    m["element_extra_daten"]    = q.value(24).isNull() ? QVariant() : q.value(24).toString();
    m["seite_name"]             = q.value(25).isNull() ? QVariant() : q.value(25).toString();
    // Formatierte Adresse berechnen
    int rackNr  = q.value(21).isNull() ? 0 : q.value(21).toInt();
    int slot    = q.value(23).isNull() ? 0 : q.value(23).toInt();
    int kanalNr = q.value(3).isNull()  ? 0 : q.value(3).toInt();
    m["adresse"] = _spsAdresseFormatieren(m["system_typ"].toString(), rackNr, slot, kanalNr,
                                           m["adress_typ"].toString(),
                                           m["byte_nr"].toInt(), m["bit_nr"].toInt(),
                                           m["datentyp"].toString());
    return m;
}

QVariantList Database::spsKanalListe(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(QString(_spsKanalSelectBase)
              + "WHERE sk.projekt_id = :pid "
                "ORDER BY sr.rack_nr, sb.slot, sk.kanal_nr, sk.adress_typ, sk.byte_nr, sk.bit_nr");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qWarning() << "spsKanalListe:" << q.lastError().text(); return result; }
    while (q.next()) result.append(_spsKanalRow(q));
    return result;
}

QVariantList Database::spsKanalListeFuerBaugruppe(int baugruppeId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare(QString(_spsKanalSelectBase)
              + "WHERE sk.baugruppe_id = :bid ORDER BY sk.kanal_nr, sk.byte_nr, sk.bit_nr");
    q.bindValue(":bid", baugruppeId);
    if (!q.exec()) { qWarning() << "spsKanalListeFuerBaugruppe:" << q.lastError().text(); return result; }
    while (q.next()) result.append(_spsKanalRow(q));
    return result;
}

int Database::spsKanalAnlegen(int projektId, int baugruppeId, int kanalNr,
                               const QString &adressTyp, int byteNr, int bitNr,
                               const QString &datentyp, const QString &variablenname,
                               const QString &kommentar)
{
    QSqlQuery q;
    q.prepare("INSERT INTO sps_kanal "
              "(projekt_id, baugruppe_id, kanal_nr, adress_typ, byte_nr, bit_nr, "
              " datentyp, variablenname, kommentar) "
              "VALUES (:pid, :bid, :knr, :typ, :byt, :bit, :dty, :var, :kom)");
    q.bindValue(":pid", projektId);
    q.bindValue(":bid", baugruppeId > 0 ? QVariant(baugruppeId) : QVariant());
    q.bindValue(":knr", kanalNr >= 0    ? QVariant(kanalNr)     : QVariant());
    q.bindValue(":typ", adressTyp);
    q.bindValue(":byt", byteNr);
    q.bindValue(":bit", bitNr);
    q.bindValue(":dty", datentyp);
    q.bindValue(":var", variablenname);
    q.bindValue(":kom", kommentar);
    if (!q.exec()) { qWarning() << "spsKanalAnlegen:" << q.lastError().text(); return -1; }
    return q.lastInsertId().toInt();
}

bool Database::spsKanalAktualisieren(int id, const QVariantMap &felder)
{
    if (felder.isEmpty()) return true;

    QStringList setClauses;
    QVariantMap bv;
    const QStringList textFelder = {"adress_typ","datentyp","variablenname","kommentar",
                                     "pls_einheit","pls_protokoll"};
    const QStringList intFelder  = {"byte_nr","bit_nr","kanal_nr","pls_hart_adresse"};
    const QStringList realFelder = {"pls_bereich_min","pls_bereich_max",
                                     "pls_alarm_ll","pls_alarm_lo","pls_alarm_hi","pls_alarm_hh"};

    for (const QString &f : textFelder) {
        if (felder.contains(f)) {
            setClauses << (f + QStringLiteral("=:") + f);
            bv[f] = felder[f].isNull() ? QVariant() : felder[f].toString();
        }
    }
    for (const QString &f : intFelder) {
        if (felder.contains(f)) {
            setClauses << (f + QStringLiteral("=:") + f);
            bv[f] = felder[f].isNull() ? QVariant() : felder[f].toInt();
        }
    }
    for (const QString &f : realFelder) {
        if (felder.contains(f)) {
            setClauses << (f + QStringLiteral("=:") + f);
            bv[f] = felder[f].isNull() ? QVariant() : felder[f].toDouble();
        }
    }
    if (setClauses.isEmpty()) return true;

    QSqlQuery q;
    q.prepare(QStringLiteral("UPDATE sps_kanal SET %1 WHERE id=:id").arg(setClauses.join(",")));
    for (auto it = bv.constBegin(); it != bv.constEnd(); ++it)
        q.bindValue(QStringLiteral(":") + it.key(), it.value());
    q.bindValue(":id", id);
    if (!q.exec()) { qWarning() << "spsKanalAktualisieren:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsKanalLoeschen(int id)
{
    QSqlQuery q;
    q.prepare("DELETE FROM sps_kanal WHERE id=:id");
    q.bindValue(":id", id);
    if (!q.exec()) { qWarning() << "spsKanalLoeschen:" << q.lastError().text(); return false; }
    return true;
}

QString Database::spsKanalAdresse(int kanalId)
{
    QSqlQuery q;
    q.prepare(QString(_spsKanalSelectBase) + "WHERE sk.id = :id");
    q.bindValue(":id", kanalId);
    if (!q.exec() || !q.next()) return QString();
    return _spsKanalRow(q)["adresse"].toString();
}

bool Database::spsKanalElementZuweisen(int kanalId, int elementId)
{
    QSqlQuery q;
    q.prepare("UPDATE sps_kanal SET grafik_element_id=:eid WHERE id=:id");
    q.bindValue(":eid", elementId);
    q.bindValue(":id",  kanalId);
    if (!q.exec()) { qWarning() << "spsKanalElementZuweisen:" << q.lastError().text(); return false; }
    return true;
}

bool Database::spsKanalElementEntfernen(int kanalId)
{
    QSqlQuery q;
    q.prepare("UPDATE sps_kanal SET grafik_element_id=NULL WHERE id=:id");
    q.bindValue(":id", kanalId);
    if (!q.exec()) { qWarning() << "spsKanalElementEntfernen:" << q.lastError().text(); return false; }
    return true;
}

QVariantMap Database::spsKanalFuerElement(int elementId)
{
    QSqlQuery q;
    q.prepare(QString(_spsKanalSelectBase) + "WHERE sk.grafik_element_id = :eid");
    q.bindValue(":eid", elementId);
    if (!q.exec() || !q.next()) return {};
    return _spsKanalRow(q);
}

QVariantList Database::spsIOListe(int projektId)
{
    return spsKanalListe(projektId);
}

bool Database::spsIOListeCsvSpeichern(int projektId, const QString &pfad)
{
    QVariantList kanaele = spsIOListe(projektId);
    QString localPfad = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;
    QFile file(localPfad);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "spsIOListeCsvSpeichern: Datei nicht schreibbar:" << localPfad;
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "\"Adresse\";\"System\";\"Typ\";\"Variable / Tag\";\"Kommentar\";"
           "\"Einheit\";\"Bereich Min\";\"Bereich Max\";"
           "\"Alarm LL\";\"Alarm LO\";\"Alarm HI\";\"Alarm HH\";"
           "\"Protokoll\";\"Element-ID\"\n";

    auto csv = [](const QVariant &v) -> QString {
        if (v.isNull()) return QString();
        return v.toString().replace('"', QLatin1String("\"\""));
    };

    for (const QVariant &kv : kanaele) {
        QVariantMap k = kv.toMap();
        out << '"' << csv(k["adresse"])          << "\";";
        out << '"' << csv(k["system_typ"])        << "\";";
        out << '"' << csv(k["adress_typ"])        << "\";";
        out << '"' << csv(k["variablenname"])     << "\";";
        out << '"' << csv(k["kommentar"])         << "\";";
        out << '"' << csv(k["pls_einheit"])       << "\";";
        out << '"' << csv(k["pls_bereich_min"])   << "\";";
        out << '"' << csv(k["pls_bereich_max"])   << "\";";
        out << '"' << csv(k["pls_alarm_ll"])      << "\";";
        out << '"' << csv(k["pls_alarm_lo"])      << "\";";
        out << '"' << csv(k["pls_alarm_hi"])      << "\";";
        out << '"' << csv(k["pls_alarm_hh"])      << "\";";
        out << '"' << csv(k["pls_protokoll"])     << "\";";
        out << '"' << csv(k["grafik_element_id"]) << "\"\n";
    }
    file.close();
    qInfo() << "SPS/PLS I/O-Liste exportiert:" << localPfad << "(" << kanaele.size() << "Kanäle)";
    return true;
}

QVariantList Database::spsKonfliktElementIds(int projektId)
{
    QVariantList result;
    QSqlQuery q;
    q.prepare("SELECT grafik_element_id FROM sps_kanal "
              "WHERE projekt_id = :pid AND grafik_element_id IS NOT NULL "
              "GROUP BY grafik_element_id HAVING COUNT(*) > 1");
    q.bindValue(":pid", projektId);
    if (!q.exec()) { qWarning() << "spsKonfliktElementIds:" << q.lastError().text(); return result; }
    while (q.next()) result.append(q.value(0).toInt());
    return result;
}

// ============================================================
// Canvas PDF-Export (L16)
// ============================================================

// ── Hilfsfunktionen (file-scope) ────────────────────────────

static QColor pdfFarbe(const QString &s, const QColor &def = Qt::black)
{
    if (s.isEmpty()) return def;
    QColor c(s);
    return c.isValid() ? c : def;
}

static Qt::PenStyle pdfLinienart(const QString &art)
{
    if (art == "gestrichelt")  return Qt::DashLine;
    if (art == "gepunktet")    return Qt::DotLine;
    return Qt::SolidLine;
}

static QPen pdfPen(const QVariantMap &el, double lw_dev)
{
    QPen pen;
    pen.setColor(pdfFarbe(el.value("strichFarbe").toString()));
    pen.setWidthF(lw_dev);
    pen.setCapStyle(Qt::FlatCap);
    pen.setJoinStyle(Qt::MiterJoin);
    pen.setStyle(pdfLinienart(el.value("strichArt").toString()));
    return pen;
}

// Symbol-Primitiv zeichnen im lokalen Koordinatensystem 0..w × 0..h (in Device-Pixel)
static void pdfPrimitivRendern(QPainter &p, const QVariantMap &pr,
                               double w, double h, const QPen &basePen)
{
    QPen pen = basePen;
    QString la = pr.value("linienart").toString();
    if      (la == "dash")    pen.setStyle(Qt::DashLine);
    else if (la == "dot")     pen.setStyle(Qt::DotLine);
    else if (la == "dashdot") pen.setStyle(Qt::DashDotLine);
    else                      pen.setStyle(Qt::SolidLine);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);

    QString typ = pr.value("typ").toString();

    if (typ == "linie") {
        p.drawLine(QLineF(pr.value("x1").toDouble() * w, pr.value("y1").toDouble() * h,
                          pr.value("x2").toDouble() * w, pr.value("y2").toDouble() * h));

    } else if (typ == "rechteck") {
        double rx = pr.value("x1").toDouble() * w;
        double ry = pr.value("y1").toDouble() * h;
        double rw = (pr.value("x2").toDouble() - pr.value("x1").toDouble()) * w;
        double rh = (pr.value("y2").toDouble() - pr.value("y1").toDouble()) * h;
        p.drawRect(QRectF(rx, ry, rw, rh));

    } else if (typ == "kreis_offen") {
        double cx = pr.value("x1").toDouble() * w;
        double cy = pr.value("y1").toDouble() * h;
        double r  = pr.value("radius").toDouble() * w;
        p.drawEllipse(QPointF(cx, cy), r, r);

    } else if (typ == "kreis_gefuellt") {
        double cx = pr.value("x1").toDouble() * w;
        double cy = pr.value("y1").toDouble() * h;
        double r  = pr.value("radius").toDouble() * w;
        p.setBrush(pen.color());
        p.setPen(Qt::NoPen);
        p.drawEllipse(QPointF(cx, cy), r, r);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);

    } else if (typ == "bogen") {
        double cx = pr.value("x1").toDouble() * w;
        double cy = pr.value("y1").toDouble() * h;
        double r  = pr.value("radius").toDouble() * w;
        // Canvas: 0=east, CW positive (Y-down), angles in degrees
        // QPainter: 0=east, CCW positive
        // Conversion: qp_start = -canvas_start; CW canvas = negative QPainter span
        double vonDeg = pr.value("winkel_von").toDouble();
        double bisDeg = pr.value("winkel_bis").toDouble();
        bool   ccw    = pr.value("bogen_gegen_uhrzeiger").toBool();
        double span   = bisDeg - vonDeg;
        while (span < 0)   span += 360;
        while (span > 360) span -= 360;
        if (qAbs(span) < 0.01) span = 360;
        double qpStart = -vonDeg;
        double qpSpan  = ccw ? span : -span;
        p.drawArc(QRectF(cx - r, cy - r, 2*r, 2*r),
                  qRound(qpStart * 16), qRound(qpSpan * 16));

    } else if (typ == "text") {
        double tx     = pr.value("x1").toDouble() * w;
        double ty     = pr.value("y1").toDouble() * h;
        double fs     = pr.value("schrift_relativ").toDouble() * h;
        bool   bold   = pr.value("schrift_fett").toBool();
        QString align    = pr.value("text_align").toString();
        QString baseline = pr.value("text_baseline").toString();
        QString inhalt   = pr.value("text_inhalt").toString();
        if (inhalt.isEmpty()) return;

        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fs)));
        font.setBold(bold);
        p.setFont(font);
        p.setPen(pen);

        Qt::Alignment qa = Qt::AlignLeft;
        if (align == "center") qa = Qt::AlignHCenter;
        else if (align == "right") qa = Qt::AlignRight;

        double rectW = w, rectH = qMax(fs * 2, 4.0);
        double rx = tx, ry = ty;
        if (align == "center") rx -= w / 2;
        if (baseline == "middle")       ry -= fs * 0.5;
        else if (baseline == "bottom")  ry -= fs;

        p.drawText(QRectF(rx, ry, rectW, rectH), qa | Qt::AlignTop, inhalt);

    } else if (typ == "dreieck_gefuellt") {
        QPolygonF tri;
        tri << QPointF(pr.value("x1").toDouble() * w, pr.value("y1").toDouble() * h)
            << QPointF(pr.value("x2").toDouble() * w, pr.value("y2").toDouble() * h)
            << QPointF(pr.value("x3").toDouble() * w, pr.value("y3").toDouble() * h);
        p.setBrush(pen.color());
        p.setPen(Qt::NoPen);
        p.drawPolygon(tri);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
    }
}

// Symbol mit Primitiven rendern (Position + Größe in Device-Pixeln)
static void pdfSymbolRendern(QPainter &p, const QString &symbolId,
                             double x, double y, double sw, double sh,
                             int rotation, bool spiegelX, bool spiegelY,
                             const QPen &pen)
{
    if (sw < 0.5 || sh < 0.5) return;

    QSqlQuery q;
    q.prepare(R"(SELECT typ,x1,y1,x2,y2,x3,y3,radius,winkel_von,winkel_bis,
                        bogen_gegen_uhrzeiger,text_inhalt,schrift_relativ,schrift_fett,
                        text_align,text_baseline,linienart
                 FROM symbol_primitiv WHERE symbol_id=:sid ORDER BY reihenfolge)");
    q.bindValue(":sid", symbolId);
    if (!q.exec()) return;

    QVector<QVariantMap> prims;
    while (q.next()) {
        QVariantMap m;
        m["typ"]                    = q.value(0).toString();
        m["x1"]                     = q.value(1).toDouble();
        m["y1"]                     = q.value(2).toDouble();
        m["x2"]                     = q.value(3).toDouble();
        m["y2"]                     = q.value(4).toDouble();
        m["x3"]                     = q.value(5).toDouble();
        m["y3"]                     = q.value(6).toDouble();
        m["radius"]                 = q.value(7).toDouble();
        m["winkel_von"]             = q.value(8).toDouble();
        m["winkel_bis"]             = q.value(9).toDouble();
        m["bogen_gegen_uhrzeiger"]  = q.value(10).toInt() != 0;
        m["text_inhalt"]            = q.value(11).toString();
        m["schrift_relativ"]        = q.value(12).toDouble();
        m["schrift_fett"]           = q.value(13).toInt() != 0;
        m["text_align"]             = q.value(14).toString();
        m["text_baseline"]          = q.value(15).toString();
        m["linienart"]              = q.value(16).toString();
        prims.append(m);
    }
    if (prims.isEmpty()) return;

    p.save();
    p.translate(x + sw / 2, y + sh / 2);
    if (rotation != 0) p.rotate(rotation);
    if (spiegelX) p.scale(-1.0, 1.0);
    if (spiegelY) p.scale(1.0, -1.0);
    p.translate(-sw / 2, -sh / 2);

    for (const QVariantMap &pr : prims)
        pdfPrimitivRendern(p, pr, sw, sh, pen);

    p.restore();
}

// Beschriftungen (BMK, Freitext) über/neben einem Symbol rendern
static void pdfBeschriftungRendern(QPainter &p, const QVariantMap &el,
                                   double C, double pxPerMm)
{
    Q_UNUSED(pxPerMm)
    QString sid = el.value("symbolId").toString();
    static const QStringList kNoLabel = {
        "winkel","treffpunkt","treffpunkt_l","geraeteanschluss","unterbrechung",
        "aderdefinition","querverweis"
    };
    if (kNoLabel.contains(sid)) return;

    QVariantMap ed  = el.value("extraDaten").toMap();
    QString bmk     = ed.value("bmk").toString();
    QString ft1     = ed.value("freitext1").toString();
    QString ft2     = ed.value("freitext2").toString();
    if (bmk.isEmpty() && ft1.isEmpty() && ft2.isEmpty()) return;

    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = qAbs(x2 - x1);
    double sh  = qAbs(y2 - y1);
    double cx  = (x1 + x2) / 2;
    double rot = el.value("rotation").toInt();

    double schrift = ed.value("schriftgroesse", 2.5).toDouble();
    double fsMm    = schrift;
    double fsDev   = fsMm * pxPerMm;

    QFont fontBmk, fontFt;
    fontBmk.setFamily(QStringLiteral("sans-serif"));
    fontBmk.setPixelSize(qMax(1, qRound(fsDev)));
    fontBmk.setBold(true);
    fontFt.setFamily(QStringLiteral("sans-serif"));
    fontFt.setPixelSize(qMax(1, qRound(fsDev * 0.85)));

    p.save();
    p.setPen(pdfFarbe(el.value("strichFarbe").toString()));

    // Beschriftung immer waagerecht; Position über/links vom Symbol
    bool vertikal = (rot == 90 || rot == 270);
    double anchorX, anchorY;
    if (vertikal) {
        anchorX = x1 < x2 ? qMin(x1,x2) - fsDev * 0.3 : qMin(x1,x2) - fsDev * 0.3;
        anchorY = (y1 + y2) / 2;
    } else {
        anchorX = cx;
        anchorY = qMin(y1, y2) - fsDev * 0.3;
    }

    double ty = anchorY;
    if (vertikal) {
        double tx = anchorX - fsDev * 3;
        if (!bmk.isEmpty()) {
            p.setFont(fontBmk);
            p.drawText(QRectF(tx - sw, ty - sh/2, sw, sh), Qt::AlignRight | Qt::AlignVCenter, bmk);
        }
        if (!ft1.isEmpty()) {
            p.setFont(fontFt);
            p.drawText(QRectF(tx - sw, ty - sh/2 + fsDev * 1.3, sw, sh), Qt::AlignRight | Qt::AlignVCenter, ft1);
        }
    } else {
        if (!bmk.isEmpty()) {
            p.setFont(fontBmk);
            p.drawText(QRectF(cx - sw, ty - fsDev * 1.5, sw*2, fsDev * 1.3),
                       Qt::AlignHCenter | Qt::AlignBottom, bmk);
            ty -= fsDev * 1.4;
        }
        if (!ft1.isEmpty()) {
            p.setFont(fontFt);
            p.drawText(QRectF(cx - sw, ty - fsDev * 1.5, sw*2, fsDev * 1.3),
                       Qt::AlignHCenter | Qt::AlignBottom, ft1);
            ty -= fsDev * 1.2;
        }
        if (!ft2.isEmpty()) {
            p.setFont(fontFt);
            p.drawText(QRectF(cx - sw, ty - fsDev * 1.5, sw*2, fsDev * 1.3),
                       Qt::AlignHCenter | Qt::AlignBottom, ft2);
        }
    }
    p.restore();
}

// Einzelnes grafik_element rendern
static void pdfElementRendern(QPainter &p, const QVariantMap &el,
                               double C, double pxPerMm)
{
    QString typ = el.value("typ").toString();
    double x1 = el.value("x1").toDouble() * C;
    double y1 = el.value("y1").toDouble() * C;
    double x2 = el.value("x2").toDouble() * C;
    double y2 = el.value("y2").toDouble() * C;
    double sw  = x2 - x1;
    double sh  = y2 - y1;

    double strichBr = qMax(0.3, el.value("strichBreite", 1.5).toDouble() * 0.25 * pxPerMm);
    QPen pen = pdfPen(el, strichBr);

    if (typ == "linie") {
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawLine(QLineF(x1, y1, x2, y2));

    } else if (typ == "polygonlinie") {
        QVariantList pts = el.value("punkte").toList();
        if (pts.size() < 2) return;
        QVector<QPointF> poly;
        for (const QVariant &v : pts) {
            QVariantMap pt = v.toMap();
            poly << QPointF(pt.value("x").toDouble() * C, pt.value("y").toDouble() * C);
        }
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawPolyline(poly.data(), poly.size());

    } else if (typ == "rechteck") {
        p.setPen(pen);
        double er = el.value("eckenRadius", 0.0).toDouble() * 0.25 * pxPerMm;
        bool fu   = el.value("fuell").toBool();
        if (fu) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString(), QColor(26,58,106));
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        if (er > 0.5)
            p.drawRoundedRect(QRectF(x1, y1, sw, sh), er, er);
        else
            p.drawRect(QRectF(x1, y1, sw, sh));

    } else if (typ == "kreis") {
        double dx = x2 - x1, dy = y2 - y1;
        double r  = qSqrt(dx*dx + dy*dy);
        if (r < 0.5) return;
        p.setPen(pen);
        bool fu = el.value("fuell").toBool();
        if (fu) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString(), QColor(26,58,106));
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        p.drawEllipse(QPointF(x1, y1), r, r);

    } else if (typ == "text") {
        QString inhalt = el.value("textInhalt").toString();
        if (inhalt.isEmpty()) return;
        double fsMm = el.value("strichBreite", 3.5).toDouble();
        double fsDev = fsMm * 0.25 * pxPerMm;
        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fsDev)));
        font.setBold(true);
        p.setFont(font);
        p.setPen(pdfFarbe(el.value("strichFarbe").toString(), QColor(192,216,240)));
        p.setBrush(Qt::NoBrush);

        QString ausrichtung = el.value("textAusrichtung", "links").toString();
        Qt::Alignment qa = Qt::AlignLeft;
        if (ausrichtung == "mitte") qa = Qt::AlignHCenter;
        else if (ausrichtung == "rechts") qa = Qt::AlignRight;

        int normRot = el.value("rotation", 0).toInt();
        // Nur 0° und 90° (senkrecht) sind erlaubt
        p.save();
        p.translate(x1, y1);
        if (normRot == 90 || normRot == -270) p.rotate(-90);
        QStringList lines = inhalt.split('\n');
        double lineH = fsDev * 1.3;
        for (int i = 0; i < lines.size(); i++)
            p.drawText(QRectF(0, i * lineH, qMax(qAbs(sw), 200.0), fsDev * 1.5),
                       qa | Qt::AlignTop, lines[i]);
        p.restore();

    } else if (typ == "bild") {
        QVariant bildVar = el.value("bildDaten");
        if (!bildVar.isValid()) return;
        QString dataUrl = bildVar.toString();
        // data:image/xxx;base64,... → decode
        int commaPos = dataUrl.indexOf(',');
        if (commaPos < 0) return;
        QByteArray bytes = QByteArray::fromBase64(dataUrl.mid(commaPos + 1).toLatin1());
        QImage img;
        if (!img.loadFromData(bytes)) return;
        p.save();
        p.setOpacity(el.value("opazitaet", 1.0).toDouble());
        p.drawImage(QRectF(qMin(x1,x2), qMin(y1,y2), qAbs(sw), qAbs(sh)), img);
        p.restore();

    } else if (typ == "notiz") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        if (rw < 2 || rh < 2) return;
        QColor bgColor = pdfFarbe(el.value("fuellFarbe").toString(), QColor(26,26,0));
        bgColor.setAlphaF(el.value("fuellOpazitaet", 0.9).toDouble());
        p.setBrush(bgColor);
        p.setPen(Qt::NoPen);
        p.drawRect(QRectF(rx, ry, rw, rh));
        p.setBrush(Qt::NoBrush);
        QPen borderPen = pen;
        borderPen.setColor(pdfFarbe(el.value("strichFarbe").toString(), QColor(204,204,34)));
        borderPen.setWidthF(strichBr);
        p.setPen(borderPen);
        p.drawRect(QRectF(rx, ry, rw, rh));

        QString text = el.value("textInhalt").toString();
        if (text.isEmpty()) return;
        QVariantMap ed = el.value("extraDaten").toMap();
        double fsMm  = ed.value("schriftGroesse", 3.5).toDouble();
        double fsDev = fsMm * pxPerMm;
        QFont font;
        font.setFamily(QStringLiteral("sans-serif"));
        font.setPixelSize(qMax(1, qRound(fsDev)));
        p.setFont(font);
        p.setPen(pdfFarbe(el.value("strichFarbe").toString(), QColor(204,204,34)));
        double pad = qMax(4.0, fsDev * 0.35);
        p.drawText(QRectF(rx + pad, ry + pad, rw - 2*pad, rh - 2*pad),
                   Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap, text);

    } else if (typ == "kabellinie") {
        // Gestrichelte orange Linie
        QPen kPen;
        kPen.setColor(pdfFarbe(el.value("strichFarbe").toString(), QColor(224,112,0)));
        kPen.setWidthF(qMax(0.5, 2.5 * 0.25 * pxPerMm));
        kPen.setStyle(Qt::DashLine);
        kPen.setCapStyle(Qt::RoundCap);
        p.setPen(kPen);
        p.setBrush(Qt::NoBrush);
        p.drawLine(QLineF(x1, y1, x2, y2));
        // Endpunkt-Kreise
        QPen cPen = kPen;
        cPen.setStyle(Qt::SolidLine);
        p.setPen(Qt::NoPen);
        p.setBrush(kPen.color());
        double cr = 4.0 * 0.25 * pxPerMm;
        p.drawEllipse(QPointF(x1, y1), cr, cr);
        p.drawEllipse(QPointF(x2, y2), cr, cr);
        p.setBrush(Qt::NoBrush);
        // Kabelkopf-Label (nur Bezeichnung, kompakt)
        QVariantMap ed = el.value("extraDaten").toMap();
        QString bez = ed.value("bezeichnung").toString();
        if (!bez.isEmpty()) {
            double fsDev = 2.5 * pxPerMm;
            QFont font;
            font.setFamily(QStringLiteral("sans-serif"));
            font.setPixelSize(qMax(1, qRound(fsDev)));
            font.setBold(true);
            p.setFont(font);
            p.setPen(kPen.color());
            p.drawText(QRectF(x1 + cr + 2, y1 - fsDev, 200 * 0.25 * pxPerMm, fsDev * 1.4),
                       Qt::AlignLeft | Qt::AlignBottom, bez);
        }

    } else if (typ == "geraetekasten") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        double er = 4.0 * 0.25 * pxPerMm;
        bool fu = el.value("fuell").toBool();
        if (fu) {
            QColor fc = pdfFarbe(el.value("fuellFarbe").toString());
            fc.setAlphaF(el.value("fuellOpazitaet", 0.3).toDouble());
            p.setBrush(fc);
        } else {
            p.setBrush(Qt::NoBrush);
        }
        p.setPen(pen);
        p.drawRoundedRect(QRectF(rx, ry, rw, rh), er, er);
        p.setBrush(Qt::NoBrush);
        QVariantMap ed  = el.value("extraDaten").toMap();
        QString bmk     = ed.value("bmk").toString();
        QString descr   = ed.value("bezeichnung").toString();
        double schrift  = ed.value("schriftgroesse", 2.5).toDouble();
        double fsDev    = schrift * pxPerMm;
        double fsDev2   = fsDev * 0.85;
        double pad      = 5.0 * 0.25 * pxPerMm;
        double ty       = ry + pad;
        if (!bmk.isEmpty()) {
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev))); f.setBold(true);
            p.setFont(f); p.setPen(pen.color());
            p.drawText(QRectF(rx+pad, ty, rw-2*pad, fsDev*1.4), Qt::AlignLeft|Qt::AlignTop, bmk);
            ty += fsDev * 1.4;
        }
        if (!descr.isEmpty()) {
            QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev2)));
            p.setFont(f); p.setPen(pen.color());
            p.drawText(QRectF(rx+pad, ty, rw-2*pad, fsDev2*1.4), Qt::AlignLeft|Qt::AlignTop, descr);
        }

    } else if (typ == "strukturkasten") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        QPen skPen = pen;
        skPen.setStyle(Qt::DashLine);
        p.setPen(skPen);
        p.setBrush(Qt::NoBrush);
        p.drawRect(QRectF(rx, ry, rw, rh));
        QVariantMap ed  = el.value("extraDaten").toMap();
        double schrift  = ed.value("schriftgroesse", 2.5).toDouble();
        double fsDev    = schrift * pxPerMm;
        double off      = 4.0 * 0.25 * pxPerMm;
        QFont f; f.setFamily("sans-serif"); f.setPixelSize(qMax(1,qRound(fsDev))); f.setBold(true);
        p.setFont(f); p.setPen(pen.color());
        QString lbl;
        if (!ed.value("anlageUO").toString().isEmpty()) lbl += "==" + ed.value("anlageUO").toString() + " ";
        if (!ed.value("ortUO").toString().isEmpty())    lbl += "++" + ed.value("ortUO").toString() + " ";
        if (!ed.value("anlage").toString().isEmpty())   lbl += "="  + ed.value("anlage").toString() + " ";
        if (!ed.value("ort").toString().isEmpty())      lbl += "+"  + ed.value("ort").toString();
        if (!lbl.isEmpty())
            p.drawText(QRectF(rx, ry + off, rw - off, fsDev*1.4),
                       Qt::AlignRight | Qt::AlignTop, lbl.trimmed());
        QString bez = ed.value("bezeichnung").toString();
        if (!bez.isEmpty()) {
            QFont fb = f; fb.setBold(false); p.setFont(fb);
            p.drawText(QRectF(rx + off, ry + off, rw - 2*off, fsDev*1.4),
                       Qt::AlignLeft | Qt::AlignTop, bez);
        }

    } else if (typ == "makrokasten") {
        double rx = qMin(x1,x2), ry = qMin(y1,y2);
        double rw = qAbs(sw),    rh = qAbs(sh);
        QPen mkPen = pen;
        mkPen.setStyle(Qt::DotLine);
        mkPen.setColor(QColor(0xa0, 0x60, 0xc0));
        p.setPen(mkPen);
        p.setBrush(Qt::NoBrush);
        p.drawRect(QRectF(rx, ry, rw, rh));

    } else if (typ == "symbol") {
        double absSw = qAbs(sw), absSh = qAbs(sh);
        if (absSw < 0.5 || absSh < 0.5) return;
        double symX = qMin(x1, x2);
        double symY = qMin(y1, y2);
        pdfSymbolRendern(p,
                         el.value("symbolId").toString(),
                         symX, symY, absSw, absSh,
                         el.value("rotation").toInt(),
                         el.value("spiegelX").toBool(),
                         el.value("spiegelY").toBool(),
                         pen);
        pdfBeschriftungRendern(p, el, C, pxPerMm);

        // ── Aderdefinitions-Textblock ────────────────────────────────────────
        if (el.value("symbolId").toString() == QStringLiteral("aderdefinition")) {
            QVariantMap ed = el.value("extraDaten").toMap();
            QStringList zeilen;
            QString bez   = ed.value("bezeichnung").toString();
            if (!bez.isEmpty()) zeilen << bez;

            QString aderfarbe = ed.value("aderfarbe").toString();
            double  quer      = ed.value("querschnitt_mm2").toDouble();
            if (!aderfarbe.isEmpty() || quer > 0) {
                QString z = aderfarbe.isEmpty() ? QStringLiteral("–") : aderfarbe;
                if (quer > 0)
                    z += QStringLiteral("  ") +
                         QString::number(quer, 'f', quer == qFloor(quer) ? 0 : 1)
                             .replace(QLatin1Char('.'), QLatin1Char(','))
                         + QStringLiteral(" mm²");
                zeilen << z;
            }
            double laenge = ed.value("laenge_m").toDouble();
            if (laenge > 0)
                zeilen << (QStringLiteral("→ ")
                           + QString::number(laenge, 'f', 1)
                               .replace(QLatin1Char('.'), QLatin1Char(','))
                           + QStringLiteral(" m"));

            if (!zeilen.isEmpty()) {
                double fsDev  = 2.0 * pxPerMm;       // 2 mm Schriftgröße
                double lineH  = fsDev * 1.3;
                double gap    = 0.5 * pxPerMm;        // 0.5 mm Abstand zum Symbol
                int rot = ((el.value("rotation").toInt() % 360) + 360) % 360;
                bool senk = (rot == 90 || rot == 270);

                double cx  = (x1 + x2) / 2.0;
                double cy  = (y1 + y2) / 2.0;
                QColor textClr(0x1a, 0x40, 0x60);     // Dunkelblau – lesbar auf Weiß

                p.save();
                if (senk) {
                    // Senkrecht: Text links des Symbols, rechtsbündig, Zeilen oben→unten
                    double lx = qMin(x1, x2) - gap;
                    double ly = cy - zeilen.size() * lineH / 2.0;
                    double tw = 30.0 * pxPerMm;        // 30 mm Textbreite
                    for (int zi = 0; zi < zeilen.size(); zi++) {
                        QFont f; f.setFamily(QStringLiteral("sans-serif"));
                        f.setPixelSize(qMax(1, qRound(fsDev)));
                        f.setBold(zi == 0 && !bez.isEmpty());
                        p.setFont(f);
                        p.setPen(textClr);
                        p.drawText(QRectF(lx - tw, ly + zi * lineH, tw, lineH * 1.2),
                                   Qt::AlignRight | Qt::AlignTop, zeilen[zi]);
                    }
                } else {
                    // Waagerecht: Text über dem Symbol, zentriert, letzte Zeile am nächsten
                    double tw = 30.0 * pxPerMm;
                    double oy = qMin(y1, y2) - gap;
                    for (int zi = zeilen.size() - 1; zi >= 0; zi--) {
                        QFont f; f.setFamily(QStringLiteral("sans-serif"));
                        f.setPixelSize(qMax(1, qRound(fsDev)));
                        f.setBold(zi == 0 && !bez.isEmpty());
                        p.setFont(f);
                        p.setPen(textClr);
                        oy -= lineH;
                        p.drawText(QRectF(cx - tw / 2.0, oy, tw, lineH * 1.2),
                                   Qt::AlignHCenter | Qt::AlignTop, zeilen[zi]);
                    }
                }
                p.restore();
            }
        }
    }
}

// Verbindungsleitungen aus verbindung_segment rendern
static void pdfLeitungenRendern(QPainter &p, int seiteId, double C, double pxPerMm)
{
    // ── Alle Segmente laden ──────────────────────────────────────────────────
    struct Seg {
        double cx1, cy1, cx2, cy2;   // Canvas-Koordinaten (1 Einheit = 0.25 mm)
        int    verbId;
        QColor color;
        double lw;                    // Linienbreite in Device-Pixeln
    };
    QVector<Seg> segs;

    QSqlQuery q;
    q.prepare(R"(
        SELECT vs.punkte, vs.verbindung_id, v.signaltyp, v.farbe
        FROM verbindung_segment vs
        JOIN verbindung v ON vs.verbindung_id = v.id
        WHERE vs.seite_id = :sid
    )");
    q.bindValue(":sid", seiteId);
    if (!q.exec()) return;

    while (q.next()) {
        QJsonDocument doc = QJsonDocument::fromJson(q.value(0).toString().toUtf8());
        if (!doc.isArray() || doc.array().size() < 2) continue;
        QJsonArray arr = doc.array();

        QString signaltyp = q.value(2).toString();
        QString farbe     = q.value(3).toString();

        QColor clr;
        if      (signaltyp == "phase")    clr = QColor(0x40, 0x90, 0xff);
        else if (signaltyp == "pe")       clr = QColor(0x20, 0xb0, 0x20);
        else if (signaltyp == "n")        clr = QColor(0xa0, 0xa0, 0xff);
        else if (signaltyp == "steuer")   clr = QColor(0xff, 0xc0, 0x40);
        else if (signaltyp == "konflikt") clr = QColor(0xff, 0x30, 0x30);
        else                              clr = Qt::black;
        if (!farbe.isEmpty()) { QColor fc(farbe); if (fc.isValid()) clr = fc; }

        segs.append({ arr[0].toObject()["x"].toDouble(),
                      arr[0].toObject()["y"].toDouble(),
                      arr[1].toObject()["x"].toDouble(),
                      arr[1].toObject()["y"].toDouble(),
                      q.value(1).toInt(),
                      clr,
                      qMax(0.3, 1.5 * 0.25 * pxPerMm) });
    }

    // ── Kreuzungslücken berechnen ────────────────────────────────────────────
    // Konvention: H-Segment bekommt Lücke, V-Segment verläuft durch.
    struct HSeg { int idx; double x1, x2, y; };
    struct VSeg { int idx; double x,  y1, y2; };
    QVector<HSeg> hSegs;
    QVector<VSeg> vSegs;

    for (int i = 0; i < segs.size(); i++) {
        const Seg &s = segs[i];
        if      (qAbs(s.cy2 - s.cy1) < 0.5)
            hSegs.append({i, qMin(s.cx1,s.cx2), qMax(s.cx1,s.cx2), (s.cy1+s.cy2)/2.0});
        else if (qAbs(s.cx2 - s.cx1) < 0.5)
            vSegs.append({i, (s.cx1+s.cx2)/2.0, qMin(s.cy1,s.cy2), qMax(s.cy1,s.cy2)});
    }

    // crossings[segIdx] = sortierte X-Positionen (Canvas-Einheiten) der Kreuzungspunkte
    QHash<int, QVector<double>> crossings;
    for (const HSeg &h : hSegs) {
        for (const VSeg &v : vSegs) {
            if (segs[h.idx].verbId == segs[v.idx].verbId) continue; // selbes Netz
            if (v.x <= h.x1 || v.x >= h.x2) continue;              // V außerhalb H
            if (h.y <= v.y1 || h.y >= v.y2) continue;              // H außerhalb V
            crossings[h.idx].append(v.x);
        }
    }
    for (auto &xList : crossings)
        std::sort(xList.begin(), xList.end());

    // ── Segmente zeichnen ────────────────────────────────────────────────────
    // Lückengröße: 4 Canvas-Einheiten = 1 mm je Seite → 2 mm Gesamtlücke (druckfest)
    const double luecke = 4.0;

    p.setBrush(Qt::NoBrush);
    for (int i = 0; i < segs.size(); i++) {
        const Seg &s = segs[i];
        QPen pen(s.color, s.lw, Qt::SolidLine, Qt::FlatCap);

        auto it = crossings.constFind(i);
        if (it == crossings.constEnd() || it->isEmpty()) {
            // Kein Kreuzungspunkt: normal zeichnen
            p.setPen(pen);
            p.drawLine(QLineF(s.cx1*C, s.cy1*C, s.cx2*C, s.cy2*C));
        } else {
            // H-Segment mit Lücken: stückweise zeichnen
            double hx1 = qMin(s.cx1, s.cx2);
            double hx2 = qMax(s.cx1, s.cx2);
            double hy  = (s.cy1 + s.cy2) / 2.0;
            pen.setCapStyle(Qt::FlatCap);
            p.setPen(pen);
            double pos = hx1;
            for (double cx : *it) {
                double ls = cx - luecke;
                double le = cx + luecke;
                if (ls > pos)
                    p.drawLine(QLineF(pos*C, hy*C, ls*C, hy*C));
                pos = le;
            }
            if (pos < hx2)
                p.drawLine(QLineF(pos*C, hy*C, hx2*C, hy*C));
        }
    }
}

// Normblatt-Rahmen und Schriftfeld rendern (Koordinaten in Device-Pixeln via pxPerMm)
static void pdfNormblattRendern(QPainter &p, const QVariantMap &nb, double pxPerMm)
{
    double bMm = nb.value("breiteMm", 297.0).toDouble();
    double hMm = nb.value("hoeheMm",  210.0).toDouble();
    double mL  = nb.value("randLinksMm",  20.0).toDouble();
    double mR  = nb.value("randRechtsMm", 10.0).toDouble();
    double mO  = nb.value("randObenMm",   10.0).toDouble();
    double mU  = nb.value("randUntenMm",  10.0).toDouble();

    auto mm = [&](double v){ return v * pxPerMm; };

    // Seitenhintergrund
    QString bg = nb.value("hintergrundFarbe").toString().trimmed();
    if (!bg.isEmpty()) {
        QColor bgC(bg);
        if (bgC.isValid()) {
            p.setBrush(bgC);
            p.setPen(Qt::NoPen);
            p.drawRect(QRectF(0, 0, mm(bMm), mm(hMm)));
        }
    }

    double iX0 = mm(mL),        iY0 = mm(mO);
    double iX1 = mm(bMm - mR),  iY1 = mm(hMm - mU);
    double iW  = iX1 - iX0,     iH  = iY1 - iY0;

    // Seitenbegrenzung (dünn gestrichelt)
    QPen outerPen(QColor(0x2a, 0x4a, 0x7a), mm(0.25), Qt::DashLine);
    p.setPen(outerPen);
    p.setBrush(Qt::NoBrush);
    p.drawRect(QRectF(0, 0, mm(bMm), mm(hMm)));

    // Zeichnungsrahmen (dick)
    QPen framePen(QColor(0x4a, 0x7a, 0xb0), mm(0.7));
    p.setPen(framePen);
    p.drawRect(QRectF(iX0, iY0, iW, iH));

    // Benutzerdefinierte Felder (Phase 2)
    QVariantList felder = nb.value("felder").toList();
    if (!felder.isEmpty()) {
        for (const QVariant &fv : felder) {
            QVariantMap f = fv.toMap();
            double fx = mm(f.value("xMm").toDouble());
            double fy = mm(f.value("yMm").toDouble());
            double fw = mm(f.value("breiteMm").toDouble());
            double fh = mm(f.value("hoeheMm").toDouble());
            // Zelle: Label oben, Wert mittig
            QString feldtyp = f.value("feldtyp").toString();
            QString inhalt;
            if (feldtyp == "fest") {
                inhalt = f.value("inhalt").toString();
            } else if (feldtyp == "logo") {
                // Logo überspringen in v1
                continue;
            } else {
                QString qs = f.value("quelleSpalte").toString();
                QMap<QString,QString> qmap;
                qmap["name"]          = nb.value("projektName").toString();
                qmap["projektnummer"] = nb.value("projektnummer").toString();
                qmap["auftraggeber"]  = nb.value("auftraggeber").toString();
                qmap["auftragnehmer"] = nb.value("auftragnehmer").toString();
                qmap["bearbeiter"]    = nb.value("bearbeiter").toString();
                qmap["norm"]          = nb.value("norm").toString();
                qmap["blattnummer"]   = nb.value("blattnummer").toString();
                qmap["bezeichnung"]   = nb.value("bezeichnung").toString();
                inhalt = qmap.value(qs);
            }
            if (f.value("rahmen").toBool()) {
                p.setPen(QPen(QColor(0x2a, 0x50, 0x80), mm(0.25)));
                p.setBrush(Qt::NoBrush);
                p.drawRect(QRectF(fx, fy, fw, fh));
            }
            // Label
            double lFs = qMax(mm(1.5), qMin(fh * 0.22, mm(2.8)));
            QFont lf; lf.setFamily("sans-serif"); lf.setPixelSize(qMax(1,qRound(lFs)));
            p.setFont(lf); p.setPen(QColor(0x5a,0x7a,0xa0));
            p.drawText(QRectF(fx+mm(1), fy+fh*0.08, fw-mm(2), lFs*1.4), Qt::AlignLeft|Qt::AlignTop,
                       f.value("label").toString());
            // Wert
            double vFs = qMax(mm(2.5), qMin(fh * 0.38, mm(4.5)));
            QFont vf; vf.setFamily("sans-serif"); vf.setPixelSize(qMax(1,qRound(vFs))); vf.setBold(true);
            p.setFont(vf); p.setPen(QColor(0xc8,0xdd,0xf0));
            p.drawText(QRectF(fx+mm(1.2), fy+fh*0.42, fw-mm(2), fh*0.55), Qt::AlignLeft|Qt::AlignTop, inhalt);
        }
        return;  // Benutzerdefinierte Felder gesetzt, fertig
    }

    // Standard-Schriftfeld
    QString vorlage = nb.value("titelblattVorlage", "din6771").toString();
    if (vorlage == "rahmen") return;  // nur Rahmen, kein Schriftfeld

    // Hilfsfunktion: Datum formatieren
    auto datumText = [&]() -> QString {
        QString raw = nb.value("erstelltAm").toString();
        if (raw.length() >= 10) {
            QStringList parts = raw.left(10).split('-');
            if (parts.size() == 3) return parts[2] + "." + parts[1] + "." + parts[0];
        }
        return raw;
    };
    // Vollkennzeichen
    auto vollkz = [&]() -> QString {
        QString a = nb.value("anlageKuerzel").toString();
        QString o = nb.value("ortKuerzel").toString();
        QString bn = nb.value("blattnummer").toString();
        QString kz;
        if (!a.isEmpty()) kz += "=" + a;
        if (!o.isEmpty()) kz += "+" + o;
        if (!kz.isEmpty()) kz += "/";
        return kz + bn;
    };
    // Seitenformat
    auto formatText = [&]() -> QString {
        double b = bMm, h = hMm;
        double mx = qMax(b,h), mn = qMin(b,h);
        QString fmt;
        if      (qAbs(mx-420)<5 && qAbs(mn-297)<5) fmt="A3";
        else if (qAbs(mx-297)<5 && qAbs(mn-210)<5) fmt="A4";
        else if (qAbs(mx-594)<5 && qAbs(mn-420)<5) fmt="A2";
        else fmt=QString::number(qRound(b))+"x"+QString::number(qRound(h));
        return fmt + (b > h ? " QF" : " HF");
    };

    // Hilfsfunktion: Zelle (Label oben, Wert mittig)
    auto zelle = [&](const QString &label, const QString &wert,
                     double fx, double fy, double fw, double fh) {
        p.setBrush(Qt::NoBrush);
        p.setPen(Qt::NoPen);
        double lFs = qMax(mm(1.5), qMin(fh * 0.22, mm(2.8)));
        QFont lf; lf.setFamily("sans-serif"); lf.setPixelSize(qMax(1,qRound(lFs)));
        p.setFont(lf); p.setPen(QColor(0x5a,0x7a,0xa0));
        p.drawText(QRectF(fx+mm(1), fy+fh*0.08, fw-mm(2), lFs*1.4), Qt::AlignLeft|Qt::AlignTop, label);
        double vFs = qMax(mm(2.5), qMin(fh * 0.38, mm(4.5)));
        QFont vf; vf.setFamily("sans-serif"); vf.setPixelSize(qMax(1,qRound(vFs))); vf.setBold(true);
        p.setFont(vf); p.setPen(QColor(0xc8,0xdd,0xf0));
        p.drawText(QRectF(fx+mm(1.2), fy+fh*0.42, fw-mm(2), fh*0.55), Qt::AlignLeft|Qt::AlignTop, wert);
    };

    QPen cellPen(QColor(0x2a, 0x50, 0x80), mm(0.25));

    if (vorlage == "kompakt") {
        double rowH = mm(8);
        double sfY0 = iY1 - 2 * rowH;
        double sfH  = 2 * rowH;
        double cX[4] = { iX0, iX0+iW*0.45, iX0+iW*0.72, iX1 };
        double rY[2] = { sfY0, sfY0+rowH };

        // Hintergrund
        p.setBrush(QColor(5,15,35,180)); p.setPen(Qt::NoPen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
        p.setBrush(Qt::NoBrush);

        p.setPen(cellPen);
        for (int c = 1; c <= 2; c++)
            p.drawLine(QLineF(cX[c], sfY0, cX[c], iY1));
        for (int r = 0; r < 2; r++)
            p.drawLine(QLineF(iX0, rY[r], iX1, rY[r]));

        zelle("PROJEKT",      nb.value("projektName").toString(),   cX[0],rY[0],cX[1]-cX[0],rowH);
        zelle("BLATT",        nb.value("blattnummer").toString(),   cX[1],rY[0],cX[2]-cX[1],rowH);
        zelle("DATUM",        datumText(),                          cX[2],rY[0],cX[3]-cX[2],rowH);
        zelle("BEZEICHNUNG",  nb.value("bezeichnung").toString(),   cX[0],rY[1],cX[1]-cX[0],rowH);
        zelle("SEITENKENNZ.", vollkz(),                             cX[1],rY[1],cX[2]-cX[1],rowH);
        zelle("BEARBEITER",   nb.value("bearbeiter").toString(),    cX[2],rY[1],cX[3]-cX[2],rowH);

        p.setPen(framePen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));

    } else {
        // DIN 6771: 3 Zeilen × 13mm
        double rowH = mm(13);
        double sfY0 = iY1 - 3 * rowH;
        double sfH  = 3 * rowH;
        double cX[5] = { iX0, iX0+iW*0.21, iX0+iW*0.66, iX0+iW*0.86, iX1 };
        double rY[3] = { sfY0, sfY0+rowH, sfY0+2*rowH };

        // Hintergrund
        p.setBrush(QColor(5,15,35,204)); p.setPen(Qt::NoPen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
        p.setBrush(Qt::NoBrush);

        p.setPen(cellPen);
        for (int c = 1; c <= 3; c++)
            p.drawLine(QLineF(cX[c], sfY0, cX[c], iY1));
        for (int r = 0; r < 3; r++)
            p.drawLine(QLineF(iX0, rY[r], iX1, rY[r]));

        zelle("AUFTRAGGEBER", nb.value("auftraggeber").toString(),  cX[0],rY[0],cX[1]-cX[0],rowH);
        zelle("PROJEKT",      nb.value("projektName").toString(),   cX[1],rY[0],cX[2]-cX[1],rowH);
        zelle("PROJEKTNR.",   nb.value("projektnummer").toString(), cX[2],rY[0],cX[3]-cX[2],rowH);
        zelle("BLATT",        nb.value("blattnummer").toString(),   cX[3],rY[0],cX[4]-cX[3],rowH);

        zelle("AUFTRAGNEHMER",nb.value("auftragnehmer").toString(), cX[0],rY[1],cX[1]-cX[0],rowH);
        zelle("BEZEICHNUNG",  nb.value("bezeichnung").toString(),   cX[1],rY[1],cX[2]-cX[1],rowH);
        zelle("FORMAT",       formatText(),                         cX[2],rY[1],cX[3]-cX[2],rowH);
        zelle("DATUM",        datumText(),                          cX[3],rY[1],cX[4]-cX[3],rowH);

        zelle("BEARBEITER",   nb.value("bearbeiter").toString(),    cX[0],rY[2],cX[1]-cX[0],rowH);
        zelle("SEITENKENNZ.", vollkz(),                             cX[1],rY[2],cX[2]-cX[1],rowH);
        zelle("NORM",         nb.value("norm", "IEC").toString(),   cX[2],rY[2],cX[3]-cX[2],rowH);
        zelle("INDEX",        QStringLiteral("–"),             cX[3],rY[2],cX[4]-cX[3],rowH);

        p.setPen(framePen);
        p.drawRect(QRectF(iX0, sfY0, iW, sfH));
    }
}

// ── Öffentliche Methode ──────────────────────────────────────

bool Database::canvasPdfExportieren(int projektId, const QString &pfad, bool mitNormblatt)
{
    // Alle Seiten des Projekts in Anzeigereihenfolge laden
    QSqlQuery q;
    q.prepare(R"(
        SELECT s.id
        FROM seite s
        JOIN ort     o ON s.ort_id      = o.id
        JOIN anlage  a ON o.anlage_id   = a.id
        WHERE a.projekt_id = :pid
        ORDER BY a.kuerzel, o.kuerzel, s.sortierung, s.blattnummer
    )");
    q.bindValue(":pid", projektId);
    if (!q.exec() || !q.next()) {
        qWarning() << "canvasPdfExportieren: keine Seiten für Projekt" << projektId;
        return false;
    }
    QList<int> seiteIds;
    seiteIds << q.value(0).toInt();
    while (q.next()) seiteIds << q.value(0).toInt();

    // Ausgabepfad normalisieren
    QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    // Erste Seite für initiale Papiergröße
    QVariantMap nb0 = normblattDatenLaden(seiteIds.first());
    double b0 = nb0.value("breiteMm", 297.0).toDouble();
    double h0 = nb0.value("hoeheMm",  210.0).toDouble();

    QPdfWriter writer(localPath);
    writer.setCreator(QStringLiteral("Stroemling Design"));
    writer.setTitle(nb0.value("projektName").toString());
    writer.setPageMargins(QMarginsF(0, 0, 0, 0));
    writer.setPageLayout(QPageLayout(
        QPageSize(QSizeF(b0, h0), QPageSize::Millimeter),
        QPageLayout::Portrait, QMarginsF(0,0,0,0)));

    QPainter painter(&writer);
    if (!painter.isActive()) {
        qWarning() << "canvasPdfExportieren: QPainter konnte nicht gestartet werden";
        return false;
    }

    // DPI-basierte Skalierung: alle Zeichenaufrufe in Device-Pixeln
    double pxPerMm = (double)writer.logicalDpiX() / 25.4;
    double C       = pxPerMm / 4.0;   // Canvas-Pixel → Device-Pixel

    for (int i = 0; i < seiteIds.size(); ++i) {
        int seiteId = seiteIds[i];
        QVariantMap nb = normblattDatenLaden(seiteId);
        double bMm = nb.value("breiteMm", 297.0).toDouble();
        double hMm = nb.value("hoeheMm",  210.0).toDouble();

        if (i > 0) {
            writer.setPageLayout(QPageLayout(
                QPageSize(QSizeF(bMm, hMm), QPageSize::Millimeter),
                QPageLayout::Portrait, QMarginsF(0,0,0,0)));
            writer.newPage();
        }

        painter.save();

        // Weißer Seitenhintergrund
        painter.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);

        // Canvas-Elemente rendern
        QVariantList elemente = grafikLaden(seiteId);
        for (const QVariant &ev : elemente)
            pdfElementRendern(painter, ev.toMap(), C, pxPerMm);

        // Verbindungsleitungen aus DB
        pdfLeitungenRendern(painter, seiteId, C, pxPerMm);

        // Normblatt-Rahmen + Schriftfeld
        if (mitNormblatt && nb.value("normblattAnzeigen").toBool())
            pdfNormblattRendern(painter, nb, pxPerMm);

        painter.restore();
    }

    painter.end();
    qInfo() << "canvasPdfExportieren: PDF gespeichert:" << localPath
            << "(" << seiteIds.size() << "Seiten)";
    return QFile::exists(localPath);
}

bool Database::canvasSeiteExportieren(int seiteId, const QString &pfad, bool mitNormblatt, bool vollCanvas)
{
    QString localPath = QUrl(pfad).isLocalFile() ? QUrl(pfad).toLocalFile() : pfad;

    QVariantMap nb = normblattDatenLaden(seiteId);
    double bMm = nb.value("breiteMm", 297.0).toDouble();
    double hMm = nb.value("hoeheMm",  210.0).toDouble();

    // ── Vollständiger Canvas-Bereich: Seitengröße aus Bounding-Box berechnen ─
    double txCu = 0.0, tyCu = 0.0; // Verschiebung in Canvas-Einheiten
    if (vollCanvas) {
        const double randCu = 20.0; // 5 mm Rand = 20 Canvas-Einheiten

        // Bounding-Box aller grafik_element
        double bxMin =  1e9, byMin =  1e9;
        double bxMax = -1e9, byMax = -1e9;

        QSqlQuery bq;
        bq.prepare(R"(
            SELECT CASE WHEN x1<x2 THEN x1 ELSE x2 END,
                   CASE WHEN y1<y2 THEN y1 ELSE y2 END,
                   CASE WHEN x1>x2 THEN x1 ELSE x2 END,
                   CASE WHEN y1>y2 THEN y1 ELSE y2 END
            FROM grafik_element WHERE seite_id = :sid
        )");
        bq.bindValue(":sid", seiteId);
        if (bq.exec()) {
            while (bq.next()) {
                bxMin = qMin(bxMin, bq.value(0).toDouble());
                byMin = qMin(byMin, bq.value(1).toDouble());
                bxMax = qMax(bxMax, bq.value(2).toDouble());
                byMax = qMax(byMax, bq.value(3).toDouble());
            }
        }

        // Bounding-Box der Verbindungssegmente
        QSqlQuery sq;
        sq.prepare("SELECT punkte FROM verbindung_segment WHERE seite_id = :sid");
        sq.bindValue(":sid", seiteId);
        if (sq.exec()) {
            while (sq.next()) {
                QJsonDocument doc = QJsonDocument::fromJson(sq.value(0).toString().toUtf8());
                if (!doc.isArray()) continue;
                for (const QJsonValue &v : doc.array()) {
                    double px = v.toObject()["x"].toDouble();
                    double py = v.toObject()["y"].toDouble();
                    bxMin = qMin(bxMin, px); byMin = qMin(byMin, py);
                    bxMax = qMax(bxMax, px); byMax = qMax(byMax, py);
                }
            }
        }

        if (bxMin < bxMax && byMin < byMax) {
            txCu = bxMin - randCu;
            tyCu = byMin - randCu;
            bMm  = (bxMax - bxMin + 2.0 * randCu) * 0.25;
            hMm  = (byMax - byMin + 2.0 * randCu) * 0.25;
        }
    }

    QPdfWriter writer(localPath);
    writer.setCreator(QStringLiteral("Stroemling Design"));
    writer.setTitle(nb.value("projektName").toString());
    writer.setPageMargins(QMarginsF(0, 0, 0, 0));
    writer.setPageLayout(QPageLayout(
        QPageSize(QSizeF(bMm, hMm), QPageSize::Millimeter),
        QPageLayout::Portrait, QMarginsF(0,0,0,0)));

    QPainter painter(&writer);
    if (!painter.isActive()) {
        qWarning() << "canvasSeiteExportieren: QPainter konnte nicht gestartet werden";
        return false;
    }

    double pxPerMm = (double)writer.logicalDpiX() / 25.4;
    double C       = pxPerMm / 4.0;

    painter.fillRect(QRectF(0, 0, bMm * pxPerMm, hMm * pxPerMm), Qt::white);

    // Vollständiger Canvas-Modus: alle Zeichenaufrufe um Bounding-Box-Ursprung verschieben
    if (vollCanvas)
        painter.translate(-txCu * C, -tyCu * C);

    QVariantList elemente = grafikLaden(seiteId);
    for (const QVariant &ev : elemente)
        pdfElementRendern(painter, ev.toMap(), C, pxPerMm);

    pdfLeitungenRendern(painter, seiteId, C, pxPerMm);

    if (mitNormblatt && nb.value("normblattAnzeigen").toBool())
        pdfNormblattRendern(painter, nb, pxPerMm);

    painter.end();
    qInfo() << "canvasSeiteExportieren: PDF gespeichert:" << localPath
            << (vollCanvas ? "(vollCanvas)" : "");
    return QFile::exists(localPath);
}

// ── Komplettarchiv-Export ────────────────────────────────────────────────────
// Struktur im Zielordner:
//   manifest.json       — Metadaten + Projektliste
//   wiki_export.json    — vollständige Wiki-Sicherung (JSON)
//   projekte/           — Kopien aller bekannten .stroemling-Projektdateien
// ────────────────────────────────────────────────────────────────────────────
QVariantMap Database::komplettarchivExportieren(const QString &zielOrdner)
{
    QString ziel = QUrl(zielOrdner).isLocalFile() ? QUrl(zielOrdner).toLocalFile() : zielOrdner;
    if (!QDir().mkpath(ziel))
        return {{"erfolg", false}, {"meldung", QStringLiteral("Zielordner konnte nicht erstellt werden")}};

    // 1. Wiki als JSON exportieren
    QString wikiJsonPfad = ziel + QStringLiteral("/wiki_export.json");
    bool wikiOk = wikiExportJson(wikiJsonPfad);

    // 2. Bekannte Projektdateien kopieren
    QString projOrdner = ziel + QStringLiteral("/projekte");
    if (!QDir().mkpath(projOrdner))
        return {{"erfolg", false}, {"meldung", QStringLiteral("Projektordner konnte nicht erstellt werden")}};

    int projekteAnzahl = 0;
    QJsonArray projekteListe;

    QSqlQuery q(m_launcherDb);
    if (q.exec("SELECT pfad, name FROM zuletzt_geoeffnet ORDER BY geoeffnet_am DESC")) {
        while (q.next()) {
            QString pfad = q.value(0).toString();
            QString name = q.value(1).toString();
            if (!QFile::exists(pfad)) continue;

            QString dateiName = QFileInfo(pfad).fileName();
            QString zielPfad  = projOrdner + "/" + dateiName;
            // Namenskonflikt auflösen
            if (QFile::exists(zielPfad)) {
                QString stem = QFileInfo(dateiName).baseName();
                dateiName = stem + "_" + QString::number(projekteAnzahl + 1) + ".stroemling";
                zielPfad  = projOrdner + "/" + dateiName;
            }
            if (QFile::copy(pfad, zielPfad)) {
                projekteAnzahl++;
                projekteListe.append(QJsonObject{
                    {QStringLiteral("name"),         name},
                    {QStringLiteral("datei"),        dateiName},
                    {QStringLiteral("originalPfad"), pfad}
                });
            } else {
                qWarning() << "komplettarchivExportieren: Kopie fehlgeschlagen:" << pfad;
            }
        }
    }

    // 3. Schema-Version ermitteln
    int schemaVer = 0;
    {
        QSqlQuery sv;
        if (sv.exec("SELECT COALESCE(MAX(version),0) FROM schema_migration") && sv.next())
            schemaVer = sv.value(0).toInt();
    }

    // 4. manifest.json schreiben
    QJsonObject manifest{
        {QStringLiteral("stroemling_backup_version"), 1},
        {QStringLiteral("exportiert_am"),  QDateTime::currentDateTime().toString(Qt::ISODate)},
        {QStringLiteral("schema_version"), schemaVer},
        {QStringLiteral("wiki_exportiert"), wikiOk},
        {QStringLiteral("projekte"),        projekteListe}
    };
    QFile mf(ziel + QStringLiteral("/manifest.json"));
    if (mf.open(QIODevice::WriteOnly | QIODevice::Text))
        mf.write(QJsonDocument(manifest).toJson(QJsonDocument::Indented));

    qInfo() << "komplettarchivExportieren:" << projekteAnzahl << "Projekt(e),"
            << "Wiki:" << wikiOk << "→" << ziel;
    return {
        {QStringLiteral("erfolg"),         true},
        {QStringLiteral("projekteAnzahl"), projekteAnzahl},
        {QStringLiteral("wikiOk"),         wikiOk},
        {QStringLiteral("meldung"),        QString("%1 Projekt(e) gesichert%2")
                                               .arg(projekteAnzahl)
                                               .arg(wikiOk ? ", Wiki exportiert" : "")}
    };
}

// ── Komplettarchiv-Import ────────────────────────────────────────────────────
// Liest manifest.json aus quellOrdner, importiert Wiki (merge) und
// registriert alle Projekte in zuletzt_geoeffnet.
// ────────────────────────────────────────────────────────────────────────────
QVariantMap Database::komplettarchivImportieren(const QString &quellOrdner)
{
    QString quelle = QUrl(quellOrdner).isLocalFile() ? QUrl(quellOrdner).toLocalFile() : quellOrdner;

    // manifest.json lesen
    QFile mf(quelle + QStringLiteral("/manifest.json"));
    if (!mf.open(QIODevice::ReadOnly))
        return {{"erfolg", false}, {"meldung", QStringLiteral("manifest.json nicht gefunden – kein gültiges Archiv")}};

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(mf.readAll(), &err);
    if (doc.isNull() || !doc.isObject())
        return {{"erfolg", false}, {"meldung", QStringLiteral("Ungültiges Archiv: ") + err.errorString()}};

    QJsonObject root = doc.object();
    if (root.value(QStringLiteral("stroemling_backup_version")).toInt() != 1)
        return {{"erfolg", false}, {"meldung", QStringLiteral("Unbekannte Archiv-Version")}};

    // 1. Wiki importieren (merge – bestehende Nutzerartikel bleiben erhalten)
    bool wikiOk = false;
    QString wikiJsonPfad = quelle + QStringLiteral("/wiki_export.json");
    if (QFile::exists(wikiJsonPfad))
        wikiOk = wikiImportJson(wikiJsonPfad, true);

    // 2. Projekte in zuletzt_geoeffnet eintragen
    int projekteAnzahl = 0;
    QJsonArray projekteListe = root.value(QStringLiteral("projekte")).toArray();
    QString projOrdner = quelle + QStringLiteral("/projekte");

    for (const QJsonValue &v : projekteListe) {
        QJsonObject pj     = v.toObject();
        QString dateiName  = pj.value(QStringLiteral("datei")).toString();
        QString name       = pj.value(QStringLiteral("name")).toString();
        QString pfad       = projOrdner + "/" + dateiName;

        if (!QFile::exists(pfad)) {
            qWarning() << "komplettarchivImportieren: Datei nicht gefunden:" << pfad;
            continue;
        }

        if (!m_launcherDb.isOpen()) continue;
        QSqlQuery q(m_launcherDb);
        q.prepare(R"(
            INSERT INTO zuletzt_geoeffnet (pfad, name, geoeffnet_am)
            VALUES (:p, :n, datetime('now'))
            ON CONFLICT(pfad) DO UPDATE SET name=excluded.name, geoeffnet_am=excluded.geoeffnet_am
        )");
        q.bindValue(":p", pfad);
        q.bindValue(":n", name);
        if (q.exec()) projekteAnzahl++;
    }

    qInfo() << "komplettarchivImportieren:" << projekteAnzahl << "Projekt(e),"
            << "Wiki:" << wikiOk;
    return {
        {QStringLiteral("erfolg"),         true},
        {QStringLiteral("projekteAnzahl"), projekteAnzahl},
        {QStringLiteral("wikiOk"),         wikiOk},
        {QStringLiteral("meldung"),        QString("%1 Projekt(e) registriert%2")
                                               .arg(projekteAnzahl)
                                               .arg(wikiOk ? ", Wiki importiert (merge)" : "")}
    };
}

// ============================================================
// CSV-Import Bauteilkatalog (M7)
// ============================================================

static QList<QStringList> parseCsvRows(const QString &pfad, QChar &trenn)
{
    QFile f(pfad);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    f.close();

    QStringList lines = content.split('\n');
    if (lines.isEmpty()) return {};

    // Trennzeichen aus erster Zeile ermitteln
    QString first = lines.first();
    trenn = (first.count(';') >= first.count(',')) ? ';' : ',';

    QList<QStringList> result;
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;

        QStringList row;
        bool inQuotes = false;
        QString field;
        for (int i = 0; i < line.length(); i++) {
            QChar c = line[i];
            if (c == '"') {
                if (inQuotes && i + 1 < line.length() && line[i + 1] == '"') {
                    field += '"'; ++i;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c == trenn && !inQuotes) {
                row.append(field.trimmed());
                field.clear();
            } else {
                field += c;
            }
        }
        row.append(field.trimmed());
        result.append(row);
    }
    return result;
}

QStringList Database::csvKopfzeile(const QString &pfad)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    return rows.isEmpty() ? QStringList() : rows.first();
}

QVariantList Database::csvVorschau(const QString &pfad, int maxZeilen)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    QVariantList result;
    for (int i = 1; i < rows.size() && result.size() < maxZeilen; i++) {
        QVariantList row;
        for (const QString &s : rows[i]) row.append(s);
        result.append(QVariant(row));
    }
    return result;
}

int Database::csvBauteileImportieren(const QString &pfad, int kategorieId,
                                      const QVariantMap &mapping)
{
    QChar trenn;
    auto rows = parseCsvRows(pfad, trenn);
    if (rows.size() < 2) return 0;

    static const QStringList numericFelder = {
        "preis_eur", "spannung_v", "strom_a", "leistung_w"
    };
    static const QStringList erlaubteFelder = {
        "bezeichnung", "hersteller", "artikelnummer", "artikelnummer_2",
        "lieferant", "bestellnummer", "preis_eur", "spannung_v",
        "strom_a", "leistung_w", "schutzart", "norm", "bmk_vorlage", "bemerkung"
    };

    QStringList dbFelder;
    QStringList bindVars;
    QList<int>  colIndizes;
    for (auto it = mapping.begin(); it != mapping.end(); ++it) {
        const QString &feld = it.key();
        int colIdx = it.value().toInt();
        if (colIdx < 0 || !erlaubteFelder.contains(feld)) continue;
        dbFelder   << feld;
        bindVars   << (":" + feld);
        colIndizes << colIdx;
    }
    if (!dbFelder.contains("bezeichnung")) return -1;

    QString sql = QString("INSERT INTO bauteil (kategorie_id, %1) VALUES (:katId, %2)")
                      .arg(dbFelder.join(", "), bindVars.join(", "));

    QSqlDatabase::database().transaction();
    QSqlQuery q;
    int count = 0;
    for (int row = 1; row < rows.size(); row++) {
        const QStringList &cols = rows[row];
        q.prepare(sql);
        q.bindValue(":katId", kategorieId > 0 ? QVariant(kategorieId) : QVariant());
        for (int f = 0; f < dbFelder.size(); f++) {
            int     ci  = colIndizes[f];
            QString val = (ci < cols.size()) ? cols[ci] : QString();
            if (numericFelder.contains(dbFelder[f])) {
                bool ok;
                double d = QString(val).replace(',', '.').toDouble(&ok);
                q.bindValue(":" + dbFelder[f], (ok && !val.isEmpty()) ? QVariant(d) : QVariant());
            } else {
                q.bindValue(":" + dbFelder[f], val.isEmpty() ? QVariant() : QVariant(val));
            }
        }
        if (q.exec()) ++count;
        else qWarning() << "csvBauteileImportieren Zeile" << row << ":" << q.lastError().text();
    }
    QSqlDatabase::database().commit();
    return count;
}

QVariantList Database::drcDoppelteBmk(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q;
    q.prepare(
        "SELECT bv.bmk_vollstaendig, COUNT(*) AS anzahl, GROUP_CONCAT(b.id) AS ids "
        "FROM betriebsmittel b "
        "JOIN betriebsmittel_bmk bv ON b.id = bv.id "
        "WHERE b.projekt_id = :pid "
        "GROUP BY bv.bmk_vollstaendig "
        "HAVING COUNT(*) > 1 "
        "ORDER BY bv.bmk_vollstaendig"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "drcDoppelteBmk:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantList ids;
        for (const QString &s : q.value(2).toString().split(','))
            ids << s.trimmed().toInt();
        QVariantMap fund;
        fund["bmk"]    = q.value(0).toString();
        fund["anzahl"] = q.value(1).toInt();
        fund["ids"]    = ids;
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcSymboleOhneBmk(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q;
    q.prepare(
        "SELECT ge.id, ge.symbol_id, ge.seite_id, s.bezeichnung "
        "FROM grafik_element ge "
        "JOIN seite s ON ge.seite_id = s.id "
        "LEFT JOIN betriebsmittel b ON ge.betriebsmittel_id = b.id "
        "WHERE s.projekt_id = :pid "
        "  AND ge.typ = 'symbol' "
        "  AND ge.symbol_id NOT IN ("
        "    'winkel','treffpunkt','treffpunkt_l','geraeteanschluss',"
        "    'unterbrechung','querverweis','aderdefinition','klemme_anschluss') "
        "  AND (ge.betriebsmittel_id IS NULL "
        "       OR TRIM(COALESCE(b.betriebsmittel_kz,'')) = '') "
        "ORDER BY s.blattnummer, ge.id"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "drcSymboleOhneBmk:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["elementId"] = q.value(0).toInt();
        fund["symbolId"]  = q.value(1).toString();
        fund["seiteId"]   = q.value(2).toInt();
        fund["seiteName"] = q.value(3).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcSeitenOhneBezeichnung(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q;
    q.prepare(
        "SELECT id, blattnummer FROM seite "
        "WHERE projekt_id = :pid "
        "  AND TRIM(COALESCE(bezeichnung,'')) = '' "
        "ORDER BY blattnummer"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "drcSeitenOhneBezeichnung:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["seiteId"]     = q.value(0).toInt();
        fund["blattnummer"] = q.value(1).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcKabeladernOhneAnschluss(int projektId)
{
    QVariantList ergebnis;
    QSqlQuery q;
    q.prepare(
        "SELECT ka.id, ka.ader_nr, ka.bezeichnung, k.bezeichnung, "
        "  CASE "
        "    WHEN TRIM(COALESCE(ka.von_gerat_pin,''))  = '' "
        "     AND TRIM(COALESCE(ka.nach_gerat_pin,'')) = '' THEN 'Von + Nach fehlen' "
        "    WHEN TRIM(COALESCE(ka.von_gerat_pin,''))  = '' THEN 'Von fehlt' "
        "    ELSE 'Nach fehlt' "
        "  END "
        "FROM kabel_ader ka "
        "JOIN kabel k ON ka.kabel_id = k.id "
        "WHERE k.projekt_id = :pid "
        "  AND (TRIM(COALESCE(ka.von_gerat_pin,''))  = '' "
        "    OR TRIM(COALESCE(ka.nach_gerat_pin,'')) = '') "
        "ORDER BY k.bezeichnung, ka.ader_nr"
    );
    q.bindValue(":pid", projektId);
    if (!q.exec()) {
        qWarning() << "drcKabeladernOhneAnschluss:" << q.lastError().text();
        return ergebnis;
    }
    while (q.next()) {
        QVariantMap fund;
        fund["aderId"]    = q.value(0).toInt();
        fund["aderNr"]    = q.value(1).toInt();
        fund["aderBez"]   = q.value(2).toString();
        fund["kabelName"] = q.value(3).toString();
        fund["wasFehlt"]  = q.value(4).toString();
        ergebnis << fund;
    }
    return ergebnis;
}

QVariantList Database::drcUnverbundenePins(int projektId)
{
    // Hilfs-Symbole, die keine BMK-Verbindung benötigen
    static const QSet<QString> hilfs = {
        "winkel", "treffpunkt", "treffpunkt_l", "geraeteanschluss",
        "unterbrechung", "querverweis", "aderdefinition", "klemme_anschluss"
    };

    QVariantList ergebnis;

    // Alle Seiten des Projekts laden
    QSqlQuery seitenQ;
    seitenQ.prepare("SELECT id, bezeichnung FROM seite WHERE projekt_id = :pid ORDER BY blattnummer");
    seitenQ.bindValue(":pid", projektId);
    if (!seitenQ.exec()) {
        qWarning() << "drcUnverbundenePins seiten:" << seitenQ.lastError().text();
        return ergebnis;
    }

    while (seitenQ.next()) {
        const int    seiteId   = seitenQ.value(0).toInt();
        const QString seiteName = seitenQ.value(1).toString();

        // Linienendpunkte dieser Seite sammeln
        struct Pt { double x, y; };
        QVector<Pt> enden;
        {
            QSqlQuery lQ;
            lQ.prepare("SELECT x1,y1,x2,y2 FROM grafik_element "
                       "WHERE seite_id=:sid AND typ='linie'");
            lQ.bindValue(":sid", seiteId);
            if (lQ.exec()) {
                while (lQ.next()) {
                    enden.push_back({lQ.value(0).toDouble(), lQ.value(1).toDouble()});
                    enden.push_back({lQ.value(2).toDouble(), lQ.value(3).toDouble()});
                }
            }
        }

        // Pin-Cache: symbol_id → [{x,y,name}]
        struct PinDef { double x, y; QString name; };
        QMap<QString, QList<PinDef>> pinCache;

        // Symbole laden (keine Hilfs-Symbole)
        QSqlQuery symQ;
        symQ.prepare("SELECT id, symbol_id, x1,y1,x2,y2, rotation, spiegel_x, spiegel_y "
                     "FROM grafik_element "
                     "WHERE seite_id=:sid AND typ='symbol'");
        symQ.bindValue(":sid", seiteId);
        if (!symQ.exec()) continue;

        while (symQ.next()) {
            const QString symId = symQ.value(1).toString();
            if (hilfs.contains(symId)) continue;

            const int    elId  = symQ.value(0).toInt();
            const double x1    = symQ.value(2).toDouble();
            const double y1    = symQ.value(3).toDouble();
            const double x2    = symQ.value(4).toDouble();
            const double y2    = symQ.value(5).toDouble();
            const int    rot   = symQ.value(6).toInt();
            const bool   spX   = symQ.value(7).toInt() != 0;
            const bool   spY   = symQ.value(8).toInt() != 0;

            // Pins für dieses Symbol (gecacht)
            if (!pinCache.contains(symId)) {
                QList<PinDef> pList;
                QSqlQuery pQ;
                pQ.prepare("SELECT x, y, name FROM symbol_pin WHERE symbol_id=:sid");
                pQ.bindValue(":sid", symId);
                if (pQ.exec()) {
                    while (pQ.next())
                        pList.push_back({pQ.value(0).toDouble(),
                                         pQ.value(1).toDouble(),
                                         pQ.value(2).toString()});
                }
                pinCache[symId] = pList;
            }

            const double sw  = x2 - x1, sh = y2 - y1;
            const double scx = x1 + sw / 2.0, scy = y1 + sh / 2.0;
            const double rad = rot * M_PI / 180.0;
            const double cosR = std::cos(rad), sinR = std::sin(rad);

            for (const PinDef &p : pinCache[symId]) {
                // pinWeltPos – identische Formel wie in SchaltplanCanvas.qml
                double cx = (p.x - 0.5) * std::abs(sw);
                double cy = (p.y - 0.5) * std::abs(sh);
                if (spX) cx = -cx;
                if (spY) cy = -cy;
                const double wx = scx + cx * cosR - cy * sinR;
                const double wy = scy + cx * sinR + cy * cosR;

                // Prüfen ob ein Leitungsende diesen Pin trifft
                bool verbunden = false;
                for (const Pt &lp : enden) {
                    if (std::abs(lp.x - wx) < 0.5 && std::abs(lp.y - wy) < 0.5) {
                        verbunden = true;
                        break;
                    }
                }
                if (!verbunden) {
                    QVariantMap fund;
                    fund["elementId"] = elId;
                    fund["symbolId"]  = symId;
                    fund["pinName"]   = p.name;
                    fund["seiteId"]   = seiteId;
                    fund["seiteName"] = seiteName;
                    ergebnis << fund;
                }
            }
        }
    }
    return ergebnis;
}

QVariantList Database::bauteilAlleKategorienFlach()
{
    QVariantList result;
    QSqlQuery q;
    q.exec("SELECT id, name FROM bauteil_kategorie ORDER BY sortierung, name");
    while (q.next()) {
        QVariantMap m;
        m["id"]   = q.value(0).toInt();
        m["name"] = q.value(1).toString();
        result.append(m);
    }
    return result;
}
