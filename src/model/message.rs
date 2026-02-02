use serde::{Deserialize, Serialize};
use time::{OffsetDateTime, format_description::well_known::Rfc3339};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MessageSidecar {
    pub schema: u8,
    pub ulid: String,
    pub filename: String,
    pub status_shadow: String,
    pub read: bool,
    pub starred: bool,
    pub pinned: bool,
    pub hash_sha256: String,
    pub received_at: String,
    pub last_activity: String,
    pub render: RenderInfo,
    pub attachments: Vec<AttachmentMeta>,
    pub headers_cache: HeadersCache,
    #[serde(default)]
    pub history: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rspamd: Option<RspamdSummary>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub outbound: Option<OutboundState>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RenderInfo {
    pub mode: String,
    pub html: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub plain: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AttachmentMeta {
    pub sha256: String,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HeadersCache {
    pub from: String,
    pub to: Vec<String>,
    pub cc: Vec<String>,
    pub subject: String,
    pub date: String,
}

impl MessageSidecar {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        ulid: impl Into<String>,
        filename: impl Into<String>,
        status_shadow: impl Into<String>,
        mode: impl Into<String>,
        html: impl Into<String>,
        hash_sha256: impl Into<String>,
        headers: HeadersCache,
    ) -> Self {
        let now = OffsetDateTime::now_utc().format(&Rfc3339).expect("rfc3339");
        Self {
            schema: 1,
            ulid: ulid.into(),
            filename: filename.into(),
            status_shadow: status_shadow.into(),
            read: false,
            starred: false,
            pinned: false,
            hash_sha256: hash_sha256.into(),
            received_at: now.clone(),
            last_activity: now,
            render: RenderInfo {
                mode: mode.into(),
                html: html.into(),
                plain: None,
            },
            attachments: Vec::new(),
            headers_cache: headers,
            history: Vec::new(),
            rspamd: None,
            outbound: None,
        }
    }

    pub fn add_attachment(&mut self, sha256: impl Into<String>, name: impl Into<String>) {
        self.attachments.push(AttachmentMeta {
            sha256: sha256.into(),
            name: name.into(),
        });
    }

    pub fn set_plain_render(&mut self, plain: impl Into<String>) {
        self.render.plain = Some(plain.into());
    }

    pub fn set_rspamd(&mut self, summary: RspamdSummary) {
        self.rspamd = Some(summary);
    }

    pub fn outbound_state_mut(&mut self) -> &mut OutboundState {
        if self.outbound.is_none() {
            self.outbound = Some(OutboundState::default());
        }
        self.outbound.as_mut().expect("outbound state to exist")
    }

    pub fn mark_read(&mut self) {
        self.read = true;
        self.touch();
    }

    pub fn touch(&mut self) {
        self.last_activity = OffsetDateTime::now_utc().format(&Rfc3339).expect("rfc3339");
    }
}

impl HeadersCache {
    pub fn new(from: impl Into<String>, subject: impl Into<String>) -> Self {
        Self {
            from: from.into(),
            to: Vec::new(),
            cc: Vec::new(),
            subject: subject.into(),
            date: OffsetDateTime::now_utc().format(&Rfc3339).expect("rfc3339"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
pub struct RspamdSummary {
    pub score: f32,
    #[serde(default)]
    pub symbols: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OutboundState {
    pub status: OutboundStatus,
    pub attempts: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub next_attempt_at: Option<String>,
}

impl Default for OutboundState {
    fn default() -> Self {
        Self {
            status: OutboundStatus::Pending,
            attempts: 0,
            last_error: None,
            next_attempt_at: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum OutboundStatus {
    Pending,
    Sent,
    Failed,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_yaml() {
        let headers = HeadersCache::new("Alice", "Hello");
        let mut sidecar = MessageSidecar::new(
            "01ABC",
            "Subject (01ABC).eml",
            "accepted",
            "strict",
            ".Subject.html",
            "deadbeef",
            headers,
        );
        sidecar.add_attachment("aa", "file.pdf");
        sidecar.mark_read();
        sidecar.set_plain_render(".Subject.txt");
        let outbound = sidecar.outbound_state_mut();
        outbound.attempts = 2;
        outbound.status = OutboundStatus::Sent;
        let yaml = serde_yaml::to_string(&sidecar).unwrap();
        let parsed: MessageSidecar = serde_yaml::from_str(&yaml).unwrap();
        assert_eq!(parsed.attachments.len(), 1);
        assert!(parsed.read);
        assert_eq!(parsed.render.plain.as_deref(), Some(".Subject.txt"));
        assert_eq!(parsed.outbound.unwrap().attempts, 2);
    }

    #[test]
    fn sidecar_defaults_flags_to_false() {
        // Per spec: read, starred, pinned default to false
        let headers = HeadersCache::new("Alice", "Test");
        let sidecar = MessageSidecar::new(
            "01XYZ",
            "test.eml",
            "quarantine",
            "strict",
            "test.html",
            "hash",
            headers,
        );
        assert!(!sidecar.read);
        assert!(!sidecar.starred);
        assert!(!sidecar.pinned);
    }

    #[test]
    fn sidecar_render_mode_variations() {
        // Per spec: render.mode can be strict or moderate
        let headers = HeadersCache::new("Test", "Subject");
        let strict = MessageSidecar::new(
            "01A",
            "a.eml",
            "accepted",
            "strict",
            "a.html",
            "h1",
            headers.clone(),
        );
        assert_eq!(strict.render.mode, "strict");

        let moderate =
            MessageSidecar::new("01B", "b.eml", "spam", "moderate", "b.html", "h2", headers);
        assert_eq!(moderate.render.mode, "moderate");
    }

    #[test]
    fn sidecar_status_shadow_variations() {
        // Per spec: status_shadow tracks message list (accepted, spam, banned, quarantine)
        let headers = HeadersCache::new("Test", "Subject");

        let accepted = MessageSidecar::new(
            "01A",
            "a.eml",
            "accepted",
            "strict",
            "a.html",
            "h1",
            headers.clone(),
        );
        assert_eq!(accepted.status_shadow, "accepted");

        let spam = MessageSidecar::new(
            "01B",
            "b.eml",
            "spam",
            "strict",
            "b.html",
            "h2",
            headers.clone(),
        );
        assert_eq!(spam.status_shadow, "spam");

        let banned = MessageSidecar::new(
            "01C",
            "c.eml",
            "banned",
            "strict",
            "c.html",
            "h3",
            headers.clone(),
        );
        assert_eq!(banned.status_shadow, "banned");

        let quarantine = MessageSidecar::new(
            "01D",
            "d.eml",
            "quarantine",
            "strict",
            "d.html",
            "h4",
            headers,
        );
        assert_eq!(quarantine.status_shadow, "quarantine");
    }

    #[test]
    fn sidecar_attachments_content_addressed() {
        // Per spec: attachments stored as sha256__<orig-name>
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        sidecar.add_attachment("abc123def456", "invoice.pdf");
        sidecar.add_attachment("789xyz012", "receipt.png");

        assert_eq!(sidecar.attachments.len(), 2);
        assert_eq!(sidecar.attachments[0].sha256, "abc123def456");
        assert_eq!(sidecar.attachments[0].name, "invoice.pdf");
        assert_eq!(sidecar.attachments[1].sha256, "789xyz012");
        assert_eq!(sidecar.attachments[1].name, "receipt.png");
    }

    #[test]
    fn sidecar_touch_updates_last_activity() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        let original_activity = sidecar.last_activity.clone();
        std::thread::sleep(std::time::Duration::from_millis(10));
        sidecar.touch();

        assert_ne!(sidecar.last_activity, original_activity);
    }

    #[test]
    fn sidecar_mark_read_sets_flag_and_touches() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        assert!(!sidecar.read);
        let original_activity = sidecar.last_activity.clone();
        std::thread::sleep(std::time::Duration::from_millis(10));
        sidecar.mark_read();

        assert!(sidecar.read);
        assert_ne!(sidecar.last_activity, original_activity);
    }

    #[test]
    fn outbound_state_defaults() {
        // Per spec: outbound messages start pending with 0 attempts
        let state = OutboundState::default();
        assert!(matches!(state.status, OutboundStatus::Pending));
        assert_eq!(state.attempts, 0);
        assert!(state.last_error.is_none());
        assert!(state.next_attempt_at.is_none());
    }

    #[test]
    fn rspamd_summary_in_quarantine() {
        // Per spec: Rspamd scores displayed in Quarantine
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A",
            "a.eml",
            "quarantine",
            "strict",
            "a.html",
            "h1",
            headers,
        );

        sidecar.set_rspamd(RspamdSummary {
            score: 7.5,
            symbols: vec!["DKIM_REJECT".to_string(), "SPF_FAIL".to_string()],
        });

        assert!(sidecar.rspamd.is_some());
        let rspamd = sidecar.rspamd.unwrap();
        assert_eq!(rspamd.score, 7.5);
        assert_eq!(rspamd.symbols.len(), 2);
    }

    #[test]
    fn sidecar_schema_version() {
        let headers = HeadersCache::new("Test", "Subject");
        let sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        // Per spec: schema version is 1
        assert_eq!(sidecar.schema, 1);
    }

    #[test]
    fn sidecar_serialization_roundtrip() {
        let headers = HeadersCache::new("Alice <alice@example.org>", "Test Subject");
        let mut sidecar = MessageSidecar::new(
            "01ARZ3NDEKTSV4RRFFQ69G5FAV",
            "msg.eml",
            "accepted",
            "strict",
            "msg.html",
            "abc123",
            headers,
        );
        sidecar.add_attachment("def456", "invoice.pdf");
        sidecar.starred = true;

        let yaml = serde_yaml::to_string(&sidecar).unwrap();
        let deserialized: MessageSidecar = serde_yaml::from_str(&yaml).unwrap();

        assert_eq!(deserialized.ulid, sidecar.ulid);
        assert_eq!(deserialized.starred, sidecar.starred);
        assert_eq!(deserialized.attachments.len(), 1);
    }

    #[test]
    fn sidecar_with_multiple_attachments() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        sidecar.add_attachment("hash1", "file1.txt");
        sidecar.add_attachment("hash2", "file2.pdf");
        sidecar.add_attachment("hash3", "file3.jpg");

        assert_eq!(sidecar.attachments.len(), 3);
        assert_eq!(sidecar.attachments[0].sha256, "hash1");
        assert_eq!(sidecar.attachments[1].name, "file2.pdf");
    }

    #[test]
    fn headers_cache_with_multiple_recipients() {
        let mut headers = HeadersCache::new("Alice <alice@example.org>", "Multi To");
        headers.to.push("bob@example.org".to_string());
        headers.to.push("carol@example.org".to_string());
        headers.cc.push("dave@example.org".to_string());

        assert_eq!(headers.to.len(), 2);
        assert_eq!(headers.cc.len(), 1);
    }

    #[test]
    fn sidecar_toggle_flags() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        // Initially all false
        assert!(!sidecar.read);
        assert!(!sidecar.starred);
        assert!(!sidecar.pinned);

        // Toggle them
        sidecar.mark_read();
        sidecar.starred = true;
        sidecar.pinned = true;

        assert!(sidecar.read);
        assert!(sidecar.starred);
        assert!(sidecar.pinned);
    }

    #[test]
    fn sidecar_timestamp_format() {
        let headers = HeadersCache::new("Test", "Subject");
        let sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        // Timestamps should be RFC3339 format
        assert!(OffsetDateTime::parse(&sidecar.received_at, &Rfc3339).is_ok());
        assert!(OffsetDateTime::parse(&sidecar.last_activity, &Rfc3339).is_ok());
    }

    #[test]
    fn sidecar_render_info_with_plain() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        // Initially no plain text
        assert!(sidecar.render.plain.is_none());

        // Add plain text
        sidecar.render.plain = Some("plain.txt".to_string());
        assert_eq!(sidecar.render.plain, Some("plain.txt".to_string()));
    }

    #[test]
    fn sidecar_history_appends() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        // Initially empty
        assert!(sidecar.history.is_empty());

        // Add entries
        sidecar.history.push("moved from quarantine".to_string());
        sidecar.history.push("marked as read".to_string());

        assert_eq!(sidecar.history.len(), 2);
    }

    #[test]
    fn outbound_state_with_error() {
        let state = OutboundState {
            attempts: 3,
            last_error: Some("SMTP connection failed".to_string()),
            next_attempt_at: Some("2026-02-02T12:00:00Z".to_string()),
            ..Default::default()
        };

        assert_eq!(state.attempts, 3);
        assert!(state.last_error.is_some());
        assert!(state.next_attempt_at.is_some());
    }

    #[test]
    fn attachment_meta_format() {
        let attachment = AttachmentMeta {
            sha256: "a".repeat(64), // SHA256 is 64 hex chars
            name: "document.pdf".to_string(),
        };

        // Per spec: attachments are content-addressed with sha256
        assert_eq!(attachment.sha256.len(), 64);
        assert_eq!(attachment.name, "document.pdf");
    }

    #[test]
    fn outbound_status_all_variants() {
        // Per spec: OutboundStatus has Pending, Sent, Failed
        let pending = OutboundStatus::Pending;
        let sent = OutboundStatus::Sent;
        let failed = OutboundStatus::Failed;

        // Verify all variants exist
        assert!(matches!(pending, OutboundStatus::Pending));
        assert!(matches!(sent, OutboundStatus::Sent));
        assert!(matches!(failed, OutboundStatus::Failed));
    }

    #[test]
    fn render_mode_strict_and_moderate() {
        // Per spec: render.mode can be "strict" or "moderate"
        let headers = HeadersCache::new("Test", "Subject");
        let strict = MessageSidecar::new(
            "01A",
            "a.eml",
            "accepted",
            "strict",
            "a.html",
            "h1",
            headers.clone(),
        );
        assert_eq!(strict.render.mode, "strict");

        let moderate = MessageSidecar::new(
            "01B", "b.eml", "accepted", "moderate", "b.html", "h2", headers,
        );
        assert_eq!(moderate.render.mode, "moderate");
    }

    #[test]
    fn sidecar_yaml_serialization_with_optional_fields() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new(
            "01A",
            "a.eml",
            "quarantine",
            "strict",
            "a.html",
            "h1",
            headers,
        );

        // Add optional fields
        sidecar.set_rspamd(RspamdSummary {
            score: 5.2,
            symbols: vec!["SPF_FAIL".to_string(), "DKIM_REJECT".to_string()],
        });
        sidecar.history.push("quarantined".to_string());

        // Serialize to YAML
        let yaml = serde_yaml::to_string(&sidecar).unwrap();

        // Should contain rspamd and history
        assert!(yaml.contains("rspamd"));
        assert!(yaml.contains("score: 5.2"));
        assert!(yaml.contains("SPF_FAIL"));
        assert!(yaml.contains("history"));
        assert!(yaml.contains("quarantined"));
    }

    #[test]
    fn sidecar_yaml_omits_none_optional_fields() {
        let headers = HeadersCache::new("Test", "Subject");
        let sidecar = MessageSidecar::new(
            "01A", "a.eml", "accepted", "strict", "a.html", "h1", headers,
        );

        // Serialize to YAML
        let yaml = serde_yaml::to_string(&sidecar).unwrap();

        // Should NOT contain rspamd or outbound since they're None
        assert!(!yaml.contains("rspamd:"));
        assert!(!yaml.contains("outbound:"));
    }

    #[test]
    fn rspamd_summary_empty_symbols() {
        let rspamd = RspamdSummary {
            score: 0.0,
            symbols: vec![],
        };

        assert_eq!(rspamd.score, 0.0);
        assert!(rspamd.symbols.is_empty());
    }

    #[test]
    fn rspamd_summary_with_multiple_symbols() {
        let rspamd = RspamdSummary {
            score: 15.5,
            symbols: vec![
                "RCVD_IN_DNSWL_NONE".to_string(),
                "DKIM_SIGNED".to_string(),
                "SPF_PASS".to_string(),
            ],
        };

        assert_eq!(rspamd.score, 15.5);
        assert_eq!(rspamd.symbols.len(), 3);
        assert!(rspamd.symbols.contains(&"SPF_PASS".to_string()));
    }

    #[test]
    fn outbound_state_status_transitions() {
        // Test typical status lifecycle: Pending -> Sent
        let mut state = OutboundState::default();
        assert!(matches!(state.status, OutboundStatus::Pending));

        state.status = OutboundStatus::Sent;
        assert!(matches!(state.status, OutboundStatus::Sent));

        // Or: Pending -> Failed
        state.status = OutboundStatus::Failed;
        assert!(matches!(state.status, OutboundStatus::Failed));
    }

    #[test]
    fn headers_cache_date_format() {
        let headers = HeadersCache::new("Alice <alice@example.org>", "Test");

        // date field should be populated with current time in RFC3339 format
        assert!(!headers.date.is_empty());
        assert!(OffsetDateTime::parse(&headers.date, &Rfc3339).is_ok());

        // Can update it to a specific RFC 2822 format
        let mut headers2 = headers.clone();
        headers2.date = "Tue, 16 Sep 2025 23:12:33 -0700".to_string();
        assert!(headers2.date.contains("2025"));
    }

    #[test]
    fn status_shadow_all_list_types() {
        // Per spec: status_shadow can be accepted, spam, banned, quarantine
        let headers = HeadersCache::new("Test", "Subject");

        let accepted = MessageSidecar::new(
            "01A",
            "a.eml",
            "accepted",
            "strict",
            "a.html",
            "h1",
            headers.clone(),
        );
        assert_eq!(accepted.status_shadow, "accepted");

        let spam = MessageSidecar::new(
            "01B",
            "b.eml",
            "spam",
            "strict",
            "b.html",
            "h2",
            headers.clone(),
        );
        assert_eq!(spam.status_shadow, "spam");

        let banned = MessageSidecar::new(
            "01C",
            "c.eml",
            "banned",
            "strict",
            "c.html",
            "h3",
            headers.clone(),
        );
        assert_eq!(banned.status_shadow, "banned");

        let quarantine = MessageSidecar::new(
            "01D",
            "d.eml",
            "quarantine",
            "strict",
            "d.html",
            "h4",
            headers,
        );
        assert_eq!(quarantine.status_shadow, "quarantine");
    }
}
