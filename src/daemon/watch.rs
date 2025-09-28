use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, mpsc};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use anyhow::Result;
use notify::event::{CreateKind, DataChange, ModifyKind, RemoveKind};
use notify::{Config, EventKind, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher};

use crate::fsops::layout::MailLayout;

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

fn watch_loop(
    list: WatchList,
    path: std::path::PathBuf,
    handler: Handler,
    shutdown: Arc<AtomicBool>,
) -> Result<()> {
    let (tx, rx) = mpsc::channel();
    let config = Config::default().with_poll_interval(Duration::from_millis(200));
    let mut watchers: Vec<Box<dyn Watcher + Send>> = Vec::new();

    match RecommendedWatcher::new(
        {
            let sender = tx.clone();
            move |res| {
                let _ = sender.send(res);
            }
        },
        config,
    ) {
        Ok(watcher) => watchers.push(Box::new(watcher)),
        Err(err) => handler(WatchEvent {
            list,
            path: path.clone(),
            kind: WatchEventKind::Error(format!("recommended watcher failed: {err}")),
        }),
    }

    let poll = PollWatcher::new(
        {
            let sender = tx.clone();
            move |res| {
                let _ = sender.send(res);
            }
        },
        config,
    )?;
    watchers.push(Box::new(poll));

    for watcher in watchers.iter_mut() {
        if let Err(err) = watcher.watch(&path, RecursiveMode::Recursive) {
            handler(WatchEvent {
                list,
                path: path.clone(),
                kind: WatchEventKind::Error(format!("watch failed: {err}")),
            });
        }
    }

    while !shutdown.load(Ordering::Relaxed) {
        match rx.recv_timeout(Duration::from_millis(200)) {
            Ok(Ok(event)) => dispatch_event(list, &handler, event),
            Ok(Err(err)) => handler(WatchEvent {
                list,
                path: path.clone(),
                kind: WatchEventKind::Error(err.to_string()),
            }),
            Err(mpsc::RecvTimeoutError::Timeout) => continue,
            Err(mpsc::RecvTimeoutError::Disconnected) => break,
        }
    }

    Ok(())
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
    use std::sync::mpsc;
    use std::time::Duration;

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
