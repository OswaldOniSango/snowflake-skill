# Task parallelization orchestrator (parallelize_task)

## Purpose

The `parallelize_task` procedure creates a fan-out/fan-in task graph:

- Requires a `<PREFIX>_START_TASK` to exist.
- Creates `<PREFIX>_P<N>_TASK` tasks (N = 1..scale) that run AFTER `<PREFIX>_START_TASK`.
- Creates a `<PREFIX>_END_TASK` that runs AFTER all `<PREFIX>_P<N>_TASK` tasks.
- Drops any previous `<PREFIX>_P<N>_TASK` and `<PREFIX>_END_TASK` before recreating.

## Call signature contract (mandatory)

All tasks created by this orchestrator must call a procedure named exactly `<PREFIX>`.

That procedure MUST support the argument shape:

    (<ARGS>, 'Process', <start_range>, <end_range>)

Where:
- `<ARGS>` is an optional comma-separated list of args that come before the three mandatory parallelization args.
- `'Process'`, `<start_range>`, `<end_range>` are always present.

The START task MUST call:

    (<ARGS>, 'Start', '', '')

The END task MUST call:

    (<ARGS>, 'End', '', '')

## Shard range formatting

Start/end ranges MUST be two-digit strings:

- '00'..'99'
- use LPAD to 2 inside the orchestrator and/or inside the target procedure.

## Warehouse placeholder rules

Tasks created by DDL should use the environment placeholder:

    WAREHOUSE = ${avashort.warehouse}

When passing the warehouse as a VARCHAR into `parallelize_task`, it must be quoted:

    CALL parallelize_task('<PREFIX>', '<args>', <scale>, '${avashort.warehouse}');

Reason: the orchestrator injects that string into a CREATE TASK statement.

## Safety guidance

- Validate `task_name_prefix` to allow only [A-Z0-9_].
- Validate `scale` is a small integer (e.g., 1..20).
- Reject args containing ';' to prevent accidental multi-statement execution.
