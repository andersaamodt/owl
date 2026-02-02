use clap::{Parser, Subcommand, ValueEnum};
use duct::cmd;
use flate2::{Compression, read::GzDecoder, write::GzEncoder};
use mailparse::{self, MailAddr, MailHeaderMap};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet},
    fs::{self, File},
    io::{self, BufRead, BufReader, Write},
    path::{Path, PathBuf},
};
use tar::{Archive, Builder};

use crate::{
    envcfg::EnvConfig,
    fsops::{io_atom::write_atomic, layout::MailLayout},
    model::{address::Address, message::MessageSidecar},
    ops::install as ops_install,
    pipeline::{
        inbound::determine_route,
        outbox::{DispatchResult, OutboxPipeline},
        smtp_in::InboundPipeline,
    },
    ruleset::loader::{LoadedRules, RulesetLoader},
    util::{
        dkim,
        logging::{self, LogLevel, Logger},
    },
};
use anyhow::{Context, Result, anyhow, bail};

#[derive(Parser, Debug, Clone)]
#[command(name = "owl", version, about = "File-first mail system")]
pub struct OwlCli {
    #[arg(
        long,
        default_value = "/home/pi/mail/.env",
        help = "Path to the .env file"
    )]
    pub env: String,

    #[command(subcommand)]
    pub command: Option<Commands>,

    #[arg(long, help = "Enable JSON output for supported commands")]
    pub json: bool,
}

#[derive(Subcommand, Debug, Clone)]
pub enum Commands {
    #[command(about = "Bootstrap mail storage, DKIM keys, and system hooks")]
    Install,
    #[command(about = "Re-apply provisioning hooks and ensure layout exists")]
    Update,
    #[command(about = "Restart Owl services via systemctl")]
    Restart {
        #[arg(value_enum, default_value_t = RestartTarget::All, help = "Service to restart")]
        target: RestartTarget,
    },
    #[command(about = "Reload routing rules without restarting the daemon")]
    Reload,
    #[command(about = "List messages in quarantine or a specific list")]
    Triage {
        #[arg(long, help = "Filter by sender address")]
        address: Option<String>,
        #[arg(long, help = "List to triage (quarantine, accepted, spam, banned)")]
        list: Option<String>,
    },
    #[command(about = "Show sender directories for one list or all lists")]
    ListSenders {
        #[arg(
            long,
            help = "List to show senders from (quarantine, accepted, spam, banned)"
        )]
        list: Option<String>,
    },
    #[command(about = "Move all mail for a sender between lists")]
    MoveSender {
        #[arg(help = "Source list")]
        from: String,
        #[arg(help = "Destination list")]
        to: String,
        #[arg(help = "Sender address to move")]
        address: String,
    },
    #[command(about = "Toggle the pinned flag for all messages from a sender")]
    Pin {
        #[arg(help = "Sender address to pin/unpin")]
        address: String,
        #[arg(long, help = "Remove the pinned flag instead of setting it")]
        unset: bool,
    },
    #[command(about = "Queue a draft for delivery")]
    Send {
        #[arg(help = "Draft file path or ULID")]
        draft: String,
    },
    #[command(about = "Create a tarball of the mail root")]
    Backup {
        #[arg(help = "Output path for the backup tarball")]
        path: PathBuf,
    },
    #[command(about = "Export a single sender to a tarball")]
    ExportSender {
        #[arg(help = "List to export from")]
        list: String,
        #[arg(help = "Sender address to export")]
        address: String,
        #[arg(help = "Output path for the tarball")]
        path: PathBuf,
    },
    #[command(about = "Import legacy archives into quarantine")]
    Import {
        #[arg(help = "Path to maildir, mbox, or tar.gz archive")]
        source: PathBuf,
    },
    #[command(about = "Render structured logs")]
    Logs {
        #[arg(value_enum, default_value_t = LogAction::Show, help = "Action to perform on logs")]
        action: LogAction,
    },
    #[command(about = "Run the interactive configuration wizard")]
    Configure,
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
    let root = mail_root(&env_path);
    let log_level = env.logging.parse::<LogLevel>().unwrap_or(LogLevel::Minimal);
    let logger = Logger::new(root.clone(), log_level)?;
    match cli.command.unwrap_or(Commands::Triage {
        address: None,
        list: None,
    }) {
        Commands::Install => install(&env_path, &env, &logger),
        Commands::Update => update(&env_path, &env, &logger),
        Commands::Restart { target } => restart(&env_path, target, &logger),
        Commands::Reload => reload(&env_path),
        Commands::Triage { address, list } => triage(&env_path, &env, address, list, cli.json),
        Commands::ListSenders { list } => list_senders(&env_path, list),
        Commands::MoveSender { from, to, address } => {
            move_sender(&env_path, &env, from, to, address)
        }
        Commands::Pin { address, unset } => pin_address(&env_path, &env, address, unset),
        Commands::Send { draft } => send_draft(&env_path, &env, &logger, &draft),
        Commands::Backup { path } => backup_mail(&env_path, &path),
        Commands::ExportSender {
            list,
            address,
            path,
        } => export_sender(&env_path, &env, &list, &address, &path),
        Commands::Import { source } => import_archive(&env_path, &source),
        Commands::Logs { action } => logs(&root, log_level, action, cli.json),
        Commands::Configure => configure(&env_path, &env, &logger),
    }
}

fn install(env_path: &Path, env: &EnvConfig, logger: &Logger) -> Result<String> {
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    layout.ensure()?;
    logger.log(
        LogLevel::Minimal,
        "install.ensure",
        Some(&format!("root={}", root.display())),
    )?;
    let dkim_material = dkim::ensure_ed25519_keypair(&layout.dkim_dir(), &env.dkim_selector)?;
    logger.log(
        LogLevel::Minimal,
        "install.dkim.ready",
        Some(&format!(
            "selector={} public_key={} dns={}",
            env.dkim_selector,
            dkim_material.public_key,
            dkim_material.dns_record_path.display()
        )),
    )?;
    ops_install::provision(&layout, env, logger)?;
    if !env_path.exists() {
        write_atomic(env_path, env.to_env_string().as_bytes())
            .with_context(|| format!("writing {}", env_path.display()))?;
        logger.log(
            LogLevel::Minimal,
            "install.env.created",
            Some(&format!("path={}", env_path.display())),
        )?;
    } else {
        logger.log(
            LogLevel::VerboseSanitized,
            "install.env.skipped",
            Some(&format!("path={}", env_path.display())),
        )?;
    }
    Ok(format!("installed {}", root.display()))
}

fn update(env_path: &Path, env: &EnvConfig, logger: &Logger) -> Result<String> {
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    layout.ensure()?;
    ops_install::provision(&layout, env, logger)?;
    logger.log(
        LogLevel::Minimal,
        "update.provisioned",
        Some(&format!("root={}", root.display())),
    )?;
    Ok(format!("updated {}", root.display()))
}

fn configure(env_path: &Path, env: &EnvConfig, logger: &Logger) -> Result<String> {
    let mut input = io::stdin().lock();
    let mut output = io::stdout();
    writeln!(output, "Welcome to Owl configuration")?;
    let default_root = mail_root(env_path);
    let mail_root = prompt(
        &mut input,
        &mut output,
        "Mail root directory",
        Some(default_root.to_string_lossy().as_ref()),
    )?;
    let mail_root = PathBuf::from(mail_root);
    fs::create_dir_all(&mail_root)?;

    let default_env = if env_path.as_os_str().is_empty() {
        mail_root.join(".env")
    } else {
        env_path.to_path_buf()
    };
    let env_path = prompt(
        &mut input,
        &mut output,
        "Env file path",
        Some(default_env.to_string_lossy().as_ref()),
    )?;
    let env_path = PathBuf::from(env_path);
    if !env_path.exists() && prompt_yes_no(&mut input, &mut output, "Create env file now?", true)? {
        setup_env(&mut input, &mut output, &env_path, env)?;
    }

    loop {
        writeln!(output)?;
        writeln!(output, "Owl configuration wizard")?;
        writeln!(output, "1) Initialize mail root (owl install)")?;
        writeln!(output, "2) Configure env settings")?;
        writeln!(output, "3) Add accepted routing rule")?;
        writeln!(output, "4) Add spam routing rule")?;
        writeln!(output, "5) Add banned routing rule")?;
        writeln!(output, "6) Configure list settings")?;
        writeln!(output, "7) Show current env + rules summary")?;
        writeln!(output, "8) Quit")?;
        let choice = prompt(&mut input, &mut output, "Choose an option [1-8]", None)?;
        match choice.trim() {
            "1" => {
                let active_env = load_env(&env_path).unwrap_or_else(|_| env.clone());
                install(&env_path, &active_env, logger)?;
            }
            "2" => {
                let active_env = load_env(&env_path).unwrap_or_else(|_| env.clone());
                setup_env(&mut input, &mut output, &env_path, &active_env)?;
            }
            "3" => {
                let entry = prompt(
                    &mut input,
                    &mut output,
                    "Accepted rule (address/domain/regex)",
                    None,
                )?;
                if !entry.trim().is_empty() {
                    set_rules_entry(&mail_root.join("accepted/.rules"), &entry)?;
                }
            }
            "4" => {
                let entry = prompt(
                    &mut input,
                    &mut output,
                    "Spam rule (address/domain/regex)",
                    None,
                )?;
                if !entry.trim().is_empty() {
                    set_rules_entry(&mail_root.join("spam/.rules"), &entry)?;
                }
            }
            "5" => {
                let entry = prompt(
                    &mut input,
                    &mut output,
                    "Banned rule (address/domain/regex)",
                    None,
                )?;
                if !entry.trim().is_empty() {
                    set_rules_entry(&mail_root.join("banned/.rules"), &entry)?;
                }
            }
            "6" => {
                let list = prompt(
                    &mut input,
                    &mut output,
                    "List to configure (accepted/spam/banned)",
                    Some("accepted"),
                )?;
                if !matches!(list.as_str(), "accepted" | "spam" | "banned") {
                    writeln!(output, "Unknown list: {list}")?;
                    continue;
                }
                let from_value = prompt(
                    &mut input,
                    &mut output,
                    "From header",
                    Some("Owl <owl@example.org>"),
                )?;
                let reply_to = prompt(&mut input, &mut output, "Reply-To header", Some(""))?;
                let signature = prompt(
                    &mut input,
                    &mut output,
                    "Signature path (optional)",
                    Some(""),
                )?;
                let body_format = prompt(
                    &mut input,
                    &mut output,
                    "Body format (both/plain/html)",
                    Some("both"),
                )?;
                let delete_after = prompt(
                    &mut input,
                    &mut output,
                    "Delete after (never/30d/6m/2y)",
                    Some("never"),
                )?;
                let list_status = prompt(
                    &mut input,
                    &mut output,
                    "List status (accepted/rejected/banned)",
                    Some("accepted"),
                )?;
                set_settings_file(
                    &mail_root.join(format!("{list}/.settings")),
                    &from_value,
                    &reply_to,
                    &signature,
                    &body_format,
                    &delete_after,
                    &list_status,
                )?;
            }
            "7" => {
                show_summary(&mut output, &env_path, &mail_root)?;
            }
            "8" => {
                writeln!(output, "Exiting configuration wizard.")?;
                break;
            }
            _ => {
                writeln!(output, "Invalid selection.")?;
            }
        }
    }

    Ok(format!(
        "configuration complete for {}",
        mail_root.display()
    ))
}

fn restart(env_path: &Path, target: RestartTarget, logger: &Logger) -> Result<String> {
    let services: Vec<&str> = match target {
        RestartTarget::All => vec!["postfix", "owl-daemon"],
        RestartTarget::Postfix => vec!["postfix"],
        RestartTarget::Daemons => vec!["owl-daemon"],
    };
    let mut results = Vec::new();
    for service in services {
        match cmd("systemctl", ["restart", service])
            .stderr_capture()
            .stdout_capture()
            .run()
        {
            Ok(_) => {
                logger.log(
                    LogLevel::Minimal,
                    "restart.service",
                    Some(&format!("service={service} status=ok")),
                )?;
                results.push(format!("{service}=ok"));
            }
            Err(err) => {
                logger.log(
                    LogLevel::Minimal,
                    "restart.service.error",
                    Some(&format!("service={service} error={err}")),
                )?;
                results.push(format!("{service}=error"));
            }
        }
    }
    let target_name = match target {
        RestartTarget::All => "all",
        RestartTarget::Postfix => "postfix",
        RestartTarget::Daemons => "daemons",
    };
    Ok(format!(
        "restart {target_name} -> {} (root={})",
        results.join(","),
        mail_root(env_path).display()
    ))
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

fn logs(root: &Path, level: LogLevel, action: LogAction, json: bool) -> Result<String> {
    if level == LogLevel::Off {
        return Ok(if json {
            "[]".to_string()
        } else {
            "logging disabled".to_string()
        });
    }
    let layout = MailLayout::new(root);
    let log_path = layout.log_file();
    let entries = Logger::load_entries(&log_path)?;
    let slice = if action == LogAction::Tail {
        logging::tail(&entries, 50)
    } else {
        &entries
    };
    if json {
        return Ok(serde_json::to_string(slice)?);
    }
    if slice.is_empty() {
        return Ok("no log entries".to_string());
    }
    Ok(slice
        .iter()
        .map(|entry| entry.format_human())
        .collect::<Vec<_>>()
        .join("\n"))
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

#[derive(Debug, Serialize, Deserialize, Clone)]
struct TriageEntry {
    list: String,
    address: String,
    ulid: String,
    subject: String,
    status: String,
    read: bool,
    pinned: bool,
    rspamd: Option<RspamdView>,
    outbound: Option<OutboundView>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct RspamdView {
    score: f32,
    symbols: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct OutboundView {
    status: String,
    attempts: u32,
    last_error: Option<String>,
    next_attempt_at: Option<String>,
}

fn triage(
    env_path: &Path,
    env: &EnvConfig,
    address: Option<String>,
    list: Option<String>,
    json: bool,
) -> Result<String> {
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    let mut entries = Vec::new();
    let filter_address = match address {
        Some(addr) => {
            let parsed = Address::parse(&addr, env.keep_plus_tags)?;
            Some(parsed.canonical().to_string())
        }
        None => None,
    };
    let lists = match list {
        Some(name) => vec![validate_list_name(&name)?.to_string()],
        None => vec!["quarantine".to_string()],
    };

    for list_name in &lists {
        let base_dir = match list_name.as_str() {
            "accepted" => layout.accepted(),
            "spam" => layout.spam(),
            "banned" => layout.banned(),
            "quarantine" => layout.quarantine(),
            other => bail!("unsupported list for triage: {other}"),
        };
        let mut senders = Vec::new();
        if let Some(filter) = &filter_address {
            senders.push(filter.clone());
        } else if base_dir.exists() {
            for entry in fs::read_dir(&base_dir)? {
                let entry = entry?;
                if !entry.file_type()?.is_dir() {
                    continue;
                }
                if list_name != "quarantine" && entry.file_name() == "attachments" {
                    continue;
                }
                senders.push(entry.file_name().to_string_lossy().into_owned());
            }
            senders.sort();
        }

        for sender in senders {
            let sender_dir = base_dir.join(&sender);
            if !sender_dir.exists() {
                continue;
            }
            for message in sidecar_files(&sender_dir)? {
                let yaml = fs::read_to_string(&message)?;
                let sidecar: MessageSidecar = serde_yaml::from_str(&yaml)?;
                let rspamd = sidecar.rspamd.as_ref().map(|summary| RspamdView {
                    score: summary.score,
                    symbols: summary.symbols.clone(),
                });
                let outbound = sidecar.outbound.as_ref().map(|out| OutboundView {
                    status: format!("{:?}", out.status),
                    attempts: out.attempts,
                    last_error: out.last_error.clone(),
                    next_attempt_at: out.next_attempt_at.clone(),
                });
                entries.push(TriageEntry {
                    list: list_name.clone(),
                    address: sender.clone(),
                    ulid: sidecar.ulid.clone(),
                    subject: sidecar.headers_cache.subject.clone(),
                    status: sidecar.status_shadow.clone(),
                    read: sidecar.read,
                    pinned: sidecar.pinned,
                    rspamd,
                    outbound,
                });
            }
        }
    }

    if json {
        return Ok(serde_json::to_string(&entries)?);
    }

    if entries.is_empty() {
        return Ok("no messages matched".into());
    }

    let mut grouped: HashMap<&str, Vec<&TriageEntry>> = HashMap::new();
    for entry in &entries {
        grouped.entry(&entry.list).or_default().push(entry);
    }

    let mut sections = Vec::new();
    for list_name in &lists {
        sections.push(format!("{list_name}:"));
        if let Some(items) = grouped.get(list_name.as_str()) {
            for entry in items {
                let mut extra = Vec::new();
                if let Some(rspamd) = &entry.rspamd {
                    extra.push(format!("rspamd={:.1}", rspamd.score));
                }
                if let Some(outbound) = &entry.outbound {
                    extra.push(format!(
                        "outbound={} attempts={}",
                        outbound.status, outbound.attempts
                    ));
                    if let Some(err) = &outbound.last_error {
                        extra.push(format!("last_error={err}"));
                    }
                }
                let extras = if extra.is_empty() {
                    String::new()
                } else {
                    format!(" [{}]", extra.join(", "))
                };
                sections.push(format!(
                    "  {address} :: {subject} ({ulid}) status={status} read={read} pinned={pinned}{extras}",
                    address = entry.address,
                    subject = entry.subject,
                    ulid = entry.ulid,
                    status = entry.status,
                    read = entry.read,
                    pinned = entry.pinned,
                    extras = extras
                ));
            }
        } else {
            sections.push("  (no messages)".into());
        }
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

fn pin_address(env_path: &Path, env: &EnvConfig, address: String, unset: bool) -> Result<String> {
    let parsed = Address::parse(&address, env.keep_plus_tags)?;
    let canonical = parsed.canonical().to_string();
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    let mut updated = 0;
    for list in ["accepted", "spam", "banned", "quarantine"] {
        let sender_dir = layout.root().join(list).join(&canonical);
        if !sender_dir.exists() {
            continue;
        }
        for path in sidecar_files(&sender_dir)? {
            let yaml = fs::read_to_string(&path)?;
            let mut sidecar: MessageSidecar = serde_yaml::from_str(&yaml)?;
            let desired_pin = !unset;
            if sidecar.pinned != desired_pin {
                sidecar.pinned = desired_pin;
                let rendered = serde_yaml::to_string(&sidecar)?;
                write_atomic(&path, rendered.as_bytes())?;
                updated += 1;
            }
        }
    }
    if updated == 0 {
        bail!("no messages found for {canonical}");
    }
    let state = if unset { "unpinned" } else { "pinned" };
    Ok(format!("{state} {canonical} ({updated} messages)"))
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

fn sidecar_files(dir: &Path) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    if !dir.exists() {
        return Ok(files);
    }
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        if !entry.file_type()?.is_file() {
            continue;
        }
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) == Some("yml") {
            files.push(path);
        }
    }
    files.sort();
    Ok(files)
}

fn send_draft(env_path: &Path, env: &EnvConfig, logger: &Logger, draft: &str) -> Result<String> {
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    let pipeline = OutboxPipeline::new(layout.clone(), env.clone(), logger.clone());
    let draft_path = resolve_draft_path(&layout, draft)?;
    if !draft_path.exists() {
        bail!("draft {} not found", draft_path.display());
    }
    let message_path = pipeline.queue_draft(&draft_path)?;
    if draft_path.starts_with(layout.drafts()) {
        let _ = fs::remove_file(&draft_path);
    }
    let results = pipeline.dispatch_pending()?;
    let sent = results
        .iter()
        .filter(|result| matches!(result, DispatchResult::Sent(_)))
        .count();
    let retried = results
        .iter()
        .filter(|result| matches!(result, DispatchResult::Retry(_)))
        .count();
    let ulid = message_path
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or_default()
        .to_string();
    Ok(format!(
        "queued {ulid} -> sent={sent} retry={retried} outbox={}",
        layout.outbox().display()
    ))
}

fn resolve_draft_path(layout: &MailLayout, draft: &str) -> Result<PathBuf> {
    let candidate = PathBuf::from(draft);
    if candidate.is_absolute() || candidate.exists() {
        return Ok(candidate);
    }
    let drafts_dir = layout.drafts();
    let with_suffix = if draft.ends_with(".md") {
        drafts_dir.join(draft)
    } else {
        drafts_dir.join(format!("{draft}.md"))
    };
    if with_suffix.exists() {
        return Ok(with_suffix);
    }
    Err(anyhow!("draft {draft} not found"))
}

fn backup_mail(env_path: &Path, target: &Path) -> Result<String> {
    let root = mail_root(env_path);
    if let Some(parent) = target.parent()
        && !parent.as_os_str().is_empty()
    {
        fs::create_dir_all(parent)?;
    }
    let file = File::create(target).with_context(|| format!("creating {}", target.display()))?;
    let encoder = GzEncoder::new(file, Compression::default());
    let mut builder = Builder::new(encoder);
    builder.append_dir_all(".", &root)?;
    let encoder = builder.into_inner()?;
    encoder.finish()?;
    Ok(format!("backup written to {}", target.display()))
}

fn export_sender(
    env_path: &Path,
    env: &EnvConfig,
    list: &str,
    address: &str,
    target: &Path,
) -> Result<String> {
    let list_name = validate_list_name(list)?;
    let parsed = Address::parse(address, env.keep_plus_tags)?;
    let canonical = parsed.canonical().to_string();
    let root = mail_root(env_path);
    let layout = MailLayout::new(&root);
    let sender_dir = layout.root().join(list_name).join(&canonical);
    if !sender_dir.exists() {
        bail!("sender {canonical} not found in {list_name}");
    }
    if let Some(parent) = target.parent()
        && !parent.as_os_str().is_empty()
    {
        fs::create_dir_all(parent)?;
    }
    let file = File::create(target).with_context(|| format!("creating {}", target.display()))?;
    let encoder = GzEncoder::new(file, Compression::default());
    let mut builder = Builder::new(encoder);
    builder.append_dir_all(format!("{list_name}/{canonical}"), &sender_dir)?;
    let attachments = collect_attachments(&sender_dir)?;
    let attachments_dir = layout.attachments(list_name);
    for attachment in attachments {
        let path = attachments_dir.join(&attachment);
        if path.exists() {
            builder
                .append_path_with_name(&path, format!("{list_name}/attachments/{attachment}"))?;
        }
    }
    let encoder = builder.into_inner()?;
    encoder.finish()?;
    Ok(format!(
        "exported {canonical} from {list_name} to {}",
        target.display()
    ))
}

fn collect_attachments(dir: &Path) -> Result<HashSet<String>> {
    let mut attachments = HashSet::new();
    for path in sidecar_files(dir)? {
        let yaml = fs::read_to_string(&path)?;
        let sidecar: MessageSidecar = serde_yaml::from_str(&yaml)?;
        for attachment in sidecar.attachments {
            attachments.insert(format!("{}__{}", attachment.sha256, attachment.name));
        }
    }
    Ok(attachments)
}

fn import_archive(env_path: &Path, source: &Path) -> Result<String> {
    if !source.exists() {
        bail!("source {} not found", source.display());
    }
    let root = mail_root(env_path);
    let env = load_env(env_path)?;
    let layout = MailLayout::new(&root);
    layout.ensure()?;

    enum Outcome {
        Archive,
        Messages(usize),
    }

    let outcome = if source.is_dir() {
        Outcome::Messages(import_maildir(&layout, &env, source)?)
    } else {
        let lower_name = source
            .file_name()
            .and_then(|name| name.to_str())
            .map(|name| name.to_ascii_lowercase());
        let ext = source
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| ext.to_ascii_lowercase());

        if ext.as_deref() == Some("mbox")
            || lower_name
                .as_deref()
                .map(|name| name.ends_with(".mbox"))
                .unwrap_or(false)
        {
            Outcome::Messages(import_mbox(&layout, &env, source)?)
        } else {
            let file =
                File::open(source).with_context(|| format!("opening {}", source.display()))?;
            let lower_name = lower_name.unwrap_or_default();
            if lower_name.ends_with(".tar.gz")
                || lower_name.ends_with(".tgz")
                || ext.as_deref() == Some("gz")
            {
                let decoder = GzDecoder::new(file);
                let mut archive = Archive::new(decoder);
                archive.unpack(&root)?;
            } else if ext.as_deref() == Some("tar") {
                let mut archive = Archive::new(file);
                archive.unpack(&root)?;
            } else {
                bail!("unsupported import format: {}", source.display());
            }
            Outcome::Archive
        }
    };

    let summary = match outcome {
        Outcome::Archive => format!("imported {} into {}", source.display(), root.display()),
        Outcome::Messages(count) => format!(
            "imported {count} messages from {} into {}",
            source.display(),
            root.display()
        ),
    };

    Ok(summary)
}

fn import_maildir(layout: &MailLayout, env: &EnvConfig, dir: &Path) -> Result<usize> {
    let (pipeline, rules) = inbound_context(layout, env)?;
    let mut count = 0;
    for leaf in ["cur", "new"] {
        let path = dir.join(leaf);
        if !path.exists() {
            continue;
        }
        for entry in fs::read_dir(&path).with_context(|| format!("reading {}", path.display()))? {
            let entry = entry?;
            if entry.file_type()?.is_file() {
                let body = fs::read(entry.path())
                    .with_context(|| format!("reading {}", entry.path().display()))?;
                deliver_imported_message(&pipeline, &rules, env, &body)?;
                count += 1;
            }
        }
    }
    Ok(count)
}

fn import_mbox(layout: &MailLayout, env: &EnvConfig, path: &Path) -> Result<usize> {
    let file = File::open(path).with_context(|| format!("opening {}", path.display()))?;
    let mut reader = BufReader::new(file);
    let (pipeline, rules) = inbound_context(layout, env)?;
    let mut current = Vec::new();
    let mut count = 0;
    loop {
        let mut line = Vec::new();
        let read = reader.read_until(b'\n', &mut line)?;
        if read == 0 {
            if !current.is_empty() {
                deliver_imported_message(&pipeline, &rules, env, &current)?;
                count += 1;
            }
            break;
        }
        if line.starts_with(b"From ") {
            if !current.is_empty() {
                deliver_imported_message(&pipeline, &rules, env, &current)?;
                count += 1;
                current.clear();
            }
            continue;
        }
        current.extend_from_slice(&line);
    }
    Ok(count)
}

fn inbound_context(layout: &MailLayout, env: &EnvConfig) -> Result<(InboundPipeline, LoadedRules)> {
    let pipeline = InboundPipeline::new(layout.clone(), env.clone())?;
    let loader = RulesetLoader::new(layout.root());
    let rules = loader.load()?;
    Ok((pipeline, rules))
}

fn deliver_imported_message(
    pipeline: &InboundPipeline,
    rules: &LoadedRules,
    env: &EnvConfig,
    body: &[u8],
) -> Result<()> {
    let parsed = mailparse::parse_mail(body).map_err(|err| anyhow!(err.to_string()))?;
    let subject = parsed
        .headers
        .get_first_value("Subject")
        .unwrap_or_else(|| "no subject".to_string());
    let sender = if let Some(from_value) = parsed.headers.get_first_value("From") {
        let addresses =
            mailparse::addrparse(from_value.as_str()).map_err(|err| anyhow!(err.to_string()))?;
        if let Some(addr) = first_mailbox(&addresses) {
            Address::parse(&addr, env.keep_plus_tags)
        } else {
            Address::parse("unknown@import.invalid", env.keep_plus_tags)
        }
    } else {
        Address::parse("unknown@import.invalid", env.keep_plus_tags)
    }?;
    let route = determine_route(&sender, rules, env)?;
    pipeline.deliver_to_route(route, &sender, &subject, body)?;
    Ok(())
}

fn first_mailbox(addrs: &[MailAddr]) -> Option<String> {
    for addr in addrs {
        match addr {
            MailAddr::Single(info) => return Some(info.addr.clone()),
            MailAddr::Group(group) => {
                if let Some(first) = group.addrs.first() {
                    return Some(first.addr.clone());
                }
            }
        }
    }
    None
}

fn resolve_env_path(raw: &str) -> Result<PathBuf> {
    resolve_env_path_with_home(raw, home_dir)
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

fn load_env(path: &Path) -> Result<EnvConfig> {
    if path.exists() {
        EnvConfig::from_file(path)
    } else {
        Ok(EnvConfig::default())
    }
}

fn prompt(
    input: &mut impl BufRead,
    output: &mut impl Write,
    label: &str,
    default: Option<&str>,
) -> Result<String> {
    match default {
        Some(value) if !value.is_empty() => {
            write!(output, "{label} [{value}]: ")?;
        }
        _ => {
            write!(output, "{label}: ")?;
        }
    }
    output.flush()?;
    let mut line = String::new();
    input.read_line(&mut line)?;
    let trimmed = line.trim();
    if trimmed.is_empty() {
        Ok(default.unwrap_or_default().to_string())
    } else {
        Ok(trimmed.to_string())
    }
}

fn prompt_yes_no(
    input: &mut impl BufRead,
    output: &mut impl Write,
    label: &str,
    default_yes: bool,
) -> Result<bool> {
    loop {
        if default_yes {
            write!(output, "{label} [Y/n]: ")?;
        } else {
            write!(output, "{label} [y/N]: ")?;
        }
        output.flush()?;
        let mut line = String::new();
        input.read_line(&mut line)?;
        let trimmed = line.trim();
        let answer = if trimmed.is_empty() {
            if default_yes { "y" } else { "n" }
        } else {
            trimmed
        };
        match answer {
            "y" | "Y" => return Ok(true),
            "n" | "N" => return Ok(false),
            _ => {
                writeln!(output, "Please answer y or n.")?;
            }
        }
    }
}

fn setup_env(
    input: &mut impl BufRead,
    output: &mut impl Write,
    env_path: &Path,
    defaults: &EnvConfig,
) -> Result<()> {
    writeln!(output, "Configuring env file at {}", env_path.display())?;
    let keep_plus = prompt(
        input,
        output,
        "Keep plus-tags in addresses? (true/false)",
        Some(bool_to_env(defaults.keep_plus_tags)),
    )?;
    let render_mode = prompt(
        input,
        output,
        "Render mode (strict/moderate)",
        Some(&defaults.render_mode),
    )?;
    let logging = prompt(
        input,
        output,
        "Logging level (off/minimal/verbose_sanitized/verbose_full)",
        Some(&defaults.logging),
    )?;
    let max_quarantine = prompt(
        input,
        output,
        "Max size for quarantine (e.g. 25M)",
        Some(&defaults.max_size_quarantine),
    )?;
    let max_approved = prompt(
        input,
        output,
        "Max size for approved mail (e.g. 50M)",
        Some(&defaults.max_size_approved_default),
    )?;
    let dkim_selector = prompt(
        input,
        output,
        "DKIM selector",
        Some(&defaults.dkim_selector),
    )?;
    let dmarc_policy = prompt(input, output, "DMARC policy", Some(&defaults.dmarc_policy))?;
    let retry_backoff = prompt(
        input,
        output,
        "Retry backoff schedule",
        Some(&defaults.retry_backoff.join(",")),
    )?;

    upsert_env_setting(env_path, "keep_plus_tags", &keep_plus)?;
    upsert_env_setting(env_path, "render_mode", &render_mode)?;
    upsert_env_setting(env_path, "logging", &logging)?;
    upsert_env_setting(env_path, "max_size_quarantine", &max_quarantine)?;
    upsert_env_setting(env_path, "max_size_approved_default", &max_approved)?;
    upsert_env_setting(env_path, "dkim_selector", &dkim_selector)?;
    upsert_env_setting(env_path, "dmarc_policy", &dmarc_policy)?;
    upsert_env_setting(env_path, "retry_backoff", &retry_backoff)?;
    Ok(())
}

fn upsert_env_setting(env_path: &Path, key: &str, value: &str) -> Result<()> {
    let mut lines = Vec::new();
    let mut found = false;
    if env_path.exists() {
        let data = fs::read_to_string(env_path)
            .with_context(|| format!("reading {}", env_path.display()))?;
        for line in data.lines() {
            if line.trim_start().starts_with('#') || line.trim().is_empty() {
                lines.push(line.to_string());
                continue;
            }
            if let Some((k, _)) = line.split_once('=')
                && k.trim() == key
            {
                lines.push(format!("{key}={value}"));
                found = true;
                continue;
            }
            lines.push(line.to_string());
        }
    }
    if !found {
        lines.push(format!("{key}={value}"));
    }
    let rendered = if lines.is_empty() {
        format!("{key}={value}\n")
    } else {
        format!("{}\n", lines.join("\n"))
    };
    write_atomic(env_path, rendered.as_bytes())
        .with_context(|| format!("writing {}", env_path.display()))?;
    Ok(())
}

fn set_rules_entry(path: &Path, entry: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if path.exists() {
        let data = fs::read_to_string(path)?;
        if data.lines().any(|line| line.trim() == entry.trim()) {
            return Ok(());
        }
        let mut rendered = data;
        if !rendered.ends_with('\n') {
            rendered.push('\n');
        }
        rendered.push_str(entry.trim());
        rendered.push('\n');
        write_atomic(path, rendered.as_bytes())?;
    } else {
        write_atomic(path, format!("{}\n", entry.trim()).as_bytes())?;
    }
    Ok(())
}

fn set_settings_file(
    path: &Path,
    from_value: &str,
    reply_to: &str,
    signature: &str,
    body_format: &str,
    delete_after: &str,
    list_status: &str,
) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let settings = format!(
        "list_status={list_status}\n\
delete_after={delete_after}\n\
from={from_value}\n\
reply_to={reply_to}\n\
signature={signature}\n\
body_format={body_format}\n\
collapse_signatures=true\n"
    );
    write_atomic(path, settings.as_bytes())?;
    Ok(())
}

fn show_summary(output: &mut impl Write, env_path: &Path, root: &Path) -> Result<()> {
    writeln!(output, "Env file: {}", env_path.display())?;
    if env_path.exists() {
        let data = fs::read_to_string(env_path)?;
        for line in data.lines() {
            writeln!(output, "  {line}")?;
        }
    } else {
        writeln!(output, "  (missing)")?;
    }
    for list in ["accepted", "spam", "banned"] {
        let rules_path = root.join(list).join(".rules");
        writeln!(output, "Rules for {list}: {}", rules_path.display())?;
        if rules_path.exists() {
            let data = fs::read_to_string(&rules_path)?;
            for line in data.lines() {
                writeln!(output, "  {line}")?;
            }
        } else {
            writeln!(output, "  (missing)")?;
        }
    }
    Ok(())
}

fn bool_to_env(value: bool) -> &'static str {
    if value { "true" } else { "false" }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;
    use flate2::read::GzDecoder;
    use serial_test::serial;
    use std::{fs, io::Cursor, path::Path};
    use tar::Archive;

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
    fn triage_lists_quarantine_messages() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let sender_dir = layout.quarantine().join("alice@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let subject = "Greetings";
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FAV";
        let mut sidecar = MessageSidecar::new(
            ulid,
            crate::model::filename::message_filename(subject, ulid),
            "quarantine",
            "strict",
            crate::model::filename::html_filename(subject, ulid),
            "deadbeef",
            crate::model::message::HeadersCache::new("Alice", subject),
        );
        sidecar.set_rspamd(crate::model::message::RspamdSummary {
            score: 4.5,
            symbols: vec!["VIOLATION".into()],
        });
        let sidecar_path = sender_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();

        let output = triage(&env_path, &env, None, None, false).unwrap();
        assert!(output.contains("alice@example.org"));
        assert!(output.contains("Greetings"));
        assert!(output.contains("rspamd=4.5"));

        let json = triage(&env_path, &env, None, None, true).unwrap();
        let parsed: Vec<TriageEntry> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), 1);
        assert_eq!(parsed[0].address, "alice@example.org");
    }

    #[test]
    fn triage_filters_and_renders_extras() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let sender_dir = layout.accepted().join("carol@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let subject = "Follow up";
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FD0";
        let mut sidecar = MessageSidecar::new(
            ulid,
            crate::model::filename::message_filename(subject, ulid),
            "accepted",
            "strict",
            crate::model::filename::html_filename(subject, ulid),
            "aa11bb22",
            crate::model::message::HeadersCache::new("Carol", subject),
        );
        sidecar.set_rspamd(crate::model::message::RspamdSummary {
            score: 2.0,
            symbols: vec!["SCORE".into()],
        });
        let outbound = sidecar.outbound_state_mut();
        outbound.attempts = 3;
        outbound.last_error = Some("timeout".into());
        outbound.next_attempt_at = Some("2030-01-01T00:00:00Z".into());
        let sidecar_path = sender_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();

        let output = triage(
            &env_path,
            &env,
            Some("carol@example.org".into()),
            Some("accepted".into()),
            false,
        )
        .unwrap();
        assert!(output.contains("outbound=Pending attempts=3"));
        assert!(output.contains("last_error=timeout"));
        assert!(output.contains("rspamd=2.0"));
    }

    #[test]
    fn triage_unknown_list_errors() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let err = triage(&env_path, &env, None, Some("mystery".into()), false).unwrap_err();
        assert!(err.to_string().contains("unknown list"));
    }

    #[test]
    fn triage_reports_empty_lists() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let output = triage(&env_path, &env, None, Some("spam".into()), false).unwrap();
        assert_eq!(output, "no messages matched");
    }

    #[test]
    fn pin_address_toggles_flag() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let sender_dir = layout.accepted().join("bob@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FB0";
        let mut sidecar = MessageSidecar::new(
            ulid,
            crate::model::filename::message_filename("Status", ulid),
            "accepted",
            "strict",
            crate::model::filename::html_filename("Status", ulid),
            "feedface",
            crate::model::message::HeadersCache::new("Bob", "Status"),
        );
        sidecar.set_rspamd(crate::model::message::RspamdSummary {
            score: 1.0,
            symbols: vec!["FLAGGED".into()],
        });
        let sidecar_path =
            sender_dir.join(crate::model::filename::sidecar_filename("Status", ulid));
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        let cli_pin = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Pin {
                address: "bob@example.org".into(),
                unset: false,
            }),
            json: false,
        };
        let result = run(cli_pin, env.clone()).unwrap();
        assert!(result.contains("pinned bob@example.org"));
        let updated: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(&sidecar_path).unwrap()).unwrap();
        assert!(updated.pinned);
        let cli_unpin = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Pin {
                address: "bob@example.org".into(),
                unset: true,
            }),
            json: false,
        };
        let result = run(cli_unpin, env.clone()).unwrap();
        assert!(result.contains("unpinned bob@example.org"));
        let updated: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(&sidecar_path).unwrap()).unwrap();
        assert!(!updated.pinned);
    }

    #[test]
    fn pin_address_errors_when_missing() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Pin {
                address: "nobody@example.org".into(),
                unset: false,
            }),
            json: false,
        };
        let err = run(cli, env).unwrap_err();
        assert!(err.to_string().contains("no messages found"));
    }

    #[test]
    fn send_draft_queues_message_and_records_retry() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig {
            retry_backoff: vec!["1s".into()],
            ..EnvConfig::default()
        };
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let ulid = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{ulid}.md"));
        fs::write(
            &draft_path,
            "---\nsubject: Hi\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\n---\nHello world!\n",
        )
        .unwrap();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Send {
                draft: draft_path.to_string_lossy().into(),
            }),
            json: false,
        };
        let output = run(cli, env.clone()).unwrap();
        assert!(output.contains(&ulid));
        let sidecar_path = layout
            .outbox()
            .join(crate::model::filename::outbox_sidecar_filename(&ulid));
        assert!(sidecar_path.exists());
        let sidecar: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(sidecar_path).unwrap()).unwrap();
        assert!(sidecar.outbound.is_some());
        assert_eq!(sidecar.outbound.unwrap().attempts, 1);
    }

    #[test]
    fn send_draft_reports_missing_file() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Send {
                draft: "nonexistent.md".into(),
            }),
            json: false,
        };
        let err = run(cli, env).unwrap_err();
        assert!(err.to_string().contains("draft"));
    }

    #[test]
    fn backup_and_import_round_trip() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join("mail/.env");
        let root = env_path.parent().unwrap();
        fs::create_dir_all(root).unwrap();
        let layout = MailLayout::new(root);
        layout.ensure().unwrap();
        fs::write(layout.root().join("marker.txt"), b"ok").unwrap();
        let backup_path = dir.path().join("backup.tar.gz");
        let backup_cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Backup {
                path: backup_path.clone(),
            }),
            json: false,
        };
        let output = run(backup_cli, EnvConfig::default()).unwrap();
        assert!(output.contains("backup written"));
        assert!(backup_path.exists());

        let dest_dir = tempfile::tempdir().unwrap();
        let dest_env = dest_dir.path().join("mail/.env");
        fs::create_dir_all(dest_env.parent().unwrap()).unwrap();
        let import_cli = OwlCli {
            env: dest_env.to_string_lossy().into(),
            command: Some(Commands::Import {
                source: backup_path.clone(),
            }),
            json: false,
        };
        run(import_cli, EnvConfig::default()).unwrap();
        assert!(dest_env.parent().unwrap().join("marker.txt").exists());
    }

    #[test]
    fn export_sender_writes_tarball() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let env = EnvConfig::default();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let sender_dir = layout.accepted().join("carol@example.org");
        fs::create_dir_all(&sender_dir).unwrap();
        let subject = "Report";
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FC0";
        let mut sidecar = MessageSidecar::new(
            ulid,
            crate::model::filename::message_filename(subject, ulid),
            "accepted",
            "strict",
            crate::model::filename::html_filename(subject, ulid),
            "cafebabe",
            crate::model::message::HeadersCache::new("Carol", subject),
        );
        sidecar.add_attachment("cafebabe", "report.pdf");
        let sidecar_path = sender_dir.join(crate::model::filename::sidecar_filename(subject, ulid));
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        let attachment_path = layout.attachments("accepted").join("cafebabe__report.pdf");
        fs::create_dir_all(attachment_path.parent().unwrap()).unwrap();
        fs::write(&attachment_path, b"pdf").unwrap();

        let export_path = dir.path().join("carol.tar.gz");
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::ExportSender {
                list: "accepted".into(),
                address: "carol@example.org".into(),
                path: export_path.clone(),
            }),
            json: false,
        };
        let output = run(cli, env.clone()).unwrap();
        assert!(output.contains("exported carol@example.org"));
        assert!(export_path.exists());

        let file = fs::File::open(&export_path).unwrap();
        let mut archive = Archive::new(GzDecoder::new(file));
        let mut entries = Vec::new();
        archive
            .entries()
            .unwrap()
            .for_each(|entry| entries.push(entry.unwrap().path().unwrap().into_owned()));
        assert!(entries.iter().any(|p| p.ends_with(Path::new(
            "accepted/carol@example.org/.Report (01ARZ3NDEKTSV4RRFFQ69G5FC0).yml"
        ))));
        assert!(
            entries
                .iter()
                .any(|p| p.ends_with(Path::new("accepted/attachments/cafebabe__report.pdf")))
        );
    }

    #[test]
    fn export_sender_errors_when_missing() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::ExportSender {
                list: "accepted".into(),
                address: "ghost@example.org".into(),
                path: dir.path().join("ghost.tar.gz"),
            }),
            json: false,
        };
        let err = run(cli, EnvConfig::default()).unwrap_err();
        assert!(err.to_string().contains("not found"));
    }

    #[test]
    fn logs_command_formats_entries() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        let env_path = dir.path().join(".env");
        fs::write(&env_path, "logging=minimal\n").unwrap();
        let logger = Logger::new(root, LogLevel::Minimal).unwrap();
        logger
            .log(LogLevel::Minimal, "outbox.retry", Some("attempt=1"))
            .unwrap();
        let show_cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Logs {
                action: LogAction::Show,
            }),
            json: false,
        };
        let human = run(show_cli, EnvConfig::default()).unwrap();
        assert!(human.contains("outbox.retry"));
        let tail_cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Logs {
                action: LogAction::Tail,
            }),
            json: true,
        };
        let json = run(tail_cli, EnvConfig::default()).unwrap();
        let parsed: Vec<logging::LogEntry> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), 1);
        assert_eq!(parsed[0].level, "minimal");
        let disabled_cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Logs {
                action: LogAction::Show,
            }),
            json: false,
        };
        let disabled = run(
            disabled_cli,
            EnvConfig {
                logging: "off".into(),
                ..EnvConfig::default()
            },
        )
        .unwrap();
        assert_eq!(disabled, "logging disabled");
        let disabled_tail_cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Logs {
                action: LogAction::Tail,
            }),
            json: true,
        };
        let disabled_json = run(
            disabled_tail_cli,
            EnvConfig {
                logging: "off".into(),
                ..EnvConfig::default()
            },
        )
        .unwrap();
        assert_eq!(disabled_json, "[]");
    }

    #[test]
    #[serial]
    fn import_maildir_consumes_messages() {
        with_fake_render_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let maildir = dir.path().join("maildir");
            fs::create_dir_all(maildir.join("cur")).unwrap();
            fs::write(
                maildir.join("cur/msg1"),
                sample_email("Alice <alice@example.org>", "Status"),
            )
            .unwrap();

            let root = dir.path().join("mail");
            fs::create_dir_all(&root).unwrap();
            let env_path = root.join(".env");
            fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();

            let output = import_archive(&env_path, &maildir).unwrap();
            assert!(output.contains("1 messages"));

            let layout = MailLayout::new(&root);
            let sender_dir = layout.quarantine().join("alice@example.org");
            let entries: Vec<_> = fs::read_dir(&sender_dir)
                .unwrap()
                .map(|entry| entry.unwrap().path())
                .collect();
            assert!(
                entries
                    .iter()
                    .any(|path| path.extension().map(|ext| ext == "eml").unwrap_or(false))
            );
            let sidecar_path = entries
                .iter()
                .find(|path| path.extension().map(|ext| ext == "yml").unwrap_or(false))
                .unwrap();
            let sidecar: MessageSidecar =
                serde_yaml::from_str(&fs::read_to_string(sidecar_path).unwrap()).unwrap();
            assert_eq!(sidecar.status_shadow, "quarantine");
            assert_eq!(sidecar.headers_cache.subject, "Status");
        });
    }

    #[test]
    #[serial]
    fn import_mbox_consumes_messages() {
        with_fake_render_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let root = dir.path().join("mail");
            fs::create_dir_all(&root).unwrap();
            let env_path = root.join(".env");
            fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();

            let mbox_path = dir.path().join("import.mbox");
            let mut mbox = Vec::new();
            mbox.extend_from_slice(b"From alice@example.org Sat Jan  1 00:00:00 2022\n");
            mbox.extend_from_slice(&sample_email("Alice <alice@example.org>", "Hello"));
            mbox.push(b'\n');
            mbox.extend_from_slice(b"From bob@example.org Sat Jan  1 01:00:00 2022\n");
            mbox.extend_from_slice(&sample_email("Bob <bob@example.org>", "Update"));
            fs::write(&mbox_path, &mbox).unwrap();

            let output = import_archive(&env_path, &mbox_path).unwrap();
            assert!(output.contains("2 messages"));

            let layout = MailLayout::new(&root);
            assert!(layout.quarantine().join("alice@example.org").exists());
            assert!(layout.quarantine().join("bob@example.org").exists());
        });
    }

    #[test]
    #[serial]
    fn import_mail_without_from_uses_fallback_sender() {
        with_fake_render_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let maildir = dir.path().join("maildir");
            fs::create_dir_all(maildir.join("cur")).unwrap();
            fs::write(maildir.join("cur/msg1"), b"Subject: Notice\n\nHello\n").unwrap();

            let root = dir.path().join("mail");
            fs::create_dir_all(&root).unwrap();
            let env_path = root.join(".env");
            fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();

            import_archive(&env_path, &maildir).unwrap();

            let layout = MailLayout::new(&root);
            let fallback_dir = layout.quarantine().join("unknown@import.invalid");
            assert!(fallback_dir.exists());
        });
    }

    #[test]
    fn import_archive_errors_when_missing() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Import {
                source: dir.path().join("missing.tar.gz"),
            }),
            json: false,
        };
        let err = run(cli, EnvConfig::default()).unwrap_err();
        assert!(err.to_string().contains("not found"));
    }

    #[test]
    #[serial]
    fn import_archive_supports_tgz_and_tar() {
        with_fake_render_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let root = dir.path().join("mail");
            fs::create_dir_all(&root).unwrap();
            let env_path = root.join(".env");
            fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();

            let tgz_path = dir.path().join("archive.tgz");
            {
                let file = fs::File::create(&tgz_path).unwrap();
                let encoder = GzEncoder::new(file, Compression::default());
                let mut builder = Builder::new(encoder);
                let mut header = tar::Header::new_gnu();
                header.set_mode(0o644);
                header.set_uid(0);
                header.set_gid(0);
                header.set_mtime(0);
                header.set_size(2);
                header.set_cksum();
                builder
                    .append_data(&mut header, "marker.txt", &b"hi"[..])
                    .unwrap();
                builder.into_inner().unwrap().finish().unwrap();
            }

            let tar_path = dir.path().join("archive.tar");
            {
                let file = fs::File::create(&tar_path).unwrap();
                let mut builder = Builder::new(file);
                let mut header = tar::Header::new_gnu();
                header.set_mode(0o644);
                header.set_uid(0);
                header.set_gid(0);
                header.set_mtime(0);
                header.set_size(2);
                header.set_cksum();
                builder
                    .append_data(&mut header, "note.txt", &b"ok"[..])
                    .unwrap();
                builder.finish().unwrap();
            }

            let tgz_cli = OwlCli {
                env: env_path.to_string_lossy().into(),
                command: Some(Commands::Import {
                    source: tgz_path.clone(),
                }),
                json: false,
            };
            run(tgz_cli, EnvConfig::default()).unwrap();
            assert!(root.join("marker.txt").exists());

            let tar_cli = OwlCli {
                env: env_path.to_string_lossy().into(),
                command: Some(Commands::Import {
                    source: tar_path.clone(),
                }),
                json: false,
            };
            run(tar_cli, EnvConfig::default()).unwrap();
            assert!(root.join("note.txt").exists());
        });
    }

    #[test]
    fn import_archive_rejects_unknown_format() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let source = dir.path().join("data.bin");
        fs::write(&source, b"binary").unwrap();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Import {
                source: source.clone(),
            }),
            json: false,
        };
        let err = run(cli, EnvConfig::default()).unwrap_err();
        assert!(err.to_string().contains("unsupported import format"));
    }

    fn sample_email(from: &str, subject: &str) -> Vec<u8> {
        format!("From: {from}\r\nTo: you@example.org\r\nSubject: {subject}\r\n\r\nBody\r\n")
            .into_bytes()
    }

    #[test]
    fn first_mailbox_extracts_from_groups() {
        let group = MailAddr::Group(mailparse::GroupInfo {
            group_name: "Team".into(),
            addrs: vec![mailparse::SingleInfo {
                display_name: Some("Helper".into()),
                addr: "helper@example.org".into(),
            }],
        });
        let single = MailAddr::Single(mailparse::SingleInfo {
            display_name: Some("Lead".into()),
            addr: "lead@example.org".into(),
        });
        assert_eq!(
            first_mailbox(std::slice::from_ref(&group)),
            Some("helper@example.org".into())
        );
        assert_eq!(first_mailbox(&[single]), Some("lead@example.org".into()));
        assert_eq!(
            first_mailbox(&[
                group,
                MailAddr::Group(mailparse::GroupInfo {
                    group_name: String::new(),
                    addrs: vec![],
                })
            ]),
            Some("helper@example.org".into())
        );
        assert_eq!(first_mailbox(&[]), None);
    }

    fn with_fake_render_env<T>(f: impl FnOnce() -> T) -> T {
        let dir = tempfile::tempdir().unwrap();
        write_exec(&dir, "sanitize-html", "#!/bin/sh\n/bin/cat\n");
        write_exec(&dir, "lynx", "#!/bin/sh\n/bin/cat\n");
        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe {
            std::env::set_var("PATH", &new_path);
        }
        struct PathGuard {
            original: Option<std::ffi::OsString>,
        }
        impl Drop for PathGuard {
            fn drop(&mut self) {
                match self.original.take() {
                    Some(path) => unsafe { std::env::set_var("PATH", path) },
                    None => unsafe { std::env::remove_var("PATH") },
                }
            }
        }
        let _guard = PathGuard { original };
        f()
    }

    #[test]
    #[serial]
    fn with_fake_render_env_handles_missing_path() {
        let original = std::env::var_os("PATH");
        unsafe { std::env::remove_var("PATH") };
        let path_inside = with_fake_render_env(|| std::env::var_os("PATH"));
        assert!(
            path_inside.is_some(),
            "helper should populate PATH during call"
        );
        match original {
            Some(value) => unsafe { std::env::set_var("PATH", value) },
            None => unsafe { std::env::remove_var("PATH") },
        }
    }

    fn write_exec(dir: &tempfile::TempDir, name: &str, body: &str) {
        let path = dir.path().join(name);
        fs::write(&path, body).unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&path).unwrap().permissions();
            perms.set_mode(0o755);
            // Ignore permission errors on systems that don't support it
            let _ = fs::set_permissions(&path, perms);
        }
    }

    fn with_fake_ops_env<T>(f: impl FnOnce() -> T) -> T {
        let dir = tempfile::tempdir().unwrap();
        for name in ["certbot", "rspamadm", "systemctl", "chronyc"] {
            write_exec(&dir, name, "#!/bin/sh\nexit 0\n");
        }
        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe {
            std::env::set_var("PATH", &new_path);
        }
        struct PathGuard {
            original: Option<std::ffi::OsString>,
        }
        impl Drop for PathGuard {
            fn drop(&mut self) {
                match self.original.take() {
                    Some(path) => unsafe { std::env::set_var("PATH", path) },
                    None => unsafe { std::env::remove_var("PATH") },
                }
            }
        }
        let _guard = PathGuard { original };
        f()
    }

    #[test]
    #[serial]
    fn with_fake_ops_env_restores_missing_path() {
        let original = std::env::var_os("PATH");
        unsafe { std::env::remove_var("PATH") };
        let path_inside = with_fake_ops_env(|| std::env::var_os("PATH"));
        assert!(
            path_inside.is_some(),
            "helper should seed PATH when missing"
        );
        match original {
            Some(value) => unsafe { std::env::set_var("PATH", value) },
            None => unsafe { std::env::remove_var("PATH") },
        }
    }

    #[test]
    #[serial]
    fn install_sets_up_mail_root_and_env() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Install),
            json: false,
        };
        let env = EnvConfig::default();
        let output = with_fake_ops_env(|| run(cli.clone(), env.clone()).unwrap());
        assert!(output.contains("installed"));
        assert!(dir.path().join("quarantine").exists());
        let dkim_dir = dir.path().join("dkim");
        assert!(dkim_dir.exists());
        let selector = env.dkim_selector.clone();
        assert!(dkim_dir.join(format!("{selector}.private")).exists());
        assert!(dkim_dir.join(format!("{selector}.public")).exists());
        assert!(dkim_dir.join(format!("{selector}.dns")).exists());
        let config_root = dir.path().join("config");
        assert!(config_root.join("postfix/main.cf").exists());
        assert!(config_root.join("rspamd/local.d/rate_limit.conf").exists());
        assert!(config_root.join("letsencrypt/README.txt").exists());
        let env_contents = std::fs::read_to_string(&env_path).unwrap();
        assert!(env_contents.contains("dmarc_policy=none"));
        std::fs::write(&env_path, "logging=off\n").unwrap();
        let again = with_fake_ops_env(|| run(cli, env.clone()).unwrap());
        assert!(again.contains("installed"));
        let env_contents_after = std::fs::read_to_string(&env_path).unwrap();
        assert_eq!(env_contents_after, "logging=off\n");
    }

    #[test]
    #[serial]
    fn install_skips_existing_env_logs_message() {
        with_fake_ops_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let env_path = dir.path().join(".env");
            let env = EnvConfig {
                logging: "verbose_sanitized".into(),
                ..EnvConfig::default()
            };
            fs::write(&env_path, env.to_env_string()).unwrap();
            let cli = OwlCli {
                env: env_path.to_string_lossy().into(),
                command: Some(Commands::Install),
                json: false,
            };
            run(cli, env.clone()).unwrap();
            let log_path = MailLayout::new(dir.path()).log_file();
            let entries = Logger::load_entries(&log_path).unwrap();
            assert!(
                entries
                    .iter()
                    .any(|entry| entry.message == "install.env.skipped")
            );
        });
    }

    fn assert_log_contains(logger: &Logger, message: &str) {
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries.iter().any(|entry| entry.message == message),
            "expected log entry `{message}` not found"
        );
    }

    #[test]
    #[serial]
    fn install_logs_each_step() {
        with_fake_ops_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let env_path = dir.path().join(".env");
            let env = EnvConfig {
                logging: "verbose_sanitized".into(),
                ..EnvConfig::default()
            };
            let logger = Logger::new(dir.path(), LogLevel::VerboseSanitized).unwrap();

            let summary = install(&env_path, &env, &logger).unwrap();
            assert!(summary.contains("installed"));
            assert_log_contains(&logger, "install.ensure");
            assert_log_contains(&logger, "install.dkim.ready");
            assert_log_contains(&logger, "install.env.created");

            // Second invocation exercises the skipped-environment branch while
            // keeping verbose logging enabled so the entry is recorded.
            let again = install(&env_path, &env, &logger).unwrap();
            assert!(again.contains("installed"));
            assert_log_contains(&logger, "install.env.skipped");
        });
    }

    #[test]
    #[serial]
    fn update_logs_summary() {
        with_fake_ops_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let env_path = dir.path().join(".env");
            let env = EnvConfig::default();
            let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();

            let summary = update(&env_path, &env, &logger).unwrap();
            assert!(summary.contains("updated"));
            assert_log_contains(&logger, "update.provisioned");
        });
    }

    #[test]
    #[serial]
    fn restart_reports_daemon_summary() {
        with_fake_ops_env(|| {
            let dir = tempfile::tempdir().unwrap();
            write_exec(&dir, "systemctl", "#!/bin/sh\nexit 0\n");
            let env_path = dir.path().join(".env");
            fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();
            let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();

            let summary = restart(&env_path, RestartTarget::Daemons, &logger).unwrap();
            assert!(summary.contains("restart daemons"));
            assert!(summary.contains("owl-daemon=ok"));
            assert_log_contains(&logger, "restart.service");
        });
    }

    #[test]
    fn logs_return_no_entries_when_empty() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig::default();
        let output = logs(
            layout.root(),
            env.logging.parse().unwrap(),
            LogAction::Show,
            false,
        )
        .unwrap();
        assert_eq!(output, "no log entries");
    }

    #[test]
    fn triage_rejects_unsupported_list() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();
        let err = triage(
            &env_path,
            &EnvConfig::default(),
            None,
            Some("invalid".into()),
            false,
        )
        .unwrap_err();
        assert!(err.to_string().contains("unknown list"));
    }

    #[test]
    fn triage_skips_missing_sender_directory() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let canonical = Address::parse("alice@example.org", false)
            .unwrap()
            .canonical()
            .to_string();
        let output = triage(
            &env_path,
            &EnvConfig::default(),
            Some("alice@example.org".into()),
            Some("quarantine".into()),
            false,
        )
        .unwrap();
        assert_eq!(output, "no messages matched");
        // ensure we touched the expected sender path even though it does not exist
        assert!(!layout.quarantine().join(&canonical).exists());
    }

    #[test]
    #[serial]
    fn run_update_provisions_environment() {
        with_fake_ops_env(|| {
            let dir = tempfile::tempdir().unwrap();
            let env_path = dir.path().join(".env");
            let cli = OwlCli {
                env: env_path.to_string_lossy().into(),
                command: Some(Commands::Update),
                json: false,
            };
            let output = run(cli, EnvConfig::default()).unwrap();
            assert!(output.contains("updated"));
            assert!(dir.path().join("config/postfix/main.cf").exists());
        });
    }

    #[test]
    fn run_defaults_to_triage_when_command_missing() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: None,
            json: false,
        };
        let output = run(cli, EnvConfig::default()).unwrap();
        assert_eq!(output, "no messages matched");
    }

    #[test]
    fn prompt_uses_default_when_empty() {
        let input_data = b"\n";
        let mut input = Cursor::new(input_data.as_slice());
        let mut output = Vec::new();
        let value = prompt(&mut input, &mut output, "Label", Some("default")).unwrap();
        assert_eq!(value, "default");
        assert!(
            String::from_utf8(output)
                .unwrap()
                .contains("Label [default]:")
        );
    }

    #[test]
    fn prompt_yes_no_accepts_defaults_and_inputs() {
        let mut input = Cursor::new(b"\n");
        let mut output = Vec::new();
        let value = prompt_yes_no(&mut input, &mut output, "Confirm?", true).unwrap();
        assert!(value);

        let mut input = Cursor::new(b"n\n");
        let mut output = Vec::new();
        let value = prompt_yes_no(&mut input, &mut output, "Confirm?", true).unwrap();
        assert!(!value);
    }

    #[test]
    fn upsert_env_setting_updates_existing_key() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        fs::write(&env_path, "logging=minimal\n").unwrap();
        upsert_env_setting(&env_path, "logging", "verbose_full").unwrap();
        let contents = fs::read_to_string(&env_path).unwrap();
        assert!(contents.contains("logging=verbose_full"));
    }

    #[test]
    fn set_rules_entry_appends_once() {
        let dir = tempfile::tempdir().unwrap();
        let rules_path = dir.path().join("accepted/.rules");
        set_rules_entry(&rules_path, "alice@example.org").unwrap();
        set_rules_entry(&rules_path, "alice@example.org").unwrap();
        let contents = fs::read_to_string(&rules_path).unwrap();
        let count = contents
            .lines()
            .filter(|line| *line == "alice@example.org")
            .count();
        assert_eq!(count, 1);
    }

    #[test]
    fn set_settings_file_renders_expected_keys() {
        let dir = tempfile::tempdir().unwrap();
        let settings_path = dir.path().join("accepted/.settings");
        set_settings_file(
            &settings_path,
            "Owl <owl@example.org>",
            "reply@example.org",
            "/tmp/signature.txt",
            "both",
            "never",
            "accepted",
        )
        .unwrap();
        let contents = fs::read_to_string(&settings_path).unwrap();
        assert!(contents.contains("list_status=accepted"));
        assert!(contents.contains("body_format=both"));
        assert!(contents.contains("signature=/tmp/signature.txt"));
    }

    #[test]
    fn show_summary_handles_missing_files() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let mut output = Vec::new();
        show_summary(&mut output, &env_path, dir.path()).unwrap();
        let rendered = String::from_utf8(output).unwrap();
        assert!(rendered.contains("(missing)"));
        assert!(rendered.contains("Rules for accepted"));
    }

    #[test]
    #[serial]
    fn restart_reports_errors_for_each_service() {
        fn write_failing_exec(dir: &tempfile::TempDir, name: &str) {
            let path = dir.path().join(name);
            fs::write(&path, "#!/bin/sh\necho \"$@\" >/dev/null\nexit 1\n").unwrap();
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = fs::metadata(&path).unwrap().permissions();
                perms.set_mode(0o755);
                // Ignore permission errors on systems that don't support it
                let _ = fs::set_permissions(&path, perms);
            }
        }

        let dir = tempfile::tempdir().unwrap();
        write_failing_exec(&dir, "systemctl");
        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe { std::env::set_var("PATH", &new_path) };

        let env_path = dir.path().join(".env");
        fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();
        let summary = restart(&env_path, RestartTarget::All, &logger).unwrap();
        assert!(summary.contains("postfix=error"));
        assert!(summary.contains("owl-daemon=error"));
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "restart.service.error")
        );
        match original {
            Some(path) => unsafe { std::env::set_var("PATH", path) },
            None => unsafe { std::env::remove_var("PATH") },
        }
    }

    #[test]
    #[serial]
    fn restart_reports_success_for_requested_service() {
        let dir = tempfile::tempdir().unwrap();
        let exec = dir.path().join("systemctl");
        fs::write(&exec, "#!/bin/sh\nexit 0\n").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&exec).unwrap().permissions();
            perms.set_mode(0o755);
            // Ignore permission errors on systems that don't support it
            let _ = fs::set_permissions(&exec, perms);
        }
        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe { std::env::set_var("PATH", &new_path) };
        let env_path = dir.path().join(".env");
        fs::write(&env_path, EnvConfig::default().to_env_string()).unwrap();
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::Restart {
                target: RestartTarget::Postfix,
            }),
            json: false,
        };
        let summary = run(cli, EnvConfig::default()).unwrap();
        assert!(summary.contains("postfix=ok"));
        match original {
            Some(path) => unsafe { std::env::set_var("PATH", path) },
            None => unsafe { std::env::remove_var("PATH") },
        }
    }

    #[test]
    fn logs_tail_supports_json_output() {
        let dir = tempfile::tempdir().unwrap();
        let logger = Logger::new(dir.path(), LogLevel::Minimal).unwrap();
        logger
            .log(LogLevel::Minimal, "install", Some("root=/tmp"))
            .unwrap();
        logger
            .log(LogLevel::Minimal, "retry", Some("attempt=2"))
            .unwrap();
        let output = logs(dir.path(), LogLevel::Minimal, LogAction::Tail, true).unwrap();
        assert!(output.starts_with("["));
        assert!(output.contains("\"retry\""));
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
    fn resolve_draft_path_resolves_relative_and_absolute() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let draft = layout.drafts().join("abc.md");
        fs::write(&draft, "content").unwrap();
        let resolved = resolve_draft_path(&layout, "abc").unwrap();
        assert_eq!(resolved, draft);
        let absolute = dir.path().join("custom.md");
        fs::write(&absolute, "note").unwrap();
        let resolved_absolute =
            resolve_draft_path(&layout, absolute.to_string_lossy().as_ref()).unwrap();
        assert_eq!(resolved_absolute, absolute);
    }

    #[test]
    fn resolve_draft_path_errors_when_missing() {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let err = resolve_draft_path(&layout, "missing").unwrap_err();
        assert!(err.to_string().contains("not found"));
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
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::ListSenders { list: None }),
            json: false,
        };
        let output = run(cli, EnvConfig::default()).unwrap();
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
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::ListSenders {
                list: Some("banned".into()),
            }),
            json: false,
        };
        let output = run(cli, EnvConfig::default()).unwrap();
        assert_eq!(output, "banned:spammer@example.com");
    }

    #[test]
    fn list_senders_rejects_unknown_list() {
        let dir = tempfile::tempdir().unwrap();
        let env_path = dir.path().join(".env");
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::ListSenders {
                list: Some("unknown".into()),
            }),
            json: false,
        };
        let err = run(cli, EnvConfig::default()).unwrap_err();
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

        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::MoveSender {
                from: "accepted".into(),
                to: "spam".into(),
                address: "alice@example.org".into(),
            }),
            json: false,
        };
        let output = run(cli, env.clone()).unwrap();
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
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::MoveSender {
                from: "accepted".into(),
                to: "accepted".into(),
                address: "bob@example.org".into(),
            }),
            json: false,
        };
        let err = run(cli, env.clone()).unwrap_err();
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

        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::MoveSender {
                from: "accepted".into(),
                to: "quarantine".into(),
                address: "eve@example.org".into(),
            }),
            json: false,
        };
        run(cli, env.clone()).unwrap();
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
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::MoveSender {
                from: "accepted".into(),
                to: "spam".into(),
                address: "nobody@example.org".into(),
            }),
            json: false,
        };
        let err = run(cli, env.clone()).unwrap_err();
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
        let cli = OwlCli {
            env: env_path.to_string_lossy().into(),
            command: Some(Commands::MoveSender {
                from: "accepted".into(),
                to: "spam".into(),
                address: "dave@example.org".into(),
            }),
            json: false,
        };
        let err = run(cli, env.clone()).unwrap_err();
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

    #[test]
    fn sidecar_files_returns_empty_for_missing_directory() {
        let dir = tempfile::tempdir().unwrap();
        let missing = dir.path().join("none");
        let files = sidecar_files(&missing).unwrap();
        assert!(files.is_empty());
    }
}
