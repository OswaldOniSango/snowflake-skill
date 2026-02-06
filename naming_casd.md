# CASD naming conventions (mandatory)

This document defines the canonical naming for the
Create Appropriated Sale Delivery (CASD) pipeline.

These names are NOT optional: do not invent `tmp_*` prefixes.

## Procedure name

Main procedure (SQL):

- `CREATE_APPROPRIATED_SALE_DELIVERY(trigger_time, action, start_seq, end_seq)`

Internal process_name (for transaction tracking / error handler):

- `create_appropriated_sale_delivery`

## Actions

`action` must be one of:

- `Start`
- `Process`
- `End`

(Comparison should be `UPPER(action)`.)

## Global staging table (Start/End)

Created in `Start` and dropped in `End`:

- `casd_sync_full_stream`

Notes:
- This table is GLOBAL (not sharded).
- It is typically TRANSIENT (as in the reference CASD procedure).

## Per-shard reduced stream table (Process)

The shard-reduced stream table must be named:

- `casd_stream<start_seq><end_seq>`

Where:
- `<start_seq>` and `<end_seq>` are 2-digit strings: `00`..`99`
- Use `LPAD(..., 2, '0')`

Example:
- `casd_stream0050`

Rules:
- Must be created and referenced using `IDENTIFIER(:var)` in dynamic SQL.
- Filtering must use:
  - `RIGHT(site_id, 2) BETWEEN :start_seq AND :end_seq`

## Per-shard intermediate tables

All intermediate per-shard tables must follow:

- `casd_<logical_name><start_seq><end_seq>`

Examples (from CASD reference):
- `casd_iso_trans_raw_historical0050`
- `casd_iso_trans_raw_filtered0050`
- `casd_manif_inv_historical0050`
- `casd_manif_inv_filtered0050`
- `casd_manif_inv_plus0050`
- `casd_sales_trans_historical0050`
- `casd_sales_trans_filtered0050`
- `casd_sales_trans_plus0050`
- `casd_del_app_del0050`
- `casd_del_time_windows0050`
- `casd_sale_app_sale0050`
- `casd_mi_json0050`
- `casd_st_json0050`
- `casd_java_in0050`
- `casd_java_out0050`
- `casd_java_out_clean0050`
- `casd_del_hist_out0050`
- `casd_sale_hist_out0050`
- `casd_del_out0050`
- `casd_sale_out0050`

## UDTF name

Java UDTF name:

- `CREATE_APPROPRIATED_SALE_DELIVERY_UDF`

Rules:
- Takes VARIANT JSON arguments (at least `app_sale_dels`, `ava_config`)
- Imports jar from stage and calls Java handler.

## Task names

Start task:

- `CREATE_APPROPRIATED_SALE_DELIVERY_START_TASK`

Parallel tasks pattern (created by `parallelize_task`):

- `CREATE_APPROPRIATED_SALE_DELIVERY_P<N>_TASK`

End task:

- `CREATE_APPROPRIATED_SALE_DELIVERY_END_TASK`

Warehouse placeholder for tasks:
- `WAREHOUSE = ${avashort.warehouse}`
- when passed as string into `parallelize_task`: `'${avashort.warehouse}'`
