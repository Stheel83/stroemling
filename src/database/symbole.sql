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
('motor_dc',        'Gleichstrommotor',        'Antriebe',     32, 16, 'verbraucher', 1),
('spule',           'Spule / Relais',          'Antriebe',     16, 16, 'verbraucher', 1),
('spule_ansi',      'Coil / Relay (ANSI)',     'Antriebe',     32, 16, 'verbraucher', 1),
('lampe',           'Lampe',                   'Signalgeräte', 32, 16, 'verbraucher', 1),
('hupe',            'Hupe / Klingel',          'Signalgeräte', 32, 16, 'verbraucher', 1),
('summer',          'Summer',                  'Signalgeräte', 32, 16, 'verbraucher', 1),
('trafo',           'Transformator',           'Antriebe',     32, 32, 'verbraucher', 1),
('netzteil',        'Netzteil',                'Antriebe',     32, 32, 'verbraucher', 1),
('widerstand_iec',  'Widerstand (IEC)',        'Passive',      32, 16, 'verbraucher', 1),
('widerstand_ansi', 'Resistor (ANSI)',         'Passive',      32, 16, 'verbraucher', 1),
('kondensator',     'Kondensator',             'Passive',      32, 16, 'verbraucher', 1),
('diode',           'Diode',                   'Passive',      32, 16, 'durchleiter', 1),
('klemme',          'Klemme',                  'Anschlüsse',   16, 16, 'durchleiter', 1),
('stecker',         'Stecker',                 'Anschlüsse',   16, 16, 'durchleiter', 1),
('buchse',          'Buchse',                  'Anschlüsse',   16, 16, 'durchleiter', 1),
('winkel',          'Winkel',                  'Verbindungen',  4,  4, 'durchleiter', 1),
('treffpunkt',      'Treffpunkt T',            'Verbindungen', 16, 16, 'durchleiter', 1),
('treffpunkt_l',    'Treffpunkt L',            'Verbindungen', 16, 16, 'durchleiter', 1),
('geraeteanschluss','Geräteanschluss',         'Verbindungen',  8,  8, 'variabel',    1),
('unterbrechung',   'Unterbrechung',           'Verbindungen', 16, 16, 'trenner',     1),
('querverweis',     'Querverweis',             'Verbindungen', 16, 16, 'durchleiter', 1),
('aderdefinition',  'Aderdefinition',          'Verbindungen', 4, 4, 'durchleiter', 1),
('klemme_anschluss','Klemmenanschluss',        'Verbindungen',  8,  8, 'durchleiter', 1),
('potenzial',       'Potenzialpunkt',          'Verbindungen',  8,  8, 'quelle',      1),
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
-- motor_dc (Permanentmagnet, 2 Anker-Anschlüsse)
('motor_dc',        'A1',  0,    0.5,  -1,  0, 'power'),
('motor_dc',        'A2',  1,    0.5,   1,  0, 'power'),
-- spule / spule_ansi
('spule',           'A1',  0.5,  0,    0,  -1, 'power'),
('spule',           'A2',  0.5,  1,    0,   1, 'power'),
('spule_ansi',      '1',   0,    0.5,  -1,  0, 'power'),
('spule_ansi',      '2',   1,    0.5,   1,  0, 'power'),
-- lampe / hupe / summer
('lampe',           '1',   0.25, 0.5,  -1,  0, 'neutral'),
('lampe',           '2',   0.75, 0.5,   1,  0, 'neutral'),
('hupe',            '1',   0,    0.5,  -1,  0, 'neutral'),
('hupe',            '2',   1,    0.5,   1,  0, 'neutral'),
('summer',          '1',   0,    0.5,  -1,  0, 'neutral'),
('summer',          '2',   1,    0.5,   1,  0, 'neutral'),
-- trafo
('trafo',           '1',   0,    0.25, -1,  0, 'power'),
('trafo',           '2',   0,    0.75, -1,  0, 'power'),
('trafo',           '3',   1,    0.25,  1,  0, 'power'),
('trafo',           '4',   1,    0.75,  1,  0, 'power'),
-- netzteil (Eingang L/N links, Ausgang +/- rechts – Namen frei umbenennbar
-- über die Pin-Bezeichnungen im EP, da kein Bauteil zugeordnet ist)
('netzteil',        'L',   0,    0.25, -1,  0, 'power'),
('netzteil',        'N',   0,    0.75, -1,  0, 'n'),
('netzteil',        '+',   1,    0.25,  1,  0, 'dc_plus'),
('netzteil',        '-',   1,    0.75,  1,  0, 'dc_minus'),
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
('klemme',          '1',   0.25, 0.5,  -1,  0, 'neutral'),
('klemme',          '2',   0.75, 0.5,   1,  0, 'neutral'),
('stecker',         '1',   0.25, 0.5,  -1,  0, 'neutral'),
('stecker',         '2',   0.75, 0.5,   1,  0, 'neutral'),
('buchse',          '1',   0.25, 0.5,  -1,  0, 'neutral'),
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

-- ── knoten_gruppe (NETZ-MEHRPOL-01) ────────────────────────────
-- Default 0 (alle obigen INSERTs) = alle Pins eines Symbols sind EIN
-- gemeinsamer elektrischer Knoten (korrekt für Durchleiter mit einem Pfad
-- wie Schließer/Sicherung und echte Sammelpunkte wie Treffpunkt). Bei Motor
-- (3 galvanisch getrennte Phasenanschlüsse) und Trafo (4 Wicklungsenden,
-- jedes für sich ein eigener Knoten wie bei einem Widerstand – auch die
-- beiden Enden EINER Wicklung sind nicht derselbe Knoten) sind das mehrere
-- Knoten – daher hier explizit auseinandergezogen, sonst verschmilzt die
-- Netzberechnung z.B. drei an denselben Motor angeschlossene Potenziale
-- fälschlich zu einem Netz.
--
-- NETZ-MEHRPOL-02 Teil A (Jul 2026): dieselbe Korrektur für die übrigen
-- 2+Pin-Verbraucher-Symbole nachgezogen — jeder Pin ein eigener Knoten,
-- da bei jedem Verbraucher Strom hindurchfließt statt durchgeleitet zu
-- werden (Anschlüsse sind per Definition unterschiedliche Potenziale).
-- `brueckengleichrichter` hat 4 Anschlüsse (2 AC-Eingänge + 2 DC-Ausgänge),
-- keiner davon ist intern direkt mit einem anderen verbunden (Gleichrichter-
-- Brücke, nur über Dioden) — analog zu Trafo alle vier eigene Knoten.
-- Teil B (~30 `rolle='variabel'`-Arduino/SPS/KFZ/Sensor-Symbole) bewusst
-- weiterhin zurückgestellt — braucht pinweise Prüfung realer Pinbelegungen
-- (z.B. mehrere GND-Pins, die tatsächlich EIN Knoten sind), keine
-- Blanket-Regel möglich. Siehe konzept/technik/51_netz_unionfind_mehrpol_debug.md §6.
UPDATE symbol_pin SET knoten_gruppe = 0 WHERE symbol_id = 'motor' AND name = 'U';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'motor' AND name = 'V';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'motor' AND name = 'W';
UPDATE symbol_pin SET knoten_gruppe = 0 WHERE symbol_id = 'trafo' AND name = '1';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'trafo' AND name = '2';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'trafo' AND name = '3';
UPDATE symbol_pin SET knoten_gruppe = 3 WHERE symbol_id = 'trafo' AND name = '4';
-- motor_dc: A1 bleibt Default 0, A2 eigener Knoten (2 galvanisch getrennte
-- Anker-Anschlüsse, wie bei jedem anderen 2-Pol-Verbraucher).
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'motor_dc' AND name = 'A2';
-- NETZ-MEHRPOL-02 Teil A: übrige 2-Pol-Verbraucher (erster Pin bleibt Default 0)
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'lampe'           AND name = '2';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'hupe'            AND name = '2';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'summer'          AND name = '2';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'widerstand_iec'  AND name = '2';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'widerstand_ansi' AND name = '2';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'kondensator'     AND name = '-';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'spule'           AND name = 'A2';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'spule_ansi'      AND name = '2';
-- brueckengleichrichter: alle 4 Anschlüsse eigene Knoten (~1 bleibt Default 0)
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'brueckengleichrichter' AND name = '~2';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'brueckengleichrichter' AND name = '+';
UPDATE symbol_pin SET knoten_gruppe = 3 WHERE symbol_id = 'brueckengleichrichter' AND name = '-';
-- netzteil: alle 4 Anschlüsse eigene Knoten (Eingang/Ausgang galvanisch
-- getrennt, wie Trafo/Brückengleichrichter) — L bleibt Default 0.
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'netzteil' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'netzteil' AND name = '+';
UPDATE symbol_pin SET knoten_gruppe = 3 WHERE symbol_id = 'netzteil' AND name = '-';
-- netzteil: gemischte Rolle je Pin (NETZTEIL-ROLLE-01) — AC-Eingang (L/N)
-- verbraucht, DC-Ausgang (+/-) ist Quelle mit eigenem Signaltyp (dc_plus/dc_minus)
UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'netzteil' AND name IN ('L', 'N');
UPDATE symbol_pin SET rolle = 'quelle'      WHERE symbol_id = 'netzteil' AND name IN ('+', '-');

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

-- ── Sicherung ── (v87: durchgehende Linie statt zwei Segmente)
('sicherung',  0, 'linie',          0,     0.5,  1.0,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherung',  1, 'rechteck',       0.25,  0.21, 0.75,  0.79, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

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

-- ── Motor DC (Permanentmagnet) – Kreis mittig, Gleichstromzeichen (IEC 60417-5031-2:
--    durchgezogene Linie über gestrichelter Linie) statt "3~" ──
('motor_dc',   0, 'linie',          0,     0.5,  0.2,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor_dc',   1, 'linie',          0.8,   0.5,  1,     0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor_dc',   2, 'kreis_offen',    0.5,   0.5,  0,     0,    0, 0, 0.3,  0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor_dc',   3, 'text',           0.5,   0.40, 0,     0,    0, 0, 0,    0,   0,   0, 'M',  0.28,1, 'center', 'middle', 'solid'),
('motor_dc',   4, 'linie',          0.36,  0.585,0.64,  0.585,0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('motor_dc',   5, 'linie',          0.36,  0.65, 0.64,  0.65, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'dash'),

-- ── Spule IEC (A1 oben, A2 unten) ──
('spule',      0, 'linie',          0.5,   0,    0.5,   0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule',      1, 'linie',          0.5,   0.75, 0.5,   1,    0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule',      2, 'rechteck',       0.0,   0.25, 1.0,   0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Spule ANSI ──
('spule_ansi', 0, 'linie',          0,     0.5,  0.2,   0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 1, 'linie',          0.8,   0.5,  1,     0.5,  0, 0, 0,     0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 2, 'bogen',          0.275, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 3, 'bogen',          0.425, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 4, 'bogen',          0.575, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('spule_ansi', 5, 'bogen',          0.725, 0.5,  0,     0,    0, 0, 0.075, 180, 360,  0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Lampe ──
('lampe',      0, 'linie',          0.25,  0.5,  0.357, 0.5,  0, 0, 0,    0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),
('lampe',      1, 'linie',          0.643, 0.5,  0.75,  0.5,  0, 0, 0,    0,   0,   0, NULL,  0.5, 0, 'center', 'middle', 'solid'),
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

-- ── Netzteil – bewusst leerer Rechteck-Block ohne festen Text, damit
--    Eingangs-/Ausgangsspannung frei über die Pin-Bezeichnungen im EP
--    beschriftet werden kann (L/N/+/- sind nur Vorbelegung) ──
('netzteil',   0, 'rechteck',       0.15,  0.15, 0.85,  0.85, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('netzteil',   1, 'linie',          0,     0.25, 0.15,  0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('netzteil',   2, 'linie',          0,     0.75, 0.15,  0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('netzteil',   3, 'linie',          0.85,  0.25, 1,     0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('netzteil',   4, 'linie',          0.85,  0.75, 1,     0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

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
('klemme',     0, 'linie',          0.25,  0.5,  0.45,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('klemme',     1, 'linie',          0.55,  0.5,  0.75,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('klemme',     2, 'kreis_offen',    0.5,   0.5,  0,     0,    0, 0, 0.05, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Stecker ──
('stecker',    0, 'linie',          0.25,  0.5,  0.45,  0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('stecker',    1, 'rechteck',       0.45,  0.45, 0.75,  0.55, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Buchse ──
('buchse',     0, 'linie',          0.25,  0.5,  0.5,   0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
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

-- ── Geräteanschluss (8x8mm) ──
('geraeteanschluss', 0, 'linie',       0.5,  0.5,  1,    0.5,  0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('geraeteanschluss', 1, 'kreis_offen', 0.25, 0.5,  0,    0,    0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

-- ── Potenzialpunkt (8x8mm) ──
('potenzial',  0, 'linie',          0.5,  0.5,  1,    0.5,  0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('potenzial',  1, 'kreis_gefuellt', 0.25, 0.5,  0,    0,    0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

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
('klemme_anschluss', 0, 'linie',       0.5,  0,    0.5,  0.25,  0, 0, 0, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
('klemme_anschluss', 1, 'kreis_offen', 0.5,  0.5,  0,    0,     0, 0, 0.25, 0, 360, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'),

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

-- ── Isoliert gelegte Ader: Linie + abgerundete Aderspitze ──
-- Bei 0°: ──) Pin links, offenes Leitungsende rechts (wie Nutzer-Kopie)
('isoliert_gelegte_ader', 0, 'linie', 0,       0.5,     0.65625, 0.5,     0, 0, 0,                    0,                  0,                  0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('isoliert_gelegte_ader', 1, 'bogen', 0.6875,  0.4375,  0,       0,       0, 0, 0.069877124296868431, 206.56505117707798, 116.56505117707799, 0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
('isoliert_gelegte_ader', 2, 'bogen', 0.53125, 0.46875, 0,       0,       0, 0, 0.15625,              180,                180,                0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
('isoliert_gelegte_ader', 3, 'linie', 0.5,     0.46875, 0.40625, 0.46875, 0, 0, 0,                    0,                  0,                  0, NULL, 0.15, 0, 'center', 'middle', 'solid'),
('isoliert_gelegte_ader', 4, 'bogen', 0.46875, 0.25,    0,       0,       0, 0, 0.22097086912079608,  45,                 81.869897645844034, 0, NULL, 0.15, 0, 'center', 'middle', 'solid');

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
-- sps_di_8: 8 Eingaenge links (72mm, Divisor=9, Schritt=8mm)
('sps_di_8',  'K0', 0, 0.111111, -1, 0, 'neutral'),
('sps_di_8',  'K1', 0, 0.222222, -1, 0, 'neutral'),
('sps_di_8',  'K2', 0, 0.333333, -1, 0, 'neutral'),
('sps_di_8',  'K3', 0, 0.444444, -1, 0, 'neutral'),
('sps_di_8',  'K4', 0, 0.555556, -1, 0, 'neutral'),
('sps_di_8',  'K5', 0, 0.666667, -1, 0, 'neutral'),
('sps_di_8',  'K6', 0, 0.777778, -1, 0, 'neutral'),
('sps_di_8',  'K7', 0, 0.888889, -1, 0, 'neutral'),
-- sps_di_16: 16 Eingaenge links (136mm, Divisor=17, Schritt=8mm)
('sps_di_16', 'K0',  0, 0.058824, -1, 0, 'neutral'),
('sps_di_16', 'K1',  0, 0.117647, -1, 0, 'neutral'),
('sps_di_16', 'K2',  0, 0.176471, -1, 0, 'neutral'),
('sps_di_16', 'K3',  0, 0.235294, -1, 0, 'neutral'),
('sps_di_16', 'K4',  0, 0.294118, -1, 0, 'neutral'),
('sps_di_16', 'K5',  0, 0.352941, -1, 0, 'neutral'),
('sps_di_16', 'K6',  0, 0.411765, -1, 0, 'neutral'),
('sps_di_16', 'K7',  0, 0.470588, -1, 0, 'neutral'),
('sps_di_16', 'K8',  0, 0.529412, -1, 0, 'neutral'),
('sps_di_16', 'K9',  0, 0.588235, -1, 0, 'neutral'),
('sps_di_16', 'K10', 0, 0.647059, -1, 0, 'neutral'),
('sps_di_16', 'K11', 0, 0.705882, -1, 0, 'neutral'),
('sps_di_16', 'K12', 0, 0.764706, -1, 0, 'neutral'),
('sps_di_16', 'K13', 0, 0.823529, -1, 0, 'neutral'),
('sps_di_16', 'K14', 0, 0.882353, -1, 0, 'neutral'),
('sps_di_16', 'K15', 0, 0.941176, -1, 0, 'neutral'),
-- sps_do_8: 8 Ausgaenge rechts (72mm, Divisor=9, Schritt=8mm)
('sps_do_8',  'K0', 1, 0.111111, 1, 0, 'neutral'),
('sps_do_8',  'K1', 1, 0.222222, 1, 0, 'neutral'),
('sps_do_8',  'K2', 1, 0.333333, 1, 0, 'neutral'),
('sps_do_8',  'K3', 1, 0.444444, 1, 0, 'neutral'),
('sps_do_8',  'K4', 1, 0.555556, 1, 0, 'neutral'),
('sps_do_8',  'K5', 1, 0.666667, 1, 0, 'neutral'),
('sps_do_8',  'K6', 1, 0.777778, 1, 0, 'neutral'),
('sps_do_8',  'K7', 1, 0.888889, 1, 0, 'neutral'),
-- sps_do_16: 16 Ausgaenge rechts (136mm, Divisor=17, Schritt=8mm)
('sps_do_16', 'K0',  1, 0.058824, 1, 0, 'neutral'),
('sps_do_16', 'K1',  1, 0.117647, 1, 0, 'neutral'),
('sps_do_16', 'K2',  1, 0.176471, 1, 0, 'neutral'),
('sps_do_16', 'K3',  1, 0.235294, 1, 0, 'neutral'),
('sps_do_16', 'K4',  1, 0.294118, 1, 0, 'neutral'),
('sps_do_16', 'K5',  1, 0.352941, 1, 0, 'neutral'),
('sps_do_16', 'K6',  1, 0.411765, 1, 0, 'neutral'),
('sps_do_16', 'K7',  1, 0.470588, 1, 0, 'neutral'),
('sps_do_16', 'K8',  1, 0.529412, 1, 0, 'neutral'),
('sps_do_16', 'K9',  1, 0.588235, 1, 0, 'neutral'),
('sps_do_16', 'K10', 1, 0.647059, 1, 0, 'neutral'),
('sps_do_16', 'K11', 1, 0.705882, 1, 0, 'neutral'),
('sps_do_16', 'K12', 1, 0.764706, 1, 0, 'neutral'),
('sps_do_16', 'K13', 1, 0.823529, 1, 0, 'neutral'),
('sps_do_16', 'K14', 1, 0.882353, 1, 0, 'neutral'),
('sps_do_16', 'K15', 1, 0.941176, 1, 0, 'neutral'),
-- sps_ai_4: 4 Eingaenge links
('sps_ai_4',  'K0', 0, 0.2,   -1, 0, 'neutral'),
('sps_ai_4',  'K1', 0, 0.4,   -1, 0, 'neutral'),
('sps_ai_4',  'K2', 0, 0.6,   -1, 0, 'neutral'),
('sps_ai_4',  'K3', 0, 0.8,   -1, 0, 'neutral'),
-- sps_ai_8: 8 Eingaenge links (72mm, Divisor=9, Schritt=8mm)
('sps_ai_8',  'K0', 0, 0.111111, -1, 0, 'neutral'),
('sps_ai_8',  'K1', 0, 0.222222, -1, 0, 'neutral'),
('sps_ai_8',  'K2', 0, 0.333333, -1, 0, 'neutral'),
('sps_ai_8',  'K3', 0, 0.444444, -1, 0, 'neutral'),
('sps_ai_8',  'K4', 0, 0.555556, -1, 0, 'neutral'),
('sps_ai_8',  'K5', 0, 0.666667, -1, 0, 'neutral'),
('sps_ai_8',  'K6', 0, 0.777778, -1, 0, 'neutral'),
('sps_ai_8',  'K7', 0, 0.888889, -1, 0, 'neutral'),
-- sps_ao_4: 4 Ausgaenge rechts
('sps_ao_4',  'K0', 1, 0.2,   1, 0, 'neutral'),
('sps_ao_4',  'K1', 1, 0.4,   1, 0, 'neutral'),
('sps_ao_4',  'K2', 1, 0.6,   1, 0, 'neutral'),
('sps_ao_4',  'K3', 1, 0.8,   1, 0, 'neutral'),
-- sps_cpu: DP / PN Kommunikations-Pins links (48mm, Divisor=3)
('sps_cpu',   'DP', 0, 0.333333, -1, 0, 'neutral'),
('sps_cpu',   'PN', 0, 0.666667, -1, 0, 'neutral'),
-- pls_ai_8: 8 Eingaenge links (72mm, Divisor=9, Schritt=8mm)
('pls_ai_8',  'K0', 0, 0.111111, -1, 0, 'neutral'),
('pls_ai_8',  'K1', 0, 0.222222, -1, 0, 'neutral'),
('pls_ai_8',  'K2', 0, 0.333333, -1, 0, 'neutral'),
('pls_ai_8',  'K3', 0, 0.444444, -1, 0, 'neutral'),
('pls_ai_8',  'K4', 0, 0.555556, -1, 0, 'neutral'),
('pls_ai_8',  'K5', 0, 0.666667, -1, 0, 'neutral'),
('pls_ai_8',  'K6', 0, 0.777778, -1, 0, 'neutral'),
('pls_ai_8',  'K7', 0, 0.888889, -1, 0, 'neutral'),
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
-- KFZ + Motorrad Symbole, Teil 2 (SYM-ERWEITERUNG-01 Prioritaet 2, Schema v104)
-- Fuenf 1:1-Wiedernutzungen bestehender Grafiken unter neuer ID:
--   kfz_zuendschloss (= wechselschalter), kfz_lichtschalter/
--   kfz_seitenstaenderschalter/kfz_kupplungsschalter/kfz_bremslichtschalter (= ausschalter)
-- Elf eigene, unverifizierte Piktogramme ohne Bildvorlage (vor Praxiseinsatz
-- gegenpruefen, analog kreuzschalter/rauchmelder/bewegungsmelder):
--   kfz_anlasser, kfz_gluehkerze, kfz_scheinwerfer, kfz_blinkerrelais,
--   kfz_scheibenwischermotor, kfz_lambdasonde, kfz_steuergeraet, kfz_cdi,
--   kfz_kombiinstrument, kfz_sicherungskasten, kfz_zuendspule
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('kfz_zuendschloss',          'Zündschloss',                 'KFZ', 32, 16, 'variabel', 1),
('kfz_lichtschalter',         'Lichtschalter',                'KFZ', 32, 16, 'variabel', 1),
('kfz_seitenstaenderschalter','Seitenständerschalter',        'KFZ', 32, 16, 'variabel', 1),
('kfz_kupplungsschalter',     'Kupplungsschalter',            'KFZ', 32, 16, 'variabel', 1),
('kfz_bremslichtschalter',    'Bremslichtschalter',           'KFZ', 32, 16, 'variabel', 1),
('kfz_anlasser',              'Anlasser (Starter)',           'KFZ', 32, 16, 'variabel', 1),
('kfz_gluehkerze',            'Glühkerze',                    'KFZ', 24, 16, 'variabel', 1),
('kfz_scheinwerfer',          'Scheinwerfer (Abblend/Fern)',  'KFZ', 32, 24, 'variabel', 1),
('kfz_blinkerrelais',         'Blinkerrelais',                'KFZ', 32, 24, 'variabel', 1),
('kfz_scheibenwischermotor',  'Scheibenwischermotor',         'KFZ', 36, 32, 'variabel', 1),
('kfz_lambdasonde',           'Lambdasonde',                  'KFZ', 16, 16, 'variabel', 1),
('kfz_steuergeraet',          'Steuergerät (ECU)',            'KFZ', 32, 32, 'variabel', 1),
('kfz_cdi',                   'CDI-Zündbox',                  'KFZ', 32, 32, 'variabel', 1),
('kfz_kombiinstrument',       'Kombiinstrument',              'KFZ', 40, 32, 'variabel', 1),
('kfz_sicherungskasten',      'Sicherungskasten',             'KFZ', 40, 48, 'variabel', 1),
('kfz_zuendspule',            'Zündspule',                    'KFZ', 32, 32, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp, knoten_gruppe) VALUES
-- kfz_zuendschloss: 1:1 wechselschalter-Pins, umbenannt (30 Common, 15/50 Ausgaenge) -- ein Strompfad, alle knoten_gruppe 0
('kfz_zuendschloss', '30', 0, 0.5,  -1, 0, 'neutral', 0),
('kfz_zuendschloss', '15', 1, 0.25,  1, 0, 'neutral', 0),
('kfz_zuendschloss', '50', 1, 0.75,  1, 0, 'neutral', 0),
-- kfz_lichtschalter/kfz_seitenstaenderschalter/kfz_kupplungsschalter/kfz_bremslichtschalter: 1:1 ausschalter-Pins
('kfz_lichtschalter', '1', 0, 0.5, -1, 0, 'neutral', 0),
('kfz_lichtschalter', '2', 1, 0.5,  1, 0, 'neutral', 0),
('kfz_seitenstaenderschalter', '1', 0, 0.5, -1, 0, 'neutral', 0),
('kfz_seitenstaenderschalter', '2', 1, 0.5,  1, 0, 'neutral', 0),
('kfz_kupplungsschalter', '1', 0, 0.5, -1, 0, 'neutral', 0),
('kfz_kupplungsschalter', '2', 1, 0.5,  1, 0, 'neutral', 0),
('kfz_bremslichtschalter', '1', 0, 0.5, -1, 0, 'neutral', 0),
('kfz_bremslichtschalter', '2', 1, 0.5,  1, 0, 'neutral', 0),
-- kfz_anlasser: 50 Steuerklemme/Solenoid, 30 B+ Hauptstrom -- getrennte Kreise
('kfz_anlasser', '50', 0, 0.5, -1, 0, 'neutral', 0),
('kfz_anlasser', '30', 1, 0.5,  1, 0, 'neutral', 1),
-- kfz_gluehkerze: 1 Anschluss, Rueckleitung ueber Zylinderkopf (kein zweiter Pin)
('kfz_gluehkerze', '1', 0, 0.5, -1, 0, 'neutral', 0),
-- kfz_scheinwerfer: 31 Masse/gemeinsame Rueckleitung, 56b Abblendlicht, 56a Fernlicht
('kfz_scheinwerfer', '31',  0, 0.5,  -1, 0, 'neutral', 0),
('kfz_scheinwerfer', '56b', 1, 0.25,  1, 0, 'neutral', 1),
('kfz_scheinwerfer', '56a', 1, 0.75,  1, 0, 'neutral', 2),
-- kfz_blinkerrelais: 49 Eingang+, 49a Ausgang blinkend, 31 Masse
('kfz_blinkerrelais', '49',  0,   0.3, -1, 0, 'neutral', 0),
('kfz_blinkerrelais', '49a', 1,   0.3,  1, 0, 'neutral', 1),
('kfz_blinkerrelais', '31',  0.5, 1.0,  0, 1, 'neutral', 2),
-- kfz_scheibenwischermotor: 31 Masse, 53 langsam, 53b schnell
('kfz_scheibenwischermotor', '31',  0, 0.2, -1, 0, 'neutral', 0),
('kfz_scheibenwischermotor', '53',  0, 0.5, -1, 0, 'neutral', 1),
('kfz_scheibenwischermotor', '53b', 0, 0.8, -1, 0, 'neutral', 2),
-- kfz_lambdasonde: Signalschleife, ein Knoten (wie sensor_temp)
('kfz_lambdasonde', '1', 0, 0.5, -1, 0, 'neutral', 0),
('kfz_lambdasonde', '2', 1, 0.5,  1, 0, 'neutral', 0),
-- kfz_steuergeraet: 30 B+, 31 Masse, Signal generisch
('kfz_steuergeraet', '30',     0, 0.25, -1, 0, 'neutral', 0),
('kfz_steuergeraet', '31',     0, 0.75, -1, 0, 'neutral', 1),
('kfz_steuergeraet', 'Signal', 1, 0.5,   1, 0, 'neutral', 2),
-- kfz_cdi: 30 B+, 31 Masse, Impuls Geber-Signal, 4 Zuendspulen-Ausgang
('kfz_cdi', '30',     0, 0.25, -1, 0, 'neutral', 0),
('kfz_cdi', '31',     0, 0.75, -1, 0, 'neutral', 1),
('kfz_cdi', 'Impuls', 1, 0.25,  1, 0, 'neutral', 2),
('kfz_cdi', '4',      1, 0.75,  1, 0, 'neutral', 3),
-- kfz_kombiinstrument: 30 B+, 31 Masse, Signal generisch
('kfz_kombiinstrument', '30',     0, 0.25, -1, 0, 'neutral', 0),
('kfz_kombiinstrument', '31',     0, 0.75, -1, 0, 'neutral', 1),
('kfz_kombiinstrument', 'Signal', 1, 0.5,   1, 0, 'neutral', 2),
-- kfz_sicherungskasten: 30 Batterie-Eingang, F1..F4 Ausgaenge
('kfz_sicherungskasten', '30', 0, 0.5,   -1, 0, 'neutral', 0),
('kfz_sicherungskasten', 'F1', 1, 0.15,   1, 0, 'neutral', 1),
('kfz_sicherungskasten', 'F2', 1, 0.383,  1, 0, 'neutral', 2),
('kfz_sicherungskasten', 'F3', 1, 0.617,  1, 0, 'neutral', 3),
('kfz_sicherungskasten', 'F4', 1, 0.85,   1, 0, 'neutral', 4),
-- kfz_zuendspule: 15 +12V, 1 Unterbrecher/Steuerung, 4 Hochspannungsausgang
('kfz_zuendspule', '15', 0, 0.25, -1, 0, 'neutral', 0),
('kfz_zuendspule', '1',  0, 0.75, -1, 0, 'neutral', 1),
('kfz_zuendspule', '4',  1, 0.5,   1, 0, 'neutral', 2);

INSERT INTO symbol_primitiv
(symbol_id, reihenfolge, typ,
 x1, y1, x2, y2, x3, y3,
 radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
 text_inhalt, schrift_relativ, schrift_fett,
 text_align, text_baseline, linienart)
VALUES
-- kfz_zuendschloss: 1:1 wechselschalter-Grafik
('kfz_zuendschloss', 0, 'linie', 0,    0.5,  0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendschloss', 1, 'linie', 0.3,  0.5,  0.75, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendschloss', 2, 'linie', 0.7,  0.25, 0.7,  0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendschloss', 3, 'linie', 0.7,  0.25, 1,    0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendschloss', 4, 'linie', 0.7,  0.75, 1,    0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_lichtschalter/seitenstaenderschalter/kupplungsschalter/bremslichtschalter: 1:1 ausschalter-Grafik
('kfz_lichtschalter', 0, 'linie', 0,   0.5, 0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_lichtschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_lichtschalter', 2, 'linie', 0.7, 0.5, 1,    0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_seitenstaenderschalter', 0, 'linie', 0,   0.5, 0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_seitenstaenderschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_seitenstaenderschalter', 2, 'linie', 0.7, 0.5, 1,    0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kupplungsschalter', 0, 'linie', 0,   0.5, 0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kupplungsschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kupplungsschalter', 2, 'linie', 0.7, 0.5, 1,    0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_bremslichtschalter', 0, 'linie', 0,   0.5, 0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_bremslichtschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_bremslichtschalter', 2, 'linie', 0.7, 0.5, 1,    0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_anlasser: Kreis+M, Stil wie kfz_lichtmaschine
('kfz_anlasser', 0, 'linie',       0,    0.5, 0.28, 0.5, 0, 0, 0,    0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_anlasser', 1, 'linie',       0.72, 0.5, 1,    0.5, 0, 0, 0,    0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_anlasser', 2, 'kreis_offen', 0.5,  0.5, 0,    0,   0, 0, 0.22, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_anlasser', 3, 'text',        0.5,  0.5, 0,    0,   0, 0, 0,    0, 0, 0, 'M',  0.35, 1, 'center', 'middle', 'solid'),
-- kfz_gluehkerze: Koerper + Heizwendel-Zickzack + Hitze-Schwuenge
('kfz_gluehkerze', 0, 'linie',    0,    0.5,  0.15, 0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 1, 'rechteck', 0.15, 0.25, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 2, 'linie',    0.22, 0.35, 0.30, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 3, 'linie',    0.30, 0.65, 0.38, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 4, 'linie',    0.38, 0.35, 0.46, 0.65, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 5, 'linie',    0.46, 0.65, 0.54, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 6, 'linie',    0.65, 0.4,  0.78, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 7, 'linie',    0.65, 0.55, 0.80, 0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_gluehkerze', 8, 'linie',    0.65, 0.7,  0.78, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_scheinwerfer: Kreis+X (wie lampe) + 3 Anschluesse
('kfz_scheinwerfer', 0, 'linie',       0,    0.5,  0.3,  0.5,  0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 1, 'kreis_offen', 0.5,  0.5,  0,    0,    0, 0, 0.2, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 2, 'linie',       0.4,  0.4,  0.6,  0.6,  0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 3, 'linie',       0.4,  0.6,  0.6,  0.4,  0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 4, 'linie',       0.7,  0.5,  0.85, 0.25, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 5, 'linie',       0.85, 0.25, 1,    0.25, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 6, 'linie',       0.7,  0.5,  0.85, 0.75, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_scheinwerfer', 7, 'linie',       0.85, 0.75, 1,    0.75, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_blinkerrelais: Rechteck + Rechteckwellen-Zickzack (Oszillation)
('kfz_blinkerrelais', 0,  'linie',    0,    0.3,  0.15, 0.3,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 1,  'linie',    0.85, 0.3,  1,    0.3,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 2,  'linie',    0.5,  0.6,  0.5,  1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 3,  'rechteck', 0.15, 0.15, 0.85, 0.6,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 4,  'linie',    0.25, 0.45, 0.35, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 5,  'linie',    0.35, 0.45, 0.35, 0.3,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 6,  'linie',    0.35, 0.3,  0.5,  0.3,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 7,  'linie',    0.5,  0.3,  0.5,  0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 8,  'linie',    0.5,  0.45, 0.65, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 9,  'linie',    0.65, 0.45, 0.65, 0.3,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_blinkerrelais', 10, 'linie',    0.65, 0.3,  0.75, 0.3,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_scheibenwischermotor: 3 Stubs in Kreis+M
('kfz_scheibenwischermotor', 0, 'linie',       0,    0.2,  0.35, 0.2,  0, 0, 0,    0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_scheibenwischermotor', 1, 'linie',       0,    0.5,  0.3,  0.5,  0, 0, 0,    0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_scheibenwischermotor', 2, 'linie',       0,    0.8,  0.35, 0.8,  0, 0, 0,    0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_scheibenwischermotor', 3, 'kreis_offen', 0.65, 0.5,  0,    0,    0, 0, 0.32, 0, 0, 0, NULL, 0.5,  0, 'center', 'middle', 'solid'),
('kfz_scheibenwischermotor', 4, 'text',        0.65, 0.46, 0,    0,    0, 0, 0,    0, 0, 0, 'M',  0.28, 1, 'center', 'middle', 'solid'),
-- kfz_lambdasonde: Rechteck + O2 (wie sensor_temp)
('kfz_lambdasonde', 0, 'rechteck', 0.1, 0.1, 0.9, 0.9, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_lambdasonde', 1, 'linie',    0,   0.5, 0.1, 0.5, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_lambdasonde', 2, 'linie',    0.9, 0.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_lambdasonde', 3, 'text',     0.5, 0.5, 0,   0,   0, 0, 0, 0, 0, 0, 'O2', 0.32, 1, 'center', 'middle', 'solid'),
-- kfz_steuergeraet (ECU): Rechteck + IC-Anschlussstriche + Text
('kfz_steuergeraet', 0, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 1, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 2, 'linie',    0.85, 0.5,  1,    0.5,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 3, 'rechteck', 0.15, 0.1,  0.85, 0.9,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 4, 'linie',    0.3,  0.3,  0.3,  0.4,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 5, 'linie',    0.45, 0.3,  0.45, 0.4,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 6, 'linie',    0.6,  0.3,  0.6,  0.4,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_steuergeraet', 7, 'text',     0.5,  0.65, 0,    0,    0, 0, 0, 0, 0, 0, 'ECU', 0.16, 1, 'center', 'middle', 'solid'),
-- kfz_cdi: Rechteck + Kondensator-Plattenpaar
('kfz_cdi', 0, 'linie',    0,    0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 1, 'linie',    0,    0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 2, 'linie',    0.85, 0.25, 1,    0.25, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 3, 'linie',    0.85, 0.75, 1,    0.75, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 4, 'rechteck', 0.15, 0.1,  0.85, 0.9,  0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 5, 'linie',    0.4,  0.35, 0.4,  0.65, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 6, 'linie',    0.6,  0.35, 0.6,  0.65, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('kfz_cdi', 7, 'text',     0.5,  0.78, 0,    0,    0, 0, 0, 0, 0, 0, 'CDI', 0.14, 1, 'center', 'middle', 'solid'),
-- kfz_kombiinstrument: Rechteck + Rundinstrument-Skala + Zeiger
('kfz_kombiinstrument', 0, 'linie',          0,    0.25, 0.15, 0.25, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kombiinstrument', 1, 'linie',          0,    0.75, 0.15, 0.75, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kombiinstrument', 2, 'linie',          0.85, 0.5,  1,    0.5,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kombiinstrument', 3, 'rechteck',       0.15, 0.1,  0.85, 0.9,  0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kombiinstrument', 4, 'bogen',          0.5,  0.6,  0,    0,    0, 0, 0.22, 200, 340, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kombiinstrument', 5, 'linie',          0.5,  0.6,  0.62, 0.42, 0, 0, 0,    0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_kombiinstrument', 6, 'kreis_gefuellt', 0.5,  0.6,  0,    0,    0, 0, 0.03, 0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_sicherungskasten: Rahmen + 4 Slots
('kfz_sicherungskasten', 0, 'linie',    0,    0.5,   0.15, 0.5,   0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 1, 'rechteck', 0.15, 0.05,  0.85, 0.95,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 2, 'linie',    0.85, 0.15,  1,    0.15,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 3, 'linie',    0.85, 0.383, 1,    0.383, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 4, 'linie',    0.85, 0.617, 1,    0.617, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 5, 'linie',    0.85, 0.85,  1,    0.85,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 6, 'rechteck', 0.3,  0.1,   0.7,  0.2,   0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 7, 'rechteck', 0.3,  0.333, 0.7,  0.433, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 8, 'rechteck', 0.3,  0.567, 0.7,  0.667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_sicherungskasten', 9, 'rechteck', 0.3,  0.8,   0.7,  0.9,   0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kfz_zuendspule: wie trafo, nur 1 Sekundaer-Pin
('kfz_zuendspule', 0, 'linie',       0,    0.25,  0.3,  0.25,  0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendspule', 1, 'linie',       0,    0.75,  0.3,  0.75,  0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendspule', 2, 'linie',       0.7,  0.5,   1,    0.5,   0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendspule', 3, 'kreis_offen', 0.3,  0.5,   0,    0,     0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendspule', 4, 'kreis_offen', 0.7,  0.5,   0,    0,     0, 0, 0.25, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendspule', 5, 'linie',       0.48, 0.275, 0.48, 0.725, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kfz_zuendspule', 6, 'linie',       0.52, 0.275, 0.52, 0.725, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- Arduino Symbole (Kategorie 'Arduino')
-- ard_uno:    Arduino UNO  32x64mm  (14 links D0-D13 + 13 rechts + NC bei k=7)
-- ard_nano:   Arduino Nano 32x64mm  (14 links D0-D13 + 14 rechts)
-- ard_mega:   Arduino Mega 32x88mm  (20 links D0-D19 + 20 rechts)
-- ard_dht:    DHT Sensor   16x16mm  (3 links)
-- ard_hcsr04: HC-SR04      16x24mm  (4 links)
-- ard_pir:    PIR Sensor   16x16mm  (3 links)
-- Pin-Formel: N Pins je Seite, Divisor=N+2 (statt N+1) → hoehe_mm = Divisor*4,
-- y_norm = k/Divisor fuer k=1..N (1 Raster-Einheit Rand oben, 2 unten).
-- Divisor muss GERADE sein: neu platzierte Symbole snappen mit ihrem
-- Mittelpunkt aufs Raster (SchaltplanCanvas.symbolVorschauErstellen), nur
-- bei einer Hoehe als Vielfaches von 8mm landet auch der Mittelpunkt exakt
-- auf einer Rasterlinie und damit alle Pins exakt im 4mm-Raster (ARD-GRID-02).
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('ard_uno',    'Arduino UNO',    'Arduino', 32, 64, 'variabel', 1),
('ard_nano',   'Arduino Nano',   'Arduino', 32, 64, 'variabel', 1),
('ard_mega',   'Arduino Mega',   'Arduino', 32, 88, 'variabel', 1),
('ard_dht',    'DHT Sensor',     'Arduino', 16, 16, 'variabel', 1),
('ard_hcsr04', 'HC-SR04 Sensor', 'Arduino', 16, 24, 'variabel', 1),
('ard_pir',    'PIR Sensor',     'Arduino', 16, 16, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
-- ard_uno: D0-D13 links (divisor=16)
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
-- ard_uno: Power+Analog rechts (NC-Luecke bei k=7, y=0.4375)
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
-- ard_nano: D0-D13 links (divisor=16)
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
-- ard_nano: Power+Analog rechts (kein NC)
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
-- ard_mega: D0-D19 links (divisor=22)
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
-- ard_mega: Power+Analog rechts
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
('ard_mega', 'A13',  1, 0.9091, 1, 0, 'neutral'),
-- Sensoren: alle Pins links
('ard_dht',    'VCC',  0, 0.25, -1, 0, 'neutral'),
('ard_dht',    'DATA', 0, 0.50, -1, 0, 'neutral'),
('ard_dht',    'GND',  0, 0.75, -1, 0, 'neutral'),
('ard_hcsr04', 'VCC',  0, 0.1667, -1, 0, 'neutral'),
('ard_hcsr04', 'TRIG', 0, 0.3333, -1, 0, 'neutral'),
('ard_hcsr04', 'ECHO', 0, 0.5000, -1, 0, 'neutral'),
('ard_hcsr04', 'GND',  0, 0.6667, -1, 0, 'neutral'),
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
-- ── ard_uno (32x64mm, 14 links + 13 rechts, NC-Luecke rechts k=7) ──
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
-- ── ard_nano (32x64mm, 14 links + 14 rechts) ──
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
-- ── ard_mega (32x88mm, 20 links + 20 rechts) ──
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
('ard_mega', 42, 'linie', 0.85, 0.9091, 1.0, 0.9091, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- ── ard_dht (16x16mm, 3 Pins links) ──
('ard_dht', 0, 'rechteck', 0.15, 0.05, 0.85, 0.95, 0, 0, 0, 0, 0, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('ard_dht', 1, 'text',     0.5,  0.15, 0,    0,    0, 0, 0, 0, 0, 0, 'DHT', 0.15, 1, 'center', 'middle', 'solid'),
('ard_dht', 2, 'linie', 0, 0.25, 0.15, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_dht', 3, 'linie', 0, 0.50, 0.15, 0.50, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_dht', 4, 'linie', 0, 0.75, 0.15, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_dht', 5, 'text',  0.2, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 'VCC',  0.11, 0, 'left', 'middle', 'solid'),
('ard_dht', 6, 'text',  0.2, 0.50, 0, 0, 0, 0, 0, 0, 0, 0, 'DATA', 0.11, 0, 'left', 'middle', 'solid'),
('ard_dht', 7, 'text',  0.2, 0.75, 0, 0, 0, 0, 0, 0, 0, 0, 'GND',  0.11, 0, 'left', 'middle', 'solid'),
-- ── ard_hcsr04 (16x24mm, 4 Pins links) ──
('ard_hcsr04', 0, 'rechteck', 0.15, 0.03, 0.85, 0.97, 0, 0, 0, 0, 0, 0, NULL,      0.5,  0, 'center', 'middle', 'solid'),
('ard_hcsr04', 1, 'text',     0.5,  0.12, 0,    0,    0, 0, 0, 0, 0, 0, 'HC-SR04', 0.10, 1, 'center', 'middle', 'solid'),
('ard_hcsr04', 2, 'linie', 0, 0.1667, 0.15, 0.1667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 3, 'linie', 0, 0.3333, 0.15, 0.3333, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 4, 'linie', 0, 0.5000, 0.15, 0.5000, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 5, 'linie', 0, 0.6667, 0.15, 0.6667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ard_hcsr04', 6, 'text',  0.2, 0.1667, 0, 0, 0, 0, 0, 0, 0, 0, 'VCC',  0.09, 0, 'left', 'middle', 'solid'),
('ard_hcsr04', 7, 'text',  0.2, 0.3333, 0, 0, 0, 0, 0, 0, 0, 0, 'TRIG', 0.09, 0, 'left', 'middle', 'solid'),
('ard_hcsr04', 8, 'text',  0.2, 0.5000, 0, 0, 0, 0, 0, 0, 0, 0, 'ECHO', 0.09, 0, 'left', 'middle', 'solid'),
('ard_hcsr04', 9, 'text',  0.2, 0.6667, 0, 0, 0, 0, 0, 0, 0, 0, 'GND',  0.09, 0, 'left', 'middle', 'solid'),
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

-- ══════════════════════════════════════════════════════════════
-- Passive Bauelemente – Ergänzungen (B9)
-- brueckengleichrichter: 32x32mm, Rauten-IEC-Symbol
--   AC-Eingänge links/rechts (~1/~2), DC-Ausgänge oben(+)/unten(-)
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('brueckengleichrichter', 'Brückengleichrichter', 'Passive', 32, 32, 'verbraucher', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('brueckengleichrichter', '~1', 0,   0.5,  -1,  0, 'power'),
('brueckengleichrichter', '~2', 1,   0.5,   1,  0, 'power'),
('brueckengleichrichter', '+',  0.5, 0,     0, -1, 'power'),
('brueckengleichrichter', '-',  0.5, 1,     0,  1, 'power');

INSERT INTO symbol_primitiv
    (symbol_id, reihenfolge, typ,
     x1, y1, x2, y2, x3, y3,
     radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
     text_inhalt, schrift_relativ, schrift_fett,
     text_align, text_baseline, linienart)
VALUES
-- Rauten-Seiten (IEC-Brückengleichrichter: Quadrat 45° gedreht)
('brueckengleichrichter', 0, 'linie', 0.15, 0.5,  0.5,  0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('brueckengleichrichter', 1, 'linie', 0.5,  0.15, 0.85, 0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('brueckengleichrichter', 2, 'linie', 0.85, 0.5,  0.5,  0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('brueckengleichrichter', 3, 'linie', 0.5,  0.85, 0.15, 0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- Pin-Stubs (Anschlusslinien zu den Symbolrändern)
('brueckengleichrichter', 4, 'linie', 0,    0.5,  0.15, 0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('brueckengleichrichter', 5, 'linie', 0.85, 0.5,  1,    0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('brueckengleichrichter', 6, 'linie', 0.5,  0,    0.5,  0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('brueckengleichrichter', 7, 'linie', 0.5,  0.85, 0.5,  1,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- Polungsmarkierungen (+ oben, - unten)
('brueckengleichrichter', 8, 'text',  0.5,  0.3,  0,    0,    0, 0, 0, 0, 0, 0, '+',  0.18, 1, 'center', 'middle', 'solid'),
('brueckengleichrichter', 9, 'text',  0.5,  0.7,  0,    0,    0, 0, 0, 0, 0, 0, '-',  0.18, 1, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- sensor_niveau: Niveauschalter (Schwimmer) – 3-Draht PNP wie die
-- übrigen Sensoren, Symbol: Schwimmerkugel über Wellenlinie
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('sensor_niveau', 'Niveauschalter (Schwimmer)', 'Sensoren', 32, 16, 'variabel', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('sensor_niveau', 'L+', 0, 0.25, -1, 0, 'power'),
('sensor_niveau', 'M',  0, 0.75, -1, 0, 'power'),
('sensor_niveau', 'Q',  1, 0.5,   1, 0, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
('sensor_niveau', 0, 'rechteck',    0.15, 0.05, 0.85, 0.95, 0, 0, 0,    0,   0,   0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 1, 'linie',       0,    0.25, 0.15, 0.25, 0, 0, 0,    0,   0,   0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 2, 'linie',       0,    0.75, 0.15, 0.75, 0, 0, 0,    0,   0,   0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 3, 'linie',       0.85, 0.5,  1.0,  0.5,  0, 0, 0,    0,   0,   0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 4, 'text',        0.5,  0.22, 0,    0,    0, 0, 0,    0,   0,   0, 'NIV', 0.16, 1, 'center', 'middle', 'solid'),
('sensor_niveau', 5, 'kreis_offen', 0.5,  0.42, 0,    0,    0, 0, 0.12, 0,   0,   0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 6, 'linie',       0.5,  0.54, 0.5,  0.68, 0, 0, 0,    0,   0,   0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 7, 'bogen',       0.36, 0.78, 0,    0,    0, 0, 0.10, 180, 360, 0, NULL,  0.5,  0, 'center', 'middle', 'solid'),
('sensor_niveau', 8, 'bogen',       0.64, 0.78, 0,    0,    0, 0, 0.10,  0,  180, 0, NULL,  0.5,  0, 'center', 'middle', 'solid');

UPDATE symbol_definition SET ibn_kategorie = 'fuellstandssensor' WHERE id = 'sensor_niveau';

-- ══════════════════════════════════════════════════════════════
-- zeitschaltuhr: Schaltkontakt mit Uhr-Symbol (analog zu not_halt/
-- bimetall_nc – Kontaktstrecke + frei stehendes Aktuator-Symbol)
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('zeitschaltuhr', 'Zeitschaltuhr', 'Kontakte', 32, 16, 'durchleiter', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('zeitschaltuhr', '1', 0, 0.5, -1, 0, 'neutral'),
('zeitschaltuhr', '2', 1, 0.5,  1, 0, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
('zeitschaltuhr', 0, 'linie',       0,    0.5,  0.3,  0.5,  0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zeitschaltuhr', 1, 'linie',       0.3,  0.5,  0.75, 0.25, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zeitschaltuhr', 2, 'linie',       0.7,  0.5,  1,    0.5,  0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zeitschaltuhr', 3, 'kreis_offen', 0.5,  0.17, 0,    0,    0, 0, 0.12, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zeitschaltuhr', 4, 'linie',       0.5,  0.17, 0.5,  0.09, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zeitschaltuhr', 5, 'linie',       0.5,  0.17, 0.58, 0.12, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- Erdungszeichen nach EN 60617 (Zeichen 02-15-01 bis 02-15-04) –
-- je 1 Pin oben, rolle='quelle' analog zu 'potenzial' (definierter
-- Referenzpunkt fürs Netz), Kategorie 'Erdung'
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('erde_allgemein',   'Erde (allgemein)',                     'Erdung', 16, 22, 'quelle', 1),
('funktionserdung',  'Funktionserdung',                      'Erdung', 24, 18, 'quelle', 1),
('schutzerdung',     'Schutzerdung',                         'Erdung', 24, 24, 'quelle', 1),
('masse_gehaeuse',   'Masse, Gehäuse',                       'Erdung', 18, 20, 'quelle', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('erde_allgemein',  '1', 0.5, 0, 0, -1, 'neutral'),
('funktionserdung', '1', 0.5, 0, 0, -1, 'neutral'),
('schutzerdung',    '1', 0.5, 0, 0, -1, 'neutral'),
('masse_gehaeuse',  '1', 0.5, 0, 0, -1, 'neutral');

-- Proportionen aller vier Erdungszeichen per Pixelvermessung der Vorlage
-- (EN-60617-Referenztabelle, Screenshot) bestimmt, nicht freihändig geschätzt.
INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
-- erde_allgemein: Stab + 3 nach unten kürzer werdende Querstriche (02-15-01)
('erde_allgemein', 0, 'linie', 0.5,  0,    0.5,  0.73, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('erde_allgemein', 1, 'linie', 0.06, 0.75, 0.94, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('erde_allgemein', 2, 'linie', 0.20, 0.86, 0.80, 0.86, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('erde_allgemein', 3, 'linie', 0.34, 0.97, 0.66, 0.97, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- funktionserdung: wie erde_allgemein + breiter, flacher offener Bogen über dem Stab (02-15-02)
('funktionserdung', 0, 'linie', 0.5,  0,    0.5,  0.65, 0, 0, 0,   0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('funktionserdung', 1, 'bogen', 0.5,  1.0,  0,    0,    0, 0, 0.5, 180, 360, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('funktionserdung', 2, 'linie', 0.16, 0.66, 0.86, 0.66, 0, 0, 0,   0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('funktionserdung', 3, 'linie', 0.28, 0.81, 0.74, 0.81, 0, 0, 0,   0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('funktionserdung', 4, 'linie', 0.39, 0.96, 0.63, 0.96, 0, 0, 0,   0,   0,   0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- schutzerdung: wie erde_allgemein, eingeschlossen in Vollkreis der den Pin berührt (02-15-03)
('schutzerdung', 0, 'kreis_offen', 0.5,  0.5,  0,    0,    0, 0, 0.5, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schutzerdung', 1, 'linie',       0.5,  0.15, 0.5,  0.61, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schutzerdung', 2, 'linie',       0.15, 0.62, 0.85, 0.62, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schutzerdung', 3, 'linie',       0.26, 0.73, 0.74, 0.73, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schutzerdung', 4, 'linie',       0.37, 0.84, 0.63, 0.84, 0, 0, 0,   0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- masse_gehaeuse: Stab + Querbalken + 3 parallele, gleich geneigte Schraffurstriche (02-15-04)
('masse_gehaeuse', 0, 'linie', 0.5,  0,    0.5,  0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('masse_gehaeuse', 1, 'linie', 0.11, 0.80, 0.89, 0.80, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('masse_gehaeuse', 2, 'linie', 0.11, 0.83, 0.00, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('masse_gehaeuse', 3, 'linie', 0.50, 0.83, 0.39, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('masse_gehaeuse', 4, 'linie', 0.89, 0.83, 0.78, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- Sicherungen (Schutz): netzseitige Kennzeichnung, NH-Sicherung,
-- Sicherungsschalter/-trennschalter/-lasttrennschalter
-- Aus Nutzer-Screenshot (Reihe "Sicherungen"/"Sicherungsschalter")
-- per PIL/numpy-Pixelvermessung nachgebaut, s. SYM-BILDVORLAGE-01.
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('sicherung_netzseitig',        'Sicherung mit netzseitiger Kennzeichnung', 'Schutz', 32, 16, 'durchleiter', 1),
('nh_sicherung',                'NH-Sicherung',                            'Schutz', 32, 16, 'durchleiter', 1),
('sicherungsschalter',          'Sicherungsschalter',                      'Schutz', 36, 24, 'durchleiter', 1),
('sicherungstrennschalter',     'Sicherungstrennschalter',                 'Schutz', 36, 24, 'durchleiter', 1),
('sicherungslasttrennschalter', 'Sicherungslasttrennschalter',             'Schutz', 36, 24, 'durchleiter', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('sicherung_netzseitig',        '1', 0, 0.5, -1, 0, 'neutral'),
('sicherung_netzseitig',        '2', 1, 0.5,  1, 0, 'neutral'),
('nh_sicherung',                '1', 0, 0.5, -1, 0, 'neutral'),
('nh_sicherung',                '2', 1, 0.5,  1, 0, 'neutral'),
('sicherungsschalter',          '1', 0, 0.5, -1, 0, 'neutral'),
('sicherungsschalter',          '2', 1, 0.5,  1, 0, 'neutral'),
('sicherungstrennschalter',     '1', 0, 0.5, -1, 0, 'neutral'),
('sicherungstrennschalter',     '2', 1, 0.5,  1, 0, 'neutral'),
('sicherungslasttrennschalter', '1', 0, 0.5, -1, 0, 'neutral'),
('sicherungslasttrennschalter', '2', 1, 0.5,  1, 0, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
-- sicherung_netzseitig: wie 'sicherung', rechtes Rechteck-Drittel als Kennzeichnung des netzseitigen Anschlusses gefüllt
('sicherung_netzseitig', 0, 'linie',           0,     0.5,  1.0,  0.5,  0,     0,    0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherung_netzseitig', 1, 'rechteck',        0.25,  0.21, 0.75, 0.79, 0,     0,    0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherung_netzseitig', 2, 'dreieck_gefuellt',0.575, 0.21, 0.75, 0.21, 0.75,  0.79, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherung_netzseitig', 3, 'dreieck_gefuellt',0.575, 0.21, 0.75, 0.79, 0.575, 0.79, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- nh_sicherung: wie 'sicherung', zusätzlich zwei kurze Messerkontakt-Striche außerhalb des Rechtecks (NH-Sicherungshalter)
-- (Jul 2026 aus Nutzer-Korrektur im Symboleditor übernommen: Zuleitung in Segmente aufgeteilt statt einer durchgehenden Linie)
('nh_sicherung', 0, 'linie', 0,        0.5,     0.203125, 0.5,     0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('nh_sicherung', 1, 'linie', 0.203125, 0.21875, 0.203125, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('nh_sicherung', 2, 'rechteck', 0.25,  0.21875, 0.75,     0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('nh_sicherung', 3, 'linie', 0.796875, 0.21875, 0.796875, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('nh_sicherung', 4, 'linie', 0.796875, 0.5,     1.0,      0.5,     0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('nh_sicherung', 5, 'linie', 0.25,     0.5,     0.75,     0.5,     0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- sicherungsschalter/-trennschalter/-lasttrennschalter: gemeinsame Basis (Zuleitung, gekippte Sicherung als
-- Schaltstrecke, offener Kontaktspalt) + Betätigungs-Symbol (kein Strich / Strich+Trennsteg / Strich+Kreis)
-- Jul 2026 aus Nutzer-Korrektur im Symboleditor übernommen: freistehender Betätigungs-Strich entfernt, Trenn-/
-- Lastschaltmarkierung sitzt jetzt direkt am Kontaktspalt statt frei zu schweben (elektrotechnisch korrekter:
-- Lasttrennschalter zeigt jetzt sowohl den Trennsteg als auch den Kreis, da er beide Eigenschaften vereint).
('sicherungsschalter', 0, 'linie', 0,     0.5,   0.28,  0.5,   0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungsschalter', 1, 'linie', 0.28,  0.5,   0.62,  0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungsschalter', 2, 'linie', 0.652777777777778, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungsschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungsschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungsschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungsschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

('sicherungstrennschalter', 0, 'linie', 0,     0.5,   0.28,  0.5,   0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 1, 'linie', 0.28,  0.5,   0.62,  0.273, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 2, 'linie', 0.638888888888889, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungstrennschalter', 7, 'linie', 0.638888888888889, 0.5625, 0.638888888888889, 0.4375, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),

('sicherungslasttrennschalter', 0, 'linie', 0,     0.5,   0.28,  0.5,   0, 0, 0,     0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 1, 'linie', 0.28,  0.5,   0.62,  0.273, 0, 0, 0,     0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 2, 'linie', 0.694444444444444, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 3, 'linie', 0.320, 0.359, 0.524, 0.223, 0, 0, 0,     0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 4, 'linie', 0.376, 0.550, 0.580, 0.414, 0, 0, 0,     0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 5, 'linie', 0.320, 0.359, 0.376, 0.550, 0, 0, 0,     0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 6, 'linie', 0.524, 0.223, 0.580, 0.414, 0, 0, 0,     0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 7, 'kreis_offen', 0.666666666666667, 0.5, 0, 0, 0, 0, 0.0277777777777778, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('sicherungslasttrennschalter', 8, 'linie', 0.694444444444444, 0.458333333333333, 0.694444444444444, 0.541666666666667, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ══════════════════════════════════════════════════════════════
-- Wischkontakte + voreilende/nacheilende Schließer/Öffner
-- Aus zwei Nutzer-Screenshots ("Wischkontakte", "Voreilende und
-- Nacheilende") per PIL/numpy-Pixelvermessung + Matplotlib-Vorschau
-- nachgebaut, s. SYM-BILDVORLAGE-01. Vertikale 2-Pin-Symbole (analog
-- 'spule'): Pin oben/unten statt links/rechts.
-- Der geschwungene Voreil-/Nacheil-Haken der Vorlage ist im
-- Primitiv-System (nur Geraden, keine Splines) nicht exakt abbildbar –
-- vereinfacht zu einem Knick früh (voreilend) bzw. spät (nacheilend)
-- im Kontaktverlauf, spiegelbildlich zueinander.
-- ══════════════════════════════════════════════════════════════

INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('wischkontakt_betaetigung', 'Wischkontakt (bei Betätigung)',        'Kontakte', 16, 32, 'durchleiter', 1),
('wischkontakt_rueckfall',   'Wischkontakt (bei Rückfall)',          'Kontakte', 16, 32, 'durchleiter', 1),
('wischkontakt_beide',       'Wischkontakt (bei Betätigung+Rückfall)','Kontakte', 16, 32, 'durchleiter', 1),
('schliesser_voreilend',     'Voreilender Schließer',                'Kontakte', 12, 32, 'durchleiter', 1),
('schliesser_nacheilend',    'Nacheilender Schließer',               'Kontakte', 12, 32, 'durchleiter', 1),
('oeffner_voreilend',        'Voreilender Öffner',                   'Kontakte', 12, 32, 'durchleiter', 1),
('oeffner_nacheilend',       'Nacheilender Öffner',                  'Kontakte', 12, 32, 'durchleiter', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('wischkontakt_betaetigung', '1', 0.5, 0, 0, -1, 'neutral'),
('wischkontakt_betaetigung', '2', 0.5, 1, 0,  1, 'neutral'),
('wischkontakt_rueckfall',   '1', 0.5, 0, 0, -1, 'neutral'),
('wischkontakt_rueckfall',   '2', 0.5, 1, 0,  1, 'neutral'),
('wischkontakt_beide',       '1', 0.5, 0, 0, -1, 'neutral'),
('wischkontakt_beide',       '2', 0.5, 1, 0,  1, 'neutral'),
('schliesser_voreilend',     '1', 0.35, 0, 0, -1, 'neutral'),
('schliesser_voreilend',     '2', 0.65, 1, 0,  1, 'neutral'),
('schliesser_nacheilend',    '1', 0.65, 0, 0, -1, 'neutral'),
('schliesser_nacheilend',    '2', 0.35, 1, 0,  1, 'neutral'),
('oeffner_voreilend',        '1', 0.35, 0, 0, -1, 'neutral'),
('oeffner_voreilend',        '2', 0.65, 1, 0,  1, 'neutral'),
('oeffner_nacheilend',       '1', 0.65, 0, 0, -1, 'neutral'),
('oeffner_nacheilend',       '2', 0.35, 1, 0,  1, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
-- wischkontakt_betaetigung: Schaft+Zeitpfeil links, Wischkontakt-Diagonale, Stummel
-- (Jul 2026 aus Nutzer-Korrektur im Symboleditor übernommen: Spindel auf x=0.5 zentriert statt x=0.74,
-- Symbolbreite 10→16mm für symmetrischen Platz beider Pfeil-Widerhaken)
('wischkontakt_betaetigung', 0, 'linie', 0.5,  0,       0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_betaetigung', 1, 'linie', 0.0,  0.265625,0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_betaetigung', 2, 'linie', 0.5,  0.78125, 0.5, 1.0,     0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_betaetigung', 3, 'linie', 0.25, 0.15625, 0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- wischkontakt_rueckfall: wie oben, Zeitpfeil rechts
('wischkontakt_rueckfall', 0, 'linie', 0.5,  0,        0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_rueckfall', 1, 'linie', 0.0,  0.265625, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_rueckfall', 2, 'linie', 0.5,  0.78125,  0.5, 1.0,     0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_rueckfall', 3, 'linie', 0.75, 0.15625,  0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- wischkontakt_beide: Zeitpfeil beidseitig (voller Pfeilkopf)
('wischkontakt_beide', 0, 'linie', 0.5,     0,        0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_beide', 1, 'linie', 0.0,     0.265625, 0.5, 0.78125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_beide', 2, 'linie', 0.5,     0.78125,  0.5, 1.0,     0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_beide', 3, 'linie', 0.21875, 0.15625,  0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wischkontakt_beide', 4, 'linie', 0.75,    0.15625,  0.5, 0.25,    0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- schliesser_voreilend: Knick früh (nahe Pin 1) + separater Voreil-Strich
('schliesser_voreilend', 0, 'linie', 0.35, 0,    0.35, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_voreilend', 1, 'linie', 0.35, 0.15, 0.15, 0.30, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_voreilend', 2, 'linie', 0.15, 0.30, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_voreilend', 3, 'linie', 0.65, 0.75, 0.65, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_voreilend', 4, 'linie', 0.55, 0.02, 0.55, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- schliesser_nacheilend: Knick spät (nahe Pin 2) + separater Nacheil-Strich, gespiegelt
('schliesser_nacheilend', 0, 'linie', 0.65, 0,    0.15, 0.70, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_nacheilend', 1, 'linie', 0.15, 0.70, 0.35, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_nacheilend', 2, 'linie', 0.35, 0.85, 0.35, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('schliesser_nacheilend', 3, 'linie', 0.45, 0.75, 0.45, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- oeffner_voreilend: wie schliesser_voreilend + Öffner-Quersteg am Knick
('oeffner_voreilend', 0, 'linie', 0.35, 0,    0.35, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_voreilend', 1, 'linie', 0.35, 0.15, 0.15, 0.30, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_voreilend', 2, 'linie', 0.15, 0.30, 0.65, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_voreilend', 3, 'linie', 0.65, 0.75, 0.65, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_voreilend', 4, 'linie', 0.55, 0.02, 0.55, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_voreilend', 5, 'linie', 0.35, 0.15, 0.55, 0.15, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- oeffner_nacheilend: wie schliesser_nacheilend + Öffner-Quersteg am Knick
('oeffner_nacheilend', 0, 'linie', 0.65, 0,    0.15, 0.70, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_nacheilend', 1, 'linie', 0.15, 0.70, 0.35, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_nacheilend', 2, 'linie', 0.35, 0.85, 0.35, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_nacheilend', 3, 'linie', 0.45, 0.75, 0.45, 1.0,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('oeffner_nacheilend', 4, 'linie', 0.35, 0.85, 0.45, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ── Kategorie "Installation" (Elektroinstallation, Jul 2026, Schema v102) ────
-- Schalter-Familie: ausschalter/wechselschalter grafisch identisch zu
-- schliesser/wechsler (gleiche IEC-Kontaktdarstellung), aber eigene
-- Symbol-IDs fuer Kategorie/Suche im Installationskontext (Hausschaltplan).
INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('ausschalter',       'Ausschalter',         'Installation', 32, 16, 'durchleiter', 1),
('wechselschalter',   'Wechselschalter',     'Installation', 32, 16, 'durchleiter', 1),
('serienschalter',    'Serienschalter',      'Installation', 32, 32, 'durchleiter', 1),
('taster_beleuchtet', 'Taster (beleuchtet)', 'Installation', 32, 24, 'durchleiter', 1),
('kreuzschalter',     'Kreuzschalter',       'Installation', 32, 24, 'durchleiter', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('ausschalter',       '1', 0, 0.5,  -1, 0, 'neutral'),
('ausschalter',       '2', 1, 0.5,   1, 0, 'neutral'),
('wechselschalter',   '1', 0, 0.5,  -1, 0, 'neutral'),
('wechselschalter',   '2', 1, 0.25,  1, 0, 'neutral'),
('wechselschalter',   '3', 1, 0.75,  1, 0, 'neutral'),
('serienschalter',    '1', 0, 0.25, -1, 0, 'neutral'),
('serienschalter',    '2', 1, 0.25,  1, 0, 'neutral'),
('serienschalter',    '3', 0, 0.75, -1, 0, 'neutral'),
('serienschalter',    '4', 1, 0.75,  1, 0, 'neutral'),
('taster_beleuchtet', '1', 0, 0.667,-1, 0, 'neutral'),
('taster_beleuchtet', '2', 1, 0.667, 1, 0, 'neutral'),
('kreuzschalter',     '1', 0, 0.25, -1, 0, 'neutral'),
('kreuzschalter',     '2', 0, 0.75, -1, 0, 'neutral'),
('kreuzschalter',     '3', 1, 0.25,  1, 0, 'neutral'),
('kreuzschalter',     '4', 1, 0.75,  1, 0, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
-- ausschalter: 1:1 wie schliesser (Einpolschalter = IEC-Schließer-Grafik)
('ausschalter', 0, 'linie', 0,    0.5,  0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ausschalter', 1, 'linie', 0.3,  0.5,  0.75, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ausschalter', 2, 'linie', 0.7,  0.5,  1,    0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- wechselschalter: 1:1 wie wechsler (Umschalt-Grafik), Pins 1/2/3 statt K/NO/NC
('wechselschalter', 0, 'linie', 0,    0.5,  0.3,  0.5,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechselschalter', 1, 'linie', 0.3,  0.5,  0.75, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechselschalter', 2, 'linie', 0.7,  0.25, 0.7,  0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechselschalter', 3, 'linie', 0.7,  0.25, 1,    0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('wechselschalter', 4, 'linie', 0.7,  0.75, 1,    0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- serienschalter: zwei ausschalter-Kontaktstrecken uebereinander + gestrichelte
-- mechanische Kupplungslinie (IEC 60617-Konvention fuer gekoppelte Schaltglieder)
('serienschalter', 0, 'linie', 0,    0.25, 0.3,  0.25,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('serienschalter', 1, 'linie', 0.3,  0.25, 0.75, 0.125, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('serienschalter', 2, 'linie', 0.7,  0.25, 1,    0.25,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('serienschalter', 3, 'linie', 0,    0.75, 0.3,  0.75,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('serienschalter', 4, 'linie', 0.3,  0.75, 0.75, 0.625, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('serienschalter', 5, 'linie', 0.7,  0.75, 1,    0.75,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('serienschalter', 6, 'linie', 0.5,  0.05, 0.5,  0.95,  0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'dash'),
-- taster_beleuchtet: taster_no-Kontakt (in unteres 2/3 gestaucht) + Meldelampe darueber
('taster_beleuchtet', 0, 'linie',       0,    0.667, 0.3,  0.667, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 1, 'linie',       0.3,  0.667, 0.75, 0.5,   0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 2, 'linie',       0.7,  0.667, 1,    0.667, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 3, 'linie',       0.5,  0.427, 0.5,  0.573, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 4, 'linie',       0.35, 0.427, 0.65, 0.427, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 5, 'linie',       0.5,  0.287, 0.5,  0.427, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 6, 'kreis_offen', 0.5,  0.167, 0,    0,     0, 0, 0.09, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 7, 'linie',       0.42, 0.107, 0.58, 0.227, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('taster_beleuchtet', 8, 'linie',       0.42, 0.227, 0.58, 0.107, 0, 0, 0,    0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
-- kreuzschalter: Schaltkasten mit gekreuzten Kontaktlinien (4 Anschluesse) —
-- eigene Vereinfachung ohne Bildvorlage, vor Praxiseinsatz gegenpruefen (§11.2)
('kreuzschalter', 0, 'linie',     0,   0.25, 0.3, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kreuzschalter', 1, 'linie',     0,   0.75, 0.3, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kreuzschalter', 2, 'linie',     0.7, 0.25, 1,   0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kreuzschalter', 3, 'linie',     0.7, 0.75, 1,   0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kreuzschalter', 4, 'rechteck',  0.3, 0.15, 0.7, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kreuzschalter', 5, 'linie',     0.3, 0.25, 0.7, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('kreuzschalter', 6, 'linie',     0.3, 0.75, 0.7, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- ── SYM-ERWEITERUNG-01 Teil 2: Steckdosen/Zaehler/Melder/SPD/Rollladen ───────
-- (Jul 2026, Schema v103). rauchmelder/bewegungsmelder/daemmerungsschalter/
-- ueberspannungsschutz sind eigene vereinfachte Piktogramme ohne Bildvorlage
-- (analog kreuzschalter-Einschraenkung, s. §11.1) — steckdose_*/zaehler/
-- rollladenmotor/rollladenschalter lehnen sich enger an etablierte IEC-
-- Konventionen an (Schuko-Rundsteckdose, Messgeraet-Kreis+Einheit, Motor-
-- Kreis+M analog motor/motor_dc, Wechselschalter-Grafik analog wechsler).
INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES
('steckdose_schuko', 'Steckdose (Schuko)', 'Installation', 24, 24, 'verbraucher', 1),
('steckdose_schalter', 'Steckdose mit Schalter', 'Installation', 24, 24, 'verbraucher', 1),
('steckdose_feuchtraum', 'Feuchtraum-/Außensteckdose', 'Installation', 24, 24, 'verbraucher', 1),
('steckdose_cee16', 'CEE-Steckdose (16A)', 'Installation', 24, 24, 'verbraucher', 1),
('zaehler', 'Stromzähler (kWh)', 'Installation', 24, 24, 'durchleiter', 1),
('rauchmelder', 'Rauchmelder', 'Installation', 24, 24, 'verbraucher', 1),
('bewegungsmelder', 'Bewegungsmelder', 'Installation', 28, 24, 'verbraucher', 1),
('daemmerungsschalter', 'Dämmerungsschalter', 'Installation', 28, 28, 'verbraucher', 1),
('ueberspannungsschutz', 'Überspannungsschutz (SPD)', 'Installation', 32, 28, 'durchleiter', 1),
('rollladenmotor', 'Rollladenmotor', 'Installation', 32, 24, 'verbraucher', 1),
('rollladenschalter', 'Rollladenschalter (Auf/Ab)', 'Installation', 32, 16, 'durchleiter', 1);

INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES
('steckdose_schuko', 'L', 0, 0.3, -1, 0, 'power'),
('steckdose_schuko', 'N', 0, 0.6, -1, 0, 'n'),
('steckdose_schuko', 'PE', 0.55, 1.0, 0, 1, 'pe'),
('steckdose_schalter', 'L', 0, 0.3, -1, 0, 'power'),
('steckdose_schalter', 'N', 0, 0.6, -1, 0, 'n'),
('steckdose_schalter', 'PE', 0.55, 1.0, 0, 1, 'pe'),
('steckdose_feuchtraum', 'L', 0, 0.3, -1, 0, 'power'),
('steckdose_feuchtraum', 'N', 0, 0.6, -1, 0, 'n'),
('steckdose_feuchtraum', 'PE', 0.55, 1.0, 0, 1, 'pe'),
('steckdose_cee16', 'L', 0, 0.3, -1, 0, 'power'),
('steckdose_cee16', 'N', 0, 0.6, -1, 0, 'n'),
('steckdose_cee16', 'PE', 0.55, 1.0, 0, 1, 'pe'),
('zaehler', '1', 0, 0.5, -1, 0, 'power'),
('zaehler', '2', 1, 0.5, 1, 0, 'power'),
('rauchmelder', '1', 0, 0.5, -1, 0, 'power'),
('rauchmelder', '2', 1, 0.5, 1, 0, 'n'),
('bewegungsmelder', 'L', 0, 0.3, -1, 0, 'power'),
('bewegungsmelder', 'N', 0, 0.6, -1, 0, 'n'),
('bewegungsmelder', 'Q', 1, 0.45, 1, 0, 'neutral'),
('daemmerungsschalter', 'L', 0, 0.4, -1, 0, 'power'),
('daemmerungsschalter', 'N', 0, 0.7, -1, 0, 'n'),
('daemmerungsschalter', 'Q', 1, 0.55, 1, 0, 'neutral'),
('ueberspannungsschutz', '1', 0, 0.4, -1, 0, 'power'),
('ueberspannungsschutz', '2', 1, 0.4, 1, 0, 'power'),
('ueberspannungsschutz', 'PE', 0.5, 1.0, 0, 1, 'pe'),
('rollladenmotor', 'Auf', 0, 0.25, -1, 0, 'power'),
('rollladenmotor', 'N', 0, 0.5, -1, 0, 'n'),
('rollladenmotor', 'Ab', 0, 0.75, -1, 0, 'power'),
('rollladenschalter', '1', 0, 0.5, -1, 0, 'neutral'),
('rollladenschalter', '2', 1, 0.25, 1, 0, 'neutral'),
('rollladenschalter', '3', 1, 0.75, 1, 0, 'neutral');

INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart) VALUES
('steckdose_schuko', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schuko', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schuko', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schuko', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schuko', 4, 'linie', 0.45, 0.28, 0.45, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schuko', 5, 'linie', 0.65, 0.28, 0.65, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 4, 'linie', 0.45, 0.28, 0.45, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 5, 'linie', 0.65, 0.28, 0.65, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_schalter', 6, 'linie', 0.11, 0.36, 0.18, 0.24, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 3, 'rechteck', 0.08, 0.03, 0.98, 0.9, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 4, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 5, 'linie', 0.45, 0.28, 0.45, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_feuchtraum', 6, 'linie', 0.65, 0.28, 0.65, 0.36, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 0, 'linie', 0, 0.3, 0.2902, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 1, 'linie', 0, 0.6, 0.2902, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 2, 'linie', 0.55, 0.75, 0.55, 1.0, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 3, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.3, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 4, 'kreis_offen', 0.55, 0.45, 0, 0, 0, 0, 0.22, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 5, 'kreis_gefuellt', 0.55, 0.34, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 6, 'kreis_gefuellt', 0.47, 0.52, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('steckdose_cee16', 7, 'kreis_gefuellt', 0.63, 0.52, 0, 0, 0, 0, 0.035, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zaehler', 0, 'linie', 0, 0.5, 0.22, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zaehler', 1, 'linie', 0.78, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zaehler', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('zaehler', 3, 'text', 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 'kWh', 0.16, 0, 'center', 'middle', 'solid'),
('rauchmelder', 0, 'linie', 0, 0.5, 0.22, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rauchmelder', 1, 'linie', 0.78, 0.5, 1, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rauchmelder', 2, 'kreis_offen', 0.5, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rauchmelder', 3, 'kreis_gefuellt', 0.5, 0.42, 0, 0, 0, 0, 0.05, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rauchmelder', 4, 'linie', 0.5, 0.42, 0.4, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rauchmelder', 5, 'linie', 0.5, 0.42, 0.5, 0.24, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rauchmelder', 6, 'linie', 0.5, 0.42, 0.6, 0.28, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 0, 'linie', 0, 0.3, 0.3676, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 1, 'linie', 0, 0.6, 0.3676, 0.6, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 2, 'linie', 0.84, 0.45, 1, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 3, 'kreis_offen', 0.58, 0.45, 0, 0, 0, 0, 0.26, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 4, 'linie', 0.58, 0.71, 0.46, 0.92, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 5, 'linie', 0.58, 0.71, 0.7, 0.92, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('bewegungsmelder', 6, 'linie', 0.46, 0.92, 0.7, 0.92, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 0, 'linie', 0, 0.4, 0.3627, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 1, 'linie', 0, 0.7, 0.3627, 0.7, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 2, 'linie', 0.79, 0.55, 1, 0.55, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 3, 'kreis_offen', 0.55, 0.55, 0, 0, 0, 0, 0.24, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 4, 'linie', 0.95, 0.15, 0.72, 0.38, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 5, 'linie', 0.72, 0.38, 0.8, 0.34, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 6, 'linie', 0.72, 0.38, 0.76, 0.46, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 7, 'linie', 0.8, 0.05, 0.632, 0.324, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 8, 'linie', 0.632, 0.324, 0.7, 0.3, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('daemmerungsschalter', 9, 'linie', 0.632, 0.324, 0.66, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 0, 'linie', 0, 0.4, 0.25, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 1, 'linie', 0.75, 0.4, 1, 0.4, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 2, 'rechteck', 0.25, 0.28, 0.75, 0.52, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 3, 'linie', 0.5, 0.52, 0.5, 0.85, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 4, 'linie', 0.32, 0.46, 0.68, 0.34, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 5, 'linie', 0.5, 0.85, 0.44, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('ueberspannungsschutz', 6, 'linie', 0.5, 0.85, 0.56, 0.78, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenmotor', 0, 'linie', 0, 0.25, 0.524, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenmotor', 1, 'linie', 0, 0.5, 0.37, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenmotor', 2, 'linie', 0, 0.75, 0.524, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenmotor', 3, 'kreis_offen', 0.65, 0.5, 0, 0, 0, 0, 0.28, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenmotor', 4, 'text', 0.65, 0.46, 0, 0, 0, 0, 0, 0, 0, 0, 'M', 0.2, 1, 'center', 'middle', 'solid'),
('rollladenmotor', 5, 'text', 0.65, 0.62, 0, 0, 0, 0, 0, 0, 0, 0, '1~', 0.14, 0, 'center', 'middle', 'solid'),
('rollladenschalter', 0, 'linie', 0, 0.5, 0.3, 0.5, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenschalter', 1, 'linie', 0.3, 0.5, 0.75, 0.35, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenschalter', 2, 'linie', 0.7, 0.25, 0.7, 0.45, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenschalter', 3, 'linie', 0.7, 0.25, 1, 0.25, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid'),
('rollladenschalter', 4, 'linie', 0.7, 0.75, 1, 0.75, 0, 0, 0, 0, 0, 0, NULL, 0.5, 0, 'center', 'middle', 'solid');

-- knoten_gruppe/rolle-Overrides fuer die neuen mehrpoligen Symbole (analog
-- NETZ-MEHRPOL-01/02 Teil A, s. Zeile 150ff) — jeder galvanisch getrennte
-- Anschluss bekommt einen eigenen Knoten, damit die Netzberechnung nicht
-- faelschlich mehrere Potenziale zusammenfuehrt.
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'steckdose_schuko' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'steckdose_schuko' AND name = 'PE';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'steckdose_schalter' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'steckdose_schalter' AND name = 'PE';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'steckdose_feuchtraum' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'steckdose_feuchtraum' AND name = 'PE';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'steckdose_cee16' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'steckdose_cee16' AND name = 'PE';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'rauchmelder' AND name = '2';
-- bewegungsmelder/daemmerungsschalter: L/N-Eingang bleibt Rolle 'verbraucher'
-- (Symbol-Default), Q-Ausgang wird zur eigenen Quelle (schaltet die Last),
-- analog netzteil (NETZTEIL-ROLLE-01).
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'bewegungsmelder' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'bewegungsmelder' AND name = 'Q';
UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'bewegungsmelder' AND name = 'Q';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'daemmerungsschalter' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'daemmerungsschalter' AND name = 'Q';
UPDATE symbol_pin SET rolle = 'quelle' WHERE symbol_id = 'daemmerungsschalter' AND name = 'Q';
-- ueberspannungsschutz: L-Ein/Aus bleiben EIN Knoten (Durchleiter, wie
-- Sicherung/LSS), PE-Ableitung ist ein eigener, separater Knoten und
-- beendet die Potenzial-Weitergabe (Rolle 'verbraucher' statt geerbtem
-- 'durchleiter').
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'ueberspannungsschutz' AND name = 'PE';
UPDATE symbol_pin SET rolle = 'verbraucher' WHERE symbol_id = 'ueberspannungsschutz' AND name = 'PE';
UPDATE symbol_pin SET knoten_gruppe = 1 WHERE symbol_id = 'rollladenmotor' AND name = 'N';
UPDATE symbol_pin SET knoten_gruppe = 2 WHERE symbol_id = 'rollladenmotor' AND name = 'Ab';

-- ── bmk_seite: Symbole mit vertikaler Hauptachse (BMK links statt oben) ──────
-- Wird nach Migration v70 auch für bestehende DBs gesetzt.
UPDATE symbol_definition SET bmk_seite = 'vertikal' WHERE id = 'spule';
UPDATE symbol_definition SET bmk_seite = 'vertikal' WHERE id IN (
    'wischkontakt_betaetigung', 'wischkontakt_rueckfall', 'wischkontakt_beide',
    'schliesser_voreilend', 'schliesser_nacheilend',
    'oeffner_voreilend', 'oeffner_nacheilend'
);
