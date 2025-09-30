#[cfg(not(test))]
use clap::Parser;
#[cfg(test)]
use owl::cli::Commands;
use owl::{
    cli::{self, OwlCli, run},
    envcfg::EnvConfig,
};

fn execute(cli: OwlCli) -> anyhow::Result<()> {
    let env = load_env_config(&cli.env)?;
    let output = run(cli.clone(), env)?;
    println!("{output}");
    Ok(())
}

fn load_env_config(raw: &str) -> anyhow::Result<EnvConfig> {
    let env_path = cli::resolve_env_path(raw)?;
    if env_path.exists() {
        EnvConfig::from_file(&env_path)
    } else {
        Ok(EnvConfig::default())
    }
}

#[cfg(not(test))]
fn main() -> anyhow::Result<()> {
    execute(OwlCli::parse())
}

#[cfg(test)]
fn main() -> anyhow::Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use tempfile::tempdir;

    fn with_fake_ops_env<T>(f: impl FnOnce() -> T) -> T {
        let dir = tempdir().unwrap();
        for name in ["certbot", "rspamadm", "systemctl", "chronyc"] {
            let path = dir.path().join(name);
            std::fs::write(&path, "#!/bin/sh\nexit 0\n").unwrap();
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = std::fs::metadata(&path).unwrap().permissions();
                perms.set_mode(0o755);
                std::fs::set_permissions(&path, perms).unwrap();
            }
        }
        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe { std::env::set_var("PATH", &new_path) };
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(f));
        unsafe { std::env::remove_var("PATH") };
        if let Some(orig) = original {
            unsafe { std::env::set_var("PATH", orig) };
        }
        result.expect("ops env callback panicked")
    }

    #[test]
    #[serial]
    fn load_env_config_expands_tilde_path() {
        struct HomeGuard(Option<std::ffi::OsString>);

        impl Drop for HomeGuard {
            fn drop(&mut self) {
                if let Some(value) = self.0.take() {
                    unsafe { std::env::set_var("HOME", value) };
                } else {
                    unsafe { std::env::remove_var("HOME") };
                }
            }
        }

        let dir = tempdir().unwrap();
        let mail_dir = dir.path().join("mail");
        std::fs::create_dir_all(&mail_dir).unwrap();
        std::fs::write(mail_dir.join(".env"), "logging=off\n").unwrap();
        let _guard = HomeGuard(std::env::var_os("HOME"));
        unsafe { std::env::set_var("HOME", dir.path()) };

        let env = load_env_config("~/mail/.env").unwrap();
        assert_eq!(env.logging, "off");
    }

    #[test]
    fn execute_runs_reload() {
        let dir = tempdir().unwrap();
        let env_path = dir.path().join(".env");
        std::fs::write(&env_path, "logging=minimal\n").unwrap();
        let layout = owl::fsops::layout::MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Reload),
            json: false,
        };
        execute(cli).unwrap();
    }

    #[test]
    #[serial]
    fn execute_reads_env_file() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("env");
        std::fs::write(&path, "logging=off\n").unwrap();
        let cli = OwlCli {
            env: path.to_string_lossy().to_string(),
            command: Some(Commands::Install),
            json: false,
        };
        with_fake_ops_env(|| execute(cli).unwrap());
    }

    #[test]
    #[serial]
    fn execute_handles_missing_env() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("missing");
        let cli = OwlCli {
            env: path.to_string_lossy().to_string(),
            command: Some(Commands::Update),
            json: false,
        };
        with_fake_ops_env(|| execute(cli).unwrap());
    }

    #[test]
    #[serial]
    fn with_fake_ops_env_restores_missing_path() {
        let original = std::env::var_os("PATH");
        unsafe { std::env::remove_var("PATH") };
        with_fake_ops_env(|| ());
        assert!(std::env::var_os("PATH").is_none());
        if let Some(path) = original {
            unsafe { std::env::set_var("PATH", path) };
        }
    }

    #[test]
    fn execute_defaults_when_env_empty() {
        let cli = OwlCli {
            env: String::new(),
            command: Some(Commands::Triage {
                address: None,
                list: None,
            }),
            json: true,
        };
        execute(cli).unwrap();
    }

    #[test]
    fn stub_main_is_callable() {
        super::main().unwrap();
    }
}
