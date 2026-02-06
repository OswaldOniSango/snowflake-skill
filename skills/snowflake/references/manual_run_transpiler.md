# Manual Run Transpiler (SP -> Worksheet) — AVA Style

Goal:
Given a Snowflake SQL stored procedure (LANGUAGE SQL) that uses AVA conventions
(Start/Process/End, shard args, dynamic IDENTIFIER tables), generate an
EXECUTABLE Snowsight Worksheet script that can be run manually.

This is referred to as "Option C" (Manual Worksheet Mode).

---

## Input expected

A procedure body that contains:
- SP-scoped variables referenced as `:var`
- Assignments using `:=` and/or `LET`
- Control flow (CASE/IF/ELSE)
- Dynamic objects using `IDENTIFIER(:nameVar)`
- AVA placeholders like `${avacore.schema}` and `${avashort.warehouse}` (keep them)

---

## Output required

Produce a single SQL worksheet script (no CREATE PROCEDURE) that:
- Declares input parameters as worksheet variables via `SET`
- Replaces SP variable syntax with worksheet syntax
- Preserves dynamic table usage via `IDENTIFIER($var)`
- Splits into clear sections: PREP / START / PROCESS / END / CLEANUP
- Includes optional gating (`cntSync`) to skip PROCESS if no data

The output must be copy/paste runnable.

---

## Variable syntax rules

### 1) References
Replace SP bind-style references:
- `:var`  ->  `$var`

Examples:
- `WHERE stream_name = :sync_stream` -> `WHERE stream_name = $sync_stream`
- `RIGHT(site_id,2) BETWEEN :start_seq AND :end_seq` -> `RIGHT(site_id,2) BETWEEN $start_seq AND $end_seq`

### 2) Assignments
Replace SP assignment forms with worksheet SET:
- `var := <expr>;` -> `SET var = <expr>;`
- `LET var <type> := <expr>;` -> `SET var = <expr>;`
- `LET var := <expr>;` -> `SET var = <expr>;`

Do not emit DECLARE/BEGIN/END in worksheet output.

### 3) Types
Worksheet `SET` does not need explicit types.
If the SP uses typed DECLARE, drop the type.

### 4) Default inputs
If SP has inputs (trigger_time, action, start_seq, end_seq), the worksheet MUST define them:

Required header template:
- `SET trigger_time = '<timestamp>'::timestamp_ntz;`
- `SET action = 'Start';` (or run Start/Process/End as separate sections)
- `SET start_seq = '00';`
- `SET end_seq = '99';`

Shard inputs MUST be two-digit strings ('00'..'99').

---

## IDENTIFIER rules (dynamic tables)

Replace:
- `identifier(:x)` -> `IDENTIFIER($x)`

Dynamic table name variables MUST be built using worksheet variables:
- `SET casd_stream = 'casd_stream' || $start_seq || $end_seq;`

Never hardcode shard table names inside the worksheet.

---

## Control flow conversion

### A) CASE action (preferred)
If procedure branches by action (Start/End/Process), the worksheet output should emit 3 explicit blocks:

1) START block (equivalent to action='Start')
2) PROCESS block (equivalent to action='Process')
3) END block (equivalent to action='End')

Do NOT rely on SP CASE/IF at runtime; instead emit the blocks separately.

### B) IF gating (cntSync)
If SP uses:
- `cntSync := (SELECT COUNT(*) ... )`
- `IF (cntSync > 0) THEN ... ELSE ... END IF;`

Then the worksheet output must include:

1) `SET cntSync = (SELECT COUNT(*) FROM IDENTIFIER($stream_table));`
2) A visible probe:
   - `SELECT 'gate' AS step, $cntSync AS cntSync;`

3) One of these strategies:

**Strategy 1 (recommended):**
Emit PROCESS steps normally, but clearly mark: "Run the next section only if cntSync > 0".
This is the most compatible across clients.

**Strategy 2 (advanced):**
Use `EXECUTE IMMEDIATE` to conditionally execute a generated SQL block:
- Build `SET work_sql = $$ ... $$;`
- Execute: `EXECUTE IMMEDIATE IFF($cntSync > 0, $work_sql, 'SELECT ''SKIPPED'';');`

Use Strategy 2 only if the user explicitly requests full automation.

---

## RETURN / EXCEPTION handling

Worksheet cannot `RETURN`.
Replace return statements with status selects:
- `RETURN 'OK';` -> `SELECT 'OK' AS status;`

Exception blocks cannot be replicated.
Instead:
- Keep the cleanup steps.
- Optionally emit a note: "On failure, run CLEANUP section".

If the procedure calls `handle_error(...)`, you may include an optional manual call template:
- `-- Optional: CALL handle_error(...);` (do not invent args)

---

## AVA placeholders preservation

Placeholders are NOT Snowflake variables. Preserve EXACTLY:
- `${avacore.schema}`
- `${avashort.warehouse}`

Do not change casing, quoting, or formatting.

When output contains AVA core tables:
Always use `${avacore.schema}.<table>` (never hardcode schema).

---

## Naming conventions for manual-run scripts

The transpiler output should name its dynamic tables using the procedure prefix.

Rule:
- If procedure is `CREATE_APPROPRIATED_SALE_DELIVERY`, prefix is `casd_`.
- The shard stream temp table should be:
  - `casd_stream` or `casd_sync_stream` (project-specific; follow naming_casd.md if present)

When the user provides a naming override, obey it.

---

## Output format requirements

The worksheet script must be formatted with:
- Section headers (comment banners)
- A single `SET` inputs section at the top
- Minimal assumptions (do not add extra filters unless user provides them)
- Drop statements grouped at the end as CLEANUP

Always keep code blocks intact (no missing fences).
