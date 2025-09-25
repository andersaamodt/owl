use anyhow::Result;
use std::path::PathBuf;

use crate::{
    envcfg::EnvConfig,
    fsops::io_atom::write_atomic,
    model::{
        filename::{html_filename, message_filename, sidecar_filename},
        message::{HeadersCache, MessageSidecar},
    },
    util::ulid,
};

pub struct OutboxPipeline {
    root: PathBuf,
    env: EnvConfig,
}

impl OutboxPipeline {
    pub fn new(root: PathBuf, env: EnvConfig) -> Self {
        Self { root, env }
    }

    pub fn queue(&self, to: &str, subject: &str, body: &[u8]) -> Result<PathBuf> {
        std::fs::create_dir_all(&self.root)?;
        let ulid = ulid::generate();
        let filename = message_filename(subject, &ulid);
        let message_path = self.root.join(&filename);
        write_atomic(&message_path, body)?;
        let headers = HeadersCache::new(to.to_string(), subject.to_string());
        let sidecar = MessageSidecar::new(
            ulid.clone(),
            filename.clone(),
            "outbox",
            self.env.render_mode.clone(),
            html_filename(subject, &ulid),
            "placeholder",
            headers,
        );
        let yaml = serde_yaml::to_string(&sidecar)?;
        write_atomic(
            &self.root.join(sidecar_filename(subject, &ulid)),
            yaml.as_bytes(),
        )?;
        write_atomic(
            &self.root.join(html_filename(subject, &ulid)),
            b"<html></html>",
        )?;
        Ok(message_path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn queue_creates_files() {
        let dir = tempfile::tempdir().unwrap();
        let pipeline = OutboxPipeline::new(dir.path().join("outbox"), EnvConfig::default());
        let path = pipeline.queue("alice@example.org", "Hi", b"Body").unwrap();
        assert!(path.exists());
    }
}
