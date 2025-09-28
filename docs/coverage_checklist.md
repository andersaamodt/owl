# Coverage Remediation Checklist

Tarpaulin reports 90.04% line coverage (1754/1948) which is below the 100% target from `SPEC.md`. The following tasks break down the remaining uncovered paths so we can close the gap methodically.

## Runtime Entrypoints

- [x] `src/bin/owl-daemon.rs` (lines 29-82, 61-70 uncovered): exercise signal handling and shutdown logging by refactoring the loop to accept an injectable termination flag and covering the graceful-stop log path.
- [x] `src/main.rs` (line 13 uncovered): add tests ensuring `execute` handles empty `env` strings without reading from disk.

## CLI Surface

- [ ] `src/cli.rs` (~78 uncovered lines across commands): add coverage for the following scenarios:
  - [ ] `run` default command when `cli.command` is `None` and JSON output is disabled.
  - [ ] `install` branch when `.env` already exists, including verbose log path.
  - [ ] `update` error handling when `ops_install::provision` fails.
  - [ ] `restart` error reporting for failing subprocesses across each `RestartTarget` variant.
  - [ ] `logs` subcommand tail action (streaming and JSON mode).
  - [ ] Import/backup helpers covering gzip error handling and unexpected archive layouts.

## Daemon Services

- [ ] `src/daemon/service.rs` (~26 uncovered lines): cover retry scheduling, error propagation from worker threads, and ensure `stop()` drains handles after multiple dispatcher failures.
- [ ] `src/daemon/watch.rs` (~18 uncovered lines): exercise inotify error branches and debounce timer cancellation logic.

## Operations & Pipelines

- [ ] `src/ops/install.rs` (~18 uncovered lines): test certificate renewal failures and skipped provisioning paths when external commands fail.
- [ ] `src/pipeline/outbox.rs` (~29 uncovered lines): cover the retry backoff calculator, DKIM signer fallbacks, and bounce-handling branches.

## Utilities

- [x] `src/util/dkim.rs` (5 uncovered lines): test key-loading error paths when key parsing fails and when DNS templates are missing.
- [x] `src/util/logging.rs` (5 uncovered lines): cover file-open failures and `tail` when requested entries exceed available data.
- [x] `src/util/time.rs` (line 29 uncovered): add a unit test ensuring zero-duration retention results behave as expected.

## Validation

- [ ] Update CI to run `cargo tarpaulin --out Lcov --fail-under 100` locally before pushing.
- [ ] Once all items are checked, regenerate coverage to confirm 100% line coverage per `SPEC.md`.
