pub fn generate() -> String {
    ulid::Ulid::new().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generates_unique() {
        let a = generate();
        let b = generate();
        assert_ne!(a, b);
    }

    #[test]
    fn ulid_format_validation() {
        // Per spec: ULID is 26 characters, Crockford's Base32
        let ulid = generate();
        assert_eq!(ulid.len(), 26);

        // Should be uppercase alphanumeric (Crockford's Base32)
        assert!(
            ulid.chars()
                .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit())
        );
    }

    #[test]
    fn ulid_sortable_by_time() {
        // ULIDs generated in sequence should be sortable
        let mut ulids = Vec::new();
        for _ in 0..10 {
            ulids.push(generate());
            std::thread::sleep(std::time::Duration::from_millis(1));
        }

        // ULIDs should be sorted (first 10 chars are timestamp)
        let mut sorted = ulids.clone();
        sorted.sort();
        assert_eq!(ulids, sorted);
    }

    #[test]
    fn ulid_spec_example_format() {
        // Per spec: ULID examples like "01ARZ3NDEKTSV4RRFFQ69G5FAV"
        let ulid = generate();

        // First char should be 0-7 (timestamp component)
        let first = ulid.chars().next().unwrap();
        assert!(first.is_ascii_digit() || matches!(first, 'A'..='H'));
    }
}
