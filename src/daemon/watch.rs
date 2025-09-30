use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, mpsc};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use anyhow::Result;
use notify::event::{CreateKind, DataChange, ModifyKind, RemoveKind};
use notify::{Config, EventKind, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher};

use crate::fsops::layout::MailLayout;

#[cfg(test)]
mod test_flags {
    use std::sync::atomic::{AtomicBool, Ordering};

    static FORCE_RECOMMENDED_FAILURE: AtomicBool = AtomicBool::new(false);
    static FORCE_WATCH_FAILURE: AtomicBool = AtomicBool::new(false);
    static FORCE_RECOMMENDED_CONSTRUCTOR_ERROR: AtomicBool = AtomicBool::new(false);
    static FORCE_POLL_WATCHER_ERROR: AtomicBool = AtomicBool::new(false);
    static FORCE_WATCH_REGISTER_ERROR: AtomicBool = AtomicBool::new(false);

    pub struct RecommendedFailureGuard;

    impl RecommendedFailureGuard {
        pub fn new() -> Self {
            FORCE_RECOMMENDED_FAILURE.store(true, Ordering::SeqCst);
            Self
        }
    }

    impl Drop for RecommendedFailureGuard {
        fn drop(&mut self) {
            FORCE_RECOMMENDED_FAILURE.store(false, Ordering::SeqCst);
        }
    }

    #[allow(dead_code)]
    pub struct WatchFailureGuard;

    #[allow(dead_code)]
    impl WatchFailureGuard {
        pub fn new() -> Self {
            FORCE_WATCH_FAILURE.store(true, Ordering::SeqCst);
            Self
        }
    }

    #[allow(dead_code)]
    impl Drop for WatchFailureGuard {
        fn drop(&mut self) {
            FORCE_WATCH_FAILURE.store(false, Ordering::SeqCst);
        }
    }

    pub struct RecommendedConstructorErrorGuard;

    impl RecommendedConstructorErrorGuard {
        pub fn new() -> Self {
            FORCE_RECOMMENDED_CONSTRUCTOR_ERROR.store(true, Ordering::SeqCst);
            Self
        }
    }

    impl Drop for RecommendedConstructorErrorGuard {
        fn drop(&mut self) {
            FORCE_RECOMMENDED_CONSTRUCTOR_ERROR.store(false, Ordering::SeqCst);
        }
    }

    pub struct PollWatcherErrorGuard;

    impl PollWatcherErrorGuard {
        pub fn new() -> Self {
            FORCE_POLL_WATCHER_ERROR.store(true, Ordering::SeqCst);
            Self
        }
    }

    impl Drop for PollWatcherErrorGuard {
        fn drop(&mut self) {
            FORCE_POLL_WATCHER_ERROR.store(false, Ordering::SeqCst);
        }
    }

    pub struct WatchRegisterErrorGuard;

    impl WatchRegisterErrorGuard {
        pub fn new() -> Self {
            FORCE_WATCH_REGISTER_ERROR.store(true, Ordering::SeqCst);
            Self
        }
    }

    impl Drop for WatchRegisterErrorGuard {
        fn drop(&mut self) {
            FORCE_WATCH_REGISTER_ERROR.store(false, Ordering::SeqCst);
        }
    }

    pub fn force_recommended_failure() -> RecommendedFailureGuard {
        RecommendedFailureGuard::new()
    }

    #[allow(dead_code)]
    pub fn force_watch_failure() -> WatchFailureGuard {
        WatchFailureGuard::new()
    }

    pub fn take_recommended_failure() -> bool {
        FORCE_RECOMMENDED_FAILURE.swap(false, Ordering::SeqCst)
    }

    pub fn take_watch_failure() -> bool {
        FORCE_WATCH_FAILURE.swap(false, Ordering::SeqCst)
    }

    pub fn force_recommended_constructor_error() -> RecommendedConstructorErrorGuard {
        RecommendedConstructorErrorGuard::new()
    }

    pub fn take_recommended_constructor_error() -> bool {
        FORCE_RECOMMENDED_CONSTRUCTOR_ERROR.swap(false, Ordering::SeqCst)
    }

    pub fn force_poll_watcher_error() -> PollWatcherErrorGuard {
        PollWatcherErrorGuard::new()
    }

    pub fn take_poll_watcher_error() -> bool {
        FORCE_POLL_WATCHER_ERROR.swap(false, Ordering::SeqCst)
    }

    pub fn force_watch_register_error() -> WatchRegisterErrorGuard {
        WatchRegisterErrorGuard::new()
    }

    pub fn take_watch_register_error() -> bool {
        FORCE_WATCH_REGISTER_ERROR.swap(false, Ordering::SeqCst)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WatchList {
    Quarantine,
    Outbox,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WatchEventKind {
    Created,
    Modified,
    Removed,
    Error(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WatchEvent {
    pub list: WatchList,
    pub path: std::path::PathBuf,
    pub kind: WatchEventKind,
}

pub struct WatchService {
    shutdown: Arc<AtomicBool>,
    threads: Vec<JoinHandle<()>>,
}

type Handler = Arc<dyn Fn(WatchEvent) + Send + Sync + 'static>;

impl WatchService {
    pub fn spawn<F>(layout: &MailLayout, handler: F) -> Result<Self>
    where
        F: Fn(WatchEvent) + Send + Sync + 'static,
    {
        let handler: Handler = Arc::new(handler);
        let shutdown = Arc::new(AtomicBool::new(false));
        let mut threads = Vec::new();

        for (list, path) in [
            (WatchList::Quarantine, layout.quarantine()),
            (WatchList::Outbox, layout.outbox()),
        ] {
            std::fs::create_dir_all(&path)?;
            let handler_for_error = Arc::clone(&handler);
            let handler_for_loop = Arc::clone(&handler_for_error);
            let shutdown_flag = Arc::clone(&shutdown);
            let watch_path = path.clone();
            let error_path = path;
            let handle = thread::spawn(move || {
                if let Err(err) = watch_loop(list, watch_path, handler_for_loop, shutdown_flag) {
                    handler_for_error(WatchEvent {
                        list,
                        path: error_path,
                        kind: WatchEventKind::Error(err.to_string()),
                    });
                }
            });
            threads.push(handle);
        }

        Ok(Self { shutdown, threads })
    }
}

impl Drop for WatchService {
    fn drop(&mut self) {
        self.shutdown.store(true, Ordering::SeqCst);
        for handle in self.threads.drain(..) {
            let _ = handle.join();
        }
    }
}

#[allow(dead_code)]
fn forward_event(
    sender: &mpsc::Sender<notify::Result<notify::Event>>,
    res: notify::Result<notify::Event>,
) {
    let _ = sender.send(res);
}

fn make_recommended_watcher(
    tx: &mpsc::Sender<notify::Result<notify::Event>>,
    config: Config,
) -> notify::Result<RecommendedWatcher> {
    #[cfg(test)]
    {
        if test_flags::take_recommended_constructor_error() {
            return Err(notify::Error::generic(
                "recommended watcher failed: forced constructor error",
            ));
        }
    }
    RecommendedWatcher::new(
        {
            let sender = tx.clone();
            move |res| forward_event(&sender, res)
        },
        config,
    )
}

fn make_poll_watcher(
    tx: &mpsc::Sender<notify::Result<notify::Event>>,
    config: Config,
) -> notify::Result<PollWatcher> {
    #[cfg(test)]
    {
        if test_flags::take_poll_watcher_error() {
            return Err(notify::Error::generic(
                "poll watcher failed: forced for test",
            ));
        }
    }
    PollWatcher::new(
        {
            let sender = tx.clone();
            move |res| forward_event(&sender, res)
        },
        config,
    )
}

fn watch_loop(
    list: WatchList,
    path: std::path::PathBuf,
    handler: Handler,
    shutdown: Arc<AtomicBool>,
) -> Result<()> {
    let (tx, rx) = mpsc::channel();
    let config = Config::default().with_poll_interval(Duration::from_millis(200));
    let mut watchers: Vec<Box<dyn Watcher + Send>> = Vec::new();

    let forced_recommended_failure = {
        #[cfg(test)]
        {
            test_flags::take_recommended_failure()
        }
        #[cfg(not(test))]
        {
            false
        }
    };

    if forced_recommended_failure {
        handler(WatchEvent {
            list,
            path: path.clone(),
            kind: WatchEventKind::Error("recommended watcher failed: forced for test".to_string()),
        });
    } else {
        let recommended = make_recommended_watcher(&tx, config);

        match recommended {
            Ok(watcher) => watchers.push(Box::new(watcher)),
            Err(err) => handler(WatchEvent {
                list,
                path: path.clone(),
                kind: WatchEventKind::Error(format!("recommended watcher failed: {err}")),
            }),
        }
    }

    let poll = make_poll_watcher(&tx, config)?;
    watchers.push(Box::new(poll));

    for watcher in watchers.iter_mut() {
        #[cfg(test)]
        if test_flags::take_watch_failure() {
            handler(WatchEvent {
                list,
                path: path.clone(),
                kind: WatchEventKind::Error("watch failed: forced for test".into()),
            });
            continue;
        }

        let watch_result = {
            #[cfg(test)]
            {
                if test_flags::take_watch_register_error() {
                    Err(notify::Error::generic(
                        "watch registration failed: forced for test",
                    ))
                } else {
                    watcher.watch(&path, RecursiveMode::Recursive)
                }
            }
            #[cfg(not(test))]
            {
                watcher.watch(&path, RecursiveMode::Recursive)
            }
        };

        if let Err(err) = watch_result {
            handler(WatchEvent {
                list,
                path: path.clone(),
                kind: WatchEventKind::Error(format!("watch failed: {err}")),
            });
        }
    }

    while !shutdown.load(Ordering::Relaxed) {
        let result = rx.recv_timeout(Duration::from_millis(200));
        if !handle_received_event(list, &handler, &path, result) {
            break;
        }
    }

    Ok(())
}

fn handle_received_event(
    list: WatchList,
    handler: &Handler,
    path: &std::path::Path,
    result: Result<Result<notify::Event, notify::Error>, mpsc::RecvTimeoutError>,
) -> bool {
    match result {
        Ok(Ok(event)) => {
            dispatch_event(list, handler, event);
            true
        }
        Ok(Err(err)) => {
            handler(WatchEvent {
                list,
                path: path.to_path_buf(),
                kind: WatchEventKind::Error(err.to_string()),
            });
            true
        }
        Err(mpsc::RecvTimeoutError::Timeout) => true,
        Err(mpsc::RecvTimeoutError::Disconnected) => false,
    }
}

fn dispatch_event(list: WatchList, handler: &Handler, event: notify::Event) {
    if let Some(kind) = classify_event(&event.kind) {
        for path in event.paths {
            handler(WatchEvent {
                list,
                path,
                kind: kind.clone(),
            });
        }
    }
}

fn classify_event(kind: &EventKind) -> Option<WatchEventKind> {
    match kind {
        EventKind::Create(CreateKind::Any | CreateKind::File | CreateKind::Folder) => {
            Some(WatchEventKind::Created)
        }
        EventKind::Create(_) => None,
        EventKind::Modify(ModifyKind::Any)
        | EventKind::Modify(ModifyKind::Data(DataChange::Content))
        | EventKind::Modify(ModifyKind::Data(DataChange::Any))
        | EventKind::Modify(ModifyKind::Metadata(_))
        | EventKind::Modify(ModifyKind::Name(_)) => Some(WatchEventKind::Modified),
        EventKind::Remove(RemoveKind::Any | RemoveKind::File | RemoveKind::Folder) => {
            Some(WatchEventKind::Removed)
        }
        EventKind::Remove(_) => None,
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fsops::layout::MailLayout;
    use notify::event::{AccessKind, CreateKind, DataChange, MetadataKind, ModifyKind, RemoveKind};
    use notify::{Error as NotifyError, Event, EventKind};
    use std::path::PathBuf;
    use std::sync::atomic::AtomicBool;
    use std::sync::{Arc, Mutex, mpsc};
    use std::time::Duration;

    #[test]
    fn forward_event_sends_result() {
        let (tx, rx) = mpsc::channel();
        forward_event(&tx, Ok(Event::new(EventKind::Create(CreateKind::File))));
        let event = rx.recv_timeout(Duration::from_millis(100)).unwrap();
        assert!(event.is_ok());
    }

    #[test]
    fn watcher_emits_quarantine_events() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let (tx, rx) = mpsc::channel();
        let _service = WatchService::spawn(&layout, move |event| {
            tx.send(event).unwrap();
        })
        .unwrap();

        std::thread::sleep(Duration::from_millis(200));

        let sender_dir = layout.quarantine().join("alice@example.org");
        std::fs::create_dir_all(&sender_dir).unwrap();
        let message_path = sender_dir.join("Hello (01ARZ3NDEKTSV4RRFFQ69G5FAV).eml");
        std::fs::write(&message_path, b"hello").unwrap();

        let event = wait_for_path(&rx, &message_path);
        assert_eq!(event.list, WatchList::Quarantine);
        assert!(matches!(
            event.kind,
            WatchEventKind::Created | WatchEventKind::Modified
        ));
    }

    #[test]
    fn watcher_emits_outbox_events() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let (tx, rx) = mpsc::channel();
        let _service = WatchService::spawn(&layout, move |event| {
            tx.send(event).unwrap();
        })
        .unwrap();

        std::thread::sleep(Duration::from_millis(200));

        let message_path = layout.outbox().join("01ARZ3NDEKTSV4RRFFQ69G5FAV.eml");
        std::fs::write(&message_path, b"queued").unwrap();

        let event = wait_for_path(&rx, &message_path);
        assert_eq!(event.list, WatchList::Outbox);
        assert!(matches!(
            event.kind,
            WatchEventKind::Created | WatchEventKind::Modified
        ));
    }

    #[test]
    fn classify_event_covers_all_variants() {
        assert_eq!(
            classify_event(&EventKind::Create(CreateKind::File)),
            Some(WatchEventKind::Created)
        );
        assert_eq!(
            classify_event(&EventKind::Modify(ModifyKind::Data(DataChange::Content))),
            Some(WatchEventKind::Modified)
        );
        assert_eq!(
            classify_event(&EventKind::Modify(ModifyKind::Metadata(
                MetadataKind::Permissions
            ))),
            Some(WatchEventKind::Modified)
        );
        assert_eq!(
            classify_event(&EventKind::Remove(RemoveKind::Folder)),
            Some(WatchEventKind::Removed)
        );
        assert!(classify_event(&EventKind::Create(CreateKind::Other)).is_none());
        assert!(classify_event(&EventKind::Remove(RemoveKind::Other)).is_none());
        assert!(classify_event(&EventKind::Access(AccessKind::Any)).is_none());
    }

    #[test]
    fn dispatch_event_emits_for_each_path() {
        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event: WatchEvent| {
                seen.lock().unwrap().push(event);
            })
        };
        let event = notify::Event {
            kind: EventKind::Remove(RemoveKind::File),
            paths: vec![PathBuf::from("a"), PathBuf::from("b")],
            attrs: Default::default(),
        };
        dispatch_event(WatchList::Outbox, &handler, event);
        let events = seen.lock().unwrap();
        assert_eq!(events.len(), 2);
        assert!(events.iter().all(|e| e.kind == WatchEventKind::Removed));
        assert!(events.iter().any(|e| e.path.ends_with("a")));
        assert!(events.iter().any(|e| e.path.ends_with("b")));
    }

    #[test]
    fn dispatch_event_ignores_unclassified() {
        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event: WatchEvent| {
                seen.lock().unwrap().push(event);
            })
        };
        let event = notify::Event {
            kind: EventKind::Create(CreateKind::Other),
            paths: vec![PathBuf::from("ignored")],
            attrs: Default::default(),
        };
        dispatch_event(WatchList::Quarantine, &handler, event);
        assert!(seen.lock().unwrap().is_empty());
    }

    #[test]
    fn watch_loop_reports_recommended_watcher_failure() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event| {
                seen.lock().unwrap().push(event);
            })
        };

        let _guard = super::test_flags::force_recommended_failure();
        let shutdown = Arc::new(AtomicBool::new(true));
        watch_loop(WatchList::Outbox, layout.outbox(), handler, shutdown).unwrap();

        let events = seen.lock().unwrap();
        assert!(events.iter().any(|event| matches!(
            event.kind,
            WatchEventKind::Error(ref msg) if msg.contains("recommended watcher failed")
        )));
    }

    #[test]
    fn watch_loop_reports_recommended_constructor_failure() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event| {
                seen.lock().unwrap().push(event);
            })
        };

        let _guard = super::test_flags::force_recommended_constructor_error();
        let shutdown = Arc::new(AtomicBool::new(true));
        watch_loop(WatchList::Outbox, layout.outbox(), handler, shutdown).unwrap();

        let events = seen.lock().unwrap();
        assert!(events.iter().any(|event| matches!(
            event.kind,
            WatchEventKind::Error(ref msg) if msg.contains("forced constructor error")
        )));
    }

    #[test]
    fn watch_loop_reports_watch_registration_failure() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event| {
                seen.lock().unwrap().push(event);
            })
        };

        let _guard = super::test_flags::force_watch_register_error();
        let shutdown = Arc::new(AtomicBool::new(true));
        watch_loop(
            WatchList::Quarantine,
            layout.quarantine(),
            handler,
            shutdown,
        )
        .unwrap();

        let events = seen.lock().unwrap();
        assert!(events.iter().any(|event| matches!(
            event.kind,
            WatchEventKind::Error(ref msg) if msg.contains("watch failed")
        )));
    }

    #[test]
    fn watch_loop_reports_forced_watch_failure() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event| {
                seen.lock().unwrap().push(event);
            })
        };

        let _guard = super::test_flags::force_watch_failure();
        let shutdown = Arc::new(AtomicBool::new(true));
        watch_loop(WatchList::Outbox, layout.outbox(), handler, shutdown).unwrap();

        let events = seen.lock().unwrap();
        assert!(events.iter().any(|event| matches!(
            event.kind,
            WatchEventKind::Error(ref msg) if msg.contains("watch failed: forced for test")
        )));
    }

    #[test]
    fn watch_service_reports_poll_watcher_failure() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let (tx, rx) = mpsc::channel();
        let _guard = super::test_flags::force_poll_watcher_error();
        let service = WatchService::spawn(&layout, move |event| {
            tx.send(event).unwrap();
        })
        .unwrap();

        let event = rx
            .recv_timeout(Duration::from_millis(500))
            .expect("expected poll watcher failure event");
        assert!(
            matches!(event.kind, WatchEventKind::Error(ref msg) if msg.contains("poll watcher failed"))
        );
        drop(service);
    }

    #[test]
    fn handle_received_event_dispatches_and_continues() {
        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event| {
                seen.lock().unwrap().push(event);
            })
        };
        let event = Event {
            kind: EventKind::Remove(RemoveKind::File),
            paths: vec![PathBuf::from("a")],
            attrs: Default::default(),
        };
        let should_continue = handle_received_event(
            WatchList::Outbox,
            &handler,
            std::path::Path::new("ignored"),
            Ok(Ok(event)),
        );
        assert!(should_continue);
        assert_eq!(seen.lock().unwrap().len(), 1);
    }

    #[test]
    fn handle_received_event_records_errors() {
        let seen = Arc::new(Mutex::new(Vec::new()));
        let handler: Handler = {
            let seen = Arc::clone(&seen);
            Arc::new(move |event| {
                seen.lock().unwrap().push(event);
            })
        };
        let should_continue = handle_received_event(
            WatchList::Quarantine,
            &handler,
            std::path::Path::new("ignored"),
            Ok(Err(NotifyError::generic("boom"))),
        );
        assert!(should_continue);
        let events = seen.lock().unwrap();
        assert!(events.iter().any(|event| matches!(
            event.kind,
            WatchEventKind::Error(ref msg) if msg.contains("boom")
        )));
    }

    #[test]
    fn handle_received_event_breaks_on_disconnect() {
        let handler: Handler = Arc::new(|_| {});
        let should_continue = handle_received_event(
            WatchList::Outbox,
            &handler,
            std::path::Path::new("ignored"),
            Err(mpsc::RecvTimeoutError::Disconnected),
        );
        assert!(!should_continue);
    }

    fn wait_for_path(rx: &mpsc::Receiver<WatchEvent>, path: &std::path::Path) -> WatchEvent {
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        let mut seen = Vec::new();
        loop {
            match rx.recv_timeout(Duration::from_millis(200)) {
                Ok(event) => {
                    seen.push(event.clone());
                    if event.path == path {
                        return event;
                    }
                }
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    if std::time::Instant::now() > deadline {
                        panic!("timed out waiting for {:?}; saw {:?}", path, seen);
                    }
                    continue;
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => {
                    panic!(
                        "watch channel disconnected before event for {:?}; saw {:?}",
                        path, seen
                    );
                }
            }
        }
    }
}
