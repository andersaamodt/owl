use sha2::{Digest, Sha256};
use std::fs;
use std::io::Read;
use std::path::PathBuf;

use anyhow::Result;

pub struct AttachmentStore {
    root: PathBuf,
}

pub struct StoredAttachment {
    pub path: PathBuf,
    pub sha256: String,
}

impl AttachmentStore {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    pub fn store(&self, name: &str, data: &[u8]) -> Result<StoredAttachment> {
        fs::create_dir_all(&self.root)?;
        let mut hasher = Sha256::new();
        hasher.update(data);
        let digest = hex::encode(hasher.finalize());
        let filename = format!("{digest}__{name}");
        let path = self.root.join(filename);
        if !path.exists() {
            std::fs::write(&path, data)?;
        }
        Ok(StoredAttachment {
            path,
            sha256: digest,
        })
    }

    pub fn load(&self, name: &str) -> Result<Vec<u8>> {
        let mut file = fs::File::open(self.root.join(name))?;
        let mut buf = Vec::new();
        file.read_to_end(&mut buf)?;
        Ok(buf)
    }

    pub fn garbage_collect(&self) -> Result<Vec<PathBuf>> {
        let mut removed = Vec::new();
        if self.root.exists() {
            for entry in fs::read_dir(&self.root)? {
                let entry = entry?;
                let metadata = entry.metadata()?;
                if metadata.len() == 0 {
                    let path = entry.path();
                    fs::remove_file(&path)?;
                    removed.push(path);
                }
            }
        }
        Ok(removed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn store_and_load() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());
        let stored = store.store("file.txt", b"hello").unwrap();
        assert!(
            stored
                .path
                .file_name()
                .unwrap()
                .to_string_lossy()
                .contains("file.txt")
        );
        assert_eq!(stored.sha256.len(), 64);
        let content = store
            .load(stored.path.file_name().unwrap().to_str().unwrap())
            .unwrap();
        assert_eq!(content, b"hello");
        std::fs::write(store.root.join("empty"), b"").unwrap();
        let gc = store.garbage_collect().unwrap();
        assert!(!gc.is_empty());
    }
}
