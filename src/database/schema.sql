-- ============================================================
-- Strömling Design – Datenbankschema
-- Wird von Database::createSchema() nach einem dropAllTables()
-- eingelesen und vollständig ausgeführt.
-- Kein IF NOT EXISTS – createSchema wird nur auf leerer DB aufgerufen.
-- ============================================================

-- Normblatt-Vorlage
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
    logo_mime       TEXT,
    logo_x_mm       REAL,
    logo_y_mm       REAL,
    logo_breite_mm  REAL,
    logo_hoehe_mm   REAL,
    schriftart      TEXT DEFAULT 'Arial'
);

-- Normblatt-Felder
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
);

-- Projekt
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
    canvas_hintergrund  TEXT NOT NULL DEFAULT '#fdf8e8'
);

-- Changelog
CREATE TABLE changelog (
    id              INTEGER PRIMARY KEY,
    projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
    version         TEXT NOT NULL,
    datum           TEXT NOT NULL DEFAULT (date('now')),
    autor           TEXT,
    aenderung       TEXT NOT NULL,
    aenderungstyp   TEXT DEFAULT 'aenderung'
);

-- Seitenbaum
CREATE TABLE anlage (
    id                      INTEGER PRIMARY KEY,
    projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
    kuerzel                 TEXT NOT NULL,
    bezeichnung             TEXT NOT NULL,
    anlage_uebergeordnet    TEXT,
    sortierung              INTEGER DEFAULT 0
);

CREATE TABLE ort (
    id                      INTEGER PRIMARY KEY,
    anlage_id               INTEGER NOT NULL REFERENCES anlage(id),
    kuerzel                 TEXT NOT NULL,
    bezeichnung             TEXT NOT NULL,
    standort_uebergeordnet  TEXT,
    sortierung              INTEGER DEFAULT 0
);

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
    rastend           INTEGER NOT NULL DEFAULT 1,
    revision_status   TEXT NOT NULL DEFAULT '',
    revision_kennung  TEXT NOT NULL DEFAULT ''
);

-- Grafik-Elemente (Linien, Rechtecke, Symbole, Texte, …)
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
    bild_pfad           TEXT NOT NULL DEFAULT '',
    bild_mime           TEXT DEFAULT NULL,
    extra_daten         TEXT DEFAULT NULL,
    betriebsmittel_id   INTEGER REFERENCES betriebsmittel(id),
    gruppe_id           INTEGER DEFAULT NULL
);

-- Symbol-Katalog (eingebaut)
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
);

CREATE TABLE symbol_anschluss (
    id          INTEGER PRIMARY KEY,
    symbol_id   INTEGER NOT NULL REFERENCES symbol(id),
    bezeichnung TEXT NOT NULL,
    x_pos       REAL,
    y_pos       REAL,
    typ         TEXT,
    richtung    TEXT
);

CREATE TABLE symbol_textfeld (
    id          INTEGER PRIMARY KEY,
    symbol_id   INTEGER NOT NULL REFERENCES symbol(id),
    feldname    TEXT NOT NULL,
    x           REAL NOT NULL DEFAULT 0,
    y           REAL NOT NULL DEFAULT 0,
    rotation    INTEGER NOT NULL DEFAULT 0,
    ausrichtung TEXT NOT NULL DEFAULT 'links'
);

-- Primitiv-Symbolsystem (Symboleditor)
CREATE TABLE symbol_definition (
    id             TEXT    PRIMARY KEY,
    name           TEXT    NOT NULL,
    kategorie      TEXT,
    breite_mm      INTEGER NOT NULL DEFAULT 16,
    hoehe_mm       INTEGER NOT NULL DEFAULT 16,
    rolle          TEXT    NOT NULL DEFAULT 'durchleiter',
    ist_builtin    INTEGER NOT NULL DEFAULT 0,
    ibn_kategorie  TEXT    NOT NULL DEFAULT '',
    bmk_seite      TEXT    NOT NULL DEFAULT 'auto'
);

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
);

CREATE TABLE symbol_pin (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol_id     TEXT    NOT NULL REFERENCES symbol_definition(id) ON DELETE CASCADE,
    name          TEXT    NOT NULL,
    x             REAL    NOT NULL,
    y             REAL    NOT NULL,
    offen_x       REAL    NOT NULL,
    offen_y       REAL    NOT NULL,
    signaltyp     TEXT    NOT NULL DEFAULT 'neutral',
    kontext       TEXT,
    knoten_gruppe INTEGER NOT NULL DEFAULT 0,
    rolle         TEXT    NOT NULL DEFAULT ''
);

-- Betriebsmittel
CREATE TABLE betriebsmittel (
    id                      INTEGER PRIMARY KEY,
    projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
    bauteil_id              INTEGER,
    symbol_code             TEXT,
    ort_id                  INTEGER REFERENCES ort(id),
    betriebsmittel_kz       TEXT NOT NULL,
    bezeichnung             TEXT,
    bemerkung               TEXT,
    haupt_element_id        INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
);

-- Verbindungen & Querverweise
CREATE TABLE verbindung (
    id              INTEGER PRIMARY KEY,
    projekt_id      INTEGER NOT NULL REFERENCES projekt(id),
    bezeichnung     TEXT,
    farbe           TEXT,
    querschnitt_mm2 REAL,
    potenzial       TEXT,
    signaltyp       TEXT NOT NULL DEFAULT 'neutral'
);

CREATE TABLE verbindung_segment (
    id                  INTEGER PRIMARY KEY,
    verbindung_id       INTEGER NOT NULL REFERENCES verbindung(id),
    seite_id            INTEGER NOT NULL REFERENCES seite(id),
    von_anschluss_id    INTEGER,
    nach_anschluss_id   INTEGER,
    punkte              TEXT
);

CREATE TABLE querverweis (
    id                  INTEGER PRIMARY KEY,
    verbindung_id       INTEGER NOT NULL REFERENCES verbindung(id),
    von_seite_id        INTEGER NOT NULL REFERENCES seite(id),
    nach_seite_id       INTEGER NOT NULL REFERENCES seite(id),
    von_bezeichnung     TEXT,
    nach_bezeichnung    TEXT
);

-- Kabel
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
    bauteil_kabel_id    INTEGER,
    grafik_element_id   INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL
);

CREATE TABLE kabel_ader (
    id                              INTEGER PRIMARY KEY,
    kabel_id                        INTEGER NOT NULL REFERENCES kabel(id),
    ader_nr                         INTEGER NOT NULL,
    farbe                           TEXT,
    farbe2                          TEXT,
    bezeichnung                     TEXT,
    verbindung_id                   INTEGER REFERENCES verbindung(id),
    kabellinie_grafik_element_id    INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
    von_gerat_pin                   TEXT,
    nach_gerat_pin                  TEXT
);

-- Klemmen
CREATE TABLE klemmenleiste (
    id                      INTEGER PRIMARY KEY,
    projekt_id              INTEGER NOT NULL REFERENCES projekt(id),
    ort_id                  INTEGER REFERENCES ort(id),
    bezeichnung             TEXT NOT NULL,
    ausrichtung             TEXT NOT NULL DEFAULT 'senkrecht',
    bemerkung               TEXT,
    highlight_override      INTEGER,
    geraet_kuerzel          TEXT DEFAULT ''
);

CREATE TABLE klemme (
    id                  INTEGER PRIMARY KEY,
    klemmenleiste_id    INTEGER NOT NULL REFERENCES klemmenleiste(id),
    bauteil_id          INTEGER,
    nummer              TEXT NOT NULL DEFAULT '',
    sortierung          INTEGER DEFAULT 0,
    bemerkung           TEXT
);

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
);

-- Leiter (Einzeladern ohne Kabelmantel) – muss vor klemme_anschluss stehen
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
);

CREATE TABLE klemme_anschluss (
    id              INTEGER PRIMARY KEY,
    klemme_id       INTEGER NOT NULL REFERENCES klemme(id),
    bezeichnung     TEXT NOT NULL,
    seite           TEXT,
    verbindung_id   INTEGER REFERENCES verbindung(id),
    leiter_id       INTEGER REFERENCES leiter(id),
    sortierung      INTEGER DEFAULT 0
);

-- Views
CREATE VIEW seite_kennzeichen AS
    SELECT s.id, s.bezeichnung, s.blattnummer, s.seitentyp,
           s.breite_mm, s.hoehe_mm, s.sortierung, s.parent_id,
           COALESCE('==' || a.anlage_uebergeordnet, '') ||
           COALESCE('++' || o.standort_uebergeordnet, '') ||
           COALESCE('=' || a.kuerzel, '') ||
           COALESCE('+' || o.kuerzel, '') ||
           '/' || s.blattnummer AS vollkennzeichen
    FROM seite s
    LEFT JOIN ort o ON s.ort_id = o.id
    LEFT JOIN anlage a ON o.anlage_id = a.id;

CREATE VIEW betriebsmittel_bmk AS
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
    LEFT JOIN anlage a ON a.id = o.anlage_id;

CREATE VIEW klemmenleiste_bmk AS
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
    LEFT JOIN anlage a ON a.id = o.anlage_id;

-- Inbetriebnahme-Modus
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
);

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
);

CREATE TABLE ibn_feldwert (
    id                INTEGER PRIMARY KEY,
    inbetriebnahme_id INTEGER NOT NULL REFERENCES inbetriebnahme(id) ON DELETE CASCADE,
    feldname          TEXT    NOT NULL,
    wert              TEXT    DEFAULT '',
    UNIQUE(inbetriebnahme_id, feldname)
);

CREATE TABLE ibn_kabel (
    id           INTEGER PRIMARY KEY,
    projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
    kabel_id     INTEGER NOT NULL REFERENCES kabel(id)   ON DELETE CASCADE,
    status       TEXT    NOT NULL DEFAULT 'offen',
    geprueft_von TEXT    DEFAULT '',
    geprueft_am  TEXT    DEFAULT '',
    notiz        TEXT    DEFAULT '',
    UNIQUE(kabel_id)
);

-- SPS / PLS-Integration
CREATE TABLE sps_rack (
    id           INTEGER PRIMARY KEY,
    projekt_id   INTEGER NOT NULL REFERENCES projekt(id) ON DELETE CASCADE,
    rack_nr      INTEGER NOT NULL DEFAULT 0,
    system_typ   TEXT    NOT NULL DEFAULT 'SPS',
    bezeichnung  TEXT    NOT NULL DEFAULT '',
    beschreibung TEXT,
    hersteller   TEXT,
    sortierung   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE sps_baugruppe (
    id                INTEGER PRIMARY KEY,
    rack_id           INTEGER NOT NULL REFERENCES sps_rack(id) ON DELETE CASCADE,
    slot              INTEGER NOT NULL DEFAULT 0,
    typ               TEXT    NOT NULL DEFAULT '',
    bezeichnung       TEXT,
    artikel_nr        TEXT,
    kanaele           INTEGER NOT NULL DEFAULT 8,
    datentyp_standard TEXT    NOT NULL DEFAULT 'BOOL',
    adress_byte_start INTEGER NOT NULL DEFAULT 0,
    kommentar         TEXT
);

CREATE TABLE sps_kanal (
    id                INTEGER PRIMARY KEY,
    projekt_id        INTEGER NOT NULL REFERENCES projekt(id)       ON DELETE CASCADE,
    baugruppe_id      INTEGER          REFERENCES sps_baugruppe(id) ON DELETE SET NULL,
    kanal_nr          INTEGER,
    adress_typ        TEXT    NOT NULL DEFAULT 'I',
    byte_nr           INTEGER NOT NULL DEFAULT 0,
    bit_nr            INTEGER NOT NULL DEFAULT 0,
    datentyp          TEXT    NOT NULL DEFAULT 'BOOL',
    variablenname     TEXT,
    kommentar         TEXT,
    grafik_element_id INTEGER REFERENCES grafik_element(id) ON DELETE SET NULL,
    pls_einheit       TEXT,
    pls_bereich_min   REAL,
    pls_bereich_max   REAL,
    pls_alarm_ll      REAL,
    pls_alarm_lo      REAL,
    pls_alarm_hi      REAL,
    pls_alarm_hh      REAL,
    pls_hart_adresse  INTEGER,
    pls_protokoll     TEXT
);
