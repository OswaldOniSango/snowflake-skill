# Parallel shard processing (00..99) using start_seq/end_seq

## Contract

Procedures intended for parallel tasks MUST support:

- trigger_time TIMESTAMP_NTZ
- action VARCHAR  -- one of: 'Start', 'Process', 'End'
- start_seq VARCHAR  -- two-digit shard start (e.g., '00')
- end_seq   VARCHAR  -- two-digit shard end   (e.g., '50')

Expected behavior:

- WHEN action = 'Start': prepare global staging state (e.g., full stream) and update watermark.
- WHEN action = 'Process': process only the shard defined by start_seq/end_seq.
- WHEN action = 'End': cleanup global staging state.

## Normalization (mandatory)

Always normalize start_seq/end_seq at the beginning of 'Process':

    start_seq := LPAD(:start_seq, 2, '0');
    end_seq   := LPAD(:end_seq, 2, '0');

Recommended validations:

- start_seq and end_seq must be numeric strings after normalization.
- 00 <= start_seq <= end_seq <= 99

## Shard filter (default)

Use suffix-based sharding on site_id:

    WHERE RIGHT(site_id, 2) BETWEEN :start_seq AND :end_seq

## Alternative shard filter (more stable)

If site_id suffix is not reliable, use a hash/mod shard:

    WHERE MOD(ABS(HASH(site_id)), 100)
          BETWEEN TO_NUMBER(:start_seq) AND TO_NUMBER(:end_seq)

## Output guidance

Prefer returning a VARIANT payload including:

- ok, action, start_seq, end_seq
- cntSync (or equivalent key counts)
- min/max time windows used for filtering
- step/phase marker (to locate failures quickly)
