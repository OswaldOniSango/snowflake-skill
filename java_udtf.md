# Java UDTF pattern (JAR in stage)

## Intent

The UDTF is declared in Snowflake SQL but executed by a Java handler.
The JAR(s) live in a Snowflake stage and are referenced via IMPORTS.

## Template: Java UDTF

    CREATE OR REPLACE FUNCTION <DB>.<SCHEMA>.<UDTF_NAME>(
      <arg1> VARIANT,
      <arg2> VARIANT
    )
    RETURNS TABLE (
      -- columns...
    )
    LANGUAGE JAVA
    IMPORTS = ('@<stage>/<path>/<jar>.jar')
    HANDLER = '<package.ClassName>';

## Rules

- IMPORTS must reference a stage-hosted jar (prefer versioned jars if your org does that).
- HANDLER must match the Java class name exactly.
- Keep the function signature stable; prefer VARIANT for complex JSON payloads.
- If returning timestamps as strings (VARCHAR), document the format (e.g., ISO-8601) and the length.

## Smoke test (mandatory)

After CREATE FUNCTION, provide a minimal smoke test query.

Example:

    SELECT *
    FROM TABLE(<DB>.<SCHEMA>.<UDTF_NAME>(PARSE_JSON('{}'), PARSE_JSON('{}')))
    LIMIT 10;

## Troubleshooting hints

- If you see "Unsupported field type ..." errors, the handler output schema does not match the declared RETURNS TABLE.
- If IMPORTS fails, verify stage path and privileges (USAGE on stage, READ on files).
