use regex::Regex;

pub fn subject_to_slug(subject: &str) -> String {
    let trimmed = subject.trim();
    let fallback = "no subject";
    let regex_ws = Regex::new(r"\s+").expect("valid regex");
    let collapsed = if trimmed.is_empty() {
        fallback.to_string()
    } else {
        regex_ws.replace_all(trimmed, " ").to_string()
    };
    let filtered = collapsed
        .chars()
        .filter(|c| !c.is_control())
        .filter(|c| !matches!(c, '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|'))
        .collect::<String>();
    let trimmed = filtered.trim();
    if trimmed.is_empty() {
        fallback.to_string()
    } else {
        let truncated: String = trimmed.chars().take(80).collect();
        truncated.trim_end().to_string()
    }
}

pub fn message_filename(subject: &str, ulid: &str) -> String {
    format!("{} ({ulid}).eml", subject_to_slug(subject))
}

pub fn sidecar_filename(subject: &str, ulid: &str) -> String {
    format!(".{} ({ulid}).yml", subject_to_slug(subject))
}

pub fn html_filename(subject: &str, ulid: &str) -> String {
    format!(".{} ({ulid}).html", subject_to_slug(subject))
}

pub fn outbox_message_filename(ulid: &str) -> String {
    format!("{ulid}.eml")
}

pub fn outbox_sidecar_filename(ulid: &str) -> String {
    format!(".{ulid}.yml")
}

pub fn outbox_html_filename(ulid: &str) -> String {
    format!(".{ulid}.html")
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn slug_collapses_whitespace() {
        assert_eq!(subject_to_slug("Hello   world"), "Hello world");
    }

    #[test]
    fn slug_fallback() {
        assert_eq!(subject_to_slug("   "), "no subject");
    }

    #[test]
    fn slug_filters_disallowed_to_fallback() {
        assert_eq!(subject_to_slug("////"), "no subject");
    }

    #[test]
    fn filenames_include_ulid() {
        let fname = message_filename("Hello", "01ABC");
        assert!(fname.contains("01ABC"));
    }

    #[test]
    fn outbox_filenames_match_spec() {
        let ulid = "01ARZ3NDEKTSV4RRFFQ69G5FAV";
        assert_eq!(outbox_message_filename(ulid), format!("{ulid}.eml"));
        assert_eq!(outbox_sidecar_filename(ulid), format!(".{ulid}.yml"));
        assert_eq!(outbox_html_filename(ulid), format!(".{ulid}.html"));
    }

    proptest! {
        #[test]
        fn slug_is_windows_safe(input in ".{0,256}") {
            let slug = subject_to_slug(&input);
            prop_assert!(!slug.is_empty());
            prop_assert!(slug.chars().count() <= 80);
            for ch in ['\0', '/', ':', '*', '?', '"', '<', '>', '|', '\r', '\n'] {
                prop_assert!(!slug.contains(ch));
            }
            prop_assert_eq!(slug.trim(), slug.as_str());
        }
    }

    #[test]
    fn slug_removes_windows_forbidden_chars() {
        // Per spec: Windows-safe filenames filter /, \, :, *, ?, ", <, >, |
        let slug = subject_to_slug("Test/File\\Name:With*Forbidden?Chars\"<>|");
        assert!(!slug.contains('/'));
        assert!(!slug.contains('\\'));
        assert!(!slug.contains(':'));
        assert!(!slug.contains('*'));
        assert!(!slug.contains('?'));
        assert!(!slug.contains('"'));
        assert!(!slug.contains('<'));
        assert!(!slug.contains('>'));
        assert!(!slug.contains('|'));
    }

    #[test]
    fn slug_removes_control_characters() {
        // Per spec: Control characters filtered
        let slug = subject_to_slug("Test\x00\x01\x02\tTab\nNewline\rReturn");
        assert!(!slug.chars().any(|c| c.is_control()));
    }

    #[test]
    fn slug_truncates_to_80_chars() {
        // Per spec: ≤80 chars
        let long_subject = "a".repeat(200);
        let slug = subject_to_slug(&long_subject);
        assert!(slug.len() <= 80);
        assert_eq!(slug.chars().count(), 80);
    }

    #[test]
    fn slug_preserves_unicode() {
        // Per spec: Unicode preserved
        let slug = subject_to_slug("Hello 世界 Привет مرحبا");
        assert!(slug.contains('世'));
        assert!(slug.contains('界'));
        assert!(slug.contains("Привет"));
        assert!(slug.contains("مرحبا"));
    }

    #[test]
    fn message_filename_format() {
        // Per spec: <subject slug> (<ULID>).eml
        let fname = message_filename("Test Subject", "01ARZ3NDEKTSV4RRFFQ69G5FAV");
        assert_eq!(fname, "Test Subject (01ARZ3NDEKTSV4RRFFQ69G5FAV).eml");
    }

    #[test]
    fn sidecar_filename_hidden() {
        // Per spec: sidecar is hidden (starts with .)
        let fname = sidecar_filename("Test", "01ABC");
        assert!(fname.starts_with('.'));
        assert!(fname.contains("01ABC"));
        assert!(fname.ends_with(".yml"));
    }

    #[test]
    fn html_filename_hidden() {
        // Per spec: sanitized HTML is hidden (starts with .)
        let fname = html_filename("Test", "01ABC");
        assert!(fname.starts_with('.'));
        assert!(fname.ends_with(".html"));
    }
}
