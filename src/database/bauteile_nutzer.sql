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
