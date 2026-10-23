-- =====================================================================
-- Q2. Overall quality: parts produced, defective parts, defect rate, cost
-- =====================================================================
USE spc_capstone;

-- Parts come from production_log and defects from the defects table.
-- Each table is summed on its own, then the two totals are combined.
-- (Joining the row-level tables first would repeat parts_produced for every defect row.)
WITH production AS (
    SELECT SUM(parts_produced) AS parts_produced
    FROM production_log
),
defect_totals AS (
    SELECT SUM(quantity)                                              AS defective_parts,
           SUM(cost_eur)                                              AS total_cost_eur,
           SUM(CASE WHEN disposition = 'Scrap'  THEN cost_eur END)    AS scrap_cost_eur,
           SUM(CASE WHEN disposition = 'Rework' THEN cost_eur END)    AS rework_cost_eur
    FROM defects
)
SELECT p.parts_produced,                                                    -- 253,374
       d.defective_parts,                                                   -- 4,489
       ROUND(d.defective_parts * 100.0  / p.parts_produced, 2) AS defect_rate_pct,       -- 1.77 %
       ROUND(d.defective_parts * 1000.0 / p.parts_produced, 2) AS defects_per_1000,      -- 17.72
       ROUND(d.total_cost_eur, 2)  AS total_cost_eur,                       -- 28,577.80
       ROUND(d.scrap_cost_eur, 2)  AS scrap_cost_eur,                       -- 12,580.00
       ROUND(d.rework_cost_eur, 2) AS rework_cost_eur                       -- 15,997.80
FROM production AS p
CROSS JOIN defect_totals AS d;
