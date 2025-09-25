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
    use tempfile::tempdir;

    #[test]
    fn execute_runs_reload() {
        let cli = OwlCli {
            env: String::new(),
            command: Some(Commands::Reload),
            json: false,
        };
        execute(cli).unwrap();
    }

    #[test]
    fn execute_reads_env_file() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("env");
        std::fs::write(&path, "logging=off\n").unwrap();
        let cli = OwlCli {
            env: path.to_string_lossy().to_string(),
            command: Some(Commands::Install),
            json: false,
        };
        execute(cli).unwrap();
    }

    #[test]
    fn execute_handles_missing_env() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("missing");
        let cli = OwlCli {
            env: path.to_string_lossy().to_string(),
            command: Some(Commands::Update),
            json: false,
        };
        execute(cli).unwrap();
    }

    #[test]
    fn stub_main_is_callable() {
        super::main().unwrap();
    }
}
