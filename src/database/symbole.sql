-- ============================================================
-- Strömling – Builtin-Symboldefinitionen
-- Wird beim DB-Aufbau von seedBuiltinSymbolDefinitionen() eingelesen.
-- Koordinaten normiert 0..1 relativ zur Symbolgröße.
-- Spaltenreihenfolge muss exakt dem Schema entsprechen.
-- ============================================================

-- ── symbol_definition ────────────────────────────────────────
-- (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin)

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('schliesser',      'Schließer (NO)',          'Kontakte',     32, 16, 'durchleiter', 1),
('oeffner',         'Öffner (NC)',             'Kontakte',     32, 16, 'durchleiter', 1),
('wechsler',        'Wechsler',                'Kontakte',     32, 16, 'durchleiter', 1),
('sicherung',       'Sicherung',               'Schutz',       32, 16, 'durchleiter', 1),
('lss',             'Leitungsschutzschalter',  'Schutz',       32, 16, 'durchleiter', 1),
('fi',              'FI-Schutzschalter',       'Schutz',       32, 16, 'durchleiter', 1),
('motor',           'Motor',                   'Antriebe',     32, 16, 'verbraucher', 1),
('spule',           'Spule / Relais',          'Antriebe',     32, 16, 'verbraucher', 1),
('spule_ansi',      'Coil / Relay (ANSI)',     'Antriebe',     32, 16, 'verbraucher', 1),
('lampe',           'Lampe',                   'Signalgeräte', 32, 16, 'verbraucher', 1),
('hupe',            'Hupe / Klingel',          'Signalgeräte', 32, 16, 'verbraucher', 1),
('summer',          'Summer',                  'Signalgeräte', 32, 16, 'verbraucher', 1),
('trafo',           'Transformator',           'Antriebe',     32, 32, 'verbraucher', 1),
('widerstand_iec',  'Widerstand (IEC)',        'Passive',      32, 16, 'verbraucher', 1),
('widerstand_ansi', 'Resistor (ANSI)',         'Passive',      32, 16, 'verbraucher', 1),
('kondensator',     'Kondensator',             'Passive',      32, 16, 'verbraucher', 1),
('diode',           'Diode',                   'Passive',      32, 16, 'durchleiter', 1),
('klemme',          'Klemme',                  'Anschlüsse',   16, 16, 'durchleiter', 1),
('stecker',         'Stecker',                 'Anschlüsse',   16, 16, 'durchleiter', 1),
('buchse',          'Buchse',                  'Anschlüsse',   16, 16, 'durchleiter', 1),
('winkel',          'Winkel',                  'Verbindungen', 16, 16, 'durchleiter', 1),
('treffpunkt',      'Treffpunkt T',            'Verbindungen', 16, 16, 'durchleiter', 1),
('treffpunkt_l',    'Treffpunkt L',            'Verbindungen', 16, 16, 'durchleiter', 1),
('geraeteanschluss','Geräteanschluss',         'Verbindungen', 16, 16, 'variabel',    1),
('unterbrechung',   'Unterbrechung',           'Verbindungen', 16, 16, 'trenner',     1),
('querverweis',     'Querverweis',             'Verbindungen', 16, 16, 'durchleiter', 1),
('aderdefinition',  'Aderdefinition',          'Verbindungen', 16, 16, 'durchleiter', 1),
('klemme_anschluss','Klemmenanschluss',        'Verbindungen', 16, 16, 'durchleiter', 1),
('potenzial',       'Potenzialpunkt',          'Verbindungen', 16, 16, 'quelle',      1),
('taster_no',       'Taster (NO)',              'Kontakte',     32, 16, 'durchleiter', 1),
('taster_nc',       'Taster NC',               'Kontakte',     32, 16, 'durchleiter', 1),
('not_halt',        'Not-Halt (NC)',            'Kontakte',     32, 16, 'durchleiter', 1),
('bimetall_nc',          'Bimetall-Kontakt (NC)',    'Schutz',       32, 16, 'durchleiter', 1),
('isoliert_gelegte_ader','Isoliert gelegte Ader',   'Verbindungen', 16, 16, 'durchleiter', 1);

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
('bimetall_nc',           '1',  0,   0.5,  -1,  0, 'neutral'),
('bimetall_nc',           '2',  1,   0.5,   1,  0, 'neutral'),
-- isoliert_gelegte_ader – 1 Pin links; rechte Seite ist isoliertes Leitungsende
('isoliert_gelegte_ader', '1',  0,   0.5,  -1,  0, 'neutral');
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
('bimetall_nc', 7, 'linie',  0.5,  0.24, 0.5,  0.38, 0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Isoliert gelegte Ader: Linie + Halbkreis-Kappe rechts ──
-- Bei 0°: ──( Pin links, offenes Leitungsende rechts
('isoliert_gelegte_ader', 0, 'linie', 0,    0.5, 0.65, 0.5, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('isoliert_gelegte_ader', 1, 'bogen', 0.65, 0.5, 0,    0,   0, 0, 0.15, 270, 90,  0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- SPS / PLS Baugruppen-Symbole (S6) — Kategorie "SPS/PLS"
-- Pins links  = Eingaenge (DI, AI)
-- Pins rechts = Ausgaenge (DO, AO)
-- Y-Koordinaten: (i+1)/(n+1) gleichmaessig verteilt
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('sps_di_8',  'DI-Baugruppe 8-Kanal',     'SPS/PLS', 32,  72, 'variabel', 1),
('sps_di_16', 'DI-Baugruppe 16-Kanal',    'SPS/PLS', 32, 136, 'variabel', 1),
('sps_do_8',  'DO-Baugruppe 8-Kanal',     'SPS/PLS', 32,  72, 'variabel', 1),
('sps_do_16', 'DO-Baugruppe 16-Kanal',    'SPS/PLS', 32, 136, 'variabel', 1),
('sps_ai_4',  'AI-Baugruppe 4-Kanal',     'SPS/PLS', 32,  40, 'variabel', 1),
('sps_ai_8',  'AI-Baugruppe 8-Kanal',     'SPS/PLS', 32,  72, 'variabel', 1),
('sps_ao_4',  'AO-Baugruppe 4-Kanal',     'SPS/PLS', 32,  40, 'variabel', 1),
('sps_cpu',   'CPU-Baugruppe',            'SPS/PLS', 32,  48, 'variabel', 1),
('pls_ai_8',  'PLS AI-Baugruppe 8-Kanal', 'SPS/PLS', 32,  72, 'variabel', 1),
('pls_ao_4',  'PLS AO-Baugruppe 4-Kanal', 'SPS/PLS', 32,  40, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
-- sps_di_8: 8 Eingaenge links
('sps_di_8',  'K0', 0, 0.111, -1, 0, 'neutral'),
('sps_di_8',  'K1', 0, 0.222, -1, 0, 'neutral'),
('sps_di_8',  'K2', 0, 0.333, -1, 0, 'neutral'),
('sps_di_8',  'K3', 0, 0.444, -1, 0, 'neutral'),
('sps_di_8',  'K4', 0, 0.556, -1, 0, 'neutral'),
('sps_di_8',  'K5', 0, 0.667, -1, 0, 'neutral'),
('sps_di_8',  'K6', 0, 0.778, -1, 0, 'neutral'),
('sps_di_8',  'K7', 0, 0.889, -1, 0, 'neutral'),
-- sps_di_16: 16 Eingaenge links
('sps_di_16', 'K0',  0, 0.059, -1, 0, 'neutral'),
('sps_di_16', 'K1',  0, 0.118, -1, 0, 'neutral'),
('sps_di_16', 'K2',  0, 0.176, -1, 0, 'neutral'),
('sps_di_16', 'K3',  0, 0.235, -1, 0, 'neutral'),
('sps_di_16', 'K4',  0, 0.294, -1, 0, 'neutral'),
('sps_di_16', 'K5',  0, 0.353, -1, 0, 'neutral'),
('sps_di_16', 'K6',  0, 0.412, -1, 0, 'neutral'),
('sps_di_16', 'K7',  0, 0.471, -1, 0, 'neutral'),
('sps_di_16', 'K8',  0, 0.529, -1, 0, 'neutral'),
('sps_di_16', 'K9',  0, 0.588, -1, 0, 'neutral'),
('sps_di_16', 'K10', 0, 0.647, -1, 0, 'neutral'),
('sps_di_16', 'K11', 0, 0.706, -1, 0, 'neutral'),
('sps_di_16', 'K12', 0, 0.765, -1, 0, 'neutral'),
('sps_di_16', 'K13', 0, 0.824, -1, 0, 'neutral'),
('sps_di_16', 'K14', 0, 0.882, -1, 0, 'neutral'),
('sps_di_16', 'K15', 0, 0.941, -1, 0, 'neutral'),
-- sps_do_8: 8 Ausgaenge rechts
('sps_do_8',  'K0', 1, 0.111, 1, 0, 'neutral'),
('sps_do_8',  'K1', 1, 0.222, 1, 0, 'neutral'),
('sps_do_8',  'K2', 1, 0.333, 1, 0, 'neutral'),
('sps_do_8',  'K3', 1, 0.444, 1, 0, 'neutral'),
('sps_do_8',  'K4', 1, 0.556, 1, 0, 'neutral'),
('sps_do_8',  'K5', 1, 0.667, 1, 0, 'neutral'),
('sps_do_8',  'K6', 1, 0.778, 1, 0, 'neutral'),
('sps_do_8',  'K7', 1, 0.889, 1, 0, 'neutral'),
-- sps_do_16: 16 Ausgaenge rechts
('sps_do_16', 'K0',  1, 0.059, 1, 0, 'neutral'),
('sps_do_16', 'K1',  1, 0.118, 1, 0, 'neutral'),
('sps_do_16', 'K2',  1, 0.176, 1, 0, 'neutral'),
('sps_do_16', 'K3',  1, 0.235, 1, 0, 'neutral'),
('sps_do_16', 'K4',  1, 0.294, 1, 0, 'neutral'),
('sps_do_16', 'K5',  1, 0.353, 1, 0, 'neutral'),
('sps_do_16', 'K6',  1, 0.412, 1, 0, 'neutral'),
('sps_do_16', 'K7',  1, 0.471, 1, 0, 'neutral'),
('sps_do_16', 'K8',  1, 0.529, 1, 0, 'neutral'),
('sps_do_16', 'K9',  1, 0.588, 1, 0, 'neutral'),
('sps_do_16', 'K10', 1, 0.647, 1, 0, 'neutral'),
('sps_do_16', 'K11', 1, 0.706, 1, 0, 'neutral'),
('sps_do_16', 'K12', 1, 0.765, 1, 0, 'neutral'),
('sps_do_16', 'K13', 1, 0.824, 1, 0, 'neutral'),
('sps_do_16', 'K14', 1, 0.882, 1, 0, 'neutral'),
('sps_do_16', 'K15', 1, 0.941, 1, 0, 'neutral'),
-- sps_ai_4: 4 Eingaenge links
('sps_ai_4',  'K0', 0, 0.2,   -1, 0, 'neutral'),
('sps_ai_4',  'K1', 0, 0.4,   -1, 0, 'neutral'),
('sps_ai_4',  'K2', 0, 0.6,   -1, 0, 'neutral'),
('sps_ai_4',  'K3', 0, 0.8,   -1, 0, 'neutral'),
-- sps_ai_8: 8 Eingaenge links
('sps_ai_8',  'K0', 0, 0.111, -1, 0, 'neutral'),
('sps_ai_8',  'K1', 0, 0.222, -1, 0, 'neutral'),
('sps_ai_8',  'K2', 0, 0.333, -1, 0, 'neutral'),
('sps_ai_8',  'K3', 0, 0.444, -1, 0, 'neutral'),
('sps_ai_8',  'K4', 0, 0.556, -1, 0, 'neutral'),
('sps_ai_8',  'K5', 0, 0.667, -1, 0, 'neutral'),
('sps_ai_8',  'K6', 0, 0.778, -1, 0, 'neutral'),
('sps_ai_8',  'K7', 0, 0.889, -1, 0, 'neutral'),
-- sps_ao_4: 4 Ausgaenge rechts
('sps_ao_4',  'K0', 1, 0.2,   1, 0, 'neutral'),
('sps_ao_4',  'K1', 1, 0.4,   1, 0, 'neutral'),
('sps_ao_4',  'K2', 1, 0.6,   1, 0, 'neutral'),
('sps_ao_4',  'K3', 1, 0.8,   1, 0, 'neutral'),
-- sps_cpu: DP / PN Kommunikations-Pins links
('sps_cpu',   'DP', 0, 0.333, -1, 0, 'neutral'),
('sps_cpu',   'PN', 0, 0.667, -1, 0, 'neutral'),
-- pls_ai_8: 8 Eingaenge links
('pls_ai_8',  'K0', 0, 0.111, -1, 0, 'neutral'),
('pls_ai_8',  'K1', 0, 0.222, -1, 0, 'neutral'),
('pls_ai_8',  'K2', 0, 0.333, -1, 0, 'neutral'),
('pls_ai_8',  'K3', 0, 0.444, -1, 0, 'neutral'),
('pls_ai_8',  'K4', 0, 0.556, -1, 0, 'neutral'),
('pls_ai_8',  'K5', 0, 0.667, -1, 0, 'neutral'),
('pls_ai_8',  'K6', 0, 0.778, -1, 0, 'neutral'),
('pls_ai_8',  'K7', 0, 0.889, -1, 0, 'neutral'),
-- pls_ao_4: 4 Ausgaenge rechts
('pls_ao_4',  'K0', 1, 0.2,   1, 0, 'neutral'),
('pls_ao_4',  'K1', 1, 0.4,   1, 0, 'neutral'),
('pls_ao_4',  'K2', 1, 0.6,   1, 0, 'neutral'),
('pls_ao_4',  'K3', 1, 0.8,   1, 0, 'neutral');

INSERT INTO symbol_primitiv
    (symbol_id, reihenfolge, typ,
     x1, y1, x2, y2, x3, y3,
     radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
     text_inhalt, schrift_relativ, schrift_fett,
     text_align, text_baseline, linienart)
VALUES
-- ── sps_di_8 (Digital Input 8-Kanal, 32x80mm, Pins links) ──
('sps_di_8',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('sps_di_8',  1, 'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'DI 8', 0.08, 1, 'center', 'middle', 'solid'),
('sps_di_8',  2, 'linie', 0,    0.111, 0.15, 0.111, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  3, 'linie', 0,    0.222, 0.15, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  4, 'linie', 0,    0.333, 0.15, 0.333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  5, 'linie', 0,    0.444, 0.15, 0.444, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  6, 'linie', 0,    0.556, 0.15, 0.556, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  7, 'linie', 0,    0.667, 0.15, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  8, 'linie', 0,    0.778, 0.15, 0.778, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_8',  9, 'linie', 0,    0.889, 0.15, 0.889, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_di_16 (Digital Input 16-Kanal, 32x128mm, Pins links) ──
('sps_di_16', 0,  'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sps_di_16', 1,  'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'DI 16', 0.06, 1, 'center', 'middle', 'solid'),
('sps_di_16', 2,  'linie', 0, 0.059, 0.15, 0.059, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 3,  'linie', 0, 0.118, 0.15, 0.118, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 4,  'linie', 0, 0.176, 0.15, 0.176, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 5,  'linie', 0, 0.235, 0.15, 0.235, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 6,  'linie', 0, 0.294, 0.15, 0.294, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 7,  'linie', 0, 0.353, 0.15, 0.353, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 8,  'linie', 0, 0.412, 0.15, 0.412, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 9,  'linie', 0, 0.471, 0.15, 0.471, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 10, 'linie', 0, 0.529, 0.15, 0.529, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 11, 'linie', 0, 0.588, 0.15, 0.588, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 12, 'linie', 0, 0.647, 0.15, 0.647, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 13, 'linie', 0, 0.706, 0.15, 0.706, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 14, 'linie', 0, 0.765, 0.15, 0.765, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 15, 'linie', 0, 0.824, 0.15, 0.824, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 16, 'linie', 0, 0.882, 0.15, 0.882, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_di_16', 17, 'linie', 0, 0.941, 0.15, 0.941, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_do_8 (Digital Output 8-Kanal, 32x80mm, Pins rechts) ──
('sps_do_8',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('sps_do_8',  1, 'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'DO 8', 0.08, 1, 'center', 'middle', 'solid'),
('sps_do_8',  2, 'linie', 0.85, 0.111, 1.0, 0.111, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  3, 'linie', 0.85, 0.222, 1.0, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  4, 'linie', 0.85, 0.333, 1.0, 0.333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  5, 'linie', 0.85, 0.444, 1.0, 0.444, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  6, 'linie', 0.85, 0.556, 1.0, 0.556, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  7, 'linie', 0.85, 0.667, 1.0, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  8, 'linie', 0.85, 0.778, 1.0, 0.778, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_8',  9, 'linie', 0.85, 0.889, 1.0, 0.889, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_do_16 (Digital Output 16-Kanal, 32x128mm, Pins rechts) ──
('sps_do_16', 0,  'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sps_do_16', 1,  'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'DO 16', 0.06, 1, 'center', 'middle', 'solid'),
('sps_do_16', 2,  'linie', 0.85, 0.059, 1.0, 0.059, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 3,  'linie', 0.85, 0.118, 1.0, 0.118, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 4,  'linie', 0.85, 0.176, 1.0, 0.176, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 5,  'linie', 0.85, 0.235, 1.0, 0.235, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 6,  'linie', 0.85, 0.294, 1.0, 0.294, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 7,  'linie', 0.85, 0.353, 1.0, 0.353, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 8,  'linie', 0.85, 0.412, 1.0, 0.412, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 9,  'linie', 0.85, 0.471, 1.0, 0.471, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 10, 'linie', 0.85, 0.529, 1.0, 0.529, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 11, 'linie', 0.85, 0.588, 1.0, 0.588, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 12, 'linie', 0.85, 0.647, 1.0, 0.647, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 13, 'linie', 0.85, 0.706, 1.0, 0.706, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 14, 'linie', 0.85, 0.765, 1.0, 0.765, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 15, 'linie', 0.85, 0.824, 1.0, 0.824, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 16, 'linie', 0.85, 0.882, 1.0, 0.882, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_do_16', 17, 'linie', 0.85, 0.941, 1.0, 0.941, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_ai_4 (Analog Input 4-Kanal, 32x64mm, Pins links) ──
('sps_ai_4',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('sps_ai_4',  1, 'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'AI 4', 0.10, 1, 'center', 'middle', 'solid'),
('sps_ai_4',  2, 'linie', 0, 0.2, 0.15, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_4',  3, 'linie', 0, 0.4, 0.15, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_4',  4, 'linie', 0, 0.6, 0.15, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_4',  5, 'linie', 0, 0.8, 0.15, 0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_ai_8 (Analog Input 8-Kanal, 32x80mm, Pins links) ──
('sps_ai_8',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('sps_ai_8',  1, 'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'AI 8', 0.08, 1, 'center', 'middle', 'solid'),
('sps_ai_8',  2, 'linie', 0, 0.111, 0.15, 0.111, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  3, 'linie', 0, 0.222, 0.15, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  4, 'linie', 0, 0.333, 0.15, 0.333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  5, 'linie', 0, 0.444, 0.15, 0.444, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  6, 'linie', 0, 0.556, 0.15, 0.556, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  7, 'linie', 0, 0.667, 0.15, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  8, 'linie', 0, 0.778, 0.15, 0.778, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ai_8',  9, 'linie', 0, 0.889, 0.15, 0.889, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_ao_4 (Analog Output 4-Kanal, 32x64mm, Pins rechts) ──
('sps_ao_4',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('sps_ao_4',  1, 'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'AO 4', 0.10, 1, 'center', 'middle', 'solid'),
('sps_ao_4',  2, 'linie', 0.85, 0.2, 1.0, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ao_4',  3, 'linie', 0.85, 0.4, 1.0, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ao_4',  4, 'linie', 0.85, 0.6, 1.0, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_ao_4',  5, 'linie', 0.85, 0.8, 1.0, 0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── sps_cpu (CPU-Baugruppe, 32x48mm) ──
('sps_cpu',   0, 'rechteck', 0.1,  0.05, 0.9,  0.95, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sps_cpu',   1, 'text',     0.5,  0.35, 0,    0,    0, 0, 0, 0, 0, 0, 'CPU', 0.13, 1, 'center', 'middle', 'solid'),
('sps_cpu',   2, 'text',     0.5,  0.65, 0,    0,    0, 0, 0, 0, 0, 0, 'SPS', 0.10, 0, 'center', 'middle', 'solid'),
('sps_cpu',   3, 'linie', 0, 0.333, 0.1, 0.333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sps_cpu',   4, 'linie', 0, 0.667, 0.1, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── pls_ai_8 (PLS Analog Input 8-Kanal, 32x80mm, Pins links) ──
('pls_ai_8',  0,  'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('pls_ai_8',  1,  'text',     0.5,  0.42, 0,    0,    0, 0, 0, 0, 0, 0, 'AI 8', 0.08, 1, 'center', 'middle', 'solid'),
('pls_ai_8',  2,  'text',     0.5,  0.58, 0,    0,    0, 0, 0, 0, 0, 0, 'PLS',  0.06, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  3,  'linie', 0, 0.111, 0.15, 0.111, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  4,  'linie', 0, 0.222, 0.15, 0.222, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  5,  'linie', 0, 0.333, 0.15, 0.333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  6,  'linie', 0, 0.444, 0.15, 0.444, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  7,  'linie', 0, 0.556, 0.15, 0.556, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  8,  'linie', 0, 0.667, 0.15, 0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  9,  'linie', 0, 0.778, 0.15, 0.778, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ai_8',  10, 'linie', 0, 0.889, 0.15, 0.889, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── pls_ao_4 (PLS Analog Output 4-Kanal, 32x64mm, Pins rechts) ──
('pls_ao_4',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,   0.5,  0, 'center', 'middle', 'solid'),
('pls_ao_4',  1, 'text',     0.5,  0.4,  0,    0,    0, 0, 0, 0, 0, 0, 'AO 4', 0.10, 1, 'center', 'middle', 'solid'),
('pls_ao_4',  2, 'text',     0.5,  0.62, 0,    0,    0, 0, 0, 0, 0, 0, 'PLS',  0.08, 0, 'center', 'middle', 'solid'),
('pls_ao_4',  3, 'linie', 0.85, 0.2, 1.0, 0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ao_4',  4, 'linie', 0.85, 0.4, 1.0, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ao_4',  5, 'linie', 0.85, 0.6, 1.0, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('pls_ao_4',  6, 'linie', 0.85, 0.8, 1.0, 0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- KFZ-Elektrik Symbole (Kategorie 'KFZ')
-- kfz_sicherung: Flachstecksicherung 32x16mm
-- kfz_relais_4:  4-Pin-Relais (85/86/30/87) 32x48mm
-- kfz_relais_5:  5-Pin-Relais (+87a) 32x64mm
-- kfz_masse:     Fahrzeugmasse/GND 32x16mm
-- kfz_batterie:  Batterie 12V 32x16mm (2-Zell IEC-Symbol)
-- kfz_lichtmaschine: Generator/Alternator 32x16mm (Kreis+G)
-- kfz_stecker_2/3/4: KFZ-Stecker 2/3/4-polig
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('kfz_sicherung',     'Flachstecksicherung',       'KFZ', 32, 16, 'variabel', 1),
('kfz_relais_4',      'KFZ-Relais 4-polig',        'KFZ', 32, 48, 'variabel', 1),
('kfz_relais_5',      'KFZ-Relais 5-polig',        'KFZ', 32, 64, 'variabel', 1),
('kfz_masse',         'Fahrzeugmasse (GND)',        'KFZ', 32, 16, 'variabel', 1),
('kfz_batterie',      'Batterie 12V',              'KFZ', 32, 16, 'variabel', 1),
('kfz_lichtmaschine', 'Lichtmaschine (Generator)', 'KFZ', 32, 16, 'variabel', 1),
('kfz_stecker_2',     'KFZ-Stecker 2-polig',       'KFZ', 32, 32, 'variabel', 1),
('kfz_stecker_3',     'KFZ-Stecker 3-polig',       'KFZ', 32, 48, 'variabel', 1),
('kfz_stecker_4',     'KFZ-Stecker 4-polig',       'KFZ', 32, 64, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
-- kfz_sicherung: A links, B rechts
('kfz_sicherung',     'A',   0, 0.5,   -1, 0, 'neutral'),
('kfz_sicherung',     'B',   1, 0.5,    1, 0, 'neutral'),
-- kfz_relais_4: Spule 85/86, Kontakt 30/87
('kfz_relais_4',      '85',  0, 0.25,  -1, 0, 'neutral'),
('kfz_relais_4',      '86',  1, 0.25,   1, 0, 'neutral'),
('kfz_relais_4',      '30',  0, 0.75,  -1, 0, 'neutral'),
('kfz_relais_4',      '87',  1, 0.75,   1, 0, 'neutral'),
-- kfz_relais_5: Spule 85/86, Kontakt 30/87/87a
('kfz_relais_5',      '85',  0, 0.25,   -1, 0, 'neutral'),
('kfz_relais_5',      '86',  1, 0.25,    1, 0, 'neutral'),
('kfz_relais_5',      '30',  0, 0.6875, -1, 0, 'neutral'),
('kfz_relais_5',      '87',  1, 0.5625,  1, 0, 'neutral'),
('kfz_relais_5',      '87a', 1, 0.875,   1, 0, 'neutral'),
-- kfz_masse: Masse-Anschluss links
('kfz_masse',         'M',   0, 0.5,   -1, 0, 'neutral'),
-- kfz_batterie: + links, - rechts
('kfz_batterie',      '+',   0, 0.5,   -1, 0, 'neutral'),
('kfz_batterie',      '-',   1, 0.5,    1, 0, 'neutral'),
-- kfz_lichtmaschine: + links, D+ rechts
('kfz_lichtmaschine', '+',   0, 0.5,   -1, 0, 'neutral'),
('kfz_lichtmaschine', 'D+',  1, 0.5,    1, 0, 'neutral'),
-- kfz_stecker_2/3/4: Pins links
('kfz_stecker_2',     '1',   0, 0.25,  -1, 0, 'neutral'),
('kfz_stecker_2',     '2',   0, 0.75,  -1, 0, 'neutral'),
('kfz_stecker_3',     '1',   0, 0.25,  -1, 0, 'neutral'),
('kfz_stecker_3',     '2',   0, 0.5,   -1, 0, 'neutral'),
('kfz_stecker_3',     '3',   0, 0.75,  -1, 0, 'neutral'),
('kfz_stecker_4',     '1',   0, 0.1875, -1, 0, 'neutral'),
('kfz_stecker_4',     '2',   0, 0.375,  -1, 0, 'neutral'),
('kfz_stecker_4',     '3',   0, 0.5625, -1, 0, 'neutral'),
('kfz_stecker_4',     '4',   0, 0.75,   -1, 0, 'neutral');

INSERT INTO symbol_primitiv
(symbol_id, reihenfolge, typ,
 x1, y1, x2, y2, x3, y3,
 radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
 text_inhalt, schrift_relativ, schrift_fett,
 text_align, text_baseline, linienart)
VALUES
-- ── kfz_sicherung (32x16mm) ──
('kfz_sicherung', 0, 'rechteck', 0.15, 0.15, 0.85, 0.85, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_sicherung', 1, 'text',     0.5,  0.5,  0,    0,    0, 0, 0, 0, 0, 0, 'F',   0.40, 1, 'center', 'middle', 'solid'),
('kfz_sicherung', 2, 'linie',    0,    0.5,  0.15, 0.5,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_sicherung', 3, 'linie',    0.85, 0.5,  1.0,  0.5,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
-- ── kfz_relais_4 (32x48mm, Spule oben / Kontakt unten) ──
('kfz_relais_4', 0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_4', 1, 'linie',    0.15, 0.5,  0.85, 0.5,  0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_4', 2, 'text',     0.5,  0.25, 0,    0,    0, 0, 0, 0, 0, 0, 'Spule', 0.10, 0, 'center', 'middle', 'solid'),
('kfz_relais_4', 3, 'text',     0.5,  0.75, 0,    0,    0, 0, 0, 0, 0, 0, 'K4',   0.13, 1, 'center', 'middle', 'solid'),
('kfz_relais_4', 4, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_4', 5, 'linie',    0.85, 0.25, 1.0,  0.25, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_4', 6, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_4', 7, 'linie',    0.85, 0.75, 1.0,  0.75, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
-- ── kfz_relais_5 (32x64mm, 5-Pin mit 87a) ──
('kfz_relais_5', 0, 'rechteck', 0.15, 0.02,   0.85, 0.98,   0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_5', 1, 'linie',    0.15, 0.375,  0.85, 0.375,  0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_5', 2, 'text',     0.5,  0.1875, 0,    0,      0, 0, 0, 0, 0, 0, 'Spule', 0.08, 0, 'center', 'middle', 'solid'),
('kfz_relais_5', 3, 'text',     0.5,  0.6875, 0,    0,      0, 0, 0, 0, 0, 0, 'K5',   0.10, 1, 'center', 'middle', 'solid'),
('kfz_relais_5', 4, 'linie',    0,    0.25,   0.15, 0.25,   0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_5', 5, 'linie',    0.85, 0.25,   1.0,  0.25,   0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_5', 6, 'linie',    0,    0.6875, 0.15, 0.6875, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_5', 7, 'linie',    0.85, 0.5625, 1.0,  0.5625, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('kfz_relais_5', 8, 'linie',    0.85, 0.875,  1.0,  0.875,  0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
-- ── kfz_masse (32x16mm, GND-Balken: vertikal + 3 waagrechte Linien) ──
('kfz_masse', 0, 'linie', 0,    0.5, 0.25, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_masse', 1, 'linie', 0.25, 0.1, 0.25, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_masse', 2, 'linie', 0.25, 0.2, 1.0,  0.2, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_masse', 3, 'linie', 0.25, 0.5, 0.8,  0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_masse', 4, 'linie', 0.25, 0.8, 0.6,  0.8, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── kfz_batterie (32x16mm, 2-Zell IEC-Symbol) ──
('kfz_batterie', 0, 'linie', 0,    0.5, 0.25, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_batterie', 1, 'linie', 0.25, 0.1, 0.25, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_batterie', 2, 'linie', 0.42, 0.3, 0.42, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_batterie', 3, 'linie', 0.58, 0.1, 0.58, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_batterie', 4, 'linie', 0.75, 0.3, 0.75, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_batterie', 5, 'linie', 0.75, 0.5, 1.0,  0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── kfz_lichtmaschine (32x16mm, Kreis mit G) ──
('kfz_lichtmaschine', 0, 'kreis_offen', 0.5,  0.5, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_lichtmaschine', 1, 'text',        0.5,  0.5, 0, 0, 0, 0, 0,    0, 0, 0, 'G',  0.35, 1, 'center', 'middle', 'solid'),
('kfz_lichtmaschine', 2, 'linie',       0,    0.5, 0.28, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_lichtmaschine', 3, 'linie',       0.72, 0.5, 1.0,  0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── kfz_stecker_2 (32x32mm) ──
('kfz_stecker_2', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_2', 1, 'text',     0.35, 0.25, 0,    0,    0, 0, 0, 0, 0, 0, '1',  0.20, 0, 'center', 'middle', 'solid'),
('kfz_stecker_2', 2, 'text',     0.35, 0.75, 0,    0,    0, 0, 0, 0, 0, 0, '2',  0.20, 0, 'center', 'middle', 'solid'),
('kfz_stecker_2', 3, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_2', 4, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
-- ── kfz_stecker_3 (32x48mm) ──
('kfz_stecker_3', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_3', 1, 'text',     0.35, 0.25, 0,    0,    0, 0, 0, 0, 0, 0, '1',  0.13, 0, 'center', 'middle', 'solid'),
('kfz_stecker_3', 2, 'text',     0.35, 0.5,  0,    0,    0, 0, 0, 0, 0, 0, '2',  0.13, 0, 'center', 'middle', 'solid'),
('kfz_stecker_3', 3, 'text',     0.35, 0.75, 0,    0,    0, 0, 0, 0, 0, 0, '3',  0.13, 0, 'center', 'middle', 'solid'),
('kfz_stecker_3', 4, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_3', 5, 'linie',    0,    0.5,  0.15, 0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_3', 6, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
-- ── kfz_stecker_4 (32x64mm) ──
('kfz_stecker_4', 0, 'rechteck', 0.15, 0.05,   0.85, 0.95,   0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 1, 'text',     0.35, 0.1875, 0,    0,      0, 0, 0, 0, 0, 0, '1',  0.10, 0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 2, 'text',     0.35, 0.375,  0,    0,      0, 0, 0, 0, 0, 0, '2',  0.10, 0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 3, 'text',     0.35, 0.5625, 0,    0,      0, 0, 0, 0, 0, 0, '3',  0.10, 0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 4, 'text',     0.35, 0.75,   0,    0,      0, 0, 0, 0, 0, 0, '4',  0.10, 0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 5, 'linie',    0,    0.1875, 0.15, 0.1875, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 6, 'linie',    0,    0.375,  0.15, 0.375,  0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 7, 'linie',    0,    0.5625, 0.15, 0.5625, 0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_stecker_4', 8, 'linie',    0,    0.75,   0.15, 0.75,   0, 0, 0, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- Arduino Symbole (Kategorie 'Arduino')
-- ard_uno:    Arduino UNO  32x60mm  (14 links D0-D13 + 13 rechts + NC bei k=7)
-- ard_nano:   Arduino Nano 32x60mm  (14 links D0-D13 + 14 rechts)
-- ard_mega:   Arduino Mega 32x84mm  (20 links D0-D19 + 20 rechts)
-- ard_dht:    DHT Sensor   16x16mm  (3 links)
-- ard_hcsr04: HC-SR04      16x20mm  (4 links)
-- ard_pir:    PIR Sensor   16x16mm  (3 links)
-- Pin-Formel: N Pins je Seite → hoehe_mm = (N+1)*4, y_norm = k/(N+1) (4mm-Raster)
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('ard_uno',    'Arduino UNO',    'Arduino', 32, 60, 'variabel', 1),
('ard_nano',   'Arduino Nano',   'Arduino', 32, 60, 'variabel', 1),
('ard_mega',   'Arduino Mega',   'Arduino', 32, 84, 'variabel', 1),
('ard_dht',    'DHT Sensor',     'Arduino', 16, 16, 'variabel', 1),
('ard_hcsr04', 'HC-SR04 Sensor', 'Arduino', 16, 20, 'variabel', 1),
('ard_pir',    'PIR Sensor',     'Arduino', 16, 16, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
-- ard_uno: D0-D13 links (divisor=15)
('ard_uno', 'D0',  0, 0.0667, -1, 0, 'neutral'),
('ard_uno', 'D1',  0, 0.1333, -1, 0, 'neutral'),
('ard_uno', 'D2',  0, 0.2000, -1, 0, 'neutral'),
('ard_uno', 'D3',  0, 0.2667, -1, 0, 'neutral'),
('ard_uno', 'D4',  0, 0.3333, -1, 0, 'neutral'),
('ard_uno', 'D5',  0, 0.4000, -1, 0, 'neutral'),
('ard_uno', 'D6',  0, 0.4667, -1, 0, 'neutral'),
('ard_uno', 'D7',  0, 0.5333, -1, 0, 'neutral'),
('ard_uno', 'D8',  0, 0.6000, -1, 0, 'neutral'),
('ard_uno', 'D9',  0, 0.6667, -1, 0, 'neutral'),
('ard_uno', 'D10', 0, 0.7333, -1, 0, 'neutral'),
('ard_uno', 'D11', 0, 0.8000, -1, 0, 'neutral'),
('ard_uno', 'D12', 0, 0.8667, -1, 0, 'neutral'),
('ard_uno', 'D13', 0, 0.9333, -1, 0, 'neutral'),
-- ard_uno: Power+Analog rechts (NC-Luecke bei k=7, y=0.4667)
('ard_uno', 'RST',  1, 0.0667, 1, 0, 'neutral'),
('ard_uno', '3V3',  1, 0.1333, 1, 0, 'neutral'),
('ard_uno', '5V',   1, 0.2000, 1, 0, 'neutral'),
('ard_uno', 'GND',  1, 0.2667, 1, 0, 'neutral'),
('ard_uno', 'GND2', 1, 0.3333, 1, 0, 'neutral'),
('ard_uno', 'Vin',  1, 0.4000, 1, 0, 'neutral'),
('ard_uno', 'A0',   1, 0.5333, 1, 0, 'neutral'),
('ard_uno', 'A1',   1, 0.6000, 1, 0, 'neutral'),
('ard_uno', 'A2',   1, 0.6667, 1, 0, 'neutral'),
('ard_uno', 'A3',   1, 0.7333, 1, 0, 'neutral'),
('ard_uno', 'A4',   1, 0.8000, 1, 0, 'neutral'),
('ard_uno', 'A5',   1, 0.8667, 1, 0, 'neutral'),
('ard_uno', 'AREF', 1, 0.9333, 1, 0, 'neutral'),
-- ard_nano: D0-D13 links
('ard_nano', 'D0',  0, 0.0667, -1, 0, 'neutral'),
('ard_nano', 'D1',  0, 0.1333, -1, 0, 'neutral'),
('ard_nano', 'D2',  0, 0.2000, -1, 0, 'neutral'),
('ard_nano', 'D3',  0, 0.2667, -1, 0, 'neutral'),
('ard_nano', 'D4',  0, 0.3333, -1, 0, 'neutral'),
('ard_nano', 'D5',  0, 0.4000, -1, 0, 'neutral'),
('ard_nano', 'D6',  0, 0.4667, -1, 0, 'neutral'),
('ard_nano', 'D7',  0, 0.5333, -1, 0, 'neutral'),
('ard_nano', 'D8',  0, 0.6000, -1, 0, 'neutral'),
('ard_nano', 'D9',  0, 0.6667, -1, 0, 'neutral'),
('ard_nano', 'D10', 0, 0.7333, -1, 0, 'neutral'),
('ard_nano', 'D11', 0, 0.8000, -1, 0, 'neutral'),
('ard_nano', 'D12', 0, 0.8667, -1, 0, 'neutral'),
('ard_nano', 'D13', 0, 0.9333, -1, 0, 'neutral'),
-- ard_nano: Power+Analog rechts (kein NC)
('ard_nano', 'RST',  1, 0.0667, 1, 0, 'neutral'),
('ard_nano', '3V3',  1, 0.1333, 1, 0, 'neutral'),
('ard_nano', '5V',   1, 0.2000, 1, 0, 'neutral'),
('ard_nano', 'GND',  1, 0.2667, 1, 0, 'neutral'),
('ard_nano', 'GND2', 1, 0.3333, 1, 0, 'neutral'),
('ard_nano', 'Vin',  1, 0.4000, 1, 0, 'neutral'),
('ard_nano', 'A0',   1, 0.4667, 1, 0, 'neutral'),
('ard_nano', 'A1',   1, 0.5333, 1, 0, 'neutral'),
('ard_nano', 'A2',   1, 0.6000, 1, 0, 'neutral'),
('ard_nano', 'A3',   1, 0.6667, 1, 0, 'neutral'),
('ard_nano', 'A4',   1, 0.7333, 1, 0, 'neutral'),
('ard_nano', 'A5',   1, 0.8000, 1, 0, 'neutral'),
('ard_nano', 'A6',   1, 0.8667, 1, 0, 'neutral'),
('ard_nano', 'A7',   1, 0.9333, 1, 0, 'neutral'),
-- ard_mega: D0-D19 links (divisor=21)
('ard_mega', 'D0',  0, 0.0476, -1, 0, 'neutral'),
('ard_mega', 'D1',  0, 0.0952, -1, 0, 'neutral'),
('ard_mega', 'D2',  0, 0.1429, -1, 0, 'neutral'),
('ard_mega', 'D3',  0, 0.1905, -1, 0, 'neutral'),
('ard_mega', 'D4',  0, 0.2381, -1, 0, 'neutral'),
('ard_mega', 'D5',  0, 0.2857, -1, 0, 'neutral'),
('ard_mega', 'D6',  0, 0.3333, -1, 0, 'neutral'),
('ard_mega', 'D7',  0, 0.3810, -1, 0, 'neutral'),
('ard_mega', 'D8',  0, 0.4286, -1, 0, 'neutral'),
('ard_mega', 'D9',  0, 0.4762, -1, 0, 'neutral'),
('ard_mega', 'D10', 0, 0.5238, -1, 0, 'neutral'),
('ard_mega', 'D11', 0, 0.5714, -1, 0, 'neutral'),
('ard_mega', 'D12', 0, 0.6190, -1, 0, 'neutral'),
('ard_mega', 'D13', 0, 0.6667, -1, 0, 'neutral'),
('ard_mega', 'D14', 0, 0.7143, -1, 0, 'neutral'),
('ard_mega', 'D15', 0, 0.7619, -1, 0, 'neutral'),
('ard_mega', 'D16', 0, 0.8095, -1, 0, 'neutral'),
('ard_mega', 'D17', 0, 0.8571, -1, 0, 'neutral'),
('ard_mega', 'D18', 0, 0.9048, -1, 0, 'neutral'),
('ard_mega', 'D19', 0, 0.9524, -1, 0, 'neutral'),
-- ard_mega: Power+Analog rechts
('ard_mega', 'RST',  1, 0.0476, 1, 0, 'neutral'),
('ard_mega', '5V',   1, 0.0952, 1, 0, 'neutral'),
('ard_mega', '3V3',  1, 0.1429, 1, 0, 'neutral'),
('ard_mega', 'GND',  1, 0.1905, 1, 0, 'neutral'),
('ard_mega', 'GND2', 1, 0.2381, 1, 0, 'neutral'),
('ard_mega', 'Vin',  1, 0.2857, 1, 0, 'neutral'),
('ard_mega', 'A0',   1, 0.3333, 1, 0, 'neutral'),
('ard_mega', 'A1',   1, 0.3810, 1, 0, 'neutral'),
('ard_mega', 'A2',   1, 0.4286, 1, 0, 'neutral'),
('ard_mega', 'A3',   1, 0.4762, 1, 0, 'neutral'),
('ard_mega', 'A4',   1, 0.5238, 1, 0, 'neutral'),
('ard_mega', 'A5',   1, 0.5714, 1, 0, 'neutral'),
('ard_mega', 'A6',   1, 0.6190, 1, 0, 'neutral'),
('ard_mega', 'A7',   1, 0.6667, 1, 0, 'neutral'),
('ard_mega', 'A8',   1, 0.7143, 1, 0, 'neutral'),
('ard_mega', 'A9',   1, 0.7619, 1, 0, 'neutral'),
('ard_mega', 'A10',  1, 0.8095, 1, 0, 'neutral'),
('ard_mega', 'A11',  1, 0.8571, 1, 0, 'neutral'),
('ard_mega', 'A12',  1, 0.9048, 1, 0, 'neutral'),
('ard_mega', 'A13',  1, 0.9524, 1, 0, 'neutral'),
-- Sensoren: alle Pins links
('ard_dht',    'VCC',  0, 0.25, -1, 0, 'neutral'),
('ard_dht',    'DATA', 0, 0.50, -1, 0, 'neutral'),
('ard_dht',    'GND',  0, 0.75, -1, 0, 'neutral'),
('ard_hcsr04', 'VCC',  0, 0.20, -1, 0, 'neutral'),
('ard_hcsr04', 'TRIG', 0, 0.40, -1, 0, 'neutral'),
('ard_hcsr04', 'ECHO', 0, 0.60, -1, 0, 'neutral'),
('ard_hcsr04', 'GND',  0, 0.80, -1, 0, 'neutral'),
('ard_pir',    'VCC',  0, 0.25, -1, 0, 'neutral'),
('ard_pir',    'OUT',  0, 0.50, -1, 0, 'neutral'),
('ard_pir',    'GND',  0, 0.75, -1, 0, 'neutral');

INSERT INTO symbol_primitiv
    (symbol_id, reihenfolge, typ,
     x1, y1, x2, y2, x3, y3,
     radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
     text_inhalt, schrift_relativ, schrift_fett,
     text_align, text_baseline, linienart)
VALUES
-- ── ard_uno (32x60mm, 14 links + 13 rechts, NC-Luecke rechts k=7) ──
('ard_uno',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,      0.5,   0, 'center', 'middle', 'solid'),
('ard_uno',  1, 'text',     0.5,  0.43, 0,    0,    0, 0, 0, 0, 0, 0, 'Arduino', 0.055, 0, 'center', 'middle', 'solid'),
('ard_uno',  2, 'text',     0.5,  0.55, 0,    0,    0, 0, 0, 0, 0, 0, 'UNO',     0.09,  1, 'center', 'middle', 'solid'),
('ard_uno',  3, 'linie', 0, 0.0667, 0.15, 0.0667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno',  4, 'linie', 0, 0.1333, 0.15, 0.1333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno',  5, 'linie', 0, 0.2000, 0.15, 0.2000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno',  6, 'linie', 0, 0.2667, 0.15, 0.2667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno',  7, 'linie', 0, 0.3333, 0.15, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno',  8, 'linie', 0, 0.4000, 0.15, 0.4000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno',  9, 'linie', 0, 0.4667, 0.15, 0.4667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 10, 'linie', 0, 0.5333, 0.15, 0.5333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 11, 'linie', 0, 0.6000, 0.15, 0.6000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 12, 'linie', 0, 0.6667, 0.15, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 13, 'linie', 0, 0.7333, 0.15, 0.7333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 14, 'linie', 0, 0.8000, 0.15, 0.8000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 15, 'linie', 0, 0.8667, 0.15, 0.8667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 16, 'linie', 0, 0.9333, 0.15, 0.9333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 17, 'linie', 0.85, 0.0667, 1.0, 0.0667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 18, 'linie', 0.85, 0.1333, 1.0, 0.1333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 19, 'linie', 0.85, 0.2000, 1.0, 0.2000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 20, 'linie', 0.85, 0.2667, 1.0, 0.2667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 21, 'linie', 0.85, 0.3333, 1.0, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 22, 'linie', 0.85, 0.4000, 1.0, 0.4000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 23, 'linie', 0.85, 0.5333, 1.0, 0.5333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 24, 'linie', 0.85, 0.6000, 1.0, 0.6000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 25, 'linie', 0.85, 0.6667, 1.0, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 26, 'linie', 0.85, 0.7333, 1.0, 0.7333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 27, 'linie', 0.85, 0.8000, 1.0, 0.8000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 28, 'linie', 0.85, 0.8667, 1.0, 0.8667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_uno', 29, 'linie', 0.85, 0.9333, 1.0, 0.9333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── ard_nano (32x60mm, 14 links + 14 rechts) ──
('ard_nano',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,      0.5,   0, 'center', 'middle', 'solid'),
('ard_nano',  1, 'text',     0.5,  0.43, 0,    0,    0, 0, 0, 0, 0, 0, 'Arduino', 0.055, 0, 'center', 'middle', 'solid'),
('ard_nano',  2, 'text',     0.5,  0.55, 0,    0,    0, 0, 0, 0, 0, 0, 'NANO',    0.09,  1, 'center', 'middle', 'solid'),
('ard_nano',  3, 'linie', 0, 0.0667, 0.15, 0.0667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano',  4, 'linie', 0, 0.1333, 0.15, 0.1333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano',  5, 'linie', 0, 0.2000, 0.15, 0.2000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano',  6, 'linie', 0, 0.2667, 0.15, 0.2667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano',  7, 'linie', 0, 0.3333, 0.15, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano',  8, 'linie', 0, 0.4000, 0.15, 0.4000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano',  9, 'linie', 0, 0.4667, 0.15, 0.4667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 10, 'linie', 0, 0.5333, 0.15, 0.5333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 11, 'linie', 0, 0.6000, 0.15, 0.6000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 12, 'linie', 0, 0.6667, 0.15, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 13, 'linie', 0, 0.7333, 0.15, 0.7333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 14, 'linie', 0, 0.8000, 0.15, 0.8000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 15, 'linie', 0, 0.8667, 0.15, 0.8667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 16, 'linie', 0, 0.9333, 0.15, 0.9333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 17, 'linie', 0.85, 0.0667, 1.0, 0.0667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 18, 'linie', 0.85, 0.1333, 1.0, 0.1333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 19, 'linie', 0.85, 0.2000, 1.0, 0.2000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 20, 'linie', 0.85, 0.2667, 1.0, 0.2667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 21, 'linie', 0.85, 0.3333, 1.0, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 22, 'linie', 0.85, 0.4000, 1.0, 0.4000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 23, 'linie', 0.85, 0.4667, 1.0, 0.4667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 24, 'linie', 0.85, 0.5333, 1.0, 0.5333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 25, 'linie', 0.85, 0.6000, 1.0, 0.6000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 26, 'linie', 0.85, 0.6667, 1.0, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 27, 'linie', 0.85, 0.7333, 1.0, 0.7333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 28, 'linie', 0.85, 0.8000, 1.0, 0.8000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 29, 'linie', 0.85, 0.8667, 1.0, 0.8667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_nano', 30, 'linie', 0.85, 0.9333, 1.0, 0.9333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── ard_mega (32x84mm, 20 links + 20 rechts) ──
('ard_mega',  0, 'rechteck', 0.15, 0.02, 0.85, 0.98, 0, 0, 0, 0, 0, 0, NULL,      0.5,   0, 'center', 'middle', 'solid'),
('ard_mega',  1, 'text',     0.5,  0.44, 0,    0,    0, 0, 0, 0, 0, 0, 'Arduino', 0.055, 0, 'center', 'middle', 'solid'),
('ard_mega',  2, 'text',     0.5,  0.54, 0,    0,    0, 0, 0, 0, 0, 0, 'MEGA',    0.075, 1, 'center', 'middle', 'solid'),
('ard_mega',  3, 'linie', 0, 0.0476, 0.15, 0.0476, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega',  4, 'linie', 0, 0.0952, 0.15, 0.0952, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega',  5, 'linie', 0, 0.1429, 0.15, 0.1429, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega',  6, 'linie', 0, 0.1905, 0.15, 0.1905, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega',  7, 'linie', 0, 0.2381, 0.15, 0.2381, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega',  8, 'linie', 0, 0.2857, 0.15, 0.2857, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega',  9, 'linie', 0, 0.3333, 0.15, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 10, 'linie', 0, 0.3810, 0.15, 0.3810, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 11, 'linie', 0, 0.4286, 0.15, 0.4286, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 12, 'linie', 0, 0.4762, 0.15, 0.4762, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 13, 'linie', 0, 0.5238, 0.15, 0.5238, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 14, 'linie', 0, 0.5714, 0.15, 0.5714, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 15, 'linie', 0, 0.6190, 0.15, 0.6190, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 16, 'linie', 0, 0.6667, 0.15, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 17, 'linie', 0, 0.7143, 0.15, 0.7143, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 18, 'linie', 0, 0.7619, 0.15, 0.7619, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 19, 'linie', 0, 0.8095, 0.15, 0.8095, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 20, 'linie', 0, 0.8571, 0.15, 0.8571, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 21, 'linie', 0, 0.9048, 0.15, 0.9048, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 22, 'linie', 0, 0.9524, 0.15, 0.9524, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 23, 'linie', 0.85, 0.0476, 1.0, 0.0476, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 24, 'linie', 0.85, 0.0952, 1.0, 0.0952, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 25, 'linie', 0.85, 0.1429, 1.0, 0.1429, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 26, 'linie', 0.85, 0.1905, 1.0, 0.1905, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 27, 'linie', 0.85, 0.2381, 1.0, 0.2381, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 28, 'linie', 0.85, 0.2857, 1.0, 0.2857, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 29, 'linie', 0.85, 0.3333, 1.0, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 30, 'linie', 0.85, 0.3810, 1.0, 0.3810, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 31, 'linie', 0.85, 0.4286, 1.0, 0.4286, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 32, 'linie', 0.85, 0.4762, 1.0, 0.4762, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 33, 'linie', 0.85, 0.5238, 1.0, 0.5238, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 34, 'linie', 0.85, 0.5714, 1.0, 0.5714, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 35, 'linie', 0.85, 0.6190, 1.0, 0.6190, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 36, 'linie', 0.85, 0.6667, 1.0, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 37, 'linie', 0.85, 0.7143, 1.0, 0.7143, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 38, 'linie', 0.85, 0.7619, 1.0, 0.7619, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 39, 'linie', 0.85, 0.8095, 1.0, 0.8095, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 40, 'linie', 0.85, 0.8571, 1.0, 0.8571, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 41, 'linie', 0.85, 0.9048, 1.0, 0.9048, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_mega', 42, 'linie', 0.85, 0.9524, 1.0, 0.9524, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── ard_dht (16x16mm, 3 Pins links) ──
('ard_dht', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('ard_dht', 1, 'text',     0.5,  0.15, 0,    0,    0, 0, 0, 0, 0, 0, 'DHT', 0.15, 1, 'center', 'middle', 'solid'),
('ard_dht', 2, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_dht', 3, 'linie', 0, 0.50, 0.15, 0.50, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_dht', 4, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_dht', 5, 'text',  0.2, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 'VCC',  0.11, 0, 'left', 'middle', 'solid'),
('ard_dht', 6, 'text',  0.2, 0.50, 0, 0, 0, 0, 0, 0, 0, 0, 'DATA', 0.11, 0, 'left', 'middle', 'solid'),
('ard_dht', 7, 'text',  0.2, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, 'GND',  0.11, 0, 'left', 'middle', 'solid'),
-- ── ard_hcsr04 (16x20mm, 4 Pins links) ──
('ard_hcsr04', 0, 'rechteck', 0.15, 0.03, 0.85, 0.97, 0, 0, 0, 0, 0, 0, NULL,      0.5,  0, 'center', 'middle', 'solid'),
('ard_hcsr04', 1, 'text',     0.5,  0.12, 0,    0,    0, 0, 0, 0, 0, 0, 'HC-SR04', 0.10, 1, 'center', 'middle', 'solid'),
('ard_hcsr04', 2, 'linie', 0, 0.20, 0.15, 0.20, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 3, 'linie', 0, 0.40, 0.15, 0.40, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 4, 'linie', 0, 0.60, 0.15, 0.60, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 5, 'linie', 0, 0.80, 0.15, 0.80, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 6, 'text',  0.2, 0.20, 0, 0, 0, 0, 0, 0, 0, 0, 'VCC',  0.09, 0, 'left', 'middle', 'solid'),
('ard_hcsr04', 7, 'text',  0.2, 0.40, 0, 0, 0, 0, 0, 0, 0, 0, 'TRIG', 0.09, 0, 'left', 'middle', 'solid'),
('ard_hcsr04', 8, 'text',  0.2, 0.60, 0, 0, 0, 0, 0, 0, 0, 0, 'ECHO', 0.09, 0, 'left', 'middle', 'solid'),
('ard_hcsr04', 9, 'text',  0.2, 0.80, 0, 0, 0, 0, 0, 0, 0, 0, 'GND',  0.09, 0, 'left', 'middle', 'solid'),
-- ── ard_pir (16x16mm, 3 Pins links) ──
('ard_pir', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('ard_pir', 1, 'text',     0.5,  0.15, 0,    0,    0, 0, 0, 0, 0, 0, 'PIR', 0.15, 1, 'center', 'middle', 'solid'),
('ard_pir', 2, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_pir', 3, 'linie', 0, 0.50, 0.15, 0.50, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_pir', 4, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_pir', 5, 'text',  0.2, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 'VCC', 0.11, 0, 'left', 'middle', 'solid'),
('ard_pir', 6, 'text',  0.2, 0.50, 0, 0, 0, 0, 0, 0, 0, 0, 'OUT', 0.11, 0, 'left', 'middle', 'solid'),
('ard_pir', 7, 'text',  0.2, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, 'GND', 0.11, 0, 'left', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- Sensoren (Kategorie 'Sensoren')
-- 3-Draht PNP (L+/M/Q): induktiv, kapazitiv, optisch, ultraschall, druck – 32x16mm
-- 2-Draht: sensor_temp (PT100) – 16x16mm
-- Pin-Positionen: L+ y=0.25 (4mm), M y=0.75 (12mm), Q y=0.5 (8mm) → 4mm-Raster
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('sensor_induktiv',   'Induktiver Näherungsschalter',  'Sensoren', 32, 16, 'variabel', 1),
('sensor_kapazitiv',  'Kapazitiver Näherungsschalter', 'Sensoren', 32, 16, 'variabel', 1),
('sensor_optisch',    'Optischer Sensor',              'Sensoren', 32, 16, 'variabel', 1),
('sensor_ultraschall','Ultraschallsensor',             'Sensoren', 32, 16, 'variabel', 1),
('sensor_druck',      'Drucksensor',                   'Sensoren', 32, 16, 'variabel', 1),
('sensor_temp',       'Temperatursensor (PT100)',       'Sensoren', 16, 16, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('sensor_induktiv',   'L+', 0, 0.25, -1, 0, 'power'),
('sensor_induktiv',   'M',  0, 0.75, -1, 0, 'power'),
('sensor_induktiv',   'Q',  1, 0.5,   1, 0, 'neutral'),
('sensor_kapazitiv',  'L+', 0, 0.25, -1, 0, 'power'),
('sensor_kapazitiv',  'M',  0, 0.75, -1, 0, 'power'),
('sensor_kapazitiv',  'Q',  1, 0.5,   1, 0, 'neutral'),
('sensor_optisch',    'L+', 0, 0.25, -1, 0, 'power'),
('sensor_optisch',    'M',  0, 0.75, -1, 0, 'power'),
('sensor_optisch',    'Q',  1, 0.5,   1, 0, 'neutral'),
('sensor_ultraschall','L+', 0, 0.25, -1, 0, 'power'),
('sensor_ultraschall','M',  0, 0.75, -1, 0, 'power'),
('sensor_ultraschall','Q',  1, 0.5,   1, 0, 'neutral'),
('sensor_druck',      'L+', 0, 0.25, -1, 0, 'power'),
('sensor_druck',      'M',  0, 0.75, -1, 0, 'power'),
('sensor_druck',      'Q',  1, 0.5,   1, 0, 'neutral'),
('sensor_temp',       '1',  0, 0.5,  -1, 0, 'neutral'),
('sensor_temp',       '2',  1, 0.5,   1, 0, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
-- sensor_induktiv: Rechteck + Pinleiter + Label + 3 Spulenbögen
('sensor_induktiv', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0,     0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_induktiv', 1, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0,     0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_induktiv', 2, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0,     0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_induktiv', 3, 'linie',    0.85, 0.5,  1.0,  0.5,  0, 0, 0,     0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_induktiv', 4, 'text',     0.5,  0.22, 0,    0,    0, 0, 0,     0,   0, 0, 'IND', 0.16, 1, 'center', 'middle', 'solid'),
('sensor_induktiv', 5, 'bogen',    0.33, 0.70, 0,    0,    0, 0, 0.065, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sensor_induktiv', 6, 'bogen',    0.46, 0.70, 0,    0,    0, 0, 0.065, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sensor_induktiv', 7, 'bogen',    0.59, 0.70, 0,    0,    0, 0, 0.065, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- sensor_kapazitiv: Rechteck + Pinleiter + Label + 2 Kondensatorplatten
('sensor_kapazitiv', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_kapazitiv', 1, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_kapazitiv', 2, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_kapazitiv', 3, 'linie',    0.85, 0.5,  1.0,  0.5,  0, 0, 0, 0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_kapazitiv', 4, 'text',     0.5,  0.22, 0,    0,    0, 0, 0, 0,   0, 0, 'CAP', 0.16, 1, 'center', 'middle', 'solid'),
('sensor_kapazitiv', 5, 'linie',    0.25, 0.57, 0.75, 0.57, 0, 0, 0, 0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_kapazitiv', 6, 'linie',    0.25, 0.71, 0.75, 0.71, 0, 0, 0, 0,   0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
-- sensor_optisch: Rechteck + Pinleiter + Label + Kreis (LED) + 3 Lichtstrahlen
('sensor_optisch', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 1, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 2, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 3, 'linie',    0.85, 0.5,  1.0,  0.5,  0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 4, 'text',     0.5,  0.22, 0,    0,    0, 0, 0,    0, 0, 0, 'OPT', 0.16, 1, 'center', 'middle', 'solid'),
('sensor_optisch', 5, 'kreis',    0.36, 0.67, 0,    0,    0, 0, 0.06, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 6, 'linie',    0.43, 0.57, 0.65, 0.47, 0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 7, 'linie',    0.43, 0.67, 0.65, 0.67, 0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_optisch', 8, 'linie',    0.43, 0.77, 0.65, 0.87, 0, 0, 0,    0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
-- sensor_ultraschall: Rechteck + Pinleiter + Label + 3 konzentrische Schallwellenbögen
('sensor_ultraschall', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0,    0,   0,  0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_ultraschall', 1, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0,    0,   0,  0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_ultraschall', 2, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0,    0,   0,  0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_ultraschall', 3, 'linie',    0.85, 0.5,  1.0,  0.5,  0, 0, 0,    0,   0,  0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_ultraschall', 4, 'text',     0.5,  0.22, 0,    0,    0, 0, 0,    0,   0,  0, 'ULT', 0.16, 1, 'center', 'middle', 'solid'),
('sensor_ultraschall', 5, 'bogen',    0.50, 0.65, 0,    0,    0, 0, 0.05, 270, 90, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_ultraschall', 6, 'bogen',    0.47, 0.65, 0,    0,    0, 0, 0.09, 270, 90, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_ultraschall', 7, 'bogen',    0.44, 0.65, 0,    0,    0, 0, 0.13, 270, 90, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
-- sensor_druck: Rechteck + Pinleiter + Label + Dreieck (Pfeil aufwärts)
('sensor_druck', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sensor_druck', 1, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sensor_druck', 2, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sensor_druck', 3, 'linie',    0.85, 0.5,  1.0,  0.5,  0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sensor_druck', 4, 'text',     0.5,  0.20, 0,    0,    0, 0, 0, 0, 0, 0, 'DRUCK', 0.11, 1, 'center', 'middle', 'solid'),
('sensor_druck', 5, 'linie',    0.50, 0.38, 0.37, 0.80, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sensor_druck', 6, 'linie',    0.50, 0.38, 0.63, 0.80, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
('sensor_druck', 7, 'linie',    0.37, 0.80, 0.63, 0.80, 0, 0, 0, 0, 0, 0, NULL,    0.5,  0, 'center', 'middle', 'solid'),
-- sensor_temp (16x16mm): Rechteck + Pinleiter + "PT" + "100"
('sensor_temp', 0, 'rechteck', 0.1,  0.1,  0.9,  0.9,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_temp', 1, 'linie',    0,    0.5,  0.1,  0.5,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_temp', 2, 'linie',    0.9,  0.5,  1.0,  0.5,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_temp', 3, 'text',     0.5,  0.35, 0,    0,    0, 0, 0, 0, 0, 0, 'PT',  0.22, 1, 'center', 'middle', 'solid'),
('sensor_temp', 4, 'text',     0.5,  0.65, 0,    0,    0, 0, 0, 0, 0, 0, '100', 0.18, 0, 'center', 'middle', 'solid');
