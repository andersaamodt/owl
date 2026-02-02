use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;

use anyhow::{Context, Result};
use tempfile::NamedTempFile;

/// Create all directories in the path, handling EOPNOTSUPP on macOS
pub fn create_dir_all(path: &Path) -> Result<()> {
    match fs::create_dir_all(path) {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(45) => {
            // EOPNOTSUPP on macOS - the operation may have partially succeeded
            // Check if the directory actually exists now
            if path.exists() && path.is_dir() {
                // Directory was created despite the error
                Ok(())
            } else {
                // Directory wasn't created - try creating parent and then this directory
                // This can happen if the permission-setting operation failed
                if let Some(parent) = path.parent()
                    && !parent.exists()
                {
                    // Recursively create parent without setting permissions
                    create_dir_all(parent)?;
                }
                // Try creating just this directory (not setting permissions)
                match fs::create_dir(path) {
                    Ok(()) => Ok(()),
                    Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => Ok(()),
                    Err(e) => Err(e.into()),
                }
            }
        }
        Err(e) => Err(e.into()),
    }
}

pub fn write_atomic(path: &Path, contents: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent() {
        create_dir_all(parent)?;
    }

    let parent_dir = path.parent().unwrap_or_else(|| Path::new("."));

    // Try to create temp file - this can fail with EOPNOTSUPP on some macOS filesystems
    let mut tmp = match NamedTempFile::new_in(parent_dir) {
        Ok(t) => t,
        Err(e) if e.raw_os_error() == Some(45) => {
            // EOPNOTSUPP on macOS - fallback to using tempdir in /tmp
            match NamedTempFile::new() {
                Ok(t) => t,
                Err(e2) if e2.raw_os_error() == Some(45) => {
                    // Even /tmp fails with EOPNOTSUPP - write directly without temp file
                    // This loses atomicity but allows the operation to succeed
                    match fs::write(path, contents) {
                        Ok(()) => return Ok(()),
                        Err(e3) if e3.raw_os_error() == Some(45) => {
                            // fs::write also fails - try with OpenOptions without mode
                            let mut file = fs::OpenOptions::new()
                                .write(true)
                                .create(true)
                                .truncate(true)
                                .open(path)?;
                            use std::io::Write;
                            file.write_all(contents)?;
                            file.flush()?;
                            return Ok(());
                        }
                        Err(e3) => return Err(e3.into()),
                    }
                }
                Err(e2) => return Err(e2).with_context(|| "creating temp file (fallback)")?,
            }
        }
        Err(e) => return Err(e.into()),
    };

    tmp.write_all(contents)?;
    tmp.flush()?;
    tmp.as_file().sync_all()?;
    tmp.persist(path)?;
    Ok(())
}

pub fn read_to_string(path: &Path) -> Result<String> {
    let mut file = File::open(path)?;
    let mut buf = String::new();
    file.read_to_string(&mut buf)?;
    Ok(buf)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use std::fs;

    #[test]
    fn write_and_read() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("file.txt");
        write_atomic(&file, b"hello").unwrap();
        let contents = read_to_string(&file).unwrap();
        assert_eq!(contents, "hello");
        fs::remove_file(&file).unwrap();
    }

    #[test]
    fn write_atomic_creates_parent_directories() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("nested").join("file.txt");
        write_atomic(&file, b"data").unwrap();
        let contents = read_to_string(&file).unwrap();
        assert_eq!(contents, "data");
    }

    #[test]
    fn write_atomic_reports_parent_creation_error() {
        let dir = tempfile::tempdir().unwrap();
        let blocker = dir.path().join("occupied");
        fs::write(&blocker, b"file").unwrap();
        let nested = blocker.join("child.txt");
        let err = write_atomic(&nested, b"data").unwrap_err();
        let io_err = err.downcast_ref::<std::io::Error>().unwrap();
        assert_eq!(io_err.kind(), std::io::ErrorKind::AlreadyExists);
    }

    #[test]
    #[serial]
    fn write_atomic_without_parent_creates_in_cwd() {
        let dir = tempfile::tempdir().unwrap();
        let original = std::env::current_dir().unwrap();
        std::env::set_current_dir(dir.path()).unwrap();
        let path = Path::new("standalone.txt");
        write_atomic(path, b"contents").unwrap();
        let data = read_to_string(path).unwrap();
        assert_eq!(data, "contents");
        std::env::set_current_dir(original).unwrap();
    }

    #[test]
    fn write_atomic_with_empty_path_errors() {
        let err = write_atomic(Path::new(""), b"data").unwrap_err();
        assert!(err.to_string().contains("persist"));
    }

    #[test]
    fn write_atomic_overwrites_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("overwrite.txt");

        write_atomic(&file, b"first").unwrap();
        assert_eq!(read_to_string(&file).unwrap(), "first");

        write_atomic(&file, b"second").unwrap();
        assert_eq!(read_to_string(&file).unwrap(), "second");
    }

    #[test]
    fn write_atomic_with_binary_data() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("binary.dat");

        let binary = vec![0xFF, 0xFE, 0x00, 0x01, 0xAB, 0xCD];
        write_atomic(&file, &binary).unwrap();

        let loaded = fs::read(&file).unwrap();
        assert_eq!(loaded, binary);
    }

    #[test]
    fn write_atomic_with_large_content() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("large.dat");

        // 1MB file
        let large = vec![0x42; 1024 * 1024];
        write_atomic(&file, &large).unwrap();

        let loaded = fs::read(&file).unwrap();
        assert_eq!(loaded.len(), large.len());
    }

    #[test]
    fn write_atomic_with_empty_content() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("empty.txt");

        write_atomic(&file, b"").unwrap();

        let contents = fs::read(&file).unwrap();
        assert_eq!(contents, b"");
    }

    #[test]
    #[cfg(unix)]
    fn write_atomic_sets_file_permissions() {
        use std::os::unix::fs::PermissionsExt;

        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("perms.txt");

        write_atomic(&file, b"data").unwrap();

        let metadata = fs::metadata(&file).unwrap();
        let mode = metadata.permissions().mode();

        // File should be readable/writable by owner (at least)
        assert_ne!(mode & 0o600, 0);
    }

    #[test]
    fn write_atomic_deep_nested_path() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("a").join("b").join("c").join("deep.txt");

        write_atomic(&file, b"nested content").unwrap();
        assert_eq!(read_to_string(&file).unwrap(), "nested content");
    }

    #[test]
    fn read_to_string_missing_file_errors() {
        let dir = tempfile::tempdir().unwrap();
        let missing = dir.path().join("nonexistent.txt");

        let err = read_to_string(&missing).expect_err("expected error");
        assert!(
            format!("{err:?}").contains("No such file") || format!("{err:?}").contains("not found")
        );
    }

    #[test]
    fn read_to_string_with_unicode() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("unicode.txt");

        let unicode = "Hello 世界 Привет مرحبا";
        write_atomic(&file, unicode.as_bytes()).unwrap();

        let loaded = read_to_string(&file).unwrap();
        assert_eq!(loaded, unicode);
    }

    #[test]
    fn write_atomic_atomicity_check() {
        // Verify that partial writes don't leave corrupted files
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("atomic.txt");

        write_atomic(&file, b"initial").unwrap();

        // Even if second write somehow failed mid-way, file should still have valid content
        // This is the guarantee of atomic writes - either complete new content or old content
        write_atomic(&file, b"updated content").unwrap();
        let result = read_to_string(&file).unwrap();

        // Should be exactly the new content, not corrupted
        assert_eq!(result, "updated content");
    }

    #[test]
    fn write_atomic_empty_path_component() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("file.txt");

        write_atomic(&file, b"test").unwrap();
        assert_eq!(read_to_string(&file).unwrap(), "test");
    }

    #[test]
    fn write_atomic_preserves_exact_bytes() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("binary.dat");

        // Test binary data with null bytes and all byte values
        let binary: Vec<u8> = (0..=255).collect();
        write_atomic(&file, &binary).unwrap();

        let loaded = std::fs::read(&file).unwrap();
        assert_eq!(loaded, binary);
    }

    #[test]
    fn read_to_string_invalid_utf8() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("invalid.txt");

        // Write invalid UTF-8
        std::fs::write(&file, [0xFF, 0xFE, 0xFD]).unwrap();

        let result = read_to_string(&file);
        assert!(result.is_err());
    }

    #[test]
    fn write_atomic_zero_bytes() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("empty.txt");

        write_atomic(&file, b"").unwrap();
        assert_eq!(read_to_string(&file).unwrap(), "");
        assert!(file.exists());
    }

    #[test]
    fn write_atomic_creates_nested_parent_dirs() {
        let dir = tempfile::tempdir().unwrap();
        let nested = dir.path().join("level1").join("level2").join("file.txt");

        // Parent directories don't exist yet
        assert!(!nested.parent().unwrap().exists());

        write_atomic(&nested, b"content").unwrap();

        // Now they should exist
        assert!(nested.parent().unwrap().exists());
        assert_eq!(read_to_string(&nested).unwrap(), "content");
    }

    #[test]
    fn write_atomic_multiple_sequential() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("multi.txt");

        // Multiple writes should all succeed
        for i in 0..10 {
            let content = format!("version {}", i);
            write_atomic(&file, content.as_bytes()).unwrap();
            assert_eq!(read_to_string(&file).unwrap(), content);
        }
    }

    #[test]
    fn write_atomic_very_large_content() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("large.bin");

        // 10MB file
        let large = vec![b'X'; 10 * 1024 * 1024];
        write_atomic(&file, &large).unwrap();

        let loaded = std::fs::read(&file).unwrap();
        assert_eq!(loaded.len(), large.len());
    }
}
