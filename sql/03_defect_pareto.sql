-- =====================================================================
-- Q3. Defect Pareto: rank defect types by quantity, then by cost.
--     Do the two rankings agree?
-- =====================================================================
USE spc_capstone;

-- 3a. Pareto by quantity
--     SUM(...) OVER () is the grand total on every row; the running SUM gives the cumulative share.
WITH by_type AS (
    SELECT defect_type, SUM(quantity) AS qty
    FROM defects
    GROUP BY defect_type
)
SELECT RANK() OVER (ORDER BY qty DESC)                                        AS rank_by_qty,
       defect_type,
       qty,
       ROUND(qty * 100.0 / SUM(qty) OVER (), 1)                               AS share_pct,
       ROUND(SUM(qty) OVER (ORDER BY qty DESC) * 100.0 / SUM(qty) OVER (), 1) AS cumulative_pct
FROM by_type
ORDER BY qty DESC;
-- Surface finish 36.9 % | Burr 23.4 % | Chatter marks 16.0 % | Porosity 11.9 % | Undersize 8.6 % | Oversize 3.3 %

-- 3b. Pareto by cost
WITH by_type AS (
    SELECT defect_type, MIN(disposition) AS disposition, SUM(cost_eur) AS cost_eur
    FROM defects
    GROUP BY defect_type
)
SELECT RANK() OVER (ORDER BY cost_eur DESC)                                             AS rank_by_cost,
       defect_type,
       disposition,
       ROUND(cost_eur, 2)                                                               AS cost_eur,
       ROUND(cost_eur * 100.0 / SUM(cost_eur) OVER (), 1)                               AS share_pct,
       ROUND(SUM(cost_eur) OVER (ORDER BY cost_eur DESC) * 100.0 / SUM(cost_eur) OVER (), 1) AS cumulative_pct
FROM by_type
ORDER BY cost_eur DESC;
-- Porosity 34.4 % | Surface finish 24.3 % | Burr 15.4 % | Chatter marks 10.6 % | Oversize 9.6 % | Undersize 5.7 %

-- 3c. Both rankings side by side
WITH by_type AS (
    SELECT defect_type, SUM(quantity) AS qty, SUM(cost_eur) AS cost_eur
    FROM defects
    GROUP BY defect_type
)
SELECT defect_type,
       RANK() OVER (ORDER BY qty DESC)      AS rank_by_qty,
       RANK() OVER (ORDER BY cost_eur DESC) AS rank_by_cost
FROM by_type
ORDER BY rank_by_cost;
-- Finding: the rankings disagree. Porosity is 4th by quantity but 1st by cost,
-- because porosity parts are scrapped (EUR 18.50 each) while most other defects are reworked (EUR 4.20).

-- 3d. Surface-finish defects by ISO week: the problem is concentrated in one week of May
SELECT WEEK(`date`, 3)  AS iso_week,
       MIN(`date`)      AS week_start,
       SUM(quantity)    AS surface_finish_defects
FROM defects
WHERE defect_type = 'Surface finish'
GROUP BY WEEK(`date`, 3)
ORDER BY surface_finish_defects DESC
LIMIT 5;
