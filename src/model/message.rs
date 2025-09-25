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
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RenderInfo {
    pub mode: String,
    pub html: String,
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
            },
            attachments: Vec::new(),
            headers_cache: headers,
            history: Vec::new(),
        }
    }

    pub fn add_attachment(&mut self, sha256: impl Into<String>, name: impl Into<String>) {
        self.attachments.push(AttachmentMeta {
            sha256: sha256.into(),
            name: name.into(),
        });
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
        let yaml = serde_yaml::to_string(&sidecar).unwrap();
        let parsed: MessageSidecar = serde_yaml::from_str(&yaml).unwrap();
        assert_eq!(parsed.attachments.len(), 1);
        assert!(parsed.read);
    }
}
