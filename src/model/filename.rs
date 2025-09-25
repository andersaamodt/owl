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
}
