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
        
        let moderate = MessageSidecar::new(
            "01B",
            "b.eml",
            "spam",
            "moderate",
            "b.html",
            "h2",
            headers,
        );
        assert_eq!(moderate.render.mode, "moderate");
    }

    #[test]
    fn sidecar_status_shadow_variations() {
        // Per spec: status_shadow tracks message list (accepted, spam, banned, quarantine)
        let headers = HeadersCache::new("Test", "Subject");
        
        let accepted = MessageSidecar::new("01A", "a.eml", "accepted", "strict", "a.html", "h1", headers.clone());
        assert_eq!(accepted.status_shadow, "accepted");
        
        let spam = MessageSidecar::new("01B", "b.eml", "spam", "strict", "b.html", "h2", headers.clone());
        assert_eq!(spam.status_shadow, "spam");
        
        let banned = MessageSidecar::new("01C", "c.eml", "banned", "strict", "c.html", "h3", headers.clone());
        assert_eq!(banned.status_shadow, "banned");
        
        let quarantine = MessageSidecar::new("01D", "d.eml", "quarantine", "strict", "d.html", "h4", headers);
        assert_eq!(quarantine.status_shadow, "quarantine");
    }

    #[test]
    fn sidecar_attachments_content_addressed() {
        // Per spec: attachments stored as sha256__<orig-name>
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new("01A", "a.eml", "accepted", "strict", "a.html", "h1", headers);
        
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
        let mut sidecar = MessageSidecar::new("01A", "a.eml", "accepted", "strict", "a.html", "h1", headers);
        
        let original_activity = sidecar.last_activity.clone();
        std::thread::sleep(std::time::Duration::from_millis(10));
        sidecar.touch();
        
        assert_ne!(sidecar.last_activity, original_activity);
    }

    #[test]
    fn sidecar_mark_read_sets_flag_and_touches() {
        let headers = HeadersCache::new("Test", "Subject");
        let mut sidecar = MessageSidecar::new("01A", "a.eml", "accepted", "strict", "a.html", "h1", headers);
        
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
        let mut sidecar = MessageSidecar::new("01A", "a.eml", "quarantine", "strict", "a.html", "h1", headers);
        
        sidecar.set_rspamd(RspamdSummary {
            score: 7.5,
            symbols: vec!["DKIM_REJECT".to_string(), "SPF_FAIL".to_string()],
        });
        
        assert!(sidecar.rspamd.is_some());
        let rspamd = sidecar.rspamd.unwrap();
        assert_eq!(rspamd.score, 7.5);
        assert_eq!(rspamd.symbols.len(), 2);
    }
}
