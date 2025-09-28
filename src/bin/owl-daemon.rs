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

fn main() -> Result<()> {
    let cli = DaemonCli::parse();
    execute(&cli)
}

fn execute(cli: &DaemonCli) -> Result<()> {
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
    flag::register(SIGINT, Arc::clone(&term_flag))?;
    flag::register(SIGTERM, Arc::clone(&term_flag))?;

    run_until_shutdown(handles, logger, term_flag, || {
        thread::sleep(Duration::from_millis(200))
    })
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
    use std::sync::Arc;
    use std::sync::atomic::Ordering;
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
}
