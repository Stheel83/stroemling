-- ============================================================
-- Strömling – Builtin-Symboldefinitionen
-- Wird beim DB-Aufbau von seedBuiltinSymbolDefinitionen() eingelesen.
-- Koordinaten normiert 0..1 relativ zur Symbolgröße.
-- Spaltenreihenfolge muss exakt dem Schema entsprechen.
-- ============================================================

-- ── symbol_definition ────────────────────────────────────────
-- (id, name, kategorie, groesse_raster, rolle, ist_builtin)

INSERT INTO symbol_definition (id, name, kategorie, groesse_raster, rolle, ist_builtin) VALUES
('schliesser',      'Schließer (NO)',          'Kontakte',     1, 'durchleiter', 1),
('oeffner',         'Öffner (NC)',             'Kontakte',     1, 'durchleiter', 1),
('wechsler',        'Wechsler',                'Kontakte',     1, 'durchleiter', 1),
('sicherung',       'Sicherung',               'Schutz',       1, 'durchleiter', 1),
('lss',             'Leitungsschutzschalter',  'Schutz',       1, 'durchleiter', 1),
('fi',              'FI-Schutzschalter',       'Schutz',       1, 'durchleiter', 1),
('motor',           'Motor',                   'Antriebe',     1, 'verbraucher', 1),
('spule',           'Spule / Relais',          'Antriebe',     1, 'verbraucher', 1),
('spule_ansi',      'Coil / Relay (ANSI)',     'Antriebe',     1, 'verbraucher', 1),
('lampe',           'Lampe',                   'Signalgeräte', 1, 'verbraucher', 1),
('hupe',            'Hupe / Klingel',          'Signalgeräte', 1, 'verbraucher', 1),
('summer',          'Summer',                  'Signalgeräte', 1, 'verbraucher', 1),
('trafo',           'Transformator',           'Antriebe',     1, 'verbraucher', 1),
('widerstand_iec',  'Widerstand (IEC)',        'Passive',      1, 'verbraucher', 1),
('widerstand_ansi', 'Resistor (ANSI)',         'Passive',      1, 'verbraucher', 1),
('kondensator',     'Kondensator',             'Passive',      1, 'verbraucher', 1),
('diode',           'Diode',                   'Passive',      1, 'durchleiter', 1),
('klemme',          'Klemme',                  'Anschlüsse',   1, 'durchleiter', 1),
('stecker',         'Stecker',                 'Anschlüsse',   1, 'durchleiter', 1),
('buchse',          'Buchse',                  'Anschlüsse',   1, 'durchleiter', 1),
('winkel',          'Winkel',                  'Verbindungen', 1, 'durchleiter', 1),
('treffpunkt',      'Treffpunkt T',            'Verbindungen', 2, 'durchleiter', 1),
('treffpunkt_l',    'Treffpunkt L',            'Verbindungen', 2, 'durchleiter', 1),
('geraeteanschluss','Geräteanschluss',         'Verbindungen', 1, 'variabel',    1),
('unterbrechung',   'Unterbrechung',           'Verbindungen', 1, 'trenner',     1),
('querverweis',     'Querverweis',             'Verbindungen', 1, 'durchleiter', 1),
('aderdefinition',  'Aderdefinition',          'Verbindungen', 1, 'durchleiter', 1),
('klemme_anschluss','Klemmenanschluss',        'Verbindungen', 1, 'durchleiter', 1),
('potenzial',       'Potenzialpunkt',          'Verbindungen', 1, 'quelle',      1),
('taster_no',       'Taster (NO)',              'Kontakte',     1, 'durchleiter', 1),
('taster_nc',       'Taster NC',               'Kontakte',     1, 'durchleiter', 1),
('not_halt',        'Not-Halt (NC)',            'Kontakte',     1, 'durchleiter', 1),
('bimetall_nc',     'Bimetall-Kontakt (NC)',    'Schutz',       1, 'durchleiter', 1);

-- ── symbol_pin ───────────────────────────────────────────────
-- (symbol_id, name, x, y, offen_x, offen_y, signaltyp)

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
-- schliesser / oeffner
('schliesser',      '1',   0,    0.5,  -1,  0, 'neutral'),
('schliesser',      '2',   1,    0.5,   1,  0, 'neutral'),
('oeffner',         '1',   0,    0.5,  -1,  0, 'neutral'),
('oeffner',         '2',   1,    0.5,   1,  0, 'neutral'),
-- wechsler
('wechsler',        'K',   0,    0.5,  -1,  0, 'neutral'),
('wechsler',        'NO',  1,    0.25,  1,  0, 'neutral'),
('wechsler',        'NC',  1,    0.75,  1,  0, 'neutral'),
-- sicherung / lss / fi
('sicherung',       '1',   0,    0.5,  -1,  0, 'neutral'),
('sicherung',       '2',   1,    0.5,   1,  0, 'neutral'),
('lss',             '1',   0,    0.5,  -1,  0, 'neutral'),
('lss',             '2',   1,    0.5,   1,  0, 'neutral'),
('fi',              '1',   0,    0.5,  -1,  0, 'neutral'),
('fi',              '2',   1,    0.5,   1,  0, 'neutral'),
-- motor
('motor',           'U',   0,    0.25, -1,  0, 'power'),
('motor',           'V',   0,    0.5,  -1,  0, 'power'),
('motor',           'W',   0,    0.75, -1,  0, 'power'),
-- spule / spule_ansi
('spule',           'A1',  0,    0.5,  -1,  0, 'power'),
('spule',           'A2',  1,    0.5,   1,  0, 'power'),
('spule_ansi',      '1',   0,    0.5,  -1,  0, 'power'),
('spule_ansi',      '2',   1,    0.5,   1,  0, 'power'),
-- lampe / hupe / summer
('lampe',           '1',   0.2,  0.5,  -1,  0, 'neutral'),
('lampe',           '2',   0.8,  0.5,   1,  0, 'neutral'),
('hupe',            '1',   0,    0.5,  -1,  0, 'neutral'),
('hupe',            '2',   1,    0.5,   1,  0, 'neutral'),
('summer',          '1',   0,    0.5,  -1,  0, 'neutral'),
('summer',          '2',   1,    0.5,   1,  0, 'neutral'),
-- trafo
('trafo',           '1',   0,    0.25, -1,  0, 'power'),
('trafo',           '2',   0,    0.75, -1,  0, 'power'),
('trafo',           '3',   1,    0.25,  1,  0, 'power'),
('trafo',           '4',   1,    0.75,  1,  0, 'power'),
-- widerstand_iec / widerstand_ansi / kondensator
('widerstand_iec',  '1',   0,    0.5,  -1,  0, 'neutral'),
('widerstand_iec',  '2',   1,    0.5,   1,  0, 'neutral'),
('widerstand_ansi', '1',   0,    0.5,  -1,  0, 'neutral'),
('widerstand_ansi', '2',   1,    0.5,   1,  0, 'neutral'),
('kondensator',     '+',   0,    0.5,  -1,  0, 'power'),
('kondensator',     '-',   1,    0.5,   1,  0, 'power'),
-- diode
('diode',           'A',   0,    0.5,  -1,  0, 'power'),
('diode',           'K',   1,    0.5,   1,  0, 'power'),
-- klemme / stecker / buchse
('klemme',          '1',   0.3,  0.5,  -1,  0, 'neutral'),
('klemme',          '2',   0.7,  0.5,   1,  0, 'neutral'),
('stecker',         '1',   0.3,  0.5,  -1,  0, 'neutral'),
('stecker',         '2',   0.6,  0.5,   1,  0, 'neutral'),
('buchse',          '1',   0.3,  0.5,  -1,  0, 'neutral'),
('buchse',          '2',   0.5,  0.5,   1,  0, 'neutral'),
-- winkel
('winkel',          '1',   0,    0,     0, -1, 'neutral'),
('winkel',          '2',   1,    1,     1,  0, 'neutral'),
-- treffpunkt T
('treffpunkt',      's1',  0,    0.5,  -1,  0, 'neutral'),
('treffpunkt',      's2',  1,    0.5,   1,  0, 'neutral'),
('treffpunkt',      'ziel',0.5,  1,     0,  1, 'neutral'),
-- treffpunkt L
('treffpunkt_l',    's1',  0,    0.5,  -1,  0, 'neutral'),
('treffpunkt_l',    's2',  0.5,  0,     0, -1, 'neutral'),
('treffpunkt_l',    'ziel',0.5,  1,     0,  1, 'neutral'),
-- geraeteanschluss / potenzial
('geraeteanschluss','1',   1,    0.5,   1,  0, 'neutral'),
('potenzial',       '1',   1,    0.5,   1,  0, 'neutral'),
-- querverweis
('querverweis',     '1',   0,    0.5,  -1,  0, 'neutral'),
-- klemme_anschluss
('klemme_anschluss','A',   0.5,    0,  0,  -1, 'neutral'),
-- taster_no
('taster_no',       '1',   0,    0.5,  -1,  0, 'neutral'),
('taster_no',       '2',   1,    0.5,   1,  0, 'neutral'),
-- taster_nc
('taster_nc',       '1',   0,    0.5,  -1,  0, 'neutral'),
('taster_nc',       '2',   1,    0.5,   1,  0, 'neutral'),
-- not_halt
('not_halt',        '1',   0,    0.5,  -1,  0, 'neutral'),
('not_halt',        '2',   1,    0.5,   1,  0, 'neutral'),
-- bimetall_nc
('bimetall_nc',     '1',   0,    0.5,  -1,  0, 'neutral'),
('bimetall_nc',     '2',   1,    0.5,   1,  0, 'neutral');
-- unterbrechung und aderdefinition haben keine Pins

-- ── symbol_primitiv ──────────────────────────────────────────
-- Spalten: symbol_id, reihenfolge, typ,
--          x1, y1, x2, y2, x3, y3,
--          radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
--          text_inhalt, schrift_relativ, schrift_fett,
--          text_align, text_baseline, linienart
--
-- Typen:  linie | rechteck | kreis_offen | kreis_gefuellt |
--         bogen | text | dreieck_gefuellt
-- Nicht verwendete Felder werden auf 0 / NULL gesetzt.

INSERT INTO symbol_primitiv
    (symbol_id, reihenfolge, typ,
     x1, y1, x2, y2, x3, y3,
     radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
     text_inhalt, schrift_relativ, schrift_fett,
     text_align, text_baseline, linienart)
VALUES
-- ── Schließer ──
('schliesser', 0, 'linie',          0,     0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser', 1, 'linie',          0.3,   0.5,  0.75,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser', 2, 'linie',          0.7,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Öffner ──
('oeffner',    0, 'linie',          0,     0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner',    1, 'linie',          0.3,   0.5,  0.75,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner',    2, 'linie',          0.7,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner',    3, 'linie',          0.7,   0.5,  0.7,   0.2,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Wechsler ──
('wechsler',   0, 'linie',          0,     0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechsler',   1, 'linie',          0.3,   0.5,  0.75,  0.35, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechsler',   2, 'linie',          0.7,   0.25, 0.7,   0.45, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechsler',   3, 'linie',          0.7,   0.25, 1,     0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechsler',   4, 'linie',          0.7,   0.75, 1,     0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Sicherung ──
('sicherung',  0, 'linie',          0,     0.5,  0.25,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherung',  1, 'rechteck',       0.25,  0.21, 0.75,  0.79, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherung',  2, 'linie',          0.75,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── LSS ──
('lss',        0, 'linie',          0,     0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('lss',        1, 'linie',          0.3,   0.5,  0.75,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('lss',        2, 'linie',          0.7,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('lss',        3, 'rechteck',       0.43,  0.11, 0.57,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('lss',        4, 'linie',          0.5,   0.25, 0.5,   0.46, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── FI ──
('fi',         0, 'linie',          0,     0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('fi',         1, 'linie',          0.3,   0.5,  0.75,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('fi',         2, 'linie',          0.7,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('fi',         3, 'rechteck',       0.43,  0.11, 0.57,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('fi',         4, 'linie',          0.5,   0.25, 0.5,   0.46, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('fi',         5, 'bogen',          0.435, 0.82, 0,     0,    0, 0, 0.065, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('fi',         6, 'bogen',          0.565, 0.82, 0,     0,    0, 0, 0.065,  0,  180, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Motor ──
('motor',      0, 'linie',          0,     0.25, 0.524, 0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor',      1, 'linie',          0,     0.5,  0.37,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor',      2, 'linie',          0,     0.75, 0.524, 0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor',      3, 'kreis_offen',    0.65,  0.5,  0,     0,    0, 0, 0.28, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor',      4, 'text',           0.65,  0.46, 0,     0,    0, 0, 0,    0,   0,   0, 'M',  0.20,1, 'center', 'middle', 'solid'),
('motor',      5, 'text',           0.65,  0.61, 0,     0,    0, 0, 0,    0,   0,   0, '3~', 0.14,0, 'center', 'middle', 'solid'),

-- ── Spule IEC ──
('spule',      0, 'linie',          0,     0.5,  0.2,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule',      1, 'linie',          0.8,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule',      2, 'rechteck',       0.2,   0.24, 0.8,   0.76, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Spule ANSI ──
('spule_ansi', 0, 'linie',          0,     0.5,  0.2,   0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 1, 'linie',          0.8,   0.5,  1,     0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 2, 'bogen',          0.275, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 3, 'bogen',          0.425, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 4, 'bogen',          0.575, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 5, 'bogen',          0.725, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Lampe ──
('lampe',      0, 'linie',          0.2,   0.5,  0.357, 0.5,  0, 0, 0,    0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),
('lampe',      1, 'linie',          0.643, 0.5,  0.8,   0.5,  0, 0, 0,    0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),
('lampe',      2, 'kreis_offen',    0.5,   0.5,  0,     0,    0, 0, 0.144,0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),
('lampe',      3, 'linie',          0.4,   0.4,  0.6,   0.6,  0, 0, 0,    0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),
('lampe',      4, 'linie',          0.4,   0.6,  0.6,   0.4,  0, 0, 0,    0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),

-- ── Hupe ──
('hupe',       0, 'linie',          0,     0.5,  0.22,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('hupe',       1, 'linie',          0.52,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('hupe',       2, 'rechteck',       0.22,  0.28, 0.52,  0.72, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('hupe',       3, 'linie',          0.52,  0.28, 0.78,  0.1,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('hupe',       4, 'linie',          0.78,  0.1,  0.78,  0.9,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('hupe',       5, 'linie',          0.78,  0.9,  0.52,  0.72, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Summer ──
('summer',     0, 'linie',          0,     0.5,  0.22,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     1, 'linie',          0.52,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     2, 'rechteck',       0.22,  0.28, 0.52,  0.72, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     3, 'linie',          0.52,  0.28, 0.78,  0.1,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     4, 'linie',          0.78,  0.1,  0.78,  0.9,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     5, 'linie',          0.78,  0.9,  0.52,  0.72, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     6, 'bogen',          0.85,  0.68, 0,     0,    0, 0, 0.03, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('summer',     7, 'bogen',          0.91,  0.68, 0,     0,    0, 0, 0.03,   0, 180,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Transformator ──
('trafo',      0, 'linie',          0,     0.25, 0.3,   0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      1, 'linie',          0,     0.75, 0.3,   0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      2, 'linie',          0.7,   0.25, 1,     0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      3, 'linie',          0.7,   0.75, 1,     0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      4, 'kreis_offen',    0.3,   0.5,  0,     0,    0, 0, 0.25, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      5, 'kreis_offen',    0.7,   0.5,  0,     0,    0, 0, 0.25, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      6, 'linie',          0.48,  0.275,0.48,  0.725,0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('trafo',      7, 'linie',          0.52,  0.275,0.52,  0.725,0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Widerstand IEC ──
('widerstand_iec',  0, 'linie',     0,     0.5,  0.2,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_iec',  1, 'linie',     0.8,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_iec',  2, 'rechteck',  0.2,   0.25, 0.8,   0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Widerstand ANSI ──
('widerstand_ansi', 0, 'linie',     0,      0.5,  0.15,   0.5,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_ansi', 1, 'linie',     0.85,   0.5,  1,      0.5,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_ansi', 2, 'linie',     0.15,   0.5,  0.2375, 0.2,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_ansi', 3, 'linie',     0.2375, 0.2,  0.4125, 0.8,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_ansi', 4, 'linie',     0.4125, 0.8,  0.5875, 0.2,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_ansi', 5, 'linie',     0.5875, 0.2,  0.7625, 0.8,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('widerstand_ansi', 6, 'linie',     0.7625, 0.8,  0.85,   0.5,  0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Kondensator ──
('kondensator', 0, 'linie',         0,     0.5,   0.45,  0.5,   0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kondensator', 1, 'linie',         0.55,  0.5,   1,     0.5,   0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kondensator', 2, 'linie',         0.45,  0.175, 0.45,  0.825, 0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kondensator', 3, 'linie',         0.55,  0.175, 0.55,  0.825, 0, 0, 0,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Diode ──
('diode',      0, 'linie',          0,     0.5,  0.28,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('diode',      1, 'linie',          0.68,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('diode',      2, 'linie',          0.28,  0.12, 0.28,  0.88, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('diode',      3, 'linie',          0.28,  0.12, 0.68,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('diode',      4, 'linie',          0.28,  0.88, 0.68,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('diode',      5, 'linie',          0.68,  0.12, 0.68,  0.88, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Klemme ──
('klemme',     0, 'linie',          0.3,   0.5,  0.45,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('klemme',     1, 'linie',          0.55,  0.5,  0.7,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('klemme',     2, 'kreis_offen',    0.5,   0.5,  0,     0,    0, 0, 0.05, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Stecker ──
('stecker',    0, 'linie',          0.3,   0.5,  0.45,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('stecker',    1, 'rechteck',       0.45,  0.45, 0.6,   0.55, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Buchse ──
('buchse',     0, 'linie',          0.3,   0.5,  0.5,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('buchse',     1, 'bogen',          0.57,  0.5,  0,     0,    0, 0, 0.07, 90,  270,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Winkel ──
('winkel',     0, 'linie',          0,     0,    0,     1,    0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('winkel',     1, 'linie',          0,     1,    1,     1,    0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Treffpunkt T ──
('treffpunkt', 0, 'linie',          0,     0.5,  0.25,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('treffpunkt', 1, 'linie',          0.25,  0.5,  0.5,   0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('treffpunkt', 2, 'linie',          0.5,   0.75, 0.5,   1,    0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('treffpunkt', 3, 'linie',          0.5,   0.75, 0.75,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('treffpunkt', 4, 'linie',          0.75,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Treffpunkt L ──
('treffpunkt_l', 0, 'linie',        0,     0.5,  0.25,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('treffpunkt_l', 1, 'linie',        0.25,  0.5,  0.5,   0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('treffpunkt_l', 2, 'linie',        0.5,   0,    0.5,   1,    0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Geräteanschluss ──
('geraeteanschluss', 0, 'linie',    0.5,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('geraeteanschluss', 1, 'kreis_offen', 0.28, 0.5, 0,    0,    0, 0, 0.22, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Potenzialpunkt ──
('potenzial',  0, 'linie',          0.5,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('potenzial',  1, 'kreis_gefuellt', 0.28,  0.5,  0,     0,    0, 0, 0.22, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Aderdefinition ──
('aderdefinition', 0, 'linie',      1,     1,    0,     0,    0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Unterbrechung ──
('unterbrechung', 0, 'linie',       0,     0.5,  0.24,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('unterbrechung', 1, 'linie',       0.76,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('unterbrechung', 2, 'text',        0.5,   0.5,  0,     0,    0, 0, 0,    0,   0,   0, 'U',  0.72,1, 'center', 'middle', 'solid'),

-- ── Querverweis ──
('querverweis', 0, 'linie',         0,     0.5,  0.5,   0.5,  0,    0,    0,   0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('querverweis', 1, 'dreieck_gefuellt', 0.5, 0.35, 1,    0.5,  0.5,  0.65, 0,   0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Klemmenanschluss ──
('klemme_anschluss', 0, 'linie',    0.5,     0,   0.5,  0.375,   0, 0, 0,  0,   360,   0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
('klemme_anschluss', 1, 'kreis_offen',    0.5,  0.5,   0,     0,   0, 0, 0,  0.125,   0,   360, NULL, 0.15, 0, 'center', 'middle', 'solid'),

-- ── Taster NO (Schließer + Drucktaste) ──
('taster_no', 0, 'linie',    0,    0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_no', 1, 'linie',    0.3,  0.5,  0.75,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_no', 2, 'linie',    0.7,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_no', 3, 'linie',    0.5,  0.14, 0.5,   0.36, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_no', 4, 'linie',    0.35, 0.14, 0.65,  0.14, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Taster NC (Öffner + Drucktaste) ──
('taster_nc', 0, 'linie',    0,    0.5,  0.3,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_nc', 1, 'linie',    0.3,  0.5,  0.75,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_nc', 2, 'linie',    0.7,  0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_nc', 3, 'linie',    0.7,  0.5,  0.7,   0.2,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_nc', 4, 'linie',    0.5,  0.14, 0.5,   0.36, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_nc', 5, 'linie',    0.35, 0.14, 0.65,  0.14, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Not-Halt NC (Öffner + Pilzkopf) ──
('not_halt', 0, 'linie',     0,    0.5,  0.3,  0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('not_halt', 1, 'linie',     0.3,  0.5,  0.75, 0.25, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('not_halt', 2, 'linie',     0.7,  0.5,  1,    0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('not_halt', 3, 'linie',     0.7,  0.5,  0.7,  0.2,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('not_halt', 4, 'linie',     0.5,  0.18, 0.5,  0.33, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('not_halt', 5, 'linie',     0.33, 0.33, 0.67, 0.33, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('not_halt', 6, 'bogen',     0.5,  0.18, 0,    0,    0, 0, 0.13, 180, 360,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Bimetall-Kontakt NC (Öffner + Thermoelement Z) ──
('bimetall_nc', 0, 'linie',  0,    0.5,  0.3,  0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 1, 'linie',  0.3,  0.5,  0.75, 0.25, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 2, 'linie',  0.7,  0.5,  1,    0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 3, 'linie',  0.7,  0.5,  0.7,  0.2,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 4, 'linie',  0.38, 0.12, 0.62, 0.12, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 5, 'linie',  0.62, 0.12, 0.38, 0.24, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 6, 'linie',  0.38, 0.24, 0.62, 0.24, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bimetall_nc', 7, 'linie',  0.5,  0.24, 0.5,  0.38, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid');
