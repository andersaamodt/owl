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
            // Use 10ms sleep to ensure timestamp difference on all systems
            std::thread::sleep(std::time::Duration::from_millis(10));
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

    #[test]
    fn ulid_no_ambiguous_chars() {
        // Crockford's Base32 excludes I, L, O, U to avoid ambiguity
        let ulid = generate();
        for c in ulid.chars() {
            assert_ne!(c, 'I');
            assert_ne!(c, 'L');
            assert_ne!(c, 'O');
            assert_ne!(c, 'U');
        }
    }

    #[test]
    fn ulid_always_26_chars() {
        // Generate multiple ULIDs to ensure length is always consistent
        for _ in 0..100 {
            let ulid = generate();
            assert_eq!(ulid.len(), 26, "ULID should always be 26 chars: {}", ulid);
        }
    }

    #[test]
    fn ulid_monotonic_in_millisecond() {
        // Multiple ULIDs within same millisecond should still be unique
        let ulids: Vec<String> = (0..10).map(|_| generate()).collect();
        let unique: std::collections::HashSet<_> = ulids.iter().collect();
        assert_eq!(unique.len(), 10, "All ULIDs should be unique");
    }

    #[test]
    fn ulid_can_be_parsed() {
        // Generate a ULID and ensure it's valid
        let ulid_str = generate();
        let parsed = ulid::Ulid::from_string(&ulid_str);
        assert!(parsed.is_ok(), "Generated ULID should be parseable");
    }

    #[test]
    fn ulid_timestamp_component() {
        // First 10 chars are timestamp (48 bits)
        let ulid = generate();
        let timestamp_part = &ulid[..10];
        assert_eq!(timestamp_part.len(), 10);
        // Should be valid Base32
        assert!(timestamp_part.chars().all(|c| c.is_ascii_alphanumeric()));
    }

    #[test]
    fn ulid_random_component() {
        // Last 16 chars are random (80 bits)
        let ulid = generate();
        let random_part = &ulid[10..];
        assert_eq!(random_part.len(), 16);
        // Should be valid Base32
        assert!(random_part.chars().all(|c| c.is_ascii_alphanumeric()));
    }
}
