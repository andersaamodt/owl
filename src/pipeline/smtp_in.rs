use std::path::{Path, PathBuf};

use anyhow::{Result, anyhow, bail};
use mailparse::{DispositionType, ParsedMail, parse_mail};
use sha2::{Digest, Sha256};

use crate::{
    envcfg::EnvConfig,
    fsops::{attach::AttachmentStore, io_atom::write_atomic, layout::MailLayout},
    model::{
        address::Address,
        filename::{html_filename, message_filename, sidecar_filename},
        message::{HeadersCache, MessageSidecar, RspamdSummary},
    },
    pipeline::render::{render_plaintext, sanitize_html},
    ruleset::eval::Route,
    util::{size::parse_size, ulid},
};

pub struct InboundPipeline {
    layout: MailLayout,
    env: EnvConfig,
    approved_limit: u64,
    quarantine_limit: u64,
}

impl InboundPipeline {
    pub fn new(layout: MailLayout, env: EnvConfig) -> Result<Self> {
        let approved_limit = parse_size(&env.max_size_approved_default)?;
        let quarantine_limit = parse_size(&env.max_size_quarantine)?;
        Ok(Self {
            layout,
            env,
            approved_limit,
            quarantine_limit,
        })
    }

    pub fn deliver_quarantine(
        &self,
        sender: &Address,
        subject: &str,
        body: &[u8],
    ) -> Result<PathBuf> {
        self.ensure_within_limit(
            body.len(),
            self.quarantine_limit,
            "quarantine",
            &self.env.max_size_quarantine,
        )?;
        self.deliver_to_dir(
            &self.layout.quarantine(),
            "quarantine",
            None,
            sender,
            subject,
            body,
        )
    }

    pub fn deliver_to_route(
        &self,
        route: Route,
        sender: &Address,
        subject: &str,
        body: &[u8],
    ) -> Result<PathBuf> {
        match route {
            Route::Accepted => {
                self.ensure_within_limit(
                    body.len(),
                    self.approved_limit,
                    "accepted",
                    &self.env.max_size_approved_default,
                )?;
                self.deliver_to_dir(
                    &self.layout.accepted(),
                    "accepted",
                    Some("accepted"),
                    sender,
                    subject,
                    body,
                )
            }
            Route::Spam => {
                self.ensure_within_limit(
                    body.len(),
                    self.approved_limit,
                    "spam",
                    &self.env.max_size_approved_default,
                )?;
                self.deliver_to_dir(
                    &self.layout.spam(),
                    "spam",
                    Some("spam"),
                    sender,
                    subject,
                    body,
                )
            }
            Route::Banned => {
                self.ensure_within_limit(
                    body.len(),
                    self.approved_limit,
                    "banned",
                    &self.env.max_size_approved_default,
                )?;
                self.deliver_to_dir(
                    &self.layout.banned(),
                    "banned",
                    Some("banned"),
                    sender,
                    subject,
                    body,
                )
            }
            Route::Quarantine => self.deliver_quarantine(sender, subject, body),
        }
    }

    fn deliver_to_dir(
        &self,
        base: &Path,
        status: &str,
        attachments_list: Option<&str>,
        sender: &Address,
        subject: &str,
        body: &[u8],
    ) -> Result<PathBuf> {
        std::fs::create_dir_all(base)?;
        let dir = base.join(sender.canonical());
        std::fs::create_dir_all(&dir)?;
        let ulid = ulid::generate();
        let message_name = message_filename(subject, &ulid);
        let sidecar_name = sidecar_filename(subject, &ulid);
        let html_name = html_filename(subject, &ulid);
        let message_path = dir.join(&message_name);
        write_atomic(&message_path, body)?;

        let mut hasher = Sha256::new();
        hasher.update(body);
        let hash = hex::encode(hasher.finalize());

        let ParsedEmail {
            html_body,
            text_body,
            attachments,
            rspamd,
        } = parse_email(body)?;
        let text_for_plain = text_body.clone();
        let html_input = html_body
            .or_else(|| text_body.clone().map(|text| plaintext_to_html(&text)))
            .unwrap_or_else(|| "<pre></pre>".to_string());
        let sanitized_html = sanitize_html(&html_input)?;
        let plain_render = render_plaintext(&sanitized_html)
            .unwrap_or_else(|_| text_for_plain.unwrap_or_default());

        let headers = HeadersCache::new(sender.to_string(), subject.to_string());
        let mut sidecar = MessageSidecar::new(
            ulid,
            message_name.clone(),
            status,
            self.env.render_mode.clone(),
            html_name.clone(),
            hash,
            headers,
        );
        if let Some(summary) = rspamd {
            sidecar.set_rspamd(summary);
        }
        let txt_name = format!(
            ".{}",
            html_name.trim_start_matches('.').replace(".html", ".txt")
        );
        sidecar.set_plain_render(txt_name.clone());
        if let Some(list) = attachments_list {
            let store = AttachmentStore::new(self.layout.attachments(list));
            for attachment in attachments {
                let stored = store.store(&attachment.name, &attachment.data)?;
                sidecar.add_attachment(stored.sha256, attachment.name);
            }
        }
        let yaml = serde_yaml::to_string(&sidecar)?;
        write_atomic(&dir.join(&sidecar_name), yaml.as_bytes())?;
        write_atomic(&dir.join(&html_name), sanitized_html.as_bytes())?;
        write_atomic(&dir.join(&txt_name), plain_render.as_bytes())?;
        Ok(message_path)
    }

    fn ensure_within_limit(
        &self,
        length: usize,
        limit: u64,
        label: &str,
        configured: &str,
    ) -> Result<()> {
        let size = length as u64;
        if size > limit {
            bail!("message size {size} bytes exceeds {label} limit ({configured})");
        }
        Ok(())
    }
}

#[derive(Default)]
struct ParsedEmail {
    html_body: Option<String>,
    text_body: Option<String>,
    attachments: Vec<EmailAttachment>,
    rspamd: Option<RspamdSummary>,
}

struct EmailAttachment {
    name: String,
    data: Vec<u8>,
}

fn parse_email(body: &[u8]) -> Result<ParsedEmail> {
    let parsed = parse_mail(body).map_err(|err| anyhow!(err.to_string()))?;
    let mut result = ParsedEmail {
        rspamd: extract_rspamd(&parsed),
        ..ParsedEmail::default()
    };
    collect_parts(&parsed, &mut result)?;
    Ok(result)
}

fn collect_parts(part: &ParsedMail, acc: &mut ParsedEmail) -> Result<()> {
    if !part.subparts.is_empty() {
        for sub in &part.subparts {
            collect_parts(sub, acc)?;
        }
        return Ok(());
    }

    let ctype = part.ctype.mimetype.to_ascii_lowercase();
    if ctype == "text/html" && acc.html_body.is_none() {
        let body = part.get_body().map_err(|err| anyhow!(err.to_string()))?;
        acc.html_body = Some(body);
    }
    if ctype == "text/plain" && acc.text_body.is_none() {
        let body = part.get_body().map_err(|err| anyhow!(err.to_string()))?;
        acc.text_body = Some(body);
    }

    let disposition = part.get_content_disposition();
    let mut filename = disposition.params.get("filename").cloned();
    if filename.is_none()
        && let Some(name) = part.ctype.params.get("name")
    {
        filename = Some(name.clone());
    }
    if let Some(name) = filename {
        let is_text = ctype.starts_with("text/");
        let treat_as_attachment = matches!(disposition.disposition, DispositionType::Attachment)
            || (!is_text
                && matches!(
                    disposition.disposition,
                    DispositionType::Inline | DispositionType::Extension(_)
                ));
        if treat_as_attachment {
            let data = part
                .get_body_raw()
                .map_err(|err| anyhow!(err.to_string()))?;
            acc.attachments.push(EmailAttachment { name, data });
        }
    }

    Ok(())
}

fn plaintext_to_html(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());
    for ch in text.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            '\r' => {}
            '\n' => escaped.push('\n'),
            _ => escaped.push(ch),
        }
    }
    format!("<pre>{}</pre>", escaped)
}

fn extract_rspamd(parsed: &ParsedMail) -> Option<RspamdSummary> {
    let mut score = None;
    let mut symbols = Vec::new();
    for header in &parsed.headers {
        let key = header.get_key_ref();
        if key.eq_ignore_ascii_case("X-Spam-Score") || key.eq_ignore_ascii_case("X-Rspamd-Score") {
            let value = header.get_value();
            score = value.trim().parse::<f32>().ok();
        }
        if key.eq_ignore_ascii_case("X-Spam-Symbols") || key.eq_ignore_ascii_case("X-Rspamd-Report")
        {
            let value = header.get_value();
            symbols = value
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect();
        }
    }
    score.map(|score| RspamdSummary { score, symbols })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ruleset::eval::Route;
    use serial_test::serial;
    use sha2::{Digest, Sha256};
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::panic;

    fn with_fake_sanitizer<T>(script_body: &str, f: impl FnOnce() -> T) -> T {
        let script_dir = tempfile::tempdir().unwrap();
        let script_path = script_dir.path().join("sanitize-html");
        fs::write(&script_path, script_body).unwrap();
        let mut perms = fs::metadata(&script_path).unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&script_path, perms).unwrap();

        let original = std::env::var_os("PATH");
        let mut new_path = std::ffi::OsString::from(script_dir.path());
        if let Some(ref orig) = original {
            new_path.push(":");
            new_path.push(orig);
        }
        unsafe { std::env::set_var("PATH", &new_path) };
        let result = panic::catch_unwind(panic::AssertUnwindSafe(f));
        match original {
            Some(orig) => unsafe { std::env::set_var("PATH", orig) },
            None => unsafe { std::env::remove_var("PATH") },
        }
        match result {
            Ok(value) => value,
            Err(err) => panic::resume_unwind(err),
        }
    }

    fn plain_message(body: &str) -> Vec<u8> {
        format!(
            "Subject: Test\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n{}",
            body
        )
        .into_bytes()
    }

    #[test]
    #[serial]
    fn deliver_writes_files() {
        with_fake_sanitizer("#!/bin/sh\ncat\n", || {
            let dir = tempfile::tempdir().unwrap();
            let layout = MailLayout::new(dir.path());
            let env = EnvConfig::default();
            let pipeline = InboundPipeline::new(layout.clone(), env).unwrap();
            let sender = Address::parse("alice@example.org", false).unwrap();
            let body = plain_message("line1 & <test> \"quote\"\nline2's");
            let path = pipeline
                .deliver_quarantine(&sender, "Hello", &body)
                .unwrap();
            assert!(path.exists());
            let stem = path.file_stem().unwrap().to_string_lossy();
            let html_path = path.with_file_name(format!(".{stem}.html"));
            assert!(html_path.exists());
            let html = std::fs::read_to_string(&html_path).unwrap();
            assert!(html.contains("line1"));
            assert!(html.contains("&amp;"));
            assert!(html.contains("&lt;test&gt;"));
            assert!(html.contains("&quot;quote&quot;"));
            assert!(html.contains("line2"));
            assert!(html.contains("&#39;s"));
            let sidecar: MessageSidecar = serde_yaml::from_str(
                &std::fs::read_to_string(path.with_file_name(format!(".{stem}.yml"))).unwrap(),
            )
            .unwrap();
            assert!(sidecar.attachments.is_empty());
            let plain_path = path.with_file_name(format!(".{stem}.txt"));
            assert!(plain_path.exists());
            assert_eq!(sidecar.render.plain.unwrap(), format!(".{stem}.txt"));
        });
    }

    #[test]
    #[serial]
    fn deliver_to_route_sets_status_and_path() {
        with_fake_sanitizer("#!/bin/sh\nsed 's/<script/[blocked]/g'\n", || {
            let dir = tempfile::tempdir().unwrap();
            let layout = MailLayout::new(dir.path());
            let env = EnvConfig::default();
            let pipeline = InboundPipeline::new(layout.clone(), env).unwrap();
            let sender = Address::parse("carol@example.org", false).unwrap();
            let accepted_body = b"Subject: Hi\r\nX-Spam-Score: 0.0\r\nX-Spam-Symbols: BAYES_GOOD\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=BOUND\r\n\r\n--BOUND\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<html><body>Hello<script>alert(1)</script></body></html>\r\n--BOUND\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"note.txt\"\r\nContent-Transfer-Encoding: base64\r\n\r\nSGVsbG8=\r\n--BOUND--\r\n";
            let path = pipeline
                .deliver_to_route(Route::Accepted, &sender, "Greetings", accepted_body)
                .unwrap();
            assert!(path.starts_with(dir.path().join("accepted")));
            let stem = path.file_stem().unwrap().to_string_lossy();
            let sidecar_path = path.with_file_name(format!(".{stem}.yml"));
            let yaml = std::fs::read_to_string(&sidecar_path).unwrap();
            let sidecar: MessageSidecar = serde_yaml::from_str(&yaml).unwrap();
            assert_eq!(sidecar.status_shadow, "accepted");
            assert_eq!(sidecar.render.html, format!(".{stem}.html"));
            let expected_plain = format!(".{stem}.txt");
            assert_eq!(
                sidecar.render.plain.as_deref(),
                Some(expected_plain.as_str())
            );
            assert_eq!(sidecar.attachments.len(), 1);
            assert_eq!(sidecar.attachments[0].name, "note.txt");
            let rspamd = sidecar.rspamd.expect("rspamd metadata");
            assert!(rspamd.score.abs() < 0.0001);
            assert_eq!(rspamd.symbols, vec!["BAYES_GOOD".to_string()]);
            let html_path = path.with_file_name(format!(".{stem}.html"));
            let html = std::fs::read_to_string(&html_path).unwrap();
            assert!(html.contains("[blocked]"));
            let mut digest = Sha256::new();
            digest.update(accepted_body);
            assert_eq!(sidecar.hash_sha256, hex::encode(digest.finalize()));

            let attachments_dir = layout.attachments("accepted");
            let mut entries = std::fs::read_dir(&attachments_dir).unwrap();
            let stored = entries.next().unwrap().unwrap();
            let stored_name = stored.file_name().into_string().unwrap();
            assert!(stored_name.ends_with("__note.txt"));
            assert!(stored_name.starts_with(&sidecar.attachments[0].sha256));

            let spam_body = plain_message("spam");
            let spam_path = pipeline
                .deliver_to_route(Route::Spam, &sender, "Spam", &spam_body)
                .unwrap();
            assert!(spam_path.starts_with(dir.path().join("spam")));
            let banned_body = plain_message("banned");
            let banned_path = pipeline
                .deliver_to_route(Route::Banned, &sender, "Banned", &banned_body)
                .unwrap();
            assert!(banned_path.starts_with(dir.path().join("banned")));

            let quarantine_body = plain_message("quarantine");
            let quarantine_path = pipeline
                .deliver_to_route(Route::Quarantine, &sender, "Quarantine", &quarantine_body)
                .unwrap();
            assert!(quarantine_path.starts_with(dir.path().join("quarantine")));

            let inline_body = b"Subject: Inline\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=BOUND2\r\n\r\n--BOUND2\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nbody\r\n--BOUND2\r\nContent-Type: image/png\r\nContent-Disposition: inline; filename=\"logo.png\"\r\nContent-Transfer-Encoding: base64\r\n\r\naGVsbG8=\r\n--BOUND2\r\nContent-Type: application/octet-stream; name=\"report.pdf\"\r\nContent-Disposition: attachment\r\nContent-Transfer-Encoding: base64\r\n\r\nc29tZQ==\r\n--BOUND2--\r\n";
            let inline_path = pipeline
                .deliver_to_route(Route::Accepted, &sender, "Inline", inline_body)
                .unwrap();
            let inline_stem = inline_path.file_stem().unwrap().to_string_lossy();
            let inline_sidecar_path = inline_path.with_file_name(format!(".{inline_stem}.yml"));
            let inline_sidecar: MessageSidecar =
                serde_yaml::from_str(&std::fs::read_to_string(&inline_sidecar_path).unwrap())
                    .unwrap();
            assert!(
                inline_sidecar
                    .attachments
                    .iter()
                    .any(|a| a.name == "logo.png")
            );
            assert!(
                inline_sidecar
                    .attachments
                    .iter()
                    .any(|a| a.name == "report.pdf")
            );
            let attachment_names: Vec<String> = std::fs::read_dir(layout.attachments("accepted"))
                .unwrap()
                .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
                .collect();
            assert!(
                attachment_names
                    .iter()
                    .any(|name| name.ends_with("__logo.png"))
            );
            assert!(
                attachment_names
                    .iter()
                    .any(|name| name.ends_with("__report.pdf"))
            );
        });
    }

    #[test]
    #[serial]
    fn quarantine_limit_enforced() {
        with_fake_sanitizer("#!/bin/sh\ncat\n", || {
            let dir = tempfile::tempdir().unwrap();
            let layout = MailLayout::new(dir.path());
            let env = EnvConfig {
                max_size_quarantine: "16".into(),
                ..EnvConfig::default()
            };
            let pipeline = InboundPipeline::new(layout, env).unwrap();
            let sender = Address::parse("dave@example.org", false).unwrap();
            let mut body = plain_message(&"A".repeat(32));
            body.extend_from_slice(&[b'X'; 64]);
            let err = pipeline
                .deliver_quarantine(&sender, "Big", &body)
                .unwrap_err();
            assert!(err.to_string().contains("limit"));
        });
    }

    #[test]
    #[serial]
    fn approved_limit_enforced() {
        with_fake_sanitizer("#!/bin/sh\ncat\n", || {
            let dir = tempfile::tempdir().unwrap();
            let layout = MailLayout::new(dir.path());
            let env = EnvConfig {
                max_size_approved_default: "32".into(),
                ..EnvConfig::default()
            };
            let pipeline = InboundPipeline::new(layout, env).unwrap();
            let sender = Address::parse("erin@example.org", false).unwrap();
            let mut body = plain_message(&"B".repeat(64));
            body.extend_from_slice(&[b'Y'; 64]);
            let err = pipeline
                .deliver_to_route(Route::Accepted, &sender, "Big", &body)
                .unwrap_err();
            assert!(err.to_string().contains("limit"));
        });
    }
}
