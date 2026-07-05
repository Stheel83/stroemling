-- bauteile_nutzer.sql
-- Eigene Bauteil-Seeds (Klemmen, Kabel, Steckverbinder …)
-- Wird bei jedem neuen Projekt via seedNutzerBauteile() eingespielt.
-- Alle Statements sind idempotent (WHERE NOT EXISTS-Guard).
--
-- FORMAT KLEMME
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Bauteil-Stammsatz
-- INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, norm, bemerkung)
-- SELECT '<BEZEICHNUNG>', '<HERSTELLER>', '<ART-NR>', '<NORM>', '<BEMERKUNG>'
-- WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='<BEZEICHNUNG>');
--
-- 2. Klemmen-Daten
-- INSERT INTO bauteil_klemme
--   (bauteil_id, norm, anschluss_typ, ebenen_anzahl,
--    punkte_seite_a, punkte_seite_b, fuss_kontakt_pe,
--    stegbruecke_faehig, breite_mm, gehaeuse_farbe_id)
-- SELECT b.id, '<NORM>', '<schraube|feder|kaefig|push_in>',
--        <EBENEN>, <PUNKTE_A>, <PUNKTE_B>, <PE_FUSS 0/1>, <BRUECKE 0/1>, <MM>,
--        (SELECT id FROM farb_definition WHERE hex_wert='<#RRGGBB>' AND ist_standard=1 LIMIT 1)
-- FROM bauteil b WHERE b.bezeichnung='<BEZEICHNUNG>'
-- AND NOT EXISTS (SELECT 1 FROM bauteil_klemme WHERE bauteil_id=b.id);
--
-- 3. Querschnitte (ein Statement pro adertyp, oder als UNION ALL)
-- INSERT INTO bauteil_klemme_querschnitt (klemme_id, adertyp, min_mm2, max_mm2)
-- SELECT bk.id, q.t, q.mn, q.mx
-- FROM bauteil_klemme bk JOIN bauteil b ON b.id=bk.bauteil_id,
--   (SELECT 'starr' t, <MIN> mn, <MAX> mx
--    UNION ALL SELECT 'flexibel', <MIN>, <MAX>
--    UNION ALL SELECT 'aenh_blank', <MIN>, <MAX>
--    UNION ALL SELECT 'aenh_isoliert', <MIN>, <MAX>) q
-- WHERE b.bezeichnung='<BEZEICHNUNG>'
-- AND NOT EXISTS (SELECT 1 FROM bauteil_klemme_querschnitt WHERE klemme_id=bk.id);
--
-- ─────────────────────────────────────────────────────────────────────────────
-- FORMAT GERÄT (einfach – 1 Symbol, z.B. LS-Schalter, Motor, Meldeleuchte)
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Bauteil-Stammsatz mit direktem Symbolverweis (kein bauteil_kontakt nötig)
-- INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, strom_a,
--   leistung_w, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
-- SELECT '<BEZEICHNUNG>', '<HERSTELLER>', '<ART-NR>', <V oder NULL>, <A oder NULL>,
--   <W oder NULL>, '<NORM>', '<BMK, z.B. -F/-M/-P/-S>', '<BEMERKUNG>', '<symbol_id>'
-- WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='<BEZEICHNUNG>');
--
-- ─────────────────────────────────────────────────────────────────────────────
-- FORMAT GERÄT (mehrteilig – Hauptfunktion + Kontakte, z.B. Schütz, Relais)
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Bauteil-Stammsatz OHNE hauptfunktion_symbol_id (Kontakte kommen aus bauteil_kontakt)
-- INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, norm, bmk_vorlage, bemerkung)
-- SELECT '<BEZEICHNUNG>', '<HERSTELLER>', '<ART-NR>', <SPULENSPANNUNG>, '<NORM>', '-K', '<BEMERKUNG>'
-- WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='<BEZEICHNUNG>');
--
-- 2. Kontaktbelegung (ein Statement je Kontakt/Gruppe, siehe 40_geraete_kontaktspiegel.md §5.1)
-- INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
-- SELECT b.id, '<schliesser|oeffner|wechsler|spule>', '<PICKER-LABEL, z.B. 13/14>', '<PIN_BEZ JSON, z.B. {"1":"13","2":"14"}>'
-- FROM bauteil b WHERE b.bezeichnung='<BEZEICHNUNG>'
-- AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='<PICKER-LABEL>');
-- ─────────────────────────────────────────────────────────────────────────────
-- FORMAT KABEL
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Bauteil-Stammsatz (wie oben)
--
-- 2. Kabel-Daten
-- INSERT INTO bauteil_kabel
--   (bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt,
--    aussenmantel_farbe, aussenmantel_mm, material_leiter, material_isolierung)
-- SELECT b.id, '<TYP>', <GESCHIRMT 0/1>, <VERDRILLT 0/1>,
--        '<FARBE>', <DURCHM_MM>, '<Cu|Al>', '<PVC|LSZH|Gummi>'
-- FROM bauteil b WHERE b.bezeichnung='<BEZEICHNUNG>'
-- AND NOT EXISTS (SELECT 1 FROM bauteil_kabel WHERE bauteil_id=b.id);
--
-- 3. Adern (je Ader ein Statement)
-- INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, nummer, bezeichnung, querschnitt_mm2)
-- SELECT bk.id, <NR>, '<FARBCODE>', '<NR_TEXT>', '<BEZEICHNUNG>', <MM2>
-- FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id
-- WHERE b.bezeichnung='<BEZEICHNUNG>'
-- AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=<NR>);
-- ─────────────────────────────────────────────────────────────────────────────


-- ===========================================================================
-- KABEL
-- ===========================================================================

-- NYM-J 3×1,5 mm²
INSERT INTO bauteil (bezeichnung, norm, bemerkung)
SELECT 'NYM-J 3x1,5', 'DIN VDE 0250-204', 'Installationskabel, grau, 3 Adern'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='NYM-J 3x1,5');

INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt, aussenmantel_farbe, material_leiter, material_isolierung)
SELECT b.id, 'NYM-J', 0, 0, 'grau', 'Cu', 'PVC'
FROM bauteil b WHERE b.bezeichnung='NYM-J 3x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel WHERE bauteil_id=b.id);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 1, 'BN', 'L', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 3x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=1);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 2, 'BU', 'N', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 3x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=2);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 3, 'GNYE', 'PE', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 3x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=3);

-- NYM-J 5×1,5 mm²
INSERT INTO bauteil (bezeichnung, norm, bemerkung)
SELECT 'NYM-J 5x1,5', 'DIN VDE 0250-204', 'Installationskabel, grau, 5 Adern'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='NYM-J 5x1,5');

INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt, aussenmantel_farbe, material_leiter, material_isolierung)
SELECT b.id, 'NYM-J', 0, 0, 'grau', 'Cu', 'PVC'
FROM bauteil b WHERE b.bezeichnung='NYM-J 5x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel WHERE bauteil_id=b.id);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 1, 'BN', 'L1', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 5x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=1);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 2, 'BK', 'L2', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 5x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=2);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 3, 'GY', 'L3', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 5x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=3);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 4, 'BU', 'N', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 5x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=4);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, farbe, bezeichnung, querschnitt_mm2)
SELECT bk.id, 5, 'GNYE', 'PE', 1.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='NYM-J 5x1,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=5);

-- LIYY 5×0,5 mm² (Steuerkabel, nummeriert)
INSERT INTO bauteil (bezeichnung, norm, bemerkung)
SELECT 'LIYY 5x0,5', 'DIN VDE 0812', 'Steuerkabel flexibel, ungeschirmt, nummeriert'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='LIYY 5x0,5');

INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt, aussenmantel_farbe, material_leiter, material_isolierung)
SELECT b.id, 'LIYY', 0, 0, 'grau', 'Cu', 'PVC'
FROM bauteil b WHERE b.bezeichnung='LIYY 5x0,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel WHERE bauteil_id=b.id);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 1, '1', 0.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LIYY 5x0,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=1);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 2, '2', 0.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LIYY 5x0,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=2);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 3, '3', 0.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LIYY 5x0,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=3);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 4, '4', 0.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LIYY 5x0,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=4);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 5, '5', 0.5
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LIYY 5x0,5'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=5);

-- LiYCY 4×0,25 mm² (geschirmt, nummeriert)
INSERT INTO bauteil (bezeichnung, norm, bemerkung)
SELECT 'LiYCY 4x0,25', 'DIN VDE 0812', 'Steuerkabel flexibel, geschirmt, nummeriert'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='LiYCY 4x0,25');

INSERT INTO bauteil_kabel (bauteil_id, kabeltyp, geschirmt, paarweise_verdrillt, aussenmantel_farbe, material_leiter, material_isolierung)
SELECT b.id, 'LiYCY', 1, 0, 'grau', 'Cu', 'PVC'
FROM bauteil b WHERE b.bezeichnung='LiYCY 4x0,25'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel WHERE bauteil_id=b.id);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 1, '1', 0.25
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LiYCY 4x0,25'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=1);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 2, '2', 0.25
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LiYCY 4x0,25'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=2);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 3, '3', 0.25
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LiYCY 4x0,25'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=3);

INSERT INTO bauteil_kabel_ader (kabel_id, ader_nr, nummer, querschnitt_mm2)
SELECT bk.id, 4, '4', 0.25
FROM bauteil_kabel bk JOIN bauteil b ON b.id=bk.bauteil_id WHERE b.bezeichnung='LiYCY 4x0,25'
AND NOT EXISTS (SELECT 1 FROM bauteil_kabel_ader WHERE kabel_id=bk.id AND ader_nr=4);


-- ===========================================================================
-- KLEMMEN  (eigene, über die 6 Standard-Klemmen hinaus)
-- ===========================================================================

-- Hier eigene Klemmen eintragen – Kopiervorlage siehe Header.


-- ===========================================================================
-- GERÄTE  (Grundausstattung für Schaltschrank-Aufbauten)
-- ===========================================================================

-- ── Schütz Siemens 3RT2015 (Grundgerät 3S + Hilfsschalterblock 1S+1Ö) ──
-- Kontaktbelegung 1:1 wie in konzept/features/06_bauteilbibliothek.md §6 dokumentiert.
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, strom_a, norm, bmk_vorlage, bemerkung)
SELECT 'Schütz 3RT2015-1AP01', 'Siemens', '3RT2015-1AP01', 230, 7, 'IEC 60947-4-1', '-K',
       'Leistungsschütz 3-polig, 7A, + Hilfsschalterblock 1 Schließer/1 Öffner'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Schütz 3RT2015-1AP01');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'spule', 'Spule', '{"A1":"A1","A2":"A2"}'
FROM bauteil b WHERE b.bezeichnung='Schütz 3RT2015-1AP01'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Spule');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'schliesser', 'Hauptkontakt 1', '{"1":"1","2":"2"}'
FROM bauteil b WHERE b.bezeichnung='Schütz 3RT2015-1AP01'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Hauptkontakt 1');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'schliesser', 'Hauptkontakt 2', '{"1":"3","2":"4"}'
FROM bauteil b WHERE b.bezeichnung='Schütz 3RT2015-1AP01'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Hauptkontakt 2');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'schliesser', 'Hauptkontakt 3', '{"1":"5","2":"6"}'
FROM bauteil b WHERE b.bezeichnung='Schütz 3RT2015-1AP01'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Hauptkontakt 3');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'schliesser', 'Hilfskontakt 13/14', '{"1":"13","2":"14"}'
FROM bauteil b WHERE b.bezeichnung='Schütz 3RT2015-1AP01'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Hilfskontakt 13/14');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'oeffner', 'Hilfskontakt 21/22', '{"1":"21","2":"22"}'
FROM bauteil b WHERE b.bezeichnung='Schütz 3RT2015-1AP01'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Hilfskontakt 21/22');

-- ── Hilfsrelais Finder 55.34 (4 Wechsler, 24V DC-Spule) ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, norm, bmk_vorlage, bemerkung)
SELECT 'Hilfsrelais Finder 55.34', 'Finder', '55.34', 24, 'IEC 61810-1', '-K',
       'Industrierelais, 4 Wechsler, Steckfassung'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Hilfsrelais Finder 55.34');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'spule', 'Spule', '{"A1":"A1","A2":"A2"}'
FROM bauteil b WHERE b.bezeichnung='Hilfsrelais Finder 55.34'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Spule');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'wechsler', 'Wechsler 11/12/14', '{"K":"11","NC":"12","NO":"14"}'
FROM bauteil b WHERE b.bezeichnung='Hilfsrelais Finder 55.34'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Wechsler 11/12/14');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'wechsler', 'Wechsler 21/22/24', '{"K":"21","NC":"22","NO":"24"}'
FROM bauteil b WHERE b.bezeichnung='Hilfsrelais Finder 55.34'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Wechsler 21/22/24');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'wechsler', 'Wechsler 31/32/34', '{"K":"31","NC":"32","NO":"34"}'
FROM bauteil b WHERE b.bezeichnung='Hilfsrelais Finder 55.34'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Wechsler 31/32/34');

INSERT INTO bauteil_kontakt (bauteil_id, symbol_id, bezeichnung, pin_bez)
SELECT b.id, 'wechsler', 'Wechsler 41/42/44', '{"K":"41","NC":"42","NO":"44"}'
FROM bauteil b WHERE b.bezeichnung='Hilfsrelais Finder 55.34'
AND NOT EXISTS (SELECT 1 FROM bauteil_kontakt WHERE bauteil_id=b.id AND bezeichnung='Wechsler 41/42/44');

-- ── Leitungsschutzschalter B16 (einfaches Gerät, direkter Symbolverweis) ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, strom_a, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'LS-Schalter B16', 'Siemens', '5SL6116-6', 16, 'DIN EN 60898-1', '-F', '1-polig, Charakteristik B', 'lss'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='LS-Schalter B16');

-- ── FI-Schutzschalter 25A/30mA ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, strom_a, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'FI-Schutzschalter 25A/30mA', 'Siemens', '5SV3314-6', 25, 'DIN EN 61008-1', '-F', 'Typ A, 2-polig', 'fi'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='FI-Schutzschalter 25A/30mA');

-- ── Feinsicherung 5x20mm 2A ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, strom_a, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Feinsicherung 5x20mm 2A', 'Wickmann', '19195000000', 2, 'DIN 41571', '-F', 'Glasrohrsicherung, träge', 'sicherung'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Feinsicherung 5x20mm 2A');

-- ── Not-Halt-Taster ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Not-Halt-Taster', 'Eaton', 'M22-PV', 'DIN EN ISO 13850', '-S', 'Pilzkopf, rastend, Öffner', 'not_halt'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Not-Halt-Taster');

-- ── Taster grün (Ein) ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Taster grün (Ein)', 'Eaton', 'M22-D-G', '-S', 'Tastend, Schließer', 'taster_no'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Taster grün (Ein)');

-- ── Taster rot (Aus) ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Taster rot (Aus)', 'Eaton', 'M22-D-R', '-S', 'Tastend, Öffner', 'taster_nc'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Taster rot (Aus)');

-- ── Meldeleuchte rot 230V ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Meldeleuchte rot 230V', 'Eaton', 'M22-L-R', 230, '-P', 'LED, Dauerlicht', 'lampe'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Meldeleuchte rot 230V');

-- ── Drehstrommotor 0,55kW ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, leistung_w, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Drehstrommotor 0,55kW', 'Siemens', '1LE1002-1CB23', 400, 550, 'IEC 60034-1', '-M', 'Kleinmotor, z.B. Pumpenantrieb', 'motor'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Drehstrommotor 0,55kW');

-- ── Steuertrafo 230/24V 63VA ──
INSERT INTO bauteil (bezeichnung, hersteller, artikelnummer, spannung_v, leistung_w, norm, bmk_vorlage, bemerkung, hauptfunktion_symbol_id)
SELECT 'Steuertrafo 230/24V 63VA', 'Block', 'STE 63/23/24', 230, 63, 'DIN EN 61558', '-T', 'Steuerspannungstrafo für 24V-AC-Steuerkreis', 'trafo'
WHERE NOT EXISTS (SELECT 1 FROM bauteil WHERE bezeichnung='Steuertrafo 230/24V 63VA');
