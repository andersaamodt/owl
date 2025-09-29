use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;

use anyhow::Result;
use tempfile::NamedTempFile;

pub fn write_atomic(path: &Path, contents: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut tmp = NamedTempFile::new_in(path.parent().unwrap_or_else(|| Path::new(".")))?;
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
}
