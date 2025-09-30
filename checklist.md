# Project Checklist

## Coverage Tasks
- [x] Exercise the real signal registration path in `src/bin/owl-daemon.rs` by invoking
  `register_signals` directly and asserting that raising SIGINT/SIGTERM flips the shared
  shutdown flag under coverage. Covered by `tests::register_signals_sets_flag_for_sigint_and_sigterm`.
- [x] Drive the outbox watcher error branch in `src/daemon/service.rs` so
  `handle_watch_event` logs `daemon.watch.error` when `WatchEventKind::Error` is received and
  the dispatcher remains untouched. Covered by `tests::handle_watch_event_outbox_error_is_logged`.

See `docs/coverage_checklist.md` for the full breakdown of remaining coverage work.
