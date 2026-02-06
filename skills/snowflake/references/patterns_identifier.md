# Dynamic temp tables per shard using IDENTIFIER()

## Naming convention

Intermediate tables MUST be suffixed by start_seq + end_seq.

Example names:

- casd_sync_stream0050
- casd_sales_trans_plus0050

Rule: the suffix must be deterministic and derived from the shard (start_seq/end_seq).

## Template: declare + create

    LET t_sync_stream STRING := 'casd_sync_stream' || :start_seq || :end_seq;

    CREATE OR REPLACE TEMPORARY TABLE IDENTIFIER(:t_sync_stream) AS
    SELECT ...
    ;

## Template: reference

Always reference dynamic table names with IDENTIFIER():

    SELECT COUNT(*) FROM IDENTIFIER(:t_sync_stream);

## Template: drop / cleanup

Always drop using IDENTIFIER():

    DROP TABLE IF EXISTS IDENTIFIER(:t_sync_stream);

## Safety rules

- Never reference shard tables by raw string concatenation inside SQL text.
- Prefer IDENTIFIER(:var) rather than EXECUTE IMMEDIATE for object names.
- Keep names short and consistent; avoid including timestamps unless required.
