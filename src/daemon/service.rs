use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use anyhow::Result;
use time::OffsetDateTime;

use crate::{
    envcfg::EnvConfig,
    fsops::layout::MailLayout,
    pipeline::{
        outbox::{MailTransport, OutboxPipeline},
        reconcile,
    },
    ruleset::loader::RulesetLoader,
    util::logging::{LogLevel, Logger},
};

use super::watch::{WatchEvent, WatchEventKind, WatchList, WatchService};

#[cfg(test)]
mod test_flags {
    use std::sync::atomic::{AtomicBool, Ordering};

    static FORCE_INITIAL_EVENTS: AtomicBool = AtomicBool::new(false);

    pub struct InitialEventsGuard;

    impl InitialEventsGuard {
        pub fn new() -> Self {
            FORCE_INITIAL_EVENTS.store(true, Ordering::SeqCst);
            Self
        }
    }

    impl Drop for InitialEventsGuard {
        fn drop(&mut self) {
            FORCE_INITIAL_EVENTS.store(false, Ordering::SeqCst);
        }
    }

    pub fn force_initial_events() -> InitialEventsGuard {
        InitialEventsGuard::new()
    }

    pub fn take_initial_events() -> bool {
        FORCE_INITIAL_EVENTS.swap(false, Ordering::SeqCst)
    }
}

pub struct DaemonHandles {
    watch: Option<WatchService>,
    shutdown: Arc<AtomicBool>,
    retention: Option<JoinHandle<()>>,
}

impl DaemonHandles {
    pub fn stop(mut self) {
        self.shutdown.store(true, Ordering::SeqCst);
        if let Some(handle) = self.retention.take() {
            let _ = handle.join();
        }
        // dropping watch stops threads
        let _ = self.watch.take();
    }
}

pub fn start(layout: MailLayout, env: EnvConfig, logger: Logger) -> Result<DaemonHandles> {
    start_with_transport(layout, env, logger, None)
}

pub fn start_with_transport(
    layout: MailLayout,
    env: EnvConfig,
    logger: Logger,
    transport: Option<Arc<dyn MailTransport>>,
) -> Result<DaemonHandles> {
    let shutdown = Arc::new(AtomicBool::new(false));
    let pipeline = if let Some(custom) = transport {
        Arc::new(OutboxPipeline::with_transport(
            layout.clone(),
            env.clone(),
            logger.clone(),
            custom,
        ))
    } else {
        Arc::new(OutboxPipeline::new(
            layout.clone(),
            env.clone(),
            logger.clone(),
        ))
    };
    if let Err(err) = pipeline.dispatch_pending() {
        let _ = logger.log(
            LogLevel::Minimal,
            "daemon.outbox.start_error",
            Some(&err.to_string()),
        );
    }
    let pipeline_logger = logger.clone();
    let watch_pipeline = pipeline.clone();
    let watch_logger = logger.clone();
    let handler = move |event| {
        handle_watch_pipeline_event(
            watch_pipeline.clone(),
            event,
            &pipeline_logger,
            &watch_logger,
        );
    };
    #[cfg(test)]
    if test_flags::take_initial_events() {
        handler(WatchEvent {
            list: WatchList::Outbox,
            path: layout.outbox(),
            kind: WatchEventKind::Created,
        });
        handler(WatchEvent {
            list: WatchList::Outbox,
            path: layout.outbox(),
            kind: WatchEventKind::Error("forced initial error".into()),
        });
    }
    let watch = WatchService::spawn(&layout, handler)?;

    let retention_shutdown = shutdown.clone();
    let retention_logger = logger.clone();
    let layout_for_retention = layout.clone();
    let retention = thread::spawn(move || {
        let loader = RulesetLoader::new(layout_for_retention.root());
        while !retention_shutdown.load(Ordering::Relaxed) {
            match loader.load() {
                Ok(rules) => {
                    let now = OffsetDateTime::now_utc();
                    if let Err(err) =
                        reconcile::enforce_retention(&layout_for_retention, &rules, now)
                    {
                        let _ = retention_logger.log(
                            LogLevel::Minimal,
                            "daemon.retention.error",
                            Some(&err.to_string()),
                        );
                    }
                }
                Err(err) => {
                    let _ = retention_logger.log(
                        LogLevel::Minimal,
                        "daemon.retention.rules_error",
                        Some(&err.to_string()),
                    );
                }
            }
            for _ in 0..60 {
                if retention_shutdown.load(Ordering::Relaxed) {
                    return;
                }
                thread::sleep(Duration::from_secs(1));
            }
        }
    });

    Ok(DaemonHandles {
        watch: Some(watch),
        shutdown,
        retention: Some(retention),
    })
}

fn handle_watch_pipeline_event(
    pipeline: Arc<OutboxPipeline>,
    event: WatchEvent,
    pipeline_logger: &Logger,
    watch_logger: &Logger,
) {
    handle_watch_event(
        event,
        move || pipeline.dispatch_pending().map(|_| ()),
        pipeline_logger,
        watch_logger,
    );
}

fn handle_watch_event<F>(
    event: WatchEvent,
    dispatch: F,
    pipeline_logger: &Logger,
    watch_logger: &Logger,
) where
    F: FnOnce() -> Result<()>,
{
    if event.list == WatchList::Outbox {
        if let WatchEventKind::Created | WatchEventKind::Modified = &event.kind
            && let Err(err) = dispatch()
        {
            let _ = pipeline_logger.log(
                LogLevel::Minimal,
                "daemon.outbox.error",
                Some(&err.to_string()),
            );
        }
        if let WatchEventKind::Error(ref msg) = event.kind {
            let _ = watch_logger.log(LogLevel::Minimal, "daemon.watch.error", Some(msg));
        }
    } else if event.list == WatchList::Quarantine {
        if matches!(&event.kind, WatchEventKind::Created) {
            let detail = format!("path={}", event.path.display());
            let _ = watch_logger.log(LogLevel::Minimal, "daemon.quarantine", Some(&detail));
        } else if matches!(&event.kind, WatchEventKind::Modified) {
            let detail = format!("path={}", event.path.display());
            let _ = watch_logger.log(
                LogLevel::VerboseSanitized,
                "daemon.quarantine.update",
                Some(&detail),
            );
        }
        if let WatchEventKind::Error(ref msg) = event.kind {
            let _ = watch_logger.log(LogLevel::Minimal, "daemon.watch.error", Some(msg));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{filename::outbox_message_filename, message::MessageSidecar};
    use serial_test::serial;
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };
    use std::time::{Duration, Instant};

    #[test]
    fn start_triggers_outbox_dispatch() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig {
            retry_backoff: vec!["1s".into()],
            ..EnvConfig::default()
        };
        let logger = Logger::new(layout.root(), LogLevel::Off).unwrap();
        let transport: Arc<dyn MailTransport> = Arc::new(CountingTransport {
            deliveries: Arc::new(AtomicUsize::new(0)),
        });
        let pipeline = Arc::new(OutboxPipeline::with_transport(
            layout.clone(),
            env.clone(),
            logger.clone(),
            transport.clone(),
        ));
        // queue a draft so dispatch has something to move
        let draft_ulid = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
        std::fs::write(
            &draft_path,
            "---\nsubject: Daemon\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\n---\nHello\n",
        )
        .unwrap();
        pipeline.queue_draft(&draft_path).unwrap();
        // start daemon with the same transport so dispatch succeeds
        let handles =
            start_with_transport(layout.clone(), env, logger.clone(), Some(transport)).unwrap();
        let mut deadline = Instant::now() + Duration::from_secs(5);
        let sent_path = layout.sent().join(outbox_message_filename(&draft_ulid));
        while Instant::now() < deadline {
            if sent_path.exists() {
                break;
            }
            thread::sleep(Duration::from_millis(100));
        }
        if !sent_path.exists() {
            let outbox_file = layout.outbox().join(outbox_message_filename(&draft_ulid));
            let contents = std::fs::read(&outbox_file).unwrap();
            std::fs::write(&outbox_file, contents).unwrap();
            deadline = Instant::now() + Duration::from_secs(5);
            while Instant::now() < deadline {
                if sent_path.exists() {
                    break;
                }
                thread::sleep(Duration::from_millis(100));
            }
        }
        assert!(sent_path.exists());
        handles.stop();
    }

    #[test]
    #[serial]
    fn start_logs_dispatch_errors() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::VerboseSanitized).unwrap();
        let sidecar_path = layout.outbox().join("broken.yml");
        std::fs::write(&sidecar_path, "{ invalid").unwrap();

        let handles = start(layout.clone(), env, logger.clone()).unwrap();
        handles.stop();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.outbox.start_error")
        );
    }

    #[test]
    #[serial]
    fn start_forced_initial_events_invoke_handler() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();

        let _guard = super::test_flags::force_initial_events();
        let handles = start(layout.clone(), env, logger.clone()).unwrap();
        std::thread::sleep(Duration::from_millis(50));
        handles.stop();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.watch.error")
        );
    }

    #[test]
    #[serial]
    fn retention_logs_rules_errors() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::VerboseSanitized).unwrap();

        let rules_path = layout.root().join("accepted/.rules");
        std::fs::create_dir_all(rules_path.parent().unwrap()).unwrap();
        std::fs::write(&rules_path, "invalid").unwrap();

        let handles = start(layout.clone(), env, logger.clone()).unwrap();
        std::thread::sleep(Duration::from_millis(200));
        handles.stop();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.retention.rules_error")
        );
    }

    #[test]
    #[serial]
    fn retention_logs_enforcement_errors() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();

        let settings_path = layout.root().join("spam/.settings");
        std::fs::create_dir_all(settings_path.parent().unwrap()).unwrap();
        std::fs::write(&settings_path, "delete_after=invalid").unwrap();

        let handles = start(layout.clone(), env, logger.clone()).unwrap();
        std::thread::sleep(Duration::from_millis(200));
        handles.stop();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.retention.error")
        );
    }

    #[test]
    #[serial]
    fn retention_removes_expired_messages() {
        use crate::model::{
            filename::{html_filename, message_filename, sidecar_filename},
            message::{HeadersCache, MessageSidecar},
        };
        use crate::util::ulid;
        use time::Duration as TimeDuration;

        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        // Configure accepted list to prune aggressively.
        std::fs::write(layout.accepted().join(".settings"), "delete_after=1d\n").unwrap();

        // Seed an expired message sidecar and related files.
        let sender_dir = layout.accepted().join("alice@example.org");
        std::fs::create_dir_all(&sender_dir).unwrap();
        let ulid = ulid::generate();
        let subject = "Expired message";
        let message_name = message_filename(subject, &ulid);
        let html_name = html_filename(subject, &ulid);
        let sidecar_name = sidecar_filename(subject, &ulid);
        let message_path = sender_dir.join(&message_name);
        std::fs::write(&message_path, b"body").unwrap();
        std::fs::write(sender_dir.join(&html_name), "<p>body</p>").unwrap();
        let mut sidecar = MessageSidecar::new(
            &ulid,
            message_name.clone(),
            "accepted",
            "strict",
            html_name.clone(),
            "hash",
            HeadersCache::new("Alice", subject),
        );
        sidecar.last_activity = (OffsetDateTime::now_utc() - TimeDuration::days(400))
            .format(&time::format_description::well_known::Rfc3339)
            .unwrap();
        let yaml = serde_yaml::to_string(&sidecar).unwrap();
        std::fs::write(sender_dir.join(&sidecar_name), yaml).unwrap();

        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
        let handles = start(layout.clone(), env, logger.clone()).unwrap();

        // Allow the retention worker to run once and then shut it down.
        std::thread::sleep(Duration::from_millis(250));
        handles.stop();

        assert!(
            !message_path.exists(),
            "expired message should be pruned by retention"
        );
        assert!(
            !sender_dir.join(&sidecar_name).exists(),
            "sidecar should be removed alongside the message"
        );
    }

    #[derive(Clone)]
    struct CountingTransport {
        deliveries: Arc<AtomicUsize>,
    }

    impl MailTransport for CountingTransport {
        fn send(&self, _message: &[u8], _sidecar: &MessageSidecar) -> Result<()> {
            self.deliveries.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }
    }

    #[test]
    fn handle_watch_event_dispatch_success_invokes_closure() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
        let counter = Arc::new(AtomicUsize::new(0));
        let dispatch_counter = counter.clone();
        handle_watch_event(
            WatchEvent {
                list: WatchList::Outbox,
                path: layout.outbox(),
                kind: WatchEventKind::Created,
            },
            move || {
                dispatch_counter.fetch_add(1, Ordering::SeqCst);
                Ok(())
            },
            &logger,
            &logger,
        );
        assert_eq!(counter.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn handle_watch_pipeline_event_dispatches_pending_messages() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();

        let deliveries = Arc::new(AtomicUsize::new(0));
        let transport: Arc<dyn MailTransport> = Arc::new(CountingTransport {
            deliveries: Arc::clone(&deliveries),
        });
        let pipeline = Arc::new(OutboxPipeline::with_transport(
            layout.clone(),
            env.clone(),
            logger.clone(),
            transport,
        ));

        let draft_id = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{draft_id}.md"));
        std::fs::write(
            &draft_path,
            "---\nsubject: Dispatch\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\n---\nBody\n",
        )
        .unwrap();
        pipeline.queue_draft(&draft_path).unwrap();

        handle_watch_pipeline_event(
            Arc::clone(&pipeline),
            WatchEvent {
                list: WatchList::Outbox,
                path: layout.outbox().join(outbox_message_filename(&draft_id)),
                kind: WatchEventKind::Created,
            },
            &logger,
            &logger,
        );

        assert_eq!(deliveries.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn handle_watch_event_dispatch_error_is_logged() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
        handle_watch_event(
            WatchEvent {
                list: WatchList::Outbox,
                path: layout.outbox(),
                kind: WatchEventKind::Modified,
            },
            || Err(anyhow::anyhow!("boom")),
            &logger,
            &logger,
        );
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.outbox.error")
        );
    }

    #[test]
    fn handle_watch_event_quarantine_variants_are_logged() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let logger = Logger::new(layout.root(), LogLevel::VerboseSanitized).unwrap();
        handle_watch_event(
            WatchEvent {
                list: WatchList::Quarantine,
                path: layout.quarantine(),
                kind: WatchEventKind::Created,
            },
            || Ok(()),
            &logger,
            &logger,
        );
        handle_watch_event(
            WatchEvent {
                list: WatchList::Quarantine,
                path: layout.quarantine(),
                kind: WatchEventKind::Modified,
            },
            || Ok(()),
            &logger,
            &logger,
        );
        handle_watch_event(
            WatchEvent {
                list: WatchList::Quarantine,
                path: layout.quarantine(),
                kind: WatchEventKind::Error("oops".into()),
            },
            || Ok(()),
            &logger,
            &logger,
        );
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.quarantine")
        );
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.quarantine.update")
        );
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.watch.error")
        );
    }
}
