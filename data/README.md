# Data

**This is a generated dataset**, modelled on CNC bore machining and built for practice. The patterns in it (tool wear, a setup error, a tool breakage, a shift effect, a bad material lot and a process improvement) were planted, then found blind in the analysis.

## The process

A plant machines the piston bore of an aluminium brake caliper on three CNC machining centres, 3 shifts a day, Monday to Friday, **5 January to 26 June 2026**.

| | |
|---|---|
| Bore diameter | Nominal 42.000 mm, tolerance ±0.025 → LSL 41.975, USL 42.025 |
| Surface roughness | Ra ≤ 1.6 µm (upper limit only) |
| Sampling | Every 2 hours, 5 consecutive parts per machine (one subgroup) |
| Tools | Changed on a schedule (about every 3 production days), plus unplanned changes |
| Material | Weekly casting lots from three suppliers |

## Raw files

| File | Grain | Columns |
|---|---|---|
| `measurements.csv` | one row per measured part (22,538) | measurement_id, subgroup_id, timestamp, machine_id, shift, operator_id, material_lot, tool_id, part_seq, bore_diameter_mm, surface_roughness_ra_um |
| `production_log.csv` | one row per machine, shift and day | date, shift, machine_id, operator_id, material_lot, parts_produced, downtime_min |
| `defects.csv` | defective parts per machine, shift, day and defect type | defect_record_id, date, shift, machine_id, defect_type, quantity, disposition (Scrap / Rework), cost_eur |
| `tool_changes.csv` | one row per tool change | machine_id, change_timestamp, tool_id, reason (Scheduled / Offset correction / Breakage) |
| `material_lots.csv` | one row per lot | lot_id, supplier_id, received_date, hardness_hb |
| `suppliers.csv`, `machines.csv`, `operators.csv` | reference tables | supplier name and country; machine model and line; operator experience and home shift |

**Keys:**
- `material_lot` → `lot_id` → `supplier_id`;
- `machine_id`, `operator_id` and `tool_id` link the tables directly;
- `production_log` and `defects` join on `date + shift + machine_id`.

**Known data quality issues in `measurements.csv`**, handled in SQL Q1 and Python section 1:
- 90 missing diameters;
- 14 impossible diameters;
- 38 exact duplicate rows;
- two timestamp formats (CNC-03 writes day-first dates).

## Derived files (exported from the Python notebook, used by Power BI)

| File | Content |
|---|---|
| `measurements_clean.csv` | 22,500 parts after cleaning, with `measured_at`, `diameter_flag` and `bore_diameter_clean` |
| `spc_subgroups.csv` | 4,396 complete subgroups with X̄, R, the January control limits and the out-of-control flags |
