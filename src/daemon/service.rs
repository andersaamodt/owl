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

use super::watch::{WatchEventKind, WatchList, WatchService};

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
    let watch = WatchService::spawn(&layout, move |event| {
        let kind = event.kind.clone();
        match (event.list, kind) {
            (WatchList::Outbox, WatchEventKind::Created)
            | (WatchList::Outbox, WatchEventKind::Modified) => {
                if let Err(err) = watch_pipeline.dispatch_pending() {
                    let _ = pipeline_logger.log(
                        LogLevel::Minimal,
                        "daemon.outbox.error",
                        Some(&err.to_string()),
                    );
                }
            }
            (WatchList::Quarantine, WatchEventKind::Created) => {
                let detail = format!("path={}", event.path.display());
                let _ = watch_logger.log(LogLevel::Minimal, "daemon.quarantine", Some(&detail));
            }
            (WatchList::Quarantine, WatchEventKind::Modified) => {
                let detail = format!("path={}", event.path.display());
                let _ = watch_logger.log(
                    LogLevel::VerboseSanitized,
                    "daemon.quarantine.update",
                    Some(&detail),
                );
            }
            (WatchList::Quarantine, WatchEventKind::Error(msg))
            | (WatchList::Outbox, WatchEventKind::Error(msg)) => {
                let _ = watch_logger.log(LogLevel::Minimal, "daemon.watch.error", Some(&msg));
            }
            _ => {}
        }
    })?;

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{filename::outbox_message_filename, message::MessageSidecar};
    use serial_test::serial;
    use std::time::Instant;

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
        let transport: Arc<dyn MailTransport> = Arc::new(SucceedingTransport);
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
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
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
    fn retention_logs_rules_errors() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();

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

    struct SucceedingTransport;

    impl MailTransport for SucceedingTransport {
        fn send(&self, _message: &[u8], _sidecar: &MessageSidecar) -> Result<()> {
            Ok(())
        }
    }
}
