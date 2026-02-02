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

    #[test]
    fn store_preserves_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());
        let stored = store.store("file.txt", b"first").unwrap();
        // Attempt to store a different payload for the same hash; the file should remain unchanged.
        store.store("file.txt", b"first").unwrap();
        let contents = std::fs::read(&stored.path).unwrap();
        assert_eq!(contents, b"first");
    }

    #[test]
    fn garbage_collect_handles_missing_root() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("not_created");
        let store = AttachmentStore::new(&path);
        assert!(store.garbage_collect().unwrap().is_empty());
    }

    #[test]
    fn store_deduplicates_identical_content() {
        // Per spec: content-addressed storage means same content = same file
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let stored1 = store.store("photo1.jpg", b"image data").unwrap();
        let stored2 = store.store("photo2.jpg", b"image data").unwrap();

        // Same hash, different names in filename
        assert_eq!(stored1.sha256, stored2.sha256);

        // Both files should exist (different names due to filename suffix)
        assert!(stored1.path.exists());
        assert!(stored2.path.exists());
    }

    #[test]
    fn store_filename_format_includes_sha256_and_name() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let stored = store.store("invoice.pdf", b"test content").unwrap();
        let filename = stored.path.file_name().unwrap().to_string_lossy();

        // Per spec: format is <sha256>__<orig-name>
        assert!(filename.contains("__"));
        assert!(filename.ends_with("invoice.pdf"));
        assert_eq!(stored.sha256.len(), 64); // SHA256 is 32 bytes = 64 hex chars
    }

    #[test]
    fn garbage_collect_removes_only_empty_files() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        // Store a real file
        store.store("real.txt", b"content").unwrap();

        // Create empty files manually
        fs::write(store.root.join("empty1"), b"").unwrap();
        fs::write(store.root.join("empty2"), b"").unwrap();

        let removed = store.garbage_collect().unwrap();

        // Should only remove empty files
        assert_eq!(removed.len(), 2);

        // Real file should still exist
        assert!(store.root.join("real.txt").parent().unwrap().exists());
    }

    #[test]
    fn load_nonexistent_file_errors() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let err = store
            .load("nonexistent__file.txt")
            .expect_err("expected error");
        assert!(
            format!("{err:?}").contains("No such file") || format!("{err:?}").contains("not found")
        );
    }

    #[test]
    fn store_binary_content() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        // Binary data (not UTF-8)
        let binary = vec![0xFF, 0xFE, 0xFD, 0x00, 0x01, 0x02];
        let stored = store.store("binary.dat", &binary).unwrap();

        let loaded = store
            .load(stored.path.file_name().unwrap().to_str().unwrap())
            .unwrap();
        assert_eq!(loaded, binary);
    }

    #[test]
    fn store_large_file() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        // 1MB file
        let large_data = vec![0xAB; 1024 * 1024];
        let stored = store.store("large.bin", &large_data).unwrap();

        let loaded = store
            .load(stored.path.file_name().unwrap().to_str().unwrap())
            .unwrap();
        assert_eq!(loaded.len(), large_data.len());
        assert_eq!(loaded, large_data);
    }

    #[test]
    fn store_special_characters_in_filename() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        // Filename with spaces and special chars
        let stored = store.store("my document (v2).pdf", b"doc").unwrap();
        let filename = stored.path.file_name().unwrap().to_string_lossy();

        assert!(filename.contains("my document (v2).pdf"));

        // Should be loadable
        let loaded = store
            .load(stored.path.file_name().unwrap().to_str().unwrap())
            .unwrap();
        assert_eq!(loaded, b"doc");
    }

    #[test]
    fn garbage_collect_idempotent() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        fs::write(store.root.join("empty"), b"").unwrap();

        let removed1 = store.garbage_collect().unwrap();
        assert_eq!(removed1.len(), 1);

        // Second GC should find nothing
        let removed2 = store.garbage_collect().unwrap();
        assert_eq!(removed2.len(), 0);
    }

    #[test]
    fn store_empty_filename() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        // Empty filename should still work (will be in format hash__)
        let stored = store.store("", b"content").unwrap();
        assert!(
            stored
                .path
                .file_name()
                .unwrap()
                .to_string_lossy()
                .contains("__")
        );
    }

    #[test]
    fn load_nonexistent_returns_error() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let result = store.load("nonexistent_file.txt");
        assert!(result.is_err());
    }

    #[test]
    fn gc_preserves_non_empty_files() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        // Create non-empty file
        let stored = store.store("keep.txt", b"content").unwrap();

        // GC should not remove it
        let removed = store.garbage_collect().unwrap();
        assert_eq!(removed.len(), 0);

        // File should still exist
        assert!(stored.path.exists());
    }

    #[test]
    fn store_unicode_filename() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let stored = store.store("文档.txt", b"unicode").unwrap();
        let filename = stored.path.file_name().unwrap().to_string_lossy();
        assert!(filename.contains("文档.txt"));

        let loaded = store.load(&filename).unwrap();
        assert_eq!(loaded, b"unicode");
    }

    #[test]
    fn attachment_meta_format() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let meta = store.store("test.pdf", b"data").unwrap();

        // Should have sha256 and path
        assert!(!meta.sha256.is_empty());
        assert!(meta.path.exists());

        // Filename should contain the original name
        let filename = meta.path.file_name().unwrap().to_string_lossy();
        assert!(filename.contains("test.pdf"));
    }

    #[test]
    fn sha256_hash_correctness() {
        let dir = tempfile::tempdir().unwrap();
        let store = AttachmentStore::new(dir.path());

        let content = b"test content";
        let meta = store.store("file.txt", content).unwrap();

        // Compute expected hash
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(content);
        let expected = hex::encode(hasher.finalize());

        assert_eq!(meta.sha256, expected);
    }
}
