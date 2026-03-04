# Outset Integration Tests

These scripts deploy real test payloads into the outset working directories and verify that each run mode executes them under the correct conditions.

## Prerequisites

- Outset installed at `/usr/local/outset/`
- macOS with all outset launchd daemons and agents loaded
- `sudo` access

## Files

| File | Purpose |
|---|---|
| `setup.zsh` | Deploys test payloads; clears previous results |
| `run_tests.zsh` | Invokes outset in each run mode |
| `verify.zsh` | Reads markers and reports pass/fail |
| `teardown.zsh` | Removes test payloads and results |
| `payloads/*.sh` | One script per run mode; each writes a timestamped marker file |

## Quick start

```zsh
# 1. Deploy payloads and clear old results
sudo ./setup.zsh --clean-run-once

# 2. Exercise each run mode
sudo ./run_tests.zsh

# 3. Check results
./verify.zsh

# 4. (Optional) Test once-type suppression
sudo ./run_tests.zsh --second-pass
./verify.zsh

# 5. Clean up when done
sudo ./teardown.zsh
```

## What each step does

### setup.zsh

- Verifies the Outset binary exists.
- Clears `/private/tmp/outset-test-results/`.
- Copies each `payloads/*.sh` file to the corresponding outset directory (e.g. `boot-once.sh` → `/usr/local/outset/boot-once/boot-once.sh`).
- Sets ownership to `root:wheel` and permissions to `755`.
- With `--clean-run-once`: removes the `run_once` keys from `io.macadmins.Outset` preferences so once-type payloads will execute even if they have run before.

### run_tests.zsh

Runs outset with each flag in sequence:

| Flag | Run mode | Expected behaviour |
|---|---|---|
| `--boot` | Boot | Processes `boot-once` and `boot-every` |
| `--login` | Login | Processes `login-once`, `login-every`; fires privileged trigger |
| `--login-privileged` | Login privileged | Processes `login-privileged-once` and `login-privileged-every` as root |
| `--on-demand` | On-demand | Processes `on-demand` scripts then removes them via `--cleanup` |
| `--on-demand-privileged` | On-demand privileged | Processes `on-demand-privileged` scripts as root |
| `--cleanup` | Cleanup | Removes scripts from on-demand directories after processing |

`--login-window` is **not** exercised here — it only runs in the `LoginWindow` launchd session. See the manual testing note below.

With `--second-pass` the script re-runs all modes so `verify.zsh` can confirm that once-type payloads are suppressed on repeat invocations.

### verify.zsh

For each run mode, checks:

1. **Executed** — the marker file exists and has content.
2. **Root context** — privileged markers contain `uid=0`.
3. **Cleanup** — on-demand scripts have been removed from their directories.
4. **Once-type suppression** (second pass only) — `*-once` payloads did not append a new line after the second-pass timestamp.
5. **Every-type re-run** (second pass only) — `*-every` payloads did append a new line.
6. **Log spot-checks** — the outset log contains expected mode-start messages and no `ERROR` entries.

Exit code `0` = all checks passed; `1` = one or more failures.

### teardown.zsh

Removes all test payload scripts from the outset directories and deletes `/private/tmp/outset-test-results/`. Pass `--keep-results` to preserve the results directory for inspection.

## Manual login-window test

`login-window` scripts run before the user authenticates, in the `LoginWindow` launchd session. To test:

1. Copy `payloads/login-window.sh` (create one if needed) to `/usr/local/outset/login-window/`.
2. Restart the Mac.
3. After reaching the login window (do not log in yet), wait a moment.
4. Log in, then inspect `/usr/local/outset/logs/outset.log` for `login-window` entries.

## Marker file format

Each payload appends one line per execution:

```
boot-once ran at Thu  1 Jan 00:00:00 UTC 2026
login-every ran at Thu  1 Jan 00:00:01 UTC 2026 as bart
login-privileged-every ran at Thu  1 Jan 00:00:02 UTC 2026 as root (uid=0)
```

Marker files are in `/private/tmp/outset-test-results/`.
