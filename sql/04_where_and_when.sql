-- =====================================================================
-- Q4. Where and when: defect rate (per 1,000 parts) by machine, shift and month
-- =====================================================================
USE spc_capstone;

-- A rate must be (sum of defects) / (sum of parts) for each group, never an average of daily rates.
-- Each table is aggregated to the same grain first, then the two summaries are joined.

-- 4a. By machine
WITH parts AS (
    SELECT machine_id, SUM(parts_produced) AS parts_produced
    FROM production_log
    GROUP BY machine_id
),
defs AS (
    SELECT machine_id, SUM(quantity) AS defective_parts
    FROM defects
    GROUP BY machine_id
)
SELECT p.machine_id,
       p.parts_produced,
       COALESCE(d.defective_parts, 0)                                         AS defective_parts,
       ROUND(COALESCE(d.defective_parts, 0) * 1000.0 / p.parts_produced, 2)  AS defects_per_1000
FROM parts AS p
LEFT JOIN defs AS d ON d.machine_id = p.machine_id
ORDER BY defects_per_1000 DESC;
-- CNC-01 19.79 | CNC-02 18.35 | CNC-03 15.01

-- 4b. By shift
WITH parts AS (
    SELECT shift, SUM(parts_produced) AS parts_produced
    FROM production_log
    GROUP BY shift
),
defs AS (
    SELECT shift, SUM(quantity) AS defective_parts
    FROM defects
    GROUP BY shift
)
SELECT p.shift,
       ROUND(COALESCE(d.defective_parts, 0) * 1000.0 / p.parts_produced, 2) AS defects_per_1000
FROM parts AS p
LEFT JOIN defs AS d ON d.shift = p.shift
ORDER BY p.shift;
-- A 15.54 | B 16.96 | C 20.64

-- 4c. By month
WITH parts AS (
    SELECT MONTH(`date`) AS month_no, SUM(parts_produced) AS parts_produced
    FROM production_log
    GROUP BY MONTH(`date`)
),
defs AS (
    SELECT MONTH(`date`) AS month_no, SUM(quantity) AS defective_parts
    FROM defects
    GROUP BY MONTH(`date`)
)
SELECT p.month_no,
       ROUND(COALESCE(d.defective_parts, 0) * 1000.0 / p.parts_produced, 2) AS defects_per_1000
FROM parts AS p
LEFT JOIN defs AS d ON d.month_no = p.month_no
ORDER BY p.month_no;
-- Jan 9.14 | Feb 8.37 | Mar 10.72 | Apr 11.30 | May 56.08 | Jun 10.15  -> May is the outlier

-- 4d. Is shift C still worse once May is removed? Month x shift, without May
WITH parts AS (
    SELECT MONTH(`date`) AS month_no, shift, SUM(parts_produced) AS parts_produced
    FROM production_log
    GROUP BY MONTH(`date`), shift
),
defs AS (
    SELECT MONTH(`date`) AS month_no, shift, SUM(quantity) AS defective_parts
    FROM defects
    GROUP BY MONTH(`date`), shift
)
SELECT p.shift,
       ROUND(SUM(COALESCE(d.defective_parts, 0)) * 1000.0 / SUM(p.parts_produced), 2) AS defects_per_1000_excl_may
FROM parts AS p
LEFT JOIN defs AS d ON d.month_no = p.month_no AND d.shift = p.shift
WHERE p.month_no <> 5
GROUP BY p.shift
ORDER BY p.shift;
-- A 9.80 | B 8.98 | C 11.16

-- 4e. Shift C by month: when did it start to rise?
WITH parts AS (
    SELECT MONTH(`date`) AS month_no, shift, SUM(parts_produced) AS parts_produced
    FROM production_log
    GROUP BY MONTH(`date`), shift
),
defs AS (
    SELECT MONTH(`date`) AS month_no, shift, SUM(quantity) AS defective_parts
    FROM defects
    GROUP BY MONTH(`date`), shift
)
SELECT p.month_no,
       ROUND(SUM(CASE WHEN p.shift = 'A' THEN d.defective_parts END) * 1000.0
             / SUM(CASE WHEN p.shift = 'A' THEN p.parts_produced END), 2) AS shift_a,
       ROUND(SUM(CASE WHEN p.shift = 'B' THEN d.defective_parts END) * 1000.0
             / SUM(CASE WHEN p.shift = 'B' THEN p.parts_produced END), 2) AS shift_b,
       ROUND(SUM(CASE WHEN p.shift = 'C' THEN d.defective_parts END) * 1000.0
             / SUM(CASE WHEN p.shift = 'C' THEN p.parts_produced END), 2) AS shift_c
FROM parts AS p
LEFT JOIN defs AS d ON d.month_no = p.month_no AND d.shift = p.shift
GROUP BY p.month_no
ORDER BY p.month_no;
-- Shift C is elevated from April (excluding the May spike, which hit all shifts).

-- 4f. Which defect types drove the May spike, and in which ISO week?
SELECT WEEK(`date`, 3) AS iso_week, defect_type, SUM(quantity) AS qty
FROM defects
WHERE MONTH(`date`) = 5
GROUP BY WEEK(`date`, 3), defect_type
ORDER BY qty DESC
LIMIT 6;
