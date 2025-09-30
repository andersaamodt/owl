use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use clap::Parser;
use owl::{
    EnvConfig,
    daemon::service,
    fsops::layout::MailLayout,
    util::logging::{LogLevel, Logger},
};
use signal_hook::consts::{SIGINT, SIGTERM};
use signal_hook::flag;

#[derive(Parser, Debug, Clone)]
#[command(name = "owl-daemon", about = "Owl background worker", version)]
struct DaemonCli {
    #[arg(long, default_value = "/home/pi/mail/.env")]
    env: String,

    /// Run a single setup cycle and exit (used for tests)
    #[arg(long, hide = true)]
    once: bool,
}

#[cfg(not(test))]
fn main() -> Result<()> {
    let cli = DaemonCli::parse();
    execute(&cli)
}

#[cfg(test)]
fn main() -> Result<()> {
    Ok(())
}

fn execute(cli: &DaemonCli) -> Result<()> {
    execute_with(cli, register_signals, default_sleep)
}

fn default_sleep() {
    thread::sleep(Duration::from_millis(200));
}

fn register_signals(term_flag: &Arc<AtomicBool>) -> Result<()> {
    flag::register(SIGINT, Arc::clone(term_flag))?;
    flag::register(SIGTERM, Arc::clone(term_flag))?;
    Ok(())
}

fn execute_with<R, S>(cli: &DaemonCli, register: R, sleeper: S) -> Result<()>
where
    R: Fn(&Arc<AtomicBool>) -> Result<()>,
    S: FnMut(),
{
    let env_path = PathBuf::from(&cli.env);
    let env = if env_path.exists() {
        EnvConfig::from_file(&env_path)
            .with_context(|| format!("loading {}", env_path.display()))?
    } else {
        EnvConfig::default()
    };
    let root = mail_root(&env_path);
    let layout = MailLayout::new(&root);
    layout.ensure()?;
    let level = env.logging.parse::<LogLevel>().unwrap_or(LogLevel::Minimal);
    let logger = Logger::new(layout.root(), level)?;
    logger.log(
        LogLevel::Minimal,
        "daemon.launch",
        Some(&format!("root={}", layout.root().display())),
    )?;

    let handles = service::start(layout.clone(), env.clone(), logger.clone())?;

    if cli.once {
        handles.stop();
        logger.log(LogLevel::Minimal, "daemon.exit", Some("mode=once"))?;
        return Ok(());
    }

    let term_flag = Arc::new(AtomicBool::new(false));
    register(&term_flag)?;

    run_until_shutdown(handles, logger, term_flag, sleeper)
}

fn mail_root(env_path: &Path) -> PathBuf {
    env_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}

fn run_until_shutdown<F>(
    handles: service::DaemonHandles,
    logger: Logger,
    term_flag: Arc<AtomicBool>,
    mut sleeper: F,
) -> Result<()>
where
    F: FnMut(),
{
    while !term_flag.load(Ordering::Relaxed) {
        sleeper();
    }

    logger.log(
        LogLevel::Minimal,
        "daemon.shutdown",
        Some("signal=received"),
    )?;
    handles.stop();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use signal_hook::low_level;
    use std::path::Path;
    use std::sync::Arc;
    use std::sync::OnceLock;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::Duration;
    use tempfile::tempdir;

    #[test]
    fn execute_once_initialises_daemon() {
        let dir = tempdir().unwrap();
        let env_path = dir.path().join(".env");
        std::fs::write(&env_path, "logging=off\n").unwrap();
        let cli = DaemonCli {
            env: env_path.to_string_lossy().into(),
            once: true,
        };
        execute(&cli).unwrap();
    }

    #[test]
    fn execute_uses_defaults_when_env_missing() {
        let dir = tempdir().unwrap();
        let env_path = dir.path().join("missing.env");
        let cli = DaemonCli {
            env: env_path.to_string_lossy().into(),
            once: true,
        };
        execute(&cli).unwrap();
    }

    #[test]
    fn execute_reports_env_load_failures() {
        let dir = tempdir().unwrap();
        let env_path = dir.path().join("config-dir");
        std::fs::create_dir(&env_path).unwrap();
        let cli = DaemonCli {
            env: env_path.to_string_lossy().into(),
            once: true,
        };

        let err = execute_with(&cli, |_| Ok(()), || {}).unwrap_err();
        let message = err.to_string();
        assert!(
            message.contains(&format!("loading {}", env_path.display())),
            "expected context to include path, got: {message}"
        );
    }

    #[test]
    #[serial]
    fn run_until_shutdown_logs_signal_and_stops_handles() {
        let dir = tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
        let handles = service::start(layout.clone(), env, logger.clone()).unwrap();

        let flag = Arc::new(AtomicBool::new(false));
        let flag_for_sleep = Arc::clone(&flag);
        let mut first_call = true;

        run_until_shutdown(handles, logger.clone(), flag, move || {
            if first_call {
                flag_for_sleep.store(true, Ordering::SeqCst);
                first_call = false;
            }
        })
        .unwrap();

        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.shutdown")
        );
    }

    #[test]
    fn cli_parses_once_flag() {
        let cli = DaemonCli::parse_from(["owl-daemon", "--env", "/var/mail/.env", "--once"]);
        assert!(cli.once);
        assert_eq!(cli.env, "/var/mail/.env");
    }

    #[test]
    fn mail_root_defaults_to_current_directory_when_parent_empty() {
        let root = mail_root(Path::new("standalone.env"));
        assert_eq!(root, PathBuf::from("."));
    }

    #[test]
    fn mail_root_uses_parent_directory() {
        let root = mail_root(Path::new("/srv/mail/.env"));
        assert_eq!(root, PathBuf::from("/srv/mail"));
    }

    #[test]
    fn default_sleep_is_callable() {
        default_sleep();
    }

    #[test]
    #[serial]
    fn register_signals_sets_flag_for_sigint_and_sigterm() {
        let flag = Arc::new(AtomicBool::new(false));
        register_signals(&flag).unwrap();

        low_level::raise(SIGINT).unwrap();
        assert!(flag.load(Ordering::Relaxed));

        flag.store(false, Ordering::Relaxed);

        low_level::raise(SIGTERM).unwrap();
        assert!(flag.load(Ordering::Relaxed));
    }

    #[test]
    fn stub_main_is_callable() {
        super::main().unwrap();
    }

    #[test]
    #[serial]
    fn run_until_shutdown_returns_immediately_when_flag_set() {
        let dir = tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
        let handles = service::start(layout.clone(), env, logger.clone()).unwrap();

        let flag = Arc::new(AtomicBool::new(true));
        let sleep_count = Arc::new(AtomicUsize::new(0));
        let counter = Arc::clone(&sleep_count);

        run_until_shutdown(handles, logger.clone(), flag, move || {
            counter.fetch_add(1, Ordering::SeqCst);
        })
        .unwrap();

        assert_eq!(sleep_count.load(Ordering::SeqCst), 0);
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.shutdown")
        );
    }

    #[test]
    #[serial]
    fn execute_stops_when_signal_received() {
        let dir = tempdir().unwrap();
        let env_path = dir.path().join(".env");
        std::fs::write(&env_path, "logging=minimal\n").unwrap();
        let cli = DaemonCli {
            env: env_path.to_string_lossy().into(),
            once: false,
        };

        execute_with(
            &cli,
            |term_flag| {
                register_signals(term_flag)?;
                let signal_flag = Arc::clone(term_flag);
                thread::spawn(move || {
                    thread::sleep(Duration::from_millis(50));
                    signal_flag.store(true, Ordering::SeqCst);
                });
                Ok(())
            },
            || thread::sleep(Duration::from_millis(5)),
        )
        .unwrap();

        let root = mail_root(env_path.as_path());
        let layout = MailLayout::new(&root);
        let log_path = layout.root().join("logs/owl.log");
        let entries = Logger::load_entries(&log_path).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "daemon.shutdown")
        );
    }

    #[test]
    #[serial]
    fn execute_registers_signals_and_exits_cleanly() {
        let dir = tempdir().unwrap();
        let env_path = dir.path().join(".env");
        std::fs::write(&env_path, "logging=minimal\n").unwrap();
        let cli = DaemonCli {
            env: env_path.to_string_lossy().into(),
            once: false,
        };

        let flag_holder: Arc<OnceLock<Arc<AtomicBool>>> = Arc::new(OnceLock::new());
        let register_holder = Arc::clone(&flag_holder);
        execute_with(
            &cli,
            move |term_flag| {
                register_signals(term_flag)?;
                register_holder
                    .set(Arc::clone(term_flag))
                    .map_err(|_| anyhow::anyhow!("term flag already set"))?;
                Ok(())
            },
            {
                let sleeper_holder = Arc::clone(&flag_holder);
                move || {
                    if let Some(flag) = sleeper_holder.get() {
                        flag.store(true, Ordering::SeqCst);
                    }
                }
            },
        )
        .unwrap();

        let flag = flag_holder.get().expect("term flag should be stored");
        assert!(flag.load(Ordering::SeqCst));
    }
}
