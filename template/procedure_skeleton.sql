-- CASD-style Procedure Skeleton (AVA style)
-- Contract: (trigger_time, action, start_seq, end_seq)
-- Actions:
--   Start   -> prepares global staging table(s) and updates watermark(s)
--   Process -> processes a shard defined by start_seq/end_seq (00..99) using IDENTIFIER() temp tables
--   End     -> drops global staging artifacts

CREATE OR REPLACE PROCEDURE <PROC_NAME>(
    trigger_time TIMESTAMP_NTZ(9),
    action       VARCHAR,
    start_seq    VARCHAR,
    end_seq      VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    process_name    VARCHAR DEFAULT '<proc_name_lowercase>';
    phase           VARCHAR DEFAULT 'init';
    result          VARIANT;

    -- global watermark example (optional)
    sync_stream     VARCHAR DEFAULT '<STREAM_NAME>';
    sync_last       TIMESTAMP_NTZ(9);
    sync_new_last   TIMESTAMP_NTZ(9);

    -- dynamic temp table names (suffix = start_seq||end_seq)
    t_sync_stream   VARCHAR;
    t_step1_hist    VARCHAR;
    t_step1_filt    VARCHAR;
    t_java_in       VARCHAR;
    t_java_out      VARCHAR;

    -- counts / metrics
    cnt_sync        NUMBER;
    cnt_step1       NUMBER;

    -- time windows example
    min_time        TIMESTAMP_NTZ(9);
    max_time        TIMESTAMP_NTZ(9);

    error_context   VARIANT;

BEGIN
    -------------------------------------------------------------------------
    -- Normalize action
    -------------------------------------------------------------------------
    phase := 'normalize_action';
    CASE UPPER(action)

    WHEN 'START' THEN
        ---------------------------------------------------------------------
        -- START: build global staging stream and update watermark
        ---------------------------------------------------------------------
        phase := 'start_load_watermark';

        -- Example: read last processed watermark (you can remove if not used)
        sync_last := (SELECT last_update_processed
                      FROM update_stream
                      WHERE stream_name = :sync_stream);

        -- Example global staging (TRANSIENT or TEMP depending on your pattern)
        -- In your CASD, this is casd_sync_full_stream.
        phase := 'start_create_global_stream';
        CREATE OR REPLACE TRANSIENT TABLE <GLOBAL_STREAM_TABLE> AS (
        SELECT *
        FROM <BASE_STREAM_TABLE>
        WHERE last_update_timestamp > :sync_last
          AND start_time >= :trigger_time - INTERVAL '3 DAYS'
          AND record_state NOT IN ('Error', 'Deleted')
        );

        -- Update stresm from what you actually staged
        phase := 'start_update_watermark';
        sync_new_last := (SELECT MAX(last_update_timestamp) FROM <GLOBAL_STREAM_TABLE>);

        UPDATE update_stream
           SET last_update_processed = :sync_new_last
         WHERE stream_name = :sync_stream
           AND :sync_new_last > last_update_processed;

        RETURN 'START';

    WHEN 'END' THEN
        ---------------------------------------------------------------------
        -- END: cleanup global staging table(s)
        ---------------------------------------------------------------------
        phase := 'end_cleanup';
        DROP TABLE IF EXISTS <GLOBAL_STREAM_TABLE>;

        RETURN 'END';

    ELSE
        ---------------------------------------------------------------------
        -- PROCESS: shard execution
        ---------------------------------------------------------------------
        phase := 'process_normalize_shard';

        -- build dynamic table names with shard suffix
        phase := 'process_build_table_names';
        t_sync_stream := 'tmp_sync_stream' || :start_seq || :end_seq;
        t_step1_hist  := 'tmp_step1_hist'  || :start_seq || :end_seq;
        t_step1_filt  := 'tmp_step1_filt'  || :start_seq || :end_seq;
        t_java_in     := 'tmp_java_in'     || :start_seq || :end_seq;
        t_java_out    := 'tmp_java_out'    || :start_seq || :end_seq;

        ---------------------------------------------------------------------
        -- Example: create reduced stream for this shard
        ---------------------------------------------------------------------
        phase := 'process_create_shard_stream';
        CREATE OR REPLACE TEMPORARY TABLE IDENTIFIER(:t_sync_stream) AS (
            SELECT *
            FROM <GLOBAL_STREAM_TABLE>
            WHERE RIGHT(site_id, 2) BETWEEN :start_seq AND :end_seq
        );

        cnt_sync := (SELECT COUNT(*) FROM IDENTIFIER(:t_sync_stream));

        IF (cnt_sync = 0) THEN
            phase := 'process_no_data_cleanup';
            
            DROP TABLE IF EXISTS IDENTIFIER(:t_sync_stream);

            RETURN 'OK'
        END IF;

        ---------------------------------------------------------------------
        -- Example Step 1: compute time window from shard stream
        ---------------------------------------------------------------------
        phase := 'process_compute_window';
        min_time := (SELECT MIN(start_time) FROM IDENTIFIER(:t_sync_stream));
        max_time := (SELECT MAX(end_time)   FROM IDENTIFIER(:t_sync_stream));

        ---------------------------------------------------------------------
        -- Example Step 2: create historical + filtered tables
        ---------------------------------------------------------------------
        phase := 'process_step1_historical';
        CREATE OR REPLACE TEMPORARY TABLE IDENTIFIER(:t_step1_hist) AS (
            SELECT *
            FROM <BASE_TABLE_1> b
            WHERE b.end_time BETWEEN :min_time AND :max_time
        );

        phase := 'process_step1_filtered';
        CREATE OR REPLACE TEMPORARY TABLE IDENTIFIER(:t_step1_filt) AS (
            SELECT b.*
            FROM IDENTIFIER(:t_step1_hist) b
            INNER JOIN IDENTIFIER(:t_sync_stream) s
                ON b.site_id = s.site_id
            AND b.atg_id  = s.atg_id
            AND b.process_path = s.process_path
            WHERE b.record_state NOT IN ('Error', 'Deleted')
        );

        cnt_step1 := (SELECT COUNT(*) FROM IDENTIFIER(:t_step1_filt));

        ---------------------------------------------------------------------
        -- Example Step 3: create Java input JSON and call UDTF
        ---------------------------------------------------------------------
        phase := 'process_java_in';
        CREATE OR REPLACE TEMPORARY TABLE IDENTIFIER(:t_java_in) AS (
            SELECT
                s.site_id,
                s.atg_id,
                s.process_path,
                OBJECT_CONSTRUCT(
                    'isolatedTransaction', OBJECT_CONSTRUCT(
                        'siteId', s.site_id,
                        'atgId', s.atg_id,
                        'processPath', s.process_path,
                        'earliestMiddleTime', :min_time,
                        'latestMiddleTime', :max_time
                    ),
                    'payload', OBJECT_CONSTRUCT(
                        'exampleCount', :cnt_step1
                    )
                ) AS app_sale_dels,
                get_config_list_by_tank(s.site_id, s.atg_id, s.primary_tank_num) AS ava_config
            FROM IDENTIFIER(:t_sync_stream) s
        );

        phase := 'process_java_out';
        CREATE OR REPLACE TEMPORARY TABLE IDENTIFIER(:t_java_out) AS (
            SELECT * EXCLUDE(app_sale_dels, ava_config)
            FROM IDENTIFIER(:t_java_in) inp,
            TABLE(
                <JAVA_UDTF_NAME>(
                    inp.app_sale_dels::VARIANT,
                    inp.ava_config::VARIANT
                )
            ) outp
        );

        ---------------------------------------------------------------------
        -- TODO: your merge logic (MERGE INTO target tables)
        ---------------------------------------------------------------------
        phase := 'process_merge_targets';
        -- MERGE INTO <target> USING IDENTIFIER(:t_java_out) ...

        ---------------------------------------------------------------------
        -- Cleanup per-shard temp tables
        ---------------------------------------------------------------------
        phase := 'process_cleanup';
        DROP TABLE IF EXISTS IDENTIFIER(:t_java_out);
        DROP TABLE IF EXISTS IDENTIFIER(:t_java_in);
        DROP TABLE IF EXISTS IDENTIFIER(:t_step1_filt);
        DROP TABLE IF EXISTS IDENTIFIER(:t_step1_hist);
        DROP TABLE IF EXISTS IDENTIFIER(:t_sync_stream);

        RETURN 'OK';
    END CASE;

EXCEPTION WHEN OTHER THEN
    -------------------------------------------------------------------------
    -- Error handling + cleanup
    -------------------------------------------------------------------------
    error_context := OBJECT_CONSTRUCT(
        'phase', :phase,
        'action', :action,
        'start_seq', :start_seq,
        'end_seq', :end_seq
    );

    -- if you have a standard error handler, call it here:
    -- CALL handle_error(:process_name, :SQLCODE, :SQLSTATE, :SQLERRM, :error_context);

    -- best-effort cleanup (only drop if vars were set)
    DROP TABLE IF EXISTS IDENTIFIER(:t_java_out);
    DROP TABLE IF EXISTS IDENTIFIER(:t_java_in);
    DROP TABLE IF EXISTS IDENTIFIER(:t_step1_filt);
    DROP TABLE IF EXISTS IDENTIFIER(:t_step1_hist);
    DROP TABLE IF EXISTS IDENTIFIER(:t_sync_stream);

    RETURN 'NOT OK'
END;
$$
;
