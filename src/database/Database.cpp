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
        { 49, "PIN-GRID-01: Pin-Koordinaten auf exaktes 4mm-Raster korrigiert", {
            // lampe (32mm breit): x=0.2→0.25 (8mm), x=0.8→0.75 (24mm)
            "UPDATE symbol_pin       SET x=0.25 WHERE symbol_id='lampe'   AND name='1'",
            "UPDATE symbol_pin       SET x=0.75 WHERE symbol_id='lampe'   AND name='2'",
            "UPDATE symbol_primitiv  SET x1=0.25 WHERE symbol_id='lampe'  AND reihenfolge=0",
            "UPDATE symbol_primitiv  SET x2=0.75 WHERE symbol_id='lampe'  AND reihenfolge=1",
            // klemme (16mm breit): x=0.3→0.25 (4mm), x=0.7→0.75 (12mm)
            "UPDATE symbol_pin       SET x=0.25 WHERE symbol_id='klemme'  AND name='1'",
            "UPDATE symbol_pin       SET x=0.75 WHERE symbol_id='klemme'  AND name='2'",
            "UPDATE symbol_primitiv  SET x1=0.25 WHERE symbol_id='klemme' AND reihenfolge=0",
            "UPDATE symbol_primitiv  SET x2=0.75 WHERE symbol_id='klemme' AND reihenfolge=1",
            // stecker (16mm breit): x=0.3→0.25 (4mm), x=0.6→0.75 (12mm); Box bis 0.75 erweitert
            "UPDATE symbol_pin       SET x=0.25 WHERE symbol_id='stecker' AND name='1'",
            "UPDATE symbol_pin       SET x=0.75 WHERE symbol_id='stecker' AND name='2'",
            "UPDATE symbol_primitiv  SET x1=0.25 WHERE symbol_id='stecker' AND reihenfolge=0",
            "UPDATE symbol_primitiv  SET x2=0.75 WHERE symbol_id='stecker' AND reihenfolge=1",
            // buchse (16mm breit): x=0.3→0.25 (4mm); Pin 2 bei x=0.5 schon korrekt
            "UPDATE symbol_pin       SET x=0.25 WHERE symbol_id='buchse'  AND name='1'",
            "UPDATE symbol_primitiv  SET x1=0.25 WHERE symbol_id='buchse' AND reihenfolge=0",
            // sps_di_8 / sps_do_8 / sps_ai_8 / pls_ai_8 (72mm hoch, Divisor=9)
            "UPDATE symbol_pin SET y=0.111111 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K1'",
            "UPDATE symbol_pin SET y=0.222222 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K2'",
            "UPDATE symbol_pin SET y=0.333333 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K3'",
            "UPDATE symbol_pin SET y=0.444444 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K4'",
            "UPDATE symbol_pin SET y=0.555556 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K5'",
            "UPDATE symbol_pin SET y=0.666667 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K6'",
            "UPDATE symbol_pin SET y=0.777778 WHERE symbol_id IN ('sps_di_8','sps_do_8','sps_ai_8','pls_ai_8') AND name='K7'",
            // sps_cpu (48mm hoch): 1/3 und 2/3
            "UPDATE symbol_pin SET y=0.333333 WHERE symbol_id='sps_cpu' AND name='DP'",
            "UPDATE symbol_pin SET y=0.666667 WHERE symbol_id='sps_cpu' AND name='PN'",
            // sps_di_16 / sps_do_16 (136mm hoch, Divisor=17)
            "UPDATE symbol_pin SET y=0.058824 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K0'",
            "UPDATE symbol_pin SET y=0.117647 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K1'",
            "UPDATE symbol_pin SET y=0.176471 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K2'",
            "UPDATE symbol_pin SET y=0.235294 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K3'",
            "UPDATE symbol_pin SET y=0.294118 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K4'",
            "UPDATE symbol_pin SET y=0.352941 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K5'",
            "UPDATE symbol_pin SET y=0.411765 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K6'",
            "UPDATE symbol_pin SET y=0.470588 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K7'",
            "UPDATE symbol_pin SET y=0.529412 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K8'",
            "UPDATE symbol_pin SET y=0.588235 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K9'",
            "UPDATE symbol_pin SET y=0.647059 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K10'",
            "UPDATE symbol_pin SET y=0.705882 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K11'",
            "UPDATE symbol_pin SET y=0.764706 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K12'",
            "UPDATE symbol_pin SET y=0.823529 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K13'",
            "UPDATE symbol_pin SET y=0.882353 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K14'",
            "UPDATE symbol_pin SET y=0.941176 WHERE symbol_id IN ('sps_di_16','sps_do_16') AND name='K15'",
        }},
        { 50, "CE-01: Elemente-Gruppen (gruppe_id auf grafik_element)", {
            "ALTER TABLE grafik_element ADD COLUMN gruppe_id INTEGER DEFAULT NULL",
            "CREATE INDEX IF NOT EXISTS idx_grafik_element_gruppe ON grafik_element(gruppe_id) WHERE gruppe_id IS NOT NULL",
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
        if (!q.exec(R"(
            CREATE TABLE IF NOT EXISTS bekannte_projekte (
                id                INTEGER PRIMARY KEY,
                datei_pfad        TEXT NOT NULL UNIQUE,
                projekt_name      TEXT,
                projekt_nummer    TEXT,
                erstellt          TEXT NOT NULL DEFAULT (date('now')),
                zuletzt_geoeffnet TEXT NOT NULL DEFAULT (datetime('now'))
            )
        )")) {
            qWarning() << "bekannte_projekte Tabelle:" << q.lastError().text();
        }
        // Einmalige Befüllung aus zuletzt_geoeffnet wenn bekannte_projekte noch leer
        {
            QSqlQuery cnt(m_launcherDb);
            if (cnt.exec("SELECT COUNT(*) FROM bekannte_projekte") && cnt.next()
                    && cnt.value(0).toInt() == 0) {
                QSqlQuery copy(m_launcherDb);
                copy.exec("INSERT OR IGNORE INTO bekannte_projekte "
                           "(datei_pfad, projekt_name, zuletzt_geoeffnet) "
                           "SELECT pfad, name, geoeffnet_am FROM zuletzt_geoeffnet");
            }
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
    const QString localPath = QUrl(path).isLocalFile() ? QUrl(path).toLocalFile() : path;

    // Bestehende Projektverbindung trennen
    if (m_projektOffen || m_db.isOpen()) {
        m_db.close();
        m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        m_projektOffen = false;
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(localPath);
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
    QString projektNummer;
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT name, projektnummer FROM projekt LIMIT 1") && q.next()) {
            projektName   = q.value(0).toString();
            projektNummer = q.value(1).toString();
        }
    }
    if (projektName.isEmpty())
        projektName = QFileInfo(localPath).baseName();

    zuletzGeoeffnetEintragen(localPath, projektName);
    bekannteProjecteEintragen(localPath, projektName, projektNummer);
    qInfo() << "Projekt geöffnet:" << localPath;
    emit projektOffenChanged();
    return true;
}

// ============================================================
// createProjekt
// Legt eine neue leere Projektdatei an (ohne Beispieldaten).
// ============================================================
bool Database::createProjekt(const QString &path, const QString &projektName)
{
    const QString localPath = QUrl(path).isLocalFile() ? QUrl(path).toLocalFile() : path;

    if (QFile::exists(localPath)) {
        qWarning() << "Projektdatei existiert bereits:" << localPath;
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
    m_db.setDatabaseName(localPath);
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
        QSqlQuery q(m_db);
        if (!q.exec("CREATE TABLE IF NOT EXISTS schema_migration ("
                    "version INTEGER PRIMARY KEY, beschreibung TEXT NOT NULL, "
                    "angewendet_am TEXT NOT NULL DEFAULT (datetime('now')))")) {
            qWarning() << "schema_migration für neues Projekt:" << q.lastError().text();
            m_db.close(); m_db = QSqlDatabase();
            QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
            QFile::remove(localPath);
            return false;
        }
    }

    if (!m_db.transaction()) {
        qWarning() << "Transaktion für neues Projekt fehlgeschlagen";
        m_db.close(); m_db = QSqlDatabase();
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
        QFile::remove(localPath);
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
        qp.bindValue(":n", projektName.isEmpty() ? QFileInfo(localPath).baseName() : projektName);
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
        QFile::remove(localPath);
        return false;
    }

    m_projektOffen = true;
    QString name = projektName.isEmpty() ? QFileInfo(localPath).baseName() : projektName;
    zuletzGeoeffnetEintragen(localPath, name);
    bekannteProjecteEintragen(localPath, name, "");
    qInfo() << "Neues Projekt erstellt:" << localPath;
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
    QSqlQuery q(m_db);
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
// projektLoeschen
// Löscht die .stroemling-Datei vom Dateisystem und entfernt
// den Launcher-Eintrag aus zuletzt_geoeffnet.
// ============================================================
bool Database::projektLoeschen(const QString &pfad)
{
    if (QFile::exists(pfad)) {
        if (!QFile::remove(pfad)) {
            qWarning() << "projektLoeschen: Datei konnte nicht gelöscht werden:" << pfad;
            return false;
        }
    }
    if (m_launcherDb.isOpen()) {
        QSqlQuery q(m_launcherDb);
        q.prepare("DELETE FROM zuletzt_geoeffnet WHERE pfad = :p");
        q.bindValue(":p", pfad);
        q.exec();
        QSqlQuery q2(m_launcherDb);
        q2.prepare("DELETE FROM bekannte_projekte WHERE datei_pfad = :p");
        q2.bindValue(":p", pfad);
        q2.exec();
        emit registryGeaendert();
    }
    return true;
}

// ============================================================
// ersteProjektInfo
// Gibt alle Meta-Daten des ersten Projekts der geöffneten DB zurück.
// ============================================================
QVariantMap Database::ersteProjektInfo() const
{
    QVariantMap m;
    if (!m_projektOffen) return m;
    QSqlQuery q(m_db);
    if (q.exec("SELECT id, name, projektnummer, auftraggeber, auftragnehmer, bearbeiter "
               "FROM projekt LIMIT 1") && q.next()) {
        m["id"]            = q.value(0).toInt();
        m["name"]          = q.value(1).toString();
        m["projektnummer"] = q.value(2).toString();
        m["auftraggeber"]  = q.value(3).toString();
        m["auftragnehmer"] = q.value(4).toString();
        m["bearbeiter"]    = q.value(5).toString();
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

// ============================================================
// bekannteProjecteEintragen (privat)
// Trägt ein Projekt in bekannte_projekte ein oder aktualisiert es.
// ============================================================
void Database::bekannteProjecteEintragen(const QString &pfad, const QString &name, const QString &nummer)
{
    if (!m_launcherDb.isOpen()) return;
    QSqlQuery q(m_launcherDb);
    q.prepare(R"(
        INSERT INTO bekannte_projekte (datei_pfad, projekt_name, projekt_nummer, zuletzt_geoeffnet)
        VALUES (:p, :n, :nr, datetime('now'))
        ON CONFLICT(datei_pfad) DO UPDATE SET
            projekt_name      = :n,
            projekt_nummer    = :nr,
            zuletzt_geoeffnet = datetime('now')
    )");
    q.bindValue(":p",  pfad);
    q.bindValue(":n",  name);
    q.bindValue(":nr", nummer);
    if (!q.exec())
        qWarning() << "bekannteProjecteEintragen:" << q.lastError().text();
    emit registryGeaendert();
}

// ============================================================
// bekannteProjecteLaden
// Gibt alle bekannten Projekte aus der Launcher-Registry zurück.
// ============================================================
QVariantList Database::bekannteProjecteLaden() const
{
    QVariantList list;
    if (!m_launcherDb.isOpen()) return list;
    QSqlQuery q(m_launcherDb);
    if (!q.exec("SELECT datei_pfad, projekt_name, projekt_nummer, erstellt, zuletzt_geoeffnet "
                "FROM bekannte_projekte ORDER BY zuletzt_geoeffnet DESC"))
        return list;
    while (q.next()) {
        QString pfad = q.value(0).toString();
        list.append(QVariantMap{
            { "dateiPfad",        pfad },
            { "projektName",      q.value(1).toString() },
            { "projektNummer",    q.value(2).toString() },
            { "erstellt",         q.value(3).toString() },
            { "zuletztGeoeffnet", q.value(4).toString() },
            { "dateiExistiert",   QFile::exists(pfad) },
        });
    }
    return list;
}

// ============================================================
// projektAusRegistryEntfernen
// Entfernt ein Projekt aus bekannte_projekte (löscht die Datei NICHT).
// ============================================================
bool Database::projektAusRegistryEntfernen(const QString &pfad)
{
    if (!m_launcherDb.isOpen()) return false;
    QSqlQuery q(m_launcherDb);
    q.prepare("DELETE FROM bekannte_projekte WHERE datei_pfad = :p");
    q.bindValue(":p", pfad);
    if (!q.exec()) {
        qWarning() << "projektAusRegistryEntfernen:" << q.lastError().text();
        return false;
    }
    QSqlQuery q2(m_launcherDb);
    q2.prepare("DELETE FROM zuletzt_geoeffnet WHERE pfad = :p");
    q2.bindValue(":p", pfad);
    q2.exec();
    emit registryGeaendert();
    return true;
}

bool Database::openWiki(const QString &path)
{
    m_wikiBlobDir = QFileInfo(path).absolutePath() + "/wiki_blobs";
    QDir().mkpath(m_wikiBlobDir);

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
    if (!checkAndApplyWikiSchema())
        return false;
    // Eingebettete Bundles (Qt-Ressourcen) automatisch einspielen
    const QStringList eingebetteteBundles = {};  // hier :/bundles/xxx.json eintragen sobald vorhanden
    for (const QString &res : eingebetteteBundles) {
        if (QFile::exists(res))
            wikiBundleAnwenden(res);
    }
    return true;
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

    // v10: bundle_kennung + von_nutzer_geaendert in wiki_artikel; wiki_meta-Tabelle
    if (storedVersion >= 1 && storedVersion < 10) {
        bool hatBundleKennung = false, hatVonNutzerGeaendert = false;
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA table_info(wiki_artikel)");
        while (pragma.next()) {
            const QString col = pragma.value(1).toString();
            if (col == "bundle_kennung")       hatBundleKennung = true;
            if (col == "von_nutzer_geaendert") hatVonNutzerGeaendert = true;
        }
        if (!hatBundleKennung) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_artikel ADD COLUMN bundle_kennung TEXT DEFAULT NULL")) {
                qWarning() << "ALTER wiki_artikel ADD bundle_kennung:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
        if (!hatVonNutzerGeaendert) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_artikel ADD COLUMN von_nutzer_geaendert INTEGER NOT NULL DEFAULT 0")) {
                qWarning() << "ALTER wiki_artikel ADD von_nutzer_geaendert:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
        QSqlQuery q(m_wikiDb);
        if (!q.exec("CREATE TABLE IF NOT EXISTS wiki_meta (schluessel TEXT PRIMARY KEY, wert TEXT NOT NULL)")) {
            qWarning() << "CREATE wiki_meta:" << q.lastError().text();
            m_wikiDb.rollback();
            return false;
        }
    }

    // v11: wiki_bild.daten (BLOB) → externe Dateien in wiki_blobs/
    if (storedVersion >= 1 && storedVersion < 11) {
        bool hasBlobPfad = false, hasDaten = false;
        QSqlQuery pragma(m_wikiDb);
        pragma.exec("PRAGMA table_info(wiki_bild)");
        while (pragma.next()) {
            const QString col = pragma.value(1).toString();
            if (col == "blob_pfad") hasBlobPfad = true;
            if (col == "daten")     hasDaten    = true;
        }
        if (!hasBlobPfad) {
            QSqlQuery alter(m_wikiDb);
            if (!alter.exec("ALTER TABLE wiki_bild ADD COLUMN blob_pfad TEXT NOT NULL DEFAULT ''")) {
                qWarning() << "ALTER wiki_bild ADD blob_pfad:" << alter.lastError().text();
                m_wikiDb.rollback();
                return false;
            }
        }
        if (hasDaten) {
            // Bestehende BLOBs in Dateien auslagern
            QSqlQuery sel(m_wikiDb);
            sel.exec("SELECT id, mime_typ, daten FROM wiki_bild WHERE blob_pfad = ''");
            while (sel.next()) {
                const int        blobId = sel.value(0).toInt();
                const QString    mime   = sel.value(1).toString();
                const QByteArray daten  = sel.value(2).toByteArray();
                if (daten.isEmpty()) continue;
                const QString ext = mime.contains("png") ? ".png" : ".jpg";
                const QString fn  = QString::number(blobId) + ext;
                QFile f(m_wikiBlobDir + "/" + fn);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(daten);
                    QSqlQuery upd(m_wikiDb);
                    upd.prepare("UPDATE wiki_bild SET blob_pfad = :p WHERE id = :id");
                    upd.bindValue(":p",  fn);
                    upd.bindValue(":id", blobId);
                    upd.exec();
                } else {
                    qWarning() << "wiki_bild Migration: Datei nicht schreibbar:" << fn;
                }
            }
            QSqlQuery drop(m_wikiDb);
            if (!drop.exec("ALTER TABLE wiki_bild DROP COLUMN daten")) {
                qWarning() << "ALTER wiki_bild DROP COLUMN daten:" << drop.lastError().text();
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
            id                   INTEGER PRIMARY KEY,
            kategorie_id         INTEGER NOT NULL REFERENCES wiki_kategorie(id) ON DELETE RESTRICT,
            titel                TEXT    NOT NULL,
            inhalt               TEXT    NOT NULL DEFAULT '',
            tags                 TEXT    NOT NULL DEFAULT '',
            ist_system           INTEGER NOT NULL DEFAULT 0,
            bundle_kennung       TEXT    DEFAULT NULL,
            von_nutzer_geaendert INTEGER NOT NULL DEFAULT 0,
            erstellt_am          TEXT    NOT NULL DEFAULT (datetime('now')),
            geaendert_am         TEXT    NOT NULL DEFAULT (datetime('now'))
        )
    )")) {
        qWarning() << "Fehler wiki_artikel:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_meta (
            schluessel TEXT PRIMARY KEY,
            wert       TEXT NOT NULL
        )
    )")) {
        qWarning() << "Fehler wiki_meta:" << q.lastError().text();
        return false;
    }

    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS wiki_bild (
            id           INTEGER PRIMARY KEY,
            artikel_id   INTEGER NOT NULL REFERENCES wiki_artikel(id) ON DELETE CASCADE,
            dateiname    TEXT    NOT NULL,
            mime_typ     TEXT    NOT NULL DEFAULT 'image/jpeg',
            blob_pfad    TEXT    NOT NULL DEFAULT '',
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
        QSqlQuery q(m_db);
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
        QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);
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
                      ? m_db
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
    QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);

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

    QSqlQuery q(m_db);

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

    QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);
    q.prepare("SELECT norm FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("IEC");
}

bool Database::projektNormSpeichern(int projektId, const QString &norm)
{
    QSqlQuery q(m_db);
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
    QSqlQuery q(m_db);
    q.prepare("SELECT canvas_hintergrund FROM projekt WHERE id = :pid");
    q.bindValue(":pid", projektId);
    if (q.exec() && q.next())
        return q.value(0).toString();
    return QStringLiteral("#080f1c");
}

bool Database::projektHintergrundSpeichern(int projektId, const QString &farbe)
{
    QSqlQuery q(m_db);
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
