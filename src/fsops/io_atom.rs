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
}
