-- =====================================================================
-- Q1. Profile and clean the measurements table
-- Database: spc_capstone (MySQL 8). Run 00_create_and_load_database.sql first.
-- =====================================================================
USE spc_capstone;

-- 1a. How many rows, and how many missing diameters?
--     COUNT(*) counts every row; COUNT(column) skips NULLs,
--     so the difference is the number of missing values.
SELECT COUNT(*)                            AS total_rows,         -- 22,538
       COUNT(*) - COUNT(bore_diameter_mm)  AS missing_diameter    -- 90
FROM measurements;

-- 1b. Impossible diameters: outside 41.9 - 42.1 mm, physically impossible for this part
SELECT COUNT(*) AS impossible_diameter                             -- 14
FROM measurements
-- NULLs are not counted here: NULL NOT BETWEEN ... gives NULL, not TRUE
WHERE bore_diameter_mm NOT BETWEEN 41.9 AND 42.1;

SELECT measurement_id, machine_id, `timestamp`, bore_diameter_mm
FROM measurements
WHERE bore_diameter_mm NOT BETWEEN 41.9 AND 42.1
ORDER BY bore_diameter_mm;

-- 1c. Exact duplicates: the same measurement stored twice under a different measurement_id
SELECT SUM(copies - 1) AS duplicate_rows                           -- 38
FROM (
    SELECT COUNT(*) AS copies
    FROM measurements
    GROUP BY subgroup_id, `timestamp`, machine_id, shift, operator_id, material_lot,
             tool_id, part_seq, bore_diameter_mm, surface_roughness_ra_um
    HAVING COUNT(*) > 1
) AS dup;

-- 1d. Two timestamp formats: ISO (yyyy-mm-dd) and day-first (dd/mm/yyyy, CNC-03 only)
SELECT machine_id,
       SUM(`timestamp` REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}')  AS iso_format,
       SUM(`timestamp` REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}')  AS day_first_format
FROM measurements
GROUP BY machine_id;

-- 1e. Build the clean table
--     * one timestamp format  -> measured_at (DATETIME)
--     * duplicates removed    -> keep the first copy (lowest measurement_id)
--     * diameter_flag         -> OK / Missing / Impossible (rows are kept: roughness is still valid)
--     * bore_diameter_clean   -> the diameter only when the flag is OK, otherwise NULL
DROP TABLE IF EXISTS measurements_clean;

CREATE TABLE measurements_clean AS
SELECT measurement_id, subgroup_id, machine_id, shift, operator_id, material_lot, tool_id, part_seq,
       measured_at, bore_diameter_mm, surface_roughness_ra_um,
       CASE
           WHEN bore_diameter_mm IS NULL                     THEN 'Missing'
           WHEN bore_diameter_mm NOT BETWEEN 41.9 AND 42.1   THEN 'Impossible'
           ELSE 'OK'
       END AS diameter_flag,
       CASE
           WHEN bore_diameter_mm BETWEEN 41.9 AND 42.1 THEN bore_diameter_mm
       END AS bore_diameter_clean
FROM (
    SELECT m.*,
           CASE
               WHEN `timestamp` REGEXP '^[0-9]{4}-' THEN STR_TO_DATE(`timestamp`, '%Y-%m-%d %H:%i')
               ELSE                                      STR_TO_DATE(`timestamp`, '%d/%m/%Y %H:%i')
           END AS measured_at,
           ROW_NUMBER() OVER (
               PARTITION BY subgroup_id, `timestamp`, machine_id, shift, operator_id, material_lot,
                            tool_id, part_seq, bore_diameter_mm, surface_roughness_ra_um
               ORDER BY measurement_id
           ) AS copy_no
    FROM measurements AS m
) AS ranked
WHERE copy_no = 1;

-- 1f. Check the result: 22,500 rows (22,396 OK, 90 Missing, 14 Impossible), no unparsed timestamps
SELECT diameter_flag, COUNT(*) AS n_rows
FROM measurements_clean
GROUP BY diameter_flag;

SELECT COUNT(*)                              AS total_rows,      -- 22,500
       SUM(measured_at IS NULL)              AS unparsed_dates,  -- 0
       MIN(measured_at)                      AS first_measurement,
       MAX(measured_at)                      AS last_measurement
FROM measurements_clean;
