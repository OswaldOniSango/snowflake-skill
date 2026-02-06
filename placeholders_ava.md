# AVA placeholders (templating variables)

This environment uses deploy-time placeholders that are NOT Snowflake variables.
They must be preserved exactly as-is in generated SQL.

## Schema placeholder

Use `${avacore.schema}` to reference AVA core tables:

- `${avacore.schema}.site`
- `${avacore.schema}.atg`
- `${avacore.schema}.tank`
- `${avacore.schema}.meter_map`
- `${avacore.schema}.fp_meter_to_tank`

Rules:
- Never hardcode the schema for core tables.
- Always use fully qualified: `${avacore.schema}.<table>`.

## Warehouse placeholder

Tasks must use `${avashort.warehouse}`.

Example task snippet (no quotes around the placeholder):

    CREATE OR REPLACE TASK <TASK_NAME>
      WAREHOUSE = ${avashort.warehouse}
      SCHEDULE = '5 minute'
    AS
      CALL <PROC>(SYSDATE(), 'Start', '', '');

## Placeholder quoting rules

- Use unquoted in direct DDL:
  - `WAREHOUSE = ${avashort.warehouse}`

- Use quoted when passing as VARCHAR to dynamic SQL builders:
  - `CALL parallelize_task('<PREFIX>', '<args>', <scale>, '${avashort.warehouse}');`

Do NOT alter placeholder casing or formatting.
