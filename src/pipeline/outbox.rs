use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::sync::Arc;

use ::ulid::Ulid;
use anyhow::{Context, Result, anyhow, bail};
use lettre::Transport;
use lettre::address::Envelope;
use lettre::message::{Mailbox, Message, MultiPart};
use lettre::transport::smtp::{SmtpTransport, authentication::Credentials};
use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd, html};
use sha2::{Digest, Sha256};
use time::{
    Duration, OffsetDateTime,
    format_description::well_known::{Rfc2822, Rfc3339},
};

use crate::{
    envcfg::EnvConfig,
    fsops::{io_atom::write_atomic, layout::MailLayout},
    model::{
        filename::{outbox_html_filename, outbox_message_filename, outbox_sidecar_filename},
        message::{HeadersCache, MessageSidecar, OutboundStatus},
    },
    util::{
        dkim::{self, DkimSigner},
        logging::{LogLevel, Logger},
        time::parse_interval,
    },
};

const SIGNED_HEADERS: &[&str] = &[
    "from",
    "to",
    "subject",
    "date",
    "mime-version",
    "content-type",
];

pub struct OutboxPipeline {
    layout: MailLayout,
    env: EnvConfig,
    logger: Logger,
    transport: Arc<dyn MailTransport>,
    retry_schedule: Vec<Duration>,
}

impl OutboxPipeline {
    pub fn new(layout: MailLayout, env: EnvConfig, logger: Logger) -> Self {
        let schedule = parse_retry_schedule(&env);
        let transport = Arc::new(SmtpRelay::from_env(&env));
        Self {
            layout,
            env,
            logger,
            transport,
            retry_schedule: schedule,
        }
    }

    pub fn with_transport(
        layout: MailLayout,
        env: EnvConfig,
        logger: Logger,
        transport: Arc<dyn MailTransport>,
    ) -> Self {
        let schedule = parse_retry_schedule(&env);
        Self {
            layout,
            env,
            logger,
            transport,
            retry_schedule: schedule,
        }
    }

    pub fn queue_draft(&self, draft_path: &Path) -> Result<PathBuf> {
        let draft = Draft::from_file(draft_path)?;
        let material =
            dkim::ensure_ed25519_keypair(&self.layout.dkim_dir(), &self.env.dkim_selector)?;
        let signer = DkimSigner::from_material(&material)?;

        fs::create_dir_all(self.layout.outbox())?;

        let text_body = markdown_to_text(&draft.body);
        let html_body = markdown_to_html(&draft.body);

        let mut builder = Message::builder()
            .from(draft.from.clone())
            .subject(&draft.subject);

        let timestamp = OffsetDateTime::now_utc();
        builder = builder.date(timestamp.into());
        builder = builder.message_id(Some(format!("<{}@{}>", draft.ulid, draft.domain)));

        if let Some(reply_to) = &draft.reply_to {
            builder = builder.reply_to(reply_to.clone());
        }

        for recipient in &draft.to {
            builder = builder.to(recipient.clone());
        }

        for recipient in &draft.cc {
            builder = builder.cc(recipient.clone());
        }

        let multipart = MultiPart::alternative_plain_html(text_body.clone(), html_body.clone());
        let message = builder.multipart(multipart)?;

        let formatted = message.formatted();
        let (headers_raw, body_bytes) = split_headers_body(&formatted)?;
        let dkim_value = signer.sign(&draft.domain, &headers_raw, body_bytes, SIGNED_HEADERS)?;

        let mut final_message = Vec::new();
        final_message.extend_from_slice(format!("DKIM-Signature: {dkim_value}\r\n").as_bytes());
        final_message.extend_from_slice(headers_raw.as_bytes());
        final_message.extend_from_slice(b"\r\n\r\n");
        final_message.extend_from_slice(body_bytes);

        let hash = Sha256::digest(&final_message);
        let hash_hex = hex::encode(hash);

        let message_filename = outbox_message_filename(&draft.ulid);
        let message_path = self.layout.outbox().join(&message_filename);
        write_atomic(&message_path, &final_message)?;

        let html_filename = outbox_html_filename(&draft.ulid);
        let html_path = self.layout.outbox().join(&html_filename);
        write_atomic(&html_path, html_body.as_bytes())?;

        let sidecar_filename = outbox_sidecar_filename(&draft.ulid);
        let sidecar_path = self.layout.outbox().join(&sidecar_filename);
        let headers_cache = HeadersCache {
            from: draft.from.to_string(),
            to: draft.to.iter().map(|m| m.to_string()).collect(),
            cc: draft.cc.iter().map(|m| m.to_string()).collect(),
            subject: draft.subject.clone(),
            date: header_value(&headers_raw, "date")
                .unwrap_or_else(|| timestamp.format(&Rfc2822).unwrap()),
        };
        let mut sidecar = MessageSidecar::new(
            draft.ulid.clone(),
            message_filename,
            "outbox",
            self.env.render_mode.clone(),
            html_filename,
            hash_hex,
            headers_cache,
        );
        sidecar.outbound_state_mut();
        let yaml = serde_yaml::to_string(&sidecar)?;
        write_atomic(&sidecar_path, yaml.as_bytes())?;

        Ok(message_path)
    }

    pub fn dispatch_pending(&self) -> Result<Vec<DispatchResult>> {
        let mut outcomes = Vec::new();
        let outbox_dir = self.layout.outbox();
        if !outbox_dir.exists() {
            return Ok(outcomes);
        }
        for entry in fs::read_dir(&outbox_dir)? {
            let entry = entry?;
            if !entry.file_type()?.is_file() {
                continue;
            }
            let path = entry.path();
            if path.extension().and_then(|ext| ext.to_str()) != Some("yml") {
                continue;
            }
            let yaml = fs::read_to_string(&path)?;
            let mut sidecar: MessageSidecar = serde_yaml::from_str(&yaml)?;
            if sidecar.status_shadow != "outbox" {
                continue;
            }
            let mut outbound = sidecar.outbound.take().unwrap_or_default();
            if outbound.status == OutboundStatus::Sent {
                sidecar.outbound = Some(outbound);
                continue;
            }
            if let Some(next) = &outbound.next_attempt_at
                && let Ok(next_time) = OffsetDateTime::parse(next, &Rfc3339)
                && next_time > OffsetDateTime::now_utc()
            {
                sidecar.outbound = Some(outbound);
                continue;
            }
            let message_path = outbox_dir.join(&sidecar.filename);
            if !message_path.exists() {
                self.logger.log(
                    LogLevel::Minimal,
                    "outbox.missing_eml",
                    Some(&format!("file={}", message_path.display())),
                )?;
                sidecar.outbound = Some(outbound);
                continue;
            }
            let eml = fs::read(&message_path)?;
            outbound.attempts += 1;
            let send_result = self.transport.send(&eml, &sidecar);
            match send_result {
                Ok(()) => {
                    outbound.status = OutboundStatus::Sent;
                    outbound.last_error = None;
                    outbound.next_attempt_at = None;
                    sidecar.status_shadow = "sent".to_string();
                    sidecar.touch();
                    let detail = format!("ulid={} attempts={}", sidecar.ulid, outbound.attempts);
                    self.logger
                        .log(LogLevel::Minimal, "outbox.sent", Some(&detail))?;
                    sidecar.outbound = Some(outbound);
                    self.finish_dispatch(&sidecar, &message_path, &path)?;
                    outcomes.push(DispatchResult::Sent(sidecar.ulid.clone()));
                }
                Err(err) => {
                    outbound.status = OutboundStatus::Pending;
                    outbound.last_error = Some(err.to_string());
                    let delay = next_delay(outbound.attempts, &self.retry_schedule);
                    let next_attempt = OffsetDateTime::now_utc() + delay;
                    outbound.next_attempt_at = Some(next_attempt.format(&Rfc3339)?);
                    let detail = format!(
                        "ulid={} attempts={} next={} error={}",
                        sidecar.ulid,
                        outbound.attempts,
                        outbound.next_attempt_at.as_deref().unwrap_or("unknown"),
                        err
                    );
                    self.logger
                        .log(LogLevel::Minimal, "outbox.retry", Some(&detail))?;
                    sidecar.outbound = Some(outbound);
                    let yaml = serde_yaml::to_string(&sidecar)?;
                    write_atomic(&path, yaml.as_bytes())?;
                    outcomes.push(DispatchResult::Retry(sidecar.ulid.clone()));
                }
            }
        }
        Ok(outcomes)
    }

    fn finish_dispatch(
        &self,
        sidecar: &MessageSidecar,
        message_path: &Path,
        sidecar_path: &Path,
    ) -> Result<()> {
        let sent_dir = self.layout.sent();
        fs::create_dir_all(&sent_dir)?;
        let sent_message = sent_dir.join(&sidecar.filename);
        let sent_sidecar = sent_dir.join(
            sidecar_path
                .file_name()
                .ok_or_else(|| anyhow!("sidecar missing filename"))?,
        );
        let html_path = message_path.with_file_name(&sidecar.render.html);
        if html_path.exists() {
            let dest = sent_dir.join(html_path.file_name().unwrap());
            fs::rename(&html_path, dest)?;
        }
        if let Some(plain) = &sidecar.render.plain {
            let plain_path = message_path.with_file_name(plain);
            if plain_path.exists() {
                let dest = sent_dir.join(plain_path.file_name().unwrap());
                fs::rename(&plain_path, dest)?;
            }
        }
        fs::rename(message_path, &sent_message)?;
        let yaml = serde_yaml::to_string(sidecar)?;
        write_atomic(&sent_sidecar, yaml.as_bytes())?;
        fs::remove_file(sidecar_path)?;
        Ok(())
    }
}

fn parse_retry_schedule(env: &EnvConfig) -> Vec<Duration> {
    let mut schedule = Vec::new();
    for entry in &env.retry_backoff {
        if let Some(duration) = parse_interval(entry) {
            schedule.push(duration);
        }
    }
    if schedule.is_empty() {
        schedule.push(Duration::minutes(1));
    }
    schedule
}

fn next_delay(attempts: u32, schedule: &[Duration]) -> Duration {
    if schedule.is_empty() {
        return Duration::minutes(1);
    }
    let idx = (attempts.saturating_sub(1) as usize).min(schedule.len() - 1);
    schedule[idx]
}

fn split_headers_body(formatted: &[u8]) -> Result<(String, &[u8])> {
    let marker = b"\r\n\r\n";
    let Some(pos) = formatted
        .windows(marker.len())
        .position(|window| window == marker)
    else {
        bail!("formatted message missing header/body separator");
    };
    let headers = String::from_utf8(formatted[..pos].to_vec())
        .map_err(|_| anyhow!("message headers are not valid UTF-8"))?;
    let body = &formatted[pos + marker.len()..];
    Ok((headers, body))
}

fn header_value(headers_raw: &str, name: &str) -> Option<String> {
    let header = dkim::extract_header(headers_raw, name)?;
    let mut parts = header.trim_end_matches("\r\n").splitn(2, ':');
    let _ = parts.next()?;
    let mut value = parts.next()?.trim().to_string();
    value = value.replace("\r\n ", " ").replace("\r\n\t", " ");
    Some(value)
}

fn markdown_to_html(markdown: &str) -> String {
    let mut html_output = String::new();
    let parser = Parser::new_ext(markdown, Options::all());
    html::push_html(&mut html_output, parser);
    html_output
}

fn markdown_to_text(markdown: &str) -> String {
    let mut output = String::new();
    let parser = Parser::new_ext(markdown, Options::all());
    for event in parser {
        match event {
            Event::Text(text) | Event::Code(text) => output.push_str(&text),
            Event::SoftBreak => output.push('\n'),
            Event::HardBreak => output.push_str("\n\n"),
            Event::Start(Tag::Item) => output.push_str("- "),
            Event::End(TagEnd::Item) => output.push('\n'),
            Event::End(TagEnd::Paragraph) | Event::End(TagEnd::List(_)) => {
                if !output.ends_with('\n') {
                    output.push('\n');
                }
                output.push('\n');
            }
            _ => {}
        }
    }
    output.trim().to_string()
}

#[derive(Debug, Clone)]
struct Draft {
    ulid: String,
    subject: String,
    from: Mailbox,
    to: Vec<Mailbox>,
    cc: Vec<Mailbox>,
    reply_to: Option<Mailbox>,
    body: String,
    domain: String,
}

pub trait MailTransport: Send + Sync {
    fn send(&self, message: &[u8], sidecar: &MessageSidecar) -> Result<()>;
}

pub struct SmtpRelay {
    inner: SmtpTransport,
}

impl SmtpRelay {
    pub fn from_env(env: &EnvConfig) -> Self {
        let host = env.smtp_host.as_deref().unwrap_or("127.0.0.1");
        let mut builder = if env.smtp_starttls {
            SmtpTransport::relay(host).unwrap_or_else(|_| SmtpTransport::builder_dangerous(host))
        } else {
            SmtpTransport::builder_dangerous(host)
        };
        builder = builder.port(env.smtp_port);
        if let (Some(user), Some(pass)) = (&env.smtp_username, &env.smtp_password) {
            builder = builder.credentials(Credentials::new(user.clone(), pass.clone()));
        }
        Self {
            inner: builder.build(),
        }
    }
}

impl MailTransport for SmtpRelay {
    fn send(&self, message: &[u8], sidecar: &MessageSidecar) -> Result<()> {
        let envelope = build_envelope(sidecar)?;
        self.inner
            .send_raw(&envelope, message)
            .map_err(|err| anyhow!("smtp send failed: {err}"))
            .map(|_| ())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DispatchResult {
    Sent(String),
    Retry(String),
}

impl Draft {
    fn from_file(path: &Path) -> Result<Self> {
        let stem = path
            .file_stem()
            .and_then(|s| s.to_str())
            .ok_or_else(|| anyhow!("draft filename missing stem"))?;
        Ulid::from_string(stem).map_err(|_| anyhow!("draft filename must be a ULID"))?;
        let ulid = stem.to_string();

        let contents = fs::read_to_string(path)
            .with_context(|| format!("reading draft {}", path.display()))?;
        let (front_matter, body) = split_front_matter(&contents)?;
        let meta: DraftFrontMatter = serde_yaml::from_str(&front_matter)?;
        if meta.to.is_empty() {
            bail!("draft front matter must include at least one recipient");
        }
        let DraftFrontMatter {
            subject,
            from,
            to,
            cc,
            reply_to,
        } = meta;
        let from_raw = from.ok_or_else(|| anyhow!("draft front matter missing 'from'"))?;
        let from = parse_mailbox(&from_raw)?;
        let address = from.email.to_string();
        let domain = address
            .rsplit_once('@')
            .map(|(_, domain)| domain.to_string())
            .ok_or_else(|| anyhow!("from address missing domain"))?;
        let to = parse_mailboxes(&to)?;
        let cc = parse_mailboxes(&cc)?;
        let reply_to = match reply_to {
            Some(value) => Some(parse_mailbox(&value)?),
            None => None,
        };

        Ok(Self {
            ulid,
            subject,
            from,
            to,
            cc,
            reply_to,
            body,
            domain,
        })
    }
}

fn parse_mailbox(value: &str) -> Result<Mailbox> {
    Mailbox::from_str(value).map_err(|err| anyhow!("invalid address '{value}': {err}"))
}

fn parse_mailboxes(values: &[String]) -> Result<Vec<Mailbox>> {
    values.iter().map(|value| parse_mailbox(value)).collect()
}

fn split_front_matter(contents: &str) -> Result<(String, String)> {
    let mut lines = contents.lines();
    let first = lines.next().ok_or_else(|| anyhow!("draft is empty"))?;
    if first.trim() != "---" {
        bail!("draft missing starting front matter delimiter");
    }
    let mut front = Vec::new();
    for line in &mut lines {
        if line.trim() == "---" {
            let body = lines.collect::<Vec<_>>().join("\n");
            return Ok((front.join("\n"), body));
        }
        front.push(line);
    }
    bail!("draft missing closing front matter delimiter")
}

fn build_envelope(sidecar: &MessageSidecar) -> Result<Envelope> {
    let from_mailbox = Mailbox::from_str(&sidecar.headers_cache.from)
        .map_err(|err| anyhow!("invalid from address: {err}"))?;
    let mut recipients = Vec::new();
    for entry in sidecar
        .headers_cache
        .to
        .iter()
        .chain(sidecar.headers_cache.cc.iter())
    {
        let parsed =
            Mailbox::from_str(entry).map_err(|err| anyhow!("invalid recipient {entry}: {err}"))?;
        recipients.push(parsed.email.clone());
    }
    if recipients.is_empty() {
        anyhow::bail!("no recipients available for envelope");
    }
    Envelope::new(Some(from_mailbox.email.clone()), recipients)
        .map_err(|err| anyhow!("failed to build envelope: {err}"))
}

#[derive(Debug, Clone, serde::Deserialize)]
struct DraftFrontMatter {
    subject: String,
    from: Option<String>,
    to: Vec<String>,
    #[serde(default)]
    cc: Vec<String>,
    #[serde(default)]
    reply_to: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::logging::{LogLevel, Logger};
    use std::path::Path;
    use std::sync::atomic::{AtomicUsize, Ordering};

    fn test_env() -> (tempfile::TempDir, MailLayout, EnvConfig, Logger) {
        let dir = tempfile::tempdir().unwrap();
        let layout = MailLayout::new(dir.path());
        layout.ensure().unwrap();
        let env = EnvConfig {
            retry_backoff: vec!["1s".into(), "invalid".into(), "2m".into()],
            ..EnvConfig::default()
        };
        let logger = Logger::new(layout.root(), LogLevel::Off).unwrap();
        (dir, layout, env, logger)
    }

    #[test]
    fn parse_retry_schedule_discards_invalid_entries() {
        let (_dir, _layout, env, _logger) = test_env();
        let schedule = parse_retry_schedule(&env);
        assert_eq!(schedule.len(), 2);
        assert_eq!(schedule[0], Duration::seconds(1));
    }

    #[test]
    fn parse_retry_schedule_uses_default_when_empty() {
        let env = EnvConfig {
            retry_backoff: Vec::new(),
            ..EnvConfig::default()
        };
        let schedule = parse_retry_schedule(&env);
        assert_eq!(schedule.len(), 1);
        assert_eq!(schedule[0], Duration::minutes(1));
    }

    #[test]
    fn next_delay_handles_empty_schedule() {
        let schedule = vec![Duration::seconds(1), Duration::minutes(5)];
        assert_eq!(next_delay(1, &schedule), Duration::seconds(1));
        assert_eq!(next_delay(6, &schedule), Duration::minutes(5));
        assert_eq!(next_delay(3, &[]), Duration::minutes(1));
    }

    #[test]
    fn split_headers_body_reports_missing_marker() {
        let err = split_headers_body(b"Subject: hi").unwrap_err();
        assert!(err.to_string().contains("separator"));
    }

    #[test]
    fn header_value_unfolds_continuations() {
        let headers = "Subject: Hello\r\n\tWorld\r\n";
        let value = header_value(headers, "subject").unwrap();
        assert_eq!(value, "Hello World");
    }

    #[test]
    fn markdown_to_text_formats_lists_and_breaks() {
        let text = markdown_to_text("- Item 1\n- Item 2\n\nParagraph");
        assert!(text.contains("- Item 1"));
        assert!(text.contains("- Item 2"));
        assert!(text.ends_with("Paragraph"));
    }

    #[test]
    fn markdown_to_text_handles_hard_and_soft_breaks() {
        let text = markdown_to_text("First line  \nSecond line\nThird\n\n* Nested");
        assert!(text.contains("First line"));
        assert!(text.contains("Second line"));
        assert!(text.contains("Third"));
        assert!(text.contains("- Nested"));
        assert!(text.contains("Second line\nThird"));
    }

    #[test]
    fn queue_draft_generates_signed_message() {
        let (_dir, layout, env, logger) = test_env();
        let pipeline = OutboxPipeline::new(layout.clone(), env, logger);
        let draft_ulid = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
        fs::write(
            &draft_path,
            "---\nsubject: Greetings\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\n---\nHello **world**!\n",
        )
        .unwrap();

        let message_path = pipeline.queue_draft(&draft_path).unwrap();
        assert!(message_path.exists());
        let message = fs::read_to_string(&message_path).unwrap();
        assert!(message.starts_with("DKIM-Signature:"));
        let sidecar_path = layout.outbox().join(outbox_sidecar_filename(&draft_ulid));
        let sidecar: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(sidecar_path).unwrap()).unwrap();
        assert_eq!(sidecar.filename, outbox_message_filename(&draft_ulid));
        assert_eq!(sidecar.status_shadow, "outbox");
        assert_eq!(sidecar.outbound.unwrap().attempts, 0);
        assert!(
            layout
                .outbox()
                .join(outbox_html_filename(&draft_ulid))
                .exists()
        );
    }

    #[test]
    fn queue_draft_includes_reply_to_and_cc() {
        let (_dir, layout, env, logger) = test_env();
        let pipeline = OutboxPipeline::new(layout.clone(), env, logger);
        let draft_ulid = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
        fs::write(
            &draft_path,
            "---\nsubject: Follow up\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\ncc:\n  - Carol <carol@example.org>\nreply_to: Help <help@example.org>\n---\nBody\n",
        )
        .unwrap();

        pipeline.queue_draft(&draft_path).unwrap();
        let sidecar_path = layout.outbox().join(outbox_sidecar_filename(&draft_ulid));
        let sidecar: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(sidecar_path).unwrap()).unwrap();
        assert_eq!(sidecar.headers_cache.cc.len(), 1);
        let message =
            fs::read_to_string(layout.outbox().join(outbox_message_filename(&draft_ulid))).unwrap();
        assert!(message.contains("Reply-To: Help <help@example.org>"));
    }

    #[test]
    fn dispatch_moves_successful_message() {
        let (_dir, layout, env, logger) = test_env();
        let transport = Arc::new(RecordingTransport::success());
        let pipeline = OutboxPipeline::with_transport(layout.clone(), env, logger, transport);
        let draft_ulid = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
        fs::write(
            &draft_path,
            "---\nsubject: Dispatch\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\n---\nBody\n",
        )
        .unwrap();
        pipeline.queue_draft(&draft_path).unwrap();
        let outcomes = pipeline.dispatch_pending().unwrap();
        assert!(matches!(outcomes.first(), Some(DispatchResult::Sent(_))));
        let sent_path = layout.sent().join(outbox_message_filename(&draft_ulid));
        assert!(sent_path.exists());
        assert!(
            !layout
                .outbox()
                .join(outbox_message_filename(&draft_ulid))
                .exists()
        );
    }

    #[test]
    fn dispatch_records_retry_on_failure() {
        let (_dir, layout, env, logger) = test_env();
        let transport = Arc::new(RecordingTransport::fail());
        let pipeline = OutboxPipeline::with_transport(layout.clone(), env, logger, transport);
        let draft_ulid = crate::util::ulid::generate();
        let draft_path = layout.drafts().join(format!("{draft_ulid}.md"));
        fs::write(
            &draft_path,
            "---\nsubject: Retry\nfrom: Owl <owl@example.org>\nto:\n  - Bob <bob@example.org>\n---\nBody\n",
        )
        .unwrap();
        pipeline.queue_draft(&draft_path).unwrap();
        let outcomes = pipeline.dispatch_pending().unwrap();
        assert!(matches!(outcomes.first(), Some(DispatchResult::Retry(_))));
        let sidecar_path = layout.outbox().join(outbox_sidecar_filename(&draft_ulid));
        let sidecar: MessageSidecar =
            serde_yaml::from_str(&fs::read_to_string(sidecar_path).unwrap()).unwrap();
        let outbound = sidecar.outbound.unwrap();
        assert_eq!(outbound.attempts, 1);
        assert!(outbound.last_error.unwrap().contains("forced"));
        assert!(outbound.next_attempt_at.is_some());
    }

    #[test]
    fn dispatch_pending_returns_empty_without_outbox_dir() {
        let (_dir, layout, env, logger) = test_env();
        fs::remove_dir_all(layout.outbox()).unwrap();
        let pipeline = OutboxPipeline::new(layout, env, logger);
        let outcomes = pipeline.dispatch_pending().unwrap();
        assert!(outcomes.is_empty());
    }

    #[test]
    fn dispatch_pending_skips_directories_and_non_outbox_entries() {
        let (_dir, layout, env, logger) = test_env();
        let pipeline = OutboxPipeline::new(layout.clone(), env, logger);
        let outbox_dir = layout.outbox();
        fs::create_dir_all(&outbox_dir).unwrap();
        fs::create_dir(outbox_dir.join("subdir")).unwrap();

        let mut sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FB0",
            "draft.eml",
            "draft",
            "strict",
            "draft.html",
            "deadbeef",
            HeadersCache::new("Alice", "Draft"),
        );
        sidecar.set_plain_render("draft.txt");
        let sidecar_path = outbox_dir.join("draft.yml");
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();

        let outcomes = pipeline.dispatch_pending().unwrap();
        assert!(outcomes.is_empty());
        assert!(sidecar_path.exists());
    }

    #[test]
    fn finish_dispatch_moves_related_files() {
        let (_dir, layout, mut env, logger) = test_env();
        env.render_mode = "strict".into();
        let pipeline = OutboxPipeline::new(layout.clone(), env.clone(), logger);
        let outbox_dir = layout.outbox();
        fs::create_dir_all(&outbox_dir).unwrap();
        let message_path = outbox_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.eml");
        fs::write(&message_path, b"message").unwrap();
        let html_path = outbox_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.html");
        fs::write(&html_path, b"<p>hi</p>").unwrap();
        let plain_path = outbox_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.txt");
        fs::write(&plain_path, b"hi").unwrap();
        let sidecar_path = outbox_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.yml");
        let mut sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FAV",
            "01ARZ3NDEKTSV4RRFFQ69G5FAV.eml",
            "outbox",
            &env.render_mode,
            "01ARZ3NDEKTSV4RRFFQ69G5FAV.html",
            "deadbeef",
            HeadersCache::new("Alice", "Hello"),
        );
        sidecar.set_plain_render("01ARZ3NDEKTSV4RRFFQ69G5FAV.txt");
        let yaml = serde_yaml::to_string(&sidecar).unwrap();
        write_atomic(&sidecar_path, yaml.as_bytes()).unwrap();

        pipeline
            .finish_dispatch(&sidecar, &message_path, &sidecar_path)
            .unwrap();

        let sent_dir = layout.sent();
        assert!(sent_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.eml").exists());
        assert!(sent_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.html").exists());
        assert!(sent_dir.join("01ARZ3NDEKTSV4RRFFQ69G5FAV.txt").exists());
        assert!(!sidecar_path.exists());
    }

    #[test]
    fn dispatch_skips_sent_and_future_messages() {
        let (_dir, layout, env, logger) = test_env();
        let pipeline = OutboxPipeline::new(layout.clone(), env, logger);
        let outbox_dir = layout.outbox();
        fs::create_dir_all(&outbox_dir).unwrap();
        let sent_sidecar_path = outbox_dir.join("sent.yml");
        let mut sent_sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FF0",
            "sent.eml",
            "outbox",
            "strict",
            "sent.html",
            "deadbeef",
            HeadersCache::new("Alice", "Hello"),
        );
        sent_sidecar.outbound_state_mut().status = OutboundStatus::Sent;
        let future_sidecar_path = outbox_dir.join("future.yml");
        let mut future_sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FF1",
            "future.eml",
            "outbox",
            "strict",
            "future.html",
            "feedface",
            HeadersCache::new("Bob", "Later"),
        );
        future_sidecar.outbound_state_mut().next_attempt_at = Some("2999-01-01T00:00:00Z".into());
        write_atomic(
            &sent_sidecar_path,
            serde_yaml::to_string(&sent_sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        write_atomic(
            &future_sidecar_path,
            serde_yaml::to_string(&future_sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        let outcomes = pipeline.dispatch_pending().unwrap();
        assert!(outcomes.is_empty());
    }

    #[test]
    fn dispatch_logs_missing_message_files() {
        let (_dir, layout, env, _) = test_env();
        let logger = Logger::new(layout.root(), LogLevel::Minimal).unwrap();
        let pipeline = OutboxPipeline::new(layout.clone(), env, logger.clone());
        let outbox_dir = layout.outbox();
        fs::create_dir_all(&outbox_dir).unwrap();
        let sidecar_path = outbox_dir.join("missing.yml");
        let sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FF2",
            "missing.eml",
            "outbox",
            "strict",
            "missing.html",
            "deadbeef",
            HeadersCache::new("Alice", "Hello"),
        );
        write_atomic(
            &sidecar_path,
            serde_yaml::to_string(&sidecar).unwrap().as_bytes(),
        )
        .unwrap();
        pipeline.dispatch_pending().unwrap();
        let entries = Logger::load_entries(&logger.log_path()).unwrap();
        assert!(
            entries
                .iter()
                .any(|entry| entry.message == "outbox.missing_eml")
        );
    }

    struct RecordingTransport {
        attempts: AtomicUsize,
        fail: bool,
    }

    impl RecordingTransport {
        fn success() -> Self {
            Self {
                attempts: AtomicUsize::new(0),
                fail: false,
            }
        }

        fn fail() -> Self {
            Self {
                attempts: AtomicUsize::new(0),
                fail: true,
            }
        }
    }

    impl MailTransport for RecordingTransport {
        fn send(&self, _message: &[u8], _sidecar: &MessageSidecar) -> Result<()> {
            self.attempts.fetch_add(1, Ordering::SeqCst);
            if self.fail {
                bail!("forced failure");
            }
            Ok(())
        }
    }

    #[test]
    fn smtp_relay_honours_starttls_and_credentials() {
        let env = EnvConfig {
            smtp_starttls: true,
            smtp_host: Some("smtp.example.org".into()),
            smtp_username: Some("user".into()),
            smtp_password: Some("pass".into()),
            ..EnvConfig::default()
        };
        let relay = SmtpRelay::from_env(&env);
        // Ensure the builder path executes without panic.
        let _ = format!("{:?}", relay.inner);
    }

    #[test]
    fn smtp_relay_without_starttls_uses_dangerous_builder() {
        let env = EnvConfig {
            smtp_starttls: false,
            smtp_host: Some("smtp.example.org".into()),
            ..EnvConfig::default()
        };
        let relay = SmtpRelay::from_env(&env);
        let _ = format!("{:?}", relay.inner);
    }

    #[test]
    fn draft_from_file_requires_filename_stem() {
        let err = Draft::from_file(Path::new("")).expect_err("expected missing stem failure");
        assert!(format!("{err}").contains("missing stem"));
    }

    #[test]
    fn draft_from_file_requires_ulid_filenames() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("not-a-ulid.md");
        fs::write(
            &path,
            "---\nsubject: hi\nfrom: alice@example.org\nto:\n  - bob@example.org\n---\nbody\n",
        )
        .unwrap();
        let err = Draft::from_file(&path).expect_err("expected ulid validation failure");
        assert!(format!("{err}").contains("must be a ULID"));
    }

    #[test]
    fn draft_from_file_enforces_recipients_and_from() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("01ARZ3NDEKTSV4RRFFQ69G5FAV.md");
        fs::write(&path, "---\nsubject: hi\nto: []\n---\nbody\n").unwrap();
        let err = Draft::from_file(&path).expect_err("expected recipient failure");
        assert!(
            format!("{err}").contains("must include at least one recipient"),
            "unexpected error: {err}"
        );

        fs::write(
            &path,
            "---\nsubject: hi\nto:\n  - bob@example.org\n---\nbody\n",
        )
        .unwrap();
        let err = Draft::from_file(&path).expect_err("expected missing from failure");
        assert!(format!("{err}").contains("missing 'from'"));
    }

    #[test]
    fn draft_from_file_reports_invalid_reply_to() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("01ARZ3NDEKTSV4RRFFQ69G5FAW.md");
        fs::write(
            &path,
            "---\nsubject: hi\nfrom: alice@example.org\nto:\n  - bob@example.org\nreply_to: not-an-email\n---\nbody\n",
        )
        .unwrap();
        let err = Draft::from_file(&path).expect_err("expected reply-to parsing failure");
        assert!(format!("{err}").contains("invalid address"));
    }

    #[test]
    fn split_front_matter_validates_delimiters() {
        let err = split_front_matter("subject: hi\n").expect_err("missing delimiter");
        assert!(format!("{err}").contains("starting front matter delimiter"));

        let err = split_front_matter("---\nsubject: hi\n").expect_err("missing closing delimiter");
        assert!(format!("{err}").contains("closing front matter delimiter"));
    }

    #[test]
    fn build_envelope_reports_address_errors() {
        let mut headers = HeadersCache::new("Alice <alice@example.org>", "Hello");
        headers.from = "invalid".into();
        headers.to.push("bob@example.org".into());
        let mut sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FAX",
            "message.eml",
            "outbox",
            "strict",
            "message.html",
            "deadbeef",
            headers.clone(),
        );
        let err = build_envelope(&sidecar).expect_err("expected invalid from");
        assert!(format!("{err}").contains("invalid from address"));

        headers.from = "Alice <alice@example.org>".into();
        headers.to = vec!["not-an-email".into()];
        sidecar.headers_cache = headers.clone();
        let err = build_envelope(&sidecar).expect_err("expected invalid recipient");
        assert!(format!("{err}").contains("invalid recipient"));

        headers.to.clear();
        headers.cc.clear();
        sidecar.headers_cache = headers;
        let err = build_envelope(&sidecar).expect_err("expected missing recipients");
        assert!(format!("{err}").contains("no recipients"));
    }
}
