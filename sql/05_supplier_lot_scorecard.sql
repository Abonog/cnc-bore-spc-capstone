-- =====================================================================
-- Q5. Supplier and lot scorecard: defect rate per lot and per supplier.
--     Does any lot stand out? What was its hardness?
-- =====================================================================
USE spc_capstone;

-- The defects table has no lot column. production_log has exactly one row per date + shift + machine,
-- so each defect record matches one production row and can safely take its lot from there.
-- Parts and defects are still aggregated separately per lot, then joined.

-- 5a. Lot scorecard
WITH lot_parts AS (
    SELECT material_lot, SUM(parts_produced) AS parts_produced
    FROM production_log
    GROUP BY material_lot
),
lot_defects AS (
    SELECT p.material_lot, SUM(d.quantity) AS defective_parts
    FROM defects AS d
    JOIN production_log AS p
      ON p.`date` = d.`date` AND p.shift = d.shift AND p.machine_id = d.machine_id
    GROUP BY p.material_lot
)
SELECT lp.material_lot,
       s.supplier_name,
       ml.hardness_hb,
       lp.parts_produced,
       COALESCE(ld.defective_parts, 0)                                         AS defective_parts,
       ROUND(COALESCE(ld.defective_parts, 0) * 1000.0 / lp.parts_produced, 2) AS defects_per_1000
FROM lot_parts AS lp
LEFT JOIN lot_defects   AS ld ON ld.material_lot = lp.material_lot
JOIN material_lots      AS ml ON ml.lot_id       = lp.material_lot
JOIN suppliers          AS s  ON s.supplier_id   = ml.supplier_id
ORDER BY defects_per_1000 DESC;
-- L-2026-041 (Kovar Castings, 242 HB): 10,228 parts, about 195 defects per 1,000.
-- Every other lot is between about 7 and 16 per 1,000, with hardness 199-213 HB.

-- 5b. Supplier scorecard, with and without the bad lot
WITH sup_parts AS (
    SELECT ml.supplier_id,
           SUM(p.parts_produced)                                                  AS parts_all,
           SUM(CASE WHEN p.material_lot <> 'L-2026-041' THEN p.parts_produced END) AS parts_excl_041
    FROM production_log AS p
    JOIN material_lots  AS ml ON ml.lot_id = p.material_lot
    GROUP BY ml.supplier_id
),
sup_defects AS (
    SELECT ml.supplier_id,
           SUM(d.quantity)                                                   AS defects_all,
           SUM(CASE WHEN p.material_lot <> 'L-2026-041' THEN d.quantity END) AS defects_excl_041
    FROM defects        AS d
    JOIN production_log AS p  ON p.`date` = d.`date` AND p.shift = d.shift AND p.machine_id = d.machine_id
    JOIN material_lots  AS ml ON ml.lot_id = p.material_lot
    GROUP BY ml.supplier_id
)
SELECT s.supplier_name,
       ROUND(sd.defects_all * 1000.0 / sp.parts_all, 2)                          AS defects_per_1000_all,
       ROUND(COALESCE(sd.defects_excl_041, 0) * 1000.0 / sp.parts_excl_041, 2)  AS defects_per_1000_excl_041
FROM sup_parts   AS sp
JOIN sup_defects AS sd ON sd.supplier_id = sp.supplier_id
JOIN suppliers   AS s  ON s.supplier_id  = sp.supplier_id
ORDER BY defects_per_1000_all DESC;

-- 5c. Porosity rate by supplier, excluding lot 041: is Kovar's porosity a one-off or chronic?
WITH sup_parts AS (
    SELECT ml.supplier_id, SUM(p.parts_produced) AS parts_produced
    FROM production_log AS p
    JOIN material_lots  AS ml ON ml.lot_id = p.material_lot
    WHERE p.material_lot <> 'L-2026-041'
    GROUP BY ml.supplier_id
),
sup_porosity AS (
    SELECT ml.supplier_id, SUM(d.quantity) AS porosity_parts
    FROM defects        AS d
    JOIN production_log AS p  ON p.`date` = d.`date` AND p.shift = d.shift AND p.machine_id = d.machine_id
    JOIN material_lots  AS ml ON ml.lot_id = p.material_lot
    WHERE d.defect_type = 'Porosity'
      AND p.material_lot <> 'L-2026-041'
    GROUP BY ml.supplier_id
)
SELECT s.supplier_name,
       ROUND(spo.porosity_parts * 1000.0 / sp.parts_produced, 2) AS porosity_per_1000
FROM sup_parts    AS sp
JOIN sup_porosity AS spo ON spo.supplier_id = sp.supplier_id
JOIN suppliers    AS s   ON s.supplier_id   = sp.supplier_id
ORDER BY porosity_per_1000 DESC;
-- Kovar Castings 3.87 | Alfold Foundry 1.50 | Rheinguss GmbH 1.34 per 1,000 -> Kovar porosity is chronic,
-- not only lot 041. Porosity parts are scrapped, so this is the most expensive defect (see Q3).
