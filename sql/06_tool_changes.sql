-- =====================================================================
-- Q6. Tool changes: list unplanned tool changes and look at defects
--     on those machines in the days around them.
-- =====================================================================
USE spc_capstone;

-- 6a. Tool changes by reason
SELECT reason, COUNT(*) AS n_changes
FROM tool_changes
GROUP BY reason;

-- 6b. The unplanned changes
SELECT machine_id, change_timestamp, tool_id, reason
FROM tool_changes
WHERE reason <> 'Scheduled'
ORDER BY change_timestamp;
-- CNC-02  2026-03-25 10:00  Offset correction
-- CNC-01  2026-05-12 17:30  Breakage

-- 6c. Defects on the same machine from 10 days before to 3 days after each unplanned change
--     (range join: each change is matched with the defect rows of its machine inside the window)
SELECT tc.machine_id,
       tc.reason,
       d.`date`,
       DATEDIFF(d.`date`, DATE(tc.change_timestamp)) AS days_from_change,
       d.defect_type,
       SUM(d.quantity) AS qty
FROM tool_changes AS tc
JOIN defects      AS d
  ON  d.machine_id = tc.machine_id
  AND DATEDIFF(d.`date`, DATE(tc.change_timestamp)) BETWEEN -10 AND 3
WHERE tc.reason <> 'Scheduled'
  AND d.defect_type IN ('Oversize bore', 'Undersize bore', 'Surface finish')
GROUP BY tc.machine_id, tc.reason, d.`date`, DATEDIFF(d.`date`, DATE(tc.change_timestamp)), d.defect_type
ORDER BY tc.machine_id, d.`date`;

-- 6d. CNC-02: oversize defects by day in March, next to the tool changes of that day
--     Oversize parts appear on the days of the scheduled changes (16, 19, 24 March) and stop after
--     the offset correction on 25 March: the offset entered at those tool changes was wrong.
SELECT d.`date`,
       SUM(d.quantity)                                   AS oversize_parts,
       MAX(tc.reason)                                    AS tool_change_that_day
FROM defects AS d
LEFT JOIN tool_changes AS tc
       ON tc.machine_id = d.machine_id
      AND DATE(tc.change_timestamp) = d.`date`
WHERE d.machine_id = 'CNC-02'
  AND d.defect_type = 'Oversize bore'
  AND d.`date` BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY d.`date`
ORDER BY d.`date`;

-- 6e. CNC-01 on 12 May: defects by shift and type around the breakage (17:30, shift B)
SELECT shift, defect_type, SUM(quantity) AS qty
FROM defects
WHERE machine_id = 'CNC-01'
  AND `date` = '2026-05-12'
GROUP BY shift, defect_type
ORDER BY shift, qty DESC;
-- Shift B: undersize and surface-finish defects from the broken tool, before it was replaced at 17:30.
