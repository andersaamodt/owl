use clap::{Parser, Subcommand, ValueEnum};
use std::{
    collections::HashSet,
    fs,
    path::{Path, PathBuf},
};

use crate::{
    envcfg::EnvConfig,
    fsops::{io_atom::write_atomic, layout::MailLayout},
    model::{address::Address, message::MessageSidecar},
    ruleset::loader::RulesetLoader,
};
use anyhow::{Context, Result, bail};

#[derive(Parser, Debug, Clone)]
#[command(name = "owl", version, about = "File-first mail system")]
pub struct OwlCli {
    #[arg(long, default_value = "/home/pi/mail/.env")]
    pub env: String,

    #[command(subcommand)]
    pub command: Option<Commands>,

    #[arg(long)]
    pub json: bool,
}

#[derive(Subcommand, Debug, Clone)]
pub enum Commands {
    Install,
    Update,
    Restart {
        #[arg(value_enum, default_value_t = RestartTarget::All)]
        target: RestartTarget,
    },
    Reload,
    Triage {
        #[arg(long)]
        address: Option<String>,
        #[arg(long)]
        list: Option<String>,
    },
    ListSenders {
        #[arg(long)]
        list: Option<String>,
    },
    MoveSender {
        from: String,
        to: String,
        address: String,
    },
    Pin {
        address: String,
        #[arg(long)]
        unset: bool,
    },
    Send {
        draft: String,
    },
    Backup {
        path: PathBuf,
    },
    ExportSender {
        list: String,
        address: String,
        path: PathBuf,
    },
    Import {
        source: PathBuf,
    },
    Logs {
        #[arg(value_enum, default_value_t = LogAction::Show)]
        action: LogAction,
    },
}

#[derive(ValueEnum, Clone, Debug, Default)]
pub enum RestartTarget {
    #[default]
    All,
    Postfix,
    Daemons,
}

#[derive(ValueEnum, Clone, Debug, Default, PartialEq, Eq)]
pub enum LogAction {
    #[default]
    Show,
    Tail,
}

const DEFAULT_ENV_PATH: &str = "/home/pi/mail/.env";

pub fn run(cli: OwlCli, env: EnvConfig) -> Result<String> {
    let env_path = resolve_env_path(&cli.env)?;
    match cli.command.unwrap_or(Commands::Triage {
        address: None,
        list: None,
    }) {
        Commands::Install => install(&env_path, &env),
        Commands::Update => Ok("update".to_string()),
        Commands::Restart { target } => Ok(format!("restart:{target:?}")),
        Commands::Reload => reload(&env_path),
        Commands::Triage { address, list } => Ok(format!(
            "triage:{}:{}:{}",
            env.render_mode,
            address.unwrap_or_default(),
            list.unwrap_or_default()
        )),
        Commands::ListSenders { list } => list_senders(&env_path, list),
        Commands::MoveSender { from, to, address } => {
            move_sender(&env_path, &env, from, to, address)
        }
        Commands::Pin { address, unset } => Ok(format!("pin:{address}:{unset}")),
        Commands::Send { draft } => Ok(format!("send:{draft}")),
        Commands::Backup { path } => Ok(path.display().to_string()),
        Commands::ExportSender {
            list,
            address,
            path,
        } => Ok(format!("export:{list}:{address}:{}", path.display())),
        Commands::Import { source } => Ok(format!("import:{}", source.display())),
        Commands::Logs { action } => Ok(format!("logs:{action:?}")),
    }
}

fn install(env_path: &Path, env: &EnvConfig) -> Result<String> {
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    layout.ensure()?;
    if !env_path.exists() {
        write_atomic(env_path, env.to_env_string().as_bytes())
            .with_context(|| format!("writing {}", env_path.display()))?;
    }
    Ok(format!("installed {}", root.display()))
}

fn reload(env_path: &Path) -> Result<String> {
    let root = mail_root(env_path);
    let loader = RulesetLoader::new(&root);
    let loaded = loader.load()?;
    let accepted = loaded.accepted.rules.rules().len();
    let spam = loaded.spam.rules.rules().len();
    let banned = loaded.banned.rules.rules().len();
    Ok(format!(
        "reloaded rules: accepted={accepted} spam={spam} banned={banned}"
    ))
}

fn list_senders(env_path: &Path, list: Option<String>) -> Result<String> {
    let root = mail_root(env_path);
    let lists = match list {
        Some(name) => vec![validate_list_name(&name)?],
        None => vec!["accepted", "spam", "banned", "quarantine"],
    };

    let mut sections = Vec::new();
    for list_name in lists {
        let mut senders = Vec::new();
        let dir = root.join(list_name);
        if dir.exists() {
            for entry in fs::read_dir(&dir)? {
                let entry = entry?;
                if !entry.file_type()?.is_dir() {
                    continue;
                }
                if list_name != "quarantine" && entry.file_name() == "attachments" {
                    continue;
                }
                senders.push(entry.file_name().to_string_lossy().into_owned());
            }
        }
        senders.sort();
        sections.push(format!("{list_name}:{}", senders.join(",")));
    }

    Ok(sections.join("\n"))
}

fn validate_list_name(name: &str) -> Result<&'static str> {
    match name.to_ascii_lowercase().as_str() {
        "accepted" => Ok("accepted"),
        "spam" => Ok("spam"),
        "banned" => Ok("banned"),
        "quarantine" => Ok("quarantine"),
        other => anyhow::bail!("unknown list: {other}"),
    }
}

fn move_sender(
    env_path: &Path,
    env: &EnvConfig,
    from: String,
    to: String,
    address: String,
) -> Result<String> {
    let from_list = validate_list_name(&from)?;
    let to_list = validate_list_name(&to)?;
    if from_list == to_list {
        bail!("source and destination lists must differ");
    }

    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    let sender = Address::parse(&address, env.keep_plus_tags)?;
    let source_dir = layout.root().join(from_list).join(sender.canonical());
    if !source_dir.exists() {
        bail!("sender {} not found in {from_list}", sender.canonical());
    }

    let dest_dir = layout.root().join(to_list).join(sender.canonical());
    if dest_dir.exists() {
        bail!("sender {} already exists in {to_list}", sender.canonical());
    }

    if let Some(parent) = dest_dir.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::rename(&source_dir, &dest_dir)?;

    let keep_attachments = list_has_attachments(to_list);
    let attachments = update_sidecars_for_move(&dest_dir, to_list, keep_attachments)?;
    if keep_attachments {
        let source_attachments = layout.attachments(from_list);
        let dest_attachments = layout.attachments(to_list);
        fs::create_dir_all(&dest_attachments)?;
        for attachment in attachments {
            let src = source_attachments.join(&attachment);
            if !src.exists() {
                continue;
            }
            let dest = dest_attachments.join(&attachment);
            if dest.exists() {
                continue;
            }
            fs::copy(&src, &dest)?;
        }
    }

    Ok(format!(
        "moved {} from {from_list} to {to_list}",
        sender.canonical()
    ))
}

fn list_has_attachments(list: &str) -> bool {
    matches!(list, "accepted" | "spam" | "banned")
}

fn update_sidecars_for_move(
    dir: &Path,
    new_status: &str,
    keep_attachments: bool,
) -> Result<HashSet<String>> {
    let mut attachments = HashSet::new();
    if !dir.exists() {
        return Ok(attachments);
    }
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if !entry.file_type()?.is_file() {
            continue;
        }
        if path.extension().and_then(|ext| ext.to_str()) != Some("yml") {
            continue;
        }
        let mut sidecar: MessageSidecar = serde_yaml::from_str(&fs::read_to_string(&path)?)?;
        sidecar.status_shadow = new_status.to_string();
        if keep_attachments {
            for attachment in &sidecar.attachments {
                attachments.insert(format!("{}__{}", attachment.sha256, attachment.name));
            }
        } else if !sidecar.attachments.is_empty() {
            sidecar.attachments.clear();
        }
        let yaml = serde_yaml::to_string(&sidecar)?;
        write_atomic(&path, yaml.as_bytes())?;
    }
    Ok(attachments)
}

fn resolve_env_path(raw: &str) -> Result<PathBuf> {
    resolve_env_path_with_home(raw, || home_dir())
}

fn resolve_env_path_with_home<F>(raw: &str, home: F) -> Result<PathBuf>
where
    F: Fn() -> Result<PathBuf>,
{
    if raw.is_empty() {
        return Ok(PathBuf::from(DEFAULT_ENV_PATH));
    }
    if raw == "~" {
        return home();
    }
    if let Some(rest) = raw.strip_prefix("~/") {
        return Ok(home()?.join(rest));
    }
    Ok(PathBuf::from(raw))
}

fn home_dir() -> Result<PathBuf> {
    std::env::var("HOME")
        .map(PathBuf::from)
        .context("$HOME is not set")
}

fn mail_root(env_path: &Path) -> PathBuf {
    env_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;
    use std::{fs, path::Path};

    #[test]
    fn parse_restart_default() {
        let cli = OwlCli::parse_from(["owl", "restart"]);
        assert!(matches!(
            cli.command,
            Some(Commands::Restart {
                target: RestartTarget::All
            })
        ));
    }

    #[test]
    fn log_action_values() {
        assert_eq!(LogAction::Show, LogAction::default());
        assert_ne!(LogAction::Show, LogAction::Tail);
    }

    #[test]
    fn run_covers_commands() {
        let env = EnvConfig::default();
        let cmds = vec![
            Commands::Install,
            Commands::Update,
            Commands::Restart {
                target: RestartTarget::Postfix,
            },
            Commands::Reload,
            Commands::Triage {
                address: Some("a".into()),
                list: None,
            },
            Commands::ListSenders {
                list: Some("accepted".into()),
            },
            Commands::MoveSender {
                from: "accepted".into(),
                to: "spam".into(),
                address: "carol@example.org".into(),
            },
            Commands::Pin {
                address: "a".into(),
                unset: true,
            },
            Commands::Send {
                draft: "file".into(),
            },
            Commands::Backup {
                path: "./tmp".into(),
            },
            Commands::ExportSender {
                list: "l".into(),
                address: "a".into(),
                path: "./out".into(),
            },
            Commands::Import {
                source: "./in".into(),
            },
            Commands::Logs {
                action: LogAction::Tail,
            },
        ];
        let temp = tempfile::tempdir().unwrap();
        let env_path = temp.path().join(".env");
        let env_string = env_path.to_string_lossy().into_owned();
        for command in cmds {
            let command_clone = command.clone();
            if let Commands::MoveSender { address, .. } = &command_clone {
                let layout = MailLayout::new(temp.path());
                layout.ensure().unwrap();
                let sender = Address::parse(address, env.keep_plus_tags).unwrap();
                fs::create_dir_all(layout.accepted().join(sender.canonical())).unwrap();
            }
            let cli = OwlCli {
                env: env_string.clone(),
                command: Some(command_clone),
                json: false,
            };
            let result = run(cli, env.clone());
            assert!(result.is_ok());
        }
    }

    #[test]
    fn install_sets_up_mail_root_and_env() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Install),
            json: false,
        };
        let env = EnvConfig::default();
        let output = run(cli.clone(), env.clone()).unwrap();
        assert!(output.contains("installed"));
        assert!(dir.path().join("quarantine").exists());
        let env_contents = std::fs::read_to_string(&env_path).unwrap();
        assert!(env_contents.contains("dmarc_policy=none"));
        std::fs::write(&env_path, "logging=off\n").unwrap();
        let again = run(cli, env).unwrap();
        assert!(again.contains("installed"));
        let env_contents_after = std::fs::read_to_string(&env_path).unwrap();
        assert_eq!(env_contents_after, "logging=off\n");
    }

    #[test]
    fn resolve_env_path_expands_defaults() {
        let default = resolve_env_path("").unwrap();
        assert_eq!(default, PathBuf::from(DEFAULT_ENV_PATH));
        let closure = || Ok(PathBuf::from("/home/example"));
        let tilde = resolve_env_path_with_home("~/mail/.env", closure).unwrap();
        assert_eq!(tilde, PathBuf::from("/home/example/mail/.env"));
        let bare = resolve_env_path_with_home("~", closure).unwrap();
        assert_eq!(bare, PathBuf::from("/home/example"));
    }

    #[test]
    fn resolve_env_path_uses_process_home() {
        let expected = std::env::var("HOME").unwrap();
        let bare = resolve_env_path("~").unwrap();
        assert_eq!(bare, PathBuf::from(expected));
    }

    #[test]
    fn reload_reports_rule_counts() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        std::fs::create_dir_all(dir.path().join("accepted")).unwrap();
        std::fs::write(dir.path().join("accepted/.rules"), "alice@example.org\n").unwrap();
        let output = reload(&env_path).unwrap();
        assert!(output.contains("accepted=1"));
        assert!(output.contains("spam=0"));
        assert!(output.contains("banned=0"));
    }

    #[test]
    fn mail_root_defaults_to_current_directory() {
        let root = mail_root(Path::new(".env"));
        assert_eq!(root, PathBuf::from("."));
    }

    #[test]
    fn list_senders_reports_directories() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        fs::create_dir_all(layout.accepted().join("alice@example.org")).unwrap();
        fs::create_dir_all(layout.spam().join("bob@spam.test")).unwrap();
        fs::create_dir_all(layout.quarantine().join("mallory@evil.test")).unwrap();
        let output = list_senders(&env_path, None).unwrap();
        assert!(output.contains("accepted:alice@example.org"));
        assert!(output.contains("spam:bob@spam.test"));
        assert!(output.contains("banned:"));
        assert!(output.contains("quarantine:mallory@evil.test"));
        assert!(!output.contains("attachments"));
    }

    #[test]
    fn list_senders_specific_list() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        fs::create_dir_all(layout.banned().join("spammer@example.com")).unwrap();
        let output = list_senders(&env_path, Some("banned".into())).unwrap();
        assert_eq!(output, "banned:spammer@example.com");
    }

    #[test]
    fn list_senders_rejects_unknown_list() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let err = list_senders(&env_path, Some("unknown".into())).unwrap_err();
        assert!(err.to_string().contains("unknown list"));
    }

    #[test]
    fn move_sender_transfers_between_lists() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();

        let sender_dir = layout.accepted().join("alice@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let subject = "Hello";
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FAV";
        let message_name = crate::model::filename::message_filename(subject, ulid);
        fs::write(sender_dir.join(&message_name), b"body").unwrap();
        let html_name = crate::model::filename::html_filename(subject, ulid);
        fs::write(sender_dir.join(&html_name), b"<html></html>").unwrap();
        let mut sidecar = MessageSidecar::new(
            ulid,
            message_name.clone(),
            "accepted",
            "strict",
            html_name.clone(),
            "deadbeef",
            crate::model::message::HeadersCache::new("Alice", subject),
        );
        sidecar.add_attachment("deadbeef", "file.txt");
        let sidecar_path = sender_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        let attachment_path = layout.attachments("accepted").join("deadbeef__file.txt");
        fs::create_dir_all(attachment_path.parent().unwrap()).unwrap();
        fs::write(&attachment_path, b"attachment").unwrap();

        let output = move_sender(
            &env_path,
            &env,
            "accepted".into(),
            "spam".into(),
            "alice@example.org".into(),
        )
        .unwrap();
        assert!(output.contains("moved alice@example.org from accepted to spam"));
        assert!(!sender_dir.exists());
        let dest_dir = layout.spam().join("alice@example.org");
        assert!(dest_dir.exists());
        let moved_sidecar_path =
            dest_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        let moved: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(&moved_sidecar_path).unwrap()).unwrap();
        assert_eq!(moved.status_shadow, "spam");
        assert_eq!(moved.attachments.len(), 1);
        assert_eq!(moved.attachments[0].name, "file.txt");
        assert!(
            layout
                .attachments("spam")
                .join("deadbeef__file.txt")
                .exists()
        );
    }

    #[test]
    fn move_sender_rejects_same_list() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        fs::create_dir_all(layout.accepted().join("bob@example.org")).unwrap();
        let err = move_sender(
            &env_path,
            &env,
            "accepted".into(),
            "accepted".into(),
            "bob@example.org".into(),
        )
        .unwrap_err();
        assert!(err.to_string().contains("source and destination lists"));
    }

    #[test]
    fn move_sender_to_quarantine_clears_attachments() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let sender_dir = layout.accepted().join("eve@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let subject = "Alert";
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FB0";
        let message_name = crate::model::filename::message_filename(subject, ulid);
        fs::write(sender_dir.join(&message_name), b"body").unwrap();
        let html_name = crate::model::filename::html_filename(subject, ulid);
        fs::write(sender_dir.join(&html_name), b"<html></html>").unwrap();
        let mut sidecar = MessageSidecar::new(
            ulid,
            message_name.clone(),
            "accepted",
            "strict",
            html_name.clone(),
            "feedface",
            crate::model::message::HeadersCache::new("Eve", subject),
        );
        sidecar.add_attachment("feedface", "warn.txt");
        let sidecar_path = sender_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        let attachment_path = layout.attachments("accepted").join("feedface__warn.txt");
        fs::create_dir_all(attachment_path.parent().unwrap()).unwrap();
        fs::write(&attachment_path, b"warn").unwrap();

        move_sender(
            &env_path,
            &env,
            "accepted".into(),
            "quarantine".into(),
            "eve@example.org".into(),
        )
        .unwrap();
        let dest_dir = layout.quarantine().join("eve@example.org");
        let moved_sidecar_path =
            dest_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        let moved: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(&moved_sidecar_path).unwrap()).unwrap();
        assert!(moved.attachments.is_empty());
    }

    #[test]
    fn move_sender_missing_sender_errors() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let err = move_sender(
            &env_path,
            &env,
            "accepted".into(),
            "spam".into(),
            "nobody@example.org".into(),
        )
        .unwrap_err();
        assert!(
            err.to_string()
                .contains("sender nobody@example.org not found")
        );
    }

    #[test]
    fn move_sender_rejects_existing_destination() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        fs::create_dir_all(layout.accepted().join("dave@example.org")).unwrap();
        fs::create_dir_all(layout.spam().join("dave@example.org")).unwrap();
        let err = move_sender(
            &env_path,
            &env,
            "accepted".into(),
            "spam".into(),
            "dave@example.org".into(),
        )
        .unwrap_err();
        assert!(
            err.to_string()
                .contains("sender dave@example.org already exists in spam")
        );
    }

    #[test]
    fn update_sidecars_for_move_missing_dir_is_empty() {
        let dir = tempfile::tempdir().unwrap();
        let missing = dir.path().join("absent");
        let attachments = update_sidecars_for_move(&missing, "accepted", true).unwrap();
        assert!(attachments.is_empty());
    }
}
