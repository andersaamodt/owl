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
}
