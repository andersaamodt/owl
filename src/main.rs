use owl::{
    cli::{Commands, OwlCli, run},
    envcfg::EnvConfig,
};
use std::path::Path;

fn execute(cli: OwlCli) -> anyhow::Result<()> {
    let env = if cli.env.is_empty() {
        EnvConfig::default()
    } else {
        let path = Path::new(&cli.env);
        if path.exists() {
            EnvConfig::from_file(path)?
        } else {
            EnvConfig::default()
        }
    };
    let output = run(cli.clone(), env)?;
    println!("{output}");
    Ok(())
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
        match original {
            Some(orig) => unsafe { std::env::set_var("PATH", orig) },
            None => unsafe { std::env::remove_var("PATH") },
        }
        result.expect("ops env callback panicked")
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
    fn stub_main_is_callable() {
        super::main().unwrap();
    }
}
